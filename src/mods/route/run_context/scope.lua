local scope = {}

local function routeBiomeCount(route, EMPTY_LIST)
    return #(route and route.biomes or EMPTY_LIST)
end

local function clampBiomeCount(value, route, EMPTY_LIST)
    local maxCount = routeBiomeCount(route, EMPTY_LIST)
    if maxCount <= 0 then
        return 0
    end
    local count = math.floor(tonumber(value) or maxCount)
    if count < 1 then
        return 1
    end
    if count > maxCount then
        return maxCount
    end
    return count
end

local function biomeKeyForControl(context, routeKey, controlName)
    for biomeKey, info in pairs(context.routeInfoByRoute[routeKey] or {}) do
        if info.controlName == controlName then
            return biomeKey
        end
    end
    return nil
end

function scope.install(context, deps)
    local routeGlobalControlName = deps.routeGlobalControlName
    local EMPTY_LIST = deps.EMPTY_LIST

    function context:bindControl(control, routeKey)
        if control ~= nil and control.setRouteContext ~= nil then
            control:setRouteContext(self, routeKey)
        end
        return control
    end

    function context:routeInfo(routeKey, biomeKey)
        if biomeKey == nil then
            biomeKey = routeKey
            routeKey = nil
        end

        if routeKey ~= nil and self.routeInfoByRoute[routeKey] ~= nil then
            return self.routeInfoByRoute[routeKey][biomeKey]
        end
        return self.routeInfoByBiome[biomeKey]
    end

    function context:controlForBiome(routeKey, biomeKey)
        local info = self:routeInfo(routeKey, biomeKey)
        if info == nil then
            return nil
        end
        if self.controlResolver ~= nil then
            return self:bindControl(self.controlResolver(info.controlName, biomeKey, info.route.key), info.route.key)
        end
        if self.controls ~= nil and self.controls.get ~= nil then
            return self:bindControl(self.controls.get(info.controlName), info.route.key)
        end
        return nil
    end

    function context:controlByName(controlName, routeKey)
        local control
        if self.controlResolver ~= nil then
            control = self.controlResolver(controlName, nil, routeKey)
        elseif self.controls ~= nil and self.controls.get ~= nil then
            control = self.controls.get(controlName)
        end
        return self:bindControl(control, routeKey)
    end

    function context:configuredBiomeCount(routeKey)
        local route = self.routes.lookup and self.routes.lookup[routeKey] or nil
        local control = self:controlByName(routeGlobalControlName(routeKey), routeKey)
        local count = control ~= nil
            and control.configuredBiomeCount ~= nil
            and control:configuredBiomeCount()
            or nil
        return clampBiomeCount(count, route, EMPTY_LIST)
    end

    function context:isBiomeInConfiguredScope(routeKey, biomeKeyOrIndex)
        if type(biomeKeyOrIndex) == "number" then
            return biomeKeyOrIndex <= self:configuredBiomeCount(routeKey)
        end
        local info = self:routeInfo(routeKey, biomeKeyOrIndex)
        return info ~= nil and info.index <= self:configuredBiomeCount(routeKey)
    end

    function context:configuredRoute(routeKey)
        local route = self.routes.lookup and self.routes.lookup[routeKey] or nil
        if route == nil then
            return nil
        end

        local configuredCount = self:configuredBiomeCount(routeKey)
        if configuredCount >= routeBiomeCount(route, EMPTY_LIST) then
            return route
        end

        local biomes = {}
        for index = 1, configuredCount do
            biomes[index] = route.biomes[index]
        end
        return {
            key = route.key,
            label = route.label,
            biomes = biomes,
        }
    end

    function context:godSourceForRoute(routeKey)
        if self.godSourceByRoute[routeKey] ~= nil then
            return self.godSourceByRoute[routeKey]
        end
        local control = self:controlByName(routeGlobalControlName(routeKey), routeKey)
        if control ~= nil and control.godSourceDrawOpts ~= nil then
            self.godSourceByRoute[routeKey] = control
            return control
        end
        return nil
    end

    function context:isLayerConfigured(routeKey, layer)
        local control = self:controlByName(routeGlobalControlName(routeKey), routeKey)
        if control ~= nil and control.isLayerConfigured ~= nil then
            return control:isLayerConfigured(layer) ~= false
        end
        return true
    end

    function context:isControlConfigured(routeKey, controlName)
        if controlName == routeGlobalControlName(routeKey) then
            return true
        end
        local biomeKey = biomeKeyForControl(self, routeKey, controlName)
        if biomeKey ~= nil then
            return self:isBiomeInConfiguredScope(routeKey, biomeKey)
        end
        return true
    end

    function context:attachControls()
        for _, route in ipairs(self.routes.ordered or EMPTY_LIST) do
            self:godSourceForRoute(route.key)
            for _, biomeKey in ipairs(route.biomes or EMPTY_LIST) do
                self:controlForBiome(route.key, biomeKey)
            end
        end
    end
end

return scope
