-- // Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

-- // LocalPlayer
local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait()

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "XuosMainUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local ESP_Settings = {
    Box = false,
    Name = false,
    Distance = false }

local CamSettings = {
    Enabled = false,
    Smoothness = 0.1,
    Prediction = 0.1,
    AimPart = "Head"
}
local LockSettings = {
    Enabled = false,
    AimPart = "Head"
}

local Colors = {
    Background = Color3.fromRGB(240, 248, 255),       
    Sidebar = Color3.fromRGB(215, 233, 252),          
    Text = Color3.fromRGB(70, 110, 150),              
    AccentBlue = Color3.fromRGB(130, 180, 240),        
    ButtonBackground = Color3.fromRGB(230, 235, 240),  
    DropdownBg = Color3.fromRGB(225, 240, 255)
}

local MainFont = Enum.Font.FredokaOne

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 580, 0, 380)
MainFrame.Position = UDim2.new(0.5, -290, 0.5, -190)
MainFrame.BackgroundColor3 = Colors.Background
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 16)
MainCorner.Parent = MainFrame

local dragging, dragInput, dragStart, startPos
local function updateDrag(input)
    local delta = input.Position - dragStart
    MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end
MainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
MainFrame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then updateDrag(input) end
end)

local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.Size = UDim2.new(0, 160, 1, 0)
Sidebar.BackgroundColor3 = Colors.Sidebar
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainFrame

local SidebarCorner = Instance.new("UICorner")
SidebarCorner.CornerRadius = UDim.new(0, 16)
SidebarCorner.Parent = Sidebar

local CornerFix = Instance.new("Frame")
CornerFix.Size = UDim2.new(0, 20, 1, 0)
CornerFix.Position = UDim2.new(1, -20, 0, 0)
CornerFix.BackgroundColor3 = Colors.Sidebar
CornerFix.BorderSizePixel = 0
CornerFix.Parent = Sidebar

local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Size = UDim2.new(1, -20, 0, 50)
Title.Position = UDim2.new(0, 15, 0, 10)
Title.BackgroundTransparency = 1
Title.Text = "xuos main"
Title.TextColor3 = Colors.Text
Title.TextSize = 26
Title.Font = MainFont
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Sidebar

local NavContainer = Instance.new("Frame")
NavContainer.Name = "NavContainer"
NavContainer.Size = UDim2.new(1, -20, 1, -80)
NavContainer.Position = UDim2.new(0, 10, 0, 70)
NavContainer.BackgroundTransparency = 1
NavContainer.Parent = Sidebar

local NavLayout = Instance.new("UIListLayout")
NavLayout.Padding = UDim.new(0, 8)
NavLayout.Parent = NavContainer

local PageContainer = Instance.new("Frame")
PageContainer.Name = "PageContainer"
PageContainer.Size = UDim2.new(1, -180, 1, -60)
PageContainer.Position = UDim2.new(0, 175, 0, 55)
PageContainer.BackgroundTransparency = 1
PageContainer.Parent = MainFrame

local WelcomeLabel = Instance.new("TextLabel")
WelcomeLabel.Name = "WelcomeLabel"
WelcomeLabel.Size = UDim2.new(1, -20, 0, 40)
WelcomeLabel.Position = UDim2.new(0, 175, 0, 15)
WelcomeLabel.BackgroundTransparency = 1
WelcomeLabel.Text = "Hello, " .. LocalPlayer.Name
WelcomeLabel.TextColor3 = Colors.Text
WelcomeLabel.TextSize = 24
WelcomeLabel.Font = MainFont
WelcomeLabel.TextXAlignment = Enum.TextXAlignment.Left
WelcomeLabel.Parent = MainFrame

local MenuToggleButton = Instance.new("TextButton")
MenuToggleButton.Name = "MenuToggleButton"
MenuToggleButton.Size = UDim2.new(0, 60, 0, 30)
MenuToggleButton.Position = UDim2.new(0, 10, 0, 10)
MenuToggleButton.BackgroundColor3 = Colors.Sidebar
MenuToggleButton.Text = "Xuos"
MenuToggleButton.TextColor3 = Colors.Text
MenuToggleButton.Font = MainFont
MenuToggleButton.TextSize = 14
MenuToggleButton.Parent = ScreenGui

local MTBCorner = Instance.new("UICorner")
MTBCorner.CornerRadius = UDim.new(0, 8)
MTBCorner.Parent = MenuToggleButton

MenuToggleButton.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.RightControl then
        MainFrame.Visible = not MainFrame.Visible
    end
end)

local Pages = {}
local FirstPage = nil

local function CreatePage(name)
    local Page = Instance.new("ScrollingFrame")
    Page.Name = name .. "Page"
    Page.Size = UDim2.new(1, 0, 1, 0)
    Page.BackgroundTransparency = 1
    Page.CanvasSize = UDim2.new(0, 0, 0, 0)
    Page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Page.ScrollBarThickness = 2
    Page.ScrollBarImageColor3 = Colors.AccentBlue
    Page.Visible = false
    Page.Parent = PageContainer

    local PageLayout = Instance.new("UIListLayout")
    PageLayout.Padding = UDim.new(0, 12)
    PageLayout.Parent = Page

    local Header = Instance.new("TextLabel")
    Header.Size = UDim2.new(1, 0, 0, 25)
    Header.BackgroundTransparency = 1
    Header.Text = name .. " settings"
    Header.TextColor3 = Colors.Text
    Header.TextSize = 16
    Header.Font = MainFont
    Header.TextXAlignment = Enum.TextXAlignment.Left
    Header.Parent = Page

    local Line = Instance.new("Frame")
    Line.Size = UDim2.new(1, -10, 0, 1)
    Line.BackgroundColor3 = Colors.Sidebar
    Line.BorderSizePixel = 0
    Line.Parent = Page

    local TabButton = Instance.new("TextButton")
    TabButton.Size = UDim2.new(1, 0, 0, 35)
    TabButton.BackgroundColor3 = Colors.Background
    TabButton.BackgroundTransparency = 1
    TabButton.Text = name
    TabButton.TextColor3 = Colors.Text
    TabButton.TextSize = 14
    TabButton.Font = MainFont
    TabButton.TextXAlignment = Enum.TextXAlignment.Left
    TabButton.Parent = NavContainer

    local TabPadding = Instance.new("UIPadding")
    TabPadding.PaddingLeft = UDim.new(0, 12)
    TabPadding.Parent = TabButton

    local TabCorner = Instance.new("UICorner")
    TabCorner.CornerRadius = UDim.new(0, 8)
    TabCorner.Parent = TabButton

    if not FirstPage then
        FirstPage = Page
        Page.Visible = true
        TabButton.BackgroundTransparency = 0
    end

    TabButton.MouseButton1Click:Connect(function()
        for _, p in pairs(PageContainer:GetChildren()) do
            if p:IsA("ScrollingFrame") then p.Visible = false end
        end
        for _, btn in pairs(NavContainer:GetChildren()) do
            if btn:IsA("TextButton") then btn.BackgroundTransparency = 1 end
        end
        Page.Visible = true
        TabButton.BackgroundTransparency = 0
    end)

    return Page
end

local Elements = {}

function Elements.AddToggle(page, text, default, keybind, callback)
    local Toggled = default or false

    local ToggleFrame = Instance.new("Frame")
    ToggleFrame.Size = UDim2.new(1, -10, 0, 30)
    ToggleFrame.BackgroundTransparency = 1
    ToggleFrame.Parent = page

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(0, 250, 1, 0)
    Label.BackgroundTransparency = 1
    Label.Text = text .. (keybind and " [" .. keybind.Name .. "]" or "")
    Label.TextColor3 = Colors.Text
    Label.TextSize = 14
    Label.Font = MainFont
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = ToggleFrame

    local Button = Instance.new("TextButton")
    Button.Size = UDim2.new(0, 50, 0, 22)
    Button.Position = UDim2.new(1, -55, 0.5, -11)
    Button.BackgroundColor3 = Toggled and Colors.AccentBlue or Colors.ButtonBackground
    Button.Text = Toggled and "ON" or "OFF"
    Button.TextColor3 = Toggled and Color3.new(1,1,1) or Color3.fromRGB(130,130,130)
    Button.Font = MainFont
    Button.TextSize = 10
    Button.Parent = ToggleFrame

    local BtnCorner = Instance.new("UICorner")
    BtnCorner.CornerRadius = UDim.new(0, 6)
    BtnCorner.Parent = Button

    local function fireToggle()
        Toggled = not Toggled
        Button.Text = Toggled and "ON" or "OFF"
        
        TweenService:Create(Button, TweenInfo.new(0.2), {
            BackgroundColor3 = Toggled and Colors.AccentBlue or Colors.ButtonBackground,
            TextColor3 = Toggled and Color3.new(1,1,1) or Color3.fromRGB(130,130,130)
        }):Play()

        callback(Toggled)
    end

    Button.MouseButton1Click:Connect(fireToggle)

    if keybind then
        UserInputService.InputBegan:Connect(function(input, processed)
            if not processed and input.KeyCode == keybind then
                fireToggle()
            end
        end)
    end
end

function Elements.AddSlider(page, text, min, max, default, callback)
    local SliderFrame = Instance.new("Frame")
    SliderFrame.Size = UDim2.new(1, -10, 0, 45)
    SliderFrame.BackgroundTransparency = 1
    SliderFrame.Parent = page

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, 0, 0, 20)
    Label.BackgroundTransparency = 1
    Label.Text = text .. ": " .. tostring(default)
    Label.TextColor3 = Colors.Text
    Label.TextSize = 14
    Label.Font = MainFont
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = SliderFrame

    local Track = Instance.new("Frame")
    Track.Size = UDim2.new(1, -10, 0, 4)
    Track.Position = UDim2.new(0, 0, 0, 28)
    Track.BackgroundColor3 = Colors.ButtonBackground
    Track.BorderSizePixel = 0
    Track.Parent = SliderFrame

    local Fill = Instance.new("Frame")
    Fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    Fill.BackgroundColor3 = Colors.AccentBlue
    Fill.BorderSizePixel = 0
    Fill.Parent = Track

    local Knob = Instance.new("ImageButton")
    Knob.Size = UDim2.new(0, 12, 0, 12)
    Knob.Position = UDim2.new((default - min) / (max - min), -6, 0.5, -6)
    Knob.BackgroundColor3 = Colors.AccentBlue
    Knob.BorderSizePixel = 0
    Knob.Parent = Track

    local KnobCorner = Instance.new("UICorner")
    KnobCorner.CornerRadius = UDim.new(1, 0)
    KnobCorner.Parent = Knob

    local draggingSlider = false

    local function update(input)
        local pos = math.clamp((input.Position.X - Track.AbsolutePosition.X) / Track.AbsoluteSize.X, 0, 1)
        local value = math.floor(min + (max - min) * pos)
        
        Knob.Position = UDim2.new(pos, -6, 0.5, -6)
        Fill.Size = UDim2.new(pos, 0, 1, 0)
        Label.Text = text .. ": " .. tostring(value)
        
        callback(value)
    end

    Knob.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingSlider = true
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingSlider = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            update(input)
        end
    end)
end

function Elements.AddDropdown(page, text, list, default, callback)
    local DropdownFrame = Instance.new("Frame")
    DropdownFrame.Size = UDim2.new(1, -10, 0, 35)
    DropdownFrame.BackgroundTransparency = 1
    DropdownFrame.ZIndex = 5
    DropdownFrame.Parent = page

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(0, 150, 1, 0)
    Label.BackgroundTransparency = 1
    Label.Text = text
    Label.TextColor3 = Colors.Text
    Label.TextSize = 14
    Label.Font = MainFont
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = DropdownFrame

    local MainButton = Instance.new("TextButton")
    MainButton.Size = UDim2.new(0, 140, 0, 26)
    MainButton.Position = UDim2.new(1, -145, 0.5, -13)
    MainButton.BackgroundColor3 = Colors.Sidebar
    MainButton.Text = default or "Select..."
    MainButton.TextColor3 = Colors.Text
    MainButton.Font = MainFont
    MainButton.TextSize = 12
    MainButton.Parent = DropdownFrame

    local MBCorner = Instance.new("UICorner")
    MBCorner.CornerRadius = UDim.new(0, 6)
    MBCorner.Parent = MainButton

    local ItemList = Instance.new("Frame")
    ItemList.Size = UDim2.new(1, 0, 0, #list * 25)
    ItemList.Position = UDim2.new(0, 0, 1, 2)
    ItemList.BackgroundColor3 = Colors.DropdownBg
    ItemList.BorderSizePixel = 0
    ItemList.Visible = false
    ItemList.ZIndex = 10
    ItemList.Parent = MainButton

    local ILCorner = Instance.new("UICorner")
    ILCorner.CornerRadius = UDim.new(0, 6)
    ILCorner.Parent = ItemList

    local ILList = Instance.new("UIListLayout")
    ILList.Parent = ItemList

    for _, val in pairs(list) do
        local Item = Instance.new("TextButton")
        Item.Size = UDim2.new(1, 0, 0, 25)
        Item.BackgroundTransparency = 1
        Item.Text = val
        Item.TextColor3 = Colors.Text
        Item.Font = MainFont
        Item.TextSize = 11
        Item.ZIndex = 11
        Item.Parent = ItemList

        Item.MouseButton1Click:Connect(function()
            MainButton.Text = val
            ItemList.Visible = false
            callback(val)
        end)
    end

    MainButton.MouseButton1Click:Connect(function()
        ItemList.Visible = not ItemList.Visible
    end)
end
function Elements.AddButton(page, text, callback)
    local ButtonFrame = Instance.new("Frame")
    ButtonFrame.Size = UDim2.new(1, -10, 0, 35)
    ButtonFrame.BackgroundTransparency = 1
    ButtonFrame.Parent = page

    local ClickButton = Instance.new("TextButton")
    ClickButton.Size = UDim2.new(1, 0, 1, 0)
    ClickButton.BackgroundColor3 = Colors.Sidebar
    ClickButton.Text = text
    ClickButton.TextColor3 = Colors.Text
    ClickButton.Font = MainFont
    ClickButton.TextSize = 14
    ClickButton.Parent = ButtonFrame

    local BtnCorner = Instance.new("UICorner")
    BtnCorner.CornerRadius = UDim.new(0, 8)
    BtnCorner.Parent = ClickButton

    ClickButton.MouseButton1Click:Connect(callback)
end
local ESPPage = CreatePage("ESP")
local SpeedPage = CreatePage("Speed")
local MiscPage = CreatePage("Teleport")
local lockPage = CreatePage("Lock")

Elements.AddButton(SpeedPage, "Walkspeed/Jump Power UI", function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/hwvahsha-prog/e/refs/heads/main/abacktools-obfuscated.lua"))()
    print("Walkspeed Loaded:")
end)

Elements.AddDropdown(lockPage, "Aim Part", {"Head", "HumanoidRootPart"}, "Head", function(selected)
    LockSettings.AimPart = selected
end)


Elements.AddToggle(lockPage, "Aimbot", false, Enum.KeyCode.V, function(state)
    LockSettings.Enabled = state -- This connects the UI to your loop
    print("Aimbot is now:", state)
end)

Elements.AddToggle(ESPPage, "Enable Box ESP", false, nil, function(state)
    ESP_Settings.Box = state
end)
Elements.AddSlider(lockPage, "Smoothness", 1, 100, 10, function(val) CamSettings.Smoothness = val / 100 end)
Elements.AddSlider(lockPage, "Prediction", 0, 50, 10, function(val) CamSettings.Prediction = val / 100 end)

Elements.AddToggle(ESPPage, "Enable Name ESP", false, nil, function(state)
    ESP_Settings.Name = state
end)

Elements.AddToggle(ESPPage, "Enable Distance ESP", false, nil, function(state)
    ESP_Settings.Distance = state
end)

local function createESP(target)
    if target == LocalPlayer then return end

    -- Box ESP (Highlight)
    local highlight = Instance.new("Highlight")
    highlight.FillColor = Colors.AccentBlue -- Matches your light blue UI
    highlight.FillTransparency = 0.5
    highlight.Enabled = false
    highlight.Parent = target.Character

    -- Text ESP (Billboard)
    local bb = Instance.new("BillboardGui", target.Character:WaitForChild("Head"))
    bb.Size = UDim2.new(0, 100, 0, 50)
    bb.StudsOffset = Vector3.new(0, 2, 0)
    bb.AlwaysOnTop = true
    bb.Enabled = false

    local label = Instance.new("TextLabel", bb)
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Colors.AccentBlue
    label.Font = MainFont

    RunService.RenderStepped:Connect(function()
        if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
            highlight.Enabled = ESP_Settings.Box
            bb.Enabled = ESP_Settings.Name or ESP_Settings.Distance
            if ESP_Settings.Name then label.Text = target.Name end
            if ESP_Settings.Distance then 
                local dist = math.floor((LocalPlayer.Character.HumanoidRootPart.Position - target.Character.HumanoidRootPart.Position).Magnitude)
                label.Text = label.Text .. " [" .. dist .. "]" 
            end
        end
    end)
end
for _, p in pairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then
        if p.Character then createESP(p) end
        p.CharacterAdded:Connect(function() createESP(p) end)
    end
end
-- 1. Helper function defined outside
local function isKnocked(character)
    local effect = character:FindFirstChild("BodyEffects") and character.BodyEffects:FindFirstChild("K.O")
    return effect and effect.Value == true
end

-- 2. Targeting function
local function getClosestPlayer()
    local closest, dist = nil, math.huge
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            if not isKnocked(p.Character) then
                local pos, onScreen = workspace.CurrentCamera:WorldToViewportPoint(p.Character.HumanoidRootPart.Position)
                if onScreen then
                    local mag = (Vector2.new(pos.X, pos.Y) - UserInputService:GetMouseLocation()).Magnitude
                    if mag < dist then
                        dist = mag
                        closest = p
                    end
                end
            end
        end
    end
    return closest
end


RunService.RenderStepped:Connect(function()
    if LockSettings.Enabled then
        local target = getClosestPlayer()
        if target and target.Character then
            local part = target.Character:FindFirstChild(LockSettings.AimPart) or target.Character.HumanoidRootPart
            
            local rayParams = RaycastParams.new()
            rayParams.FilterDescendantsInstances = {LocalPlayer.Character, target.Character}
            rayParams.FilterType = Enum.RaycastFilterType.Exclude
            local ray = workspace:Raycast(workspace.CurrentCamera.CFrame.Position, (part.Position - workspace.CurrentCamera.CFrame.Position), rayParams)
            
            if not ray then 
                local targetPos = part.Position + (target.Character.HumanoidRootPart.AssemblyLinearVelocity * CamSettings.Prediction)
                local targetCFrame = CFrame.new(workspace.CurrentCamera.CFrame.Position, targetPos)
                workspace.CurrentCamera.CFrame = workspace.CurrentCamera.CFrame:Lerp(targetCFrame, CamSettings.Smoothness)
            end
        end
    end
end)
