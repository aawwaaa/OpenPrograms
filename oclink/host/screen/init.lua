local function run(...)
    -- 读取环境变量LOVE_PATH，调用LOVE_PATH指向的可执行文件，参数为当前文件所在目录
    local love_path = os.getenv("LOVE_PATH")
    if not love_path then
        error("Missing LOVE_PATH environment variable")
    end

    local current_dir = require("util").get_current_dir()

    local cmd = string.format('"%s" "%s" %s &', love_path, current_dir .. "/screen/", table.concat({...}, " "))
    local process = io.popen(cmd)
    if process then
        process:close()
    end
end

return run