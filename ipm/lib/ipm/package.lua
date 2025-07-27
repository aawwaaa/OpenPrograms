local fs = require("filesystem")

local ipm = ...

local M = {}

local data_package_base = ipm.install_base and ipm.install_base .. "/.ipm_packages"
    or "/usr/share/ipm/package"
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

M.load_package_file = load_package_file
M.has_package_file = has_package_file
M.load_installed_file = load_installed_file
M.save_installed_file = save_installed_file
M.is_installed = is_installed

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

local function solve_dependencies(options, deps)
    local package = options.package
    local target = options.target
    local data = options.data
    local install = options.install
    local force = options.force
    local check = options.check
    local add_used = options.add_used
    if add_used == nil then
        add_used = true
    end
    for dep, path in pairs(package.dependencies or {}) do
        if path:sub(1, 2) == "//" then
            path = path:sub(2)
        else
            path = fs.canonical(target .. "/" .. path:gsub("^/", ""))
        end
        local optional = dep:sub(1, 1) == "?"
        dep = dep:lower():gsub("^%?", "")
        if deps[dep] then
            if add_used then
                table.insert(data.before, {"add_used", dep, package.id})
            end
            goto continue
        end
        deps[dep] = true
        if not check(dep) then
            if optional then
                io.write("Install optional dependency: " .. dep .. " -> " .. path .. "? [y/N] ")
                if io.read("*l"):lower() ~= "y" then
                    goto continue
                end
            end
            local dep_data = install({
                id = dep,
                target = path,
                auto_installed = true,
                force = force,
                check = check,
                add_used = add_used,
            }, deps)
            table.insert(data.before, {"execute", dep, dep_data})
            if not dep_data then
                table.insert(data.errors, "Dependency not satisfied: " .. dep)
            end
        end
        if add_used then
            table.insert(data.before, {"add_used", dep, package.id})
        end
        ::continue::
    end
end
local function solve_files(options)
    local target = options.target
    local data = options.data
    local repo = options.repo
    local noskip = options.noskip
    local dirs = {}
    local dirs_added = {}
    local files = {}
    data.repo = repo.repo_str
    for src, dst in pairs(options.files) do
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
        if options.noabsolute and dst:sub(1, 2) == "//" then
            real_dst = target .. dst:sub(2)
        end
        if real_dst:sub(-1) == "!" then
            real_dst = real_dst:sub(1, -2)
        elseif not dir then
            real_dst = real_dst .. "/" .. fs.name(src)
        end
        real_dst = fs.canonical(real_dst)
        if optional and fs.exists(real_dst) and not noskip then
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
            table.insert(data.run, {"fetch", src, real_dst})
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
                table.insert(data.run, {"fetch", path .. "/" .. name, real_dst})
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

    return files, dirs
end

function M.prepare_install(options, deps)
    local id = options.id:lower()
    if deps == nil then
        deps = {}
    end
    deps[id] = true
    local force = options.force
    local auto_installed = options.auto_installed
    local target = options.target
    if is_installed(id) and not force then
        io.stderr:write("Error: package " .. id .. " already installed\n")
        return {
            errors = {"Package already installed: " .. id}
        }
    end
    local package = load_package_file(id)
    if not package then
        io.stderr:write("Error: package " .. id .. " not found\n")
        return {
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
    solve_dependencies({
        package = package,
        target = target,
        data = data,
        install = M.prepare_install,
        force = force,
        check = is_installed,
        add_used = options.add_used,
    }, deps)

    io.write("Prepare install: " .. id .. " -> " .. target .. "\n")
    local repo = ipm.repo.repo(package.repo)
    if not repo then
        table.insert(data.errors, "Repo error: " .. package.repo)
        return data -- error message already printed
    end

    local files, dirs = solve_files({
        repo = repo,
        target = target,
        data = data,
        files = package.files,
    })

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

function M.prepare_mkinst(options, deps)
    local id = options.id:lower()
    if deps == nil then
        deps = {}
    end
    deps[id] = true
    local target = options.target
    local package = load_package_file(id)
    if not package then
        io.stderr:write("Error: package " .. id .. " not found\n")
        return {
            errors = {"Package not found: " .. id}
        }
    end
    local data = {
        type = "mkinst",
        before = {},
        run = {},
        after = {}
    }
    data.package = package
    data.errors = {}
    solve_dependencies({
        package = package,
        target = target,
        data = data,
        install = M.prepare_mkinst,
        force = true,
        check = function(id) return fs.exists(target .. "/.ipm_packages/" .. id .. ".cfg") end,
        add_used = false,
    }, deps)

    io.write("Prepare mkinst: " .. id .. " -> " .. target .. "\n")
    local repo = ipm.repo.repo(package.repo)
    if not repo then
        table.insert(data.errors, "Repo error: " .. package.repo)
        return data -- error message already printed
    end

    solve_files({
        repo = repo,
        target = target,
        data = data,
        files = package.files,
        noskip = true,
        noabsolute = true,
    })

    table.insert(data.after, {"mkinst", id, target, options.auto_installed or false})
    return data
end

function M.prepare_remove(id)
    id = id:lower()
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
        dep = dep:lower():gsub("^%?", "")
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
    id = id:lower()
    local installed = load_installed_file(id)
    if not installed then
        io.stderr:write("Error: package " .. id .. " not installed\n")
        return {
            errors = {"Package not installed: " .. id}
        }
    end
    local data = {
        type = "upgrade",
        before = {
            { "execute", "remove", M.prepare_remove(id) },
        },
        run = {
            { "execute", "install", M.prepare_install(id, installed.install_path, false, true) },
        },
        after = {}
    }
    return data
end

return M