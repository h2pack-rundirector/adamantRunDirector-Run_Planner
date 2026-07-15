local configurationRevision = {}

function configurationRevision.install(module, opts)
    opts = opts or {}
    local revision = 0

    local function advance(host, runtime)
        revision = revision + 1
        if opts.onAdvance ~= nil then
            opts.onAdvance(host, runtime, {
                revision = revision,
            })
        end
    end

    module.onActivate(function(host, runtime)
        advance(host, runtime)
    end)

    module.onCommit(function(host, runtime, commit)
        if commit.hadConfigChanges() then
            advance(host, runtime)
        end
    end)

    module.onReload(function(host, runtime, reload)
        if reload.hadSettingChanges() then
            advance(host, runtime)
        end
    end)

    return {
        current = function()
            return revision
        end,
    }
end

return configurationRevision
