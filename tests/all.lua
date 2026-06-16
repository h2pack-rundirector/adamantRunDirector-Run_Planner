package.path = "./?.lua;./?/init.lua;" .. package.path

local lu = require("luaunit")
dofile("tests/TestData.lua")
dofile("tests/TestControls.lua")
os.exit(lu.LuaUnit.run())
