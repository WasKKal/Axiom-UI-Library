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

local Win = Axiom.CreateWindow({
    Title = "AXIOM",
    Info  = "General",
})
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
Win:ShowNotify({ Title = "Ready", Info = "Axiom UI Library · 图标缓存于 lucide-icon-latest/" })
