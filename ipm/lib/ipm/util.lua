local fs = require("filesystem")
local serialization = require("serialization")
local M = {}

function M.rmdir(path)
    local iter, err = fs.list(path)
    if not iter then
        io.stderr:write("Error: " .. path .. " list failed: " .. tostring(err) .. "\n")
        return
    end
    for file in iter do
        if fs.isDirectory(path .. "/" .. file) then
            M.rmdir(path .. "/" .. file)
        else
            fs.remove(path .. "/" .. file)
        end
    end
end

function M.mkdirp(path)
    if not fs.exists(path) then
        fs.makeDirectory(path)
    end
end

function M.load_file(path)
    if not fs.exists(path) then
        path = path .. ".cfg"
    end
    local f, err = io.open(path, "r")
    if not f then
        io.stderr:write("Error: " .. path .. " open failed: " .. tostring(err) .. "\n")
        return nil
    end
    local data, err = serialization.unserialize(f:read("*a"))
    f:close()
    if not data then
        io.stderr:write("Error: " .. path .. " parse failed: " .. tostring(err) .. "\n")
        return nil
    end
    return data
end

function M.each_file(path, pattern, func, keyfunc, with_name)
    if keyfunc == nil then
        keyfunc = function(file)
            return file
        end
    end
    local iter, err = fs.list(path)
    if not iter then
        io.stderr:write("Error: " .. path .. " list failed: " .. tostring(err) .. "\n")
        return
    end
    local output = {}
    for file in iter do
        if file:match(pattern) then
            output[keyfunc(file)] = func(with_name and file or path .. "/" .. file)
        end
    end
    return output
end

function M.save_file(path, data)
    if not path:match("%.cfg$") then
        path = path .. ".cfg"
    end
    local f, err = io.open(path, "w")
    if not f then
        io.stderr:write("Error: " .. path .. " open failed: " .. tostring(err) .. "\n")
        return nil
    end
    f:write(serialization.serialize(data, math.huge))
    f:close()
end

function M.cherry_base_path(func, path)
    return function(p, ...)
        return func(path .. "/" .. p, ...)
    end
end

function M.format(url, t)
    -- 查找url中${...}，使用t中对应键的值替换，若为x:1则选择x对应值的第一个'/'之前内容
    return (url:gsub("%${(.-)}", function(key)
        -- 检查是否有:分割
        local base, op = key:match("^([^:]+):(.+)$")
        if base and op then
            local val = t[base]
            if type(val) ~= "string" then return "" end
            -- 只处理x:1的情况
            if op == "1" then
                -- 返回第一个'/'之前的内容
                return val:match("([^/]+)") or val
            elseif op:match("^%d+%.%.$") then
                -- 处理x:2.. 这种情况，返回第2段及之后
                local start_idx = tonumber(op:match("^(%d+)%.%.$"))
                if start_idx then
                    local parts = {}
                    for part in val:gmatch("[^/]+") do
                        table.insert(parts, part)
                    end
                    if start_idx <= #parts then
                        return table.concat({table.unpack(parts, start_idx)}, "/")
                    else
                        return ""
                    end
                end
            end
            -- 其他情况暂不处理
            return val
        else
            -- 普通替换
            local val = t[key]
            if val == nil then return "" end
            return tostring(val)
        end
    end))
end

return M