local desktop = require("frontend/desktop")
local backend = require("backend/core")
local M = {}

function M.create_headless_process(options)
    local default_components = { "computer" }
    if backend.process.current_process then
        default_components = {}
        for k, v in pairs(backend.process.current_process.instances.component._get_components()) do
            default_components[k] = v
        end
    end
    local api = backend.virtual_components.api("gmuxapi", M)
    local components = options.components or default_components
    components[api.address] = api
    local process = backend.process.create_process({
        main = options.main or function() dofile(options.main_path) end,
        components = components
    })
    return {process = process}
end
function M.create_graphics_process(options)
    local default_components = { "computer" }
    local current_process = backend.process.current_process
    if current_process then
        default_components = {}
        for k, v in pairs(current_process.instances.component._get_components()) do
            local type = current_process.instances.component.type(k)
            if type ~= "gpu" and type ~= "screen" and type ~= "keyboard" then
                default_components[k] = v
            end
        end
    end
    local vgpu = backend.virtual_components.gpu({
        gpu = options.gpu or desktop.gpu,
        width = options.width or 30,
        height = options.height or 10
    })
    local vkeyboard = backend.virtual_components.keyboard()
    local vscreen = backend.virtual_components.screen({
        keyboards = {vkeyboard.address}
    })
    local components = options.components or default_components
    components[vgpu.address] = vgpu
    components[vkeyboard.address] = vkeyboard
    components[vscreen.address] = vscreen
    local api = backend.virtual_components.api("gmuxapi", M)
    components[api.address] = api
    local process = backend.process.create_process({
        main = options.main or function() dofile(options.main_path) end,
        components = components
    })
    return {process = process, gpu = vgpu, keyboard = vkeyboard, screen = vscreen}
end
function M.create_window(options)
    if not options.gpu then options.gpu = desktop.gpu end
    local source = desktop.empty_source()
    if type(options.source) == "table" then
        source = desktop.vgpu_source(options.source.gpu, options.source.screen)
    elseif type(options.source) == "number" then
        source = desktop.buffer_source(options.gpu, options.source)
    end
    local event_handler = options.event_handler
    if type(event_handler) == "table" then
        event_handler = desktop.virtual_component_event_handler(event_handler)
    end
    return desktop.create_window({
        source = source,
        process = options.process or backend.process.current_process,
        event_handler = event_handler,
        gpu = options.gpu,
        title = options.title,
        x = options.x or 1 ,
        y = options.y or 1
    })
end
function M.get_processes()
    return backend.process.processes
end
function M.get_windows()
    return desktop.windows
end

function M.show_error(error)
    local buffer = desktop.gpu.allocateBuffer(60, 25)
    desktop.gpu.setActiveBuffer(buffer)
    desktop.gpu.setForeground(0xff0000)
    desktop.gpu.setBackground(0xaaaaaa)
    desktop.gpu.fill(1, 1, 60, 25, " ")
    local x = 1
    local y = 1
    for i=1, #error, 1 do
        local char = error:sub(i, i)
        if char == "\n" or x > 60 then
            x = 1
            y = y + 1
        end
        if char ~= "\n" then
            desktop.gpu.set(x, y, char)
            x = x + 1
        end
    end
    return M.create_window({
        source = buffer,
        gpu = desktop.gpu,
        title = "Error",
        x = 20,
        y = 5
    })
end

function M.get_process()
    return backend.process.current_process
end

return M
