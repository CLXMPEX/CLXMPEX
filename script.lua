-- ESCORT START TEST — finds the working escorts.create argument shape
local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
local player  = Players.LocalPlayer
local pgui    = player:WaitForChild("PlayerGui", 10)

local ESCORT_NAME = "Journeys End"
local KEY_NAME    = "T1 Holy Key"   -- you have plenty of these
local RAID_Y_MIN  = 5000

local lines = {}
local outLabel
local function render() if outLabel then outLabel.Text = table.concat(lines, "\n") end end
local function log(s) lines[#lines+1] = s; render() end

-- remo container (dotted-name remotes)
local remoBase
pcall(function()
    remoBase = RS:WaitForChild("rbxts_include",5):WaitForChild("node_modules",5)
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
local escortCreate = getRemote("escorts.create")

local function inRaid()
    local c = player.Character
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    return hrp and hrp.Position.Y > RAID_Y_MIN
end

local function run()
    lines = {}
    log("=== ESCORT START TEST ===")
    if not escortCreate then log("escorts.create NOT FOUND"); return end
    log("escorts.create: "..escortCreate.ClassName)
    if inRaid() then log("Already in a raid (Y>5000). Leave first."); return end

    local shapes = {
        {"name,{key=,friendsOnly=}", function() return escortCreate:InvokeServer(ESCORT_NAME, {key=KEY_NAME, friendsOnly=false}) end},
        {"name,{key=}",             function() return escortCreate:InvokeServer(ESCORT_NAME, {key=KEY_NAME}) end},
        {"name,keyName",            function() return escortCreate:InvokeServer(ESCORT_NAME, KEY_NAME) end},
        {"name,{tier='common'}",    function() return escortCreate:InvokeServer(ESCORT_NAME, {tier="common"}) end},
        {"name,{difficulty=key}",   function() return escortCreate:InvokeServer(ESCORT_NAME, {difficulty=KEY_NAME}) end},
        {"{name=,key=}",            function() return escortCreate:InvokeServer({name=ESCORT_NAME, key=KEY_NAME}) end},
    }

    for i, s in ipairs(shapes) do
        if inRaid() then break end
        log("["..i.."] trying: "..s[1])
        local ok, ret = pcall(s[2])
        if ok then log("    call OK, ret="..tostring(ret))
        else log("    ERROR: "..tostring(ret):sub(1,60)) end
        for _ = 1, 8 do
            if inRaid() then break end
            task.wait(0.5)
        end
        if inRaid() then
            log(">> SHAPE "..i.." WORKED — teleported in!")
            log(">> WINNER: "..s[1])
            return
        end
        log("    no teleport")
    end
    log("None teleported in. Tell Claude this output.")
end

-- GUI
local sg = Instance.new("ScreenGui")
sg.Name = "EscortStartTest"; sg.ResetOnSpawn = false; sg.DisplayOrder = 99999
sg.IgnoreGuiInset = true; sg.Parent = pgui
local panel = Instance.new("Frame", sg)
panel.Size = UDim2.new(0, 340, 0, 300); panel.Position = UDim2.new(0, 14, 0, 60)
panel.BackgroundColor3 = Color3.fromRGB(14,16,20); panel.BorderSizePixel = 0
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)
local strk = Instance.new("UIStroke", panel); strk.Color = Color3.fromRGB(120,200,255); strk.Thickness = 1

local function mkBtn(txt, color, x, w)
    local b = Instance.new("TextButton", panel)
    b.Size = UDim2.new(0, w, 0, 30); b.Position = UDim2.new(0, x, 0, 6)
    b.BackgroundColor3 = color; b.Text = txt; b.TextColor3 = Color3.new(1,1,1)
    b.Font = Enum.Font.GothamBold; b.TextSize = 12; b.BorderSizePixel = 0
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end
local runBtn   = mkBtn("TRY START", Color3.fromRGB(60,170,110), 8,   100)
local copyBtn  = mkBtn("COPY",      Color3.fromRGB(70,130,210), 116, 90)
local closeBtn = mkBtn("X",         Color3.fromRGB(200,55,55),  214, 60)

local scroll = Instance.new("ScrollingFrame", panel)
scroll.Size = UDim2.new(1,-12,1,-46); scroll.Position = UDim2.new(0,6,0,42)
scroll.BackgroundColor3 = Color3.fromRGB(8,10,12); scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 5; scroll.CanvasSize = UDim2.new(0,0,0,0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Instance.new("UICorner", scroll).CornerRadius = UDim.new(0,6)
outLabel = Instance.new("TextLabel", scroll)
outLabel.Size = UDim2.new(1,-8,0,0); outLabel.Position = UDim2.new(0,4,0,2)
outLabel.AutomaticSize = Enum.AutomaticSize.Y; outLabel.BackgroundTransparency = 1
outLabel.TextColor3 = Color3.fromRGB(220,230,215); outLabel.Font = Enum.Font.Code
outLabel.TextSize = 11; outLabel.TextXAlignment = Enum.TextXAlignment.Left
outLabel.TextYAlignment = Enum.TextYAlignment.Top; outLabel.TextWrapped = true; outLabel.Text = ""

runBtn.MouseButton1Click:Connect(function()
    runBtn.Text = "..."; task.spawn(function() pcall(run); runBtn.Text = "TRY START" end)
end)
copyBtn.MouseButton1Click:Connect(function()
    local clip = setclipboard or toclipboard or set_clipboard or (syn and syn.write_clipboard)
    local ok = clip and pcall(function() clip(table.concat(lines,"\n")) end)
    copyBtn.Text = ok and "COPIED!" or "NO CLIP"; task.wait(1.2); copyBtn.Text = "COPY"
end)
closeBtn.MouseButton1Click:Connect(function() sg:Destroy() end)

log("Stand in lobby with a T1 key. Tap TRY START.")
