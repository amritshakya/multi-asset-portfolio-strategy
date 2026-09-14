# Rebuilt Methodology (Stage 1)

This document describes the **Stage 1** reconstruction of the five-asset
portfolio case study: a point-in-time, walk-forward implementation built to
address the failures recorded in [`docs/methodology-audit.md`](methodology-audit.md).

## Research framing

This is **not** a claim that constrained mean-variance optimization
outperforms naive diversification, or that either approach "works" as a
general strategy. It is a bounded empirical case study of:

- estimation error in sample-based mean-variance optimization,
- look-ahead bias and what a proper walk-forward evaluation changes,
- uncontrolled portfolio drift when a static allocation is never rebalanced,
- the practical role of portfolio constraints,
- turnover and transaction costs,
- concentration, and
- constrained MVO vs. naive 1/N diversification, **in this one universe over
  this one historical sample** — see [`docs/rebuilt-methodology.md#research-context`](#research-context) below and the final report for why this
  cannot be generalized.

## 1. Investment universe

Assets: **JPM, XOM, EEM, GLD, BTC-USD**. Benchmarks: **SPY, ACWI, AOR**.

These are retained from the original project deliberately, **not** because
they represent a considered asset-allocation universe. The point of Stage 1
is to audit and correctly re-implement the *methodology* applied to an
already-fixed universe, not to redesign the universe. A cross-asset class
mix that includes a single-name growth stock (JPM), a single-name energy
stock (XOM), an EM equity ETF, a commodity ETF, and a highly volatile crypto
asset is exactly the kind of small, high-variance, low-observation-count
universe where estimation error and constraint interactions are easiest to
see and explain — which suits a methodology case study, even though it would
not suit an actual diversified allocation.

## 2. Data

- **Source:** Yahoo Finance via `quantmod::getSymbols()`.
- **Frozen window:** requested `2016-01-01` through `2025-12-31`. `Sys.Date()`
  is never used anywhere in the Stage 1 code.
- **Price convention:** adjusted close (`quantmod::Ad()`) — dividend- and
  split-adjusted.
- **Caching:** every ticker's raw download is cached to `data/cache/*.rds` on
  first run, with a recorded download timestamp, so re-running the pipeline
  during development cannot silently change the historical sample (Yahoo's
  adjusted-close history can itself be revised after the fact). Delete a
  cache file and re-run to force a fresh download.
- **Provenance table:** `outputs/rebuilt/tables/data-provenance.csv` records,
  per ticker: source, requested start/end, actual first/last observation,
  number of observations, download timestamp, and price convention.

## 3. Monthly return construction (fixing methodology-audit finding M6)

Each asset's daily adjusted-price series is collapsed to monthly **on its own
trading calendar** (`to.monthly(..., indexAt = "lastof")` applied per-asset,
*before* any merge). Only after each asset has its own independent monthly
series are they merged and aligned by calendar-month label.

This is the direct fix for the audit finding that merging BTC's 7-day
calendar with equities' 5-day calendar *before* resampling silently
reconciles both down to the last row with **no missing values across any
column** — i.e., BTC's true month-end price would be discarded whenever a
month ends on a weekend. Doing the monthly collapse per-asset first removes
that failure mode entirely.

No forward-filling is applied anywhere. If an asset lacks an observation in
a given calendar month, that month is `NA` for that column and the entire
row is dropped by `na.omit()` at the return-matrix stage (2 months were
dropped for the asset universe, 1 for the benchmark universe, out of 119
calendar months in the frozen window — see console output of
`scripts/run_stage1.R`).

**Limitation, explicitly deferred:** all metrics in Stage 1 (drawdown
included) are computed on **monthly-sampled** returns. This will understate
true intra-month drawdown, particularly for the BTC sleeve. A daily-NAV /
BTC-weekend-calendar system was intentionally **not** built in Stage 1 (per
scope). It should only be built later if the clean monthly-rebalanced
results in this stage give a substantive reason to (e.g. if monthly-sampled
drawdown looks materially inconsistent with known market history).

## 4. Walk-forward timing

Explicit, hand-rolled, and independently tested (see `tests/testthat/test-timing.R`).
No package's implicit weight-timing behavior is relied upon.

At signal index `i` (using monthly return matrix `R`, row `i` dated
`dates[i]`, holding the return earned **from** `dates[i-1]` **to** `dates[i]`):

1. **Estimation window:** rows `(i - 23):i` — i.e. the trailing 24 months
   *through and including* `dates[i]`.
2. **Signal / rebalance date:** `dates[i]` — weights are decided using only
   information available as of this date.
3. **Holding period:** `dates[i]` to `dates[i+1]`. The new target weight is
   applied **only** to `R[i+1, ]`, the return realized strictly after the
   weight was set.

A newly estimated weight never receives the return used to estimate it. This
is verified by two dedicated tests:

- **Future-data invariance** (`test-timing.R`): mutating a return far in the
  future leaves every earlier signal date's target weight bit-for-bit
  unchanged; a later signal date whose estimation window *does* include the
  mutated row is confirmed to actually change (so the test is not vacuous).
- **Holding-period timing** (`test-timing.R`): a hand-built two-asset,
  four-month example confirms a weight set at month `t` earns month `t+1`'s
  return and never month `t`'s own return.

The full audit trail is written to `outputs/rebuilt/tables/rebalance-audit.csv`
with columns `estimation_start, estimation_end, signal_date, rebalance_date,
holding_period_start, holding_period_end, n_estimation_obs, solver_status`.

## 5. Baseline specification

- Long-only, fully invested.
- Minimum weight 5% per asset.
- BTC maximum target weight 5%.
- Trailing estimation window: 24 months (unchanged from the original
  project; not tuned in Stage 1).
- Monthly rebalance.

Note: because BTC's floor (5%) equals its ceiling (5%), **BTC's target
weight is not actually a free decision variable in this specification** —
it is mechanically fixed at exactly 5% every rebalance, by construction of
the box constraints inherited unchanged from the original project. This is
documented plainly in `outputs/rebuilt/tables/constraint-binding.csv` (BTC
is "at both bounds" 100% of rebalances) and is not something Stage 1 tunes
away, per the scope lock.

## 6. Objective function diagnosis

The original code called, via `PortfolioAnalytics::optimize.portfolio()`
with `optimize_method = "ROI"`:

```r
add.objective(pspec, type = "return", name = "mean")
add.objective(pspec, type = "risk",   name = "StdDev")
```

**What we found by reading the installed PortfolioAnalytics source directly**
(`PortfolioAnalytics:::gmv_opt` and the dispatch logic inside
`PortfolioAnalytics:::optimize.portfolio`, not assumed from documentation):
this combination is resolved into a single quadratic program via
`ROI::Q_objective(Q = 2 * lambda * moments$var, L = -moments$mean)`, i.e. the
solver minimizes

```
lambda * w'Sigma w  -  w'mu
```

which is equivalent to a standard mean-variance utility maximization,
`maximize  w'mu - lambda * w'Sigma w`. Critically, `optimize.portfolio()`
initializes `lambda <- 1` and only overrides it if the objective explicitly
supplies a `risk_aversion` parameter — which the original code never did.
So **the risk-aversion coefficient actually driving every allocation in the
original project was a silent package default of 1**, never a deliberate or
disclosed modeling choice. We additionally confirmed that because no
`target` was supplied to the "mean" objective, its would-be target-return
constraint degenerates to a no-op (`0 == 0`) inside `gmv_opt()`, confirming
the mean term enters only as the QP's linear coefficient, not as a fixed
target return.

**Conclusion:** the original objective *can* be faithfully reconstructed
outside PortfolioAnalytics's opaque defaults. Stage 1 reimplements it
directly with `quadprog::solve.QP()` (see `R/optimizer.R`): the exact same
mathematical program, `lambda = 1` made **explicit** rather than an
undocumented default, and zero remaining dependency on PortfolioAnalytics or
ROI internals for the canonical optimizer.

`lambda = 1` is retained **for continuity with the historical project's
revealed behavior**, not because it is a principled or calibrated
risk-aversion coefficient — it is not, and this is a documented limitation.
It was **not** tuned against backtest performance, in either the original
project or here.

## 7. Portfolio comparisons

Four portfolios are constructed and compared over the identical evaluated
window (`outputs/rebuilt/tables/rebalance-audit.csv`'s 95 holding periods,
2018-02 through 2025-12):

- **A. Walk-forward constrained MVO** — the canonical strategy above,
  monthly rebalanced to a freshly estimated target every period.
- **B. Naive 1/N** — same five assets, 20% each, monthly rebalanced, same
  cost convention. Constructed on the *same* signal dates as A for a direct,
  apples-to-apples comparison.
- **C. No-rebalance baseline** — buy-and-hold starting from A's *first*
  target weight vector, never rebalanced again. Its purpose is narrow and
  specific: isolate and quantify the drift mechanism that caused the
  original project's failure (methodology-audit finding #2/#3). Its realized
  weights are tracked and charted (`outputs/rebuilt/figures/realized-no-rebalance-weights.png`);
  it is **not** described anywhere as an investable constrained strategy once
  its weights drift outside the original box constraints.
- **D. External benchmarks** — SPY, ACWI, AOR, aligned to the same 95
  evaluated holding periods.

## 8. Constraint enforcement

Every constrained-MVO rebalance is checked (`tests/testthat/test-constraints.R`)
for: `sum(weights) ≈ 1`, all weights `≥ 5%` (within `1e-6` tolerance), BTC
`≤ 5%`, and non-negativity. Target weights, pre-trade drifted weights, and
post-trade (= target) weights are stored as **distinct** objects throughout
(`outputs/rebuilt/tables/target-weights.csv` vs. `pretrade-weights.csv`) —
they are never conflated.

## 9. Turnover

```
gross_traded_notional_t = sum(abs(target_weight_t - pretrade_weight_t))
one_way_turnover_t      = 0.5 * gross_traded_notional_t
```

where `pretrade_weight_t` is the weight the portfolio actually **drifted
to** since the last trade (via compounding the previous target weight
through the realized return of its holding period) — never a simple
target-to-target difference. See `R/backtest.R::drift_weights()` and the
hand-verified example in `tests/testthat/test-turnover.R`.

The very first rebalance is a one-time "initial funding trade" (from a zero
/ no-position state into the first target) and is reported separately; all
steady-state summary statistics in `outputs/rebuilt/tables/turnover-summary.csv`
exclude it (documented in that file's `annualization_convention` column).

## 10. Transaction costs

```
cost_t = cost_rate * gross_traded_notional_t
```

Evaluated at 0, 5, 10, and 20 bps for both constrained MVO and 1/N. Cost is
charged per dollar traded (not per dollar held), deducted as a one-time drag
on the return of the holding period immediately following the trade that
generated it:

```
net_return_t = gross_return_t - cost_t
```

Verified in `tests/testthat/test-costs.R`. Portfolio construction was **not**
altered in response to the resulting cost sensitivity, per the scope lock.

## 11. Metrics

CAGR (geometric), annualized arithmetic mean, annualized volatility,
Sharpe, Sortino, monthly-sampled max drawdown, Calmar, monthly VaR(95%),
monthly ES(95%), best/worst month, positive-month hit rate. All formulas are
in `R/metrics.R` with inline documentation. Sharpe ratio uses the
explicitly-specified consistent monthly excess-return formulation:

```
Sharpe_annualized = mean(Rp - Rf_monthly) / sd(Rp - Rf_monthly) * sqrt(12)
```

`Rf_monthly = (1 + 0.045)^(1/12) - 1`, applied consistently everywhere — the
annual/monthly risk-free unit bug from the archived report (methodology-audit
finding #4) cannot recur because there is only one risk-free conversion
function in the codebase (`rf_monthly_rate()`), used by both Sharpe and
Sortino. CAPM is out of scope for Stage 1.

## 12. Concentration diagnostics

For the constrained-MVO strategy, computed over all 95 rebalances
(`outputs/rebuilt/tables/concentration-summary.csv`):

- Average/max/min target weight by asset.
- The maximum single-asset target weight *at every rebalance*, then
  averaged and maxed across rebalances.
- Effective number of holdings, `N_eff = 1 / sum(w_i^2)`, per rebalance;
  mean/median/min reported.

## 12B. Constraint-binding diagnostics

For each asset (`outputs/rebuilt/tables/constraint-binding.csv`): percentage
of rebalances at/near its lower bound (tolerance `1e-4` for "at", `0.005`
for "near"), percentage at/near its applicable upper bound, and average /
median / max target weight.

## 13. Return and risk contribution

- **Return contribution:** an exact multi-period decomposition — each
  period's per-asset dollar P&L is scaled by the cumulative portfolio growth
  up to the start of that period, so the per-asset contributions sum exactly
  to the total compounded portfolio return (see `R/attribution.R` for the
  proof). Reported once over the full evaluated window
  (`outputs/rebuilt/tables/return-contributions.csv`).
- **Risk contribution (MCR/CR/PCR):** computed **at every rebalance**, using
  the trailing covariance matrix actually in effect at that date and that
  date's target weights (`outputs/rebuilt/tables/risk-contributions.csv`,
  summarized in `risk-contributions-summary.csv`). This is deliberately a
  time series, not a single static table — the original project's failure
  (finding #5) was presenting one point-in-time risk-budget snapshot as if
  it described the whole strategy.

## Research context

DeMiguel, Garlappi, and Uppal (2009), *"Optimal Versus Naive Diversification:
How Inefficient is the 1/N Portfolio Strategy?"*, **The Review of Financial
Studies**, 22(5), 1915–1953, evaluated 14 optimized portfolio-construction
models across seven empirical datasets and found that none was consistently
better than the naive 1/N rule out of sample, in Sharpe ratio,
certainty-equivalent return, or turnover — concluding that estimation error
typically offsets the theoretical gains from optimization. (Verified via
Oxford Academic / SSRN listings before citing.)

This Stage 1 comparison of constrained MVO vs. 1/N on five assets over one
~8-year evaluated window is a **single additional data point**, not a
replication of that study's breadth (different universe, single estimation
specification, single historical path). It is presented here to contextualize
our result as an instance of a documented, general estimation-error problem
— not to claim our five-asset test establishes anything beyond itself.

## Limitations (Stage 1)

- Monthly-sampled drawdown/VaR/ES (no daily NAV) — likely understates true
  peak-to-trough risk, especially for the BTC sleeve.
- 24-month trailing covariance estimation from 5 assets is a genuinely
  small-sample problem (20 free covariance/mean parameters from 24
  observations); the resulting instability is measured (see
  `constraint-binding.csv` and the corner-solution pattern in
  `outputs/rebuilt/figures/target-weights.png`), not corrected with
  shrinkage in Stage 1.
- `lambda = 1` is inherited for continuity, not derived from any utility
  calibration.
- No package/version pinning (no `renv.lock`); Yahoo's adjusted-close
  history can itself be revised retroactively, so bit-for-bit reproducibility
  years from now is not guaranteed even with identical code.
- BTC's 5%-floor-equals-5%-ceiling means it is not truly an optimized
  decision variable in this specification (see section 5).
- Single universe, single historical sample, single estimation window —
  results here should not be generalized (see Research context above and
  the final report's adversarial assessment).

## Future work (explicitly out of Stage 1 scope)

- Broad asset-class sleeves / strategic multi-asset allocation.
- Risk-balanced (risk-parity) construction.
- Longer-history robustness checks.
- Regime analysis / regime classification / tactical allocation.
- Factor attribution (Fama-French or otherwise).
- Covariance shrinkage.
- Daily-NAV / intramonth drawdown measurement.
- `renv` dependency pinning.

None of the above should begin without a written scope document (research
question, universe, data, methodology, deliverables, estimated work) —
see the final report for the explicit hard stop.
