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
    local self = setmetatable({ _rows = 0 }, Axiom)
    local gui = inst("ScreenGui", nil, { Name = "AxiomUI", ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 100000 })
    local holder = resolveHolder()
    if holder then gui.Parent = holder end
    self.gui = gui
    local W, H = 620, 440
    local main = inst("Frame", gui, { Name = "Main", Size = UDim2.fromOffset(W, H),
        Position = UDim2.new(0.5, -W/2, 0.5, -H/2), BackgroundColor3 = C.Bg,
        BorderSizePixel = 0, ZIndex = 1 })
    corner(main, 12); stroke(main, C.Line, 1, 0.2); self.main = main

    local bar = inst("Frame", main, { Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = C.Side,
        BorderSizePixel = 0, ZIndex = 3 })
    inst("UICorner", bar, { CornerRadius = UDim.new(0, 12) })
    for i, col in ipairs({ Color3.fromRGB(255, 95, 86), Color3.fromRGB(255, 189, 46), Color3.fromRGB(39, 201, 63) }) do
        local d = inst("Frame", bar, { Size = UDim2.fromOffset(11, 11),
            Position = UDim2.fromOffset(16 + (i - 1) * 18, 12), BackgroundColor3 = col, BorderSizePixel = 0, ZIndex = 4 })
        corner(d, 6)
    end
    local bt = label(bar, opts.Title or "AXIOM", 12, C.Sub, false, Enum.TextXAlignment.Center)
    bt.Size = UDim2.fromOffset(300, 20); bt.Position = UDim2.new(0.5, -150, 0, 7); bt.ZIndex = 4

    local side = inst("Frame", main, { Size = UDim2.fromOffset(176, H - 34),
        Position = UDim2.fromOffset(0, 34), BackgroundColor3 = C.Side, BorderSizePixel = 0, ZIndex = 2 })
    local menu = { { "home", "General" }, { "palette", "Appearance" },
        { "monitor", "System" }, { "info", "About" } }
    for i, m in ipairs(menu) do
        local my = 22 + (i - 1) * 44
        local mi = inst("ImageLabel", side, { Size = UDim2.fromOffset(17, 17),
            Position = UDim2.fromOffset(18, my + 5), BackgroundTransparency = 1, ZIndex = 3 })
        applyIcon(mi, m[1], i == 1 and C.Accent or C.Sub)
        local mt = label(side, m[2], 13, i == 1 and C.Text or C.Sub, i == 1)
        mt.Size = UDim2.fromOffset(120, 24); mt.Position = UDim2.fromOffset(44, my); mt.ZIndex = 3
        if i == 1 then
            local act = inst("Frame", side, { Size = UDim2.fromOffset(3, 26),
                Position = UDim2.fromOffset(0, my - 1), BackgroundColor3 = C.Accent, BorderSizePixel = 0, ZIndex = 4 })
            corner(act, 2)
            local bg = inst("Frame", side, { Size = UDim2.fromOffset(160, 34),
                Position = UDim2.fromOffset(8, my - 5), BackgroundColor3 = C.Panel,
                BackgroundTransparency = 0.4, BorderSizePixel = 0, ZIndex = 1 })
            corner(bg, 8)
            bg.Parent = side
        end
    end

    local detail = inst("Frame", main, { Size = UDim2.fromOffset(W - 176, H - 34),
        Position = UDim2.fromOffset(176, 34), BackgroundTransparency = 1, ZIndex = 2 })
    self.body = detail
    local dh = label(detail, opts.Info or "General", 20, C.Text, true)
    dh.Size = UDim2.fromOffset(400, 28); dh.Position = UDim2.fromOffset(24, 20); dh.ZIndex = 3
    local ds = label(detail, "Manage your workspace preferences and behavior", 11, C.Sub)
    ds.Size = UDim2.fromOffset(440, 20); ds.Position = UDim2.fromOffset(25, 50); ds.ZIndex = 3
    local ddiv = inst("Frame", detail, { Size = UDim2.fromOffset(W - 176 - 48, 1),
        Position = UDim2.fromOffset(24, 80), BackgroundColor3 = C.Line, BorderSizePixel = 0, ZIndex = 3 })

    function self:AddTab(name, icon)
        local tab = { _win = self, _name = name }
        function tab:AddToggle(o) return self._win:_row("Toggle", o) end
        function tab:AddButton(o) return self._win:_row("Button", o) end
        function tab:AddSlider(o) return self._win:_row("Slider", o) end
        function tab:AddDropdown(o) return self._win:_row("Dropdown", o) end
        function tab:AddParagraph(o) return self._win:_row("Paragraph", o) end
        function tab:AddColorPicker(o) return self._win:_row("ColorPicker", o) end
        return tab
    end

    function self:_row(kind, o)
        o = o or {}
        self._rows = self._rows + 1
        local y = 92 + (self._rows - 1) * 52
        local obj = { Value = o.Default, _kind = kind, _cb = nil, _win = self }
        if type(o.Callback) == "function" then obj._cb = o.Callback end
        local iconTop = (kind == "Paragraph") and (y + 21)
            or (((o.Desc ~= nil and o.Desc ~= "") or (o.Info ~= nil and o.Info ~= "")) and (y + 16) or (y + 8))
        local ci = inst("ImageLabel", detail, { Size = UDim2.fromOffset(16, 16),
            Position = UDim2.fromOffset(24, iconTop), BackgroundTransparency = 1, ZIndex = 3 })
        applyIcon(ci, o.Icon or DEFAULT_ICONS[kind], C.Sub)
        local tx = label(detail, o.Title or kind, 13, C.Text, true)
        tx.Size = UDim2.fromOffset(210, 20); tx.Position = UDim2.fromOffset(46, y + 6); tx.ZIndex = 3
        local sub = label(detail, o.Desc or "Axiom setting", 10, C.Sub)
        sub.Size = UDim2.fromOffset(230, 16); sub.Position = UDim2.fromOffset(46, y + 26); sub.ZIndex = 3
        local rx = W - 176 - 24
        if kind == "Paragraph" then
            sub.Text = o.Text or ""; sub.Size = UDim2.new(1, -300, 0, 30)
            sub.Position = UDim2.fromOffset(46, y + 22); sub.TextWrapped = true
            function obj:SetText(v) sub.Text = tostring(v or "") end
            function obj:Get() return sub.Text end
        elseif kind == "Toggle" then
            local on = o.Default and true or false
            local tr = inst("TextButton", detail, { Size = UDim2.fromOffset(44, 24),
                Position = UDim2.fromOffset(rx - 44, y + 8), BackgroundColor3 = on and C.Accent or C.Track,
                BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 3 })
            corner(tr, 12)
            local kn = inst("Frame", tr, { Size = UDim2.fromOffset(18, 18),
                Position = UDim2.new(on and 1 or 0, on and -21 or 3, 0.5, 0),
                AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0, ZIndex = 4 })
            corner(kn, 9)
            local function refresh()
                local bg = on and C.Accent or C.Track
                local kp = UDim2.new(on and 1 or 0, on and -21 or 3, 0.5, 0)
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
            local b = inst("TextButton", detail, { Size = UDim2.fromOffset(96, 28),
                Position = UDim2.fromOffset(rx - 96, y + 6), BackgroundColor3 = C.Accent,
                BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 3 })
            corner(b, 7)
            local bfill = inst("Frame", b, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Accent,
                BorderSizePixel = 0, ZIndex = 3 })
            corner(bfill, 7); grad(bfill, C.Accent, C.Accent2, 0)
            local btxt = label(b, o.Title or "Apply", 12, Color3.new(1, 1, 1), true, Enum.TextXAlignment.Center)
            btxt.Size = UDim2.fromScale(1, 1); btxt.ZIndex = 5
            connect(b.MouseButton1Click, function() emit(obj, nil) end)
            function obj:Fire() emit(obj, nil) end
        elseif kind == "Slider" then
            local minN, maxN = o.Min or 0, o.Max or 100
            local val = o.Default or minN
            local tr = inst("TextButton", detail, { Size = UDim2.fromOffset(130, 6),
                Position = UDim2.fromOffset(rx - 176, y + 19), BackgroundColor3 = C.Track,
                BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 3 })
            corner(tr, 3)
            local pct0 = (val - minN) / math.max(1, maxN - minN)
            local fl = inst("Frame", tr, { Size = UDim2.fromScale(clamp(pct0, 0.03, 1), 1),
                BackgroundColor3 = C.Accent, BorderSizePixel = 0, ZIndex = 4 })
            corner(fl, 3)
            local vv = label(detail, tostring(math.floor(val)), 12, C.Accent, true, Enum.TextXAlignment.Right)
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
            local cap = inst("TextButton", detail, { Size = UDim2.fromOffset(140, 28),
                Position = UDim2.fromOffset(rx - 140, y + 6), BackgroundColor3 = C.Panel,
                BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 3 })
            corner(cap, 7); stroke(cap, C.Line, 1, 0)
            local cur = label(cap, display(), 12, C.Text, false, Enum.TextXAlignment.Center)
            cur.Size = UDim2.new(1, -18, 1, 0); cur.ZIndex = 4
            local ar = inst("ImageLabel", cap, { Size = UDim2.fromOffset(13, 13),
                Position = UDim2.new(1, -19, 0.5, -6.5), BackgroundTransparency = 1, ZIndex = 4 })
            applyIcon(ar, "chevron-down", C.Sub)
            local menu = inst("Frame", detail, { Size = UDim2.fromOffset(140, 8 + #options * 26),
                Position = UDim2.fromOffset(rx - 140, y + 36), BackgroundColor3 = C.Panel,
                BorderSizePixel = 0, Visible = false, ZIndex = 14 })
            corner(menu, 7); stroke(menu, C.Line, 1, 0)
            for i, opt in ipairs(options) do
                local rb = inst("TextButton", menu, { Size = UDim2.new(1, -8, 0, 22),
                    Position = UDim2.fromOffset(4, 4 + (i - 1) * 26), BackgroundColor3 = C.Row,
                    BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 15 })
                corner(rb, 5)
                local rl = label(rb, tostring(opt), 12, C.Text, false, Enum.TextXAlignment.Center)
                rl.Size = UDim2.new(1, 0, 1, 0); rl.ZIndex = 16
                connect(rb.MouseButton1Click, function()
                    if multi then
                        selected[opt] = not selected[opt]
                    else
                        selected = {}; selected[opt] = true; menu.Visible = false
                    end
                    cur.Text = display(); obj.Value = multi and keys() or keys()[1]
                    emit(obj, obj.Value)
                end)
            end
            connect(cap.MouseButton1Click, function() menu.Visible = not menu.Visible end)
            function obj:Set(v)
                selected = {}
                if multi and type(v) == "table" then
                    for _, x in ipairs(v) do selected[x] = true end
                elseif v ~= nil then selected[tostring(v)] = true end
                cur.Text = display(); obj.Value = multi and keys() or keys()[1]
            end
            function obj:Get() return multi and keys() or keys()[1] end
            function obj:Select(name, on)
                selected[name] = (on == nil) and true or (on and true or false)
                cur.Text = display(); obj.Value = multi and keys() or keys()[1]
            end
            function obj:IsSelected(name) return selected[name] and true or false end
            function obj:ClearSelection()
                selected = {}; cur.Text = display(); obj.Value = multi and {} or nil
            end
        elseif kind == "ColorPicker" then
            local cur = o.Default or C.Accent
            local sw = inst("TextButton", detail, { Size = UDim2.fromOffset(42, 24),
                Position = UDim2.fromOffset(rx - 42, y + 7), BackgroundColor3 = cur,
                BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 3 })
            corner(sw, 6); stroke(sw, C.Line, 1, 0)
            local palette = inst("Frame", detail, { Size = UDim2.fromOffset(150, 36),
                Position = UDim2.fromOffset(rx - 150, y + 36), BackgroundColor3 = C.Panel,
                BorderSizePixel = 0, Visible = false, ZIndex = 14 })
            corner(palette, 8); stroke(palette, C.Line, 1, 0)
            local swatches = { C.Accent, Color3.fromRGB(94, 234, 212), C.Green,
                Color3.fromRGB(255, 189, 46), Color3.fromRGB(255, 95, 86), C.Text }
            for i, col in ipairs(swatches) do
                local b = inst("TextButton", palette, { Size = UDim2.fromOffset(18, 18),
                    Position = UDim2.fromOffset(8 + (i - 1) * 23, 9), BackgroundColor3 = col,
                    BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 15 })
                corner(b, 5)
                connect(b.MouseButton1Click, function()
                    cur = col; sw.BackgroundColor3 = cur; obj.Value = cur
                    palette.Visible = false; emit(obj, cur)
                end)
            end
            connect(sw.MouseButton1Click, function() palette.Visible = not palette.Visible end)
            function obj:SetValue(v) cur = v or C.Accent; sw.BackgroundColor3 = cur; obj.Value = cur end
            function obj:Get() return cur end
        end
        function obj:Callback(fn) obj._cb = fn; return obj end
        return obj
    end

    function self:ShowNotify(o)
        o = o or {}
        local toast = inst("Frame", gui, { Size = UDim2.fromOffset(260, 60),
            Position = UDim2.new(1, -280, 1, -78), BackgroundColor3 = C.Panel, BorderSizePixel = 0, ZIndex = 20 })
        corner(toast, 10); stroke(toast, C.Accent, 1.5, 0.3)
        local ni = inst("ImageLabel", toast, { Size = UDim2.fromOffset(20, 20),
            Position = UDim2.fromOffset(12, 11), BackgroundTransparency = 1, ZIndex = 22 })
        applyIcon(ni, "bell", C.Accent)
        local t = label(toast, o.Title or "Axiom", 14, C.Text, true)
        t.Size = UDim2.fromOffset(200, 22); t.Position = UDim2.fromOffset(40, 9); t.ZIndex = 21
        local s = label(toast, o.Info or "", 11, C.Sub)
        s.Size = UDim2.fromOffset(230, 20); s.Position = UDim2.fromOffset(12, 34); s.ZIndex = 21
        if type(task) == "table" and type(task.delay) == "function" then
            pcall(task.delay, o.Duration or 3, function()
                if toast.Parent then toast:Destroy() end
            end)
        end
        return toast
    end
    return self
end
return Axiom
