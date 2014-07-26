using Stage
using Base.Test

@expect 1 == 1
try @expect 1 == 2
catch e
  @test e.msg == "test failed 1 == 2"
end

@expect log(e) == 1.0
try @expect log(e) == 2.0
catch e
  @test e.msg == "test failed log(e) == 2.0"
end

@expect log(e) < 2.0
try @expect log(e) >= 2.0
catch e
  @test e.msg == "test failed log(e) >= 2.0"
end

@expect abs(1.0 - 0.9) < 0.1

