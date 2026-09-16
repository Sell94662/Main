local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local LP=Players.LocalPlayer

local Config=require(RS:WaitForChild("Mog"):WaitForChild("MogConfig"))
local WinConfig=require(RS:WaitForChild("Mog"):WaitForChild("WinPadConfig"))
local Worlds=require(RS:WaitForChild("Modules"):WaitForChild("Worlds"))
local ClickPower=RS:WaitForChild("PowerRemotes"):WaitForChild("ClickPower")

local mogFarm=false
local appealFarm=false
local mogThread=nil
local appealThread=nil
local savedCFrame=nil

local function root()
	local c=LP.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function world()
	local ok,w=pcall(function() return Worlds.Of(LP) end)
	return ok and w or 1
end

local function worldRoot()
	local ok,w=pcall(function() return Worlds.Root(Worlds.Get(world()) or Worlds.Home()) end)
	return ok and w or nil
end

local function getMogger(zone)
	local w=worldRoot()
	if not w then return end
	local mf=w:FindFirstChild("Moggers")
	if not mf then return end
	local z=mf:FindFirstChild(zone)
	if not z then return end
	local m=z:FindFirstChild("Mogger")
	if not m then return end
	if m:IsA("Model") then return m:GetPivot() end
	if m:IsA("BasePart") then return m.CFrame end
	local p=m:FindFirstChildWhichIsA("BasePart",true)
	return p and p.CFrame
end

local function beaten()
	local ok,z=pcall(function() return Config:ZonesOf(world()) end)
	if not ok or type(z)~="table" then return {} end
	local r={}
	for _,v in ipairs(z) do
		if v.Zone and LP:GetAttribute("Beat_"..v.Zone) then
			local cf=getMogger(v.Zone)
			if cf then table.insert(r,{Zone=v.Zone,CFrame=cf}) end
		end
	end
	return r
end

local function progress()
	return math.min(#beaten()+1,#WinConfig.Rewards)
end

local function getWinPad()
	local w=worldRoot()
	if not w then return end
	local pads=w:FindFirstChild("WinPads")
	if not pads then return end
	local normal=pads:FindFirstChild("Normal")
	if not normal then return end
	local target=WinConfig.RewardFor(progress())
	for _,v in ipairs(normal:GetDescendants()) do
		if v:IsA("TextLabel") and v.Text:find("Wins") then
			local model=v:FindFirstAncestorWhichIsA("Model")
			if model and tonumber(model.Name) and WinConfig.RewardFor(tonumber(model.Name))==target then
				local win=model:FindFirstChild("Win",true)
				if win and win:IsA("BasePart") then return win.CFrame end
			end
		end
	end
end

local function mogFarmLoop()
	while mogFarm do
		local r=root()
		if r then
			local list=beaten()
			for _,v in ipairs(list) do
				if not mogFarm then return end
				r.CFrame=v.CFrame
				task.wait()
			end
			if not mogFarm then return end
			local cf=getWinPad()
			if cf then
				r.CFrame=cf
				task.wait()
			end
		end
		task.wait()
	end
end

local function appealFarmLoop()
	while appealFarm do
		ClickPower:FireServer()
		task.wait(0.05)
	end
end

local gui=Instance.new("ScreenGui")
gui.Name="MogFarmUI"
gui.ResetOnSpawn=false
gui.Parent=LP:WaitForChild("PlayerGui")

local frame=Instance.new("Frame")
frame.Size=UDim2.fromOffset(230,145)
frame.Position=UDim2.new(0,15,0.5,-72)
frame.BackgroundColor3=Color3.fromRGB(20,20,25)
frame.Active=false
frame.Parent=gui

local corner=Instance.new("UICorner")
corner.CornerRadius=UDim.new(0,12)
corner.Parent=frame

local stroke=Instance.new("UIStroke")
stroke.Color=Color3.fromRGB(60,60,70)
stroke.Parent=frame

local title=Instance.new("TextLabel")
title.Size=UDim2.new(1,0,0,30)
title.BackgroundTransparency=1
title.Text="BloxyScripts"
title.TextColor3=Color3.new(1,1,1)
title.TextSize=17
title.Font=Enum.Font.GothamBold
title.Parent=frame

local credit=Instance.new("TextLabel")
credit.Size=UDim2.fromOffset(100,15)
credit.Position=UDim2.new(1,-105,1,-18)
credit.BackgroundTransparency=1
credit.Text="by https://t.me/BloxyScripts"
credit.TextColor3=Color3.fromRGB(120,120,130)
credit.TextSize=9
credit.Font=Enum.Font.Gotham
credit.TextXAlignment=Enum.TextXAlignment.Right
credit.Parent=frame

local function button(y,text,callback)
	local b=Instance.new("TextButton")
	b.Size=UDim2.new(1,-20,0,38)
	b.Position=UDim2.new(0,10,0,y)
	b.BackgroundColor3=Color3.fromRGB(45,45,52)
	b.Text=text.."  OFF"
	b.TextColor3=Color3.new(1,1,1)
	b.TextSize=14
	b.Font=Enum.Font.GothamBold
	b.AutoButtonColor=false
	b.Parent=frame
	local c=Instance.new("UICorner")
	c.CornerRadius=UDim.new(0,8)
	c.Parent=b
	b.Activated:Connect(function()
		callback(b)
	end)
	return b
end

button(35,"Farm Wins",function(b)
	mogFarm=not mogFarm
	b.Text="Farm Wins  "..(mogFarm and "ON" or "OFF")
	b.BackgroundColor3=mogFarm and Color3.fromRGB(35,130,65) or Color3.fromRGB(45,45,52)
	if mogFarm then
		local r=root()
		if r then savedCFrame=r.CFrame end
		if mogThread then pcall(task.cancel, mogThread) end
		mogThread=task.spawn(mogFarmLoop)
	else
		if savedCFrame then
			local r=root()
			if r then r.CFrame=savedCFrame end
		end
	end
end)

button(80,"Appeal Farm",function(b)
	appealFarm=not appealFarm
	b.Text="Appeal Farm  "..(appealFarm and "ON" or "OFF")
	b.BackgroundColor3=appealFarm and Color3.fromRGB(35,130,65) or Color3.fromRGB(45,45,52)
	if appealFarm then
		if appealThread then pcall(task.cancel, appealThread) end
		appealThread=task.spawn(appealFarmLoop)
	end
end)

local dragging=false
local dragStart
local startPos

title.InputBegan:Connect(function(input)
	if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
		dragging=true
		dragStart=input.Position
		startPos=frame.Position
	end
end)

game:GetService("UserInputService").InputChanged:Connect(function(input)
	if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
		local delta=input.Position-dragStart
		frame.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+delta.X,startPos.Y.Scale,startPos.Y.Offset+delta.Y)
	end
end)

game:GetService("UserInputService").InputEnded:Connect(function(input)
	if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
		dragging=false
	end
end)
