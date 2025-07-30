print("Configuring Inet...")

local component = require("component")
local computer = require("computer")
local serialization = require("serialization")
local shell = require("shell")
local tty = require("tty")

tty.clear()

print("If you want to configure it again, run /usr/lib/inet/configure.lua")

local function configure_basic()
    print("1. Client")
    print("2. Router")
    print("3. Switch")
    print("4. Root")
    io.write("Which mode do you want to use? [1] ")
    
    local mode = ({
        ["1"] = "client",
        ["2"] = "router",
        ["3"] = "switch",
        ["4"] = "root",
    })[io.read("*l")] or "client"

    print("Mode: " .. mode)

    local modems = {}
    for address, _ in component.list("modem") do
        table.insert(modems, address)
    end
    table.sort(modems)

    local modem = nil

    if #modems == 0 then
        print("No modem found, skipping")
        modem = "*"
    elseif #modems == 1 then
        modem = modems[1]
    else
        print("Multiple modems found, please select one:")
        for i, address in ipairs(modems) do
            print(i .. ". " .. address)
        end
        io.write("Select one: ")
        local index = tonumber(io.read("*l"))
        modem = modems[index]
    end

    print("Modem: " .. modem)

    io.write("Port for inet: [10251] ")
    local port = tonumber(io.read("*l")) or 10251

    print("Port: " .. port)

    io.write("Logging? This is for debugging or demonstation. [false] ")
    local logging = io.read("*l"):sub(1,1) == "t"

    return {
        mode = mode,
        modem = modem,
        port = port,
        logging = logging,
        enabled = true
    }
end

local function configure_access_point(config)
    local default = config.mode .. "-" .. config.modem:sub(1,8)
    io.write("Name for access point? [".. default .. "] ")
    local name = io.read("*l")
    if name == "" then
        name = default
    end
    config.name = name

    print("1. None")
    print("2. Password")
    io.write("Verify type? [1] ")
    local verify = ({
        ["1"] = nil,
        ["2"] = "password",
    })[io.read("*l")]
    config.verify = verify

    if verify == "password" then
        io.write("Password? ")
        local password = io.read("*l")
        config.password = password
    end

    return config
end

local function configure_router()
    print("You can assign a name to devices connected to the router, by inetconfig d later.")
    print("The format is: .dev=name, where dev is the first 3 characters of the device's modem's address.")
    io.write("Do you want to run it now? [y]")

    local run = io.read("*l"):sub(1,1) == "y"
    if run then
        loadfile(shell.resolve("inetconfig"))("d")
    end
end

local config = configure_basic()
if config.mode ~= "client" then
    configure_access_point(config)
end

io.write("Writing config to /etc/inetd.cfg")
local file = io.open("/etc/inetd.cfg", "w")
if file then
    file:write(serialization.serialize(config, math.huge))
    file:close()
else
    print("Failed to write config to /etc/inetd.cfg")
end

if config.mode == "router" or config.mode == "root" then
    configure_router()
end

print("Do not forget to make rc work if you haven't done so.")