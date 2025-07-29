local inet = require("inet")
local access_point = require("inet/access_point")

local M = {}

local address_spacing_escaped = inet.constants.address_spacing_escaped
local broadcast_symbol = inet.constants.broadcast_symbol
local address_spacing = inet.constants.address_spacing
local messages = inet.constants.messages
local log_type = inet.constants.log_type
local log = inet.constants.log
local shorten = inet.constants.shorten
local send = inet.constants.send
local push_signal_internal = inet.constants.push_signal_internal
local update_status = inet.constants.update_status
local broadcast = inet.constants.broadcast

local push_signal = function(...) end

local device_store = access_point.device_store
local device_deferred = access_point.device_deferred

local names = {}

local con = inet.con

local signals_router = {
    [messages.request_address] = function(src_modem, device)
        if access_point.check_reject(src_modem) then
            return
        end
        local this = names[shorten(device)] or shorten(device)
        access_point.add_device(this, src_modem)
        local address = con.addr .. address_spacing .. this
        if con.addr == "" then
            address = address:sub(2)
        end
        send(src_modem, messages.response_address, device, address, this)
        log(log_type.assign, "Assign address: " .. this .. " -> " .. address)
    end,
    [messages.response_nearby_device] = function(src_modem, this)
        access_point.add_device(this, src_modem)
        push_signal_internal("response_nearby_device", this, src_modem)
        log(log_type.discover, "Response nearby device: " .. this .. " -> " .. src_modem)
    end,
    [messages.message] = function(src_modem, msg, src, dst, id, ...)
        if access_point.check_reject(src_modem) then
            return
        end
        if dst:sub(1, #con.addr) == con.addr then
            local next = dst:match("^" .. con.addr_esc
                .. (con.addr_esc ~= "" and address_spacing_escaped or "")
                .. "([^" .. address_spacing_escaped .. "]+)")
            if device_store[next] ~= nil and device_store[next].address == src_modem then
                return -- duplicated broadcast packet
            end
            if next == broadcast_symbol then
                broadcast(msg, ...)
                push_signal("inet", dst, src, ...)
                push_signal("inet_full", dst, id, src, ...)
                log(log_type.route, "Broadcast message: target: " .. src .. " -> " .. dst, ...)
                return
            end
            if device_store[next] ~= nil then
                send(device_store[next].address, msg, ...)
                log(log_type.route, "Forward message: child: " .. src .. " -> " .. dst, ...)
            else
                broadcast(messages.request_nearby_device, next)
                local packed = table.pack(msg, ...)
                device_deferred(next, function(short, device)
                    log(log_type.route, "Forward message: child: " .. src .. " -> " .. dst, table.unpack(packed))
                    send(device, table.unpack(packed))
                end)
                log(log_type.discover, "Request nearby device:", next)
            end
            push_signal("inet", dst, src, ...)
            push_signal("inet_full", dst, id, src, ...)
            return
        elseif dst:sub(1, #con.broadcast) == con.broadcast and src_modem == con.ap then
            local left = dst:match("^" .. con.parent_esc .. (con.parent_esc ~= "" and address_spacing_escaped or "")
                .. broadcast_symbol .. "(.*)")
            broadcast("m!" .. src .. "@" .. con.addr .. address_spacing .. broadcast_symbol .. left, ...)
            log(log_type.route, "Broadcast message: child: " .. src .. " -> " .. dst, ...)
            return
        else
            log(log_type.route, "Forward message: parent: " .. src .. " -> " .. dst, ...)
            send(con.ap, msg, ...)
            return
        end
    end
}

function M.init_as_root(options)
    options.mode = "router"
    local ret = table.pack(M.init(options))
    update_status("connected", "as root")
    con.addr = ""
    con.addr_esc = ""
    con.parent = ""
    con.broadcast = broadcast_symbol
    log(log_type.assign, "As root")
    return table.unpack(ret)
end
function M.init(options)
    options.mode = "router"
    names = options.names or {}
    for key, value in pairs(signals_router) do
        inet.signals.router[key] = value
    end
    push_signal = options.push_signal or push_signal
    return access_point.init(options)
end

return M