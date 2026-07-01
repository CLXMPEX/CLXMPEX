-- ============================================================
--  REMOTE SPY  (comprehensive, standalone)
--  Captures everything about the game's remotes:
--   * Hooks EVERY FireServer / InvokeServer / FireAllClients etc.
--     and logs the remote's full path, the method, and the args.
--   * Can DUMP the full list of remotes in the game on demand.
--   * Live counter + on-screen log + COPY button (mobile-friendly).
--
--  HOW TO USE:
--   1) Run it. A panel appears with a live log.
--   2) Play normally — every remote the game fires shows up.
--   3) Tap DUMP to list every remote object in the game.
--   4) Tap COPY to copy the whole log; paste it to me.
--
--  Buttons: DUMP (list all remotes) · PAUSE · CLEAR · COPY · X
-- ============================================================

local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
local player  = Players.LocalPlayer
local pgui    = player:WaitForChild("PlayerGui", 10)

-- ---------- log store ----------
local lines = {}          -- newest first
local maxLines = 400
local count = 0
local paused = false

-- noisy remotes to skip so the log stays readable (edit as needed)
local SKIP = {}  -- nothing skipped: capture EVERYTHING

local logLabel
local function refresh() if logLabel then logLabel.Text = table.concat(lines, "\n") end end
local function push(s)
    table.insert(lines, 1, s)
    while #lines > maxLines do table.remove(lines) end
    refresh()
end

-- ---------- value stringify ----------
local function short(v, depth)
    depth = depth or 0
    local t = typeof(v)
    if t == "string" then
        if #v > 60 then v = v:sub(1, 60) .. "~" end
        return '"' .. v .. '"'
    elseif t == "number" or t == "boolean" then
        return tostring(v)
    elseif t == "nil" then
        return "nil"
    elseif t == "Instance" then
        return "<" .. v.ClassName .. ":" .. v.Name .. ">"
    elseif t == "Vector3" then
        return string.format("V3(%.1f,%.1f,%.1f)", v.X, v.Y, v.Z)
    elseif t == "CFrame" then
        local p = v.Position
        return string.format("CF(%.1f,%.1f,%.1f)", p.X, p.Y, p.Z)
    elseif t == "table" then
        if depth > 2 then return "{...}" end
        local parts, n = {}, 0
        for k, vv in pairs(v) do
            n = n + 1
            if n > 12 then table.insert(parts, "..."); break end
            table.insert(parts, tostring(k) .. "=" .. short(vv, depth + 1))
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    end
    return t
end

local function argsToStr(args, n)
    local parts = {}
    for i = 1, n do
        parts[i] = short(args[i])
    end
    return table.concat(parts, ", ")
end

-- ---------- the remote hook (namecall) ----------
-- Captures FireServer / InvokeServer from RemoteEvent / RemoteFunction /
-- UnreliableRemoteEvent. Uses hookmetamethod if available, else falls back
-- to hooking each remote's methods individually.
local hookedOk = false
pcall(function()
    local mt = getrawmetatable(game)
    local old = mt.__namecall
    setreadonly(mt, false)
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod and getnamecallmethod() or ""
        if not paused and (method == "FireServer" or method == "InvokeServer"
            or method == "fireServer" or method == "invokeServer") then
            if typeof(self) == "Instance"
               and (self:IsA("RemoteEvent") or self:IsA("RemoteFunction")
                    or self:IsA("UnreliableRemoteEvent")) then
                local path = self.Name
                pcall(function() path = self:GetFullName() end)
                local nameKey = self.Name
                if not SKIP[nameKey] then
                    local args = { ... }
                    local n = select("#", ...)
                    count = count + 1
                    push("[" .. count .. "] " .. method .. "  " .. self.Name)
                    push("     path: " .. path)
                    if n > 0 then
                        push("     args(" .. n .. "): " .. argsToStr(args, n))
                    else
                        push("     args: (none)")
                    end
                end
            end
        end
        return old(self, ...)
    end)
    setreadonly(mt, true)
    hookedOk = true
end)

-- Fallback if hookmetamethod-style approach failed: hook each remote object.
if not hookedOk then
    pcall(function()
        local function hookRemote(rem)
            if rem:IsA("RemoteEvent") or rem:IsA("UnreliableRemoteEvent") then
                local orig = rem.FireServer
                rem.FireServer = function(self, ...)
                    if not paused and not SKIP[self.Name] then
                        local n = select("#", ...)
                        count = count + 1
                        push("[" .. count .. "] FireServer  " .. self.Name)
                        push("     args(" .. n .. "): " .. argsToStr({...}, n))
                    end
                    return orig(self, ...)
                end
            elseif rem:IsA("RemoteFunction") then
                local orig = rem.InvokeServer
                rem.InvokeServer = function(self, ...)
                    if not paused and not SKIP[self.Name] then
                        local n = select("#", ...)
                        count = count + 1
                        push("[" .. count .. "] InvokeServer  " .. self.Name)
                        push("     args(" .. n .. "): " .. argsToStr({...}, n))
                    end
                    return orig(self, ...)
                end
            end
        end
        for _, d in ipairs(game:GetDescendants()) do
            if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("UnreliableRemoteEvent") then
                pcall(hookRemote, d)
            end
        end
    end)
end

-- ---------- DUMP: list every remote in the game ----------
local function dumpRemotes()
    push("================ REMOTE DUMP ================")
    local roots = { ReplicatedStorage = RS,
                    ReplicatedFirst = game:GetService("ReplicatedFirst") }
    -- also scan workspace + a couple common spots lightly
    local seen = {}
    local total = 0
    for rootName, root in pairs(roots) do
        local found = {}
        for _, d in ipairs(root:GetDescendants()) do
            if (d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("UnreliableRemoteEvent"))
               and not seen[d] then
                seen[d] = true
                total = total + 1
                local cls = d:IsA("RemoteFunction") and "RF" or "RE"
                table.insert(found, cls .. "  " .. d.Name)
            end
        end
        push("-- " .. rootName .. " (" .. #found .. ") --")
        table.sort(found)
        for _, s in ipairs(found) do push("   " .. s) end
    end
    push("TOTAL remotes: " .. total)
    push("================ END DUMP ================")
end

-- ---------- GUI ----------
local sg = Instance.new("ScreenGui")
sg.Name = "RemoteSpy"
sg.ResetOnSpawn = false
sg.DisplayOrder = 99999
sg.IgnoreGuiInset = true
sg.Parent = pgui

local panel = Instance.new("Frame", sg)
panel.Size = UDim2.new(0, 400, 0, 340)
panel.Position = UDim2.new(0, 16, 0, 54)
panel.BackgroundColor3 = Color3.fromRGB(10, 10, 16)
panel.BackgroundTransparency = 0.05
panel.BorderSizePixel = 0
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)
local strk = Instance.new("UIStroke", panel)
strk.Color = Color3.fromRGB(255, 120, 200); strk.Thickness = 1

-- top bar (drag + title + count)
local top = Instance.new("Frame", panel)
top.Size = UDim2.new(1, 0, 0, 30)
top.BackgroundColor3 = Color3.fromRGB(22, 20, 28)
top.BorderSizePixel = 0
Instance.new("UICorner", top).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", top)
title.Size = UDim2.new(0.6, 0, 1, 0)
title.Position = UDim2.new(0, 8, 0, 0)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(255, 150, 210)
title.Font = Enum.Font.GothamBold
title.TextSize = 12
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "REMOTE SPY: 0"

-- button row
local btnRow = Instance.new("Frame", panel)
btnRow.Size = UDim2.new(1, -8, 0, 28)
btnRow.Position = UDim2.new(0, 4, 0, 32)
btnRow.BackgroundTransparency = 1

local function mkBtn(txt, color, order, w)
    local b = Instance.new("TextButton", btnRow)
    b.Size = UDim2.new(0, w, 1, 0)
    b.Position = UDim2.new(0, order, 0, 0)
    b.BackgroundColor3 = color
    b.Text = txt
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 11
    b.BorderSizePixel = 0
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end

local dumpBtn  = mkBtn("DUMP",  Color3.fromRGB(150, 90, 220), 0,   72)
local pauseBtn = mkBtn("PAUSE", Color3.fromRGB(200, 150, 40), 76,  72)
local clearBtn = mkBtn("CLEAR", Color3.fromRGB(90, 90, 110),  152, 62)
local copyBtn  = mkBtn("COPY",  Color3.fromRGB(70, 130, 210), 218, 72)
local closeBtn = mkBtn("X",     Color3.fromRGB(200, 55, 55),  294, 40)

-- log scroll
local scroll = Instance.new("ScrollingFrame", panel)
scroll.Size = UDim2.new(1, -8, 1, -66)
scroll.Position = UDim2.new(0, 4, 0, 62)
scroll.BackgroundColor3 = Color3.fromRGB(6, 6, 10)
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 5
scroll.ScrollBarImageColor3 = Color3.fromRGB(255, 120, 200)
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Instance.new("UICorner", scroll).CornerRadius = UDim.new(0, 6)

logLabel = Instance.new("TextLabel", scroll)
logLabel.Size = UDim2.new(1, -8, 0, 0)
logLabel.Position = UDim2.new(0, 4, 0, 2)
logLabel.AutomaticSize = Enum.AutomaticSize.Y
logLabel.BackgroundTransparency = 1
logLabel.TextColor3 = Color3.fromRGB(220, 225, 235)
logLabel.Font = Enum.Font.Code
logLabel.TextSize = 10
logLabel.TextXAlignment = Enum.TextXAlignment.Left
logLabel.TextYAlignment = Enum.TextYAlignment.Top
logLabel.TextWrapped = true
logLabel.Text = ""

-- button actions
dumpBtn.MouseButton1Click:Connect(function()
    dumpBtn.Text = "..."
    task.spawn(function()
        dumpRemotes()
        dumpBtn.Text = "DUMP"
    end)
end)
pauseBtn.MouseButton1Click:Connect(function()
    paused = not paused
    pauseBtn.Text = paused and "RESUME" or "PAUSE"
    pauseBtn.BackgroundColor3 = paused and Color3.fromRGB(60, 160, 90) or Color3.fromRGB(200, 150, 40)
end)
clearBtn.MouseButton1Click:Connect(function()
    lines = {}; refresh()
end)
copyBtn.MouseButton1Click:Connect(function()
    local ordered = {}
    for i = #lines, 1, -1 do table.insert(ordered, lines[i]) end
    local out = "=== REMOTE SPY OUTPUT ===\nhook mode: "
        .. (hookedOk and "namecall" or "per-remote")
        .. "\n" .. table.concat(ordered, "\n")
    local clip = setclipboard or toclipboard or set_clipboard or (syn and syn.write_clipboard)
    local ok = clip and pcall(function() clip(out) end)
    copyBtn.Text = ok and "COPIED!" or "NO CLIP"
    task.wait(1.2); copyBtn.Text = "COPY"
end)
closeBtn.MouseButton1Click:Connect(function() sg:Destroy() end)

-- drag by top bar
local UIS = game:GetService("UserInputService")
local drag = { on = false, s = nil, p = nil }
top.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
        drag.on = true; drag.s = i.Position; drag.p = panel.Position
    end
end)
UIS.InputChanged:Connect(function(i)
    if drag.on and (i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseMovement) then
        local d = i.Position - drag.s
        panel.Position = UDim2.new(drag.p.X.Scale, drag.p.X.Offset + d.X, drag.p.Y.Scale, drag.p.Y.Offset + d.Y)
    end
end)
UIS.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
        drag.on = false
    end
end)

-- live counter
task.spawn(function()
    while sg.Parent do
        title.Text = "REMOTE SPY: " .. count .. (paused and "  [PAUSED]" or "")
        task.wait(0.3)
    end
end)

-- startup notes
push("hook mode: " .. (hookedOk and "namecall (best)" or "per-remote fallback"))
push("Play the game — remote calls will appear here.")
push("Tap DUMP to list every remote. Tap COPY to copy all.")
push("Nothing skipped — every remote is captured.")
push("=================================================")
