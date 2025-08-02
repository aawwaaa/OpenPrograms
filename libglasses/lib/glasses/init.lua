--[[
Container
Input
Button
Text
Item
Box2D
]]

local M = {}

local widgets = {
    Container = require("glasses.container"),
    -- Input = require("glasses.input"),
    -- Button = require("glasses.button"),
    Text = require("glasses.text"),
    -- Item = require("glasses.item"),
    Box2D = require("glasses.box2d"),
}

local function proxy(class)
    return function(self, ...)
        local instance = class:new(...)
        self.widget:add(instance)
        return instance
    end
end
local widget_proxy_metatable = {
    container = proxy(widgets.Container),
    -- input = proxy(widgets.Input),
    -- button = proxy(widgets.Button),
    text = proxy(widgets.Text),
    -- item = proxy(widgets.Item),
    box2d = proxy(widgets.Box2D),
}

for _, v in pairs(widgets) do
    v.widget_proxy_metatable = widget_proxy_metatable
end

local root = nil
function M.root(glasses)
    if root then
        return root
    end
    root = widgets.Container:new(function(c) end):glasses(glasses)
    print("create!")
    return root
end

function M.update()
    if root then
        root:update()
    end
end

function M.signal(event, ...)
    if root then
        root:signal(event, ...)
    end
end

return M