local lib_base = "/usr/lib/ipm"

local M = {}
M.util = loadfile(lib_base .. "/util.lua")(M)
M.json = loadfile(lib_base .. "/json.lua")(M)
M.tui = loadfile(lib_base .. "/tui.lua")(M)
M.internet = loadfile(lib_base .. "/internet.lua")(M)
M.repo = loadfile(lib_base .. "/repo.lua")(M)
M.package = loadfile(lib_base .. "/package.lua")(M)
M.source = loadfile(lib_base .. "/source.lua")(M)

M.format = loadfile(lib_base .. "/format.lua")(M)

return M
