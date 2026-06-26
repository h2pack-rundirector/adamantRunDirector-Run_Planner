local rewardRatio = {}

local MAJOR_VALUE = "Major"
local MINOR_VALUE = "Minor"

local function percent(value)
    return string.format("%.1f%%", (value or 0) * 100)
end

local function countText(count, noun)
    if count == 1 then
        return "1 " .. noun
    end
    return tostring(count) .. " " .. noun .. "s"
end

local function currentText(summary)
    local setCount = summary.majorCount + summary.minorCount
    if setCount == 0 then
        return "-- (" .. countText(summary.unsetCount, "vanilla") .. ")"
    end

    local minorRatio = summary.minorCount / setCount
    local text = percent(minorRatio) .. " / " .. percent(1 - minorRatio)
        .. " (" .. tostring(setCount) .. "/" .. tostring(summary.totalCount) .. " set"
    if summary.unsetCount > 0 then
        text = text .. ", " .. countText(summary.unsetCount, "vanilla")
    end
    return text .. ")"
end

function rewardRatio.createSummary(instance)
    local ratio = instance.biome and instance.biome.rewardRatio or nil
    if ratio == nil then
        return nil
    end

    return {
        targetMetaProgress = ratio.targetMetaProgress,
        totalCount = 0,
        majorCount = 0,
        minorCount = 0,
        unsetCount = 0,
    }
end

function rewardRatio.countSurface(summary, rewardSystem, surface, fields)
    if summary == nil or surface == nil or surface.kind ~= "majorMinor" then
        return
    end

    summary.totalCount = summary.totalCount + 1
    local value = fields:read(rewardSystem.rewardAlias(1)) or ""
    if value == MINOR_VALUE then
        summary.minorCount = summary.minorCount + 1
    elseif value == MAJOR_VALUE then
        summary.majorCount = summary.majorCount + 1
    else
        summary.unsetCount = summary.unsetCount + 1
    end
end

function rewardRatio.finish(summary)
    if summary == nil or summary.totalCount == 0 then
        return nil
    end

    local targetMinor = summary.targetMetaProgress or 0
    summary.text = "Expected Minor/Major: " .. percent(targetMinor) .. " / " .. percent(1 - targetMinor)
        .. "    Current Minor/Major: " .. currentText(summary)
    return summary
end

function rewardRatio.invalidate(instance)
    instance.rewardRatioVersion = (instance.rewardRatioVersion or 0) + 1
end

function rewardRatio.drawInfoLine(imgui, decorations, summary)
    if summary == nil then
        return
    end

    decorations.drawColoredText(imgui, decorations.warningValueColor(), summary.text)
    imgui.Spacing()
end

return rewardRatio
