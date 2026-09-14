# R/metrics.R
#
# Performance metrics, kept deliberately explicit rather than delegated to
# package defaults, since the forensic audit found package-default /
# copy-pasted formulas were a direct source of past errors (mixed
# annualization conventions, a monthly-vs-annual risk-free unit bug, etc).
#
# All functions take a plain numeric vector (or something coercible via
# as.numeric()) of monthly discrete returns.

# Risk-free assumption --------------------------------------------------
# Same annual assumption as the historical project (4.5%), but the
# monthly conversion is ALWAYS compounding-consistent and is the only
# risk-free number used anywhere in Stage 1 metrics. Documented here as
# the single source of truth to prevent the annual/monthly unit bug found
# in archive/original-final.Rmd (methodology-audit finding H3).
RF_ANNUAL <- 0.045
rf_monthly_rate <- function(rf_annual = RF_ANNUAL) (1 + rf_annual)^(1 / 12) - 1

#' Geometric compound annual growth rate from a vector of monthly returns.
cagr <- function(R) {
  R <- as.numeric(na.omit(R))
  if (length(R) == 0) return(NA_real_)
  total <- prod(1 + R) - 1
  yrs <- length(R) / 12
  (1 + total)^(1 / yrs) - 1
}

#' Simple (arithmetic) annualized mean return: mean(monthly R) * 12.
#' Deliberately kept distinct from CAGR (geometric) per Stage 1 spec.
annualized_arithmetic_mean <- function(R) {
  R <- as.numeric(na.omit(R))
  mean(R) * 12
}

#' Annualized volatility from monthly returns (i.i.d. convention: sd * sqrt(12)).
annualized_vol <- function(R) {
  R <- as.numeric(na.omit(R))
  sd(R) * sqrt(12)
}

#' Annualized Sharpe ratio using a consistent monthly excess-return
#' formulation (never mixes a geometric CAGR numerator with an i.i.d.
#' monthly-vol denominator -- see methodology-audit finding M3):
#'
#'   Sharpe_annualized = mean(Rp - Rf_monthly) / sd(Rp - Rf_monthly) * sqrt(12)
sharpe_ratio <- function(R, rf_annual = RF_ANNUAL) {
  R <- as.numeric(na.omit(R))
  rf_m <- rf_monthly_rate(rf_annual)
  excess <- R - rf_m
  mean(excess) / sd(excess) * sqrt(12)
}

#' Downside deviation of a return series below a minimum acceptable
#' return (MAR), using the full sample size N in the denominator
#' (a conservative, commonly used convention -- documented explicitly).
downside_deviation <- function(R, mar = 0) {
  R <- as.numeric(na.omit(R))
  shortfall <- pmin(R - mar, 0)
  sqrt(mean(shortfall^2))
}

#' Annualized Sortino ratio, mirroring the Sharpe formulation above:
#' numerator = annualized mean monthly excess return over Rf,
#' denominator = annualized downside deviation of that same excess return
#' series below zero.
sortino_ratio <- function(R, rf_annual = RF_ANNUAL) {
  R <- as.numeric(na.omit(R))
  rf_m <- rf_monthly_rate(rf_annual)
  excess <- R - rf_m
  dd <- downside_deviation(excess, mar = 0) * sqrt(12)
  if (dd == 0) return(NA_real_)
  (mean(excess) * 12) / dd
}

#' Maximum drawdown computed from a MONTHLY-SAMPLED wealth index.
#' Documented limitation: this can understate true peak-to-trough loss
#' for assets/portfolios with material intra-month drawdowns (see
#' docs/rebuilt-methodology.md limitations -- daily NAV explicitly
#' deferred out of Stage 1 scope).
max_drawdown <- function(R) {
  R <- as.numeric(na.omit(R))
  wealth <- cumprod(1 + R)
  running_peak <- cummax(wealth)
  drawdown <- wealth / running_peak - 1
  min(drawdown)
}

#' Calmar ratio: CAGR / |max drawdown|.
calmar_ratio <- function(R) {
  mdd <- max_drawdown(R)
  if (mdd == 0) return(NA_real_)
  cagr(R) / abs(mdd)
}

#' Historical (empirical) monthly Value-at-Risk at a given confidence
#' level, reported as the raw quantile (typically negative = a loss).
historical_var <- function(R, level = 0.95) {
  R <- as.numeric(na.omit(R))
  as.numeric(quantile(R, probs = 1 - level, type = 7))
}

#' Historical (empirical) monthly Expected Shortfall: mean of returns at
#' or below the VaR threshold at the given confidence level.
historical_es <- function(R, level = 0.95) {
  R <- as.numeric(na.omit(R))
  v <- historical_var(R, level)
  tail_obs <- R[R <= v]
  if (length(tail_obs) == 0) return(NA_real_)
  mean(tail_obs)
}

#' One-row performance summary table for a monthly return series.
performance_summary <- function(R, label, rf_annual = RF_ANNUAL) {
  R <- as.numeric(na.omit(R))
  data.frame(
    portfolio = label,
    n_months = length(R),
    cagr = cagr(R),
    annualized_arithmetic_mean = annualized_arithmetic_mean(R),
    annualized_vol = annualized_vol(R),
    sharpe_ratio = sharpe_ratio(R, rf_annual),
    sortino_ratio = sortino_ratio(R, rf_annual),
    max_drawdown_monthly_sampled = max_drawdown(R),
    calmar_ratio = calmar_ratio(R),
    var_95_monthly = historical_var(R, 0.95),
    es_95_monthly = historical_es(R, 0.95),
    best_month = max(R),
    worst_month = min(R),
    positive_month_hit_rate = mean(R > 0),
    rf_annual_assumption = rf_annual,
    rf_monthly_conversion = "(1+rf_annual)^(1/12) - 1",
    stringsAsFactors = FALSE
  )
}
