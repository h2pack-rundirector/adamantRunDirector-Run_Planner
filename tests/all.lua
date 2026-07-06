package.path = "./?.lua;./?/init.lua;" .. package.path

local lu = require("luaunit")
dofile("tests/TestFreshSkeleton.lua")
dofile("tests/declarations/TestDeclarationCatalog.lua")
os.exit(lu.LuaUnit.run())
