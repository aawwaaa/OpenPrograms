local backend = require("backend/core")
local component = require("component")
local main = require("frontend/main")

local gpu = component.gpu

backend.load()
local function error_handler(process, error)
    gpu.setActiveBuffer(0)
    gpu.setBackground(0x000000)
    gpu.setForeground(0xff0000)
    local w, h = gpu.getResolution()
    gpu.fill(1, 1, w, h, " ")
    gpu.set(1, 1, "---Error---")
    gpu.setForeground(0xffffff)
    local str = string.format("An error occurred in process %d:\n%s", process.id, error)
    local x, y = 1, 3
    for i = 1, #str, 1 do
        local char = str:sub(i, i)
        if char == "\n" or x > w then
            x = 1
            y = y + 1
        end
        if char ~= "\n" then
            gpu.set(x, y, char)
            x = x + 1
        end
    end
end
backend.process.create_process({
    main = main.main,
    name = "GmuxFrontend",
    components = component.list(),
    args = {backend},
    error_handler = error_handler
})

backend.loop(function()
end)

backend.finish()
gpu.freeAllBuffers()
gpu.setBackground(0x000000)
gpu.setForeground(0xffffff)
local w, h = gpu.getResolution()
gpu.fill(1, 1, w, h, " ")
os.execute("clear")
