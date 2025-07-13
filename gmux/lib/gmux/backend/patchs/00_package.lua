local _package = {}
for k, v in pairs(require("package")) do
    _package[k] = v
end
local __package = _G.package

local _require = require

return function(instances)
    local package = {}
    
    local metatable = {
        __index = _package,
        __pairs = function(t)
            local parent = false
            return function(_, key)
                if parent then
                    return next(_package, key)
                else
                    local k, v = next(t, key)
                    if not k then
                        parent = true
                        return next(_package)
                    else
                        return k, v
                    end
                end
            end
        end
    }
    setmetatable(package, metatable)

    package.path = _package.path
    local loaded = {}
    local loading = {}
    package.loaded = loaded
    setmetatable(package.loaded, {
        __index = function(t, k)
            if _package.loaded[k] then
                return _package.loaded[k]
            end
            return nil
        end,
        __pairs = function(t)
            local parent = false
            return function(_, key)
                if parent then
                    return next(_package.loaded, key)
                end
                local k, v = next(t, key)
                if not k then
                    parent = true
                    return next(_package.loaded)
                else
                    return k, v
                end
            end
        end
    })

    function package.searchpath(name, path, sep, rep)
        checkArg(1, name, "string")
        checkArg(2, path, "string")
        sep = sep or '.'
        rep = rep or '/'
        sep, rep = '%' .. sep, rep
        name = string.gsub(name, sep, rep)
        local fs = _require("filesystem")
        local errorFiles = {}
        for subPath in string.gmatch(path, "([^;]+)") do
          subPath = string.gsub(subPath, "?", name)
          if subPath:sub(1, 1) ~= "/" and os.getenv then
            subPath = fs.concat(os.getenv("PWD") or "/", subPath)
          end
          if fs.exists(subPath) then
            local file = fs.open(subPath, "r")
            if file then
              file:close()
              return subPath
            end
          end
          table.insert(errorFiles, "\tno file '" .. subPath .. "'")
        end
        return nil, table.concat(errorFiles, "\n")
      end

    function package.require(module)
        checkArg(1, module, "string")
        if loaded[module] ~= nil then
          return loaded[module]
        elseif not loading[module] then
          local library, status, step
      
          step, library, status = "not found", package.searchpath(module, package.path)
      
          if library then
            step, library, status = "loadfile failed", loadfile(library)
          end
      
          if library then
            loading[module] = true
            step, library, status = "load failed", pcall(library, module)
            loading[module] = false
          end
      
          assert(library, string.format("module '%s' %s:\n%s", module, step, status))
          loaded[module] = status
          return status
        else
          error("already loading: " .. module .. "\n" .. debug.traceback(), 2)
        end
    end

    instances.package = package

    table.insert(instances.loads.load, function()
        _G.require = package.require
        _G.package = package
    end)

    table.insert(instances.loads.unload, function()
        _G.require = _require
        _G.package = __package
    end)
end
