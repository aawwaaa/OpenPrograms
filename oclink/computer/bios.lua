do
    local internet = component.list("internet")()
    if not internet then
        computer.beep(500, 0.3)
        computer.beep(800, 0.1)
        goto continue
    end
    internet = component.proxy(internet)
    if not internet.isTcpEnabled() then
        computer.beep(500, 0.5)
        goto continue
    end
    local socket = internet.connect("localhost", 10252)
    if socket.finishConnect() then
        computer.beep(800, 0.3)
        computer.beep(500, 0.1)
        goto continue
    end
    local function encode_i32(value)
        return string.char(
            (value >> 24) & 0xFF,
            (value >> 16) & 0xFF,
            (value >> 8) & 0xFF,
            value & 0xFF
        )
    end
    local function decode_i32(data)
        return (
            (string.byte(data, 1) << 24) |
            (string.byte(data, 2) << 16) |
            (string.byte(data, 3) << 8) |
            string.byte(data, 4)
        )
    end
    local data = string.char(0x01) .. encode_i32(8) .. "computer"
    socket.write(encode_i32(#data + 1) .. data .. "\n")
    local buffer = ""
    local length = -1
    repeat
        local data = socket.read()
        buffer = buffer .. (data or "")
        if length == -1 and #buffer >= 4 then
            length = decode_i32(buffer:sub(1, 4))
            buffer = buffer:sub(5)
        end
    until length ~= -1 and #buffer >= length
    local code = buffer:sub(6, length - 2) -- \x01[length:4][data]\n
    local wrapper, err = load(code, "wrapper.lua")
    if not wrapper then
        error(err)
    end
    wrapper(socket, buffer:sub(length + 1), encode_i32, decode_i32)
    ::continue::
end

local init
do
  local component_invoke = component.invoke
  local function boot_invoke(address, method, ...)
    local result = table.pack(pcall(component_invoke, address, method, ...))
    if not result[1] then
      return nil, result[2]
    else
      return table.unpack(result, 2, result.n)
    end
  end

  -- backwards compatibility, may remove later
  local eeprom = component.list("eeprom")()
  computer.getBootAddress = function()
    return boot_invoke(eeprom, "getData")
  end
  computer.setBootAddress = function(address)
    return boot_invoke(eeprom, "setData", address)
  end

  do
    local screen = component.list("screen")()
    local gpu = component.list("gpu")()
    if gpu and screen then
      boot_invoke(gpu, "bind", screen)
    end
  end
  local function tryLoadFrom(address)
    local handle, reason = boot_invoke(address, "open", "/init.lua")
    if not handle then
      return nil, reason
    end
    local buffer = ""
    repeat
      local data, reason = boot_invoke(address, "read", handle, math.maxinteger or math.huge)
      if not data and reason then
        return nil, reason
      end
      buffer = buffer .. (data or "")
    until not data
    boot_invoke(address, "close", handle)
    return load(buffer, "=init")
  end
  local reason
  if computer.getBootAddress() then
    init, reason = tryLoadFrom(computer.getBootAddress())
  end
  if not init then
    computer.setBootAddress()
    for address in component.list("filesystem") do
      init, reason = tryLoadFrom(address)
      if init then
        computer.setBootAddress(address)
        break
      end
    end
  end
  if not init then
    error("no bootable medium found" .. (reason and (": " .. tostring(reason)) or ""), 0)
  end
  computer.beep(1000, 0.2)
end
local result, reason = xpcall(init, debug.traceback)
if not result then
    error(reason)
end
return result
