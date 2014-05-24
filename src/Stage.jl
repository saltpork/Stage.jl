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
export @fwrap, @stage

using Datetime
import Base: fetch, close, write, haskey, merge, print, println

function dt2tm(dt :: DateTime)
  tmdt = TmStruct(second(dt), minute(dt), hour(dt), day(dt), month(dt)-1, year(dt)-1900,
                  dayofweek(dt), dayofyear(dt), 0)
  return time(tmdt)
end

# -------------------------------------------------------------------------------------------------
# global date constants
# -------------------------------------------------------------------------------------------------
const ftime_format = "%Y-%m-%d %H:%M:%S"
const date_format  = "yyyy-MM-dd HH:mm:ss"

# -------------------------------------------------------------------------------------------------
# Checkpoint stub
# -------------------------------------------------------------------------------------------------
type Checkpoint
  date :: Real
  name :: String
  location :: String
end

function Checkpoint(line :: String)
  dstring, tstring, name, location = split(line, " ")
  Checkpoint(dt2tm(datetime(date_format, dstring * " " * tstring)), name, location)
end

function fetch(ckpt :: Checkpoint) # get the value of this checkpoint, mimic remote refs
  f   = open(ckpt.location, "r")
  res = deserialize(f)
  close(f)
  res
end

function write{T}(file :: IO, ckpt :: Checkpoint, value :: T) # write checkpoint metadata and value to file
  # write data
  f = open(ckpt.location, "w")
  serialize(f, value)
  close(f)

  # write metadata
  println(file, strftime(ftime_format, ckpt.date), " ", ckpt.name, " ", ckpt.location)
  flush(file)
end

# -------------------------------------------------------------------------------------------------
# Checkpoint container
# -------------------------------------------------------------------------------------------------
type Checkpoints
  file :: IO
  base :: String
  status :: Dict{String, Checkpoint}
end

function Checkpoints(dir) 
  if !isdir(dir) mkdir(dir) end
  f = open(joinpath(dir, "ckpts"), "a+")
  seekstart(f)
  status = (String => Checkpoint)[]
  for l in eachline(f)
    ckpt = Checkpoint(strip(l))
    status[ckpt.name] = ckpt
  end
  Checkpoints(f, dir, status)
end
close(ckpts :: Checkpoints) = close(ckpts.file)

getindex(ckpts :: Checkpoints, key :: String) = ckpts.status[key]
haskey(ckpts :: Checkpoints, key :: String) = haskey(ckpts.status, key)
function setindex!{T}(ckpts :: Checkpoints, value :: T, key :: String) 
  ckpts.status[key] = Checkpoint(time(), key, joinpath(ckpts.base, key))
  write(ckpts.file, ckpts.status[key], value)
end

# -------------------------------------------------------------------------------------------------
# logging stub
# -------------------------------------------------------------------------------------------------
# levels: 1 = debug, 2 = info, 3 = warn, 4 = error, 5 = critical, 0 = all
const LOG_LEVELS = [ ("debug", "cyan"), ("info", "normal"), ("warn", "yellow"), ("error", "red"), ("critical", "blue"), ("success", "green") ]
LOG_LEVEL = 0

type Log
  output :: IO
end
Log() = Log(IOBuffer())

function print!(log :: Log, msg...; color = :normal)
  Base.print_with_color(color, log.output, [ string(x) for x in msg ]...)
end
function print(log :: Log, msg...; color = :normal, m_type = "[INFO]")
  prefix = @sprintf("%-18s %-7s ", strftime(ftime_format, time()), m_type)
  Base.print_with_color(color, log.output, prefix, [ string(x) for x in msg ]...)
end
println(log :: Log, msg...; color = :normal, m_type = "[INFO]") = print(log, msg..., "\n"; color = color, m_type = m_type)
println!(log :: Log, msg...; color = :normal) = print!(log, msg..., "\n"; color = color)


macro timer(log, name, expr)
  quote
    println($(esc(log)), "starting ", $(esc(name)); m_type = "[START]", color = :magenta)
    local t0 = time_ns()
    $(esc(expr))
    local t1 = time_ns()
    println($(esc(log)), "finished ", $(esc(name)), @sprintf(" took [%.2f seconds]", (t1-t0)/1e9); m_type = "[END]", color = :magenta)
  end
end

macro sep(log)
  :(println($(esc(log)), "-" ^ 100; color = :bold, m_type = "[---]"))
end

macro banner(log, title)
  quote
    residual = int(max(98 - length($(esc(title))), 20) / 2)
    println($(esc(log)), "-" ^ residual, " ", $(esc(title)), " ", "-" ^ residual; color = :bold, m_type = "[TITLE]")
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
      macro $(symbol(label))(log, msg...)
        tag   = $("[" * uppercase(label[1:min(5, length(label))]) * "]")
        color = $col
        if LOG_LEVEL <= $level
          :(println($(esc(log)), $(map(esc, msg)...); color = symbol($color), m_type = $tag))
        else
          :nothing
        end
      end
    end
    eval(x)
  end
end

# -------------------------------------------------------------------------------------------------
# module globals
# -------------------------------------------------------------------------------------------------
global_checkpoints = Checkpoints(".ckpts")
global_log         = Log(STDERR)

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
  fargs = [ symbol("dead_" * string(sym) * "_beef") for sym in call.args[2:end] ]
  block = Expr(:block, [ :($sym = fetch($(symbol("dead_" * string(sym) * "_beef")))) for sym in call.args[2:end] ]...)
  x     = gensym()
  quote
    #function $(esc(call.args[1]))(name, $(call.args[2:end]...); logger = Log(), ckpts = global_checkpoints)
    function $(esc(call.args[1]))(name, $(fargs...); logger = global_log, ckpts = global_checkpoints)
      $block
      local_log = Log()
      sep(local_log)
      @info(local_log, @sprintf("%-60s start execution", name))
      $x = 
        if haskey(ckpts, name)
          @info(local_log, @sprintf("%-60s already completed [%s]", name, strftime(ftime_format, ckpts[name].date)))
          sep(local_log)
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
              @info(local_log, @sprintf("%-60s completed [%s]", name, strftime(ftime_format, ckpts[name].date)))
            end
            sep(local_log)
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

end # module