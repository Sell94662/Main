local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Stats = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer

---------------------------------------------------------
-- ЭКСПОРТ ДЛЯ ДОГРУЗЧИКОВ
---------------------------------------------------------
local Hub = {}
getgenv().CustomHub = Hub

---------------------------------------------------------
-- СИСТЕМА КОНФИГУРАЦИИ
---------------------------------------------------------
local ConfigFolder = "BloxyScriptsConfigs"
local DefaultConfigName = "default.json"

if isfolder and not isfolder(ConfigFolder) and makefolder then
    makefolder(ConfigFolder)
end

local DefaultConfig = {
    AccentColorR = 115,
    AccentColorG = 80,
    AccentColorB = 255,
    Transparency = 50,
    CornerRadius = 12,
    FlingClick = false,
    AntiFling = false,
    FlyEnabled = false,
    FlySpeed = 50,
    WalkSpeed = 16,
    JumpPower = 50
}

local Config = table.clone(DefaultConfig)
local UIElementUpdaters = {}

local Theme = {
    Background = Color3.fromRGB(20, 20, 26),
    Header     = Color3.fromRGB(15, 15, 20),
    Sidebar    = Color3.fromRGB(18, 18, 24),
    Accent     = Color3.fromRGB(Config.AccentColorR, Config.AccentColorG, Config.AccentColorB),
    Text       = Color3.fromRGB(255, 255, 255),
    TextDark   = Color3.fromRGB(140, 140, 155),
    ElementBg  = Color3.fromRGB(28, 28, 36),
    ToggleOff  = Color3.fromRGB(45, 45, 55)
}

---------------------------------------------------------
-- UI CORE
---------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BloxyScriptsUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 999
ScreenGui.Parent = RunService:IsStudio() and LocalPlayer.PlayerGui or CoreGui

---------------------------------------------------------
-- 1. СПЛЕШ-СКРИН
---------------------------------------------------------
local SplashFrame = Instance.new("Frame")
SplashFrame.Size = UDim2.fromOffset(200, 150)
SplashFrame.Position = UDim2.fromScale(0.5, 0.5)
SplashFrame.AnchorPoint = Vector2.new(0.5, 0.5)
SplashFrame.BackgroundColor3 = Theme.Background
SplashFrame.BorderSizePixel = 0
SplashFrame.ClipsDescendants = true
SplashFrame.Parent = ScreenGui

local SplashCorner = Instance.new("UICorner")
SplashCorner.CornerRadius = UDim.new(0, 12)
SplashCorner.Parent = SplashFrame

local SplashStroke = Instance.new("UIStroke")
SplashStroke.Thickness = 1.5
SplashStroke.Color = Theme.Accent
SplashStroke.Parent = SplashFrame

local SplashLogo = Instance.new("TextLabel")
SplashLogo.Text = "⚡"
SplashLogo.Size = UDim2.fromOffset(40, 40)
SplashLogo.Position = UDim2.new(0.5, -20, 0.25, -20)
SplashLogo.BackgroundTransparency = 1
SplashLogo.TextSize = 30
SplashLogo.Parent = SplashFrame

local SplashTitle = Instance.new("TextLabel")
SplashTitle.Text = "BLOXYSCRIPTS"
SplashTitle.Size = UDim2.new(1, 0, 0, 20)
SplashTitle.Position = UDim2.new(0, 0, 0.55, 0)
SplashTitle.TextColor3 = Theme.Text
SplashTitle.Font = Enum.Font.GothamBold
SplashTitle.TextSize = 13
SplashTitle.BackgroundTransparency = 1
SplashTitle.Parent = SplashFrame

local LoadingBarBg = Instance.new("Frame")
LoadingBarBg.Size = UDim2.new(0.7, 0, 0, 4)
LoadingBarBg.Position = UDim2.new(0.15, 0, 0.78, 0)
LoadingBarBg.BackgroundColor3 = Theme.ElementBg
LoadingBarBg.BorderSizePixel = 0
LoadingBarBg.Parent = SplashFrame

local LoadingBarBgCorner = Instance.new("UICorner")
LoadingBarBgCorner.CornerRadius = UDim.new(1, 0)
LoadingBarBgCorner.Parent = LoadingBarBg

local LoadingBarFill = Instance.new("Frame")
LoadingBarFill.Size = UDim2.new(0, 0, 1, 0)
LoadingBarFill.BackgroundColor3 = Theme.Accent
LoadingBarFill.BorderSizePixel = 0
LoadingBarFill.Parent = LoadingBarBg

local LoadingBarFillCorner = Instance.new("UICorner")
LoadingBarFillCorner.CornerRadius = UDim.new(1, 0)
LoadingBarFillCorner.Parent = LoadingBarFill

---------------------------------------------------------
-- 2. ОСНОВНОЕ ОКНО HUB
---------------------------------------------------------
local Main = Instance.new("Frame")
Main.Name = "MainFrame"
Main.Size = UDim2.fromOffset(540, 370)
Main.Position = UDim2.fromScale(0.5, 0.5)
Main.AnchorPoint = Vector2.new(0.5, 0.5)
Main.BackgroundColor3 = Theme.Background
Main.BackgroundTransparency = Config.Transparency / 100
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
Main.Visible = false
Main.Parent = ScreenGui

local AllCorners = {}
local AllFrames = {Main}
local AccentElements = {SplashStroke, LoadingBarFill}

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, Config.CornerRadius)
MainCorner.Parent = Main
table.insert(AllCorners, MainCorner)

local MainStroke = Instance.new("UIStroke")
MainStroke.Thickness = 1.5
MainStroke.Color = Theme.Accent
MainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
MainStroke.Parent = Main
table.insert(AccentElements, MainStroke)

local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 40)
Header.BackgroundColor3 = Theme.Header
Header.BackgroundTransparency = Config.Transparency / 100
Header.BorderSizePixel = 0
Header.Parent = Main
table.insert(AllFrames, Header)

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, Config.CornerRadius)
HeaderCorner.Parent = Header
table.insert(AllCorners, HeaderCorner)

local Title = Instance.new("TextLabel")
Title.Text = "BLOXYSCRIPTS"
Title.Size = UDim2.new(1, -85, 1, 0)
Title.Position = UDim2.fromOffset(15, 0)
Title.TextColor3 = Theme.Text
Title.TextSize = 14
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.BackgroundTransparency = 1
Title.Parent = Header

local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Size = UDim2.fromOffset(30, 30)
MinimizeBtn.Position = UDim2.new(1, -70, 0.5, -15)
MinimizeBtn.BackgroundColor3 = Theme.ElementBg
MinimizeBtn.BackgroundTransparency = Config.Transparency / 100
MinimizeBtn.Text = "-"
MinimizeBtn.TextColor3 = Theme.Text
MinimizeBtn.TextSize = 18
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.Parent = Header
table.insert(AllFrames, MinimizeBtn)

local MinBtnCorner = Instance.new("UICorner")
MinBtnCorner.CornerRadius = UDim.new(0, 6)
MinBtnCorner.Parent = MinimizeBtn
table.insert(AllCorners, MinBtnCorner)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.fromOffset(30, 30)
CloseBtn.Position = UDim2.new(1, -35, 0.5, -15)
CloseBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
CloseBtn.BackgroundTransparency = Config.Transparency / 100
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Theme.Text
CloseBtn.TextSize = 14
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Parent = Header

CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 140, 1, -40)
Sidebar.Position = UDim2.fromOffset(0, 40)
Sidebar.BackgroundTransparency = 1
Sidebar.BorderSizePixel = 0
Sidebar.Parent = Main

local SidebarList = Instance.new("UIListLayout")
SidebarList.Padding = UDim.new(0, 5)
SidebarList.SortOrder = Enum.SortOrder.LayoutOrder
SidebarList.Parent = Sidebar

local SidebarPadding = Instance.new("UIPadding")
SidebarPadding.PaddingTop = UDim.new(0, 8)
SidebarPadding.PaddingLeft = UDim.new(0, 6)
SidebarPadding.PaddingRight = UDim.new(0, 6)
SidebarPadding.Parent = Sidebar

local Container = Instance.new("Frame")
Container.Size = UDim2.new(1, -150, 1, -50)
Container.Position = UDim2.fromOffset(145, 45)
Container.BackgroundTransparency = 1
Container.Parent = Main

---------------------------------------------------------
-- КНОПКА-МОБИЛЬНАЯ ИКОНКА
---------------------------------------------------------
local MobileIcon = Instance.new("TextButton")
MobileIcon.Size = UDim2.fromOffset(42, 42)
MobileIcon.Position = UDim2.new(0, 15, 0.4, 0)
MobileIcon.BackgroundColor3 = Theme.Accent
MobileIcon.Text = "⚡"
MobileIcon.TextSize = 20
MobileIcon.Visible = false
MobileIcon.Parent = ScreenGui
table.insert(AccentElements, MobileIcon)

local MobileCorner = Instance.new("UICorner")
MobileCorner.CornerRadius = UDim.new(1, 0)
MobileCorner.Parent = MobileIcon

local MobileStroke = Instance.new("UIStroke")
MobileStroke.Thickness = 1.5
MobileStroke.Color = Theme.Text
MobileStroke.Parent = MobileIcon

local function ToggleUI()
    Main.Visible = not Main.Visible
    MobileIcon.Visible = not Main.Visible
end

MinimizeBtn.MouseButton1Click:Connect(ToggleUI)
MobileIcon.MouseButton1Click:Connect(ToggleUI)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.RightShift then ToggleUI() end
end)

local dragging, dragStart, startPos
Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = Main.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

Header.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

---------------------------------------------------------
-- ОБНОВЛЕНИЕ СТИЛЕЙ И КОНФИГА
---------------------------------------------------------
local function ApplyConfig()
    Theme.Accent = Color3.fromRGB(Config.AccentColorR, Config.AccentColorG, Config.AccentColorB)
    
    for _, elem in ipairs(AccentElements) do
        if elem and elem.Parent then
            if elem:IsA("UIStroke") then
                elem.Color = Theme.Accent
            elseif elem:IsA("TextButton") or elem:IsA("Frame") then
                elem.BackgroundColor3 = Theme.Accent
            end
        end
    end
    
    local alpha = Config.Transparency / 100
    for _, f in ipairs(AllFrames) do
        if f and f.Parent then
            f.BackgroundTransparency = alpha
        end
    end
    
    for _, corner in ipairs(AllCorners) do
        if corner and corner.Parent then
            corner.CornerRadius = UDim.new(0, Config.CornerRadius)
        end
    end
end

---------------------------------------------------------
-- HUB LIBRARY API
---------------------------------------------------------
local Tabs = {}
local FirstTab = true
local TabOrderCounter = 1


function Hub:CreateTab(tabName, customOrder)
    local TabBtn = Instance.new("TextButton")
    TabBtn.Size = UDim2.new(1, 0, 0, 30)
    TabBtn.BackgroundColor3 = Theme.ElementBg
    TabBtn.BackgroundTransparency = Config.Transparency / 100
    TabBtn.Text = tabName
    TabBtn.TextColor3 = Theme.TextDark
    TabBtn.TextSize = 11
    TabBtn.Font = Enum.Font.GothamMedium
    

    TabBtn.LayoutOrder = customOrder or TabOrderCounter
    TabOrderCounter = TabOrderCounter + 1
    
    TabBtn.Parent = Sidebar
    table.insert(AllFrames, TabBtn)

    local BtnCorner = Instance.new("UICorner")
    BtnCorner.CornerRadius = UDim.new(0, Config.CornerRadius)
    BtnCorner.Parent = TabBtn
    table.insert(AllCorners, BtnCorner)

    local Page = Instance.new("ScrollingFrame")
    Page.Size = UDim2.new(1, 0, 1, 0)
    Page.BackgroundTransparency = 1
    Page.ScrollBarThickness = 2
    Page.Visible = false
    Page.Parent = Container

    local PageList = Instance.new("UIListLayout")
    PageList.Padding = UDim.new(0, 6)
    PageList.SortOrder = Enum.SortOrder.LayoutOrder
    PageList.Parent = Page


    local PagePadding = Instance.new("UIPadding")
    PagePadding.PaddingBottom = UDim.new(0, 15)
    PagePadding.Parent = Page


    PageList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        Page.CanvasSize = UDim2.new(0, 0, 0, PageList.AbsoluteContentSize.Y + 20)
    end)

    if FirstTab then
        FirstTab = false
        Page.Visible = true
        TabBtn.TextColor3 = Theme.Text
        TabBtn.BackgroundColor3 = Theme.Accent
        table.insert(AccentElements, TabBtn)
    end

    TabBtn.MouseButton1Click:Connect(function()
        for _, t in pairs(Tabs) do
            t.Page.Visible = false
            t.Btn.TextColor3 = Theme.TextDark
            t.Btn.BackgroundColor3 = Theme.ElementBg
            local idx = table.find(AccentElements, t.Btn)
            if idx then table.remove(AccentElements, idx) end
        end
        Page.Visible = true
        TabBtn.TextColor3 = Theme.Text
        table.insert(AccentElements, TabBtn)
        TweenService:Create(TabBtn, TweenInfo.new(0.2), {BackgroundColor3 = Theme.Accent}):Play()
    end)

    table.insert(Tabs, {Page = Page, Btn = TabBtn})

    local Elements = {Page = Page}

    function Elements:AddSection(sectionTitle)
        local Label = Instance.new("TextLabel")
        Label.Text = string.upper(sectionTitle)
        Label.Size = UDim2.new(1, -5, 0, 20)
        Label.TextColor3 = Theme.TextDark
        Label.TextSize = 10
        Label.Font = Enum.Font.GothamBold
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Label.BackgroundTransparency = 1
        Label.Parent = Page
    end

    function Elements:AddWarning(warningText)
        local Frame = Instance.new("Frame")
        Frame.Size = UDim2.new(1, -5, 0, 48)
        Frame.BackgroundColor3 = Color3.fromRGB(45, 20, 20)
        Frame.BackgroundTransparency = Config.Transparency / 100
        Frame.Parent = Page
        table.insert(AllFrames, Frame)

        local FCorner = Instance.new("UICorner")
        FCorner.CornerRadius = UDim.new(0, Config.CornerRadius)
        FCorner.Parent = Frame
        table.insert(AllCorners, FCorner)

        local FStroke = Instance.new("UIStroke")
        FStroke.Thickness = 1
        FStroke.Color = Color3.fromRGB(220, 60, 60)
        FStroke.Parent = Frame

        local Label = Instance.new("TextLabel")
        Label.Text = warningText
        Label.Size = UDim2.new(1, -16, 1, 0)
        Label.Position = UDim2.fromOffset(8, 0)
        Label.TextColor3 = Color3.fromRGB(255, 130, 130)
        Label.TextSize = 10
        Label.Font = Enum.Font.GothamMedium
        Label.TextWrapped = true
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Label.BackgroundTransparency = 1
        Label.Parent = Frame
    end

    function Elements:AddInfo(label, value)
        local Frame = Instance.new("Frame")
        Frame.Size = UDim2.new(1, -5, 0, 32)
        Frame.BackgroundColor3 = Theme.ElementBg
        Frame.BackgroundTransparency = Config.Transparency / 100
        Frame.Parent = Page
        table.insert(AllFrames, Frame)

        local FCorner = Instance.new("UICorner")
        FCorner.CornerRadius = UDim.new(0, Config.CornerRadius)
        FCorner.Parent = Frame
        table.insert(AllCorners, FCorner)

        local Lbl = Instance.new("TextLabel")
        Lbl.Text = label
        Lbl.Size = UDim2.new(0.4, 0, 1, 0)
        Lbl.Position = UDim2.fromOffset(10, 0)
        Lbl.TextColor3 = Theme.TextDark
        Lbl.TextSize = 11
        Lbl.Font = Enum.Font.Gotham
        Lbl.TextXAlignment = Enum.TextXAlignment.Left
        Lbl.BackgroundTransparency = 1
        Lbl.Parent = Frame

        local Val = Instance.new("TextLabel")
        Val.Text = type(value) == "function" and value() or tostring(value)
        Val.Size = UDim2.new(0.6, -20, 1, 0)
        Val.Position = UDim2.new(0.4, 10, 0, 0)
        Val.TextColor3 = Theme.Text
        Val.TextSize = 11
        Val.Font = Enum.Font.GothamMedium
        Val.TextXAlignment = Enum.TextXAlignment.Right
        Val.BackgroundTransparency = 1
        Val.Parent = Frame

        if type(value) == "function" then
            task.spawn(function()
                while Frame and Frame.Parent do
                    pcall(function()
                        Val.Text = value()
                    end)
                    task.wait(0.5)
                end
            end)
        end
    end

    function Elements:AddButton(btnText, onClick)
        local Btn = Instance.new("TextButton")
        Btn.Size = UDim2.new(1, -5, 0, 32)
        Btn.BackgroundColor3 = Theme.ElementBg
        Btn.BackgroundTransparency = Config.Transparency / 100
        Btn.Text = btnText
        Btn.TextColor3 = Theme.Text
        Btn.TextSize = 11
        Btn.Font = Enum.Font.GothamMedium
        Btn.Parent = Page
        table.insert(AllFrames, Btn)

        local BCorner = Instance.new("UICorner")
        BCorner.CornerRadius = UDim.new(0, Config.CornerRadius)
        BCorner.Parent = Btn
        table.insert(AllCorners, BCorner)

        Btn.MouseButton1Click:Connect(function() if onClick then onClick() end end)
    end

    function Elements:AddToggle(toggleText, configKey, default, callback)
        local state = Config[configKey] ~= nil and Config[configKey] or (default or false)
        Config[configKey] = state

        local Frame = Instance.new("Frame")
        Frame.Size = UDim2.new(1, -5, 0, 36)
        Frame.BackgroundColor3 = Theme.ElementBg
        Frame.BackgroundTransparency = Config.Transparency / 100
        Frame.Parent = Page
        table.insert(AllFrames, Frame)

        local FCorner = Instance.new("UICorner")
        FCorner.CornerRadius = UDim.new(0, Config.CornerRadius)
        FCorner.Parent = Frame
        table.insert(AllCorners, FCorner)

        local Label = Instance.new("TextLabel")
        Label.Text = toggleText
        Label.Size = UDim2.new(1, -55, 1, 0)
        Label.Position = UDim2.fromOffset(10, 0)
        Label.TextColor3 = Theme.Text
        Label.TextSize = 11
        Label.Font = Enum.Font.Gotham
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Label.BackgroundTransparency = 1
        Label.Parent = Frame

        local Switch = Instance.new("TextButton")
        Switch.Size = UDim2.fromOffset(36, 18)
        Switch.Position = UDim2.new(1, -44, 0.5, -9)
        Switch.BackgroundColor3 = state and Theme.Accent or Theme.ToggleOff
        Switch.Text = ""
        Switch.Parent = Frame

        if state then table.insert(AccentElements, Switch) end

        local SCorner = Instance.new("UICorner")
        SCorner.CornerRadius = UDim.new(1, 0)
        SCorner.Parent = Switch

        local Circle = Instance.new("Frame")
        Circle.Size = UDim2.fromOffset(14, 14)
        Circle.Position = state and UDim2.fromOffset(20, 2) or UDim2.fromOffset(2, 2)
        Circle.BackgroundColor3 = Theme.Text
        Circle.Parent = Switch

        local CCorner = Instance.new("UICorner")
        CCorner.CornerRadius = UDim.new(1, 0)
        CCorner.Parent = Circle

        local function UpdateVisual(newState)
            state = newState
            Config[configKey] = state
            local targetPos = state and UDim2.fromOffset(20, 2) or UDim2.fromOffset(2, 2)
            local targetColor = state and Theme.Accent or Theme.ToggleOff

            if state then
                if not table.find(AccentElements, Switch) then
                    table.insert(AccentElements, Switch)
                end
            else
                local idx = table.find(AccentElements, Switch)
                if idx then table.remove(AccentElements, idx) end
            end

            TweenService:Create(Circle, TweenInfo.new(0.15), {Position = targetPos}):Play()
            TweenService:Create(Switch, TweenInfo.new(0.15), {BackgroundColor3 = targetColor}):Play()

            if callback then callback(state) end
        end

        table.insert(UIElementUpdaters, {
            Key = configKey,
            Update = UpdateVisual
        })

        Switch.MouseButton1Click:Connect(function()
            UpdateVisual(not state)
        end)

        if callback then callback(state) end
    end

    function Elements:AddSlider(sliderText, configKey, min, max, default, callback)
        local defaultVal = Config[configKey] ~= nil and Config[configKey] or (default or min)
        Config[configKey] = defaultVal

        local Frame = Instance.new("Frame")
        Frame.Size = UDim2.new(1, -5, 0, 45)
        Frame.BackgroundColor3 = Theme.ElementBg
        Frame.BackgroundTransparency = Config.Transparency / 100
        Frame.Parent = Page
        table.insert(AllFrames, Frame)

        local FCorner = Instance.new("UICorner")
        FCorner.CornerRadius = UDim.new(0, Config.CornerRadius)
        FCorner.Parent = Frame
        table.insert(AllCorners, FCorner)

        local Label = Instance.new("TextLabel")
        Label.Text = sliderText .. ": " .. tostring(defaultVal)
        Label.Size = UDim2.new(1, -20, 0, 20)
        Label.Position = UDim2.fromOffset(10, 2)
        Label.TextColor3 = Theme.Text
        Label.TextSize = 11
        Label.Font = Enum.Font.Gotham
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Label.BackgroundTransparency = 1
        Label.Parent = Frame

        local Track = Instance.new("Frame")
        Track.Size = UDim2.new(1, -20, 0, 6)
        Track.Position = UDim2.fromOffset(10, 28)
        Track.BackgroundColor3 = Theme.ToggleOff
        Track.Parent = Frame

        local TCorner = Instance.new("UICorner")
        TCorner.CornerRadius = UDim.new(1, 0)
        TCorner.Parent = Track

        local Fill = Instance.new("Frame")
        Fill.Size = UDim2.new((defaultVal - min) / (max - min), 0, 1, 0)
        Fill.BackgroundColor3 = Theme.Accent
        Fill.Parent = Track
        table.insert(AccentElements, Fill)

        local FCorner2 = Instance.new("UICorner")
        FCorner2.CornerRadius = UDim.new(1, 0)
        FCorner2.Parent = Fill

        local function SetSliderValue(val)
            val = math.clamp(val, min, max)
            Config[configKey] = val
            local pos = math.clamp((val - min) / (max - min), 0, 1)
            Fill.Size = UDim2.new(pos, 0, 1, 0)
            Label.Text = sliderText .. ": " .. tostring(val)
            if callback then callback(val) end
        end

        table.insert(UIElementUpdaters, {
            Key = configKey,
            Update = SetSliderValue
        })

        local sliding = false

        local function UpdateFromInput(input)
            local pos = math.clamp((input.Position.X - Track.AbsolutePosition.X) / Track.AbsoluteSize.X, 0, 1)
            local value = math.floor(min + (max - min) * pos)
            SetSliderValue(value)
        end

        Track.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                sliding = true
                UpdateFromInput(input)
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                UpdateFromInput(input)
            end
        end)

        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                sliding = false
            end
        end)

        if callback then callback(defaultVal) end
    end

    function Elements:AddColorPicker(pickerText, onSelect)
        local Frame = Instance.new("Frame")
        Frame.Size = UDim2.new(1, -5, 0, 36)
        Frame.BackgroundColor3 = Theme.ElementBg
        Frame.BackgroundTransparency = Config.Transparency / 100
        Frame.Parent = Page
        table.insert(AllFrames, Frame)

        local FCorner = Instance.new("UICorner")
        FCorner.CornerRadius = UDim.new(0, Config.CornerRadius)
        FCorner.Parent = Frame
        table.insert(AllCorners, FCorner)

        local Label = Instance.new("TextLabel")
        Label.Text = pickerText
        Label.Size = UDim2.new(1, -120, 1, 0)
        Label.Position = UDim2.fromOffset(10, 0)
        Label.TextColor3 = Theme.Text
        Label.TextSize = 11
        Label.Font = Enum.Font.Gotham
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Label.BackgroundTransparency = 1
        Label.Parent = Frame

        local Colors = {
            Color3.fromRGB(115, 80, 255),
            Color3.fromRGB(0, 162, 255),
            Color3.fromRGB(255, 65, 105),
            Color3.fromRGB(0, 220, 130)
        }

        for i, col in ipairs(Colors) do
            local Btn = Instance.new("TextButton")
            Btn.Size = UDim2.fromOffset(20, 20)
            Btn.Position = UDim2.new(1, -110 + (i * 24), 0.5, -10)
            Btn.BackgroundColor3 = col
            Btn.Text = ""
            Btn.Parent = Frame

            local CCorner = Instance.new("UICorner")
            CCorner.CornerRadius = UDim.new(1, 0)
            CCorner.Parent = Btn

            Btn.MouseButton1Click:Connect(function()
                if onSelect then onSelect(col) end
            end)
        end
    end

    function Elements:AddDropdown(dropdownText, configKey, options, defaultOption, callback)
        local selected = defaultOption or options[1]
        if configKey then
            Config[configKey] = Config[configKey] or selected
            selected = Config[configKey]
        end

        local isOpen = false
        local itemHeight = 26
        local headerHeight = 36
        local maxVisibleItems = 3
        
        local Frame = Instance.new("Frame")
        Frame.Size = UDim2.new(1, -5, 0, headerHeight)
        Frame.BackgroundColor3 = Theme.ElementBg
        Frame.BackgroundTransparency = Config.Transparency / 100
        Frame.ClipsDescendants = true
        Frame.Parent = Page
        table.insert(AllFrames, Frame)

        local FCorner = Instance.new("UICorner")
        FCorner.CornerRadius = UDim.new(0, Config.CornerRadius)
        FCorner.Parent = Frame
        table.insert(AllCorners, FCorner)

        local Label = Instance.new("TextLabel")
        Label.Text = dropdownText .. ": " .. tostring(selected)
        Label.Size = UDim2.new(1, -40, 0, headerHeight)
        Label.Position = UDim2.fromOffset(10, 0)
        Label.TextColor3 = Theme.Text
        Label.TextSize = 11
        Label.Font = Enum.Font.Gotham
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Label.BackgroundTransparency = 1
        Label.Parent = Frame

        local Arrow = Instance.new("TextLabel")
        Arrow.Text = "▼"
        Arrow.Size = UDim2.fromOffset(20, 20)
        Arrow.Position = UDim2.new(1, -25, 0, 8)
        Arrow.TextColor3 = Theme.TextDark
        Arrow.TextSize = 10
        Arrow.BackgroundTransparency = 1
        Arrow.Parent = Frame

        local DropContainer = Instance.new("ScrollingFrame")
        DropContainer.Size = UDim2.new(1, -10, 0, 0)
        DropContainer.Position = UDim2.fromOffset(5, headerHeight)
        DropContainer.BackgroundTransparency = 1
        DropContainer.BorderSizePixel = 0
        DropContainer.ScrollBarThickness = 3
        DropContainer.Parent = Frame

        local DropList = Instance.new("UIListLayout")
        DropList.Padding = UDim.new(0, 2)
        DropList.SortOrder = Enum.SortOrder.LayoutOrder
        DropList.Parent = DropContainer

        DropList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            DropContainer.CanvasSize = UDim2.new(0, 0, 0, DropList.AbsoluteContentSize.Y)
        end)

        local function RefreshDropdownOptions(newOpts)
            options = newOpts
            for _, child in ipairs(DropContainer:GetChildren()) do
                if child:IsA("TextButton") then child:Destroy() end
            end

            if #options == 0 then
                local EmptyLbl = Instance.new("TextButton")
                EmptyLbl.Size = UDim2.new(1, 0, 0, itemHeight)
                EmptyLbl.BackgroundColor3 = Theme.Header
                EmptyLbl.Text = "Нет элементов"
                EmptyLbl.TextColor3 = Theme.TextDark
                EmptyLbl.TextSize = 10
                EmptyLbl.Font = Enum.Font.Gotham
                EmptyLbl.Parent = DropContainer
                return
            end

            for _, option in ipairs(options) do
                local OptBtn = Instance.new("TextButton")
                OptBtn.Size = UDim2.new(1, 0, 0, itemHeight)
                OptBtn.BackgroundColor3 = Theme.Header
                OptBtn.BackgroundTransparency = Config.Transparency / 100
                OptBtn.Text = tostring(option)
                OptBtn.TextColor3 = (option == selected) and Theme.Accent or Theme.Text
                OptBtn.TextSize = 10
                OptBtn.Font = Enum.Font.GothamMedium
                OptBtn.Parent = DropContainer

                local OCorner = Instance.new("UICorner")
                OCorner.CornerRadius = UDim.new(0, 4)
                OCorner.Parent = OptBtn

                OptBtn.MouseButton1Click:Connect(function()
                    selected = option
                    if configKey then Config[configKey] = selected end
                    Label.Text = dropdownText .. ": " .. tostring(selected)
                    
                    isOpen = false
                    TweenService:Create(Frame, TweenInfo.new(0.2), {Size = UDim2.new(1, -5, 0, headerHeight)}):Play()
                    Arrow.Rotation = 0

                    for _, child in ipairs(DropContainer:GetChildren()) do
                        if child:IsA("TextButton") then
                            child.TextColor3 = (child.Text == tostring(selected)) and Theme.Accent or Theme.Text
                        end
                    end

                    if callback then callback(selected) end
                end)
            end
        end

        RefreshDropdownOptions(options)

        local ToggleBtn = Instance.new("TextButton")
        ToggleBtn.Size = UDim2.new(1, 0, 0, headerHeight)
        ToggleBtn.BackgroundTransparency = 1
        ToggleBtn.Text = ""
        ToggleBtn.Parent = Frame

        ToggleBtn.MouseButton1Click:Connect(function()
            isOpen = not isOpen
            local count = math.clamp(#options, 1, maxVisibleItems)
            local contentHeight = count * itemHeight + ((#options > 0) and 4 or 0)
            local targetHeight = isOpen and (headerHeight + contentHeight + 4) or headerHeight
            
            if isOpen then
                DropContainer.Size = UDim2.new(1, -10, 0, contentHeight)
            end

            TweenService:Create(Frame, TweenInfo.new(0.2), {Size = UDim2.new(1, -5, 0, targetHeight)}):Play()
            Arrow.Rotation = isOpen and 180 or 0
        end)

        return {
            Frame = Frame,
            Refresh = RefreshDropdownOptions,
            GetSelected = function() return selected end
        }
    end

    return Elements
end

---------------------------------------------------------
-- 1. ВКЛАДКА "ИНФО" 
---------------------------------------------------------
local InfoTab = Hub:CreateTab("Инфо", 1)
InfoTab:AddSection("Информация о сессии")

InfoTab:AddInfo("Игрок:", LocalPlayer.Name)

local executorName = "Неизвестен"
if identifyexecutor then
    executorName = identifyexecutor()
elseif getexecutorname then
    executorName = getexecutorname()
end
InfoTab:AddInfo("Инжектор:", executorName)

InfoTab:AddInfo("Плейс ID:", tostring(game.PlaceId))

local placeNameText = "Загрузка..."
InfoTab:AddInfo("Название плейса:", function()
    return placeNameText
end)

task.spawn(function()
    pcall(function()
        local info = MarketplaceService:GetProductInfo(game.PlaceId)
        if info and info.Name then
            placeNameText = info.Name
        else
            placeNameText = "Не удалось загрузить"
        end
    end)
end)

InfoTab:AddSection("Диагностика сети и железа")

InfoTab:AddInfo("FPS:", function()
    local fps = 0
    pcall(function()
        fps = math.floor(1 / RunService.RenderStepped:Wait())
    end)
    return tostring(fps)
end)

InfoTab:AddInfo("Пинг (Ms):", function()
    local ping = 0
    pcall(function()
        local network = Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
        ping = math.floor(network)
    end)
    return ping .. " ms"
end)

InfoTab:AddSection("Ссылки и сообщество")

InfoTab:AddButton("Telegram: @BloxyScripts", function()
    pcall(function()
        if setclipboard then
            setclipboard("https://t.me/BloxyScripts")
        end
    end)
    
    local Notif = Instance.new("TextLabel")
    Notif.Size = UDim2.new(0, 260, 0, 35)
    Notif.Position = UDim2.new(0.5, -130, 0.85, 0)
    Notif.BackgroundColor3 = Theme.Header
    Notif.TextColor3 = Theme.Text
    Notif.TextSize = 11
    Notif.Font = Enum.Font.GothamBold
    Notif.Text = "Ссылка скопирована в буфер обмена!"
    Notif.BackgroundTransparency = 0.2
    Notif.Parent = ScreenGui
    
    local NC = Instance.new("UICorner")
    NC.CornerRadius = UDim.new(0, 8)
    NC.Parent = Notif
    
    task.delay(2, function()
        if Notif then Notif:Destroy() end
    end)
end)

---------------------------------------------------------
-- ФУНКЦИИ ФЛИНГА И АНТИФЛИНГА
---------------------------------------------------------
local FlingEnabled = false
local AntiFlingEnabled = false
local IsFlinging = false

RunService.Stepped:Connect(function()
    if not AntiFlingEnabled then return end
    
    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    
    if myRoot then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                for _, part in ipairs(p.Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end
    end
end)

local function ExecuteFling(targetPlayer)
    if IsFlinging or not targetPlayer or not targetPlayer.Character then return end
    
    local myChar = LocalPlayer.Character
    local targetChar = targetPlayer.Character
    
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
    
    if not myRoot or not targetRoot then return end
    
    IsFlinging = true
    local savedCFrame = myRoot.CFrame + Vector3.new(0, 3, 0)
    
    local originalCollisions = {}
    for _, part in ipairs(myChar:GetDescendants()) do
        if part:IsA("BasePart") then
            originalCollisions[part] = part.CanCollide
            part.CanCollide = false
        end
    end

    workspace.CurrentCamera.CameraSubject = targetRoot
    
    local connection
    local angle = 0
    connection = RunService.Heartbeat:Connect(function()
        if not IsFlinging or not myRoot or not targetRoot or not targetRoot.Parent then return end
        
        angle = angle + 150
        myRoot.CFrame = targetRoot.CFrame * CFrame.Angles(0, math.rad(angle), 0) * CFrame.new(0, -0.5, 0)
        myRoot.AssemblyAngularVelocity = Vector3.new(99999, 99999, 99999)
        myRoot.AssemblyLinearVelocity = Vector3.new(99999, 99999, 99999)
    end)
    
    task.wait(0.3)
    
    if connection then connection:Disconnect() end

    if myRoot then
        myRoot.AssemblyAngularVelocity = Vector3.zero
        myRoot.AssemblyLinearVelocity = Vector3.zero
    end

    for part, canCollide in pairs(originalCollisions) do
        if part and part.Parent then
            part.CanCollide = canCollide
        end
    end

    if myRoot then
        myRoot.CFrame = savedCFrame
        myRoot.AssemblyLinearVelocity = Vector3.zero
        myRoot.AssemblyAngularVelocity = Vector3.zero
    end

    local hum = myChar:FindFirstChild("Humanoid")
    if hum then
        workspace.CurrentCamera.CameraSubject = hum
    end
    
    task.wait(0.1)
    IsFlinging = false
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not FlingEnabled or gameProcessed or IsFlinging then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        local mouse = LocalPlayer:GetMouse()
        local target = mouse.Target
        if target and target.Parent then
            local targetChar = target.Parent:IsA("Model") and target.Parent or target.Parent.Parent
            local targetPlayer = Players:GetPlayerFromCharacter(targetChar)
            
            if targetPlayer and targetPlayer ~= LocalPlayer then
                task.spawn(function()
                    ExecuteFling(targetPlayer)
                end)
            end
        end
    end
end)

---------------------------------------------------------
-- МОДУЛЬ NOCLIP
---------------------------------------------------------
local NoclipEnabled = false

RunService.Stepped:Connect(function()
    if not NoclipEnabled then return end
    
    local char = LocalPlayer.Character
    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
end)

---------------------------------------------------------
-- МОДУЛЬ ПОЛЕТА (FLY) 
---------------------------------------------------------
local FlyEnabled = false
local FlySpeed = 50
local flyConnection

local function StartFly()
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not root or not hum then return end

    hum.PlatformStand = true

    local att = Instance.new("Attachment")
    att.Name = "HubFlyAttachment"
    att.Parent = root

    -- Линейная скорость для перемещения
    local linearVel = Instance.new("LinearVelocity")
    linearVel.Name = "HubFlyVelocity"
    linearVel.Attachment0 = att
    linearVel.MaxForce = math.huge
    linearVel.VectorVelocity = Vector3.zero
    linearVel.RelativeTo = Enum.ActuatorRelativeTo.World
    linearVel.Parent = root

    local alignOrient = Instance.new("AlignOrientation")
    alignOrient.Name = "HubFlyOrientation"
    alignOrient.Attachment0 = att
    alignOrient.Mode = Enum.OrientationAlignmentMode.OneAttachment
    alignOrient.MaxTorque = math.huge
    alignOrient.Responsiveness = 500 
    alignOrient.RigidityEnabled = true 
    alignOrient.Parent = root

    flyConnection = RunService.RenderStepped:Connect(function()
        if not FlyEnabled or not root or not root.Parent then return end
        
        local cam = workspace.CurrentCamera
        local moveDir = Vector3.zero

        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir += cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir -= cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir -= cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir += cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir += Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir -= Vector3.new(0, 1, 0) end

        if linearVel and alignOrient then
            linearVel.VectorVelocity = moveDir.Magnitude > 0 and moveDir.Unit * FlySpeed or Vector3.zero
            alignOrient.CFrame = cam.CFrame
        end
    end)
end

local function StopFly()
    if flyConnection then
        flyConnection:Disconnect()
        flyConnection = nil
    end

    local char = LocalPlayer.Character
    if char then
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then
            local lv = root:FindFirstChild("HubFlyVelocity")
            local ao = root:FindFirstChild("HubFlyOrientation")
            local att = root:FindFirstChild("HubFlyAttachment")
            if lv then lv:Destroy() end
            if ao then ao:Destroy() end
            if att then att:Destroy() end
        end

        local hum = char:FindFirstChild("Humanoid")
        if hum then 
            hum.PlatformStand = false 
        end
    end
end

---------------------------------------------------------
-- ПОСТОЯННЫЙ ОБХОД СБРОСА СКОРОСТИ И ПРЫЖКА
---------------------------------------------------------
RunService.Heartbeat:Connect(function()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChild("Humanoid")
    if hum then
        if Config.WalkSpeed and hum.WalkSpeed ~= Config.WalkSpeed then
            hum.WalkSpeed = Config.WalkSpeed
        end
        if Config.JumpPower then
            hum.UseJumpPower = true
            if hum.JumpPower ~= Config.JumpPower then
                hum.JumpPower = Config.JumpPower
            end
        end
    end
end)

---------------------------------------------------------
-- 2. ВКЛАДКА "ОСНОВНОЕ" 
---------------------------------------------------------
local UniversalTab = Hub:CreateTab("Основное", 2)

UniversalTab:AddWarning("⚠️ ВНИМАНИЕ: Это основные функции скрипта которые будует присутствовать везде. Использование на серверах с античитом приведет к кику или бану!")

UniversalTab:AddSection("Управление персонажем")

UniversalTab:AddToggle("Включить Полет (Fly)", "FlyEnabled", false, function(state)
    FlyEnabled = state
    if state then
        StartFly()
    else
        StopFly()
    end
end)

UniversalTab:AddSlider("Скорость полета", "FlySpeed", 16, 200, 50, function(val)
    FlySpeed = val
end)

UniversalTab:AddToggle("Включить NoClip", "NoclipEnabled", false, function(state)
    NoclipEnabled = state
end)

UniversalTab:AddSlider("WalkSpeed", "WalkSpeed", 16, 120, 16, function(val)
    Config.WalkSpeed = val
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChild("Humanoid")
    if hum then
        hum.WalkSpeed = val
    end
end)

UniversalTab:AddSlider("JumpPower", "JumpPower", 50, 250, 50, function(val)
    Config.JumpPower = val
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChild("Humanoid")
    if hum then
        hum.UseJumpPower = true
        hum.JumpPower = val
    end
end)


UniversalTab:AddSection("Флинг функции")

UniversalTab:AddToggle("Включить Флинг по клику", "FlingClick", false, function(state)
    FlingEnabled = state
end)

UniversalTab:AddToggle("Анти-флинг", "AntiFling", false, function(state)
    AntiFlingEnabled = state
end)

UniversalTab:AddSection("💤 Утилиты")
UniversalTab:AddToggle("Anti-AFK", false, function(state)
    if state then
        local vu = game:GetService("VirtualUser")
        getgenv().AntiAfkConnection = game:GetService("Players").LocalPlayer.Idled:Connect(function()
            vu:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            task.wait(1)
            vu:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        end)
        print("[BloxyScripts]: Anti-AFK активирован")
    else
        if getgenv().AntiAfkConnection then
            getgenv().AntiAfkConnection:Disconnect()
            getgenv().AntiAfkConnection = nil
        end
        print("[BloxyScripts]: Anti-AFK деактивирован")
    end
end)

---------------------------------------------------------
-- 4. ВКЛАДКА "НАСТРОЙКИ" 
---------------------------------------------------------
local SettingsTab = Hub:CreateTab("Настройки", 99)

SettingsTab:AddSection("Кастомизация")

SettingsTab:AddColorPicker("Цвет акцента", function(newColor)
    Config.AccentColorR = math.floor(newColor.R * 255)
    Config.AccentColorG = math.floor(newColor.G * 255)
    Config.AccentColorB = math.floor(newColor.B * 255)
    ApplyConfig()
end)

SettingsTab:AddSlider("Прозрачность", "Transparency", 0, 90, Config.Transparency, function(val)
    Config.Transparency = val
    ApplyConfig()
end)

SettingsTab:AddSlider("Скругление углов", "CornerRadius", 0, 20, Config.CornerRadius, function(val)
    Config.CornerRadius = val
    ApplyConfig()
end)

SettingsTab:AddSection("Управление конфигами")

local ConfigInputFrame = Instance.new("Frame")
ConfigInputFrame.Size = UDim2.new(1, -5, 0, 32)
ConfigInputFrame.BackgroundColor3 = Theme.ElementBg
ConfigInputFrame.BackgroundTransparency = Config.Transparency / 100
ConfigInputFrame.Parent = SettingsTab.Page
table.insert(AllFrames, ConfigInputFrame)

local CInputCorner = Instance.new("UICorner")
CInputCorner.CornerRadius = UDim.new(0, Config.CornerRadius)
CInputCorner.Parent = ConfigInputFrame
table.insert(AllCorners, CInputCorner)

local ConfigTextBox = Instance.new("TextBox")
ConfigTextBox.Size = UDim2.new(1, -20, 1, 0)
ConfigTextBox.Position = UDim2.fromOffset(10, 0)
ConfigTextBox.PlaceholderText = "Введите имя файла для сохранения..."
ConfigTextBox.Text = ""
ConfigTextBox.TextColor3 = Theme.Text
ConfigTextBox.PlaceholderColor3 = Theme.TextDark
ConfigTextBox.Font = Enum.Font.Gotham
ConfigTextBox.TextSize = 11
ConfigTextBox.BackgroundTransparency = 1
ConfigTextBox.TextXAlignment = Enum.TextXAlignment.Left
ConfigTextBox.Parent = ConfigInputFrame

local function GetSavedConfigFiles()
    local filesList = {}
    if listfiles then
        local success, files = pcall(function() return listfiles(ConfigFolder) end)
        if success and files then
            for _, path in ipairs(files) do
                local name = path:match("[^/\\]+$")
                if name and name:find("%.json$") then
                    table.insert(filesList, name)
                end
            end
        end
    end
    if #filesList == 0 then
        table.insert(filesList, "default.json")
    end
    return filesList
end

local dropdownFiles = GetSavedConfigFiles()
local configDropdownController

local function LoadFile(fileName)
    if not readfile or not isfile then return end
    local filePath = ConfigFolder .. "/" .. fileName
    if isfile(filePath) then
        local success, result = pcall(function()
            return HttpService:JSONDecode(readfile(filePath))
        end)
        if success and type(result) == "table" then
            for k, v in pairs(result) do
                Config[k] = v
            end
            ApplyConfig()
            
            for _, updater in ipairs(UIElementUpdaters) do
                if result[updater.Key] ~= nil then
                    updater.Update(result[updater.Key])
                end
            end
        end
    end
end

local function SaveFile(fileName)
    if not writefile then return end
    if fileName == "" then return end
    if not fileName:find("%.json$") then fileName = fileName .. ".json" end
    
    local filePath = ConfigFolder .. "/" .. fileName
    local jsonStr = HttpService:JSONEncode(Config)
    writefile(filePath, jsonStr)
end

local function DeleteFile(fileName)
    if not delfile or not isfile then return end
    if not fileName or fileName == "" then return end
    
    local filePath = ConfigFolder .. "/" .. fileName
    if isfile(filePath) then
        pcall(function()
            delfile(filePath)
        end)
    end
end

configDropdownController = SettingsTab:AddDropdown("Выбрать конфиг", "SelectedConfigTarget", dropdownFiles, dropdownFiles[1], function(selectedFile)
    if selectedFile and selectedFile ~= "Нет элементов" then
        LoadFile(selectedFile)
    end
end)

SettingsTab:AddButton("Сохранить текущий конфиг", function()
    local name = ConfigTextBox.Text
    if name ~= "" then
        SaveFile(name)
        ConfigTextBox.Text = ""
        local updatedList = GetSavedConfigFiles()
        if configDropdownController and configDropdownController.Refresh then
            configDropdownController.Refresh(updatedList)
        end
    end
end)


SettingsTab:AddButton("Удалить выбранный конфиг", function()
    if configDropdownController and configDropdownController.GetSelected then
        local selectedFile = configDropdownController.GetSelected()
        if selectedFile and selectedFile ~= "Нет элементов" then
            DeleteFile(selectedFile)
            local updatedList = GetSavedConfigFiles()
            configDropdownController.Refresh(updatedList)
            -- Автоматически загружаем первый доступный конфиг после удаления
            if updatedList[1] then
                LoadFile(updatedList[1])
            end
        end
    end
end)

SettingsTab:AddButton("Обновить список конфигов", function()
    local updatedList = GetSavedConfigFiles()
    if configDropdownController and configDropdownController.Refresh then
        configDropdownController.Refresh(updatedList)
    end
end)

if isfile and isfile(ConfigFolder .. "/" .. DefaultConfigName) then
    LoadFile(DefaultConfigName)
end

---------------------------------------------------------
-- АНИМАЦИЯ ПОЯВЛЕНИЯ
---------------------------------------------------------
task.spawn(function()
    TweenService:Create(LoadingBarFill, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(1, 0, 1, 0)}):Play()
    task.wait(1.1)
    
    TweenService:Create(SplashFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()
    task.wait(0.3)
    
    SplashFrame:Destroy()
    Main.Visible = true
end)
