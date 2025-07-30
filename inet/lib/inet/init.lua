local M = {}

--[[
Signals:
inet(local_address, source_address, ...) - packet
inet_full(local_address, packet_id, source_address, ...) - packet with id
inet_status(status, ...) - status
inet_ack(id) - ack
]]

local inetmodem = ""
local inetport = 0
local send_impl = function(dst, port, msg, ...) end
local broadcast_impl = function(port, msg, ...) end
local push_signal = function(type, ...) end
local pull_signal = function(...) end
local uptime = function() return 1 end
local mode = nil
local status = "disconnected"
local timer_end, timer_event = nil, function() end
local last_ping = 0
local access_points = {}

local con = {
    ap = nil,
    ap_data = nil,
    addr = nil,
    addr_esc = nil,
    this = nil,
    parent = nil,
    parent_esc = nil,
    broadcast = nil,
}
M.con = con
local connection_info = {
    disconnect_manually = false,
    ap = nil,
    verify = nil,
    retry_timer = 0
}
M.mode = function() return mode end
M.set_mode = function(m)
    mode = m
end

local wait_for_ack = {}
local acked = {}

local address_spacing = "."
local address_spacing_escaped = "%."
local broadcast_symbol = "~"

local messages = {
    request_available_access_point = "p",
    response_available_access_point = "P",
    request_address = "a",
    response_address = "A",
    request_nearby_device = "f",
    response_nearby_device = "F",
    ping = "c",
    pong = "C",
    verify = "v",
    response_verify = "V",
    message = "m",
    rejected = "!"
}

local timeouts = {
    access_point = 2,
    verify = 5,
    request_address = 5,
    ping = 3,
    ping_disconnect = 10,
    ack = 5,
    device = 300,
    connect_retry = 15
}
local max_tries = 5
local short_device_length = 3

local log_type = {
    status      = "\x1b[32mSTATUS   ",
    error       = "\x1b[31mERROR    ",
    discover    = "\x1b[34mDISCOVER ",
    assign      = "\x1b[33mASSIGN   ",
    message     = "\x1b[36mMESSAGE  ",
    route       = "\x1b[35mROUTE    ",
    ping        = "\x1b[36mPING     ",
    verify      = "\x1b[35mVERIFY   ",
    modem       = "\x1b[37mMODEM    ",
}

local logging = false
local function log(type, ...)
    if not logging then return end
    local packed = table.pack(...)
    for i = 1, packed.n do
        packed[i] = tostring(packed[i])
    end
    print(type .. table.concat(packed, " ") .. "\x1b[0m")
end
local debug_log = function(type, ...) end

local function shorten(address)
    return address:sub(1, short_device_length)
end
local function send(dst, msg, ...)
    ((msg == messages.ping or msg == messages.pong) and debug_log or log)
        (log_type.modem, ">", shorten(dst), msg, ...)
    send_impl(dst, inetport, msg, ...)
end
local function broadcast(msg, ...)
    log(log_type.modem, ">", "~~~", msg, ...)
    broadcast_impl(inetport, msg, ...)
end
local function push_signal_internal(...)
    push_signal("inet_internal", ...)
end
local function pull_signal_internal(...)
    local signal, timeout = ...
    if type(signal) == "number" then
        signal, timeout = nil, signal
    end
    local end_time = uptime() + (timeout or math.huge)
    while uptime() < end_time do
        local packed = table.pack(pull_signal(end_time - uptime()))
        if packed.n > 0 and packed[1] == "inet_internal" and packed[2] == signal then
            return table.unpack(packed, 2)
        end
    end
    return nil
end
local function update_status(s, ...)
    status = s
    push_signal("inet_status", s, ...)
    log(log_type.status, s, ...)
end

M.constants = {
    address_spacing = address_spacing,
    address_spacing_escaped = address_spacing_escaped,
    broadcast_symbol = broadcast_symbol,
    messages = messages,
    timeouts = timeouts,
    max_tries = max_tries,
    short_device_length = short_device_length,
    log_type = log_type,
    debug_log = debug_log,
    log = log,
    shorten = shorten,
    send = send,
    broadcast = broadcast,
    push_signal_internal = push_signal_internal,
    pull_signal_internal = pull_signal_internal,
    update_status = update_status,
}

local signals = {
    [messages.response_available_access_point] = function(src_modem, address, name, verify)
        access_points[src_modem] = {
            device = src_modem,
            address = address,
            name = name,
            verify = verify,
        }
        log(log_type.discover, "Access point discovered: " .. shorten(src_modem) .. ": " .. address .. " - " .. name)
    end,
    [messages.rejected] = function(src_modem, ...)
        if src_modem ~= con.ap then
            return
        end
        log(log_type.error, "Rejected: ", ...)
        update_status("disconnected", "rejected", ...)
    end,
    [messages.response_verify] = function(src_modem, result, message)
        if src_modem ~= con.ap then
            return
        end
        log(log_type.verify, "Response verify: ", result, message)
        push_signal_internal("response_verify", result, message)
    end,
    [messages.response_address] = function(src_modem, device, address, this)
        if src_modem ~= con.ap then
            return
        end
        log(log_type.assign, "Response address: " .. this .. " -> " .. address)
        push_signal_internal("response_address", device, address, this)
    end,
    [messages.ping] = function(src_modem)
        if status ~= "connected" then
            return
        end
        debug_log(log_type.ping, "Ping")
        send(src_modem, messages.pong)
    end,
    [messages.pong] = function(src_modem)
        if src_modem ~= con.ap then
            return
        end
        last_ping = uptime()
        debug_log(log_type.ping, "Pong")
    end,
    [messages.request_nearby_device] = function(src_modem, device)
        if con.this == device then
            send(src_modem, messages.response_nearby_device, device)
            log(log_type.discover, "Response nearby device: " .. device .. " -> " .. src_modem)
        end
    end,

    -- these is for micro controller config
    ["."] = function() end,
    [":"] = function() end,
    ["="] = function() end,
    [","] = function() end,
}
signals.client = {
    [messages.request_available_access_point] = function(src_modem, ...) end,
    [messages.message] = function(src_modem, msg, src, dst, id, ...)
        if dst:sub(1, #con.addr) == con.addr then
            if id ~= "" and id:sub(1, 1) == "!" then
                id = id:sub(2)
                push_signal("inet_ack", id)
                wait_for_ack[id] = nil
                log(log_type.message, "Message acknowledged: " .. id)
                return
            end
            if id ~= "" then
                send(src_modem, "m!" .. con.addr .. "@" .. src .. "#!" .. id)
                local repeated = acked[id] ~= nil
                acked[id] = uptime() + timeouts.ack
                if repeated then
                    log(log_type.message, "Message repeated: " .. id)
                    return
                end
            end
            push_signal("inet", dst, src, ...)
            push_signal("inet_full", dst, id, src, ...)
            log(log_type.message, "Message: " .. src .. " -> " .. dst, ...)
            return
        end
        if dst:sub(1, #con.broadcast) == con.broadcast then
            push_signal("inet", dst, src, ...)
            push_signal("inet_full", dst, nil, src, ...)
            log(log_type.message, "Message: " .. src .. " -> " .. dst, ...)
            return
        end
    end
}
signals.router = {}
signals.switch = {}
M.signals = signals

local function handle_signal(type, modem, src_modem, port, distance, msg, ...)
    if type ~= "modem_message" or modem ~= inetmodem or port ~= inetport then
        return
    end
    ((msg == messages.ping or msg == messages.pong) and debug_log or log)
        (log_type.modem, "<", shorten(src_modem), msg, ...)
    if msg:sub(1, 1) == messages.message then
        local src, dst, id = msg:match("^m!(.+)@([^#]+)#?(.*)$")
        signals[mode][messages.message](src_modem, msg, src, dst, id, ...)
        return
    end
    if signals[mode][msg] ~= nil then
        signals[mode][msg](src_modem, ...)
        return
    end
    if signals[msg] ~= nil then
        signals[msg](src_modem, ...)
        return
    end
    log(log_type.error, "Unknown message: " .. msg, ...)
end
local function timer()
    if timer_end ~= nil and uptime() > timer_end then
        timer_end = nil
        timer_event()
    end
    if status == "connected" and con.ap ~= nil then
        if last_ping + timeouts.ping < uptime() then
            send(con.ap, messages.ping, con.this)
            debug_log(log_type.ping, "Ping")
        end
        if last_ping + timeouts.ping_disconnect < uptime() then
            update_status("disconnected", "ping timeout")
        end
    end
    for id, data in pairs(acked) do
        if data < uptime() then
            acked[id] = nil
        end
    end
    for id, data in pairs(wait_for_ack) do
        if data.timeout < uptime() then
            data.tries = data.tries - 1
            if data.tries == 0 then
                wait_for_ack[id] = nil
                goto continue
            end
            send(con.ap, "m!" .. con.addr .. "@" .. data.dst .. "#" .. id,
                table.unpack(data.msg))
            log(log_type.message, "Resend message: " .. data.dst .. " -> " .. id, table.unpack(data.msg))
        end
        ::continue::
    end
    if status == "disconnected" and not connection_info.disconnect_manually then
        if connection_info.retry_timer < uptime() then
            connection_info.retry_timer = uptime() + timeouts.connect_retry
            log(log_type.assign, "Retry connect to: " .. connection_info.ap)
            require("thread").create(function()
                M.connect_to(connection_info.ap)
                M.verify(table.unpack(connection_info.verify))
                M.request_address()
            end):start()
        end
    end
end

local inited = false
function M.init(options)
    if inited then
        error("inet already initialized")
        return
    end
    inited = true
    inetmodem = options.modem
    inetport = options.port
    M.set_mode(options.mode or "client")

    send_impl = options.send_impl
    broadcast_impl = options.broadcast_impl
    push_signal = options.push_signal
    pull_signal = options.pull_signal
    uptime = options.uptime
    logging = options.logging
    return function(...)
        local status, err = xpcall(handle_signal, debug.traceback, ...)
        if not status then
            local lines = {}
            local count = 0
            for line in tostring(err):gmatch("([^\n]*)\n?") do
                table.insert(lines, line)
                count = count + 1
                if count >= 10 then break end
            end
            log(log_type.error, "Error: " .. table.concat(lines, "\n"))
        end
    end, timer
end
function M.inited() return inited end
local function wait(t)
    local end_time = uptime() + t
    while uptime() < end_time do
        pull_signal(end_time - uptime())
    end
end
function M.list_access_points()
    access_points = {}
    broadcast(messages.request_available_access_point)
    log(log_type.discover, "Request available access point")
    wait(timeouts.access_point)
    return access_points
end
function M.connect_to(point)
    update_status("connecting")
    con.ap = point
    con.ap_data = access_points[point]
    connection_info.ap = point
    connection_info.disconnect_manually = false
    log(log_type.assign, "Connect to: " .. point)
    last_ping = uptime() + timeouts.ping
end
function M.verify(...)
    send(con.ap, messages.verify, ...)
    log(log_type.verify, "Verify: ", ...)
    connection_info.verify = table.pack(...)
    local signal, result, message = pull_signal_internal("response_verify", timeouts.verify)
    if signal == nil then
        update_status("disconnected", "timeout")
        return nil, "timeout"
    end
    return result, message
end
function M.request_address()
    if mode == "switch" then
        update_status("connected")
        return
    end
    update_status("request_address")
    send(con.ap, messages.request_address, inetmodem)
    local signal, _, address, this = pull_signal_internal("response_address", timeouts.request_address)
    if signal == nil then
        update_status("disconnected", "timeout")
        return nil, "timeout"
    end
    if address == nil then
        update_status("disconnected", "no address")
        return nil, "no address"
    end
    con.addr = address
    con.this = this
    con.addr_esc = address:gsub(address_spacing_escaped, "%" .. address_spacing_escaped)
    con.parent = address:match("^(.+)" .. address_spacing_escaped) or ""
    con.parent_esc = con.parent:gsub(address_spacing_escaped, "%" .. address_spacing_escaped)
    con.broadcast = con.parent .. (con.parent ~= "" and address_spacing or "") .. broadcast_symbol
    update_status("connected")
    log(log_type.assign, "Assigned address: ", con.addr)
    return con.addr
end
function M.disconnect()
    update_status("disconnected")
    con.ap = nil
    con.ap_data = nil
    con.addr = nil
    con.addr_esc = nil
    con.parent = nil
    con.this = nil
    con.broadcast = nil
    con.parent_esc = nil
    connection_info.disconnect_manually = true
end
function M.auto_connect()
    update_status("connecting")
    M.list_access_points()
    local target = nil
    local target_length = -1
    for device, data in pairs(access_points) do
        if data.verify ~= nil then
            goto continue
        end
        local length = select(2, data.address:gsub(address_spacing_escaped, ""))
        if length > target_length then
            target_length = length
            target = device
        end
        ::continue::
    end
    if target == nil then
        update_status("disconnected", "no access point found")
        return nil, "no access point found"
    end
    M.connect_to(target)
    log(log_type.assign, "Auto connect: " .. target)
    M.verify("")
    return M.request_address()
end
function M.address()
    return con.addr
end
function M.status()
    return {
        status = status,
        access_point = con.ap,
        access_point_data = con.ap_data,
        device_address = con.addr,
        broadcast_address = con.broadcast,
    }
end

function M.send(dst, ...)
    if status ~= "connected" then
        return
    end
    log(log_type.message, "Send: " .. con.addr .. " -> " .. dst, ...)
    send(con.ap, "m!" .. con.addr .. "@" .. dst, ...)
end
function M.send_suffix(suffix, dst, ...)
    if status ~= "connected" then
        return
    end
    log(log_type.message, "Send: " .. con.addr .. address_spacing .. suffix .. " -> " .. dst, ...)
    send(con.ap, "m!" .. con.addr .. address_spacing .. suffix .. "@" .. dst, ...)
end
function M.send_reliable(dst, ...)
    if status ~= "connected" then
        return
    end
    local id = tostring(math.random(1000000000, 9999999999))
    send(con.ap, "m!" .. con.addr .. "@" .. dst .. "#" .. id, ...)
    wait_for_ack[id] = {
        dst = dst,
        msg = table.pack(...),
        timeout = uptime() + timeouts.ack,
        tries = max_tries
    }
    log(log_type.message, "Send reliable: " .. con.addr .. " -> " .. dst, ...)
    return id
end
function M.send_reliable_suffix(suffix, dst, ...)
    if status ~= "connected" then
        return
    end
    local id = tostring(math.random(1000000000, 9999999999))
    send(con.ap, "m!" .. con.addr .. address_spacing .. suffix .. "@" .. dst .. "#" .. id, ...)
    wait_for_ack[id] = {
        dst = dst,
        msg = table.pack(...),
        timeout = uptime() + timeouts.ack,
        tries = max_tries
    }
    log(log_type.message, "Send reliable: " .. con.addr .. address_spacing .. suffix .. " -> " .. dst, ...)
    return id
end
function M.broadcast(...)
    if status ~= "connected" then
        return
    end
    log(log_type.message, "Broadcast: " .. con.addr .. " -> " .. con.broadcast, ...)
    send(con.ap, "m!" .. con.addr .. "@" .. con.broadcast, ...)
end
function M.wait_for_ack(id)
    if wait_for_ack[id] == nil then
        return true
    end
    while wait_for_ack[id] ~= nil and wait_for_ack[id].tries > 0 do
        local end_time = wait_for_ack[id].timeout
        while uptime() < end_time do
            local signal, ack_id = pull_signal("inet_ack", end_time - uptime())
            if ack_id == id then
                break
            end
        end
    end
    if wait_for_ack[id] == nil then
        return true
    end
    return false, "timeout"
end

function M.suffix(dst)
    return dst:sub(#con.addr + 2)
end
function M.with_suffix(dst, suffix)
    return dst .. address_spacing .. suffix
end

return M