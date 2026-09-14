# scripts/run_stage1.R
#
# Stage 1 canonical pipeline: point-in-time, walk-forward reconstruction of
# the five-asset case study. Run from the repository root:
#
#   Rscript scripts/run_stage1.R
#
# Produces every table/figure under outputs/rebuilt/ and prints a summary
# to the console. Does not modify archive/original-final.Rmd,
# paper/final-paper.pdf, or code/portfolio-analysis.R.

repo_root <- getwd()
stopifnot(basename(repo_root) == "multi-asset-portfolio-strategy" || file.exists("R/data.R"))

source(file.path("R", "data.R"))
source(file.path("R", "returns.R"))
source(file.path("R", "optimizer.R"))
source(file.path("R", "backtest.R"))
source(file.path("R", "turnover.R"))
source(file.path("R", "metrics.R"))
source(file.path("R", "attribution.R"))
source(file.path("R", "plotting.R"))

TABLES_DIR <- file.path("outputs", "rebuilt", "tables")
FIGURES_DIR <- file.path("outputs", "rebuilt", "figures")
dir.create(TABLES_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(FIGURES_DIR, recursive = TRUE, showWarnings = FALSE)

cat("== Stage 1: point-in-time walk-forward reconstruction ==\n")

## 1. DATA -----------------------------------------------------------------
cat("\n[1/9] Loading (or caching) price data...\n")
loaded <- load_all_price_series(refresh = FALSE)
write_data_provenance(loaded$meta, file.path(TABLES_DIR, "data-provenance.csv"))
print(loaded$meta[, c("ticker", "requested_start", "requested_end",
                       "actual_first_observation", "actual_last_observation",
                       "n_observations")])

asset_prices <- loaded$prices[ASSET_TICKERS]
bench_prices <- loaded$prices[BENCHMARK_TICKERS]

## 2. MONTHLY RETURNS --------------------------------------------------------
cat("\n[2/9] Building monthly returns (own-calendar, no forward-fill)...\n")
R_assets <- build_monthly_returns(asset_prices)
R_bench <- build_monthly_returns(bench_prices)

cat("Asset monthly returns:", nrow(R_assets), "months,",
    format(index(R_assets)[1]), "to", format(index(R_assets)[nrow(R_assets)]), "\n")
cat("Benchmark monthly returns:", nrow(R_bench), "months,",
    format(index(R_bench)[1]), "to", format(index(R_bench)[nrow(R_bench)]), "\n")

## 3. WALK-FORWARD CONSTRAINED MVO ------------------------------------------
cat("\n[3/9] Running walk-forward constrained MVO...\n")

EST_WINDOW <- 24
assets <- colnames(R_assets)
min_w <- setNames(rep(0.05, length(assets)), assets)
max_w <- setNames(rep(1.00, length(assets)), assets)
max_w["BTC-USD"] <- 0.05
LAMBDA <- 1  # see R/optimizer.R for the objective-function diagnosis

mvo_fit <- run_walk_forward_mvo(R_assets, est_window = EST_WINDOW,
                                 min_w = min_w, max_w = max_w, lambda = LAMBDA)

write.csv(mvo_fit$rebalance_audit, file.path(TABLES_DIR, "rebalance-audit.csv"), row.names = FALSE)

if (nrow(mvo_fit$failures) > 0) {
  cat("WARNING:", nrow(mvo_fit$failures), "rebalance(s) failed to solve. See rebalance-audit.csv.\n")
} else {
  cat("All", nrow(mvo_fit$rebalance_audit), "walk-forward rebalances solved successfully.\n")
}

target_weights_df <- data.frame(date = index(mvo_fit$target_weights), coredata(mvo_fit$target_weights))
write.csv(target_weights_df, file.path(TABLES_DIR, "target-weights.csv"), row.names = FALSE)

## 4. COMPARISON PORTFOLIOS --------------------------------------------------
cat("\n[4/9] Building 1/N and no-rebalance comparison portfolios...\n")

signal_dates <- index(mvo_fit$target_weights)
naive_weights <- naive_1_over_n_weights(assets, signal_dates)

cost_rates <- c(bps0 = 0.0000, bps5 = 0.0005, bps10 = 0.0010, bps20 = 0.0020)

mvo_series <- lapply(cost_rates, function(cr) compute_portfolio_series(R_assets, mvo_fit$target_weights, cost_rate = cr))
naive_series <- lapply(cost_rates, function(cr) compute_portfolio_series(R_assets, naive_weights, cost_rate = cr))

pretrade_weights_df <- data.frame(date = index(mvo_series$bps0$pretrade_weights),
                                   coredata(mvo_series$bps0$pretrade_weights))
write.csv(pretrade_weights_df, file.path(TABLES_DIR, "pretrade-weights.csv"), row.names = FALSE)

# No-rebalance baseline: buy-and-hold from the FIRST MVO target weight,
# held (with zero trading) over the exact same sequence of holding periods.
initial_weights <- as.numeric(mvo_fit$target_weights[1, ])
names(initial_weights) <- assets
holding_end_dates <- mvo_series$bps0$dates
no_rebal <- no_rebalance_series(R_assets, initial_weights, holding_end_dates)

## 5. BENCHMARKS, ALIGNED TO THE SAME EVALUATED WINDOW -----------------------
cat("\n[5/9] Aligning external benchmarks to the evaluated window...\n")
bench_aligned <- R_bench[holding_end_dates]
if (nrow(bench_aligned) != length(holding_end_dates)) {
  warning("Benchmark series missing some evaluated dates -- check alignment.")
}

## 6. PERFORMANCE SUMMARY -----------------------------------------------------
cat("\n[6/9] Computing performance summary...\n")

perf_rows <- list(
  performance_summary(mvo_series$bps0$net_return, "Constrained MVO (gross, 0bps)"),
  performance_summary(mvo_series$bps5$net_return, "Constrained MVO (net, 5bps)"),
  performance_summary(mvo_series$bps10$net_return, "Constrained MVO (net, 10bps)"),
  performance_summary(mvo_series$bps20$net_return, "Constrained MVO (net, 20bps)"),
  performance_summary(naive_series$bps0$net_return, "Naive 1/N (gross, 0bps)"),
  performance_summary(naive_series$bps5$net_return, "Naive 1/N (net, 5bps)"),
  performance_summary(naive_series$bps10$net_return, "Naive 1/N (net, 10bps)"),
  performance_summary(naive_series$bps20$net_return, "Naive 1/N (net, 20bps)"),
  performance_summary(no_rebal$port_return, "No-Rebalance Baseline (buy-and-hold from initial MVO target)"),
  performance_summary(bench_aligned$SPY, "SPY"),
  performance_summary(bench_aligned$ACWI, "ACWI"),
  performance_summary(bench_aligned$AOR, "AOR")
)
performance_summary_df <- do.call(rbind, perf_rows)
write.csv(performance_summary_df, file.path(TABLES_DIR, "performance-summary.csv"), row.names = FALSE)
print(performance_summary_df[, c("portfolio", "cagr", "annualized_vol", "sharpe_ratio", "max_drawdown_monthly_sampled")])

## 7. TURNOVER, CONCENTRATION, CONSTRAINT BINDING -----------------------------
cat("\n[7/9] Turnover, concentration, and constraint-binding diagnostics...\n")

turnover_summary_df <- rbind(
  data.frame(portfolio = "Constrained MVO", summarize_turnover(mvo_series$bps0)),
  data.frame(portfolio = "Naive 1/N", summarize_turnover(naive_series$bps0))
)
write.csv(turnover_summary_df, file.path(TABLES_DIR, "turnover-summary.csv"), row.names = FALSE)
print(turnover_summary_df[, c("portfolio", "avg_monthly_one_way_turnover",
                               "max_monthly_one_way_turnover", "annualized_one_way_turnover_x12")])

W <- coredata(mvo_fit$target_weights)
max_w_per_rebalance <- apply(W, 1, max)
n_eff_per_rebalance <- 1 / rowSums(W^2)

concentration_summary_df <- data.frame(
  asset = c(assets, "ALL_ASSETS_MAX_SINGLE_WEIGHT", "N_EFF"),
  avg_target_weight = c(colMeans(W), mean(max_w_per_rebalance), mean(n_eff_per_rebalance)),
  max_target_weight = c(apply(W, 2, max), max(max_w_per_rebalance), max(n_eff_per_rebalance)),
  min_target_weight = c(apply(W, 2, min), min(max_w_per_rebalance), min(n_eff_per_rebalance)),
  median_target_weight = c(apply(W, 2, median), median(max_w_per_rebalance), median(n_eff_per_rebalance))
)
write.csv(concentration_summary_df, file.path(TABLES_DIR, "concentration-summary.csv"), row.names = FALSE)
cat("Mean effective N (1/sum(w^2)) across rebalances:", round(mean(n_eff_per_rebalance), 2),
    "| median:", round(median(n_eff_per_rebalance), 2),
    "| min:", round(min(n_eff_per_rebalance), 2), "(out of", length(assets), "assets)\n")

tol_at <- 1e-4
tol_near <- 0.005
constraint_binding_rows <- lapply(assets, function(a) {
  w <- W[, a]
  at_lower <- mean(abs(w - min_w[a]) < tol_at)
  near_lower <- mean(w <= (min_w[a] + tol_near))
  at_upper <- if (max_w[a] < 1) mean(abs(w - max_w[a]) < tol_at) else NA_real_
  near_upper <- if (max_w[a] < 1) mean(w >= (max_w[a] - tol_near)) else NA_real_
  data.frame(
    asset = a,
    lower_bound = min_w[a],
    upper_bound = max_w[a],
    pct_rebalances_at_lower_bound = at_lower,
    pct_rebalances_near_lower_bound = near_lower,
    pct_rebalances_at_upper_bound = at_upper,
    pct_rebalances_near_upper_bound = near_upper,
    avg_target_weight = mean(w),
    median_target_weight = median(w),
    max_target_weight = max(w)
  )
})
constraint_binding_df <- do.call(rbind, constraint_binding_rows)
constraint_binding_df$tolerance_at <- tol_at
constraint_binding_df$tolerance_near <- tol_near
write.csv(constraint_binding_df, file.path(TABLES_DIR, "constraint-binding.csv"), row.names = FALSE)
print(constraint_binding_df[, c("asset", "pct_rebalances_at_lower_bound", "pct_rebalances_at_upper_bound", "avg_target_weight")])

## 8. RETURN AND RISK CONTRIBUTION --------------------------------------------
cat("\n[8/9] Return and risk contribution by asset...\n")

return_contrib_df <- return_contribution(mvo_fit$target_weights, R_assets, holding_end_dates)
write.csv(return_contrib_df, file.path(TABLES_DIR, "return-contributions.csv"), row.names = FALSE)
print(return_contrib_df)

risk_contrib_df <- risk_contribution_series(R_assets, mvo_fit$target_weights, est_window = EST_WINDOW)
write.csv(risk_contrib_df, file.path(TABLES_DIR, "risk-contributions.csv"), row.names = FALSE)

risk_contrib_summary <- do.call(rbind, lapply(split(risk_contrib_df, risk_contrib_df$asset), function(d) {
  data.frame(asset = d$asset[1], mean_PCR = mean(d$PCR), median_PCR = median(d$PCR), max_PCR = max(d$PCR))
}))
write.csv(risk_contrib_summary, file.path(TABLES_DIR, "risk-contributions-summary.csv"), row.names = FALSE)
print(risk_contrib_summary)

## 9. FIGURES ------------------------------------------------------------------
cat("\n[9/9] Writing figures...\n")

return_list <- list(
  "Constrained MVO (net, 10bps)" = mvo_series$bps10$net_return,
  "Naive 1/N (net, 10bps)" = naive_series$bps10$net_return,
  "No-Rebalance Baseline" = no_rebal$port_return,
  "SPY" = bench_aligned$SPY,
  "ACWI" = bench_aligned$ACWI,
  "AOR" = bench_aligned$AOR
)

plot_equity_curves(return_list, file.path(FIGURES_DIR, "equity-curves.png"))
plot_drawdowns(return_list, file.path(FIGURES_DIR, "drawdowns.png"))
plot_weights_stacked(mvo_fit$target_weights, file.path(FIGURES_DIR, "target-weights.png"),
                     "Constrained MVO: Target Weights Through Time")
plot_weights_stacked(no_rebal$realized_weights, file.path(FIGURES_DIR, "realized-no-rebalance-weights.png"),
                     "No-Rebalance Baseline: Realized (Drifted) Weights Through Time")
plot_turnover(mvo_series$bps0$one_way_turnover, file.path(FIGURES_DIR, "turnover.png"),
              "Constrained MVO: One-Way Turnover per Rebalance")

cat("\nDone. Tables written to", TABLES_DIR, "\n")
cat("Figures written to", FIGURES_DIR, "\n")

# Save key objects for the final report / ad hoc inspection.
saveRDS(list(
  R_assets = R_assets, R_bench = R_bench,
  mvo_fit = mvo_fit, mvo_series = mvo_series, naive_series = naive_series,
  no_rebal = no_rebal, bench_aligned = bench_aligned,
  performance_summary_df = performance_summary_df,
  turnover_summary_df = turnover_summary_df,
  concentration_summary_df = concentration_summary_df,
  constraint_binding_df = constraint_binding_df,
  return_contrib_df = return_contrib_df,
  risk_contrib_summary = risk_contrib_summary
), file.path("outputs", "rebuilt", "stage1_run.rds"))
