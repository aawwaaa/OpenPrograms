local term = require("term")
local event = require("event")
local keyboard = require("keyboard")
local computer = require("computer")
local component = require("component")
local shell = require("shell")
local serialization = require("serialization")
local io = require("io")

local function edit_line(x, y, v1, k, tabs)
    if type(v1) == "boolean" then
        return not v1
    end
    term.setCursor(x, y)
    term.clearLine()
    term.write(k .. string.rep(" ", tabs - #k) .. " = ")
    term.setCursor(x, y)
    computer.pushSignal("key_down", term.keyboard(), 9, 15, "")
    computer.pushSignal("key_up", term.keyboard(), 9, 15, "")
    local v = term.read({
        dobreak = false,
        hint = function(line, pos)
            return pos == 1 and {tostring(v1)} or {}
        end
    })
    if v ~= nil and v:sub(#v) == "\n" then
        v = v:sub(1, #v - 1)
    end
    v = v ~= nil and v or v1
    if type(v1) == "number" then
        v = tonumber(v) or 0
    end
    return v
end

local function edit(configs, save, max)
    local keys = {}
    local tabs = 0
    for k, v in pairs(configs) do
        table.insert(keys, k)
        tabs = math.max(tabs, #k)
    end
    table.sort(keys)

    local selected = 1
    local cursors = {}
    local serialized = ""

    local function draw()
        serialized = serialization.serialize(configs)
        term.clear()
        term.setCursor(1, 1)
        term.write("--- Config ---\n")
        for i, k in ipairs(keys) do
            if selected == i then
                term.write("\x1b[47m\x1b[30m")
            end
            term.clearLine()
            term.write(k .. string.rep(" ", tabs - #k) .. " = ")
            cursors[i] = table.pack(term.getCursor())
            term.write(tostring(configs[k]))
            term.write("\x1b[0m\n")
        end
        if max then
            term.write("Size: " .. tostring(#serialized) .. "/" .. tostring(max) .. " bytes\n")
            if #serialized > max then
                term.write("Size limit exceeded\n")
            end
        end
        term.write("[up/down] toggle [space/enter] edit [n] new [d] delete\n[s] save & quit [q] discard & quit\n")
    end

    while true do
        draw()
        local e, _, _, code = event.pull("key_down")
        if e == "key_down" then
            if code == keyboard.keys.up then
                selected = selected - 1
                if selected < 1 then
                    selected = #keys
                end
            elseif code == keyboard.keys.down then
                selected = selected + 1
                if selected > #keys then
                    selected = 1
                end
            elseif code == keyboard.keys.n then
                term.write("New key: ")
                local k = term.read():sub(1, -2)
                if k then
                    term.write("Type: [s]tring [n]umber [b]oolean [q]uit\n")
                    local _, _, _, code = event.pull("key_down")
                    if code == keyboard.keys.s then
                        configs[k] = ""
                    elseif code == keyboard.keys.n then
                        configs[k] = 0
                    elseif code == keyboard.keys.b then
                        configs[k] = false
                    else
                        goto continue
                    end
                    table.insert(keys, k)
                    table.sort(keys)
                    for i, k1 in ipairs(keys) do
                        if k1 == k then
                            selected = i
                            break
                        end
                    end
                end
            elseif code == keyboard.keys.space or code == keyboard.keys.enter then
                local k = keys[selected]
                local x, y = table.unpack(cursors[selected])
                configs[k] = edit_line(x, y, configs[k], k, tabs)
            elseif code == keyboard.keys.s then
                save(serialized)
                break
            elseif code == keyboard.keys.q then
                break
            elseif code == keyboard.keys.d then
                local k = keys[selected]
                configs[k] = nil
                table.remove(keys, selected)
                selected = selected - 1
                if selected < 1 then
                    selected = 1
                end
            end
        end
        ::continue::
    end
end

local args, options = shell.parse(...)

if options.h or options.help then
    print("Usage: inetcfg [--help] [-r]")
    print("Options:")
    print("  --help, -h    Show this help message")
    print("  -r            Connect to micro controller")
end

if options.r then
    if not require("component").isAvailable("modem") then
        io.stderr:write("Modem not found")
        return
    end
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
            if k ~= "" then
                known[s][k] = v
            else
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

    print("Select a micro controller: ")
    local i = tonumber(term.read())
    if not i or i < 1 or i > #keys then
        print("Invalid input")
        return
    end

    local k = keys[i]

    edit(known[k], function(serialized)
        modem.send(k, 10251, "=", serialized)
    end, 256)

    return
end

local file = io.open("/etc/inetd.cfg", "r")
if not file then
    print("Error: Failed to read file")
    return
end
local data = file:read("*a")
file:close()

local configs = serialization.unserialize(data)

edit(configs, function(serialized)
    file = io.open("/etc/inetd.cfg", "w")
    if not file then
        print("Error: Failed to write file")
        return
    end
    file:write(serialized)
    file:close()
end)