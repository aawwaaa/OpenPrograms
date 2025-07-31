local screen = require("screen")
local role_screen = require("role.screen")

return function (client, address, ...)
    local object = { keyboards = {...} }
    local width, height = 80, 25
    local gpu = nil
    local screen_client = nil
    local screen_on = true
    local precise_mode = false
    function object.invoke(method, ...)
        local updated = false
        if method == "turnOn" then
            screen_on = true
            updated = true
        elseif method == "turnOff" then
            screen_on = false
            updated = true
        elseif method == "setPrecise" then
            precise_mode = ...
            updated = true
        end
        if updated and screen_client then
            screen_client:send("state", screen_on, precise_mode)
        end
    end
    function object.init_screen(client)
        screen_client = client
        if gpu then
            screen_client:send("resolution", width, height)
            gpu.send()
        end
    end
    function object.remove_screen()
        screen_client = nil
    end
    function object.bind(target, reset)
        if reset == nil then reset = true end
        gpu = target
        if reset and screen_client then
            screen_client:send("reset")
            screen_on = true
            precise_mode = false
        end
        if gpu then
            gpu.send()
        end
    end
    function object.size(w, h)
        width, height = w, h
        if screen_client then
            screen_client:send("resolution", width, height)
        end
    end
    function object.send_buffer(buffer, fgs, bgs)
        if not screen_client then
            return
        end
        screen_client:send("buffer", buffer, fgs, bgs)
    end
    function object.send_view(vw, vh)
        if not screen_client then
            return
        end
        screen_client:send("view", vw, vh)
    end
    function object.send_op(method, ...)
        if not screen_client then
            return
        end
        screen_client:send("op", method, ...)
    end
    role_screen.handlers[address] = object
    screen(address)
    function object.close()
        if not screen_client then
            return
        end
        screen_client:send("close")
        screen_client:close()
    end

    function object.onmessage(msg, ...)
        if msg == "drag" or msg == "touch" or msg == "drop" then
            local x, y, button = ...
            client:send("signal", msg, address, x, y, button, "external")
        end
        if object.keyboards[1] then
            if msg == "key_down" or msg == "key_up" then
                local unicode, keycode = ...
                client:send("signal", msg, object.keyboards[1], unicode, keycode, "external")
            end
            if msg == "clipboard" then
                local text = ...
                client:send("signal", msg, object.keyboards[1], text, "external")
            end
        end
    end

    return object
end
