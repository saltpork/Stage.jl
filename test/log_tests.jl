using Stage

l = Log(STDERR)
@banner l "logging test"
@error l "error message"
@debug l "debugging message"
@info l "info message"
@warn l "warning message"
@critical l "critical error message"
@sep l
@timer l "test" x = 1
@info l "x = $x"


