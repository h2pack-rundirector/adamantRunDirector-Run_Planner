package.path = "./?.lua;./?/init.lua;" .. package.path

local lu = require("luaunit")
dofile("tests/TestResetSkeleton.lua")
dofile("tests/TestCatalogFoundation.lua")
dofile("tests/TestManagedPersistence.lua")
os.exit(lu.LuaUnit.run())
