local M = {}

function M.source(source, detailed)
    local output = ""
    output = output .. source.name .. " [" .. source.id .. "| " .. source.type .. "]\n"
    if source.description then
        output = output .. "  " .. source.description .. "\n"
    end
    if detailed then
        output = output .. "  Source: " .. source.source .. "\n"
        output = output .. "  Priority: " .. source.priority .. "\n"
        output = output .. "  Content:\n"
        for _, content in ipairs(source.data) do
            output = output .. "  - " .. content[1] .. " " .. content[2] .. "\n"
        end
    end
    return output
end

function M.package(package, detailed, locals)
    local output = ""
    output = output .. tostring(package.name) .. " [" .. tostring(package.id) .. "]" .. (package.installed and ", Installed" or "") .. (package.hidden and ", Hidden" or "")
        .. (package.auto_installed and ", Auto Installed" or "") .. (package.auto_installed and not next(package.used) and ", Removeable" or "") .. "\n"
    if package.description then
        output = output .. "  " .. package.description .. "\n"
    end
    if detailed then
        if package.note and not locals then
            output = output .. "  Note: \n" .. package.note .. "\n"
        end
        output = output .. "  Source: " .. package.source .. "\n"
        if not locals then
            if package.authors then
                output = output .. "  Authors: " .. package.authors .. "\n"
            end
            output = output .. "  Repo: " .. package.repo .. "\n"
        end
        if package.dependencies and next(package.dependencies) then
            output = output .. "  Dependencies:\n"
            for dependency, path in pairs(package.dependencies) do
                output = output .. "  - " .. dependency .. " -> " .. path .. "\n"
            end
        end
        if package.used and next(package.used) then
            output = output .. "  Used:\n"
            for used, _ in pairs(package.used) do
                output = output .. "  - " .. used .. "\n"
            end
        end
        if package.install_path then
            output = output .. "  Install Path: " .. package.install_path .. "\n"
        end
        if package.install_dirs and next(package.install_dirs) then
            output = output .. "  Install Dirs:\n"
            for _, dir in ipairs(package.install_dirs) do
                output = output .. "  - " .. dir .. "\n"
            end
        end
        if package.install_files and next(package.install_files) then
            output = output .. "  Install Files:\n"
            for _, dir in ipairs(package.install_files) do
                output = output .. "  - " .. dir .. "\n"
            end
        else
            output = output .. "  Files:\n"
            for src, dst in pairs(package.files) do
                output = output .. "  - " .. src .. " -> " .. dst .. "\n"
            end
        end
    end
    return output
end

local execution = {
    execute = function(tab, ...)
        local packed = table.pack(...)
        local last = table.remove(packed, #packed)
        if type(last) == "table" then
            return tab .. " - " .. table.concat(packed, " ") .. " -> " .. M.execute_data(last, tab .. " ")
        end
        return tab .. " - " .. table.concat(packed, " ") .. " Failed to generate execute data"
    end,
    add_used = function(tab, id, package)
        local output = ""
        output = output .. tab .. " - Add used: " .. id .. " <- " .. package .. "\n"
        return output
    end,
    remove_used = function(tab, id, package)
        local output = ""
        output = output .. tab .. " - Remove used: " .. id .. " <- " .. package .. "\n"
        return output
    end,
    skip = function(tab, src, dst)
        local output = ""
        output = output .. tab .. " - Skip: " .. src .. " -> " .. dst .. "\n"
        return output
    end,
    mkdir = function(tab, dst)
        local output = ""
        output = output .. tab .. " - Make directory: " .. dst .. "\n"
        return output
    end,
    fetch = function(tab, src, dst)
        local output = ""
        output = output .. tab .. " - Fetch: " .. tostring(src) .. " -> " .. tostring(dst) .. "\n"
        return output
    end,
    rm = function(tab, path)
        local output = ""
        output = output .. tab .. " - Remove: " .. tostring(path) .. "\n"
        return output
    end,
    rmdir = function(tab, path)
        local output = ""
        output = output .. tab .. " - Remove directory: " .. tostring(path) .. "\n"
        return output
    end,
    configure = function(tab, path)
        local output = ""
        output = output .. tab .. " - Configure script: " .. tostring(path) .. "\n"
        return output
    end,
    remove = function(tab, path)
        local output = ""
        output = output .. tab .. " - Remove script: " .. tostring(path) .. "\n"
        return output
    end,
    register = function(tab, id, path)
        local output = ""
        output = output .. tab .. " - Register: " .. id .. " -> " .. path .. "\n"
        return output
    end,
    unregister = function(tab, id)
        local output = ""
        output = output .. tab .. " - Unregister: " .. id .. "\n"
        return output
    end,
    mkinst = function(tab, id, path)
        local output = ""
        output = output .. tab .. " - Make install disk: " .. id .. " -> " .. path .. "\n"
        return output
    end,
}

local function execution_line(tab, line)
    local value = execution[line[1]](tab, table.unpack(line, 2))
    return value
end

function M.execute_data(data, tab)
    if not tab then
        tab = ""
    end
    local output = ""
    output = output .. "Execution: " .. data.type .. "\n"
    if next(data.before or {}) then
        output = output .. tab .. " Before:\n"
        for _, task in ipairs(data.before) do
            output = output .. execution_line(tab, task)
        end
    end
    if data.repo then
        output = output .. tab .. " Repo: " .. data.repo .. "\n"
    end
    if next(data.run or {}) then
        output = output .. tab .. " Run:\n"
        for _, task in ipairs(data.run) do
            output = output .. execution_line(tab, task)
        end
    end
    if next(data.after or {}) then
        output = output .. tab .. " After:\n"
        for _, task in ipairs(data.after) do
            output = output .. execution_line(tab, task)
        end
    end
    if next(data.errors or {}) then
        output = output .. tab .. " Errors:\n"
        for _, error in ipairs(data.errors) do
            output = output .. tab .. "  - \x1b[31m" .. error .. "\x1b[0m\n"
        end
    end
    return output
end

return M