# Executive Summary

## Project

**The Resilient Growth Opportunities Fund** is a quantitative finance project focused on building and evaluating a diversified multi-asset portfolio using constrained mean-variance optimization.

The strategy combines U.S. financial equities, emerging markets, gold, energy, and a capped Bitcoin allocation to create a portfolio with multiple return drivers across different macroeconomic regimes.

## Objective

The goal of the project is to design a portfolio that balances long-term growth potential with macro resilience, diversification, and disciplined risk control.

Rather than simply maximizing the unconstrained Sharpe ratio, the project applies practical constraints to produce a more stable and implementable allocation.

## Portfolio Construction

The final portfolio uses five assets:

- **JPM** – primary U.S. equity and financials growth anchor
- **GLD** – defensive real asset exposure
- **XOM** – energy and commodity-cycle exposure
- **EEM** – emerging markets diversification
- **BTC-USD** – capped convex upside exposure

The final constrained allocation is:

- **JPM:** 57.85%
- **GLD:** 27.15%
- **XOM:** 5.00%
- **EEM:** 5.00%
- **BTC-USD:** 5.00%

The constraints include long-only positions, minimum allocations to traditional assets, a strict 5% Bitcoin cap, and full investment of portfolio capital.

## Methods Used

The analysis includes:

- Constrained mean-variance optimization
- Efficient frontier analysis
- Historical performance comparison
- Benchmarking against ACWI, AOR, and SPY
- Maximum drawdown analysis
- Expected shortfall and downside risk metrics
- Portfolio risk budgeting
- Percent contribution to risk
- Rolling performance analysis
- Backtested portfolio weights
- CAPM regression
- Bootstrapped 3-year forecast
- Correlation and normality diagnostics

## Main Findings

The fund produced strong historical performance over the sample period, with higher long-term returns than ACWI, AOR, and SPY, though with meaningfully higher volatility and drawdowns.

The analysis shows that:

- JPM acts as the main return engine but also dominates portfolio risk.
- GLD provides meaningful diversification because of its low volatility and favorable correlation profile.
- BTC contributes significant upside potential, but even a 5% allocation creates a material risk contribution.
- XOM and EEM add incremental macro and geographic diversification.
- The portfolio benefits from exposure to multiple return drivers rather than relying only on traditional U.S. equity beta.

## Risk Interpretation

The project highlights the importance of looking beyond headline returns.

Although the strategy achieved strong historical returns, it also experienced a large maximum drawdown and a high annualized standard deviation. This makes the strategy better understood as a high-growth, multi-asset portfolio with defensive components rather than a low-risk balanced portfolio.

Risk budgeting shows that portfolio risk is not distributed in the same proportion as capital weights. JPM receives the largest allocation and contributes the majority of total portfolio risk, while GLD receives a large allocation but contributes relatively little to total risk. BTC remains a meaningful risk factor despite its small weight.

## Investment Interpretation

The portfolio is designed around the idea that resilience does not mean avoiding volatility entirely. Instead, resilience comes from combining assets with different macro sensitivities, controlling exposure to extreme volatility, and maintaining the ability to recover across changing regimes.

The project demonstrates how quantitative optimization can support investment judgment, but also why constraints, interpretation, and practical risk controls are essential.

## Relevance

This project is relevant to investment research, portfolio analytics, asset allocation, and quantitative finance-adjacent roles because it combines:

- Financial theory
- Empirical analysis
- Portfolio construction
- Risk interpretation
- Benchmarking
- Written investment communication

## Main File

- `paper/final-paper.pdf` – Full research paper
