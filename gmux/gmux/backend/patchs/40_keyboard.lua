local _keyboard = {}
for k, v in pairs(require("keyboard")) do
    _keyboard[k] = v
end
local coroutine = require("coroutine")
local config = require("gmux/backend/config")
return function(instances)
    local keyboard = {
        pressedChars = {},
        pressedCodes = {}
    }
    
    local metatable = {
        __index = _keyboard
    }
    setmetatable(keyboard, metatable)
    

    instances.keyboard = keyboard
end
