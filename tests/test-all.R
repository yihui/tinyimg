library(testit)
library(tinyimg)

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
assert("optim_png ran successfully", {
  file.exists(test_png)
})

# Test that optim_png works with output parameter
test_png_in = create_test_png()
test_png_out = tempfile(fileext = ".png")
optim_png(test_png_in, test_png_out)
assert("optim_png created output file", {
  file.exists(test_png_out)
})

# Test that optim_png works with different optimization levels
test_png2 = create_test_png()
optim_png(test_png2, level = 0)
assert("optim_png works with level = 0", {
  file.exists(test_png2)
})

test_png3 = create_test_png()
optim_png(test_png3, level = 6)
assert("optim_png works with level = 6", {
  file.exists(test_png3)
})

# Test that optim_png fails with non-existent file
assert("optim_png fails with non-existent file", {
  has_error(optim_png("nonexistent.png"))
})

# Test that optim_png fails with invalid level
test_png4 = create_test_png()
assert("optim_png fails with level > 6", {
  has_error(optim_png(test_png4, level = 7))
})

test_png5 = create_test_png()
assert("optim_png fails with level < 0", {
  has_error(optim_png(test_png5, level = -1))
})

# Test new parameters: strip
test_png6 = create_test_png()
test_png6_out = tempfile(fileext = ".png")
optim_png(test_png6, test_png6_out, strip = "safe")
assert("optim_png works with strip = 'safe'", {
  file.exists(test_png6_out)
})

test_png7 = create_test_png()
test_png7_out = tempfile(fileext = ".png")
optim_png(test_png7, test_png7_out, strip = "all")
assert("optim_png works with strip = 'all'", {
  file.exists(test_png7_out)
})

# Test new parameters: alpha
test_png8 = create_test_png()
test_png8_out = tempfile(fileext = ".png")
optim_png(test_png8, test_png8_out, alpha = TRUE)
assert("optim_png works with alpha = TRUE", {
  file.exists(test_png8_out)
})

# Test new parameters: interlace
test_png9 = create_test_png()
test_png9_out = tempfile(fileext = ".png")
optim_png(test_png9, test_png9_out, interlace = "keep")
assert("optim_png works with interlace = 'keep'", {
  file.exists(test_png9_out)
})

# Test new parameters: fast
test_png10 = create_test_png()
test_png10_out = tempfile(fileext = ".png")
optim_png(test_png10, test_png10_out, fast = TRUE)
assert("optim_png works with fast = TRUE", {
  file.exists(test_png10_out)
})

# Test new parameters: timeout
test_png11 = create_test_png()
test_png11_out = tempfile(fileext = ".png")
optim_png(test_png11, test_png11_out, timeout = 5)
assert("optim_png works with timeout = 5", {
  file.exists(test_png11_out)
})

# Test directory optimization
test_dir = tempfile()
dir.create(test_dir)
for (i in 1:3) {
  file.copy(create_test_png(), file.path(test_dir, paste0("test", i, ".png")))
}
result = optim_png(test_dir)
assert("optim_png works with directory input", {
  length(result) == 3 && all(file.exists(result))
})

# Test recursive directory optimization
test_dir2 = tempfile()
dir.create(test_dir2)
subdir = file.path(test_dir2, "subdir")
dir.create(subdir)
file.copy(create_test_png(), file.path(test_dir2, "test1.png"))
file.copy(create_test_png(), file.path(subdir, "test2.png"))
result2 = optim_png(test_dir2, recursive = TRUE)
assert("optim_png works with recursive directory optimization", {
  length(result2) == 2 && all(file.exists(result2))
})

# Test directory to directory optimization
test_dir3 = tempfile()
dir.create(test_dir3)
file.copy(create_test_png(), file.path(test_dir3, "test1.png"))
output_dir = tempfile()
result3 = optim_png(test_dir3, output_dir)
assert("optim_png works with directory to directory optimization", {
  dir.exists(output_dir) && length(list.files(output_dir, pattern = "\\.png$")) == 1
})
