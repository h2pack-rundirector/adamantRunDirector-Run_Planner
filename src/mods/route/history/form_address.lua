local formAddress = {}

local function positiveIndex(value)
    local index = math.floor(tonumber(value) or 0)
    if index < 1 then
        return nil
    end
    return index
end

function formAddress.row(rowIndex)
    rowIndex = positiveIndex(rowIndex)
    if rowIndex == nil then
        return nil
    end
    return {
        rowIndex = rowIndex,
    }
end

function formAddress.child(rowIndex, childKind, childIndex)
    rowIndex = positiveIndex(rowIndex)
    if rowIndex == nil then
        return nil
    end
    return {
        rowIndex = rowIndex,
        childKind = childKind,
        childIndex = positiveIndex(childIndex),
    }
end

function formAddress.copy(address)
    if address == nil then
        return nil
    end
    return {
        rowIndex = address.rowIndex,
        childKind = address.childKind,
        childIndex = address.childIndex,
    }
end

function formAddress.withRowFallback(address, rowIndex)
    return formAddress.copy(address) or formAddress.row(rowIndex)
end

function formAddress.rowIndex(address, fallback)
    return address and address.rowIndex or fallback
end

function formAddress.key(address)
    if address == nil or address.rowIndex == nil then
        return nil
    end
    return tostring(address.rowIndex)
        .. ":"
        .. tostring(address.childKind or "row")
        .. ":"
        .. tostring(address.childIndex or "")
end

return formAddress
