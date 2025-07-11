local event = require("event")
local component = require("component")
local windows = require("frontend/windows")
local graphics = require("frontend/graphics")
local desktop = require("frontend/desktop")
local os = require("os")
local api = require("frontend/api")

local M = {}

local backend = nil

function M.main(be)
    backend = be
    graphics.gpu = component.gpu
    graphics.clear()
    event.register(nil, function(...)
        local ok, err = xpcall(windows.handle_signal, function(err)
            return err .. "\n" .. debug.traceback()
        end, ...)
        if not ok then
            api.show_error(err)
        end
    end, math.huge, math.huge)
    windows.init()
    desktop.init({
        require("frontend/apps/shell"),
        require("frontend/apps/lua_repl"),
        require("frontend/apps/run"),
        require("frontend/apps/monitor"),
        require("frontend/apps/exit")
    })

    while true do
        graphics.draw()
        windows.tick()
---@diagnostic disable-next-line: undefined-field
        pcall(os.sleep, 0)
    end
end

return M