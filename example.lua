-- Copyright (C) 2018 Alexey Kopytov <akopytov@gmail.com>
--
-- This code is licensed under the MIT license, see LICENSE.

--[[
An example benchmark written using the sysbench Lua API.

To install from local Git tree:
  luarocks make --local

To install from SysbenchRocks:
  luarocks --server=rocks.sysbench.io --local install example

Try running the following commands after installation (with N and M being
positive integers of your choice):

sysbench example help
sysbench example --counters=N --threads=M prepare
sysbench example --counters=N --threads=M run
sysbench example --counters=N aggregate
sysbench example cleanup
--]]

--[[
------------------------------------------------------------------------
Command line option handling.

Benchmark-specific command line options are defined as a Lua table with the
sysbench.cmdline.options name.

Each element in the table is a key/value pair with the string option name as a
key and another table describing the option as a value, i.e.:

sysbench.cmdline.options = {
  opt_name = {opt_description, opt_default, opt_type},
  ...
}

opt_description is what "sysbench help" will print next to the option
name. opt_default is a default value, and opt_type is an option type which may
be one of the following values:

sysbench.cmdline.ARG_BOOL
sysbench.cmdline.ARG_INT
sysbench.cmdline.ARG_SIZE
sysbench.cmdline.ARG_DOUBLE
sysbench.cmdline.ARG_STRING
sysbench.cmdline.ARG_LIST
sysbench.cmdline.ARG_FILE

Both opt_default and opt_type are optional. When opt_default is missing,
sysbench will nto assign a default value to the option. When opt_type is
missing, sysbench will try to infer option type from its default value, or
assume string type, if the there is not default value.

Option names may use dashes ("-") and underscores ("_") interchangeably -- they
are both treated as equal characters by sysbench when it parses command line
arguments. The only difference is that the Lua syntax requires quoting keys that
contain dashes or start with numbers. That is, the following definitions are
equivalent:

my_opt = {"My option", "default"}
"my-opt" = {"My option", "default"}

Values passed on the command line (or defaults) are available as
sysbench.opt.opt_name for both general sysbench options and custom ones defined
in a benchmark script.
------------------------------------------------------------------------
--]]

sysbench.cmdline.options = {
  counters = {"Number of counter tables to create/use", 1}
}

--[[
Custom commands.

In addition to default commands provided by sysbench (e.g. "prepare", "run" or
"cleanup"), a benchmark script may define its own commands by defining a table
named sysbench.cmdline.commands, which must have the following format:

cmd_name = {cmd_func, cmd_type}

cmd_func is a Lua function that will be executed when "sysbench cmd_name" is
executed. cmd_type is an optional command type specification. The only currently
supported type is sysbench.cmdline.PARALLEL_COMMAND which tells sysbench the
command is safe to execute in a multi-threaded context. That is,
when --threads>1 is specified on the command line, sysbench will create multiple
threads calling cmd_func for parallel commands, and only a single thread if no
type is specified.
--]]

sysbench.cmdline.commands = {
  -- "sysbench prepare" will create counter tables in multiple threads
  -- if called with --threads>1 and --counters>1
  prepare = {
    function ()
      local c = sysbench.sql.driver():connect()
      for i = sysbench.tid % sysbench.opt.threads + 1,
              sysbench.opt.counters,
              sysbench.opt.threads
      do
        print(("Creating counter %d..."):format(i))
        c:query(("CREATE TABLE IF NOT EXISTS counter%d(value INT)"):format(i))
      end
    end, sysbench.cmdline.PARALLEL_COMMAND
  },

  -- "sysbench cleanup" will DROP all counter tables in a single thread
  cleanup = {
    function ()
      local c = sysbench.sql.driver():connect()
      for i = 1, sysbench.opt.counters do
        print(("Dropping counter %d..."):format(i))
        c:query(("DROP TABLE IF EXISTS counter%d"):format(i))
      end
    end
  },

  -- "sysbench aggregate" will print the sum of all counter values
  aggregate = {
    function ()
      local c = sysbench.sql.driver():connect()
      local sum = 0
      for i = 1, sysbench.opt.counters do
        sum = sum + c:query_row(("SELECT value FROM counter%d"):format(i))
      end
      print("Sum of all counters: " .. sum)
    end
  }
}

--[[
init()

This hook is called when "sysbench run" is executed before creating and
initializing worker threads. It can be used to do pre-flight checks that
benchmark was started in a sane environment and do global initialization that
are independent of worker thread states. Note that this hook is called in its
own 'master' thread, so all global variables and connections will not be
available to worker threads.
--]]
function init()
  print("Initializing counter(s)...")
  c = sysbench.sql.driver():connect()
  -- Reset counters before starting the actual benchmark run
  for i = 1, sysbench.opt.counters do
    c:query(("DELETE FROM counter%d"):format(i))
    c:query(("INSERT INTO counter%d VALUES(0)"):format(i))
  end
end

--[[
thread_init()

This hook is called in each worker thread when "sysbench run" is executed and is
normally used to create perform worker-specific initialization, e.g. create a
database connection used by each worker. sysbench requires all threads to be
initialized (i.e. thread_init() in all functions to return) before starting the
actual benchmark and measuring time.
--]]
function thread_init()
  -- Each worker thread gets its own Lua interpreter state. So the following
  -- variable is intentionally created in the global scope, so its value will be
  -- available to other functions executed in the same worker thread.
  c = sysbench.sql.driver():connect()
end

--[[
event()

This is the only mandatory hook that sysbench expects in any benchmark
script. It is what sysbench calls in a loop in each worker thread on "sysbench
run". We use connection created by thread_init() here.
--]]
function event()
  -- Increment/decrement a random counter with a random value
  c:query(("UPDATE counter%d SET value = value + %d"):format(
      -- For a counter number, use a pseudo-random number distributed according
      -- to --rand-type option on the sysbench command line
      sysbench.rand.default(1, sysbench.opt.counters),
      -- For an increment value, use a uniformly distributed number in the
      -- [-100, 100] range, overriding the --rand-type command line option
      sysbench.rand.uniform(0, 200) - 100))
end

--[[
thread_done()

This is the opposite of thread_init(), i.e. called in each worker thread after
stopping the benchmark and timers. We close the database connection created in
thread_init() for demo purposes here, but that's unnecessary, because that would
be performed automatically by sysbench and the Lua garbage collector when
closing Lua state for each worker.
--]]
function thread_done()
  c:disconnect()
end

--[[
done()

This hook is called after de-initializing and terminating worker threads. This
is called in the same 'master' thread and thus shares the same Lua interpreter
with the init() hook. So we use the same database connection created by init()
and then close it.
--]]
function done()
  print("Counter values:")
  for i = 1, sysbench.opt.counters do
    local value = c:query_row(("SELECT value FROM counter%d"):format(i))
    print(("%5d: %d"):format(i, value))
  end
  c:disconnect()
end
