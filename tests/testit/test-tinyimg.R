library(testit)
library(tinyimg)

# Create test images
create_png = function() {
  tmp = tempfile(fileext = ".png")
  png(tmp, width = 400, height = 400)
  plot(1:10)
  dev.off()
  tmp
}

create_jpg = function() {
  tmp = tempfile(fileext = ".jpg")
  jpeg(tmp, width = 400, height = 400)
  plot(1:10)
  dev.off()
  tmp
}

test_png = create_png()
test_jpg = create_jpg()

# Mixed vector of files
assert("tinyimg() optimizes both PNG and JPEG in a vector", {
  result = tinyimg(c(test_png, test_jpg))
  (length(result) %==% 2L)
  (file.exists(result))
})

# Directory with both PNG and JPEG files
assert("tinyimg() optimizes a directory with mixed formats", {
  d = tempfile()
  dir.create(d)
  file.copy(test_png, file.path(d, "plot.png"))
  file.copy(test_jpg, file.path(d, "photo.jpg"))
  result = tinyimg(d, verbose = FALSE)
  (length(result) %==% 2L)
  (file.exists(result))
})

# Directory with only PNG files
assert("tinyimg() handles a directory with only PNG files", {
  d = tempfile()
  dir.create(d)
  file.copy(test_png, file.path(d, "plot.png"))
  result = tinyimg(d, verbose = FALSE)
  (length(result) %==% 1L)
  (file.exists(result))
})

# Directory with only JPEG files
assert("tinyimg() handles a directory with only JPEG files", {
  d = tempfile()
  dir.create(d)
  file.copy(test_jpg, file.path(d, "photo.jpg"))
  result = tinyimg(d, verbose = FALSE)
  (length(result) %==% 1L)
  (file.exists(result))
})

# Output directory
assert("tinyimg() writes to an output directory", {
  d_in  = tempfile()
  d_out = tempfile()
  dir.create(d_in)
  file.copy(test_png, file.path(d_in, "plot.png"))
  file.copy(test_jpg, file.path(d_in, "photo.jpg"))
  result = tinyimg(d_in, d_out, verbose = FALSE)
  (dir.exists(d_out))
  (length(list.files(d_out)) %==% 2L)
})

# Output function
assert("tinyimg() accepts an output function", {
  make_out = function(x) sub("\\.(png|jpg)$", "-opt.\\1", x)
  result = tinyimg(c(test_png, test_jpg), output = make_out, verbose = FALSE)
  (length(result) %==% 2L)
  (file.exists(result))
})

# Recursive directory
assert("tinyimg() works recursively", {
  d = tempfile()
  sub = file.path(d, "sub")
  dir.create(d)
  dir.create(sub)
  file.copy(test_png, file.path(d,   "plot.png"))
  file.copy(test_jpg, file.path(sub, "photo.jpg"))
  result = tinyimg(d, recursive = TRUE, verbose = FALSE)
  (length(result) %==% 2L)
  (file.exists(result))
})

# Empty directory returns zero-length result
assert("tinyimg() handles an empty directory", {
  d = tempfile()
  dir.create(d)
  result = tinyimg(d, verbose = FALSE)
  (length(result) %==% 0L)
})
