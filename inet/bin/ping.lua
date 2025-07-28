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

inet.send_suffix("pong", inet.with_suffix(address, "ping"))
local timer = computer.uptime() + 5
local begin = computer.uptime()
local success = nil
while computer.uptime() < timer do
    local signal, dst, src = event.pull(1)
    if signal == "inet" then
        local type = inet.suffix(dst)
        if type == "pong" and src == inet.with_suffix(address, "ping") then
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