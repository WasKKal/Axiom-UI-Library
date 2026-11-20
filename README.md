# Axiom UI Library

主从分栏布局的 Roblox/Luau UI 库：左侧文字菜单 + 右侧表格化对齐控件。带两级本地 Lucide 图标缓存（优先读本地）与完整交互控件。

## 文件

| 文件 | 说明 |
|---|---|
| `Axiom.lua` | 独立库文件（ModuleScript，结尾 `return Axiom`） |
| `Axiom_Example.lua` | 示例：通过 HttpGet 加载独立库并建窗 |

图标首次加载后缓存到执行器的 `lucide-icon-latest/` 文件夹（模块 `init.lua` + 各图标 PNG），后续启动**优先读本地**，无需重复联网。

## 用法一：执行器（推荐）

新建 LocalScript / 执行器脚本，`require` 远程 ModuleScript：

```lua
local Axiom = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/WasKKal/Axiom-UI-Library/main/Axiom.lua"
))()

local Win = Axiom.CreateWindow({ Title = "AXIOM", Info = "General" })
local Tab = Win:AddTab("General", "settings")
Tab:AddToggle({ Title = "Master Switch", Default = true, Callback = function(v) print(v) end })
```

或直接运行 `Axiom_Example.lua`（内置 raw / jsdelivr 双 CDN 回退）。

## 用法二：Roblox Studio

1. 把 `Axiom.lua` 作为 ModuleScript 放进 ReplicatedStorage，命名 `Axiom`。
2. LocalScript 中 `require`：

```lua
local Axiom = require(game.ReplicatedStorage.Axiom)
local Win = Axiom.CreateWindow({ Title = "AXIOM" })
```

> Studio 环境没有 `writefile`/`getcustomasset` 时，图标会自动降级为在线加载，界面照常显示。

## API

### `Axiom.CreateWindow(opts)`

`opts`：`Title`（标题栏/详情标题）、`Info`（详情副标题）。返回 `Window`。

### `Window:AddTab(name, icon)`

返回 `Tab`。`icon` 为 Lucide 图标名（如 `settings`）。

### Tab 控件方法

| 方法 | 常用参数 | 返回对象方法 |
|---|---|---|
| `AddToggle(o)` | `Title, Desc, Icon, Default, Callback` | `SetValue(v)`, `Get()`, `Callback(fn)` |
| `AddSlider(o)` | `Title, Icon, Min, Max, Default, Callback` | `SetValue(v)`, `Get()`, `Callback(fn)` |
| `AddDropdown(o)` | `Title, Icon, Options, Default, Multi, Callback` | `Set(v)`, `Get()`, `Select(name,on)`, `IsSelected(name)`, `ClearSelection()`, `Callback(fn)` |
| `AddColorPicker(o)` | `Title, Icon, Default(Color3), Callback` | `SetValue(c)`, `Get()`, `Callback(fn)` |
| `AddButton(o)` | `Title, Icon, Callback` | `Fire()`, `Callback(fn)` |
| `AddParagraph(o)` | `Title, Icon, Text` | `SetText(s)`, `Get()` |

- `Multi = true` 时下拉为多选：`Default` 传数组（如 `{ "Neon", "Retro" }`），`Get()` 返回按 `Options` 排序的数组；胶囊超过 3 项折叠为 `+N`。
- `Callback` 也可在创建对象后通过 `obj:Callback(fn)` 设置。

### `Window:ShowNotify(o)`

`o`：`Title`、`Info`、`Duration`（秒，默认 3）。右下角通知，到时自动淡出。

### 缓存查询

| 方法 | 返回 |
|---|---|
| `Axiom.GetLucideCacheDir()` | `"lucide-icon-latest"` |
| `Axiom.GetLucideModulePath()` | `"lucide-icon-latest/init.lua"` |
| `Axiom.GetLucideSource()` | `"none" | "local" | "network"`（首次真实来源） |

## 图标

图标用 [Lucide](https://lucide.dev) v6，图标名即 Lucide 名（`toggle-right`、`gauge`、`palette`、`list-filter`、`send`、`home`、`settings`、`chevron-down`、`bell` 等）。也可直接传 `http(s)://` 图片 URL 作为图标。所有图标解析都有 pcall 兜底——即便加载失败也不会阻断窗口创建。

## 分支

`main`
