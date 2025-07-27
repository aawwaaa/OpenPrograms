local ipm = ...
local fs = require("filesystem")
local serialization = require("serialization")
local M = {}

local execution_log = {
    execute = function(...)
        local packed = table.pack(...)
        local last = table.remove(packed, #packed)
        io.write(table.concat(packed, " ") .. " -> Execute: " .. last.type .. "\n")
    end,
    add_used = function(id, package)
        id = id:lower()
        io.write("Add used: " .. id .. " <- " .. package .. "\n")
    end,
    remove_used = function(id, package)
        id = id:lower()
        io.write("Remove used: " .. id .. " <- " .. package .. "\n")
    end,
    skip = function(src, dst) end,
    mkdir = function(dst)
        io.write("Make directory: " .. dst .. "\n")
    end,
    fetch = function(src, dst)
        io.write("Fetch: " .. src .. " -> " .. dst .. "\n")
    end,
    rm = function(path)
        io.write("Remove: " .. path .. "\n")
    end,
    rmdir = function(path)
        io.write("Remove directory: " .. path .. "\n")
    end,
    configure = function(path)
        io.write("Configure script: " .. path .. "\n")
    end,
    remove = function(path)
        io.write("Remove script: " .. path .. "\n")
    end,
    register = function(id, path, options)
        id = id:lower()
        io.write("Register: " .. id .. " -> " .. path .. "\n")
    end,
    unregister = function(id)
        id = id:lower()
        io.write("Unregister: " .. id .. "\n")
    end,
    mkinst = function(id, path)
        io.write("Make install disk: " .. id .. " -> " .. path .. "\n")
    end,
}

local execution = {
    execute = function(...)
        local packed = table.pack(...)
        M.execute(packed[#packed - 1])
    end,
    add_used = function(id, package)
        id = id:lower()
        local data = ipm.package.load_installed_file(id)
        data.used[package] = true
        ipm.package.save_installed_file(id, data)
    end,
    remove_used = function(id, package)
        id = id:lower()
        local data = ipm.package.load_installed_file(id)
        data.used[package] = nil
        ipm.package.save_installed_file(id, data)
    end,
    skip = function(src, dst) end,
    mkdir = function(dst)
        fs.makeDirectory(dst)
    end,
    fetch = function(src, dst, data)
        if type(data.repo) == "string" then
            data.repo = ipm.repo.repo(data.repo)
        end
        data.repo:fetch(src, dst)
    end,
    rm = function(path)
        fs.remove(path)
    end,
    rmdir = function(path)
        ipm.util.rmdir(path)
    end,
    configure = function(path)
        dofile(path)
    end,
    remove = function(path)
        dofile(path)
    end,
    register = function(id, path, options)
        id = id:lower()
        local data = ipm.package.has_package_file(id) and ipm.package.load_package_file(id) or {
            type = "package",
            id = id,
        }
        data.used = {}
        data.install_path = path
        for k, v in pairs(options) do
            data[k] = v
        end
        ipm.package.save_installed_file(id, data)
    end,
    unregister = function(id)
        id = id:lower()
        os.remove(ipm.package.data_installed_base .. "/" .. id .. ".cfg")
    end,
    mkinst = function(id, path, auto_installed)
        local existed = fs.exists(path .. "/.prop")
        local prop = io.open(path .. "/.prop", "w")
        if not prop then
            return
        end
        prop:write(serialization.serialize({
            label = existed and "ipm-packages" or id
        }, math.huge))
        prop:close()
        if not existed then
            fs.copy(ipm.lib_base .. "/ipm_install.lua", path .. "/.install")
            fs.makeDirectory(path .. "/.ipm")
            fs.makeDirectory(path .. "/.ipm_packages")
            fs.copy(ipm.lib_base .. "/execute.lua", path .. "/.ipm/execute.lua")
            fs.copy(ipm.lib_base .. "/format.lua", path .. "/.ipm/format.lua")
            fs.copy(ipm.lib_base .. "/package.lua", path .. "/.ipm/package.lua")
            fs.copy(ipm.lib_base .. "/repo_install.lua", path .. "/.ipm/repo.lua")
            fs.copy(ipm.lib_base .. "/init_install.lua", path .. "/.ipm/init.lua")
            fs.copy(ipm.lib_base .. "/tui.lua", path .. "/.ipm/tui.lua")
            fs.copy(ipm.lib_base .. "/util.lua", path .. "/.ipm/util.lua")
        end
        local package = ipm.package.load_package_file(id)
        local file = io.open(path .. "/.ipm_packages/" .. id .. ".cfg", "w")
        if not file then
            return
        end
        local files = package.files
        package.files = {}
        for key, value in pairs(files) do
            local prefix = key:match("^[$?:]") or ""
            local value_noprefix = value:match("^//") and value:sub(2) or value
            local file_name = prefix ~= ":" and key:match("(/[^/]+)$") or ""
            package.files[prefix .. value_noprefix .. file_name] = value
        end
        package.repo = "local"
        package.source = package.source .. " -> " .. path
        package.auto_installed = auto_installed
        file:write(serialization.serialize(package, math.huge))
        file:close()
    end
}

local function log(type, ...)
    execution_log[type](...)
end

local function execute_line(data, line)
    local type = table.remove(line, 1)
    table.insert(line, data)
    return execution[type](table.unpack(line))
end

function M.has_error(data)
    if data.errors and next(data.errors) then
        return true
    end
    for _, line in ipairs(data.before) do
        if line[1] == "execute" then
            if M.has_error(line[#line]) then
                return true
            end
        end
    end
    for _, line in ipairs(data.run) do
        if line[1] == "execute" then
            if M.has_error(line[#line]) then
                return true
            end
        end
    end
    for _, line in ipairs(data.after) do
        if line[1] == "execute" then
            if M.has_error(line[#line]) then
                return true
            end
        end
    end
    return false
end

local execute_stack = {}

function M.execute(data)
    if data.before == nil then
        data.before = {}
    end
    if data.run == nil then
        data.run = {}
    end
    if data.after == nil then
        data.after = {}
    end
    local total_lines = math.max(#data.before + #data.run + #data.after, 1)
    local current_line = 0

    table.insert(execute_stack, function() return current_line / total_lines end)

    local function update_progress()
        current_line = current_line + 1
        ipm.tui.text(-5, "")
        ipm.tui.text(-4, "")
        ipm.tui.text(-3, "")
        for i=0, 2 do
            if execute_stack[i+1] then
                ipm.tui.progress(-i, "", execute_stack[i+1]())
            else
                ipm.tui.text(-i, "")
            end
        end
    end
    for _, task in ipairs(data.before) do
        log(table.unpack(task))
        update_progress()
        execute_line(data, task)
    end
    for _, task in ipairs(data.run) do
        log(table.unpack(task))
        update_progress()
        execute_line(data, task)
    end
    for _, task in ipairs(data.after) do
        log(table.unpack(task))
        update_progress()
        execute_line(data, task)
    end
    table.remove(execute_stack)
    update_progress()
end

return M