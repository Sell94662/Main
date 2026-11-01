-- Подключение фреймворка с GitHub (как в документации)
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/TheBloxyScripts/BloxyScripts/main/main.lua"))()

-- Создание главного окна (как в документации)
local Window = Library:CreateWindow({
    Name = "BloxyScripts | Hub",
    LoadingTitle = "Загрузка модулей...",
    LoadingSubtitle = "by TheBloxyScripts",
    FolderName = "BloxyConfigs"
})

-- Безопасный доступ для скриптов (как в документации)
local Hub = Window or getgenv().CustomHub
if not Hub then
    warn("Ошибка: Главный фреймворк не инициализирован!")
    return
end

-- Сервисы
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- Координаты старта и финального сундука
local START_POSITION = Vector3.new(41.48, -12.09, -35.71)
local CHEST_POSITION = Vector3.new(0, 50, 9550)

-- Переменные
local autoFarmActive = false
local flightSpeed = 150
local farmThread = nil
local noclipConnection = nil

-- Функция NoClip (чтобы не упираться в стены)
local function enableNoClip()
    if noclipConnection then return end
    noclipConnection = RunService.Stepped:Connect(function()
        if autoFarmActive and LocalPlayer.Character then
            for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
    end)
end

local function disableNoClip()
    if noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end
end

-- Основной цикл автофарма
local function startFarmLoop()
    enableNoClip()

    while autoFarmActive do
        task.wait(0.5)

        local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        local rootPart = character:WaitForChild("HumanoidRootPart", 5)
        local humanoid = character:WaitForChild("Humanoid", 5)

        if rootPart and humanoid and humanoid.Health > 0 then
            -- 1. Телепортация на стартовые координаты
            rootPart.CFrame = CFrame.new(START_POSITION)
            rootPart.AssemblyLinearVelocity = Vector3.zero
            task.wait(0.5)

            -- 2. Взлет на высоту +10 от точки старта
            local flyHeight = START_POSITION.Y + 10
            local highStartPos = Vector3.new(START_POSITION.X, flyHeight, START_POSITION.Z)
            rootPart.CFrame = CFrame.new(highStartPos)

            local targetFlightPos = Vector3.new(CHEST_POSITION.X, flyHeight, CHEST_POSITION.Z)

            -- 3. Полет к сундуку
            while autoFarmActive and humanoid.Health > 0 and (rootPart.Position - targetFlightPos).Magnitude > 12 do
                local dt = RunService.Heartbeat:Wait()
                local direction = (targetFlightPos - rootPart.Position).Unit
                
                rootPart.CFrame = rootPart.CFrame + (direction * (flightSpeed * dt))
                rootPart.AssemblyLinearVelocity = Vector3.zero
                rootPart.AssemblyAngularVelocity = Vector3.zero
            end

            -- 4. Точный залет в сундук и ожидание награды
            if autoFarmActive and humanoid.Health > 0 then
                rootPart.CFrame = CFrame.new(CHEST_POSITION)
                rootPart.AssemblyLinearVelocity = Vector3.zero
                
                -- Ждем, пока игра засчитает сундук
                task.wait(2.5)
                
                -- 5. Ресет для возврата на базу
                humanoid.Health = 0
                
                LocalPlayer.CharacterAdded:Wait()
                task.wait(2)
            end
        end
    end

    disableNoClip()
end

-- Создание вкладки (по документации)
local Tab = Window:CreateTab({EN = "Auto Farm", RU = "Автофарм"})

-- Раздел (по документации)
Tab:AddSection({EN = "Gold Farm Settings", RU = "Настройки фарма"})

-- Слайдер скорости (по документации)
Tab:AddSlider({EN = "Flight Speed", RU = "Скорость полета"}, "AutoFarmSpeedKey", 50, 300, 150, function(value)
    flightSpeed = value
end)

-- Переключатель (по документации) с надежным запуском через task.spawn
Tab:AddToggle({EN = "Enable Auto Farm", RU = "Включить автофарм"}, "AutoFarmToggleKey", false, function(state)
    autoFarmActive = state
    if state then
        print("Автофарм включен")
        if not farmThread or coroutine.status(farmThread) == "dead" then
            farmThread = task.spawn(startFarmLoop)
        end
    else
        disableNoClip()
        print("Автофарм выключен")
    end
end)

-- Статическая метка (по документации)
Tab:AddLabel({EN = "Status: Active", RU = "Статус: Активен"})
