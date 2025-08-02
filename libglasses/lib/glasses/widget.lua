local Widget = {}
Widget.__index = Widget

local function apply_translate(self_translate, parent_translate)
    return {
        self_translate[1] + parent_translate[1],
        self_translate[2] + parent_translate[2],
        self_translate[3] + parent_translate[3]
    }
end

local function apply_rotation(self_rotation, parent_rotation)
    return {
        self_rotation[1] + parent_rotation[1],
        self_rotation[2] + parent_rotation[2],
        self_rotation[3] + parent_rotation[3]
    }
end

local function apply_scale(self_scale, parent_scale)
    return {
        self_scale[1] * parent_scale[1],
        self_scale[2] * parent_scale[2],
        self_scale[3] * parent_scale[3]
    }
end

local function valueof(self, value_or_function)
    if type(value_or_function) == "function" then
        return value_or_function(self)
    else
        return value_or_function
    end
end

function Widget:new(options)
    local instance = setmetatable({}, self)
    options = options or {}

    instance.modifiers = {}
    instance.props = {
        translation = options.translation or {0, 0, 0},
        rotation = options.rotation or {0, 0, 0},
        scale = options.scale or {1, 1, 1},
        condition = options.condition or "ALWAYS",
        visible = options.visible,
        visibility = options.visibility or function(self) return true end,
        size = options.size or nil,
    }
    if instance.props.visible == nil then
        instance.props.visible = true
    end
    instance.instance = nil
    instance.children = {}
    return instance
end

function Widget:add(child)
    table.insert(self.children, child)
    child:setParent(self)

    if self.instance and not child.instance then
        child:instanciate()
    end
end
function Widget:remove(child)
    for i, v in ipairs(self.children) do
        if v == child then
            table.remove(self.children, i)
            break
        end
    end
end

function Widget:instanciate()
    for i, v in ipairs(self.children) do
        v:instanciate()
    end
    -- keep blank
end
function Widget:update()
    for i, v in ipairs(self.children) do
        v:update()
    end
    if self.instance then
        local visible_should = self.props.visibility(self) and self.props.visible
        if visible_should ~= self.instance.isVisible() then
            self.instance.setVisible(visible_should)
        end
        if self.applied_translation ~= self:getGlobalTranslation() then
            self:applyTranslation()
        end
        if self.applied_rotation ~= self:getGlobalRotation() then
            self:applyRotation()
        end
        if self.applied_scale ~= self:getGlobalScale() then
            self:applyScale()
        end
        if self.applied_size ~= valueof(self, self.props.size) then
            self:applySize()
        end
    end
end
function Widget:destroy()
    for i, v in ipairs(self.children) do
        v:destroy()
    end
    if self.instance then
        self.instance.removeWidget()
        self.instance = nil
    end
end
function Widget:signal(signal, ...)
    for i, v in ipairs(self.children) do
        v:signal(signal, ...)
    end
end
function Widget:match(x, y, z)
    for i, v in ipairs(self.children) do
        if v:match(x, y, z) then
            return v
        end
    end
    return nil
end

function Widget:getParent()
    return self.parent
end

function Widget:setParent(parent)
    self.parent = parent
end

-- 递归获取全局translation，调用父类方法
function Widget:getGlobalTranslation()
    if self.parent and self.parent.getGlobalTranslation then
        local parent_translate = self.parent:getGlobalTranslation()
        return apply_translate(valueof(self, self.props.translation), parent_translate)
    else
        return valueof(self, self.props.translation)
    end
end

-- 递归获取全局rotation
function Widget:getGlobalRotation()
    if self.parent and self.parent.getGlobalRotation then
        local parent_rotation = self.parent:getGlobalRotation()
        return apply_rotation(valueof(self, self.props.rotation), parent_rotation)
    else
        return valueof(self, self.props.rotation)
    end
end

-- 递归获取全局scale，调用父类方法
function Widget:getGlobalScale()
    if self.parent and self.parent.getGlobalScale then
        local parent_scale = self.parent:getGlobalScale()
        return apply_scale(valueof(self, self.props.scale), parent_scale)
    else
        return valueof(self, self.props.scale)
    end
end

function Widget:getGlasses()
    if not self.parent and not self.props.glasses then
        error("No glasses found")
    end
    return self.props.glasses or self.parent:getGlasses()
end

function Widget:applyTranslation()
    for _, modifier in ipairs(self.instance.modifiers()) do
        if modifier.type() == "translate" then
            modifier.remove()
        end
    end
    local translation = self:getGlobalTranslation()
    self.instance.addTranslation(table.unpack(translation))
    self.applied_translation = translation
end

function Widget:applyRotation()
    for _, modifier in ipairs(self.instance.modifiers()) do
        if modifier.type() == "rotation" then
            modifier.remove()
        end
    end
    local rotation = self:getGlobalRotation()
    -- lol bad code
    self.instance.addRotation(rotation[1], 1, 0, 0)
    self.instance.addRotation(rotation[2], 0, 1, 0)
    self.instance.addRotation(rotation[3], 0, 0, 1)
    self.applied_rotation = rotation
end

function Widget:applyScale()
    for _, modifier in ipairs(self.instance.modifiers()) do
        if modifier.type() == "scale" then
            modifier.remove()
        end
    end
    local scale = self:getGlobalScale()
    self.instance.addScale(table.unpack(scale))
    self.applied_scale = scale
end

function Widget:applySize()
    local size = valueof(self, self.props.size)
    if size ~= nil then
        self.instance.setSize(size[1], size[2])
    end
    self.applied_size = size
end

function Widget:apply()
    self:applyTranslation()
    self:applyRotation()
    self:applyScale()
    self:applySize()

    for i, v in ipairs(self.modifiers) do
        self["modifier_" .. v[1]](self, table.unpack(v, 2))
    end
end

function Widget.prop(name, packed)
    return function(self, ...)
        if packed then
            self.props[name] = { ... }
        else
            self.props[name] = ...
        end
        return self
    end
end
function Widget.modifier(name)
    return function(self, ...)
        table.insert(self.modifiers, { name, ... })
        return self
    end
end

function Widget:modifier_color(r, g, b, a)
    self.last_modifier = self.instance.addColor(r, g, b, a)
end
function Widget:modifier_condition(condition)
    self.instance.setCondition(self.last_modifier, condition, true)
end

Widget.glasses = Widget.prop("glasses")
Widget.visible = Widget.prop("visible")
Widget.visibility = Widget.prop("visibility")
Widget.translation = Widget.prop("translation", true)
Widget.rotation = Widget.prop("rotation", true)
Widget.scale = Widget.prop("scale", true)
Widget.size = Widget.prop("size", true)

Widget.color = Widget.modifier("color")
Widget.condition = Widget.modifier("condition")

return Widget
