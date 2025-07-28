local ocelot = component.proxy(component.list("ocelot")())
local modem = component.proxy(component.list("modem")())
local microcontroller = component.proxy(component.list("microcontroller")())

for i=0, 5 do
    if i ~= 3 then
        microcontroller.setSideOpen(i, true)
    end
end

modem.open(10251)

ocelot.clearLog()
ocelot.log(_VERSION)

_G.print = ocelot.log

while true do
    local event = table.pack(computer.pullSignal())
    if event[1] == "ocelot_message" then
        if event[3]:sub(1, 1) == "=" then
            event[3] = "return " .. event[3]:sub(2)
        end
        local func, err = load(event[3], "=stdin", "t", _G)
        if func then
            local succ, err = xpcall(func, debug.traceback)
            ocelot.log(tostring(err))
        else
            ocelot.log(err)
        end
    else
        for i = 1, #event do
            event[i] = tostring(event[i])
        end
        ocelot.log(table.concat(event, " "))
    end
end