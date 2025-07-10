local function main()
    local component = require("component")
    local computer = require("computer")
    local event = require("event")
    local math = require("math")
    local gpu = component.gpu

    local function fixed(d)
        return tostring(math.floor(d * 100) / 100)
    end

    local w, h = gpu.getResolution()
    gpu.setForeground(0x000000)
    gpu.setBackground(0xaaaaaa)
    local backend = require("backend/core")
    local desktop = require("frontend/desktop")
    while true do
        gpu.fill(1, 1, w, h, " ")
        gpu.set(1, 1, "CPU")
        gpu.set(12, 1, fixed(backend.cpu_usage * 100) .. "%")
        gpu.set(1, 2, "FreeMemory")
        gpu.set(12, 2, fixed(computer.freeMemory() / 1024))
        gpu.set(22, 2, fixed(computer.totalMemory() / 1024))
        gpu.set(1, 3, "GPU")
        gpu.set(12, 3, fixed(desktop.gpu_usage * 100) .. "%")
        gpu.set(1, 4, "GPUFMemory")
        gpu.set(12, 4, fixed(component.gpu.freeMemory() / 1024))
        gpu.set(22, 4, fixed(component.gpu.totalMemory() / 1024))
        event.pull(0.01)
    end
end

return {
    name = "Monitor",
    action = function()
        local api = require("frontend/api")
        local gpu = require("component").gpu
        local result = api.create_graphics_process({
            gpu = gpu, width = 30, height = 4,
            main = main
        })
        local window = api.create_window({
            source = result,
            process = result.process,
            title = "Monitor",
            event_handler = result,
            gpu = gpu, x = 10, y = 10
        })
        result.process.win = window
        window.source.set_size = nil
    end
}
