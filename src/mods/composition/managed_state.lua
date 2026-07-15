local deps = ...
local storage = deps.storage
local templates = deps.templates
local instances = deps.instances

local managedState = {}

function managedState.install(module)
    module.data.define(storage.moduleStorage)
    module.controls.defineTemplates(templates)
    module.controls.define(instances)

    return {
        storage = storage,
    }
end

return managedState
