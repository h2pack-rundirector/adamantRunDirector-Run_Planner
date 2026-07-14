-- luacheck: globals TestResetSkeleton

local lu = require("luaunit")
local smokeEnv = dofile("tests/smoke_env.lua")

TestResetSkeleton = {}

function TestResetSkeleton.testPreservesModuleIdentity()
    lu.assertEquals(smokeEnv.expectedPackId, "run-director")
    lu.assertEquals(smokeEnv.expectedModuleId, "Run_Planner")
end

function TestResetSkeleton.testSmokeEnvironmentRemainsNeutral()
    local env = {}
    lu.assertIs(smokeEnv.configureEnv(env), env)
end
