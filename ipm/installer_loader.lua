local internet = require("internet")
local component = require("component")

if not component.isAvailable("internet") then
    io.stderr:write("No internet card found\n")
    return
end

local use_mirror = false

io.write("Use mirror? [y/N]")
local answer = io.read()
if answer == "y" then
    use_mirror = true
end

local installer = use_mirror and "https://ghfast.top/raw.githubusercontent.com/aawwaaa/OpenPrograms/refs/heads/main/ipm/installer.lua"
    or "https://raw.githubusercontent.com/aawwaaa/OpenPrograms/refs/heads/main/ipm/installer.lua"

local con = internet.request(installer)
if not con then
    io.stderr:write("Failed to connect to: " .. installer .. "\n")
    return
end

local file = ""
for chunk in con do
    file = file .. chunk
end

local func = load(file, "=(installer)")

if not func then
    io.stderr:write("Failed to load installer\n")
    return
end

io.write("Running installer...\n")

func(use_mirror)
