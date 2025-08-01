#!/usr/bin/env lua

if package.loaded.computer then
    print("Please DO NOT run this file INSIDE OpenComputers.")
    print("It's for physical computer only.")
    return
end

local server = require("server")

local roles = {
    computer = require("role.computer"),
    screen = require("role.screen"),
}
local vcomponent = {
    filesystem = require("vcomponent.filesystem"),
}
roles.computer.vcomponents = {
    ["file"] = vcomponent.filesystem("filesyst-em00-4000-0000-000000000000", "./vfs"),
}
roles.computer.handlers = {
    gpu = require("handler.gpu"),
    screen = require("handler.screen"),
    keyboard = require("handler.keyboard"),
}

server.onconnected = function(client)
    print("? client connected")
    client.role = nil
end
server.onmessage = function(client, ...)
    -- print("M " .. tostring(client.role) .. " | " .. table.concat({...}, " "))
    if client.role == nil then
        client.role = ...
        print("+ " .. client.role)
        roles[client.role].onconnected(client)
        return
    end
    roles[client.role].onmessage(client, ...)
end
server.onclosed = function(client)
    if client.role == nil then
        return
    end
    roles[client.role].onclosed(client)
    print("- " .. client.role)
end

while true do
    server.tick()
    server.sleep(0.01)
end