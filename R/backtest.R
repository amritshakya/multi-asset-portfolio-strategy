# R/backtest.R
#
# Explicit, hand-rolled walk-forward timing engine.
#
# We deliberately do NOT rely on any package's implicit weight-timing
# behavior (the forensic audit found the original project's headline
# numbers came from an optimizer that saw the full sample it was then
# evaluated on -- see docs/methodology-audit.md, finding C1). Every date
# used below is tracked explicitly in a rebalance-audit table so a human
# reviewer can verify, row by row, that a weight estimated through month t
# is applied only to the return realized in month t+1.
#
# Indexing convention:
#   R is a T x N xts matrix of monthly returns. Row i, dated dates[i],
#   holds the return earned OVER THE PERIOD ENDING at dates[i] (i.e. from
#   dates[i-1] to dates[i]).
#
#   At each walk-forward step we pick a "signal index" i (est_window <= i
#   <= T-1). We estimate mu/Sigma from rows (i-est_window+1):i (i.e. using
#   data observable through, and including, dates[i]). The resulting
#   target weight is dated at dates[i] (signal_date == rebalance_date) and
#   is applied ONLY to row i+1's return -- the return realized strictly
#   after the weight was decided. Row i's own return is never re-used to
#   pay off the weight that was estimated from it.

suppressMessages(library(xts))

# NOTE: this module calls solve_constrained_mvo(), defined in R/optimizer.R.
# The caller (scripts/run_stage1.R, or tests/testthat/helper-load-src.R) is
# responsible for sourcing R/optimizer.R first -- we deliberately avoid a
# relative source() call here so this file behaves the same regardless of
# the caller's working directory.

#' Run the walk-forward constrained MVO strategy.
#'
#' @param R xts of monthly returns (T x N).
#' @param est_window Trailing estimation window length, in months.
#' @param min_w,max_w Per-asset box constraints (named or plain vectors,
#'   same asset order as columns of R).
#' @param lambda Risk-aversion coefficient passed to solve_constrained_mvo().
#' @return list(target_weights = xts (K x N) indexed at signal dates,
#'   rebalance_audit = data.frame, failures = data.frame of any failed
#'   rebalances)
run_walk_forward_mvo <- function(R, est_window = 24, min_w, max_w, lambda = 1) {
  dates <- index(R)
  Tn <- nrow(R)
  N <- ncol(R)
  assets <- colnames(R)

  if (Tn <= est_window) stop("Not enough monthly observations for the estimation window.")

  signal_idx <- seq(est_window, Tn - 1)  # need a row i+1 to hold the weight

  weight_rows <- matrix(NA_real_, nrow = length(signal_idx), ncol = N,
                         dimnames = list(NULL, assets))
  audit <- data.frame(
    estimation_start = as.Date(character()),
    estimation_end = as.Date(character()),
    signal_date = as.Date(character()),
    rebalance_date = as.Date(character()),
    holding_period_start = as.Date(character()),
    holding_period_end = as.Date(character()),
    n_estimation_obs = integer(),
    solver_status = character(),
    stringsAsFactors = FALSE
  )

  for (k in seq_along(signal_idx)) {
    i <- signal_idx[k]
    est_rows <- (i - est_window + 1):i
    est_R <- coredata(R)[est_rows, , drop = FALSE]

    mu <- colMeans(est_R)
    Sigma <- cov(est_R)

    fit <- solve_constrained_mvo(mu, Sigma, min_w = min_w, max_w = max_w, lambda = lambda)
    weight_rows[k, ] <- fit$weights

    audit[k, ] <- list(
      estimation_start = dates[est_rows[1]],
      estimation_end = dates[i],
      signal_date = dates[i],
      rebalance_date = dates[i],
      holding_period_start = dates[i],
      holding_period_end = dates[i + 1],
      n_estimation_obs = length(est_rows),
      solver_status = fit$status
    )
  }

  target_weights <- xts(weight_rows, order.by = audit$signal_date)

  list(
    target_weights = target_weights,
    rebalance_audit = audit,
    failures = audit[audit$solver_status != "OK", , drop = FALSE]
  )
}

#' Build a constant naive 1/N target-weight series aligned to the SAME
#' signal dates as another strategy's audit (for apples-to-apples
#' comparison over the identical evaluated window).
naive_1_over_n_weights <- function(assets, signal_dates) {
  N <- length(assets)
  w <- matrix(1 / N, nrow = length(signal_dates), ncol = N,
              dimnames = list(NULL, assets))
  xts(w, order.by = signal_dates)
}

#' Compute the realized pre-trade (drifted) weight just before rebalance k,
#' given the target weight actually held during holding period k-1 and the
#' return realized over that holding period.
#'
#' pretrade_weight_k = (prev_target * (1 + r)) / sum(prev_target * (1 + r))
drift_weights <- function(prev_target, r) {
  grown <- prev_target * (1 + r)
  grown / sum(grown)
}

#' Turn a series of target weights (established at signal dates, to be
#' applied to the NEXT row of R) into realized gross/net portfolio returns,
#' pre-trade drifted weights, turnover, and transaction costs.
#'
#' @param R Full monthly return xts (T x N) -- must contain, for every
#'   signal date in target_weights, the NEXT row's return.
#' @param target_weights xts (K x N), one row per rebalance, indexed at the
#'   signal/rebalance date. Row k is applied to the return immediately
#'   following that date in R.
#' @param cost_rate Proportional cost per dollar traded (e.g. 0.0005 = 5bps).
#' @return list with per-period gross/net returns, pretrade weights,
#'   turnover, and cost, all indexed at the HOLDING-PERIOD-END date (i.e.
#'   the date of the return actually earned).
compute_portfolio_series <- function(R, target_weights, cost_rate = 0) {
  dates <- index(R)
  assets <- colnames(R)
  N <- length(assets)
  K <- nrow(target_weights)

  signal_dates <- index(target_weights)
  row_of <- match(signal_dates, dates)
  if (anyNA(row_of)) stop("Some target_weights signal dates not found in R's index.")
  if (any(row_of >= nrow(R))) stop("Some signal dates have no subsequent return row in R.")

  holding_end_dates <- dates[row_of + 1]

  gross_return <- numeric(K)
  net_return <- numeric(K)
  pretrade_w <- matrix(NA_real_, nrow = K, ncol = N, dimnames = list(NULL, assets))
  gross_traded_notional <- numeric(K)
  one_way_turnover <- numeric(K)
  cost <- numeric(K)
  is_initial <- logical(K)

  prev_target <- rep(0, N)  # "no position" before the very first rebalance

  for (k in seq_len(K)) {
    tgt_k <- as.numeric(target_weights[k, ])

    if (k == 1) {
      pretrade_w[k, ] <- prev_target  # zero vector: initial funding trade
      is_initial[k] <- TRUE
    } else {
      r_prev_period <- as.numeric(R[row_of[k], ])  # return earned by prev_target during its holding period
      pretrade_w[k, ] <- drift_weights(prev_target, r_prev_period)
    }

    gross_traded_notional[k] <- sum(abs(tgt_k - pretrade_w[k, ]))
    one_way_turnover[k] <- 0.5 * gross_traded_notional[k]
    cost[k] <- cost_rate * gross_traded_notional[k]

    r_hold <- as.numeric(R[row_of[k] + 1, ])
    gross_return[k] <- sum(tgt_k * r_hold)
    net_return[k] <- gross_return[k] - cost[k]

    prev_target <- tgt_k
  }

  list(
    dates = holding_end_dates,
    signal_dates = signal_dates,
    target_weights = target_weights,
    pretrade_weights = xts(pretrade_w, order.by = signal_dates),
    gross_return = xts(gross_return, order.by = holding_end_dates),
    net_return = xts(net_return, order.by = holding_end_dates),
    gross_traded_notional = xts(gross_traded_notional, order.by = signal_dates),
    one_way_turnover = xts(one_way_turnover, order.by = signal_dates),
    cost = xts(cost, order.by = signal_dates),
    is_initial = is_initial,
    cost_rate = cost_rate
  )
}

#' Build the no-rebalance (buy-and-hold) baseline from an initial target
#' weight vector, held with zero subsequent trading over a set of holding
#' periods. Tracks the realized (drifted) weight at the END of every
#' holding period, to make the drift mechanism explicit and chartable.
#'
#' @param R Full monthly return xts (T x N).
#' @param initial_weights Named numeric vector, the starting allocation.
#' @param holding_end_dates Dates (must exist in index(R)) defining the
#'   sequence of periods over which to compound with no rebalancing.
no_rebalance_series <- function(R, initial_weights, holding_end_dates) {
  dates <- index(R)
  assets <- colnames(R)
  N <- length(assets)
  row_of <- match(holding_end_dates, dates)
  if (anyNA(row_of)) stop("Some holding_end_dates not found in R's index.")

  K <- length(row_of)
  realized_w <- matrix(NA_real_, nrow = K, ncol = N, dimnames = list(NULL, assets))
  port_return <- numeric(K)

  w <- as.numeric(initial_weights)
  for (k in seq_len(K)) {
    r <- as.numeric(R[row_of[k], ])
    port_return[k] <- sum(w * r)
    w <- (w * (1 + r)) / sum(w * (1 + r))  # drift forward, NEVER rebalanced
    realized_w[k, ] <- w
  }

  list(
    dates = holding_end_dates,
    realized_weights = xts(realized_w, order.by = holding_end_dates),
    port_return = xts(port_return, order.by = holding_end_dates)
  )
}
