# R/plotting.R
#
# Minimal, functional figures only (per Stage 1 scope lock: no time spent
# on visual polish). Uses ggplot2, already a project dependency.

suppressMessages({
  library(ggplot2)
  library(xts)
  library(zoo)
})

#' Equity-curve chart (growth of $1) for a named list of monthly return xts
#' series, restricted to their common overlapping date range.
plot_equity_curves <- function(return_list, path, title = "Equity Curves (Growth of $1)") {
  common_dates <- Reduce(intersect, lapply(return_list, index))
  common_dates <- as.Date(common_dates)

  df_list <- lapply(names(return_list), function(nm) {
    r <- as.numeric(return_list[[nm]][common_dates])
    data.frame(date = common_dates, series = nm, wealth = cumprod(1 + r))
  })
  df <- do.call(rbind, df_list)

  p <- ggplot(df, aes(x = date, y = wealth, color = series)) +
    geom_line(linewidth = 0.7) +
    labs(title = title, x = NULL, y = "Wealth (Start = $1)", color = NULL) +
    theme_minimal()

  ggsave(path, p, width = 9, height = 5.5, dpi = 150)
  invisible(path)
}

#' Drawdown chart for the same named list of return series.
plot_drawdowns <- function(return_list, path, title = "Drawdowns (Monthly-Sampled)") {
  common_dates <- Reduce(intersect, lapply(return_list, index))
  common_dates <- as.Date(common_dates)

  df_list <- lapply(names(return_list), function(nm) {
    r <- as.numeric(return_list[[nm]][common_dates])
    wealth <- cumprod(1 + r)
    dd <- wealth / cummax(wealth) - 1
    data.frame(date = common_dates, series = nm, drawdown = dd)
  })
  df <- do.call(rbind, df_list)

  p <- ggplot(df, aes(x = date, y = drawdown, color = series)) +
    geom_line(linewidth = 0.7) +
    labs(title = title, x = NULL, y = "Drawdown", color = NULL) +
    theme_minimal()

  ggsave(path, p, width = 9, height = 5, dpi = 150)
  invisible(path)
}

#' Stacked-area chart of target (or realized) weights through time.
plot_weights_stacked <- function(weights_xts, path, title) {
  dates <- index(weights_xts)
  assets <- colnames(weights_xts)
  df <- data.frame(
    date = rep(dates, times = length(assets)),
    asset = rep(assets, each = length(dates)),
    weight = as.numeric(coredata(weights_xts))
  )

  p <- ggplot(df, aes(x = date, y = weight, fill = asset)) +
    geom_area(position = "stack") +
    labs(title = title, x = NULL, y = "Weight", fill = NULL) +
    theme_minimal()

  ggsave(path, p, width = 9, height = 5, dpi = 150)
  invisible(path)
}

#' Turnover bar chart (one-way turnover per rebalance).
plot_turnover <- function(one_way_turnover_xts, path, title = "One-Way Turnover per Rebalance") {
  df <- data.frame(date = index(one_way_turnover_xts), turnover = as.numeric(one_way_turnover_xts))

  p <- ggplot(df, aes(x = date, y = turnover)) +
    geom_col(fill = "steelblue") +
    labs(title = title, x = NULL, y = "One-Way Turnover") +
    theme_minimal()

  ggsave(path, p, width = 9, height = 4.5, dpi = 150)
  invisible(path)
}
