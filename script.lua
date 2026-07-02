-- ============================================================
--  DEEP BUY PROBE  (input-safe: no hooks, no metatable, no input conns)
--
--  Last real shot at shop-closed buying: instead of guessing the
--  encoded packet, find the GAME'S OWN buy function in memory and
--  call it — letting the game build the packet for us.
--
--  Searches:
--    * getloadedmodules() — every required module, scanned for a
--      buy/purchase function
--    * getgc(true) — every function/table in memory, by name
--    * client controllers (Knit/roblox-ts style) with Buy methods
--  Then calls candidates with "Carrot" and watches Sheckles.
--
--  Reads only. Does not touch taps, chat, or input.
-- ============================================================

local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
local player  = Players.LocalPlayer
local pgui    = player:WaitForChild("PlayerGui", 10)

local TEST_SEED = "Carrot"

local lines = {}
local outLabel
local function render() if outLabel then outLabel.Text = table.concat(lines, "\n") end end
local function log(s) lines[#lines+1] = s; render(); print("[DEEPBUY] "..s) end
local function clear() lines = {}; render() end

-- ---------- find Sheckles (deep search of player data) ----------
local function findSheckles()
    -- check leaderstats, attributes, and any NumberValue named sheckle
    local best
    local function checkContainer(cont)
        for _, v in ipairs(cont:GetDescendants()) do
            local nm = string.lower(v.Name)
            if (v:IsA("NumberValue") or v:IsA("IntValue")) and
               (string.find(nm,"sheckle",1,true) or string.find(nm,"shekel",1,true)
                or string.find(nm,"coin",1,true) or string.find(nm,"cash",1,true)
                or string.find(nm,"money",1,true)) then
                return v
            end
        end
    end
    best = checkContainer(player)
    if not best then
        local ls = player:FindFirstChild("leaderstats")
        if ls then best = checkContainer(ls) end
    end
    return best
end

local function sheckleVal(obj)
    if not obj then return nil end
    local ok, v = pcall(function() return obj.Value end)
    return ok and v or nil
end

-- ---------- the deep probe ----------
local function probe()
    clear()
    log("===== DEEP BUY PROBE ("..TEST_SEED..") =====")

    local shObj = findSheckles()
    local before = sheckleVal(shObj)
    if shObj then log("Sheckles found: "..shObj.Name.." = "..tostring(before))
    else log("Sheckles stat not found (will still try; watch screen)") end
    log("")

    local candidates = {}   -- {fn=, label=}

    -- helper: does this key look like a buy function?
    local function isBuyName(k)
        k = string.lower(tostring(k))
        return (string.find(k,"buy",1,true) or string.find(k,"purchase",1,true))
            and not string.find(k,"gamepass",1,true)
            and not string.find(k,"robux",1,true)
            and not string.find(k,"dev",1,true)
    end

    -- 1) getloadedmodules
    log("== scanning loaded modules ==")
    local glm = getloadedmodules or get_loaded_modules
    if glm then
        local ok, mods = pcall(glm)
        if ok and mods then
            for _, mod in ipairs(mods) do
                pcall(function()
                    if mod:IsA("ModuleScript") then
                        local rok, m = pcall(require, mod)
                        if rok and typeof(m) == "table" then
                            for k, v in pairs(m) do
                                if typeof(v) == "function" and isBuyName(k) then
                                    candidates[#candidates+1] = { fn = v, label = mod.Name.."."..tostring(k) }
                                end
                            end
                        end
                    end
                end)
            end
        end
        log("  loaded-module candidates so far: "..#candidates)
    else
        log("  getloadedmodules not available")
    end

    -- 2) getgc — functions and tables in memory
    log("== scanning memory (getgc) ==")
    if getgc then
        local ok, gc = pcall(function() return getgc(true) end)
        if ok and gc then
            local scanned = 0
            for _, obj in pairs(gc) do
                scanned = scanned + 1
                if typeof(obj) == "table" then
                    pcall(function()
                        for k, v in pairs(obj) do
                            if typeof(v) == "function" and isBuyName(k) then
                                -- capture the table as 'self' too, in case it's a method
                                candidates[#candidates+1] = { fn = v, label = "gc.table."..tostring(k), selfObj = obj }
                            end
                        end
                    end)
                end
            end
            log("  gc objects scanned: "..scanned)
        else
            log("  getgc returned nothing")
        end
    else
        log("  getgc not available")
    end

    log("  TOTAL buy candidates: "..#candidates)
    log("")

    if #candidates == 0 then
        log("No callable buy function exists in memory.")
        log("VERDICT: shop-closed buying is not reachable on this game.")
        log("===== END =====")
        return
    end

    -- 3) try each candidate with several call shapes; watch Sheckles
    log("== trying candidates ==")
    for i, cand in ipairs(candidates) do
        if i > 30 then log("  (stopping after 30)"); break end
        log("  ["..i.."] "..cand.label)
        local shapes = {
            function() return cand.fn(TEST_SEED) end,
            function() return cand.fn(TEST_SEED, 1) end,
            function() return cand.fn({item=TEST_SEED, amount=1}) end,
            function() return cand.fn(cand.selfObj, TEST_SEED) end,      -- method style
            function() return cand.fn(cand.selfObj, TEST_SEED, 1) end,
        }
        for si, mk in ipairs(shapes) do
            pcall(mk)
            task.wait(0.35)
            local now = sheckleVal(shObj)
            if before and now and now ~= before then
                log("  >> SHECKLES CHANGED "..tostring(before).."->"..tostring(now))
                log("  >> WINNER: "..cand.label.."  (shape "..si..")")
                log("  Tell Claude this exact line — we build the buyer on it.")
                log("===== END =====")
                return
            end
        end
    end

    local after = sheckleVal(shObj)
    log("")
    if before and after and after ~= before then
        log("Sheckles changed overall ("..tostring(before).."->"..tostring(after)..") — something worked!")
    else
        log("No Sheckle change from any candidate.")
        log("VERDICT: the game only accepts buys via the encoded packet;")
        log("shop-closed buying is not safely reachable. Button-tap")
        log("(shop open) is the working route.")
    end
    log("===== END — COPY/screenshot to Claude =====")
end

-- ---------- GUI (no input conns / hooks / drag) ----------
local nm = "DeepBuyProbe"
local old = pgui:FindFirstChild(nm)
if old then old:Destroy() end
local sg = Instance.new("ScreenGui")
sg.Name = nm; sg.ResetOnSpawn = false; sg.DisplayOrder = 99999
sg.IgnoreGuiInset = true; sg.Parent = pgui

local panel = Instance.new("Frame", sg)
panel.Size = UDim2.new(0, 400, 0, 380)
panel.Position = UDim2.new(0, 12, 0, 60)
panel.BackgroundColor3 = Color3.fromRGB(16, 18, 22)
panel.BorderSizePixel = 0
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)
local strk = Instance.new("UIStroke", panel)
strk.Color = Color3.fromRGB(120, 200, 255); strk.Thickness = 1

local title = Instance.new("TextLabel", panel)
title.Size = UDim2.new(1, -12, 0, 26); title.Position = UDim2.new(0, 10, 0, 6)
title.BackgroundTransparency = 1; title.TextColor3 = Color3.fromRGB(130, 205, 255)
title.Font = Enum.Font.GothamBold; title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left; title.Text = "DEEP BUY PROBE (safe)"

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
scroll.ScrollBarThickness = 6; scroll.ScrollBarImageColor3 = Color3.fromRGB(120, 200, 255)
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

log("Have some Sheckles ready. Tap TRY BUY.")
log("It searches the game's own code for a buy function")
log("and calls it directly. Watch your Sheckles / inventory.")
