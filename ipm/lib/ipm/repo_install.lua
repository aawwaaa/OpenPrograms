local fs = require("filesystem")
local serialization = require("serialization")

local ipm = ...
local base = ipm.install_base

local M = {}

function M.repo()
    return {
        repo_str = "local:" .. base,
        fetch = function(self, path, dst)
            local src = base .. "/" .. path
            if fs.exists(src) then
                fs.copy(src, dst)
            end
        end,
        list = function(self, path, relative)
            if relative == nil then
                relative = "/"
            end
            local output = {}
            for file in fs.list(base .. "/" .. path) do
                if fs.isDirectory(base .. "/" .. path .. "/" .. file) then
                    output[file] = self:list(path .. "/" .. file, relative .. file .. "/")
                else
                    output[file] = relative .. file
                end
            end
            return output
        end,
    }
end

return M