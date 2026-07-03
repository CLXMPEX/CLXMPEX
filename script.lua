-- ============================================================
--  ESCORT AUTO FARM  (Journey's End — Elf Mage)  v1
--  Confirmed start: escorts.create:InvokeServer("Journeys End", "T<n> Holy Key")
--  Features:
--   * Instant start via escorts.create (no NPC talk, no page).
--   * 5 key-priority dropdowns (P1 used first ... P5 last, skip if 0).
--   * On entry: teleport to horse (4408, 6021.9, -248.5), press Start.
--   * v5 auto-attack (teleport onto enemy 1 stud, swing).
--   * Auto-restart after each win.  No modifiers (escort has none).
--   * Draggable, small GUI.
-- ============================================================

local Players           = game:GetService("Players")
local UIS               = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

local player = Players.LocalPlayer
local pgui   = player:WaitForChild("PlayerGui", 10)

local RAID_Y_MIN = 5000

-- ============================================================
--  REMOTES (flat dotted names)
-- ============================================================
local remoBase
pcall(function()
    remoBase = ReplicatedStorage:WaitForChild("rbxts_include",5):WaitForChild("node_modules",5)
        :WaitForChild("@rbxts",5):WaitForChild("remo",5):WaitForChild("src",5)
        :WaitForChild("container",5)
end)
local function getRemote(dotted)
    if not remoBase then return nil end
    local r = remoBase:FindFirstChild(dotted)
    if r then return r end
    for _, d in ipairs(remoBase:GetDescendants()) do
        if d.Name == dotted then return d end
    end
end

local R = {
    escortCreate   = getRemote("escorts.create"),
    escortLeave    = getRemote("escorts.leaveEscort"),
    weaponActivate = getRemote("weapons.activate"),
    sendAndRetreat = getRemote("enemies.sendAndRetreat"),
    toolbarEquip   = getRemote("toolbar.equip"),
    lobbyStart     = getRemote("lobbies.start"),
}
do
    local n = 0
    for _, v in pairs(R) do if v then n = n + 1 end end
    print("[ESCORT] remotes resolved: " .. n)
end

-- ============================================================
--  CONFIG
-- ============================================================
local ESCORT_NAME = "Journeys End"
local HORSE_POS   = CFrame.new(4408, 6021.9, -248.5)
local KEY_TIERS = {
    T1 = "T1 Holy Key", T2 = "T2 Holy Key", T3 = "T3 Holy Key",
    T4 = "T4 Holy Key", T5 = "T5 Holy Key",
}
local TIER_OPTS = { "T1", "T2", "T3", "T4", "T5" }

-- ============================================================
--  STATE
-- ============================================================
getgenv().EscortState = getgenv().EscortState or {}
local State = getgenv().EscortState
local defaults = {
    autoFarm      = false,
    autoStart     = false,
    autoEquip     = false,
    friendOnly    = false,
    keyPriorities = { "T5", "T4", "T3", "T2", "T1" },  -- P1..P5
    guiVisible    = true,
    running       = true,
    inRaid        = false,
    starting      = false,
    startingAt    = 0,
    runCount      = 0,
    freezeUntil   = 0,
}
for k, v in pairs(defaults) do if State[k] == nil then State[k] = v end end
State.guiVisible = true

-- ============================================================
--  HELPERS
-- ============================================================
local function getChar()
    local c = player.Character
    if not c then return nil, nil end
    return c, c:FindFirstChild("HumanoidRootPart")
end
local function getEnemyFolder()
    local w = Workspace:FindFirstChild("World")
    return w and w:FindFirstChild("Enemies")
end
local function getWarriorUUIDs()
    local uuids = {}
    local w = Workspace:FindFirstChild("World")
    local f = w and w:FindFirstChild("Warriors")
    if not f then return uuids end
    for _, m in ipairs(f:GetChildren()) do
        if m:IsA("Model") then table.insert(uuids, m.Name) end
    end
    return uuids
end
local function isInRaidArea()
    local _, hrp = getChar()
    if not hrp then return false end
    return hrp.Position.Y > RAID_Y_MIN
end
-- alive unless dead == true
local function getAliveEnemies()
    local enemies = {}
    local folder = getEnemyFolder()
    if not folder then return enemies end
    for _, e in ipairs(folder:GetChildren()) do
        if not e:IsA("Model") then continue end
        if e:GetAttribute("dead") == true then continue end
        local hrp = e:FindFirstChild("HumanoidRootPart") or e:FindFirstChild("Root")
        if not hrp then continue end
        if hrp.Position.Y < RAID_Y_MIN then continue end
        local hum = e:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health <= 0 then continue end
        table.insert(enemies, { uuid = e.Name, hrp = hrp })
    end
    return enemies
end

-- ============================================================
--  KEY INVENTORY (atoms datastore)
-- ============================================================
local cachedAtoms
local function getAtomsData()
    if not cachedAtoms then
        for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
            if d:IsA("ModuleScript") and d.Name == "atoms"
               and d:GetFullName():find("common.store.atoms") then
                pcall(function() cachedAtoms = require(d) end); break
            end
        end
    end
    if not cachedAtoms then return nil end
    local atomTable = cachedAtoms.atoms or cachedAtoms
    if typeof(atomTable.datastore) ~= "function" then return nil end
    local ok, ds = pcall(atomTable.datastore)
    if not ok or typeof(ds) ~= "table" then return nil end
    return ds[tostring(player.UserId)] or ds[player.UserId]
end
local function getKeyCount(keyItemName)
    local pdata = getAtomsData()
    if not pdata or not pdata.items then return 0 end
    local item = pdata.items[keyItemName]
    if not item then return 0 end
    if typeof(item) == "table" then return item.amount or 0 end
    return tonumber(item) or 0
end
-- first priority tier you still have keys for
local function pickKey()
    for _, tier in ipairs(State.keyPriorities) do
        local keyName = KEY_TIERS[tier]
        if keyName and getKeyCount(keyName) > 0 then
            return tier, keyName
        end
    end
    return nil, nil
end

-- ============================================================
--  COMBAT (v5)
-- ============================================================
local function swingWeapon()
    if not R.weaponActivate then return end
    local _, hrp = getChar()
    if not hrp then return end
    pcall(function() R.weaponActivate:FireServer(tick(), hrp.CFrame) end)
end
local function hitEnemy(uuid)
    if not R.sendAndRetreat then return end
    local warriors = getWarriorUUIDs()
    if #warriors == 0 then return end
    pcall(function() R.sendAndRetreat:FireServer(uuid, warriors) end)
end
local function isWeaponEquipped()
    local char = player.Character
    if not char then return false end
    if char:FindFirstChildOfClass("Tool") then return true end
    local a = char:GetAttribute("equippedTool") or char:GetAttribute("EquippedTool")
        or char:GetAttribute("weaponEquipped")
    return a ~= nil and a ~= false and a ~= ""
end
local function equipWeapon()
    if not R.toolbarEquip then return end
    if isWeaponEquipped() then return end
    pcall(function() R.toolbarEquip:FireServer("weapon") end)
end
local function attackTarget(target)
    local _, hrp = getChar()
    if hrp and target.hrp then
        hrp.CFrame = target.hrp.CFrame * CFrame.new(0, 0, 1)
    end
    task.wait(0.05); swingWeapon()
    task.wait(0.05); hitEnemy(target.uuid)
    task.wait(0.05); swingWeapon()
end

print("[ESCORT] foundation + combat loaded")

-- ============================================================
--  INSTANT ESCORT START  (confirmed: name, keyName as plain string)
-- ============================================================
local function startEscortInstant()
    if not R.escortCreate then warn("[ESCORT] escorts.create missing"); return false end
    if isInRaidArea() then return true end

    local tier, keyName = pickKey()
    if not keyName then
        print("[ESCORT] No keys available in any priority tier — skipping")
        return false
    end

    State.starting = true
    State.startingAt = tick()
    print("[ESCORT] Starting Journey's End with " .. tier .. " (" .. keyName .. ")")

    for attempt = 1, 5 do
        if isInRaidArea() then State.starting = false; return true end
        -- CONFIRMED shape: name + key item name as a plain string
        pcall(function() R.escortCreate:InvokeServer(ESCORT_NAME, keyName) end)
        print("[ESCORT] Fired escorts.create (attempt " .. attempt .. ")")
        for _ = 1, 10 do
            if isInRaidArea() then break end
            task.wait(0.5)
        end
    end
    State.starting = false
    return isInRaidArea()
end

local function leaveEscort()
    if R.escortLeave then pcall(function() R.escortLeave:FireServer() end) end
end

-- ============================================================
--  CLICK HELPERS + press in-raid Start
-- ============================================================
local function fireConns(btn)
    if not btn then return false end
    local fired = false
    for _, ev in ipairs({ "Activated", "MouseButton1Click", "MouseButton1Down" }) do
        pcall(function()
            for _, c in pairs(getconnections(btn[ev])) do c:Fire(); fired = true end
        end)
    end
    return fired
end
local function clickByText(searchText)
    searchText = string.lower(searchText)
    local myGui = pgui:FindFirstChild("EscortGUI")
    for _, obj in ipairs(pgui:GetDescendants()) do
        if obj:IsA("TextLabel") and obj.Visible then
            if myGui and obj:IsDescendantOf(myGui) then continue end
            if string.find(string.lower(obj.Text), searchText, 1, true) then
                local cur = obj.Parent
                for _ = 1, 8 do
                    if not cur or cur == pgui then break end
                    if cur.Name == "inner" then
                        local tb = cur:FindFirstChildOfClass("TextButton") or cur:FindFirstChildOfClass("ImageButton")
                        if tb and fireConns(tb) then return true end
                    end
                    cur = cur.Parent
                end
            end
        end
    end
    return false
end
local function clickExact(exactText)
    local myGui = pgui:FindFirstChild("EscortGUI")
    for _, obj in ipairs(pgui:GetDescendants()) do
        if obj:IsA("TextLabel") and obj.Visible and obj.Text == exactText then
            if myGui and obj:IsDescendantOf(myGui) then continue end
            local cur = obj.Parent
            for _ = 1, 8 do
                if not cur then break end
                if cur.Name == "inner" then
                    local tb = cur:FindFirstChildOfClass("TextButton")
                    if tb and fireConns(tb) then return true end
                    break
                end
                cur = cur.Parent
            end
        end
    end
    return false
end
local function pressInRaidStart()
    print("[ESCORT] Pressing in-raid Start...")
    for _ = 1, 12 do
        if #getAliveEnemies() > 0 then return true end
        clickExact("Start")
        clickByText("start")
        if R.lobbyStart then pcall(function() R.lobbyStart:FireServer() end) end
        task.wait(1)
    end
    return #getAliveEnemies() > 0
end

-- ============================================================
--  LOOPS
-- ============================================================
local function farmLoop()
    while State.running do
        if State.starting then
            repeat task.wait(0.1) until (not State.starting) or (not State.running)
        end
        task.wait(0.15)
        if not State.autoFarm then task.wait(0.5); continue end
        if not isInRaidArea() then task.wait(1); continue end
        if tick() < (State.freezeUntil or 0) then task.wait(0.2); continue end

        if State.autoEquip then equipWeapon() end

        local enemies = getAliveEnemies()
        if #enemies > 0 then
            local _, myHRP = getChar()
            if myHRP then
                table.sort(enemies, function(a, b)
                    return (myHRP.Position - a.hrp.Position).Magnitude
                         < (myHRP.Position - b.hrp.Position).Magnitude
                end)
            end
            attackTarget(enemies[1])
        else
            -- between waves: hold on the horse and swing
            local _, myHRP = getChar()
            if myHRP and (myHRP.Position - HORSE_POS.Position).Magnitude > 20 then
                myHRP.CFrame = HORSE_POS
                task.wait(0.1)
            end
            swingWeapon(); task.wait(0.1); swingWeapon()
        end
    end
end

local function cycleLoop()
    while State.running do
        task.wait(3)
        if State.starting and (tick() - (State.startingAt or 0)) > 40 then State.starting = false end
        if not State.autoStart then continue end

        if isInRaidArea() then State.inRaid = true; continue end
        if State.inRaid and not isInRaidArea() and tick() >= (State.freezeUntil or 0) and not State.starting then
            State.inRaid = false
        end

        if not isInRaidArea() and not State.inRaid and not State.starting then
            if startEscortInstant() then
                local _, hrp = getChar()
                if hrp then hrp.CFrame = HORSE_POS; print("[ESCORT] On the horse") end
                task.wait(0.3)
                pressInRaidStart()
                if State.autoEquip then equipWeapon() end
                State.inRaid = true
                State.freezeUntil = tick() + 3
                print("[ESCORT] Escort started!")
            end
        end
    end
end

local function victoryLoop()
    while State.running do
        if State.starting then
            repeat task.wait(0.1) until (not State.starting) or (not State.running)
        end
        task.wait(1)
        if not State.autoFarm and not State.autoStart then continue end

        local myGui = pgui:FindFirstChild("EscortGUI")
        local won = false
        for _, obj in ipairs(pgui:GetDescendants()) do
            if (obj:IsA("TextLabel") or obj:IsA("TextButton")) and obj.Visible then
                if myGui and obj:IsDescendantOf(myGui) then continue end
                local low = string.lower(obj.Text)
                if string.find(low, "victory", 1, true) or string.find(low, "complete", 1, true) then
                    won = true; break
                end
            end
        end

        if won then
            State.runCount = (State.runCount or 0) + 1
            print("[ESCORT] Win! Run #" .. State.runCount)
            task.wait(3)
            State.freezeUntil = tick() + 6
            leaveEscort()
            task.wait(2)
            local tries = 0
            while isInRaidArea() and tries < 8 do
                clickExact("Continue"); clickByText("continue"); leaveEscort()
                task.wait(1); tries = tries + 1
            end
            State.inRaid = false
            State.freezeUntil = 0
            print("[ESCORT] Back in lobby; restarting.")
        end
    end
end

local function utilityLoop()
    while State.running do
        if State.starting then
            repeat task.wait(0.1) until (not State.starting) or (not State.running)
        end
        task.wait(3)
        if State.autoEquip then equipWeapon() end
    end
end

print("[ESCORT] start + loops loaded")

-- ============================================================
--  GUI  (draggable, small)
-- ============================================================
local oldGui = pgui:FindFirstChild("EscortGUI")
if oldGui then oldGui:Destroy() end

local sg = Instance.new("ScreenGui")
sg.Name = "EscortGUI"; sg.ResetOnSpawn = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.IgnoreGuiInset = true; sg.DisplayOrder = 9999; sg.Parent = pgui

local C = {
    bg = Color3.fromRGB(18,18,24), card = Color3.fromRGB(30,30,42),
    border = Color3.fromRGB(48,48,66), text = Color3.fromRGB(225,225,235),
    textDim = Color3.fromRGB(110,110,135), textMid = Color3.fromRGB(160,160,180),
    accent = Color3.fromRGB(120,200,255), green = Color3.fromRGB(50,205,110),
    gold = Color3.fromRGB(255,200,60), pink = Color3.fromRGB(255,90,140),
    toggleOff = Color3.fromRGB(50,50,65),
}

local floatBtn = Instance.new("TextButton", sg)
floatBtn.Size = UDim2.new(0,44,0,44); floatBtn.Position = UDim2.new(0,8,0.4,0)
floatBtn.BackgroundColor3 = C.accent; floatBtn.Text = "ES"
floatBtn.TextColor3 = Color3.fromRGB(10,20,30); floatBtn.TextSize = 15
floatBtn.Font = Enum.Font.GothamBold; floatBtn.BorderSizePixel = 0; floatBtn.ZIndex = 100
Instance.new("UICorner", floatBtn).CornerRadius = UDim.new(0,12)

local mainFrame = Instance.new("Frame", sg)
mainFrame.Size = UDim2.new(0,250,0,300); mainFrame.Position = UDim2.new(0.5,-125,0.5,-150)
mainFrame.BackgroundColor3 = C.bg; mainFrame.BorderSizePixel = 0; mainFrame.ZIndex = 50
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0,14)
local mStroke = Instance.new("UIStroke", mainFrame); mStroke.Color = C.accent; mStroke.Thickness = 1; mStroke.Transparency = 0.4
mainFrame.Visible = State.guiVisible

local titleBar = Instance.new("Frame", mainFrame)
titleBar.Size = UDim2.new(1,0,0,38); titleBar.BackgroundColor3 = Color3.fromRGB(16,22,30)
titleBar.BorderSizePixel = 0; titleBar.ZIndex = 51
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0,14)

local tt = Instance.new("TextLabel", titleBar)
tt.Size = UDim2.new(0,180,1,0); tt.Position = UDim2.new(0,12,0,0)
tt.BackgroundTransparency = 1; tt.Text = "Journey's End"; tt.TextColor3 = C.accent
tt.TextSize = 14; tt.Font = Enum.Font.GothamBold
tt.TextXAlignment = Enum.TextXAlignment.Left; tt.ZIndex = 52

local closeB = Instance.new("TextButton", titleBar)
closeB.Size = UDim2.new(0,26,0,26); closeB.Position = UDim2.new(1,-32,0,6)
closeB.BackgroundColor3 = Color3.fromRGB(60,30,40); closeB.Text = "X"
closeB.TextColor3 = C.pink; closeB.TextSize = 12; closeB.Font = Enum.Font.GothamBold
closeB.BorderSizePixel = 0; closeB.ZIndex = 54
Instance.new("UICorner", closeB).CornerRadius = UDim.new(0,8)
closeB.MouseButton1Click:Connect(function() State.guiVisible = false; mainFrame.Visible = false end)
floatBtn.MouseButton1Click:Connect(function()
    State.guiVisible = not State.guiVisible; mainFrame.Visible = State.guiVisible
end)

-- drag by title bar
local dragB = Instance.new("TextButton", titleBar)
dragB.Size = UDim2.new(1,-40,1,0); dragB.BackgroundTransparency = 1; dragB.Text = ""; dragB.ZIndex = 52
local mDrag = { on = false }
dragB.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
        mDrag.on = true; mDrag.s = i.Position; mDrag.p = mainFrame.Position
    end
end)
UIS.InputChanged:Connect(function(i)
    if mDrag.on and (i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseMovement) then
        local d = i.Position - mDrag.s
        mainFrame.Position = UDim2.new(mDrag.p.X.Scale, mDrag.p.X.Offset+d.X, mDrag.p.Y.Scale, mDrag.p.Y.Offset+d.Y)
    end
end)
UIS.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
        mDrag.on = false
    end
end)

local body = Instance.new("ScrollingFrame", mainFrame)
body.Size = UDim2.new(1,-10,1,-46); body.Position = UDim2.new(0,6,0,42)
body.BackgroundTransparency = 1; body.BorderSizePixel = 0
body.ScrollBarThickness = 3; body.ScrollBarImageColor3 = C.accent
body.CanvasSize = UDim2.new(0,0,0,0); body.AutomaticCanvasSize = Enum.AutomaticSize.Y; body.ZIndex = 51
local lay = Instance.new("UIListLayout", body); lay.Padding = UDim.new(0,5)
local pad = Instance.new("UIPadding", body)
pad.PaddingLeft = UDim.new(0,8); pad.PaddingRight = UDim.new(0,6)
pad.PaddingTop = UDim.new(0,4); pad.PaddingBottom = UDim.new(0,8)

local orderN = 0
local function nextOrder() orderN = orderN + 1; return orderN end

local function sec(title, color)
    local f = Instance.new("Frame", body)
    f.Size = UDim2.new(1,0,0,20); f.BackgroundTransparency = 1; f.LayoutOrder = nextOrder(); f.ZIndex = 51
    local dot = Instance.new("Frame", f)
    dot.Size = UDim2.new(0,6,0,6); dot.Position = UDim2.new(0,2,0.5,-3)
    dot.BackgroundColor3 = color; dot.BorderSizePixel = 0; dot.ZIndex = 52
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1,0)
    local l = Instance.new("TextLabel", f)
    l.Size = UDim2.new(1,-14,1,0); l.Position = UDim2.new(0,12,0,0)
    l.BackgroundTransparency = 1; l.Text = string.upper(title); l.TextColor3 = color
    l.TextSize = 9; l.Font = Enum.Font.GothamBold
    l.TextXAlignment = Enum.TextXAlignment.Left; l.ZIndex = 52
end

local function tog(label, key, color)
    local h = Instance.new("Frame", body)
    h.Size = UDim2.new(1,0,0,32); h.BackgroundColor3 = C.card; h.BorderSizePixel = 0
    h.LayoutOrder = nextOrder(); h.ZIndex = 51
    Instance.new("UICorner", h).CornerRadius = UDim.new(0,8)
    local hs = Instance.new("UIStroke", h); hs.Color = C.border; hs.Transparency = 0.6
    local l = Instance.new("TextLabel", h)
    l.Size = UDim2.new(1,-54,1,0); l.Position = UDim2.new(0,10,0,0)
    l.BackgroundTransparency = 1; l.Text = label; l.TextColor3 = C.textMid
    l.TextSize = 11; l.Font = Enum.Font.Gotham
    l.TextXAlignment = Enum.TextXAlignment.Left; l.ZIndex = 52
    local tr = Instance.new("Frame", h)
    tr.Size = UDim2.new(0,36,0,20); tr.Position = UDim2.new(1,-44,0.5,-10)
    tr.BackgroundColor3 = C.toggleOff; tr.BorderSizePixel = 0; tr.ZIndex = 52
    Instance.new("UICorner", tr).CornerRadius = UDim.new(1,0)
    local kn = Instance.new("Frame", tr)
    kn.Size = UDim2.new(0,16,0,16); kn.Position = UDim2.new(0,2,0,2)
    kn.BackgroundColor3 = Color3.fromRGB(120,120,135); kn.BorderSizePixel = 0; kn.ZIndex = 53
    Instance.new("UICorner", kn).CornerRadius = UDim.new(1,0)
    local b = Instance.new("TextButton", h)
    b.Size = UDim2.new(1,0,1,0); b.BackgroundTransparency = 1; b.Text = ""; b.ZIndex = 54
    local function upd()
        local on = State[key]
        tr.BackgroundColor3 = on and color or C.toggleOff
        kn.Position = on and UDim2.new(0,18,0,2) or UDim2.new(0,2,0,2)
        kn.BackgroundColor3 = on and Color3.new(1,1,1) or Color3.fromRGB(120,120,135)
        l.TextColor3 = on and C.text or C.textMid
        hs.Color = on and color or C.border
    end
    b.MouseButton1Click:Connect(function() State[key] = not State[key]; upd() end)
    upd()
end

local function drop(label, options, default, onSelect)
    local h = Instance.new("Frame", body)
    h.Size = UDim2.new(1,0,0,44); h.BackgroundColor3 = C.card; h.BorderSizePixel = 0
    h.LayoutOrder = nextOrder(); h.ClipsDescendants = true; h.ZIndex = 51
    Instance.new("UICorner", h).CornerRadius = UDim.new(0,8)
    local hs = Instance.new("UIStroke", h); hs.Color = C.border; hs.Transparency = 0.5
    local l = Instance.new("TextLabel", h)
    l.Size = UDim2.new(1,-14,0,12); l.Position = UDim2.new(0,10,0,4)
    l.BackgroundTransparency = 1; l.Text = label; l.TextColor3 = C.textDim
    l.TextSize = 9; l.Font = Enum.Font.GothamBold
    l.TextXAlignment = Enum.TextXAlignment.Left; l.ZIndex = 52
    local sf = Instance.new("Frame", h)
    sf.Size = UDim2.new(1,-16,0,20); sf.Position = UDim2.new(0,8,0,20)
    sf.BackgroundColor3 = Color3.fromRGB(40,40,56); sf.BorderSizePixel = 0; sf.ZIndex = 52
    Instance.new("UICorner", sf).CornerRadius = UDim.new(0,6)
    local st = Instance.new("TextLabel", sf)
    st.Size = UDim2.new(1,-10,1,0); st.Position = UDim2.new(0,8,0,0)
    st.BackgroundTransparency = 1; st.Text = default or options[1]; st.TextColor3 = C.text
    st.TextSize = 11; st.Font = Enum.Font.GothamBold
    st.TextXAlignment = Enum.TextXAlignment.Left; st.ZIndex = 53
    for i, opt in ipairs(options) do
        local ob = Instance.new("TextButton", h)
        ob.Size = UDim2.new(1,-16,0,26); ob.Position = UDim2.new(0,8,0,44+(i-1)*28)
        ob.BackgroundColor3 = Color3.fromRGB(38,38,52); ob.Text = "  "..opt
        ob.TextColor3 = C.text; ob.TextSize = 11; ob.Font = Enum.Font.Gotham
        ob.TextXAlignment = Enum.TextXAlignment.Left; ob.BorderSizePixel = 0; ob.ZIndex = 53
        Instance.new("UICorner", ob).CornerRadius = UDim.new(0,6)
        ob.MouseButton1Click:Connect(function()
            st.Text = opt; h.Size = UDim2.new(1,0,0,44)
            if onSelect then onSelect(i, opt) end
        end)
    end
    local ca = Instance.new("TextButton", h)
    ca.Size = UDim2.new(1,0,0,44); ca.BackgroundTransparency = 1; ca.Text = ""; ca.ZIndex = 54
    ca.MouseButton1Click:Connect(function()
        local open = h.Size.Y.Offset > 46
        h.Size = open and UDim2.new(1,0,0,44) or UDim2.new(1,0,0,44+#options*28+4)
    end)
end

-- layout
sec("Escort", C.accent)
tog("Auto start", "autoStart", C.accent)
tog("Auto attack", "autoFarm", C.green)
tog("Auto equip weapon", "autoEquip", C.gold)

sec("Key Priority", C.gold)
for i = 1, 5 do
    local default = State.keyPriorities[i] or TIER_OPTS[i]
    drop("Priority " .. i, TIER_OPTS, default, function(_, opt)
        State.keyPriorities[i] = opt
        print("[ESCORT] Priority " .. i .. " = " .. opt)
    end)
end

-- status bar
local statusHolder = Instance.new("Frame", body)
statusHolder.Size = UDim2.new(1,0,0,24); statusHolder.BackgroundColor3 = Color3.fromRGB(24,24,34)
statusHolder.BorderSizePixel = 0; statusHolder.LayoutOrder = 999; statusHolder.ZIndex = 51
Instance.new("UICorner", statusHolder).CornerRadius = UDim.new(0,8)
local statusBar = Instance.new("TextLabel", statusHolder)
statusBar.Size = UDim2.new(1,-16,1,0); statusBar.Position = UDim2.new(0,10,0,0)
statusBar.BackgroundTransparency = 1; statusBar.Text = "Idle"; statusBar.TextColor3 = C.textDim
statusBar.TextSize = 10; statusBar.Font = Enum.Font.Gotham
statusBar.TextXAlignment = Enum.TextXAlignment.Left; statusBar.ZIndex = 52

-- ============================================================
--  START
-- ============================================================
task.spawn(farmLoop)
task.spawn(cycleLoop)
task.spawn(victoryLoop)
task.spawn(utilityLoop)

task.spawn(function()
    while State.running do
        if State.starting then
            statusBar.Text = "Starting escort..."; statusBar.TextColor3 = C.gold
            repeat task.wait(0.1) until (not State.starting) or (not State.running)
        end
        task.wait(1)
        if State.starting then continue end
        if State.autoFarm or State.autoStart then
            local enemies = getAliveEnemies()
            if isInRaidArea() then
                if #enemies > 0 then
                    statusBar.Text = "Fighting " .. #enemies .. "  •  Run " .. (State.runCount or 0)
                    statusBar.TextColor3 = C.green
                else
                    statusBar.Text = "Escorting  •  Run " .. (State.runCount or 0)
                    statusBar.TextColor3 = C.accent
                end
            else
                local tier = pickKey()
                statusBar.Text = "Lobby  •  next key: " .. (tier or "none") .. "  •  Runs " .. (State.runCount or 0)
                statusBar.TextColor3 = C.gold
            end
        else
            statusBar.Text = "Idle"; statusBar.TextColor3 = C.textDim
        end
    end
end)

player.CharacterAdded:Connect(function()
    task.wait(2)
    if State.autoEquip then equipWeapon() end
end)

print("=========================================")
print("  Escort Auto Farm loaded — Journey's End")
print("  Instant start, key priority, v5 attack")
print("=========================================")
