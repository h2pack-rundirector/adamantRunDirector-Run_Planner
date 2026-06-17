local runContext = {}

local EMPTY_LIST = {}

local function routeControlName(biomeKey)
    return "Route" .. tostring(biomeKey or "")
end

local function buildRouteInfoByBiome(routes)
    local routeInfoByBiome = {}
    for _, route in ipairs(routes and routes.ordered or EMPTY_LIST) do
        for index, routeBiomeKey in ipairs(route.biomes or EMPTY_LIST) do
            routeInfoByBiome[routeBiomeKey] = {
                route = route,
                index = index,
                controlName = routeControlName(routeBiomeKey),
            }
        end
    end
    return routeInfoByBiome
end

local function addGodLootSelection(selections, countedLookup, lootName)
    if lootName ~= nil and lootName ~= "" and countedLookup[lootName] and not selections[lootName] then
        selections[lootName] = true
        return 1
    end
    return 0
end

local function selectionCount(selections)
    local count = 0
    for _ in pairs(selections) do
        count = count + 1
    end
    return count
end

local function pickValueByKey(item, key)
    for _, pick in ipairs(item and item.rewardPicks or EMPTY_LIST) do
        if pick.key == key then
            return pick.value
        end
    end
    return nil
end

local function collectRewardGodLoot(item, countedLookup, selections)
    if item == nil or item.valid == false then
        return 0
    end

    local rewards = item.rewards or EMPTY_LIST
    local count = 0
    if item.rewardKind == "boonSource" then
        count = count + addGodLootSelection(selections, countedLookup, pickValueByKey(item, "boonSource") or rewards[1])
    elseif item.rewardKind == "devotionPair" then
        count = count + addGodLootSelection(selections, countedLookup, pickValueByKey(item, "lootAName") or rewards[1])
        count = count + addGodLootSelection(selections, countedLookup, pickValueByKey(item, "lootBName") or rewards[2])
    elseif item.rewardKind == "roomStore" then
        if rewards[1] == "Boon" then
            count = count + addGodLootSelection(
                selections,
                countedLookup,
                pickValueByKey(item, "boonSource") or rewards[2]
            )
        end
    elseif item.rewardKind == "majorMinor" or item.rewardKind == "shipWheel" then
        if rewards[1] == "Major" and rewards[2] == "Boon" then
            count = count + addGodLootSelection(
                selections,
                countedLookup,
                pickValueByKey(item, "boonSource") or rewards[3]
            )
        end
    end
    return count
end

local function collectRowGodLoot(row, countedLookup, selections)
    local count = collectRewardGodLoot(row, countedLookup, selections)
    for _, sideRoom in ipairs(row and row.sideRooms or EMPTY_LIST) do
        count = count + collectRewardGodLoot(sideRoom, countedLookup, selections)
    end
    for _, cageReward in ipairs(row and row.cageRewards or EMPTY_LIST) do
        count = count + collectRewardGodLoot(cageReward, countedLookup, selections)
    end
    for _, encounterRewardLeg in ipairs(row and row.encounterRewardLegs or EMPTY_LIST) do
        count = count + collectRewardGodLoot(encounterRewardLeg, countedLookup, selections)
    end
    return count
end

local function controlSnapshot(context, biomeKey)
    if context.snapshotByBiome[biomeKey] ~= nil then
        return context.snapshotByBiome[biomeKey]
    end

    local control = context:controlForBiome(biomeKey)
    local snapshot = control ~= nil and control.read ~= nil and control:read("snapshot") or nil
    context.snapshotByBiome[biomeKey] = snapshot or false
    return snapshot
end

local function clearMap(map)
    for key in pairs(map) do
        map[key] = nil
    end
end

function runContext.create(opts)
    opts = opts or {}
    local context = {
        routes = opts.routes or {},
        routeInfoByBiome = buildRouteInfoByBiome(opts.routes),
        controlResolver = opts.controlResolver,
        controls = opts.controls,
        snapshotByBiome = {},
    }

    function context:beginPass(controls)
        self.controls = controls or self.controls
        clearMap(self.snapshotByBiome)
    end

    function context:bindControl(control)
        if control ~= nil and control.setRouteContext ~= nil then
            control:setRouteContext(self)
        end
        return control
    end

    function context:controlForBiome(biomeKey)
        local info = self.routeInfoByBiome[biomeKey]
        if info == nil then
            return nil
        end
        if self.controlResolver ~= nil then
            return self:bindControl(self.controlResolver(info.controlName, biomeKey))
        end
        if self.controls ~= nil and self.controls.get ~= nil then
            return self:bindControl(self.controls.get(info.controlName))
        end
        return nil
    end

    function context:attachControls()
        for _, route in ipairs(self.routes.ordered or EMPTY_LIST) do
            for _, biomeKey in ipairs(route.biomes or EMPTY_LIST) do
                self:controlForBiome(biomeKey)
            end
        end
    end

    function context:collectPriorGodLoot(biomeKey, countedLookup, selections, stopAtCount)
        if countedLookup == nil or selections == nil then
            return selections
        end

        local info = self.routeInfoByBiome[biomeKey]
        if info == nil then
            return selections
        end

        local count = selectionCount(selections)
        for index = 1, info.index - 1 do
            local snapshot = controlSnapshot(self, info.route.biomes[index])
            for _, row in ipairs(snapshot and snapshot.rows or EMPTY_LIST) do
                count = count + collectRowGodLoot(row, countedLookup, selections)
                if stopAtCount ~= nil and count >= stopAtCount then
                    return selections
                end
            end
        end
        return selections
    end

    function context:snapshot(routeKey)
        local route = self.routes.lookup and self.routes.lookup[routeKey] or nil
        local snapshots = {}
        local invalidRows = {}
        if route == nil then
            return {
                routeKey = routeKey,
                valid = false,
                disabled = true,
                invalidRows = {
                    { code = "unknown_route", message = "Unknown route: " .. tostring(routeKey) },
                },
                biomes = snapshots,
            }
        end

        for _, biomeKey in ipairs(route.biomes or EMPTY_LIST) do
            local snapshot = controlSnapshot(self, biomeKey)
            snapshots[#snapshots + 1] = snapshot
            for _, invalidRow in ipairs(snapshot and snapshot.invalidRows or EMPTY_LIST) do
                invalidRows[#invalidRows + 1] = {
                    biomeKey = biomeKey,
                    controlName = snapshot.controlName,
                    rowIndex = invalidRow.rowIndex,
                    coordinate = invalidRow.coordinate,
                    code = invalidRow.code,
                    message = invalidRow.message,
                }
            end
        end

        return {
            routeKey = route.key,
            label = route.label,
            valid = invalidRows[1] == nil,
            disabled = invalidRows[1] ~= nil,
            invalidRows = invalidRows,
            biomes = snapshots,
        }
    end

    return context
end

runContext.collectRewardGodLoot = collectRewardGodLoot
runContext.collectRowGodLoot = collectRowGodLoot

return runContext
