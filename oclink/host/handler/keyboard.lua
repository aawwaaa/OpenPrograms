return function (client, address)
    local function invoke(method, ...)
    end
    return {
        invoke = invoke,
        close = function() end
    }
end