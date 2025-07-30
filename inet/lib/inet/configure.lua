local component = require("component")
local computer = require("computer")
local serialization = require("serialization")
local shell = require("shell")
local tty = require("tty")

tty.clear()

print("Configuring Inet...")

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

    local wireless_strength = 400

    if modem ~= "*" and component.invoke(modem, "isWireless") then
        io.write("Wireless strength? [400] ")
        local wireless_strength = tonumber(io.read("*l")) or wireless_strength
        print("Wireless strength: " .. wireless_strength)
    end

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
        enabled = true,
        wireless_strength = wireless_strength,
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
    io.write("Do you want to run it now? [n]")

    local run = io.read("*l"):sub(1,1) == "y"
    if run then
        loadfile(shell.resolve("inetconfig","lua"))("d")
    end
end

local function configure_connection()
    print("Connection:")
    print("1. Automatically connect to the access point that needn't verify.")
    print("2. Scan for access points and pick one.")
    print("3. Manually configure.")
    print("4. Do not connect.")
    io.write("Connection type? [1] ")
    local type = io.read("*l")
    if type == "" then type = "1" end

    local config = {
        enabled = true,
        ap = "*",
        verify = ""
    } -- type 1

    if type == "2" then
        print("Initializing inet...")
        local file = io.open("/etc/inetcon.cfg", "w")
        if file then
            file:write(serialization.serialize({enabled=false}, math.huge))
            file:close()
        else
            print("Failed to write config to /etc/inetcon.cfg")
        end
        dofile("/etc/rc.d/inet.lua")
        local inet = require("inet")
        print("Scanning for access points...")
        local ap_map = inet.list_access_points()
        local aps = {}
        for k, v in pairs(ap_map) do
            table.insert(aps, k)
        end
        table.sort(aps)
        if #aps == 0 then
            print("No access points found.")
            print("Using type 1.")
            goto write
        end
        for i, ap in ipairs(aps) do
            print(i .. ". " .. ap_map[ap].name .. " - " .. (ap_map[ap].verify or "Open"))
        end
        io.write("Select one: ")
        local index = tonumber(io.read("*l"))
        local ap = aps[index]
        config.ap = ap
        if ap_map[ap].verify then
            print("Verify prompt: " .. ap_map[ap].verify)
            config.verify = io.read("*l")
        end
    elseif type == "3" then
        loadfile(shell.resolve("inetconfig","lua"))("c")
        return
    elseif type == "4" then
        config.enabled = false
    end

    ::write::
    local file = io.open("/etc/inetcon.cfg", "w")
    if file then
        file:write(serialization.serialize(config, math.huge))
        file:close()
    else
        print("Failed to write config to /etc/inetcon.cfg")
    end
end

local config = configure_basic()
if config.mode ~= "client" then
    configure_access_point(config)
end

io.write("Writing config to /etc/inetd.cfg\n")
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

if config.modem ~= "*" then
    configure_connection()
else
    print("No modem found, skipping connection configuration.")
    print("You can configure it later by running inetconfig c")
end

print("\x1b[32mRestart is required.\x1b[0m")
print("Do not forget to make rc work if you haven't done so.")