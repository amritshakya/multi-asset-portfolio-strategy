# R/returns.R
#
# Monthly return construction.
#
# Methodology-audit finding M6 (docs/methodology-audit.md) showed that
# merging all assets into ONE xts object first and then calling
# to.monthly() on the merged object silently reconciles BTC's 7-day
# calendar down to the last common ROW across all columns -- i.e. it can
# quietly discard an asset's true month-end observation.
#
# Fix used here: convert EACH asset's price series to monthly *on its own*
# (its own last available trading observation in each calendar month), and
# only merge the resulting monthly series afterward, joined by calendar
# month-end label. This is what the Stage 1 spec calls for:
#   "For each asset, use its own last available observation in each
#    calendar month, then align monthly returns by calendar month."
#
# We explicitly do NOT forward-fill: if an asset has no observation in a
# given calendar month, that month is left NA for that asset and handled
# by na.omit() at the return-matrix stage (dropping the row entirely),
# never by carrying a stale price forward.

suppressMessages({
  library(xts)
  library(quantmod)
  library(PerformanceAnalytics)
})

#' Collapse ONE asset's daily adjusted-price series to its own monthly
#' last-observation-of-calendar-month series.
#'
#' @param px xts, single column of adjusted prices.
#' @return xts, single column, indexed at the last calendar day of each
#'   month, valued at that asset's own last available observation in that
#'   month (not row-aligned to any other series).
to_monthly_last_obs <- function(px) {
  stopifnot(is.xts(px), ncol(px) == 1)
  m <- to.monthly(px, indexAt = "lastof", OHLC = FALSE, drop.time = TRUE)
  colnames(m) <- colnames(px)
  m
}

#' Build a monthly discrete-return matrix from a named list of daily
#' adjusted-price xts series, each on its own native trading calendar.
#'
#' @param price_list Named list of single-column xts price series.
#' @return xts matrix of monthly discrete returns, one column per asset,
#'   rows restricted to months where EVERY asset has a valid return
#'   (na.omit -- no forward-filling).
build_monthly_returns <- function(price_list) {
  monthly_prices <- lapply(price_list, to_monthly_last_obs)

  # Align independently-computed monthly series by their calendar-month
  # label. merge() here is an outer join on the "lastof" month-end dates;
  # any asset missing an observation for a given month becomes NA for that
  # column only (not row-completed from another asset's calendar).
  merged_prices <- do.call(merge, monthly_prices)
  colnames(merged_prices) <- names(price_list)

  monthly_returns <- Return.calculate(merged_prices, method = "discrete")

  n_before <- nrow(monthly_returns)
  monthly_returns <- na.omit(monthly_returns)
  n_after <- nrow(monthly_returns)
  if (n_after < n_before) {
    message(
      "build_monthly_returns(): dropped ", n_before - n_after,
      " month(s) with at least one missing asset return (no forward-fill applied)."
    )
  }

  monthly_returns
}
