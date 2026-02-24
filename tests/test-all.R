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

# Test that optim_png works with default parameters
assert("optim_png ran successfully", {
  (optim_png(test_png) %==% test_png)
  (file.exists(test_png))
})

# Test that optim_png works with output parameter
assert("optim_png created output file", {
  test_png_out = tempfile(fileext = ".png")
  (optim_png(test_png, test_png_out) %==% test_png_out)
  (file.exists(test_png_out))
})

# Test that optim_png works with different optimization levels
assert("optim_png works with level = 0", {
  optim_png(test_png, level = 0)
  (file.exists(test_png))
})

assert("optim_png works with level = 6", {
  optim_png(test_png, level = 6)
  (file.exists(test_png))
})

assert("tinypng works with lossy optimization", {
  test_png_lossy_out = tempfile(fileext = ".png")
  tinypng(test_png, test_png_lossy_out, lossy = 0.5)
  (file.exists(test_png_lossy_out))
})

assert("tinypng supports lossy auto mode", {
  test_png_lossy_auto_out = tempfile(fileext = ".png")
  tinypng(test_png, test_png_lossy_auto_out, lossy = NA)
  (file.exists(test_png_lossy_auto_out))
})

assert("tinypng validates lossy range", {
  (has_error(tinypng(test_png, lossy = 1.1)))
})

# Test that optim_png fails with non-existent file
assert("optim_png fails with non-existent file", {
  (has_error(optim_png(tempfile())))
})

# Test alpha parameter
assert("optim_png works with alpha = TRUE", {
  test_png4_out = tempfile(fileext = ".png")
  optim_png(test_png, test_png4_out, alpha = TRUE)
  (file.exists(test_png4_out))
})

# Test verbose parameter
assert("optim_png works with verbose = FALSE", {
  test_png5_out = tempfile(fileext = ".png")
  optim_png(test_png, test_png5_out, verbose = FALSE)
  (file.exists(test_png5_out))
})

# Test directory optimization
assert("optim_png works with directory input", {
  test_dir = tempfile()
  dir.create(test_dir)
  for (i in 1:3) {
    file.copy(test_png, file.path(test_dir, paste0("test", i, ".png")))
  }
  result = optim_png(test_dir)
  (length(result) %==% 3L)
  (file.exists(result))
})

# Test recursive directory optimization
assert("optim_png works with recursive directory optimization", {
  test_dir2 = tempfile()
  dir.create(test_dir2)
  subdir = file.path(test_dir2, "subdir")
  dir.create(subdir)
  file.copy(test_png, file.path(test_dir2, "test1.png"))
  file.copy(test_png, file.path(subdir, "test2.png"))
  result2 = optim_png(test_dir2, recursive = TRUE)
  (length(result2) %==% 2L)
  (file.exists(result2))
})

# Test directory to directory optimization
assert("optim_png works with directory to directory optimization", {
  test_dir3 = tempfile()
  dir.create(test_dir3)
  file.copy(test_png, file.path(test_dir3, "test1.png"))
  output_dir = tempfile()
  result3 = optim_png(test_dir3, output_dir)
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
  optim_png(test_files, verbose = TRUE)
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
  optim_png(test_png, verbose = TRUE)
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
  optim_png(test_png, test_diff_out, verbose = TRUE)
})

assert("verbose output shows both paths when different", {
  (length(diff_output) %==% 1L)
  # Should show "input -> output" format
  (grepl(" -> ", diff_output))
})
