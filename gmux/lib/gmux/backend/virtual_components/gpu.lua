local math = require("math")
local vgpu_callbacks = {}
local keep = 32
return function(options)
    local real = options.gpu

    local width = options.width or 30
    local height = options.height or 19
    if width * height > real.freeMemory() then
        height = math.floor((real.freeMemory() - keep) / width)
    end
    local viewportWidth = width
    local viewportHeight = height
    local screenBuffer = real.allocateBuffer(width, height)
    local buffers = {}
    local activeBuffer = screenBuffer
    local background = 0x000000
    local foreground = 0xffffff
    local dirty = false

    local function freeBuffer(index)
        return real.freeBuffer(index)
    end
    local callback = function(index)
        if screenBuffer >= index then screenBuffer = screenBuffer - 1 end
        for i, a in ipairs(buffers) do 
            if a >= index then buffers[i] = a - 1 end
        end
    end
    vgpu_callbacks[#vgpu_callbacks+1] = callback

    local function applyState()
        real.setActiveBuffer(activeBuffer)
        real.setBackground(background)
        real.setForeground(foreground)
    end

    local gpu = {
        type = "gpu",
        address = "virtual0-gpu0-0000-0000-component000",
    }
    local vscreen = ""
    function gpu.bind(address)
        vscreen = address
    end
    function gpu.getScreen()
        return vscreen
    end
    function gpu.getBackground()
        return background, false
    end
    function gpu.setBackground(color)
        local last = background
        background = color
        return last, nil
    end
    function gpu.getForeground()
        return foreground, false
    end
    function gpu.setForeground(color)
        local last = foreground
        foreground = color
        return last, nil
    end
    gpu.getPaletteColor = real.getPaletteColor
    gpu.setPaletteColor = real.setPaletteColor
    gpu.maxDepth = real.maxDepth
    gpu.getDepth = real.getDepth
    function gpu.setDepth(depth)
        return real.setDepth(depth)
    end
    
    gpu.maxResolution = real.maxResolution
    function gpu.getResolution()
        return width, height
    end
    function gpu.setResolution(w, h)
        local oldBuffer = screenBuffer
        if w * h <= real.freeMemory() - keep then
            screenBuffer = real.allocateBuffer(w, h)
            real.bitblt(screenBuffer, 0, 0, math.min(width, w), math.min(height, h), oldBuffer, 0, 0)
            freeBuffer(oldBuffer)
        elseif w * h <= real.freeMemory() + width * height - keep then
            freeBuffer(oldBuffer)
            screenBuffer = real.allocateBuffer(w, h)
        else
            freeBuffer(oldBuffer)
            h = math.floor((real.freeMemory() - keep) / w)
            screenBuffer = real.allocateBuffer(w, h)
        end
        if activeBuffer == oldBuffer then activeBuffer = screenBuffer end
        width = w
        height = h
        viewportWidth = width
        viewportHeight = height
        gpu.pushSignal("screen_resized", w, h)
    end
    function gpu.getViewport()
        return viewportWidth, viewportHeight
    end
    function gpu.setViewport(w, h)
        if w > width or h > height then
            return false
        end
        viewportWidth = w
        viewportHeight = h
        return true
    end

    function gpu.get(x, y)
        real.setActiveBuffer(activeBuffer)
        return real.get(x, y)
    end
    function gpu.set(x, y, ...)
        applyState()
        real.set(x, y, ...)
        dirty = true
    end
    function gpu.copy(...)
        real.setActiveBuffer(activeBuffer)
        dirty = true
        return real.copy(...)
    end
    function gpu.fill(...)
        applyState()
        real.fill(...)
        dirty = true
    end

    function gpu.getActiveBuffer()
        if activeBuffer == screenBuffer then
            return 0
        end
        return activeBuffer
    end
    function gpu.setActiveBuffer(buffer)
        if buffer == 0 then
            activeBuffer = screenBuffer
        else
            activeBuffer = buffer 
        end
        real.setActiveBuffer(buffer)
    end
    function gpu.buffers()
        return buffers
    end
    function gpu.allocateBuffer(w, h)
        local buffer = real.allocateBuffer(w, h)
        buffers[#buffers + 1] = buffer
        return buffer
    end
    function gpu.freeBuffer(buffer)
        for i = #buffers, 1, -1 do
            if buffers[i] == buffer then
                table.remove(buffers, i)
                break
            end
        end
        return freeBuffer(buffer)
    end
    function gpu.freeAllBuffers()
        for _, buffer in ipairs(buffers) do
            freeBuffer(buffer)
        end
        buffers = {}
    end
    gpu.totalMemory = real.totalMemory
    gpu.freeMemory = real.freeMemory
    function gpu.getBufferSize(buffer)
        if buffer == 0 then buffer = screenBuffer end
        return real.getBufferSize(buffer)
    end
    function gpu.bitblt(dst, col, row, w, h, src, fromCol, fromRow)
        if dst == 0 then dst = screenBuffer end
        if src == 0 then src = screenBuffer end
        dirty = true
        return real.bitblt(dst, col, row, w, h, src, fromCol, fromRow)
    end

    function gpu._copy_to_screen(col, row, x, y, w, h)
        real.bitblt(0, col, row, w, h, screenBuffer, x, y)
        dirty = false
    end
    function gpu._is_dirty()
        return dirty
    end
    function gpu.remove()
        freeBuffer(screenBuffer)
        for _, buffer in ipairs(buffers) do
            freeBuffer(buffer)
        end
        for i, cb in ipairs(vgpu_callbacks) do
            if cb == gpu then
                table.remove(vgpu_callbacks, i)
                break
            end
        end
    end
    function gpu.active()
        if activeBuffer == nil then return end
        real.setActiveBuffer(activeBuffer)
    end

    function gpu.pushSignal(...) end
    return gpu
end
