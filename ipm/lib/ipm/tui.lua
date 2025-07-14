local term = require("term")
local tty = require("tty")
local M = {}

function M.paged(text)
    local w, h = tty.getViewport()
    term.setCursor(1, 1)
    term.clear()
    for i=1, #text, 20 do
        term.write(text:sub(i, i+19))
        local x, y = tty.getCursor()
        if y >= h - 2 then
            term.scroll(1)
            term.setCursor(1, h)
            term.clearLine()
            term.write("Press Enter to continue...")
            local _ = io.read()
            term.setCursor(1, h)
            term.clearLine()
            term.scroll(h - 7)
            term.setCursor(x, y - (h - 7) - 2)
        end
    end
end

function M.text(offset_y, text)
    local w, h = tty.getViewport()
    local x, y = tty.getCursor()

    while y >= h + offset_y do
        term.setCursor(1, h + offset_y)
        term.clearLine()
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

    per = math.min(1, math.max(0, per))
    local a = math.floor(left * per + 0.5)
    local bar = "[\x1b[42m" .. string.rep("#", a) .. "\x1b[0m" .. string.rep(" ", left - a) .. "]"

    M.text(offset_y, text .. " " .. bar .. " " .. tostring(math.floor(per*100+0.5)) .. "% " .. right)
end

return M