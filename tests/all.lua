package.path = "./?.lua;./?/init.lua;" .. package.path

local lu = require("luaunit")
dofile("tests/TestFreshSkeleton.lua")
dofile("tests/declarations/TestDeclarationCatalog.lua")
dofile("tests/feedback/TestCandidateFeedback.lua")
dofile("tests/forms/TestRouteForm.lua")
dofile("tests/history/TestHistoryBuilder.lua")
dofile("tests/pipeline/TestRoutePipeline.lua")
dofile("tests/ui/TestDebugHarness.lua")
dofile("tests/validation/TestRewardValidator.lua")
dofile("tests/validation/TestStructuralValidator.lua")
os.exit(lu.LuaUnit.run())
