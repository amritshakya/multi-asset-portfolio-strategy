# R/attribution.R
#
# Return contribution and ex-ante risk contribution by asset.
#
# Return contribution methodology
# --------------------------------
# For a portfolio holding weight w_{i,k} in asset i during holding period
# k (realizing asset return r_{i,k}), the period's exact portfolio return
# is Rp_k = sum_i w_{i,k} * r_{i,k}. To get a MULTI-period contribution
# that sums EXACTLY to the portfolio's total compounded (geometric)
# return, each period's per-asset dollar P&L is scaled by the cumulative
# portfolio growth up to the start of that period:
#
#   contribution_i = sum_k  w_{i,k} * r_{i,k} * G_{k-1}
#
# where G_{k-1} = prod_{j<k} (1 + Rp_j)  (G_0 = 1).
#
# Proof this sums correctly:
#   sum_i contribution_i = sum_k Rp_k * G_{k-1} = sum_k (G_k - G_{k-1}) = G_K - 1
# which is exactly the portfolio's total realized (geometric) return.
#
# Risk contribution methodology
# ------------------------------
# At each rebalance date, using the SAME trailing covariance matrix that
# was actually used to select that date's target weights (recomputed here
# from R and the same estimation window, rather than threaded through
# multiple objects, to keep modules decoupled):
#
#   sigma_p  = sqrt(w' Sigma w)
#   MCR_i    = (Sigma w)_i / sigma_p        (marginal contribution to risk)
#   CR_i     = w_i * MCR_i                  (component contribution to risk)
#   PCR_i    = CR_i / sigma_p               (percent contribution to risk)
#
# This is reported PER REBALANCE, not as a single static table, since the
# original project's C2 failure was exactly that: reporting one point-in-
# time risk-budget table as if it described the whole strategy.

#' Exact multi-period return contribution by asset.
#'
#' @param weights_by_period xts (K x N): weight actually held by asset
#'   during each holding period (row k = weight held during period k).
#' @param R Full monthly return xts.
#' @param holding_end_dates Dates of the returns actually earned in each
#'   holding period (must exist in index(R), same order/length as
#'   weights_by_period).
#' @return data.frame with one row per asset: total contribution, and
#'   contribution as a fraction of total portfolio return.
return_contribution <- function(weights_by_period, R, holding_end_dates) {
  assets <- colnames(R)
  N <- length(assets)
  K <- nrow(weights_by_period)
  stopifnot(K == length(holding_end_dates))

  row_of <- match(holding_end_dates, index(R))
  if (anyNA(row_of)) stop("Some holding_end_dates not found in R's index.")

  W <- coredata(weights_by_period)
  Rk <- coredata(R)[row_of, , drop = FALSE]

  period_port_return <- rowSums(W * Rk)
  G_prev <- c(1, cumprod(1 + period_port_return))[1:K]  # G_{k-1}, G_0 = 1

  contrib_matrix <- W * Rk * G_prev  # K x N
  total_contribution <- colSums(contrib_matrix)
  total_portfolio_return <- prod(1 + period_port_return) - 1

  data.frame(
    asset = assets,
    total_return_contribution = as.numeric(total_contribution),
    share_of_total_portfolio_return = as.numeric(total_contribution) / total_portfolio_return,
    total_portfolio_return = total_portfolio_return,
    stringsAsFactors = FALSE
  )
}

#' Ex-ante risk contribution (MCR/CR/PCR) at every rebalance date.
#'
#' @param R Full monthly return xts, same series used for estimation.
#' @param target_weights xts (K x N), one row per rebalance/signal date.
#' @param est_window Trailing estimation window (months) -- MUST match
#'   whatever was used to actually select target_weights, so the
#'   covariance matrix reconstructed here is the one that was actually in
#'   effect at that date.
#' @return data.frame, one row per (rebalance_date x asset), with
#'   weight, MCR, CR, PCR.
risk_contribution_series <- function(R, target_weights, est_window = 24) {
  dates <- index(R)
  assets <- colnames(R)
  signal_dates <- index(target_weights)
  row_of <- match(signal_dates, dates)
  if (anyNA(row_of)) stop("Some signal dates not found in R's index.")

  out <- vector("list", length(signal_dates))

  for (k in seq_along(signal_dates)) {
    i <- row_of[k]
    est_rows <- (i - est_window + 1):i
    Sigma <- cov(coredata(R)[est_rows, , drop = FALSE])
    w <- as.numeric(target_weights[k, ])

    sigma_p <- sqrt(as.numeric(t(w) %*% Sigma %*% w))
    MCR <- as.numeric((Sigma %*% w) / sigma_p)
    CR <- w * MCR
    PCR <- CR / sigma_p

    out[[k]] <- data.frame(
      rebalance_date = signal_dates[k],
      asset = assets,
      weight = w,
      MCR = MCR,
      CR = CR,
      PCR = PCR,
      stringsAsFactors = FALSE
    )
  }

  do.call(rbind, out)
}
