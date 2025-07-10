local computer = require("computer")
local M = {}

M.desktop_background = 0x444444
M.gpu = nil
local buf = nil

function M.vgpu_source(vgpu, vscreen)
    return {
        copy = function(col, row)
            vgpu._copy_to_screen(col, row)
        end,
        need_copy = function()
            return vgpu._is_dirty()
        end,
        size = function()
            return vgpu.getViewport()
        end,
        set_size = function(w, h)
            vgpu.setResolution(w, h)
            vscreen.pushSignal("screen_resized", w, h)
        end
    }
end
function M.empty_source()
    return {
        copy = function() end,
        need_copy = function() return false end,
        size = function() return 20, 10 end,
    }
end
function M.buffer_source(gpu, buffer)
    return {
        copy = function(col, row)
            local width, height = gpu.getBufferSize(buffer)
            gpu.bitblt(gpu.getActiveBuffer(), col, row, width, height, buffer, 1, 1)
        end,
        need_copy = function()
            return true
        end,
        size = function()
            return gpu.getBufferSize(buffer)
        end,
    }
end
local keyboard_events = {key_down = 1, key_up = 1, clipboard = 1}
local screen_events = {screen_resized = 1, touch = 1, drag = 1, drop = 1, scroll = 1, walk = 1}
function M.virtual_component_event_handler(options)
    return function(type, _, ...)
        if keyboard_events[type] and options.keyboard then
            options.keyboard.pushSignal(type, ...)
        end
        if screen_events[type] and options.screen then
            options.screen.pushSignal(type, ...)
        end
    end
end

local Window = {}
M.Window = Window
function Window:new(options)
    local obj = {
        source = options.source or M.empty_source(),
        process = options.process or nil,
        event_handler = options.event_handler or nil,
        title = options.title or "Window",
        gpu = options.gpu,
        x = options.x or 1,
        y = options.y or 1,
        minimized = options.minimized or false,
        maximized = options.maximized or false,
        refresh = false,
        onclose = options.onclose or function() end
    }
    setmetatable(obj, self)
    self.__index = self
    table.insert(M.windows, 1, obj)
    return obj
end

function Window:draw()
    -- if not self.refresh then
    --     return
    -- end
    -- self.gpu.setActiveBuffer(buf)
    local foreground = 0x888888
    if M.get_focused_window() == self then
        foreground = 0x000000
    end
    self.gpu.setForeground(foreground)
    self.gpu.setBackground(0xffffff)
    local width, height = self.source.size()
    self.gpu.fill(self.x, self.y, width - 6, 1, " ")
    local prefix = ""
    if self.process then
        if self.process.status == "waiting" then
            prefix = "[Waiting] - "
        elseif self.process.status == "dead" then
            prefix = "[Dead] - "
        elseif self.process.status == "error" then
            prefix = "[Error] - "
        end
    end
    self.gpu.set(self.x + 1, self.y, prefix .. self.title)
    self.gpu.setForeground(0xffaa00)
    self.gpu.set(self.x + width - 6, self.y, self.minimized and "<>" or "\\/")
    if self.source.set_size then
        self.gpu.setForeground(0x00aaff)
        self.gpu.set(self.x + width - 4, self.y, self.maximized and "<>" or "/\\")
    else
        self.gpu.setForeground(0x888888)
        self.gpu.set(self.x + width - 4, self.y, "--")
    end
    self.gpu.setBackground(0xff0000)
    self.gpu.setForeground(0xffffff)
    self.gpu.set(self.x + width - 2, self.y, "><")
    if not self.minimized then
        self.source.copy(self.x, self.y + 1)
        -- if M.get_focused_window() == self then
        --     -- self.gpu.setActiveBuffer(0)
        --     self.source.copy(self.x, self.y + 1)
        -- end
        self.refresh = false
    end
end
function Window:minimize(minimized)
    if self.minimized == minimized then return end
    self.minimized = minimized
end
function Window:maximize(maximized)
    if self.maximized == maximized then return end
    if not self.source.set_size then return end
    self.maximized = maximized
    -- self.gpu.setActiveBuffer(0)
    if maximized then
        self.real_pos = {self.x, self.y}
        self.real_size = {self.source.size()}
        self.x = 1
        self.y = 1
        local w, h = self.gpu.getResolution()
        self.source.set_size(w, h - 1)
    else
        self.x = self.real_pos[1]
        self.y = self.real_pos[2]
        self.source.set_size(self.real_size[1], self.real_size[2])
    end
end
function Window:focus()
    for i, win in ipairs(M.windows) do
        if win == self then
            table.remove(M.windows, i)
            break
        end
    end
    table.insert(M.windows, 1, self)
end
function Window:set_position(x, y)
    self.x = x
    self.y = y
end
function Window:resize(w, h)
    self.source.set_size(w, h)
end
function Window:close()
    for i, win in ipairs(M.windows) do
        if win == self then
            table.remove(M.windows, i)
            break
        end
    end
    self.onclose()
end

M.windows = {}
function M.create_window(options)
    return Window:new(options)
end
function M.get_focused_window()
    return M.windows[1]
end
function M.draw()
    for i=#M.windows, 1, -1 do
        M.windows[i]:draw()
    end
end

function M.test_window(x, y)
    for i=1, #M.windows, 1 do
        local window = M.windows[i]
        local w, h = window.source.size()
        if window.minimized then
            if x >= window.x and x < window.x + w and y == window.y then
                return window, x - window.x + 1, 1
            end
        elseif x >= window.x and x < window.x + w and
            y >= window.y and y < window.y + h + 1 then
            return window, x - window.x + 1, y - window.y + 1
        end
    end
    return nil, x, y
end

local touch_state = nil
local drag_data = nil
local last_handle = 0
function M.handle_signal(type, ...)
    local focused = M.get_focused_window()
    if type == "key_down" or type == "key_up" or type == "clipboard" then
        if not focused then return end
        focused.event_handler(type, ...)
        return
    end
    if type == "touch" then
        local address, touch_x, touch_y, modify, player = ...
        local window, x, y = M.test_window(touch_x, touch_y)
        if window then
            window:focus()
            local w, h = window.source.size()
            if x == w and y == h + 1 and window.source.set_size then
                touch_state = {type = "resize", window = window}
                return
            end
            if y > 1 then
                window.event_handler(type, address, x, y - 1, modify, player)
                return
            end
            if x == w - 5 or x == w - 4 then
                window:maximize(false)
                window:minimize(not window.minimized)
                return
            elseif x == w - 3 or x == w - 2 then
                window:minimize(false)
                window:maximize(not window.maximized)
                return
            elseif x == w - 1 or x == w then
                window:close()
                window.process:kill()
                return
            end
            if window.process and window.process.status == "error" and modify then
                require("frontend/api").show_error(window.process.error)
                return
            end
            touch_state = {type = "drag", window = window, x = x, y = y}
            return
        end
        M.desktop_touch(touch_x, touch_y)
        return
    end
    if type == "drag" then
        local address, touch_x, touch_y, modify, player = ...
        if not touch_state then
            focused.event_handler(type, address, touch_x - focused.x + 1, touch_y - focused.y, modify, player)
            return
        end
        drag_data = {touch_x, touch_y}
        if last_handle + 0.1 < computer.uptime() then
            if touch_state.type == "drag" then
                focused:set_position(touch_x - touch_state.x + 1, touch_y - touch_state.y + 1)
            end
            if touch_state.type == "resize" then
                focused:resize(touch_x - focused.x + 1, touch_y - focused.y)
            end
            drag_data = nil
            last_handle = computer.uptime()
        end
        return
    end
    if type == "drop" then
        if touch_state then
            if drag_data then
                local touch_x, touch_y = table.unpack(drag_data)
                if touch_state.type == "drag" then
                    focused:set_position(touch_x - touch_state.x + 1, touch_y - touch_state.y + 1)
                end
                if touch_state.type == "resize" then
                    focused:resize(touch_x - focused.x + 1, touch_y - focused.y)
                end
            end
            touch_state = nil
            return
        end
        local address, touch_x, touch_y, modify, player = ...
        focused.event_handler(type, address, touch_x - focused.x + 1, touch_y - focused.y, modify, player)
    end
end

M.desktop_items = {}

function M.init()
    -- buf = M.gpu.allocateBuffer(M.gpu.getResolution())
end

M.gpu_usage = 0
function M.tick()
    local check = computer.uptime()
    M.gpu.setActiveBuffer(0)
    local w, h = M.gpu.getResolution()
    M.gpu.setBackground(0x444444)
    M.gpu.fill(1, 1, w, h, " ")
    M.gpu.setForeground(0xffffff)
    for i, item in ipairs(M.desktop_items) do
        M.gpu.set(1, i, "[" .. item.name .. "]")
    end
    for i=#M.windows, 1, -1 do
        M.windows[i].refresh = true
    end
    M.draw()
    -- M.gpu.bitblt(0, 1, 1, w, h, buf, 1, 1)
    local deltat = computer.uptime() - check
    M.gpu_usage = deltat / require("frontend/config").gpu_usage_factor
end
function M.desktop_touch(x, y)
    local item = M.desktop_items[y]
    if not item then return end
    if x > #item.name + 2 then return end
    item.action()
end

return M
