local utf8 = require("utf8")
local bufferops = require("screen.bufferops")

return function (client, address, width, height, depth)
    local methods = {}
    local object = {
        invoke = function(method, ...)
            if methods[method] then
                return methods[method](...)
            end
            print("? method of gpu " .. method)
        end
    }

    local buffers = {}
    local palette = depth == 4 and {
        0xFFFFFF, 0xFFCC33, 0xCC66CC, 0x6699FF, 0xFFFF33, 0x33CC33, 0xFF6699, 0x333333,
        0xCCCCCC, 0x336699, 0x9933CC, 0x333399, 0x663300, 0x336600, 0xFF3333, 0x000000
    } or {
        0x0F0F0F, 0x1E1E1E, 0x2D2D2D, 0x3C3C3C, 0x4B4B4B, 0x5A5A5A, 0x696969, 0x787878,
        0x878787, 0x969696, 0xA5A5A5, 0xB4B4B4, 0xC3C3C3, 0xD2D2D2, 0xE1E1E1, 0xF0F0F0,
    }

    local function create_buffer(w, h)
        local id = 0;
        for i = 0, #buffers+1 do
            if not buffers[i] then
                id = i
                break
            end
        end
        buffers[id] = {
            w = w, h = h, vw = w, vh = h,
            chars = string.char(0, 0, 0, 0):rep(w * h),
            fgs = string.char(0, 0, 0, 0):rep(w * h),
            bgs = string.char(0, 0, 0, 0):rep(w * h),
        }
        return id
    end
    local screen_buffer = create_buffer(width, height)
    local active_buffer = screen_buffer
    local fg, bg = 0xFFFFFF, 0x000000

    local screen = nil
    local function send_view()
        if not screen then
            return
        end
        screen.send_view(buffers[screen_buffer].vw, buffers[screen_buffer].vh)
    end
    local function send_buffer()
        if not screen then
            return
        end
        screen.send_buffer(buffers[screen_buffer].chars, buffers[screen_buffer].fgs, buffers[screen_buffer].bgs)
    end
    local function send_op(method, ...)
        if not screen then
            return
        end
        screen.send_op(method, ...)
    end
    object.send = function()
        send_view()
        send_buffer()
    end

    function methods.bind(address, reset)
        if reset == nil then reset = true end
        if screen then screen.gpu = nil end
        screen = client.component_handlers[address:sub(1, 4)]
        screen.bind(object, reset)
        screen.size(width, height)
    end
    function methods.setBackground(color, is_palette)
        bg = is_palette and palette[color + 1] or color
    end
    function methods.setForeground(color, is_palette)
        fg = is_palette and palette[color + 1] or color
    end
    function methods.setPaletteColor(index, color)
        palette[index + 1] = color
    end
    function methods.maxDepth() end -- nothing
    function methods.setDepth() end -- nothing
    function methods.setResolution(w, h)
        buffers[screen_buffer].vw = w
        buffers[screen_buffer].vh = h
        send_view()
    end
    function methods.maxResolution() end -- nothing
    methods.setViewport = methods.setResolution

    function methods.set(x, y, value, vertical)
        local buffer = buffers[active_buffer]
        bufferops.set(buffer, x, y, value, vertical or false, fg, bg)
        if active_buffer == screen_buffer then
            send_op("set", x, y, value, vertical or false, fg, bg)
        end
    end
    function methods.copy(x, y, w, h, tx, ty)
        local buffer = buffers[active_buffer]
        bufferops.copy(buffer, x, y, w, h, tx, ty)
        if active_buffer == screen_buffer then
            send_op("copy", x, y, w, h, tx, ty)
        end
    end
    function methods.fill(x, y, w, h, value)
        local buffer = buffers[active_buffer]
        bufferops.fill(buffer, x, y, w, h, value, fg, bg)
        if active_buffer == screen_buffer then
            send_op("fill", x, y, w, h, value, fg, bg)
        end
    end
    
    function methods.setActiveBuffer(buffer)
        active_buffer = buffer
    end
    function methods.buffers() end -- nothing
    function methods.allocateBuffer(w, h)
        create_buffer(w or width, h or height)
    end
    function methods.freeBuffer(buffer)
        buffer = buffer or active_buffer
        if buffer == screen_buffer then return end
        buffers[buffer] = nil
        if active_buffer == buffer then
            active_buffer = screen_buffer
        end
    end
    function methods.freeAllBuffers()
        for i = 1, #buffers do
            buffers[i] = nil
        end
        active_buffer = screen_buffer
    end
    function methods.totalMemory() end -- nothing
    function methods.freeMemory() end -- nothing
    function methods.bitblt(dst, col, row, w, h, src, fromCol, fromRow)
        dst = dst or screen_buffer
        col = col or 1
        row = row or 1
        w = w or buffers[dst].w
        h = h or buffers[dst].h
        src = src or active_buffer
        fromCol = fromCol or 1
        fromRow = fromRow or 1

        local dst_buffer = buffers[dst]
        local src_buffer = buffers[src]
        if col + w > dst_buffer.w then
            w = dst_buffer.w - col
        end
        if row + h > dst_buffer.h then
            h = dst_buffer.h - row
        end
        if fromCol + w > src_buffer.w then
            w = buffers[src].w - fromCol
        end
        if fromRow + h > src_buffer.h then
            h = src_buffer.h - fromRow
        end
        
        local slice_chars, slice_fgs, slice_bgs = bufferops.slice(src_buffer, fromCol, fromRow, w, h)
        bufferops.apply(dst_buffer, col, row, w, h, slice_chars, slice_fgs, slice_bgs)
        if active_buffer == screen_buffer then
            send_op("apply", col, row, w, h, slice_chars, slice_fgs, slice_bgs)
        end
    end

    function object.close()
    end

    return object
end