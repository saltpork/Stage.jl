using Stage

l = Log(STDERR)
print_with_color(:red, l.output, "this is red\n")
@banner l "logging test"
@error l "error message"
@debug l "debugging message"
@info l "info message"
@warn l "warning message"
@critical l "critical error message"
@sep l
@timer l "test" x = 1
@info l "x = $x"

@banner l "raw printing test"
println(l, "raw println")
print(l, "raw print")
print!(l, ".")
print!(l, ".")
print!(l, ".")
println!(l, "")
println(l, "new message")


