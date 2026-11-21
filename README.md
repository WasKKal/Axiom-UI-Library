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
- 🎨 **壁纸与动效**：支持自定义背景壁纸（自动裁剪填充 + 圆角 + 暗化遮罩），配套入场收缩动画、渐隐渐显与控件过渡。
- 🧩 **完整控件**：开关、滑块、多选下拉、颜色选择器、按钮、文本段落等，统一回调与 getter 接口；按钮带按压缩放与压暗反馈。
- 🔔 **全局通知**：右上角堆叠通知，左边缘蓝白渐变条贴齐边框，圆角裁剪，支持多种类型着色。
- 🛡️ **输入隔离**：全屏透明拦截层吸收空白处点击 / 触摸，防止穿透到 Roblox 游戏世界，不影响窗口内控件交互。
- 🔐 **登录启动页**：可选启动页，头像 / 用户名 / 加载按钮居中，加载动画结束后切入主界面。
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
    Background = "https://raw.githubusercontent.com/WasKKal/Axiom-UI-Library/main/axiom-background.jpg",
})

local Tab = Win:AddTab("General", "settings")
Tab:AddToggle({ Title = "Master Switch", Default = true, Callback = function(v) print(v) end })
Tab:AddSlider({ Title = "Walk Speed", Min = 0, Max = 200, Default = 65 })

Axiom.Notify({ Title = "系统就绪", Text = "已加载完成", Type = "success", Duration = 5 })
```

直接运行 `Axiom_Example.lua` 可查看完整演示（内置 raw / jsdelivr 双 CDN 回退）。

## 🗂️ API 一览

| 接口 | 说明 |
| --- | --- |
| `Axiom.CreateWindow(opts)` | 创建窗口，`opts`：`Title`、`Info`、`Background`、`LoginInfo`、`LoginTitle`、`OnLoadScript` |
| `Window:AddTab(name, icon)` | 添加选项卡，返回 `Tab` |
| `Window:AddLoginParagraph(o)` | 启动页添加整行段落 |
| `Window:ShowNotify(o)` | 窗口内右下角简易通知 |
| `Axiom.Notify(o)` | 全局堆叠通知，`o`：`Title`、`Text`/`Info`、`Duration`、`Type`；返回 `{ Frame, Dismiss() }` |
| `Axiom.GetLucideCacheDir()` | 图标缓存目录 |
| `Axiom.GetLucideModulePath()` | 图标缓存模块路径 |
| `Axiom.GetLucideSource()` | 图标首次加载来源 |

### Tab 控件

| 方法 | 说明 |
| --- | --- |
| `AddToggle(o)` | 开关 |
| `AddSlider(o)` | 滑块 |
| `AddDropdown(o)` | 下拉选择，`Multi = true` 开启多选 |
| `AddColorPicker(o)` | 颜色选择器 |
| `AddButton(o)` | 按钮 |
| `AddParagraph(o)` | 文本段落 |

控件对象统一提供 `SetValue` / `Set` / `Get` / `Callback` 等方法，下拉另含 `Select` / `ClearSelection` / `IsSelected`。

## 🎯 设计理念

- **主从分栏**：以信息层级为核心，左侧导航、右侧内容，控件沿统一栅格对齐，保持一致与克制。
- **动效克制**：入场、过渡、通知均有动画，但服务于层级表达而非装饰，动画失败时自动兜底直接赋值。
- **图标即用**：图标名即 Lucide 名，支持直接传 `http(s)://` 图片 URL，解析失败不阻断界面创建。

## 📄 许可证

本项目基于 [MIT License](./LICENSE) 开源。

---

<p align="center">Made with ❤️ by Axiom</p>
