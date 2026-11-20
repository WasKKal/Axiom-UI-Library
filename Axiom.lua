local LUCIDE_CACHE_DIR = "lucide-icon-latest"
local LUCIDE_MODULE_PATH = LUCIDE_CACHE_DIR .. "/init.lua"
local LucideModule = nil
local LucideCache = {}
local LucideSource = "none"
local LUCIDE_URLS = {
    "https://gcore.jsdelivr.net/gh/WasKKal/DeltaExecutor-UI-Rebuild@lucide-v6/lucide/init.lua",
    "https://cdn.jsdelivr.net/gh/WasKKal/DeltaExecutor-UI-Rebuild@lucide-v6/lucide/init.lua",
    "https://raw.githubusercontent.com/WasKKal/DeltaExecutor-UI-Rebuild@lucide-v6/lucide/init.lua",
}
local function httpGet(url)
    local ok, res = pcall(function()
        if type(_G.httpGet) == "function" then return _G.httpGet(url) end
        if type(request) == "function" then
            local r = request({ Url = url, Method = "GET" })
            return r and (r.Body or r.body)
        end
        if type(syn) == "table" and type(syn.request) == "function" then
            local r = syn.request({ Url = url, Method = "GET" })
            return r and (r.Body or r.body)
        end
        if game and type(game.HttpGet) == "function" then return game:HttpGet(url) end
        return nil
    end)
    return ok and res or nil
end
local function hasFs()
    return type(isfile) == "function" and type(readfile) == "function"
        and type(writefile) == "function" and type(makefolder) == "function"
end
local function moduleFromContent(content)
    if type(content) ~= "string" or #content < 5000 then return nil end
    local ok, fn = pcall(loadstring, content)
    if not ok or not fn then return nil end
    local ok2, mod = pcall(fn)
    if not ok2 or type(mod) ~= "table" or type(mod.GetAsset) ~= "function" then return nil end
    return mod
end
local function writeLocalModule(content)
    if not hasFs() then return end
    pcall(function()
        if type(isfolder) == "function" then
            local ok, ex = pcall(isfolder, LUCIDE_CACHE_DIR)
            if ok and not ex then pcall(makefolder, LUCIDE_CACHE_DIR) end
        else
            pcall(makefolder, LUCIDE_CACHE_DIR)
        end
        pcall(writefile, LUCIDE_MODULE_PATH, content)
    end)
end
local function loadLucide()
    if LucideModule then return LucideModule end
    if hasFs() then
        local ok, ex = pcall(isfile, LUCIDE_MODULE_PATH)
        if ok and ex then
            local ok2, data = pcall(readfile, LUCIDE_MODULE_PATH)
            local mod = moduleFromContent(data)
            if mod then LucideModule = mod; LucideSource = "local"; return mod end
        end
    end
    local content
    for _, url in ipairs(LUCIDE_URLS) do
        local ok, res = pcall(httpGet, url)
        if ok and type(res) == "string" and #res > 5000 then content = res; break end
        if type(task) == "table" and type(task.wait) == "function" then task.wait(0.3) end
    end
    if not content then return nil end
    writeLocalModule(content)
    local mod = moduleFromContent(content)
    if mod then LucideModule = mod; LucideSource = "network" end
    return mod
end
local function markSource()
    local function writeTo(g)
        if type(g) ~= "table" then return false end
        return pcall(function()
            g.AXIOM_LUCIDE_SOURCE = LucideSource
            g.AXIOM_LUCIDE_DIR = LUCIDE_CACHE_DIR
            g.AXIOM_LUCIDE_MODULE_PATH = LUCIDE_MODULE_PATH
        end)
    end
    if type(getgenv) == "function" then
        local ok, g = pcall(getgenv)
        if ok and writeTo(g) then return end
    end
    if type(_G) == "table" then pcall(writeTo, _G) end
    if type(shared) == "table" then pcall(writeTo, shared) end
end
local function resolveIcon(icon)
    if type(icon) ~= "string" or #icon == 0 then return nil end
    if icon:match("^%a[%w+.-]*://") then return { Url = icon } end
    if LucideCache[icon] ~= nil then return LucideCache[icon] end
    local asset = nil
    local mod = loadLucide()
    markSource()
    if mod then
        local ok, a = pcall(mod.GetAsset, icon)
        if ok and a and a.Url then asset = a end
    end
    LucideCache[icon] = asset or false
    return asset
end
local function applyIcon(imageLabel, icon, color)
    local ok, result = pcall(function()
        local asset = resolveIcon(icon)
        if not asset then return false end
        imageLabel.Image = asset.Url
        if asset.ImageRectOffset then
            imageLabel.ImageRectOffset = asset.ImageRectOffset
            imageLabel.ImageRectSize = asset.ImageRectSize
        end
        imageLabel.ImageColor3 = color or Color3.new(1, 1, 1)
        imageLabel.ScaleType = Enum.ScaleType.Fit
        return true
    end)
    if not ok then return false end
    return result
end
local DEFAULT_ICONS = {
    Toggle = "toggle-right", Button = "send", Slider = "gauge",
    Dropdown = "list-filter", Paragraph = "align-left", ColorPicker = "palette",
    General = "sliders-horizontal", Visual = "palette", System = "monitor",
}
local function resolveHolder()
    local function try(fn)
        local ok, v = pcall(fn)
        if ok and v ~= nil then return v end
        return nil
    end
    if type(gethui) == "function" then
        local h = try(gethui); if h then return h end
    end
    if type(get_hidden_gui) == "function" then
        local h = try(get_hidden_gui); if h then return h end
    end
    local h = try(function()
        local lp = game:GetService("Players").LocalPlayer
        if not lp then return nil end
        if lp.PlayerGui then return lp.PlayerGui end
        return nil
    end)
    if not h then h = try(function()
        local lp = game:GetService("Players").LocalPlayer
        if not lp then return nil end
        if lp.FindFirstChild then local pg = lp:FindFirstChild("PlayerGui"); if pg then return pg end end
        if lp.WaitForChild then return lp:WaitForChild("PlayerGui", 2) end
        return nil
    end) end
    if h then return h end
    h = try(function() return game:GetService("CoreGui") end); if h then return h end
    return nil
end
local function clamp(v, a, b) return math.max(a, math.min(b, v)) end
local function connect(signal, fn)
    if not signal then return end
    pcall(function() signal:Connect(fn) end)
end
local function emit(obj, value)
    if type(obj._cb) == "function" then pcall(obj._cb, value) end
end
local strokeBase = setmetatable({}, { __mode = "k" })
local function collectStrokes(root, out)
    out = out or {}
    if not root then return out end
    local function walk(o)
        if not o then return end
        local ok, kids = pcall(function() return o:GetChildren() end)
        if ok and type(kids) == "table" then
            for _, c in ipairs(kids) do
                local okCls, cls = pcall(function() return c.ClassName end)
                if okCls and cls == "UIStroke" then
                    if strokeBase[c] == nil then
                        local okT, t = pcall(function() return c.Transparency end)
                        strokeBase[c] = okT and type(t) == "number" and t or 0
                    end
                    out[#out + 1] = c
                end
                walk(c)
            end
        end
    end
    walk(root)
    return out
end
local function targetStrokeTransparency(base, to)
    local t = clamp(to, 0, 1)
    return base + (1 - base) * t
end
local function fade(cg, to, dur, cb)
    if not cg then return end
    local strokes = collectStrokes(cg)
    local done = false
    pcall(function()
        local ts = game:GetService("TweenService")
        if not ts then return end
        local ti = TweenInfo.new(dur or 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local tw = ts:Create(cg, ti, { GroupTransparency = to })
        if type(cb) == "function" then tw.Completed:Connect(cb) end
        tw:Play()
        for _, s in ipairs(strokes) do
            pcall(function()
                local stw = ts:Create(s, ti, { Transparency = targetStrokeTransparency(strokeBase[s], to) })
                stw:Play()
            end)
        end
        done = true
    end)
    if not done then
        pcall(function() cg.GroupTransparency = to end)
        for _, s in ipairs(strokes) do
            pcall(function() s.Transparency = targetStrokeTransparency(strokeBase[s], to) end)
        end
        if type(cb) == "function" then pcall(cb) end
    end
end
local function fadeAny(o, to, dur, cb)
    if not o then return end
    local isGroup = (o.ClassName == "CanvasGroup")
    local prop = isGroup and "GroupTransparency" or "BackgroundTransparency"
    local strokes = collectStrokes(o)
    local done = false
    pcall(function()
        local ts = game:GetService("TweenService")
        if not ts then return end
        local ti = TweenInfo.new(dur or 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local tw = ts:Create(o, ti, { [prop] = to })
        if type(cb) == "function" then tw.Completed:Connect(cb) end
        tw:Play()
        for _, s in ipairs(strokes) do
            pcall(function()
                local stw = ts:Create(s, ti, { Transparency = targetStrokeTransparency(strokeBase[s], to) })
                stw:Play()
            end)
        end
        done = true
    end)
    if not done then
        pcall(function() o[prop] = to end)
        for _, s in ipairs(strokes) do
            pcall(function() s.Transparency = targetStrokeTransparency(strokeBase[s], to) end)
        end
        if type(cb) == "function" then pcall(cb) end
    end
end
-- 通用补间：对实例 o 的多个属性同时补间到 goal，带 pcall 兜底（失败立即设值）
local function tweenProp(o, goal, dur, cb)
    if not o then return end
    local done = false
    pcall(function()
        local ts = game:GetService("TweenService")
        if not ts then return end
        local ti = TweenInfo.new(dur or 0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local tw = ts:Create(o, ti, goal)
        if type(cb) == "function" then tw.Completed:Connect(cb) end
        tw:Play()
        done = true
    end)
    if not done then
        pcall(function() for k, v in pairs(goal) do o[k] = v end end)
        if type(cb) == "function" then pcall(cb) end
    end
end

local Axiom = {}
Axiom.__index = Axiom
Axiom.GetLucideCacheDir = function() return LUCIDE_CACHE_DIR end
Axiom.GetLucideModulePath = function() return LUCIDE_MODULE_PATH end
Axiom.GetLucideSource = function() return LucideSource end
local C = {
    Bg = Color3.fromRGB(24, 26, 31), Side = Color3.fromRGB(29, 32, 38),
    Panel = Color3.fromRGB(32, 35, 42), Row = Color3.fromRGB(36, 40, 48),
    Line = Color3.fromRGB(52, 57, 67), Text = Color3.fromRGB(232, 236, 243),
    Sub = Color3.fromRGB(144, 152, 166), Accent = Color3.fromRGB(88, 150, 255),
    Accent2 = Color3.fromRGB(120, 190, 255), Green = Color3.fromRGB(76, 209, 153),
    AccentW = Color3.fromRGB(172, 208, 255),
    Track = Color3.fromRGB(58, 63, 74),
}
local FONT = Enum.Font.SourceSans
local FONT_B = Enum.Font.GothamBold
local function inst(cls, parent, props)
    local o = Instance.new(cls)
    if props then for k, v in pairs(props) do o[k] = v end end
    if parent then o.Parent = parent end
    return o
end
local function corner(p, r) return inst("UICorner", p, { CornerRadius = UDim.new(0, r or 12) }) end
local function stroke(p, col, t, a)
    return inst("UIStroke", p, { Color = col or C.Line, Thickness = t or 1, Transparency = a or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
end
local function grad(p, c1, c2, rot)
    return inst("UIGradient", p, { Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, c1), ColorSequenceKeypoint.new(1, c2) }), Rotation = rot or 0 })
end
-- 微弱白色静态渐变：叠加在蓝色之上（白色 0.18 -> 0.02 的透明度渐变）
local function whiteSheen(p, rot)
    return inst("UIGradient", p, {
        Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1, 1, 1)),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0.02) }),
        Rotation = rot or 90,
    })
end
local function label(p, txt, size, col, bold, xal)
    return inst("TextLabel", p, {
        BackgroundTransparency = 1, Text = txt or "", TextSize = size or 14,
        TextColor3 = col or C.Text, Font = bold and FONT_B or FONT,
        TextXAlignment = xal or Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center, RichText = false,
    })
end

function Axiom.CreateWindow(opts)
    opts = opts or {}
    local self = setmetatable({ _rows = 0, _tabs = {}, _activeTab = nil }, Axiom)
    local gui = inst("ScreenGui", nil, { Name = "AxiomUI", ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 100000 })
    local holder = resolveHolder()
    if holder then gui.Parent = holder end
    self.gui = gui
    local W, H = 620, 440
    local SCALE = 0.65
    local main = inst("CanvasGroup", gui, { Name = "Main", Size = UDim2.fromOffset(W, H),
        Position = UDim2.new(0.5, -(W*SCALE)/2, 0.5, -(H*SCALE)/2), BackgroundColor3 = C.Bg,
        BorderSizePixel = 0, ZIndex = 1, GroupTransparency = 1 })
    inst("UIScale", main, { Scale = SCALE })
    corner(main, 12); stroke(main, C.Line, 1, 0.2); self.main = main
    fade(main, 0, 0.35)

    local bar = inst("Frame", main, { Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = C.Side,
        BorderSizePixel = 0, ZIndex = 3 })
    inst("UICorner", bar, { CornerRadius = UDim.new(0, 12) })
    local dots = { Color3.fromRGB(255, 95, 86), Color3.fromRGB(255, 189, 46), Color3.fromRGB(39, 201, 63) }
    for i, col in ipairs(dots) do
        local d = inst("TextButton", bar, { Name = i == 1 and "CloseDot" or "Dot",
            Size = UDim2.fromOffset(11, 11),
            Position = UDim2.fromOffset(16 + (i - 1) * 18, 12), BackgroundColor3 = col, BorderSizePixel = 0,
            Text = "", AutoButtonColor = false, ZIndex = 4 })
        corner(d, 6)
        if i == 1 then
            connect(d.MouseButton1Click, function() self:_openCloseConfirm() end)
        end
    end
    local bt = label(bar, opts.Title or "AXIOM", 12, C.Sub, false, Enum.TextXAlignment.Center)
    bt.Size = UDim2.fromOffset(300, 20); bt.Position = UDim2.new(0.5, -150, 0, 7); bt.ZIndex = 4

    local side = inst("ScrollingFrame", main, { Size = UDim2.fromOffset(176, H - 34),
        Position = UDim2.fromOffset(0, 34), BackgroundColor3 = C.Side, BorderSizePixel = 0, ZIndex = 2,
        ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 3,
        HorizontalScrollBarInset = Enum.ScrollBarInset.None, VerticalScrollBarInset = Enum.ScrollBarInset.None,
        CanvasSize = UDim2.new(0, 0, 0, H - 34), ClipsDescendants = false })
    self._tabCount = 0
    self._side = side

    local detail = inst("ScrollingFrame", main, { Size = UDim2.fromOffset(W - 176, H - 34),
        Position = UDim2.fromOffset(176, 34), BackgroundTransparency = 1, ZIndex = 2,
        ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 3,
        HorizontalScrollBarInset = Enum.ScrollBarInset.None, VerticalScrollBarInset = Enum.ScrollBarInset.None,
        CanvasSize = UDim2.new(0, 0, 0, H - 34), ClipsDescendants = false })
    self.body = detail
    local dh = label(detail, opts.Info or "General", 20, C.Text, true)
    dh.Size = UDim2.fromOffset(400, 28); dh.Position = UDim2.fromOffset(24, 20); dh.ZIndex = 3
    local ds = label(detail, "Manage your workspace preferences and behavior", 11, C.Sub)
    ds.Size = UDim2.fromOffset(385, 20); ds.Position = UDim2.fromOffset(25, 50); ds.ZIndex = 3
    local ddiv = inst("Frame", detail, { Size = UDim2.fromOffset(W - 176 - 48, 1),
        Position = UDim2.fromOffset(24, 80), BackgroundColor3 = C.Line, BorderSizePixel = 0, ZIndex = 3 })

    function self:AddTab(name, icon)
        self._tabCount = self._tabCount + 1
        local i = self._tabCount
        local my = 22 + (i - 1) * 44
        local active = (i == 1)
        local side = self._side
        -- 每个选项卡拥有独立内容容器（挂在 detail 内，与 detail 同坐标系）
        local content = inst("Frame", detail, { Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 2,
            ClipsDescendants = false, Visible = active })
        local bg = inst("Frame", side, { Size = UDim2.fromOffset(160, 34),
            Position = UDim2.fromOffset(8, my - 5), BackgroundColor3 = C.Panel,
            BackgroundTransparency = active and 0.4 or 1, BorderSizePixel = 0, ZIndex = 1 })
        corner(bg, 8)
        -- 蓝白竖向渐变指示条（蓝 -> 白，Rotation=90 竖向）；初始非激活条长度为 0
        local act = inst("Frame", bg, { Size = UDim2.fromOffset(3, active and 26 or 0),
            Position = UDim2.fromOffset(2, 4), BackgroundColor3 = C.Accent,
            BackgroundTransparency = active and 0 or 1, BorderSizePixel = 0, ZIndex = 4 })
        corner(act, 2); grad(act, C.Accent, Color3.new(1, 1, 1), 90)
        side.CanvasSize = UDim2.new(0, 0, 0, math.max(H - 34, my + 40))
        local mi = inst("ImageLabel", side, { Size = UDim2.fromOffset(17, 17),
            Position = UDim2.fromOffset(18, my + 5), BackgroundTransparency = 1, ZIndex = 3 })
        applyIcon(mi, icon or "home", active and C.Accent or C.Sub)
        local mt = label(side, name or ("Tab " .. i), 13, active and C.Text or C.Sub, active)
        mt.Size = UDim2.fromOffset(120, 24); mt.Position = UDim2.fromOffset(44, my); mt.ZIndex = 3
        -- 覆盖整行的透明点击热区
        local hit = inst("TextButton", side, { Size = UDim2.fromOffset(160, 34),
            Position = UDim2.fromOffset(8, my - 5), BackgroundTransparency = 1,
            BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 5 })
        local tab = { _win = self, _name = name, _bg = bg, _act = act, _mi = mi, _mt = mt,
            _content = content, _rows = 0, _lastY = 92 }
        connect(hit.MouseButton1Click, function() self:SelectTab(tab) end)
        self._tabs[#self._tabs + 1] = tab
        if active then self._activeTab = tab end
        function tab:AddToggle(o) return self._win:_row("Toggle", o, self) end
        function tab:AddButton(o) return self._win:_row("Button", o, self) end
        function tab:AddSlider(o) return self._win:_row("Slider", o, self) end
        function tab:AddDropdown(o) return self._win:_row("Dropdown", o, self) end
        function tab:AddParagraph(o) return self._win:_row("Paragraph", o, self) end
        function tab:AddColorPicker(o) return self._win:_row("ColorPicker", o, self) end
        return tab
    end

    function self:SelectTab(tab)
        if not tab or self._activeTab == tab then return end
        self._activeTab = tab
        -- 内容容器显隐 + 滚动高度切到目标 tab
        for _, t in ipairs(self._tabs) do
            if t._content then t._content.Visible = (t == tab) end
        end
        detail.CanvasSize = UDim2.new(0, 0, 0, math.max(H - 34, (tab._lastY or 92) + 60))
        pcall(function() detail.CanvasPosition = UDim2.fromOffset(0, 0) end)
        for _, t in ipairs(self._tabs) do
            local on = (t == tab)
            -- 指示条：新条渐显并伸长到 26；旧条缩短到 0 并渐隐直到消失
            tweenProp(t._act, { Size = UDim2.fromOffset(3, on and 26 or 0),
                BackgroundTransparency = on and 0 or 1 }, on and 0.28 or 0.22)
            -- 高亮背景 + 图标/文字高亮同步
            tweenProp(t._bg, { BackgroundTransparency = on and 0.4 or 1 }, 0.22)
            pcall(function() t._mi.ImageColor3 = on and C.Accent or C.Sub end)
            t._mt.TextColor3 = on and C.Text or C.Sub
            t._mt.Font = on and FONT_B or FONT
        end
        return tab
    end

    function self:_row(kind, o, tab)
        o = o or {}
        local owner = tab or self._activeTab
        local host = (owner and owner._content) or detail
        owner = owner or self
        owner._rows = (owner._rows or 0) + 1
        local y = 92 + (owner._rows - 1) * 52
        owner._lastY = y
        detail.CanvasSize = UDim2.new(0, 0, 0, math.max(H - 34, y + 60))
        local obj = { Value = o.Default, _kind = kind, _cb = nil, _win = self }
        if type(o.Callback) == "function" then obj._cb = o.Callback end
        local iconTop = (kind == "Paragraph") and (y + 21)
            or (((o.Desc ~= nil and o.Desc ~= "") or (o.Info ~= nil and o.Info ~= "")) and (y + 16) or (y + 8))
        local ci = inst("ImageLabel", host, { Size = UDim2.fromOffset(16, 16),
            Position = UDim2.fromOffset(24, iconTop), BackgroundTransparency = 1, ZIndex = 3 })
        applyIcon(ci, o.Icon or DEFAULT_ICONS[kind], C.Sub)
        local tx = label(host, o.Title or kind, 13, C.Text, true)
        tx.Size = UDim2.fromOffset(210, 20); tx.Position = UDim2.fromOffset(46, y + 6); tx.ZIndex = 3
        local sub = label(host, o.Desc or "Axiom setting", 10, C.Sub)
        sub.Size = UDim2.fromOffset(230, 16); sub.Position = UDim2.fromOffset(46, y + 26); sub.ZIndex = 3
        local rx = W - 176 - 24
        if kind == "Paragraph" then
            sub.Text = o.Text or ""; sub.Size = UDim2.new(1, -300, 0, 30)
            sub.Position = UDim2.fromOffset(46, y + 22); sub.TextWrapped = true
            function obj:SetText(v) sub.Text = tostring(v or "") end
            function obj:Get() return sub.Text end
        elseif kind == "Toggle" then
            local on = o.Default and true or false
            local tr = inst("TextButton", host, { Size = UDim2.fromOffset(44, 24),
                Position = UDim2.fromOffset(rx - 44, y + 8), BackgroundColor3 = on and C.Accent or C.Track,
                BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 3 })
            corner(tr, 12)
            local shine = inst("Frame", tr, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1),
                BackgroundTransparency = 0, BorderSizePixel = 0, Visible = on, ZIndex = 3 })
            corner(shine, 12); whiteSheen(shine, 0)
            local kn = inst("Frame", tr, { Size = UDim2.fromOffset(18, 18),
                Position = UDim2.new(on and 1 or 0, on and -21 or 3, 0.5, 0),
                AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0, ZIndex = 4 })
            corner(kn, 9)
            local function refresh()
                local bg = on and C.Accent or C.Track
                local kp = UDim2.new(on and 1 or 0, on and -21 or 3, 0.5, 0)
                shine.Visible = on
                local done = false
                pcall(function()
                    local ts = game:GetService("TweenService")
                    if not ts then return end
                    local ti = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                    ts:Create(tr, ti, { BackgroundColor3 = bg }):Play()
                    ts:Create(kn, ti, { Position = kp }):Play()
                    done = true
                end)
                if not done then
                    tr.BackgroundColor3 = bg
                    kn.Position = kp
                end
            end
            connect(tr.MouseButton1Click, function()
                on = not on; obj.Value = on; refresh(); emit(obj, on)
            end)
            function obj:SetValue(v) on = v and true or false; obj.Value = on; refresh() end
            function obj:Get() return on end
        elseif kind == "Button" then
            local b = inst("TextButton", host, { Size = UDim2.fromOffset(96, 28),
                Position = UDim2.fromOffset(rx - 96, y + 6), BackgroundColor3 = C.Accent,
                BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 3 })
            corner(b, 7)
            local bfill = inst("Frame", b, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Accent,
                BorderSizePixel = 0, ZIndex = 3 })
            corner(bfill, 7); grad(bfill, C.Accent, C.AccentW, 0); whiteSheen(bfill, 0)
            local btxt = label(b, o.Title or "Apply", 12, Color3.new(1, 1, 1), true, Enum.TextXAlignment.Center)
            btxt.Size = UDim2.fromScale(1, 1); btxt.ZIndex = 5
            connect(b.MouseButton1Click, function() emit(obj, nil) end)
            function obj:Fire() emit(obj, nil) end
        elseif kind == "Slider" then
            local minN, maxN = o.Min or 0, o.Max or 100
            local val = o.Default or minN
            local tr = inst("TextButton", host, { Size = UDim2.fromOffset(130, 6),
                Position = UDim2.fromOffset(rx - 176, y + 19), BackgroundColor3 = C.Track,
                BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 3 })
            corner(tr, 3)
            local pct0 = (val - minN) / math.max(1, maxN - minN)
            local fl = inst("Frame", tr, { Size = UDim2.fromScale(clamp(pct0, 0.03, 1), 1),
                BackgroundColor3 = C.Accent, BorderSizePixel = 0, ZIndex = 4 })
            corner(fl, 3)
            local vv = label(host, tostring(math.floor(val)), 12, C.Accent, true, Enum.TextXAlignment.Right)
            vv.Size = UDim2.fromOffset(38, 20); vv.Position = UDim2.fromOffset(rx - 40, y + 12); vv.ZIndex = 3
            local dragging = false
            local function applyVal(v, fire)
                val = clamp(v, minN, maxN)
                local pct = (val - minN) / math.max(1, maxN - minN)
                fl.Size = UDim2.fromScale(clamp(pct, 0.03, 1), 1)
                vv.Text = tostring(math.floor(val)); obj.Value = val
                if fire then emit(obj, val) end
            end
            local function fromInput(input)
                local okX, absX = pcall(function() return input.Position.X end)
                if not okX or not absX then return end
                local okAbs, rel = pcall(function() return tr.AbsolutePosition.X end)
                local okSize, wid = pcall(function() return tr.AbsoluteSize.X end)
                if okAbs and okSize and wid and wid > 0 then
                    applyVal(minN + clamp((absX - rel) / wid, 0, 1) * (maxN - minN), true)
                end
            end
            connect(tr.InputBegan, function(input) dragging = true; fromInput(input) end)
            connect(tr.InputChanged, function(input) if dragging then fromInput(input) end end)
            connect(tr.InputEnded, function() dragging = false end)
            function obj:SetValue(v) applyVal(v, false) end
            function obj:Get() return val end
        elseif kind == "Dropdown" then
            local options = o.Options or {}
            local multi = o.Multi and true or false
            local selected = {}
            if multi then
                local d = o.Default
                if type(d) == "table" then
                    for _, v in ipairs(d) do selected[v] = true end
                elseif type(d) == "string" then selected[d] = true end
            else
                selected[o.Default or options[1]] = true
            end
            local function keys()
                local arr = {}
                for k, v in pairs(selected) do if v and k ~= nil then arr[#arr + 1] = k end end
                table.sort(arr)
                return arr
            end
            local function display()
                local arr = keys()
                if #arr == 0 then return "Select" end
                if not multi then return tostring(arr[1]) end
                if #arr <= 3 then return table.concat(arr, ", ") end
                return tostring(arr[1]) .. ", " .. tostring(arr[2]) .. ", " .. tostring(arr[3]) .. " +" .. (#arr - 3)
            end
            local cap = inst("TextButton", host, { Size = UDim2.fromOffset(140, 28),
                Position = UDim2.fromOffset(rx - 140, y + 6), BackgroundColor3 = C.Panel,
                BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 3 })
            corner(cap, 7); stroke(cap, C.Line, 1, 0)
            local cur = label(cap, display(), 12, C.Text, false, Enum.TextXAlignment.Center)
            cur.Size = UDim2.new(1, -18, 1, 0); cur.ZIndex = 4
            local ar = inst("ImageLabel", cap, { Size = UDim2.fromOffset(13, 13),
                Position = UDim2.new(1, -19, 0.5, -6.5), BackgroundTransparency = 1, ZIndex = 4 })
            applyIcon(ar, "chevron-down", C.Sub)
            local menu = inst("CanvasGroup", main, { Name = "DropMenu", Size = UDim2.fromOffset(140, 8 + #options * 26),
                Position = UDim2.fromOffset(176 + rx - 140, 34 + y + 36), BackgroundColor3 = C.Panel,
                BorderSizePixel = 0, Visible = false, GroupTransparency = 1, ZIndex = 14 })
            corner(menu, 7); stroke(menu, C.Line, 1, 0)
            local checks = {}
            local function refreshChecks()
                for _, opt in ipairs(options) do
                    local ui = checks[opt]
                    if ui then
                        local on = selected[opt] and true or false
                        ui.row.BackgroundColor3 = on and Color3.new(1, 1, 1) or C.Row
                        ui.row.BackgroundTransparency = on and 0.86 or 0
                        ui.txt.TextColor3 = on and Color3.fromRGB(18, 18, 22) or C.Text
                        ui.chk.Visible = on
                        ui.chk.ImageColor3 = on and Color3.fromRGB(18, 18, 22) or C.Accent
                    end
                end
            end
            local function openMenu() menu.Visible = true; fade(menu, 0, 0.18) end
            local function closeMenu() fade(menu, 1, 0.18, function() menu.Visible = false end) end
            for i, opt in ipairs(options) do
                local rb = inst("TextButton", menu, { Size = UDim2.new(1, -8, 0, 22),
                    Position = UDim2.fromOffset(4, 4 + (i - 1) * 26), BackgroundColor3 = C.Row,
                    BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 15 })
                corner(rb, 5)
                local rl = label(rb, tostring(opt), 12, C.Text, false, Enum.TextXAlignment.Center)
                rl.Size = UDim2.new(1, -22, 1, 0); rl.ZIndex = 16
                local chk = inst("ImageLabel", rb, { Name = "checkicon", Size = UDim2.fromOffset(13, 13),
                    Position = UDim2.new(1, -20, 0.5, -6.5), BackgroundTransparency = 1,
                    Visible = false, ZIndex = 17 })
                applyIcon(chk, "check", C.Accent)
                checks[opt] = { row = rb, txt = rl, chk = chk }
                connect(rb.MouseButton1Click, function()
                    if multi then
                        selected[opt] = not selected[opt]
                    else
                        selected = {}; selected[opt] = true; closeMenu()
                    end
                    refreshChecks()
                    cur.Text = display(); obj.Value = multi and keys() or keys()[1]
                    emit(obj, obj.Value)
                end)
            end
            refreshChecks()
            connect(cap.MouseButton1Click, function()
                if menu.Visible then closeMenu() else openMenu() end
            end)
            function obj:Set(v)
                selected = {}
                if multi and type(v) == "table" then
                    for _, x in ipairs(v) do selected[x] = true end
                elseif v ~= nil then selected[tostring(v)] = true end
                refreshChecks(); cur.Text = display(); obj.Value = multi and keys() or keys()[1]
            end
            function obj:Get() return multi and keys() or keys()[1] end
            function obj:Select(name, on)
                selected[name] = (on == nil) and true or (on and true or false)
                refreshChecks(); cur.Text = display(); obj.Value = multi and keys() or keys()[1]
            end
            function obj:IsSelected(name) return selected[name] and true or false end
            function obj:ClearSelection()
                selected = {}; refreshChecks(); cur.Text = display(); obj.Value = multi and {} or nil
            end
        elseif kind == "ColorPicker" then
            local cur = o.Default or C.Accent
            local sw = inst("TextButton", host, { Size = UDim2.fromOffset(42, 24),
                Position = UDim2.fromOffset(rx - 42, y + 7), BackgroundColor3 = cur,
                BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 3 })
            corner(sw, 6); stroke(sw, C.Line, 1, 0)
            local palette = inst("CanvasGroup", main, { Name = "ColorPalette", Size = UDim2.fromOffset(150, 36),
                Position = UDim2.fromOffset(176 + rx - 150, 34 + y + 36), BackgroundColor3 = C.Panel,
                BorderSizePixel = 0, Visible = false, GroupTransparency = 1, ZIndex = 14 })
            corner(palette, 8); stroke(palette, C.Line, 1, 0)
            local function openPalette() palette.Visible = true; fade(palette, 0, 0.18) end
            local function closePalette() fade(palette, 1, 0.18, function() palette.Visible = false end) end
            local function tweenSwatch(target)
                local done = false
                pcall(function()
                    local ts = game:GetService("TweenService")
                    if not ts then return end
                    local ti = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                    ts:Create(sw, ti, { BackgroundColor3 = target }):Play()
                    done = true
                end)
                if not done then pcall(function() sw.BackgroundColor3 = target end) end
            end
            local swatches = { C.Accent, Color3.fromRGB(94, 234, 212), C.Green,
                Color3.fromRGB(255, 189, 46), Color3.fromRGB(255, 95, 86), C.Text }
            for i, col in ipairs(swatches) do
                local b = inst("TextButton", palette, { Size = UDim2.fromOffset(18, 18),
                    Position = UDim2.fromOffset(8 + (i - 1) * 23, 9), BackgroundColor3 = col,
                    BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 15 })
                corner(b, 5)
                connect(b.MouseButton1Click, function()
                    cur = col; tweenSwatch(cur); obj.Value = cur
                    closePalette(); emit(obj, cur)
                end)
            end
            connect(sw.MouseButton1Click, function()
                if palette.Visible then closePalette() else openPalette() end
            end)
            function obj:SetValue(v) cur = v or C.Accent; tweenSwatch(cur); obj.Value = cur end
            function obj:Get() return cur end
        end
        function obj:Callback(fn) obj._cb = fn; return obj end
        return obj
    end

    function self:ShowNotify(o)
        o = o or {}
        local toast = inst("CanvasGroup", main, { Size = UDim2.fromOffset(260, 60),
            Position = UDim2.new(1, -280, 1, -78), BackgroundColor3 = C.Panel,
            BorderSizePixel = 0, GroupTransparency = 1, ZIndex = 20 })
        corner(toast, 10); stroke(toast, C.Accent, 1.5, 0.3)
        fade(toast, 0, 0.25)
        local ni = inst("ImageLabel", toast, { Size = UDim2.fromOffset(20, 20),
            Position = UDim2.fromOffset(12, 11), BackgroundTransparency = 1, ZIndex = 22 })
        applyIcon(ni, "bell", C.Accent)
        local t = label(toast, o.Title or "Axiom", 14, C.Text, true)
        t.Size = UDim2.fromOffset(200, 22); t.Position = UDim2.fromOffset(40, 9); t.ZIndex = 21
        local s = label(toast, o.Info or "", 11, C.Sub)
        s.Size = UDim2.fromOffset(230, 20); s.Position = UDim2.fromOffset(12, 34); s.ZIndex = 21
        if type(task) == "table" and type(task.delay) == "function" then
            pcall(task.delay, o.Duration or 3, function()
                fade(toast, 1, 0.3, function() if toast.Parent then toast:Destroy() end end)
            end)
        end
        return toast
    end

    local confirm = inst("CanvasGroup", main, { Name = "CloseConfirm", Size = UDim2.fromOffset(300, 168),
        Position = UDim2.new(0.5, -150, 0.5, -84), BackgroundColor3 = C.Panel,
        BorderSizePixel = 0, GroupTransparency = 1, Visible = false, ZIndex = 46 })
    corner(confirm, 12); stroke(confirm, C.Line, 1, 0.15); self._confirm = confirm
    local qi = inst("ImageLabel", confirm, { Size = UDim2.fromOffset(22, 22),
        Position = UDim2.fromOffset(18, 16), BackgroundTransparency = 1, ZIndex = 48 })
    applyIcon(qi, "circle-help", C.Accent)
    local qt = label(confirm, "你要关闭这个脚本吗？", 15, C.Text, true)
    qt.Size = UDim2.fromOffset(250, 26); qt.Position = UDim2.fromOffset(48, 14); qt.ZIndex = 48
    local qd = label(confirm, "关闭后界面将被销毁，需重新运行脚本。", 11, C.Sub)
    qd.Size = UDim2.fromOffset(260, 20); qd.Position = UDim2.fromOffset(18, 42); qd.ZIndex = 48
    local function confirmBtn(txt, y, c1, c2, danger)
        local b = inst("TextButton", confirm, { Size = UDim2.fromOffset(264, 40),
            Position = UDim2.fromOffset(18, y), BackgroundColor3 = c1,
            BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 48 })
        corner(b, 8)
        local fill = inst("Frame", b, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = c1,
            BorderSizePixel = 0, ZIndex = 48 })
        corner(fill, 8); grad(fill, c1, c2, 0)
        local tx = label(b, txt, 13, Color3.new(1, 1, 1), true, Enum.TextXAlignment.Center)
        tx.Size = UDim2.fromScale(1, 1); tx.ZIndex = 49
        return b, tx
    end
    local yesBtn = confirmBtn("关闭窗口", 72, Color3.fromRGB(214, 62, 62), Color3.fromRGB(150, 34, 34), true)
    local noBtn = confirmBtn("取消", 120, C.Track, C.Row, false)
    local shade = inst("TextButton", main, { Name = "CloseShade", Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1,
        BorderSizePixel = 0, Text = "", AutoButtonColor = false, Visible = false, ZIndex = 45 })
    corner(shade, 12)
    self._shade = shade

    local function hideConfirm()
        fade(confirm, 1, 0.18, function() confirm.Visible = false end)
        fadeAny(shade, 1, 0.18, function() shade.Visible = false end)
    end
    function self:_openCloseConfirm()
        shade.Visible = true; confirm.Visible = true
        fadeAny(shade, 0.55, 0.2)
        fade(confirm, 0, 0.22)
    end
    function self:_closeWindow()
        fade(confirm, 1, 0.2, function() confirm.Visible = false end)
        fadeAny(shade, 1, 0.2, function() shade.Visible = false end)
        fade(main, 1, 0.35, function()
            pcall(function() if self.gui and self.gui.Parent then self.gui:Destroy() end end)
        end)
    end
    connect(noBtn.MouseButton1Click, function() hideConfirm() end)
    connect(yesBtn.MouseButton1Click, function() self:_closeWindow() end)
    connect(shade.MouseButton1Click, function() hideConfirm() end)
    return self
end
return Axiom
