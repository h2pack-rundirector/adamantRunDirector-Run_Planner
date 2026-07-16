local none = {}

function none.prepare(binding)
    if binding.kind ~= "none" then
        error("none component requires a none binding", 0)
    end
    return { kind = "none" }
end

function none.storage(_)
    return {}
end

function none.read(_, _, _)
    return nil
end

function none.write(_, _, _, context)
    error(context .. ": none reward does not accept authored state", 0)
end

function none.isComplete(_, value)
    return value == nil
end

return none
