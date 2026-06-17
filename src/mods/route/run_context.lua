local runContext = {}

local EMPTY_LIST = {}

local function routeControlName(biomeKey)
    return "Route" .. tostring(biomeKey or "")
end

local function buildRouteInfo(routes)
    local routeInfoByRoute = {}
    local routeInfoByBiome = {}
    for _, route in ipairs(routes and routes.ordered or EMPTY_LIST) do
        local routeInfos = {}
        routeInfoByRoute[route.key] = routeInfos
        for index, routeBiomeKey in ipairs(route.biomes or EMPTY_LIST) do
            local info = {
                route = route,
                index = index,
                controlName = routeControlName(routeBiomeKey),
            }
            routeInfos[routeBiomeKey] = info
            if routeInfoByBiome[routeBiomeKey] == nil then
                routeInfoByBiome[routeBiomeKey] = info
            end
        end
    end
    return routeInfoByRoute, routeInfoByBiome
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

local function routeSnapshotCache(context, routeKey)
    local snapshots = context.snapshotByRoute[routeKey]
    if snapshots == nil then
        snapshots = {}
        context.snapshotByRoute[routeKey] = snapshots
    end
    return snapshots
end

local function routeOverviewState(context, routeKey)
    local state = context.overviewByRoute[routeKey]
    if state == nil then
        state = {
            dirty = true,
            snapshot = nil,
        }
        context.overviewByRoute[routeKey] = state
    end
    return state
end

local function controlSnapshot(context, routeKey, biomeKey)
    local snapshots = routeSnapshotCache(context, routeKey)
    if snapshots[biomeKey] ~= nil then
        return snapshots[biomeKey]
    end

    local control = context:controlForBiome(routeKey, biomeKey)
    local snapshot = control ~= nil and control.read ~= nil and control:read("snapshot") or nil
    snapshots[biomeKey] = snapshot or false
    return snapshot
end

local function clearMap(map)
    for key in pairs(map) do
        map[key] = nil
    end
end

function runContext.create(opts)
    opts = opts or {}
    local routeInfoByRoute, routeInfoByBiome = buildRouteInfo(opts.routes)
    local context = {
        routes = opts.routes or {},
        routeInfoByRoute = routeInfoByRoute,
        routeInfoByBiome = routeInfoByBiome,
        controlResolver = opts.controlResolver,
        controls = opts.controls,
        snapshotByRoute = {},
        overviewByRoute = {},
    }

    function context:beginPass(controls)
        self.controls = controls or self.controls
        clearMap(self.snapshotByRoute)
    end

    function context:bindControl(control, routeKey)
        if control ~= nil and control.setRouteContext ~= nil then
            control:setRouteContext(self, routeKey)
        end
        return control
    end

    function context:routeInfo(routeKey, biomeKey)
        if biomeKey == nil then
            biomeKey = routeKey
            routeKey = nil
        end

        if routeKey ~= nil and self.routeInfoByRoute[routeKey] ~= nil then
            return self.routeInfoByRoute[routeKey][biomeKey]
        end
        return self.routeInfoByBiome[biomeKey]
    end

    function context:markAllDirty()
        for _, route in ipairs(self.routes.ordered or EMPTY_LIST) do
            routeOverviewState(self, route.key).dirty = true
        end
        clearMap(self.snapshotByRoute)
    end

    function context:markRoutesForBiome(biomeKey)
        local marked = false
        for routeKey, routeInfos in pairs(self.routeInfoByRoute) do
            if routeInfos[biomeKey] ~= nil then
                routeOverviewState(self, routeKey).dirty = true
                self.snapshotByRoute[routeKey] = nil
                marked = true
            end
        end
        if not marked then
            self:markAllDirty()
        end
    end

    function context:markDirty(routeKey, biomeKey)
        if routeKey ~= nil then
            routeOverviewState(self, routeKey).dirty = true
            self.snapshotByRoute[routeKey] = nil
            return
        end
        if biomeKey ~= nil then
            self:markRoutesForBiome(biomeKey)
            return
        end
        self:markAllDirty()
    end

    function context:controlForBiome(routeKey, biomeKey)
        local info = self:routeInfo(routeKey, biomeKey)
        if info == nil then
            return nil
        end
        if self.controlResolver ~= nil then
            return self:bindControl(self.controlResolver(info.controlName, biomeKey, info.route.key), info.route.key)
        end
        if self.controls ~= nil and self.controls.get ~= nil then
            return self:bindControl(self.controls.get(info.controlName), info.route.key)
        end
        return nil
    end

    function context:attachControls()
        for _, route in ipairs(self.routes.ordered or EMPTY_LIST) do
            for _, biomeKey in ipairs(route.biomes or EMPTY_LIST) do
                self:controlForBiome(route.key, biomeKey)
            end
        end
    end

    function context:collectPriorGodLoot(routeKey, biomeKey, countedLookup, selections, stopAtCount)
        if type(biomeKey) == "table" then
            stopAtCount = selections
            selections = countedLookup
            countedLookup = biomeKey
            biomeKey = routeKey
            routeKey = nil
        end

        if countedLookup == nil or selections == nil then
            return selections
        end

        local info = self:routeInfo(routeKey, biomeKey)
        if info == nil then
            return selections
        end

        local count = selectionCount(selections)
        for index = 1, info.index - 1 do
            local snapshot = controlSnapshot(self, info.route.key, info.route.biomes[index])
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
            local snapshot = controlSnapshot(self, route.key, biomeKey)
            snapshots[#snapshots + 1] = snapshot
            if not snapshot then
                invalidRows[#invalidRows + 1] = {
                    biomeKey = biomeKey,
                    controlName = routeControlName(biomeKey),
                    code = "missing_control",
                    message = "Missing route control: " .. tostring(biomeKey),
                }
            else
                for _, invalidRow in ipairs(snapshot.invalidRows or EMPTY_LIST) do
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

    function context:overview(routeKey)
        local state = routeOverviewState(self, routeKey)
        if state.dirty or state.snapshot == nil then
            state.snapshot = self:snapshot(routeKey)
            state.dirty = false
        end
        return state.snapshot
    end

    return context
end

runContext.collectRewardGodLoot = collectRewardGodLoot
runContext.collectRowGodLoot = collectRowGodLoot

return runContext
