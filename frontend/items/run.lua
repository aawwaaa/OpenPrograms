local function main()
    local component = require("component")
    local gpu = component.gpu

    local w, h = gpu.getResolution()
    gpu.setForeground(0x000000)
    gpu.setBackground(0xaaaaaa)
    gpu.fill(1, 1, w, h, " ")
    io.write("Path: \n >")
    gpu.setBackground(0x888888)
    gpu.fill(3, 2, w - 6, 1, " ")
    local line = io.stdin:readLine(false)
    local resolved = require("text").trim(line)
    local api = component.gmuxapi
    local result = api.create_graphics_process({
        width = 90, height = 20,
        main_path = resolved,
    })
    local window = api.create_window({
        source = result,
        process = result.process,
        title = resolved,
        event_handler = result,
        x = 10, y = 10
    })

    api.get_process().win:close()
end

return {
    name = "Run",
    action = function()
        local api = require("frontend/api")
        local gpu = require("component").gpu
        local result = api.create_graphics_process({
            gpu = gpu, width = 60, height = 4,
            main = main
        })
        local window = api.create_window({
            source = result,
            process = result.process,
            title = "Run...",
            event_handler = result,
            gpu = gpu, x = 10, y = 10
        })
        result.process.win = window
        window.source.set_size = nil
    end
}
