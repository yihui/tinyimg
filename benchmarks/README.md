# Benchmark Results for optim_png()

This directory contains benchmark results for the `optim_png()` function across all optimization levels (0-6).

## Files

- **benchmark-levels.R** - R script that generates benchmarks
- **benchmark-time.png** - Plot showing optimization time vs level
- **benchmark-reduction.png** - Plot showing file size reduction % vs level
- **benchmark-scatter.png** - Scatter plot of time vs compression trade-off
- **benchmark-results.csv** - Raw benchmark data in CSV format

## Running Benchmarks

To regenerate benchmarks manually:

```bash
Rscript benchmarks/benchmark-levels.R
```

## Automated Updates

Benchmarks are automatically regenerated twice a month (1st and 15th) via the `cargo-update.yaml` GitHub Actions workflow. If benchmark results change, a pull request is automatically created.

## Benchmark Methodology

The script benchmarks two types of plots:

1. **Simple plot**: A basic line plot (low complexity, ~12KB)
2. **Complex plot**: Multi-panel plot with scatter plots, boxplot, and perspective plot (high complexity, ~184KB)

For each plot type and optimization level (0-6), the script measures:

- **Time**: Seconds taken to optimize
- **Original size**: Original file size in bytes
- **Optimized size**: Optimized file size in bytes
- **Reduction**: Percentage reduction in file size

## Interpreting Results

- **Level 0-1**: Fast optimization with modest compression (~3-21% reduction)
- **Level 2**: Default level, good balance of speed and compression (~22-29% reduction)
- **Level 3-6**: Diminishing returns for additional time investment (~22-29% reduction)

The benchmarks help users choose the appropriate optimization level for their use case based on the time/compression trade-off.
