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
    return fs.exists(data_package_base .. "/" .. id .. ".cfg")
end
local load_installed_file = ipm.util.cherry_base_path(ipm.util.load_file, data_installed_base)
local function is_installed(id)
    return fs.exists(data_installed_base .. "/" .. id .. ".cfg")
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

function M.prepare_install(id, target)
    if not has_package_file(id) then
        io.stderr:write("Error: package " .. id .. " not found\n")
        return {
            errors = {"Package not found: " .. id}
        }
    end
    if is_installed(id) then
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
    for dep, path in pairs(package.installs) do
        if not is_installed(dep) then
            local dep_data = M.prepare_install(dep, path)
            table.insert(data.before, {"execute", dep, dep_data})
            if not dep_data then
                table.insert(data.errors, "Dependency not satisfied: " .. dep)
            end
        else
            table.insert(data.before, {"add_dependency", dep, id})
        end
    end
    io.write("Prepare install: " .. id .. " -> " .. target .. "\n")
    local repo = ipm.repo.repo(package.repo)
    if not repo then
        table.insert(data.errors, "Repo error: " .. package.repo)
        return data -- error message already printed
    end

    data.repo = repo
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
        if optional and fs.exists(real_dst) then
            io.write("Skipping optional file: " .. src .. " -> " .. real_dst .. "\n")
            table.insert(data.run, {"skip", src, real_dst})
            goto continue
        end
        if dir and not fs.exists(real_dst) then
            table.insert(data.run, {"mkdir", real_dst})
        end
        if not dir then
            table.insert(data.run, {"download", src, real_dst})
            goto continue
        end
        local results = repo:list(src, real_dst .. "/")
        local function iter(result, path)
            for name, real_dst in pairs(result) do
                if type(real_dst) == "table" then
                    iter(real_dst, path .. "/" .. name)
                    goto continue
                end
                table.insert(data.run, {"download", path .. "/" .. name, real_dst})
                ::continue::
            end
        end
        iter(results, src)
        ::continue::
    end

    if package.configure then
        table.insert(data.after, {"configure", target .. "/" .. package.configure})
    end
    return data
end

local execution = {}

function M.execute(data)
end

return M