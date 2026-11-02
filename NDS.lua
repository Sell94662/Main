-- Подключение фреймворка
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/TheBloxyScripts/BloxyScripts/main/main.lua"))()

local Window = Library:CreateWindow({
    Name = "BloxyScripts | Natural Disaster Survival",
    LoadingTitle = "Загрузка модулей NDS...",
    LoadingSubtitle = "by TheBloxyScripts",
    FolderName = "BloxyConfigs"
})

if not Window then
    warn("Ошибка: Главный фреймворк не инициализирован!")
    return
end

-- Сервисы
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- БАЗОВЫЙ ОБХОД АНТИ-ЧИТА (Anti-Kick)
pcall(function()
    local mt = getrawmetatable(game)
    local oldNamecall = mt.__namecall
    setreadonly(mt, false)
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if method == "Kick" then return end
        return oldNamecall(self, ...)
    end)
    setreadonly(mt, true)
end)

-- ==========================================================
-- НАСТРОЙКИ КООРДИНАТ
-- ==========================================================
local SAFE_POSITION = Vector3.new(-239.08, 179.78, 352.48)

-- ==========================================================
-- ПЕРЕМЕННЫЕ СОСТОЯНИЙ
-- ==========================================================
local autoWinActive = false
local infJumpActive = false
local flyActive = false
local flySpeed = 60
local espActive = false

local flyConn, espConn = nil, nil
local flyAtt, flyLV, flyLA = nil, nil, nil

-- ==========================================================
-- ВКЛАДКИ
-- ==========================================================
local MainTab = Window:CreateTab({EN = "Automation", RU = "Автоматизация"})
local PlayerTab = Window:CreateTab({EN = "Movement", RU = "Физика и Движение"})
local VisualTab = Window:CreateTab({EN = "Visuals", RU = "Визуал и ESP"})

-- ==========================================================
-- 1. АВТОМАТИЗАЦИЯ (MAIN TAB)
-- ==========================================================
MainTab:AddSection({EN = "Disaster Control", RU = "Управление катастрофами"})

local disasterLabel = MainTab:AddLabel({EN = "Next Disaster: Waiting...", RU = "Следующая катастрофа: Ожидание..."})

RunService.Heartbeat:Connect(function()
    pcall(function()
        local gui = LocalPlayer.PlayerGui:FindFirstChild("MainGui")
        if gui and gui:FindFirstChild("DisplayMessage") then
            local disasterText = gui.DisplayMessage.Text
            if disasterText and disasterText ~= "" then
                disasterLabel:SetText({EN = "Disaster: " .. disasterText, RU = "Катастрофа: " .. disasterText})
            else
                disasterLabel:SetText({EN = "Next Disaster: Waiting...", RU = "Следующая катастрофа: Ожидание..."})
            end
        end
    end)
end)

-- УМНЫЙ AUTO WIN (ТЕЛЕПОРТ В БЕЗОПАСНУЮ ЗОНУ)
MainTab:AddToggle({EN = "Auto Win (Safe Zone)", RU = "Авто-победа (Безопасная зона)"}, "AutoWinKey_V4", false, function(state)
    autoWinActive = state
    
    if state then
        task.spawn(function()
            while autoWinActive do
                task.wait(0.5)
                local char = LocalPlayer.Character
                
                if char and char:FindFirstChild("HumanoidRootPart") then
                    local hrp = char.HumanoidRootPart
                    local distance = (hrp.Position - SAFE_POSITION).Magnitude
                    
                    -- Если игрок находится дальше 25 стадов от безопасной точки (новый раунд или упал)
                    if distance > 25 then
                        hrp.CFrame = CFrame.new(SAFE_POSITION)
                        hrp.AssemblyLinearVelocity = Vector3.zero
                        hrp.AssemblyAngularVelocity = Vector3.zero
                    end
                end
            end
        end)
    end
end)

-- ==========================================================
-- 2. ФИЗИКА И ДВИЖЕНИЕ (PLAYER TAB)
-- ==========================================================
PlayerTab:AddSection({EN = "Movement & Physics", RU = "Физика персонажа"})

PlayerTab:AddSlider({EN = "WalkSpeed", RU = "Скорость бега"}, "SpeedKey_V4", 16, 150, 16, function(v)
    local char = LocalPlayer.Character
    if char and char:FindFirstChildOfClass("Humanoid") then
        char:FindFirstChildOfClass("Humanoid").WalkSpeed = v
    end
end)

PlayerTab:AddSlider({EN = "JumpPower", RU = "Высота прыжка"}, "JumpKey_V4", 50, 300, 50, function(v)
    local char = LocalPlayer.Character
    if char and char:FindFirstChildOfClass("Humanoid") then
        local hum = char:FindFirstChildOfClass("Humanoid")
        hum.UseJumpPower = true
        hum.JumpPower = v
    end
end)

PlayerTab:AddToggle({EN = "Infinite Jump", RU = "Бесконечный прыжок"}, "InfJumpKey_V4", false, function(state)
    infJumpActive = state
    if state then
        UserInputService.JumpRequest:Connect(function()
            if infJumpActive and LocalPlayer.Character then
                local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
            end
        end)
    end
end)

-- Fly Mode (Современный, с Lerp)
PlayerTab:AddToggle({EN = "Fly Mode (LinearVelocity)", RU = "Режим полета"}, "FlyKey_V4", false, function(state)
    flyActive = state
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end

    if flyActive then
        hum:ChangeState(Enum.HumanoidStateType.Physics)
        
        flyAtt = Instance.new("Attachment", root)
        flyLV = Instance.new("LinearVelocity", root)
        flyLV.Attachment0 = flyAtt
        flyLV.MaxForce = math.huge
        flyLV.VectorVelocity = Vector3.zero
        flyLV.RelativeTo = Enum.ActuatorRelativeTo.World
        
        flyLA = Instance.new("AlignOrientation", root)
        flyLA.Attachment0 = flyAtt
        flyLA.MaxTorque = math.huge
        flyLA.Responsiveness = 200
        
        local currentVelocity = Vector3.zero
        
        flyConn = RunService.RenderStepped:Connect(function(dt)
            if not flyActive or not flyLV or not flyLA then return end
            local cam = Workspace.CurrentCamera
            local moveDir = Vector3.zero
            
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir += cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir -= cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir -= cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir += cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir += Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir -= Vector3.new(0, 1, 0) end
            
            local targetVelocity = moveDir * flySpeed
            currentVelocity = currentVelocity:Lerp(targetVelocity, math.clamp(8 * dt, 0, 1))
            
            flyLV.VectorVelocity = currentVelocity
            flyLA.CFrame = cam.CFrame
        end)
    else
        if flyConn then flyConn:Disconnect() flyConn = nil end
        if flyLV then flyLV:Destroy() flyLV = nil end
        if flyLA then flyLA:Destroy() flyLA = nil end
        if flyAtt then flyAtt:Destroy() flyAtt = nil end
        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
    end
end)

PlayerTab:AddSlider({EN = "Fly Speed", RU = "Скорость полета"}, "FlySpeedKey_V4", 30, 200, 60, function(v) flySpeed = v end)

-- ==========================================================
-- 3. ВИЗУАЛЬНЫЕ ФУНКЦИИ (VISUAL TAB)
-- ==========================================================
VisualTab:AddSection({EN = "Visual Enhancements", RU = "Визуальные улучшения"})

VisualTab:AddToggle({EN = "FullBright & No Fog", RU = "Яркость и без тумана"}, "FullBrightKey_V4", false, function(state)
    local lighting = game:GetService("Lighting")
    if state then
        lighting.Brightness = 2
        lighting.ClockTime = 14
        lighting.FogEnd = 100000
        lighting.GlobalShadows = false
    else
        lighting.Brightness = 1
        lighting.FogEnd = 10000
        lighting.GlobalShadows = true
    end
end)

VisualTab:AddToggle({EN = "Player ESP", RU = "Подсветка игроков (ESP)"}, "ESPKey_V4", false, function(state)
    espActive = state
    if state then
        espConn = RunService.RenderStepped:Connect(function()
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("Head") then
                    if not plr.Character:FindFirstChild("HighlightESP") then
                        local hl = Instance.new("Highlight")
                        hl.Name = "HighlightESP"
                        hl.Adornee = plr.Character
                        hl.FillColor = Color3.fromRGB(0, 255, 255)
                        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                        hl.Parent = plr.Character
                    end
                end
            end
        end)
    else
        if espConn then espConn:Disconnect() espConn = nil end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr.Character and plr.Character:FindFirstChild("HighlightESP") then
                plr.Character.HighlightESP:Destroy()
            end
        end
    end
end)

MainTab:AddLabel({EN = "Status: NDS Script Loaded", RU = "Статус: Скрипт NDS загружен"})
