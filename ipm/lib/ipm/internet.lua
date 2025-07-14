local component = require("component")

local M = {}

local ipm = ...

local config = ipm.util.load_file("/etc/ipm/config.cfg")

function M.get_internet()
    if not component.isAvailable("internet") then
        return nil
    end

    M.internet = require("internet")
    return M.internet
end

local function redirect(url)
    for redirect, target in pairs(config.redirects) do
        if url:match(redirect) then
            url = url:gsub(redirect, target)
            break
        end
    end
    return url
end

function M.fetch(url, headers)
    url = redirect(url)
    ipm.tui.text(-4, "Connecting to " .. url)
    ipm.tui.text(-3, "")
    local result, handle = pcall(M.internet.request, url, nil, headers)
    if not result then
        io.stderr:write("Failed to connect to " .. url .. "\n")
        return nil
    end
    local con = getmetatable(handle).__index
    local content_length = nil
    local content = ""
    local first = true
    local ok, err = pcall(function()
        for chunk in handle do
            local code, message, headers = con.response()
            if first and headers then
                first = false
                content_length = headers and headers["Content-Length"]
                    and tonumber(headers["Content-Length"][1]) or nil
                if code ~= 200 then
                    io.stderr:write("Failed to fetch " .. url .. " (" .. code .. " " .. message .. ")\n")
                    return nil
                end
                ipm.tui.text(-4, "Fetching " .. url)
                ipm.tui.progress(-3, "", 0)
            end
            content = content .. chunk
            ipm.tui.progress(-3, "", #content / (content_length or #content*1.5))
        end
    end)
    ipm.tui.text(-4, "")
    ipm.tui.text(-3, "")
    if not ok then
        io.stderr:write("Failed to fetch " .. url .. " (" .. err .. ")\n")
        return nil
    end
    return content
end

function M.download(url, path, headers)
    url = redirect(url)
    ipm.tui.text(-5, "Connecting to " .. url)
    ipm.tui.text(-4, " -> " .. path)
    local file = io.open(path, "w")
    if not file then
        io.stderr:write("Failed to open " .. path .. "\n")
        return nil
    end
    local result, handle = pcall(M.internet.request, url, nil, headers)
    if not result then
        io.stderr:write("Failed to connect to " .. url .. "\n")
        return nil
    end
    local con = getmetatable(handle).__index
    local content_length = nil
    local length = 0

    local first = true
    local ok, err = pcall(function()
        for chunk in handle do
            local code, message, headers = con.response()
            if first and headers then
                content_length = headers and headers["Content-Length"]
                    and tonumber(headers["Content-Length"][1]) or nil
                if code ~= 200 then
                    io.stderr:write("Failed to fetch " .. url .. " (" .. code .. " " .. message .. ")\n")
                    return nil
                end
                ipm.tui.text(-5, "Downloading " .. url)
                ipm.tui.text(-4, " -> " .. path)
                ipm.tui.progress(-3, "", 0)
                first = false
            end
            file:write(chunk)
            length = length + #chunk
            ipm.tui.progress(-3, "", length / (content_length or length*1.5))
        end
    end)
    if not ok then
        io.stderr:write("Failed to download " .. url .. " (" .. err .. ")\n")
        os.remove(path)
        return nil
    end
    ipm.tui.text(-5, "")
    ipm.tui.text(-4, "")
    ipm.tui.text(-3, "")
    file:close()
    return true
end

return M