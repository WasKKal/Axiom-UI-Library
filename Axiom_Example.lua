local LIB_URLS = {
    "https://raw.githubusercontent.com/WasKKal/Axiom-UI-Library/main/Axiom.lua",
    "https://cdn.jsdelivr.net/gh/WasKKal/Axiom-UI-Library@main/Axiom.lua",
}
local Axiom = nil
for _, url in ipairs(LIB_URLS) do
    local ok, mod = pcall(function()
        local src = game:HttpGet(url)
        if type(src) ~= "string" or #src < 1000 then return nil end
        local fn = loadstring(src)
        if not fn then return nil end
        return fn()
    end)
    if ok and type(mod) == "table" and type(mod.CreateWindow) == "function" then
        Axiom = mod
        break
    end
end
if not Axiom then
    warn("[Axiom] 加载库失败，请检查网络或仓库地址")
    return
end

-- 单个窗口：LoginInfo 启动页与选项卡主 UI 共存。
-- 加载脚本后淡出登录层，露出同一个窗口的选项卡；最小化/展开/关闭都只作用于这一个窗口。
local Win = Axiom.CreateWindow({
    Title = "AXIOM",
    LoginInfo = true,
    LoginTitle = "版本更新日志",
    Background = "https://raw.githubusercontent.com/WasKKal/Axiom-UI-Library/main/axiom-background.jpg",
    OnLoadScript = function() print("load script -> main UI") end,
})

-- ===== 主 UI 选项卡（加载脚本后显示）=====
local Tab = Win:AddTab("General", "settings")
Tab:AddParagraph({
    Title = "Overview", Desc = "Layout & typography preview", Icon = "align-left",
    Text = "主从分栏布局：左侧文字菜单，右侧表格化对齐控件。",
})
Tab:AddToggle({
    Title = "Master Switch", Desc = "启用全部功能", Icon = "toggle-right", Default = true,
    Callback = function(v) print("toggle ->", v) end,
})
local Slider = Tab:AddSlider({
    Title = "Walk Speed", Desc = "移动速度", Icon = "gauge",
    Min = 0, Max = 200, Default = 65,
    Callback = function(v) print("slider ->", v) end,
})
local Dropdown = Tab:AddDropdown({
    Title = "Theme Preset", Desc = "主题预设", Icon = "list-filter",
    Multi = true, Options = { "Default", "Neon", "Minimal", "Retro", "Mono" },
    Default = { "Neon", "Retro" },
    Callback = function(list) print("dropdown ->", table.concat(list, ",")) end,
})
Tab:AddColorPicker({
    Title = "Accent Color", Desc = "强调色", Icon = "palette",
    Default = Color3.fromRGB(88, 150, 255),
    Callback = function(c) print("color ->", c) end,
})
Tab:AddButton({
    Title = "Apply", Desc = "应用设置", Icon = "send",
    Callback = function() print("apply clicked") end,
})
Slider:SetValue(120)
Dropdown:Select("Mono", true)

local TabVisual = Win:AddTab("Appearance", "palette")
TabVisual:AddToggle({ Title = "Transparency", Desc = "窗口半透明", Icon = "toggle-right", Default = false })
TabVisual:AddSlider({ Title = "Corner Radius", Desc = "圆角大小", Icon = "gauge", Min = 0, Max = 24, Default = 12 })
TabVisual:AddDropdown({
    Title = "Font Style", Desc = "字体风格", Icon = "list-filter",
    Options = { "Source Sans", "Gotham", "Roboto", "Arial", "Verdana", "Segoe UI", "Comic Sans" },
    Default = "Gotham",
})
TabVisual:AddColorPicker({ Title = "Highlight", Desc = "高亮颜色", Icon = "palette", Default = Color3.fromRGB(76, 209, 153) })

local TabSystem = Win:AddTab("System", "monitor")
TabSystem:AddToggle({ Title = "Auto Launch", Desc = "启动时自动运行", Icon = "toggle-right", Default = true })
TabSystem:AddToggle({ Title = "Notifications", Desc = "启用通知", Icon = "bell", Default = true })
TabSystem:AddSlider({ Title = "Refresh Rate", Desc = "刷新频率", Icon = "gauge", Min = 30, Max = 240, Default = 60 })
TabSystem:AddDropdown({
    Title = "Language", Desc = "界面语言", Icon = "list-filter", Multi = true,
    Options = { "简体中文", "English", "日本語", "Français" }, Default = { "简体中文" },
})

local TabAbout = Win:AddTab("About", "circle-help")
TabAbout:AddParagraph({ Title = "Axiom UI Library", Desc = "关于", Icon = "align-left",
    Text = "主从分栏布局 · Lucide 本地缓存 · 多选下拉 · 全窗口渐隐。滚动容器支持竖向滚动，下拉菜单可溢出窗口。" })
TabAbout:AddButton({ Title = "GitHub", Desc = "打开仓库", Icon = "send",
    Callback = function() print("https://github.com/WasKKal/Axiom-UI-Library") end })

-- ===== 启动页更新日志（进入脚本时显示）=====
Win:AddLoginParagraph({
    Title = "v1.0.0", Icon = "align-left",
    Text = "重构主从分栏布局，新增 Lucide 本地图标缓存；下拉菜单支持多选并允许溢出窗口，选项卡加入蓝白渐变指示条与切换伸缩动画。",
})
Win:AddLoginParagraph({
    Title = "v1.0.0", Icon = "sparkles",
    Text = string.rep("新增全局 Notify 通知系统：照抄 WasUI-Pro 风格，右上角堆叠、固定 250x30 紧凑框架、左边缘蓝白渐变条、滑入与退场动画；黄点可最小化窗口，标题栏支持拖动。", 2),
})
Win:AddLoginParagraph({
    Title = "v1.0.0", Icon = "align-left",
    Text = "修复最小化后功能区发白、收起残留长条、隐藏圆点仍可交互等问题；边框加深，控件标题与描述排版更紧凑。",
})

-- ===== Notify 演示：照抄 WasUI-Pro 风格——右上角堆叠、固定 250x30 紧凑框架、左边缘蓝白渐变条、滑入/上移补位/滑出动画 =====
Axiom.Notify({ Title = "系统就绪", Text = "Axiom UI Library 已加载，图标缓存于 lucide-icon-latest/", Type = "info", Duration = 5 })
Axiom.Notify({ Title = "多选下拉", Text = "支持多选、限高滚动与触摸防穿透。", Type = "success", Duration = 6 })
Axiom.Notify({ Title = "提示", Text = "右上角堆叠，到期后其余通知自动上移补位。", Type = "warning", Duration = 7 })
