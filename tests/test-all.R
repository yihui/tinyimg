library(testit)
library(tinyimg)

# Create a simple test PNG file
# Reuses last created plot by default; use new = TRUE to create a new plot
test_png = NULL
create_test_png = function(new = FALSE) {
  if (!new && !is.null(test_png) && file.exists(test_png)) {
    return(test_png)
  }
  tmp = tempfile(fileext = ".png")
  png(tmp, width = 400, height = 400)
  plot(1:10)
  dev.off()
  test_png <<- tmp
  tmp
}

create_test_png()

# Test that tinypng() works with default parameters
assert("tinypng() ran successfully", {
  (tinypng(test_png) %==% test_png)
  (file.exists(test_png))
})

# Test that tinypng() works with output parameter
assert("tinypng() created output file", {
  test_png_out = tempfile(fileext = ".png")
  (tinypng(test_png, test_png_out) %==% test_png_out)
  (file.exists(test_png_out))
})

# Test that tinypng() works with different optimization levels
assert("tinypng() works with level = 0", {
  tinypng(test_png, level = 0)
  (file.exists(test_png))
})

assert("tinypng() works with level = 6", {
  tinypng(test_png, level = 6)
  (file.exists(test_png))
})

assert("tinypng() works with lossy optimization", {
  test_png_lossy_out = tempfile(fileext = ".png")
  tinypng(test_png, test_png_lossy_out, lossy = 0.5)
  (file.exists(test_png_lossy_out))
})

assert("tinypng() supports delta-e lossy thresholds", {
  test_png_lossy_jnd_out = tempfile(fileext = ".png")
  tinypng(test_png, test_png_lossy_jnd_out, lossy = 2.3)
  (file.exists(test_png_lossy_jnd_out))

  test_png_lossy_neg_out = tempfile(fileext = ".png")
  tinypng(test_png, test_png_lossy_neg_out, lossy = -1)
  (file.exists(test_png_lossy_neg_out))
})

# Test that tinypng() fails with non-existent file
assert("tinypng() fails with non-existent file", {
  (has_error(tinypng(tempfile())))
})

# Test alpha parameter
assert("tinypng() works with alpha = TRUE", {
  test_png4_out = tempfile(fileext = ".png")
  tinypng(test_png, test_png4_out, alpha = TRUE)
  (file.exists(test_png4_out))
})

# Test verbose parameter
assert("tinypng() works with verbose = FALSE", {
  test_png5_out = tempfile(fileext = ".png")
  tinypng(test_png, test_png5_out, verbose = FALSE)
  (file.exists(test_png5_out))
})

# Test directory optimization
assert("tinypng() works with directory input", {
  test_dir = tempfile()
  dir.create(test_dir)
  for (i in 1:3) {
    file.copy(test_png, file.path(test_dir, paste0("test", i, ".png")))
  }
  result = tinypng(test_dir)
  (length(result) %==% 3L)
  (file.exists(result))
})

# Test recursive directory optimization
assert("tinypng() works with recursive directory optimization", {
  test_dir2 = tempfile()
  dir.create(test_dir2)
  subdir = file.path(test_dir2, "subdir")
  dir.create(subdir)
  file.copy(test_png, file.path(test_dir2, "test1.png"))
  file.copy(test_png, file.path(subdir, "test2.png"))
  result2 = tinypng(test_dir2, recursive = TRUE)
  (length(result2) %==% 2L)
  (file.exists(result2))
})

# Test directory to directory optimization
assert("tinypng() works with directory to directory optimization", {
  test_dir3 = tempfile()
  dir.create(test_dir3)
  file.copy(test_png, file.path(test_dir3, "test1.png"))
  output_dir = tempfile()
  result3 = tinypng(test_dir3, output_dir)
  (dir.exists(output_dir))
  (length(list.files(output_dir, pattern = "\\.png$")) %==% 1L)
})

# Test verbose output with common parent directory
test_verbose_dir = tempfile()
dir.create(test_verbose_dir)
test_files = file.path(test_verbose_dir, paste0("test", 1:3, ".png"))
file.copy(test_png, test_files)

# Capture verbose output
verbose_output = capture.output({
  tinypng(test_files, verbose = TRUE)
})

assert("verbose output contains truncated paths", {
  # Verbose output should not contain the full temp directory path
  # It should show truncated paths like "test1.png", "test2.png", etc.
  (length(verbose_output) %==% 3L)
  (grepl("test[1-3]\\.png", verbose_output))
  # Make sure full paths are NOT in the output
  (!any(grepl(test_verbose_dir, verbose_output, fixed = TRUE)))
})

# Test verbose output with single file (should show basename)
single_output = capture.output({
  tinypng(test_png, verbose = TRUE)
})

assert("verbose output shows basename for single file", {
  (length(single_output) %==% 1L)
  # Should show just the filename, not the full path
  (grepl(basename(test_png), single_output))
  # Make sure full path is NOT in the output
  (!grepl(test_png, single_output, fixed = TRUE))
})

# Test verbose output with different input/output paths
test_diff_out = tempfile(fileext = ".png")
diff_output = capture.output({
  tinypng(test_png, test_diff_out, verbose = TRUE)
})

assert("verbose output shows both paths when different", {
  (length(diff_output) %==% 1L)
  # Should show "input -> output" format
  (grepl(" -> ", diff_output))
})
