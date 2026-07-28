knitr::opts_chunk$set(
  echo = FALSE,
  message = FALSE,
  warning = FALSE)

## set options and load packages
options(digits = 3)
options(width = 75)
Sys.setenv(TZ="UTC")

library(quantmod)
library(PerformanceAnalytics)
library(tidyverse)
library(xts)
library(zoo)
library(knitr)
library(tseries)
library(corrplot)
library(IntroCompFinR)

library(PortfolioAnalytics)
library(ROI)
library(ROI.plugin.quadprog)
library(ROI.plugin.glpk)


# Define tickers (diverse, cross-asset)
tickers <- c( "JPM", "XOM",       # U.S. industry benchmarks (financials-25%, energy-25%)
             "EEM",               # International equities (25%)
             "GLD",                     # Commodities (15%)
             "BTC-USD")                  # Crypto (10%)

# Fixed research window for reproducible published results
start <- as.Date("2016-01-01")
end   <- as.Date("2026-01-01")  # exclusive upper bound; includes December 2025

# Download data
getSymbols(tickers, src = "yahoo", from = start, to = end, auto.assign = TRUE)

# Extract Adjusted prices for all tickers dynamically
adjPrices <- do.call(merge, lapply(tickers, function(tk) Ad(get(tk))))
colnames(adjPrices) <- tickers

# Convert to monthly prices
monthlyPrices <- to.monthly(adjPrices, indexAt = "lastof", OHLC = FALSE)

# Compute simple monthly returns
returns <- na.omit(Return.calculate(monthlyPrices, method = "discrete"))

# Now add benchmark tickers
bench_tickers <- c("ACWI", "AOR", "SPY" )

getSymbols(bench_tickers, src = "yahoo", from = start, to = end, auto.assign = TRUE)

# Extract Adjusted prices for benchmarks
benchPrices <- do.call(merge, lapply(bench_tickers, function(tk) Ad(get(tk))))
colnames(benchPrices) <- bench_tickers

# Convert to monthly prices and compute simple monthly returns
benchMonthly <- to.monthly(benchPrices, indexAt = "lastof", OHLC = FALSE)
benchRet <- na.omit(Return.calculate(benchMonthly, method = "discrete"))

# Risk-free rate definitions
rf_annual  <- 0.045
rf_monthly <- (1 + rf_annual)^(1 / 12) - 1

mu.val <- 12 * apply(returns, 2, mean)
sig.val <- sqrt(12) * apply(returns, 2, sd)
cov.val <- 12 * cov(returns)
corr.val <- cor(returns)
# Benchmarks
er_ACWI<- 12 * mean(benchRet[,1])
sd_ACWI <- sqrt(12) *  sd(benchRet[,1])

er_AOR  <-12 *  mean(benchRet[,2])
sd_AOR  <- sqrt(12) * sd(benchRet[,2])


library(PortfolioAnalytics)
assets = colnames(returns)
# Portfolio specification
pspec <- portfolio.spec(assets = assets)

# Full investment
pspec <- add.constraint(pspec, type = "full_investment")

# Long-only
pspec <- add.constraint(pspec, type = "long_only")
# Create min and max weight vectors
min_w <- rep(0.05, length(assets))   # all assets at least 5%
max_w <- rep(1.0,  length(assets))   # general max

# Now adjust BTC constraint:
btc_index <- which(assets == "BTC-USD")
max_w[btc_index] <- 0.05  # BTC cannot exceed 5%
pspec <- add.constraint(pspec, 
                        type = "box",
                        min = min_w,
                        max = max_w)
pspec <- add.objective(pspec, type = "return", name = "mean")
pspec <- add.objective(pspec, type = "risk",   name = "StdDev")

opt_constrained <- optimize.portfolio(
  R = returns,
  portfolio = pspec,
  optimize_method = "ROI"
)

opt_constrained
new_weights <- extractWeights(opt_constrained)
new_weights

R_new <- Return.portfolio(R = returns, weights = new_weights)
port_er = 12 * mean (R_new)
port_sd = sqrt(12) * sd(R_new)


### 1. Merge portfolio + benchmarks + assets
### ---------------------------
hist_rets <- na.omit(merge(R_new, benchRet, returns))
colnames(hist_rets) <- c("Resilient Fund", "ACWI", "AOR", "SPY", assets)

### ---------------------------
### 2. CAGR helper function
### ---------------------------
CAGR <- function(R) {
  R <- na.omit(R)
  if (length(R) == 0) return(NA)
  total <- prod(1 + R) - 1
  yrs <- length(R) / 12
  (1 + total)^(1/yrs) - 1
}

### ---------------------------
### 3. Slicing function
### ---------------------------
slice_years <- function(R, yrs) {
  end_date <- index(R)[NROW(R)]
  start_date <- end_date - years(yrs)
  R[paste0(start_date, "/", end_date)]
}

### ---------------------------
### 4. Compute CAGR for all horizons
### ---------------------------

# Full-period CAGR
cagr_full <- apply(hist_rets, 2, CAGR)

# Latest calendar-year return within the fixed research sample
latest_year <- format(last(index(hist_rets)), "%Y")
ytd_rets <- hist_rets[paste0(latest_year, "/")]
cagr_ytd <- apply(ytd_rets, 2, CAGR)

# 3-Year CAGR
cagr_3yr <- apply(slice_years(hist_rets, 3), 2, CAGR)

# 5-Year CAGR
cagr_5yr <- apply(slice_years(hist_rets, 5), 2, CAGR)

# 10-Year CAGR
cagr_10yr <- apply(slice_years(hist_rets, 10), 2, CAGR)

### ---------------------------
### 5. Annualized SD (full-sample)
### ---------------------------
ann_sd_vec <- apply(hist_rets, 2, function(x) sd(x) * sqrt(12))

### ---------------------------
### 6. Sharpe ratio (full-sample)
### ---------------------------
sharpe_vec <- (cagr_full - rf_annual) / ann_sd_vec

### ---------------------------
### 7. Max Drawdown (full-sample)
### ---------------------------
mdd_vec <- apply(hist_rets, 2, maxDrawdown)


library(knitr)
library(scales)

# Convert return-based metrics to percent formatting
to_percent <- function(x) scales::percent(x, accuracy = 0.1)

perf_table <- data.frame(
  Metric = c(
    "CAGR (Full Sample)",
    "CAGR (YTD)",
    "CAGR (3-Year)",
    "CAGR (5-Year)",
    "CAGR (10-Year)",
    "Annualized SD",
    "Sharpe Ratio",
    "Max Drawdown"
  ),
  `Resilient Fund` = c(
    to_percent(cagr_full[1]),
    to_percent(cagr_ytd[1]),
    to_percent(cagr_3yr[1]),
    to_percent(cagr_5yr[1]),
    to_percent(cagr_10yr[1]),
    round(ann_sd_vec[1], 3),
    round(sharpe_vec[1], 3),
    to_percent(mdd_vec[1])
  ),
  ACWI = c(
    to_percent(cagr_full[2]),
    to_percent(cagr_ytd[2]),
    to_percent(cagr_3yr[2]),
    to_percent(cagr_5yr[2]),
    to_percent(cagr_10yr[2]),
    round(ann_sd_vec[2], 3),
    round(sharpe_vec[2], 3),
    to_percent(mdd_vec[2])
  ),
  AOR = c(
    to_percent(cagr_full[3]),
    to_percent(cagr_ytd[3]),
    to_percent(cagr_3yr[3]),
    to_percent(cagr_5yr[3]),
    to_percent(cagr_10yr[3]),
    round(ann_sd_vec[3], 3),
    round(sharpe_vec[3], 3),
    to_percent(mdd_vec[3])
  ),
  SPY = c(
    to_percent(cagr_full[4]),
    to_percent(cagr_ytd[4]),
    to_percent(cagr_3yr[4]),
    to_percent(cagr_5yr[4]),
    to_percent(cagr_10yr[4]),
    round(ann_sd_vec[4], 3),
    round(sharpe_vec[4], 3),
    to_percent(mdd_vec[4])
  ),
  check.names = FALSE
)

kable(perf_table, 
      caption = "Performance Summary: Fund vs Benchmarks", 
      booktabs = TRUE, 
      align = c("l","c","c","c","c"))




# Align dates across all assets
common_dates <- Reduce(
  intersect,
  list(index(R_new), index(benchRet$ACWI), index(benchRet$AOR), index(benchRet$SPY))
)

fund_ret  <- R_new[common_dates]
acwi_ret  <- benchRet$ACWI[common_dates]
aor_ret   <- benchRet$AOR[common_dates]
spy_ret   <- benchRet$SPY[common_dates]

toPlot <- na.omit(merge(fund_ret, acwi_ret, aor_ret, spy_ret))
colnames(toPlot) <- c("Fund", "ACWI", "AOR", "SPY")

charts.PerformanceSummary(
  toPlot
)


descriptive_stats <- data.frame(
  Asset     = colnames(returns),
  Mean      = apply(returns, 2, mean),
  SD        = apply(returns, 2, sd),
  Skewness  = apply(returns, 2, skewness),
  Kurtosis  = apply(returns, 2, kurtosis),
  row.names = NULL
)

knitr::kable(
  descriptive_stats,
  caption = "Monthly Descriptive Statistics for Asset Returns"
)

library(knitr)

asset_metadata <- data.frame(
  Ticker = c("JPM", "GLD", "XOM", "EEM", "BTC-USD"),
  Asset = c("JPMorgan Chase & Co.", "SPDR Gold Shares", "ExxonMobil", 
            "iShares MSCI Emerging Markets", "Bitcoin"),
  Sector = c("U.S. Financials (Equity)", "Real Assets / Commodities",
             "Energy / Oil & Gas", "Emerging Markets Equity", 
             "Digital Asset")
)

asset_table <- asset_metadata %>%
  mutate(
    Weight = scales::percent(new_weights[Ticker], accuracy = 0.01)
  ) %>%
  select(Asset, Ticker, Sector, Weight)

knitr::kable(asset_table,
             caption = " Fund Asset Summary")

  
#Plot Attributes
asset_names <- colnames(returns)
assetname.val <- 1
dot.val <- 1
axis.val <- 1

#Plotting the Assets
plot(sig.val,mu.val, ylim=c(0,1), xlim=c(0,1), ylab=expression(mu[p]),
     xlab=expression(sigma[p]), pch=16, col="blue", cex=dot.val, cex.lab=axis.val)  
text(sig.val, mu.val, labels=asset_names, pos=4, cex = assetname.val)

#Plotting risk free
points(0, rf_annual, pch=16, col="red", cex=dot.val)  
text(0.001, rf_annual, labels=expression(r[f]), pos=1, cex = assetname.val)

#efficient frontier from introfinR
ef <- efficient.frontier(mu.val, cov.val, nport = 50)

lines (ef$sd,ef$er, 
     col = "purple",
     lwd = 2)


points(port_sd, port_er, col="green", pch=16, cex=1.4)
text(port_sd, port_er, "Resilient Portfolio ", pos=3)



# Benchmarks: ACWI and AOR
points(sd_ACWI, er_ACWI, col = "orange", pch = 15, cex = 1.4)
text(sd_ACWI, er_ACWI, "ACWI", pos = 2)

points(sd_AOR, er_AOR, col = "brown", pch = 15, cex = 1.4)
text(sd_AOR, er_AOR, "AOR", pos = 1)




# 1. Annual return and SD 
ann_table <- table.AnnualizedReturns(R_new, geometric = TRUE)

# 2. SemiDeviation 
semi_m <- SemiDeviation(R_new)
semi_annual <- semi_m * sqrt(12)

# 3. DownsideDeviation (professor method)
dd_m <- DownsideDeviation(R_new, MAR = 0)
dd_annual <- dd_m * sqrt(12)

# 4. Expected Shortfall (keep monthly)
es_m <- ES(R_new, p = 0.95)

# 5. Max Drawdown
mdd <- maxDrawdown(R_new)

risk_table <- data.frame(
  Metric = c(
    "Annual Return",
    "Annual SD",
    "Annual SemiDeviation",
    "Annual DownsideDeviation",
    "ES 95% (Monthly)",
    "Max Drawdown"
  ),
  Value = c(
    ann_table[1,1],
    ann_table[2,1],
    as.numeric(semi_annual),
    as.numeric(dd_annual),
    as.numeric(es_m),
    as.numeric(mdd)
  )
)

knitr::kable(
  risk_table,
  caption = "Annualized Stats"
)



# Covariance matrix of asset returns
cov_mat <- cov(returns)

# Convert weights to numeric vector
w <- as.numeric(new_weights)

# Portfolio variance and SD (consistent with cov_mat)
var_p <- as.numeric(t(w) %*% cov_mat %*% w)
sd_p  <- sqrt(var_p)


# Marginal Contribution to Risk
MCR <- (cov_mat %*% w) / sd_p

# Component Risk
CR <- w * MCR

# Percent Contribution to Risk
PCR <- CR / sd_p

# Create table
risk_budget <- data.frame(
  Asset = colnames(returns),
  Weight = w,
  MCR = as.numeric(MCR),
  CR = as.numeric(CR),
  PCR = as.numeric(PCR)
)

kable(risk_budget, caption= "Portfolio Risk Budgeting")

dir.create("outputs/tables", recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/figures", recursive = TRUE, showWarnings = FALSE)

write.csv(
  risk_budget,
  "outputs/tables/risk-budget.csv",
  row.names = FALSE
)

asset_order <- risk_budget %>%
  arrange(desc(PCR)) %>%
  pull(Asset)

risk_budget_long <- risk_budget %>%
  mutate(Asset = factor(Asset, levels = asset_order)) %>%
  select(Asset, Weight, PCR) %>%
  pivot_longer(
    cols = c(Weight, PCR),
    names_to = "Metric",
    values_to = "Value"
  ) %>%
  mutate(
    Metric = recode(
      Metric,
      Weight = "Capital Weight",
      PCR = "Risk Contribution"
    )
  )

risk_contribution_plot <- ggplot(
  risk_budget_long,
  aes(x = Asset, y = Value, fill = Metric)
) +
  geom_col(position = "dodge") +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
  labs(
    title = "Capital Weight vs. Risk Contribution",
    subtitle = "JPM accounts for most portfolio risk despite a five-asset allocation",
    x = NULL,
    y = "Share of Portfolio",
    fill = NULL
  ) +
  theme_minimal()

ggsave(
  "outputs/figures/risk-contribution.png",
  risk_contribution_plot,
  width = 8,
  height = 5,
  dpi = 300
)


par(mfrow = c(1, 2), mar = c(4, 4, 3, 1))

## --- Rolling Mean ---
roll.mean <- rollapply(R_new, 24, mean, align="right", fill=NA)
roll.sd   <- rollapply(R_new, 24, sd,   align="right", fill=NA)
se.mean   <- roll.sd / sqrt(24)

meanPlot <- merge(
  roll.mean,
  roll.mean - 2*se.mean,
  roll.mean + 2*se.mean,
  R_new
)

plot.zoo(
  meanPlot, plot.type="single",
  main="Rolling Mean",
  ylab="Returns",
  col=c("blue","red","red","lightgray"),
  lwd=c(2,1,1,1),
  lty=c(1,2,2,1)
)

abline(h=0, lty=3)

legend(
  "top", horiz=TRUE, bty="n",
  legend=c("Mean","±2 SE","Returns"),
  col=c("blue","red","lightgray"),
  lwd=c(2,1,1),
  lty=c(1,2,1)
)

## --- Rolling Volatility ---
roll.vol <- rollapply(R_new, 24, sd, align="right", fill=NA)
se.vol   <- roll.vol / sqrt(2*24)

volPlot <- merge(
  roll.vol,
  roll.vol - 2*se.vol,
  roll.vol + 2*se.vol,
  R_new
)

plot.zoo(
  volPlot, plot.type="single",
  main="Rolling Volatility",
  ylab="Volatility",
  col=c("darkgreen","red","red","lightgray"),
  lwd=c(2,1,1,1),
  lty=c(1,2,2,1)
)
abline(h=0, lty=3)
legend(
  "top", horiz=TRUE, bty="n",
  legend=c("Volatility","±2 SE","Returns"),
  col=c("darkgreen","red","lightgray"),
  lwd=c(2,1,1),
  lty=c(1,2,1)
)

par(mfrow = c(1, 1))

### --- Rolling Sharpe Ratio (24 Months) ---

roll.sharpe <- rollapply(
  R_new,
  width = 24,
  FUN = function(x) {
    monthly_sharpe <- (mean(x) - rf_monthly) / sd(x)
    monthly_sharpe * sqrt(12)
  },
  by.column = TRUE,
  align = "right",
  fill = NA
)

# Combine for overlay plot with monthly returns
sharpePlot_noSE <- merge(roll.sharpe, R_new)

plot.zoo(
  sharpePlot_noSE,
  plot.type = "single",
  
  ylab = "Sharpe Ratio",
  col = c("purple", "lightgray"),
  lwd = c(2, 1),
  lty = c("solid", "solid")
)

abline(h = 0, col = "black", lty = 3)

legend(
  x = "top",
  inset = 0.02,
  horiz = TRUE,
  bty = "n",
  legend = c("Rolling Sharpe", "Monthly returns"),
  col = c("purple", "lightgray"),
  lwd = c(2, 1),
  lty = c(1, 1)
)




# 24-month rolling backtest for your portfolio
backtest_portfolio <- optimize.portfolio.rebalancing(
  R               = returns,       
  portfolio       = pspec,
  optimize_method = "ROI",
  rebalance_on    = "months",
  training_period = 24,
  rolling_window  = 24
)
# Extract rebalance optimization results
rebalance_list <- backtest_portfolio$opt_rebalancing

# Extract weight vectors for each rebalance
weights_list <- lapply(rebalance_list, function(x) x$weights)

# Extract rebalance dates
dates <- as.Date(names(rebalance_list))

# Identify and remove NA weight vectors
valid_idx <- !sapply(weights_list, function(x) all(is.na(x)))
weights_list <- weights_list[valid_idx]
dates <- dates[valid_idx]

# Convert to xts
wts_clean <- xts(do.call(rbind, weights_list), order.by = dates)

# Plot
# Convert xts to matrix
wmat <- coredata(wts_clean)
dates <- index(wts_clean)

cols <- c("red", "green", "blue", "gold", "purple")
names(cols) <- colnames(wts_clean)
# Expand margins
par(mar = c(5, 4, 6, 10))
par(xpd = NA)  # allow drawing outside plot area

bp <- barplot(
  t(wmat),
  col = cols,
  border = "black",
  lwd = 1,
  space = 0,
  width = 1,
  axes = FALSE,
 
  ylab = "Portfolio Weight"
)

axis(2, las = 1)

label_idx <- seq(1, length(dates), length.out = 6)
axis(1,
     at = bp[label_idx],
     labels = format(dates[label_idx], "%Y-%m"),
     cex.axis = 0.9
)

# Legend outside plot
legend(
  x = max(bp) * 1.05,   # to the right of bars
  y = 1,                # top of plot
  legend = colnames(wts_clean),
  fill = cols,
  box.lwd = 1.3,
  bty = "o",
  cex = 0.9
)


# 1. Extract weights
wts_xts <- extractWeights(backtest_portfolio)

# 2. LOCF-fill missing rebalance weights
wts_filled <- na.locf(wts_xts, na.rm = FALSE)

# Remove leading NA rows
wts_filled <- wts_filled[rowSums(!is.na(wts_filled)) > 0, ]

# 3. Align with returns
common_dates <- intersect(index(wts_filled), index(returns))
wts_final <- wts_filled[common_dates]
R_bt      <- returns[common_dates]

# 4. Compute strategy backtested returns
bt_ret <- Return.portfolio(R = R_bt, weights = wts_final)

# 5. Align benchmarks (ACWI, AOR, SPY) to same dates
bench_acwi <- benchRet$ACWI[common_dates]
bench_aor  <- benchRet$AOR[common_dates]
bench_spy  <- benchRet$SPY[common_dates]

# 6. Merge into a single xts object
toPlot <- na.omit( merge(bt_ret, bench_acwi, bench_aor, bench_spy, join = "inner") )

colnames(toPlot) <- c("Strategy", "ACWI", "AOR", "SPY")

# 7. Plot cumulative wealth
chart.CumReturns(
  toPlot,
  wealth.index = TRUE,
  geometric = TRUE,
  ylab = "Wealth (Start = $1)",
  legend.loc = "topleft"
)




## CAPM Regression ----
library(PerformanceAnalytics)

# Monthly risk-free rate series aligned with fund returns
Rf_xts <- xts(rep(rf_monthly, nrow(R_new)), index(R_new))

# Compute excess returns
excess_fund <- R_new - Rf_xts
excess_mkt  <- benchRet$SPY - Rf_xts

# Merge and clean data
capm_data <- na.omit(merge(excess_fund, excess_mkt))
colnames(capm_data) <- c("Fund", "Market")

# Run CAPM regression
fit <- lm(Fund ~ Market, data = capm_data)


beta <- coef(fit)[2] 
alpha_monthly <- coef(fit)[1] 
alpha_annual <- (1 + alpha_monthly)^12 - 1 #  annualization 
R2 <- summary(fit)$r.squared
capm_table <- data.frame(
  Metric = c("Alpha (Annualized)", "Beta", "R-squared"),
  Value  = c(
    round(alpha_annual, 3),
    round(beta, 3),
    round(R2, 3)
  )
)

knitr::kable(
  capm_table,
  caption = "CAPM Regression Results"
)



set.seed(123)

B <- 5000
n <- nrow(R_new)

boot_means <- replicate(B, {
  boot_sample <- sample(R_new, n, replace = TRUE)
  total <- prod(1 + boot_sample) - 1
  yrs <- n / 12
  (1 + total)^(1/yrs) - 1
})

ci_95 <- quantile(boot_means, probs = c(0.025, 0.975))
ci_95

library(lubridate)

future_months <- 36

# last date in your series
start_date <- last(index(R_new))

# start forecasting from next month
dates_future <- seq(from = start_date %m+% months(1),
                    by = "month",
                    length.out = future_months)

set.seed(123)
B <- 5000

boot_future <- matrix(NA, nrow = future_months, ncol = B)
for (b in 1:B) {
  boot_future[, b] <- sample(as.numeric(R_new), future_months, replace = TRUE)
}

boot_equity <- apply(boot_future, 2, function(x) cumprod(1 + x))

eq_median <- apply(boot_equity, 1, median)
eq_low    <- apply(boot_equity, 1, quantile, probs = 0.025)
eq_high   <- apply(boot_equity, 1, quantile, probs = 0.975)

boot_xts <- xts(cbind(eq_low, eq_median, eq_high), order.by = dates_future)
colnames(boot_xts) <- c("Lower_95", "Median", "Upper_95")

chart.TimeSeries(
  boot_xts,
  legend.loc = "topleft",
  ylab = "Forecasted Growth of $1"
)
boot_ci <- quantile(boot_means, c(0.025, 0.5, 0.975))




PerformanceAnalytics:::chart.QQPlot(
  R_new,
  main = "Portfolio Returns QQ-Plot"
)

library(tseries)

jb_portfolio <- data.frame(
  JB_Statistic = jarque.bera.test(R_new)$statistic,
  JB_pvalue    = jarque.bera.test(R_new)$p.value
)

knitr::kable(
  jb_portfolio,
  caption = "Jarque–Bera Normality Test for Portfolio Returns"
)




corr_mat <- cor(returns)

corrplot(corr_mat, method="color",
type="upper",
addCoef.col = "black",
number.cex = .6,
tl.cex = .8,
tl.col = "black"

)
