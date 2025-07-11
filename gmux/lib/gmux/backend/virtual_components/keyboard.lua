return function(options)
    local keyboard = {
        type = "keyboard",
        address = "virtual0-keyb-oard-0000-component000",
    }
    function keyboard.pushSignal(...) end
    return keyboard
end
