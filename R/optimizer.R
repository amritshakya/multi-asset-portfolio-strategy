# R/optimizer.R
#
# Canonical constrained mean-variance optimizer for Stage 1.
#
# --- OBJECTIVE FUNCTION DIAGNOSIS (see docs/rebuilt-methodology.md sec. 6) ---
#
# The original project called, via PortfolioAnalytics::optimize.portfolio()
# with optimize_method = "ROI":
#
#     add.objective(pspec, type = "return", name = "mean")
#     add.objective(pspec, type = "risk",   name = "StdDev")
#
# Inspecting the installed PortfolioAnalytics source directly
# (PortfolioAnalytics:::gmv_opt and the dispatch logic inside
# PortfolioAnalytics:::optimize.portfolio) shows this combination is
# resolved into a single quadratic program:
#
#     ROI::Q_objective(Q = 2 * lambda * moments$var, L = -moments$mean)
#
# i.e. the solver minimizes   lambda * w'Sigma w  -  w'mu
# which is equivalent to      maximize  w'mu - lambda * w'Sigma w
#
# a textbook mean-variance utility with risk-aversion coefficient `lambda`.
# Critically, `lambda` is initialized in optimize.portfolio() as:
#
#     lambda <- 1
#     lambda <- ifelse(!is.null(objective$risk_aversion), objective$risk_aversion, lambda)
#
# The original code never supplied `risk_aversion` to add.objective(), so
# `lambda` silently defaulted to 1. Additionally, because no `target` was
# supplied to the "mean" objective, the return objective's target constraint
# degenerates to a no-op (0 == 0) inside gmv_opt(), confirming the mean
# term enters ONLY as the linear term of the QP, not as a fixed target.
#
# CONCLUSION: the original objective *can* be faithfully reconstructed
# outside PortfolioAnalytics's opaque defaults. It is exactly:
#
#     maximize   w'mu - w'Sigma w      (i.e. risk aversion lambda = 1)
#     subject to fully-invested, long-only, box constraints
#
# We reimplement this directly with quadprog::solve.QP() below: same
# mathematical program, same lambda = 1, but fully transparent and with
# zero dependency on PortfolioAnalytics/ROI internals. lambda = 1 is
# reproduced for continuity with the historical project's revealed
# behavior -- it was never a deliberately chosen risk-aversion coefficient
# in the original work, and we do not tune it here either. This is
# documented as a limitation (docs/rebuilt-methodology.md).

suppressMessages(library(quadprog))

#' Solve the constrained mean-variance QP:
#'   maximize  w'mu - lambda * w'Sigma w
#'   s.t.      sum(w) == 1
#'             w_i >= min_w[i]  for all i
#'             w_i <= max_w[i]  for all i
#'
#' @param mu Numeric vector of expected (mean) returns, length N.
#' @param Sigma N x N covariance matrix.
#' @param min_w Numeric vector, per-asset lower bound (length N).
#' @param max_w Numeric vector, per-asset upper bound (length N).
#' @param lambda Risk-aversion coefficient. Default 1, reproducing the
#'   original project's undocumented PortfolioAnalytics default. Must not
#'   be tuned against backtest performance (Stage 1 scope lock).
#' @return list(weights = named numeric vector, status = solver status,
#'   objective_value = numeric or NA on failure)
solve_constrained_mvo <- function(mu, Sigma, min_w, max_w, lambda = 1) {
  N <- length(mu)
  stopifnot(nrow(Sigma) == N, ncol(Sigma) == N,
            length(min_w) == N, length(max_w) == N)

  Dmat <- 2 * lambda * Sigma
  # quadprog requires Dmat to be (numerically) positive definite.
  # A trailing covariance estimated from a short window can be only
  # positive semi-definite due to floating point noise; nudge the
  # diagonal by a tiny amount only if needed, and record that this
  # happened (estimation instability is something to measure, not hide).
  jitter <- 0
  eig_min <- tryCatch(min(eigen(Dmat, symmetric = TRUE, only.values = TRUE)$values),
                       error = function(e) NA_real_)
  if (!is.na(eig_min) && eig_min <= 1e-10) {
    jitter <- (1e-8 - eig_min)
    Dmat <- Dmat + diag(jitter, N)
  }

  dvec <- mu

  Amat <- cbind(
    rep(1, N),      # full investment (equality)
    diag(N),        # w_i >= min_w[i]
    -diag(N)        # -w_i >= -max_w[i]  <=>  w_i <= max_w[i]
  )
  bvec <- c(1, min_w, -max_w)
  meq <- 1

  result <- tryCatch(
    quadprog::solve.QP(Dmat = Dmat, dvec = dvec, Amat = Amat, bvec = bvec, meq = meq),
    error = function(e) e
  )

  if (inherits(result, "error")) {
    return(list(
      weights = setNames(rep(NA_real_, N), names(mu)),
      status = paste("FAILED:", conditionMessage(result)),
      objective_value = NA_real_,
      jitter_applied = jitter
    ))
  }

  w <- setNames(result$solution, names(mu))

  list(
    weights = w,
    status = "OK",
    objective_value = -result$value,  # solve.QP returns 0.5 w'Dw - d'w minimized; negate for "maximize mu'w - lambda w'Sw" convention
    jitter_applied = jitter
  )
}
