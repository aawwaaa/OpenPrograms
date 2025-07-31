-- 初始化 luasocket
local socket = require("socket")
local ClientProxy = require("screen.clientproxy")

local M = {}

M.onconnected = function(client) end
M.onmessage = function(client, ...) end
M.onclosed = function(client) end

-- 创建 TCP 服务器，监听 10252 端口
local server = assert(socket.bind("*", 10252))
server:settimeout(0) -- 非阻塞模式

print("Listening 10252")

-- 客户端连接列表
local clients = {}
local client_proxies = {}

function M.sleep(time)
    socket.sleep(time)
end

function M.tick()
    -- 接受新客户端
    local client = server:accept()
    if client then
        client:settimeout(0)
        table.insert(clients, client)
        table.insert(client_proxies, ClientProxy:new(client))
        M.onconnected(client_proxies[#client_proxies])
    end

    -- 处理已连接客户端的数据
    for i = #client_proxies, 1, -1 do
        local c = client_proxies[i]
        local err = c:update()
        while c:has() do
            M.onmessage(c, c:receive())
        end
        if err == "closed" then
            c.client:close()
            table.remove(clients, i)
            table.remove(client_proxies, i)
            M.onclosed(c)
        end
    end
end

return M