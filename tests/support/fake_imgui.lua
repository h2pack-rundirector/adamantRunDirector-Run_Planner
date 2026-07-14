local fakeImgui = {}

local function record(imgui, name, ...)
    imgui._calls[#imgui._calls + 1] = {
        name = name,
        args = { ... },
    }
end

local function append(lines, text)
    lines[#lines + 1] = tostring(text)
end

function fakeImgui.surface(overrides)
    local lines = {}
    local imgui = {
        _calls = {},
        _lines = lines,
    }

    function imgui.Text(text)
        record(imgui, "Text", text)
        append(lines, text)
    end

    function imgui.TextDisabled(text)
        record(imgui, "TextDisabled", text)
        append(lines, text)
    end

    function imgui.Separator()
        record(imgui, "Separator")
    end

    function imgui.SameLine()
        record(imgui, "SameLine")
    end

    function imgui.AlignTextToFramePadding()
        record(imgui, "AlignTextToFramePadding")
    end

    function imgui.PushItemWidth(width)
        record(imgui, "PushItemWidth", width)
    end

    function imgui.PopItemWidth()
        record(imgui, "PopItemWidth")
    end

    function imgui.GetWindowDrawList()
        record(imgui, "GetWindowDrawList")
        return {}
    end

    function imgui.GetStyle()
        record(imgui, "GetStyle")
        return {
            FramePadding = { x = 4 },
            ItemInnerSpacing = { x = 4 },
        }
    end

    function imgui.GetItemRectMin()
        record(imgui, "GetItemRectMin")
        return 10, 20
    end

    function imgui.GetItemRectMax()
        record(imgui, "GetItemRectMax")
        return 250, 44
    end

    function imgui.CalcTextSize(text)
        record(imgui, "CalcTextSize", text)
        return string.len(tostring(text)) * 8, 16
    end

    function imgui.GetFrameHeight()
        record(imgui, "GetFrameHeight")
        return 20
    end

    function imgui.GetColorU32(r, g, b, a)
        record(imgui, "GetColorU32", r, g, b, a)
        return {
            r = r,
            g = g,
            b = b,
            a = a,
        }
    end

    function imgui.PushClipRect(minX, minY, maxX, maxY, intersect)
        record(imgui, "PushClipRect", minX, minY, maxX, maxY, intersect)
    end

    function imgui.ImDrawListAddText(drawList, x, y, color, text)
        record(imgui, "ImDrawListAddText", drawList, x, y, color, text)
    end

    function imgui.PopClipRect()
        record(imgui, "PopClipRect")
    end

    function imgui.BeginChild(label, width, height, border)
        record(imgui, "BeginChild", label, width, height, border)
        return true
    end

    function imgui.EndChild()
        record(imgui, "EndChild")
    end

    function imgui.SmallButton(label)
        record(imgui, "SmallButton", label)
        return false
    end

    function imgui.BeginCombo(label, preview, flags)
        record(imgui, "BeginCombo", label, preview, flags)
        append(lines, tostring(label) .. ": " .. tostring(preview))
        return false
    end

    function imgui.Selectable(label, selected)
        record(imgui, "Selectable", label, selected)
        return false
    end

    function imgui.EndCombo()
        record(imgui, "EndCombo")
    end

    function imgui.CloseCurrentPopup()
        record(imgui, "CloseCurrentPopup")
    end

    function imgui.Checkbox(label, checked)
        record(imgui, "Checkbox", label, checked)
        append(lines, tostring(label) .. ": " .. tostring(checked))
        return checked, false
    end

    function imgui.Indent()
        record(imgui, "Indent")
    end

    function imgui.Unindent()
        record(imgui, "Unindent")
    end

    function imgui.BeginDisabled(disabled)
        record(imgui, "BeginDisabled", disabled)
    end

    function imgui.EndDisabled()
        record(imgui, "EndDisabled")
    end

    function imgui.PushStyleColor(kind, r, g, b, a)
        record(imgui, "PushStyleColor", kind, r, g, b, a)
    end

    function imgui.PopStyleColor()
        record(imgui, "PopStyleColor")
    end

    function imgui.IsItemHovered()
        record(imgui, "IsItemHovered")
        return false
    end

    function imgui.SetTooltip(message)
        record(imgui, "SetTooltip", message)
    end

    function imgui.BeginTabBar(label)
        record(imgui, "BeginTabBar", label)
        return false
    end

    function imgui.BeginTabItem(label)
        record(imgui, "BeginTabItem", label)
        return false
    end

    function imgui.EndTabItem()
        record(imgui, "EndTabItem")
    end

    function imgui.EndTabBar()
        record(imgui, "EndTabBar")
    end

    for key, value in pairs(overrides or {}) do
        imgui[key] = value
    end

    return lines, imgui
end

local function defaultNav(lines)
    return {
        verticalTabs = function(opts)
            for _, tab in ipairs(opts.tabs or {}) do
                local marker = tab.key == opts.activeKey and "* " or "  "
                append(lines, marker .. tostring(tab.label or tab.key))
            end
            return opts.activeKey
        end,
    }
end

function fakeImgui.lineSink(drawOverrides)
    local draw = drawOverrides or {}
    local lines, imgui = fakeImgui.surface(draw.imgui)
    draw.imgui = imgui
    draw.nav = draw.nav or defaultNav(lines)
    return lines, {
        draw = draw,
        data = {
            read = function()
                return nil
            end,
            write = function()
                return false
            end,
        },
        controls = {
            get = function()
                return nil
            end,
        },
    }
end

function fakeImgui.countCalls(imgui, name)
    local count = 0
    for _, call in ipairs(imgui._calls or {}) do
        if call.name == name then
            count = count + 1
        end
    end
    return count
end

return fakeImgui
