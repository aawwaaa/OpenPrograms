local fs = require("filesystem")

local ipm = ...

local M = {}

local data_package_base = "/usr/share/ipm/package"
local data_installed_base = "/usr/share/ipm/installed"
M.data_package_base = data_package_base

ipm.util.mkdirp(data_package_base)
ipm.util.mkdirp(data_installed_base)

local load_package_file = ipm.util.cherry_base_path(ipm.util.load_file, data_package_base)
local function has_package_file(id)
    return fs.exists(data_package_base .. "/" .. tostring(id) .. ".cfg")
end
local load_installed_file = ipm.util.cherry_base_path(ipm.util.load_file, data_installed_base)
local save_installed_file = ipm.util.cherry_base_path(ipm.util.save_file, data_installed_base)
local function is_installed(id)
    return fs.exists(data_installed_base .. "/" .. tostring(id) .. ".cfg")
end

function M.package_list()
    io.write("List: " .. data_package_base .. "\n")
    local inc_id = 1
    local output = ipm.util.each_file(data_package_base, "%.cfg$", load_package_file, function(file)
        local id = inc_id
        inc_id = inc_id + 1
        return id
    end, true)
    table.sort(output, function(a, b)
        return a.id < b.id
    end)
    for _, package in ipairs(output) do
        package.installed = is_installed(package.id)
    end
    return output
end
function M.package_list_installed()
    io.write("List: " .. data_installed_base .. "\n")
    local inc_id = 1
    local output = ipm.util.each_file(data_installed_base, "%.cfg$", load_installed_file, function(file)
        local id = inc_id
        inc_id = inc_id + 1
        return id
    end, true)
    table.sort(output, function(a, b)
        return a.id < b.id
    end)
    for _, package in ipairs(output) do
        package.installed = true
    end
    return output
end

function M.package_info(id)
    if not has_package_file(id) and not is_installed(id) then
        io.stderr:write("Error: package " .. id .. " not found\n")
        return
    end
    local package, installed;
    if has_package_file(id) then
        package = load_package_file(id)
    end
    if is_installed(id) then
        installed = load_installed_file(id)
    end
    return package, installed
end

function M.prepare_install(id, target, auto_installed)
    if not has_package_file(id) then
        io.stderr:write("Error: package " .. id .. " not found\n")
        return {
            type = "install", before = {}, run = {}, after = {},
            errors = {"Package not found: " .. id}
        }
    end
    if is_installed(id) then
        io.stderr:write("Error: package " .. id .. " already installed\n")
        return {
            type = "install", before = {}, run = {}, after = {},
            errors = {"Package already installed: " .. id}
        }
    end
    local package = load_package_file(id)
    if not package then
        io.stderr:write("Error: package " .. id .. " not found\n")
        return {
            type = "install", before = {}, run = {}, after = {},
            errors = {"Package not found: " .. id}
        }
    end
    local data = {
        type = "install",
        before = {},
        run = {},
        after = {}
    }
    data.package = package
    data.errors = {}
    for dep, path in pairs(package.dependencies or {}) do
        if not is_installed(dep) then
            local dep_data = M.prepare_install(dep, path, true)
            table.insert(data.before, {"execute", dep, dep_data})
            if not dep_data then
                table.insert(data.errors, "Dependency not satisfied: " .. dep)
            end
        end
        table.insert(data.before, {"add_used", dep, id})
    end
    io.write("Prepare install: " .. id .. " -> " .. target .. "\n")
    local repo = ipm.repo.repo(package.repo)
    if not repo then
        table.insert(data.errors, "Repo error: " .. package.repo)
        return data -- error message already printed
    end

    data.repo = repo
    local files = {}
    local dirs = {}
    local dirs_added = {}
    for src, dst in pairs(package.files) do
        local optional, dir = false, false
        if src:sub(1, 1) == "?" then
            optional = true
            src = src:sub(2)
        end
        if src:sub(1, 1) == ":" then
            dir = true
            src = src:sub(2)
        end
        local real_dst = target .. dst
        if dst:sub(1, 2) == "//" then
            real_dst = dst:sub(2)
        end
        if not dir then
            real_dst = real_dst .. "/" .. fs.name(src)
        end
        real_dst = fs.canonical(real_dst)
        if optional and fs.exists(real_dst) then
            io.write("Skipping optional file: " .. src .. " -> " .. real_dst .. "\n")
            table.insert(data.run, {"skip", src, real_dst})
            goto continue
        end
        real_dst = fs.canonical(real_dst)
        if dir and not fs.exists(real_dst) and not dirs_added[real_dst] then
            table.insert(dirs, real_dst)
            table.insert(data.run, {"mkdir", real_dst})
            dirs_added[real_dst] = true
        end
        if not dir then
            local dst_dir = fs.canonical(fs.path(real_dst))
            if not fs.exists(dst_dir) and not dirs_added[dst_dir] then
                if not optional then
                    dirs_added[dst_dir] = true
                    table.insert(dirs, dst_dir)
                end
                table.insert(data.run, {"mkdir", dst_dir})
            end
            if not optional then
                table.insert(files, real_dst)
            else
                dirs_added[dst_dir] = "never"
            end
            table.insert(data.run, {"download", repo, src, real_dst})
            goto continue
        end
        local results = repo:list(src, real_dst .. "/")
        local function iter(result, path)
            for name, real_dst in pairs(result) do
                if type(real_dst) == "table" then
                    iter(real_dst, path .. "/" .. name)
                    goto continue
                end
                local dst_dir = fs.canonical(fs.path(real_dst))
                if not fs.exists(dst_dir) and not dirs_added[dst_dir] then
                    table.insert(dirs, dst_dir)
                    dirs_added[dst_dir] = true
                    table.insert(data.run, {"mkdir", dst_dir})
                end
                table.insert(files, real_dst)
                table.insert(data.run, {"download", repo, path .. "/" .. name, real_dst})
                ::continue::
            end
        end
        iter(results, src)
        ::continue::
    end

    for id, dir in ipairs(dirs) do
        if dirs_added[dir] == "never" then
            table.remove(dirs, id)
        end
    end

    if package.configure then
        table.insert(data.after, {"configure", target .. "/" .. package.configure})
    end

    table.insert(data.after, {"register", id, target, {
        auto_installed = auto_installed or false,
        install_files = files,
        install_dirs = dirs,
    }})
    return data
end

function M.prepare_remove(id)
    if not is_installed(id) then
        io.stderr:write("Error: package " .. id .. " not installed\n")
        return {
            type = "remove", before = {}, run = {}, after = {},
            errors = {"Package not installed: " .. id}
        }
    end
    local data = {
        type = "remove",
        before = {},
        run = {},
        after = {}
    }
    local installed = load_installed_file(id)
    if installed.remove then
        table.insert(data.run, {"remove", installed.remove})
    end

    for dep, path in pairs(installed.dependencies or {}) do
        table.insert(data.before, {"remove_used", dep, id})
    end

    for _, file in ipairs(installed.install_files) do
        table.insert(data.run, {"rm", file})
    end
    for _, dir in ipairs(installed.install_dirs) do
        table.insert(data.run, {"rmdir", dir})
    end
    table.insert(data.after, {"unregister", id})
    return data
end

function M.prepare_upgrade(id)
    local installed = load_installed_file(id)
    if not installed then
        io.stderr:write("Error: package " .. id .. " not installed\n")
        return {
            type = "upgrade", before = {}, run = {}, after = {},
            errors = {"Package not installed: " .. id}
        }
    end
    local data = {
        type = "upgrade",
        before = {
            { "execute", "remove", M.prepare_remove(id) },
        },
        run = {
            { "execute", "install", M.prepare_install(id, installed.install_path) },
        },
        after = {}
    }
    return data
end

local execution = {
    execute = function(...)
        local packed = table.pack(...)
        local last = table.remove(packed, #packed)
        io.write(table.concat(packed, " ") .. " -> Execute: " .. last.type .. "\n")
        M.execute(last)
    end,
    add_used = function(id, package)
        io.write("Add used: " .. id .. " <- " .. package .. "\n")
        local data = load_installed_file(id)
        data.used[package] = true
        save_installed_file(id, data)
    end,
    remove_used = function(id, package)
        io.write("Remove used: " .. id .. " <- " .. package .. "\n")
        local data = load_installed_file(id)
        data.used[package] = nil
        save_installed_file(id, data)
    end,
    skip = function(src, dst) end,
    mkdir = function(dst)
        io.write("Make directory: " .. dst .. "\n")
        fs.makeDirectory(dst)
    end,
    download = function(repo, src, dst)
        io.write("Download: " .. src .. " -> " .. dst .. "\n")
        repo:download(src, dst)
    end,
    rm = function(path)
        io.write("Remove: " .. path .. "\n")
        fs.remove(path)
    end,
    rmdir = function(path)
        io.write("Remove directory: " .. path .. "\n")
        ipm.util.rmdir(path)
    end,
    configure = function(path)
        io.write("Configure script: " .. path .. "\n")
        dofile(path)
    end,
    remove = function(path)
        io.write("Remove script: " .. path .. "\n")
        dofile(path)
    end,
    register = function(id, path, options)
        io.write("Register: " .. id .. " -> " .. path .. "\n")
        local data = load_package_file(id)
        data.used = {}
        data.install_path = path
        for k, v in pairs(options) do
            data[k] = v
        end
        save_installed_file(id, data)
    end,
    unregister = function(id)
        io.write("Unregister: " .. id .. "\n")
        os.remove(data_installed_base .. "/" .. id .. ".cfg")
    end
}

local function execute_line(line)
    local type = table.remove(line, 1)
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

local execute_stack = 0

function M.execute(data)
    local total_lines = #data.before + #data.run + #data.after
    local current_line = 0

    local offset_y = execute_stack
    execute_stack = execute_stack - 1

    local function update_progress()
        if execute_stack <= -2 then
            return
        end
        current_line = current_line + 1
        ipm.tui.progress(offset_y, "", current_line / total_lines)
    end
    ipm.tui.progress(offset_y, "", 0)
    for _, task in ipairs(data.before) do
        update_progress()
        execute_line(task)
    end
    for _, task in ipairs(data.run) do
        update_progress()
        execute_line(task)
    end
    for _, task in ipairs(data.after) do
        update_progress()
        execute_line(task)
    end
    ipm.tui.text(offset_y, "")
    execute_stack = execute_stack + 1
end

return M