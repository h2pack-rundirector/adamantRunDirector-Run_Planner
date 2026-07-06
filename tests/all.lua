package.path = "./?.lua;./?/init.lua;" .. package.path

local lu = require("luaunit")
dofile("tests/TestFreshSkeleton.lua")
dofile("tests/declarations/TestDeclarationCatalog.lua")
dofile("tests/forms/TestRouteForm.lua")
os.exit(lu.LuaUnit.run())
