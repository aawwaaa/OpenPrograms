local base = _ENV.install.from
base = base:sub(1, -2)

local ipm = loadfile(base .. "/.ipm/init.lua")(base)

local packages = ipm.package.package_list()

io.write("Packages: \n")
for index, package in ipairs(packages) do
    io.write("  - [" .. index .. "] " .. package.name .. " [" .. package.id .. "]" ..
        (package.installed and ", Installed" or "") ..
        (package.auto_installed and ", Auto Included" or "") .. "\n" ..
        "    " .. (package.description or "No description") .. "\n")
end
local index = nil
if #packages > 1 then
    io.write("Which package to install? [number/all] ")
    local answer = io.read()
    index = answer and tonumber(answer) or nil
end

local function install(package)
    local data;
    if not _ENV.install.update then
        data = ipm.package.prepare_install({
            id = package.id,
            target = _ENV.install.to:sub(1, -2),
            auto_installed = false,
            force = false,
        })
    else
        data = ipm.package.prepare_upgrade(package.id)
    end
    io.write("Install: " .. package.id .. "\n")
    ipm.tui.paged(ipm.format.execute_data(data))
    if ipm.execute.has_error(data) then
        io.stderr:write("Error: execute data has error\n")
        return
    end
    io.write("Continue? [y/N]")
    local answer = io.read()
    if answer ~= "y" then
        return
    end
    ipm.execute.execute(data)
end

if not index then
    for _, package in ipairs(packages) do
        install(package)
    end
else
    install(packages[index])
end