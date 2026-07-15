package.path = "./?.lua;./?/init.lua;" .. package.path

local lu = require("luaunit")
dofile("tests/TestResetSkeleton.lua")
dofile("tests/TestCatalogFoundation.lua")
os.exit(lu.LuaUnit.run())
