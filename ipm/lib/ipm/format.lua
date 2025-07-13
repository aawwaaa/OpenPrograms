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
    output = output .. package.name .. " [" .. package.id .. "]" .. (package.installed and ", Installed" or "") .. "\n"
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

return M