local _thread = {}
for k, v in pairs(require("thread")) do
    _thread[k] = v
end
return function(instances) 
    local thread = {}
    
    local metatable = {
        __index = _thread
    }
    setmetatable(thread, metatable)

    local threads = {}
    
    function thread._has_alive()
        for _, th in ipairs(threads) do
            if th:status() ~= "dead" then
                return true
            end
        end
        return false
    end
    function thread._kill_threads()
        for _, th in ipairs(threads) do
            if th:status() ~= "dead" then
                th:kill()
            end
        end
    end
    function thread.create(func, ...)
        local th = _thread.create(func, ...)
        table.insert(threads, th)
        return th
    end

    instances.thread = thread
end
