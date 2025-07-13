local term = require("term")
local tty = require("tty")
local M = {}

function M.text(offset_y, text)
    local w, h = tty.getViewport()
    local x, y = tty.getCursor()

    while y >= h + offset_y do
        term.scroll(1)
        y = y - 1
    end

    term.setCursor(1, h + offset_y)
    term.clearLine()
    term.write(text)
    term.setCursor(x, y)
end

function M.progress(offset_y, text, per, right)
    right = right or ""
    local w, h = tty.getViewport()

    local left = w - #text - #right - 8

    local a = math.floor(left * per + 0.5)
    local bar = "[\x1b[42m" .. string.rep("#", a) .. "\x1b[0m" .. string.rep(" ", left - a) .. "]"

    M.text(offset_y, text .. " " .. bar .. " " .. tostring(math.floor(per*100+0.5)) .. "% " .. right)
end

return M