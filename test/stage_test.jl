using Stage

# test the macros
@stage function add(a, b)
  sleep(10)
  a + b
end
@stage function mult(a, b)
  sleep(2)
  a * b
end
@stage function sub(a, b)
  sleep(2)
  a - b
end

@debug "initiating test"
res2 = sub("sub2", sub("sub", mult("mult", 4, 3), 2), 2)
res_future = add("add", mult("mult2", 1, 2), 3)
@debug "mult result: $(fetch(res2))"
@debug "madd result: $(fetch(res_future))"

res3 = sub("s1", mult("m1", 4, 3), mult("m2", 5, 6))
@expect res3 == -18
@debug "res3 = $(fetch(res3)) [should be -18 and should have taken approx. 4 seconds]"

res4 = sub("sub2", mult("m1", 4, 3), mult("m2", 5, 6))
@expect res4 == 8
@debug "res4 = $(fetch(res4)) [should be 8 and should have taken approx. 0 seconds]"
@debug "completed test"
