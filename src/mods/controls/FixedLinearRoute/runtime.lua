-- luacheck: no unused args

local deps = ...
local data = deps.data

local runtime = {}

local function normalizeRole(instance, roleKey)
    local role = instance.rolesByKey[roleKey]
    if role ~= nil then
        return roleKey, role
    end
    return "Vanilla", instance.rolesByKey.Vanilla
end

local function normalizeOption(role, optionKey)
    if role == nil then
        return "", nil
    end

    local normalizedKey = optionKey
    local option = normalizedKey ~= nil and role.optionsByKey and role.optionsByKey[normalizedKey] or nil
    if option == nil then
        normalizedKey = role.defaultOptionKey or ""
        option = normalizedKey ~= "" and role.optionsByKey and role.optionsByKey[normalizedKey] or nil
    end
    return normalizedKey, option
end

local function readRewards(rows, rowIndex)
    local rewards = {}
    for index = 1, data.REWARD_SLOT_COUNT do
        rewards[index] = rows:read(rowIndex, "Reward" .. tostring(index) .. "Key") or ""
    end
    return rewards
end

function runtime.create(fields, instance)
    local control = {}

    function control:name()
        return instance.name
    end

    function control:biomeKey()
        return instance.biomeKey
    end

    function control:label()
        return instance.label
    end

    function control:rowCount()
        return fields.Rows:count()
    end

    function control:slot(rowIndex)
        return instance.routeSlots[math.floor(tonumber(rowIndex) or 0)]
    end

    function control:role(rowIndex)
        local roleKey = fields.Rows:read(rowIndex, "RoleKey")
        local _, role = normalizeRole(instance, roleKey)
        return role
    end

    function control:option(rowIndex)
        local role = self:role(rowIndex)
        local optionKey = fields.Rows:read(rowIndex, "OptionKey")
        local _, option = normalizeOption(role, optionKey)
        return option
    end

    function control:rowSnapshot(rowIndex)
        local slot = self:slot(rowIndex)
        if slot == nil then
            return nil
        end

        local roleKey, role = normalizeRole(instance, fields.Rows:read(rowIndex, "RoleKey"))
        local optionKey, option = normalizeOption(role, fields.Rows:read(rowIndex, "OptionKey"))
        return {
            rowIndex = rowIndex,
            coordinate = slot.coordinate,
            slotLabel = slot.label,
            roleKey = roleKey,
            role = role,
            optionKey = optionKey,
            option = option,
            variantKey = fields.Rows:read(rowIndex, "VariantKey") or "",
            rewards = readRewards(fields.Rows, rowIndex),
        }
    end

    function control:buildSnapshot()
        local rows = {}
        for rowIndex = 1, self:rowCount() do
            rows[#rows + 1] = self:rowSnapshot(rowIndex)
        end
        return {
            controlName = instance.name,
            biomeKey = instance.biomeKey,
            adapter = instance.biome.adapter,
            rows = rows,
        }
    end

    function control:read(path, ...)
        if path == "snapshot" then
            return self:buildSnapshot()
        elseif path == "row" then
            return self:rowSnapshot(...)
        end
        return nil
    end

    return control
end

return runtime
