# Test 5: minimal hand-calculable checks on CAGR, Sharpe, and max drawdown
# to catch unit/annualization mistakes (not an exhaustive metrics suite).

test_that("Test 5: CAGR matches hand calculation", {
  # 12 months of a flat 1% monthly return.
  R <- rep(0.01, 12)
  expected <- (1.01)^12 - 1
  expect_equal(cagr(R), expected, tolerance = 1e-10)
})

test_that("Test 5: Sharpe ratio uses the documented monthly-excess-return formulation", {
  R <- c(0.02, -0.01, 0.03, 0.00, 0.01, -0.02)
  rf_annual <- 0.045
  rf_m <- (1 + rf_annual)^(1 / 12) - 1
  excess <- R - rf_m
  expected <- mean(excess) / sd(excess) * sqrt(12)
  expect_equal(sharpe_ratio(R, rf_annual), expected, tolerance = 1e-10)

  # The CAGR of R must NEVER appear in the Sharpe numerator (guard against
  # methodology-audit finding M3 recurring).
  bad_numerator <- cagr(R) - rf_annual
  expect_false(isTRUE(all.equal(sharpe_ratio(R, rf_annual), bad_numerator / (sd(R) * sqrt(12)))))
})

test_that("Test 5: max drawdown matches a hand-built example", {
  # Wealth path: 1 -> 1.10 -> 0.99 -> 1.05
  # Returns:        +10%    -10%     +6.0606...%
  R <- c(0.10, -0.10, 1.05 / 0.99 - 1)
  wealth <- cumprod(1 + R)
  expect_equal(wealth, c(1.10, 0.99, 1.05), tolerance = 1e-8)

  # Peak is 1.10 after month 1; trough is 0.99 after month 2.
  expected_mdd <- 0.99 / 1.10 - 1
  expect_equal(max_drawdown(R), expected_mdd, tolerance = 1e-10)
})
