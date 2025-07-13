local shell = require("shell")
local ipm = loadfile("/usr/lib/ipm/init.lua")()

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
    ipm list [-i] [id-filter] - List all packages, you can pipe it to `less`.
    ipm info <id> - Show information about a package.
    ipm search <filter...> - Search for packages.
    ipm install <id> - Install a package.
    ipm files <id> - List files in a installed package.
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
        io.write(ipm.format.package(package))
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
        io.write(ipm.format.package(installed, true))
    end
    return
end
if args[1] == "search" then
    table.remove(args, 1)
    local pattern = table.concat(args, " "):lower()
    local replaced_pattern = "\x1b[31m" .. pattern .. "\x1b[0m"
    for _, package in ipairs(ipm.package.package_list()) do
        local info = ipm.format.package(package, false):lower()
        local replaced = info:gsub(pattern, replaced_pattern)
        if info ~= replaced then
            io.write(replaced .. "\n")
        end
    end
    return
end
