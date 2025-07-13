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

function M.install(id)
    if not has_package_file(id) then
        io.stderr:write("Error: package " .. id .. " not found\n")
        return
    end
    if is_installed(id) then
        io.stderr:write("Error: package " .. id .. " already installed\n")
        return
    end
    local package = load_package_file(id)
    if not package then
        io.stderr:write("Error: package " .. id .. " not found\n")
        return
    end
    local repo = ipm.repo.repo(package.repo)
    if not repo then
        return
    end
    for src, dst in pairs(package.files) do
    end
end

return M