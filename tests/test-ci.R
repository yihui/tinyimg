# run tests on CI only
if (tolower(Sys.getenv('CI')) == 'true') testit::test_pkg('tinyimg', 'test-ci')
