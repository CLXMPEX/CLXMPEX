-- ============================================================
--  BUY PROBE  (input-safe: no hooks, no metatable, no input conns)
--
--  Goal: try to buy a seed WITHOUT opening the shop, by finding a
--  readable/callable buy path in the game's own code — not by
--  guessing encoded packets.
--
--  It looks for:
--    1) named "buy" RemoteEvents/Functions with readable args
--    2) ModuleScripts exposing a buy/purchase function we can call
--    3) client controllers with a Buy method
--  Then it TRIES buying "Carrot" (1 coin, cheap) and reports what
--  happened. Read the log; COPY/screenshot; send to Claude.
--
--  Nothing here touches your taps, chat, or screen input.
-- ============================================================

local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
local player  = Players.LocalPlayer
local pgui    = player:WaitForChild("PlayerGui", 10)

local TEST_SEED = "Carrot"   -- cheap test purchase

local lines = {}
local outLabel
local function render() if outLabel then outLabel.Text = table.concat(lines, "\n") end end
local function log(s) lines[#lines+1] = s; render() end
local function clear() lines = {}; render() end

local function pathOf(o)
    local p = o.Name
    pcall(function() p = o:GetFullName() end)
    return (p:gsub("^Players%..-%.PlayerGui%.", "PlayerGui."))
end

-- get player's coin count if we can find it (to detect a successful buy)
local function getCoins()
    local ls = player:FindFirstChild("leaderstats")
    if ls then
        for _, v in ipairs(ls:GetChildren()) do
            local nm = string.lower(v.Name)
            if string.find(nm,"coin",1,true) or string.find(nm,"cash",1,true)
               or string.find(nm,"money",1,true) or nm == "¢" then
                local ok, val = pcall(function() return v.Value end)
                if ok then return v.Name, val end
            end
        end
    end
    -- attribute fallback
    for k, val in pairs(player:GetAttributes()) do
        local nm = string.lower(k)
        if string.find(nm,"coin",1,true) or string.find(nm,"cash",1,true)
           or string.find(nm,"money",1,true) then
            return k, val
        end
    end
    return nil, nil
end

-- ---------- the probe ----------
local function probe()
    clear()
    log("===== BUY PROBE ("..TEST_SEED..") =====")
    local coinName, before = getCoins()
    if coinName then log("coins ("..coinName.."): "..tostring(before))
    else log("coins: (couldn't locate a coin stat)") end
    log("")

    -- 1) named buy remotes
    log("== named 'buy' remotes ==")
    local buyRemotes = {}
    for _, d in ipairs(RS:GetDescendants()) do
        if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
            local nm = string.lower(d.Name)
            if string.find(nm,"buy",1,true) or string.find(nm,"purchase",1,true) then
                buyRemotes[#buyRemotes+1] = d
                log("  "..(d:IsA("RemoteFunction") and "RF" or "RE").."  "..pathOf(d))
            end
        end
    end
    if #buyRemotes == 0 then log("  (none — game likely uses the buffer packet)") end

    -- try each named buy remote with common arg shapes
    for _, rem in ipairs(buyRemotes) do
        log("  trying "..rem.Name.."...")
        local shapes = {
            function() return TEST_SEED end,
            function() return TEST_SEED, 1 end,
            function() return {item=TEST_SEED, amount=1} end,
            function() return "buy", TEST_SEED end,
        }
        for i, mk in ipairs(shapes) do
            pcall(function()
                if rem:IsA("RemoteFunction") then rem:InvokeServer(mk())
                else rem:FireServer(mk()) end
            end)
            task.wait(0.4)
            local _, now = getCoins()
            if coinName and now and before and now ~= before then
                log("  >> shape "..i.." CHANGED coins ("..tostring(before).."->"..tostring(now)..") — LIKELY BOUGHT!")
                return
            end
        end
    end

    -- 2) ModuleScripts exposing a buy function
    log("")
    log("== modules with a buy/purchase function ==")
    local tried = 0
    for _, d in ipairs(RS:GetDescendants()) do
        if d:IsA("ModuleScript") then
            local nm = string.lower(d.Name)
            if string.find(nm,"shop",1,true) or string.find(nm,"buy",1,true)
               or string.find(nm,"purchase",1,true) or string.find(nm,"seed",1,true) then
                local ok, m = pcall(require, d)
                if ok and typeof(m) == "table" then
                    for k, v in pairs(m) do
                        local kl = string.lower(tostring(k))
                        if typeof(v) == "function" and
                           (string.find(kl,"buy",1,true) or string.find(kl,"purchase",1,true)) then
                            log("  found "..d.Name.."."..tostring(k).."()")
                            tried = tried + 1
                            -- try calling it a few ways
                            pcall(function() v(TEST_SEED) end); task.wait(0.3)
                            pcall(function() v(TEST_SEED, 1) end); task.wait(0.3)
                            pcall(function() v({item=TEST_SEED}) end); task.wait(0.3)
                            local _, now = getCoins()
                            if coinName and now and before and now ~= before then
                                log("  >> coins CHANGED after "..tostring(k).." — LIKELY BOUGHT!")
                                return
                            end
                        end
                    end
                end
            end
        end
    end
    if tried == 0 then log("  (no callable buy function found in modules)") end

    -- verdict
    log("")
    local _, after = getCoins()
    if coinName and after and before and after ~= before then
        log("RESULT: coins changed ("..tostring(before).."->"..tostring(after)..") — something worked!")
    else
        log("RESULT: no coin change detected.")
        log("Shop-closed buying likely needs the encoded packet,")
        log("which isn't safely reachable on this game.")
        log("The safe route is tapping the buy button (shop open).")
    end
    log("===== END — COPY/screenshot to Claude =====")
end

-- ---------- GUI (no input conns / hooks / drag) ----------
local nm = "BuyProbe"
local old = pgui:FindFirstChild(nm)
if old then old:Destroy() end
local sg = Instance.new("ScreenGui")
sg.Name = nm; sg.ResetOnSpawn = false; sg.DisplayOrder = 99999
sg.IgnoreGuiInset = true; sg.Parent = pgui

local panel = Instance.new("Frame", sg)
panel.Size = UDim2.new(0, 400, 0, 360)
panel.Position = UDim2.new(0, 12, 0, 60)
panel.BackgroundColor3 = Color3.fromRGB(16, 18, 22)
panel.BorderSizePixel = 0
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)
local strk = Instance.new("UIStroke", panel)
strk.Color = Color3.fromRGB(240, 180, 60); strk.Thickness = 1

local title = Instance.new("TextLabel", panel)
title.Size = UDim2.new(1, -12, 0, 26); title.Position = UDim2.new(0, 10, 0, 6)
title.BackgroundTransparency = 1; title.TextColor3 = Color3.fromRGB(245, 200, 80)
title.Font = Enum.Font.GothamBold; title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left; title.Text = "BUY PROBE (safe)"

local function mkBtn(txt, color, x, w)
    local b = Instance.new("TextButton", panel)
    b.Size = UDim2.new(0, w, 0, 30); b.Position = UDim2.new(0, x, 0, 34)
    b.BackgroundColor3 = color; b.Text = txt; b.TextColor3 = Color3.new(1,1,1)
    b.Font = Enum.Font.GothamBold; b.TextSize = 12; b.BorderSizePixel = 0
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end
local tryBtn   = mkBtn("TRY BUY", Color3.fromRGB(60, 170, 110), 10,  110)
local copyBtn  = mkBtn("COPY",    Color3.fromRGB(70, 130, 210), 128, 110)
local closeBtn = mkBtn("CLOSE",   Color3.fromRGB(200, 55, 55),  246, 120)

local scroll = Instance.new("ScrollingFrame", panel)
scroll.Size = UDim2.new(1, -12, 1, -76); scroll.Position = UDim2.new(0, 6, 0, 70)
scroll.BackgroundColor3 = Color3.fromRGB(8, 10, 12); scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 6; scroll.ScrollBarImageColor3 = Color3.fromRGB(240, 180, 60)
scroll.CanvasSize = UDim2.new(0, 0, 0, 0); scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Instance.new("UICorner", scroll).CornerRadius = UDim.new(0, 6)

outLabel = Instance.new("TextLabel", scroll)
outLabel.Size = UDim2.new(1, -10, 0, 0); outLabel.Position = UDim2.new(0, 5, 0, 3)
outLabel.AutomaticSize = Enum.AutomaticSize.Y; outLabel.BackgroundTransparency = 1
outLabel.TextColor3 = Color3.fromRGB(225, 230, 215); outLabel.Font = Enum.Font.Code
outLabel.TextSize = 11; outLabel.TextXAlignment = Enum.TextXAlignment.Left
outLabel.TextYAlignment = Enum.TextYAlignment.Top; outLabel.TextWrapped = true
outLabel.Text = ""

tryBtn.MouseButton1Click:Connect(function()
    tryBtn.Text = "..."
    task.spawn(function() pcall(probe); tryBtn.Text = "TRY BUY" end)
end)
copyBtn.MouseButton1Click:Connect(function()
    local text = table.concat(lines, "\n")
    local clip = setclipboard or toclipboard or set_clipboard or (syn and syn.write_clipboard)
    local ok = clip and pcall(function() clip(text) end)
    copyBtn.Text = ok and "COPIED!" or "NO CLIP"
    task.wait(1.2); copyBtn.Text = "COPY"
end)
closeBtn.MouseButton1Click:Connect(function() sg:Destroy() end)

log("Ready. Make sure you have a few coins.")
log("Tap TRY BUY — it attempts to buy 1 "..TEST_SEED.." without the shop.")
log("Watch your coin count / inventory. Then COPY the result.")
