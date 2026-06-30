local npcValidator = {}

local EMPTY_LIST = {}

local function validResult(findings)
    return {
        valid = true,
        invalids = {},
        findings = findings or {},
    }
end

local function selectedKey(row)
    if row == nil or row.disabled == true then
        return ""
    end
    return tostring(row.biomeKey or "") .. ":" .. tostring(row.targetRowIndex or "") .. ":" .. tostring(row.variantKey or "")
end

local function targetForRow(targets, row)
    local bucket = row and targets and targets.byNpc and targets.byNpc[row.npcKey] or nil
    return bucket and bucket.lookup and bucket.lookup[selectedKey(row)] or nil
end

local function npcInvalid(row, code, message, fields)
    local invalid = {
        kind = "npcSelectionInvalid",
        layer = "npcs",
        tabKey = "npcs",
        code = code,
        reason = code,
        message = message,
        routeKey = row and row.routeKey or nil,
        controlName = row and row.controlName or nil,
        rowIndex = row and row.rowIndex or nil,
        npcKey = row and row.npcKey or nil,
        groupKey = row and row.groupKey or nil,
        biomeKey = row and row.biomeKey or nil,
        targetRowIndex = row and row.targetRowIndex or nil,
        variantKey = row and row.variantKey or nil,
        entry = row,
    }
    for key, value in pairs(fields or {}) do
        invalid[key] = value
    end
    return invalid
end

local function rowBefore(left, right)
    return (left.rowIndex or 0) < (right.rowIndex or 0)
end

local function sameTarget(left, right)
    return left ~= nil
        and right ~= nil
        and left.biomeKey == right.biomeKey
        and tostring(left.rowIndex or "") == tostring(right.rowIndex or "")
end

local function spacingConflict(rows, targetsByRow, groups, row)
    local group = groups and groups[row.groupKey] or nil
    local spacing = group and group.plannedSpacingRooms or nil
    if spacing == nil then
        return nil
    end
    local target = targetsByRow[row.rowIndex]
    for _, prior in ipairs(rows or EMPTY_LIST) do
        if rowBefore(prior, row)
            and prior.groupKey == row.groupKey
            and prior.disabled ~= true
        then
            local priorTarget = targetsByRow[prior.rowIndex]
            if priorTarget ~= nil
                and target ~= nil
                and math.abs((target.roomHistoryOrdinal or 0) - (priorTarget.roomHistoryOrdinal or 0)) < spacing
            then
                return prior
            end
        end
    end
    return nil
end

local function occupiedConflict(rows, targetsByRow, row)
    local target = targetsByRow[row.rowIndex]
    for _, prior in ipairs(rows or EMPTY_LIST) do
        if rowBefore(prior, row)
            and prior.disabled ~= true
            and sameTarget(target, targetsByRow[prior.rowIndex])
        then
            return prior
        end
    end
    return nil
end

function npcValidator.validate(args)
    local snapshot = args and args.npcSnapshot or nil
    local targets = args and args.npcTargets or nil
    local npcs = args and args.npcs or {}
    local findings = {}
    local targetsByRow = {}
    for _, row in ipairs(snapshot and snapshot.rows or EMPTY_LIST) do
        row.routeKey = snapshot.routeKey
        row.controlName = snapshot.controlName
        if row.disabled ~= true then
            local target = targetForRow(targets, row)
            targetsByRow[row.rowIndex] = target
            if row.biomeKey == nil or row.biomeKey == "" then
                local invalid = npcInvalid(row, "npc_biome_required", tostring(row.npcKey) .. " needs Disabled or a target biome", {
                    controlAlias = "BiomeKey",
                })
                return {
                    valid = false,
                    invalids = { invalid },
                    findings = findings,
                }
            elseif row.targetRowIndex == nil or row.targetRowIndex == "" then
                local invalid = npcInvalid(row, "npc_room_required", tostring(row.npcKey) .. " needs a target room", {
                    controlAlias = "RowIndex",
                })
                return {
                    valid = false,
                    invalids = { invalid },
                    findings = findings,
                }
            elseif target == nil then
                local invalid = npcInvalid(row, "npc_target_unavailable", "Selected NPC target is no longer valid", {
                    controlAlias = "RowIndex",
                    controlValue = tostring(row.targetRowIndex or ""),
                })
                return {
                    valid = false,
                    invalids = { invalid },
                    findings = findings,
                }
            end
        end
    end

    for _, row in ipairs(snapshot and snapshot.rows or EMPTY_LIST) do
        if row.disabled ~= true then
            local occupied = occupiedConflict(snapshot.rows, targetsByRow, row)
            if occupied ~= nil then
                local invalid = npcInvalid(row, "npc_room_occupied", "Only one NPC encounter can use the same room", {
                    controlAlias = "RowIndex",
                    controlValue = tostring(row.targetRowIndex or ""),
                    relatedEvents = {
                        npcInvalid(occupied, "npc_room_occupied", "Only one NPC encounter can use the same room", {
                            controlAlias = "RowIndex",
                            controlValue = tostring(occupied.targetRowIndex or ""),
                            markerKind = "related",
                        }),
                    },
                })
                return {
                    valid = false,
                    invalids = { invalid },
                    findings = findings,
                }
            end
            local spacing = spacingConflict(snapshot.rows, targetsByRow, npcs.groups, row)
            if spacing ~= nil then
                local invalid = npcInvalid(row, "npc_spacing", tostring(row.npcKey) .. " is too close to another planned NPC", {
                    controlAlias = "RowIndex",
                    controlValue = tostring(row.targetRowIndex or ""),
                    relatedEvents = {
                        npcInvalid(spacing, "npc_spacing", tostring(spacing.npcKey) .. " is too close to another planned NPC", {
                            controlAlias = "RowIndex",
                            controlValue = tostring(spacing.targetRowIndex or ""),
                            markerKind = "related",
                        }),
                    },
                })
                return {
                    valid = false,
                    invalids = { invalid },
                    findings = findings,
                }
            end
        end
    end
    return validResult(findings)
end

return npcValidator
