# Test 6: transaction cost = cost_rate * gross_traded_notional, and net
# performance reconciles with gross performance minus that cost.

test_that("Test 6: transaction cost is deducted exactly as cost_rate x gross_traded_notional", {
  dates <- as.Date(c("2020-01-31", "2020-02-29"))
  R <- xts::xts(cbind(A = c(0, 0.20), B = c(0, 0.00)), order.by = dates)

  target_weights <- xts::xts(rbind(c(A = 0.5, B = 0.5)), order.by = as.Date("2020-01-31"))
  cost_rate <- 0.0010  # 10 bps

  gross_series <- compute_portfolio_series(R, target_weights, cost_rate = 0)
  net_series <- compute_portfolio_series(R, target_weights, cost_rate = cost_rate)

  # Initial funding trade: pretrade = (0,0), target = (0.5, 0.5)
  # gross_traded_notional = |0.5-0| + |0.5-0| = 1.0
  expect_equal(as.numeric(net_series$gross_traded_notional[1]), 1.0, tolerance = 1e-10)

  expected_cost <- cost_rate * 1.0
  expect_equal(as.numeric(net_series$cost[1]), expected_cost, tolerance = 1e-10)

  # gross_return must be IDENTICAL whether or not a cost is charged.
  expect_equal(as.numeric(gross_series$gross_return), as.numeric(net_series$gross_return))

  # net_return must equal gross_return - cost, exactly.
  expect_equal(
    as.numeric(net_series$net_return[1]),
    as.numeric(net_series$gross_return[1]) - expected_cost,
    tolerance = 1e-10
  )

  # Zero cost_rate must reconcile net == gross exactly.
  expect_equal(as.numeric(gross_series$net_return), as.numeric(gross_series$gross_return))

  # Higher cost rate must never produce HIGHER net return, all else equal.
  net_series_high <- compute_portfolio_series(R, target_weights, cost_rate = 0.01)
  expect_true(as.numeric(net_series_high$net_return[1]) <= as.numeric(net_series$net_return[1]))
})
