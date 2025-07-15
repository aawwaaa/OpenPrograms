local fs = require("filesystem")
local serialization = require("serialization")

local ipm = ...

local M = {}

local sources_file = "/etc/ipm/sources.list.cfg"
M.source_file = sources_file
local sources_base = "/etc/ipm/sources.list.d"
M.source_base = sources_base

local data_source_base = "/usr/share/ipm/source"
local data_repo_base = ipm.repo.data_repo_base
local data_package_base = ipm.package.data_package_base

ipm.util.mkdirp(data_source_base)

local loading = {}
local loaded = {}

local source_inc_id = 1

local function load_oppm_source_data(data, source_data)
    local recursive = source_data.recursive
    local priority = source_data.priority
    local source_str = source_data.source_str
    local source_repo = source_data.source.source_repo or nil

    local output = {}
    for key, source in pairs(data) do
        source.source = source_str
        if source_repo or source.files then
            source.type = "package"
            source.id = key
            source.repo = source_repo or source.repo or "unknown"
            table.insert(loading, source)
            table.insert(output, { "package", key })
        elseif source.programs then
            local package_source = {
                type = "packages",
                id = tostring(source_inc_id),
                name = key,
                data = source.programs,
                priority = priority,
                recursive = recursive - 1,
                source = source_str,
                source_repo = "unknown",
            }
            source_inc_id = source_inc_id + 1
            table.insert(loading, package_source)
            table.insert(output, { "programs", key })
        elseif source.repo then
            local package_source = {
                type = "packages",
                id = tostring(source_inc_id),
                name = key,
                url = "https://raw.githubusercontent.com/" .. source.repo .. "/master/programs.cfg",
                source_repo = "github:" .. source.repo,
                priority = priority,
                recursive = recursive - 1,
                source = source_str,
            }
            source_inc_id = source_inc_id + 1
            table.insert(loading, package_source)
            table.insert(output, { "packages", key })
        end
    end
    return output
end

local function load_ipm_source_data(data, source_data)
    local recursive = source_data.recursive
    local priority = source_data.priority
    local source_str = source_data.source_str

    local output = {}
    for key, source in pairs(data) do
        if source.enabled == false then
            goto continue
        end
        source.source = source_str
        if recursive >= 2 and source.type == "repos" then
            source.priority = source.priority or priority
            source.recursive = source.recursive == nil and (recursive - 1)
                or (source.recursive == true and 2
                    or (source.recursive == false and 1
                    or source.recursive)
                )
            table.insert(output, { "repos", source.id })
            table.insert(loading, source)
        elseif source.type == "repo" then
            table.insert(output, { "repo", source.id })
            table.insert(loading, source)
        elseif recursive >= 1 and source.type == "packages" then
            source.priority = source.priority or priority
            source.recursive = source.recursive == nil and (recursive - 1)
                or (source.recursive == true and 1
                    or (source.recursive == false and 0
                    or source.recursive)
                )
            table.insert(output, { "packages", source.id })
            table.insert(loading, source)
        elseif source.type == "package" then
            if source.priority == nil then
                source.priority = priority
            end
            table.insert(output, { "package", source.id })
            table.insert(loading, source)
        end
        ::continue::
    end
    return output
end

local function load_hel_source_data(data, source_data)
    local output = source_data.data or {}
    source_data.data = nil
    local n = data.offset + data.sent
    local cont = data.offset < data.total
    source_data.source.offset = n
    source_data.source.url = source_data.source.url:gsub("(%?offset=%d+)?", "") .. "?offset=" .. n
    for _, package in ipairs(data.list) do
        local id = package.name
        local latest = package.versions[next(package.versions)]
        local files = {}
        for src, obj in pairs(latest.files) do
            files[src] = "/" .. obj.path .. "!"
        end
        local dependencies = {}
        for id, obj in pairs(latest.depends) do
            dependencies[(obj.type == "optional" and "?" or "") .. id] = "/"
        end
        local object = {
            type = "package",
            id = id,
            name = id,
            description = package.short_description,
            note = package.description,
            repo = "url:",
            priority = source_data.priority,
            recursive = source_data.recursive - 1,
            source = source_data.source_str,
            authors = table.concat(package.authors, "\n"),

            files = files,
            dependencies = dependencies
        }
        table.insert(output, { "package", id })
        table.insert(loading, object)
    end
    if cont then
        table.insert(loading, source_data.source)
    end
    return output
end

local function load_source_data(data, source_data)
    source_data.recursive = source_data.recursive or 0
    source_data.priority = source_data.priority or 0
    source_data.source_str = source_data.source_str or "unknown"
    if data.data then
        return load_hel_source_data(data.data, source_data)
    end
    if type(next(data)) == "string" then
        return load_oppm_source_data(data, source_data)
    end
    return load_ipm_source_data(data, source_data)
end

local function load_source(path)
    io.write("Load: " .. path .. "\n")
    local data = ipm.util.load_file(path)
    load_source_data(data, {
        priority = 0,
        recursive = 2,
        source_str = path,
    })
end


function M.clear_data()
    io.write("Clear: " .. data_source_base .. "\n")
    ipm.util.rmdir(data_source_base)
    io.write("Clear: " .. data_repo_base .. "\n")
    ipm.util.rmdir(data_repo_base)
    io.write("Clear: " .. data_package_base .. "\n")
    ipm.util.rmdir(data_package_base)
end
function M.load_sources(file)
    load_source(sources_file)
    if not file then
        ipm.util.each_file(sources_base, "%.cfg$", load_source)
    else
        load_source(sources_base .. "/" .. file .. ".cfg")
    end
end

local function save(base, name, data)
    ipm.util.save_file(base .. "/" .. name .. ".cfg", data)
end

local function resolve_repo(source)
    save(data_repo_base, source.id, source)
end

local parsers = {
    json = ipm.json.decode,
    cfg = serialization.unserialize,
}
local function resolve_repos(source)
    if source.url then
        io.write("Fetch: " .. source.type .. " " .. source.id .. ": " .. source.url .. "\n")
        local data = ipm.internet.fetch(source.url)
        if not data then
            io.stderr:write("Error: " .. source.type .. " " .. source.id .. " fetch failed\n")
            return
        end
        local data, err = parsers[source.url_response or "cfg"](data)
        if not data then
            io.stderr:write("Error: " .. source.type .. " " .. source.id .. " parse failed: " .. tostring(err) .. "\n")
            return
        end
        source.data = data
    else
        io.write("Hit: " .. source.type .. " " .. source.id .. "\n")
    end
    if not source.data then
        io.stderr:write("Error: " .. source.type .. " " .. source.id .. " no data\n")
        return
    end
    source.data = load_source_data(source.data, {
        priority = source.priority or 0,
        recursive = source.recursive or (source.type == "repos" and 1 or 0),
        source_str = (source.name or "") .. " [" .. source.id .. "| " .. source.type .. "]",
        source = source,
    })
    save(data_source_base, source.type .. "--" .. source.id, source)
end
local function resolve_package(source)
    save(data_package_base, source.id, source)
end

function M.resolve_sources()
    loaded = {}
    while #loading > 0 do
        local source = table.remove(loading, 1)
        if loaded[source.type .. "--" .. source.id] then
            goto continue
        end
        loaded[source.type .. "--" .. source.id] = true
        if source.type == "repo" then
            resolve_repo(source)
        elseif source.type == "repos" or source.type == "packages" then
            resolve_repos(source)
        elseif source.type == "package" then
            resolve_package(source)
        end
        ::continue::
    end
end

local load_source_file = ipm.util.cherry_base_path(ipm.util.load_file, data_source_base)

function M.source_list()
    io.write("List: " .. data_source_base .. "\n")
    local iter, err = fs.list(data_source_base)
    if not iter then
        io.stderr:write("Error: " .. data_source_base .. " list failed: " .. tostring(err) .. "\n")
        return
    end
    local output_repos = {}
    local output_packages = {}
    for file in iter do
        if file:match("%.cfg$") then
            local data = load_source_file(file)
            if data then
                if data.type == "repos" then
                    table.insert(output_repos, data)
                elseif data.type == "packages" then
                    table.insert(output_packages, data)
                end
            end
        end
    end
    table.sort(output_repos, function(a, b)
        return string.lower(a.name or a.id) < string.lower(b.name or b.id)
    end)
    table.sort(output_packages, function(a, b)
        return string.lower(a.name or a.id) < string.lower(b.name or b.id)
    end)
    return output_repos, output_packages
end

function M.source_info(id, type)
    if type == nil and not fs.exists(data_source_base .. "/repos--" .. id .. ".cfg") then
        type = "packages"
    end
    if type == nil then
        type = "repos"
    end
    local source = load_source_file(type .. "--" .. id .. ".cfg")
    if not source then
        io.stderr:write("Error: source " .. id .. " not found\n")
        return
    end
    return source
end

return M