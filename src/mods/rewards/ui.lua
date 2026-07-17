local deps = ... or {}
local countedChoice = deps.countedChoice
local primitiveChoice = deps.primitiveChoice

local rewardUi = {}

local FRAME_ALIGNED_TEXT_OPTS = {
    alignToFramePadding = true,
}

local function hasFramedPayload(editor)
    return editor ~= nil and editor.kind ~= "none"
end

local function primitiveLabels(primitives)
    local labels = {}
    for _, primitive in ipairs(primitives) do
        labels[primitive.gameName] = primitive.label
    end
    return labels
end

local function payloadView(primitive)
    local payload = primitive.payload
    if payload.kind == "none" then
        return { kind = "none" }
    end
    local values = payload.values
    local labels = {}
    for _, value in ipairs(payload.values) do
        labels[value] = payload.valueLabels[value]
    end
    if payload.kind == "oneOf" then
        return {
            kind = "oneOf",
            opts = {
                label = "Source",
                values = values,
                displayValues = labels,
                controlWidth = 150,
            },
        }
    end
    if payload.kind == "distinctPair" then
        local firstVisible = {}
        local secondVisible = {}
        for _, value in ipairs(values) do
            firstVisible[value] = true
            secondVisible[value] = true
        end
        return {
            kind = "distinctPair",
            values = values,
            first = {
                label = "Source 1",
                values = values,
                displayValues = labels,
                visibleValues = firstVisible,
                controlWidth = 150,
            },
            second = {
                label = "Source 2",
                values = values,
                displayValues = labels,
                visibleValues = secondVisible,
                controlWidth = 150,
            },
        }
    end
    error("missing reward UI for payload kind '" .. tostring(payload.kind) .. "'", 0)
end

local function payloadViews(primitives)
    local result = {}
    for _, primitive in ipairs(primitives) do
        result[primitive.gameName] = payloadView(primitive)
    end
    return result
end

local function rewardOpts(primitives)
    local keys = {}
    for _, primitive in ipairs(primitives) do
        keys[#keys + 1] = primitive.gameName
    end
    return {
        label = "Reward",
        values = keys,
        displayValues = primitiveLabels(primitives),
        controlWidth = 170,
    }
end

function rewardUi.prepareCounted(descriptor)
    local view = descriptor.view
    local editor = {
        payloads = payloadViews(view.primitives.ordered),
        rewardsByStore = {},
    }
    if view.fixedStoreKey == nil then
        local labels = {}
        for _, store in ipairs(view.stores.ordered) do
            labels[store.key] = store.key
            editor.rewardsByStore[store.key] = rewardOpts(store.primitives)
        end
        editor.store = {
            label = "Store",
            values = view.storeKeys,
            displayValues = labels,
            controlWidth = 145,
        }
    else
        editor.rewardsByStore[view.fixedStoreKey] = rewardOpts(
            view.stores.lookup[view.fixedStoreKey].primitives
        )
    end
    descriptor.editor = editor
    return descriptor
end

function rewardUi.prepareFixed(descriptor)
    descriptor.editor = {
        payload = payloadView(descriptor.primitive),
    }
    return descriptor
end

function rewardUi.preparePrimitiveChoice(descriptor)
    descriptor.editor = {
        reward = rewardOpts(descriptor.optionSet.primitives),
        payloads = payloadViews(descriptor.optionSet.primitives),
    }
    return descriptor
end

function rewardUi.prepareShop(descriptor)
    for _, slot in ipairs(descriptor.slots.ordered) do
        rewardUi.preparePrimitiveChoice(slot.reward)
        slot.editor = {
            purchased = {
                label = "Purchased##" .. slot.key,
            },
        }
    end
    return descriptor
end

local function drawPayload(draw, fields, mapping, editor)
    if editor == nil or editor.kind == "none" then
        return
    end
    local firstField = fields[mapping.source1]
    if editor.kind == "oneOf" then
        draw.imgui.SameLine()
        draw.widgets.dropdown(firstField, editor.opts)
        return
    end

    local secondField = fields[mapping.source2]
    local first = firstField:read()
    local second = secondField:read()
    for _, value in ipairs(editor.values) do
        editor.first.visibleValues[value] = true
        editor.second.visibleValues[value] = true
    end
    if second ~= "" then
        editor.first.visibleValues[second] = false
    end
    if first ~= "" then
        editor.second.visibleValues[first] = false
    end
    draw.imgui.SameLine()
    draw.widgets.dropdown(firstField, editor.first)
    draw.imgui.SameLine()
    draw.widgets.dropdown(secondField, editor.second)
end

local function drawPrimitiveChoice(draw, fields, descriptor)
    local optionSet = descriptor.optionSet
    local rewardType = optionSet.fixedRewardType
    if descriptor.fields.rewardType ~= nil then
        local field = fields[descriptor.fields.rewardType]
        if draw.widgets.dropdown(field, descriptor.editor.reward) then
            primitiveChoice.replaceReward(
                fields,
                descriptor,
                field:read(),
                "primitive reward editor"
            )
        end
        rewardType = field:read()
    elseif rewardType ~= nil then
        draw.widgets.text(
            optionSet.primitiveLookup[rewardType].label,
            FRAME_ALIGNED_TEXT_OPTS
        )
    end
    local primitive = optionSet.primitiveLookup[rewardType]
    if primitive ~= nil then
        drawPayload(
            draw,
            fields,
            descriptor.fields,
            descriptor.editor.payloads[primitive.gameName]
        )
    end
end

function rewardUi.drawCounted(draw, fields, descriptor)
    local view = descriptor.view
    local storeKey = view.fixedStoreKey
    local drewStore = false
    if descriptor.fields.storeKey ~= nil then
        local field = fields[descriptor.fields.storeKey]
        if draw.widgets.dropdown(field, descriptor.editor.store) then
            countedChoice.replaceStore(
                fields,
                descriptor,
                field:read(),
                "counted reward editor"
            )
        end
        storeKey = field:read()
        drewStore = true
    end

    local rewardType = view.fixedRewardType
    if descriptor.fields.rewardType ~= nil then
        local opts = descriptor.editor.rewardsByStore[storeKey]
        if opts == nil then
            return
        end
        if drewStore then
            draw.imgui.SameLine()
        end
        local field = fields[descriptor.fields.rewardType]
        if draw.widgets.dropdown(field, opts) then
            countedChoice.replaceReward(
                fields,
                descriptor,
                field:read(),
                "counted reward editor"
            )
        end
        rewardType = field:read()
    end

    local primitive = view.primitives.lookup[rewardType]
    local payloadEditor = primitive
        and descriptor.editor.payloads[primitive.gameName]
        or nil
    if descriptor.fields.rewardType == nil and rewardType ~= nil then
        if drewStore then
            draw.imgui.SameLine()
        end
        draw.widgets.text(
            primitive.label,
            (drewStore or hasFramedPayload(payloadEditor))
                and FRAME_ALIGNED_TEXT_OPTS
                or nil
        )
    end
    if primitive ~= nil then
        drawPayload(
            draw,
            fields,
            descriptor.fields,
            payloadEditor
        )
    end
end

function rewardUi.drawFixed(draw, fields, descriptor)
    draw.widgets.text(
        descriptor.primitive.label,
        hasFramedPayload(descriptor.editor.payload) and FRAME_ALIGNED_TEXT_OPTS or nil
    )
    drawPayload(
        draw,
        fields,
        descriptor.fields,
        descriptor.editor.payload
    )
end

function rewardUi.drawShop(draw, fields, descriptor)
    for index, slot in ipairs(descriptor.slots.ordered) do
        if index > 1 then
            draw.imgui.Spacing()
        end
        draw.widgets.text(slot.label, FRAME_ALIGNED_TEXT_OPTS)
        draw.imgui.SameLine()
        drawPrimitiveChoice(draw, fields, slot.reward)
        draw.imgui.SameLine()
        draw.widgets.checkbox(fields[slot.purchasedField], slot.editor.purchased)
    end
end

return rewardUi
