local bit = nil

if _VERSION == "Lua 5.1" then
    bit = require("bit")
else
    bit = load([[return {
    band = function(a, b) return a & b end,
    rshift = function(a, b) return a >> b end,
    lshift = function(a, b) return a << b end,
    bor = function(a, b) return a | b end,
}]])()
end

local ClientProxy = {}
ClientProxy.__index = ClientProxy

function ClientProxy:new(client)
    local obj = {
        buffer = "",
        length = -1
    }
    setmetatable(obj, self)
    obj.client = client
    return obj
end

local function encode_i32(value)
    return string.char(
        bit.band(bit.rshift(value, 24), 0xFF),
        bit.band(bit.rshift(value, 16), 0xFF),
        bit.band(bit.rshift(value, 8), 0xFF),
        bit.band(value, 0xFF)
    )
end
local function decode_i32(data)
    return bit.bor(bit.bor(
        bit.lshift(string.byte(data, 1) or 0, 24),
        bit.lshift(string.byte(data, 2) or 0, 16)
    ), bit.bor(
        bit.lshift(string.byte(data, 3) or 0, 8),
        string.byte(data, 4) or 0
    ))
end

function ClientProxy:send(...)
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
            error("Unknown type: " .. ty)
        end
        local data = tostring(value)
        encoded = encoded .. type_data .. encode_i32(#data) .. data
    end
    encoded = encode_i32(#encoded + 1) .. encoded .. "\n"
    -- print("> " .. dump(encoded))
    self.client:send(encoded)
end

function ClientProxy:update()
    local data, err, partial = self.client:receive(65536*16)
    if err == "timeout" then
        data = partial
        self.client:receive(#data)
    elseif err then
        return err
    end
    data = data or ""
    -- if data ~= "" then
    --     print("< " .. dump(data))
    -- end
    self.buffer = self.buffer .. data

    if self.length == -1 and #self.buffer >= 4 then
        self.length = decode_i32(self.buffer:sub(1, 4))
        self.buffer = self.buffer:sub(5)
    end
end

function ClientProxy:has()
    return self.length >= 0 and self.length <= #self.buffer
end

function ClientProxy:receive()
    while not self:has() do self:update() end
    local data = self.buffer:sub(1, self.length - 1) -- remove \n
    self.buffer = self.buffer:sub(self.length + 1)
    self.length = -1
    self:update()
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
        if not decoder then error("Unknown type: " .. (string.byte(type_data) or 0)) end
        table.insert(output, decoder(value))
        data = data:sub(6 + length)
    until #data == 0
    return (table.unpack or unpack)(output)
end

function ClientProxy:close()
    self.client:close()
end

return ClientProxy
