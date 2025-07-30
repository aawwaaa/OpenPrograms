local inet = require("inet")

local M = {}

local address_spacing = inet.constants.address_spacing
local address_spacing_escaped = inet.constants.address_spacing_escaped
local broadcast_symbol = inet.constants.broadcast_symbol
local messages = inet.constants.messages
local log_type = inet.constants.log_type
local timeouts = inet.constants.timeouts
local log = inet.constants.log
local debug_log = inet.constants.debug_log
local send = inet.constants.send
local broadcast = inet.constants.broadcast
local shorten = inet.constants.shorten

local push_signal = function(...) end
local uptime = function() return 1 end

local access_point_config = {
    name = "Router",
    verify = nil,
    accept = function(src, ...) return true end,
    hidden = false
}
local access_point_accepted = {}
local device_store = {}
M.device_store = device_store
local device_store_deferred = {}
M.device_store_deferred = device_store_deferred

local parent_broadcast_address = ""

local function add_device(short, device)
    device_store[short] = {
        address = device,
        lifetime = uptime() + timeouts.device
    }
    if device_store_deferred[short] then
        for _, func in ipairs(device_store_deferred[short]) do
            func(short, device)
        end
        device_store_deferred[short] = nil
    end
end
local function device_deferred(short, func)
    device_store_deferred[short] = device_store_deferred[short] or {}
    table.insert(device_store_deferred[short], func)
end
M.device_deferred = device_deferred
M.add_device = add_device

local con = inet.con

local function check_reject(src_modem)
    if not access_point_accepted[src_modem] then
        send(src_modem, messages.rejected)
        log(log_type.route, "Rejected: " .. src_modem)
        return true
    end
    return false
end
M.check_reject = check_reject

local function timer()
    for id, data in pairs(device_store) do
        if data.lifetime < uptime() then
            device_store[id] = nil
            log(log_type.discover, "Device expired: " .. id)
        end
    end
end

local signals = {
    [messages.ping] = function(src_modem, this)
        if inet.status().status ~= "connected" then
            return
        end
        debug_log(log_type.ping, "Ping")
        send(src_modem, messages.pong)
        if this then
            add_device(this, src_modem)
        end
    end,
    [messages.request_available_access_point] = function(src_modem, ...)
        if src_modem == con.ap then
            return
        end
        if access_point_config.hidden then
            return
        end
        send(src_modem, messages.response_available_access_point, con.addr or "l",
            access_point_config.name, access_point_config.verify)
        log(log_type.discover, "Access point requested.")
    end,
    [messages.verify] = function(src_modem, ...)
        local result, message;
        if access_point_config.verify == nil then
            access_point_accepted[src_modem] = true
            log(log_type.verify, "Verified: " .. src_modem, "No verification")
            result, message = true, "No verification"
        else
            result, message = access_point_config.accept(src_modem, ...)
            if result then
                access_point_accepted[src_modem] = true
                log(log_type.verify, "Verified: " .. src_modem, message)
            else
                log(log_type.verify, "Rejected: " .. src_modem, message)
            end
        end
        send(src_modem, messages.response_verify, result, message)
    end,
}

function M.init(options)
    access_point_config = options.access_point_config or access_point_config

    for key, value in pairs(signals) do
        inet.signals.router[key] = value
        inet.signals.switch[key] = value
    end

    push_signal = options.push_signal or push_signal
    uptime = options.uptime or uptime

    local event_handler, t = inet.init(options)
    return event_handler, function()
        timer()
        t()
    end
end
local orequest_address = inet.request_address
---@diagnostic disable-next-line: duplicate-set-field
function inet.request_address()
    local address = orequest_address()
    return address
end
local oconnect_to = inet.connect_to
---@diagnostic disable-next-line: duplicate-set-field
function inet.connect_to(point)
    oconnect_to(point)
    access_point_accepted = {}
    access_point_accepted[point] = true
end
local odisconnect = inet.disconnect
---@diagnostic disable-next-line: duplicate-set-field
function inet.disconnect()
    odisconnect()
    device_store = {}
    device_store_deferred = {}
    access_point_accepted = {}
end
local ostatus = inet.status
---@diagnostic disable-next-line: duplicate-set-field
function inet.status()
    local status = ostatus()
    status.device_store = device_store
    return status
end

return M