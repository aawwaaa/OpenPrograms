local inet = require("inet")
local shell = require("shell")

local args, options = shell.parse(...)

if #args < 1 then
    print("Usage: send [-r] <address> <message...>")
    return
end

local address = args[1]
local message = table.concat(args, " ", 2)

if options.r or options.reliable then
    inet.send_reliable(address, message)
else
    inet.send(address, message)
end