using Stage
using Base.Test

logger = Log(STDERR)
# test the macros
@stage function tester(a, b)
  a + b
end

@debug(logger, "initiating test")
res_future, res_log = fetch(@spawn tester("Test", 1, 2))
merge(logger, res_log)
@debug(logger, "tester result: $res_future")
@debug(logger, "completed test")
