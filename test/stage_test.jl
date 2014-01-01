using Stage
using Base.Test

l = Log(STDERR)

# test the macros
@stage function add(a, b)
  sleep(10)
  a + b
end
@stage function mult(a, b)
  sleep(2)
  a * b
end

@debug(l, "initiating test")
res_future = mult("mult", add("add", 1, 2), 3)
res2 = mult("mult2", 2, 3)
@debug(l, "mult result: $(fetch(res2))")
@debug(l, "madd result: $(fetch(res_future))")
@debug(l, "completed test")
