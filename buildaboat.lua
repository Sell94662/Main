-- ==========================================================
-- BloxyScripts Hub | Модуль АвтоФарм (V9 - Hyperspeed)
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
local CHEST_ZONE_RADIUS = 50   -- Увеличил радиус, чтобы не проскочить на высокой скорости

-- ==========================================================
-- СОСТОЯНИЕ
-- ==========================================================
local autoFarmActive   = false
local flightSpeed      = 1000 -- Новая скорость по умолчанию
local dropSpeed        = 150  
local chestYOffset     = 0     
local waitTime         = 4    
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

            -- 1) Возврат на старт
            root.CFrame = CFrame.new(START_POSITION)
            freezeRoot(root)
            task.wait(0.5)

            if not autoFarmActive then break end

            -- 2) ВЗЛЕТ НА ВЫСОТУ
            local upTarget = Vector3.new(START_POSITION.X, flightY, START_POSITION.Z)
            while autoFarmActive do
                local r = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if not r then break end
                
                local dist = (upTarget - r.Position).Magnitude
                if dist <= 5 then break end
                
                local dt = RunService.Heartbeat:Wait()
                local step = flightSpeed * dt
                local dir = (upTarget - r.Position).Unit
                
                -- Защита от перелета при лагах
                if dist <= step then
                    r.CFrame = CFrame.new(upTarget)
                else
                    r.CFrame = r.CFrame + (dir * step)
                end
            end

            if not autoFarmActive then break end

            -- 3) ГОРИЗОНТАЛЬНЫЙ ПОЛЕТ (Гипер-скорость)
            local overTarget = Vector3.new(CHEST_X, flightY, CHEST_Z)
            while autoFarmActive do
                local r = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if not r then break end
                
                local dist = (overTarget - r.Position).Magnitude
                if dist <= CHEST_ZONE_RADIUS then break end

                local dt = RunService.Heartbeat:Wait()
                local step = flightSpeed * dt
                local dir = Vector3.new(overTarget.X - r.Position.X, 0, overTarget.Z - r.Position.Z).Unit
                
                if dist <= step then
                    r.CFrame = CFrame.new(overTarget.X, flightY, overTarget.Z)
                else
                    r.CFrame = r.CFrame + (dir * step)
                    r.CFrame = CFrame.new(r.Position.X, flightY, r.Position.Z)
                end
            end

            if not autoFarmActive then break end

            -- 4) ПЛАВНЫЙ ПОДЛЕТ К СУНДУКУ
            while autoFarmActive do
                local r = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if not r then break end
                
                local dist = (targetChestPos - r.Position).Magnitude
                if dist <= 5 then break end

                local dt = RunService.Heartbeat:Wait()
                local step = dropSpeed * dt
                local dir = (targetChestPos - r.Position).Unit
                
                if dist <= step then
                    r.CFrame = CFrame.new(targetChestPos)
                else
                    r.CFrame = r.CFrame + (dir * step)
                end
                freezeRoot(r)
            end

            if not autoFarmActive then break end

            -- 5) СБОР И ОЖИДАНИЕ НАГРАДЫ (БЕЗ РЕСЕТА)
            char, root, hum = getCharacter(5)
            if root and hum then
                local timer = 0
                local touchCFrame = CFrame.new(targetChestPos)
                
                while timer < waitTime and autoFarmActive do
                    if not root or not root.Parent then break end
                    root.CFrame = touchCFrame
                    freezeRoot(root)

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
        else
            task.wait(0.5)
        end
    end

    disableNoClip()
end

-- ==========================================================
-- UI (Ключи V9)
-- ==========================================================
local Tab = Window:CreateTab({ EN = "Auto Farm", RU = "Автофарм" }, 10)

Tab:AddSection({ EN = "Flight Settings", RU = "Настройки полета" })

-- УВЕЛИЧИЛ МАКСИМУМ ДО 1500
Tab:AddSlider(
    { EN = "Flight Speed", RU = "Скорость полёта" },
    "AutoFarmSpeed_V9", 
    100, 1500, 1000, -- 1000 по умолчанию, макс 1500
    function(value) flightSpeed = value end
)

Tab:AddSlider(
    { EN = "Flight Altitude", RU = "Высота полета (Y)" },
    "FlightAlt_V9", 
    50, 120, 100,
    function(value) FLIGHT_ALTITUDE = value end
)

Tab:AddSlider(
    { EN = "Fly Down Speed", RU = "Скорость подлета к сундуку" },
    "FallSpeed_V9", 
    20, 150, 150,
    function(value) dropSpeed = value end
)

Tab:AddSlider(
    { EN = "Chest Y Offset", RU = "Коррекция высоты" },
    "ChestYOffset_V9", 
    -20, 20, 0,
    function(value) chestYOffset = value end
)

Tab:AddSlider(
    { EN = "Wait Time", RU = "Время ожидания на сундуке" },
    "WaitTime_V9", 
    2, 10, 4,
    function(value) waitTime = value end
)

Tab:AddToggle(
    { EN = "Enable Auto Farm", RU = "Включить автофарм" },
    "AutoFarmToggle_V9", 
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

print("[BloxyScripts Hub] Модуль АвтоФарм V9 успешно загружен!")
