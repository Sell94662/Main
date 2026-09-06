local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/TheBloxyScripts/BloxyScripts/main/main.lua"))()

local Window = Library:CreateWindow({
    Name = "Bloxy Scripts",
    LoadingTitle = "Loading ",
    LoadingSubtitle = "by BloxyScripts (Telegram)",
    FolderName = "BladeBallConfigs"
})

local Hub = Window or getgenv().CustomHub
if not Hub then return end

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Stats = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer

-- State & Settings
local State = {
    AutoParry = false,
    BaseParryDistance = 25,
    CurrentDynamicDistance = 25,
    InstantPrediction = true,
    Visualizer = false,
    DomeMaterialIndex = 4, -- ForceField по умолчанию
    DomeColorIndex = 2, -- Cyan
    DomeTransparency = 0.35,
    FPSBoost = false,
    AutoFarm = false,
}

-- Пресеты цветов
local ColorsList = {
    {Name = "Green", Color = Color3.fromRGB(0, 255, 120)},
    {Name = "Cyan", Color = Color3.fromRGB(0, 220, 255)},
    {Name = "Blue", Color = Color3.fromRGB(50, 120, 255)},
    {Name = "Purple", Color = Color3.fromRGB(180, 50, 255)},
    {Name = "Gold", Color = Color3.fromRGB(255, 215, 0)},
    {Name = "White", Color = Color3.fromRGB(255, 255, 255)}
}

-- Пресеты материалов
local MaterialsList = {
    {Name = "SmoothPlastic", Material = Enum.Material.SmoothPlastic},
    {Name = "Glass", Material = Enum.Material.Glass},
    {Name = "Neon", Material = Enum.Material.Neon},
    {Name = "ForceField", Material = Enum.Material.ForceField}
}

local function GetBall()
    local ballsFolder = Workspace:FindFirstChild("Balls")
    if ballsFolder then
        for _, ball in ipairs(ballsFolder:GetChildren()) do
            if ball:IsA("BasePart") or ball:IsA("Model") then
                if ball:GetAttribute("realBall") == true or ball.Name:match("Ball") then
                    if ball:IsA("Model") then
                        return ball.PrimaryPart or ball:FindFirstChildWhichIsA("BasePart")
                    else
                        return ball
                    end
                end
            end
        end
        local fallback = ballsFolder:FindFirstChildWhichIsA("BasePart", true)
        if fallback then return fallback end
    end
    
    for _, obj in pairs(Workspace:GetChildren()) do
        if obj:IsA("BasePart") and (obj.Name:match("Ball") or obj.Name == "Part") then
            if obj.Size.Magnitude > 2 and obj.Size.Magnitude < 20 then
                return obj
            end
        end
    end
    return nil
end

local function GetRootPart(plr)
    local char = plr and plr.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function GetHumanoid(plr)
    local char = plr and plr.Character
    return char and char:FindFirstChildWhichIsA("Humanoid")
end

local function GetPing()
    local success, val = pcall(function()
        return Stats.Network.ServerStatsItem["Data Receive Kbps"]:GetValue() / 1000
    end)
    return success and val or 0.05
end

local function SimulateKeyPress(key)
    VirtualInputManager:SendKeyEvent(true, key, false, nil)
    task.wait(0.005)
    VirtualInputManager:SendKeyEvent(false, key, false, nil)
end

-- Авто-паррирование с проверкой, что мяч летит именно в игрока
local ParryConnection = nil
local lastParryTick = 0

local function StartAutoParry()
    if ParryConnection then ParryConnection:Disconnect() end
    ParryConnection = RunService.RenderStepped:Connect(function()
        if not State.AutoParry then return end
        
        local ball = GetBall()
        local root = GetRootPart(LocalPlayer)
        if not ball or not root then return end
        
        local ballPos = ball.Position
        local rootPos = root.Position
        local dist = (ballPos - rootPos).Magnitude
        local velocity = ball.AssemblyLinearVelocity
        local speed = velocity.Magnitude
        
        local dynamicDistance = State.BaseParryDistance
        if speed > 20 then
            dynamicDistance = math.clamp(State.BaseParryDistance + (speed / 6), State.BaseParryDistance, 50)
        end
        State.CurrentDynamicDistance = math.clamp(dynamicDistance, 10, 50)
        
        local dirToPlayer = (rootPos - ballPos).Unit
        local ballDir = speed > 0 and velocity.Unit or Vector3.new()
        local dot = ballDir:Dot(dirToPlayer)
        
        -- Проверяем атрибут цели игры, если он есть
        local targetPlayer = ball:GetAttribute("target") or ball:GetAttribute("Target")
        local isTargetingMe = (targetPlayer == LocalPlayer.Name or targetPlayer == LocalPlayer)
        
        -- Геометрическая проверка: мяч должен лететь прямо на нас (а не пролетать рядом)
        local isHeadingTowardsMe = dot > 0.75
        
        local closingSpeed = speed * math.max(0, dot)
        local timeToCollision = closingSpeed > 0 and (dist / closingSpeed) or 999
        
        local ping = GetPing()
        local thresholdTime = math.clamp(ping * 1.5, 0.03, 0.12)
        
        -- Срабатываем только если расстояние/время критические И мяч летит конкретно в нас
        if (dist <= State.CurrentDynamicDistance or timeToCollision <= thresholdTime) and (isHeadingTowardsMe or isTargetingMe) then
            local currentTime = tick()
            if currentTime - lastParryTick > 0.15 then
                lastParryTick = currentTime
                SimulateKeyPress(Enum.KeyCode.F)
            end
        end
    end)
end

-- Автофарм с безопасным увеличенным радиусом от мяча и проверкой на 160 стадов
RunService.RenderStepped:Connect(function()
    if not State.AutoFarm then return end
    
    local ball = GetBall()
    local root = GetRootPart(LocalPlayer)
    local humanoid = GetHumanoid(LocalPlayer)
    if not ball or not root or not humanoid then return end
    
    local ballPos = ball.Position
    local rootPos = root.Position
    local dist = (ballPos - rootPos).Magnitude
    
    -- Если мяч дальше 160 стадов или отсутствует, игрок стоит на месте
    if dist > 160 then
        return
    end
    
    -- Держимся на безопасном расстоянии от мяча
    if dist < 17 then
        local escapeDir = (rootPos - ballPos) * Vector3.new(1, 0, 1)
        if escapeDir.Magnitude > 0 then
            escapeDir = escapeDir.Unit
        else
            escapeDir = Vector3.new(1, 0, 0)
        end
        humanoid:MoveTo(ballPos + (escapeDir * 16))
    elseif dist > 20 then
        humanoid:MoveTo(ballPos + Vector3.new(0, 0, 5))
    end
end)

-- Создание купола
local DomePart = nil
local function CreateDome()
    if DomePart then return end
    DomePart = Instance.new("Part")
    DomePart.Name = "BladeBallVisualDome"
    DomePart.Shape = Enum.PartType.Ball
    DomePart.Anchored = true
    DomePart.CanCollide = false
    DomePart.CastShadow = false
    DomePart.Locked = true
    DomePart.Parent = Workspace
end

local function RemoveDome()
    if DomePart then
        DomePart:Destroy()
        DomePart = nil
    end
end

-- Рендер купола
RunService.RenderStepped:Connect(function()
    if not State.Visualizer then
        RemoveDome()
        return
    end
    
    if not DomePart then
        CreateDome()
    end
    
    local root = GetRootPart(LocalPlayer)
    if not root then
        if DomePart then DomePart.Transparency = 1 end
        return
    end
    
    local clampedDist = math.clamp(State.CurrentDynamicDistance, 10, 50)
    local diameter = clampedDist * 2
    
    DomePart.Size = Vector3.new(diameter, diameter, diameter)
    DomePart.CFrame = root.CFrame
    
    local currentMat = MaterialsList[State.DomeMaterialIndex]
    if currentMat then
        DomePart.Material = currentMat.Material
    end
    
    local ball = GetBall()
    if ball and (ball.Position - root.Position).Magnitude <= clampedDist then
        DomePart.Color = Color3.fromRGB(255, 50, 50)
        DomePart.Transparency = math.clamp(State.DomeTransparency - 0.15, 0.1, 0.8)
    else
        local currentCol = ColorsList[State.DomeColorIndex]
        if currentCol then
            DomePart.Color = currentCol.Color
        end
        DomePart.Transparency = State.DomeTransparency
    end
end)

-- ==========================================
-- ИНТЕРФЕЙС И МУЛЬТИЯЗЫЧНОСТЬ
-- ==========================================

-- Вкладка: Combat
local CombatTab = Hub:CreateTab({EN = "Combat", RU = "Бой"})

CombatTab:AddSection({EN = "Instant Parry", RU = "Aвто-паррирование"})

CombatTab:AddToggle({EN = "Auto Parry", RU = "Авто-паррирование"}, "AutoParry", false, function(s) 
    State.AutoParry = s 
    if s then StartAutoParry() end 
end)

CombatTab:AddToggle({EN = "Legit AutoFarm (Smart Movement)", RU = "Автофарм (Умное движение)"}, "AutoFarm", false, function(s)
    State.AutoFarm = s
end)

CombatTab:AddSlider({EN = "Base Distance", RU = "Базовая дистанция"}, "BaseParryDistance", 10, 40, 25, function(val) 
    State.BaseParryDistance = val 
end)

CombatTab:AddToggle({EN = "Instant Velocity Prediction", RU = "Предсказание скорости"}, "InstantPrediction", true, function(s) 
    State.InstantPrediction = s 
end)

CombatTab:AddSection({EN = "Dome Customization", RU = "Настройка купола"})

CombatTab:AddToggle({EN = "Enable Dome Visualizer", RU = "Включить купол"}, "Visualizer", false, function(s) 
    State.Visualizer = s 
end)

CombatTab:AddButton({EN = "Next Color", RU = "Следующий цвет"}, function()
    State.DomeColorIndex = State.DomeColorIndex + 1
    if State.DomeColorIndex > #ColorsList then State.DomeColorIndex = 1 end
end)

CombatTab:AddButton({EN = "Next Material", RU = "Следующий материал"}, function()
    State.DomeMaterialIndex = State.DomeMaterialIndex + 1
    if State.DomeMaterialIndex > #MaterialsList then State.DomeMaterialIndex = 1 end
end)

CombatTab:AddSlider({EN = "Transparency", RU = "Прозрачность"}, "DomeTransparency", 10, 90, 35, function(val)
    local num = tonumber(val) or 35
    State.DomeTransparency = num / 100
end)

-- Вкладка: Visual (FPS Boost)
local SettingsTab = Hub:CreateTab({EN = "Visual", RU = "Визуал"})

SettingsTab:AddSection({EN = "Performance & FPS", RU = "Производительность и FPS"})

SettingsTab:AddButton({EN = "Unlock FPS (Max)", RU = "Снять лимит FPS (Максимум)"}, function()
    if setfpscap then
        setfpscap(9999)
        print("[Hub] FPS Unlocked successfully!")
    else
        warn("[Hub] setfpscap is not supported by your executor.")
    end
end)

SettingsTab:AddToggle({EN = "FPS Booster (Remove Effects)", RU = "Буст FPS (Убрать эффекты)"}, "FPSBoost", false, function(state)
    State.FPSBoost = state
    if state then
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 999999
        for _, v in ipairs(Lighting:GetChildren()) do
            if v:IsA("PostEffect") then
                v.Enabled = false
            elseif v:IsA("Sky") then
                v:Destroy()
            end
        end
        for _, v in ipairs(Workspace:GetDescendants()) do
            if v.Name ~= "BladeBallVisualDome" then
                if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles") then
                    v.Enabled = false
                elseif v:IsA("BasePart") then
                    v.Material = Enum.Material.SmoothPlastic
                    v.CastShadow = false
                end
            end
        end
        print("[Hub] FPS Booster enabled!")
    else
        Lighting.GlobalShadows = true
        print("[Hub] FPS Booster disabled.")
    end
end)

-- Вкладка: Social (Социальные сети)
local SocialTab = Hub:CreateTab({EN = "Social", RU = "Социальные сети"})

SocialTab:AddSection({EN = "Community Links", RU = "Ссылки на сообщество"})

SocialTab:AddLabel({
    EN = "Join our Telegram channel https://t.me/BloxyScripts", 
    RU = "Подписывайтесь на наш Telegram-канал https://t.me/BloxyScripts"
})

SocialTab:AddButton({EN = "Copy Telegram Link", RU = "Скопировать ссылку на Telegram"}, function()
    local success = pcall(function()
        setclipboard("https://t.me/BloxyScripts")
    end)
    
    if success then
        print("[Hub] Telegram link copied to clipboard!")
    else
        warn("[Hub] setclipboard is not supported by your executor.")
    end
end)