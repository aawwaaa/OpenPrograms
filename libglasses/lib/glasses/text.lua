local Widget = require("glasses.widget")
local Text = {}
Text.__index = Text
setmetatable(Text, { __index = Widget })

local function valueof(self, value_or_function)
    if type(value_or_function) == "function" then
        return value_or_function(self)
    else
        return value_or_function
    end
end

function Text:new(options)
    options = options or {}
    local instance = Widget.new(self, options)
    setmetatable(instance, self)
    instance.props.text = options.text or ""
    instance.props.font = options.font or ""
    instance.props.fontSize = options.fontSize or 16
    return instance
end

function Text:instanciate()
    Widget.instanciate(self)
    self.instance = self:getGlasses().addText2D()
    self:apply()
end

function Text:update()
    Widget.update(self)
    if self.instance then
        if self.applied_text ~= valueof(self, self.props.text) then
            self:applyText()
        end
    end
end

function Text:applyText()
    self.instance.setText(valueof(self, self.props.text))
    self.instance.setFont(valueof(self, self.props.font))
    self.instance.setFontSize(valueof(self, self.props.fontSize))
    self.applied_text = valueof(self, self.props.text)
end

function Text:apply()
    Widget.apply(self)
    self:applyText()
end

Text.text = Widget.prop("text")
Text.font = Widget.prop("font")
Text.fontSize = Widget.prop("fontSize")

return Text
