# Test 4: turnover on a tiny synthetic example with hand-known values.

test_that("Test 4: turnover matches a hand calculation", {
  # Two rebalances, two assets.
  # Rebalance 1 (Jan): target = (0.6, 0.4). No prior position -> pretrade = (0,0).
  #   gross_traded_notional = |0.6-0| + |0.4-0| = 1.0
  #   one_way_turnover = 0.5
  # Holding period Jan->Feb return: A=+10%, B=-10%.
  #   end-of-period value: A: 0.6*1.10=0.66, B: 0.4*0.90=0.36, total=1.02
  #   pretrade weight at Feb rebalance: A=0.66/1.02=0.647058824, B=0.36/1.02=0.352941176
  # Rebalance 2 (Feb): target = (0.5, 0.5).
  #   gross_traded_notional = |0.5-0.647058824| + |0.5-0.352941176|
  #                         = 0.147058824 + 0.147058824 = 0.294117647
  #   one_way_turnover = 0.147058824

  dates <- as.Date(c("2020-01-31", "2020-02-29", "2020-03-31"))
  R <- xts::xts(cbind(A = c(0, 0.10, 0.03), B = c(0, -0.10, 0.01)), order.by = dates)

  target_weights <- xts::xts(
    rbind(c(A = 0.6, B = 0.4), c(A = 0.5, B = 0.5)),
    order.by = as.Date(c("2020-01-31", "2020-02-29"))
  )

  series <- compute_portfolio_series(R, target_weights, cost_rate = 0)

  expect_equal(as.numeric(series$gross_traded_notional[1]), 1.0, tolerance = 1e-8)
  expect_equal(as.numeric(series$one_way_turnover[1]), 0.5, tolerance = 1e-8)

  expected_pretrade_A <- 0.66 / 1.02
  expected_pretrade_B <- 0.36 / 1.02
  expect_equal(as.numeric(series$pretrade_weights[2, "A"]), expected_pretrade_A, tolerance = 1e-8)
  expect_equal(as.numeric(series$pretrade_weights[2, "B"]), expected_pretrade_B, tolerance = 1e-8)

  expected_gtn2 <- abs(0.5 - expected_pretrade_A) + abs(0.5 - expected_pretrade_B)
  expect_equal(as.numeric(series$gross_traded_notional[2]), expected_gtn2, tolerance = 1e-8)
  expect_equal(as.numeric(series$one_way_turnover[2]), 0.5 * expected_gtn2, tolerance = 1e-8)

  # drift_weights() unit-level check directly
  dw <- drift_weights(c(A = 0.6, B = 0.4), c(0.10, -0.10))
  expect_equal(as.numeric(dw), c(expected_pretrade_A, expected_pretrade_B), tolerance = 1e-8)
})
