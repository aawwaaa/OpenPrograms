return function(name, module)
    local id = name
    while #id < 8 do id = id .. "0" end
    local api = {
        type = name,
        address = "virtual0-"..id:sub(0, 4).."-"..id:sub(5, 8).."-0000-component000",
    }
    setmetatable(api, {
        __index = module
    })
    return api
end
