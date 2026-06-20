package.path = "./?.lua;./?/init.lua;" .. package.path

local lu = require("luaunit")
dofile("tests/TestData.lua")
dofile("tests/TestTimeline.lua")
dofile("tests/TestControls.lua")
dofile("tests/TestRewards.lua")
dofile("tests/TestNpcs.lua")
dofile("tests/TestFeatures.lua")
dofile("tests/TestLogic.lua")
os.exit(lu.LuaUnit.run())
