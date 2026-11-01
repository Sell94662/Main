-- Безопасная загрузка фреймворка с проверкой HTTP 404
local Success, Library = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/TheBloxyScripts/BloxyScripts/main/main.lua"))()
end)

if not Success or not Library then
    warn("[BloxyScripts Error]: Ошибка 404! Проверь правильность ссылки на main.lua в твоем GitHub репозитории.")
    return
end

-- Создание главного окна
local Window = Library:CreateWindow({
    Name = "BloxyScripts | BABFT AutoFarm",
    LoadingTitle = "Загрузка автофарма...",
    LoadingSubtitle = "by TheBloxyScripts",
    FolderName = "BloxyConfigs"
})

local Hub = Window or getgenv().CustomHub
if not Hub then
    warn("[BloxyScripts Error]: Главный фреймворк не инициализирован!")
    return
end

-- Основные сервисы
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- Координаты старта и финального сундука (BABFT)
local START_POSITION = Vector3.new(41.48, -12.09, -35.71)
local CHEST_POSITION = Vector3.new(0, 50, 9550)

-- Переменные состояния
local autoFarmActive = false
local flightSpeed = 150
local farmThread = nil
local noclipConnection = nil

-- Функция NoClip (прохождение сквозь стены и острова)
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

-- Функция выполнения цикла автофарма
local function startFarmLoop()
    enableNoClip()

    while autoFarmActive do
        task.wait(0.5)

        local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        local rootPart = character:WaitForChild("HumanoidRootPart", 5)
        local humanoid = character:WaitForChild("Humanoid", 5)

        if rootPart and humanoid and humanoid.Health > 0 then
            -- 1. Телепортация на твои координаты старта
            rootPart.CFrame = CFrame.new(START_POSITION)
            rootPart.AssemblyLinearVelocity = Vector3.zero
            task.wait(0.5)

            -- 2. Взлет на высоту +10 относительно точки старта
            local flyHeight = START_POSITION.Y + 10
            local highStartPos = Vector3.new(START_POSITION.X, flyHeight, START_POSITION.Z)
            rootPart.CFrame = CFrame.new(highStartPos)

            local targetFlightPos = Vector3.new(CHEST_POSITION.X, flyHeight, CHEST_POSITION.Z)

            -- 3. Полный полет к сундуку на нужной высоте
            while autoFarmActive and humanoid.Health > 0 and (rootPart.Position - targetFlightPos).Magnitude > 12 do
                local dt = RunService.Heartbeat:Wait()
                local direction = (targetFlightPos - rootPart.Position).Unit
                
                rootPart.CFrame = rootPart.CFrame + (direction * (flightSpeed * dt))
                rootPart.AssemblyLinearVelocity = Vector3.zero
                rootPart.AssemblyAngularVelocity = Vector3.zero
            end

            -- 4. Касание сундука и ожидание начисления золота
            if autoFarmActive and humanoid.Health > 0 then
                rootPart.CFrame = CFrame.new(CHEST_POSITION)
                rootPart.AssemblyLinearVelocity = Vector3.zero
                
                -- Ждем 2.5 секунды, чтобы игра точно засчитала сундук
                task.wait(2.5)
                
                -- 5. Ресет персонажа для возврата на базу (только после получения)
                humanoid.Health = 0
                
                -- Ожидание респавна
                LocalPlayer.CharacterAdded:Wait()
                task.wait(2)
            end
        end
    end

    disableNoClip()
end

-- Создание вкладки управления
local FarmTab = Window:CreateTab({EN = "Auto Farm", RU = "Автофарм"})

FarmTab:AddSection({EN = "Gold Farm Settings", RU = "Настройки фарма золота"})

FarmTab:AddSlider({EN = "Flight Speed", RU = "Скорость погоня"}, "AutoFarmSpeedKey", 50, 300, 150, function(value)
    flightSpeed = value
end)

FarmTab:AddToggle({EN = "Enable Auto Farm", RU = "Включить автофарм"}, "AutoFarmToggleKey", false, function(state)
    autoFarmActive = state
    
    if autoFarmActive then
        print("[AutoFarm]: Запущен!")
        if not farmThread or coroutine.status(farmThread) == "dead" then
            farmThread = task.spawn(startFarmLoop)
        end
    else
        disableNoClip()
        print("[AutoFarm]: Остановлен.")
    end
end)

FarmTab:AddLabel({EN = "Status: Working Base + NoClip", RU = "Статус: Работает на твоей базе"})
