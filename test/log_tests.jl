using Stage

# global log
@banner "test"
@error "fuck!"
@debug "is it fucked?"
@info "look"
@warn "dude, look"
@critical "fuuuuucccckkkkkk!"
@sep
@timer "how long does this take" begin
  sleep(1)
  y = 42
end
@expect y == 42
@info "y = $y"

# local log
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
@expect x == 1
@info l "x = $x"

@banner l "raw printing test"
println(l, "raw println")
print(l, "raw print")
print!(l, ".")
print!(l, ".")
print!(l, ".")
println!(l, "")
println(l, "new message")


