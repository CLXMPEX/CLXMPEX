-- ============================================================
--  GAME EXPLORER  (passive — NO hooks, cannot block input)
--
--  The remote spy blocked your screen because hooking __namecall
--  intercepts EVERY tap on this game. This version hooks NOTHING.
--  It only READS the game and dumps what it finds. Your screen and
--  buying/selling work completely normally the whole time.
--
--  Tap a category button to scan it; read the results; COPY to send.
--   REMOTES  — every RemoteEvent/Function + path
--   MODULES  — ModuleScripts likely holding shop/seed/fruit data
--   SHOP     — anything named shop/buy/seed/purchase
--   FRUIT    — anything named fruit/sell/harvest/crop
--   DATA     — your player data (leaderstats, attributes, folders)
-- ============================================================

local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
local player  = Players.LocalPlayer
local pgui    = player:WaitForChild("PlayerGui", 10)

-- ---------- log ----------
local lines = {}
local function refresh() end  -- set after label made
local out
local function log(s)
    table.insert(lines, s)
    if #lines > 800 then table.remove(lines, 1) end
    if out then out.Text = table.concat(lines, "\n") end
end
local function clear() lines = {}; if out then out.Text = "" end end

-- ---------- value stringify (read-only, safe) ----------
local function short(v, depth)
    depth = depth or 0
    local t = typeof(v)
    if t == "string" then return (#v > 50 and (v:sub(1,50).."~") or v) end
    if t == "number" or t == "boolean" then return tostring(v) end
    if t == "Instance" then return "<"..v.ClassName..">" end
    if t == "Vector3" then return string.format("V3(%.0f,%.0f,%.0f)",v.X,v.Y,v.Z) end
    if t == "table" then
        if depth > 2 then return "{...}" end
        local p, n = {}, 0
        for k, vv in pairs(v) do
            n = n + 1
            if n > 20 then table.insert(p, "..."); break end
            table.insert(p, tostring(k).."="..short(vv, depth+1))
        end
        return "{"..table.concat(p, ", ").."}"
    end
    return t
end

-- ---------- scans ----------
local function scanRemotes()
    clear()
    log("===== REMOTES =====")
    local found = {}
    for _, d in ipairs(RS:GetDescendants()) do
        if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("UnreliableRemoteEvent") then
            local cls = d:IsA("RemoteFunction") and "RF" or "RE"
            local path = d.Name
            pcall(function() path = d:GetFullName() end)
            table.insert(found, cls.."  "..path)
        end
    end
    table.sort(found)
    for _, s in ipairs(found) do log(s) end
    log("total: "..#found)
end

local function scanModules(filterWords)
    clear()
    log("===== MODULES"..(filterWords and " (filtered)" or "").." =====")
    local n = 0
    for _, d in ipairs(RS:GetDescendants()) do
        if d:IsA("ModuleScript") then
            local nm = string.lower(d.Name)
            local match = not filterWords
            if filterWords then
                for _, w in ipairs(filterWords) do
                    if string.find(nm, w, 1, true) then match = true; break end
                end
            end
            if match then
                n = n + 1
                if n <= 120 then
                    local path = d.Name
                    pcall(function() path = d:GetFullName() end)
                    log(d.Name.."   ["..path.."]")
                end
            end
        end
    end
    log("total matched: "..n)
end

-- generic name search across RS + workspace for buy/sell/seed/fruit
local function scanByWords(title, words)
    clear()
    log("===== "..title.." =====")
    local roots = { RS, workspace, player }
    local n = 0
    local seen = {}
    for _, root in ipairs(roots) do
        for _, d in ipairs(root:GetDescendants()) do
            if seen[d] then continue end
            local nm = string.lower(d.Name)
            for _, w in ipairs(words) do
                if string.find(nm, w, 1, true) then
                    seen[d] = true
                    n = n + 1
                    if n <= 150 then
                        local path = d.Name
                        pcall(function() path = d:GetFullName() end)
                        log(d.ClassName.."  "..path)
                    end
                    break
                end
            end
        end
    end
    log("total: "..n)
end

local function scanData()
    clear()
    log("===== PLAYER DATA =====")
    -- leaderstats
    local ls = player:FindFirstChild("leaderstats")
    if ls then
        log("-- leaderstats --")
        for _, v in ipairs(ls:GetChildren()) do
            log("  "..v.Name.." = "..short(v.Value ~= nil and v.Value or "?"))
        end
    else
        log("no leaderstats")
    end
    -- attributes on player
    log("-- player attributes --")
    for k, v in pairs(player:GetAttributes()) do
        log("  "..k.." = "..short(v))
    end
    -- child folders of player (data holders)
    log("-- player child folders --")
    for _, c in ipairs(player:GetChildren()) do
        if c:IsA("Folder") or c:IsA("Configuration") then
            log("  "..c.Name.." ("..#c:GetChildren().." kids)")
        end
    end
    -- common data folders in RS
    log("-- RS data-ish folders --")
    for _, d in ipairs(RS:GetChildren()) do
        local nm = string.lower(d.Name)
        if string.find(nm,"data",1,true) or string.find(nm,"config",1,true)
           or string.find(nm,"item",1,true) or string.find(nm,"shop",1,true) then
            log("  "..d.Name.." ("..d.ClassName..")")
        end
    end
end

-- ---------- GUI (plain frame, NO hooks anywhere) ----------
local sg = Instance.new("ScreenGui")
sg.Name = "GameExplorer"
sg.ResetOnSpawn = false
sg.DisplayOrder = 99999
sg.IgnoreGuiInset = true
sg.Parent = pgui

local panel = Instance.new("Frame", sg)
panel.Size = UDim2.new(0, 400, 0, 360)
panel.Position = UDim2.new(0, 14, 0, 54)
panel.BackgroundColor3 = Color3.fromRGB(14, 16, 20)
panel.BackgroundTransparency = 0.05
panel.BorderSizePixel = 0
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)
local strk = Instance.new("UIStroke", panel)
strk.Color = Color3.fromRGB(90, 200, 130); strk.Thickness = 1

local top = Instance.new("Frame", panel)
top.Size = UDim2.new(1, 0, 0, 30)
top.BackgroundColor3 = Color3.fromRGB(20, 26, 22)
top.BorderSizePixel = 0
Instance.new("UICorner", top).CornerRadius = UDim.new(0, 10)
local title = Instance.new("TextLabel", top)
title.Size = UDim2.new(0.7, 0, 1, 0)
title.Position = UDim2.new(0, 10, 0, 0)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(120, 230, 150)
title.Font = Enum.Font.GothamBold
title.TextSize = 12
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "GAME EXPLORER (passive)"

-- two rows of category buttons
local row1 = Instance.new("Frame", panel)
row1.Size = UDim2.new(1, -8, 0, 26)
row1.Position = UDim2.new(0, 4, 0, 32)
row1.BackgroundTransparency = 1
local row2 = Instance.new("Frame", panel)
row2.Size = UDim2.new(1, -8, 0, 26)
row2.Position = UDim2.new(0, 4, 0, 60)
row2.BackgroundTransparency = 1

local function btn(parent, txt, color, x, w)
    local b = Instance.new("TextButton", parent)
    b.Size = UDim2.new(0, w, 1, 0)
    b.Position = UDim2.new(0, x, 0, 0)
    b.BackgroundColor3 = color
    b.Text = txt
    b.TextColor3 = Color3.new(1,1,1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 10
    b.BorderSizePixel = 0
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end

local bRemotes = btn(row1, "REMOTES", Color3.fromRGB(90,150,220), 0,   84)
local bModules = btn(row1, "MODULES", Color3.fromRGB(150,110,220), 88,  84)
local bShop    = btn(row1, "SHOP",    Color3.fromRGB(210,150,40),  176, 66)
local bFruit   = btn(row1, "FRUIT",   Color3.fromRGB(210,90,120),  246, 66)
local bData    = btn(row1, "DATA",    Color3.fromRGB(60,180,120),  316, 70)

local bCopy    = btn(row2, "COPY",    Color3.fromRGB(70,130,210),  0,   120)
local bClear   = btn(row2, "CLEAR",   Color3.fromRGB(90,90,110),   124, 100)
local bClose   = btn(row2, "CLOSE",   Color3.fromRGB(200,55,55),   228, 158)

-- output scroll
local scroll = Instance.new("ScrollingFrame", panel)
scroll.Size = UDim2.new(1, -8, 1, -94)
scroll.Position = UDim2.new(0, 4, 0, 90)
scroll.BackgroundColor3 = Color3.fromRGB(8, 10, 12)
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 5
scroll.ScrollBarImageColor3 = Color3.fromRGB(90, 200, 130)
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Instance.new("UICorner", scroll).CornerRadius = UDim.new(0, 6)

out = Instance.new("TextLabel", scroll)
out.Size = UDim2.new(1, -8, 0, 0)
out.Position = UDim2.new(0, 4, 0, 2)
out.AutomaticSize = Enum.AutomaticSize.Y
out.BackgroundTransparency = 1
out.TextColor3 = Color3.fromRGB(210, 230, 215)
out.Font = Enum.Font.Code
out.TextSize = 10
out.TextXAlignment = Enum.TextXAlignment.Left
out.TextYAlignment = Enum.TextYAlignment.Top
out.TextWrapped = true
out.Text = ""

-- wire buttons (each runs a passive scan in a separate thread)
local function run(fn) task.spawn(function() pcall(fn) end) end
bRemotes.MouseButton1Click:Connect(function() run(scanRemotes) end)
bModules.MouseButton1Click:Connect(function() run(function() scanModules() end) end)
bShop.MouseButton1Click:Connect(function() run(function()
    scanByWords("SHOP / BUY / SEED", {"shop","buy","seed","purchase","store","gourmet"})
end) end)
bFruit.MouseButton1Click:Connect(function() run(function()
    scanByWords("FRUIT / SELL / CROP", {"fruit","sell","harvest","crop","plant","produce"})
end) end)
bData.MouseButton1Click:Connect(function() run(scanData) end)
bClear.MouseButton1Click:Connect(clear)
bCopy.MouseButton1Click:Connect(function()
    local text = table.concat(lines, "\n")
    local clip = setclipboard or toclipboard or set_clipboard or (syn and syn.write_clipboard)
    local ok = clip and pcall(function() clip(text) end)
    bCopy.Text = ok and "COPIED!" or "NO CLIP"
    task.wait(1.2); bCopy.Text = "COPY"
end)
bClose.MouseButton1Click:Connect(function() sg:Destroy() end)

-- drag by top bar (only affects THIS window; touches nothing else)
local UIS = game:GetService("UserInputService")
local drag = { on=false }
top.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then
        drag.on=true; drag.s=i.Position; drag.p=panel.Position
    end
end)
UIS.InputChanged:Connect(function(i)
    if drag.on and (i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseMovement) then
        local d=i.Position-drag.s
        panel.Position=UDim2.new(drag.p.X.Scale,drag.p.X.Offset+d.X,drag.p.Y.Scale,drag.p.Y.Offset+d.Y)
    end
end)
UIS.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then
        drag.on=false
    end
end)

log("Passive explorer ready. No hooks — your screen works normally.")
log("Tap a category button above to scan, then COPY.")
log("Try SHOP and FRUIT first for buy/sell data.")
