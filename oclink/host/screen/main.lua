---@diagnostic disable: deprecated
local socket = require("socket")
local bit = require("bit")
local ClientProxy = require("clientproxy")
local bufferops = require("bufferops")
local utf8 = require("utf8")

local client;
local buffer = {chars = "", fgs = "", bgs = "", w = 1, h = 1}
local vw, vh = 1, 1
local screen_on = true
local precise_mode = false

local font = {}

function love.load(arg)
    local port, address = 10252, arg[1]
    love.window.setTitle("OCLink Screen " .. port .. " " .. address)
    love.graphics.setBackgroundColor(0.1, 0.1, 0.1)

    local rawclient = assert(socket.connect("localhost", port))
    rawclient:settimeout(0)
    client = ClientProxy:new(rawclient)
    client:send("screen")
    client:send(address)

    local font_file = io.open("screen/font.hex", "r")
    if font_file then
        repeat
            local line = font_file:read("*l")
            if not line then break end
            local code, data = line:match("^([0-9A-F]+):([0-9A-F]+)$")
            code = tonumber(code, 16)
            local out = {[0]=#data*4/16}
            for i=1, #data, out[0]/4 do
                local char = data:sub(i, i+(out[0]/4)-1)
                table.insert(out, tonumber(char, 16))
            end
            font[code] = out
        until not line
        font_file:close()
    else
        print("Failed to open font.hex")
    end

    love.keyboard.setKeyRepeat(true)
end

local function render(x, y, code, fg, bg)
    love.graphics.setColor(bg)
    local char = font[code]
    if not char then return 1 end
    love.graphics.rectangle("fill", x, y, 8*char[0], 16)
    love.graphics.setColor(fg)
    for oy=1, #char do
        local c = char[oy]
        for ox=1, char[0] do
            if bit.band(c, bit.lshift(1, char[0]-ox)) ~= 0 then
                love.graphics.rectangle("fill", x+ox-1, y+oy-1, 1, 1)
            end
        end
    end
    return char[0]/8
end

local function dump(str)
    local output = ""
    for i = 1, #str do
        local char = str:sub(i, i)
        output = output .. string.format("%02X", string.byte(char) or 0) .. " "
    end
    return output
end

local handler = {}
function handler.resolution(w, h)
    buffer.w, buffer.h = w, h
    vw, vh = w, h
    love.window.setMode(w*8,h*16)
end
function handler.view(w, h)
    vw, vh = w, h
    love.window.setMode(w*8,h*16)
end
function handler.buffer(...)
    buffer.chars, buffer.fgs, buffer.bgs = ...
end
function handler.op(method, ...)
    if not bufferops[method] then
        return
    end
    local time = love.timer.getTime()
    bufferops[method](buffer, ...)
    print(method, ...)
    -- print(method, love.timer.getTime() - time)
end
function handler.reset()
end
function handler.close()
    love.event.quit()
end
function handler.state(on, precise)
    screen_on = on
    precise_mode = precise
end

local mouse_pressed = false
local mouse_x, mouse_y = 0, 0
local record_timer = 0

function love.update(dt)
    local err = client:update()
    if err == "closed" then
        love.event.quit()
    end
    while client:has() do
        local packed = {client:receive()}
        local h = handler[packed[1]]
        if h then
            h(select(2, unpack(packed)))
        end
    end
    local x, y = love.mouse.getPosition()
    x = math.floor(x / 8) + 1
    y = math.floor(y / 16) + 1
    record_timer = record_timer - dt
    if mouse_pressed and (x ~= mouse_x or y ~= mouse_y) and record_timer < 0 then
        client:send("drag", x, y, love.mouse.isDown(1) and 0 or 1)
        mouse_x, mouse_y = x, y
        record_timer = record_timer + 0.1
    end
end

function love.draw()
    love.graphics.clear(0,0,0)
    local time = love.timer.getTime()
    local x, y = 1, 1
    while y <= vh do
        while x <= vw do
            local offset = (y-1)*buffer.w*4 + (x-1)*4 + 1
            local char = buffer.chars:sub(offset, offset+3)
            local fgc = buffer.fgs:sub(offset, offset+3)
            local bgc = buffer.bgs:sub(offset, offset+3)
            local code = bit.bor(
                bit.lshift(string.byte(char, 1) or 0, 24),
                bit.lshift(string.byte(char, 2) or 0, 16),
                bit.lshift(string.byte(char, 3) or 0, 8),
                string.byte(char, 4) or 0
            )
            local fg = { (string.byte(fgc, 1) or 255) / 255, (string.byte(fgc, 2) or 255) / 255, (string.byte(fgc, 3) or 255) / 255 }
            local bg = { (string.byte(bgc, 1) or 0) / 255, (string.byte(bgc, 2) or 0) / 255, (string.byte(bgc, 3) or 0) / 255 }
            local w = render((x-1)*8, (y-1)*16, code, fg, bg)
            x = x + w
        end
        x = 1
        y = y + 1
    end
    -- print(love.timer.getTime() - time)

    if not screen_on then
        love.graphics.setColor(0.3, 0.3, 0.3)
        love.graphics.rectangle("fill", 5, 5, 200, 30)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("Screen is off", 10, 10)
        return
    end
    -- local str = "Hello World! 你好世界"
    -- local x = 0
    -- for i, code in require("utf8").codes(str) do
    --     render(x, 0, code, {1,1,1}, {0,0,0})
    --     x = x + (bit.band(code, 0xFFFFFF00) ~= 0 and 16 or 8)
    -- end
end

function love.mousepressed(x, y, button, istouch)
    mouse_pressed = true
    x = math.floor(x / 8) + 1
    y = math.floor(y / 16) + 1
    mouse_x, mouse_y = x, y
    client:send("touch", x, y, button - 1)
    record_timer = 0.1
end
function love.mousereleased(x, y, button, istouch)
    mouse_pressed = false
    x = math.floor(x / 8) + 1
    y = math.floor(y / 16) + 1
    client:send("drop", x, y, button - 1)
end

local keycode = require("keycode")

local last_pressed = nil
local chars = {
    ["return"] = 13,
    ["backspace"] = 8
}
function love.keypressed(key)
    if key == "insert" then
        client:send("clipboard", love.system.getClipboardText())
        return
    end
    last_pressed = key
    if chars[last_pressed] == nil then
        chars[last_pressed] = 0
    end
    if (#key == 1 or key == "space") and not (
            love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") or
            love.keyboard.isDown("lalt") or love.keyboard.isDown("ralt")
        ) then return end
    client:send("key_down", chars[key], keycode[key])
end
function love.textinput(text)
    if not last_pressed then return end
    local char = utf8.codepoint(text)
    chars[last_pressed] = char
    client:send("key_down", char, keycode[last_pressed])
end
function love.keyreleased(key)
    if key == "insert" then return end
    client:send("key_up", chars[key] or 0, keycode[key])
end
