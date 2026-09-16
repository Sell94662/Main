local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 15)

-- Clean up any previous instance
if _G.LootToForgeCleanup then
    pcall(_G.LootToForgeCleanup)
end

-- ====================================================================
-- 📦 GAME MODULES & REMOTES
-- ====================================================================
local CommunicationUtils = require(ReplicatedStorage:WaitForChild("Utils"):WaitForChild("CommunicationUtils"))
local TranslateUtils = require(ReplicatedStorage:WaitForChild("Utils"):WaitForChild("TranslateUtils"))
local TrainCTRL = require(ReplicatedStorage:WaitForChild("CTRL"):WaitForChild("TrainCTRL"))
local HPCTRL = require(ReplicatedStorage:WaitForChild("CTRL"):WaitForChild("HPCTRL"))
local BackpackData = require(ReplicatedStorage:WaitForChild("LocalData"):WaitForChild("BackpackData"))
local StageUtils = require(LocalPlayer.PlayerScripts.Manager.StageManager.StageUtils)
local CameraUtils = require(ReplicatedStorage:WaitForChild("Utils"):WaitForChild("CameraUtils"))
local DamageUtils = require(ReplicatedStorage.SkillSystemNew.Utils.DamageUtils)
local CalculateUtils = require(ReplicatedStorage:WaitForChild("Utils"):WaitForChild("CalculateUtils"))

local WeaponConfig = nil
local OreConfig = nil
local WeaponHelper = nil
local ArmorConfig = nil
local ArmorHelper = nil
local DungeonData = nil
local DungeonFightGUI = nil
pcall(function() WeaponConfig = require(ReplicatedStorage.Config.Weapon.Config) end)
pcall(function() OreConfig = require(ReplicatedStorage.Config.Ore.Config) end)
pcall(function() WeaponHelper = require(ReplicatedStorage.Config.Weapon.Helper) end)
pcall(function() ArmorConfig = require(ReplicatedStorage.Config.Armor.Config) end)
pcall(function() ArmorHelper = require(ReplicatedStorage.Config.Armor.Helper) end)
pcall(function() DungeonData = require(ReplicatedStorage.LocalData.DungeonData) end)
pcall(function() DungeonFightGUI = require(ReplicatedStorage.GuiUtils.DungeonFightGUI) end)
local LeftInfoGUI = nil
local Message = nil
pcall(function() LeftInfoGUI = require(ReplicatedStorage.GuiUtils.LeftInfoGUI) end)
pcall(function() Message = require(ReplicatedStorage.GuiUtils.Message) end)

-- Forward declaration of Config & getStageEnemies for hooks
local Config = {
    HitAllMobs = true,
    OneHitKill = true,
    GodMode = true,
    FastPacketAllStages = false,
    FastPacketTower = false,
    TowerStartRound = 1,
    AutoForgeBestWeapon = false,
    AutoEquipBestWeapon = true,
    AutoRestockOres = false,
    ForgeTargetMode = "CYCLE", -- "CYCLE", "WEAPON", "ARMOR"
    ForgeInterval = 1.5,
    OnlyHighestOres = true,
    MinOreRarity = 8, -- 8: Secret+ (Ore 32-48), 7: Eternal+ (Ore 26-48)
    AutoSellJunkOres = false,
}
local getStageEnemies = nil

-- Hook CalculateUtils.CCPlrDamage for massive 1-hit kill on all normal swings & skills
if not _G.OriginalCCPlrDamage and CalculateUtils then
    _G.OriginalCCPlrDamage = CalculateUtils.CCPlrDamage
    CalculateUtils.CCPlrDamage = function(attacker, skillData)
        if Config.OneHitKill then
            return 1e35
        end
        return _G.OriginalCCPlrDamage(attacker, skillData)
    end
end

-- Hook DamageOnce for absolute player immunity + enemy lethal 1-hit kill
if not _G.OriginalDamageOnce then
    _G.OriginalDamageOnce = HPCTRL.DamageOnce
end
HPCTRL.DamageOnce = function(target, amount)
    if target == LocalPlayer.Character then
        if Config.GodMode then
            return false
        end
        return _G.OriginalDamageOnce(target, amount)
    else
        if Config.OneHitKill then
            local cur = HPCTRL.GetCurrentHP(target) or 0
            local max = HPCTRL.GetMaxHP(target) or 0
            amount = math.max(cur * 2, max * 2, 1e35)
        end
        return _G.OriginalDamageOnce(target, amount)
    end
end

-- Hook TryFireDamageEvent for full-room AoE + amplified damage (Filtered strictly to LocalPlayer)
if not _G.OriginalTryFireDamageEvent and DamageUtils and DamageUtils.TryFireDamageEvent then
    _G.OriginalTryFireDamageEvent = DamageUtils.TryFireDamageEvent
    DamageUtils.TryFireDamageEvent = function(attacker, hitList, damageInfo)
        local isSelf = (attacker == LocalPlayer or attacker == LocalPlayer.Character)
        if isSelf then
            if Config.HitAllMobs then
                local stageMobs = getStageEnemies and getStageEnemies() or {}
                if #stageMobs > 0 then
                    hitList = hitList or {}
                    local seen = {}
                    for _, item in ipairs(hitList) do
                        if item.UUID then seen[item.UUID] = true end
                    end
                    for _, entry in ipairs(stageMobs) do
                        if not seen[entry.uuid] then
                            table.insert(hitList, { Type = "Enemy", UUID = entry.uuid, Model = entry.model })
                        end
                    end
                end
            end
            if Config.OneHitKill and damageInfo then
                damageInfo.Damage = 1e35
            end
        end
        return _G.OriginalTryFireDamageEvent(attacker, hitList, damageInfo)
    end
end

-- Disable screen shake completely
if not _G.OriginalCameraShake then
    _G.OriginalCameraShake = {
        PosShakeOnce = CameraUtils.PosShakeOnce,
        DirShakeOnce = CameraUtils.DirShakeOnce,
        NonShakeOnce = CameraUtils.NonShakeOnce,
        MoveShake = CameraUtils.MoveShake
    }
end
CameraUtils.PosShakeOnce = function(...) end
CameraUtils.DirShakeOnce = function(...) end
CameraUtils.NonShakeOnce = function(...) end
CameraUtils.MoveShake = function(...) end

local Remotes = {
    TrainOnce = CommunicationUtils.TryGetRemoteEvent("Train", "TrainOnceRE"),
    IntoAutoTrain = CommunicationUtils.TryGetRemoteEvent("Train", "IntoAutoTrainRE"),
    ExitAutoTrain = CommunicationUtils.TryGetRemoteEvent("Train", "ExitAutoTrainRE"),
    ClaimedAllOre = CommunicationUtils.TryGetRemoteEvent("Stage", "ClaimedAllOreRE"),
    GetOre = CommunicationUtils.TryGetRemoteFunction("Stage", "GetOreRF"),
    StageFinished = CommunicationUtils.TryGetRemoteFunction("Stage", "StageFinishedRF"),
    TryRebirth = CommunicationUtils.TryGetRemoteEvent("Rebirth", "TryRebirthRE"),
    TrySellAll = CommunicationUtils.TryGetRemoteEvent("Backpack", "TrySellAllRE"),
    ClaimOnline = CommunicationUtils.TryGetRemoteEvent("Online", "TryClaimRE"),
    ClaimOffline = CommunicationUtils.TryGetRemoteEvent("Offline", "TryClaimOfflineRewardRE"),
    ClaimDailyDunTicket = CommunicationUtils.TryGetRemoteEvent("Dungeon", "TryClaimDailyDunTicRE"),
    TryIntoDungeonRF = CommunicationUtils.TryGetRemoteFunction("Dungeon", "TryIntoDungeonRF"),
    StartRoundRE = CommunicationUtils.TryGetRemoteEvent("Dungeon", "StartRoundRE"),
    CompleteRoundRF = CommunicationUtils.TryGetRemoteFunction("Dungeon", "CompleteRoundRF"),
    ExitDungeonRE = CommunicationUtils.TryGetRemoteEvent("Dungeon", "ExitDungeonRE"),
    ExitDungeonBE = CommunicationUtils.TryGetBindableEvent("Stage", "ExitDungeonBE"),
    ClaimIndexExp = CommunicationUtils.TryGetRemoteFunction("Index", "TryClaimIndexExpRF"),
    TryClaimLevelRewardRF = CommunicationUtils.TryGetRemoteFunction("Index", "TryClaimLevelRewardRF"),
    
    KillSuperLootRE = CommunicationUtils.TryGetRemoteEvent("SuperLoot", "KillSuperLootRE"),
    EnemyHitBE = CommunicationUtils.TryGetBindableEvent("Attack", "EnemyHitBE"),
    UpgradeOnceRE = CommunicationUtils.TryGetRemoteEvent("Upgrade", "UpgradeOnceRE"),
    TryUsePotionRE = CommunicationUtils.TryGetRemoteEvent("Potion", "TryUsePotionRE"),
    
    ForgeRF = CommunicationUtils.TryGetRemoteFunction("Forge", "ForgeRF"),
    TryEquipItemRE = CommunicationUtils.TryGetRemoteEvent("Backpack", "TryEquipItemRE"),
    TryUnEquipItemRE = CommunicationUtils.TryGetRemoteEvent("Backpack", "TryUnEquipItemRE"),
    TrySellItemRE = CommunicationUtils.TryGetRemoteEvent("Backpack", "TrySellItemRE"),
    
    ATKOnceBE = CommunicationUtils.TryGetBindableEvent("Attack", "ATKOnceBE"),
    UseSkillByIndexBE = CommunicationUtils.TryGetBindableEvent("Skill", "UseSkillByIndexBE"),
    ExitFightBE = CommunicationUtils.TryGetBindableEvent("Stage", "ExitFightBE"),
}

-- Suppress "Pack is full" notifications & keep carried pack automatically flushed
if not _G.OriginalShowMessage and Message and Message.showMessage then
    _G.OriginalShowMessage = Message.showMessage
    Message.showMessage = function(text, ...)
        if text and (tostring(text):find("Pack is full") or tostring(text):find("full")) then
            if Remotes.ClaimedAllOre then
                pcall(function() Remotes.ClaimedAllOre:FireServer() end)
            end
            if LeftInfoGUI and LeftInfoGUI.UpdateOrePack then
                pcall(function() LeftInfoGUI.UpdateOrePack(0) end)
            end
            return
        end
        return _G.OriginalShowMessage(text, ...)
    end
end

if LeftInfoGUI and LeftInfoGUI.GetOrePack then
    LeftInfoGUI.GetOrePack = function() return 0 end
end

-- ====================================================================
-- ⚙️ CONFIGURATION & RUNTIME
-- ====================================================================
Config.SelectedStage = 1
Config.AutoStageLoop = false
Config.SuperLootSniper = true
Config.OreMagnet = true
Config.SpeedBoost = true
Config.TargetWalkSpeed = 50
Config.AutoPotion = false
Config.AutoUpgradeStats = true
Config.AutoAttackMobs = false
Config.GodMode = true
Config.HitAllMobs = true
Config.OneHitKill = true

-- Farming & Loot
Config.AutoClaimOres = true
Config.OnlyHighestOres = true
Config.MinOreRarity = 8
Config.AutoSellJunkOres = false
Config.AutoSellBag = false
Config.AutoClaimRewards = true

-- Training & Growth (ALL COMBAT/TRAIN OFF BY DEFAULT!)
Config.AutoTrain = false
Config.AutoRebirth = false
Config.AntiAFK = true

-- Auto Forge Best Weapon System
Config.AutoForgeBestWeapon = false
Config.AutoEquipBestWeapon = true
Config.AutoSellJunkGear = true
Config.AutoRestockOres = false
Config.ForgeTargetMode = "CYCLE" -- "CYCLE", "WEAPON", "ARMOR"
Config.ForgeInterval = 1.5

Config.SpeedMode = "HYPER" -- HYPER (0.12s), TURBO (0.15s), FAST (0.2s), NORMAL (0.35s)
Config.TrainDelay = 0.12

-- Auto-detect currently unlocked stage if available
local currentStageAttr = LocalPlayer:GetAttribute("StageID")
if currentStageAttr then
    local num = tonumber(string.match(tostring(currentStageAttr), "%d+"))
    if num and num >= 1 and num <= 22 then
        Config.SelectedStage = num
    end
end

local Runtime = {
    Running = true,
    ActiveTab = "Combat",
    TotalTrained = 0,
    TotalOresClaimed = 0,
    TotalMobsKilled = 0,
    TotalWeaponsForged = 0,
    TotalTowerRounds = 0,
    TotalTowerRuns = 0,
    ForgeHistory = {},
    StartPower = 0,
    Logs = {},
    Connections = {},
    Threads = {}
}

local function addLog(msg)
    table.insert(Runtime.Logs, 1, string.format("[%s] %s", os.date("%X"), msg))
    if #Runtime.Logs > 30 then
        table.remove(Runtime.Logs)
    end
end

-- Number Formatting
local Suffixes = {
    {1e+33, "Dc"}, {1e+30, "No"}, {1e+27, "Oc"}, {1e+24, "Sp"},
    {1e+21, "Sx"}, {1e+18, "Qi"}, {1e+15, "Qa"}, {1e+12, "T"},
    {1e+9, "B"}, {1e+6, "M"}, {1e+3, "K"}
}

local function formatNumber(n)
    local num = tonumber(n)
    if not num then return tostring(n or "0") end
    for _, item in ipairs(Suffixes) do
        if num >= item[1] then
            return string.format("%.2f%s", num / item[1], item[2])
        end
    end
    return tostring(math.floor(num))
end

local function getEcoStat(statName)
    local eco = LocalPlayer:FindFirstChild("Eco")
    if eco then
        local val = eco:FindFirstChild(statName)
        if val then return val.Value end
    end
    return 0
end

Runtime.StartPower = getEcoStat("power")

-- ====================================================================
-- 🛡️ GOD MODE DAMAGE INTERCEPTOR
-- ====================================================================
HPCTRL.DamageOnce = function(target, amount, ...)
    if Config.GodMode and target == LocalPlayer then
        return false
    end
    return _G.OriginalDamageOnce(target, amount, ...)
end

-- ====================================================================
-- 💎 ORE RARITY FILTERS
-- ====================================================================
local function getOreRarity(oreNameOrId)
    if not oreNameOrId then return 1 end
    local id = tostring(oreNameOrId)
    local matched = id:match("Ore_%d+")
    if matched then id = matched end
    local cfg = OreConfig and OreConfig[id]
    if cfg and cfg.Rarity then
        return cfg.Rarity
    end
    local num = tonumber(id:match("%d+"))
    if num then
        if num >= 48 then return 10
        elseif num >= 40 then return 9
        elseif num >= 32 then return 8
        elseif num >= 26 then return 7
        elseif num >= 20 then return 6
        elseif num >= 15 then return 5
        elseif num >= 10 then return 4
        elseif num >= 6 then return 3
        elseif num >= 3 then return 2
        else return 1 end
    end
    return 1
end

local function isOreHighTier(oreNameOrId)
    if not Config.OnlyHighestOres then return true end
    local r = getOreRarity(oreNameOrId)
    return r >= (Config.MinOreRarity or 8)
end

-- ====================================================================
-- 🕹️ CORE EXECUTION ACTIONS
-- ====================================================================
local ToggleSetters = {}
local Actions = {}
_G.LootToForgeActions = Actions
_G.LootToForgeConfig = Config

function Actions.StopTrain()
    pcall(function()
        if TrainCTRL.ExitAutoTrain then
            TrainCTRL.ExitAutoTrain()
        end
        if TrainCTRL.EndTrain then
            TrainCTRL.EndTrain()
        end
        local char = LocalPlayer.Character
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        if humanoid then
            for _, t in ipairs(humanoid:GetPlayingAnimationTracks()) do
                local name = (t.Name or ""):lower()
                if string.find(name, "train") then
                    t:Stop()
                end
            end
        end
    end)
    addLog("Stopped Auto Train.")
end

function Actions.StopStage()
    Config.AutoStageLoop = false
    Config.AutoAttackMobs = false
    
    if ToggleSetters["AutoStageLoop"] then
        ToggleSetters["AutoStageLoop"](false, true)
    end
    if ToggleSetters["AutoAttackMobs"] then
        ToggleSetters["AutoAttackMobs"](false, true)
    end
    
    pcall(function()
        if Remotes.ExitFightBE then
            Remotes.ExitFightBE:Fire(true)
        end
        if TranslateUtils and TranslateUtils.ToSpawn and LocalPlayer.Character then
            TranslateUtils.ToSpawn(LocalPlayer.Character)
        end
        LocalPlayer:SetAttribute("IntoFight", nil)
    end)
    
    pcall(function()
        local char = LocalPlayer.Character
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        if humanoid then
            for _, t in ipairs(humanoid:GetPlayingAnimationTracks()) do
                local name = (t.Name or ""):lower()
                if string.find(name, "atk") then
                    t:Stop()
                end
            end
        end
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local bv = hrp:FindFirstChild("CombatHoverVelocity")
            if bv then bv:Destroy() end
        end
    end)
    
    addLog(string.format("🛑 Stopped Stage %d & Exited Dungeon!", Config.SelectedStage))
end

function Actions.TrainOnce()
    if Remotes.TrainOnce then
        pcall(function()
            Remotes.TrainOnce:FireServer()
        end)
        Runtime.TotalTrained = Runtime.TotalTrained + 1
    end
end

function Actions.StartAutoTrain()
    local areaId = LocalPlayer:GetAttribute("AutoTrainAreaID") or 5
    if Remotes.IntoAutoTrain then
        pcall(function()
            Remotes.IntoAutoTrain:FireServer(areaId)
        end)
    end
    addLog(string.format("⚡ Dual-Engine Auto Train Activated! (Area: %s)", tostring(areaId)))
end

function Actions.StopTrain()
    local areaId = LocalPlayer:GetAttribute("AutoTrainAreaID") or 5
    if Remotes.ExitAutoTrain then
        pcall(function()
            Remotes.ExitAutoTrain:FireServer(areaId)
        end)
    end
    addLog("🛑 Auto Train Deactivated.")
end

function Actions.ClaimAllOres()
    local fireprompt = fireproximityprompt or (getgenv and getgenv().fireproximityprompt)
    local oc = workspace:FindFirstChild("OreCache")
    local count = 0
    if oc then
        for _, ore in ipairs(oc:GetChildren()) do
            if not Config.OnlyHighestOres or isOreHighTier(ore.Name) then
                local prompt = ore:FindFirstChildWhichIsA("ProximityPrompt", true)
                if prompt and fireprompt then
                    pcall(function() fireprompt(prompt) end)
                    count = count + 1
                end
            end
        end
    end
    if Remotes.ClaimedAllOre then
        pcall(function() Remotes.ClaimedAllOre:FireServer() end)
    end
    if LeftInfoGUI and LeftInfoGUI.UpdateOrePack then
        pcall(function() LeftInfoGUI.UpdateOrePack(0) end)
    end
    Runtime.TotalOresClaimed = Runtime.TotalOresClaimed + count
end

function Actions.StartStage(stageNum)
    local stageName = "Stage_" .. tostring(stageNum)
    pcall(function()
        StageUtils.StartFight(stageName)
    end)
    addLog("Engaged " .. stageName)
end

function Actions.PacketClearAllStages()
    local totalOresClaimed = 0
    local startStage = 1
    if Config.OnlyHighestOres then
        startStage = (Config.MinOreRarity and Config.MinOreRarity >= 8) and 21 or 18
    end
    for stageIdx = startStage, 22 do
        local stageName = "Stage_" .. stageIdx
        local s, rewards = pcall(function()
            return Remotes.StageFinished:InvokeServer(stageName)
        end)
        if s and type(rewards) == "table" then
            for uuid, oreType in pairs(rewards) do
                if not Config.OnlyHighestOres or isOreHighTier(oreType) then
                    pcall(function()
                        local res = Remotes.GetOre:InvokeServer(uuid)
                        if res and res ~= false then
                            totalOresClaimed = totalOresClaimed + 1
                        end
                    end)
                end
            end
        end
        -- Immediately flush and deposit carried ores to inventory after each stage
        if Remotes.ClaimedAllOre then
            pcall(function() Remotes.ClaimedAllOre:FireServer() end)
        end
        if LeftInfoGUI and LeftInfoGUI.UpdateOrePack then
            pcall(function() LeftInfoGUI.UpdateOrePack(0) end)
        end
    end
    if Config.AutoSellBag then
        pcall(function() BackpackData.SellAll() end)
    end
    Runtime.TotalOresClaimed = Runtime.TotalOresClaimed + totalOresClaimed
    addLog(string.format("⚡ Packet Cleared Stages %d-22! (+%d %s Ores)", startStage, totalOresClaimed, Config.OnlyHighestOres and "Top-Tier" or "Total"))
    return totalOresClaimed
end

function Actions.PacketClearTower(startRound)
    startRound = startRound or Config.TowerStartRound or 1
    
    -- Check tower tickets
    local ticketItem = nil
    if BackpackData and BackpackData.GetItemDataByIDType then
        ticketItem = BackpackData.GetItemDataByIDType("Dungeon_Ticket", "Material")
    end
    local ticketCount = ticketItem and ticketItem.Number or 0
    
    if ticketCount <= 0 then
        if Remotes.ClaimDailyDunTicket then
            pcall(function() Remotes.ClaimDailyDunTicket:FireServer() end)
            task.wait(0.25)
            if BackpackData and BackpackData.GetItemDataByIDType then
                ticketItem = BackpackData.GetItemDataByIDType("Dungeon_Ticket", "Material")
            end
            ticketCount = ticketItem and ticketItem.Number or 0
        end
        if ticketCount <= 0 then
            addLog("❌ No Tower Tickets left! Cannot enter Frostbound Tower.")
            return false, 0
        end
    end
    
    -- Enter dungeon if not already inside
    if not LocalPlayer:GetAttribute("Dungeoning") then
        local ok = false
        local s = pcall(function()
            if Remotes.TryIntoDungeonRF then
                ok = Remotes.TryIntoDungeonRF:InvokeServer(startRound)
            end
        end)
        if not s or not ok then
            addLog("❌ Failed to enter Frostbound Tower!")
            return false, 0
        end
        task.wait(0.1)
    end
    
    local roundsCleared = 0
    local totalLootCount = 0
    
    -- Fast clear rounds up to 30
    for r = startRound, 30 do
        if not Runtime.Running then break end
        if Remotes.StartRoundRE then
            pcall(function() Remotes.StartRoundRE:FireServer(r) end)
        end
        task.wait(0.04)
        
        local pass = false
        local loot = nil
        if Remotes.CompleteRoundRF then
            local s, res1, res2 = pcall(function()
                return Remotes.CompleteRoundRF:InvokeServer(r)
            end)
            if s then
                loot = res1
                pass = res2
                if pass or loot then
                    roundsCleared = roundsCleared + 1
                    if type(loot) == "table" then
                        totalLootCount = totalLootCount + #loot
                    end
                else
                    break
                end
            else
                break
            end
        end
        task.wait(0.04)
    end
    
    -- Clean exit & state restoration
    pcall(function()
        if Remotes.ExitDungeonRE then
            Remotes.ExitDungeonRE:FireServer()
        end
        if Remotes.ExitDungeonBE then
            Remotes.ExitDungeonBE:Fire()
        end
        if DungeonFightGUI and DungeonFightGUI.Close then
            DungeonFightGUI.Close()
        end
        LocalPlayer:SetAttribute("StageID", nil)
        LocalPlayer:SetAttribute("Dungeoning", nil)
        TranslateUtils.ToSpawn(LocalPlayer.Character)
        
        local infoGui = PlayerGui:FindFirstChild("Info")
        if infoGui then
            if infoGui:FindFirstChild("DungeonResult") then
                infoGui.DungeonResult.Visible = false
            end
            if infoGui:FindFirstChild("RoundCompleted") then
                infoGui.RoundCompleted.Visible = false
            end
        end
    end)
    
    if Config.AutoSellBag and BackpackData and BackpackData.SellAll then
        pcall(function() BackpackData.SellAll() end)
    end
    
    Runtime.TotalTowerRounds = Runtime.TotalTowerRounds + roundsCleared
    Runtime.TotalTowerRuns = Runtime.TotalTowerRuns + 1
    
    local leftTickets = math.max(0, ticketCount - 1)
    addLog(string.format("❄️ Tower Cleared! %d Rounds (+%d Items) [Tickets left: %d]", roundsCleared, totalLootCount, leftTickets))
    return true, roundsCleared
end

function Actions.Rebirth()
    if Remotes.TryRebirth then
        pcall(function() Remotes.TryRebirth:FireServer() end)
    end
end

function Actions.SellAll()
    pcall(function() BackpackData.SellAll() end)
    addLog("Sold all bag items!")
end

function Actions.ClaimAllGifts()
    task.spawn(function()
        if Remotes.ClaimOffline then pcall(function() Remotes.ClaimOffline:FireServer() end) end
        if Remotes.ClaimDailyDunTicket then pcall(function() Remotes.ClaimDailyDunTicket:FireServer() end) end
        if Remotes.ClaimOnline then
            for i = 1, 12 do
                pcall(function() Remotes.ClaimOnline:FireServer(tostring(i)) end)
                task.wait(0.03)
            end
        end
        if Remotes.ClaimIndexExp then pcall(function() Remotes.ClaimIndexExp:InvokeServer() end) end
        if Remotes.TryClaimLevelRewardRF then pcall(function() Remotes.TryClaimLevelRewardRF:InvokeServer() end) end
        addLog("Claimed all gifts, index rewards & tickets!")
    end)
end

function Actions.SnipeSuperLoot()
    local enemyFolder = workspace:FindFirstChild("EnemyFolder")
    if not enemyFolder then return end
    
    for _, e in ipairs(enemyFolder:GetChildren()) do
        if e.Name:match("^SSS%-") or e.Name:match("Super") then
            local uuid = e:GetAttribute("UUID") or e.Name
            local curHp = HPCTRL.GetCurrentHP(e) or 1
            if curHp > 0 then
                for i = 1, math.min(curHp + 2, 12) do
                    if not enemyFolder:FindFirstChild(e.Name) then break end
                    if Remotes.EnemyHitBE then
                        Remotes.EnemyHitBE:Fire(uuid, 1, "Normal")
                    end
                    task.wait(0.03)
                end
                if Remotes.KillSuperLootRE then
                    pcall(function() Remotes.KillSuperLootRE:FireServer(uuid) end)
                end
                addLog(string.format("🎯 SuperLoot Sniped! [%s]", uuid))
            end
        end
    end
end

function Actions.FastOreMagnet()
    local oc = workspace:FindFirstChild("OreCache")
    if not oc then return end
    
    local fireprompt = fireproximityprompt or (getgenv and getgenv().fireproximityprompt)
    local count = 0
    for _, ore in ipairs(oc:GetChildren()) do
        if not Config.OnlyHighestOres or isOreHighTier(ore.Name) then
            local prompt = ore:FindFirstChildWhichIsA("ProximityPrompt", true)
            if prompt then
                for _, conn in ipairs(getconnections(prompt.Triggered)) do
                    conn:Fire()
                end
                if fireprompt then
                    pcall(function() fireprompt(prompt, 0) end)
                end
                count = count + 1
            end
        end
    end
    if count > 0 then
        if Remotes.ClaimedAllOre then
            pcall(function() Remotes.ClaimedAllOre:FireServer() end)
        end
        if LeftInfoGUI and LeftInfoGUI.UpdateOrePack then
            pcall(function() LeftInfoGUI.UpdateOrePack(0) end)
        end
        Runtime.TotalOresClaimed = Runtime.TotalOresClaimed + count
    end
end

function Actions.SellJunkOres()
    local data = BackpackData.GetData()
    if not data or not data.have then return 0 end
    
    local minRarity = Config.MinOreRarity or 8
    local soldCount = 0
    local batches = {}
    
    for uuid, item in pairs(data.have) do
        local id = tostring(item.ID or "")
        if item.Type == "Ore" or item.ConfigType == "Ore" or id:match("Ore") then
            local r = getOreRarity(id)
            if r < minRarity then
                local count = item.Number or item.Count or 1
                if count > 0 then
                    table.insert(batches, { uuid = uuid, count = count, id = id, rarity = r })
                end
            end
        end
    end
    
    for _, b in ipairs(batches) do
        if Remotes.TrySellItemRE then
            pcall(function()
                Remotes.TrySellItemRE:FireServer(b.uuid, b.count)
            end)
            soldCount = soldCount + b.count
            task.wait(0.03)
        end
    end
    
    if soldCount > 0 then
        addLog(string.format("🧹 Purged %d Junk Ores (< Rarity %d) into Coins!", soldCount, minRarity))
    else
        addLog(string.format("✨ Bag already clean! All ores are Rarity %d+", minRarity))
    end
    return soldCount
end

function Actions.ApplyWalkSpeed()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        if Config.SpeedBoost then
            if hum.WalkSpeed ~= Config.TargetWalkSpeed then
                hum.WalkSpeed = Config.TargetWalkSpeed
            end
        end
    end
end

function Actions.AutoUseAllPotions()
    if not Remotes.TryUsePotionRE then return end
    local potions = {"DamagePotion", "LuckPotion", "TrainPotion", "CoinPotion"}
    for _, p in ipairs(potions) do
        pcall(function()
            Remotes.TryUsePotionRE:FireServer(p)
        end)
    end
end

function Actions.AutoUpgradeStats()
    if not Remotes.UpgradeOnceRE then return end
    pcall(function() Remotes.UpgradeOnceRE:FireServer("Luck") end)
    pcall(function() Remotes.UpgradeOnceRE:FireServer("OrePack") end)
    pcall(function() Remotes.UpgradeOnceRE:FireServer("Train") end)
end

-- ====================================================================
-- 🔨 FORGE & WEAPON SYSTEM ACTIONS
-- ====================================================================
function Actions.GetWeaponStats(itemOrId)
    local id = type(itemOrId) == "table" and itemOrId.ID or itemOrId
    local cfg = WeaponConfig and WeaponConfig[id]
    local designPower = cfg and (cfg.DesignPower or 0) or 0
    local trainMult = cfg and (cfg.Train or 0) or 0
    local rarity = cfg and (cfg.Rarity or "Unknown") or "Unknown"
    local name = WeaponHelper and WeaponHelper.GetDisName and WeaponHelper.GetDisName(id) or (cfg and cfg.Name or id)
    local price = cfg and (cfg.Price or 0) or 0
    return {
        ID = id,
        Name = name,
        DesignPower = designPower,
        Train = trainMult,
        Rarity = rarity,
        Price = price
    }
end

function Actions.GetArmorStats(itemOrId)
    local id = type(itemOrId) == "table" and itemOrId.ID or itemOrId
    local cfg = ArmorConfig and ArmorConfig[id]
    local designPower = cfg and (cfg.DesignPower or 0) or 0
    local rarity = cfg and (cfg.Rarity or "Unknown") or "Unknown"
    local name = ArmorHelper and ArmorHelper.GetDisName and ArmorHelper.GetDisName(id) or (cfg and cfg.Name or id)
    local price = cfg and (cfg.Price or 0) or 0
    local bigType = cfg and cfg.BigType or (type(itemOrId) == "table" and itemOrId.Type) or "Armor"
    local attrType = cfg and cfg.AttributeType or ""
    local attrNum = cfg and cfg.AttriNum or 0
    return {
        ID = id,
        Name = name,
        DesignPower = designPower,
        Rarity = rarity,
        Price = price,
        BigType = bigType,
        AttributeType = attrType,
        AttriNum = attrNum
    }
end

function Actions.GetEquippedGearStats()
    local data = BackpackData.GetData()
    local equipped = data.equiped or {}
    
    local weaponStats = nil
    if equipped.Weapon and data.have and data.have[equipped.Weapon] then
        weaponStats = Actions.GetWeaponStats(data.have[equipped.Weapon])
        weaponStats.UUID = equipped.Weapon
    end
    
    local armorStats = nil
    if equipped.Armor and data.have and data.have[equipped.Armor] then
        armorStats = Actions.GetArmorStats(data.have[equipped.Armor])
        armorStats.UUID = equipped.Armor
    end
    
    local hatStats = nil
    if equipped.Hat and data.have and data.have[equipped.Hat] then
        hatStats = Actions.GetArmorStats(data.have[equipped.Hat])
        hatStats.UUID = equipped.Hat
    end
    
    return {
        Weapon = weaponStats,
        Armor = armorStats,
        Hat = hatStats
    }
end

function Actions.GetEquippedWeaponStats()
    local gear = Actions.GetEquippedGearStats()
    return gear.Weapon
end

function Actions.GetBestOresForForge(targetCount)
    targetCount = targetCount or 4
    local data = BackpackData.GetData()
    if not data or not data.have then return nil, 0, {}, "" end
    
    local oreList = {}
    for uuid, item in pairs(data.have) do
        local id = tostring(item.ID or "")
        if item.Type == "Ore" or item.ConfigType == "Ore" or id:match("Ore") then
            local count = item.Number or item.Count or item.Num or 1
            if count > 0 then
                local oreCfg = OreConfig and OreConfig[id]
                local power = oreCfg and (oreCfg.Power or oreCfg.BaseATK) or 0
                local quality = oreCfg and (oreCfg.Quality or oreCfg.Rarity) or 0
                table.insert(oreList, {
                    UUID = uuid,
                    ID = id,
                    Count = count,
                    Power = power,
                    Quality = quality
                })
            end
        end
    end
    
    -- Sort ores strictly by Power descending, then Quality descending
    table.sort(oreList, function(a, b)
        if a.Power ~= b.Power then return a.Power > b.Power end
        return a.Quality > b.Quality
    end)
    
    local selectedUUIDs = {}
    local totalCount = 0
    local oresUsedDesc = {}
    
    for _, ore in ipairs(oreList) do
        local needed = targetCount - totalCount
        local take = math.min(ore.Count, needed)
        if take > 0 then
            selectedUUIDs[ore.UUID] = take
            totalCount = totalCount + take
            table.insert(oresUsedDesc, string.format("%s x%d", ore.ID, take))
        end
        if totalCount >= targetCount then break end
    end
    
    if totalCount < targetCount then
        return nil, totalCount, oreList, ""
    end
    
    return selectedUUIDs, totalCount, oreList, table.concat(oresUsedDesc, ", ")
end

function Actions.ForgeBestWeapon()
    local selectedUUIDs, totalCount, allOres, desc = Actions.GetBestOresForForge()
    if not selectedUUIDs or totalCount < 4 then
        addLog(string.format("⚠️ Not enough ores to forge (Have %d/4 top ores)", totalCount))
        return false, "Not enough ores"
    end
    
    local dataBefore = BackpackData.GetData()
    local beforeUUIDs = {}
    for uuid, _ in pairs(dataBefore.have or {}) do
        beforeUUIDs[uuid] = true
    end
    
    local s, res = pcall(function()
        return Remotes.ForgeRF:InvokeServer({
            ConfigType = "Weapon",
            UUIDList = selectedUUIDs
        })
    end)
    
    if not s or not res then
        addLog("❌ Forge request failed on server.")
        return false, "Server failed"
    end
    
    local craftedItem = res[1] or res
    local craftedID = craftedItem and craftedItem.ID
    local craftedStats = Actions.GetWeaponStats(craftedID)
    
    local newWeaponUUID = nil
    for attempt = 1, 8 do
        task.wait(0.15)
        local dataAfter = BackpackData.GetData()
        for uuid, item in pairs(dataAfter.have or {}) do
            if not beforeUUIDs[uuid] and (item.Type == "Weapon" or item.ConfigType == "Weapon" or tostring(item.ID):match("^[KG]_")) then
                newWeaponUUID = uuid
                break
            end
        end
        if not newWeaponUUID and craftedID then
            for uuid, item in pairs(dataAfter.have or {}) do
                if item.ID == craftedID and uuid ~= (dataAfter.equiped and dataAfter.equiped.Weapon) then
                    newWeaponUUID = uuid
                    break
                end
            end
        end
        if newWeaponUUID then break end
    end
    
    Runtime.TotalWeaponsForged = Runtime.TotalWeaponsForged + 1
    local curEquipped = Actions.GetEquippedWeaponStats()
    local isBetter = false
    if not curEquipped then
        isBetter = true
    elseif craftedStats.DesignPower > curEquipped.DesignPower then
        isBetter = true
    elseif craftedStats.DesignPower == curEquipped.DesignPower and craftedStats.Train > curEquipped.Train then
        isBetter = true
    end
    
    local historyEntry = {
        Name = craftedStats.Name,
        Rarity = craftedStats.Rarity,
        Power = craftedStats.DesignPower,
        Time = os.date("%X"),
        Equipped = false
    }
    
    if isBetter and Config.AutoEquipBestWeapon then
        if newWeaponUUID then
            pcall(function()
                Remotes.TryEquipItemRE:FireServer(newWeaponUUID, "Weapon")
            end)
        else
            task.wait(0.2)
            Actions.EquipHighestWeaponInBag()
        end
        historyEntry.Equipped = true
        addLog(string.format("🎉 AUTO-EQUIPPED NEW BEST: %s (%s | Pwr %d)!", craftedStats.Name, craftedStats.Rarity, craftedStats.DesignPower))
    else
        addLog(string.format("🔨 Forged: %s (%s | Pwr %d)", craftedStats.Name, craftedStats.Rarity, craftedStats.DesignPower))
    end
    
    table.insert(Runtime.ForgeHistory, 1, historyEntry)
    if #Runtime.ForgeHistory > 8 then table.remove(Runtime.ForgeHistory) end
    
    if Config.AutoSellJunkGear then
        task.delay(0.3, function()
            Actions.SellWeakerAndDuplicateGear()
        end)
    end
    
    return true, craftedStats
end

function Actions.EquipHighestWeaponInBag()
    local data = BackpackData.GetData()
    if not data or not data.have then return end
    
    local bestUUID = nil
    local bestPower = -1
    local bestTrain = -1
    local bestName = ""
    local bestRarity = ""
    
    for uuid, item in pairs(data.have) do
        if item.Type == "Weapon" or item.ConfigType == "Weapon" or tostring(item.ID):match("^[KG]_") then
            local stats = Actions.GetWeaponStats(item)
            if stats.DesignPower > bestPower or (stats.DesignPower == bestPower and stats.Train > bestTrain) then
                bestPower = stats.DesignPower
                bestTrain = stats.Train
                bestUUID = uuid
                bestName = stats.Name
                bestRarity = stats.Rarity
            end
        end
    end
    
    if bestUUID then
        pcall(function()
            Remotes.TryEquipItemRE:FireServer(bestUUID, "Weapon")
        end)
        addLog(string.format("🗡️ Equipped Highest in Bag: %s (%s | Pwr %d)", bestName, bestRarity, bestPower))
    else
        addLog("⚠️ No weapons found in backpack.")
    end
end

function Actions.EquipHighestArmorInBag()
    local data = BackpackData.GetData()
    if not data or not data.have then return end
    local bestUUID, bestPower, bestName, bestRarity = nil, -1, "", ""
    for uuid, item in pairs(data.have) do
        local stats = Actions.GetArmorStats(item)
        if stats.BigType == "Armor" and stats.DesignPower > bestPower then
            bestPower = stats.DesignPower
            bestUUID = uuid
            bestName = stats.Name
            bestRarity = stats.Rarity
        end
    end
    if bestUUID then
        pcall(function() Remotes.TryEquipItemRE:FireServer(bestUUID, "Armor") end)
        addLog(string.format("🛡️ Equipped Highest Armor: %s (%s | Pwr %d)", bestName, bestRarity, bestPower))
    else
        addLog("⚠️ No Armor found in backpack.")
    end
end

function Actions.EquipHighestHatInBag()
    local data = BackpackData.GetData()
    if not data or not data.have then return end
    local bestUUID, bestPower, bestName, bestRarity = nil, -1, "", ""
    for uuid, item in pairs(data.have) do
        local stats = Actions.GetArmorStats(item)
        if stats.BigType == "Hat" and stats.DesignPower > bestPower then
            bestPower = stats.DesignPower
            bestUUID = uuid
            bestName = stats.Name
            bestRarity = stats.Rarity
        end
    end
    if bestUUID then
        pcall(function() Remotes.TryEquipItemRE:FireServer(bestUUID, "Hat") end)
        addLog(string.format("👑 Equipped Highest Hat: %s (%s | Pwr %d)", bestName, bestRarity, bestPower))
    else
        addLog("⚠️ No Hat found in backpack.")
    end
end

function Actions.EquipAllBestGearInBag()
    Actions.EquipHighestWeaponInBag()
    Actions.EquipHighestArmorInBag()
    Actions.EquipHighestHatInBag()
    addLog("👑 Equipped Best Gear (Weapon + Armor + Hat)!")
end

function Actions.ForgeBestArmor(preferredTarget)
    local curGear = Actions.GetEquippedGearStats()
    local armorMax = curGear and curGear.Armor and curGear.Armor.DesignPower >= 67
    local hatMax = curGear and curGear.Hat and curGear.Hat.DesignPower >= 67
    
    local targetOres = 10
    if preferredTarget == "Hat" or (armorMax and not hatMax) then
        targetOres = 4
    elseif preferredTarget == "Armor" or (hatMax and not armorMax) then
        targetOres = 10
    end
    
    local selectedUUIDs, totalCount, allOres, desc = Actions.GetBestOresForForge(targetOres)
    if (not selectedUUIDs or totalCount < targetOres) and targetOres > 4 then
        selectedUUIDs, totalCount, allOres, desc = Actions.GetBestOresForForge(4)
        targetOres = 4
    end
    
    if not selectedUUIDs or totalCount < targetOres then
        addLog(string.format("⚠️ Not enough ores to forge Armor/Helm (Need %d, have %d)", targetOres, totalCount))
        return false, "Not enough ores"
    end
    
    local dataBefore = BackpackData.GetData()
    local beforeUUIDs = {}
    for uuid, _ in pairs(dataBefore.have or {}) do beforeUUIDs[uuid] = true end
    
    local s, res = pcall(function()
        return Remotes.ForgeRF:InvokeServer({
            ConfigType = "Armor",
            UUIDList = selectedUUIDs
        })
    end)
    
    if not s or not res then
        addLog("❌ Armor forge request failed on server.")
        return false, "Server failed"
    end
    
    local craftedItem = res[1] or res
    local craftedID = craftedItem and craftedItem.ID
    local craftedStats = Actions.GetArmorStats(craftedID)
    local bigType = craftedStats.BigType -- "Armor" or "Hat"
    
    local newUUID = nil
    for attempt = 1, 8 do
        task.wait(0.15)
        local dataAfter = BackpackData.GetData()
        for uuid, item in pairs(dataAfter.have or {}) do
            if not beforeUUIDs[uuid] and (item.Type == "Armor" or item.Type == "Hat" or (ArmorConfig and ArmorConfig[item.ID])) then
                newUUID = uuid
                break
            end
        end
        if not newUUID and craftedID then
            for uuid, item in pairs(dataAfter.have or {}) do
                if item.ID == craftedID and uuid ~= (dataAfter.equiped and dataAfter.equiped[bigType]) then
                    newUUID = uuid
                    break
                end
            end
        end
        if newUUID then break end
    end
    
    Runtime.TotalWeaponsForged = Runtime.TotalWeaponsForged + 1
    local currentGear = Actions.GetEquippedGearStats()
    local currentEquippedSlot = currentGear and currentGear[bigType]
    
    local isBetter = false
    if not currentEquippedSlot then
        isBetter = true
    elseif craftedStats.DesignPower > currentEquippedSlot.DesignPower then
        isBetter = true
    elseif craftedStats.DesignPower == currentEquippedSlot.DesignPower and craftedStats.AttriNum > currentEquippedSlot.AttriNum then
        isBetter = true
    end
    
    local historyEntry = {
        Name = craftedStats.Name,
        Rarity = craftedStats.Rarity,
        Power = craftedStats.DesignPower,
        Time = os.date("%X"),
        Equipped = false
    }
    
    if isBetter and Config.AutoEquipBestWeapon then
        if newUUID then
            pcall(function()
                Remotes.TryEquipItemRE:FireServer(newUUID, bigType)
            end)
        else
            task.wait(0.2)
            if bigType == "Hat" then
                Actions.EquipHighestHatInBag()
            else
                Actions.EquipHighestArmorInBag()
            end
        end
        historyEntry.Equipped = true
        addLog(string.format("🎉 AUTO-EQUIPPED NEW BEST %s: %s (%s | Pwr %d)!", bigType:upper(), craftedStats.Name, craftedStats.Rarity, craftedStats.DesignPower))
    else
        addLog(string.format("🛡️ Forged %s: %s (%s | Pwr %d)", bigType, craftedStats.Name, craftedStats.Rarity, craftedStats.DesignPower))
    end
    
    table.insert(Runtime.ForgeHistory, 1, historyEntry)
    if #Runtime.ForgeHistory > 8 then table.remove(Runtime.ForgeHistory) end
    
    if Config.AutoSellJunkGear then
        task.delay(0.3, function()
            Actions.SellWeakerAndDuplicateGear()
        end)
    end
    
    return true, craftedStats
end

function Actions.SellWeakerAndDuplicateGear()
    local data = BackpackData.GetData()
    if not data or not data.have then return 0 end
    
    local curGear = Actions.GetEquippedGearStats()
    local equippedUUIDs = {}
    if data.equiped then
        if data.equiped.Weapon then equippedUUIDs[data.equiped.Weapon] = true end
        if data.equiped.Armor then equippedUUIDs[data.equiped.Armor] = true end
        if data.equiped.Hat then equippedUUIDs[data.equiped.Hat] = true end
    end
    
    local curWeaponPower = curGear and curGear.Weapon and curGear.Weapon.DesignPower or 0
    local curArmorPower = curGear and curGear.Armor and curGear.Armor.DesignPower or 0
    local curHatPower = curGear and curGear.Hat and curGear.Hat.DesignPower or 0
    
    local soldCount = 0
    local totalSoldPrice = 0
    local seenIDs = {}
    
    for uuid, item in pairs(data.have) do
        if not equippedUUIDs[uuid] then
            local isWeapon = (item.Type == "Weapon" or item.ConfigType == "Weapon" or tostring(item.ID):match("^[KG]_"))
            local isArmor = (item.Type == "Armor" or item.Type == "Hat" or (ArmorConfig and ArmorConfig[item.ID]))
            
            local shouldSell = false
            local reason = ""
            local itemPrice = 0
            
            if isWeapon then
                local stats = Actions.GetWeaponStats(item)
                itemPrice = stats.Price or 0
                if stats.DesignPower < curWeaponPower then
                    shouldSell = true
                    reason = "weaker"
                elseif stats.DesignPower == curWeaponPower then
                    -- If we already have the equipped one, this is duplicate
                    shouldSell = true
                    reason = "duplicate"
                elseif seenIDs[item.ID] then
                    shouldSell = true
                    reason = "duplicate"
                end
                seenIDs[item.ID] = true
            elseif isArmor then
                local stats = Actions.GetArmorStats(item)
                itemPrice = stats.Price or 0
                local bigType = stats.BigType
                local curPower = (bigType == "Hat") and curHatPower or curArmorPower
                
                if stats.DesignPower < curPower then
                    shouldSell = true
                    reason = "weaker"
                elseif stats.DesignPower == curPower then
                    shouldSell = true
                    reason = "duplicate"
                elseif seenIDs[item.ID] then
                    shouldSell = true
                    reason = "duplicate"
                end
                seenIDs[item.ID] = true
            end
            
            if shouldSell then
                pcall(function()
                    Remotes.TrySellItemRE:FireServer(uuid, 1)
                end)
                soldCount = soldCount + 1
                totalSoldPrice = totalSoldPrice + itemPrice
            end
        end
    end
    
    if soldCount > 0 then
        addLog(string.format("🧹 Auto-Sold %d Weaker/Duplicate gear items (+%s Coins)!", soldCount, formatNumber(totalSoldPrice)))
    end
    
    return soldCount
end

function Actions.RestockHighestStageOres()
    local stageNum = Config.SelectedStage or 22
    if stageNum < 21 then stageNum = 22 end
    local totalRestocked = 0
    pcall(function()
        local rewards = Remotes.StageFinished:InvokeServer("Stage_" .. tostring(stageNum))
        if rewards and type(rewards) == "table" then
            for uuid, oreType in pairs(rewards) do
                if not Config.OnlyHighestOres or isOreHighTier(oreType) then
                    pcall(function()
                        if Remotes.GetOre:InvokeServer(uuid) then
                            totalRestocked = totalRestocked + 1
                        end
                    end)
                end
            end
        end
        if Remotes.ClaimedAllOre then
            pcall(function() Remotes.ClaimedAllOre:FireServer() end)
        end
        if LeftInfoGUI and LeftInfoGUI.UpdateOrePack then
            pcall(function() LeftInfoGUI.UpdateOrePack(0) end)
        end
    end)
    addLog(string.format("⛏️ Restocked Stage %d Top Ores! (+%d)", stageNum, totalRestocked))
end
Actions.RestockStage17Ores = Actions.RestockHighestStageOres

-- Retrieve enemies belonging specifically to the player's active stage
local stageUpvals = debug.getupvalues(StageUtils.HurtEnemy)
local stageDataTab = stageUpvals and stageUpvals[2]

getStageEnemies = function()
    local list = {}
    local curStage = LocalPlayer:GetAttribute("StageID") or ("Stage_" .. tostring(Config.SelectedStage))
    if stageDataTab and stageDataTab[curStage] and stageDataTab[curStage].EnemyTab then
        for uuid, entry in pairs(stageDataTab[curStage].EnemyTab) do
            if not entry.Dead then
                local model = workspace.EnemyFolder:FindFirstChild(uuid)
                if model then
                    table.insert(list, { uuid = uuid, model = model, entry = entry })
                end
            end
        end
    end
    -- Fallback: query alive mobs in EnemyFolder near player
    if #list == 0 then
        local ef = workspace:FindFirstChild("EnemyFolder")
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if ef then
            for _, m in ipairs(ef:GetChildren()) do
                if m:IsA("Model") and not m:GetAttribute("Dead") then
                    if hrp then
                        local dist = (m:GetPivot().Position - hrp.Position).Magnitude
                        if dist < 120 then
                            table.insert(list, { uuid = m.Name, model = m })
                        end
                    else
                        table.insert(list, { uuid = m.Name, model = m })
                    end
                end
            end
        end
    end
    return list
end

-- ====================================================================
-- ⚡ CONCURRENT WORKER THREADS (ALL WORK SIMULTANEOUSLY)
-- ====================================================================

-- Helper to stabilize character in the air without gravity falling jitter
local function setHoverVelocity(hrp, enable)
    if not hrp then return end
    local bv = hrp:FindFirstChild("CombatHoverVelocity")
    if enable then
        if not bv then
            bv = Instance.new("BodyVelocity")
            bv.Name = "CombatHoverVelocity"
            bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
            bv.Velocity = Vector3.new(0, 0, 0)
            bv.Parent = hrp
        end
    else
        if bv then bv:Destroy() end
    end
end

-- Thread 1: Combat & Skill Execution
table.insert(Runtime.Threads, task.spawn(function()
    while Runtime.Running do
        if Config.AutoAttackMobs or Config.AutoStageLoop then
            local stageMobs = getStageEnemies()
            local enemy = stageMobs[1] and stageMobs[1].model
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            
            if enemy and hrp then
                setHoverVelocity(hrp, true)
                local pivot = enemy:GetPivot()
                local targetPos = pivot.Position
                
                -- Calculate stable hovering position (offset diagonally to completely avoid vertical gimbal lock shake)
                local hoverOffset = Config.GodMode and Vector3.new(0, 4.8, 2.5) or Vector3.new(0, 3.2, 3.0)
                local desiredPos = targetPos + hoverOffset
                local desiredCFrame = CFrame.lookAt(desiredPos, targetPos)
                
                -- Deadzone threshold: only teleport when moving to a new mob or drifted away (> 2 studs)
                -- Prevents violent 10/sec micro-jitter and camera twitching
                if (hrp.Position - desiredPos).Magnitude > 2.0 then
                    hrp.CFrame = desiredCFrame
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    hrp.AssemblyAngularVelocity = Vector3.zero
                end
                
                -- Execute Hit All Mobs / One-Hit Kill with 1e35 damage
                if Config.HitAllMobs then
                    for _, item in ipairs(stageMobs) do
                        pcall(function()
                            local dmg = Config.OneHitKill and 1e35 or math.max(50, getEcoStat("power"))
                            StageUtils.HurtEnemy(item.uuid, dmg, "Title")
                        end)
                    end
                elseif Config.OneHitKill then
                    pcall(function()
                        StageUtils.HurtEnemy(stageMobs[1].uuid, 1e35, "Title")
                    end)
                end
                
                -- Fire weapon attack + rotate Skill 1 (Q) & Skill 2 (E)
                pcall(function() Remotes.ATKOnceBE:Fire() end)
                pcall(function() Remotes.UseSkillByIndexBE:Fire(1) end)
                pcall(function() Remotes.UseSkillByIndexBE:Fire(2) end)
                
                task.wait(0.1)
            else
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                setHoverVelocity(hrp, false)
                task.wait(0.25)
            end
        else
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            setHoverVelocity(hrp, false)
            task.wait(0.3)
        end
    end
end))
-- Thread 2: Auto Stage Loop (Continuous Dungeon Progression)
table.insert(Runtime.Threads, task.spawn(function()
    while Runtime.Running do
        if Config.AutoStageLoop then
            local intoFight = LocalPlayer:GetAttribute("IntoFight")
            local ef = workspace:FindFirstChild("EnemyFolder")
            local hasEnemies = ef and #ef:GetChildren() > 0
            
            if not intoFight or not hasEnemies then
                Actions.StartStage(Config.SelectedStage)
                task.wait(1.2)
            end
        end
        task.wait(0.8)
    end
end))

-- Thread 3: Dual-Engine Auto Train Accelerator (Server Passive Auto + Direct Burst)
table.insert(Runtime.Threads, task.spawn(function()
    local wasTraining = false
    while Runtime.Running do
        if Config.AutoTrain then
            if not wasTraining then
                wasTraining = true
                Actions.StartAutoTrain()
            end
            Actions.TrainOnce()
            task.wait(Config.TrainDelay or 0.12)
        else
            if wasTraining then
                wasTraining = false
                Actions.StopTrain()
            end
            task.wait(0.5)
        end
    end
end))

-- Thread 4: Independent Ore Looting (Dual Engine)
table.insert(Runtime.Threads, task.spawn(function()
    while Runtime.Running do
        if Config.AutoClaimOres then
            Actions.ClaimAllOres()
        end
        task.wait(0.35)
    end
end))

-- Thread 5: GodMode Health Lock
table.insert(Runtime.Threads, task.spawn(function()
    while Runtime.Running do
        if Config.GodMode then
            pcall(function()
                HPCTRL.SetCurrentHP(LocalPlayer, HPCTRL.GetMaxHP(LocalPlayer))
            end)
        end
        task.wait(0.4)
    end
end))

-- Thread 6: Auto Rebirth (Zero Combat Interruption)
table.insert(Runtime.Threads, task.spawn(function()
    while Runtime.Running do
        if Config.AutoRebirth then
            Actions.Rebirth()
        end
        task.wait(1.5)
    end
end))

-- Thread 7: Auto Sell Bag & Junk Ores
table.insert(Runtime.Threads, task.spawn(function()
    while Runtime.Running do
        if Config.AutoSellBag then
            Actions.SellAll()
        end
        if Config.AutoSellJunkOres then
            Actions.SellJunkOres()
        end
        task.wait(12)
    end
end))

-- Thread 8: Auto Claim Free Gifts & Online Gifts
table.insert(Runtime.Threads, task.spawn(function()
    while Runtime.Running do
        if Config.AutoClaimRewards then
            Actions.ClaimAllGifts()
            task.wait(60)
        else
            task.wait(2)
        end
    end
end))

-- Thread 9: Anti-AFK Kick Protection
table.insert(Runtime.Threads, task.spawn(function()
    local conn = LocalPlayer.Idled:Connect(function()
        if Config.AntiAFK then
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
            addLog("Anti-AFK active")
        end
    end)
    table.insert(Runtime.Connections, conn)
end))

-- Thread 10: Fast Packet All Stages (Instant Nuke All 17 Stages)
table.insert(Runtime.Threads, task.spawn(function()
    while Runtime.Running do
        if Config.FastPacketAllStages then
            pcall(function()
                Actions.PacketClearAllStages()
            end)
            task.wait(1.0)
        else
            task.wait(0.5)
        end
    end
end))

-- Thread 10.5: Fast Packet Frostbound Tower (Instant Nuke Tower 1-30)
table.insert(Runtime.Threads, task.spawn(function()
    while Runtime.Running do
        if Config.FastPacketTower then
            local success, rounds = Actions.PacketClearTower(Config.TowerStartRound or 1)
            if not success then
                Config.FastPacketTower = false
                if ToggleSetters["FastPacketTower"] then
                    ToggleSetters["FastPacketTower"](false, true)
                end
                task.wait(1.5)
            else
                task.wait(1.5)
            end
        else
            task.wait(0.5)
        end
    end
end))

-- Thread 11: Auto Forge Best Gear (Weapon + Armor + Hat)
local forgeCycleAlternator = false
table.insert(Runtime.Threads, task.spawn(function()
    while Runtime.Running do
        if Config.AutoForgeBestWeapon then
            local selectedUUIDs, totalCount = Actions.GetBestOresForForge()
            if selectedUUIDs and totalCount >= 4 then
                if Config.ForgeTargetMode == "WEAPON" then
                    Actions.ForgeBestWeapon()
                elseif Config.ForgeTargetMode == "ARMOR" then
                    Actions.ForgeBestArmor()
                else -- "CYCLE"
                    forgeCycleAlternator = not forgeCycleAlternator
                    if forgeCycleAlternator then
                        Actions.ForgeBestWeapon()
                    else
                        Actions.ForgeBestArmor()
                    end
                end
                task.wait(Config.ForgeInterval or 1.5)
            else
                if Config.AutoRestockOres then
                    Actions.RestockStage17Ores()
                    task.wait(2.0)
                else
                    task.wait(2.0)
                end
            end
        else
            task.wait(0.5)
        end
    end
end))

-- Thread 12: SuperLoot Boss Sniper
table.insert(Runtime.Threads, task.spawn(function()
    while Runtime.Running do
        if Config.SuperLootSniper then
            pcall(Actions.SnipeSuperLoot)
        end
        task.wait(0.5)
    end
end))

-- Thread 13: Instant Ore Magnet (Full-Map Aura)
table.insert(Runtime.Threads, task.spawn(function()
    while Runtime.Running do
        if Config.OreMagnet then
            pcall(Actions.FastOreMagnet)
        end
        task.wait(0.15)
    end
end))

-- Thread 14: Movement Speed Enforcer
table.insert(Runtime.Threads, task.spawn(function()
    while Runtime.Running do
        if Config.SpeedBoost then
            pcall(Actions.ApplyWalkSpeed)
        end
        task.wait(0.5)
    end
end))

-- Thread 15: Auto Potion Buffs
table.insert(Runtime.Threads, task.spawn(function()
    while Runtime.Running do
        if Config.AutoPotion then
            pcall(Actions.AutoUseAllPotions)
            task.wait(30)
        else
            task.wait(2)
        end
    end
end))

-- Thread 16: Auto Upgrade Stats
table.insert(Runtime.Threads, task.spawn(function()
    while Runtime.Running do
        if Config.AutoUpgradeStats then
            pcall(Actions.AutoUpgradeStats)
            task.wait(10)
        else
            task.wait(2)
        end
    end
end))

-- ====================================================================
-- 🎨 GLASS DECK UI SYSTEM (DARK GLASSMORPHISM & STEEL-CYAN COMMAND DECK)
-- ====================================================================
local GuiParent = (gethui and gethui()) or PlayerGui or game:GetService("CoreGui")
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BloxyScripts"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 99999
ScreenGui.Parent = GuiParent

-- Theme Palette (Strict Glass Deck Tokens)
local Theme = {
    -- Surfaces
    BgDark = Color3.fromRGB(7, 8, 12),              -- #07080c deep base
    BgBody = Color3.fromRGB(10, 12, 17),            -- Window background
    BgPanel = Color3.fromRGB(14, 17, 24),           -- Header / sub-bars
    BgCard = Color3.fromRGB(17, 21, 29),            -- Glass card fill
    BgCardHover = Color3.fromRGB(24, 29, 40),       -- Hovered card
    BgSunken = Color3.fromRGB(5, 6, 9),             -- Deep well / toggle off / terminal
    BgSunkenDeep = Color3.fromRGB(4, 5, 7),         -- Darkest console surface
    
    -- Accent: Signature Muted Steel-Cyan (#3d80a1)
    Accent = Color3.fromRGB(61, 128, 161),          -- #3d80a1 muted steel-cyan
    AccentLight = Color3.fromRGB(90, 178, 218),     -- #5ab2da bright highlight
    AccentDark = Color3.fromRGB(40, 99, 128),       -- #286380 gradient end
    
    -- Alerts & Status
    Danger = Color3.fromRGB(239, 68, 68),           -- #ef4444
    DangerDark = Color3.fromRGB(155, 28, 28),       -- #9b1c1c
    Ok = Color3.fromRGB(52, 211, 153),              -- #34d399
    Warn = Color3.fromRGB(251, 191, 36),            -- #fbbf24
    
    -- Hairline Borders (1px solid var(--border-line))
    BorderLine = Color3.fromRGB(34, 40, 52),        -- Hairline normal
    BorderAccent = Color3.fromRGB(61, 128, 161),    -- Hairline active/focus
    BorderBright = Color3.fromRGB(56, 66, 84),      -- Hovered card hairline
    
    -- Text Ramp (4-step ramp)
    TextBright = Color3.fromRGB(255, 255, 255),     -- #ffffff
    TextMain = Color3.fromRGB(218, 218, 218),       -- #dadada
    TextDim = Color3.fromRGB(140, 147, 160),        -- Labels / inactive
    TextMuted = Color3.fromRGB(88, 94, 106),        -- Timestamps / hints
    
    -- Radii
    RadiusSm = UDim.new(0, 4),                      -- 4px: buttons, pills, tags
    RadiusMd = UDim.new(0, 6),                      -- 6px: cards, panels, toggles
    RadiusLg = UDim.new(0, 8),                      -- 8px: main window shell
}

-- Main Window (.deck-window)
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 380, 0, 560)
MainFrame.Position = UDim2.new(0.02, 0, 0.10, 0)
MainFrame.BackgroundColor3 = Theme.BgBody
MainFrame.BackgroundTransparency = 0.04
MainFrame.BorderSizePixel = 0
MainFrame.Active = false
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner", MainFrame)
MainCorner.CornerRadius = Theme.RadiusLg

local MainStroke = Instance.new("UIStroke", MainFrame)
MainStroke.Color = Theme.BorderLine
MainStroke.Thickness = 1

-- Header Bar (.deck-header frameless titlebar)
local Header = Instance.new("Frame", MainFrame)
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 44)
Header.BackgroundColor3 = Theme.BgPanel
Header.BorderSizePixel = 0
Header.Active = true

local HeaderCorner = Instance.new("UICorner", Header)
HeaderCorner.CornerRadius = Theme.RadiusLg

local HeaderLine = Instance.new("Frame", Header)
HeaderLine.Size = UDim2.new(1, 0, 0, 1)
HeaderLine.Position = UDim2.new(0, 0, 1, -1)
HeaderLine.BackgroundColor3 = Theme.BorderLine
HeaderLine.BorderSizePixel = 0

-- Signature Icon Badge (Double-wrapper stamp)
local OuterBadge = Instance.new("Frame", Header)
OuterBadge.Name = "IconBadge"
OuterBadge.Size = UDim2.new(0, 26, 0, 26)
OuterBadge.Position = UDim2.new(0, 10, 0.5, -13)
OuterBadge.BackgroundColor3 = Theme.BgCard
OuterBadge.BackgroundTransparency = 0.2
local ObCorner = Instance.new("UICorner", OuterBadge) ObCorner.CornerRadius = Theme.RadiusMd
local ObStroke = Instance.new("UIStroke", OuterBadge) ObStroke.Color = Theme.BorderLine ObStroke.Thickness = 1

local InnerBadge = Instance.new("Frame", OuterBadge)
InnerBadge.Name = "InnerBadge"
InnerBadge.Size = UDim2.new(0, 18, 0, 18)
InnerBadge.Position = UDim2.new(0.5, -9, 0.5, -9)
InnerBadge.BackgroundColor3 = Theme.Accent
local IbCorner = Instance.new("UICorner", InnerBadge) IbCorner.CornerRadius = Theme.RadiusSm

local BadgeIcon = Instance.new("TextLabel", InnerBadge)
BadgeIcon.Size = UDim2.new(1, 0, 1, 0)
BadgeIcon.BackgroundTransparency = 1
BadgeIcon.Font = Enum.Font.GothamBold
BadgeIcon.TextSize = 10
BadgeIcon.TextColor3 = Theme.TextBright
BadgeIcon.Text = "⚒"

-- Title & Subtitle block
local Title = Instance.new("TextLabel", Header)
Title.Size = UDim2.new(0, 120, 0, 16)
Title.Position = UDim2.new(0, 42, 0, 8)
Title.BackgroundTransparency = 1
Title.Font = Enum.Font.GothamBold
Title.TextSize = 12
Title.Text = "BloxyScripts"
Title.TextColor3 = Theme.TextBright
Title.TextXAlignment = Enum.TextXAlignment.Left

local SubTitle = Instance.new("TextLabel", Header)
SubTitle.Size = UDim2.new(0, 120, 0, 12)
SubTitle.Position = UDim2.new(0, 42, 0, 24)
SubTitle.BackgroundTransparency = 1
SubTitle.Font = Enum.Font.GothamBold
SubTitle.TextSize = 8.5
SubTitle.Text = "https://t.me/BloxyScripts"
SubTitle.TextColor3 = Theme.TextMuted
SubTitle.TextXAlignment = Enum.TextXAlignment.Left

-- Status Pill (.status-pill)
local StatusPill = Instance.new("Frame", Header)
StatusPill.Name = "StatusPill"
StatusPill.Size = UDim2.new(0, 68, 0, 18)
StatusPill.Position = UDim2.new(1, -128, 0.5, -9)
StatusPill.BackgroundColor3 = Theme.BgSunken
local SpCorner = Instance.new("UICorner", StatusPill) SpCorner.CornerRadius = Theme.RadiusSm
local SpStroke = Instance.new("UIStroke", StatusPill) SpStroke.Color = Theme.BorderLine SpStroke.Thickness = 1

local SpText = Instance.new("TextLabel", StatusPill)
SpText.Size = UDim2.new(1, 0, 1, 0)
SpText.BackgroundTransparency = 1
SpText.Font = Enum.Font.GothamBold
SpText.TextSize = 9
SpText.TextColor3 = Theme.TextDim
SpText.Text = "● ONLINE"
SpText.RichText = true

-- Minimize Button
local MinBtn = Instance.new("TextButton", Header)
MinBtn.Size = UDim2.new(0, 22, 0, 22)
MinBtn.Position = UDim2.new(1, -54, 0.5, -11)
MinBtn.BackgroundColor3 = Theme.BgCard
MinBtn.Font = Enum.Font.GothamBold
MinBtn.Text = "—"
MinBtn.TextColor3 = Theme.TextDim
MinBtn.TextSize = 11
local MinCorner = Instance.new("UICorner", MinBtn) MinCorner.CornerRadius = Theme.RadiusSm
local MinStroke = Instance.new("UIStroke", MinBtn) MinStroke.Color = Theme.BorderLine MinStroke.Thickness = 1

local Minimized = false
MinBtn.Activated:Connect(function()
    Minimized = not Minimized
    if Minimized then
        TweenService:Create(MainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Size = UDim2.new(0, 380, 0, 44)}):Play()
        MinBtn.Text = "+"
    else
        TweenService:Create(MainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Size = UDim2.new(0, 380, 0, 560)}):Play()
        MinBtn.Text = "—"
    end
end)

-- Close Button (Frameless Window Close)
local CloseBtn = Instance.new("TextButton", Header)
CloseBtn.Size = UDim2.new(0, 22, 0, 22)
CloseBtn.Position = UDim2.new(1, -28, 0.5, -11)
CloseBtn.BackgroundColor3 = Theme.BgCard
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Theme.TextDim
CloseBtn.TextSize = 9.5
local ClCorner = Instance.new("UICorner", CloseBtn) ClCorner.CornerRadius = Theme.RadiusSm
local ClStroke = Instance.new("UIStroke", CloseBtn) ClStroke.Color = Theme.BorderLine ClStroke.Thickness = 1

CloseBtn.MouseEnter:Connect(function()
    CloseBtn.BackgroundColor3 = Theme.DangerDark
    CloseBtn.TextColor3 = Theme.TextBright
    ClStroke.Color = Theme.Danger
end)
CloseBtn.MouseLeave:Connect(function()
    CloseBtn.BackgroundColor3 = Theme.BgCard
    CloseBtn.TextColor3 = Theme.TextDim
    ClStroke.Color = Theme.BorderLine
end)
CloseBtn.Activated:Connect(function()
    if _G.LootToForgeCleanup then
        _G.LootToForgeCleanup()
    end
end)

-- Draggable Header
local dragging, dragStart, startPos
Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)

-- Navigation Tab Bar (Glass Deck Segmented Control)
local TabBar = Instance.new("Frame", MainFrame)
TabBar.Name = "TabBar"
TabBar.Size = UDim2.new(1, -20, 0, 30)
TabBar.Position = UDim2.new(0, 10, 0, 50)
TabBar.BackgroundColor3 = Theme.BgSunken
local TabCorner = Instance.new("UICorner", TabBar) TabCorner.CornerRadius = Theme.RadiusMd
local TabStroke = Instance.new("UIStroke", TabBar) TabStroke.Color = Theme.BorderLine TabStroke.Thickness = 1

local Tabs = {"Combat", "Training", "Farming", "Forge", "Dashboard"}
local TabButtons = {}
local TabStrokes = {}
local TabPages = {}

-- Container for all Pages
local PageContainer = Instance.new("Frame", MainFrame)
PageContainer.Name = "PageContainer"
PageContainer.Size = UDim2.new(1, -20, 1, -90)
PageContainer.Position = UDim2.new(0, 10, 0, 86)
PageContainer.BackgroundTransparency = 1

local function switchTab(tabName)
    Runtime.ActiveTab = tabName
    for name, btn in pairs(TabButtons) do
        local isActive = (name == tabName)
        btn.BackgroundColor3 = isActive and Theme.Accent or Color3.new(0, 0, 0)
        btn.BackgroundTransparency = isActive and 0 or 1
        btn.TextColor3 = isActive and Theme.TextBright or Theme.TextDim
        if TabStrokes[name] then
            TabStrokes[name].Color = isActive and Theme.BorderAccent or Color3.new(0, 0, 0)
            TabStrokes[name].Transparency = isActive and 0 or 1
        end
    end
    for name, page in pairs(TabPages) do
        page.Visible = (name == tabName)
    end
end

for i, tabName in ipairs(Tabs) do
    local btn = Instance.new("TextButton", TabBar)
    btn.Size = UDim2.new(1 / #Tabs, -2, 1, -4)
    btn.Position = UDim2.new((i - 1) * (1 / #Tabs), 1, 0, 2)
    btn.BackgroundColor3 = Theme.Accent
    btn.BackgroundTransparency = 1
    btn.Font = Enum.Font.GothamBold
    btn.Text = tabName
    btn.TextColor3 = Theme.TextDim
    btn.TextSize = 10
    local c = Instance.new("UICorner", btn) c.CornerRadius = Theme.RadiusSm
    local s = Instance.new("UIStroke", btn) s.Color = Theme.BorderAccent s.Thickness = 1 s.Transparency = 1
    TabStrokes[tabName] = s
    
    btn.Activated:Connect(function()
        switchTab(tabName)
    end)
    TabButtons[tabName] = btn
    
    local page = Instance.new("ScrollingFrame", PageContainer)
    page.Name = tabName .. "Page"
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = Theme.BorderLine
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = false
    
    local pageLayout = Instance.new("UIListLayout", page)
    pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
    pageLayout.Padding = UDim.new(0, 6)
    
    TabPages[tabName] = page
end

-- ====================================================================
-- 🎛️ GLASS DECK UI HELPERS: CARDS & ROUNDED-SQUARE TOGGLES
-- ====================================================================

local function createCard(parent, height)
    local card = Instance.new("Frame", parent)
    card.Size = UDim2.new(1, -4, 0, height)
    card.BackgroundColor3 = Theme.BgCard
    card.BackgroundTransparency = 0.2
    local c = Instance.new("UICorner", card) c.CornerRadius = Theme.RadiusMd
    local s = Instance.new("UIStroke", card) s.Color = Theme.BorderLine s.Thickness = 1
    return card
end

-- Glass Deck Toggle Switch (Rounded-square track, spring knob)
local function createPillToggle(parent, title, desc, configKey, onToggle)
    local card = Instance.new("Frame", parent)
    card.Size = UDim2.new(1, -4, 0, 48)
    card.BackgroundColor3 = Theme.BgCard
    card.BackgroundTransparency = 0.2
    local c = Instance.new("UICorner", card) c.CornerRadius = Theme.RadiusMd
    local s = Instance.new("UIStroke", card) s.Color = Theme.BorderLine s.Thickness = 1
    
    card.MouseEnter:Connect(function()
        TweenService:Create(s, TweenInfo.new(0.15), {Color = Theme.BorderBright}):Play()
    end)
    card.MouseLeave:Connect(function()
        TweenService:Create(s, TweenInfo.new(0.15), {Color = Theme.BorderLine}):Play()
    end)
    
    local titleLbl = Instance.new("TextLabel", card)
    titleLbl.Size = UDim2.new(1, -64, 0, 18)
    titleLbl.Position = UDim2.new(0, 10, 0, 6)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 11.5
    titleLbl.TextColor3 = Theme.TextBright
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Text = title
    
    local descLbl = Instance.new("TextLabel", card)
    descLbl.Size = UDim2.new(1, -64, 0, 14)
    descLbl.Position = UDim2.new(0, 10, 0, 25)
    descLbl.BackgroundTransparency = 1
    descLbl.Font = Enum.Font.GothamMedium
    descLbl.TextSize = 9.5
    descLbl.TextColor3 = Theme.TextDim
    descLbl.TextXAlignment = Enum.TextXAlignment.Left
    descLbl.Text = desc
    
    -- Rounded-square toggle switch
    local switchBtn = Instance.new("TextButton", card)
    switchBtn.Size = UDim2.new(0, 34, 0, 18)
    switchBtn.Position = UDim2.new(1, -44, 0.5, -9)
    switchBtn.BackgroundColor3 = Config[configKey] and Theme.Accent or Theme.BgSunken
    switchBtn.Text = ""
    switchBtn.AutoButtonColor = false
    local switchCorner = Instance.new("UICorner", switchBtn) switchCorner.CornerRadius = UDim.new(0, 5)
    local switchStroke = Instance.new("UIStroke", switchBtn)
    switchStroke.Color = Config[configKey] and Theme.AccentLight or Theme.BorderLine
    switchStroke.Thickness = 1
    
    local knob = Instance.new("Frame", switchBtn)
    knob.Size = UDim2.new(0, 12, 0, 12)
    knob.Position = Config[configKey] and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)
    knob.BackgroundColor3 = Config[configKey] and Theme.TextBright or Color3.fromRGB(130, 136, 148)
    local knobCorner = Instance.new("UICorner", knob) knobCorner.CornerRadius = UDim.new(0, 3)
    
    local function setVisual(isEnabled, silent)
        Config[configKey] = isEnabled
        local targetTrack = isEnabled and Theme.Accent or Theme.BgSunken
        local targetStroke = isEnabled and Theme.AccentLight or Theme.BorderLine
        local targetKnobPos = isEnabled and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)
        local targetKnobColor = isEnabled and Theme.TextBright or Color3.fromRGB(130, 136, 148)
        
        TweenService:Create(switchBtn, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {BackgroundColor3 = targetTrack}):Play()
        TweenService:Create(switchStroke, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {Color = targetStroke}):Play()
        TweenService:Create(knob, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {Position = targetKnobPos, BackgroundColor3 = targetKnobColor}):Play()
        
        if not silent then
            addLog(string.format("%s: %s", title, isEnabled and "ON" or "OFF"))
        end
        if onToggle then onToggle(isEnabled) end
    end
    
    ToggleSetters[configKey] = setVisual
    
    switchBtn.Activated:Connect(function()
        setVisual(not Config[configKey])
    end)
    
    return card
end

-- ====================================================================
-- ⚔️ TAB 1: COMBAT PAGE
-- ====================================================================
local combatPage = TabPages["Combat"]

-- Target Dungeon Stage Stepper Card
local stageCard = createCard(combatPage, 66)
local stLabel = Instance.new("TextLabel", stageCard)
stLabel.Size = UDim2.new(1, -20, 0, 14)
stLabel.Position = UDim2.new(0, 10, 0, 6)
stLabel.BackgroundTransparency = 1
stLabel.Font = Enum.Font.GothamBold
stLabel.TextSize = 9
stLabel.TextColor3 = Theme.TextMuted
stLabel.TextXAlignment = Enum.TextXAlignment.Left
stLabel.Text = "TARGET DUNGEON STAGE"

local pBtn = Instance.new("TextButton", stageCard)
pBtn.Size = UDim2.new(0, 28, 0, 28)
pBtn.Position = UDim2.new(0, 10, 0, 26)
pBtn.BackgroundColor3 = Theme.BgSunken
pBtn.Font = Enum.Font.GothamBold
pBtn.Text = "◀"
pBtn.TextColor3 = Theme.TextDim
pBtn.TextSize = 11
local pc = Instance.new("UICorner", pBtn) pc.CornerRadius = Theme.RadiusSm
local ps = Instance.new("UIStroke", pBtn) ps.Color = Theme.BorderLine ps.Thickness = 1

local sDisplay = Instance.new("TextLabel", stageCard)
sDisplay.Size = UDim2.new(1, -210, 0, 28)
sDisplay.Position = UDim2.new(0, 42, 0, 26)
sDisplay.BackgroundColor3 = Theme.BgSunken
sDisplay.Font = Enum.Font.Code
sDisplay.TextSize = 11.5
sDisplay.TextColor3 = Theme.AccentLight
sDisplay.Text = string.format("STAGE %02d", Config.SelectedStage)
local sc = Instance.new("UICorner", sDisplay) sc.CornerRadius = Theme.RadiusSm
local ss = Instance.new("UIStroke", sDisplay) ss.Color = Theme.BorderLine ss.Thickness = 1

local nBtn = Instance.new("TextButton", stageCard)
nBtn.Size = UDim2.new(0, 28, 0, 28)
nBtn.Position = UDim2.new(1, -164, 0, 26)
nBtn.BackgroundColor3 = Theme.BgSunken
nBtn.Font = Enum.Font.GothamBold
nBtn.Text = "▶"
nBtn.TextColor3 = Theme.TextDim
nBtn.TextSize = 11
local nc = Instance.new("UICorner", nBtn) nc.CornerRadius = Theme.RadiusSm
local ns = Instance.new("UIStroke", nBtn) ns.Color = Theme.BorderLine ns.Thickness = 1

local fightBtn = Instance.new("TextButton", stageCard)
fightBtn.Size = UDim2.new(0, 64, 0, 28)
fightBtn.Position = UDim2.new(1, -132, 0, 26)
fightBtn.BackgroundColor3 = Theme.Accent
fightBtn.Font = Enum.Font.GothamBold
fightBtn.Text = "⚔ Fight"
fightBtn.TextColor3 = Theme.TextBright
fightBtn.TextSize = 10.5
local fc = Instance.new("UICorner", fightBtn) fc.CornerRadius = Theme.RadiusSm
local fs = Instance.new("UIStroke", fightBtn) fs.Color = Theme.BorderAccent fs.Thickness = 1

local stopStageBtn = Instance.new("TextButton", stageCard)
stopStageBtn.Size = UDim2.new(0, 62, 0, 28)
stopStageBtn.Position = UDim2.new(1, -64, 0, 26)
stopStageBtn.BackgroundColor3 = Theme.DangerDark
stopStageBtn.Font = Enum.Font.GothamBold
stopStageBtn.Text = "🛑 Stop"
stopStageBtn.TextColor3 = Theme.TextBright
stopStageBtn.TextSize = 10.5
local stpc = Instance.new("UICorner", stopStageBtn) stpc.CornerRadius = Theme.RadiusSm
local stps = Instance.new("UIStroke", stopStageBtn) stps.Color = Theme.Danger stps.Thickness = 1

local function updateStageDisplay()
    sDisplay.Text = string.format("STAGE %02d", Config.SelectedStage)
end

pBtn.Activated:Connect(function()
    Config.SelectedStage = Config.SelectedStage - 1
    if Config.SelectedStage < 1 then Config.SelectedStage = 22 end
    updateStageDisplay()
end)

nBtn.Activated:Connect(function()
    Config.SelectedStage = Config.SelectedStage + 1
    if Config.SelectedStage > 22 then Config.SelectedStage = 1 end
    updateStageDisplay()
end)

fightBtn.Activated:Connect(function()
    Actions.StartStage(Config.SelectedStage)
    Config.AutoAttackMobs = true
    Config.AutoStageLoop = true
    if ToggleSetters["AutoStageLoop"] then
        ToggleSetters["AutoStageLoop"](true, true)
    end
    if ToggleSetters["AutoAttackMobs"] then
        ToggleSetters["AutoAttackMobs"](true, true)
    end
end)

stopStageBtn.Activated:Connect(function()
    Actions.StopStage()
end)

-- Frostbound Tower Action Card
local towerCard = createCard(combatPage, 66)
local twLabel = Instance.new("TextLabel", towerCard)
twLabel.Size = UDim2.new(1, -20, 0, 14)
twLabel.Position = UDim2.new(0, 10, 0, 6)
twLabel.BackgroundTransparency = 1
twLabel.Font = Enum.Font.GothamBold
twLabel.TextSize = 9
twLabel.TextColor3 = Theme.TextMuted
twLabel.TextXAlignment = Enum.TextXAlignment.Left
twLabel.Text = "FROSTBOUND TOWER (DUNGEON)"

local clearTowerOnceBtn = Instance.new("TextButton", towerCard)
clearTowerOnceBtn.Size = UDim2.new(1, -20, 0, 28)
clearTowerOnceBtn.Position = UDim2.new(0, 10, 0, 26)
clearTowerOnceBtn.BackgroundColor3 = Theme.Accent
clearTowerOnceBtn.Font = Enum.Font.GothamBold
clearTowerOnceBtn.Text = "❄️ Instant Clear 1 Tower Run (Rounds 1-30)"
clearTowerOnceBtn.TextColor3 = Theme.TextBright
clearTowerOnceBtn.TextSize = 10.5
local ctc = Instance.new("UICorner", clearTowerOnceBtn) ctc.CornerRadius = Theme.RadiusSm
local cts = Instance.new("UIStroke", clearTowerOnceBtn) cts.Color = Theme.BorderAccent cts.Thickness = 1

clearTowerOnceBtn.Activated:Connect(function()
    task.spawn(function()
        Actions.PacketClearTower(1)
    end)
end)

-- Combat Pill Toggles
createPillToggle(combatPage, "⚡ FAST PACKET ALL STAGES", "Nukes & claims all 22 stages simultaneously every second!", "FastPacketAllStages")
createPillToggle(combatPage, "❄️ FAST PACKET FROSTBOUND TOWER", "Auto clears Frostbound Tower (Rounds 1-30) instantly via packets!", "FastPacketTower")
createPillToggle(combatPage, "Auto Stage Loop", "Continuously clear selected stage and auto-restart", "AutoStageLoop", function(isEnabled)
    if not isEnabled then Actions.StopStage() end
end)
createPillToggle(combatPage, "Auto Attack & Skills", "Rotates normal attack and Weapon Skills (Q & E)", "AutoAttackMobs")
createPillToggle(combatPage, "Hit All (Full-Room AoE)", "Hits every alive mob in the dungeon room simultaneously", "HitAllMobs")
createPillToggle(combatPage, "One-Hit Kill (ตีทีเดียวตาย)", "Instantly defeats all enemies in a single blow", "OneHitKill")
createPillToggle(combatPage, "God Mode (Invulnerable)", "Safe floating + damage block, zero damage taken", "GodMode")

-- ====================================================================
-- ⚡ TAB 2: TRAINING PAGE
-- ====================================================================
local trainPage = TabPages["Training"]

-- Speed Mode Selector
local speedCard = createCard(trainPage, 62)
local spTitle = Instance.new("TextLabel", speedCard)
spTitle.Size = UDim2.new(1, -20, 0, 14)
spTitle.Position = UDim2.new(0, 10, 0, 6)
spTitle.BackgroundTransparency = 1
spTitle.Font = Enum.Font.GothamBold
spTitle.TextSize = 9
spTitle.TextColor3 = Theme.TextMuted
spTitle.TextXAlignment = Enum.TextXAlignment.Left
spTitle.Text = "TRAINING SPEED RATE (TICK DELAY)"

local speeds = {"HYPER", "TURBO", "FAST", "NORMAL"}
local speedBtns = {}
local speedStrokes = {}

local function setSpeed(s)
    Config.SpeedMode = s
    if s == "HYPER" then Config.TrainDelay = 0.12
    elseif s == "TURBO" then Config.TrainDelay = 0.15
    elseif s == "FAST" then Config.TrainDelay = 0.20
    else Config.TrainDelay = 0.35 end
    
    for name, b in pairs(speedBtns) do
        local isSel = (name == s)
        b.BackgroundColor3 = isSel and Theme.Accent or Theme.BgSunken
        b.TextColor3 = isSel and Theme.TextBright or Theme.TextDim
        if speedStrokes[name] then
            speedStrokes[name].Color = isSel and Theme.BorderAccent or Theme.BorderLine
        end
    end
    addLog("Training Rate: " .. s)
end

for idx, sName in ipairs(speeds) do
    local b = Instance.new("TextButton", speedCard)
    b.Size = UDim2.new(0.25, -4, 0, 26)
    b.Position = UDim2.new((idx - 1) * 0.25, 2, 0, 26)
    b.BackgroundColor3 = (Config.SpeedMode == sName) and Theme.Accent or Theme.BgSunken
    b.Font = Enum.Font.GothamBold
    b.Text = sName
    b.TextColor3 = (Config.SpeedMode == sName) and Theme.TextBright or Theme.TextDim
    b.TextSize = 9.5
    local bc = Instance.new("UICorner", b) bc.CornerRadius = Theme.RadiusSm
    local bs = Instance.new("UIStroke", b)
    bs.Color = (Config.SpeedMode == sName) and Theme.BorderAccent or Theme.BorderLine
    bs.Thickness = 1
    speedStrokes[sName] = bs
    
    b.Activated:Connect(function()
        setSpeed(sName)
    end)
    speedBtns[sName] = b
end

createPillToggle(trainPage, "Auto Fast Train", "Continuous power farming simultaneously", "AutoTrain", function(isEnabled)
    if not isEnabled then Actions.StopTrain() end
end)
createPillToggle(trainPage, "Auto Rebirth", "Rebirths automatically when requirement is reached", "AutoRebirth")
createPillToggle(trainPage, "Anti-AFK Protection", "Prevents 20-minute disconnect kicks", "AntiAFK")

-- ====================================================================
-- 🎒 TAB 3: FARMING & LOOT PAGE
-- ====================================================================
local farmPage = TabPages["Farming"]

-- Quick Actions Grid
local actionCard = createCard(farmPage, 74)
local actTitle = Instance.new("TextLabel", actionCard)
actTitle.Size = UDim2.new(1, -20, 0, 14)
actTitle.Position = UDim2.new(0, 10, 0, 6)
actTitle.BackgroundTransparency = 1
actTitle.Font = Enum.Font.GothamBold
actTitle.TextSize = 9
actTitle.TextColor3 = Theme.TextMuted
actTitle.TextXAlignment = Enum.TextXAlignment.Left
actTitle.Text = "QUICK ACTIONS"

local function createQuickAction(name, xPos, color, strokeColor, cb)
    local b = Instance.new("TextButton", actionCard)
    b.Size = UDim2.new(0.25, -4, 0, 36)
    b.Position = UDim2.new(xPos, 2, 0, 26)
    b.BackgroundColor3 = color
    b.Font = Enum.Font.GothamBold
    b.Text = name
    b.TextColor3 = Theme.TextBright
    b.TextSize = 9.5
    local bc = Instance.new("UICorner", b) bc.CornerRadius = Theme.RadiusSm
    local bs = Instance.new("UIStroke", b) bs.Color = strokeColor or Theme.BorderLine bs.Thickness = 1
    b.Activated:Connect(cb)
    return b
end

createQuickAction("🎒 Sell Bag", 0, Theme.DangerDark, Theme.Danger, function()
    Actions.SellAll()
end)

createQuickAction("⛏️ Get Ores", 0.25, Theme.Accent, Theme.BorderAccent, function()
    Actions.ClaimAllOres()
end)

createQuickAction("🧹 Junk Ores", 0.5, Theme.BgSunken, Theme.Warn, function()
    Actions.SellJunkOres()
end)

createQuickAction("🎁 Gifts", 0.75, Theme.BgSunken, Theme.BorderLine, function()
    Actions.ClaimAllGifts()
end)

-- Ore Rarity Filter Card
local oreFilterCard = createCard(farmPage, 62)
local ofTitle = Instance.new("TextLabel", oreFilterCard)
ofTitle.Size = UDim2.new(1, -20, 0, 14)
ofTitle.Position = UDim2.new(0, 10, 0, 6)
ofTitle.BackgroundTransparency = 1
ofTitle.Font = Enum.Font.GothamBold
ofTitle.TextSize = 9
ofTitle.TextColor3 = Theme.TextMuted
ofTitle.TextXAlignment = Enum.TextXAlignment.Left
ofTitle.Text = "MINIMUM ORE RARITY FILTER (ระดับแร่เป้าหมาย)"

local rarityTiers = {
    { Label = "⭐ SECRET+ (8+)", Rarity = 8 },
    { Label = "✨ ETERNAL+ (7+)", Rarity = 7 },
    { Label = "🟣 MYTHIC+ (6+)", Rarity = 6 },
}
local rarityBtns = {}
local rarityStrokes = {}
local function setRarityFilter(r)
    Config.MinOreRarity = r
    for _, item in ipairs(rarityTiers) do
        local isSel = (item.Rarity == r)
        local b = rarityBtns[item.Rarity]
        if b then
            b.BackgroundColor3 = isSel and Theme.Accent or Theme.BgSunken
            b.TextColor3 = isSel and Theme.TextBright or Theme.TextDim
        end
        if rarityStrokes[item.Rarity] then
            rarityStrokes[item.Rarity].Color = isSel and Theme.BorderAccent or Theme.BorderLine
        end
    end
    addLog(string.format("Ore Target: Rarity %d+ only!", r))
end

for idx, item in ipairs(rarityTiers) do
    local b = Instance.new("TextButton", oreFilterCard)
    b.Size = UDim2.new(0.333, -4, 0, 26)
    b.Position = UDim2.new((idx - 1) * 0.333, 2, 0, 26)
    b.BackgroundColor3 = (Config.MinOreRarity == item.Rarity) and Theme.Accent or Theme.BgSunken
    b.Font = Enum.Font.GothamBold
    b.Text = item.Label
    b.TextColor3 = (Config.MinOreRarity == item.Rarity) and Theme.TextBright or Theme.TextDim
    b.TextSize = 9
    local bc = Instance.new("UICorner", b) bc.CornerRadius = Theme.RadiusSm
    local bs = Instance.new("UIStroke", b)
    bs.Color = (Config.MinOreRarity == item.Rarity) and Theme.BorderAccent or Theme.BorderLine
    bs.Thickness = 1
    rarityStrokes[item.Rarity] = bs
    
    b.Activated:Connect(function()
        setRarityFilter(item.Rarity)
    end)
    rarityBtns[item.Rarity] = b
end

createPillToggle(farmPage, "💎 Only Highest Tier Ores (เก็บเฉพาะแร่ระดับสูงสุด)", "Skips all low tier ores (Common-Legendary/Mythic) and exclusively collects highest tiers", "OnlyHighestOres")
createPillToggle(farmPage, "🧹 Auto Sell Junk Ores (ขายแร่ขยะอัตโนมัติ)", "Continuously purges any bag ores below the selected rarity threshold into coins", "AutoSellJunkOres")
createPillToggle(farmPage, "🎯 SuperLoot Boss Sniper", "Auto snipes secret bosses & forces Eternal/Secret ore drops!", "SuperLootSniper")
createPillToggle(farmPage, "🧲 Fast Ore Magnet Aura", "Instantly triggers and collects all ore drops across the entire map", "OreMagnet")
createPillToggle(farmPage, "🏃 Movement Speed Boost (50 WalkSpeed)", "Enforces 2x run speed safely without anti-cheat rubberbanding", "SpeedBoost")
createPillToggle(farmPage, "🧪 Auto Potion Engine", "Auto consumes Damage, Luck, Train & Coin boost potions", "AutoPotion")
createPillToggle(farmPage, "⭐ Auto Upgrade Stats", "Automatically upgrades permanent Luck, Pack & Train stats", "AutoUpgradeStats")
createPillToggle(farmPage, "Auto Collect Ores", "Dual-engine instant loot collection from drops", "AutoClaimOres")
createPillToggle(farmPage, "Auto Claim Free Gifts", "Periodically claims online/offline gifts, index & tickets", "AutoClaimRewards")
createPillToggle(farmPage, "Auto Sell Bag", "Periodically cleans bag to prevent inventory overflow", "AutoSellBag")

-- ====================================================================
-- 🔨 TAB 4: FORGE & WEAPON MASTER PAGE
-- ====================================================================
local forgePage = TabPages["Forge"]

-- 1. Status & Target Gear Card (Weapon + Armor + Helmet)
local forgeStatusCard = createCard(forgePage, 134)
local fsTitle = Instance.new("TextLabel", forgeStatusCard)
fsTitle.Size = UDim2.new(1, -20, 0, 14)
fsTitle.Position = UDim2.new(0, 10, 0, 6)
fsTitle.BackgroundTransparency = 1
fsTitle.Font = Enum.Font.GothamBold
fsTitle.TextSize = 9
fsTitle.TextColor3 = Theme.TextMuted
fsTitle.TextXAlignment = Enum.TextXAlignment.Left
fsTitle.Text = "EQUIPPED GEAR STATUS & FORGE ENGINE"

local fsWeapon = Instance.new("TextLabel", forgeStatusCard)
fsWeapon.Size = UDim2.new(1, -20, 0, 15)
fsWeapon.Position = UDim2.new(0, 10, 0, 22)
fsWeapon.BackgroundTransparency = 1
fsWeapon.Font = Enum.Font.GothamBold
fsWeapon.TextSize = 10.5
fsWeapon.TextColor3 = Theme.AccentLight
fsWeapon.TextXAlignment = Enum.TextXAlignment.Left
fsWeapon.Text = "🗡️ Weapon: Scanning..."

local fsArmor = Instance.new("TextLabel", forgeStatusCard)
fsArmor.Size = UDim2.new(1, -20, 0, 15)
fsArmor.Position = UDim2.new(0, 10, 0, 39)
fsArmor.BackgroundTransparency = 1
fsArmor.Font = Enum.Font.GothamBold
fsArmor.TextSize = 10.5
fsArmor.TextColor3 = Theme.Ok
fsArmor.TextXAlignment = Enum.TextXAlignment.Left
fsArmor.Text = "🛡️ Armor: Scanning..."

local fsHat = Instance.new("TextLabel", forgeStatusCard)
fsHat.Size = UDim2.new(1, -20, 0, 15)
fsHat.Position = UDim2.new(0, 10, 0, 56)
fsHat.BackgroundTransparency = 1
fsHat.Font = Enum.Font.GothamBold
fsHat.TextSize = 10.5
fsHat.TextColor3 = Theme.Warn
fsHat.TextXAlignment = Enum.TextXAlignment.Left
fsHat.Text = "👑 Helmet: Scanning..."

local fsTarget = Instance.new("TextLabel", forgeStatusCard)
fsTarget.Size = UDim2.new(1, -20, 0, 15)
fsTarget.Position = UDim2.new(0, 10, 0, 73)
fsTarget.BackgroundTransparency = 1
fsTarget.Font = Enum.Font.GothamMedium
fsTarget.TextSize = 9.5
fsTarget.TextColor3 = Theme.TextDim
fsTarget.TextXAlignment = Enum.TextXAlignment.Left
fsTarget.Text = "🎯 Goals: Bone Carver(150), Verdant Bark(67), Grove Warden(67)"

local fsOres = Instance.new("TextLabel", forgeStatusCard)
fsOres.Size = UDim2.new(1, -20, 0, 36)
fsOres.Position = UDim2.new(0, 10, 0, 90)
fsOres.BackgroundTransparency = 1
fsOres.Font = Enum.Font.Gotham
fsOres.TextSize = 9.5
fsOres.TextColor3 = Theme.TextMuted
fsOres.TextXAlignment = Enum.TextXAlignment.Left
fsOres.TextYAlignment = Enum.TextYAlignment.Top
fsOres.TextWrapped = true
fsOres.Text = "💎 Top Ores: Scanning inventory..."

-- 2. Target Mode Selector Card
local modeCard = createCard(forgePage, 62)
local modeTitle = Instance.new("TextLabel", modeCard)
modeTitle.Size = UDim2.new(1, -20, 0, 14)
modeTitle.Position = UDim2.new(0, 10, 0, 6)
modeTitle.BackgroundTransparency = 1
modeTitle.Font = Enum.Font.GothamBold
modeTitle.TextSize = 9
modeTitle.TextColor3 = Theme.TextMuted
modeTitle.TextXAlignment = Enum.TextXAlignment.Left
modeTitle.Text = "AUTO FORGE TARGET TYPE"

local modeBtns = {}
local modeStrokes = {}
local function setForgeMode(m)
    Config.ForgeTargetMode = m
    for name, b in pairs(modeBtns) do
        local isSel = (name == m)
        b.BackgroundColor3 = isSel and Theme.Accent or Theme.BgSunken
        b.TextColor3 = isSel and Theme.TextBright or Theme.TextDim
        if modeStrokes[name] then
            modeStrokes[name].Color = isSel and Theme.BorderAccent or Theme.BorderLine
        end
    end
    addLog("Forge Target: " .. m)
end

local modeList = {
    { ID = "CYCLE", Text = "👑 All Gear" },
    { ID = "WEAPON", Text = "⚔️ Swords" },
    { ID = "ARMOR", Text = "🛡️ Armor/Helm" }
}

for idx, item in ipairs(modeList) do
    local b = Instance.new("TextButton", modeCard)
    b.Size = UDim2.new(0.333, -4, 0, 26)
    b.Position = UDim2.new((idx - 1) * 0.333, 2, 0, 26)
    b.BackgroundColor3 = (Config.ForgeTargetMode == item.ID) and Theme.Accent or Theme.BgSunken
    b.Font = Enum.Font.GothamBold
    b.Text = item.Text
    b.TextColor3 = (Config.ForgeTargetMode == item.ID) and Theme.TextBright or Theme.TextDim
    b.TextSize = 9.5
    local bc = Instance.new("UICorner", b) bc.CornerRadius = Theme.RadiusSm
    local bs = Instance.new("UIStroke", b)
    bs.Color = (Config.ForgeTargetMode == item.ID) and Theme.BorderAccent or Theme.BorderLine
    bs.Thickness = 1
    modeStrokes[item.ID] = bs
    
    b.Activated:Connect(function()
        setForgeMode(item.ID)
    end)
    modeBtns[item.ID] = b
end

-- 3. Quick Actions Grid
local forgeActionCard = createCard(forgePage, 74)
local faTitle = Instance.new("TextLabel", forgeActionCard)
faTitle.Size = UDim2.new(1, -20, 0, 14)
faTitle.Position = UDim2.new(0, 10, 0, 6)
faTitle.BackgroundTransparency = 1
faTitle.Font = Enum.Font.GothamBold
faTitle.TextSize = 9
faTitle.TextColor3 = Theme.TextMuted
faTitle.TextXAlignment = Enum.TextXAlignment.Left
faTitle.Text = "FORGE ACTIONS"

local function createForgeBtn(name, xPos, color, strokeColor, widthScale, cb)
    local b = Instance.new("TextButton", forgeActionCard)
    b.Size = UDim2.new(widthScale or 0.25, -4, 0, 36)
    b.Position = UDim2.new(xPos, 2, 0, 26)
    b.BackgroundColor3 = color
    b.Font = Enum.Font.GothamBold
    b.Text = name
    b.TextColor3 = Theme.TextBright
    b.TextSize = 9.5
    local bc = Instance.new("UICorner", b) bc.CornerRadius = Theme.RadiusSm
    local bs = Instance.new("UIStroke", b) bs.Color = strokeColor or Theme.BorderLine bs.Thickness = 1
    b.Activated:Connect(cb)
    return b
end

createForgeBtn("🔨 Sword", 0, Theme.Accent, Theme.BorderAccent, 0.25, function()
    Actions.ForgeBestWeapon()
end)

createForgeBtn("🛡️ Armor", 0.25, Theme.BgSunken, Theme.BorderLine, 0.25, function()
    Actions.ForgeBestArmor()
end)

createForgeBtn("👑 Best", 0.5, Theme.BgSunken, Theme.BorderLine, 0.25, function()
    Actions.EquipAllBestGearInBag()
end)

createForgeBtn("🧹 Junk", 0.75, Theme.DangerDark, Theme.Danger, 0.25, function()
    Actions.SellWeakerAndDuplicateGear()
end)

-- 4. Pill Toggles
createPillToggle(forgePage, "⚡ Auto Forge Best Gear", "Auto crafts selected gear (Swords, Armor & Hats)", "AutoForgeBestWeapon")
createPillToggle(forgePage, "🏆 Auto Equip If Better", "Auto equips forged gear if Power/Stats > equipped", "AutoEquipBestWeapon")
createPillToggle(forgePage, "🧹 Auto Sell Weaker & Duplicates", "Auto sells gear that is weaker than equipped or duplicate", "AutoSellJunkGear")
createPillToggle(forgePage, "🔄 Auto Restock Ores", "Auto clears Stage 17 if high-tier ores < 4", "AutoRestockOres")

-- 5. Recent Forge History Card
local forgeLogCard = createCard(forgePage, 108)
local flTitle = Instance.new("TextLabel", forgeLogCard)
flTitle.Size = UDim2.new(1, -20, 0, 14)
flTitle.Position = UDim2.new(0, 10, 0, 6)
flTitle.BackgroundTransparency = 1
flTitle.Font = Enum.Font.GothamBold
flTitle.TextSize = 9
flTitle.TextColor3 = Theme.TextMuted
flTitle.TextXAlignment = Enum.TextXAlignment.Left
flTitle.Text = "RECENT FORGE LOG"

local flContent = Instance.new("TextLabel", forgeLogCard)
flContent.Size = UDim2.new(1, -20, 1, -26)
flContent.Position = UDim2.new(0, 10, 0, 22)
flContent.BackgroundTransparency = 1
flContent.Font = Enum.Font.Code
flContent.TextSize = 9.5
flContent.TextColor3 = Theme.TextDim
flContent.TextXAlignment = Enum.TextXAlignment.Left
flContent.TextYAlignment = Enum.TextYAlignment.Top
flContent.TextWrapped = true
flContent.Text = "No gear forged yet this session."

-- ====================================================================
-- 📊 TAB 5: DASHBOARD & LIVE STATS
-- ====================================================================
local dashPage = TabPages["Dashboard"]

local statCard = createCard(dashPage, 116)
local dashTitle = Instance.new("TextLabel", statCard)
dashTitle.Size = UDim2.new(1, -20, 0, 14)
dashTitle.Position = UDim2.new(0, 10, 0, 6)
dashTitle.BackgroundTransparency = 1
dashTitle.Font = Enum.Font.GothamBold
dashTitle.TextSize = 9
dashTitle.TextColor3 = Theme.TextMuted
dashTitle.TextXAlignment = Enum.TextXAlignment.Left
dashTitle.Text = "LIVE PLAYER TELEMETRY"

local function createStatRow(yPos, color)
    local l = Instance.new("TextLabel", statCard)
    l.Size = UDim2.new(1, -20, 0, 18)
    l.Position = UDim2.new(0, 10, 0, yPos)
    l.BackgroundTransparency = 1
    l.Font = Enum.Font.Code
    l.TextSize = 10.5
    l.TextColor3 = color
    l.TextXAlignment = Enum.TextXAlignment.Left
    return l
end

local dRow1 = createStatRow(24, Theme.AccentLight)
local dRow2 = createStatRow(44, Theme.Ok)
local dRow3 = createStatRow(64, Theme.TextMain)
local dRow4 = createStatRow(84, Theme.TextDim)

-- Live Log Card (Terminal Console Well)
local logCard = createCard(dashPage, 186)
local logTitle = Instance.new("TextLabel", logCard)
logTitle.Size = UDim2.new(1, -20, 0, 14)
logTitle.Position = UDim2.new(0, 10, 0, 6)
logTitle.BackgroundTransparency = 1
logTitle.Font = Enum.Font.GothamBold
logTitle.TextSize = 9
logTitle.TextColor3 = Theme.TextMuted
logTitle.TextXAlignment = Enum.TextXAlignment.Left
logTitle.Text = "ACTIVITY TERMINAL CONSOLE"

local logWell = Instance.new("Frame", logCard)
logWell.Size = UDim2.new(1, -16, 1, -26)
logWell.Position = UDim2.new(0, 8, 0, 20)
logWell.BackgroundColor3 = Theme.BgSunkenDeep
local LwCorner = Instance.new("UICorner", logWell) LwCorner.CornerRadius = Theme.RadiusSm
local LwStroke = Instance.new("UIStroke", logWell) LwStroke.Color = Theme.BorderLine LwStroke.Thickness = 1

local logContent = Instance.new("TextLabel", logWell)
logContent.Size = UDim2.new(1, -12, 1, -10)
logContent.Position = UDim2.new(0, 6, 0, 5)
logContent.BackgroundTransparency = 1
logContent.Font = Enum.Font.Code
logContent.TextSize = 9.5
logContent.TextColor3 = Theme.TextMain
logContent.TextXAlignment = Enum.TextXAlignment.Left
logContent.TextYAlignment = Enum.TextYAlignment.Top
logContent.TextWrapped = true
logContent.Text = "System active and listening..."

-- Telemetry Updater Loop
table.insert(Runtime.Threads, task.spawn(function()
    while Runtime.Running do
        pcall(function()
            local p = getEcoStat("power")
            local l = getEcoStat("level")
            local r = getEcoStat("rebirth")
            local c = getEcoStat("coin")
            
            dRow1.Text = string.format("Power: %s  |  Level: %s", formatNumber(p), tostring(l))
            dRow2.Text = string.format("Rebirth: %s  |  Coins: %s", formatNumber(r), formatNumber(c))
            dRow3.Text = string.format("Trained: %d  |  Forged: %d  |  Ores: %d", Runtime.TotalTrained, Runtime.TotalWeaponsForged, Runtime.TotalOresClaimed)
            dRow4.Text = string.format("Stage: %d  |  Tower: %d Runs (%d Rounds)", Config.SelectedStage, Runtime.TotalTowerRuns, Runtime.TotalTowerRounds)
            
            if #Runtime.Logs > 0 then
                local slice = {}
                for i = 1, math.min(7, #Runtime.Logs) do
                    table.insert(slice, Runtime.Logs[i])
                end
                logContent.Text = table.concat(slice, "\n")
            end
            
            -- Update Forge Live Status for all 3 gear slots
            local gear = Actions.GetEquippedGearStats()
            if gear and gear.Weapon then
                fsWeapon.Text = string.format("🗡️ Weapon: %s [%s | Power: %d]", gear.Weapon.Name, gear.Weapon.Rarity, gear.Weapon.DesignPower)
            else
                fsWeapon.Text = "🗡️ Weapon: None"
            end
            
            if gear and gear.Armor then
                fsArmor.Text = string.format("🛡️ Armor: %s [%s | Power: %d | Def +%d%%]", gear.Armor.Name, gear.Armor.Rarity, gear.Armor.DesignPower, math.floor(gear.Armor.AttriNum * 100))
            else
                fsArmor.Text = "🛡️ Armor: None"
            end
            
            if gear and gear.Hat then
                fsHat.Text = string.format("👑 Helmet: %s [%s | Power: %d | Pwr +%d%%]", gear.Hat.Name, gear.Hat.Rarity, gear.Hat.DesignPower, math.floor(gear.Hat.AttriNum * 100))
            else
                fsHat.Text = "👑 Helmet: None"
            end
            
            local _, totalCount, allOres = Actions.GetBestOresForForge()
            if allOres and #allOres > 0 then
                local topNames = {}
                for i = 1, math.min(3, #allOres) do
                    table.insert(topNames, string.format("%s(x%d, P%d)", allOres[i].ID, allOres[i].Count, allOres[i].Power))
                end
                fsOres.Text = string.format("💎 Ready Ores: %s... (Total: %d)", table.concat(topNames, ", "), totalCount)
            else
                fsOres.Text = "💎 Ready Ores: None in bag (Click Restock!)"
            end
            
            if #Runtime.ForgeHistory > 0 then
                local histLines = {}
                for i = 1, math.min(4, #Runtime.ForgeHistory) do
                    local h = Runtime.ForgeHistory[i]
                    local tag = h.Equipped and "[EQUIPPED]" or "[KEPT]"
                    local typePrefix = h.Type and ("[" .. h.Type:upper() .. "] ") or ""
                    table.insert(histLines, string.format("[%s] %s%s %s (%s, Pwr %d)", h.Time, typePrefix, tag, h.Name, h.Rarity, h.Power))
                end
                flContent.Text = table.concat(histLines, "\n")
            end
        end)
        task.wait(0.4)
    end
end))

-- ====================================================================
-- 🧹 GLOBAL CLEANUP
-- ====================================================================
_G.LootToForgeCleanup = function()
    Runtime.Running = false
    pcall(function()
        Actions.StopStage()
    end)
    if _G.OriginalCameraShake then
        CameraUtils.PosShakeOnce = _G.OriginalCameraShake.PosShakeOnce
        CameraUtils.DirShakeOnce = _G.OriginalCameraShake.DirShakeOnce
        CameraUtils.NonShakeOnce = _G.OriginalCameraShake.NonShakeOnce
        CameraUtils.MoveShake = _G.OriginalCameraShake.MoveShake
    end
    if _G.OriginalDamageOnce then
        HPCTRL.DamageOnce = _G.OriginalDamageOnce
    end
    if _G.OriginalCCPlrDamage and CalculateUtils then
        CalculateUtils.CCPlrDamage = _G.OriginalCCPlrDamage
    end
    if _G.OriginalTryFireDamageEvent and DamageUtils then
        DamageUtils.TryFireDamageEvent = _G.OriginalTryFireDamageEvent
    end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        local bv = hrp:FindFirstChild("CombatHoverVelocity")
        if bv then bv:Destroy() end
    end
    for _, t in ipairs(Runtime.Threads) do pcall(function() task.cancel(t) end) end
    for _, c in ipairs(Runtime.Connections) do pcall(function() c:Disconnect() end) end
    if ScreenGui then ScreenGui:Destroy() end
    print("🧹 BloxyScripts Cleaned up previous session.")
end

-- Set Initial Active Tab
switchTab("Combat")

_G.LootToForge = {
    Config = Config,
    Runtime = Runtime,
    Actions = Actions,
    ScreenGui = ScreenGui,
    MainFrame = MainFrame
}

addLog("Hub V3 Online: All systems operational.")
print("BloxyScripts Loaded!")

return _G.LootToForge
