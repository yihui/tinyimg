library(testit)

# Create a simple test PNG file
create_test_png = function() {
  tmp = tempfile(fileext = ".png")
  png(tmp, width = 100, height = 100)
  plot(1:10)
  dev.off()
  tmp
}

# Test that optim_png works with default parameters
test_png = create_test_png()
assert("optim_png runs without error", {
  tryCatch({
    optim_png(test_png)
    TRUE
  }, error = function(e) FALSE)
})

# Test that optim_png works with output parameter
test_png_in = create_test_png()
test_png_out = tempfile(fileext = ".png")
assert("optim_png works with output parameter", {
  optim_png(test_png_in, test_png_out)
  file.exists(test_png_out)
})

# Test that optim_png works with different optimization levels
test_png2 = create_test_png()
assert("optim_png works with level = 0", {
  tryCatch({
    optim_png(test_png2, level = 0)
    TRUE
  }, error = function(e) FALSE)
})

test_png3 = create_test_png()
assert("optim_png works with level = 6", {
  tryCatch({
    optim_png(test_png3, level = 6)
    TRUE
  }, error = function(e) FALSE)
})

# Test that optim_png fails with non-existent file
assert("optim_png fails with non-existent file", {
  tryCatch({
    optim_png("nonexistent.png")
    FALSE
  }, error = function(e) TRUE)
})

# Test that optim_png fails with invalid level
test_png4 = create_test_png()
assert("optim_png fails with level > 6", {
  tryCatch({
    optim_png(test_png4, level = 7)
    FALSE
  }, error = function(e) TRUE)
})

test_png5 = create_test_png()
assert("optim_png fails with level < 0", {
  tryCatch({
    optim_png(test_png5, level = -1)
    FALSE
  }, error = function(e) TRUE)
})
