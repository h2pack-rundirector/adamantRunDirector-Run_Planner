package.path = "./?.lua;./?/init.lua;" .. package.path

local lu = require("luaunit")
dofile("tests/TestResetSkeleton.lua")
dofile("tests/TestCatalogFoundation.lua")
dofile("tests/TestBiomeSupport.lua")
dofile("tests/TestRewardHierarchy.lua")
dofile("tests/TestRoomTemplates.lua")
dofile("tests/TestManagedPersistence.lua")
dofile("tests/TestBiomePlan.lua")
os.exit(lu.LuaUnit.run())
