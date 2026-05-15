_G.CLXMPEXConfig = {

    -- =====================
    -- [ AUTO JOIN ]
    -- =====================

    AutoJoinDelay = 3, -- seconds

    -- Missions
    AutoJoinMissions = false,
    SelectMap_Mission = "None", -- "Shiganshina", "Trost", "Outskirts", "Forest", "Utgard", "Docks", "Stohess", "Chapel", "Boosted Map"
    SelectObjective = "Skirmish", -- "Skirmish", etc.
    SelectDifficulty_Mission = "Normal", -- "Easy", "Normal", "Hard", "Severe", "Aberrant"
    SelectModifiers_Mission = {"None"}, -- "No Perks", "No Skills", "No Memories", "Nightmare", "Oddball", "Injury Prone", "Chronic Injuries", "Fog", "Class Cannon", "Time Trial", "Boring", "Simple"

    -- Raids
    AutoJoinRaids = false,
    SelectRaid = "None", -- "Attack Titan", "Armored Titan", "Female Titan", "Colossal Titan"
    SelectDifficulty_Raid = "None", -- "Easy", "Normal", "Hard", "Severe", "Aberrant"
    SelectModifiers_Raid = {"None"}, -- "No Perks", "No Skills", "No Memories", "Nightmare", "Oddball", "Injury Prone", "Chronic Injuries", "Fog", "Class Cannon", "Time Trial", "Boring", "Simple"

    -- Waves
    AutoJoinWaves = false,
    SelectMap_Waves = "Trost", -- "Trost"

    -- =====================
    -- [ MAIN - MISSIONS ]
    -- =====================

    AutoFarm_Missions = false,
    WaitBeforeKillingLastTitan = 30, -- seconds

    -- =====================
    -- [ MAIN - RAIDS ]
    -- =====================

    AutoFarm_Raids = false,
    AutoOpenChests = false,
    AutoOpenEmperorChests = false,
    WaitBeforeKillingRaidBoss = false,
    WaitBeforeKillingRaidBossSeconds = 15, -- seconds

    -- =====================
    -- [ MAIN - WAVES ]
    -- =====================

    AutoFarm_Waves = false,
    AutoStart_SkipWave = false,
    AutoUpgradeGear_Waves = false,
    AutoBuyBaseUpgrades = false,
    SelectUpgradesToBuy = "None", -- specify upgrade name or "None"
    ReturnToLobbyAfterXWaves = false,
    ReturnAfterXWaves = 10, -- number of waves (1-500)

    -- =====================
    -- [ MAIN - SETTINGS ]
    -- =====================

    AutoFarmSpeed = 300,   -- min: 100, max: 600
    FloatHeight = 400,     -- min: 100, max: 600
    TeleportToTitans = true, -- teleport to each titan to kill it

    -- =====================
    -- [ MAIN - SECURITY ]
    -- =====================

    MultiHitTitans = false,
    HitXTitans = 3,         -- min: 1, max: 10 (how many titans hit at once)
    WaitBeforeFarming = false,
    WaitBeforeStartingFarmingSeconds = 15, -- seconds

    -- =====================
    -- [ MAIN - GAME ]
    -- =====================

    ReturnToLobbyAfterXMins = false,
    ReturnToLobbyAfterXMinsValue = 10, -- minutes

    AutoEscapeGrab = false,
    AutoSkipCutscenes = false,
    AutoRetry = false,
    AutoLobby = false,
    ReturnToLobbyAfterXGames = false,
    ReturnAfterXGames = 10, -- min: 1, max: 500

    -- =====================
    -- [ MISC ]
    -- =====================

    AutoUpgradeGear_Misc = false,
    AutoExecuteScript = false,

    -- =====================
    -- [ FARM OPTIONS ]
    -- =====================
    -- Add or remove a string to toggle that feature on/off

    FarmOptions = {
        "Auto Farm Missions",
        "Auto Farm Raids",
        "Auto Farm Waves",
        "Auto Open Chests",
        "Auto Open Emperor Chests",
        "Teleport To Titans",
        "Multi Hit Titans",
        "Auto Escape Grab",
        "Auto Skip Cutscenes",
        "Auto Retry",
        "Auto Lobby",
        "Auto Upgrade Gear",
        "Auto Execute Script",
    },

}

loadstring(game:HttpGet("https://api.luarmor.net/files/v4/loaders/705e7fe7aa288f0fe86900cedb1119b1.lua"))()
