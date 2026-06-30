local overview = {}

local function biomeLabel(context, biomeKey)
    local biome = context and context.biomeLookup and context.biomeLookup[biomeKey] or nil
    return tostring(biome and (biome.label or biome.key) or biomeKey or "Route")
end

local function copyInvalidRow(invalidRow, extras)
    local copied = {}
    for key, value in pairs(invalidRow or {}) do
        copied[key] = value
    end
    for key, value in pairs(extras or {}) do
        copied[key] = value
    end
    return copied
end

local function missingControlInvalid(context, routeControlName, routeBiomeIndex, biomeKey)
    return {
        biomeKey = biomeKey,
        routeBiomeIndex = routeBiomeIndex,
        controlName = routeControlName(biomeKey),
        locationLabel = biomeLabel(context, biomeKey),
        code = "missing_control",
        message = "Missing route control: " .. tostring(biomeKey),
    }
end

local function firstCompletionInvalid(routeControlName, routeBiomeIndex, biomeKey, completion)
    local invalid = completion and completion.completionInvalidRows and completion.completionInvalidRows[1] or nil
    if invalid == nil then
        return nil
    end
    return copyInvalidRow(invalid, {
        biomeKey = biomeKey,
        routeBiomeIndex = routeBiomeIndex,
        controlName = completion.controlName or routeControlName(biomeKey),
    })
end

local function layerForInvalid(invalid)
    if invalid.layer ~= nil then
        return invalid.layer
    end
    return "route"
end

local function blockingHorizon(context, route, invalid)
    if invalid == nil then
        return nil
    end

    local horizon = copyInvalidRow(invalid, {
        layer = layerForInvalid(invalid),
        routeKey = route.key,
    })
    if horizon.routeBiomeIndex == nil and horizon.biomeKey ~= nil then
        local info = context:routeInfo(route.key, horizon.biomeKey)
        horizon.routeBiomeIndex = info and info.index or nil
    end
    return horizon
end

function overview.install(context, deps)
    local state = deps.state
    local routePosition = deps.position
    local routeControlName = deps.routeControlName
    local EMPTY_LIST = deps.EMPTY_LIST

    function context:snapshot(routeKey)
        local route = self.routes.lookup and self.routes.lookup[routeKey] or nil
        local snapshots = {}
        local invalidRows = {}
        local missingInvalid
        local layerStatus = {
            route = {
                canDecorate = true,
                evaluated = false,
                valid = nil,
            },
        }
        if route == nil then
            local invalid = { code = "unknown_route", message = "Unknown route: " .. tostring(routeKey) }
            local routeFeedback = {
                valid = false,
                primary = invalid,
                related = {},
                markers = { invalid },
            }
            return {
                routeKey = routeKey,
                valid = false,
                disabled = true,
                invalidRows = { invalid },
                routeFeedback = routeFeedback,
                blockingHorizon = {
                    layer = "route",
                    routeKey = routeKey,
                    code = invalid.code,
                    message = invalid.message,
                },
                layerStatus = layerStatus,
                biomes = snapshots,
            }
        end

        local previousCompletionBuilding = self.completionBuilding
        self.completionBuilding = true
        local configuredBiomeCount = self:configuredBiomeCount(route.key)
        local completionInvalid = nil
        for routeBiomeIndex, biomeKey in ipairs(route.biomes or EMPTY_LIST) do
            if routeBiomeIndex > configuredBiomeCount then
                break
            end
            local completion = self:controlCompletionReport(route.key, biomeKey)
            snapshots[#snapshots + 1] = completion
            if missingInvalid == nil and not completion then
                missingInvalid = missingControlInvalid(self, routeControlName, routeBiomeIndex, biomeKey)
            end
            if completionInvalid == nil and completion then
                completionInvalid = firstCompletionInvalid(routeControlName, routeBiomeIndex, biomeKey, completion)
            end
        end
        self.completionBuilding = previousCompletionBuilding

        local routeFeedback
        if missingInvalid ~= nil then
            routeFeedback = {
                valid = false,
                primary = missingInvalid,
                related = {},
                markers = { missingInvalid },
            }
        elseif completionInvalid == nil then
            local historyFeedback = self:historyFeedback(route.key)
            routeFeedback = historyFeedback and historyFeedback.route or nil
        else
            routeFeedback = {
                valid = false,
                primary = completionInvalid,
                related = {},
                markers = { completionInvalid },
            }
        end

        routeFeedback = routeFeedback or {
            valid = true,
            primary = nil,
            related = {},
            markers = {},
        }

        for _, marker in ipairs(routeFeedback.markers or EMPTY_LIST) do
            invalidRows[#invalidRows + 1] = marker
        end

        local routeValid = routeFeedback.valid == true
        layerStatus.route.evaluated = true
        layerStatus.route.valid = routeValid

        return {
            routeKey = route.key,
            label = route.label,
            configuredBiomeCount = configuredBiomeCount,
            valid = routeValid,
            disabled = not routeValid,
            incomplete = completionInvalid ~= nil,
            incompleteBiomeKey = completionInvalid and completionInvalid.biomeKey or nil,
            incompleteControlName = completionInvalid and completionInvalid.controlName or nil,
            incompleteMessage = completionInvalid
                    and ("Data entry incomplete: finish " .. biomeLabel(self, completionInvalid.biomeKey))
                or nil,
            invalidRows = invalidRows,
            routeFeedback = routeFeedback,
            blockingHorizon = blockingHorizon(self, route, routeFeedback.primary),
            layerStatus = layerStatus,
            biomes = snapshots,
        }
    end

    function context:blockingHorizon(routeKey)
        local routeOverview = self:overview(routeKey)
        return routeOverview and routeOverview.blockingHorizon or nil
    end

    function context:canUseEnrichmentColors(routeKey)
        local routeOverview = self:overview(routeKey)
        return routeOverview ~= nil and routeOverview.valid == true
    end

    function context:isRouteBiomeInactive(routeKey, biomeKey)
        local horizon = self:blockingHorizon(routeKey)
        if horizon == nil or horizon.layer ~= "route" or horizon.routeBiomeIndex == nil then
            return false
        end
        local info = self:routeInfo(routeKey, biomeKey)
        return info ~= nil and info.index > horizon.routeBiomeIndex
    end

    function context:isRouteRowInactive(routeKey, biomeKey, routeOrdinal, tabKey)
        local horizon = self:blockingHorizon(routeKey)
        if horizon == nil or horizon.layer ~= "route" then
            return false
        end
        local info = self:routeInfo(routeKey, biomeKey)
        local horizonKey = routePosition.key({
            routeBiomeIndex = horizon.routeBiomeIndex,
            tabKey = routePosition.tabKeyForInvalid(horizon),
            routeOrdinal = horizon.routeOrdinal,
        })
        if horizonKey == nil then
            return self:isRouteBiomeInactive(routeKey, biomeKey)
        end
        return routePosition.after(
            routePosition.key({
                routeBiomeIndex = info and info.index or nil,
                tabKey = tabKey or "rooms",
                routeOrdinal = routeOrdinal,
            }),
            horizonKey
        )
    end

    function context:isNavTabInactive(routeKey, tab)
        return self:isRouteBiomeInactive(routeKey, tab.key)
    end

    function context:overview(routeKey)
        local routeOverview = state.routeOverviewState(self, routeKey)
        if routeOverview.dirty or routeOverview.snapshot == nil then
            routeOverview.snapshot = self:snapshot(routeKey)
            routeOverview.dirty = false
        end
        return routeOverview.snapshot
    end
end

return overview
