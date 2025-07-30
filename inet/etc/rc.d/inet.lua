local component = require("component")
local event = require("event")
local computer = require("computer")
local inet = require("inet")

local function load_config(path)
    local config_file = io.open(path, "r")
    local config_data = config_file and config_file:read("*a") or "{}"
    if config_file then config_file:close() end

    local config, err = load("return " .. config_data, "=config", "bt", {})
    if not config then
        error("Error loading inet config: " .. err)
    end
    return config()
end

function start()
end

-- daemon
do
    local config = load_config("/etc/inetd.cfg")

    if not config.enabled then
        return
    end

    if inet.inited() then
        goto continue
    end

    local modem, port = nil, config.port
    for address, component_type in pairs(component.list("modem")) do
        if config.modem == "*" or address:sub(1, #config.modem) == config.modem then
            modem = component.proxy(address)
            break
        end
    end
    if not modem then
        print("Modem not found: " .. config.modem)
        return
    end

    local init, options = nil, nil

    if config.mode == "client" then
        init = inet.init
        options = {
            modem = modem.address, port = port,
            mode = "client",
        }
    elseif ("router,switch,root"):match(config.mode) then
        local parsed_names = {}
        for k, v in pairs(config) do
            if k:sub(1, 1) == "." then
                parsed_names[k:sub(2)] = v
            end
        end
        options = {
            modem = modem.address, port = port,
            mode = config.mode,
            names = parsed_names,
            access_point_config = {
                name = config.name or (config.mode .. "-" .. modem.address:sub(1, 8)),
                verify = config.verify ~= "" and config.verify or nil,
                accept = function(src, ...)
                    if config.verify == "password" then
                        local password = ...
                        if password == config.password then
                            return true, "Password verified"
                        end
                        return false, "Invalid password"
                    end
                    return true, "No verification"
                end
            }
        }
        if config.mode == "router" then
            init = require("inet/router").init
        elseif config.mode == "switch" then
            init = require("inet/switch").init
        elseif config.mode == "root" then
            init = require("inet/router").init_as_root
            options.mode = "router"
        end
    else
        print("Invalid mode: " .. config.mode)
        return
    end

    options.send_impl = modem.send
    options.broadcast_impl = modem.broadcast
    options.pull_signal = event.pull
    options.push_signal = event.push
    options.uptime = computer.uptime
    options.logging = config.logging

    if not init then
        print("Something went wrong")
        return
    end

    local handle_signal, timer = init(options)

    modem.open(port)

    event.register(nil, handle_signal, math.huge, math.huge)
    event.timer(3, timer, math.huge)

    event.listen("inet", function(_, dst, src, ...)
        local type = inet.suffix(dst)
        if type == "ping" then
            inet.send(inet.with_suffix(src, "pong"), computer.uptime())
        end
    end)

    ::continue::
end

-- connection
do
    local config = load_config("/etc/inetcon.cfg")

    if not config.enabled then
        goto continue
    end

    require("thread").create(function()
        local aps = inet.list_access_points()
        local ap = nil
        for dev, data in pairs(aps) do
            if dev:sub(1, #config.ap) == config.ap or config.ap == "*" and data.verify == nil then
                ap = dev
                break
            end
        end
        if ap then
            inet.connect_to(ap)
            inet.verify(config.verify)
            inet.request_address()
        end
    end):start()

    ::continue::
end