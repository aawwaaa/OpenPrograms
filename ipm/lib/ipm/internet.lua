local component = require("component")

local M = {}

local ipm = ...

function M.get_internet()
    if not component.isAvailable("internet") then
        return nil
    end

    M.internet = require("internet")
    return M.internet
end

function M.fetch(url)
    ipm.tui.text(-3, "Connecting to " .. url)
    ipm.tui.text(-2, "")
    local result, handle = pcall(M.internet.request, url)
    if not result then
        io.stderr:write("Failed to connect to " .. url .. "\n")
        return nil
    end
    local code, message, headers = getmetatable(handle).__index.response()
    local content_length = headers and headers["Content-Length"] or nil
    ipm.tui.text(-3, "Fetching " .. url)
    ipm.tui.progress(-2, "", 0)
    local content = ""
    local ok, err = pcall(function()
        for chunk in handle do
            content = content .. chunk
            ipm.tui.progress(-2, "", #content / (content_length or #content*1.5))
        end
    end)
    ipm.tui.text(-3, "")
    ipm.tui.text(-2, "")
    if not ok then
        return nil
    end
    return content
end

function M.download(url, path)
    ipm.tui.text(-4, "Connecting to " .. url)
    ipm.tui.text(-3, " -> " .. path)
    local file = io.open(path, "w")
    if not file then
        io.stderr:write("Failed to open " .. path .. "\n")
        return nil
    end
    local result, handle = pcall(M.internet.request, url)
    if not result then
        io.stderr:write("Failed to connect to " .. url .. "\n")
        return nil
    end
    local code, message, headers = getmetatable(handle).__index.response()
    local content_length = headers["Content-Length"] or nil
    local length = 0
    ipm.tui.text(-4, "Downloading " .. url)
    ipm.tui.text(-3, " -> " .. path)
    ipm.tui.progress(-2, "", 0)

    for chunk in handle do
        file:write(chunk)
        length = length + #chunk
        ipm.tui.progress(-3, "", length / (content_length or 1))
    end
    ipm.tui.text(-4, "")
    ipm.tui.text(-3, "")
    ipm.tui.text(-2, "")
    file:close()
    return true
end

return M