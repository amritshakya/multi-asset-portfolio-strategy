# Executive Summary

## Resilient Growth Opportunities Fund

I built this five-asset strategy to examine how constrained portfolio optimization could combine growth, defensive, commodity, international, and alternative exposures within one allocation.

The strategy invests in JPMorgan Chase, gold, ExxonMobil, emerging-markets equities, and Bitcoin. The corrected analysis uses monthly data from January 2016 through December 2025 and evaluates historical performance against ACWI, AOR, and SPY.

## Portfolio Construction

The portfolio is long-only and fully invested, with minimum allocations across the selected assets and a 5% cap on Bitcoin.

| Asset                                     | Weight | Role in the Strategy                        |
| ----------------------------------------- | -----: | ------------------------------------------- |
| JPMorgan Chase (`JPM`)                    | 68.10% | U.S. financials and primary growth exposure |
| SPDR Gold Shares (`GLD`)                  | 16.90% | Defensive real-asset exposure               |
| ExxonMobil (`XOM`)                        |  5.00% | Energy and commodity-cycle exposure         |
| iShares MSCI Emerging Markets ETF (`EEM`) |  5.00% | Emerging-markets diversification            |
| Bitcoin (`BTC-USD`)                       |  5.00% | Capped alternative-asset exposure           |

After standardizing the return methodology and fixing the sample period, the constrained optimizer allocated 68.1% to JPM and 16.9% to GLD, while XOM, EEM, and Bitcoin remained at their 5% minimum or cap.

## Principal Findings

**The portfolio is more concentrated than its five holdings suggest.** JPM represents 68.1% of invested capital and approximately 83.8% of estimated portfolio risk. Diversification by asset count and diversification by risk source are not the same thing.

**Gold added diversification without contributing much portfolio volatility.** GLD represents 16.9% of capital but contributes less than 1% of estimated portfolio risk because of its lower volatility and covariance with the other holdings.

**Bitcoin remained influential at a 5% weight.** It contributes approximately 9% of estimated portfolio risk, showing how a high-volatility asset can materially affect portfolio behavior at a modest allocation.

The result is not a conventional low-risk balanced portfolio. It is a concentrated, growth-oriented strategy with defensive and alternative sleeves.

## Interpretation and Limitations

The allocation is sensitive to:

* Historical expected-return estimates
* Covariance and correlation assumptions
* The selected asset universe
* Minimum- and maximum-weight constraints
* The estimation window
* Strong historical Bitcoin returns
* Concentration in a single U.S. financial stock

The portfolio should not be assessed solely through historical return or Sharpe ratio. Drawdowns, risk contribution, allocation stability, and the reason each position belongs in the portfolio are equally important.

The analysis applies constrained mean-variance optimization, rolling re-optimization, risk attribution, drawdown analysis, CAPM regression, and historical bootstrap scenarios.

## Conclusion

The strategy shows how assets that respond differently across market environments can improve a portfolio while still leaving it concentrated in a small number of risk drivers.

What the analysis makes clear is not the specific allocation, but the gap between holding several assets and achieving genuine risk diversification. Quantitative optimization can identify trade-offs, but the final portfolio still requires sensible constraints, robustness checks, and investment judgment.

For the original academic report, see [`paper/final-paper.pdf`](paper/final-paper.pdf). The corrected standalone analysis is available in [`code/portfolio-analysis.R`](code/portfolio-analysis.R), with updated risk outputs in [`outputs/tables/risk-budget.csv`](outputs/tables/risk-budget.csv) and [`outputs/figures/risk-contribution.png`](outputs/figures/risk-contribution.png).
