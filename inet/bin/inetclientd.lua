local event = require("event")
local computer = require("computer")
local shell = require("shell")

if not require("component").isAvailable("modem") then
    io.stderr:write("Modem not found")
    return
end

local args, options = shell.parse(...)

local modem = require("component").modem

local inet = require("inet")

local handle_signal, timer = inet.init({
    modem = modem.address,
    port = 10251,
    mode = "client",
    send_impl = modem.send,
    broadcast_impl = modem.broadcast,
    pull_signal = event.pull,
    push_signal = event.push,
    uptime = computer.uptime,
    logging = options.l or options.logging
})
modem.open(10251)

event.listen("modem_message", handle_signal)
event.timer(3, timer, math.huge)

event.listen("inet", function(_, dst, src, ...)
    local type = inet.suffix(dst)
    if type == "ping" then
        inet.send(inet.with_suffix(src, "pong"), computer.uptime())
    end
end)

print("inetd started")