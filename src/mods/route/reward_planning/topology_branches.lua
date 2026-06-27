local deps = ... or {}
local valueStates = deps.valueStates

local topologyBranches = {}

local EMPTY_LIST = {}
local MAJOR_MINOR_BRANCH = "majorMinor"

local function branchValue(node)
    local value = node and node.rewardClass or nil
    if value == "Major" or value == "Minor" then
        return value
    end
    return nil
end

local function branchAddress(node)
    return node and (node.rewardBranchAddress or node.rewardAddress) or nil
end

local function branchControlAlias(node)
    return node and node.rewardBranchControlAlias or nil
end

local function branchLabel(node)
    return node and node.rewardBranchLabel or nil
end

local function branchEvent(row, node, value)
    local targetValue = value or branchValue(node)
    local valueTargets = {}
    if targetValue ~= nil then
        valueTargets[#valueTargets + 1] = {
            address = branchAddress(node),
            controlAlias = branchControlAlias(node),
            value = targetValue,
        }
    end

    return {
        row = row,
        rewardType = targetValue or "MajorMinorBranch",
        address = branchAddress(node),
        addressLabel = branchLabel(node),
        valueTargets = valueTargets,
    }
end

local function appendBranchNode(nodes, node, isSibling)
    if node ~= nil and node.rewardBranch == MAJOR_MINOR_BRANCH then
        nodes[#nodes + 1] = {
            node = node,
            isSibling = isSibling == true,
            value = branchValue(node),
        }
    end
end

local function collectBranchNodes(topology, out)
    for index = #out, 1, -1 do
        out[index] = nil
    end

    appendBranchNode(out, topology and topology.selected or nil, false)
    for _, sibling in ipairs(topology and topology.siblings or EMPTY_LIST) do
        appendBranchNode(out, sibling, true)
    end
    return out
end

local function branchControlNode(topology, rewardAddress, controlAlias)
    local selected = topology and topology.selected or nil
    if selected ~= nil
        and selected.rewardBranch == MAJOR_MINOR_BRANCH
        and branchAddress(selected) == rewardAddress
        and branchControlAlias(selected) == controlAlias
    then
        return selected
    end

    for _, sibling in ipairs(topology and topology.siblings or EMPTY_LIST) do
        if sibling.rewardBranch == MAJOR_MINOR_BRANCH
            and branchAddress(sibling) == rewardAddress
            and branchControlAlias(sibling) == controlAlias
        then
            return sibling
        end
    end
    return nil
end

local function expectedBranchExcluding(topology, excludedNode)
    local expected
    local conflict = false
    local function inspect(node)
        if node == nil or node == excludedNode or node.rewardBranch ~= MAJOR_MINOR_BRANCH then
            return
        end

        local value = branchValue(node)
        if value == nil then
            return
        elseif expected == nil then
            expected = value
        elseif expected ~= value then
            conflict = true
        end
    end

    inspect(topology and topology.selected or nil)
    for _, sibling in ipairs(topology and topology.siblings or EMPTY_LIST) do
        inspect(sibling)
    end
    return expected, conflict
end

local function setInvalid(states, value)
    states = states or {}
    valueStates.set(states, value, valueStates.INVALID)
    return states
end

local function missingSiblingBranch(row, nodes)
    for _, entry in ipairs(nodes) do
        if entry.isSibling and entry.value == nil then
            return branchEvent(row, entry.node), {
                code = "major_minor_sibling_branch_required",
                message = "Other door reward needs Major or Minor",
            }
        end
    end
    return nil, nil
end

local function mismatchedBranch(row, nodes)
    local first
    for _, entry in ipairs(nodes) do
        if entry.value ~= nil then
            if first == nil then
                first = entry
            elseif first.value ~= entry.value then
                return branchEvent(row, entry.node, entry.value), {
                    code = "major_minor_branch_mismatch",
                    message = "Generated doors cannot mix Major and Minor rewards",
                    relatedEvents = {
                        branchEvent(row, first.node, first.value),
                    },
                }
            end
        end
    end
    return nil, nil
end

function topologyBranches.invalidForRow(row, scratch)
    local topology = row and row.roomTopology or nil
    if topology == nil then
        return nil, nil
    end

    scratch = scratch or {}
    local nodes = collectBranchNodes(topology, scratch.branchNodes or {})
    scratch.branchNodes = nodes

    local event, invalid = missingSiblingBranch(row, nodes)
    if invalid ~= nil then
        return event, invalid
    end
    return mismatchedBranch(row, nodes)
end

function topologyBranches.valueStatesForControl(topology, rewardAddress, controlAlias, control, states)
    local currentNode = branchControlNode(topology, rewardAddress, controlAlias)
    if currentNode == nil then
        return states
    end

    local expected, conflict = expectedBranchExcluding(topology, currentNode)
    if expected == nil and not conflict then
        return states
    end

    for _, value in ipairs(control.values or EMPTY_LIST) do
        if (value == "Major" or value == "Minor")
            and (conflict or value ~= expected)
        then
            states = setInvalid(states, value)
        end
    end
    return states
end

return topologyBranches
