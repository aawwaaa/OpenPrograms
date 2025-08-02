local component = require("component")
local event = require("event")

for k, v in pairs(package.loaded) do
    if k:find("glasses") then
        package.loaded[k] = nil
    end
end

local glasses = require("glasses")

component.glasses.removeAll()
component.glasses.setRenderResolution("", 640, 360)
component.glasses.setRenderPosition("relative")

local root = glasses.root(component.glasses)

root.proxy:text():text("Hello World!")
    :translation(20, 20, 20)
    :color(0, 1, 1, 1)
    :color(0, 1, 1, 1)
    :fontSize(20):size(50, 10)
    :background(0, 0, 0, 0.3)

root:instanciate()

print("Loaded")

while true do
    glasses.update()
    local packed = table.pack(event.pull(0.1))
    if packed[1] == "interrupt" then
        break
    end
    if #packed > 0 then
        glasses.signal(table.unpack(packed))
    end
    print("update!")
end