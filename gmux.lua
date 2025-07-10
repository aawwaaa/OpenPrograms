local backend = require("backend/core")
local component = require("component")
local main = require("frontend/main")

backend.load()
backend.process.create_process({
    main = main,
    components = component.list(),
    args = {backend}
})

backend.loop(function()
end)

backend.finish()
