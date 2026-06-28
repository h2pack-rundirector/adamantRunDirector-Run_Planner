local sideRoomProbability = {}

local ENABLED_MODE = "Enabled"

local function percent(value)
    return string.format("%.1f%%", (value or 0) * 100)
end

local function oneDecimal(value)
    return string.format("%.1f", value or 0)
end

local function policyFor(instance)
    return instance
        and instance.biome
        and instance.biome.hub
        and instance.biome.hub.sideRoomAvailability
        and instance.biome.hub.sideRoomAvailability.vanillaPolicy
        or nil
end

function sideRoomProbability.createSummary(instance)
    local policy = policyFor(instance)
    if policy == nil then
        return nil
    end

    return {
        minPerPylon = policy.minPerPylon or 0,
        chanceAfterMinimum = policy.chanceAfterMinimum or 0,
        totalCount = 0,
        enabledCount = 0,
        disabledCount = 0,
        expectedOpenCount = 0,
        expectedSpawnedCount = 0,
    }
end

function sideRoomProbability.countSideDoor(summary, mode)
    if summary == nil then
        return
    end

    summary.totalCount = summary.totalCount + 1

    if mode == ENABLED_MODE then
        summary.enabledCount = summary.enabledCount + 1
        summary.expectedOpenCount = summary.expectedOpenCount + 1
        summary.expectedSpawnedCount = summary.expectedSpawnedCount + 1
        return
    end

    summary.disabledCount = summary.disabledCount + 1
end

function sideRoomProbability.finish(summary)
    if summary == nil or summary.totalCount == 0 then
        return nil
    end

    summary.text = "Vanilla Side Rooms: min "
        .. oneDecimal(summary.minPerPylon)
        .. " per pylon, then "
        .. percent(summary.chanceAfterMinimum)
        .. " chance    Planned: "
        .. tostring(summary.enabledCount)
        .. " enabled / "
        .. tostring(summary.disabledCount)
        .. " disabled, expected ~"
        .. oneDecimal(summary.expectedOpenCount)
        .. " open"
    return summary
end

function sideRoomProbability.invalidate(instance)
    instance.sideRoomProbabilityVersion = (instance.sideRoomProbabilityVersion or 0) + 1
end

function sideRoomProbability.drawInfoLine(imgui, decorations, summary)
    if summary == nil then
        return
    end

    decorations.drawColoredText(imgui, decorations.warningValueColor(), summary.text)
    imgui.Spacing()
end

return sideRoomProbability
