local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

-- Убираем старые меню
local old = pg:FindFirstChild("SuperChestGui")
if old then old:Destroy() end
local oldClicker = pg:FindFirstChild("HiddenClicker")
if oldClicker then oldClicker:Destroy() end

-- ============================================================
-- 1. НЕВИДИМАЯ КНОПКА
-- ============================================================
local clickGui = Instance.new("ScreenGui")
clickGui.Name = "HiddenClicker"
clickGui.ResetOnSpawn = false
clickGui.IgnoreGuiInset = true
clickGui.Parent = pg

local hiddenBtn = Instance.new("TextButton")
hiddenBtn.Size = UDim2.new(0, 100, 0, 100)
hiddenBtn.Position = UDim2.new(0, 535 - 50, 0, 454 - 50)
hiddenBtn.BackgroundTransparency = 1
hiddenBtn.Text = ""
hiddenBtn.Active = false
hiddenBtn.Parent = clickGui

-- ============================================================
-- 2. МЕНЮ
-- ============================================================
local gui = Instance.new("ScreenGui")
gui.Name = "SuperChestGui"
gui.ResetOnSpawn = false
gui.Parent = pg

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 200, 0, 70)
frame.Position = UDim2.new(0, 20, 0, 20)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

local btn = Instance.new("TextButton")
btn.Size = UDim2.new(1, -20, 0, 40)
btn.Position = UDim2.new(0, 10, 0, 15)
btn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
btn.Text = "AutoFarm: OFF"
btn.TextColor3 = Color3.new(1, 1, 1)
btn.Font = Enum.Font.GothamBold
btn.TextSize = 16
btn.Active = true
btn.Parent = frame
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

-- ============================================================
-- 3. НАСТРОЙКИ
-- ============================================================
local CLICK_INTERVAL = 0.1
local OFFSET_X = 3
local OFFSET_Z = 3
local STABILIZE_DELAY = 0.3
local RESCAN_DELAY = 1

local activePlatform = nil
local autoFarmEnabled = false
local currentChest = nil -- Чтобы не кликать бесконечно по одному и тому же

-- ============================================================
-- 4. ФУНКЦИИ
-- ============================================================
local function createInvisiblePlatform(position)
    if activePlatform then activePlatform:Destroy() end
    local platform = Instance.new("Part")
    platform.Name = "SWP_Platform"
    platform.Size = Vector3.new(10, 1, 10)
    platform.Anchored = true
    platform.CanCollide = true
    platform.Transparency = 1
    platform.Material = Enum.Material.Plastic
    platform.Position = Vector3.new(position.X + OFFSET_X, position.Y - 3, position.Z + OFFSET_Z)
    platform.Parent = workspace
    activePlatform = platform
end

local function findChest()
    for _, obj in ipairs(workspace:GetDescendants()) do
        -- Ищем сундук, пропуская тот, который уже кликаем
        if obj.Name == "ClickerChest" and obj.Parent and obj ~= currentChest then
            local ok, pos = pcall(function()
                if obj:IsA("Model") and obj.PrimaryPart then return obj.PrimaryPart.Position end
                if obj:IsA("BasePart") then return obj.Position end
                return obj:GetPivot().Position
            end)
            if ok and pos then return obj, pos end
        end
    end
    return nil, nil
end

local function performClick()
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(535, 454, 0, true, game, 0)
        task.wait(0.01)
        VirtualInputManager:SendMouseButtonEvent(535, 454, 0, false, game, 0)
    end)
    pcall(function()
        hiddenBtn:Activate()
    end)
end

local function processChest(chest, chestPos)
    currentChest = chest -- Запоминаем, что мы на этом сундуке
    
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- 1. Телепорт
    createInvisiblePlatform(chestPos)
    local targetPos = Vector3.new(chestPos.X + OFFSET_X, chestPos.Y + 2, chestPos.Z + OFFSET_Z)
    hrp.CFrame = CFrame.new(targetPos)
    task.wait(STABILIZE_DELAY)

    -- 2. 11 кликов
    for i = 1, 11 do
        if not autoFarmEnabled then break end
        performClick()
        task.wait(0.05)
    end

    -- 3. Кликаем по сундуку 3 секунды, затем ищем следующий
    local timer = 0
    while chest and chest.Parent and autoFarmEnabled and timer < 3 do
        for _, d in ipairs(chest:GetDescendants()) do
            if d:IsA("ClickDetector") then pcall(function() fireclickdetector(d) end) end
            if d:IsA("ProximityPrompt") then pcall(function() fireproximityprompt(d) end) end
            if d:IsA("RemoteEvent") then pcall(function() d:FireServer(chest) end) end
        end
        task.wait(CLICK_INTERVAL)
        timer = timer + CLICK_INTERVAL
    end

    if activePlatform then 
        activePlatform:Destroy() 
        activePlatform = nil 
    end
end

-- ============================================================
-- 5. ГЛАВНЫЙ ЦИКЛ
-- ============================================================
btn.MouseButton1Click:Connect(function()
    autoFarmEnabled = not autoFarmEnabled
    if autoFarmEnabled then
        btn.Text = "AutoFarm: ON"
        btn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
        currentChest = nil -- Сбрасываем при включении
        
        task.spawn(function()
            while autoFarmEnabled do
                local chest, pos = findChest()
                if chest and pos then
                    processChest(chest, pos)
                    -- Сбрасываем текущий сундук, чтобы он мог найти его снова (если других нет)
                    currentChest = nil 
                    task.wait(0.5) -- Пауза перед поиском следующего
                else
                    task.wait(RESCAN_DELAY)
                end
            end
        end)
    else
        btn.Text = "AutoFarm: OFF"
        btn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        if activePlatform then 
            activePlatform:Destroy() 
            activePlatform = nil 
        end
    end
end)
