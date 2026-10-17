local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

-- Убираем старые меню, если были
local old = pg:FindFirstChild("SuperChestGui")
if old then old:Destroy() end

-- ============================================================
-- 1. СОЗДАЕМ САМО МЕНЮ
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
-- 2. НАСТРОЙКИ
-- ============================================================
local CLICK_INTERVAL = 0.1
local OFFSET_X = 3
local OFFSET_Z = 3
local STABILIZE_DELAY = 0.3
local RESCAN_DELAY = 1

local activePlatform = nil
local autoFarmEnabled = false

-- ============================================================
-- 3. ТВОИ ОРИГИНАЛЬНЫЕ ФУНКЦИИ (НЕ ТРОНУТЫ)
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
        if obj.Name == "ClickerChest" and obj.Parent then
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

-- ============================================================
-- 4. КЛИК ИЗ ВТОРОГО СКРИПТА (VIRTUAL INPUT)
-- ============================================================
local function performClick()
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(535, 454, 0, true, game, 0)
        task.wait(0.01)
        VirtualInputManager:SendMouseButtonEvent(535, 454, 0, false, game, 0)
    end)
end

-- ============================================================
-- 5. ОБЪЕДИНЕННАЯ ЛОГИКА
-- ============================================================
local function processChest(chest, chestPos)
    -- 11 кликов
    for i = 1, 11 do
        if not autoFarmEnabled then break end
        performClick()
        task.wait(0.05)
    end

    if not autoFarmEnabled then return end

    -- Телепорт
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    createInvisiblePlatform(chestPos)
    local targetPos = Vector3.new(chestPos.X + OFFSET_X, chestPos.Y + 2, chestPos.Z + OFFSET_Z)
    hrp.CFrame = CFrame.new(targetPos)
    task.wait(STABILIZE_DELAY)

    -- Кликаем по сундуку
    while chest and chest.Parent and autoFarmEnabled do
        for _, d in ipairs(chest:GetDescendants()) do
            if d:IsA("ClickDetector") then pcall(function() fireclickdetector(d) end) end
            if d:IsA("ProximityPrompt") then pcall(function() fireproximityprompt(d) end) end
            if d:IsA("RemoteEvent") then pcall(function() d:FireServer(chest) end) end
        end
        task.wait(CLICK_INTERVAL)
    end

    if activePlatform then 
        activePlatform:Destroy() 
        activePlatform = nil 
    end
end

-- ============================================================
-- 6. ВКЛЮЧАТЕЛЬ
-- ============================================================
btn.MouseButton1Click:Connect(function()
    autoFarmEnabled = not autoFarmEnabled
    if autoFarmEnabled then
        btn.Text = "AutoFarm: ON"
        btn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
        
        task.spawn(function()
            while autoFarmEnabled do
                local chest, pos = findChest()
                if chest and pos then
                    processChest(chest, pos)
                else
                    task.wait(RESCAN_DELAY)
                end
                task.wait(0.1)
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

print("Скрипт загружен.")
