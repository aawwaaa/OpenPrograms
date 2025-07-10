local process = require("backend/process")
local patch = require("backend/patch")
local computer = require("computer")
local config = require("backend/config")

local M = {}

function M.load()
    patch.patch_coroutine()
    patch.inject_package_patchs()
end

function M.finish()
    patch.undo()
end

M.cpu_usage = 0
function M.loop(update)
    local last_yield = computer.uptime()
    local last_check = computer.uptime()
    while true do
        if process.is_empty() then
            break
        end
        if last_yield + config.loop_yield_timeout < computer.uptime() or process.all_waiting() then
            process.push_signal(computer.pullSignal(0))
            last_yield = computer.uptime()
        end
        if update then update() end
        xpcall(process.next, function(msg) process.error_handler(0, msg .. "\n" .. debug.traceback()) end)
        if process.is_begin() then
            local deltat = computer.uptime() - last_check
            last_check = computer.uptime()
            M.cpu_usage = deltat / config.loop_yield_timeout
        end
    end
end

M.process = process
M.virtual_components = {
    gpu = require("backend/virtual_components/gpu"),
    keyboard = require("backend/virtual_components/keyboard"),
    screen = require("backend/virtual_components/screen"),
    api = require("backend/virtual_components/api"),
}

return M;
