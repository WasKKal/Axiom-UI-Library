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
-- ===== 背景图资源加载：http(s) 优先缓存为本地文件 + getcustomasset，失败回退原始 URL =====
local ImageCache = {}
local function resolveImage(src)
    if type(src) ~= "string" or #src == 0 then return nil end
    if ImageCache[src] ~= nil then return ImageCache[src] or nil end
    local result = nil
    pcall(function()
        if src:match("^rbxasset") or src:match("^%a[%w+.-]*://") == nil then
            result = src
        else
            local content = httpGet(src)
            if type(content) == "string" and #content > 100 then
                if hasFs() and type(getcustomasset) == "function" then
                    local name = "axiom_bg_" .. tostring(#src % 100000) .. ".png"
                    pcall(writefile, name, content)
                    local okA, asset = pcall(getcustomasset, name)
                    if okA and type(asset) == "string" and #asset > 0 then
                        result = asset
                    end
                end
            end
            if not result then result = src end
        end
    end)
    if result == nil then result = src end
    ImageCache[src] = result
    return result
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
-- 通用补间：对实例 o 的多个属性同时补间到 goal，带 pcall 兜底（失败立即设值）；delay 用于动画顺序错峰
local function tweenProp(o, goal, dur, cb, delay)
    if not o then return end
    local function run()
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
    if delay and delay > 0 and type(task) == "table" and type(task.delay) == "function" then
        pcall(task.delay, delay, run)
    else
        run()
    end
end
-- 自定义缓动补间：用于入场动画的曲线变速（style/dir 可指定）
local function tweenEx(o, goal, dur, style, dir, cb, delay)
    if not o then return end
    local function run()
        local done = false
        pcall(function()
            local ts = game:GetService("TweenService")
            if not ts then return end
            local ti = TweenInfo.new(dur or 0.6, style or Enum.EasingStyle.Quint,
                dir or Enum.EasingDirection.InOut)
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
    if delay and delay > 0 and type(task) == "table" and type(task.delay) == "function" then
        pcall(task.delay, delay, run)
    else
        run()
    end
end

local Axiom = {}
Axiom.__index = Axiom
Axiom.GetLucideCacheDir = function() return LUCIDE_CACHE_DIR end
Axiom.GetLucideModulePath = function() return LUCIDE_MODULE_PATH end
Axiom.GetLucideSource = function() return LucideSource end
local C = {
    Bg = Color3.fromRGB(24, 26, 31), Side = Color3.fromRGB(29, 32, 38),
    Bar = Color3.fromRGB(18, 20, 25),
    Panel = Color3.fromRGB(32, 35, 42), Row = Color3.fromRGB(36, 40, 48),
    Line = Color3.fromRGB(52, 57, 67), Border = Color3.fromRGB(88, 96, 112),
    Text = Color3.fromRGB(232, 236, 243),
    Sub = Color3.fromRGB(144, 152, 166), Accent = Color3.fromRGB(88, 150, 255),
    Accent2 = Color3.fromRGB(120, 190, 255), Green = Color3.fromRGB(76, 209, 153),
    AccentW = Color3.fromRGB(172, 208, 255),
    Track = Color3.fromRGB(58, 63, 74),
    DeepGray1 = Color3.fromRGB(78, 84, 94), DeepGray2 = Color3.fromRGB(56, 61, 70),
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
local function whiteSheen(p, rot, a1, a2)
    return inst("UIGradient", p, {
        Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1, 1, 1)),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, a1 or 0.18), NumberSequenceKeypoint.new(1, a2 or 0.02) }),
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

-- 估算文本渲染高度：优先 TextService 实测，失败按字数粗估（用于通知/登录段落高度自适应）
local function estimateTextHeight(text, size, width)
    size = size or 12; width = width or 200
    local h = nil
    pcall(function()
        local ts = game:GetService("TextService")
        if ts and type(ts.GetTextSize) == "function" then
            local v = ts:GetTextSize(tostring(text or ""), size, FONT, Vector2.new(width, 10000))
            if v then h = v.Y end
        end
    end)
    if h and h > 0 then return math.ceil(h) + 4 end
    local str = tostring(text or "")
    local per = math.max(1, math.floor(width / (size * 0.62)))
    local lines, cur = 1, 0
    for i = 1, #str do
        local b = str:byte(i)
        local w = (b >= 128) and 1 or 0.55
        cur = cur + w
        if cur >= per then lines = lines + 1; cur = 0 end
    end
    return math.ceil(lines * (size * 1.45)) + 6
end

-- ===== 全局 Notify：右上角堆叠，高度自适应，入场/退场动画 =====
local notifyState = nil
local function notifyEnsure()
    if notifyState and notifyState.gui and notifyState.gui.Parent then return notifyState end
    local gui = inst("ScreenGui", nil, { Name = "AxiomNotify", ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 100001 })
    local holder = resolveHolder()
    if holder then gui.Parent = holder end
    local stack = inst("Frame", gui, { Name = "Stack", Size = UDim2.fromOffset(0, 0),
        Position = UDim2.new(1, -340, 0, 16), BackgroundTransparency = 1, ZIndex = 1 })
    notifyState = { gui = gui, stack = stack, list = {} }
    return notifyState
end
local function notifyReflow()
    if not notifyState then return end
    local y = 0
    for _, n in ipairs(notifyState.list) do
        if n.alive then
            tweenProp(n.frame, { Position = UDim2.fromOffset(0, y) }, 0.26)
            y = y + n.h + 10
        end
    end
end
function Axiom.Notify(o)
    o = o or {}
    local st = notifyEnsure()
    local text = tostring(o.Text or o.Info or "")
    local title = tostring(o.Title or "Axiom")
    local NW, textW = 320, 280
    local th = estimateTextHeight(text, 12, textW)
    local h = math.max(70, 34 + th + 18)
    local accent = C.Accent
    if o.Type == "success" then accent = C.Green
    elseif o.Type == "warning" then accent = Color3.fromRGB(255, 189, 46)
    elseif o.Type == "error" then accent = Color3.fromRGB(255, 95, 86) end
    local frame = inst("CanvasGroup", st.stack, { Name = "Notice", Size = UDim2.fromOffset(NW, h),
        Position = UDim2.fromOffset(40, 0), BackgroundColor3 = C.Panel,
        BorderSizePixel = 0, GroupTransparency = 1, ZIndex = 2 })
    corner(frame, 10); stroke(frame, accent, 1.5, 0.25)
    local rail = inst("Frame", frame, { Size = UDim2.fromOffset(3, h - 16),
        Position = UDim2.fromOffset(0, 8), BackgroundColor3 = accent,
        BorderSizePixel = 0, ZIndex = 3 })
    corner(rail, 2)
    local ic = inst("ImageLabel", frame, { Size = UDim2.fromOffset(20, 20),
        Position = UDim2.fromOffset(14, 9), BackgroundTransparency = 1, ZIndex = 3 })
    applyIcon(ic, o.Icon or ((o.Type == "success") and "circle-check" or "bell"), accent)
    local tt = label(frame, title, 13, C.Text, true)
    tt.Size = UDim2.fromOffset(NW - 52, 18); tt.Position = UDim2.fromOffset(42, 8); tt.ZIndex = 3
    local dd = label(frame, text, 12, C.Sub)
    dd.Size = UDim2.fromOffset(textW, th); dd.Position = UDim2.fromOffset(20, 30)
    dd.TextWrapped = true; dd.ZIndex = 3
    local entry = { frame = frame, h = h, alive = true }
    st.list[#st.list + 1] = entry
    notifyReflow()
    fade(frame, 0, 0.3)
    local function dismiss()
        if not entry.alive then return end
        entry.alive = false
        tweenProp(frame, { Position = UDim2.fromOffset(40, frame.Position.Y.Offset) }, 0.28)
        fade(frame, 1, 0.3, function()
            for i, x in ipairs(st.list) do if x == entry then table.remove(st.list, i); break end end
            pcall(function() if frame.Parent then frame:Destroy() end end)
            notifyReflow()
        end)
    end
    if type(task) == "table" and type(task.delay) == "function" then
        pcall(task.delay, o.Duration or 4, dismiss)
    end
    return { Frame = frame, Dismiss = dismiss }
end

-- ===== LoginInfo 启动页构建器（覆盖在主 UI 之上；加载脚本后切到主 UI）=====
function Axiom._buildLogin(self, opts, main, bar, bt, gui, contentLayer, dotList)
    local W, H = 620, 440
    local leftW = math.floor(W * 2 / 3)
    local rightW = W - leftW
    local bodyH = H - 34
    self._isLogin = true
    self._loginLoading = false

    local layer = inst("CanvasGroup", main, { Name = "LoginLayer",
        Size = UDim2.fromOffset(W, bodyH), Position = UDim2.fromOffset(0, 34),
        BackgroundColor3 = C.Bg, BorderSizePixel = 0, GroupTransparency = 0, ZIndex = 25 })
    self._loginLayer = layer

    -- 左侧 2/3：大标题 + 更新日志段落（整行、自动换行、动态高度）
    local left = inst("ScrollingFrame", layer, { Size = UDim2.fromOffset(leftW, bodyH),
        Position = UDim2.fromOffset(0, 0), BackgroundTransparency = 1,
        BorderSizePixel = 0, ZIndex = 26,
        ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 3,
        HorizontalScrollBarInset = Enum.ScrollBarInset.None,
        VerticalScrollBarInset = Enum.ScrollBarInset.None,
        CanvasSize = UDim2.new(0, 0, 0, bodyH), ClipsDescendants = false })
    local big = label(left, opts.LoginTitle or "版本更新日志", 22, C.Text, true)
    big.Size = UDim2.fromOffset(leftW - 40, 32); big.Position = UDim2.fromOffset(24, 16); big.ZIndex = 27
    inst("Frame", left, { Size = UDim2.fromOffset(leftW - 48, 1),
        Position = UDim2.fromOffset(24, 54), BackgroundColor3 = C.Line,
        BackgroundTransparency = 0.3, BorderSizePixel = 0, ZIndex = 27 })
    local yCursor = 68
    function self:AddLoginParagraph(o)
        o = o or {}
        local text = tostring(o.Text or "")
        local tw = leftW - 48
        local th = estimateTextHeight(text, 12, tw)
        local yy = yCursor
        local t = label(left, o.Title or "Update", 14, C.Text, true)
        t.Size = UDim2.fromOffset(tw, 20); t.Position = UDim2.fromOffset(24, yy); t.ZIndex = 27
        local d = label(left, text, 12, C.Sub)
        d.Size = UDim2.fromOffset(tw, th); d.Position = UDim2.fromOffset(24, yy + 24)
        d.TextWrapped = true; d.ZIndex = 27
        yCursor = yy + 24 + th + 16
        left.CanvasSize = UDim2.new(0, 0, 0, math.max(bodyH, yCursor + 20))
        local obj = { _win = self }
        function obj:SetText(v)
            local nv = tostring(v or "")
            d.Text = nv
            d.Size = UDim2.fromOffset(tw, estimateTextHeight(nv, 12, tw))
        end
        function obj:Get() return d.Text end
        return obj
    end

    -- 右侧 1/3：圆形头像 + 用户名 + 两个按钮
    local right = inst("Frame", layer, { Size = UDim2.fromOffset(rightW, bodyH),
        Position = UDim2.fromOffset(leftW, 0), BackgroundColor3 = C.Side,
        BorderSizePixel = 0, ZIndex = 26 })
    inst("Frame", right, { Size = UDim2.fromOffset(1, bodyH),
        Position = UDim2.fromOffset(0, 0), BackgroundColor3 = C.Line,
        BackgroundTransparency = 0.3, BorderSizePixel = 0, ZIndex = 27 })
    local avSize = 96
    local avatar = inst("ImageLabel", right, { Name = "Avatar", Size = UDim2.fromOffset(avSize, avSize),
        Position = UDim2.fromOffset((rightW - avSize) / 2, 44), BackgroundColor3 = C.Row,
        BorderSizePixel = 0, ZIndex = 27 })
    corner(avatar, avSize / 2); stroke(avatar, C.Accent, 1.5, 0.4)
    local lpName = "Player"
    pcall(function()
        local Players = game:GetService("Players")
        local lp = Players and Players.LocalPlayer
        if lp then
            lpName = tostring(lp.Name)
            if type(Players.GetUserThumbnailAsync) == "function" then
                avatar.Image = Players:GetUserThumbnailAsync(lp.UserId,
                    Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
            end
        end
    end)
    local uname = label(right, lpName, 15, C.Text, true, Enum.TextXAlignment.Center)
    uname.Size = UDim2.fromOffset(rightW - 20, 26)
    uname.Position = UDim2.fromOffset(10, 44 + avSize + 12); uname.ZIndex = 27

    local function loginBtn(name, txt, y, a1, a2, cb, textGrad)
        local b = inst("TextButton", right, { Name = name, Size = UDim2.fromOffset(rightW - 36, 40),
            Position = UDim2.fromOffset(18, y), BackgroundColor3 = a1,
            BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 27 })
        corner(b, 8)
        local fill = inst("Frame", b, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = a1,
            BorderSizePixel = 0, ZIndex = 27 })
        corner(fill, 8); grad(fill, a1, a2, 0)
        local tx = label(b, txt, 13, Color3.new(1, 1, 1), true, Enum.TextXAlignment.Center)
        tx.Size = UDim2.fromScale(1, 1); tx.ZIndex = 28
        if textGrad then grad(tx, textGrad[1], textGrad[2], textGrad[3] or 90) end
        connect(b.MouseButton1Click, function() if type(cb) == "function" then pcall(cb) end end)
        return b, tx
    end
    local by = 44 + avSize + 12 + 36
    local loadBtn, loadTx = loginBtn("LoadScript", "加载脚本", by, C.Accent, C.Accent2, nil,
        { C.AccentW, Color3.new(1, 1, 1), 90 })
    -- 加载中：右侧 loader-circle 持续旋转；文字左移一点点；延迟 1.5-2.5s 后进入主界面
    local spinConn = nil
    local function stopSpin()
        if spinConn then pcall(function() spinConn:Disconnect() end); spinConn = nil end
    end
    connect(loadBtn.MouseButton1Click, function()
        if self._loginLoading then return end
        self._loginLoading = true
        loadBtn.Active = false
        -- 文字向左微移
        tweenProp(loadTx, { Position = UDim2.new(0, -14, 0, 0) }, 0.25)
        -- 右侧旋转 loader
        local loader = inst("ImageLabel", loadBtn, { Name = "LoadSpinner",
            Size = UDim2.fromOffset(18, 18),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(1, -18, 0.5, 0),
            BackgroundTransparency = 1, ImageTransparency = 1, Rotation = 0, ZIndex = 29 })
        applyIcon(loader, "loader-circle", Color3.new(1, 1, 1))
        tweenProp(loader, { ImageTransparency = 0 }, 0.2)
        local okRs, rs = pcall(function() return game:GetService("RunService") end)
        if okRs and rs then
            local okc, conn = pcall(function()
                return rs.Heartbeat:Connect(function(dt)
                    pcall(function() loader.Rotation = (loader.Rotation + (dt or 1 / 60) * 360) % 360 end)
                end)
            end)
            if okc then spinConn = conn end
        end
        local wait = 0.3 + (math.random(0, 1000) / 1000) * 0.7
        pcall(task.delay, wait, function()
            stopSpin()
            self:_showMainUI()
            if type(opts.OnLoadScript) == "function" then pcall(opts.OnLoadScript) end
        end)
    end)
    loginBtn("UnloadScript", "卸载脚本", by + 52, C.DeepGray1, C.DeepGray2, function()
        if type(opts.OnUnloadScript) == "function" then pcall(opts.OnUnloadScript) end
        self:_closeWindow()
    end)

    function self:_showMainUI()
        if not self._isLogin then return end
        self._isLogin = false
        fade(layer, 1, 0.4, function() layer.Visible = false end)
        contentLayer.GroupTransparency = 1; contentLayer.Visible = true
        fade(contentLayer, 0, 0.45)
        for _, d in ipairs(dotList) do
            d.Visible = true; d.Active = true
            pcall(function() d.BackgroundTransparency = 1 end)
            fadeAny(d, 0, 0.45)
        end
    end

    -- 初始：隐藏主 UI 的三色点与内容区，仅显示登录层
    contentLayer.Visible = false
    for _, d in ipairs(dotList) do
        d.Visible = false; d.Active = false
        pcall(function() d.BackgroundTransparency = 1 end)
    end
    return self
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
    corner(main, 12); stroke(main, C.Border, 1.5, 0); self.main = main
    -- main 保持隐藏(GroupTransparency=1)，待图标/壁纸等资源全部就绪后再淡入（见 _finishAssets）

    local bar = inst("Frame", main, { Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = C.Bar,
        BorderSizePixel = 0, ZIndex = 3 })
    inst("UICorner", bar, { CornerRadius = UDim.new(0, 12) })
    local dots = { Color3.fromRGB(255, 95, 86), Color3.fromRGB(255, 189, 46), Color3.fromRGB(39, 201, 63) }
    local dotList = {}
    self._dots = dotList
    for i, col in ipairs(dots) do
        local d = inst("TextButton", bar, { Name = i == 1 and "CloseDot" or (i == 2 and "MinDot" or "Dot"),
            Size = UDim2.fromOffset(11, 11),
            Position = UDim2.fromOffset(16 + (i - 1) * 18, 12), BackgroundColor3 = col, BorderSizePixel = 0,
            Text = "", AutoButtonColor = false, ZIndex = 4 })
        corner(d, 6)
        dotList[i] = d
        if i == 1 then
            connect(d.MouseButton1Click, function() self:_openCloseConfirm() end)
        elseif i == 2 then
            connect(d.MouseButton1Click, function() self:_minimize() end)
        end
    end
    local bt = label(bar, opts.Title or "AXIOM", 12, C.Sub, false, Enum.TextXAlignment.Center)
    bt.Size = UDim2.fromOffset(300, 20); bt.Position = UDim2.fromOffset(160, 7); bt.ZIndex = 4
    local plusBtn = inst("ImageButton", bar, { Name = "ExpandPlus", Size = UDim2.fromOffset(16, 16),
        Position = UDim2.fromOffset(126, 9), BackgroundTransparency = 1, ImageTransparency = 1,
        AutoButtonColor = false, Visible = false, ZIndex = 5 })
    applyIcon(plusBtn, "plus", C.Accent)
    connect(plusBtn.MouseButton1Click, function() self:_expand() end)

    -- 内容层：包裹选项卡区与控件区，供黄点最小化时整块渐隐
    local contentLayer = inst("CanvasGroup", main, { Name = "ContentLayer", Size = UDim2.fromOffset(W, H - 34),
        Position = UDim2.fromOffset(0, 34), BackgroundTransparency = 1,
        GroupTransparency = 0, BorderSizePixel = 0, ZIndex = 2 })
    self._contentLayer = contentLayer

    -- 壁纸：仅主 UI 内可见（登录层覆盖其上时不显示）；自动裁剪填充+圆角；暗化遮罩保证控件可读
    self._wallpaper = nil
    local bgSrc = opts.Background
    local hasBg = type(bgSrc) == "string" and #bgSrc > 0
    if hasBg then
        local asset = resolveImage(bgSrc)
        local wallpaper = inst("ImageLabel", contentLayer, { Name = "Wallpaper",
            Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 0),
            Image = asset or "", ScaleType = Enum.ScaleType.Crop,
            BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 1, ImageTransparency = 0 })
        corner(wallpaper, 12)
        inst("Frame", contentLayer, { Name = "WallpaperDim", Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.42,
            BorderSizePixel = 0, ZIndex = 1 })
        self._wallpaper = wallpaper
    end

    local side = inst("ScrollingFrame", contentLayer, { Size = UDim2.fromOffset(176, H - 34),
        Position = UDim2.fromOffset(0, 0), BackgroundColor3 = C.Side,
        BackgroundTransparency = hasBg and 0.45 or 0, BorderSizePixel = 0, ZIndex = 2,
        ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 3,
        HorizontalScrollBarInset = Enum.ScrollBarInset.None, VerticalScrollBarInset = Enum.ScrollBarInset.None,
        CanvasSize = UDim2.new(0, 0, 0, H - 34), ClipsDescendants = false })
    self._tabCount = 0
    self._side = side

    local detail = inst("ScrollingFrame", contentLayer, { Size = UDim2.fromOffset(W - 176, H - 34),
        Position = UDim2.fromOffset(176, 0), BackgroundTransparency = 1, ZIndex = 2,
        ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 3,
        HorizontalScrollBarInset = Enum.ScrollBarInset.None, VerticalScrollBarInset = Enum.ScrollBarInset.None,
        CanvasSize = UDim2.new(0, 0, 0, H - 34), ClipsDescendants = false })
    self.body = detail

    -- ===== 黄点最小化 / plus 展开 =====
    local TITLE_W = 150
    local btBasePos = UDim2.fromOffset(160, 7)
    local btBaseAlign = Enum.TextXAlignment.Center
    local barBaseW = UDim2.new(1, 0, 0, 34)
    self._minimized = false

    function self:_minimize()
        if self._minimized then return end
        self._minimized = true
        -- 立即禁用三色点交互（避免淡出过程中误触），Visible 待淡出完成后再关
        for _, d in ipairs(dotList) do pcall(function() d.Active = false end) end
        -- 内容区 / 选项卡区整块渐隐
        fade(contentLayer, 1, 0.3, function()
            contentLayer.Visible = false
            for _, d in ipairs(dotList) do pcall(function() d.Visible = false end) end
        end)
        -- 三色点渐隐
        for _, d in ipairs(dotList) do fadeAny(d, 1, 0.3) end
        -- UI 框架向上收起：高度收到仅剩标题栏、宽度从右向左收起至标题宽度（不再留长条）
        tweenProp(main, { Size = UDim2.fromOffset(TITLE_W, 34) }, 0.34)
        -- 标题栏从右向左收起，仅剩标题文字区（含右侧 plus 预留位）
        tweenProp(bar, { Size = UDim2.fromOffset(TITLE_W, 34) }, 0.34)
        -- 标题文字左移并改左对齐（延迟到三色点渐隐完成后再移动，避免文字压到尚未消失的点上）
        -- 纯 Offset 定位，配合 bar 收起做精确线性位移，不再用 Scale+Offset 混合插值导致移过头
        tweenProp(bt, { Position = UDim2.fromOffset(10, 7), Size = UDim2.fromOffset(TITLE_W - 40, 20) }, 0.3, nil, 0.32)
        pcall(function() bt.TextXAlignment = Enum.TextXAlignment.Left end)
        -- 预留位置后显示 plus 图标
        plusBtn.Visible = true
        tweenProp(plusBtn, { ImageTransparency = 0 }, 0.3, nil, 0.18)
    end

    function self:_expand()
        if not self._minimized then return end
        self._minimized = false
        -- plus 先淡出
        tweenProp(plusBtn, { ImageTransparency = 1 }, 0.2, function() plusBtn.Visible = false end, 0.2)
        -- 标题栏从右向左还原为全宽
        tweenProp(bar, { Size = barBaseW }, 0.34)
        -- 标题文字回居中
        tweenProp(bt, { Position = btBasePos, Size = UDim2.fromOffset(300, 20) }, 0.34)
        pcall(function() bt.TextXAlignment = btBaseAlign end)
        -- UI 框架向下展开还原高度（逆向动画）
        tweenProp(main, { Size = UDim2.fromOffset(W, H) }, 0.34, function()
            contentLayer.Visible = true
            for _, d in ipairs(dotList) do
                pcall(function() d.Visible = true; d.Active = true end)
            end
        end, 0.1)
        -- 内容区 / 三色点渐显还原（先恢复可见再渐显，避免隐藏态下渐显不可见）
        fade(contentLayer, 0, 0.3)
        for _, d in ipairs(dotList) do
            pcall(function() d.Visible = true; d.Active = true end)
            fadeAny(d, 0, 0.3)
        end
    end

    -- ===== 拖动标题栏 / 标题文字移动窗口（UserInputService 全局监听，鼠标移出标题栏仍可拖）=====
    local UIS = nil
    pcall(function() UIS = game:GetService("UserInputService") end)
    local dragging, dragStart, mainStart = false, nil, nil
    local function startDrag(input)
        local ok, typ = pcall(function() return input.UserInputType end)
        if not ok then return end
        if typ ~= Enum.UserInputType.MouseButton1 and typ ~= Enum.UserInputType.Touch then return end
        dragging = true
        dragStart = { x = input.Position.X, y = input.Position.Y }
        mainStart = { x = main.Position.X.Offset, y = main.Position.Y.Offset,
            sx = main.Position.X.Scale, sy = main.Position.Y.Scale }
    end
    local function attachDrag(target)
        connect(target.InputBegan, startDrag)
    end
    attachDrag(bar)   -- 整个标题栏可拖（含三色点旁边的空白区）
    attachDrag(bt)    -- 标题文字本身也可拖
    if UIS then
        connect(UIS.InputChanged, function(input)
            if not dragging then return end
            local ok, typ = pcall(function() return input.UserInputType end)
            if not ok or typ ~= Enum.UserInputType.MouseMovement then return end
            local dx = input.Position.X - dragStart.x
            local dy = input.Position.Y - dragStart.y
            main.Position = UDim2.new(mainStart.sx, mainStart.x + dx, mainStart.sy, mainStart.y + dy)
        end)
        connect(UIS.InputEnded, function(input)
            local ok, typ = pcall(function() return input.UserInputType end)
            if ok and (typ == Enum.UserInputType.MouseButton1 or typ == Enum.UserInputType.Touch) then
                dragging = false
            end
        end)
    end

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
            _content = content, _rows = 0, _lastY = 24 }
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
        detail.CanvasSize = UDim2.new(0, 0, 0, math.max(H - 34, (tab._lastY or 24) + 60))
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
        local y = 24 + (owner._rows - 1) * 52
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
        tx.Size = UDim2.fromOffset(210, 20); tx.Position = UDim2.fromOffset(58, y + 4); tx.ZIndex = 3
        local sub = label(host, o.Desc or "Axiom setting", 10, C.Sub)
        sub.Size = UDim2.fromOffset(230, 16); sub.Position = UDim2.fromOffset(58, y + 22); sub.ZIndex = 3
        local rx = W - 176 - 24
        if kind == "Paragraph" then
            sub.Text = o.Text or ""; sub.Size = UDim2.new(1, -300, 0, 30)
            sub.Position = UDim2.fromOffset(58, y + 20); sub.TextWrapped = true
            function obj:SetText(v) sub.Text = tostring(v or "") end
            function obj:Get() return sub.Text end
        elseif kind == "Toggle" then
            local on = o.Default and true or false
            local tr = inst("TextButton", host, { Size = UDim2.fromOffset(44, 24),
                Position = UDim2.fromOffset(rx - 44, y + 8), BackgroundColor3 = on and C.Accent or C.Track,
                BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 3 })
            corner(tr, 12)
            local shine = inst("Frame", tr, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1),
                BackgroundTransparency = 0.52, BorderSizePixel = 0, Visible = on, ZIndex = 3 })
            corner(shine, 12); whiteSheen(shine, 0, 0.42, 0.2)
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
            cur.Size = UDim2.fromScale(1, 1); cur.ZIndex = 4
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
                rl.Size = UDim2.fromScale(1, 1); rl.ZIndex = 16
                checks[opt] = { row = rb, txt = rl }
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

    -- LoginInfo 启动页：覆盖在主 UI 之上，加载脚本后切入主 UI
    if opts.LoginInfo == true then
        Axiom._buildLogin(self, opts, main, bar, bt, gui, contentLayer, dotList)
    end

    -- ===== 入场动画层：画面渐暗 + 中心大标题 + 全屏直角边框收敛为窗口圆角 =====
    -- 资源（含壁纸）全部就绪后才启动，避免边框先于壁纸出现
    local introLayer = inst("CanvasGroup", gui, { Name = "IntroLayer", Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromOffset(0, 0), BackgroundTransparency = 1,
        GroupTransparency = 0, BorderSizePixel = 0, Visible = false, ZIndex = 60 })
    local introDim = inst("Frame", introLayer, { Name = "IntroDim", Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1,
        BorderSizePixel = 0, ZIndex = 61 })
    local introBorder = inst("Frame", introLayer, { Name = "IntroBorder", Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromOffset(0, 0), BackgroundTransparency = 1,
        BorderSizePixel = 0, ZIndex = 62 })
    local introCorner = corner(introBorder, 0)              -- 直角起步
    local introStroke = stroke(introBorder, C.Border, 3, 0) -- 随层渐隐
    local introTitle = inst("TextLabel", introLayer, { Name = "IntroTitle",
        Text = opts.Title or "AXIOM", Font = Enum.Font.GothamBold, TextSize = 56,
        TextColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1,
        Size = UDim2.fromScale(0.9, 0.16), Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5), TextXAlignment = Enum.TextXAlignment.Center,
        TextTransparency = 1, ZIndex = 63 })
    self._intro = { layer = introLayer, dim = introDim, border = introBorder,
        corner = introCorner, stroke = introStroke, title = introTitle }

    -- 收敛终点：与 main 的最终视觉矩形对齐（main 带 UIScale=SCALE，视觉尺寸 W*SCALE×H*SCALE 居中）
    local finW, finH = W * SCALE, H * SCALE
    local finSize = UDim2.fromOffset(finW, finH)
    local finPos = UDim2.new(0.5, -finW / 2, 0.5, -finH / 2)
    local finCorner = 12 * SCALE
    local titleEndPos = UDim2.new(0.5, 0, 0.5, -finH / 2 + 11)
    local CURVE = Enum.EasingStyle.Quint -- 曲线变速（缓入缓出）
    local function playIntro(done)
        introLayer.Visible = true
        -- 1) 画面渐暗 + 大字淡入 + 全屏直角边框描边淡入
        tweenEx(introDim, { BackgroundTransparency = 0.72 }, 0.3, CURVE, Enum.EasingDirection.Out)
        tweenEx(introTitle, { TextTransparency = 0 }, 0.26, CURVE, Enum.EasingDirection.Out)
        tweenEx(introStroke, { Transparency = 0 }, 0.26, CURVE, Enum.EasingDirection.Out)
        -- 2) 同步收敛：边框全屏直角 -> 窗口圆角；标题缩小并平滑上移（曲线变速），到位后终止
        local CONV = 0.82
        tweenEx(introBorder, { Size = finSize, Position = finPos }, CONV, CURVE, Enum.EasingDirection.InOut, nil, 0.28)
        tweenEx(introCorner, { CornerRadius = UDim.new(0, finCorner) }, CONV, CURVE, Enum.EasingDirection.InOut, nil, 0.28)
        tweenEx(introTitle, { Size = UDim2.fromOffset(240, 26), TextSize = 12, Position = titleEndPos },
            CONV, CURVE, Enum.EasingDirection.InOut, nil, 0.28)
        -- 3) 到位后：入场层淡出，主 UI 淡入，动画层销毁
        local function finish()
            fade(introLayer, 1, 0.28)
            tweenEx(introDim, { BackgroundTransparency = 1 }, 0.28)
            if type(done) == "function" then pcall(done) end
            if type(task) == "table" and type(task.delay) == "function" then
                pcall(task.delay, 0.35, function() pcall(function() introLayer:Destroy() end) end)
            end
        end
        if type(task) == "table" and type(task.delay) == "function" then
            pcall(task.delay, 0.28 + CONV, finish)
        else
            finish()
        end
    end

    -- ===== 资源门控：图标模块 / 背景图（含壁纸实际下载）全部就绪后才启动入场动画 =====
    local shown = false
    local function reveal()
        if shown then return end
        shown = true
        playIntro(function() fade(main, 0, 0.35) end)
    end
    self._reveal = reveal
    local function preload()
        pcall(function() loadLucide() end)
        if self._wallpaper then
            local asset = resolveImage(bgSrc)
            pcall(function() self._wallpaper.Image = asset or "" end)
            -- 等壁纸真正加载完成后才入场（避免边框先于壁纸出现）
            local cpOk, cp = pcall(function() return game:GetService("ContentProvider") end)
            if cpOk and cp and type(cp.PreloadAsync) == "function" then
                local fired = false
                local function ready()
                    if fired then return end
                    fired = true
                    reveal()
                end
                pcall(function() cp:PreloadAsync({ self._wallpaper }, function() ready() end) end)
                -- 兜底：部分执行器/无头环境回调不触发，短延时后强制入场
                if type(task) == "table" and type(task.delay) == "function" then
                    pcall(task.delay, 0.3, ready)
                else
                    ready()
                end
                return
            end
        end
        reveal()
    end
    if type(task) == "table" and type(task.spawn) == "function" then
        pcall(task.spawn, preload)
    else
        preload()
    end
    -- 兜底：极端情况下预加载被阻塞，最多 8 秒后强制入场
    if type(task) == "table" and type(task.delay) == "function" then
        pcall(task.delay, 8, reveal)
    end
    return self
end
return Axiom
