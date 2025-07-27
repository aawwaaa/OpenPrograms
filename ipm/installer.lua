local repo = "https://raw.githubusercontent.com/aawwaaa/OpenPrograms/refs/heads/main/ipm"
local mirror_repo = "https://ghfast.top/raw.githubusercontent.com/aawwaaa/OpenPrograms/refs/heads/main/ipm"
local mirror_config = [[{
    default_install_path = "/usr",
    redirects = {
        ["raw.githubusercontent.com"] = "ghfast.top/raw.githubusercontent.com",
        ["http://pastebin.com"] = "https://pastebin.com"
    }
}]]

local use_mirror = ...
use_mirror = use_mirror or false

local files = {
    "/bin/ipm.lua",
    "/etc/ipm/config.cfg",
    "/etc/ipm/sources.list.cfg",
    "/etc/ipm/sources.list.d/aawwaaa.cfg",
    "/lib/ipm/format.lua",
    "/lib/ipm/internet.lua",
    "/lib/ipm/execute.lua",
    "/lib/ipm/json.lua",
    "/lib/ipm/package.lua",
    "/lib/ipm/repo.lua",
    "/lib/ipm/source.lua",
    "/lib/ipm/util.lua",
    "/lib/ipm/tui.lua",
    "/lib/ipm/init.lua",
}

local internet = require("internet")
local component = require("component")
local fs = require("filesystem")

if not component.isAvailable("internet") then
    io.stderr:write("No internet card found\n")
    return
end

local function download(file, dst)
    io.write("Download: " .. file .. " -> " .. dst .. "\n")
    fs.makeDirectory(fs.path(dst))
    local f = io.open(dst, "w")
    if not f then
        io.stderr:write("Failed to open file: " .. dst .. "\n")
        return
    end
    local con = internet.request(repo .. file)
    if not con then
        io.stderr:write("Failed to connect to: " .. repo .. file .. "\n")
        return
    end
    for chunk in con do
        f:write(chunk)
    end
    f:close()
end

io.write("Improved Package Manager Installer\n")
io.write("Continue? [y/N]")
local answer = io.read()
if answer ~= "y" then
    io.write("Aborting...\n")
    return
end
if use_mirror then
    io.write("Using mirror...\n")
    repo = mirror_repo
end
io.write("Downloading files...\n")
for _, file in ipairs(files) do
    local dst = file:sub(1, 4) == "/etc" and file or "/usr" .. file
    download(file, dst)
end

local ipm = loadfile("/usr/bin/ipm.lua")

if use_mirror then
    local config = io.open("/etc/ipm/config.cfg", "w")
    if config then
        config:write(mirror_config)
        config:close()
    end
end

if ipm then
    io.write("Update cache...\n")
    ipm("update")
    io.write("Install ipm...\n")
    ipm("install", "ipm", "-y")
else
    io.stderr:write("Failed to load ipm.lua\n")
    return
end

if use_mirror then
    local config = io.open("/etc/ipm/config.cfg", "w")
    if config then
        config:write(mirror_config)
        config:close()
    end
end

io.write("Update cache...\n")
local ipm = loadfile("/usr/bin/ipm.lua")
if ipm then
    ipm("update")
else
    io.stderr:write("Failed to load ipm.lua\n")
    return
end

io.write("Done!\n")
io.write("Reboot? [Y/n] ")
answer = io.read()
if answer ~= "n" then
    require("computer").shutdown(true)
end