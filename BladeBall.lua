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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Stats = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer

-- State & Settings
local State = {
    AutoParry = false,
    BaseParryDistance = 30,
    Visualizer = false,
    DomeMaterialIndex = 4,
    DomeColorIndex = 2,
    DomeTransparency = 0.35,
    FPSBoost = false,
    AutoFarm = false,
}

local ColorsList = {
    {Name = "Green", Color = Color3.fromRGB(0, 255, 120)},
    {Name = "Cyan", Color = Color3.fromRGB(0, 220, 255)},
    {Name = "Blue", Color = Color3.fromRGB(50, 120, 255)},
    {Name = "Purple", Color = Color3.fromRGB(180, 50, 255)},
    {Name = "Gold", Color = Color3.fromRGB(255, 215, 0)},
    {Name = "White", Color = Color3.fromRGB(255, 255, 255)}
}

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

local function GetParryRemote()
    local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage:FindFirstChild("Packages")
    local ParryEvent = ReplicatedStorage:FindFirstChild("ParryButtonPress", true) 
        or (remotesFolder and remotesFolder:FindFirstChild("ParryButtonPress", true))
    return ParryEvent
end

local function TriggerParry()
    local remote = GetParryRemote()
    if remote and remote:IsA("RemoteEvent") then
        remote:FireServer()
    else
        local vim = game:GetService("VirtualInputManager")
        vim:SendKeyEvent(true, Enum.KeyCode.F, false, nil)
        vim:SendKeyEvent(false, Enum.KeyCode.F, false, nil)
    end
end

-- Ультра-быстрое авто-паррирование с жесткой проверкой цели (Target)
local ParryConnection = nil
local lastParryTick = 0

local function StartAutoParry()
    if ParryConnection then ParryConnection:Disconnect() end
    ParryConnection = RunService.Heartbeat:Connect(function()
        if not State.AutoParry then return end
        
        local ball = GetBall()
        local root = GetRootPart(LocalPlayer)
        if not ball or not root then return end
        
        local dist = (ball.Position - root.Position).Magnitude
        
        -- ЖЕСТКАЯ ПРОВЕРКА ЦЕЛИ: Мяч должен быть направлен именно на нас
        local targetAttr = ball:GetAttribute("target") or ball:GetAttribute("Target")
        local isTargetingMe = false
        
        if targetAttr then
            if typeof(targetAttr) == "Instance" then
                isTargetingMe = (targetAttr == LocalPlayer or targetAttr == LocalPlayer.Character)
            elseif typeof(targetAttr) == "string" then
                isTargetingMe = (targetAttr == LocalPlayer.Name)
            end
        else
            -- Запасной векторный метод, если атрибут скрыт: мяч летит в нашу сторону (dot > 0.6)
            local velocity = ball.AssemblyLinearVelocity
            if velocity.Magnitude > 0 then
                local dirToPlayer = (root.Position - ball.Position).Unit
                local ballDir = velocity.Unit
                local dot = ballDir:Dot(dirToPlayer)
                isTargetingMe = (dot > 0.65)
            end
        end
        
        -- Срабатываем строго если мяч летит в нашу сторону и вошел в зону досягаемости
        if dist <= State.BaseParryDistance and isTargetingMe then
            local currentTime = tick()
            if currentTime - lastParryTick > 0.08 then
                lastParryTick = currentTime
                TriggerParry()
            end
        end
    end)
end

-- Автофарм
RunService.RenderStepped:Connect(function()
    if not State.AutoFarm then return end
    
    local ball = GetBall()
    local root = GetRootPart(LocalPlayer)
    local humanoid = GetHumanoid(LocalPlayer)
    if not ball or not root or not humanoid then return end
    
    local dist = (ball.Position - root.Position).Magnitude
    if dist > 160 then return end
    
    if dist < 17 then
        local escapeDir = (root.Position - ball.Position) * Vector3.new(1, 0, 1)
        if escapeDir.Magnitude > 0 then escapeDir = escapeDir.Unit else escapeDir = Vector3.new(1, 0, 0) end
        humanoid:MoveTo(ball.Position + (escapeDir * 16))
    elseif dist > 20 then
        humanoid:MoveTo(ball.Position + Vector3.new(0, 0, 5))
    end
end)

-- Создание купола визуализации
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
    if DomePart then DomePart:Destroy() DomePart = nil end
end

RunService.RenderStepped:Connect(function()
    if not State.Visualizer then RemoveDome() return end
    if not DomePart then CreateDome() end
    
    local root = GetRootPart(LocalPlayer)
    if not root then return end
    
    local diameter = State.BaseParryDistance * 2
    DomePart.Size = Vector3.new(diameter, diameter, diameter)
    DomePart.CFrame = root.CFrame
    
    local currentMat = MaterialsList[State.DomeMaterialIndex]
    if currentMat then DomePart.Material = currentMat.Material end
    
    local ball = GetBall()
    if ball and (ball.Position - root.Position).Magnitude <= State.BaseParryDistance then
        DomePart.Color = Color3.fromRGB(255, 50, 50)
        DomePart.Transparency = math.clamp(State.DomeTransparency - 0.15, 0.1, 0.8)
    else
        local currentCol = ColorsList[State.DomeColorIndex]
        if currentCol then DomePart.Color = currentCol.Color end
        DomePart.Transparency = State.DomeTransparency
    end
end)

-- Интерфейс
local CombatTab = Hub:CreateTab({EN = "Combat", RU = "Бой"})

CombatTab:AddSection({EN = "Instant Parry", RU = "Aвто-паррирование"})

CombatTab:AddToggle({EN = "Auto Parry (Instant)", RU = "Авто-паррирование (Мгновенное)"}, "AutoParry", false, function(s) 
    State.AutoParry = s 
    if s then StartAutoParry() end 
end)

CombatTab:AddToggle({EN = "Legit AutoFarm (Smart Movement)", RU = "Автофарм (Умное движение)"}, "AutoFarm", false, function(s)
    State.AutoFarm = s
end)

CombatTab:AddSlider({EN = "Parry Distance", RU = "Дистанция отбивания"}, "BaseParryDistance", 10, 50, 30, function(val) 
    State.BaseParryDistance = val 
end)

CombatTab:AddSection({EN = "Dome Customization", RU = "Настройка купола"})
CombatTab:AddToggle({EN = "Enable Dome Visualizer", RU = "Включить купол"}, "Visualizer", false, function(s) State.Visualizer = s end)
CombatTab:AddButton({EN = "Next Color", RU = "Следующий цвет"}, function()
    State.DomeColorIndex = State.DomeColorIndex + 1
    if State.DomeColorIndex > #ColorsList then State.DomeColorIndex = 1 end
end)
CombatTab:AddButton({EN = "Next Material", RU = "Следующий материал"}, function()
    State.DomeMaterialIndex = State.DomeMaterialIndex + 1
    if State.DomeMaterialIndex > #MaterialsList then State.DomeMaterialIndex = 1 end
end)

local SettingsTab = Hub:CreateTab({EN = "Visual", RU = "Визуал"})
SettingsTab:AddButton({EN = "Unlock FPS (Max)", RU = "Снять лимит FPS (Максимум)"}, function()
    pcall(function() setfpscap(9999) end)
end)
SettingsTab:AddToggle({EN = "Safe FPS Booster", RU = "Безопасный буст FPS"}, "FPSBoost", false, function(state)
    Lighting.GlobalShadows = not state
    Lighting.FogEnd = state and 999999 or 100000
end)

local SocialTab = Hub:CreateTab({EN = "Social", RU = "Социальные сети"})
SocialTab:AddLabel({EN = "Join our Telegram channel https://t.me/BloxyScripts", RU = "Подписывайтесь на наш Telegram-канал https://t.me/BloxyScripts"})
