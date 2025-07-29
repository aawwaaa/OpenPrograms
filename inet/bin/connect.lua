local inet = require("inet")
local shell = require("shell")

local args, options = shell.parse(...)

local print = print
if options.q or options.quiet then
    print = function(...) end
end

-- 显示可用接入点列表
local function display_access_points(access_points)
    if not access_points or next(access_points) == nil then
        print("No access points found")
        return false
    end
    
    print("Available access points:")
    local index = 1
    for device, data in pairs(access_points) do
        local verify_status = data.verify or "Open"
        print("[" .. index .. "] " .. data.name .. " - " .. verify_status)
        index = index + 1
    end
    return true
end

-- 获取并验证用户选择
local function get_user_selection(access_points)
    if args[1] then
        for device, data in pairs(access_points) do
            if device:sub(1, #args[1]) == args[1] then
                return device, data
            end
        end
        print("Access point not found")
        return nil, nil
    end

    local count = 0
    for _ in pairs(access_points) do
        count = count + 1
    end
    
    while true do
        print("Select access point (1-" .. count .. "):")
        local input = io.read("*n")
        local _ = io.read("*l")
        
        if input and input >= 1 and input <= count then
            local index = 1
            for device, data in pairs(access_points) do
                if index == input then
                    return device, data
                end
                index = index + 1
            end
        else
            print("Invalid selection, please enter a number between 1 and " .. count)
        end
    end
end

-- 连接到指定接入点
local function connect_to_access_point(access_point, data)
    print("Connecting to " .. data.name .. "...")
    
    -- 使用正确的API调用
    inet.connect_to(access_point)
    
    print("Connection successful")
    return true
end

-- 处理需要验证的接入点
local function handle_verification(access_point, data)
    local message = ""
    if not data.verify then
        message = ""
    else
        print("Waiting for verification...")
        print("Verification prompt: " .. data.verify)
        
        message = io.read("*l")
        if not message then
            print("Verification failed: no verification information entered")
            inet.disconnect()
            return false
        end
    end
    
    local success, error_msg = inet.verify(message)
    if success then
        print("Verification successful")
        return true
    else
        print("Verification failed: " .. (error_msg or "Unknown error"))
        inet.disconnect()
        return false
    end
end

-- 请求网络地址
local function request_network_address()
    if inet.mode() == "switch" then
        return true
    end

    print("Requesting network address...")
    
    local address = inet.request_address()
    if address then
        print("Network address: " .. address)
        return true
    else
        print("Failed to get network address")
        inet.disconnect()
        return false
    end
end

-- 主程序函数
local function main()
    print("Network connection tool")
    print("Searching for available access points...")
    
    -- 获取可用接入点
    local access_points = inet.list_access_points()
    
    -- 显示接入点列表
    if not display_access_points(access_points) then
        return
    end
    
    -- 获取用户选择
    local selected_device, selected_data = get_user_selection(access_points)
    
    -- 连接到选定的接入点
    if not connect_to_access_point(selected_device, selected_data) then
        return
    end
    
    -- 处理验证（如果需要）
    if not handle_verification(selected_device, selected_data) then
        return
    end
    
    -- 请求网络地址
    if not request_network_address() then
        return
    end
    
    print("Network connection completed!")
end

-- 程序入口
main()