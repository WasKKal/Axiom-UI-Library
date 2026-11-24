# Axiom UI Library

<p align="center">
  <img src="https://img.shields.io/badge/Roblox-Luau-00a2ff?style=for-the-badge&logo=roblox" alt="Roblox Luau" />
  <img src="https://img.shields.io/badge/Layout-Master%20%2B%20Detail-000000?style=for-the-badge" alt="Master + Detail Layout" />
  <img src="https://img.shields.io/badge/Icons-Lucide%20v6-yellowgreen?style=for-the-badge" alt="Lucide v6" />
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" alt="MIT License" />
</p>

> 一个 Roblox / Luau UI 库，采用左侧文字菜单 + 右侧表格化对齐的主从分栏布局，内置 Lucide 图标本地缓存与完整动效，单文件引入即可搭建设置面板与功能界面。

---

## ✨ 特性

- 🪟 **主从分栏布局**：左侧选项卡文字菜单，右侧表格化对齐的控件区，视觉紧凑、层级清晰。
- 🎨 **壁纸与动效**：支持自定义背景壁纸（自动裁剪填充 + 圆角 + 暗化遮罩），配套入场收缩动画、渐隐渐显与控件过渡；登录页点击加载脚本后按「后仰压暗 → 品牌字标与三条进度条 → 头像飞入角落 → 整层上滑」的顺序转场（约 1.2 秒），关闭时控件自下而上向两侧退场、握手致谢、收缩成圆渐隐，最后 360° 粒子炸出拉丝消失。
- 🧩 **完整控件**：开关、滑块、多选下拉、HSV 取色器、按钮、文本段落等，统一回调与 getter 接口；按钮带按压缩放与压暗反馈，下拉点空白自动收起。
- 🔔 **全局通知**：右上角堆叠通知，左边缘蓝白渐变条贴齐边框，圆角裁剪，支持多种类型着色。
- 🛡️ **输入隔离**：窗口区域透明拦截层吸收空白处点击 / 触摸，防止穿透到 Roblox；窗口外区域不拦截，允许正常点击 / 触摸。
- 💾 **Config 系统**：控件 `ConfigKey` 绑定 + 命名配置存取（保存 / 载入 / 删除 / 重命名 / 列表），落盘到 `Axiom/<Folder>/`。
- 🔐 **登录启动页**：可选启动页，左侧更新日志标题常驻顶部、正文独立滚动；头像 / 用户名 / 加载按钮居中，加载动画结束后切入主界面。
- 🔑 **卡密验证（KeySystem）**：开启后按钮文案变为「验证密钥并载入」，按钮上方出现带 `user-key` 图标的卡密输入框，占位文字与图标点击行为均可自定义；支持 Luarmor 内置适配、自定义 HTTP 接口或完全自定义校验函数。
- 🌐 **界面多语言**：设置面板内置语言下拉（默认中文，内置 `zh` / `en`），支持追加语言包、覆盖词条、为页签与控件指定翻译键，也可用 `Translator` 完全接管。
- 🖼️ **图标缓存**：Lucide v6 图标首次加载后缓存到本地，后续启动优先读取本地，无需重复联网。
- 🔌 **零依赖单文件**：`Axiom.lua` 独立引入，兼容主流 Roblox 执行环境与 Roblox Studio。

## 📦 安装

通过执行环境加载远程模块：

```lua
local Axiom = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/WasKKal/Axiom-UI-Library/main/Axiom.lua"
))()
```

> 也可将 `Axiom.lua` 作为 ModuleScript 放入项目后 `require`。

## 🚀 快速开始

```lua
local Axiom = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/WasKKal/Axiom-UI-Library/main/Axiom.lua"
))()

local Win = Axiom.CreateWindow({
    Title = "AXIOM",
    Folder = "MyHub",
    Background = "https://raw.githubusercontent.com/WasKKal/Axiom-UI-Library/main/axiom-background.jpg",
})
Win:SaveConfig("Preset1")

local Tab = Win:AddTab("General", "settings")
Tab:AddToggle({ Title = "Master Switch", Default = true, Callback = function(v) print(v) end })
Tab:AddSlider({ Title = "Walk Speed", Min = 0, Max = 200, Default = 65 })

Axiom.Notify({ Title = "系统就绪", Text = "已加载完成", Type = "success", Duration = 5 })
```

直接运行 `Axiom_Example.lua` 可查看完整演示（内置 raw / jsdelivr 双 CDN 回退）。

## 🗂️ API 一览

| 接口 | 说明 |
| --- | --- |
| `Axiom.CreateWindow(opts)` | 创建窗口，`opts`：`Title`、`Info`、`Folder`（资源/配置目录名）、`ConfigName`、`Background`、`LoginInfo`、`LoginTitle`、`OnLoadScript`；卡密相关：`KeySystem`、`KeyPlaceholder`、`KeyIcon`、`KeyDefault`、`OnKeyIconClick`、`KeyCheck`、`KeyAPI`；语言相关：`Lang`、`Languages`、`Locales`、`Translator` |
| `Window:AddTab(name, icon, titleKey)` | 添加选项卡，返回 `Tab`；`titleKey` 为可选页签翻译键 |
| `Window:AddLoginParagraph(o)` | 启动页添加整行段落 |
| `Window:ShowNotify(o)` | 窗口内右下角简易通知 |
| `Axiom.Notify(o)` | 全局堆叠通知，`o`：`Title`、`Text`/`Info`、`Duration`、`Type`、`Color`，传 `Win` + `TitleKey` / `TextKey` 后通知文字随语言切换实时更新；返回 `{ Frame, Dismiss() }` |
| `Window:SetLanguage(code)` / `GetLanguage()` | 切换 / 读取当前界面语言 |
| `Window:GetLanguages()` | 可用语言列表（`{ Code, Label }`） |
| `Axiom.GetLucideCacheDir()` | 图标缓存目录 |
| `Axiom.GetLucideModulePath()` | 图标缓存模块路径 |
| `Axiom.GetLucideSource()` | 图标首次加载来源 |

### 卡密验证（KeySystem）

需同时开启 `LoginInfo = true`。开启后登录按钮上方出现卡密输入框，按钮文案改为「验证密钥并载入」；左侧 `user-key` 图标可点击，输入框占位文字可自定义。

```lua
local Win = Axiom.CreateWindow({
    Title = "AXIOM",
    LoginInfo = true,
    KeySystem = true,
    KeyPlaceholder = "请输入您的卡密",
    KeyIcon = "user-key",
    KeyDefault = "",
    OnKeyIconClick = function(win, input, field)
        pcall(function() setclipboard(tostring(input.Text or "")) end)
        Axiom.Notify({ Title = "卡密", Text = "卡密已复制到剪贴板", Type = "success", Duration = 2.5 })
    end,
    KeyCheck = function(key, resolve)
        if key == "MY-KEY" then
            resolve(true, "验证成功", { plan = "pro" })
        else
            resolve(false, "密钥无效")
        end
    end,
})
```

`resolve(ok, message, data)` 可同步或异步调用，20 秒未回调判定为超时；`data` 通过 `Win:GetKeyData()` 取回。校验失败时输入框抖动、按钮转红并显示原因，0.8 秒后自动恢复，期间重新输入会立即解除红色态。

**自定义 HTTP 接口**

```lua
KeyAPI = {
    Url = "https://your-server.example/verify",
    Method = "POST",
    Headers = { ["Content-Type"] = "application/json", ["Authorization"] = "Bearer ..." },
    Body = function(key) return { key = key, hwid = "..." } end,
    Check = function(data, raw, status) return data and data.valid == true, data and data.message end,
}
```

默认 POST JSON `{ key = key }`；响应 2xx 且包含 `success` / `valid` / `ok = true`（或 `status = "active"`）视为通过，`success = false`、`banned`、`status = "banned"` 视为失败。`Check` 可完全接管判定。`Method = "GET"` 时卡密拼到 `?key=`。

**Luarmor 内置适配**

```lua
KeyAPI = { Provider = "Luarmor", ScriptId = "你的脚本 ID" }
```

通过 Luarmor 官方客户端库的 `check_key` 校验，仅 `KEY_VALID` 放行，其余状态映射为中文提示（过期 / 封禁 / 绑定其他设备 / 不存在 / 脚本 ID 错误等）。验证通过后自动解锁 UI；追加 `LoadScript = true` 时会写入 `script_key` 并调用 `load_script()`。

> Luarmor 校验由官方库在客户端完成，UI 内无需填写 API Key。若使用自建后端代理，请改用上面的自定义 HTTP 接口，避免把 `Authorization` 暴露在客户端。

### 界面语言（i18n）

设置面板「窗口比例」下方内置语言下拉，默认中文，切换后立即生效（内置 `zh` / `en`）。

```lua
local Win = Axiom.CreateWindow({
    Title = "AXIOM",
    Lang = "zh",                 -- 默认语言；也可用 Axiom.DefaultLanguage 改全局默认
    Languages = {                -- 追加可选语言
        { Code = "ja", Label = "日本語" },
    },
    Locales = {                  -- 追加或覆盖词条
        en = { ["demo.master"] = "Master Switch" },
        ja = { ["settings.apply"] = "適用" },
    },
})
Win:SetLanguage("en")            -- 代码切换
Win:GetLanguage()                -- 当前语言
Win:GetLanguages()               -- 语言列表
```

控件与页签可指定翻译键，未提供时以 `Title` / `Desc` 作为回退：

```lua
local Tab = Win:AddTab("常规", "settings", "tab.general")
Tab:AddToggle({ Title = "主开关", TitleKey = "demo.master", Desc = "启用全部功能", DescKey = "demo.desc" })
Tab:AddParagraph({ Title = "说明", Text = "默认文本", TextKey = "demo.body" })
```

内置词条键为 `login.*`、`settings.*`、`close.*`、`control.*`、`account.*`、`key.*`、`bar.*`、`notify.title`；缺失词条会依次回退到 `Locales`、内置语言包、传入的 `Title` / `Desc`。也可以用 `Translator = function(key, lang, fallback) ... end` 完全接管翻译。

已绑定到翻译键的文本（登录页文案、设置面板、关闭确认与感谢语、标题栏关闭提示、账号生日、卡密校验失败原因、通知内容）在切换语言时立即刷新，不需要重建窗口。自定义通知也可跟随语言：

```lua
Axiom.Notify({ Win = Win, TitleKey = "settings.savedTitle", TextKey = "settings.savedText",
    Title = "设置", Text = "你的设定已保存!", Type = "success" })
```

### Tab 控件

| 方法 | 说明 |
| --- | --- |
| `AddToggle(o)` | 开关 |
| `AddSlider(o)` | 滑块 |
| `AddDropdown(o)` | 下拉选择，`Multi = true` 开启多选；展开后点击空白处自动收起 |
| `AddColorPicker(o)` | HSV 取色器：SV 面板 + 色相条 + 预览 + HEX，支持拖动取色，点击面板外自动收起 |
| `AddInput(o)` | 输入框：左侧标题/描述，右侧圆角输入区；`Default` 默认文本，`Placeholder` 灰色占位文字，`PlaceholderKey` 占位文字翻译键 |
| `AddButton(o)` | 按钮 |
| `AddParagraph(o)` | 文本段落 |

```lua
local Name = Tab:AddInput({
    Title = "名字", Desc = "显示名称", Icon = "text-cursor-input",
    Default = "Player", Placeholder = "输入名字", ConfigKey = "name",
    Callback = function(v) print("名字改为", v) end,
})
Name:Set("Axiom")
print(Name:Get())
```

控件对象统一提供 `SetValue` / `Set` / `Get` / `Callback` 等方法，下拉另含 `Select` / `ClearSelection` / `IsSelected`。给控件传 `o.ConfigKey = "xxx"` 即纳入配置管理（Toggle / Slider / Dropdown / ColorPicker / Input）。

#### 动态改值

控件的值可以在任意时刻被代码改写，界面、`Value` 字段与配置通道会同步更新，不需要重建窗口或模拟点击：

```lua
local Slider = Tab:AddSlider({ Title = "音量", Min = 0, Max = 100, Default = 20, ConfigKey = "volume" })

Slider:SetValue(70)        -- 静默改值：界面同步，不触发 Callback
Slider:Set(70, true)       -- 改值并触发一次 Callback
Slider:Get()               -- 读取当前值
```

| 控件 | 改值方法 | 读值 | 补充 |
| --- | --- | --- | --- |
| `AddParagraph` | `SetText(v)` / `Set(v[, fire])` / `SetValue` | `Get()` | 文本即时刷新 |
| `AddToggle` | `SetValue(v[, fire])` / `Set` | `Get()` | 开关状态与动画同步 |
| `AddSlider` | `SetValue(v[, fire])` / `Set` | `Get()` | 超出 `Min`~`Max` 自动夹取 |
| `AddDropdown` | `Set(v[, fire])` / `SetValue` | `Get()` | 单选传字符串，多选传数组；另有 `Select` / `ClearSelection` / `IsSelected` |
| `AddColorPicker` | `Set(c[, fire])` / `SetValue` | `Get()` | 仅接受 `Color3`，非法值忽略 |
| `AddInput` | `Set(v[, fire])` / `SetValue` | `Get()` | `Get()` 实时返回输入框内容；用户键入时自动同步 `Value` 并触发 `Callback` |

`fire` 省略时为静默改值，只更新界面与状态，不触发 `Callback`，适合“程序回填”场景；传 `true` 时按用户操作处理，回调收到新值。带 `ConfigKey` 的 Toggle / Slider / Dropdown / ColorPicker / Input 在改值时会同步刷新 `Config` 文件夹中对应的 `BoolValue` / `NumberValue` / `StringValue` / `Color3Value`，`SaveConfig` 落到文件的值也是最新值。


### Config（Window 方法）

| 方法 | 说明 |
| --- | --- |
| `Win:SaveConfig(name)` | 保存当前所有 `ConfigKey` 控件值为命名配置（省略 `name` 存到 Default） |
| `Win:LoadConfig(name)` | 载入配置回填控件（省略 `name` 读 active 记录） |
| `Win:GetConfigs()` | 列出所有配置名 |
| `Win:ConfigExists(name)` | 配置是否存在 |
| `Win:SetConfig(name)` / `GetConfigName()` / `GetConfigPath()` | 切换 / 查询当前配置 |
| `Win:DeleteConfig(name)` / `RenameConfig(old, new)` | 删除 / 重命名（Default 不可删） |
| `Win:GetAssetDir()` / `GetConfigDir()` | 资源 / 配置落盘目录，形如 `Axiom/<Folder>/` |
| `Win:GetKey()` / `Win:SetKey(v)` | 读取 / 写入卡密输入框 |
| `Win:GetKeyData()` | 最近一次验证通过返回的数据 |
| `Win:VerifyKey(cb)` | 手动触发验证，`cb(ok, msg, data)` |

背景图下载到 `Axiom/<Folder>/` 并按 URL 编码命名；下次使用命中本地缓存不再下载，更换 `Background` URL 时自动删除旧图。

## 🎯 设计理念

- **主从分栏**：以信息层级为核心，左侧导航、右侧内容，控件沿统一栅格对齐，保持一致与克制。
- **动效克制**：入场、过渡、通知均有动画，但服务于层级表达而非装饰，动画失败时自动兜底直接赋值。
- **图标即用**：图标名即 Lucide 名，支持直接传 `http(s)://` 图片 URL，解析失败不阻断界面创建。

## 📄 许可证

本项目基于 [MIT License](./LICENSE) 开源。

---

<p align="center">Made with ❤️ by Axiom</p>
