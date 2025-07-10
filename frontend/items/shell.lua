return {
    name = "Shell",
    action = function()
        local api = require("frontend/api")
        local gpu = require("component").gpu
        local result = api.create_graphics_process({
            gpu = gpu, width = 90, height = 20,
            main_path = "/bin/sh.lua",
        })
        local window = api.create_window({
            source = result,
            process = result.process,
            title = "Shell",
            event_handler = result,
            gpu = gpu, x = 10, y = 10
        })
    end
}
