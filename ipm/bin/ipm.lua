local shell = require("shell")
local ipm = loadfile("/usr/lib/ipm/init.lua")()

local config = ipm.util.load_file("/etc/ipm/config.cfg")

local internet = ipm.internet.get_internet()

if not internet then
    io.stderr:write("No internet card found\n")
    return
end

local args, options = shell.parse(...)

local function printUsage()
    print([[
Improved Package Manager
Usage:
  Package:
    ipm list [-ia] [id-filter] - List all packages, you can pipe it to `less`.
    ipm info <id> - Show information about a package.
    ipm search <filter...> - Search for packages.
    ipm install [--path=<path>] <id> - Install a package.
    ipm which <file> - Show which package contains a file.
    ipm upgrade <id> - Upgrade a package.
    ipm upgrade all - Upgrade all packages.
    ipm remove <id> - Remove a package.
    ipm remove auto - Remove unused packages.
  Source:
    ipm update - Update all sources.
    ipm clear - Clear cache.
    ipm source list - List all sources.
    ipm source info <id> [type] - Show information about a source.
]])
end

if #args == 0 or options.h or options.help then
    printUsage()
    return
end

local function source(args, options)
    if #args == 0 then
        printUsage()
        return
    end
    if args[1] == "list" then
        local repos, packages = ipm.source.source_list()
        io.write("Repository sources:\n\n")
        for _, repo in ipairs(repos) do
            io.write(ipm.format.source(repo))
        end
        io.write("\nPackages sources:\n\n")
        for _, package in ipairs(packages) do
            io.write(ipm.format.source(package))
        end
        return
    end
    if args[1] == "info" then
        local source = ipm.source.source_info(args[2], args[3])
        if source then
            io.write(ipm.format.source(source, true))
        else
            io.stderr:write("Source not found\n")
        end
        return
    end
end

if args[1] == "clear" then
    ipm.source.clear_data()
    return
end
if args[1] == "update" then
    ipm.source.clear_data()
    ipm.source.load_sources()
    ipm.source.resolve_sources()
    return
end
if args[1] == "source" then
    table.remove(args, 1)
    source(args, options)
    return
end

if args[1] == "list" then
    local packages = (options.i or options.installed)
        and ipm.package.package_list_installed()
        or ipm.package.package_list()
    for _, package in ipairs(packages) do
        if package.hidden and not (options.a or options.all) then
            goto continue
        end
        io.write(ipm.format.package(package))
        ::continue::
    end
    return
end
if args[1] == "info" then
    local package, installed = ipm.package.package_info(args[2])
    if package then
        io.write("Package in " .. package.source .. ":\n\n")
        io.write(ipm.format.package(package, true))
    end
    if installed then
        io.write("\nPackage installed:\n\n")
        io.write(ipm.format.package(installed, true, true))
    end
    return
end
if args[1] == "search" then
    table.remove(args, 1)
    local pattern = table.concat(args, " "):lower()
    local replaced_pattern = "\x1b[31m" .. pattern .. "\x1b[0m"
    for _, package in ipairs(ipm.package.package_list()) do
        if package.hidden and not (options.a or options.all) then
            goto continue
        end
        local info = ipm.format.package(package, false):lower()
        local replaced = info:gsub(pattern, replaced_pattern)
        if info ~= replaced then
            io.write(replaced .. "\n")
        end
        ::continue::
    end
    return
end
if args[1] == "install" then
    local path = options.path or config.default_install_path
    table.remove(args, 1)
    for _, id in ipairs(args) do
        local data = ipm.package.prepare_install(id, path, false, options.f or options.force)
        io.write("Install: " .. id .. "\n")
        ipm.tui.paged(ipm.format.execute_data(data))
        if ipm.package.has_error(data) then
            io.stderr:write("Error: execute data has error\n")
            return
        end
        if not options.y and not options.yes then
            io.write("Continue? [y/N]")
            local answer = io.read()
            if answer ~= "y" then
                return
            end
        end
        ipm.package.execute(data)
    end
    return
end
if args[1] == "which" then
    local lua = shell.resolve(args[2], "lua")
    local file = lua or shell.resolve(args[2])
    if not file then
        io.stderr:write("File not found\n")
        return
    end
    local packages = ipm.package.package_list_installed()
    for _, package in ipairs(packages) do
        local result = {}
        for _, dst in pairs(package.install_files) do
            if dst:sub(1, #file) == file then
                table.insert(result, dst)
            end
        end
        for _, dst in pairs(package.install_dirs) do
            if dst:sub(1, #file) == file then
                table.insert(result, dst)
            end
        end
        if #result > 0 then
            io.write(package.id .. ":\n")
            for _, r in ipairs(result) do
                io.write("  " .. r .. "\n")
            end
        end
    end
end
if args[1] == "upgrade" then
    table.remove(args, 1)
    if args[1] == "all" then
        local packages = ipm.package.package_list_installed()
        local ids = {}
        for _, package in ipairs(packages) do
            table.insert(ids, package.id)
        end
        args = ids
        io.write("Will upgrade: " .. table.concat(args, ", ") .. "\n")
        if not options.y and not options.yes then
            io.write("Continue? [y/N]")
            local answer = io.read()
            if answer ~= "y" then
                return
            end
        end
    end
    for _, id in ipairs(args) do
        local data = ipm.package.prepare_upgrade(id)
        io.write("Upgrade: " .. id .. "\n")
        ipm.tui.paged(ipm.format.execute_data(data))
        if ipm.package.has_error(data) then
            io.stderr:write("Error: execute data has error\n")
            return
        end
        if not options.y and not options.yes then
            io.write("Continue? [y/N]")
            local answer = io.read()
            if answer ~= "y" then
                return
            end
        end
        ipm.package.execute(data)
    end
    return
end
if args[1] == "remove" then
    table.remove(args, 1)
    if args[1] == "auto" then
        local packages = ipm.package.package_list_installed()
        local ids = {}
        for _, package in ipairs(packages) do
            if not next(package.used) and package.auto_installed then
                table.insert(ids, package.id)
            end
        end
        args = ids
        io.write("Will remove: " .. table.concat(args, ", ") .. "\n")
        if not options.y and not options.yes then
            io.write("Continue? [y/N]")
            local answer = io.read()
            if answer ~= "y" then
                return
            end
        end
    end
    for _, id in ipairs(args) do
        local data = ipm.package.prepare_remove(id)
        io.write("Remove: " .. id .. "\n")
        ipm.tui.paged(ipm.format.execute_data(data))
        if ipm.package.has_error(data) then
            io.stderr:write("Error: execute data has error\n")
            return
        end
        if not options.y and not options.yes then
            io.write("Continue? [y/N]")
            local answer = io.read()
            if answer ~= "y" then
                return
            end
        end
        ipm.package.execute(data)
    end
    return
end