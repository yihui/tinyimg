# For more info, see https://pkg.yihui.org/tinyimg/

test_plot = function(expr, filename = tempfile(fileext = '.png'), ...) {
  png(filename, ...)
  expr
  dev.off()
  filename
}

#| results = 'asis'
out = test_plot({
  par(mar = c(4, 4, 1, .1))
  with(penguins, plot(bill_len ~ bill_dep, pch = 19, col = species))
})
xfun::html_tag("img", src = xfun::base64_uri(out), alt = "Original")

tinyimg::tinypng(out)
xfun::html_tag("img", src = xfun::base64_uri(out), alt = "Optimized")
