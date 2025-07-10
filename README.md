* 本文由AI生成，仅供参考
* 如与实际情况不符，请以实际情况为准
* [English](README_en.md)

## 关于 Bug

- 窗口数量多时会出现闪烁，原因未知

# GMUX - OpenComputers多任务桌面环境

一个为Minecraft OpenComputers mod设计的先进多任务桌面环境系统，通过虚拟化组件、进程隔离和窗口管理，为OpenComputers提供类似现代操作系统的多任务体验。

## ✨ 项目亮点

GMUX打破了OpenComputers传统的单任务限制，实现了真正的多进程并发运行：

- 🖥️ **窗口化桌面环境** - 类似现代操作系统的GUI界面
- ⚡ **真正的多任务** - 多个程序同时运行而不互相干扰  
- 🔒 **进程隔离机制** - 每个进程拥有独立的虚拟组件空间
- 🎯 **高效资源管理** - 智能的CPU时间片分配和内存管理

## 🚀 核心功能

### 1. 多进程系统
- **并发执行**: 支持多个Lua程序同时运行
- **状态管理**: 实时监控进程状态（运行/等待/错误/死亡）
- **资源隔离**: 每个进程拥有独立的内存空间和执行环境
- **智能调度**: 基于事件驱动的高效进程调度算法

### 2. 窗口化GUI界面
- **窗口管理**: 创建、移动、调整大小、最小化、最大化窗口
- **焦点控制**: 智能的窗口焦点管理和事件分发
- **实时状态**: 窗口标题栏显示进程实时状态
- **拖拽操作**: 支持窗口拖拽和位置调整

### 3. 虚拟组件系统  
- **GPU虚拟化**: 每个进程获得独立的GPU访问权限
- **键盘隔离**: 键盘事件准确分发到对应进程
- **屏幕缓冲**: 独立的屏幕缓冲区防止显示冲突
- **组件代理**: 透明的组件访问代理机制

### 4. 桌面应用生态
- **Shell终端**: 功能完整的命令行环境
- **程序启动器**: 图形化的程序启动和管理工具
- **系统监控**: 实时显示CPU使用率和进程信息
- **扩展支持**: 易于开发和集成新的桌面应用

## 📦 快速开始

### 下载安装

1. **获取源码**
   ```bash
   # 在OpenComputers中下载
   wget https://github.com/your-repo/gmux/archive/main.zip
   # 或者克隆仓库
   git clone https://github.com/your-repo/gmux.git
   ```

2. **部署文件**
   ```bash
   # 将所有文件复制到OpenComputers根目录
   cp -r gmux/* /
   ```

### 启动使用

1. **启动GMUX**
   ```lua
   -- 在OpenComputers中运行
   lua /gmux.lua
   ```

2. **基本操作**
   - 点击桌面图标启动应用程序
   - 拖拽窗口标题栏移动窗口
   - 点击窗口按钮进行最小化/最大化/关闭操作
   - 使用鼠标在不同窗口间切换焦点

3. **启动Shell**
   - 点击"Shell"图标打开终端
   - 在终端中运行任何OpenComputers程序
   - 程序将在独立窗口中运行，不会影响其他进程

## 💻 系统要求

### OpenComputers环境
- **OpenComputers版本**: 1.7.5+
- **Minecraft版本**: 1.12.2+ (推荐)
- **Lua版本**: 5.3+ (OpenComputers内置)

### 硬件配置建议
- **内存**: 至少3.5MB内存条 (推荐4MB+)
- **CPU**: T2及以上处理器 (支持多线程)
- **显卡**: T2及以上显卡 (支持多缓冲区)
- **屏幕**: T2及以上屏幕 (推荐160x50分辨率)

### 依赖组件
```lua
-- 必需组件
component.gpu      -- 图形处理单元
component.screen   -- 显示屏幕  
component.keyboard -- 键盘输入
computer           -- 计算机核心

-- 可选组件
component.ocelot   -- 日志记录 (如果可用)
```

## 🏗️ 架构说明

GMUX采用分层架构设计，确保系统的稳定性和可扩展性：

### 系统架构图
```
┌─────────────────────────────────────┐
│           Frontend Layer            │  <- 用户界面层
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ │
│  │Desktop  │ │Windows  │ │ Items   │ │
│  │Manager  │ │Manager  │ │ Apps    │ │
│  └─────────┘ └─────────┘ └─────────┘ │
└─────────────────────────────────────┘
           │           │           │
┌─────────────────────────────────────┐
│            Backend Layer            │  <- 系统核心层
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ │
│  │Process  │ │Virtual  │ │ Patch   │ │
│  │Manager  │ │Component│ │ System  │ │
│  └─────────┘ └─────────┘ └─────────┘ │
└─────────────────────────────────────┘
           │           │           │
┌─────────────────────────────────────┐
│         OpenComputers API           │  <- 底层接口层
│     computer │ component │ event     │
└─────────────────────────────────────┘
```

### 核心模块说明

**后端核心 (Backend)**
- `core.lua`: 系统初始化和主事件循环
- `process.lua`: 进程创建、调度和生命周期管理
- `patch.lua`: OpenComputers API增强和修改
- `virtual_components/`: 虚拟组件实现

**前端界面 (Frontend)**  
- `main.lua`: 前端入口点和事件处理
- `desktop.lua`: 桌面环境和窗口管理器
- `api.lua`: 前端API接口
- `items/`: 桌面应用程序

### 数据流说明
1. **事件输入**: 硬件事件 → Patch系统 → 虚拟组件 → 目标进程
2. **显示输出**: 进程渲染 → 虚拟GPU → 窗口管理器 → 物理屏幕
3. **进程通信**: 进程A → 事件系统 → 进程B (通过信号机制)

## 📁 项目结构

```
gmux/
├── gmux.lua                 # 主入口文件
├── bin/
│   └── start.lua           # 启动脚本
├── backend/                # 后端系统核心
│   ├── config.lua          # 系统配置
│   ├── core.lua            # 核心管理器
│   ├── patch.lua           # API补丁系统
│   ├── process.lua         # 进程管理器
│   ├── patchs/             # API补丁实现
│   │   ├── 01_computer.lua # Computer API增强
│   │   ├── 02_event.lua    # Event系统增强
│   │   ├── 03_component.lua# Component虚拟化
│   │   ├── 04_thread.lua   # 线程支持
│   │   ├── 40_keyboard.lua # 键盘虚拟化
│   │   ├── 50_tty.lua      # TTY终端支持
│   │   ├── 51_core_cursor.lua # 光标管理
│   │   ├── 52_term.lua     # 终端增强
│   │   ├── 60_io.lua       # IO系统增强
│   │   ├── 91_gpu.lua      # GPU虚拟化
│   │   ├── 92_keyboard.lua # 键盘事件处理
│   │   └── 93_term.lua     # 终端显示增强
│   └── virtual_components/ # 虚拟组件实现
│       ├── api.lua         # 虚拟组件API
│       ├── gpu.lua         # 虚拟GPU实现
│       ├── keyboard.lua    # 虚拟键盘实现
│       └── screen.lua      # 虚拟屏幕实现
├── frontend/               # 前端用户界面
│   ├── main.lua           # 前端主程序
│   ├── config.lua         # 前端配置
│   ├── desktop.lua        # 桌面管理器
│   ├── api.lua            # 前端API接口
│   └── items/             # 桌面应用
│       ├── monitor.lua    # 系统监控器
│       ├── run.lua        # 程序启动器
│       └── shell.lua      # Shell终端
└── README.md              # 项目文档
```

## 🔧 开发信息

### 贡献指南

欢迎为GMUX项目贡献代码！请遵循以下步骤：

1. **Fork仓库**并创建功能分支
2. **遵循代码规范**：
   - 使用4空格缩进
   - 函数和变量使用下划线命名法
   - 添加必要的注释说明

3. **测试您的更改**：
   ```lua
   -- 确保在OpenComputers环境中测试
   lua /gmux.lua
   ```

4. **提交Pull Request**并详细描述您的更改

### 开发环境搭建

1. **准备OpenComputers测试环境**
   - 安装Minecraft 1.12.2+
   - 安装OpenComputers mod
   - 创建包含足够内存的计算机

2. **开发工具推荐**
   - 代码编辑器：VS Code + Lua扩展
   - 版本控制：Git
   - 测试环境：OpenComputers模拟器 (可选)

### API扩展开发

创建新的桌面应用：

```lua
-- frontend/items/your_app.lua
return {
    name = "Your App",
    action = function()
        local api = require("frontend/api")
        local result = api.create_graphics_process({
            gpu = component.gpu,
            width = 80, height = 25,
            main_path = "/your/app/path.lua",
        })
        api.create_window({
            source = result,
            process = result.process,
            title = "Your App Title",
            event_handler = result,
            gpu = component.gpu,
            x = 5, y = 5
        })
    end
}
```

### 已知限制

- 同时运行的进程数量受OpenComputers内存限制
- 某些OpenComputers程序可能需要适配才能在窗口中正常运行
- 高频率的屏幕更新可能影响性能

## 📄 许可证

本项目采用 **MIT许可证** 开源发布。

---

### 致谢

感谢OpenComputers mod的开发者们为Minecraft带来了强大的计算机模拟功能，让这个项目成为可能。

**让我们一起为OpenComputers带来更好的多任务体验！** 🚀
