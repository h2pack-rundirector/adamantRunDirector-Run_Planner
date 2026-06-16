package.path = "./?.lua;./?/init.lua;" .. package.path

local lu = require("luaunit")
dofile("tests/TestData.lua")
os.exit(lu.LuaUnit.run())
