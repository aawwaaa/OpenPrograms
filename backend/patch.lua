local coroutine = require("coroutine")
local config = require("backend/config")

local M = {}
local process = {
    current_process = nil
}

M.set_process = function(p)
    process = p
end

M.patchs = {
    require("backend/patchs/01_computer"),
    require("backend/patchs/02_event"),
    require("backend/patchs/03_component"),
    require("backend/patchs/04_thread"),
    require("backend/patchs/40_keyboard"),
    require("backend/patchs/50_tty"),
    require("backend/patchs/51_core_cursor"),
    require("backend/patchs/52_term"),
    require("backend/patchs/60_io"),
    require("backend/patchs/91_gpu"),
    require("backend/patchs/92_keyboard"),
    require("backend/patchs/93_term"),
}

M.package_patchs = {
    "computer",
    "event",
    "component",
    "thread",
    "keyboard",
    "tty",
    "core/cursor",
    "term"
}

function M.patch_coroutine()
    local _resume = coroutine.resume
    coroutine.resume = function(co, ...)
        while true do
            local result = table.pack(_resume(co, ...))
            if result[0] ~= config.yield_magic_value then
                return table.unpack(result)
            end
            coroutine.yield(table.unpack(result, 1, #result))
        end
    end
end

function M.create_patch_instances(options)
    local instances = {
        loads = {
            load = {},
            unload = {}
        }
    }
    for _, patch in ipairs(M.patchs) do
        patch(instances, options)
    end
    return instances
end

function M.inject_package_patchs()
    for _, patch in ipairs(M.package_patchs) do
        require(patch)
        local obj = package.loaded[patch]
        local real = {}
        for k, v in pairs(obj) do
            real[k] = v
        end
        local metatable = {
            __index = function(_, key)
                if key == "__real" then return real end
                if process.current_process then
                    return process.current_process.instances[patch][key]
                end
                return real[key]
            end,
            __newindex = function(_, key, value)
                if process.current_process then
                    process.current_process.instances[patch][key] = value
                end
                real[key] = value
            end
        }
        setmetatable(real, getmetatable(obj))
        setmetatable(obj, nil)
        for k, _ in pairs(obj) do
            obj[k] = nil
        end
        setmetatable(obj, metatable)
    end
end

function M.undo()
    for _, patch in ipairs(M.package_patchs) do
        local obj = package.loaded[patch]
        local real = obj.__real
        setmetatable(obj, nil)
        for k, v in pairs(real) do
            obj[k] = v
        end
        setmetatable(obj, getmetatable(real))
    end
end

return M
