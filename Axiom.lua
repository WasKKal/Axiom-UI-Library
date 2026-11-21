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
local inst
local HttpService = pcall(function() return game:GetService("HttpService") end) and game:GetService("HttpService") or nil
local jsonEncodeValue, jsonDecodeRaw
do
    local function tryEncode(v)
        if not HttpService then return nil end
        local ok, r = pcall(function() return HttpService:JSONEncode(v) end)
        if ok and type(r) == "string" and r:find("axiom_probe", 1, true) then
            return function(x) return HttpService:JSONEncode(x) end
        end
        local ok2, r2 = pcall(function() return HttpService.JSONEncode(v) end)
        if ok2 and type(r2) == "string" and r2:find("axiom_probe", 1, true) then
            return function(x) return HttpService.JSONEncode(x) end
        end
        return nil
    end
    jsonEncodeValue = tryEncode("__axiom_probe__") or function() return nil end
    local function tryDecode(s)
        if not HttpService then return nil end
        local ok, d = pcall(function() return HttpService:JSONDecode(s) end)
        if ok and type(d) == "table" and d.__axiom_probe__ == 1 then
            return function(x) return HttpService:JSONDecode(x) end
        end
        local ok2, d2 = pcall(function() return HttpService.JSONDecode(s) end)
        if ok2 and type(d2) == "table" and d2.__axiom_probe__ == 1 then
            return function(x) return HttpService.JSONDecode(x) end
        end
        return nil
    end
    jsonDecodeRaw = tryDecode('{"__axiom_probe__":1}') or function() return nil end
end
local DEFAULT_CONFIG = "Default"
local CONFIG_DIR_NAME = "Configs"
local ROOT_FOLDER = "Axiom"
local function sanitizeName(name)
    if name == nil then return nil end
    local raw = tostring(name):gsub("^%s+", ""):gsub("%s+$", "")
    if raw == "" then return nil end
    raw = raw:gsub("[\\/:*?\"<>|]", "_")
    if #raw > 40 then raw = raw:sub(1, 40) end
    return raw
end
local function cfgToJSON(v)
    if type(v) == "userdata" then
        local okR, r = pcall(function() return v.R end)
        if okR and r ~= nil then
            local okG, g = pcall(function() return v.G end)
            local okB, b = pcall(function() return v.B end)
            if okG and okB then return { __axiom_color3 = { r = r, g = g, b = b } } end
        end
    end
    return v
end
local function jsonToCfg(v)
    if type(v) == "table" and type(v.__axiom_color3) == "table" then
        local c = v.__axiom_color3
        return Color3.new(tonumber(c.r) or 0, tonumber(c.g) or 0, tonumber(c.b) or 0)
    end
    return v
end
local function fileExists(path)
    if type(path) ~= "string" or type(isfile) ~= "function" then return false end
    local ok, ex = pcall(isfile, path)
    return ok and ex == true
end
local function ensureFolder(path)
    if not path or not hasFs() then return end
    pcall(function()
        if type(isfolder) == "function" then
            local ok, ex = pcall(isfolder, path)
            if ok and not ex then pcall(makefolder, path) end
        else
            pcall(makefolder, path)
        end
    end)
end
local function resolveConfigPath(win, name)
    if not (win and win._assetDir) then return nil, nil end
    local n = sanitizeName(name) or win._configName or DEFAULT_CONFIG
    if n == DEFAULT_CONFIG then return win._assetDir .. "/config.json", DEFAULT_CONFIG end
    local dir = win._configDir or (win._assetDir .. "/" .. CONFIG_DIR_NAME)
    return dir .. "/" .. n .. ".json", n
end
local function makeConfigValue(win, key, kind)
    local folder = win and win._configFolder
    if not (folder and key and key ~= "") then return nil end
    local v
    if kind == "Toggle" then v = inst("BoolValue", folder, { Name = key })
    elseif kind == "Slider" then v = inst("NumberValue", folder, { Name = key })
    elseif kind == "ColorPicker" then v = inst("Color3Value", folder, { Name = key })
    else v = inst("StringValue", folder, { Name = key }) end
    return v
end
local function syncConfigValue(ctrl)
    local v = ctrl and ctrl._configValue
    if not v then return end
    local value = ctrl._configCurrent
    pcall(function()
        if v:IsA("BoolValue") then v.Value = not not value
        elseif v:IsA("NumberValue") then v.Value = tonumber(value) or 0
        elseif v:IsA("Color3Value") then v.Value = value
        elseif v:IsA("StringValue") then
            if type(value) == "table" then
                local ok, enc = pcall(function() return jsonEncodeValue(value) end)
                v.Value = (ok and type(enc) == "string") and enc or ""
            else v.Value = tostring(value or "") end
        end
    end)
end
local function registerConfig(win, obj, o, kind)
    local key = o and o.ConfigKey
    if type(key) ~= "string" or key == "" then return end
    obj._configKey = key
    obj._configKind = kind
    obj._configGet = function()
        local ok, val = pcall(function() return obj.Get and obj:Get() end)
        if ok and val ~= nil then return val end
        return obj.Value
    end
    if type(obj.Set) ~= "function" and type(obj.SetValue) == "function" then obj.Set = obj.SetValue end
    win._config = win._config or {}
    win._config[key] = obj
    obj._configValue = makeConfigValue(win, key, kind)
    obj._configCurrent = obj._configGet()
    syncConfigValue(obj)
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
local ImageCache = {}
local function urlToPngName(url)
    local prefix = tostring(url):match("([^/]+)$") or "bg"
    prefix = prefix:gsub("%.[%w]+$", "")  
    prefix = prefix:gsub("[^%w%-_]+", "_")
    if #prefix > 40 then prefix = prefix:sub(1, 40) end
    if prefix == "" then prefix = "bg" end
    local h = 0
    for i = 1, #tostring(url) do h = (h * 31 + tostring(url):byte(i)) % 1000000007 end
    return prefix .. "_" .. string.format("%08x", h) .. ".png"
end
local function bgStatePath(dir) return dir .. "/bg_state.json" end
local function readBgState(dir)
    local state = {}
    pcall(function()
        local p = bgStatePath(dir)
        if fileExists(p) then
            local raw = readfile(p)
            local ok, d = pcall(function() return jsonDecodeRaw(raw) end)
            if ok and type(d) == "table" then state = d end
        end
    end)
    return state
end
local function writeBgState(dir, state)
    pcall(function()
        ensureFolder(dir)
        local ok, enc = pcall(function() return jsonEncodeValue(state) end)
        if ok and type(enc) == "string" then writefile(bgStatePath(dir), enc) end
    end)
end
local function resolveImage(src, assetDir)
    if type(src) ~= "string" or #src == 0 then return nil end
    local cacheKey = tostring(assetDir or "") .. "|" .. src
    if ImageCache[cacheKey] ~= nil then return ImageCache[cacheKey] or nil end
    local result = nil
    pcall(function()
        if src:match("^rbxasset") or src:match("^%a[%w+.-]*://") == nil then
            result = src
        else
            local dir = assetDir or ROOT_FOLDER .. "/Default"
            ensureFolder(dir)
            local pngName = urlToPngName(src)
            local localPath = dir .. "/" .. pngName
            if hasFs() and type(getcustomasset) == "function" then
                if not fileExists(localPath) then
                    local content = httpGet(src)
                    if type(content) == "string" and #content > 100 then
                        pcall(writefile, localPath, content)
                    end
                end
                if fileExists(localPath) then
                    local okA, asset = pcall(getcustomasset, localPath)
                    if okA and type(asset) == "string" and #asset > 0 then result = asset end
                end
                local state = readBgState(dir)
                local old = state.file
                if type(old) == "string" and old ~= "" and old ~= pngName then
                    local oldPath = dir .. "/" .. old
                    if fileExists(oldPath) and type(delfile) == "function" then
                        pcall(function() delfile(oldPath) end)
                    end
                end
                state.file = pngName
                state.url = src
                writeBgState(dir, state)
            end
            if not result then result = src end
        end
    end)
    if result == nil then result = src end
    ImageCache[cacheKey] = result
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
local function colorToHSV(c)
    local ok, r, g, b = pcall(function() return c.R, c.G, c.B end)
    if not ok or r == nil then return 0, 0, 1 end
    local mx = math.max(r, g, b)
    local mn = math.min(r, g, b)
    local d = mx - mn
    local h = 0
    if d > 1e-6 then
        if mx == r then h = ((g - b) / d) % 6
        elseif mx == g then h = (b - r) / d + 2
        else h = (r - g) / d + 4 end
        h = h / 6
    end
    local sat = (mx <= 0) and 0 or (d / mx)
    return h, sat, mx
end
local function hsvToColor(h, sat, val)
    h = (h or 0) % 1
    sat = clamp(sat or 0, 0, 1)
    val = clamp(val or 0, 0, 1)
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = val * (1 - sat)
    local q = val * (1 - f * sat)
    local t = val * (1 - (1 - f) * sat)
    local r, g, b
    local m = i % 6
    if m == 0 then r, g, b = val, t, p
    elseif m == 1 then r, g, b = q, val, p
    elseif m == 2 then r, g, b = p, val, t
    elseif m == 3 then r, g, b = p, q, val
    elseif m == 4 then r, g, b = t, p, val
    else r, g, b = val, p, q end
    return Color3.new(r, g, b)
end
local function isColor3(c)
    if c == nil then return false end
    local ok, r, g, b = pcall(function() return c.R, c.G, c.B end)
    return ok and r ~= nil and g ~= nil and b ~= nil
end
local function inputPoint(i)
    local p = i and i.Position
    if p and p.X ~= nil and p.Y ~= nil then return p.X, p.Y end
    local ok, m = pcall(function() return game:GetService("UserInputService"):GetMouseLocation() end)
    if ok and m and m.X ~= nil and m.Y ~= nil then return m.X, m.Y end
    return 0, 0
end
local function hitTest(o, px, py)
    if not o then return false end
    local ok, parented = pcall(function() return o.Parent ~= nil end)
    if not ok or not parented then return false end
    local ok2, a, sz = pcall(function() return o.AbsolutePosition, o.AbsoluteSize end)
    if not ok2 or not a or not sz then return false end
    return px >= a.X - 2 and px <= a.X + sz.X + 2
        and py >= a.Y - 2 and py <= a.Y + sz.Y + 2
end
local function connect(signal, fn)
    if not signal then return end
    pcall(function() signal:Connect(fn) end)
end
local function bindDrag(control, onMove)
    local state = { active = false, conns = {} }
    local function release()
        state.active = false
        for _, cn in ipairs(state.conns) do pcall(function() cn:Disconnect() end) end
        state.conns = {}
    end
    connect(control.InputBegan, function(input)
        release()
        state.active = true
        onMove(input)
        pcall(function()
            local uis = game:GetService("UserInputService")
            if not uis then return end
            state.conns[1] = uis.InputChanged:Connect(function(i)
                if not state.active then return end
                local t = i and i.UserInputType
                if t == Enum.UserInputType.MouseMovement or t == Enum.UserInputType.Touch then onMove(i) end
            end)
            state.conns[2] = uis.InputEnded:Connect(function(i)
                if not state.active then return end
                local t = i and i.UserInputType
                if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then release() end
            end)
        end)
    end)
    connect(control.InputChanged, function(input) if state.active then onMove(input) end end)
    connect(control.InputEnded, function() release() end)
    return state
end
local function emit(obj, value)
    if type(obj._cb) == "function" then pcall(obj._cb, value) end
end
local function tweenShadeAlpha(shadeObj, to, dur, done)
    if not shadeObj then return end
    local from = shadeObj.BackgroundTransparency or 1
    local steps, waitT = 20, (dur or 0.3) / 20
    local function run()
        for i = 1, steps do
            local t = i / steps
            pcall(function() shadeObj.BackgroundTransparency = from + (to - from) * t end)
            task.wait(waitT)
        end
        if to >= 0.999 then pcall(function() shadeObj.Visible = false end) end
        if type(done) == "function" then pcall(done) end
    end
    if type(task) == "table" and type(task.spawn) == "function" then
        pcall(task.spawn, run)
    else
        run()
    end
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
local function tweenEx(o, goal, dur, style, dir, cb, delay)
    if not o then return nil end
    local created = nil
    local function run()
        local done = false
        pcall(function()
            local ts = game:GetService("TweenService")
            if not ts then return end
            local ti = TweenInfo.new(dur or 0.6, style or Enum.EasingStyle.Quint,
                dir or Enum.EasingDirection.InOut)
            local tw = ts:Create(o, ti, goal)
            created = tw
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
    return created
end
local function deepFade(root, to, dur, delayT)
    if not root then return end
    local function walk(o)
        local okCls, cls = pcall(function() return o.ClassName end)
        if not okCls then return end
        local prop = nil
        if cls == "TextLabel" or cls == "TextButton" or cls == "TextBox" then
            prop = "TextTransparency"
        elseif cls == "ImageLabel" or cls == "ImageButton" then
            prop = "ImageTransparency"
        elseif cls == "Frame" then
            prop = "BackgroundTransparency"
        elseif cls == "CanvasGroup" then
            prop = "GroupTransparency"
        end
        if prop then tweenProp(o, { [prop] = to }, dur, nil, delayT) end
        local okKids, kids = pcall(function() return o:GetChildren() end)
        if okKids and kids then
            for _, k in ipairs(kids) do
                local okK, kcls = pcall(function() return k.ClassName end)
                if okK and kcls == "UIStroke" then
                    tweenProp(k, { Transparency = to }, dur, nil, delayT)
                else
                    walk(k)
                end
            end
        end
    end
    walk(root)
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
local FONT_FACE, FONT_FACE_B, USE_FONT_FACE = nil, nil, false
pcall(function()
    local FC = Font
    if type(FC) ~= "table" then return end
    local fam = "rbxasset://fonts/families/SourceSansPro.json"
    local WR, WB, NS
    pcall(function() WR = Enum.FontWeight.Regular end)
    pcall(function() WB = Enum.FontWeight.Bold end)
    pcall(function() NS = Enum.FontStyle.Normal end)
    local function mkFont(weight, enumFallback)
        local ok, f
        if weight then
            ok, f = pcall(FC.new, fam, weight, NS)
            if ok and f then return f end
            ok, f = pcall(FC.new, fam, weight)
            if ok and f then return f end
        end
        if type(FC.fromEnum) == "function" then
            ok, f = pcall(FC.fromEnum, enumFallback)
            if ok and f then return f end
        end
        ok, f = pcall(FC.new, fam)
        if ok and f then return f end
        return nil
    end
    local r = mkFont(WR, Enum.Font.SourceSans)
    local b = mkFont(WB, Enum.Font.GothamBold)
    if r and b then
        FONT_FACE, FONT_FACE_B, USE_FONT_FACE = r, b, true
    end
end)
local TEXT_CLASSES = { TextLabel = true, TextButton = true, TextBox = true }
inst = function(cls, parent, props)
    local okNew, o = pcall(Instance.new, cls)
    if not okNew or not o then return nil end
    if props then
        if USE_FONT_FACE and TEXT_CLASSES[cls] then
            local req = props.Font
            props.FontFace = (req == FONT_B) and FONT_FACE_B or FONT_FACE
            props.Font = nil
        end
        for k, v in pairs(props) do
            pcall(function() o[k] = v end)
        end
    elseif USE_FONT_FACE and TEXT_CLASSES[cls] then
        pcall(function() o.FontFace = FONT_FACE end)
    end
    if parent then pcall(function() o.Parent = parent end) end
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
local N_TOP, N_SPACING, N_H, N_W = 20, 8, 30, 250
local notifyState = nil
local function notifyEnsure()
    if notifyState and notifyState.gui and notifyState.gui.Parent then return notifyState end
    local gui = inst("ScreenGui", nil, { Name = "AxiomNotify", ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 100001 })
    local holder = resolveHolder()
    if holder then gui.Parent = holder end
    notifyState = { gui = gui, list = {}, seq = 0 }
    return notifyState
end
local function notifyReflow()
    if not notifyState then return {} end
    local sorted = {}
    for _, n in ipairs(notifyState.list) do
        if n.alive then sorted[#sorted + 1] = n end
    end
    table.sort(sorted, function(a, b) return a.seq < b.seq end)
    local targets = {}
    for i, n in ipairs(sorted) do
        local targetY = N_TOP + (i - 1) * (N_H + N_SPACING)
        targets[n] = UDim2.new(1, -N_W - 10, 0, targetY)  
    end
    return targets
end
local function notifyApply(targets, dur)
    for n, pos in pairs(targets) do
        tweenProp(n.frame, { Position = pos }, dur or 0.35)
    end
end
function Axiom.Notify(o)
    o = o or {}
    local st = notifyEnsure()
    local title = tostring(o.Title or "Notification")
    local content = tostring(o.Text or o.Info or "")
    local borderColor = C.Line
    local mainColor = C.Accent
    if o.Type == "success" then borderColor = C.Green; mainColor = C.Green
    elseif o.Type == "warning" then borderColor = Color3.fromRGB(255, 189, 46); mainColor = borderColor
    elseif o.Type == "error" then borderColor = Color3.fromRGB(255, 95, 86); mainColor = borderColor end
    local okCustom, custom = pcall(function() return o.Color and o.Color.R and o.Color end)
    if okCustom and custom then borderColor = custom; mainColor = custom end
    local frame = inst("CanvasGroup", st.gui, { Name = "Notice",
        Size = UDim2.fromOffset(N_W, N_H), Position = UDim2.new(1, N_W + 20, 0, N_TOP),
        BackgroundColor3 = C.Panel, BackgroundTransparency = 0.2, GroupTransparency = 0,
        ClipsDescendants = true, BorderSizePixel = 0, Visible = true, ZIndex = 9999 })
    corner(frame, 6)
    local strokeObj = stroke(frame, borderColor, 1, 0.5)
    local rail = inst("Frame", frame, { Name = "Rail", Size = UDim2.fromOffset(3, N_H),
        Position = UDim2.fromOffset(0, 0), BackgroundColor3 = mainColor,
        BorderSizePixel = 0, ZIndex = 1 })
    corner(rail, 2); grad(rail, mainColor, Color3.new(1, 1, 1), 90)
    local tt = label(frame, title, 12, C.Text, true, Enum.TextXAlignment.Left)
    tt.Name = "Title"; tt.Size = UDim2.new(1, -16, 0, 14); tt.Position = UDim2.fromOffset(10, 2)
    tt.ZIndex = 2
    local dd = label(frame, content, 10, C.Sub, false, Enum.TextXAlignment.Left)
    dd.Name = "Content"; dd.Size = UDim2.new(1, -16, 0, 12); dd.Position = UDim2.fromOffset(10, 16)
    dd.ZIndex = 2
    pcall(function() dd.TextTruncate = Enum.TextTruncate.AtEnd end)
    local entry = { frame = frame, alive = true, seq = st.seq }
    st.seq = st.seq + 1
    st.list[#st.list + 1] = entry
    notifyApply(notifyReflow(), 0.35)  
    local function dismiss()
        if not entry.alive then return end
        entry.alive = false
        notifyApply(notifyReflow(), 0.3)  
        tweenProp(frame, { Position = UDim2.new(1, N_W + 20, 0, frame.Position.Y.Offset),
            BackgroundTransparency = 1 }, 0.3, function()
            for i, x in ipairs(st.list) do if x == entry then table.remove(st.list, i); break end end
            pcall(function() if frame.Parent then frame:Destroy() end end)
        end)
    end
    if type(task) == "table" and type(task.delay) == "function" then
        pcall(task.delay, o.Duration or 3, dismiss)
    end
    return { Frame = frame, Dismiss = dismiss }
end
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

    local RAINBOW = {
        Color3.fromRGB(255, 0, 0), Color3.fromRGB(255, 140, 0),
        Color3.fromRGB(255, 235, 0), Color3.fromRGB(80, 230, 60),
        Color3.fromRGB(0, 210, 220), Color3.fromRGB(60, 110, 255),
        Color3.fromRGB(180, 60, 255), Color3.fromRGB(255, 0, 0),
    }
    local function rainbowSeq(colors)
        local kps = {}
        local n = #colors
        for i = 1, n do kps[i] = ColorSequenceKeypoint.new((i - 1) / (n - 1), colors[i]) end
        return ColorSequence.new(kps)
    end
    local flowConn = nil
    local flowGradient = nil
    local flowEnabled = false
    local function stopFlow()
        if flowConn then pcall(function() flowConn:Disconnect() end); flowConn = nil end
    end
    local function startFlow()
        if flowEnabled then return end
        local ms = self.mainStroke
        if not ms then return end
        flowGradient = inst("UIGradient", ms, { Rotation = 0, Color = rainbowSeq(RAINBOW) })
        flowEnabled = true
        pcall(function() ms.Color = Color3.new(1, 1, 1) end)
        local okRs, rs = pcall(function() return game:GetService("RunService") end)
        if okRs and rs then
            local rot = 0
            local okc, conn = pcall(function()
                return rs.Heartbeat:Connect(function(dt)
                    if not flowEnabled then return end
                    rot = (rot + (dt or 1 / 60) * 70) % 360
                    pcall(function() if flowGradient then flowGradient.Rotation = rot end end)
                end)
            end)
            if okc then flowConn = conn end
        end
    end
    local function restoreFlow()
        if not flowEnabled then return end
        flowEnabled = false
        stopFlow()
        local ms = self.mainStroke
        if not ms then return end
        local duration = 0.6
        local elapsed = 0
        local okRs, rs = pcall(function() return game:GetService("RunService") end)
        local function step(dt)
            elapsed = math.min(duration, elapsed + (dt or 1 / 60))
            local a = elapsed / duration
            local e = a * a * (3 - 2 * a)
            local mixed = {}
            for i = 1, #RAINBOW do
                local c = RAINBOW[i]
                mixed[i] = Color3.new(
                    c.R + (C.Border.R - c.R) * e,
                    c.G + (C.Border.G - c.G) * e,
                    c.B + (C.Border.B - c.B) * e)
            end
            pcall(function()
                if flowGradient then flowGradient.Color = rainbowSeq(mixed) end
            end)
            if a >= 1 then
                pcall(function() if flowGradient then flowGradient:Destroy() end end)
                flowGradient = nil
                pcall(function() ms.Color = C.Border end)
            end
        end
        if okRs and rs then
            local okc, conn = pcall(function() return rs.Heartbeat:Connect(step) end)
            if okc then
                pcall(task.delay, duration + 0.1, function() pcall(function() conn:Disconnect() end) end)
            else
                step(1 / 60)
            end
        else
            step(1 / 60)
        end
    end
    self._startLoginFlow = startFlow
    self._restoreLoginFlow = restoreFlow
    startFlow()
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
    local function placeParagraph(host, tw, z, yy, title, text)
        local th = estimateTextHeight(text, 12, tw)
        local t = label(host, title, 14, C.Text, true)
        t.Size = UDim2.fromOffset(tw, 20); t.Position = UDim2.fromOffset(24, yy); t.ZIndex = z
        local d = label(host, text, 12, C.Sub)
        d.Size = UDim2.fromOffset(tw, th); d.Position = UDim2.fromOffset(24, yy + 24)
        d.TextWrapped = true; d.ZIndex = z
        return d, th
    end
    function self:AddLoginParagraph(o)
        o = o or {}
        local text = tostring(o.Text or "")
        local title = o.Title or "Update"
        local tw = leftW - 48
        local yy = yCursor
        local d, th = placeParagraph(left, tw, 27, yy, title, text)
        yCursor = yy + 24 + th + 16
        left.CanvasSize = UDim2.new(0, 0, 0, math.max(bodyH, yCursor + 20))
        local sd = nil
        if self._settingsLeft then
            local sy = self._settingsY or 68
            sd = placeParagraph(self._settingsLeft, tw, 42, sy, title, text)
            self._settingsY = sy + 24 + th + 16
            self._settingsLeft.CanvasSize = UDim2.new(0, 0, 0, math.max(bodyH, self._settingsY + 20))
        end
        local obj = { _win = self }
        function obj:SetText(v)
            local nv = tostring(v or "")
            d.Text = nv
            d.Size = UDim2.fromOffset(tw, estimateTextHeight(nv, 12, tw))
            if sd then
                sd.Text = nv
                sd.Size = UDim2.fromOffset(tw, estimateTextHeight(nv, 12, tw))
            end
        end
        function obj:Get() return d.Text end
        return obj
    end
    local right = inst("Frame", layer, { Size = UDim2.fromOffset(rightW, bodyH),
        Position = UDim2.fromOffset(leftW, 0), BackgroundColor3 = C.Side,
        BorderSizePixel = 0, ZIndex = 26 })
    local rightDivider = inst("Frame", right, { Size = UDim2.fromOffset(1, bodyH),
        Position = UDim2.fromOffset(0, 0), BackgroundColor3 = C.Line,
        BackgroundTransparency = 0.3, BorderSizePixel = 0, ZIndex = 27 })
    local avSize = 96
    local blockH = avSize + 12 + 26 + 18 + 40   
    local baseY = (bodyH - blockH) / 2
    local avatar = inst("ImageLabel", right, { Name = "Avatar", Size = UDim2.fromOffset(avSize, avSize),
        Position = UDim2.fromOffset((rightW - avSize) / 2, baseY), BackgroundColor3 = C.Row,
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
    uname.Position = UDim2.fromOffset(10, baseY + avSize + 12); uname.ZIndex = 27
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
    local by = baseY + avSize + 12 + 26 + 18
    local loadBtn, loadTx = loginBtn("LoadScript", "加载脚本", by, C.Accent, C.Accent2, nil,
        { C.AccentW, Color3.new(1, 1, 1), 90 })
    stroke(loadBtn, C.AccentW, 1.5, 0.25)                       
    local loadFill = nil
    for _, c in ipairs(loadBtn:GetChildren()) do
        if c.ClassName == "Frame" and c.Size.X.Scale == 1 and c.Size.Y.Scale == 1 then loadFill = c end
    end
    if loadFill then
        pcall(function() loadFill.UIGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(58, 122, 235)),
            ColorSequenceKeypoint.new(0.5, C.Accent),
            ColorSequenceKeypoint.new(1, C.Accent2) }) end)
    end
    pcall(function() loadTx.UIGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, C.AccentW),
        ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
        ColorSequenceKeypoint.new(1, C.AccentW) }) end)
    local function later(t, fn)
        if type(task) == "table" and type(task.delay) == "function" then
            pcall(task.delay, t, fn)
        else
            fn()
        end
    end
    local function loginSequence(done)
        pcall(function()
            layer.AnchorPoint = Vector2.new(0.5, 0.5)
            layer.Position = UDim2.fromOffset(W / 2, 34 + bodyH / 2)
        end)
        local tilt = inst("UIScale", layer, { Scale = 1 })
        if tilt then tweenProp(tilt, { Scale = 0.972 }, 0.26) end
        local brand = label(layer, opts.Title or "AXIOM", 42, C.Text, true, Enum.TextXAlignment.Center)
        brand.Name = "LoginBrand"
        brand.Size = UDim2.fromOffset(460, 54)
        brand.Position = UDim2.new(0.5, 0, 0.5, -40)
        brand.AnchorPoint = Vector2.new(0.5, 0.5)
        brand.TextTransparency = 1
        brand.ZIndex = 62
        local under = inst("Frame", layer, { Name = "LoginBrandLine", Size = UDim2.fromOffset(2, 2),
            Position = UDim2.new(0.5, 0, 0.5, -8), AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = C.Accent, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 62 })
        corner(under, 1)
        grad(under, C.Accent, Color3.new(1, 1, 1), 0)
        local bw, bh, gap = 34, 4, 10
        local total = bw * 3 + gap * 2
        local bars, fills = {}, {}
        for i = 1, 3 do
            local b = inst("Frame", layer, { Name = "LoginBar" .. tostring(i),
                Size = UDim2.fromOffset(bw, bh),
                Position = UDim2.new(0.5, -(total / 2) + (i - 1) * (bw + gap), 0.5, 14),
                BackgroundColor3 = C.Track, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 62 })
            corner(b, 2)
            local f = inst("Frame", b, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Accent,
                BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 63 })
            corner(f, 2)
            grad(f, C.Accent, Color3.new(1, 1, 1), 0)
            bars[i] = b
            fills[i] = f
        end
        later(0.06, function()
            deepFade(left, 0.9, 0.3)
            fadeAny(right, 1, 0.3)
            deepFade(uname, 0.6, 0.3)
            deepFade(loadBtn, 0.55, 0.3)
            if rightDivider then tweenProp(rightDivider, { BackgroundTransparency = 1 }, 0.3) end
            tweenProp(brand, { TextTransparency = 0, Position = UDim2.new(0.5, 0, 0.5, -46) }, 0.32)
            tweenProp(under, { BackgroundTransparency = 0, Size = UDim2.fromOffset(128, 2) }, 0.32)
        end)
        for i = 1, 3 do
            later(0.18 + (i - 1) * 0.08, function()
                tweenProp(bars[i], { BackgroundTransparency = 0.22 }, 0.16)
                tweenProp(fills[i], { BackgroundTransparency = 0, Size = UDim2.fromScale(1, 1) }, 0.16)
            end)
        end
        later(0.52, function()
            tweenProp(avatar, { Size = UDim2.fromOffset(34, 34),
                Position = UDim2.fromOffset(14 - leftW, 10) }, 0.26)
            deepFade(uname, 1, 0.18)
            deepFade(loadBtn, 1, 0.18)
            deepFade(left, 1, 0.2)
        end)
        later(0.72, function()
            for i = 1, 3 do
                tweenProp(fills[i], { BackgroundColor3 = Color3.new(1, 1, 1) }, 0.12)
                tweenProp(bars[i], { BackgroundTransparency = 1 }, 0.2)
                tweenProp(fills[i], { BackgroundTransparency = 1 }, 0.2)
            end
            tweenProp(brand, { TextTransparency = 1, Position = UDim2.new(0.5, 0, 0.5, -60) }, 0.22)
            tweenProp(under, { BackgroundTransparency = 1, Size = UDim2.fromOffset(64, 2) }, 0.2)
        end)
        later(0.9, function()
            tweenProp(layer, { Position = UDim2.fromOffset(W / 2, 34 + bodyH / 2 - 40) }, 0.3)
            if tilt then tweenProp(tilt, { Scale = 1 }, 0.3) end
            if type(done) == "function" then pcall(done) end
        end)
        later(1.6, function()
            pcall(function()
                if brand and brand.Parent then brand:Destroy() end
                if under and under.Parent then under:Destroy() end
                for i = 1, 3 do
                    if bars[i] and bars[i].Parent then bars[i]:Destroy() end
                end
            end)
        end)
    end
    self._loginSequence = loginSequence
    connect(loadBtn.MouseButton1Click, function()
        if self._loginLoading then return end
        self._loginLoading = true
        loadBtn.Active = false
        if loadTx then pcall(function() loadTx.Text = "加载中" end) end
        loginSequence(function()
            self:_showMainUI()
            if type(opts.OnLoadScript) == "function" then pcall(opts.OnLoadScript) end
        end)
    end)
    function self:_showMainUI()
        if not self._isLogin then return end
        self._isLogin = false
        restoreFlow()
        fade(layer, 1, 0.3, function() layer.Visible = false end)
        pcall(function() contentLayer.Position = UDim2.fromOffset(0, 34 + 16) end)
        contentLayer.GroupTransparency = 1; contentLayer.Visible = true
        fade(contentLayer, 0, 0.42)
        pcall(function() tweenProp(contentLayer, { Position = UDim2.fromOffset(0, 34) }, 0.42) end)
        for i, d in ipairs(dotList) do
            d.Visible = true; d.Active = true
            local base = nil
            pcall(function() base = d.BackgroundColor3 end)
            pcall(function() d.BackgroundTransparency = 1 end)
            local delay = (i - 1) * 0.06
            tweenProp(d, { BackgroundTransparency = 0 }, 0.3, nil, delay)
            if base then
                pcall(function() d.BackgroundColor3 = Color3.new(1, 1, 1) end)
                tweenProp(d, { BackgroundColor3 = base }, 0.36, nil, delay)
            end
        end
    end
    contentLayer.Visible = false
    for _, d in ipairs(dotList) do
        d.Visible = false; d.Active = false
        pcall(function() d.BackgroundTransparency = 1 end)
    end
    local sLayer = inst("CanvasGroup", main, { Name = "SettingsLayer",
        Size = UDim2.fromOffset(W, bodyH), Position = UDim2.fromOffset(0, 34),
        BackgroundColor3 = C.Bg, BorderSizePixel = 0, GroupTransparency = 1,
        Visible = false, ZIndex = 28 })
    self._settingsLayer = sLayer
    local sLeft = inst("ScrollingFrame", sLayer, { Name = "SettingsLog", Size = UDim2.fromOffset(leftW, bodyH),
        Position = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 29,
        ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 3,
        HorizontalScrollBarInset = Enum.ScrollBarInset.None, VerticalScrollBarInset = Enum.ScrollBarInset.None,
        CanvasSize = UDim2.new(0, 0, 0, bodyH), ClipsDescendants = false })
    self._settingsLeft = sLeft
    self._settingsY = 68
    local sBig = label(sLeft, opts.LoginTitle or "版本更新日志", 22, C.Text, true)
    sBig.Size = UDim2.fromOffset(leftW - 40, 32); sBig.Position = UDim2.fromOffset(24, 16); sBig.ZIndex = 30
    inst("Frame", sLeft, { Size = UDim2.fromOffset(leftW - 48, 1), Position = UDim2.fromOffset(24, 54),
        BackgroundColor3 = C.Line, BackgroundTransparency = 0.3, BorderSizePixel = 0, ZIndex = 30 })
    local sRight = inst("Frame", sLayer, { Name = "SettingsArea", Size = UDim2.fromOffset(rightW, bodyH),
        Position = UDim2.fromOffset(leftW, 0), BackgroundColor3 = C.Side, BorderSizePixel = 0, ZIndex = 29 })
    inst("Frame", sRight, { Size = UDim2.fromOffset(1, bodyH), Position = UDim2.fromOffset(0, 0),
        BackgroundColor3 = C.Line, BackgroundTransparency = 0.3, BorderSizePixel = 0, ZIndex = 30 })
    local av2 = 54
    local avatar2 = inst("ImageLabel", sRight, { Name = "SettingsAvatar", Size = UDim2.fromOffset(av2, av2),
        Position = UDim2.fromOffset(16, 16), BackgroundColor3 = C.Row, BorderSizePixel = 0, ZIndex = 30 })
    corner(avatar2, av2 / 2); stroke(avatar2, C.Accent, 1.2, 0.4)
    local name2 = "Player"
    pcall(function()
        local Players = game:GetService("Players")
        local lp = Players and Players.LocalPlayer
        if lp then
            name2 = tostring(lp.Name)
            if type(Players.GetUserThumbnailAsync) == "function" then
                avatar2.Image = Players:GetUserThumbnailAsync(lp.UserId,
                    Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
            end
        end
    end)
    local uname2 = label(sRight, name2, 13, C.Text, true, Enum.TextXAlignment.Left)
    uname2.Name = "SettingsName"; uname2.Size = UDim2.fromOffset(rightW - av2 - 26, 18)
    uname2.Position = UDim2.fromOffset(16 + av2 + 8, 18); uname2.ZIndex = 30
    local bday = "账号生日: 未知"
    pcall(function()
        local Players = game:GetService("Players")
        local lp = Players and Players.LocalPlayer
        local age = lp and lp.AccountAge
        if type(age) == "number" and type(os) == "table" and type(os.time) == "function" and type(os.date) == "function" then
            local created = os.time() - math.floor(age) * 86400
            bday = "账号生日: " .. tostring(os.date("%Y-%m-%d", created))
        elseif type(age) == "number" then
            bday = "账号年龄: " .. tostring(math.floor(age)) .. " 天"
        end
    end)
    local bdayTx = label(sRight, bday, 10, C.Sub, false, Enum.TextXAlignment.Left)
    bdayTx.Name = "SettingsBirthday"; bdayTx.Size = UDim2.fromOffset(rightW - av2 - 26, 16)
    bdayTx.Position = UDim2.fromOffset(16 + av2 + 8, 38); bdayTx.ZIndex = 30
    local secTitle = label(sRight, "UI设置", 14, C.Text, true, Enum.TextXAlignment.Left)
    secTitle.Name = "SettingsSection"; secTitle.Size = UDim2.fromOffset(rightW - 32, 22)
    secTitle.Position = UDim2.fromOffset(16, av2 + 30); secTitle.ZIndex = 30
    inst("Frame", sRight, { Size = UDim2.fromOffset(rightW - 32, 1), Position = UDim2.fromOffset(16, av2 + 54),
        BackgroundColor3 = C.Line, BackgroundTransparency = 0.3, BorderSizePixel = 0, ZIndex = 30 })
    local minPct, maxPct, pct = 60, 160, 100
    local scaleCap = label(sRight, "窗口比例", 11, C.Sub, false, Enum.TextXAlignment.Left)
    scaleCap.Size = UDim2.fromOffset(90, 18); scaleCap.Position = UDim2.fromOffset(16, av2 + 64); scaleCap.ZIndex = 30
    local pctTx = label(sRight, "100%", 11, C.Accent, true, Enum.TextXAlignment.Right)
    pctTx.Name = "ScaleLabel"; pctTx.Size = UDim2.fromOffset(46, 18)
    pctTx.Position = UDim2.fromOffset(rightW - 62, av2 + 64); pctTx.ZIndex = 30
    local strack = inst("TextButton", sRight, { Name = "ScaleSlider", Size = UDim2.fromOffset(rightW - 32, 6),
        Position = UDim2.fromOffset(16, av2 + 86), BackgroundColor3 = C.Track,
        BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 30 })
    corner(strack, 3)
    local sfill = inst("Frame", strack, { Size = UDim2.fromScale((pct - minPct) / (maxPct - minPct), 1),
        BackgroundColor3 = C.Accent, BorderSizePixel = 0, ZIndex = 31 })
    corner(sfill, 3)
    local pvBaseScale = self._baseScale or 0.65
    local preview = inst("Frame", gui, { Name = "SizePreview", AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(W * pvBaseScale, H * pvBaseScale), Position = UDim2.new(0.5, 0, 0.5, 0),
        BackgroundColor3 = C.Accent, BackgroundTransparency = 0.9, BorderSizePixel = 0,
        Visible = false, ZIndex = 2 })
    corner(preview, 12)
    local pvStroke = stroke(preview, C.AccentW, 2, 0.25)
    local pvTweens = {}
    local pvSnap = true
    local function restorePvAlpha()
        pcall(function()
            preview.BackgroundTransparency = 0.9
            if pvStroke then pvStroke.Transparency = 0.25 end
        end)
    end
    local function showPreview()
        pcall(function() preview.Visible = true end)
        restorePvAlpha()
        pvSnap = true
    end
    local function hidePreview()
        pcall(function() preview.Visible = false end)
        restorePvAlpha()
        pvSnap = false
    end
    local function tweenPreview(nw, nh, cx, cy)
        showPreview()
        if pvSnap then
            pvSnap = false
            pcall(function()
                preview.Size = UDim2.fromOffset(nw, nh)
                preview.Position = UDim2.new(0.5, 0, 0.5, 0)
            end)
            return
        end
        pcall(function()
            local ts = game:GetService("TweenService")
            for _, tw in ipairs(pvTweens) do pcall(function() tw:Cancel() end) end
            pvTweens = {}
            if not ts then
                preview.Size = UDim2.fromOffset(nw, nh)
                preview.Position = UDim2.new(0.5, 0, 0.5, 0)
                return
            end
            local ti = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            local tw1 = ts:Create(preview, ti, { Size = UDim2.fromOffset(nw, nh) })
            pvTweens[1] = tw1
            tw1:Play()
        end)
    end
    local function updatePreview(k)
        if not k then hidePreview(); return end
        local nw, nh = W * k, H * k
        tweenPreview(nw, nh)
    end
    self._showSizePreview = showPreview
    self._hideSizePreview = hidePreview
    self._updateSizePreview = updatePreview
    local function sfrom(input)
        local okX, ax = pcall(function() return input.Position.X end)
        if not okX or not ax then return end
        local okA, rel = pcall(function() return strack.AbsolutePosition.X end)
        local okS, wid = pcall(function() return strack.AbsoluteSize.X end)
        if okA and okS and wid and wid > 0 then
            pct = math.floor(minPct + clamp((ax - rel) / wid, 0, 1) * (maxPct - minPct))
            sfill.Size = UDim2.fromScale(clamp((pct - minPct) / (maxPct - minPct), 0.02, 1), 1)
            pctTx.Text = tostring(pct) .. "%"
            updatePreview(pvBaseScale * (pct / 100))
        end
    end
    bindDrag(strack, sfrom)
    self._getSettingsScale = function() return pct / 100 end
    local applyBtn = inst("TextButton", sRight, { Name = "ApplyUi", Size = UDim2.fromOffset(rightW - 32, 36),
        Position = UDim2.fromOffset(16, bodyH - 48), BackgroundColor3 = C.Accent,
        BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 30 })
    corner(applyBtn, 8)
    local afill = inst("Frame", applyBtn, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Accent,
        BorderSizePixel = 0, ZIndex = 30 })
    corner(afill, 8); grad(afill, C.Accent, Color3.new(1, 1, 1), 0)
    local atx = label(applyBtn, "应用修改", 13, Color3.new(1, 1, 1), true, Enum.TextXAlignment.Center)
    atx.Name = "ApplyUiText"; atx.Size = UDim2.fromScale(1, 1); atx.ZIndex = 31
    stroke(applyBtn, C.AccentW, 1.2, 0.25)
    connect(applyBtn.MouseButton1Click, function()
        local k = (self._baseScale or 0.65) * (pct / 100)
        local newPos = UDim2.new(0.5, -(W * k) / 2, 0.5, -(H * k) / 2)
        self._scaleTweens = {
            tweenEx(self._mainScale, { Scale = k }, 0.34, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            tweenEx(main, { Position = newPos }, 0.34, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        }
        hidePreview()
        if type(Axiom.Notify) == "function" then
            pcall(function() Axiom.Notify({ Title = "设置", Text = "你的设定已保存!", Type = "success", Duration = 2.5 }) end)
        end
    end)
    local settingsOpen = false
    self._settingsOpenState = false
    function self:_toggleSettingsPanel()
        if self._isLogin then return end
        settingsOpen = not settingsOpen
        self._settingsOpenState = settingsOpen
        if settingsOpen then
            pct = math.floor(((self._mainScale and self._mainScale.Scale or pvBaseScale) / pvBaseScale) * 100 + 0.5)
            pct = clamp(pct, minPct, maxPct)
            sfill.Size = UDim2.fromScale(clamp((pct - minPct) / (maxPct - minPct), 0.02, 1), 1)
            pctTx.Text = tostring(pct) .. "%"
            fade(contentLayer, 1, 0.25, function() contentLayer.Visible = false end)
            sLayer.Visible = true; sLayer.GroupTransparency = 1
            fade(sLayer, 0, 0.3)
            if type(self._startExitHint) == "function" then self:_startExitHint() end
        else
            hidePreview()
            if type(self._stopExitHint) == "function" then self:_stopExitHint() end
            fade(sLayer, 1, 0.24, function() sLayer.Visible = false end)
            contentLayer.Visible = true; contentLayer.GroupTransparency = 1
            fade(contentLayer, 0, 0.3)
        end
    end
    return self
end
function Axiom.CreateWindow(opts)
    opts = opts or {}
    local self = setmetatable({ _rows = 0, _tabs = {}, _activeTab = nil }, Axiom)
    local gui = inst("ScreenGui", nil, { Name = "AxiomUI", ResetOnSpawn = false,
        IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 100000 })
    local holder = resolveHolder()
    if holder then gui.Parent = holder end
    self.gui = gui
    local subFolder = sanitizeName(opts.Folder) or "Default"
    local assetDir = ROOT_FOLDER .. "/" .. subFolder
    local configDir = assetDir .. "/" .. CONFIG_DIR_NAME
    self._folderName = subFolder
    self._assetDir = assetDir
    self._configDir = configDir
    self._configName = sanitizeName(opts.ConfigName) or DEFAULT_CONFIG
    self._configPath = (self._configName == DEFAULT_CONFIG)
        and (assetDir .. "/config.json")
        or (configDir .. "/" .. self._configName .. ".json")
    self._config = {}
    ensureFolder(ROOT_FOLDER); ensureFolder(assetDir); ensureFolder(configDir)
    local rootFolder = inst("Folder", holder, { Name = ROOT_FOLDER })
    local subFolderObj = inst("Folder", rootFolder, { Name = subFolder })
    local configFolder = inst("Folder", subFolderObj, { Name = "Config" })
    self._rootFolder = rootFolder
    self._folder = subFolderObj
    self._configFolder = configFolder
    local W, H = 620, 440
    local SCALE = 0.65
    local main = inst("CanvasGroup", gui, { Name = "Main", Size = UDim2.fromOffset(W, H),
        Position = UDim2.new(0.5, -(W*SCALE)/2, 0.5, -(H*SCALE)/2), BackgroundColor3 = C.Bg,
        BorderSizePixel = 0, ZIndex = 1, GroupTransparency = 1 })
    local mainScale = inst("UIScale", main, { Scale = SCALE })
    self._mainScale = mainScale
    self._baseScale = SCALE
    self._baseW, self._baseH = W, H
    local mainCorner = corner(main, 12)
    self._mainCorner = mainCorner
    local mainStroke = stroke(main, C.Border, 1.5, 1)  
    if mainStroke then pcall(function() strokeBase[mainStroke] = 0; mainStroke.Transparency = 1 end) end
    self.main = main
    self.mainStroke = mainStroke
    local inputBlocker = inst("TextButton", main, { Name = "InputBlocker",
        Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 0),
        BackgroundTransparency = 1, BorderSizePixel = 0, Text = "",
        AutoButtonColor = false, Active = true, Visible = true, ZIndex = 1 })
    self._inputBlocker = inputBlocker
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
        else
            connect(d.MouseButton1Click, function()
                if type(self._toggleSettingsPanel) == "function" then self:_toggleSettingsPanel() end
            end)
        end
        local baseCol = col
        local darkCol = Color3.new(col.R * 0.55, col.G * 0.55, col.B * 0.55)
        connect(d.MouseButton1Down, function() tweenProp(d, { BackgroundColor3 = darkCol }, 0.08) end)
        local function lighten() tweenProp(d, { BackgroundColor3 = baseCol }, 0.12) end
        connect(d.MouseButton1Up, lighten)
        connect(d.MouseLeave, lighten)
    end
    local hintIconX, hintTextX = 68, 86
    local hintIcon = inst("ImageButton", bar, { Name = "ExitHintIcon", Size = UDim2.fromOffset(14, 14),
        Position = UDim2.fromOffset(hintIconX, 10), BackgroundTransparency = 1, ImageTransparency = 1,
        AutoButtonColor = false, Visible = false, ZIndex = 6 })
    applyIcon(hintIcon, "arrow-left", C.Accent)
    local hintText = inst("TextButton", bar, { Name = "ExitHintText", Size = UDim2.fromOffset(112, 16),
        Position = UDim2.fromOffset(hintTextX, 9), BackgroundTransparency = 1, Text = "点击此处关闭页面",
        TextColor3 = C.Accent, TextSize = 10, Font = FONT, TextXAlignment = Enum.TextXAlignment.Left,
        TextTransparency = 1, AutoButtonColor = false, Visible = false, ZIndex = 6 })
    local hintConn = nil
    local hintRun = false
    local hintT = 0
    local function stopExitHint()
        hintRun = false
        if hintConn then pcall(function() hintConn:Disconnect() end); hintConn = nil end
        pcall(function() hintIcon.Visible = false; hintText.Visible = false end)
    end
    local function startExitHint()
        if hintRun then return end
        hintRun = true
        pcall(function() hintIcon.Visible = true; hintText.Visible = true end)
        local okRs, rs = pcall(function() return game:GetService("RunService") end)
        if okRs and rs then
            local okc, conn = pcall(function()
                return rs.Heartbeat:Connect(function(dt)
                    if not hintRun then return end
                    hintT = hintT + (dt or 1 / 60)
                    local phase = (math.sin(hintT * 2.2) + 1) * 0.5
                    local trans = 0.12 + phase * 0.48
                    local shift = -3 * phase
                    pcall(function()
                        hintIcon.ImageTransparency = trans
                        hintText.TextTransparency = trans
                        hintIcon.Position = UDim2.fromOffset(hintIconX + shift, 10)
                        hintText.Position = UDim2.fromOffset(hintTextX + shift, 9)
                    end)
                end)
            end)
            if okc then hintConn = conn end
        else
            pcall(function() hintIcon.ImageTransparency = 0.12; hintText.TextTransparency = 0.12 end)
        end
    end
    local function closeFromHint()
        if type(self._toggleSettingsPanel) == "function" and self._settingsOpenState then
            self:_toggleSettingsPanel()
        end
    end
    connect(hintIcon.MouseButton1Click, closeFromHint)
    connect(hintText.MouseButton1Click, closeFromHint)
    self._startExitHint = startExitHint
    self._stopExitHint = stopExitHint
    local bt = label(bar, opts.Title or "AXIOM", 12, C.Sub, false, Enum.TextXAlignment.Center)
    bt.Size = UDim2.fromOffset(300, 20); bt.Position = UDim2.fromOffset(160, 7); bt.ZIndex = 4
    local plusBtn = inst("ImageButton", bar, { Name = "ExpandPlus", Size = UDim2.fromOffset(16, 16),
        Position = UDim2.fromOffset(126, 9), BackgroundTransparency = 1, ImageTransparency = 1,
        AutoButtonColor = false, Visible = false, ZIndex = 5 })
    applyIcon(plusBtn, "plus", C.Accent)
    connect(plusBtn.MouseButton1Click, function() self:_expand() end)
    local contentLayer = inst("CanvasGroup", main, { Name = "ContentLayer", Size = UDim2.fromOffset(W, H - 34),
        Position = UDim2.fromOffset(0, 34), BackgroundTransparency = 1,
        GroupTransparency = 0, BorderSizePixel = 0, ZIndex = 2 })
    self._contentLayer = contentLayer
    self._wallpaper = nil
    local bgSrc = opts.Background
    local hasBg = type(bgSrc) == "string" and #bgSrc > 0
    if hasBg then
        local asset = resolveImage(bgSrc, assetDir)
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
    local TITLE_W = 150
    local btBasePos = UDim2.fromOffset(160, 7)
    local btBaseAlign = Enum.TextXAlignment.Center
    local barBaseW = UDim2.new(1, 0, 0, 34)
    self._minimized = false
    function self:_minimize()
        if self._minimized then return end
        self._minimized = true
        for _, d in ipairs(dotList) do pcall(function() d.Active = false end) end
        fade(contentLayer, 1, 0.3, function()
            contentLayer.Visible = false
            for _, d in ipairs(dotList) do pcall(function() d.Visible = false end) end
        end)
        for _, d in ipairs(dotList) do fadeAny(d, 1, 0.3) end
        tweenProp(main, { Size = UDim2.fromOffset(TITLE_W, 34) }, 0.34)
        tweenProp(bar, { Size = UDim2.fromOffset(TITLE_W, 34) }, 0.34)
        tweenProp(bt, { Position = UDim2.fromOffset(10, 7), Size = UDim2.fromOffset(TITLE_W - 40, 20) }, 0.3)
        pcall(function() bt.TextXAlignment = Enum.TextXAlignment.Left end)
        plusBtn.Visible = true
        tweenProp(plusBtn, { ImageTransparency = 0 }, 0.3, nil, 0.18)
    end
    function self:_expand()
        if not self._minimized then return end
        self._minimized = false
        tweenProp(plusBtn, { ImageTransparency = 1 }, 0.2, function() plusBtn.Visible = false end, 0.2)
        tweenProp(bar, { Size = barBaseW }, 0.34)
        tweenProp(bt, { Position = btBasePos, Size = UDim2.fromOffset(300, 20) }, 0.34)
        pcall(function() bt.TextXAlignment = btBaseAlign end)
        tweenProp(main, { Size = UDim2.fromOffset(W, H) }, 0.34, function()
            contentLayer.Visible = true
            for _, d in ipairs(dotList) do
                pcall(function() d.Visible = true; d.Active = true end)
            end
        end, 0.1)
        fade(contentLayer, 0, 0.3)
        for _, d in ipairs(dotList) do
            pcall(function() d.Visible = true; d.Active = true end)
            fadeAny(d, 0, 0.3)
        end
    end
    local UIS = nil
    pcall(function() UIS = game:GetService("UserInputService") end)
    local dragging, dragStart, mainStart = false, nil, nil
    local function startDrag(input)
        if self._closing then return end
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
    attachDrag(bar)   
    attachDrag(bt)    
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
        local content = inst("Frame", detail, { Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 2,
            ClipsDescendants = false, Visible = active })
        local bg = inst("Frame", side, { Size = UDim2.fromOffset(160, 34),
            Position = UDim2.fromOffset(8, my - 5), BackgroundColor3 = C.Panel,
            BackgroundTransparency = active and 0.4 or 1, BorderSizePixel = 0, ZIndex = 1 })
        corner(bg, 8)
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
        for _, t in ipairs(self._tabs) do
            if t._content then t._content.Visible = (t == tab) end
        end
        detail.CanvasSize = UDim2.new(0, 0, 0, math.max(H - 34, (tab._lastY or 24) + 60))
        pcall(function() detail.CanvasPosition = UDim2.fromOffset(0, 0) end)
        for _, t in ipairs(self._tabs) do
            local on = (t == tab)
            tweenProp(t._act, { Size = UDim2.fromOffset(3, on and 26 or 0),
                BackgroundTransparency = on and 0 or 1 }, on and 0.28 or 0.22)
            tweenProp(t._bg, { BackgroundTransparency = on and 0.4 or 1 }, 0.22)
            pcall(function() t._mi.ImageColor3 = on and C.Accent or C.Sub end)
            t._mt.TextColor3 = on and C.Text or C.Sub
            if USE_FONT_FACE then
                pcall(function() t._mt.FontFace = on and FONT_FACE_B or FONT_FACE end)
            else
                t._mt.Font = on and FONT_B or FONT
            end
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
            local sheen = inst("Frame", tr, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1),
                BackgroundTransparency = 0, BorderSizePixel = 0, Visible = on, ZIndex = 3 })
            corner(sheen, 12); whiteSheen(sheen, 0, 0.88, 0.74)
            local kn = inst("Frame", tr, { Size = UDim2.fromOffset(18, 18),
                Position = UDim2.new(on and 1 or 0, on and -21 or 3, 0.5, 0),
                AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0, ZIndex = 4 })
            corner(kn, 9)
            local function refresh()
                local bg = on and C.Accent or C.Track
                local kp = UDim2.new(on and 1 or 0, on and -21 or 3, 0.5, 0)
                if on then sheen.Visible = true end
                local done = false
                pcall(function()
                    local ts = game:GetService("TweenService")
                    if not ts then return end
                    local ti = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                    ts:Create(tr, ti, { BackgroundColor3 = bg }):Play()
                    ts:Create(kn, ti, { Position = kp }):Play()
                    local stw = ts:Create(sheen, ti, { BackgroundTransparency = on and 0 or 1 })
                    if not on then
                        stw.Completed:Connect(function()
                            pcall(function() sheen.Visible = false end)
                        end)
                    end
                    stw:Play()
                    done = true
                end)
                if not done then
                    tr.BackgroundColor3 = bg
                    kn.Position = kp
                    pcall(function() sheen.BackgroundTransparency = on and 0 or 1; sheen.Visible = on end)
                end
            end
            connect(tr.MouseButton1Click, function()
                on = not on; obj.Value = on; refresh(); emit(obj, on)
            end)
            function obj:SetValue(v) on = v and true or false; obj.Value = on; refresh() end
            function obj:Get() return on end
            registerConfig(self, obj, o, "Toggle")
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
            local bScale = inst("UIScale", b, { Scale = 1 })
            local press = inst("Frame", b, { Size = UDim2.fromScale(1, 1),
                BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1,
                BorderSizePixel = 0, ZIndex = 4 })
            corner(press, 7)
            local function pressOn()
                tweenProp(bScale, { Scale = 0.94 }, 0.08)
                tweenProp(press, { BackgroundTransparency = 0.78 }, 0.08)
            end
            local function pressOff()
                tweenProp(bScale, { Scale = 1 }, 0.12)
                tweenProp(press, { BackgroundTransparency = 1 }, 0.12)
            end
            connect(b.MouseButton1Down, pressOn)
            connect(b.MouseButton1Up, pressOff)
            connect(b.MouseLeave, pressOff)
            connect(b.MouseButton1Click, function() pressOff(); emit(obj, nil) end)
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
            bindDrag(tr, fromInput)
            function obj:SetValue(v) applyVal(v, false) end
            function obj:Get() return val end
            registerConfig(self, obj, o, "Slider")
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
            local MENU_MAX_H = 160
            local contentH = 8 + #options * 26
            local menuH = contentH < MENU_MAX_H and contentH or MENU_MAX_H
            local menu = inst("CanvasGroup", main, { Name = "DropMenu", Size = UDim2.fromOffset(140, menuH),
                Position = UDim2.fromOffset(176 + rx - 140, 34 + y + 36), BackgroundColor3 = C.Panel,
                BorderSizePixel = 0, Visible = false, GroupTransparency = 1, ZIndex = 14, Active = true })
            corner(menu, 7); stroke(menu, C.Line, 1, 0)
            local scroller = inst("ScrollingFrame", menu, { Name = "DropScroller",
                Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 0),
                CanvasSize = UDim2.new(0, 0, 0, contentH),
                ScrollingDirection = Enum.ScrollingDirection.Y,
                ScrollBarThickness = 3, BackgroundTransparency = 1,
                BorderSizePixel = 0, Active = true, ClipsDescendants = true, ZIndex = 14 })
            local checks = {}
            local function refreshChecks()
                for _, opt in ipairs(options) do
                    local ui = checks[opt]
                    if ui then
                        local on = selected[opt] and true or false
                        ui.row.BackgroundColor3 = on and Color3.new(1, 1, 1) or C.Row
                        ui.row.BackgroundTransparency = on and 0.86 or 0
                        ui.txt.TextColor3 = C.Text
                    end
                end
            end
            local menuOpen = false
            local outsideConn = nil
            local function closeMenu()
                if not menuOpen then return end
                menuOpen = false
                if outsideConn then pcall(function() outsideConn:Disconnect() end); outsideConn = nil end
                fade(menu, 1, 0.18, function() if not menuOpen then menu.Visible = false end end)
            end
            local function openMenu()
                if menuOpen then return end
                pcall(function()
                    for _, fn in ipairs(self._closePopups or {}) do if fn ~= closeMenu then fn() end end
                end)
                menuOpen = true
                menu.Visible = true
                fade(menu, 0, 0.18)
                pcall(function()
                    local uis = game:GetService("UserInputService")
                    if not uis then return end
                    outsideConn = uis.InputBegan:Connect(function(input)
                        if not menuOpen then return end
                        local t = input and input.UserInputType
                        if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then return end
                        local px, py = inputPoint(input)
                        if not hitTest(cap, px, py) and not hitTest(menu, px, py) then closeMenu() end
                    end)
                end)
            end
            self._closePopups = self._closePopups or {}
            table.insert(self._closePopups, closeMenu)
            for i, opt in ipairs(options) do
                local rb = inst("TextButton", scroller, { Size = UDim2.new(1, -8, 0, 22),
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
            registerConfig(self, obj, o, "Dropdown")
        elseif kind == "ColorPicker" then
            local def = isColor3(o.Default) and o.Default or Color3.fromRGB(255, 96, 96)
            local h, sat, val = colorToHSV(def)
            local sw = inst("TextButton", host, { Size = UDim2.fromOffset(110, 24),
                Position = UDim2.fromOffset(rx - 110, y + 7), BackgroundColor3 = def,
                BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 3 })
            corner(sw, 6); stroke(sw, C.Line, 1, 0)
            local swlbl = label(sw, "", 12, Color3.new(1, 1, 1), true, Enum.TextXAlignment.Center)
            swlbl.Size = UDim2.fromScale(1, 1); swlbl.ZIndex = 4
            local lstroke = stroke(swlbl, Color3.new(0, 0, 0), 1, 0.35)
            local pw, ph = 210, 158
            local panel = inst("CanvasGroup", main, { Name = "ColorPalette", Size = UDim2.fromOffset(pw, ph),
                Position = UDim2.new(0.5, -pw / 2, 0.5, -ph / 2), BackgroundColor3 = Color3.fromRGB(20, 20, 26),
                BorderSizePixel = 0, Visible = false, GroupTransparency = 1, ZIndex = 40 })
            corner(panel, 12); stroke(panel, C.Border, 1, 0.4)
            panel.ClipsDescendants = true
            self._colorPanels = self._colorPanels or {}
            table.insert(self._colorPanels, panel)
            local pad = 10
            local svW, svH = pw - pad * 2, 90
            local sv = inst("Frame", panel, { Name = "SV", Size = UDim2.fromOffset(svW, svH),
                Position = UDim2.fromOffset(pad, pad), BackgroundColor3 = hsvToColor(h, 1, 1),
                BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 41 })
            corner(sv, 6)
            local white = inst("Frame", sv, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1),
                BorderSizePixel = 0, ZIndex = 41 })
            inst("UIGradient", white, { Rotation = 0,
                Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }) })
            local black = inst("Frame", sv, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
                BorderSizePixel = 0, ZIndex = 41 })
            inst("UIGradient", black, { Rotation = 90,
                Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }) })
            local cursor = inst("Frame", sv, { Name = "SVCursor", Size = UDim2.fromOffset(10, 10),
                BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 43 })
            inst("UICorner", cursor, { CornerRadius = UDim.new(1, 0) })
            stroke(cursor, Color3.new(1, 1, 1), 1.5, 0)
            local hueY = pad + svH + 8
            local hue = inst("Frame", panel, { Name = "Hue", Size = UDim2.fromOffset(svW, 12),
                Position = UDim2.fromOffset(pad, hueY), BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 41 })
            corner(hue, 6)
            inst("UIGradient", hue, { Rotation = 0, Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
                ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
                ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
                ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
                ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
                ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)) }) })
            local hcur = inst("Frame", hue, { Name = "HueCursor", Size = UDim2.fromOffset(4, 16),
                BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 43 })
            corner(hcur, 2)
            local prev = inst("Frame", panel, { Name = "Preview", Size = UDim2.fromOffset(22, 22),
                Position = UDim2.fromOffset(pad, ph - pad - 22), BorderSizePixel = 0, ZIndex = 41 })
            corner(prev, 5); stroke(prev, C.Border, 1, 0.4)
            local hexLabel = label(panel, "", 12, C.Text, false, Enum.TextXAlignment.Left)
            hexLabel.Size = UDim2.new(1, -pad * 2 - 34, 0, 22)
            hexLabel.Position = UDim2.fromOffset(pad + 30, ph - pad - 22); hexLabel.ZIndex = 41
            local function toHex(c)
                return string.format("#%02X%02X%02X",
                    math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
            end
            local function refresh(fire)
                local c = hsvToColor(h, sat, val)
                local hex = toHex(c)
                sw.BackgroundColor3 = c
                swlbl.Text = hex
                prev.BackgroundColor3 = c
                hexLabel.Text = hex
                sv.BackgroundColor3 = hsvToColor(h, 1, 1)
                cursor.Position = UDim2.new(sat, -5, 1 - val, -5)
                hcur.Position = UDim2.new(h, -2, 0.5, -8)
                obj.Value = c
                if fire then emit(obj, c) end
            end
            local function releaseGrab()
                local g = self._colorGrab
                if not g then return end
                self._colorGrab = nil
                for _, cn in ipairs(g.conns) do pcall(function() cn:Disconnect() end) end
            end
            self._releaseColorGrab = releaseGrab
            local function grab(apply, initial)
                releaseGrab()
                local px, py = inputPoint(initial)
                apply(px, py)
                local session = { conns = {} }
                pcall(function()
                    local uis = game:GetService("UserInputService")
                    if not uis then return end
                    session.conns[1] = uis.InputChanged:Connect(function(i)
                        if self._colorGrab ~= session then return end
                        local t = i and i.UserInputType
                        if t == Enum.UserInputType.MouseMovement or t == Enum.UserInputType.Touch then
                            local mx, my = inputPoint(i)
                            apply(mx, my)
                        end
                    end)
                    session.conns[2] = uis.InputEnded:Connect(function(i)
                        if self._colorGrab ~= session then return end
                        local t = i and i.UserInputType
                        if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
                            releaseGrab()
                        end
                    end)
                end)
                self._colorGrab = session
            end
            local function setSV(px, py)
                local okp, p, sz = pcall(function() return sv.AbsolutePosition, sv.AbsoluteSize end)
                if not okp or not p or not sz then return end
                sat = clamp((px - p.X) / math.max(1, sz.X), 0, 1)
                val = 1 - clamp((py - p.Y) / math.max(1, sz.Y), 0, 1)
                refresh(true)
            end
            local function setHue(px)
                local okp, p, sz = pcall(function() return hue.AbsolutePosition, hue.AbsoluteSize end)
                if not okp or not p or not sz then return end
                h = clamp((px - p.X) / math.max(1, sz.X), 0, 1)
                refresh(true)
            end
            inst("TextButton", panel, { Name = "ColorPanelHit", Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 42, Active = true })
            local svHit = inst("TextButton", panel, { Name = "SVHit", Size = UDim2.fromOffset(svW, svH),
                Position = UDim2.fromOffset(pad, pad), BackgroundTransparency = 1, Text = "",
                AutoButtonColor = false, ZIndex = 45, Active = true })
            connect(svHit.InputBegan, function(i)
                local t = i and i.UserInputType
                if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then grab(setSV, i) end
            end)
            local hueHit = inst("TextButton", panel, { Name = "HueHit", Size = UDim2.fromOffset(svW, 12),
                Position = UDim2.fromOffset(pad, hueY), BackgroundTransparency = 1, Text = "",
                AutoButtonColor = false, ZIndex = 45, Active = true })
            connect(hueHit.InputBegan, function(i)
                local t = i and i.UserInputType
                if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then grab(setHue, i) end
            end)
            local function closePalette()
                if not panel.Visible then return end
                releaseGrab()
                fade(panel, 1, 0.18, function() panel.Visible = false end)
            end
            local function openPalette()
                pcall(function()
                    for _, fn in ipairs(self._closePopups or {}) do if fn ~= closePalette then fn() end end
                end)
                panel.Visible = true
                fade(panel, 0, 0.18)
            end
            self._closePopups = self._closePopups or {}
            table.insert(self._closePopups, closePalette)
            connect(sw.MouseButton1Click, function()
                if panel.Visible then closePalette() else openPalette() end
            end)
            refresh(false)
            function obj:Set(c)
                if isColor3(c) then
                    h, sat, val = colorToHSV(c)
                    refresh(false)
                end
            end
            obj.SetValue = obj.Set
            function obj:Get() return hsvToColor(h, sat, val) end
            registerConfig(self, obj, o, "ColorPicker")
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
        tweenShadeAlpha(shade, 1, 0.2)
    end
    function self:_openCloseConfirm()
        shade.Visible = true; confirm.Visible = true
        tweenShadeAlpha(shade, 0.35, 0.3)
        fade(confirm, 0, 0.22)
    end
    local closing = false
    function self:_closeWindow()
        if closing then return end
        closing = true
        self._closing = true
        dragging = false
        if type(self._scaleTweens) == "table" then
            for _, tw in pairs(self._scaleTweens) do
                if tw then pcall(function() tw:Cancel() end) end
            end
        end
        self._scaleTweens = nil
        pcall(function() if self._intro and self._intro.layer and self._intro.layer.Parent then self._intro.layer.Visible = false end end)
        local sc = self._baseScale or SCALE
        pcall(function() sc = self._mainScale.Scale end)
        if type(sc) ~= "number" or sc <= 0 then sc = self._baseScale or SCALE end
        pcall(function()
            local cs = main.Size
            local cw = cs.X.Offset + cs.X.Scale
            local ch = cs.Y.Offset + cs.Y.Scale
            local p = main.Position
            main.AnchorPoint = Vector2.new(0.5, 0.5)
            main.Position = UDim2.new(p.X.Scale, p.X.Offset + cw * sc / 2,
                p.Y.Scale, p.Y.Offset + ch * sc / 2)
        end)
        pcall(function() main.GroupTransparency = 0 end)
        local function atCenter(dy)
            local p = main.Position
            return UDim2.new(p.X.Scale, p.X.Offset, p.Y.Scale, p.Y.Offset + (dy or 0))
        end
        fade(confirm, 1, 0.2, function() confirm.Visible = false end)
        tweenShadeAlpha(shade, 1, 0.2)
        if type(self._stopExitHint) == "function" then self._stopExitHint() end
        local function later(t, fn)
            if type(task) == "table" and type(task.delay) == "function" then
                pcall(task.delay, t, fn)
            else
                fn()
            end
        end
        local rows = {}
        local function grab(cont, dir)
            if not cont then return end
            local ok, kids = pcall(function() return cont:GetChildren() end)
            if not ok or type(kids) ~= "table" then return end
            for _, c in ipairs(kids) do
                local okCls, cls = pcall(function() return c.ClassName end)
                if okCls and (cls == "Frame" or cls == "TextButton" or cls == "ImageButton"
                    or cls == "TextLabel" or cls == "ImageLabel" or cls == "CanvasGroup"
                    or cls == "ScrollingFrame") then
                    rows[#rows + 1] = { obj = c, dir = dir }
                end
            end
        end
        grab(detail, 1)
        grab(side, -1)
        for i = 1, #rows do
            local r = rows[i]
            local okP, p = pcall(function() return r.obj.Position end)
            local stagger = (#rows - i) * 0.025
            if okP and p and p.X and p.Y then
                local target = UDim2.new(p.X.Scale, p.X.Offset + r.dir * 140, p.Y.Scale, p.Y.Offset)
                tweenProp(r.obj, { Position = target }, 0.42, nil, stagger)
            end
            deepFade(r.obj, 1, 0.38, stagger)
        end
        deepFade(bt, 1, 0.3)
        for _, d in ipairs(dotList) do deepFade(d, 1, 0.3) end
        if hintIcon then deepFade(hintIcon, 1, 0.2) end
        if hintText then deepFade(hintText, 1, 0.2) end
        local containerFadeDelay = 0.06 + #rows * 0.025
        later(containerFadeDelay, function()
            local kids = nil
            pcall(function() kids = main:GetChildren() end)
            if kids then
                for _, c in ipairs(kids) do
                    local okCls, cls = pcall(function() return c.ClassName end)
                    if okCls and (cls == "Frame" or cls == "ScrollingFrame" or cls == "CanvasGroup") then
                        deepFade(c, 1, 0.24)
                    end
                end
            end
            for _, d in ipairs(dotList) do pcall(function() d.Visible = false end) end
        end)
        local fx = inst("CanvasGroup", gui, { Name = "CloseFx", Size = UDim2.fromScale(1, 1),
            Position = UDim2.fromOffset(0, 0), BackgroundTransparency = 1,
            GroupTransparency = 0, BorderSizePixel = 0, Visible = false, ZIndex = 200 })
        local centerIcon = inst("ImageLabel", fx, { Name = "ThanksIcon",
            Size = UDim2.fromOffset(72, 72), Position = atCenter(-34),
            AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1,
            ImageTransparency = 1, ZIndex = 202 })
        applyIcon(centerIcon, "handshake", C.Accent)
        local thanksText = label(fx, "感谢使用", 20, C.Text, true, Enum.TextXAlignment.Center)
        thanksText.Name = "ThanksText"
        thanksText.Size = UDim2.fromOffset(240, 30)
        thanksText.Position = atCenter(28)
        thanksText.AnchorPoint = Vector2.new(0.5, 0.5)
        thanksText.TextTransparency = 1
        thanksText.ZIndex = 202
        local function stageThanks()
            fx.Visible = true
            tweenProp(centerIcon, { ImageTransparency = 0 }, 0.4)
            tweenProp(thanksText, { TextTransparency = 0 }, 0.4)
        end
        local function stageCollapse()
            local d = 150
            tweenProp(main, { Size = UDim2.fromOffset(d, d) }, 0.7)
            if mainCorner then
                tweenProp(mainCorner, { CornerRadius = UDim.new(0, d / 2) }, 0.7)
            end
            local iconSize = math.max(26, math.floor(d * sc * 0.42))
            tweenProp(centerIcon, { Size = UDim2.fromOffset(iconSize, iconSize),
                Position = atCenter(0) }, 0.7)
            tweenProp(thanksText, { Position = atCenter(iconSize * 0.5 + 18) }, 0.7)
        end
        local function stageVanish()
            fade(main, 1, 0.5)
            tweenProp(main, { Size = UDim2.fromOffset(6, 6) }, 0.5)
            tweenProp(centerIcon, { ImageTransparency = 1, Size = UDim2.fromOffset(8, 8) }, 0.5)
            tweenProp(thanksText, { TextTransparency = 1 }, 0.4)
        end
        local function stageParticles()
            local parts = {}
            local N = 20
            local palette = { C.Accent, C.AccentW, C.Accent2, Color3.new(1, 1, 1) }
            local origin = main.Position
            local ox, oy = origin.X.Scale, origin.Y.Scale
            local oox, ooy = origin.X.Offset, origin.Y.Offset
            for i = 1, N do
                local p = inst("Frame", fx, { Name = "Particle",
                    Size = UDim2.fromOffset(9, 9), Position = UDim2.new(ox, oox, oy, ooy),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundColor3 = palette[(i % #palette) + 1],
                    BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 204 })
                corner(p, 5)
                parts[#parts + 1] = p
            end
            local R1, R2 = 190, 2400
            for i, p in ipairs(parts) do
                local ang = (i / N) * math.pi * 2
                local dx, dy = math.cos(ang), math.sin(ang)
                local deg = i * (360 / N)
                local p1 = UDim2.new(ox, oox + dx * R1, oy, ooy + dy * R1)
                local p2 = UDim2.new(ox, oox + dx * R2, oy, ooy + dy * R2)
                local d1 = (i % 5) * 0.015
                later(d1, function()
                    tweenProp(p, { Position = p1, BackgroundTransparency = 0 }, 0.32)
                end)
                later(0.34 + d1, function()
                    pcall(function() p.Rotation = deg end)
                    tweenProp(p, { Position = p2, Size = UDim2.fromOffset(2, 340),
                        BackgroundTransparency = 1 }, 0.75, function()
                        pcall(function() if p.Parent then p:Destroy() end end)
                    end)
                end)
            end
            later(1.3, function()
                pcall(function() if self.gui and self.gui.Parent then self.gui:Destroy() end end)
            end)
        end
        local t0 = containerFadeDelay + 0.28
        later(t0, stageThanks)
        later(t0 + 1.5, function() tweenProp(thanksText, { TextTransparency = 1 }, 0.5) end)
        later(t0 + 2.05, stageCollapse)
        later(t0 + 2.8, stageVanish)
        later(t0 + 3.35, stageParticles)
    end
    connect(noBtn.MouseButton1Click, function() hideConfirm() end)
    connect(yesBtn.MouseButton1Click, function() self:_closeWindow() end)
    connect(shade.MouseButton1Click, function() hideConfirm() end)
    if opts.LoginInfo == true then
        Axiom._buildLogin(self, opts, main, bar, bt, gui, contentLayer, dotList)
    end
    local introLayer = inst("CanvasGroup", gui, { Name = "IntroLayer", Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromOffset(0, 0), BackgroundTransparency = 1,
        GroupTransparency = 0, BorderSizePixel = 0, Visible = false, ZIndex = 60 })
    local introDim = inst("Frame", introLayer, { Name = "IntroDim", Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1,
        BorderSizePixel = 0, ZIndex = 61 })
    local introBorder = inst("Frame", introLayer, { Name = "IntroBorder", Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromOffset(0, 0), BackgroundTransparency = 1,
        BorderSizePixel = 0, ZIndex = 62 })
    local introCorner = corner(introBorder, 0)              
    local introStroke = stroke(introBorder, C.Border, 3, 1) 
    local introTitle = inst("TextLabel", introLayer, { Name = "IntroTitle",
        Text = opts.Title or "AXIOM", Font = Enum.Font.GothamBold, TextSize = 56,
        TextColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1,
        Size = UDim2.fromScale(0.9, 0.16), Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5), TextXAlignment = Enum.TextXAlignment.Center,
        TextTransparency = 1, ZIndex = 63 })
    self._intro = { layer = introLayer, dim = introDim, border = introBorder,
        corner = introCorner, stroke = introStroke, title = introTitle }
    local finW, finH = W * SCALE, H * SCALE
    local finSize = UDim2.fromOffset(finW, finH)
    local finPos = UDim2.new(0.5, -finW / 2, 0.5, -finH / 2)
    local finCorner = 12 * SCALE
    local titleEndPos = UDim2.new(0.5, 0, 0.5, -finH / 2 + 11)
    local CURVE = Enum.EasingStyle.Quint 
    local function playIntro(done)
        introLayer.Visible = true
        tweenEx(introDim, { BackgroundTransparency = 0.72 }, 0.3, CURVE, Enum.EasingDirection.Out)
        tweenEx(introTitle, { TextTransparency = 0 }, 0.26, CURVE, Enum.EasingDirection.Out)
        tweenEx(introStroke, { Transparency = 0 }, 0.26, CURVE, Enum.EasingDirection.Out)
        local CONV = 0.82
        tweenEx(introBorder, { Size = finSize, Position = finPos }, CONV, CURVE, Enum.EasingDirection.InOut, nil, 0.28)
        tweenEx(introCorner, { CornerRadius = UDim.new(0, finCorner) }, CONV, CURVE, Enum.EasingDirection.InOut, nil, 0.28)
        tweenEx(introTitle, { Size = UDim2.fromOffset(240, 26), TextSize = 12, Position = titleEndPos },
            CONV, CURVE, Enum.EasingDirection.InOut, nil, 0.28)
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
    local shown = false
    local function reveal()
        if shown or self._closing then return end
        shown = true
        playIntro(function() if not self._closing then fade(main, 0, 0.35) end end)
    end
    self._reveal = reveal
    local function preload()
        pcall(function() loadLucide() end)
        if self._wallpaper then
            local asset = resolveImage(bgSrc, assetDir)
            pcall(function() self._wallpaper.Image = asset or "" end)
            local cpOk, cp = pcall(function() return game:GetService("ContentProvider") end)
            if cpOk and cp and type(cp.PreloadAsync) == "function" then
                local fired = false
                local function ready()
                    if fired then return end
                    fired = true
                    reveal()
                end
                pcall(function() cp:PreloadAsync({ self._wallpaper }, function() ready() end) end)
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
    if type(task) == "table" and type(task.delay) == "function" then
        pcall(task.delay, 8, reveal)
    end
    return self
end
local function listConfigFiles(win)
    local out, seen = {}, {}
    local dir = win._configDir or (win._assetDir and (win._assetDir .. "/" .. CONFIG_DIR_NAME))
    if dir and type(listfiles) == "function" then
        pcall(function()
            if type(isfolder) == "function" and not isfolder(dir) then return end
            local files = listfiles(dir)
            if type(files) ~= "table" then return end
            for _, f in ipairs(files) do
                local base = tostring(f):match("([^/\\]+)%.json$")
                if base and base ~= "" and not seen[base] then seen[base] = true; out[#out + 1] = base end
            end
        end)
    end
    table.sort(out, function(a, b) return a:lower() < b:lower() end)
    return out
end
function Axiom:SaveConfig(name)
    local path, resolved = resolveConfigPath(self, name)
    if path then self._configPath = path; self._configName = resolved end
    if not path then path = self._configPath end
    for _, ctrl in pairs(self._config or {}) do
        if ctrl then
            local ok, val = pcall(function() return ctrl._configGet and ctrl._configGet() or ctrl.Value end)
            ctrl._configCurrent = ok and val or ctrl.Value
            syncConfigValue(ctrl)
        end
    end
    if path then
        pcall(function()
            local data = {}
            for key, ctrl in pairs(self._config or {}) do
                if ctrl and ctrl._configCurrent ~= nil then data[key] = cfgToJSON(ctrl._configCurrent) end
            end
            writefile(path, jsonEncodeValue(data))
            if self._assetDir then
                writefile(self._assetDir .. "/active.json", jsonEncodeValue({ name = self._configName or DEFAULT_CONFIG }))
            end
        end)
    end
    return self
end
function Axiom:_autoSave() return self end
function Axiom:LoadConfig(name)
    if name == nil and self._assetDir then
        local active
        pcall(function()
            local ap = self._assetDir .. "/active.json"
            if fileExists(ap) then
                local ok, d = pcall(function() return jsonDecodeRaw(readfile(ap)) end)
                if ok and type(d) == "table" and type(d.name) == "string" and d.name ~= "" then active = d.name end
            end
        end)
        if active and fileExists(resolveConfigPath(self, active)) then name = active end
    end
    local path, resolved = resolveConfigPath(self, name)
    if not path then return false end
    if name ~= nil and not fileExists(path) then return false end
    local data = nil
    pcall(function()
        if fileExists(path) then
            local raw = readfile(path)
            local ok, d = pcall(function() return jsonDecodeRaw(raw) end)
            if ok and type(d) == "table" then data = d end
        end
    end)
    self._configPath = path
    self._configName = resolved or DEFAULT_CONFIG
    self._loadingConfig = true
    for key, ctrl in pairs(self._config or {}) do
        if data and data[key] ~= nil and type(ctrl.Set) == "function" then
            pcall(function() ctrl:Set(jsonToCfg(data[key])) end)
        end
        ctrl._configCurrent = ctrl._configGet and ctrl._configGet() or ctrl.Value
        syncConfigValue(ctrl)
    end
    self._loadingConfig = false
    return true
end
function Axiom:GetConfigs()
    local out, seen = { DEFAULT_CONFIG }, { [DEFAULT_CONFIG] = true }
    for _, n in ipairs(listConfigFiles(self)) do
        if not seen[n] and n ~= DEFAULT_CONFIG then seen[n] = true; out[#out + 1] = n end
    end
    return out
end
function Axiom:ConfigExists(name) return fileExists(resolveConfigPath(self, name)) end
function Axiom:SetConfig(name)
    local path, resolved = resolveConfigPath(self, name)
    if not path then return false end
    self._configPath = path; self._configName = resolved
    return true
end
function Axiom:DeleteConfig(name)
    local path, resolved = resolveConfigPath(self, name)
    if not path or resolved == DEFAULT_CONFIG then return false end
    local removed = false
    pcall(function() if fileExists(path) then delfile(path); removed = true end end)
    if self._configName == resolved then
        self._configName = DEFAULT_CONFIG
        self._configPath = self._assetDir .. "/config.json"
    end
    return removed
end
function Axiom:RenameConfig(oldName, newName)
    local from, fromName = resolveConfigPath(self, oldName)
    local to, toName = resolveConfigPath(self, newName)
    if not (from and to) then return false end
    if fromName == DEFAULT_CONFIG or toName == DEFAULT_CONFIG then return false end
    if fromName == toName or fileExists(to) then return false end
    local ok = false
    pcall(function() if fileExists(from) then writefile(to, readfile(from)); delfile(from); ok = true end end)
    if ok and self._configName == fromName then self._configName = toName; self._configPath = to end
    return ok
end
function Axiom:GetConfigName() return self._configName or DEFAULT_CONFIG end
function Axiom:GetConfigPath() return self._configPath end
function Axiom:GetConfigDir() return self._configDir end
function Axiom:GetAssetDir() return self._assetDir end
return Axiom