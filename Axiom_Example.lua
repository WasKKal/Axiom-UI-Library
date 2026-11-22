local LIB_URLS = {
    "https://raw.githubusercontent.com/WasKKal/Axiom-UI-Library/main/Axiom.lua",
    "https://cdn.jsdelivr.net/gh/WasKKal/Axiom-UI-Library@main/Axiom.lua",
}
local Axiom = nil
local failReason = nil
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
    if ok then
        if failReason == nil then failReason = "库返回内容无效" end
    else
        failReason = tostring(mod)
    end
end
if not Axiom then
    warn("[Axiom] 加载库失败：" .. tostring(failReason or "未知原因"))
    return
end

-- 单个窗口：LoginInfo 启动页与选项卡主 UI 共存。
-- 加载脚本后淡出登录层，露出同一个窗口的选项卡；最小化/展开/关闭都只作用于这一个窗口。
-- 标题栏第三个绿色球：点击唤出设置面板（左侧更新日志 + 右侧账号信息/窗口比例），"应用修改"保存并弹出通知。
local Win = Axiom.CreateWindow({
    Title = "AXIOM",
    Folder = "AxiomDemo",
    LoginInfo = true,
    LoginTitle = "版本更新日志",
    Background = "https://raw.githubusercontent.com/WasKKal/Axiom-UI-Library/main/axiom-background.jpg",
    -- 多语言：Lang 为默认语言（缺省 zh），Languages 追加可选语言，Locales 追加或覆盖词条。
    Lang = "zh",
    Languages = { { Code = "ja", Label = "日本語" } },
    Locales = {
        en = { ["demo.master"] = "Master Switch", ["demo.masterDesc"] = "Enable all features" },
        ja = { ["demo.master"] = "メインスイッチ" },
    },
    -- KeySystem 演示：输入框占位文字可改；点击左侧 user-key 图标可自定义行为（这里演示复制卡密到剪贴板）。
    -- 正式使用时把 KeyCheck 换成自己的后端接口，或写 KeyAPI = { Provider = "Luarmor", ScriptId = "..." }。
    KeySystem = true,
    KeyPlaceholder = "输入 AXIOM-DEMO 解锁",
    KeyDefault = "",
    OnKeyIconClick = function(win, input)
        local txt = tostring(input and input.Text or "")
        local done = false
        pcall(function()
            if type(setclipboard) == "function" then
                setclipboard(txt); done = true
            elseif type(toclipboard) == "function" then
                toclipboard(txt); done = true
            end
        end)
        Axiom.Notify({
            Title = "卡密",
            Text = done and "卡密已复制到剪贴板" or "复制失败，请手动选择文本",
            Type = done and "success" or "warning",
            Duration = 2.5,
        })
    end,
    KeyCheck = function(key, resolve)
        if string.upper(key) == "AXIOM-DEMO" then
            resolve(true, "验证成功", { plan = "demo" })
        else
            resolve(false, "密钥无效，请输入 AXIOM-DEMO")
        end
    end,
    OnLoadScript = function() print("load script -> main UI") end,
})

-- Config：给控件加 ConfigKey 后即可用 Win:SaveConfig / LoadConfig 存取
-- 例：Win:SaveConfig("Preset1"); Win:LoadConfig("Preset1"); Win:GetConfigs()

-- ===== 通知快捷封装：控件回调触发右上角堆叠通知 =====
local function toast(title, text, typ)
    Axiom.Notify({ Title = title, Text = text, Type = typ or "info", Duration = 3 })
end

-- ===== 主 UI 选项卡（加载脚本后显示）=====
local Tab = Win:AddTab("General", "settings")
Tab:AddParagraph({
    Title = "Overview", Desc = "Layout & typography preview", Icon = "align-left",
    Text = "主从分栏布局：左侧文字菜单，右侧表格化对齐控件。",
})
Tab:AddToggle({
    Title = "主开关", TitleKey = "demo.master",
    Desc = "启用全部功能", DescKey = "demo.masterDesc",
    Icon = "toggle-right", Default = true, ConfigKey = "master",
    Callback = function(v) toast("主开关", "已" .. (v and "启用" or "关闭") .. "全部功能", v and "success" or "warning") end,
})
local Slider = Tab:AddSlider({
    Title = "Walk Speed", Desc = "移动速度", Icon = "gauge",
    Min = 0, Max = 200, Default = 65, ConfigKey = "speed",
    Callback = function(v) toast("移动速度", "当前速度：" .. tostring(v), "info") end,
})
local Dropdown = Tab:AddDropdown({
    Title = "Theme Preset", Desc = "主题预设", Icon = "list-filter",
    Multi = true, Options = { "Default", "Neon", "Minimal", "Retro", "Mono" },
    Default = { "Neon", "Retro" }, ConfigKey = "theme",
    Callback = function(list) toast("主题预设", "已选 " .. table.concat(list, "、"), "success") end,
})
Tab:AddColorPicker({
    Title = "Accent Color", Desc = "强调色", Icon = "palette",
    Default = Color3.fromRGB(88, 150, 255), ConfigKey = "accent",
    Callback = function(c) toast("强调色", "RGB(" .. math.floor(c.R * 255) .. ", " .. math.floor(c.G * 255) .. ", " .. math.floor(c.B * 255) .. ")", "info") end,
})
Tab:AddButton({
    Title = "Apply", Desc = "应用设置", Icon = "send",
    Callback = function() toast("应用成功", "所有设置已保存并生效", "success") end,
})
Slider:SetValue(120)
Dropdown:Select("Mono", true)

local TabVisual = Win:AddTab("Appearance", "palette")
TabVisual:AddToggle({ Title = "Transparency", Desc = "窗口半透明", Icon = "toggle-right", Default = false,
    Callback = function(v) toast("窗口半透明", v and "已开启" or "已关闭", "info") end })
TabVisual:AddSlider({ Title = "Corner Radius", Desc = "圆角大小", Icon = "gauge", Min = 0, Max = 24, Default = 12,
    Callback = function(v) toast("圆角大小", "半径：" .. tostring(v) .. "px", "info") end })
TabVisual:AddDropdown({
    Title = "Font Style", Desc = "字体风格", Icon = "list-filter",
    Options = { "Source Sans", "Gotham", "Roboto", "Arial", "Verdana", "Segoe UI", "Comic Sans" },
    Default = "Gotham",
    Callback = function(v) toast("字体风格", "已切换为 " .. tostring(v), "success") end,
})
TabVisual:AddColorPicker({ Title = "Highlight", Desc = "高亮颜色", Icon = "palette", Default = Color3.fromRGB(76, 209, 153),
    Callback = function() toast("高亮颜色", "高亮色已更新", "success") end })

local TabSystem = Win:AddTab("System", "monitor")
TabSystem:AddToggle({ Title = "Auto Launch", Desc = "启动时自动运行", Icon = "toggle-right", Default = true,
    Callback = function(v) toast("自动运行", v and "开机自启已开启" or "开机自启已关闭", v and "success" or "warning") end })
TabSystem:AddToggle({ Title = "Notifications", Desc = "启用通知", Icon = "bell", Default = true,
    Callback = function(v) toast("通知开关", v and "通知已启用" or "通知已静音", "info") end })
TabSystem:AddSlider({ Title = "Refresh Rate", Desc = "刷新频率", Icon = "gauge", Min = 30, Max = 240, Default = 60,
    Callback = function(v) toast("刷新频率", tostring(v) .. " Hz", "info") end })
TabSystem:AddDropdown({
    Title = "Language", Desc = "界面语言", Icon = "list-filter", Multi = true,
    Options = { "简体中文", "English", "日本語", "Français" }, Default = { "简体中文" },
    Callback = function(list) toast("界面语言", "已切换 " .. table.concat(list, "、"), "success") end,
})

local TabAbout = Win:AddTab("About", "circle-help")
TabAbout:AddParagraph({ Title = "Axiom UI Library", Desc = "关于", Icon = "align-left",
    Text = "主从分栏布局 · Lucide 本地缓存 · 多选下拉 · 全窗口渐隐。滚动容器支持竖向滚动，下拉菜单可溢出窗口。" })
TabAbout:AddButton({ Title = "GitHub", Desc = "打开仓库", Icon = "send",
    Callback = function() toast("仓库地址", "github.com/WasKKal/Axiom-UI-Library", "info") end })

-- ===== 启动页更新日志（进入脚本时显示）=====
Win:AddLoginParagraph({
    Title = "v1.0.0", Icon = "align-left",
    Text = "春日的清晨总是格外温柔，街角面包店飘出刚出炉的可颂香气，路边的樱花树下有几只麻雀在嬉戏，远处钟楼敲响了八下，提醒人们新的一天开始了。",
})
Win:AddLoginParagraph({
    Title = "v1.0.1", Icon = "sparkles",
    Text = "上周去了一趟海边，浪花拍打着礁石发出阵阵轰鸣，夕阳把整片海面染成金红色，我沿着沙滩捡了许多漂亮的贝壳，准备带回去送给朋友们当作纪念。",
})
Win:AddLoginParagraph({
    Title = "v1.0.2", Icon = "align-left",
    Text = "巷子里的那只橘猫最近成了街坊们的团宠，每天蹲在杂货铺门口晒太阳，有人投喂它小鱼干，它就眯起眼睛发出满足的呼噜声，模样十分惬意又可爱。",
})
Win:AddLoginParagraph({
    Title = "v1.0.3", Icon = "sparkles",
    Text = "今年第一场雪来得比往年更早，屋檐下挂满晶莹的冰棱，孩子们在院子里堆起一个大雪人，还给它戴上旧帽子和围巾，看起来滑稽极了，逗得路人直笑。",
})
Win:AddLoginParagraph({
    Title = "v1.0.4", Icon = "align-left",
    Text = "周末逛了逛老城区的新华书店，淘到几本绝版的旧书，纸张泛黄却带着淡淡墨香，店员还贴心地用牛皮纸帮我包好了书脊，让我有种淘到宝的欣喜。",
})
Win:AddLoginParagraph({
    Title = "v1.0.5", Icon = "sparkles",
    Text = "深夜的城市褪去了白日喧嚣，路灯把行人的影子拉得很长，便利店里的关东煮冒着热气，我买了一杯热可可捧在手心，慢慢走回家享受这份久违宁静。",
})

-- ===== Notify 演示：右上角堆叠、固定 250x30 紧凑框架、左边缘指示条按主色自适应(蓝/绿/黄/红白)、滑入/上移补位/滑出动画 =====
Axiom.Notify({ Title = "系统就绪", Text = "Axiom UI Library 已加载，图标缓存于 lucide-icon-latest/", Type = "info", Duration = 5 })
Axiom.Notify({ Title = "多选下拉", Text = "支持多选、限高滚动与触摸防穿透。", Type = "success", Duration = 6 })
Axiom.Notify({ Title = "提示", Text = "右上角堆叠，到期后其余通知自动上移补位。", Type = "warning", Duration = 7 })
Axiom.Notify({ Title = "错误", Text = "指示条随主色自适应：红边框即红白指示条。", Type = "error", Duration = 8 })
Axiom.Notify({ Title = "自定义颜色", Text = "传入 Color 可指定主色，指示条与边框同步。", Color = Color3.fromRGB(200, 30, 180), Duration = 9 })
