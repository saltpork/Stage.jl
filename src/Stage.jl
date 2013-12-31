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
export @fwrap, @stage, @debug, @info, @warn, @error, @critical, Log, Checkpoints, Checkpoint

using Datetime
import Base: fetch, close, write, haskey

function dt2tm(dt :: DateTime)
  tmdt = TmStruct(second(dt), minute(dt), hour(dt), day(dt), month(dt)-1, year(dt)-1900,
                  dayofweek(dt), dayofyear(dt), 0)
  return time(tmdt)
end

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
  Checkpoint(dt2tm(datetime("yyyy-MM-dd HH:mm:ss", dstring * " " * tstring)), name, location)
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
  println(file, strftime("%Y-%m-%d %H:%M:%S", ckpt.date), " ", ckpt.name, " ", ckpt.location)
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
const LOG_LEVELS = [ ("debug", "cyan"), ("info", "normal"), ("warn", "yellow"), ("error", "red"), ("critical", "blue") ]
LOG_LEVEL = 0

type Log
  output :: IO
end

function print(log :: Log, msg...; color = :normal, m_type = "[INFO]")
  prefix = @sprintf("%-18s %-7s ", strftime("%Y-%m-%d %H:%M:%S", time()), m_type)
  Base.print_with_color(color, log.output, prefix, msg..., "\n")
end

for lvl = 1:length(LOG_LEVELS)
  let level = lvl
    label, col = LOG_LEVELS[level]
    x = quote
      macro $(symbol(label))(log, msg...)
        tag   = $("[" * uppercase(label[1:min(5, length(label))]) * "]")
        color = $col
        if LOG_LEVEL <= $level
          :(print($(esc(log)), $(map(esc, msg)...); color = symbol($color), m_type = $tag))
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

macro stage(fn)
  assert(isa(fn, Expr) && fn.head == :function)
  call = fn.args[1]
  body = fn.args[2]
  x    = gensym()
  quote
    function $(esc(call.args[1]))(name, $(call.args[2:end]...))
      @info("starting stage $name")
      try
        $x = haskey(ckpts, name) ? ckpts[name] : $body
        ckpts[name] = $x
      catch 
        error("Unable to execute stage $name")
      end
      if haskey(ckpts, name) 
        @info("stage $name already completed on $(ckpts(name).date)")
      else
        @info("completed stage $name on $(ckpts(name).date)")
      end
      $x
    end
  end
end

end # module