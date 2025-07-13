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

function M.package(package, detailed)
    local output = ""
    output = output .. package.name .. " [" .. package.id .. "]" .. (package.installed and ", Installed" or "") .. (package.hidden and ", Hidden" or "") .. "\n"
    if package.description then
        output = output .. "  " .. package.description .. "\n"
    end
    if detailed then
        output = output .. "  Source: " .. package.source .. "\n"
        if package.authors then
            output = output .. "  Authors: " .. package.authors .. "\n"
        end
        output = output .. "  Repo: " .. package.repo .. "\n"
        if package.dependencies and next(package.dependencies) then
            output = output .. "  Dependencies:\n"
            for _, dependency in ipairs(package.dependencies) do
                output = output .. "  - " .. dependency[1] .. "\n"
            end
        end
        output = output .. "  Files:\n"
        for src, dst in pairs(package.files) do
            output = output .. "  - " .. src .. " -> " .. dst .. "\n"
        end
    end
    return output
end

local execution = {
    execute = function(tab, ...)
        local packed = table.pack(...)
        local last = table.remove(packed, #packed)
        local output = ""
        output = output .. tab .. " - " .. table.concat(packed, " ") .. "\n"
        if type(last) == "table" then
            output = output .. M.execute_data(last, tab .. " ")
        end
        return output
    end,
    add_dependency = function(tab, id, package)
        local output = ""
        output = output .. tab .. " - Add dependency: " .. id .. " <- " .. package .. "\n"
        return output
    end,
    remove_dependency = function(tab, id, package)
        local output = ""
        output = output .. tab .. " - Remove dependency: " .. id .. " <- " .. package .. "\n"
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
    download = function(tab, src, dst)
        local output = ""
        output = output .. tab .. " - Download: " .. src .. " -> " .. dst .. "\n"
        return output
    end,
    rm = function(tab, path)
        local output = ""
        output = output .. tab .. " - Remove: " .. path .. "\n"
        return output
    end,
    rmdir = function(tab, path)
        local output = ""
        output = output .. tab .. " - Remove directory: " .. path .. "\n"
        return output
    end,
    configure = function(tab, path)
        local output = ""
        output = output .. tab .. " - Configure: " .. path .. "\n"
        return output
    end
}

local function execution_line(tab, line)
    local type = table.remove(line, 1)
    return execution[type](tab, table.unpack(line))
end

function M.execute_data(data, tab)
    if not tab then
        tab = ""
    end
    local output = ""
    output = output .. tab .. "Execution: " .. data.type .. "\n"
    if next(data.before) then
        output = output .. tab .. " Before:\n"
        for _, task in ipairs(data.before) do
            output = output .. execution_line(tab, task)
        end
    end
    if data.repo then
        output = output .. tab .. " Repo: " .. data.repo.repo_str .. "\n"
    end
    if next(data.run) then
        output = output .. tab .. " Run:\n"
        for _, task in ipairs(data.run) do
            output = output .. execution_line(tab, task)
        end
    end
    if next(data.after) then
        output = output .. tab .. " After:\n"
        for _, task in ipairs(data.after) do
            output = output .. execution_line(tab, task)
        end
    end
    if next(data.errors) then
        output = output .. tab .. " Errors:\n"
        for _, error in ipairs(data.errors) do
            output = output .. tab .. "  - \x1b[31m" .. error .. "\x1b[0m\n"
        end
    end
    return output
end

return M