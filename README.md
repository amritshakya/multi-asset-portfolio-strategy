# Resilient Growth Opportunities Fund

This repository contains a quantitative finance project that designs, analyzes, and backtests a multi-asset portfolio strategy called the **Resilient Growth Opportunities Fund**.

The project applies constrained mean-variance optimization, portfolio risk analysis, benchmark comparison, risk budgeting, and forecasting to evaluate a strategy built across U.S. equities, emerging markets, real assets, energy, and a capped digital asset allocation.

## Project Overview

The Resilient Growth Opportunities Fund is designed to pursue long-term risk-adjusted returns across changing macroeconomic environments.

The portfolio combines:

- **JPM** – U.S. financials and cyclical growth exposure
- **GLD** – defensive real asset exposure
- **XOM** – energy and commodity-cycle exposure
- **EEM** – emerging markets equity exposure
- **BTC-USD** – capped digital asset exposure for convex upside

The project begins with a theoretical Markowitz tangency portfolio and then applies practical constraints to create a more stable, long-only, implementable allocation.

## Final Portfolio

The final constrained allocation is:

- JPMorgan Chase & Co. (**JPM**) – 57.85%
- SPDR Gold Shares (**GLD**) – 27.15%
- ExxonMobil (**XOM**) – 5.00%
- iShares MSCI Emerging Markets ETF (**EEM**) – 5.00%
- Bitcoin (**BTC-USD**) – 5.00%

The allocation reflects a balance between growth, diversification, defensive assets, and controlled exposure to high-volatility return drivers.

## Key Questions

- How can a multi-asset portfolio be constructed using constrained mean-variance optimization?
- How do practical constraints change the theoretical tangency portfolio?
- How does the strategy perform relative to ACWI, AOR, and SPY?
- Which assets drive portfolio risk, return, and drawdowns?
- How do rolling weights, rolling Sharpe ratios, and backtests change across macro regimes?
- How can risk metrics such as drawdown, expected shortfall, and risk contribution improve portfolio interpretation?

## Methods

The project includes:

- Constrained mean-variance optimization
- Efficient frontier analysis
- Historical return and volatility analysis
- Benchmark comparison against ACWI, AOR, and SPY
- Downside risk analysis
- Expected shortfall
- Maximum drawdown analysis
- Risk budgeting and percent contribution to risk
- Rolling mean, volatility, and Sharpe ratio analysis
- Backtested portfolio weights
- CAPM regression
- Bootstrapped 3-year forecast
- Correlation and distributional diagnostics

## Repository Structure

    portfolio-risk-modeling/
    ├── README.md
    ├── executive-summary.md
    ├── paper/
    │   └── final-paper.pdf
    ├── code/
    ├── outputs/
    └── data/
        └── README.md

## Files

- `paper/final-paper.pdf` – Full research paper
- `executive-summary.md` – Summary of the strategy, methods, and main findings
- `data/` – Notes on data sources and availability
- `code/` – Supporting analysis files, to be added or cleaned
- `outputs/` – Charts and exhibits, to be added if available

## Skills Demonstrated

- Portfolio construction
- Quantitative finance
- Mean-variance optimization
- Risk and return analysis
- Benchmarking and backtesting
- Risk budgeting
- Financial time series analysis
- Investment research communication
- Technical writing

## Status

The full research paper is included first. Supporting code, charts, and cleaned data documentation may be added as the project is further organized.

This repository is intended as a professional work sample for investment research, portfolio analytics, asset allocation, and financial data analysis roles.

## Disclaimer

This project was developed for academic and professional portfolio purposes. It is not investment advice or a recommendation to buy or sell any security.
