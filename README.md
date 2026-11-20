# Axiom UI Library

主从分栏布局的 Roblox/Luau UI 库：左侧文字菜单 + 右侧表格化对齐控件。带两级本地 Lucide 图标缓存（优先读本地）与完整交互控件。

## 视觉与动效

- **紧凑窗口**：内部 620×440 设计坐标配合 `UIScale=0.65`，视觉尺寸缩小约三分之一且始终居中；`DisplayOrder=100000` 并挂载到 `gethui`（下游回退 hidden_gui → PlayerGui → CoreGui）。
- **动态选项卡**：左侧菜单由 `AddTab` 数量决定，调用几次就显示几项，不再出现示例外的多余选项卡；第一项默认激活。切换时旧蓝白渐变条缩短渐隐、新条伸长渐显。
- **登录页加载动画**：点击`加载脚本`后不立即切换——文字向左微移，右侧浮现持续旋转的 `loader-circle`，随机等待 **1.5–2.5 秒**后才开始渐隐进入主界面；加载期间按钮锁定防重复点击。
- **渐隐渐显**：主窗口、下拉菜单、颜色色板、通知均用 `CanvasGroup` + `TweenService` 做淡入淡出，动画失败时 pcall 兜底直接赋值；边框 `UIStroke` 同步补间透明度。
- **角落圆点**：红点=关闭确认框；黄点=最小化（内容/选项卡/圆点渐隐，框架收起到仅剩标题栏，标题左移并显示 plus，再点 plus 逆向还原）；绿点为装饰。拖动标题栏或标题文字可移动窗口（用 `UserInputService` 全局监听，鼠标移出标题栏后仍可持续拖动）。
- **下拉已选择指示器**：多选/单选菜单每项右侧带 Lucide `check` 勾选，`Set/Select/ClearSelection` 后同步刷新。
- **颜色过渡**：ColorPicker 切换颜色时对色块做 0.22s 颜色补间，不再瞬间跳变。
- **红点关闭确认**：标题栏最左侧红点为可点击按钮，点击后黑色蒙版覆盖界面并居中弹出确认框"你要关闭这个脚本吗？"，下方两个长按钮各占一行——`关闭窗口`（红色，销毁整个界面）与 `取消`（关闭确认框）。蒙版点击也可取消。

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

### `Axiom.Notify(o)`（全局通知，推荐）

`o`：`Title`、`Text`（或 `Info`）、`Duration`（秒，默认 4）、`Type`（`info`/`success`/`warning`/`error`，影响左侧色条与图标）、`Icon`。从屏幕右上角堆叠，多条通知自动向下排列；高度按文字长度自适应（实测 `TextService` 优先、超长文本自动换行）；入场从右滑入+渐显，退场滑出+渐隐并让后续通知自动上移。返回 `{ Frame, Dismiss() }`，可手动 `Dismiss()` 提前关闭。

```lua
Axiom.Notify({ Title = "系统就绪", Text = "已加载完成", Type = "success", Duration = 5 })
```

### `Window:ShowNotify(o)`

窗口内右下角简易通知。`o`：`Title`、`Info`、`Duration`（默认 3）。到时自动淡出。（全局堆叠通知请用上面的 `Axiom.Notify`。）

### LoginInfo 启动页

`Axiom.CreateWindow({ LoginInfo = true, LoginTitle = "版本更新日志", ... })` 时创建启动页：初始只显示登录层，隐藏三色点/功能区。右侧 1/3 显示圆形 LocalPlayer 头像、用户名与两个按钮——`加载脚本`（点击后文字左移、右侧出现旋转 loader，随机 1.5–2.5 秒后登录层渐隐、主界面渐显）、`卸载脚本`（整个 UI 渐隐销毁）；左侧 2/3 显示加粗大标题与多个整行段落。`加载脚本`文字为蓝白微渐变，`卸载脚本`为深灰底。

**登录页与选项卡共用同一个窗口**：对同一个 `CreateWindow` 返回值继续 `AddTab` 添加功能即可。加载脚本后，登录层淡出，露出的就是**同一个窗口**里已建好的选项卡与控件；最小化/展开/关闭都只作用于这一个窗口，不会出现两个窗口。

`opts` 额外字段：`LoginTitle`（大标题）、`OnLoadScript(fn)`、`OnUnloadScript(fn)`。

```lua
local Win = Axiom.CreateWindow({ Title = "AXIOM", LoginInfo = true, LoginTitle = "版本更新日志" })
Win:AddLoginParagraph({ Title = "v1.0.0", Text = "更新内容……" }) -- 整行、自动换行、高度自适应，返回对象有 SetText/Get
-- 同一个窗口继续加选项卡：加载脚本后即显示这些功能
local Tab = Win:AddTab("General", "settings")
Tab:AddToggle({ Title = "Master Switch", Default = true })
```

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
