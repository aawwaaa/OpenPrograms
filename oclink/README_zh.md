# OCLink

OCLink - 基于Lua的OpenComputers连接器

## 配置与运行

### 游戏外配置

1. 你需要一个Lua 5.3的解释器，你可以在[这里](https://www.lua.org/ftp/lua-5.3.6.tar.gz)下载源代码并编译。

2. 你需要如下lua库:
```
luasocket
luafilesystem
```
你可以通过luarocks安装这些库，而luarocks的安装方法请参考[这里](https://github.com/luarocks/luarocks/blob/main/docs/download.md)。
```
luarocks install luasocket
luarocks install luafilesystem
```

3. 你需要下载love的二进制程序，在[这里](https://www.love2d.org/)下载。
在将其安装后，你需要配置环境变量`LOVE_PATH`指向其二进制程序(对于可直接使用`love`命令的系统，将其指向`love`字符串)。

4. 下载`/oclink/host`目录。
5. 运行`oclink.lua`，你应该会看到如下输出:
```
Listening 10252
```
这表示OCLink已经成功启动，并开始监听10252端口。

### 游戏内配置

1. 在游戏目录中，找到`/config/opencomputers/settings.conf`文件

> Warning: 如下操作可能会破坏OpenComputers的安全性，请不要在不可信环境的服务器中执行。

找到如下位置:
```
    filteringRules=[
      removeme,
      "deny private",
      "deny bogon",
      "allow default"
    ]
```
并修改为
```
    filteringRules=[
      "allow private",
      "deny bogon",
      "allow default"
    ]
```

2. 启动Minecraft，找到需要建立连接的computer，为其刷写如下路径的EEPROM:
[/oclink/computer/bios.lua](/oclink/computer/bios.lua)
你可以修改
```
    local socket = internet.connect("localhost", 10252)
```
来修改连接的地址和端口。

### OCLink配置

在`/oclink/host/oclink.lua`中，你可以配置虚拟组件。文件中附带了一个虚拟文件系统的案例，你可以参考其配置。
在`/oclink/host/data/wrapper.lua`中，你可以配置将在computer中运行的lua代码，这段代码将于Lua BIOS前运行。
 - 你可以修改`write_check`函数中的`0.3`和`40`来调整数据发送的频率。
 - 你可以将其他EEPROM，如`advancedLoader`和`error("Computer halted")`追加到文件末尾，来替代默认的Lua BIOS行为。
