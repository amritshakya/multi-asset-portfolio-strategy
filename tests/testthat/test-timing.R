# Test 1 (future-data invariance) and Test 2 (holding-period timing).
# These are the key anti-look-ahead tests for the whole project.

make_synthetic_returns <- function(Tn = 40, N = 3, seed = 42) {
  set.seed(seed)
  dates <- seq(as.Date("2016-01-31"), by = "month", length.out = Tn)
  R <- matrix(rnorm(Tn * N, mean = 0.01, sd = 0.05), nrow = Tn, ncol = N)
  colnames(R) <- paste0("A", 1:N)
  xts::xts(R, order.by = dates)
}

test_that("Test 1: changing a FUTURE return leaves earlier weights unchanged", {
  R <- make_synthetic_returns()
  est_window <- 12
  min_w <- rep(0, ncol(R))
  max_w <- rep(1, ncol(R))

  fit_before <- run_walk_forward_mvo(R, est_window = est_window, min_w = min_w, max_w = max_w)

  # Mutate a return that lies STRICTLY AFTER the estimation window used for
  # the earliest few signal dates (signal_idx starts at est_window = 12;
  # its estimation window is rows 1:12). Row 35 is far in the future
  # relative to that.
  R_mutated <- R
  R_mutated[35, 1] <- R_mutated[35, 1] + 5  # a large, obviously different shock

  fit_after <- run_walk_forward_mvo(R_mutated, est_window = est_window, min_w = min_w, max_w = max_w)

  # The first several signal dates' estimation windows (rows 1:12, 2:13, ...)
  # do not touch row 35 at all -> their target weights must be bit-for-bit
  # identical before and after the future mutation.
  unaffected_k <- 1:5  # signal_idx = 12..16, estimation windows end well before row 35
  w_before <- coredata(fit_before$target_weights)[unaffected_k, ]
  w_after <- coredata(fit_after$target_weights)[unaffected_k, ]

  expect_equal(w_before, w_after)

  # Sanity check the test is not vacuous: a LATER signal date whose
  # estimation window DOES include row 35 should actually change.
  # signal_idx = est_window - 1 + k (1-indexed k), so we need
  # estimation window (i-11):i to include row 35, e.g. i = 35 -> k = 35-11 = 24
  affected_k <- 24
  w_before_aff <- coredata(fit_before$target_weights)[affected_k, ]
  w_after_aff <- coredata(fit_after$target_weights)[affected_k, ]
  expect_false(isTRUE(all.equal(w_before_aff, w_after_aff)))
})

test_that("Test 2: a weight estimated through month t is applied ONLY to month t+1's return", {
  # Two assets, four months. Asset A always +50%, asset B always -50%.
  # Start with a target weight vector of 100% A at month-1's signal, and a
  # second target weight of 100% B established at month-3's signal.
  dates <- as.Date(c("2020-01-31", "2020-02-29", "2020-03-31", "2020-04-30"))
  R <- xts::xts(cbind(A = c(0.5, 0.5, 0.5, 0.5), B = c(-0.5, -0.5, -0.5, -0.5)),
                order.by = dates)

  target_weights <- xts::xts(
    rbind(c(A = 1, B = 0), c(A = 0, B = 1)),
    order.by = as.Date(c("2020-01-31", "2020-03-31"))
  )

  series <- compute_portfolio_series(R, target_weights, cost_rate = 0)

  # Row 1 of target_weights (100% A, dated Jan) must be applied to the
  # return dated Feb (the row immediately AFTER Jan in R) -- i.e. +50%,
  # NOT to Jan's own return.
  expect_equal(as.numeric(series$gross_return[1]), 0.5)
  expect_equal(as.character(series$dates[1]), "2020-02-29")

  # Row 2 of target_weights (100% B, dated Mar) must be applied to Apr's
  # return (-50%), not to Mar's own return.
  expect_equal(as.numeric(series$gross_return[2]), -0.5)
  expect_equal(as.character(series$dates[2]), "2020-04-30")

  # January's and March's OWN returns must never appear as gross_return
  # values anywhere in the series (they were used only to estimate/hold
  # into the weight, never to pay it off).
  expect_false(any(abs(as.numeric(series$gross_return) - 0.5) < 1e-12 &
                    as.character(series$dates) == "2020-01-31"))
})
