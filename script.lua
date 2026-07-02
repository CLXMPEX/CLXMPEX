-- ============================================================
--  SEED / FRUIT FINDER  (v2 — totally passive, input-safe)
--
--  IMPORTANT: this script does NOT hook anything, does NOT touch
--  the metatable, and does NOT use any UserInputService/InputBegan
--  connections. Those are what were hijacking your taps and chat.
--  This only READS the game and shows results. Nothing you touch
--  is affected — chat, tapping, buying all work normally.
--
--  It runs ONE automatic scan on launch and shows the results.
--  Buttons: SCAN AGAIN · COPY · CLOSE  (plain buttons, no drag).
-- ============================================================

local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
local player  = Players.LocalPlayer
local pgui    = player:WaitForChild("PlayerGui", 10)

-- ---------- output store ----------
local lines = {}
local outLabel
local function render() if outLabel then outLabel.Text = table.concat(lines, "\n") end end
local function log(s) lines[#lines+1] = s; render() end
local function clear() lines = {}; render() end

-- ---------- readable value ----------
local function short(v, d)
    d = d or 0
    local t = typeof(v)
    if t == "string" then return (#v > 48 and v:sub(1,48).."~" or v) end
    if t == "number" or t == "boolean" then return tostring(v) end
    if t == "table" then
        if d > 2 then return "{...}" end
        local p, n = {}, 0
        for k, vv in pairs(v) do
            n = n + 1
            if n > 25 then p[#p+1] = "..."; break end
            p[#p+1] = tostring(k).."="..short(vv, d+1)
        end
        return "{"..table.concat(p, ", ").."}"
    end
    return t
end

-- try to require a module safely and dump its top-level keys
local function dumpModule(mod)
    local ok, data = pcall(require, mod)
    if not ok or typeof(data) ~= "table" then return false end
    local path = mod.Name
    pcall(function() path = mod:GetFullName() end)
    log("")
    log(">> MODULE: "..mod.Name)
    log("   "..path)
    local n = 0
    for k, v in pairs(data) do
        n = n + 1
        if n > 40 then log("   ...more"); break end
        log("   "..tostring(k).." = "..short(v))
    end
    return true
end

-- ---------- the scan ----------
local function scan()
    clear()
    log("===== SEED / FRUIT FINDER =====")
    log("(passive read — nothing you tap is affected)")

    -- 1) ModuleScripts whose name hints at shop / seed / fruit data
    log("")
    log("== data modules (shop/seed/fruit/item) ==")
    local dataWords = {"seed","fruit","shop","crop","plant","item","produce","harvest","gourmet","store"}
    local dumped = 0
    for _, d in ipairs(RS:GetDescendants()) do
        if d:IsA("ModuleScript") then
            local nm = string.lower(d.Name)
            for _, w in ipairs(dataWords) do
                if string.find(nm, w, 1, true) then
                    if dumped < 8 then
                        if dumpModule(d) then dumped = dumped + 1 end
                    end
                    break
                end
            end
        end
    end
    if dumped == 0 then log("  (no readable data modules matched)") end

    -- 2) Remotes (names only — for reference)
    log("")
    log("== remotes ==")
    local rem = {}
    for _, d in ipairs(RS:GetDescendants()) do
        if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("UnreliableRemoteEvent") then
            local path = d.Name
            pcall(function() path = d:GetFullName() end)
            rem[#rem+1] = (d:IsA("RemoteFunction") and "RF " or "RE ")..path
        end
    end
    table.sort(rem)
    for i = 1, math.min(#rem, 40) do log("  "..rem[i]) end
    log("  remotes total: "..#rem)

    -- 3) Objects named like seed/fruit/shop anywhere in RS + workspace
    log("")
    log("== named objects (seed/fruit/shop/sell/buy) ==")
    local words = {"seed","fruit","shop","sell","buy","crop","harvest"}
    local seen, n = {}, 0
    for _, root in ipairs({RS, workspace}) do
        for _, d in ipairs(root:GetDescendants()) do
            if not seen[d] then
                local nm = string.lower(d.Name)
                for _, w in ipairs(words) do
                    if string.find(nm, w, 1, true) then
                        seen[d] = true; n = n + 1
                        if n <= 60 then
                            local path = d.Name
                            pcall(function() path = d:GetFullName() end)
                            log("  "..d.ClassName.."  "..path)
                        end
                        break
                    end
                end
            end
        end
    end
    log("  named total: "..n)

    -- 4) player data
    log("")
    log("== player data ==")
    local ls = player:FindFirstChild("leaderstats")
    if ls then
        for _, v in ipairs(ls:GetChildren()) do
            log("  "..v.Name.." = "..short(v.Value ~= nil and v.Value or "?"))
        end
    else
        log("  no leaderstats")
    end
    for k, v in pairs(player:GetAttributes()) do
        log("  attr "..k.." = "..short(v))
    end

    log("")
    log("===== END. tap COPY, paste to Claude =====")
end

-- ============================================================
--  GUI  (plain fixed panel — NO input connections, NO drag)
-- ============================================================
local old = pgui:FindFirstChild("SeedFruitFinder")
if old then old:Destroy() end

local sg = Instance.new("ScreenGui")
sg.Name = "SeedFruitFinder"
sg.ResetOnSpawn = false
sg.DisplayOrder = 99999
sg.IgnoreGuiInset = true
sg.Parent = pgui

local panel = Instance.new("Frame", sg)
panel.Size = UDim2.new(0, 390, 0, 380)
panel.Position = UDim2.new(0, 12, 0, 60)
panel.BackgroundColor3 = Color3.fromRGB(16, 18, 22)
panel.BorderSizePixel = 0
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)
local strk = Instance.new("UIStroke", panel)
strk.Color = Color3.fromRGB(90, 200, 130); strk.Thickness = 1

local title = Instance.new("TextLabel", panel)
title.Size = UDim2.new(1, -12, 0, 26)
title.Position = UDim2.new(0, 10, 0, 6)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(120, 230, 150)
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "SEED / FRUIT FINDER  (safe)"

-- buttons
local function btn(txt, color, x, w, y)
    local b = Instance.new("TextButton", panel)
    b.Size = UDim2.new(0, w, 0, 30)
    b.Position = UDim2.new(0, x, 0, y)
    b.BackgroundColor3 = color
    b.Text = txt
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.BorderSizePixel = 0
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end

local scanBtn  = btn("SCAN AGAIN", Color3.fromRGB(60, 170, 110), 10,  120, 34)
local copyBtn  = btn("COPY",       Color3.fromRGB(70, 130, 210), 138, 110, 34)
local closeBtn = btn("CLOSE",      Color3.fromRGB(200, 55, 55),  256, 120, 34)

-- output area
local scroll = Instance.new("ScrollingFrame", panel)
scroll.Size = UDim2.new(1, -12, 1, -76)
scroll.Position = UDim2.new(0, 6, 0, 70)
scroll.BackgroundColor3 = Color3.fromRGB(8, 10, 12)
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 6
scroll.ScrollBarImageColor3 = Color3.fromRGB(90, 200, 130)
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Instance.new("UICorner", scroll).CornerRadius = UDim.new(0, 6)

outLabel = Instance.new("TextLabel", scroll)
outLabel.Size = UDim2.new(1, -10, 0, 0)
outLabel.Position = UDim2.new(0, 5, 0, 3)
outLabel.AutomaticSize = Enum.AutomaticSize.Y
outLabel.BackgroundTransparency = 1
outLabel.TextColor3 = Color3.fromRGB(210, 230, 215)
outLabel.Font = Enum.Font.Code
outLabel.TextSize = 11
outLabel.TextXAlignment = Enum.TextXAlignment.Left
outLabel.TextYAlignment = Enum.TextYAlignment.Top
outLabel.TextWrapped = true
outLabel.Text = ""

-- button actions (MouseButton1Click ONLY — no InputBegan/InputChanged anywhere)
scanBtn.MouseButton1Click:Connect(function()
    scanBtn.Text = "..."
    task.spawn(function()
        pcall(scan)
        scanBtn.Text = "SCAN AGAIN"
    end)
end)
copyBtn.MouseButton1Click:Connect(function()
    local text = table.concat(lines, "\n")
    local clip = setclipboard or toclipboard or set_clipboard or (syn and syn.write_clipboard)
    local ok = clip and pcall(function() clip(text) end)
    copyBtn.Text = ok and "COPIED!" or "NO CLIP"
    task.wait(1.2); copyBtn.Text = "COPY"
end)
closeBtn.MouseButton1Click:Connect(function() sg:Destroy() end)

-- run one scan automatically on launch
task.spawn(function() pcall(scan) end)
