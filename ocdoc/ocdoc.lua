local comp = require("component")
local computer = require("computer")
local math = require("math")
local event = require("event")
local shell = require("shell")
local i = require("internet")
local unicode = require("unicode")

local marginRight = 3
local backgroundColor = 0x000000
local textColor = 0xffffff
local linkColor = 0x00ff00

local escape_names = {
  ["amp"] = "&",
  ["quot"] = "\"",
  ["gt"] = ">",
  ["lt"] = "<",
  ["nbsp"] = " ",
}
local color_tags = {
  ["h1"] = 0xffff00,
  ["h2"] = 0x00aaff,
  ["h3"] = 0xff00ff
}

local args, opts = shell.parse(...)

local gpu = comp.gpu

local path = args[1] or "/start"
local buffer = 0
local links = {}
local marks = {}
local lines = 0
local scrollY = 0

local w, h = gpu.getResolution()

function update_connecting()
  gpu.setActiveBuffer(0)
  gpu.setBackground(0x000000)
  gpu.setForeground(0xffffff)
  gpu.fill(1, 2, w, h - 1, " ")
  gpu.set(1, 2, "Connecting...")
end

function update_loading(part, all, text)
  gpu.setActiveBuffer(0)
  gpu.setBackground(0x000000)
  gpu.setForeground(0xffffff)
  gpu.fill(1, 2, w, h - 1, " ")
  gpu.set(1, 2, "Loading... " .. tostring(part) .. "/" .. tostring(all))
  gpu.setForeground(0x00ff00)
  gpu.set(1, 3, "[")
  gpu.fill(2, 3, math.floor(part / all * (w-2)), 1, "=")
  gpu.set(w, 3, "]")
end

function request_page(url)
  update_connecting()
  if url:sub(1, 8) ~= "https://" then
    url = "https://ocdoc.cil.li" .. url
  end
  local result, response = pcall(i.request, url)
  if not result then
    return false, {lines = 1, text = "Request failed. ~1~[Retry]~", links = { url }, marks = {}}
  end
  return true, response
end

function format_page(resp)
  local ut = 0
  local linkid = 1
  local links = {}
  local marks = {}
  local output = ""
  
  local chars = 0
  local lines = 0
  local lasts = "-----"
  local in_mark = false
  local in_escape = false
  local in_prop = false
  local in_commit = false
  
  local in_script = false
  local in_code = false
  
  local current_escape = nil
  local current_mark = nil
  local current_prop = nil
  local current_prop_value = nil
  local props = {}
  
  function parse_mark()
    if props.id then
      marks[props.id] = lines
    end
    if current_mark == "ul" and props.class == "nav" then
      output = output .. "\n    "
      chars = 4
      lines = lines + 1
    end
    if current_mark == "script" then
      in_script = true
    end
    if current_mark == "/script" then
      in_script = false
    end
    if current_mark == "dl" then
      output = output .. "\n\n"
      chars = 0
      lines = lines + 2
    end
    if current_mark == "code" or current_mark == "dd" then
      in_code = true
    end
    if current_mark == "/code" or current_mark == "/dd" then
      in_code = false
    end
    if current_mark == "a" then
      links[linkid] = props.href
      output = output .. "~" .. tostring(linkid) .. "~"
      add_char("[")
      linkid = linkid + 1
      return
    end
    if current_mark == "/a" then
      add_char("]")
      output = output .. "~"
      return
    end
    if current_mark == "p" or current_mark == "br/" or current_mark == "/dt" then
      output = output .. "\n"
      chars = 0
      lines = lines + 1
      return
    end
    if current_mark == "li" or current_mark == "/td" or current_mark == "/th" then
      add_char(" ")
      add_char(" ")
      return
    end
    if current_mark == "tr" then
      output = output .. "\n    "
      chars = 4
      lines = lines + 1
      return
    end
    for tag, color in pairs(color_tags) do
      if current_mark == tag then
        output = output .. "\n\n~##" .. tostring(color) .. "~"
        chars = 0
        lines = lines + 2
        return
      end
      if current_mark == "/" .. tag then
        output = output .. "~\n"
        chars = 0
        lines = lines + 1
        return
      end
    end
  end
  
  function parse_escape()
    if current_escape:sub(1, 1) == "#" then
      add_char(unicode.char(tonumber(current_escape:sub(2))))
      return
    end
    add_char(escape_names[current_escape])
  end
  
  function parse(char)
    if in_commit then
      if lasts:sub(-3, -1) == "-->" then
        in_commit = false
        current_mark = nil
        current_prop = nil
        current_prop_value = nil
        in_mark = false
        in_prop = false
        props = {}
        return
      end
      return
    end
    if char == "<" then
      in_mark = true
      current_mark = ""
      return
    end
    if char == ">" then
      parse_mark()
      current_mark = nil
      current_prop = nil
      current_prop_value = nil
      in_mark = false
      in_prop = false
      props = {}
      return
    end
    if char == "&" then
      in_escape = true
      current_escape = ""
      return
    end
    
    if in_escape then
      if char == ";" then
        parse_escape()
        in_escape = false
        current_escape = nil
        return
      end
      current_escape = current_escape .. char
      return
    end
    if in_prop then
      if current_prop_value ~= nil then
        if char == "\"" then
          props[current_prop] = current_prop_value
          current_prop = ""
          current_prop_value = nil
          return
        end
        current_prop_value = current_prop_value .. char
        return
      end
      if char == "\"" then
        current_prop_value = ""
        return
      end
      if char == "=" then return end
      if current_prop == "" and char == " " then return end
      current_prop = current_prop .. char
      return
    end
  
    if in_mark then
      if lasts:sub(-4, -1) == "<!--" then
        in_commit = true
        return
      end
      if char == " " then
        in_prop = true
        current_prop = ""
        current_prop_value = nil
        return
      end
      current_mark = current_mark .. char
      return
    end
    if in_script then return end
    if not in_code and char == " " and lasts:sub(-2, -2) == " " then
      return
    end
    if not in_code and (char == "\n" or char == "\t") then
      return
    end
    add_char(char)
  end
  
  function add_char(char)
    if char == nil then return end
    output = output .. char
    chars = chars + 1
    if chars >= w - marginRight then
      chars = 0
      lines = lines + 1
    end
  end
  
  for text in resp do
    for i=1, #text, 1 do
      if computer.uptime() - ut > 1.5 then
        ut = computer.uptime()
        event.pull(0)
        update_loading(i, #text)
      end
      local char = text:sub(i, i)
      lasts = lasts:sub(2) .. char
      
      parse(char)
    end
  end
  
  return {text = output, links = links, lines = lines, marks = marks}
end

function render_page(formatted)
  if buffer ~= 0 then
    gpu.freeBuffer(buffer)
  end
  local err;
  buffer, err = gpu.allocateBuffer(w, formatted.lines + 5)
  if err then
    error("Page too long or out of memory: " .. tostring(err))
    return
  end
  gpu.setActiveBuffer(buffer)
  gpu.setBackground(backgroundColor)
  gpu.setForeground(textColor)
  local x, y = 1, 1
  links = {}
  lines = formatted.lines
  marks = formatted.marks
  scrollY = 0
  local link = false
  local linkid = nil
  local beginI = 0
  
  local buf = nil
  
  function parse(char)
    if char == "\n" then
      x = 1
      y = y + 1
      return
    end
    if char == "~" then
      if link == false then
        if linkid == nil then
          gpu.setForeground(linkColor)
          linkid = ""
          return
        end
        if #linkid >= 2 and linkid:sub(1, 2) == "##" then
          local color = linkid:sub(3)
          gpu.setForeground(tonumber(color))
          beginI = -1
          link = true
          return
        end
        linkid = tonumber(linkid)
        beginI = (y-1) * (w-marginRight) + (x-1)
        link = true
        return
      end
      gpu.setForeground(textColor)
      if beginI ~= -1 then
        for i=beginI, (y-1) * (w-marginRight) + (x-1), 1 do
          links[i] = formatted.links[linkid]
        end
      end
      linkid = nil
      link = false
      return
    end
    if not link and linkid ~= nil then
      linkid = linkid .. char
      return
    end
    if buf ~= nil then
      buf = buf .. char
      if #buf >= 3 then
        add_char(buf)
        buf = nil
        return
      end
      return
    end
    if char:byte() >= 129 then
      buf = char
      return
    end
    add_char(char)
  end
  function add_char(char)
    gpu.set(x, y, char)
    x = x + unicode.charWidth(char)
    if x >= w - marginRight then
      x = 1
      y = y + 1
    end
  end
  for i=1, #formatted.text, 1 do
    local char = formatted.text:sub(i, i)
    parse(char)
  end
  gpu.setActiveBuffer(0)
end

function draw()
  gpu.setActiveBuffer(0)
  
  -- path, exit button
  gpu.setBackground(0x444444)
  gpu.fill(1, 1, w, 1, " ")
  gpu.setForeground(0xff0000)
  gpu.set(w - 4, 1, "Exit")
  gpu.setForeground(0xffffff)
  gpu.set(1, 1, path)
  
  -- content
  gpu.setBackground(0x000000)
  gpu.fill(1, lines - scrollY + 1, w - marginRight, h-1, " ")
  gpu.bitblt(0, 1, 2, w - marginRight, h - 1, buffer, 1, scrollY + 1)
  
  -- slider
  gpu.setBackground(0x444488)
  gpu.fill(w - 1, 2, 2, h - 1, " ")
  local scrollable = math.max(1, lines - h)
  local size = math.max(1, math.min(h - 1, math.floor((h-1) / lines * (h-1))))
  local y = math.floor(scrollY / scrollable * (h-1)) + 2
  gpu.setBackground(0x88aaff)
  gpu.fill(w-1, y, 2, size, " ")
end

function jumpToMark(mark)
  if not marks[mark] then return end
  scrollY = math.max(0, marks[mark] - 2)
end

function jumpTo(new_path)
  if new_path:sub(1, 1) == "#" then
    local beg = path:find("#")
    if beg ~= nil then
      path = path:sub(1, beg-1)
    end
    path = path .. new_path
    jumpToMark(new_path:sub(2))
    return true
  end
  local beg = new_path:find("#")
  if beg == nil then
    return path == new_path
  end
  local url = new_path:sub(1, beg-1)
  local mark = new_path:sub(beg+1)
  if url == path then
    jumpToMark(mark)
    return true
  end
  return false
end

function loop()
  local t, _, x, y, s = event.pull(3)
  if t == "touch" and x >= w-4 and y <= 1 then
    error("interrupted")
    return
  end
  if t == "touch" and x >= w-1 and y >= 2 then
    -- slider
    y = y - 2
    local scrollable = math.max(1, lines - h) + 5
    local size = math.max(1, math.min(h - 1, math.floor((h-1) / lines * (h-1))))
    scrollY = math.max(0, math.floor(y / (h-1 - size) * scrollable))
    return
  end
  if t == "touch" then
    x = x - 1
    y = y - 1 - 1 + scrollY
    local i = y * (w-marginRight) + x
    if links[i] then
      if not jumpTo(links[i]) then
        path = links[i]
        return "continue"
      else
        path = links[i]
        return
      end
    end
  end
  if t == "scroll" then
    scrollY = math.max(0, scrollY + (-s * 5))
  end
end

while true do
  if buffer ~= 0 then
    gpu.freeBuffer(buffer)
    buffer = 0
  end
  local result, formatted = request_page(path)
  if result then
    result, formatted = pcall(format_page, formatted)
    if not result then
      io.stderr:write(formatted)
    end
  end
  render_page(formatted)
  
  jumpTo(path)
  result = true
  while result do
    draw()
    result, command = pcall(loop)
    if command == "continue" then
      break
    end
  end
  if command ~= "continue" then break end
end

if buffer ~= 0 then
  gpu.freeBuffer(buffer)
end
gpu.setBackground(0x000000)
gpu.fill(1, 1, w, h, " ")
