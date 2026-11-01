-- ==========================================================
-- BloxyScripts Hub | Модуль АвтоФарм (V8 - Smooth Flight, No Reset)
-- ==========================================================

print("[BloxyScripts Hub] Загрузка модуля АвтоФарм...")

local ok, Library = pcall(function()
    return loadstring(game:HttpGet(
        "https://raw.githubusercontent.com/TheBloxyScripts/BloxyScripts/main/main.lua"
    ))()
end)

if not ok or not Library then
    warn("[BloxyScripts Hub] ОШИБКА: Не удалось загрузить фреймворк!")
    return
end

local Window = Library:CreateWindow({
    Name = "BloxyScripts | Hub",
    LoadingTitle = "Загрузка модулей...",
    LoadingSubtitle = "by TheBloxyScripts",
    FolderName = "BloxyConfigs"
})

if not Window then return end

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- ==========================================================
-- КОНСТАНТЫ
-- ==========================================================
local START_POSITION = Vector3.new(41.48, -12.09, -35.71)
local CHEST_X = -46.42
local CHEST_Z = 9502.53
local CHEST_Y = -353.53 

local FLIGHT_ALTITUDE   = 100  
local CHEST_ZONE_RADIUS = 20   

-- ==========================================================
-- СОСТОЯНИЕ
-- ==========================================================
local autoFarmActive   = false
local flightSpeed      = 500  
local dropSpeed        = 60   -- Плавная скорость подлета к сундуку
local chestYOffset     = 0     
local waitTime         = 4    -- Ждем 4 секунды на сундуке
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
        local char, root, hum = getCharacter(15)

        if char then
            local currentChestY = CHEST_Y + chestYOffset
            local flightY = FLIGHT_ALTITUDE + chestYOffset
            local targetChestPos = Vector3.new(CHEST_X, currentChestY, CHEST_Z)

            -- 1) Возврат на старт для нового круга (телепорт только на старт)
            root.CFrame = CFrame.new(START_POSITION)
            freezeRoot(root)
            task.wait(0.5)

            if not autoFarmActive then break end

            -- 2) ВЗЛЕТ НА ВЫСОТУ
            local upTarget = Vector3.new(START_POSITION.X, flightY, START_POSITION.Z)
            while autoFarmActive do
                local r = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if not r then break end
                if (upTarget - r.Position).Magnitude <= 5 then break end
                
                local dt = RunService.Heartbeat:Wait()
                local dir = (upTarget - r.Position).Unit
                r.CFrame = r.CFrame + (dir * (flightSpeed * dt))
            end

            if not autoFarmActive then break end

            -- 3) ГОРИЗОНТАЛЬНЫЙ ПОЛЕТ К ЗОНЕ НАД СУНДУКОМ
            local overTarget = Vector3.new(CHEST_X, flightY, CHEST_Z)
            while autoFarmActive do
                local r = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if not r then break end
                if (overTarget - r.Position).Magnitude <= CHEST_ZONE_RADIUS then break end

                local dt = RunService.Heartbeat:Wait()
                local dir = (overTarget - r.Position).Unit
                r.CFrame = r.CFrame + (dir * (flightSpeed * dt))
                r.CFrame = CFrame.new(r.Position.X, flightY, r.Position.Z) -- Держим высоту
            end

            if not autoFarmActive then break end

            -- 4) ПЛАВНЫЙ ПОДЛЕТ К СУНДУКУ (По диагонали)
            while autoFarmActive do
                local r = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if not r then break end
                
                -- Если подлетели близко к сундуку — стоп
                if (targetChestPos - r.Position).Magnitude <= 5 then break end

                local dt = RunService.Heartbeat:Wait()
                -- Летим прямо к сундуку
                local dir = (targetChestPos - r.Position).Unit
                r.CFrame = r.CFrame + (dir * (dropSpeed * dt))
                freezeRoot(r)
            end

            if not autoFarmActive then break end

            -- 5) СБОР И ОЖИДАНИЕ НАГРАДЫ (БЕЗ РЕСЕТА)
            char, root, hum = getCharacter(5)
            if root and hum then
                local timer = 0
                
                -- Прилипаем к сундуку, чтобы игра 100% засчитала
                local touchCFrame = CFrame.new(targetChestPos)
                
                while timer < waitTime and autoFarmActive do
                    if not root or not root.Parent then break end
                    root.CFrame = touchCFrame
                    freezeRoot(root)

                    -- Авто-клик по кнопке "Claim" (если она появилась)
                    pcall(function()
                        local function clickClaim(parent)
                            for _, gui in pairs(parent:GetDescendants()) do
                                if gui:IsA("TextButton") and string.lower(gui.Text):find("claim") then
                                    gui:FireMouseClick()
                                end
                            end
                        end
                        clickClaim(game:GetService("CoreGui"))
                        clickClaim(LocalPlayer.PlayerGui)
                    end)
                    
                    local dt = RunService.Heartbeat:Wait()
                    timer = timer + dt
                end
            end
            -- Тут ресета нет. Скрипт просто пойдет на новую итерацию цикла (вернется на старт).
        else
            task.wait(0.5)
        end
    end

    disableNoClip()
end

-- ==========================================================
-- UI (Ключи V8 для сброса настроек)
-- ==========================================================
local Tab = Window:CreateTab({ EN = "Auto Farm", RU = "Автофарм" }, 10)

Tab:AddSection({ EN = "Flight Settings", RU = "Настройки полета" })

Tab:AddSlider(
    { EN = "Flight Speed", RU = "Скорость полёта" },
    "AutoFarmSpeed_V8", 
    100, 500, 500,
    function(value) flightSpeed = value end
)

Tab:AddSlider(
    { EN = "Flight Altitude", RU = "Высота полета (Y)" },
    "FlightAlt_V8", 
    50, 120, 100,
    function(value) FLIGHT_ALTITUDE = value end
)

Tab:AddSlider(
    { EN = "Fly Down Speed", RU = "Скорость подлета к сундуку" },
    "FallSpeed_V8", 
    20, 150, 60, -- Поставил 60 для плавного долета
    function(value) dropSpeed = value end
)

Tab:AddSlider(
    { EN = "Chest Y Offset", RU = "Коррекция высоты" },
    "ChestYOffset_V8", 
    -20, 20, 0,
    function(value) chestYOffset = value end
)

Tab:AddSlider(
    { EN = "Wait Time", RU = "Время ожидания на сундуке" },
    "WaitTime_V8", 
    2, 10, 4,
    function(value) waitTime = value end
)

Tab:AddToggle(
    { EN = "Enable Auto Farm", RU = "Включить автофарм" },
    "AutoFarmToggle_V8", 
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
        local targetY = CHEST_Y + chestYOffset
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

print("[BloxyScripts Hub] Модуль АвтоФарм V8 успешно загружен!")
