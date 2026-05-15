-- Load Rayfield UI Library
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "CLXMPEX | AoT Revolution",
    LoadingTitle = "CLXMPEX",
    LoadingSubtitle = "Attack on Titan Revolution",
    Theme = "Ocean",
    DisableRayfieldPrompts = false,
    DisableBuildWarnings = false,
})

-- =====================
-- CONFIG
-- =====================
local Config = {
    KillMethod = "Teleport To Titan",
    AutoFarmSpeed = 300,
    FloatHeight = 400,
    HitXTitans = 3,
    WaitBeforeKillingLastTitan = 30,
    WaitBeforeKillingRaidBossSeconds = 15,
    WaitBeforeStartingFarmingSeconds = 15,
    ReturnAfterXWaves = 10,
    ReturnToLobbyAfterXMinsValue = 10,
    ReturnAfterXGames = 10,
    AutoJoinDelay = 3,
}

-- =====================
-- AUTO JOIN TAB
-- =====================
local AutoJoinTab = Window:CreateTab("Auto Join", 4483362458)

AutoJoinTab:CreateSection("General")

AutoJoinTab:CreateSlider({
    Name = "Auto Join Delay (seconds)",
    Range = {1, 30},
    Increment = 1,
    CurrentValue = Config.AutoJoinDelay,
    Flag = "AutoJoinDelay",
    Callback = function(val) Config.AutoJoinDelay = val end,
})

AutoJoinTab:CreateSection("Missions")

AutoJoinTab:CreateToggle({
    Name = "Auto Join Missions",
    CurrentValue = false,
    Flag = "AutoJoinMissions",
    Callback = function(val) Config.AutoJoinMissions = val end,
})

AutoJoinTab:CreateDropdown({
    Name = "Select Map",
    Options = {"None", "Shiganshina", "Trost", "Outskirts", "Forest", "Utgard", "Docks", "Stohess", "Chapel", "Boosted Map"},
    CurrentOption = {"None"},
    Flag = "MissionMap",
    MultipleOptions = false,
    Callback = function(val) Config.SelectMap_Mission = val end,
})

AutoJoinTab:CreateDropdown({
    Name = "Select Difficulty",
    Options = {"Easy", "Normal", "Hard", "Severe", "Aberrant"},
    CurrentOption = {"Normal"},
    Flag = "MissionDifficulty",
    MultipleOptions = false,
    Callback = function(val) Config.SelectDifficulty_Mission = val end,
})

AutoJoinTab:CreateDropdown({
    Name = "Select Modifiers",
    Options = {"None", "No Perks", "No Skills", "No Memories", "Nightmare", "Oddball", "Injury Prone", "Chronic Injuries", "Fog", "Class Cannon", "Time Trial", "Boring", "Simple"},
    CurrentOption = {"None"},
    Flag = "MissionModifiers",
    MultipleOptions = true,
    Callback = function(val) Config.SelectModifiers_Mission = val end,
})

AutoJoinTab:CreateSection("Raids")

AutoJoinTab:CreateToggle({
    Name = "Auto Join Raids",
    CurrentValue = false,
    Flag = "AutoJoinRaids",
    Callback = function(val) Config.AutoJoinRaids = val end,
})

AutoJoinTab:CreateDropdown({
    Name = "Select Raid",
    Options = {"None", "Attack Titan", "Armored Titan", "Female Titan", "Colossal Titan"},
    CurrentOption = {"None"},
    Flag = "SelectRaid",
    MultipleOptions = false,
    Callback = function(val) Config.SelectRaid = val end,
})

AutoJoinTab:CreateDropdown({
    Name = "Select Difficulty",
    Options = {"Easy", "Normal", "Hard", "Severe", "Aberrant"},
    CurrentOption = {"Normal"},
    Flag = "RaidDifficulty",
    MultipleOptions = false,
    Callback = function(val) Config.SelectDifficulty_Raid = val end,
})

AutoJoinTab:CreateDropdown({
    Name = "Select Modifiers",
    Options = {"None", "No Perks", "No Skills", "No Memories", "Nightmare", "Oddball", "Injury Prone", "Chronic Injuries", "Fog", "Class Cannon", "Time Trial", "Boring", "Simple"},
    CurrentOption = {"None"},
    Flag = "RaidModifiers",
    MultipleOptions = true,
    Callback = function(val) Config.SelectModifiers_Raid = val end,
})

AutoJoinTab:CreateSection("Waves")

AutoJoinTab:CreateToggle({
    Name = "Auto Join Waves",
    CurrentValue = false,
    Flag = "AutoJoinWaves",
    Callback = function(val) Config.AutoJoinWaves = val end,
})

AutoJoinTab:CreateDropdown({
    Name = "Select Map",
    Options = {"Trost"},
    CurrentOption = {"Trost"},
    Flag = "WavesMap",
    MultipleOptions = false,
    Callback = function(val) Config.SelectMap_Waves = val end,
})

-- =====================
-- MAIN TAB
-- =====================
local MainTab = Window:CreateTab("Main", 4483362458)

MainTab:CreateSection("Missions")

MainTab:CreateToggle({
    Name = "Auto Farm (Missions)",
    CurrentValue = false,
    Flag = "AutoFarmMissions",
    Callback = function(val) Config.AutoFarm_Missions = val end,
})

MainTab:CreateSlider({
    Name = "Wait Before Killing Last Titan (seconds)",
    Range = {0, 120},
    Increment = 1,
    CurrentValue = Config.WaitBeforeKillingLastTitan,
    Flag = "WaitLastTitan",
    Callback = function(val) Config.WaitBeforeKillingLastTitan = val end,
})

MainTab:CreateSection("Raids")

MainTab:CreateToggle({
    Name = "Auto Farm (Raids)",
    CurrentValue = false,
    Flag = "AutoFarmRaids",
    Callback = function(val) Config.AutoFarm_Raids = val end,
})

MainTab:CreateToggle({
    Name = "Auto Open Chests",
    CurrentValue = false,
    Flag = "AutoOpenChests",
    Callback = function(val) Config.AutoOpenChests = val end,
})

MainTab:CreateToggle({
    Name = "Auto Open Emperor Chests",
    CurrentValue = false,
    Flag = "AutoOpenEmperorChests",
    Callback = function(val) Config.AutoOpenEmperorChests = val end,
})

MainTab:CreateToggle({
    Name = "Wait Before Killing Raid Boss",
    CurrentValue = false,
    Flag = "WaitRaidBoss",
    Callback = function(val) Config.WaitBeforeKillingRaidBoss = val end,
})

MainTab:CreateSlider({
    Name = "Wait Before Killing Raid Boss (seconds)",
    Range = {0, 120},
    Increment = 1,
    CurrentValue = Config.WaitBeforeKillingRaidBossSeconds,
    Flag = "WaitRaidBossSeconds",
    Callback = function(val) Config.WaitBeforeKillingRaidBossSeconds = val end,
})

MainTab:CreateSection("Waves")

MainTab:CreateToggle({
    Name = "Auto Farm (Waves)",
    CurrentValue = false,
    Flag = "AutoFarmWaves",
    Callback = function(val) Config.AutoFarm_Waves = val end,
})

MainTab:CreateToggle({
    Name = "Auto Start / Skip Wave",
    CurrentValue = false,
    Flag = "AutoStartSkipWave",
    Callback = function(val) Config.AutoStart_SkipWave = val end,
})

MainTab:CreateToggle({
    Name = "Auto Buy Base Upgrades",
    CurrentValue = false,
    Flag = "AutoBuyBaseUpgrades",
    Callback = function(val) Config.AutoBuyBaseUpgrades = val end,
})

MainTab:CreateToggle({
    Name = "Return To Lobby After X Waves",
    CurrentValue = false,
    Flag = "ReturnAfterWaves",
    Callback = function(val) Config.ReturnToLobbyAfterXWaves = val end,
})

MainTab:CreateSlider({
    Name = "Return After X Waves",
    Range = {1, 500},
    Increment = 1,
    CurrentValue = Config.ReturnAfterXWaves,
    Flag = "ReturnAfterXWaves",
    Callback = function(val) Config.ReturnAfterXWaves = val end,
})

MainTab:CreateSection("Settings")

MainTab:CreateSlider({
    Name = "Auto Farm Speed",
    Range = {100, 600},
    Increment = 10,
    CurrentValue = Config.AutoFarmSpeed,
    Flag = "AutoFarmSpeed",
    Callback = function(val) Config.AutoFarmSpeed = val end,
})

MainTab:CreateSlider({
    Name = "Float Height",
    Range = {100, 600},
    Increment = 10,
    CurrentValue = Config.FloatHeight,
    Flag = "FloatHeight",
    Callback = function(val) Config.FloatHeight = val end,
})

MainTab:CreateDropdown({
    Name = "Kill Method",
    Options = {"Teleport To Titan", "Hover Over Titan"},
    CurrentOption = {"Teleport To Titan"},
    Flag = "KillMethod",
    MultipleOptions = false,
    Callback = function(val) Config.KillMethod = val end,
})

MainTab:CreateSection("Security")

MainTab:CreateToggle({
    Name = "Multi Hit Titans",
    CurrentValue = false,
    Flag = "MultiHitTitans",
    Callback = function(val) Config.MultiHitTitans = val end,
})

MainTab:CreateSlider({
    Name = "Hit X Titans At Once",
    Range = {1, 10},
    Increment = 1,
    CurrentValue = Config.HitXTitans,
    Flag = "HitXTitans",
    Callback = function(val) Config.HitXTitans = val end,
})

MainTab:CreateToggle({
    Name = "Wait Before Farming",
    CurrentValue = false,
    Flag = "WaitBeforeFarming",
    Callback = function(val) Config.WaitBeforeFarming = val end,
})

MainTab:CreateSlider({
    Name = "Wait Before Starting Farming (seconds)",
    Range = {0, 120},
    Increment = 1,
    CurrentValue = Config.WaitBeforeStartingFarmingSeconds,
    Flag = "WaitBeforeStartingFarmingSeconds",
    Callback = function(val) Config.WaitBeforeStartingFarmingSeconds = val end,
})

MainTab:CreateSection("Game")

MainTab:CreateToggle({
    Name = "Return To Lobby After X Mins",
    CurrentValue = false,
    Flag = "ReturnAfterMins",
    Callback = function(val) Config.ReturnToLobbyAfterXMins = val end,
})

MainTab:CreateSlider({
    Name = "Return To Lobby After X Mins",
    Range = {1, 120},
    Increment = 1,
    CurrentValue = Config.ReturnToLobbyAfterXMinsValue,
    Flag = "ReturnToLobbyAfterXMinsValue",
    Callback = function(val) Config.ReturnToLobbyAfterXMinsValue = val end,
})

MainTab:CreateToggle({
    Name = "Auto Escape Grab",
    CurrentValue = false,
    Flag = "AutoEscapeGrab",
    Callback = function(val) Config.AutoEscapeGrab = val end,
})

MainTab:CreateToggle({
    Name = "Auto Skip Cutscenes",
    CurrentValue = false,
    Flag = "AutoSkipCutscenes",
    Callback = function(val) Config.AutoSkipCutscenes = val end,
})

MainTab:CreateToggle({
    Name = "Auto Retry",
    CurrentValue = false,
    Flag = "AutoRetry",
    Callback = function(val) Config.AutoRetry = val end,
})

MainTab:CreateToggle({
    Name = "Auto Lobby",
    CurrentValue = false,
    Flag = "AutoLobby",
    Callback = function(val) Config.AutoLobby = val end,
})

MainTab:CreateToggle({
    Name = "Return To Lobby After X Games",
    CurrentValue = false,
    Flag = "ReturnAfterGames",
    Callback = function(val) Config.ReturnToLobbyAfterXGames = val end,
})

MainTab:CreateSlider({
    Name = "Return After X Games",
    Range = {1, 500},
    Increment = 1,
    CurrentValue = Config.ReturnAfterXGames,
    Flag = "ReturnAfterXGames",
    Callback = function(val) Config.ReturnAfterXGames = val end,
})

-- =====================
-- MISC TAB
-- =====================
local MiscTab = Window:CreateTab("Misc", 4483362458)

MiscTab:CreateSection("General")

MiscTab:CreateToggle({
    Name = "Auto Upgrade Gear",
    CurrentValue = false,
    Flag = "AutoUpgradeGear",
    Callback = function(val) Config.AutoUpgradeGear = val end,
})

MiscTab:CreateToggle({
    Name = "Auto Execute Script",
    CurrentValue = false,
    Flag = "AutoExecuteScript",
    Callback = function(val) Config.AutoExecuteScript = val end,
})

MiscTab:CreateButton({
    Name = "Return To Lobby",
    Callback = function()
        Rayfield:Notify({
            Title = "CLXMPEX",
            Content = "Returning to lobby...",
            Duration = 3,
        })
    end,
})

MiscTab:CreateButton({
    Name = "Check If Shadow Banned",
    Callback = function()
        Rayfield:Notify({
            Title = "CLXMPEX",
            Content = "Checking shadow ban status...",
            Duration = 3,
        })
    end,
})

-- Done
Rayfield:Notify({
    Title = "CLXMPEX Loaded",
    Content = "Attack on Titan Revolution script ready!",
    Duration = 5,
})
