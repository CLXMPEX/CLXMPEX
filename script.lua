-- ============================================================
--  ESCORT REMOTE SPY  (captures the REAL escort start call)
--
--  Hooks remote calls and logs anything escort/key/mission related
--  with FULL arguments, so we see exactly what the game sends when
--  you start Journey's End the normal way.
--
--  SAFE: uses hookmetamethod, restores on close, logging is off the
--  hot path so it won't freeze your taps. Tap X to fully unhook.
--
--  HOW TO USE:
--   1) Run it (stand in lobby).
--   2) Start the escort the NORMAL way: talk to Elf Mage ->
--      "I'll escort you there" -> pick a key -> Start Mission.
--   3) Watch the log fill. Tap COPY, paste to Claude.
-- ============================================================

local Players = game:GetService("Players")
local player  = Players.LocalPlayer
local pgui    = player:WaitForChild("PlayerGui", 10)

local lines = {}
local outLabel
local count = 0
local paused = false
local function render() if outLabel then outLabel.Text = table.concat(lines, "\n") end end
local function push(s)
    table.insert(lines, 1, s)
    while #lines > 300 do table.remove(lines) end
    render()
end

-- only log calls whose remote name relates to escort/mission/key/start/lobby
local WATCH = { "escort","journey","mission","key","start","create","lobby","begin","difficulty" }
local function watched(name)
    local low = string.lower(name)
    for _, w in ipairs(WATCH) do
        if string.find(low, w, 1, true) then return true end
    end
    return false
end

local function short(v, depth)
    depth = depth or 0
    local t = typeof(v)
    if t == "string" then return '"'..(#v>60 and v:sub(1,60).."~" or v)..'"' end
    if t == "number" or t == "boolean" then return tostring(v) end
    if t == "nil" then return "nil" end
    if t == "Instance" then return "<"..v.ClassName..":"..v.Name..">" end
    if t == "Vector3" then return string.format("V3(%.1f,%.1f,%.1f)",v.X,v.Y,v.Z) end
    if t == "CFrame" then local p=v.Position return string.format("CF(%.1f,%.1f,%.1f)",p.X,p.Y,p.Z) end
    if t == "table" then
        if depth > 3 then return "{...}" end
        local parts, n = {}, 0
        for k, vv in pairs(v) do
            n = n + 1
            if n > 20 then table.insert(parts,"..."); break end
            table.insert(parts, tostring(k).."="..short(vv, depth+1))
        end
        return "{"..table.concat(parts, ", ").."}"
    end
    return t
end
local function argsToStr(args, n)
    local p = {}
    for i = 1, n do p[i] = short(args[i]) end
    return table.concat(p, ", ")
end

-- ---------- hook ----------
local hookedOk = false
local unhook = nil
pcall(function()
    if hookmetamethod and newcclosure then
        local original
        original = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            local method = getnamecallmethod and getnamecallmethod() or ""
            if not paused and (method == "FireServer" or method == "InvokeServer") then
                if typeof(self) == "Instance"
                   and (self:IsA("RemoteEvent") or self:IsA("RemoteFunction")
                        or self:IsA("UnreliableRemoteEvent")) then
                    local nm = self.Name
                    if watched(nm) then
                        local n = select("#", ...)
                        local args = { ... }
                        count = count + 1
                        task.spawn(function()
                            push("["..count.."] "..method.."  "..nm)
                            push("     args("..n.."): "..(n>0 and argsToStr(args,n) or "(none)"))
                        end)
                    end
                end
            end
            return original(self, ...)
        end))
        unhook = function() pcall(function() hookmetamethod(game, "__namecall", original) end) end
        hookedOk = true
    end
end)

-- ---------- GUI ----------
local sg = Instance.new("ScreenGui")
sg.Name = "EscortSpy"; sg.ResetOnSpawn = false; sg.DisplayOrder = 99999
sg.IgnoreGuiInset = true; sg.Parent = pgui

local panel = Instance.new("Frame", sg)
panel.Size = UDim2.new(0, 380, 0, 320); panel.Position = UDim2.new(0, 14, 0, 54)
panel.BackgroundColor3 = Color3.fromRGB(10,10,16); panel.BorderSizePixel = 0
Instance.new("UICorner", panel).CornerRadius = UDim.new(0,8)
local strk = Instance.new("UIStroke", panel); strk.Color = Color3.fromRGB(255,150,210); strk.Thickness = 1

local top = Instance.new("Frame", panel)
top.Size = UDim2.new(1,0,0,28); top.BackgroundColor3 = Color3.fromRGB(24,20,28)
top.BorderSizePixel = 0; Instance.new("UICorner", top).CornerRadius = UDim.new(0,8)
local title = Instance.new("TextLabel", top)
title.Size = UDim2.new(0.7,0,1,0); title.Position = UDim2.new(0,8,0,0)
title.BackgroundTransparency = 1; title.TextColor3 = Color3.fromRGB(255,160,215)
title.Font = Enum.Font.GothamBold; title.TextSize = 12
title.TextXAlignment = Enum.TextXAlignment.Left; title.Text = "ESCORT SPY: 0"

local btnRow = Instance.new("Frame", panel)
btnRow.Size = UDim2.new(1,-8,0,26); btnRow.Position = UDim2.new(0,4,0,30)
btnRow.BackgroundTransparency = 1
local function mkBtn(txt,color,x,w)
    local b = Instance.new("TextButton", btnRow)
    b.Size = UDim2.new(0,w,1,0); b.Position = UDim2.new(0,x,0,0)
    b.BackgroundColor3 = color; b.Text = txt; b.TextColor3 = Color3.new(1,1,1)
    b.Font = Enum.Font.GothamBold; b.TextSize = 11; b.BorderSizePixel = 0
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)
    return b
end
local pauseBtn = mkBtn("PAUSE", Color3.fromRGB(200,150,40), 0,   80)
local clearBtn = mkBtn("CLEAR", Color3.fromRGB(90,90,110),  84,  70)
local copyBtn  = mkBtn("COPY",  Color3.fromRGB(70,130,210), 158, 80)
local closeBtn = mkBtn("X",     Color3.fromRGB(200,55,55),  242, 50)

local scroll = Instance.new("ScrollingFrame", panel)
scroll.Size = UDim2.new(1,-8,1,-62); scroll.Position = UDim2.new(0,4,0,58)
scroll.BackgroundColor3 = Color3.fromRGB(6,6,10); scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 5; scroll.ScrollBarImageColor3 = Color3.fromRGB(255,150,210)
scroll.CanvasSize = UDim2.new(0,0,0,0); scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Instance.new("UICorner", scroll).CornerRadius = UDim.new(0,6)
outLabel = Instance.new("TextLabel", scroll)
outLabel.Size = UDim2.new(1,-8,0,0); outLabel.Position = UDim2.new(0,4,0,2)
outLabel.AutomaticSize = Enum.AutomaticSize.Y; outLabel.BackgroundTransparency = 1
outLabel.TextColor3 = Color3.fromRGB(225,230,240); outLabel.Font = Enum.Font.Code
outLabel.TextSize = 10; outLabel.TextXAlignment = Enum.TextXAlignment.Left
outLabel.TextYAlignment = Enum.TextYAlignment.Top; outLabel.TextWrapped = true; outLabel.Text = ""

pauseBtn.MouseButton1Click:Connect(function()
    paused = not paused
    pauseBtn.Text = paused and "RESUME" or "PAUSE"
    pauseBtn.BackgroundColor3 = paused and Color3.fromRGB(60,160,90) or Color3.fromRGB(200,150,40)
end)
clearBtn.MouseButton1Click:Connect(function() lines = {}; render() end)
copyBtn.MouseButton1Click:Connect(function()
    local ordered = {}
    for i = #lines, 1, -1 do table.insert(ordered, lines[i]) end
    local out = "=== ESCORT SPY ===\nhook: "..(hookedOk and "ok" or "FAILED").."\n"..table.concat(ordered,"\n")
    local clip = setclipboard or toclipboard or set_clipboard or (syn and syn.write_clipboard)
    local ok = clip and pcall(function() clip(out) end)
    copyBtn.Text = ok and "COPIED!" or "NO CLIP"; task.wait(1.2); copyBtn.Text = "COPY"
end)
closeBtn.MouseButton1Click:Connect(function()
    if unhook then pcall(unhook) end
    sg:Destroy()
end)

task.spawn(function()
    while sg.Parent do
        title.Text = "ESCORT SPY: "..count..(paused and " [PAUSED]" or "")
        task.wait(0.3)
    end
end)

push(hookedOk and "hook ok — start the escort normally now" or "HOOK FAILED (executor)")
push("Talk to Elf Mage -> escort -> pick key -> Start Mission.")
push("Then tap COPY and paste to Claude.")
