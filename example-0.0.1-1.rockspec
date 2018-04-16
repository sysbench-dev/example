package = "example"
version = "0.0.1-1"

description = {
  summary = "An example benchmark written using the sysbench Lua API.",
  detailed = [[
Try running the following commands after installation (with N and M being
positive integers of your choice):

sysbench example help
sysbench example --counters=N --threads=M prepare
sysbench example --counters=N --threads=M run
sysbench example --counters=N aggregate
sysbench example cleanup
]],
  homepage = "https://github.com/sysbench-dev/example",
  license = "MIT"
}

source = {
  url = "git+https://github.com/sysbench-dev/example"
}

dependencies = {
  "lua == 5.1"
}

build = {
  type = "builtin",
  modules = {
    example = "example.lua"
  }
}
