# R/turnover.R
#
# Turnover summarization on top of the per-rebalance series produced by
# R/backtest.R::compute_portfolio_series().
#
# Definitions (documented per Stage 1 spec section 9):
#   gross_traded_notional_t = sum(abs(target_weight_t - pretrade_weight_t))
#   one_way_turnover_t      = 0.5 * gross_traded_notional_t
#
# "pretrade_weight_t" is the weight the portfolio actually drifted to
# (via compounding, not rebalancing) since the previous trade -- NOT the
# previous period's target weight. This is the key distinction requested:
# turnover is a measure of what actually had to be traded, not merely the
# difference between two successive target vectors.
#
# Annualization convention used here: monthly one-way turnover summed over
# a trailing/rolling 12 observations, averaged, then reported alongside the
# plain monthly average x 12. Both are documented explicitly in the output
# so the convention is never ambiguous.

suppressMessages(library(xts))

#' Summarize turnover for one portfolio's per-rebalance series.
#'
#' @param port_series Output of compute_portfolio_series().
#' @param exclude_initial If TRUE (default), the first ("initial funding")
#'   trade is excluded from the steady-state averages, since it is a
#'   one-time cost of entering the strategy, not a recurring monthly cost.
#'   It is always reported separately regardless.
#' @return A one-row data.frame of summary statistics.
summarize_turnover <- function(port_series, exclude_initial = TRUE) {
  gtn <- as.numeric(port_series$gross_traded_notional)
  owt <- as.numeric(port_series$one_way_turnover)
  is_initial <- port_series$is_initial

  keep <- if (exclude_initial) !is_initial else rep(TRUE, length(gtn))

  data.frame(
    n_rebalances_used = sum(keep),
    initial_funding_gross_traded_notional = gtn[which(is_initial)][1],
    initial_funding_one_way_turnover = owt[which(is_initial)][1],
    avg_monthly_gross_traded_notional = mean(gtn[keep]),
    avg_monthly_one_way_turnover = mean(owt[keep]),
    max_monthly_gross_traded_notional = max(gtn[keep]),
    max_monthly_one_way_turnover = max(owt[keep]),
    annualized_one_way_turnover_x12 = mean(owt[keep]) * 12,
    annualization_convention = "avg monthly one-way turnover x 12 (steady-state months only, initial funding trade excluded)"
  )
}
