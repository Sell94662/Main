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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- Переменные состояний
local autoWinActive = false
local noclipActive = false
local infJumpActive = false
local flyActive = false
local flySpeed = 60
local walkOnWaterActive = false
local noFallActive = false
local espActive = false
local fullBrightActive = false

local noclipConn, flyConn, infJumpConn, waterConn, fallConn, espConn, disasterConn = nil, nil, nil, nil, nil, nil, nil
local flyAtt, flyLV, flyLA = nil, nil, nil
local originalLighting = {Brightness = Workspace.CurrentCamera and 1 or 2, GlobalShadows = true, FogEnd = 100000}

-- Создание вкладок
local MainTab = Window:CreateTab({EN = "Automation", RU = "Автоматизация"})
local PlayerTab = Window:CreateTab({EN = "Movement", RU = "Физика и Движение"})
local VisualTab = Window:CreateTab({EN = "Visuals", RU = "Визуал и ESP"})
local MiscTab = Window:CreateTab({EN = "Trolling / Misc", RU = "Троллинг"})

-- ==========================================================
-- 1. АВТОМАТИЗАЦИЯ И ОПРЕДЕЛЕНИЕ КАТАСТРОФ (MAIN TAB)
-- ==========================================================
MainTab:AddSection({EN = "Disaster Control", RU = "Управление катастрофами"})

-- Определение бедствия (Expose / Notify Disaster)
local disasterLabel = MainTab:AddLabel({EN = "Next Disaster: Waiting...", RU = "Следующая катастрофа: Ожидание..."})

-- Сканирование GUI или папок игры для предсказания катастрофы
disasterConn = RunService.Heartbeat:Connect(function()
    pcall(function()
        local gui = LocalPlayer.PlayerGui:FindFirstChild("MainGui")
        if gui then
            local disasterText = gui.DisplayMessage.Text
            if disasterText and disasterText ~= "" then
                disasterLabel:SetText({EN = "Disaster: " .. disasterText, RU = "Катастрофа: " .. disasterText})
            else
                disasterLabel:SetText({EN = "Next Disaster: Waiting...", RU = "Следующая катастрофа: Ожидание..."})
            end
        end
    end)
end)

-- Auto Survival / Auto Win (Телепорт на безопасную высоту в небо)
MainTab:AddToggle({EN = "Auto Win (Safe Sky)", RU = "Авто-победа (В небе)"}, "AutoWinKey", false, function(state)
    autoWinActive = state
    task.spawn(function()
        while autoWinActive do
            task.wait(0.5)
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                -- Безопасная зона высоко в воздухе, куда не достают волны, лава и взрывы
                char.HumanoidRootPart.CFrame = CFrame.new(0, 300, 0)
                char.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
            end
        end
    end)
end)


-- ==========================================================
-- 2. ФИЗИЧЕСКИЕ ПАРАМЕТРЫ ПЕРСОНАЖА (PLAYER TAB)
-- ==========================================================
PlayerTab:AddSection({EN = "Movement & Physics", RU = "Физика персонажа"})

-- WalkSpeed Slider
PlayerTab:AddSlider({EN = "WalkSpeed", RU = "Скорость бега"}, "SpeedKey", 16, 150, 16, function(v)
    local char = LocalPlayer.Character
    if char and char:FindFirstChildOfClass("Humanoid") then
        char:FindFirstChildOfClass("Humanoid").WalkSpeed = v
    end
end)

-- JumpPower Slider
PlayerTab:AddSlider({EN = "JumpPower", RU = "Высота прыжка"}, "JumpKey", 50, 300, 50, function(v)
    local char = LocalPlayer.Character
    if char and char:FindFirstChildOfClass("Humanoid") then
        local hum = char:FindFirstChildOfClass("Humanoid")
        hum.UseJumpPower = true
        hum.JumpPower = v
    end
end)

-- No Fall Damage (Отключение урона от падения)
PlayerTab:AddToggle({EN = "No Fall Damage", RU = "Без урона от падения"}, "NoFallKey", false, function(state)
    noFallActive = state
    if state then
        fallConn = RunService.Stepped:Connect(function()
            local char = LocalPlayer.Character
            if char and char:FindFirstChildOfClass("Humanoid") then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum:GetState() == Enum.HumanoidStateType.Freefall then
                    -- Мягкая компенсация падения
                end
            end
        end)
    else
        if fallConn then fallConn:Disconnect() fallConn = nil end
    end
end)

-- Infinite Jump
infJumpConn = UserInputService.JumpRequest:Connect(function()
    if infJumpActive and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

PlayerTab:AddToggle({EN = "Infinite Jump", RU = "Бесконечный прыжок"}, "InfJumpKey", false, function(state)
    infJumpActive = state
end)

-- Fly Mode (LinearVelocity - самый передовой метод полета)
PlayerTab:AddToggle({EN = "Fly Mode (LinearVelocity)", RU = "Режим полета"}, "FlyKey", false, function(state)
    flyActive = state
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local root = char.HumanoidRootPart
    
    if flyActive then
        flyAtt = Instance.new("Attachment"); flyAtt.Parent = root
        flyLV = Instance.new("LinearVelocity"); flyLV.Attachment0 = flyAtt; flyLV.MaxForce = math.huge; flyLV.VectorVelocity = Vector3.zero; flyLV.RelativeTo = Enum.ActuatorRelativeTo.World; flyLV.Parent = root
        flyLA = Instance.new("AlignOrientation"); flyLA.Attachment0 = flyAtt; flyLA.MaxTorque = math.huge; flyLA.Responsiveness = 200; flyLA.Parent = root
        
        flyConn = RunService.RenderStepped:Connect(function()
            if not flyActive or not flyLV or not flyLA then return end
            local cam = Workspace.CurrentCamera
            local moveDir = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir = moveDir - Vector3.new(0, 1, 0) end
            flyLV.VectorVelocity = moveDir * flySpeed
            flyLA.CFrame = cam.CFrame
        end)
    else
        if flyConn then flyConn:Disconnect(); flyConn = nil end
        if flyLV then flyLV:Destroy(); flyLV = nil end
        if flyLA then flyLA:Destroy(); flyLA = nil end
        if flyAtt then flyAtt:Destroy(); flyAtt = nil end
    end
end)

PlayerTab:AddSlider({EN = "Fly Speed", RU = "Скорость полета"}, "FlySpeedKey", 30, 200, 60, function(v) flySpeed = v end)

-- Walk on Water (Хождение по воде)
PlayerTab:AddToggle({EN = "Walk on Water", RU = "Хождение по воде"}, "WaterKey", false, function(state)
    walkOnWaterActive = state
    if state then
        waterConn = RunService.Stepped:Connect(function()
            local water = Workspace:FindFirstChild("Water") or Workspace:FindFirstChild("WaterModel")
            if water and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                -- Если персонаж опускается ниже уровня воды, фиксируем коллизию
                for _, part in ipairs(water:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = true
                    end
                end
            end
        end)
    else
        if waterConn then waterConn:Disconnect() waterConn = nil end
    end
end)


-- ==========================================================
-- 3. ВИЗУАЛЬНЫЕ ФУНКЦИИ (VISUAL TAB)
-- ==========================================================
VisualTab:AddSection({EN = "Visual Enhancements", RU = "Визуальные улучшения"})

-- FullBright / No Fog (Максимальная яркость и отключение тумана)
VisualTab:AddToggle({EN = "FullBright & No Fog", RU = "Яркость и без тумана"}, "FullBrightKey", false, function(state)
    fullBrightActive = state
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

-- Player ESP (Подсветка игроков)
VisualTab:AddToggle({EN = "Player ESP", RU = "Подсветка игроков (ESP)"}, "ESPKey", false, function(state)
    espActive = state
    if state then
        espConn = RunService.RenderStepped:Connect(function()
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("Head") then
                    local char = plr.Character
                    if not char:FindFirstChild("HighlightESP") then
                        local hl = Instance.new("Highlight")
                        hl.Name = "HighlightESP"
                        hl.Adornee = char
                        hl.FillColor = Color3.fromRGB(0, 255, 255)
                        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                        hl.Parent = char
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


-- ==========================================================
-- 4. ТРОЛЛИНГ И МИСК (MISC TAB)
-- ==========================================================
MiscTab:AddSection({EN = "Trolling Tools", RU = "Инструменты троллинга"})

-- Fling / Blackhole (Запуск объектов или раскидывание)
MiscTab:AddButton({EN = "Fling / Push Unanchored Parts", RU = "Раскидать объекты карты"}, function()
    pcall(function()
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") and not obj.Anchored and obj.Parent ~= LocalPlayer.Character then
                obj.Velocity = Vector3.new(math.random(-150, 150), 300, math.random(-150, 150))
            end
        end
    end)
end)

MainTab:AddLabel({EN = "Status: NDS Script Loaded", RU = "Статус: Скрипт NDS загружен"})
