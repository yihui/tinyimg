# For more info, see https://pkg.yihui.org/tinyimg/
tmp = tempfile(fileext = '.png')
png(tmp, width = 400, height = 400)
plot(1:10)
dev.off()

tinypng::tinyimg(tmp)
