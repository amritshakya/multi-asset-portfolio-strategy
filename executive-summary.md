# Executive Summary — Stage 1 Rebuild

## Purpose

This repository is a case study in portfolio-construction methodology,
built on a five-asset universe (JPM, XOM, EEM, GLD, BTC-USD): estimation
error in mean-variance optimization, look-ahead bias, portfolio drift,
constraints, turnover, transaction costs, and concentration, evaluated
through a point-in-time walk-forward implementation. It is not a fund and
does not claim a proven or generalizable strategy.

## What was wrong with the original project

A forensic audit found the original project's headline results (a 33.2%
CAGR, 59.8% max drawdown) came from an optimizer evaluated on the same data
it was trained on, held in a portfolio that was never subsequently
rebalanced — so its Bitcoin allocation drifted from a stated 5% cap to
roughly 68.5% of the book, while every reported statistic described that
drifting position as if it were the disciplined, constrained fund it was
supposed to be. Full detail in `docs/methodology-audit.md`.

## Current methodology

Weights are estimated from a trailing 24-month window and applied only to
the following month's return — never to a return used in estimation — with
timing enforced explicitly and verified by tests. Four portfolios are
compared over an identical 95-month evaluated window (2018-02–2025-12):
constrained mean-variance optimization (long-only, fully invested, 5%
minimum per asset, 5% BTC cap, monthly rebalance), naive 1/N (same
universe, monthly rebalanced), a no-rebalance buy-and-hold baseline, and
external benchmarks (SPY, ACWI, AOR). Full detail in
`docs/rebuilt-methodology.md`.

## Key performance comparison

(Source: `outputs/rebuilt/tables/performance-summary.csv`)

| Portfolio | CAGR | Ann. Vol | Sharpe | Max DD (monthly) |
|---|---:|---:|---:|---:|
| Constrained MVO — gross | 19.1% | 19.6% | 0.77 | −15.8% |
| Naive 1/N — gross | 19.6% | 21.1% | 0.75 | −25.7% |
| No-rebalance baseline | 17.2% | 24.1% | 0.60 | −39.0% |
| SPY | 13.6% | 16.5% | 0.59 | −23.9% |
| ACWI | 10.2% | 15.6% | 0.42 | −25.7% |
| AOR | 6.9% | 10.8% | 0.27 | −20.8% |

## MVO vs. 1/N result

Naive 1/N had a slightly higher raw CAGR than constrained MVO in this
sample; constrained MVO had a materially smaller drawdown and a modestly
higher Sharpe and Calmar ratio. Neither dominates the other. This is
reported exactly as pre-committed regardless of outcome, and is one
five-asset universe over one ~8-year sample — not evidence that either
method is generally superior (see "Research context" in
`docs/rebuilt-methodology.md` and `README.md`).

## Concentration finding

Across the 95 rebalances, mean effective number of holdings
(`N_eff = 1/Σw_i²`) is 1.73 (median 1.54) out of 5 assets. JPM, XOM, and GLD
each independently hit an 80% corner-solution weight at different points in
the sample, and BTC's target weight is pinned at exactly 5% in 100% of
rebalances by construction of its box constraint (floor = ceiling = 5%), not
as an optimized outcome. (Source: `outputs/rebuilt/tables/concentration-summary.csv`,
`constraint-binding.csv`.)

## Turnover / cost finding

Constrained MVO averages 7.8% one-way monthly turnover versus 3.0% for
naive 1/N. At transaction-cost assumptions of 5, 10, and 20 bps per dollar
traded, constrained MVO's CAGR falls from 19.1% (gross) to 18.7% (20bps);
naive 1/N's falls from 19.6% to 19.4% over the same cost range — costs
compress but do not reverse either portfolio's ranking. (Source:
`outputs/rebuilt/tables/turnover-summary.csv`, `performance-summary.csv`.)

## No-rebalance drift result

Starting from the same initial allocation as the constrained MVO strategy
but never trading again, realized volatility rises from 19.6% to 24.1% and
max drawdown worsens from −15.8% to −39.0% over the identical 95 periods —
isolating, at a controlled scale, the drift mechanism behind the original
project's BTC allocation running from 5% to ~68.5% of the book. (Source:
`outputs/rebuilt/tables/performance-summary.csv`.)

## Limitations

Monthly-sampled drawdown/VaR/ES only (no daily NAV); a genuinely small
24-month covariance estimation window that produces measured instability
rather than being corrected with shrinkage; a risk-aversion coefficient
(λ=1) inherited from the original project's undocumented package default
rather than calibrated; no dependency version pinning; a single universe,
sample, and estimation window. Full detail in `docs/rebuilt-methodology.md`.

## What the evidence does and does not establish

**Does establish:** that this specific project's original headline numbers
were a methodology artifact; that a correctly-timed walk-forward version of
the same idea produces a materially different (and much less extreme)
result; that an unrebalanced allocation drifts into risk its stated
constraints were meant to prevent; that this five-asset optimizer is
effectively concentrated in fewer than two independent bets most of the
time.

**Does not establish:** that constrained mean-variance optimization
outperforms naive diversification in general; that this or any allocation
is investable or advisable; that these results would hold over a different
sample period, universe, or estimation window.
