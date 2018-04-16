# `sysbench` Module Example

This is an example project implementing a simple benchmark using the [sysbench](https://github.com/akopytov/sysbench) Lua API.

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

# Useful links

- [Lua Style Guide](https://github.com/luarocks/lua-style-guide) which is used by the LuaRocks project
- [Numerical Computing Performance Guide](http://wiki.luajit.org/Numerical-Computing-Performance-Guide) --
  a guide on writing efficient LuaJIT code from Mike Pall, the LuaJIT creator
- [Lua Performance Tips](http://www.lua.org/gems/sample.pdf)(PDF) -- a guide on high-performance Lua code from Roberto Ierusalimschy, the Lua creator.
