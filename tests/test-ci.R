# run tests on CI only
if (tolower(Sys.getenv('CI')) == 'true' && .Platform$OS.type == 'unix') testit::test_pkg('tinyimg', 'test-ci')
