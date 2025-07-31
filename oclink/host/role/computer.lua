local util = require("util")

local M = {}

M.onconnected = function(client)
    local wrapper = util.file("data/wrapper.lua")
    client:send(wrapper)

    for short, object in pairs(M.vcomponents) do
        local t = {"component", object.address, object.type, object.slot}
        for key, value in pairs(object) do
            if type(value) == "function" then
                table.insert(t, key)
            end
        end
        client:send(table.unpack(t))
    end
    client:send("component", nil)

    client.components = {}
    client.component_handlers = {}

    function client:signal(...)
        client:send("signal", ...)
    end
end
M.onmessage = function(client, type, ...)
    if type == "component" then
        local address, type = ...
        if address == nil then return end
        client.components[address] = type
        if M.handlers[type] then
            print("H " .. address .. " " .. type)
            client.component_handlers[address:sub(1, 4)] = M.handlers[type](client, address, select(3, ...))
        end
    end
    if type == "i" then
        local address, method = ...
        client:send("r", M.vcomponents[address][method](select(3, ...)))
    end
    if type == "im" then
        local address, method = ...
        if client.component_handlers[address] then
            client.component_handlers[address].invoke(method, select(3, ...))
        end
    end
end
M.onclosed = function(client)
    for _, handler in pairs(client.component_handlers) do
        handler.close()
    end
end

M.vcomponents = {}
M.handlers = {}

return M