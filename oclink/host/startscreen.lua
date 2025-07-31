#!/usr/bin/env lua

if package.loaded.computer then
    print("Please DO NOT run this file INSIDE OpenComputers.")
    print("It's for physical computer only.")
    return
end

local screen = require("screen")

screen(...)