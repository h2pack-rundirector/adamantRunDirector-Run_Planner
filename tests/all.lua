package.path = "./?.lua;./?/init.lua;" .. package.path

local lu = require("luaunit")
dofile("tests/TestFreshSkeleton.lua")
os.exit(lu.LuaUnit.run())
