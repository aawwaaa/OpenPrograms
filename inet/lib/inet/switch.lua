local inet = require("inet")
local access_point = require("inet/access_point")

local M = {}

local address_spacing_escaped = inet.constants.address_spacing_escaped
local address_spacing = inet.constants.address_spacing
local broadcast_symbol = inet.constants.broadcast_symbol
local messages = inet.constants.messages
local log_type = inet.constants.log_type
local log = inet.constants.log
local shorten = inet.constants.shorten
local send = inet.constants.send
local broadcast = inet.constants.broadcast
local update_status = inet.constants.update_status

local push_signal = function(...) end

local device_store = access_point.device_store

local con = inet.con

local switch_call_map = {}

local signal_switch = {
    [messages.request_address] = function(src_modem, device)
        if access_point.check_reject(src_modem) then
            return
        end
        switch_call_map[device] = src_modem
        send(con.ap, messages.request_address, device)
        log(log_type.assign, "Assign address forward: " .. shorten(device) .. " -> " .. shorten(con.ap))
    end,
    [messages.response_address] = function(src_modem, device, address, this)
        send(switch_call_map[device], messages.response_address, device, address, this)
        access_point.add_device(this, switch_call_map[device])
        log(log_type.assign, "Address response forward: " .. this .. " with " .. address .. " -> " .. shorten(switch_call_map[device]))
        switch_call_map[device] = nil
    end,
    [messages.request_nearby_device] = function(src_modem, device)
        if con.addr:sub(1, #device) == device and src_modem == con.ap then
            send(src_modem, messages.response_nearby_device, device)
            return
        end
        broadcast(messages.request_nearby_device, device)
        log(log_type.discover, "Request nearby device forward: " .. device)
        switch_call_map[device] = src_modem
    end,
    [messages.response_nearby_device] = function(src_modem, address)
        access_point.add_device(address, src_modem)
        send(switch_call_map[address],
            messages.response_nearby_device, address)
        log(log_type.discover, "Response nearby device: " .. address .. " -> " .. switch_call_map[address])
        switch_call_map[address] = nil
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
                if src_modem ~= con.ap then
                    log(log_type.route, "Forward message: parent: " .. src .. " -> " .. dst, ...)
                    send(con.ap, msg, ...)
                    return
                end
                for short, data in pairs(device_store) do
                    if data.address == con.ap then
                        goto continue
                    end
                    send(data.address, msg, ...)
                    ::continue::
                end
                push_signal("inet", dst, src, ...)
                push_signal("inet_full", dst, id, src, ...)
                log(log_type.route, "Broadcast message: target: " .. src .. " -> " .. dst, ...)
                return
            end
            if device_store[next] ~= nil then
                send(device_store[next].address, msg, ...)
                log(log_type.route, "Forward message: child: " .. src .. " -> " .. dst, ...)
            else
                log(log_type.route, "Forward message: parent: " .. src .. " -> " .. dst, ...)
                send(con.ap, msg, ...)
            end
            push_signal("inet", dst, src, ...)
            push_signal("inet_full", dst, id, src, ...)
            return
        else
            send(con.ap, msg, ...)
            log(log_type.route, "Forward message: parent: " .. src .. " -> " .. dst, ...)
            return
        end
    end
}

function M.init(options)
    options.mode = "switch"
    for key, value in pairs(signal_switch) do
        inet.signals.switch[key] = value
    end
    push_signal = options.push_signal or push_signal
    return access_point.init(options)
end

local overify = inet.verify
---@diagnostic disable-next-line: duplicate-set-field
function inet.verify(...)
    local result, message = overify(...)
    if result then
---@diagnostic disable-next-line: undefined-field
        con.addr = con.ap_data.address
        con.addr_esc = con.addr:gsub(address_spacing_escaped, "%" .. address_spacing_escaped)
        con.parent = con.addr:match("^(.+)" .. address_spacing_escaped) or ""
        con.parent_esc = con.parent:gsub(address_spacing_escaped, "%" .. address_spacing_escaped)
        con.broadcast = con.parent .. (con.parent ~= "" and address_spacing or "") .. broadcast_symbol
        update_status("connected")
    end
    return result, message
end

return M
