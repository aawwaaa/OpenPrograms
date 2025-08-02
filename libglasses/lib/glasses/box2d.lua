local Widget = require("glasses.widget")
local Box2D = {}
Box2D.__index = Box2D
setmetatable(Box2D, { __index = Widget })

function Box2D:new(options)
    options = options or {}
    local instance = Widget.new(self, options)
    setmetatable(instance, self)
    return instance
end

function Box2D:instanciate()
    Widget.instanciate(self)
    self.instance = self:getGlasses().addBox2D()
    self:apply()
end

-- extend widget
function Widget:background(r, g, b, a)
    local box2d = Box2D:new({
        size = function(_) return self.instance and {self.instance.getSize()} or {1, 1} end,
    }):color(r, g, b, a):color(r, g, b, a) -- it's a feature
    self:add(box2d)
    return self, box2d
end

return Box2D
