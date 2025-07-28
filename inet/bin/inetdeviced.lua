local event = require("event")
local computer = require("computer")

if not require("component").isAvailable("modem") then
    io.stderr:write("Modem not found")
    return
end

local modem = require("component").modem
local shell = require("shell")

local inet = require("inet")
local router = require("inet/router")
local switch = require("inet/switch")

local args, options = shell.parse(...)

local type = args[1] or "router"

local handle_signal, timer = (type == "root" and router.init_as_root
    or type == "switch" and switch.init
    or router.init)({
    modem = modem.address,
    port = 10251,
    mode = type == "root" and "router" or type,
    send_impl = modem.send,
    broadcast_impl = modem.broadcast,
    pull_signal = event.pull,
    push_signal = event.push,
    uptime = computer.uptime,
    logging = options.l or options.logging,

    access_point_config = {
        name = options.name or (type .. "-" .. modem.address:sub(1, 8)),
        verify = options.verify,
        accept = function(src, ...)
            if options.verify == "password" then
                local password = ...
                if password == options.password then
                    return true, "Password verified"
                end
                return false, "Invalid password"
            end
            return true, "No verification"
        end
    },
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