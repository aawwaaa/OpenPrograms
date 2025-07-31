local M = {}

M.handlers = {}

M.onconnected = function(client) end
M.onmessage = function(client, ...)
    if not client.address then
        client.address = ...
        client.handler = M.handlers[client.address]
        if not client.handler then
            print("Unknown screen address: " .. client.address)
            client:close()
            return
        end
        client.handler.init_screen(client)
        return
    end
    if not client.handler then
        return
    end
    client.handler.onmessage(...)
end
M.onclosed = function(client)
    if client.handler then
        client.handler.remove_screen()
    end
end

return M
