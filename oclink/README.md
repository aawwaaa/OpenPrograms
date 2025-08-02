# OCLink  

OCLink - A Lua-based OpenComputers Connector  

## Configuration and Operation  

### External Game Configuration  

1. You need a Lua 5.3 interpreter. You can download the source code [here](https://www.lua.org/ftp/lua-5.3.6.tar.gz) and compile it.  

2. You will need the following Lua libraries:  
```
luasocket  
luafilesystem  
```  
You can install these libraries via luarocks. For luarocks installation instructions, refer to [here](https://github.com/luarocks/luarocks/blob/main/docs/download.md).  
```
luarocks install luasocket  
luarocks install luafilesystem  
```  

3. You need to download the Love2D binary from [here](https://www.love2d.org/).  
After installation, you need to set the environment variable `LOVE_PATH` to point to its binary (for systems where the `love` command is directly usable, set it to the string `love`).  

4. Download the `/oclink/host` directory.  
5. Run `oclink.lua`. You should see the following output:  
```
Listening 10252  
```  
This indicates that OCLink has started successfully and is listening on port 10252.  

### In-Game Configuration  

1. In the game directory, locate the file `/config/opencomputers/settings.conf`.  

> Warning: The following operations may compromise OpenComputers' security. Do not perform these steps on servers in untrusted environments.  

Locate the following section:  
```
    filteringRules=[
      removeme,
      "deny private",
      "deny bogon",
      "allow default"
    ]
```  
And modify it to:  
```
    filteringRules=[
      "allow private",
      "deny bogon",
      "allow default"
    ]
```  

2. Launch Minecraft, locate the computer you want to connect, and flash its EEPROM with the following file:  
[/oclink/computer/bios.lua](/oclink/computer/bios.lua)  
You can modify:  
```
    local socket = internet.connect("localhost", 10252)
```  
To change the connection address and port.  

### OCLink Configuration  

In `/oclink/host/oclink.lua`, you can configure virtual components. The file includes an example of a virtual filesystem configuration for reference.  
In `/oclink/host/data/wrapper.lua`, you can configure the Lua code that will run on the computer. This code will execute before the Lua BIOS.  
 - You can adjust the `0.3` and `40` in the `write_check` function to modify the data transmission frequency.  
 - You can append other EEPROMs, such as `advancedLoader` and `error("Computer halted")`, to the end of the file to replace the default Lua BIOS behavior.