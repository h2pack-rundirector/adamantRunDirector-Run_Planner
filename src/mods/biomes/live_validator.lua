local liveValidator = {}

local function addIssue(issues, code, path, message)
    issues[#issues + 1] = {
        code = code,
        path = path,
        message = message,
    }
end

local function childPath(path, key)
    if type(key) == "number" then
        return path .. "[" .. tostring(key) .. "]"
    end
    if path == "" then
        return tostring(key)
    end
    return path .. "." .. tostring(key)
end

local function liveTable(game, key)
    if game[key] ~= nil then
        return game[key]
    end
    return _G[key]
end

local function addRoomRef(refs, roomKey, path)
    if roomKey == nil then
        return
    end
    refs[#refs + 1] = {
        key = roomKey,
        path = path,
    }
end

local collectSlotList

local function collectRoomOption(refs, option, path)
    if type(option) ~= "table" then
        return
    end
    addRoomRef(refs, option.key, childPath(path, "key"))
    collectSlotList(refs, option.sideDoors, childPath(path, "sideDoors"))
end

local function collectRoomOptions(refs, options, path)
    for index, option in ipairs(options or {}) do
        collectRoomOption(refs, option, childPath(path, index))
    end
end

local function collectSlotEntry(refs, entry, path)
    if type(entry) ~= "table" then
        return
    end
    addRoomRef(refs, entry.roomKey, childPath(path, "roomKey"))
    collectRoomOption(refs, entry.room, childPath(path, "room"))
    collectRoomOptions(refs, entry.roomOptions, childPath(path, "roomOptions"))
end

collectSlotList = function(refs, items, path)
    for index, entry in ipairs(items or {}) do
        collectSlotEntry(refs, entry, childPath(path, index))
    end
end

local function collectSlotMap(refs, items, path)
    for key, entry in pairs(items or {}) do
        collectSlotEntry(refs, entry, childPath(path, key))
    end
end

local function collectRoleRefs(refs, roles, path)
    for roleIndex, role in ipairs(roles or {}) do
        local rolePath = childPath(path, roleIndex)
        collectRoomOptions(refs, role.roomOptions, childPath(rolePath, "roomOptions"))
        collectRoomOptions(refs, role.mapOptions, childPath(rolePath, "mapOptions"))
    end
end

local function collectHubRefs(refs, hub, path)
    if type(hub) ~= "table" then
        return
    end
    addRoomRef(refs, hub.roomKey, childPath(path, "roomKey"))
    collectRoomOptions(refs, hub.combatRooms, childPath(path, "combatRooms"))
    collectRoomOptions(refs, hub.minibossRooms, childPath(path, "minibossRooms"))
    collectRoomOptions(refs, hub.storyRooms, childPath(path, "storyRooms"))
end

local function collectFieldsRefs(refs, fields, path)
    if type(fields) ~= "table" then
        return
    end
    collectRoomOptions(refs, fields.combatRooms, childPath(path, "combatRooms"))
    collectRoomOptions(refs, fields.minibossRooms, childPath(path, "minibossRooms"))
end

local function collectRoomTopologyRefs(refs, topology, path)
    if type(topology) ~= "table" then
        return
    end

    local hub = topology.hub
    if type(hub) == "table" then
        collectSlotList(refs, hub.doorRooms, childPath(childPath(path, "hub"), "doorRooms"))
    end
end

local function collectTimelineRefs(refs, timeline, path)
    if type(timeline) ~= "table" then
        return
    end
    collectSlotList(refs, timeline.afterBiome, childPath(path, "afterBiome"))
end

local function collectBiomeRoomRefs(catalog)
    local refs = {}
    for biomeIndex, biome in ipairs(catalog.ordered or {}) do
        local biomePath = "catalog.ordered[" .. tostring(biomeIndex) .. "]"
        collectRoleRefs(refs, biome.roles, childPath(biomePath, "roles"))

        local slotLayout = biome.slotLayout or {}
        local layoutPath = childPath(biomePath, "slotLayout")
        collectSlotEntry(refs, slotLayout.entry, childPath(layoutPath, "entry"))
        collectSlotMap(refs, slotLayout.special, childPath(layoutPath, "special"))
        collectSlotList(refs, slotLayout.fixedBeforeRoute, childPath(layoutPath, "fixedBeforeRoute"))
        collectSlotList(refs, slotLayout.fixedAfterRoute, childPath(layoutPath, "fixedAfterRoute"))
        collectSlotList(refs, slotLayout.fixedBeforeHub, childPath(layoutPath, "fixedBeforeHub"))
        collectSlotList(refs, slotLayout.fixedAfterHub, childPath(layoutPath, "fixedAfterHub"))
        collectSlotList(refs, slotLayout.fixedAfterGoals, childPath(layoutPath, "fixedAfterGoals"))

        collectTimelineRefs(refs, biome.timeline, childPath(biomePath, "timeline"))
        collectHubRefs(refs, biome.hub, childPath(biomePath, "hub"))
        collectFieldsRefs(refs, biome.fields, childPath(biomePath, "fields"))
        collectRoomTopologyRefs(refs, biome.roomTopology, childPath(biomePath, "roomTopology"))
    end
    return refs
end

local function validateRoomRefs(issues, game, catalog)
    local roomData = liveTable(game, "RoomData")
    if roomData == nil then
        addIssue(issues, "missing_live_table", "RoomData", "Live RoomData table is missing")
        return
    end

    for _, ref in ipairs(collectBiomeRoomRefs(catalog)) do
        if roomData[ref.key] == nil then
            addIssue(issues, "missing_live_room", ref.path, "Live RoomData is missing room: " .. tostring(ref.key))
        end
    end
end

local function validateRewardStores(issues, game, rewardDefinitions)
    local rewardStoreData = liveTable(game, "RewardStoreData")
    if rewardStoreData == nil then
        addIssue(issues, "missing_live_table", "RewardStoreData", "Live RewardStoreData table is missing")
        return
    end

    for storeKey in pairs(rewardDefinitions.rewardStores or {}) do
        if rewardStoreData[storeKey] == nil then
            addIssue(
                issues,
                "missing_live_reward_store",
                "rewardStores." .. tostring(storeKey),
                "Live RewardStoreData is missing store: " .. tostring(storeKey)
            )
        end
    end
end

local function validateShops(issues, game, rewardDefinitions)
    local storeData = liveTable(game, "StoreData")
    if storeData == nil then
        addIssue(issues, "missing_live_table", "StoreData", "Live StoreData table is missing")
        return
    end

    for shopKey in pairs(rewardDefinitions.shops or {}) do
        if storeData[shopKey] == nil then
            addIssue(
                issues,
                "missing_live_shop",
                "shops." .. tostring(shopKey),
                "Live StoreData is missing shop: " .. tostring(shopKey)
            )
        end
    end
end

local function roomDataHasField(roomData, fieldName)
    if roomData.BaseRoom ~= nil and roomData.BaseRoom[fieldName] ~= nil then
        return true
    end
    for _, room in pairs(roomData) do
        if type(room) == "table" and room[fieldName] ~= nil then
            return true
        end
    end
    return false
end

local function validateFeatureRequirementFields(issues, game, featureDefinitions)
    local roomData = liveTable(game, "RoomData")
    if roomData == nil then
        return
    end

    for featureKey, feature in pairs((featureDefinitions or {}).byKey or {}) do
        local fieldName = feature.vanillaNamedRequirement
        if fieldName ~= nil and not roomDataHasField(roomData, fieldName) then
            addIssue(
                issues,
                "missing_live_feature_requirement",
                "features." .. tostring(featureKey) .. ".vanillaNamedRequirement",
                "Live RoomData is missing requirement field: " .. tostring(fieldName)
            )
        end
    end
end

function liveValidator.validate(catalog, opts)
    opts = opts or {}
    local game = opts.game or _G
    local rewardDefinitions = opts.rewardDefinitions
    local featureDefinitions = opts.featureDefinitions or catalog.features
    local issues = {}

    validateRoomRefs(issues, game, catalog)
    validateRewardStores(issues, game, rewardDefinitions)
    validateShops(issues, game, rewardDefinitions)
    validateFeatureRequirementFields(issues, game, featureDefinitions)

    return issues
end

function liveValidator.run(catalog, opts)
    opts = opts or {}
    local issues = liveValidator.validate(catalog, opts)
    local host = opts.host

    if #issues == 0 then
        host.log("[RunPlanner] live game-data validation passed")
        return issues
    end

    host.log("[RunPlanner] live game-data validation found %d issue(s)", #issues)
    for _, issue in ipairs(issues) do
        host.log(
            "[RunPlanner] live validator %s at %s: %s",
            tostring(issue.code),
            tostring(issue.path),
            tostring(issue.message)
        )
    end
    return issues
end

return liveValidator
