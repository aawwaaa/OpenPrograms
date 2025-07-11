require("component").gmuxapi.create_window_buffer({
    width = 40, height = 10,
    title = "Test",
    x = 5, y = 5
}, function (gpu)
    gpu.set(1, 1, "Test")
end)

require("component").gmuxapi.show_error([[
    An error occurred in process 1:
    Test error!
]])