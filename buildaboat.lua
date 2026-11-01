-- ==========================================================
-- BloxyScripts Hub | Модуль АвтоФарм (Координаты обновлены)
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
-- КОНСТАНТЫ И НАСТРОЙКИ
-- ==========================================================
local START_POSITION    = Vector3.new(41.48, -12.09, -35.71)

-- НОВЫЕ КООРДИНАТЫ СУНДУКА (от пользователя)
local CHEST_X = -46.42
local CHEST_Z = 9502.53
local CHEST_Y = -353.53 

local FLY_HEIGHT_OFFSET = 50   -- Высота полета относительно старта
local CHEST_ZONE_RADIUS = 15   -- Радиус зоны над сундуком (начинаем спуск)
local TOUCH_DISTANCE    = 3    -- Насколько близко к Y сундука считаем касанием
local DROP_SPEED        = 150  -- Скорость падения вниз (studs/sec)

-- ==========================================================
-- СОСТОЯНИЕ
-- ==========================================================
local autoFarmActive   = false
local flightSpeed      = 200  -- Увеличил скорость полета для дальних дистанций
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
            local flyHeight = START_POSITION.Y + FLY_HEIGHT_OFFSET

            -- 1) Телепорт на старт
            root.CFrame = CFrame.new(START_POSITION)
            freezeRoot(root)
            task.wait(0.5)

            if not autoFarmActive then break end

            -- 2) Подъём над стартом
            root.CFrame = CFrame.new(START_POSITION.X, flyHeight, START_POSITION.Z)
            freezeRoot(root)

            -- 3) ГОРИЗОНТАЛЬНЫЙ ПОЛЁТ ДО ЗОНЫ
            while autoFarmActive do
                local c = LocalPlayer.Character
                if not c then break end
                local r = c:FindFirstChild("HumanoidRootPart")
                local h = c:FindFirstChildOfClass("Humanoid")
                if not r or not h or h.Health <= 0 then break end

                -- Проверяем расстояние по X и Z до сундука
                local dxz = Vector3.new(r.Position.X - CHEST_X, 0, r.Position.Z - CHEST_Z)
                
                if dxz.Magnitude <= CHEST_ZONE_RADIUS then
                    break -- Долетели до зоны
                end

                local dt = RunService.Heartbeat:Wait()
                local deltaXZ = Vector3.new(CHEST_X - r.Position.X, 0, CHEST_Z - r.Position.Z)
                
                if deltaXZ.Magnitude > 0.01 then
                    local step = deltaXZ.Unit * (flightSpeed * dt)
                    local newPos = r.Position + step
                    -- ЖЁСТКО удерживаем высоту flyHeight
                    r.CFrame = CFrame.new(newPos.X, flyHeight, newPos.Z)
                end
                freezeRoot(r)
            end

            if not autoFarmActive then break end

            -- 4) ПЛАВНЫЙ СПУСК ВНИЗ (на нужную высоту сундука)
            char, root, hum = getCharacter(5)
            if root and hum then
                -- Выравниваемся ровно над сундуком
                root.CFrame = CFrame.new(CHEST_X, flyHeight, CHEST_Z)
                freezeRoot(root)
                task.wait(0.1)

                -- Спускаемся строго вниз до Y сундука
                while autoFarmActive do
                    local c = LocalPlayer.Character
                    if not c then break end
                    local r = c:FindFirstChild("HumanoidRootPart")
                    if not r then break end

                    local targetY = currentChestY + TOUCH_DISTANCE
                    
                    if r.Position.Y <= targetY then
                        break -- Приземлились на нужную высоту
                    end

                    local dt = RunService.Heartbeat:Wait()
                    local newY = math.max(r.Position.Y - DROP_SPEED * dt, targetY)
                    r.CFrame = CFrame.new(CHEST_X, newY, CHEST_Z)
                    freezeRoot(r)
                end

                if not autoFarmActive then break end

                -- 5) ФИКСАЦИЯ НА СУНДУКЕ И РЕСЕТ
                char, root, hum = getCharacter(5)
                if root and hum then
                    -- Ставим точно в координаты сундука
                    root.CFrame = CFrame.new(CHEST_X, currentChestY + TOUCH_DISTANCE, CHEST_Z)
                    freezeRoot(root)
                    
                    -- Ждем засчитывания награды (если сундук не засчитывается, увеличь до 3-4 сек)
                    task.wait(2.5)

                    -- Ресет
                    if hum and hum.Health > 0 then
                        hum.Health = 0
                    end
                    task.wait(2)
                end
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
    50, 400, 200,
    function(value) flightSpeed = value end
)

-- Оставил слайдер на случай, если нужно будет чуть-чуть подправить высоту
Tab:AddSlider(
    { EN = "Chest Y Offset", RU = "Коррекция высоты (Y)" },
    "ChestYOffsetKey",
    -20, 20, 0,
    function(value) 
        chestYOffset = value 
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
