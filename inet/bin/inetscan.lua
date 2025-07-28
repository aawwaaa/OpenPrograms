local component = require("component")
local computer = require("computer")
local event = require("event")

local modem = component.modem
modem.open(10251)
if modem.isWireless() then
    modem.setStrength(1000)
end

modem.broadcast(10251, ".")
print("Scanning for micro controllers...")

local known = {}
local stat = {}
local keys = {}

local timer = computer.uptime() + 1
while computer.uptime() < timer do
    local e, _, s, p, _, m, k, v = event.pull(timer - computer.uptime())
    if e == "modem_message" and p == 10251 and m == ":" then
        if known[s] == nil then
            table.insert(keys, s)
        end
        known[s] = known[s] or {}
        if k == "" then
            stat[s] = v
        end
    end
end

if #keys == 0 then
    print("No micro controllers found")
    return
end

print("Found " .. #keys .. " micro controllers")

table.sort(keys)

print("Micro controllers:")
for i, k in ipairs(keys) do
    print("  [" .. tostring(i) .. "] " .. k:sub(1, 8) .. "\n  " .. tostring(stat[k]))
end