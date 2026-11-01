-- ==========================================================
-- BloxyScripts Hub | Модуль АвтоФарм
-- Работает с фреймворком TheBloxyScripts (твой main.lua)
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
    warn("Проверьте ссылку: https://raw.githubusercontent.com/TheBloxyScripts/BloxyScripts/main/main.lua")
    return
end

-- Создание окна хаба (параметры как у фреймворка)
local Window = Library:CreateWindow({
    Name = "BloxyScripts | Hub",
    LoadingTitle = "Загрузка модулей...",
    LoadingSubtitle = "by TheBloxyScripts",
    FolderName = "BloxyConfigs"
})

if not Window then
    warn("[BloxyScripts Hub] ОШИБКА: Окно не создано!")
    return
end

-- Сервисы
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- ==========================================================
-- КОНСТАНТЫ
-- ==========================================================
local START_POSITION    = Vector3.new(41.48, -12.09, -35.71)
local CHEST_POSITION    = Vector3.new(0, 50, 9550)
local FLY_HEIGHT_OFFSET = 50
local ARRIVE_DISTANCE   = 12
local CHEST_WAIT_TIME   = 2.5
local RESPAWN_WAIT_TIME = 2
local CHARACTER_TIMEOUT = 15

-- ==========================================================
-- СОСТОЯНИЕ
-- ==========================================================
local autoFarmActive   = false
local flightSpeed      = 150
local farmThread       = nil
local noclipConnection = nil

-- ==========================================================
-- NOCLIP
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
    -- Восстанавливаем коллизии
    local char = LocalPlayer.Character
    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
    end
end

-- ==========================================================
-- ВСПОМОГАТЕЛЬНЫЕ
-- ==========================================================
local function getCharacter(timeout)
    timeout = timeout or CHARACTER_TIMEOUT
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

local function freezeRoot(root)
    if not root then return end
    root.AssemblyLinearVelocity  = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
end

-- ==========================================================
-- ОСНОВНОЙ ЦИКЛ АВТОФАРМА
-- ==========================================================
local function startFarmLoop()
    enableNoClip()

    while autoFarmActive do
        local char, root, hum = getCharacter(CHARACTER_TIMEOUT)

        if char then
            -- 1) Телепорт на старт
            root.CFrame = CFrame.new(START_POSITION)
            freezeRoot(root)
            task.wait(0.5)

            if not autoFarmActive then break end

            -- 2) Подъём над стартом
            local flyHeight = START_POSITION.Y + FLY_HEIGHT_OFFSET
            root.CFrame = CFrame.new(Vector3.new(START_POSITION.X, flyHeight, START_POSITION.Z))
            freezeRoot(root)

            local targetFlightPos = Vector3.new(CHEST_POSITION.X, flyHeight, CHEST_POSITION.Z)

            -- 3) Полёт к сундуку
            while autoFarmActive do
                local c = LocalPlayer.Character
                if not c then break end
                local r = c:FindFirstChild("HumanoidRootPart")
                local h = c:FindFirstChildOfClass("Humanoid")
                if not r or not h or h.Health <= 0 then break end
                if (r.Position - targetFlightPos).Magnitude <= ARRIVE_DISTANCE then break end

                local dt = RunService.Heartbeat:Wait()
                local delta = targetFlightPos - r.Position
                if delta.Magnitude > 0.01 then
                    r.CFrame = r.CFrame + (delta.Unit * (flightSpeed * dt))
                end
                freezeRoot(r)
            end

            if not autoFarmActive then break end

            -- 4) Точный залёт в сундук
            char, root, hum = getCharacter(5)
            if root and hum then
                root.CFrame = CFrame.new(CHEST_POSITION)
                freezeRoot(root)
                task.wait(CHEST_WAIT_TIME)

                -- 5) Ресет для возврата на базу
                if hum and hum.Health > 0 then
                    hum.Health = 0
                end
                task.wait(RESPAWN_WAIT_TIME)
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
    50, 300, 150,
    function(value)
        flightSpeed = value
    end
)

Tab:AddToggle(
    { EN = "Enable Auto Farm", RU = "Включить автофарм" },
    "AutoFarmToggleKey",
    false,
    function(state)
        autoFarmActive = state

        if state then
            print("[BloxyScripts Hub] Автофарм ВКЛЮЧЕН")
            -- Если старый поток ещё жив — принудительно гасим
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

-- Живой статус (обновляется в реальном времени)
local StatusLabel = Tab:AddLabel("Статус: ❌ Неактивен")

task.spawn(function()
    while task.wait(0.3) do
        if not StatusLabel or not StatusLabel.Parent then break end
        StatusLabel.Text = "Статус: " .. (autoFarmActive and "✅ Активен" or "❌ Неактивен")
    end
end)

-- Действия
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
        char.HumanoidRootPart.CFrame = CFrame.new(CHEST_POSITION)
    end
end)

Tab:AddButton({ EN = "Reset Character", RU = "Ресет персонажа" }, function()
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.Health = 0 end
    end
end)

Tab:AddSection({ EN = "Hotkeys", RU = "Горячие клавиши" })
Tab:AddLabel({ EN = "RightShift — toggle UI", RU = "RightShift — скрыть/показать UI" })

print("[BloxyScripts Hub] Модуль АвтоФарм успешно загружен!")
