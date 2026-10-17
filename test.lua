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
-- 1. НЕВИДИМАЯ КНОПКА (Клик по координатам)
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
local OFFSET_X = 3
local OFFSET_Z = 3
local STABILIZE_DELAY = 0.3

local activePlatform = nil
local autoFarmEnabled = false

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

local function performClick()
    -- Клик 1: Эмуляция мыши
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(535, 454, 0, true, game, 0)
        VirtualInputManager:SendMouseButtonEvent(535, 454, 0, false, game, 0)
    end)
    -- Клик 2: Невидимая кнопка
    pcall(function()
        hiddenBtn:Activate()
    end)
end

-- ============================================================
-- 5. ЛОГИКА
-- ============================================================
btn.MouseButton1Click:Connect(function()
    autoFarmEnabled = not autoFarmEnabled
    if autoFarmEnabled then
        btn.Text = "AutoFarm: ON"
        btn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
        
        -- ПОТОК 1: Бесконечные клики (не останавливается никогда)
        task.spawn(function()
            while autoFarmEnabled do
                performClick()
                task.wait(0.05) -- Скорость кликов (0.05 = 20 кликов в секунду)
            end
        end)

        -- ПОТОК 2: Телепорт каждые 4 секунды
        task.spawn(function()
            while autoFarmEnabled do
                local chest, pos = findChest()
                if chest and pos then
                    local char = player.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    
                    if hrp then
                        createInvisiblePlatform(pos)
                        local targetPos = Vector3.new(pos.X + OFFSET_X, pos.Y + 2, pos.Z + OFFSET_Z)
                        hrp.CFrame = CFrame.new(targetPos)
                        
                        -- Пытаемся нажать на сундук
                        for _, d in ipairs(chest:GetDescendants()) do
                            if d:IsA("ClickDetector") then pcall(function() fireclickdetector(d) end) end
                            if d:IsA("ProximityPrompt") then pcall(function() fireproximityprompt(d) end) end
                        end
                    end
                end
                task.wait(4) -- Ждем ровно 4 секунды перед следующим телепортом
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
