local computer = require("computer")
local event = require("event")
local component = require("component")
local desktop = require("frontend/desktop")
local api = require("frontend/api")
return function(backend)
    local gpu = component.gpu
    desktop.gpu = gpu
    desktop.desktop_items = {
        require("frontend/items/shell"),
        require("frontend/items/run"),
        require("frontend/items/monitor"),
    }
    event.register(nil, function(...)
        desktop.handle_signal(...)
    end, math.huge, math.huge)
    desktop.init()

    backend.process.error_handler = function(process, error)
        api.show_error("An error occurred in process " .. process.id .. ":\n" .. error)
        if component.isAvailable("ocelot") then component.ocelot.log(error) end
    end

    while true do
        desktop.tick()
        computer.pullSignal(0.001)
    end
end
