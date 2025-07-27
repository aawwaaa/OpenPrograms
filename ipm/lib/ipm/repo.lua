local fs = require("filesystem")
local serialization = require("serialization")

local ipm = ...

local M = {}

local data_repo_base = "/usr/share/ipm/repo"
M.data_repo_base = data_repo_base

local load_repo_file = ipm.util.cherry_base_path(ipm.util.load_file, data_repo_base)
local function has_repo_file(repo)
    return fs.exists(data_repo_base .. "/" .. repo .. ".cfg")
end
ipm.util.mkdirp(data_repo_base)

local Repo = {}

function Repo:new(repo)
    local repo_type, repo_value = repo:gmatch("([^:]+):(.*)$")()
    if not repo_type or not repo_value then
        io.stderr:write("Error: repo should be <type>:<value>\n")
        return nil
    end
    if not has_repo_file(repo_type) then
        io.stderr:write("Error: repo " .. repo_type .. " not found\n")
        return nil
    end
    local repo_data = load_repo_file(repo_type)
    local obj = {
        repo = repo_value,
        repo_str = repo,
        file_url = repo_data.file_url,
        dir_url = repo_data.dir_url,
        dir_url_format = repo_data.dir_url_format,
        dir_url_response = repo_data.dir_url_response,
        headers = repo_data.headers or {},
    }
    setmetatable(obj, self)
    self.__index = self
    return obj
end

function Repo:fetch(path, target)
    local url = ipm.util.format(self.file_url, {
        repo = self.repo,
        path = path,
    })
    ipm.internet.download(url, target, self.headers)
end

local parsers = {
    json = ipm.json.decode,
    cfg = serialization.unserialize
}

function Repo:list(path, relative)
    if not relative then
        relative = "/"
    end
    local output = {}
    local url = ipm.util.format(self.dir_url, {
        repo = self.repo,
        path = path,
    })
    io.write("List: " .. self.repo_str .. "/" .. path .. " -> " .. relative .. "\n")
    local content = ipm.internet.fetch(url, self.headers)
    local data = parsers[self.dir_url_response](content)
    local parsed = {}
    for k, item in pairs(data) do
        local key = next(self.dir_url_format)
        if key then
            local obj = {}
            for k, v in pairs(self.dir_url_format[key]) do
                local kv = v:gmatch("<(.-)>")()
                if kv:match(":") then
                    local vk, vv = kv:gmatch("([^:]+):(.-)$")()
                    if vv:sub(1, 1) == "=" then
                        obj[vk] = item[k] == vv:sub(2)
                    end
                else
                    obj[kv] = item[k]
                end
            end
            obj[key:gmatch("<(.-)>")()] = k
            table.insert(parsed, obj)
        end
    end
    for _, obj in ipairs(parsed) do
        if obj.is_dir then
            output[obj.name] = self:list(path .. "/" .. obj.name, relative .. obj.name .. "/")
        else
            output[obj.name] = relative .. obj.name
        end
    end
    return output
end

function M.repo(repo)
    return Repo:new(repo)
end

return M