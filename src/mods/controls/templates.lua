local deps = ...

local route = deps.route
local transitionalRoom = deps.transitionalRoom
local fixedOpening = deps.fixedOpening
local fixedIntro = deps.fixedIntro
local standardCombat = deps.standardCombat
local miniboss = deps.miniboss
local story = deps.story
local fountain = deps.fountain
local shopRoom = deps.shopRoom
local forkedPreboss = deps.forkedPreboss

local templates = {}

local implementations = {
    FixedOpening = fixedOpening,
    FixedIntro = fixedIntro,
    FixedPreHub = transitionalRoom,
    EphyraHub = transitionalRoom,
    StandardCombat = standardCombat,
    FieldsCombat = transitionalRoom,
    ClockworkCombat = transitionalRoom,
    EphyraCombat = transitionalRoom,
    ShipCombat = transitionalRoom,
    OlympusCombat = transitionalRoom,
    Story = story,
    Fountain = fountain,
    Shop = shopRoom,
    Miniboss = miniboss,
    Devotion = transitionalRoom,
    DirectPreboss = transitionalRoom,
    ForkedPreboss = forkedPreboss,
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

function templates.implementationKind(templateKey)
    if implementation(templateKey) == transitionalRoom then
        return "transitional"
    end
    return "focused"
end

function templates.build(catalog)
    local result = { Route = route }
    for _, declaration in ipairs(catalog.roomTemplates.ordered) do
        result[declaration.key] = implementation(declaration.key).template
    end
    return result
end

return templates
