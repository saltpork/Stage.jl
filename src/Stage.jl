# Copyright 2013 Wade Shen
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module Stage
export @debug, @info, @warn, @error, @critical, @timer, @sep, @banner, Log, merge, print, print!, println, println!
export Checkpoints, Checkpoint, global_checkpoints, fetch
export @expect, @approx
export @fwrap, @stage
export getfile

import Base: fetch, close, write, haskey, merge, print, println, getindex, setindex!

# -------------------------------------------------------------------------------------------------
# global date constants
# -------------------------------------------------------------------------------------------------
const date_format = "yyyy-mm-dd HH:MM:SS.sss"

# -------------------------------------------------------------------------------------------------
# Checkpoint stub
# -------------------------------------------------------------------------------------------------
mutable struct Checkpoint
  date :: DateTime
  name :: AbstractString
  location :: AbstractString
end

function Checkpoint(line :: AbstractString)
  dstring, tstring, name, location = split(line, " ")
  Checkpoint(DateTime(dstring * " " * tstring, date_format), name, location)
end

function fetch(ckpt :: Checkpoint) # get the value of this checkpoint, mimic remote refs
  f   = open(ckpt.location, "r")
  res = deserialize(f)
  close(f)
  res
end

# -------------------------------------------------------------------------------------------------
# Checkpoint container
# -------------------------------------------------------------------------------------------------
mutable struct Checkpoints
  base :: AbstractString
  status :: Dict{AbstractString, Checkpoint}
end

function Checkpoints(dir) 
  ret = Checkpoints(dir, Dict{AbstractString, Checkpoint}())
  if isdir(ret.base)
    read(ret)
  end
  return ret
end

function read(ckpts :: Checkpoints)
  f = open(joinpath(ckpts.base, "ckpts"), "r")
  for l in eachline(f)
    ckpt = Checkpoint(strip(l))
    ckpts.status[ckpt.name] = ckpt
  end
  close(f)
end

function write{T}(ckpts :: Checkpoints, ckpt :: Checkpoint, value :: T) # write checkpoint metadata and value to file
  # write data
  if !isdir(ckpts.base) mkdir(ckpts.base) end
  f = open(ckpt.location, "w")
  serialize(f, value)
  close(f)

  # write metadata
  f = open(joinpath(ckpts.base, "ckpts"), "a+")
  println(f, Dates.format(ckpt.date, date_format), " ", ckpt.name, " ", ckpt.location)
  flush(f)
  close(f)
end

getindex(ckpts :: Checkpoints, key :: AbstractString) = ckpts.status[key]
haskey(ckpts :: Checkpoints, key :: AbstractString) = haskey(ckpts.status, key)

function setindex!{T}(ckpts :: Checkpoints, value :: T, key :: AbstractString) 
  ckpts.status[key] = Checkpoint(Dates.now(), key, joinpath(ckpts.base, key))
  write(ckpts, ckpts.status[key], value)
end

# -------------------------------------------------------------------------------------------------
# logging stub
# -------------------------------------------------------------------------------------------------
# levels: 1 = debug, 2 = info, 3 = warn, 4 = error, 5 = critical, 0 = all
const LOG_LEVELS = [ ("debug", "cyan"), ("info", "normal"), ("warn", "yellow"), ("error", "red"), ("critical", "blue"), ("success", "green") ]
LOG_LEVEL = 0

struct Log
  output :: IO
end
Log() = Log(IOBuffer())

function print!(log :: Log, msg...; color = :normal)
  Base.print_with_color(color, log.output, [ string(x) for x in msg ]...)
end
function print(log :: Log, msg...; color = :normal, m_type = "[INFO]")
  prefix = @sprintf("%-18s %-7s ", Dates.format(now(), date_format), m_type)
  Base.print_with_color(color, log.output, prefix, [ string(x) for x in msg ]...)
end

function println(log :: Log, msg...; color = :normal, m_type = "[INFO]")
  print(log, msg..., "\n"; color = color, m_type = m_type)
end

function println!(log :: Log, msg...; color = :normal)
  print!(log, msg..., "\n"; color = color)
end

macro timer(args...)
  if length(args) == 3
    log  = args[1]
    name = args[2]
    expr = args[3]
  elseif length(args) == 2
    log  = global_log
    name = args[1]
    expr = args[2]
  else
    error("timer() must be called with either 2 (string, expr) or 3 (log, string, expr) arguments")
  end
  quote
    println($(esc(log)), "starting ", $(esc(name)); m_type = "[START]", color = :magenta)
    local t0 = time_ns()
    $(esc(expr))
    local t1 = time_ns()
    println($(esc(log)), "finished ", $(esc(name)), @sprintf(" took [%.2f seconds]", (t1-t0)/1e9); m_type = "[END]", color = :magenta)
  end
end

macro sep(args...)
  if length(args) == 1
    log  = args[1]
  elseif length(args) == 0
    log  = global_log
  else
    error("sep() must be called with either 0 () or 1 (log) arguments")
  end
  :(println($(esc(log)), "-" ^ 100; color = :bold, m_type = "[---]"))
end

macro banner(args...)
  if length(args) == 2
    log   = args[1]
    title = args[2]
  elseif length(args) == 1
    log   = global_log
    title = args[1]
  else
    error("banner() must be called with either 1 (string) or 2 (log, string) arguments")
  end
  quote
    residual = round(Int, max(98 - length($(esc(title))), 20) / 2)
    println("resxxxx === " * string(residual))
    println($(esc(log)), "-" ^ residual, " ", $(esc(title)), " ", "-" ^ residual; color = :bold, m_type = "[TITLE]")
  end
end

macro test_pass(args...)
  tag   = "[TEST]"
  color = "green"
  if length(args) == 1
    log = global_log
    msg = args[1]
  elseif length(args) == 2
    log = args[1]
    msg = args[2]
  else
    error("test_pass() must be called with either 1 (string) or 2 (log, string) arguments")
  end
  quote
    residual = round(Int, max(98 - length($(esc(msg))) - 6, 20))
    println($(esc(log)), $(esc(msg)), " " ^ residual, "[PASS]", color = Symbol($color), m_type = $tag)
  end
end

macro test_fail(args...)
  tag   = "[TEST]"
  color = "red"
  if length(args) == 1
    log = global_log
    msg = args[1]
  elseif length(args) == 2
    log = args[1]
    msg = args[2]
  else
    error("test_fail() must be called with either 1 (string) or 2 (log, string) arguments")
  end
  quote
    residual = round(Int, max(98 - length($(esc(msg))) - 6, 20))
    println($(esc(log)), $(esc(msg)), " " ^ residual, "[FAIL]", color = Symbol($color), m_type = $tag)
  end
end

function merge(l1 :: Log, l2 :: Log)
  seekstart(l2.output)
  for l in readlines(l2.output)
    println(l1.output, l)
  end
end

for lvl = 1:length(LOG_LEVELS)
  let level = lvl
    label, col = LOG_LEVELS[level]
    x = quote
      macro $(Symbol(label))(args...)
        tag   = $("[" * uppercase(label[1:min(5, length(label))]) * "]")
        color = $col
        if length(args) == 1
          log = global_log
          msg = args[1]
        elseif length(args) == 2
          log = args[1]
          msg = args[2]
        else
          error("$label() must be called with either 1 (string) or 2 (log, string) arguments")
        end
        if LOG_LEVEL <= $level
          :(println($(esc(log)), $(esc(msg)), color = Symbol($color), m_type = $tag))
        else
          :nothing
        end
      end
    end
    eval(x)
  end
end

# -------------------------------------------------------------------------------------------------
# macro that defines a function
# -------------------------------------------------------------------------------------------------
macro fwrap(fname, args_and_body...)
  ef = esc(fname)
  ea = args_and_body
  args = ea[1:end-1]
  quote
    function ($ef)($(map(y -> y, args)...))
      $(ea[end])
    end
  end
end

# walk the AST and replace symbols A with fetch(A)
# should make this tail recursive at some point
function clean_remoterefs(expr, names)
  if isa(expr, Expr)
    if (expr.head == :call)
      return Expr(expr.head, [expr.args[1], [ clean_remoterefs(a, names) for a in expr.args[2:end] ]... ])
    else
      return Expr(expr.head, [ clean_remoterefs(a, names) for a in expr.args ])
    end
  elseif isa(expr, Symbol)
    return Expr(:call, [ :fetch, expr ])
  else
    return expr
  end
end

macro stage(fn)
  assert(isa(fn, Expr) && fn.head == :function)

  call  = fn.args[1]
  body  = fn.args[2]
  fargs = [ Symbol("dead_" * string(sym) * "_beef") for sym in call.args[2:end] ]
  block = Expr(:block, [ :($sym = fetch($(Symbol("dead_" * string(sym) * "_beef")))) for sym in call.args[2:end] ]...)
  x     = gensym()
  quote
    #function $(esc(call.args[1]))(name, $(call.args[2:end]...); logger = Log(), ckpts = global_checkpoints)
    function $(esc(call.args[1]))(name, $(fargs...); logger = global_log, ckpts = global_checkpoints)
      $block
      local_log = Log()
      @sep(local_log)
      @info(local_log, @sprintf("%-60s start execution", name))
      $x = 
        if haskey(ckpts, name)
          @info(local_log, @sprintf("%-60s already completed [%s]", name, Dates.format(ckpts[name].date, date_format)))
          @sep(local_log)
          merge(logger, local_log)
          fetch(ckpts[name])
        else
          res = @spawn $body
          @schedule begin 
            r = fetch(res)
            if isa(r, Exception)
              @error(local_log, @sprintf("%-60s Unable to execute", name))
              @error(local_log, string(" - ERROR: ", r))
            else
              ckpts[name] = r
              @info(local_log, @sprintf("%-60s completed [%s]", name, Dates.format(ckpts[name].date, date_format)))
            end
            @sep(local_log)
            merge(logger, local_log)
          end
          res
        end
      # catch e
      #   @error(local_log, "Unable to execute stage $name")
      #   @error(local_log, string(e))
      #   Base.show_backtrace(local_log.output, catch_backtrace()) # NOTE: not writing to logger!
      # end
      $x
    end
  end
end

# -------------------------------------------------------------------------------------------------
# module globals
# -------------------------------------------------------------------------------------------------
global_checkpoints = Checkpoints(".ckpts")
global_log         = Log(STDERR)
comparisons        = Set([ :>, :<, Symbol("=="), :!=, :<=, :>=, :in, :∉ ])

# -------------------------------------------------------------------------------------------------
# expect and fuzzy_expect
# -------------------------------------------------------------------------------------------------
macro expect(args...)
  if length(args) == 2
    log  = args[1]
    expr = args[2]
  elseif length(args) == 1
    log   = global_log
    expr = args[1]
  else
    error("expect() must be called with either 1 (expr) or 2 (log, expr) arguments")
  end
  if expr.head != :call && length(expr.args) != 3 && expr.args[1] ∉ comparisons
    error("expect() requires that its argument (expr) be a comparison")
  end

  a    = expr.args[2]
  b    = expr.args[3]
  nexp = Expr(:call, expr.args[1], :la, :lb)
  sexp = string(expr)
  st   = length(sexp) > 70 ? sexp[1:min(end, 66)] * " ..." : sexp
  quote
    let la = $(esc(a)),
        lb = $(esc(b)),
        st = $(esc(st))
      if $nexp
        @test_pass $log "$st"
      else
        @test_fail $log "$st"
        @error $log     " + left  side: $la"
        @error $log     " + right side: $lb"
        error("test failed $st")
      end
    end
  end
end

# -------------------------------------------------------------------------------------------------
# other utilities
# -------------------------------------------------------------------------------------------------
function getfile(url, fn; expected_size = -1, logger = Log(STDERR))
  if filesize(fn) != expected_size
    @timer logger "downloading $fn from $url" download(url, fn)
  else
    @error logger "$fn already downloaded, using local version."
  end
end

end # module
