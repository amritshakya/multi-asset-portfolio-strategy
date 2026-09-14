# R/data.R
#
# Data acquisition and local caching for Stage 1.
#
# Design goals (per docs/methodology-audit.md and the Stage 1 scope lock):
#   * NO Sys.Date() anywhere - the research window is a fixed, frozen constant.
#   * Every download is cached locally on first run so that re-running the
#     pipeline during development does not silently change the historical
#     sample (Yahoo's adjusted-close history can itself be revised over time).
#   * We record data provenance explicitly: source, requested dates, actual
#     first/last observation, and a download timestamp.

suppressMessages({
  library(quantmod)
  library(xts)
})

# Frozen research window --------------------------------------------------
RESEARCH_START <- as.Date("2016-01-01")
RESEARCH_END   <- as.Date("2025-12-31")

ASSET_TICKERS     <- c("JPM", "XOM", "EEM", "GLD", "BTC-USD")
BENCHMARK_TICKERS <- c("SPY", "ACWI", "AOR")

CACHE_DIR <- file.path("data", "cache")

#' Download (or load from cache) adjusted daily prices for one ticker.
#'
#' @param ticker Yahoo ticker symbol.
#' @param start,end Fixed Date bounds (never Sys.Date()).
#' @param cache_dir Directory used to persist a local copy.
#' @param refresh If TRUE, force a re-download even if a cache file exists.
#' @return A list with the adjusted-close xts series and a metadata record.
get_adjusted_prices <- function(ticker,
                                 start = RESEARCH_START,
                                 end = RESEARCH_END,
                                 cache_dir = CACHE_DIR,
                                 refresh = FALSE) {

  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  safe_name <- gsub("[^A-Za-z0-9_-]", "_", ticker)
  cache_file <- file.path(cache_dir, paste0(safe_name, ".rds"))

  if (file.exists(cache_file) && !refresh) {
    cached <- readRDS(cache_file)
    return(cached)
  }

  message("Downloading ", ticker, " from Yahoo Finance (", start, " to ", end, ")...")
  raw <- getSymbols(
    ticker, src = "yahoo",
    from = start, to = end + 1,  # +1 day: Yahoo's `to` is exclusive
    auto.assign = FALSE
  )

  adj <- Ad(raw)
  colnames(adj) <- ticker

  meta <- list(
    ticker = ticker,
    source = "Yahoo Finance (quantmod::getSymbols)",
    requested_start = start,
    requested_end = end,
    actual_first_observation = as.character(first(index(adj))),
    actual_last_observation = as.character(last(index(adj))),
    n_observations = nrow(adj),
    download_timestamp_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
    price_convention = "Adjusted close (dividend- and split-adjusted, quantmod::Ad())"
  )

  out <- list(prices = adj, meta = meta)
  saveRDS(out, cache_file)
  out
}

#' Download/load all asset + benchmark series and return provenance table.
#'
#' @param refresh If TRUE, force re-download of every ticker.
#' @return list(prices = named list of xts, meta = data.frame of provenance)
load_all_price_series <- function(refresh = FALSE) {
  tickers <- c(ASSET_TICKERS, BENCHMARK_TICKERS)
  results <- lapply(tickers, get_adjusted_prices, refresh = refresh)
  names(results) <- tickers

  prices <- lapply(results, `[[`, "prices")
  meta_list <- lapply(results, `[[`, "meta")
  meta_df <- do.call(rbind, lapply(meta_list, as.data.frame, stringsAsFactors = FALSE))
  rownames(meta_df) <- NULL

  list(prices = prices, meta = meta_df)
}

#' Write the data provenance table to disk (for the audit trail).
write_data_provenance <- function(meta_df, path = file.path("outputs", "rebuilt", "tables", "data-provenance.csv")) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  write.csv(meta_df, path, row.names = FALSE)
  invisible(path)
}
