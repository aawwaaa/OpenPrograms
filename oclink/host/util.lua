local M = {}

M.get_current_dir = function()
    -- debug.getinfo(1, "S").source 返回形如 "@/path/to/file.lua"
    local info = debug.getinfo(1, "S")
    local source = info and info.source or ""
    if source:sub(1, 1) == "@" then
        local path = source:sub(2)
        -- 去掉文件名，保留目录
        return path:match("^(.*)[/\\][^/\\]*$") or "."
    else
        return "."
    end
end

M.file = function(path)
    local file = io.open(M.get_current_dir() .. "/" .. path, "r")
    if not file then
        return nil
    end
    local content = file:read("*a")
    file:close()
    return content
end

return M