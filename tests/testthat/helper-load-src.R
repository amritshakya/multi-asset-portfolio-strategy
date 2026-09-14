# Loaded automatically by testthat before any test file runs.
# Sources the project's R/ modules relative to the repo root.

repo_root <- normalizePath(file.path(testthat::test_path(), "..", ".."))

source(file.path(repo_root, "R", "optimizer.R"))
source(file.path(repo_root, "R", "backtest.R"))
source(file.path(repo_root, "R", "metrics.R"))
source(file.path(repo_root, "R", "turnover.R"))
source(file.path(repo_root, "R", "attribution.R"))
