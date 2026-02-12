library(testit)

# Create a simple test PNG file
create_test_png = function() {
  tmp = tempfile(fileext = ".png")
  png(tmp, width = 400, height = 400)
  plot(1:10)
  dev.off()
  tmp
}

# Test that optim_png works with default parameters
test_png = create_test_png()
optim_png(test_png)
assert("optim_png ran successfully", file.exists(test_png))

# Test that optim_png works with output parameter
test_png_in = create_test_png()
test_png_out = tempfile(fileext = ".png")
optim_png(test_png_in, test_png_out)
assert("optim_png created output file", file.exists(test_png_out))

# Test that optim_png works with different optimization levels
test_png2 = create_test_png()
optim_png(test_png2, level = 0)
assert("optim_png works with level = 0", file.exists(test_png2))

test_png3 = create_test_png()
optim_png(test_png3, level = 6)
assert("optim_png works with level = 6", file.exists(test_png3))

# Test that optim_png fails with non-existent file
has_error = FALSE
tryCatch(optim_png("nonexistent.png"), error = function(e) has_error <<- TRUE)
assert("optim_png fails with non-existent file", has_error)

# Test that optim_png fails with invalid level
test_png4 = create_test_png()
has_error = FALSE
tryCatch(optim_png(test_png4, level = 7), error = function(e) has_error <<- TRUE)
assert("optim_png fails with level > 6", has_error)

test_png5 = create_test_png()
has_error = FALSE
tryCatch(optim_png(test_png5, level = -1), error = function(e) has_error <<- TRUE)
assert("optim_png fails with level < 0", has_error)
