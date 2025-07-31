local utf8 = require("utf8")
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

local M = {}

local function modify(data, offset, value)
    local before, after = "", ""
    if offset > 1 then
        before = data:sub(1, offset - 1)
    end
    if offset + #value < #data then
        after = data:sub(offset + #value)
    end
    return before .. value .. after
end

function M.set(buffer, x, y, value, vertical, fg, bg)
    local i = 0
    local j = 0
    for _, code in utf8.codes(value) do
        local current_x = vertical and x or x + i
        local current_y = vertical and y + j or y
        if current_x > buffer.w + 1 then
            break
        end
        if current_y > buffer.h + 1 then
            break
        end
        local offset = (current_y - 1) * buffer.w * 4 + (current_x - 1) * 4 + 1
        buffer.chars = modify(buffer.chars, offset, string.char(
            bit.rshift(bit.band(code, 0xFF000000), 24),
            bit.rshift(bit.band(code, 0x00FF0000), 16),
            bit.rshift(bit.band(code, 0x0000FF00), 8),
            bit.band(code, 0x000000FF)
        ))
        buffer.fgs = modify(buffer.fgs, offset, string.char(
            bit.rshift(bit.band(fg, 0xFF0000), 16),
            bit.rshift(bit.band(fg, 0x00FF00), 8),
            bit.band(fg, 0x0000FF),
            0
        ))
        buffer.bgs = modify(buffer.bgs, offset, string.char(
            bit.rshift(bit.band(bg, 0xFF0000), 16),
            bit.rshift(bit.band(bg, 0x00FF00), 8),
            bit.band(bg, 0x0000FF),
            0
        ))
        i = i + utf8.len(utf8.char(code))
        j = j + 1
    end
end

function M.copy(buffer, x, y, w, h, tx, ty)
    if x + w > buffer.w then
        w = buffer.w - x + 1
    end
    if y + h > buffer.h then
        h = buffer.h - y + 1
    end
    tx = x + tx
    ty = y + ty
    if tx + w > buffer.w then
        w = buffer.w - tx + 1
    end
    if ty + h > buffer.h then
        h = buffer.h - ty + 1
    end
    local slice_chars, slice_fgs, slice_bgs = M.slice(buffer, x, y, w, h)
    M.apply(buffer, tx, ty, w, h, slice_chars, slice_fgs, slice_bgs)
end

function M.fill(buffer, x, y, w, h, value, fg, bg)
    value = utf8.codepoint(value) or 0
    if x + w > buffer.w then
        w = buffer.w - x + 1
    end
    if y + h > buffer.h then
        h = buffer.h - y + 1
    end
    w = w + 1
    for current_y = y, y + h do
        local offset = (current_y - 1) * buffer.w * 4 + (x - 1) * 4 + 1
        buffer.chars = modify(buffer.chars, offset, string.char(
            bit.rshift(bit.band(value, 0xFF000000), 24),
            bit.rshift(bit.band(value, 0x00FF0000), 16),
            bit.rshift(bit.band(value, 0x0000FF00), 8),
            bit.band(value, 0x000000FF)
        ):rep(w))
        buffer.fgs = modify(buffer.fgs, offset, string.char(
            bit.rshift(bit.band(fg, 0xFF0000), 16),
            bit.rshift(bit.band(fg, 0x00FF00), 8),
            bit.band(fg, 0x0000FF),
            0
        ):rep(w))
        buffer.bgs = modify(buffer.bgs, offset, string.char(
            bit.rshift(bit.band(bg, 0xFF0000), 16),
            bit.rshift(bit.band(bg, 0x00FF00), 8),
            bit.band(bg, 0x0000FF),
            0
        ):rep(w))
    end
end

function M.slice(buffer, x, y, w, h)
    local slice_chars = ""
    local slice_fgs = ""
    local slice_bgs = ""
    for current_y = y, y + h - 1 do
        local offset = (current_y - 1) * buffer.w * 4 + (x - 1) * 4 + 1
        slice_chars = slice_chars .. buffer.chars:sub(offset, offset + w * 4 - 1)
        slice_fgs = slice_fgs .. buffer.fgs:sub(offset, offset + w * 4 - 1)
        slice_bgs = slice_bgs .. buffer.bgs:sub(offset, offset + w * 4 - 1)
    end
    return slice_chars, slice_fgs, slice_bgs
end
function M.apply(buffer, x, y, w, h, slice_chars, slice_fgs, slice_bgs)
    for current_y = y, y + h - 1 do
        local offset = (current_y - 1) * buffer.w * 4 + (x - 1) * 4 + 1
        local slice_offset = (current_y - y) * w * 4 + 1
        buffer.chars = modify(buffer.chars, offset,
            slice_chars:sub(slice_offset, slice_offset + w * 4 - 1))
        buffer.fgs = modify(buffer.fgs, offset,
            slice_fgs:sub(slice_offset, slice_offset + w * 4 - 1))
        buffer.bgs = modify(buffer.bgs, offset,
            slice_bgs:sub(slice_offset, slice_offset + w * 4 - 1))
    end
end

return M