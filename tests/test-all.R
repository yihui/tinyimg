library(testit)
test_pkg("tinyimg")
if (tolower(Sys.getenv('CI')) == 'true') test_pkg('tinyimg', 'test-ci')
