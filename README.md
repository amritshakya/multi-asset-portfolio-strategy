# Multi-Asset Portfolio Strategy: A Methodology Case Study

## Project description

This repository is a case study in portfolio-construction methodology: a
five-asset universe (JPM, XOM, EEM, GLD, BTC-USD) is used to examine
estimation error in mean-variance optimization, look-ahead bias, portfolio
drift, constraints, turnover, transaction costs, and concentration, using a
point-in-time walk-forward implementation built and audited in this
repository. **It is not a fund and does not claim a proven, generalizable,
or investable strategy.**

## Why the project was rebuilt

The repository began as an academic portfolio project. A forensic audit
(`docs/methodology-audit.md`) found that its headline results were produced
by an optimizer evaluated on the same data it was trained on, and that the
resulting portfolio was never subsequently rebalanced — so its Bitcoin
allocation drifted from a stated 5% cap to roughly 68.5% of the book over
the sample, while every reported statistic (CAGR, drawdown, CAPM alpha, risk
budget) described that drifting, look-ahead-biased portfolio as if it were a
disciplined, constrained fund. Rather than patch the original numbers, the
project was rebuilt from scratch as a point-in-time, walk-forward
implementation ("Stage 1"), documented in `docs/rebuilt-methodology.md`.

## Research question / case-study framing

Stage 1 is a bounded empirical case study of:

- estimation error in sample-based mean-variance optimization,
- look-ahead bias and what a correct walk-forward evaluation changes,
- uncontrolled portfolio drift when a static allocation is never rebalanced,
- the practical effect of portfolio constraints,
- turnover and transaction costs,
- concentration, and
- constrained mean-variance optimization versus naive 1/N diversification —
  **in this one universe, over this one historical sample, with this one
  estimation specification.**

## Portfolio universe and constraints

**Assets:** JPM, XOM, EEM, GLD, BTC-USD. **Benchmarks:** SPY, ACWI, AOR.
These are retained unchanged from the original project so that Stage 1
audits and corrects the *methodology* applied to an already-fixed universe,
rather than redesigning the universe itself.

**Constrained MVO baseline:** long-only, fully invested, 5% minimum weight
per asset, 5% maximum weight on BTC, 24-month trailing estimation window,
monthly rebalance. Because BTC's floor equals its ceiling (5% = 5%), BTC is
not actually a free decision variable in this specification — it is fixed
by construction (see "Concentration and constraint-binding findings" below).

## Point-in-time methodology

Every walk-forward weight is estimated using only data observable through
its signal date, and applied only to the return realized in the
**following** month — never to the return used to estimate it. This timing
is implemented explicitly (not left to any package's implicit behavior) and
verified by dedicated tests, including a future-data-invariance test that
mutates a future return and confirms all earlier weights are unaffected.
Full detail — data sourcing/caching, the objective-function diagnosis, the
exact timing convention, constraint enforcement, turnover and
transaction-cost definitions — is in `docs/rebuilt-methodology.md`.

## Key Stage 1 results

Evaluated window: 95 monthly holding periods, 2018-02 through 2025-12.
Sharpe/Sortino use a 4.5% annual risk-free assumption converted to a
consistent monthly rate. Source: `outputs/rebuilt/tables/performance-summary.csv`.

| Portfolio | CAGR | Ann. Vol | Sharpe | Max DD (monthly) |
|---|---:|---:|---:|---:|
| Constrained MVO — gross | 19.1% | 19.6% | 0.77 | −15.8% |
| Constrained MVO — net, 10bps | 18.9% | 19.6% | 0.76 | −15.8% |
| Naive 1/N — gross | 19.6% | 21.1% | 0.75 | −25.7% |
| Naive 1/N — net, 10bps | 19.5% | 21.1% | 0.75 | −25.8% |
| No-rebalance baseline (buy-and-hold) | 17.2% | 24.1% | 0.60 | −39.0% |
| SPY | 13.6% | 16.5% | 0.59 | −23.9% |
| ACWI | 10.2% | 15.6% | 0.42 | −25.7% |
| AOR | 6.9% | 10.8% | 0.27 | −20.8% |

## MVO vs. 1/N interpretation

Reported exactly as pre-committed, regardless of outcome: naive 1/N produced
a very slightly *higher* raw CAGR than constrained MVO (19.6% vs. 19.1%
gross), while constrained MVO produced a materially smaller drawdown
(−15.8% vs. −25.7%) and a modestly higher Sharpe and Calmar ratio (1.21 vs.
0.76; `outputs/rebuilt/tables/performance-summary.csv`). **Neither method
dominates the other on every metric.** This is one five-asset universe, one
~8-year sample, one estimation specification — see "Research context" below
for why this cannot be generalized.

## Concentration and constraint-binding findings

Across the 95 rebalances (`outputs/rebuilt/tables/concentration-summary.csv`,
`constraint-binding.csv`): mean effective number of holdings
(`N_eff = 1/Σw_i²`) is **1.73** (median 1.54) out of 5 assets — the
"five-asset" portfolio behaves, on average, like it holds fewer than two
independent bets. EEM sits at its 5% floor in 97.9% of rebalances, XOM in
71.6%, GLD in 67.4%, JPM in 36.8%. JPM, XOM, and GLD each independently hit
the exact 80% corner solution (the maximum possible once the other four sit
at their floors) at different points in the sample, evidence of estimation
instability in a 24-observation covariance window. **BTC is at both its
floor and ceiling in 100% of rebalances** — its 5% allocation is a hardwired
constant in this specification, not an optimized outcome.

## No-rebalance drift finding

Starting from the identical initial target allocation as the constrained
MVO strategy but never trading again, the buy-and-hold portfolio's realized
risk degrades materially over the same 95 periods: annualized volatility
24.1% vs. 19.6%, and max drawdown −39.0% vs. −15.8%
(`outputs/rebuilt/tables/performance-summary.csv`). This isolates, at a
smaller and controlled scale, the exact drift mechanism that caused the
original project's BTC allocation to run from 5% to ~68.5% of the book.

## Repository structure

| Path | Contents |
|---|---|
| `docs/methodology-audit.md` | Forensic audit of the original project. |
| `docs/rebuilt-methodology.md` | Full Stage 1 methodology and limitations. |
| `R/`, `scripts/run_stage1.R` | Stage 1 implementation. |
| `tests/testthat/` | Timing, constraint, turnover, cost, and metric tests. |
| `outputs/rebuilt/tables/`, `outputs/rebuilt/figures/` | Stage 1 outputs. |
| `data/README.md`, `data/cache/` | Data sourcing notes; local download cache (not committed). |

**Project history (original academic project, preserved unmodified):**
`archive/original-final.Rmd`, `paper/final-paper.pdf`, and
`code/portfolio-analysis.R` are kept in the repository for reference only.
Their charts, allocations, and headline numbers (e.g. a 68.1% JPM weight, or
the CAPM/efficient-frontier/bootstrap-forecast exhibits in the PDF) describe
the **original, since-superseded implementation** and are not current
evidence — see `docs/methodology-audit.md` for why.

## Reproduction

```r
Rscript scripts/run_stage1.R                              # full pipeline
Rscript -e 'testthat::test_dir("tests/testthat")'          # test suite
```

Data downloads from Yahoo Finance on first run and is cached to
`data/cache/*.rds` (not committed) so later runs use a frozen local copy.
See `outputs/rebuilt/tables/data-provenance.csv` for source/date/timestamp
metadata from the most recent run. No `renv` lockfile is included yet.

## Limitations

Monthly-sampled drawdown/VaR/ES only (no daily NAV, likely understating true
intramonth risk for the BTC sleeve); a genuinely small 24-month covariance
estimation window (5 assets, 20 free parameters) that is measured as
unstable rather than corrected with shrinkage; a risk-aversion coefficient
(λ=1) inherited from the original project's undocumented package default,
not a calibrated choice; no dependency version pinning; a single universe,
single historical sample, and single estimation window. Full detail in
`docs/rebuilt-methodology.md`.

## Research context

DeMiguel, Garlappi, and Uppal (2009), *"Optimal Versus Naive
Diversification: How Inefficient is the 1/N Portfolio Strategy?"*, **The
Review of Financial Studies**, 22(5), 1915–1953, evaluated 14 optimized
portfolio-construction models across seven empirical datasets and found none
consistently better than naive 1/N out of sample, in Sharpe ratio,
certainty-equivalent return, or turnover — concluding that estimation error
typically offsets optimization's theoretical gains. This repository's single
five-asset, one-window comparison is one additional data point consistent
with that documented problem, not a replication of its scope.

## Future work

Not part of this repository, and not started: broader asset-class sleeves,
risk-parity construction, longer-history robustness checks, regime analysis,
factor attribution, covariance shrinkage, daily-NAV drawdown measurement,
and `renv` dependency pinning. Any such "Version 2" work requires a written
scope document (research question, universe, data, methodology,
deliverables, estimated work) before implementation begins.

## Disclaimer

This project is for academic and portfolio-methodology purposes only.
Nothing here is investment advice, a recommendation to buy or sell any
security, or a live or investable track record.
