-- Подключение фреймворка с GitHub (как в документации)
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/TheBloxyScripts/BloxyScripts/main/main.lua"))()

-- Создание главного окна (как в документации)
local Window = Library:CreateWindow({
    Name = "BloxyScripts | Tower of Hell",
    LoadingTitle = "Загрузка башни...",
    LoadingSubtitle = "by TheBloxyScripts",
    FolderName = "BloxyConfigs"
})

-- Безопасный доступ для скриптов (как в документации)
local Hub = Window or getgenv().CustomHub
if not Hub then
    warn("Ошибка: Главный фреймворк не инициализирован!")
    return
end

-- Сервисы и игроки
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- Переменные состояний
local noclipActive = false
local infJumpActive = false
local flyActive = false
local flySpeed = 50
local ctrlTpEnabled = false
local noclipConnection = nil
local flyConnection = nil

-- Функция NoClip
local function updateNoClip()
    if noclipActive and LocalPlayer.Character then
        for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
end

-- Создание вкладок (по документации)
local MainTab = Window:CreateTab({EN = "Main", RU = "Главная"})
local PlayerTab = Window:CreateTab({EN = "Player", RU = "Игрок"})
local MiscTab = Window:CreateTab({EN = "Misc / Gear", RU = "Разное"})

-- ==================== MAIN TAB ====================
MainTab:AddSection({EN = "Tower Automation", RU = "Автоматизация башни"})

-- 1. Instant Win (Телепорт на самый верх к финишу)
MainTab:AddButton({EN = "Instant Win (To Top)", RU = "Мгновенная победа (Наверх)"}, function()
    local character = LocalPlayer.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        local tower = workspace:FindFirstChild("Tower")
        if tower and tower:FindFirstChild("sections") then
            -- Ищем финишную платформу или ParticleBrick на верхушке башни
            local topPart = nil
            for _, desc in ipairs(tower:GetDescendants()) do
                if desc.Name == "ParticleBrick" or desc.Name == "Finish" or desc.Name == "Glitch" then
                    topPart = desc
                    break
                end
            end
            if topPart and topPart:IsA("BasePart") then
                character.HumanoidRootPart.CFrame = topPart.CFrame + Vector3.new(0, 5, 0)
                print("[ToH]: Телепорт к финишу успешен!")
            else
                -- Универсальный подъем наверх по высоте (если топка не найдена)
                character.HumanoidRootPart.CFrame = CFrame.new(0, 350, 0)
            end
        end
    end
end)

-- 2. Godmode (Защита от смерти)
MainTab:AddToggle({EN = "Godmode (Anti-Death)", RU = "Режим бога (Бессмертие)"}, "GodmodeKey", false, function(state)
    local character = LocalPlayer.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            if state then
                humanoid.MaxHealth = math.huge
                humanoid.Health = math.huge
            else
                humanoid.MaxHealth = 100
                humanoid.Health = 100
            end
        end
    end
end)

-- 3. NoClip
MainTab:AddToggle({EN = "NoClip (Walk through walls)", RU = "NoClip (Сквозь стены)"}, "NoClipKey", false, function(state)
    noclipActive = state
    if state then
        if not noclipConnection then
            noclipConnection = RunService.Stepped:Connect(updateNoClip)
        end
    else
        if noclipConnection then
            noclipConnection:Disconnect()
            noclipConnection = nil
        end
    end
end)

-- 4. Control TP (Клик мышей с Ctrl)
MainTab:AddToggle({EN = "Ctrl + Click Teleport", RU = "Телепорт по клику (Ctrl)"}, "CtrlTpKey", false, function(state)
    ctrlTpEnabled = state
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and ctrlTpEnabled and input.UserInputType == Enum.UserInputType.MouseButton1 then
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then
            local mouse = LocalPlayer:GetMouse()
            if mouse.Target and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3, 0))
            end
        end
    end
end)


-- ==================== PLAYER TAB ====================
PlayerTab:AddSection({EN = "Movement & Physics", RU = "Физика и движение"})

-- 5. Infinite Jump
PlayerTab:AddToggle({EN = "Infinite Jump", RU = "Бесконечный прыжок"}, "InfJumpKey", false, function(state)
    infJumpActive = state
end)

UserInputService.JumpRequest:Connect(function()
    if infJumpActive and LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

-- 6. Fly / Float
PlayerTab:AddToggle({EN = "Fly / Float Mode", RU = "Полет / Зависание"}, "FlyKey", false, function(state)
    flyActive = state
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end
    
    local rootPart = character.HumanoidRootPart
    if flyActive then
        local bv = Instance.new("BodyVelocity")
        bv.Name = "ToHFlyVelocity"
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Velocity = Vector3.new(0, 0, 0)
        bv.Parent = rootPart
        
        flyConnection = RunService.RenderStepped:Connect(function()
            if not flyActive then return end
            local cam = workspace.CurrentCamera
            local moveDir = Vector3.new(0,0,0)
            
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + cam.CoordinateFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - cam.CoordinateFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - cam.CoordinateFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + cam.CoordinateFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0,1,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir = moveDir - Vector3.new(0,1,0) end
            
            bv.Velocity = moveDir * flySpeed
        end)
    else
        if flyConnection then flyConnection:Disconnect() flyConnection = nil end
        if rootPart:FindFirstChild("ToHFlyVelocity") then rootPart.ToHFlyVelocity:Destroy() end
    end
end)

-- 7. WalkSpeed Slider
PlayerTab:AddSlider({EN = "WalkSpeed", RU = "Скорость бега"}, "SpeedKey", 16, 150, 16, function(value)
    local character = LocalPlayer.Character
    if character and character:FindFirstChildOfClass("Humanoid") then
        character:FindFirstChildOfClass("Humanoid").WalkSpeed = value
    end
end)

-- 8. JumpPower Slider
PlayerTab:AddSlider({EN = "JumpPower", RU = "Высота прыжка"}, "JumpKey", 50, 300, 50, function(value)
    local character = LocalPlayer.Character
    if character and character:FindFirstChildOfClass("Humanoid") then
        local hum = character:FindFirstChildOfClass("Humanoid")
        hum.UseJumpPower = true
        hum.JumpPower = value
    end
end)


-- ==================== MISC / GEAR TAB ====================
MiscTab:AddSection({EN = "Gear & Items", RU = "Инвентарь и снаряжение"})

-- 9. Gear Acquisition (Выдача снаряжения)
MiscTab:AddButton({EN = "Give Coil (Speed/Gravity)", RU = "Выдать Коготь (Скорость/Гравитация)"}, function()
    -- Поиск ковров/снаряжения в игре или серверах
    for _, item in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
        if item:IsA("Tool") and (item.Name:lower():find("coil") or item.Name:lower():find("gravity")) then
            item:Clone().Parent = LocalPlayer.Backpack
        end
    end
    print("[ToH]: Попытка выдать снаряжение из хранилища игры.")
end)

MiscTab:AddLabel({EN = "Status: Script Loaded Successfully", RU = "Статус: Скрипт успешно загружен"})
