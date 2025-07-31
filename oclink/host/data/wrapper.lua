local socket, buffer, encode_i32, decode_i32 = ...
-- local ocelot = component.proxy(component.list("ocelot")())

local computer, unicode
    = computer, unicode

-- local ocelot = component.proxy(component.list("ocelot")())

--[[
组件列表
> component|address|type|slot|method1|method2|...\n
> ...
> component|nil\n

组件invoke
> invoke|address|method|arg1|arg2|...\n
arg: tData 如遇"|"转义为"\:", "\"转义为"\\", "\n"转义为"\0"
< return|arg|...\n

组件镜像
> invoke_mirror|address|...\n

信号
> signal|signal|...\n
< signal|signal|...\n
]]

local send_buffer = ""
local send_buffer_count = 0
local last_write = 0
local function write()
    socket.write(send_buffer)
    send_buffer = ""
    send_buffer_count = 0
    last_write = computer.uptime()
end
local function write_check()
    if send_buffer_count == 0 then return end
    if computer.uptime() - last_write > 0.3 or send_buffer_count > 40 then
        write()
    end
end

local function send(...)
    local t = {...}
    local n = select('#', ...)
    local encoded = ""
    for i = 1, n do
        local value = t[i]
        local ty = type(value)
        local type_data = ({
            ["nil"] = string.char(0x00),
            ["string"] = string.char(0x01),
            ["number"] = string.char(0x02),
            ["boolean"] = string.char(0x03),
        })[ty or "nil"]
        if not type_data then
            goto continue
        end
        local data = tostring(value)
        encoded = encoded .. type_data .. encode_i32(#data) .. data
        ::continue::
    end
    encoded = encode_i32(#encoded + 1) .. encoded .. "\n"
    send_buffer = send_buffer .. encoded
    send_buffer_count = send_buffer_count + 1
    write_check()
end
local length = -1
local function update()
    local data = socket.read() or ""
    buffer = buffer .. data
    if length == -1 and #buffer >= 4 then
        length = decode_i32(buffer:sub(1, 4))
        buffer = buffer:sub(5)
    end
end
local function has()
    return length >= 0 and length <= #buffer
end
local function receive(once)
    if once then
        update()
        if not has() then return {} end
    else
        while not has() do update() end
    end
    local data = buffer:sub(1, length - 1) -- remove \n
    buffer = buffer:sub(length + 1)
    length = -1
    local output = {}
    repeat
        local type_data = data:sub(1, 1)
        local length = decode_i32(data:sub(2, 5))
        local value = data:sub(6, 6 + length - 1)
        local decoder = ({
            [string.char(0x00)] = function(data) return nil end,
            [string.char(0x01)] = function(data) return data end,
            [string.char(0x02)] = function(data) return tonumber(data) end,
            [string.char(0x03)] = function(data) return data == "true" or data == "1" end,
        })[type_data]
        if not decoder then error("Unknown type: " .. type_data) end
        table.insert(output, decoder(value))
        data = data:sub(6 + length)
    until #data == 0
    return output
end

local signal_queue = {}

local function receive_filted(once)
    local packed = receive(once)
    if packed[1] == "signal" then
        table.insert(signal_queue, {table.unpack(packed, 2)})
        return receive_filted(once)
    end
    return packed
end
local function monitor(t, func)
    if t._processed then
        return t
    end
    return setmetatable({
        _processed = true
    }, {
        __call = function(self, ...)
            func(...)
            return t(...)
        end,
        __tostring = function(self)
            return tostring(t)
        end,
    })
end
local function report(address, method)
    if string.sub(method, 1, 3) == "get" then
        return function() end
    end
    return function(...)
        send("im", address, method, ...)
    end
end
local function invoke(address, method)
    return function(...)
        send("i", address, method, ...)
        write()
        return select(2, table.unpack(receive_filted()))
    end
end

local vcomponents_list = {}
local vcomponents_methods = {}
local vcomponents = {}
while true do
    local t = receive_filted()
    if t[1] == "component" then
        if t[2] == nil then break end
        local address, type, slot = t[2], t[3], t[4]
        local comp = {
            address = address,
            type = type,
            slot = slot,
        }
        vcomponents_list[address] = type
        vcomponents_methods[address] = {}
        for i = 5, #t do
            comp[t[i]] = invoke(address:sub(0, 4), t[i])
            table.insert(vcomponents_methods[address], t[i])
        end
        vcomponents[address] = comp
    end
end
for address, type in component.list() do
    local datas = {"component", address, type}
    if type == "gpu" then
        local proxy = component.proxy(address)
        local w, h = proxy.maxResolution()
        local d = proxy.maxDepth()
        datas = {"component", address, type, w, h, d}
    elseif type == "screen" then
        local proxy = component.proxy(address)
        local keyboards = proxy.getKeyboards()
        for i = 1, #keyboards do
            datas[#datas+1] = keyboards[i]
        end
    end
    send(table.unpack(datas))
end
send("component", nil)
write()

local ocomponent = component

_G.component = {}

function component.slot(address)
    if vcomponents[address] then
        return vcomponents[address].slot
    end
    return ocomponent.slot(address)
end
function component.methods(address)
    if vcomponents_methods[address] then
        return vcomponents_methods[address]
    end
    return ocomponent.methods(address)
end
function component.invoke(address, method, ...)
    if vcomponents[address] then
        return vcomponents[address][method](...)
    end
    local ctype = ocomponent.type(address)
    if ctype == "gpu" or ctype == "screen" then
        if string.sub(method, 1, 3) ~= "get" then
            send("im", address:sub(0, 4), method, ...)
        end
    end
    local packed = table.pack(ocomponent.invoke(address, method, ...))
    -- local packed_tostring = {}
    -- for i = 1, #packed do
    --     packed_tostring[i] = tostring(packed[i])
    -- end
    -- ocelot.log("R | " .. table.concat(packed_tostring, " "))
    return table.unpack(packed)
end
function component.type(address)
    if vcomponents[address] then
        return vcomponents[address].type
    end
    return ocomponent.type(address)
end
function component.list(filter, strict)
    local output = {}
    for address, comp in pairs(vcomponents) do
        if filter == nil or
            (not strict and string.find(comp.type, filter)) or
            (strict and comp.type == filter) then
            output[address] = comp.type
        end
    end
    for address, type in pairs(ocomponent.list(filter, strict)) do
        if not output[address] then
            output[address] = type
        end
    end
    setmetatable(output, {
        __call = function (self, _, key)
            return next(self, key)
        end,
    })
    return output
end
function component.proxy(address)
    if vcomponents[address] then
        return vcomponents[address]
    end
    local proxy = ocomponent.proxy(address)
    local ctype = ocomponent.type(address)
    if ctype == "gpu" or ctype == "screen" then
        for key, value in pairs(proxy) do
            if type(value) == "function" or type(value) == "table" then
                proxy[key] = monitor(proxy[key], report(address:sub(0, 4), key))
            end
        end
    end
    return proxy
end
function component.doc(address, method)
    if vcomponents[address] then
        return ""
    end
    return ocomponent.doc(address, method)
end
function component.fields(address)
    return ocomponent.fields(address)
end

local opullSignal = computer.pullSignal
function computer.pullSignal(timeout)
    local t = computer.uptime() + timeout
    while timeout == nil or computer.uptime() < t do
        if #signal_queue > 0 then
            return table.unpack(table.remove(signal_queue, 1))
        end
        local packed = table.pack(opullSignal(timeout ~= nil and t - computer.uptime() or nil))
        write_check()
        if packed[1] == "internet_ready" or packed[2] == socket.id() then
            receive_filted(true)
            goto continue
        end
        if #packed > 0 then
            return table.unpack(packed)
        end
        ::continue::
    end
end
