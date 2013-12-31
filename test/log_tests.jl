using Stage

l = Log(STDERR)
@error(l, "error message")
@debug(l, "debugging message")
@info(l, "info message")
@warn(l, "warning message")
@critical(l, "critical error message")

