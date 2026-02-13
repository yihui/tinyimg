#!/usr/bin/env Rscript

# Benchmark script for optim_png() optimization levels
# This script benchmarks all optimization levels (0-6) on both simple and
# complex plots, measuring time and file size reduction.

library(tinyimg)

# Helper function to format time
format_time = function(seconds) {
  if (seconds < 1) {
    paste0(round(seconds * 1000, 1), "ms")
  } else {
    paste0(round(seconds, 2), "s")
  }
}

# Helper function to format file size
format_size = function(bytes) {
  if (bytes < 1024) {
    paste0(bytes, "B")
  } else if (bytes < 1024^2) {
    paste0(round(bytes / 1024, 1), "KB")
  } else {
    paste0(round(bytes / 1024^2, 1), "MB")
  }
}

# Create a simple plot (low complexity)
create_simple_plot = function(file) {
  png(file, width = 600, height = 400)
  plot(1:100, type = "l", main = "Simple Line Plot",
       xlab = "X", ylab = "Y", col = "blue", lwd = 2)
  dev.off()
}

# Create a complex plot (high complexity)
create_complex_plot = function(file) {
  png(file, width = 800, height = 800)
  par(mfrow = c(2, 2))
  
  # Scatterplot matrix style - many points
  x = rnorm(1000)
  y = rnorm(1000)
  z = x + y + rnorm(1000, sd = 0.5)
  
  plot(x, y, pch = 19, col = rgb(0, 0, 1, 0.3), main = "Scatter Plot")
  plot(x, z, pch = 19, col = rgb(1, 0, 0, 0.3), main = "Scatter Plot 2")
  boxplot(list(X = x, Y = y, Z = z), col = rainbow(3), main = "Boxplot")
  
  # Perspective plot
  x_grid = seq(-3, 3, length.out = 50)
  y_grid = seq(-3, 3, length.out = 50)
  z_grid = outer(x_grid, y_grid, function(x, y) sin(sqrt(x^2 + y^2)))
  persp(x_grid, y_grid, z_grid, col = "lightblue", theta = 30, phi = 30,
        main = "Perspective Plot")
  
  dev.off()
}

# Benchmark function
benchmark_level = function(input_file, level, plot_type) {
  output_file = tempfile(fileext = ".png")
  
  # Measure time
  start_time = Sys.time()
  optim_png(input_file, output_file, level = level)
  end_time = Sys.time()
  elapsed = as.numeric(difftime(end_time, start_time, units = "secs"))
  
  # Get file sizes
  original_size = file.info(input_file)$size
  optimized_size = file.info(output_file)$size
  reduction_pct = (1 - optimized_size / original_size) * 100
  
  # Clean up
  unlink(output_file)
  
  data.frame(
    plot_type = plot_type,
    level = level,
    time_sec = elapsed,
    original_bytes = original_size,
    optimized_bytes = optimized_size,
    reduction_pct = reduction_pct,
    stringsAsFactors = FALSE
  )
}

# Run benchmarks
cat("Running PNG optimization benchmarks...\n\n")

# Create test images
simple_file = tempfile(fileext = ".png")
complex_file = tempfile(fileext = ".png")

cat("Creating test images...\n")
set.seed(123)  # For reproducibility
create_simple_plot(simple_file)
create_complex_plot(complex_file)

cat("Simple plot size:", format_size(file.info(simple_file)$size), "\n")
cat("Complex plot size:", format_size(file.info(complex_file)$size), "\n\n")

# Benchmark all levels
results = data.frame()
levels = 0:6

for (level in levels) {
  cat("Benchmarking level", level, "...\n")
  
  # Simple plot
  result_simple = benchmark_level(simple_file, level, "simple")
  results = rbind(results, result_simple)
  
  # Complex plot
  result_complex = benchmark_level(complex_file, level, "complex")
  results = rbind(results, result_complex)
}

# Clean up
unlink(simple_file)
unlink(complex_file)

# Print results table
cat("\n")
cat("=" , rep("=", 79), sep = "")
cat("\nBenchmark Results\n")
cat("=" , rep("=", 79), sep = "")
cat("\n\n")

# Print formatted table
cat(sprintf("%-8s %-6s %-10s %-12s %-12s %-10s\n",
            "Type", "Level", "Time", "Original", "Optimized", "Reduction"))
cat(sprintf("%-8s %-6s %-10s %-12s %-12s %-10s\n",
            "--------", "-----", "----------", "------------", "------------", "----------"))

for (i in seq_len(nrow(results))) {
  r = results[i, ]
  cat(sprintf("%-8s %-6d %-10s %-12s %-12s %9.1f%%\n",
              r$plot_type, r$level, format_time(r$time_sec),
              format_size(r$original_bytes), format_size(r$optimized_bytes),
              r$reduction_pct))
}

cat("\n")

# Generate plots
cat("Generating benchmark plots...\n\n")

# Determine output directory
if (interactive()) {
  output_dir = getwd()
} else {
  # Try to find the benchmarks directory
  script_args = commandArgs(trailingOnly = FALSE)
  file_arg = grep("^--file=", script_args, value = TRUE)
  if (length(file_arg) > 0) {
    output_dir = dirname(sub("^--file=", "", file_arg))
  } else {
    output_dir = "."
  }
}

# Plot 1: Time vs Level (by plot type)
png(file.path(output_dir, "benchmark-time.png"), width = 800, height = 500)
par(mar = c(5, 5, 4, 2))
simple_data = results[results$plot_type == "simple", ]
complex_data = results[results$plot_type == "complex", ]

plot(simple_data$level, simple_data$time_sec, type = "b", pch = 19, col = "blue",
     xlab = "Optimization Level", ylab = "Time (seconds)",
     main = "Optimization Time by Level", ylim = c(0, max(results$time_sec)),
     lwd = 2, cex.lab = 1.2, cex.main = 1.3)
lines(complex_data$level, complex_data$time_sec, type = "b", pch = 17, col = "red", lwd = 2)
legend("topleft", legend = c("Simple Plot", "Complex Plot"),
       col = c("blue", "red"), pch = c(19, 17), lwd = 2, bty = "n")
grid()
dev.off()
cat("Created: benchmark-time.png\n")

# Plot 2: File size reduction % vs Level
png(file.path(output_dir, "benchmark-reduction.png"), width = 800, height = 500)
par(mar = c(5, 5, 4, 2))
plot(simple_data$level, simple_data$reduction_pct, type = "b", pch = 19, col = "blue",
     xlab = "Optimization Level", ylab = "File Size Reduction (%)",
     main = "Compression Efficiency by Level",
     ylim = c(0, max(results$reduction_pct) * 1.1), lwd = 2,
     cex.lab = 1.2, cex.main = 1.3)
lines(complex_data$level, complex_data$reduction_pct, type = "b", pch = 17, col = "red", lwd = 2)
legend("bottomright", legend = c("Simple Plot", "Complex Plot"),
       col = c("blue", "red"), pch = c(19, 17), lwd = 2, bty = "n")
grid()
dev.off()
cat("Created: benchmark-reduction.png\n")

# Plot 3: Time vs Reduction scatter plot
png(file.path(output_dir, "benchmark-scatter.png"), width = 800, height = 600)
par(mar = c(5, 5, 4, 2))
plot(results$time_sec, results$reduction_pct,
     pch = ifelse(results$plot_type == "simple", 19, 17),
     col = ifelse(results$plot_type == "simple", "blue", "red"),
     xlab = "Time (seconds)", ylab = "File Size Reduction (%)",
     main = "Time vs Compression Trade-off", cex = 1.5, cex.lab = 1.2, cex.main = 1.3)

# Add level labels
text(results$time_sec, results$reduction_pct, labels = results$level,
     pos = 3, cex = 0.8)
legend("bottomright", legend = c("Simple Plot", "Complex Plot"),
       col = c("blue", "red"), pch = c(19, 17), pt.cex = 1.5, bty = "n")
grid()
dev.off()
cat("Created: benchmark-scatter.png\n")

# Save results to CSV
csv_file = file.path(output_dir, "benchmark-results.csv")
write.csv(results, csv_file, row.names = FALSE)
cat("Created:", csv_file, "\n")

cat("\nBenchmark complete!\n")
