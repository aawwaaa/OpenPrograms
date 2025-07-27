local base = ...
local lib_base = base .. "/.ipm"

local M = {}
M.install_base = base

M.util = loadfile(lib_base .. "/util.lua")(M)
M.tui = loadfile(lib_base .. "/tui.lua")(M)
M.package = loadfile(lib_base .. "/package.lua")(M)
M.repo = loadfile(lib_base .. "/repo.lua")(M)
M.execute = loadfile(lib_base .. "/execute.lua")(M)

M.format = loadfile(lib_base .. "/format.lua")(M)

return M
