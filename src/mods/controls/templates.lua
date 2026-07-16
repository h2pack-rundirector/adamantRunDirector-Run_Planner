local deps = ...

local route = deps.route
local transitionalRoom = deps.transitionalRoom
local standardCombat = deps.standardCombat

local templates = {}

local implementations = {
    FixedOpening = transitionalRoom,
    FixedIntro = transitionalRoom,
    FixedPreHub = transitionalRoom,
    EphyraHub = transitionalRoom,
    StandardCombat = standardCombat,
    FieldsCombat = transitionalRoom,
    ClockworkCombat = transitionalRoom,
    EphyraCombat = transitionalRoom,
    ShipCombat = transitionalRoom,
    OlympusCombat = transitionalRoom,
    Story = transitionalRoom,
    Fountain = transitionalRoom,
    Shop = transitionalRoom,
    Miniboss = transitionalRoom,
    Devotion = transitionalRoom,
    DirectPreboss = transitionalRoom,
    ForkedPreboss = transitionalRoom,
}

local function implementation(templateKey)
    local value = implementations[templateKey]
    if value == nil then
        error("no control implementation registered for room template '" .. tostring(templateKey) .. "'", 0)
    end
    return value
end

function templates.prepareRoom(catalog, room)
    return implementation(room.templateKey).prepare(catalog, room)
end

function templates.build(catalog)
    local result = { Route = route }
    for _, declaration in ipairs(catalog.roomTemplates.ordered) do
        result[declaration.key] = implementation(declaration.key).template
    end
    return result
end

return templates
