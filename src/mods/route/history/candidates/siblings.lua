local siblingCandidates = {}

local EMPTY_LIST = {}

local function copyValue(value)
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for key, child in pairs(value) do
        copy[key] = copyValue(child)
    end
    return copy
end

local function topologyForBiome(biome)
    return biome and (
        biome.roomTopology
            or biome.fields and biome.fields.roomTopology
    ) or nil
end

local function roomKeyFor(option)
    return option and (
        option.roomKey
            or option.structure == "Miniboss" and option.key
    ) or nil
end

local function siblingSlotCount(selectedRow)
    local topology = selectedRow and selectedRow.topology or nil
    return #(topology and (topology.otherDoors or topology.siblings) or EMPTY_LIST)
end

local function siblingDoor(selectedRow, siblingIndex)
    local topology = selectedRow and selectedRow.topology or nil
    local doors = topology and (topology.otherDoors or topology.siblings) or EMPTY_LIST
    return doors[siblingIndex]
end

local function appendCandidate(candidates, siblingIndex, option, opts, door)
    candidates[#candidates + 1] = {
        siblingIndex = siblingIndex,
        structureKey = option.key,
        structure = option.structure,
        label = option.label,
        roleKey = option.roleKey,
        optionKey = option.roomKey,
        roomKey = roomKeyFor(option),
        availability = copyValue(option.availability),
        force = copyValue(option.force),
        sameExitRewardCount = option.sameExitRewardCount,
        rewardStore = option.rewardStore,
        rewardClass = option.rewardClass,
        rewardBranch = option.rewardBranch,
        eligibleRewardTypes = copyValue(option.eligibleRewardTypes),
        ineligibleRewardTypes = copyValue(option.ineligibleRewardTypes),
        isClockworkGoal = option.isClockworkGoal == true,
        isPreboss = option.isPreboss == true,
        availabilityContext = copyValue(opts and opts.availabilityContext),
        targetRowIndex = door and door.formAddress and door.formAddress.rowIndex or nil,
        targetRouteOrdinal = opts and opts.targetRouteOrdinal or nil,
        targetFormAddress = copyValue(door and door.formAddress or nil),
    }
end

function siblingCandidates.forBiomeRow(biome, selectedRow, opts)
    local topology = topologyForBiome(biome)
    local control = topology and (topology.generatedDoorControl or topology.siblingStructureControl) or nil
    local options = control
        and control.options
        or EMPTY_LIST
    local slotCount = siblingSlotCount(selectedRow)
    local candidates = {}
    for siblingIndex = 1, slotCount do
        local door = siblingDoor(selectedRow, siblingIndex)
        for _, option in ipairs(options) do
            appendCandidate(candidates, siblingIndex, option, opts, door)
        end
    end
    return candidates
end

return siblingCandidates
