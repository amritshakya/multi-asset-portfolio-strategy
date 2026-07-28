# Data Notes

This project uses publicly available market data downloaded from Yahoo Finance through R.

## Asset Universe

The strategy analyzes five assets:

| Ticker | Description |
|---|---|
| `JPM` | JPMorgan Chase & Co. |
| `GLD` | SPDR Gold Shares |
| `XOM` | ExxonMobil Corporation |
| `EEM` | iShares MSCI Emerging Markets ETF |
| `BTC-USD` | Bitcoin in U.S. dollars |

## Benchmarks

The portfolio is compared against:

| Ticker | Description |
|---|---|
| `ACWI` | iShares MSCI ACWI ETF |
| `AOR` | iShares Core Growth Allocation ETF |
| `SPY` | SPDR S&P 500 ETF Trust |

## Methodology

The original analysis downloads adjusted price data, converts prices to monthly observations, and calculates monthly returns for portfolio construction, benchmark comparison, rolling analysis, and risk attribution.

The full executable source is preserved in [`../archive/original-final.Rmd`](../archive/original-final.Rmd).

## Notes

Raw price data and processed return files are not currently committed to the repository. The project should therefore be read as a preserved academic research project with source code and final exhibits, not as a fully packaged production data pipeline.
