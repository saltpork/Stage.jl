using Stage
using Base.Test

ckpts = Checkpoints(".ckpts")
testdata = { 10, "test-2", { "test" => 1, "test2" => 2 }, [1 2; 3 4] }

logger = Log(STDERR)
for i = 1:length(testdata)
  if !haskey(ckpts, "test-$i")
    ckpts["test-$i"] = testdata[i]
  end
  @info(logger, "running test $i")
  @test haskey(ckpts, "test-$i")
  @test fetch(ckpts["test-$i"]) == testdata[i]
end

