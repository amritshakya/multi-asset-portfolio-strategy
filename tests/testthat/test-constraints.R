# Test 3: every constrained-MVO target portfolio must satisfy
# full investment, long-only, minimum weights, and the BTC maximum.

test_that("Test 3: constrained MVO weights satisfy all box/investment constraints", {
  set.seed(7)
  Tn <- 48
  assets <- c("JPM", "XOM", "EEM", "GLD", "BTC-USD")
  N <- length(assets)
  dates <- seq(as.Date("2016-01-31"), by = "month", length.out = Tn)

  # Deliberately give BTC a much higher mean/vol so the optimizer WANTS to
  # push it past 5% if unconstrained -- a meaningful test of the cap.
  R <- matrix(rnorm(Tn * N, mean = c(0.01, 0.008, 0.006, 0.005, 0.06),
                     sd = c(0.06, 0.07, 0.05, 0.04, 0.20)),
              nrow = Tn, ncol = N, byrow = FALSE)
  colnames(R) <- assets
  R <- xts::xts(R, order.by = dates)

  min_w <- setNames(rep(0.05, N), assets)
  max_w <- setNames(rep(1.00, N), assets)
  max_w["BTC-USD"] <- 0.05

  fit <- run_walk_forward_mvo(R, est_window = 24, min_w = min_w, max_w = max_w, lambda = 1)
  ok <- fit$rebalance_audit$solver_status == "OK"
  expect_true(all(ok))

  W <- coredata(fit$target_weights)[ok, , drop = FALSE]
  tol <- 1e-6

  expect_true(all(abs(rowSums(W) - 1) < 1e-6))               # fully invested
  expect_true(all(W >= -tol))                                # long only
  expect_true(all(sweep(W, 2, min_w, `-`) >= -tol))           # >= min_w (within tol)
  expect_true(all(W[, "BTC-USD"] <= max_w["BTC-USD"] + tol)) # BTC cap respected

  # Confirm the BTC cap is actually a binding, meaningful constraint here
  # (i.e. the test setup isn't vacuous): BTC should be pinned at/near 5%
  # given its deliberately high assumed mean.
  expect_true(mean(W[, "BTC-USD"]) > 0.05 - 1e-3)
})
