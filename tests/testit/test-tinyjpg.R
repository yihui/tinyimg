library(testit)
library(tinyimg)

# Reuse or create a test JPEG
test_jpg = NULL
create_test_jpg = function(new = FALSE) {
  if (!new && !is.null(test_jpg) && file.exists(test_jpg)) return(test_jpg)
  tmp = tempfile(fileext = ".jpg")
  jpeg(tmp, width = 400, height = 400)
  plot(1:10)
  dev.off()
  test_jpg <<- tmp
  tmp
}

create_test_jpg()

# Basic round-trip
assert("tinyjpg() ran successfully", {
  (tinyjpg(test_jpg) %==% test_jpg)
  (file.exists(test_jpg))
})

# Output to a new file
assert("tinyjpg() created output file", {
  out = tempfile(fileext = ".jpg")
  (tinyjpg(test_jpg, out) %==% out)
  (file.exists(out))
})

# Quality levels
assert("tinyjpg() works with quality = 30", {
  out = tempfile(fileext = ".jpg")
  tinyjpg(test_jpg, out, quality = 30)
  (file.exists(out))
})

assert("tinyjpg() works with quality = 95", {
  out95 = tempfile(fileext = ".jpg")
  out30 = tempfile(fileext = ".jpg")
  tinyjpg(test_jpg, out95, quality = 95)
  tinyjpg(test_jpg, out30, quality = 30)
  (file.exists(out95))
  # higher quality should produce a larger (or equal) file
  (file.size(out95) >= file.size(out30))
})

# Non-existent input
assert("tinyjpg() fails with non-existent file", {
  (has_error(tinyjpg(tempfile(fileext = ".jpg"))))
})

# Verbose = FALSE
assert("tinyjpg() works with verbose = FALSE", {
  out = tempfile(fileext = ".jpg")
  tinyjpg(test_jpg, out, verbose = FALSE)
  (file.exists(out))
})

# Directory input
assert("tinyjpg() works with directory input", {
  d = tempfile()
  dir.create(d)
  for (i in 1:3) file.copy(test_jpg, file.path(d, paste0("test", i, ".jpg")))
  result = tinyjpg(d)
  (length(result) %==% 3L)
  (file.exists(result))
})

# Recursive directory input
assert("tinyjpg() works with recursive directory optimization", {
  d = tempfile()
  dir.create(d)
  sub = file.path(d, "sub")
  dir.create(sub)
  file.copy(test_jpg, file.path(d,   "test1.jpg"))
  file.copy(test_jpg, file.path(sub, "test2.jpg"))
  result = tinyjpg(d, recursive = TRUE)
  (length(result) %==% 2L)
  (file.exists(result))
})

# Directory to directory
assert("tinyjpg() works with directory to directory optimization", {
  d_in  = tempfile()
  d_out = tempfile()
  dir.create(d_in)
  file.copy(test_jpg, file.path(d_in, "test1.jpg"))
  result = tinyjpg(d_in, d_out)
  (dir.exists(d_out))
  (length(list.files(d_out, pattern = "\\.jpg$")) %==% 1L)
})
