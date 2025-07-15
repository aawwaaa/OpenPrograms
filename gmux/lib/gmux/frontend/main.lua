local event = require("event")
local component = require("component")
local windows = require("gmux/frontend/windows")
local graphics = require("gmux/frontend/graphics")
local desktop = require("gmux/frontend/desktop")
local os = require("os")
local api = require("gmux/frontend/api")
local filesystem = require("filesystem")
local package = require("package")
local serialization = require("serialization")

local M = {}

local backend = nil

local function load_apps()
    local apps = {}
    local path = filesystem.isDirectory("/usr/share/gmux/apps")
        and "/usr/share/gmux/apps" or "share/gmux/apps"
    for k in pairs(package.loaded) do
        if type(k) == "string" and k:sub(1, #path) == path then
            package.loaded[k] = nil
        end
    end
    local order = {}
    local order_file, error = io.open(path .. "/.order", "r")
    if order_file then
        order = order_file:read("*a")
        order_file:close()
        order = serialization.unserialize(order)
    end
    local original = package.path
    package.path = original .. ";/usr/share/?.lua;/usr/share/?/main.lua"
    for app in filesystem.list(path) do
        app = app:gsub("%.lua$", "")
        if app == ".order" then
            goto continue
        end
        table.insert(apps, {
            app = require("gmux/apps/" .. app),
            order = order[app] or 500
        })
        ::continue::
    end
    package.path = original
    table.sort(apps, function(a, b)
        return a.order < b.order
    end)
    for ind, app in ipairs(apps) do
        apps[ind] = app.app
    end
    return apps
end

local function load_plugins()
    local plugins = {}
    local path = filesystem.isDirectory("/usr/share/gmux/plugins")
        and "/usr/share/gmux/plugins" or "share/gmux/plugins"
    for k in pairs(package.loaded) do
        if type(k) == "string" and k:sub(1, #path) == path then
            package.loaded[k] = nil
        end
    end
    local original = package.path
    package.path = original .. ";/usr/share/?.lua;/usr/share/?/main.lua"
    for plugin in filesystem.list(path) do
        plugin = plugin:gsub("%.lua$", "")
        local ok, err = pcall(loadfile(path .. "/" .. plugin .. ".lua"), M)
        if not ok then
            api.show_error("Failed to load plugin: " .. plugin .. "\n" .. err)
        end
    end
    package.path = original
end

function M.handle_signal(...)
    local ok, err = xpcall(windows.handle_signal, debug.traceback, ...)
    if not ok then
        api.show_error(err)
    end
end

function M.main(be)
    backend = be
    graphics.gpu = component.gpu
    graphics.clear()
    event.register(nil, M.handle_signal, math.huge, math.huge)
    windows.init()
    local apps = load_apps()
    desktop.init(apps)

    load_plugins()

    while true do
        graphics.draw()
        windows.tick()
---@diagnostic disable-next-line: undefined-field
        pcall(os.sleep, 0)
    end
end

return M