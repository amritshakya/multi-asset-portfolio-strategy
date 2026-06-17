# Executive Summary

## Resilient Growth Opportunities Fund

I built this five-asset strategy to examine how constrained portfolio optimization could combine growth, defensive, commodity, international, and alternative exposures within one allocation.

The strategy invests in JPMorgan Chase, gold, ExxonMobil, emerging-markets equities, and Bitcoin. Historical performance is evaluated against ACWI, AOR, and SPY using monthly data from 2016 through 2025.

## Portfolio Construction

The portfolio is long-only and fully invested, with minimum allocations across the selected assets and a 5% cap on Bitcoin.

| Asset                                     | Weight | Role in the Strategy                        |
| ----------------------------------------- | -----: | ------------------------------------------- |
| JPMorgan Chase (`JPM`)                    | 57.85% | U.S. financials and primary growth exposure |
| SPDR Gold Shares (`GLD`)                  | 27.15% | Defensive real-asset exposure               |
| ExxonMobil (`XOM`)                        |  5.00% | Energy and commodity-cycle exposure         |
| iShares MSCI Emerging Markets ETF (`EEM`) |  5.00% | Emerging-markets diversification            |
| Bitcoin (`BTC-USD`)                       |  5.00% | Capped alternative-asset exposure           |

Given the constraints and historical inputs, the model allocated most of the remaining capital to JPM and GLD, while XOM, EEM, and Bitcoin remained at their minimum permitted weights.

## Principal Findings

**The portfolio is more concentrated than its five holdings suggest.** JPM represents the majority of invested capital and an even larger share of estimated portfolio risk. Diversification by asset count and diversification by risk source are not the same thing.

**Gold added diversification without contributing much portfolio volatility.** Its large capital allocation was accompanied by a relatively small risk contribution because of its low correlation with the portfolio’s equity positions.

**Bitcoin remained influential at a 5% weight.** Its high volatility meant that a small allocation still had a noticeable effect on both portfolio risk and historical return.

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

For the complete methodology and exhibits, see [`paper/final-paper.pdf`](paper/final-paper.pdf).
