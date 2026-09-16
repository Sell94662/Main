local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UIS = game:GetService("UserInputService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local StartFishing = Remotes:WaitForChild("StartFishing")
local FishingInfoSend = Remotes:WaitForChild("FishingInfoSend")
local EndFishing = Remotes:FindFirstChild("EndFIshing") or Remotes:FindFirstChild("EndFlshing") or Remotes:FindFirstChild("EndFishing")

local autoFish = false
local fishThread = nil

local function fishLoop()
    while autoFish do
        pcall(function()
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local currentCFrame = hrp and hrp.CFrame or CFrame.new(0,0,0)

            StartFishing:FireServer(2.0)

            FishingInfoSend:FireServer({
                ["Strength"] = 1000000,
                ["Weight"] = 100000000
            }, 4, "Divine Lochness")

            task.wait()

            EndFishing:FireServer("Divine Lochness", currentCFrame)
        end)
        task.wait(0.5)
    end
end

-- ===== GUI =====
local gui = Instance.new("ScreenGui")
gui.Name = "BloxyScripts_Fish"
gui.ResetOnSpawn = false
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(220, 115)
frame.Position = UDim2.new(0, 15, 0.5, -57)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
frame.Active = false
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = frame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(60, 60, 70)
stroke.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundTransparency = 1
title.Text = "BloxyScripts"
title.TextColor3 = Color3.new(1, 1, 1)
title.TextSize = 17
title.Font = Enum.Font.GothamBold
title.Parent = frame

local credit = Instance.new("TextLabel")
credit.Size = UDim2.new(1, -10, 0, 15)
credit.Position = UDim2.new(0, 10, 1, -18)
credit.BackgroundTransparency = 1
credit.Text = "By https://t.me/BloxyScripts"
credit.TextColor3 = Color3.fromRGB(120, 120, 130)
credit.TextSize = 9
credit.Font = Enum.Font.Gotham
credit.TextXAlignment = Enum.TextXAlignment.Right
credit.Parent = frame

local btn = Instance.new("TextButton")
btn.Size = UDim2.new(1, -20, 0, 40)
btn.Position = UDim2.new(0, 10, 0, 38)
btn.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
btn.Text = "Auto Fish  OFF"
btn.TextColor3 = Color3.new(1, 1, 1)
btn.TextSize = 14
btn.Font = Enum.Font.GothamBold
btn.AutoButtonColor = false
btn.Parent = frame

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 8)
btnCorner.Parent = btn

btn.Activated:Connect(function()
    autoFish = not autoFish
    btn.Text = "Auto Fish  " .. (autoFish and "ON" or "OFF")
    btn.BackgroundColor3 = autoFish and Color3.fromRGB(35, 130, 65) or Color3.fromRGB(45, 45, 52)
    if autoFish then
        if fishThread then pcall(task.cancel, fishThread) end
        fishThread = task.spawn(fishLoop)
    end
end)

-- Draggable
local dragging, dragStart, startPos
title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = frame.Position
    end
end)

UIS.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

print("BloxyScripts Fish loaded")