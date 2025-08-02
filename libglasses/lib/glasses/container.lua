local Widget = require("glasses.widget")

local Container = {}
Container.__index = Container
setmetatable(Container, { __index = Widget })

function Container:new(func, options)
    options = options or {}
    local instance = Widget.new(self, options)
    setmetatable(instance, self)
    instance.proxy = setmetatable(self.widget_proxy_metatable, {
        __index = { widget = instance }
    })
    func(instance.proxy)
    return instance
end

return Container
