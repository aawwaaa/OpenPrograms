local inet = require("inet")
local shell = require("shell")
local event = require("event")
local computer = require("computer")

local args = shell.parse(...)

if #args < 1 then
    print("Usage: ping <address>")
    return
end

local address = args[1]

inet.send(inet.with_suffix(address, "ping"))
local timer = computer.uptime() + 5
local begin = computer.uptime()
local success = nil
while computer.uptime() < timer do
    local signal, result = event.pull(1)
    if signal == "inet" then
        local type = inet.suffix(result[1])
        if type == "pong" and result[2] == address then
            success = computer.uptime()
            break
        end
    end
end
if success then
    print("Ping success: " .. (success - begin) .. "s")
else
    print("Ping failed")
end