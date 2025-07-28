local inet = require("inet")

local status = inet.status()

if status.status ~= "connected" then
    print("Status: " .. status.status)
    return
end

print("Status: ", status.status)
print("Access Point: ", status.access_point)
print("Device Address: ", status.device_address)
print("Broadcast Address: ", status.broadcast_address)
print("Device Store:")
for id, data in pairs(status.device_store or {}) do
    print("  -", id, data.device)
end