-- ==========================================================
-- BloxyScripts Hub | Модуль АвтоФарм (Arch Flight Version)
-- ==========================================================

print("[BloxyScripts Hub] Загрузка модуля АвтоФарм...")

-- Защищённая загрузка фреймворка
local ok, Library = pcall(function()
    return loadstring(game:HttpGet(
        "https://raw.githubusercontent.com/TheBloxyScripts/BloxyScripts/main/main.lua"
    ))()
end)

if not ok or not Library then
    warn("[BloxyScripts Hub] ОШИБКА: Не удалось загрузить фреймворк!")
    return
end

-- Создание окна
local Window = Library:CreateWindow({
    Name = "BloxyScripts | Hub",
    LoadingTitle = "Загрузка модулей...",
    LoadingSubtitle = "by TheBloxyScripts",
    FolderName = "BloxyConfigs"
})

if not Window then return end

-- Сервисы
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- ==========================================================
-- КОНСТАНТЫ
-- ==========================================================
local START_POSITION = Vector3.new(41.48, -12.09, -35.71)

-- Твои точные координаты сундука
local CHEST_X = -46.42
local CHEST_Z = 9502.53
local CHEST_Y = -353.53 

local FLIGHT_ALTITUDE   = 500  -- Высота полета (Y), чтобы перелететь все стены
local CHEST_ZONE_RADIUS = 20   -- Радиус зоны, где начинаем снижаться
local TOUCH_DISTANCE    = 3    -- Отступ от сундука, чтобы не застрять

-- ==========================================================
-- СОСТОЯНИЕ
-- ==========================================================
local autoFarmActive   = false
local flightSpeed      = 300  -- Увеличил скорость для быстрого пролета
local dropSpeed        = 200  -- Скорость падения вниз
local chestYOffset     = 0     
local farmThread       = nil
local noclipConnection = nil

-- ==========================================================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ==========================================================
local function enableNoClip()
    if noclipConnection then return end
    noclipConnection = RunService.Stepped:Connect(function()
        if not autoFarmActive then return end
        local char = LocalPlayer.Character
        if not char then return end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end)
end

local function disableNoClip()
    if noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end
    local char = LocalPlayer.Character
    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
    end
end

local function getCharacter(timeout)
    timeout = timeout or 15
    local startTime = os.clock()
    while os.clock() - startTime < timeout do
        local char = LocalPlayer.Character
        if char then
            local root = char:FindFirstChild("HumanoidRootPart")
            local hum  = char:FindFirstChildOfClass("Humanoid")
            if root and hum and hum.Health > 0 then
                return char, root, hum
            end
        end
        task.wait(0.1)
    end
    return nil
end

-- ==========================================================
-- ОСНОВНОЙ ЦИКЛ АВТОФАРМА (МЕТОД АРКИ)
-- ==========================================================
local function startFarmLoop()
    enableNoClip()

    while autoFarmActive do
        local char, root, hum = getCharacter(15)

        if char then
            local currentChestY = CHEST_Y + chestYOffset
            local flightY = FLIGHT_ALTITUDE + chestYOffset

            -- 1) Телепорт на старт
            root.CFrame = CFrame.new(START_POSITION)
            task.wait(0.2)

            if not autoFarmActive then break end

            -- 2) ВЗЛЕТ В НЕБО (Арка: часть 1)
            local upTarget = Vector3.new(START_POSITION.X, flightY, START_POSITION.Z)
            while autoFarmActive do
                local r = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if not r then break end
                
                local dist = (upTarget - r.Position).Magnitude
                if dist <= 5 then break end

                local dt = RunService.Heartbeat:Wait()
                local dir = (upTarget - r.Position).Unit
                r.CFrame = r.CFrame + (dir * (flightSpeed * 1.5 * dt))
            end

            if not autoFarmActive then break end
            task.wait(0.1)

            -- 3) ПОЛЕТ ПО ПРЯМОЙ НАД КАРТОЙ (Арка: часть 2)
            local overTarget = Vector3.new(CHEST_X, flightY, CHEST_Z)
            while autoFarmActive do
                local r = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if not r then break end
                
                local dist = (overTarget - r.Position).Magnitude
                if dist <= CHEST_ZONE_RADIUS then break end

                local dt = RunService.Heartbeat:Wait()
                -- Двигаемся строго по горизонтали
                local dir = Vector3.new(overTarget.X - r.Position.X, 0, overTarget.Z - r.Position.Z).Unit
                r.CFrame = r.CFrame + (dir * (flightSpeed * dt))
                -- Жестко фиксируем высоту
                r.CFrame = CFrame.new(r.Position.X, flightY, r.Position.Z)
            end

            if not autoFarmActive then break end
            task.wait(0.1)

            -- 4) СПУСК ВНИЗ К СУНДУКУ (Арка: часть 3)
            local downTarget = Vector3.new(CHEST_X, currentChestY + TOUCH_DISTANCE, CHEST_Z)
            while autoFarmActive do
                local r = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if not r then break end
                
                local dist = (downTarget - r.Position).Magnitude
                if dist <= 3 then break end

                local dt = RunService.Heartbeat:Wait()
                local dir = (downTarget - r.Position).Unit
                r.CFrame = r.CFrame + (dir * (dropSpeed * dt))
            end

            if not autoFarmActive then break end

            -- 5) КАСАНИЕ И РЕСЕТ
            char, root, hum = getCharacter(5)
            if root and hum then
                root.CFrame = CFrame.new(CHEST_X, currentChestY + TOUCH_DISTANCE, CHEST_Z)
                task.wait(2.5) -- Ждем награду

                if hum and hum.Health > 0 then
                    hum.Health = 0
                end
                task.wait(2)
            end
        else
            task.wait(0.5)
        end
    end

    disableNoClip()
end

-- ==========================================================
-- UI
-- ==========================================================
local Tab = Window:CreateTab({ EN = "Auto Farm", RU = "Автофарм" }, 10)

Tab:AddSection({ EN = "Gold Farm Settings", RU = "Настройки фарма" })

Tab:AddSlider(
    { EN = "Flight Speed", RU = "Скорость полёта" },
    "AutoFarmSpeedKey",
    100, 500, 300,
    function(value) flightSpeed = value end
)

Tab:AddSlider(
    { EN = "Flight Altitude", RU = "Высота полета (Y)" },
    "FlightAltitudeKey",
    200, 1000, 500,
    function(value) FLIGHT_ALTITUDE = value end
)

Tab:AddSlider(
    { EN = "Chest Y Offset", RU = "Коррекция высоты сундука" },
    "ChestYOffsetKey",
    -20, 20, 0,
    function(value) chestYOffset = value end
)

Tab:AddToggle(
    { EN = "Enable Auto Farm", RU = "Включить автофарм" },
    "AutoFarmToggleKey",
    false,
    function(state)
        autoFarmActive = state

        if state then
            print("[BloxyScripts Hub] Автофарм ВКЛЮЧЕН")
            if farmThread and coroutine.status(farmThread) ~= "dead" then
                pcall(task.cancel, farmThread)
            end
            farmThread = task.spawn(startFarmLoop)
        else
            print("[BloxyScripts Hub] Автофарм ВЫКЛЮЧЕН")
            if farmThread and coroutine.status(farmThread) ~= "dead" then
                pcall(task.cancel, farmThread)
            end
            farmThread = nil
            disableNoClip()
        end
    end
)

local StatusLabel = Tab:AddLabel("Статус: ❌ Неактивен")
task.spawn(function()
    while task.wait(0.3) do
        if not StatusLabel or not StatusLabel.Parent then break end
        StatusLabel.Text = "Статус: " .. (autoFarmActive and "✅ Активен" or "❌ Неактивен")
    end
end)

Tab:AddSection({ EN = "Actions", RU = "Действия" })

Tab:AddButton({ EN = "Teleport to Start", RU = "Телепорт на старт" }, function()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        char.HumanoidRootPart.CFrame = CFrame.new(START_POSITION)
    end
end)

Tab:AddButton({ EN = "Teleport to Chest", RU = "Телепорт к сундуку" }, function()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local targetY = CHEST_Y + chestYOffset + 3
        char.HumanoidRootPart.CFrame = CFrame.new(CHEST_X, targetY, CHEST_Z)
    end
end)

Tab:AddButton({ EN = "Reset Character", RU = "Ресет персонажа" }, function()
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.Health = 0 end
    end
end)

print("[BloxyScripts Hub] Модуль АвтоФарм успешно загружен!")
