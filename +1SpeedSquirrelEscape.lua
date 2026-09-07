local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/TheBloxyScripts/BloxyScripts/main/main.lua"))()

local Window = Library:CreateWindow({
    Name = "BloxyScripts | +1 Speed Squirrel Escape",
    LoadingTitle = "Loading...",
    LoadingSubtitle = "by TheBloxyScripts (Telegram)",
    FolderName = "SpeedSimulatorConfigs"
})

local Hub = Window or getgenv().CustomHub
if not Hub then
    warn("Error: Main framework not initialized!")
    return
end

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

-- State & Settings
local State = {
    AutoFarm = false,
    AutoWin = false,
    WalkSpeedValue = 16,
    JumpPowerValue = 50,
    EnableWalkSpeed = false,
    EnableJumpPower = false,
    Fly = false,
    FlySpeed = 150,
    Noclip = false,
}

local function GetRootPart(plr)
    local char = plr and plr.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function GetHumanoid(plr)
    local char = plr and plr.Character
    return char and char:FindFirstChildWhichIsA("Humanoid")
end

-- Точный поиск беговой дорожки x1 Speed
local function FindTreadmillX1()
    local targetText = "x1"
    local foundParts = {}

    for _, obj in ipairs(Workspace:GetDescendants()) do
        local textStr = ""
        if obj:IsA("TextLabel") or obj:IsA("TextBox") then
            textStr = obj.Text:gsub("%s+", ""):lower()
        elseif obj:IsA("SurfaceGui") or obj:IsA("BillboardGui") then
            for _, child in ipairs(obj:GetDescendants()) do
                if child:IsA("TextLabel") then
                    textStr = child.Text:gsub("%s+", ""):lower()
                end
            end
        end
        
        if textStr ~= "" and (textStr == "x1" or textStr:find("x1speed") or textStr:find("x1 speed")) then
            local curr = obj.Parent
            while curr and curr ~= Workspace do
                if curr:IsA("BasePart") then
                    table.insert(foundParts, curr)
                    break
                elseif curr:IsA("Model") then
                    local p = curr:FindFirstChildWhichIsA("BasePart", true)
                    if p then
                        table.insert(foundParts, p)
                        break
                    end
                end
                curr = curr.Parent
            end
        end
    end
    
    if #foundParts > 0 then
        return foundParts[1]
    end
    
    return nil
end

-- 1. Автофарм (Телепорт строго на x1 дорожку)
local lastTreadmillPosition = nil
RunService.Heartbeat:Connect(function(dt)
    if not State.AutoFarm then 
        lastTreadmillPosition = nil
        return 
    end
    
    local root = GetRootPart(LocalPlayer)
    if not root then return end
    
    local targetTreadmill = FindTreadmillX1()
    if targetTreadmill then
        local targetCF = targetTreadmill.CFrame + Vector3.new(0, 3, 0)
        
        if lastTreadmillPosition ~= targetTreadmill.Position or (root.Position - targetCF.Position).Magnitude > 25 then
            lastTreadmillPosition = targetTreadmill.Position
            root.CFrame = targetCF
        else
            root.CFrame = targetCF
            root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        end
    end
end)

-- 2. Автовин (Телепорт по точным координатам финишной плиты)
local WinCFrame = CFrame.new(72511.2812, 457.839783, 7695.32568, 0.780868888, -0.615050256, 0.109348185, -0, 0.17504251, 0.984560847, -0.624695003, -0.768812954, 0.136685237)

task.spawn(function()
    while true do
        task.wait(1.5)
        if State.AutoWin then
            pcall(function()
                local root = GetRootPart(LocalPlayer)
                if not root then return end
                
                root.CFrame = WinCFrame
                root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            end)
        end
    end
end)

-- 3. Noclip
RunService.Stepped:Connect(function()
    if State.Noclip then
        local char = LocalPlayer.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
    end
end)

-- 4. Fly
RunService.RenderStepped:Connect(function()
    if not State.Fly then return end
    local char = LocalPlayer.Character
    local root = GetRootPart(LocalPlayer)
    local humanoid = GetHumanoid(LocalPlayer)
    if not char or not root or not humanoid then return end
    
    humanoid.PlatformStand = true
    local camera = Workspace.CurrentCamera
    local moveDir = Vector3.new()
    
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + camera.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - camera.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - camera.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + camera.CFrame.RightVector end
    
    root.AssemblyLinearVelocity = moveDir * State.FlySpeed
    root.CFrame = CFrame.new(root.Position, root.Position + camera.CFrame.LookVector)
end)

task.spawn(function()
    while true do
        task.wait(0.5)
        if not State.Fly then
            local humanoid = GetHumanoid(LocalPlayer)
            if humanoid and humanoid.PlatformStand then
                humanoid.PlatformStand = false
            end
        end
    end
end)

-- 5. Статы персонажа
RunService.Heartbeat:Connect(function()
    local humanoid = GetHumanoid(LocalPlayer)
    if humanoid then
        if State.EnableWalkSpeed then
            humanoid.WalkSpeed = State.WalkSpeedValue
        end
        if State.EnableJumpPower then
            humanoid.UseJumpPower = true
            humanoid.JumpPower = State.JumpPowerValue
        end
    end
end)

-- ==================== ИНТЕРФЕЙС ====================

local FarmTab = Hub:CreateTab({EN = "Auto Farm", RU = "Автофарм"})

FarmTab:AddSection({EN = "Treadmill Training", RU = "Автотреин (x1 Speed)"})

FarmTab:AddToggle({EN = "Enable Auto Farm", RU = "Включить автофарм (x1 Speed)"}, "AutoFarmKey", false, function(state)
    State.AutoFarm = state
end)

FarmTab:AddSection({EN = "Auto Win", RU = "Авто-победа"})

FarmTab:AddToggle({EN = "Enable Auto Win (118Qa)", RU = "Включить авто-победу (118Qa)"}, "AutoWinKey", false, function(state)
    State.AutoWin = state
end)

-- Вкладка Misc
local MiscTab = Hub:CreateTab({EN = "Misc", RU = "Разное"})

MiscTab:AddSection({EN = "Movement & Physics", RU = "Передвижение и физика"})

MiscTab:AddToggle({EN = "Enable Fly", RU = "Включить полёт (Fly)"}, "FlyToggle", false, function(state)
    State.Fly = state
    local humanoid = GetHumanoid(LocalPlayer)
    if humanoid and not state then humanoid.PlatformStand = false end
end)

MiscTab:AddSlider({EN = "Fly Speed", RU = "Скорость полёта"}, "FlySpeedSetting", 20, 1000, 150, function(value)
    State.FlySpeed = value
end)

MiscTab:AddToggle({EN = "Enable Noclip", RU = "Включить Noclip (сквозь стены)"}, "NoclipToggle", false, function(state)
    State.Noclip = state
end)

MiscTab:AddSection({EN = "Player Stats", RU = "Характеристики игрока"})

MiscTab:AddToggle({EN = "Enable WalkSpeed", RU = "Включить скорость бега"}, "WSToggle", false, function(state)
    State.EnableWalkSpeed = state
end)

MiscTab:AddSlider({EN = "WalkSpeed", RU = "Скорость бега"}, "WalkSpeedSetting", 16, 500, 16, function(value)
    State.WalkSpeedValue = value
end)

MiscTab:AddToggle({EN = "Enable JumpPower", RU = "Включить силу прыжка"}, "JPToggle", false, function(state)
    State.EnableJumpPower = state
end)

MiscTab:AddSlider({EN = "JumpPower", RU = "Сила прыжка"}, "JumpPowerSetting", 50, 500, 50, function(value)
    State.JumpPowerValue = value
end)