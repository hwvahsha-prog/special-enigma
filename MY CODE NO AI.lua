-- Add these default values for the new ESP options
if not Esp.Tracers then
    Esp.Tracers = {Enabled = false, Color = NewRGB(255,255,255), Origin = "Bottom", Thickness = 1}
end
if not Esp.Skeleton then
    Esp.Skeleton = {Enabled = false, Color = NewRGB(255,255,255), Thickness = 1}
end
if not Esp.HeadDot then
    Esp.HeadDot = {Enabled = false, Color = NewRGB(255,0,0), Size = 5}
end
if not Esp.Footsteps then
    Esp.Footsteps = {Enabled = false, Color = NewRGB(255,255,0), Lifetime = 3}
end
if not Esp.Arrow then
    Esp.Arrow = {Enabled = false, Color = NewRGB(255,0,0), Size = 20, Distance = 50}
end
if not Esp.PlayerCount then
    Esp.PlayerCount = {Enabled = false, Color = NewRGB(255,255,255), ShowAlive = true, ShowTotal = true, TextSize = 14}
end
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local Camera = workspace.CurrentCamera
local player = Players.LocalPlayer

-- UI parent (fallback for some games)
local guiParent = player:WaitForChild("PlayerGui")
pcall(function() guiParent = CoreGui end)

-- Detect game version
local function GetGameInfo()
    local success, result = pcall(function()
        return MarketplaceService:GetProductInfo(game.PlaceId)
    end)
    if success and result then
        return result.Creator.Name or "Unknown", result.Name or "Unknown"
    end
    return "Unknown", "Unknown"
end

local Creator, GameName = GetGameInfo()
print("["..os.date("%X").."] Detected:", Creator, "|", GameName)

-- ============================================================
-- SECTION 2: COLORS & UI THEME
-- ============================================================
local Colors = {
    MainBgDark = Color3.fromRGB(10, 8, 15),
    MainBgPurple = Color3.fromRGB(45, 25, 70),
    SidebarBg = Color3.fromRGB(20, 15, 25),
    Highlight = Color3.fromRGB(150, 100, 255),
    TextMuted = Color3.fromRGB(180, 170, 200),
    TextLight = Color3.fromRGB(255, 255, 255),
    ToggleOff = Color3.fromRGB(40, 30, 50),
    ToggleOn = Color3.fromRGB(150, 100, 255),
    SliderFill = Color3.fromRGB(150, 100, 255)
}

-- ============================================================
-- SECTION 3: ADVANCED RESOLVER (from Serial.xyz)
-- ============================================================
local ResolverState = {}

local function GetState(p)
    if not ResolverState[p] then
        ResolverState[p] = {
            positionLog = {},
            foundPattern = nil,
            lastRefresh = tick(),
            lastPos = nil,
            lastTime = nil,
            expDist = 0,
            expDir = 1,
            defensivePos = {},
            lastDefUpdate = tick(),
            velocity = Vector3.new(0, 0, 0),
            lastVelPos = nil,
            lastVelTime = tick(),
        }
    end
    return ResolverState[p]
end

Players.PlayerRemoving:Connect(function(p) ResolverState[p] = nil end)

local function TrackVelocity(state, pos)
    local now = tick()
    local dt = now - state.lastVelTime
    if dt > 0 and state.lastVelPos then
        state.velocity = (pos - state.lastVelPos) / dt
    end
    state.lastVelPos = pos
    state.lastVelTime = now
end

local function ResolveCluster(state, root, pos)
    local now = tick()
    local refreshTime = getgenv().serial_refreshtime or 3
    local forgiveness = getgenv().serial_forgiveness or 14.4
    local distPenalty = getgenv().serial_distpenalty or 2
    local voidBonus = getgenv().serial_voidbonus or 5
    local minCluster = 4

    if now - state.lastRefresh >= refreshTime then
        state.positionLog = {}
        state.foundPattern = nil
        state.lastRefresh = now
    end

    local flatDist = math.abs(pos.X) + math.abs(pos.Z)
    if flatDist < 8955 then forgiveness = forgiveness + voidBonus end

    local lchar = player.Character
    if lchar and lchar:FindFirstChild("HumanoidRootPart") then
        local dist = (pos - lchar.HumanoidRootPart.Position).Magnitude
        local penalty = (dist / 100) * distPenalty
        forgiveness = math.clamp(forgiveness - penalty, 1, 100)
    end

    table.insert(state.positionLog, { pos = pos, time = now })
    if #state.positionLog > 500 then table.remove(state.positionLog, 1) end
    if #state.positionLog < 10 then return pos end

    local clusters = {}
    for i = 1, #state.positionLog do
        local base = state.positionLog[i].pos
        local count = 0
        local sum = Vector3.new(0, 0, 0)
        for j = 1, #state.positionLog do
            local tp = state.positionLog[j].pos
            if (base - tp).Magnitude <= forgiveness then
                count = count + 1
                sum = sum + tp
            end
        end
        if count >= minCluster then
            table.insert(clusters, { pos = sum / count, count = count })
        end
    end

    local best = nil
    for _, c in ipairs(clusters) do
        if not best or c.count > best.count then best = c end
    end
    if best then
        state.foundPattern = best.pos
        return best.pos
    end
    return pos
end

local function ResolvePredict(state, root, pos)
    local now = tick()
    local result = pos
    local predMode = getgenv().ue_pred_mode or "Custom"
    local predMult = getgenv().ue_pred_mult or 2.0

    if state.lastPos and state.lastTime then
        local dt = now - state.lastTime
        if dt > 0 and dt < 0.5 then
            local vel = (pos - state.lastPos) / dt
            local speed = vel.Magnitude
            if speed > 0.001 then
                local strength = predMult * 0.01
                if predMode == "Custom" then
                    local dist = (pos - state.lastPos).Magnitude
                    local pred = (dist / dt) * strength
                    result = pos + vel.Unit * pred
                else
                    result = pos + vel * strength
                end
            end
        end
    end
    state.lastPos = root.Position
    state.lastTime = now
    return result
end

local function ResolveExponential(state, root, pos)
    local minD = getgenv().ue_exp_min or 0
    local maxD = getgenv().ue_exp_max or 10
    local step = (maxD - minD) / 10
    state.expDist = state.expDist + step * state.expDir
    if state.expDist >= maxD then
        state.expDist = maxD
        state.expDir = -1
    elseif state.expDist <= minD then
        state.expDist = minD
        state.expDir = 1
    end
    return pos + root.CFrame.UpVector * state.expDist
end

local function ResolveDefensive(state, root, pos)
    local now = tick()
    local posWeight = getgenv().ue_def_pos_weight or 1.5
    local voidWeight = getgenv().ue_def_void_weight or 0.2
    local forgetRate = getgenv().ue_def_forget_rate or 80
    local accuracy = getgenv().ue_def_accuracy or 1.35
    local lerp = getgenv().ue_def_lerp or 0.10

    local inVoid = (math.abs(pos.X) + math.abs(pos.Z)) >= 8955
    local wToAdd = inVoid and voidWeight or posWeight

    local toRemove = {}
    for p, data in pairs(state.defensivePos) do
        local dt = now - data.lastUpdate
        local rate = forgetRate / 20
        data.weight = data.weight - ((p - pos).Magnitude > 200 and dt * (rate * 2.5) or dt * rate)
        data.lastUpdate = now
        if data.weight < 0.1 then table.insert(toRemove, p) end
    end
    for _, p in ipairs(toRemove) do state.defensivePos[p] = nil end

    local merged = false
    for p, data in pairs(state.defensivePos) do
        if (p - pos).Magnitude <= 200 then
            local newP = p:Lerp(pos, lerp)
            state.defensivePos[newP] = {
                weight = math.clamp(data.weight + wToAdd, -1, 18),
                lastUpdate = now
            }
            state.defensivePos[p] = nil
            merged = true
            break
        end
    end
    if not merged then
        state.defensivePos[pos] = { weight = wToAdd, lastUpdate = now }
    end

    local bestP, bestW = nil, 0
    for p, data in pairs(state.defensivePos) do
        if data.weight > bestW then
            bestW = data.weight
            bestP = p
        end
    end
    if bestP and bestW > accuracy then
        return bestP
    end
    return pos
end

function GetResolvedPosition(p)
    if not p or not p.Character then return nil end
    local root = p.Character:FindFirstChild("HumanoidRootPart")
    if not root then return nil end

    local pos = root.Position
    local state = GetState(p)
    TrackVelocity(state, pos)

    local mode = getgenv().ue_resolver_mode or "auto"
    if mode == "cluster" then
        return ResolveCluster(state, root, pos)
    elseif mode == "predict" then
        return ResolvePredict(state, root, pos)
    elseif mode == "exponential" then
        return ResolveExponential(state, root, pos)
    elseif mode == "defensive" then
        return ResolveDefensive(state, root, pos)
    else
        local clustered = ResolveCluster(state, root, pos)
        if state.foundPattern then
            return clustered
        end
        return ResolvePredict(state, root, pos)
    end
end

-- ============================================================
-- SECTION 4: SILENT AIM SYSTEM
-- ============================================================
local SilentAim = {
    Enabled = false,
    Target = nil,
    IsTargetting = false,

    -- FOV
    ShowFOV = false,
    FOVRadius = 263,

    -- Aim settings
    HitPart = "Head",
    PredictionAmount = 0.135,
    UseCustomPrediction = false,
    ResolverEnabled = false,
    ResolverMethod = "Recalculate Velocity",
    ResolverRefreshRate = 100,
    HumanizationEnabled = false,
    HumanizationValue = 5,
    JumpOffsetEnabled = false,
    JumpOffset = 0,
    AntiGroundShots = false,
    AntiGroundShotsFactor = 2,
    ChecksEnabled = false,
    ChecksFlags = {},
    WallCheck = false,
    BulletSpread = 0,
}

local function CalculateResolverOffset(Target, Method, UpdateTime)
    if not Target or not Target.Character then return Vector3.new(0, 0, 0) end
    local Root = Target.Character:FindFirstChild("HumanoidRootPart")
    if not Root then return Vector3.new(0, 0, 0) end

    if Method == "Recalculate Velocity" then
        local pos1 = Root.Position
        local t1 = tick()
        task.wait(1 / UpdateTime)
        local pos2 = Root.Position
        local t2 = tick()
        return (pos2 - pos1) / (t2 - t1)
    elseif Method == "Suppress Velocity" then
        return Vector3.new(Root.Velocity.X, 0, Root.Velocity.Z)
    elseif Method == "Move Direction" then
        local Hum = Target.Character:FindFirstChild("Humanoid")
        if Hum then return Hum.MoveDirection * Hum.WalkSpeed end
    end
    return Vector3.new(0, 0, 0)
end

function SilentAim:GetPredictedPosition(Target)
    if not Target then Target = self.Target end
    if not Target or not Target.Character then return nil end

    local Char = Target.Character
    local Root = Char:FindFirstChild("HumanoidRootPart")
    if not Root then return nil end

    local Velocity
    if self.ResolverEnabled then
        Velocity = CalculateResolverOffset(Target, self.ResolverMethod, self.ResolverRefreshRate)
    else
        Velocity = Root.Velocity
    end

    local Part
    if self.HitPart == "Head" then
        Part = Char:FindFirstChild("Head")
    elseif self.HitPart == "UpperTorso" then
        Part = Char:FindFirstChild("UpperTorso")
    elseif self.HitPart == "LowerTorso" then
        Part = Char:FindFirstChild("LowerTorso")
    elseif self.HitPart == "Root" then
        Part = Root
    else
        Part = Root
    end
    if not Part then return nil end
    local Pos = Part.Position

    local Ping = tonumber(string.split(
        game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValueString(),
        '('
    )[1]) or 50
    local PingFactor = Ping / 500

    local Predicted
    if self.UseCustomPrediction then
        Predicted = Pos + Velocity * self.PredictionAmount
    else
        Predicted = Pos + Velocity * PingFactor
    end

    if self.AntiGroundShots and Root.Velocity.Y ~= 0 then
        local factor = self.AntiGroundShotsFactor
        Velocity = Vector3.new(Velocity.X, math.abs(Velocity.Y * factor), Velocity.Z)
    end

    if self.JumpOffsetEnabled and Root.Velocity.Y ~= 0 then
        Predicted = Predicted + Vector3.new(0, self.JumpOffset, 0)
    end

    if self.HumanizationEnabled then
        local r = self.HumanizationValue * 0.01
        local rand = Vector3.new(
            math.random(-r, r),
            math.random(-r, r),
            math.random(-r, r)
        )
        Predicted = Predicted + rand
    end

    if self.BulletSpread > 0 then
        local s = self.BulletSpread / 100
        Predicted = Predicted + Vector3.new(
            math.random(-s, s),
            math.random(-s, s),
            math.random(-s, s)
        )
    end

    return Predicted
end
function SilentAim:FindTarget()
    if not self.Enabled then
        self.Target = nil
        self.IsTargetting = false
        return nil
    end
    local origin = UserInputService:GetMouseLocation()
    local closestDist = self.FOVRadius
    local closest = nil

    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            local root = p.Character:FindFirstChild("HumanoidRootPart")
            if root then
                local pos, onScreen = Camera:WorldToViewportPoint(root.Position)
                if onScreen then
                    local dist = (Vector2.new(pos.X, pos.Y) - origin).Magnitude
                    if dist <= closestDist then
                        local passesChecks = true
                        
                        if self.WallCheck then
                            local rayParams = RaycastParams.new()
                            rayParams.FilterType = Enum.RaycastFilterType.Exclude
                            rayParams.FilterDescendantsInstances = {player.Character}
                            
                            local ray = Workspace:Raycast(Camera.CFrame.Position, (root.Position - Camera.CFrame.Position).Unit * 1000, rayParams)
                            if not (ray and ray.Instance and ray.Instance:IsDescendantOf(p.Character)) then
                                passesChecks = false
                            end
                        end
                        
                        if passesChecks and self.ChecksEnabled then
                            for _, flag in ipairs(self.ChecksFlags) do
                                if flag == "Knocked" then
                                    local body = p.Character:FindFirstChild("BodyEffects")
                                    local KO = body and body:FindFirstChild("K.O")
                                    if KO and KO.Value == true then 
                                        passesChecks = false 
                                        break
                                    end
                                end
                            end
                        end

                        if passesChecks then
                            closestDist = dist
                            closest = p
                        end
                    end
                end
            end
        end
    end

    self.Target = closest
    self.IsTargetting = closest ~= nil
    return closest
end
-- ============================================================
-- SECTION 5: FOV CIRCLE
-- ============================================================
local FOVCircle = Drawing.new("Circle")
FOVCircle.Visible = false
FOVCircle.Radius = SilentAim.FOVRadius
FOVCircle.Color = Color3.fromRGB(255, 255, 255)
FOVCircle.Thickness = 2
FOVCircle.Filled = false
FOVCircle.NumSides = 64
FOVCircle.Transparency = 1
FOVCircle.ZIndex = 999

local function UpdateFOV()
    FOVCircle.Radius = SilentAim.FOVRadius
    FOVCircle.Visible = SilentAim.ShowFOV and SilentAim.Enabled
end
-- ============================================================
-- SECTION 6: UNIVERSAL HOOKS (works on any Da Hood game)
-- ============================================================

-- 6a: Auto-detect shooting remotes
local function GetShootingRemotes()
    local remotes = {}
    local commonNames = {
        "MainEvent", "ShootEvent", "FireEvent", "GunEvent",
        "Shoot", "Fire", "Gun", "WeaponEvent", "Bullet", "Hit",
        "RemoteEvent", "Weapon", "Attack", "Damage"
    }
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            local name = obj.Name
            for _, pattern in ipairs(commonNames) do
                if name:lower():find(pattern:lower()) then
                    table.insert(remotes, obj)
                    break
                end
            end
        end
    end
    return remotes
end

local ShootingRemotes = GetShootingRemotes()
local remoteNames = {}
for _, remote in ipairs(ShootingRemotes) do
    table.insert(remoteNames, remote.Name)
end
print("["..os.date("%X").."] Found shooting remotes:", table.concat(remoteNames, ", "))
-- 6b: Hook FireServer (universal argument modifier)
local oldFireServer
oldFireServer = hookfunction(Instance.new("RemoteEvent").FireServer, function(self, ...)
    local args = {...}
    
    if SilentAim.Enabled then
        SilentAim:FindTarget()
        if SilentAim.Target then
            local aimPos = SilentAim:GetPredictedPosition()
            if aimPos then
                -- Recursively scan and modify any Vector3 or CFrame
                local function modifyTable(t)
                    for k, v in pairs(t) do
                        if typeof(v) == "Vector3" then
                            t[k] = aimPos
                        elseif typeof(v) == "CFrame" then
                            t[k] = CFrame.lookAt(v.Position, aimPos)
                        elseif typeof(v) == "table" then
                            modifyTable(v)
                        end
                    end
                end
                
                for i, arg in pairs(args) do
                    if typeof(arg) == "Vector3" then
                        -- If it's the second arg and first is also Vector3, treat as direction
                        if i > 1 and typeof(args[i-1]) == "Vector3" then
                            args[i] = (aimPos - args[i-1]).Unit * 100
                        else
                            args[i] = aimPos
                        end
                    elseif typeof(arg) == "CFrame" then
                        args[i] = CFrame.lookAt(arg.Position, aimPos)
                    elseif typeof(arg) == "table" then
                        modifyTable(arg)
                    end
                end
                return oldFireServer(self, unpack(args))
            end
        end
    end
    return oldFireServer(self, ...)
end)

-- 6c: Hook __namecall for games that use it
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local args, method = {...}, tostring(getnamecallmethod())
    if not checkcaller() and method == "FireServer" then
        if SilentAim.Enabled then
            SilentAim:FindTarget()
            if SilentAim.Target then
                local aimPos = SilentAim:GetPredictedPosition()
                if aimPos then
                    for i, arg in pairs(args) do
                        if typeof(arg) == "Vector3" then
                            if i > 1 and typeof(args[i-1]) == "Vector3" then
                                args[i] = (aimPos - args[i-1]).Unit * 100
                            else
                                args[i] = aimPos
                            end
                        elseif typeof(arg) == "CFrame" then
                            args[i] = CFrame.lookAt(arg.Position, aimPos)
                        elseif typeof(arg) == "table" then
                            for k, v in pairs(arg) do
                                if typeof(v) == "Vector3" then
                                    arg[k] = aimPos
                                elseif typeof(v) == "CFrame" then
                                    arg[k] = CFrame.lookAt(v.Position, aimPos)
                                end
                            end
                        end
                    end
                    return oldNamecall(self, unpack(args))
                end
            end
        end
    end
    return oldNamecall(self, ...)
end)

-- 6d: Monitor for new remotes
ReplicatedStorage.DescendantAdded:Connect(function(obj)
    if obj:IsA("RemoteEvent") then
        local name = obj.Name
        local patterns = {"shoot", "fire", "gun", "weapon", "bullet", "hit", "attack", "damage"}
        for _, p in ipairs(patterns) do
            if name:lower():find(p) then
                print("["..os.date("%X").."] New shooting remote detected:", name)
                break
            end
        end
    end
end)

-- ============================================================
-- SECTION 7: UI (moonlight.cc style)
-- ============================================================
local moonlightGui = Instance.new("ScreenGui")
moonlightGui.Name = "moonlight.cc"
moonlightGui.ResetOnSpawn = false
moonlightGui.Parent = guiParent

local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0, 45, 0, 45)
toggleBtn.Position = UDim2.new(0, 15, 0, 15)
toggleBtn.BackgroundColor3 = Colors.MainBgPurple
toggleBtn.Text = "M.cc"
toggleBtn.TextColor3 = Colors.TextLight
toggleBtn.Font = Enum.Font.FredokaOne
toggleBtn.TextSize = 14
toggleBtn.Active = true
toggleBtn.Draggable = true
toggleBtn.Parent = moonlightGui
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(1, 0)

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 580, 0, 380)
mainFrame.Position = UDim2.new(0.5, -290, 0.5, -190)
mainFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.ClipsDescendants = true
mainFrame.Parent = moonlightGui
local grad = Instance.new("UIGradient", mainFrame)
grad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Colors.MainBgPurple),
    ColorSequenceKeypoint.new(1, Colors.MainBgDark)
})
grad.Rotation = 45
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 12)

toggleBtn.MouseButton1Click:Connect(function() mainFrame.Visible = not mainFrame.Visible end)

-- Drag
local drag, dInput, dStart, sPos
mainFrame.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        drag, dStart, sPos = true, i.Position, mainFrame.Position
        i.Changed:Connect(function() if i.UserInputState == Enum.UserInputState.End then drag = false end end)
    end
end)
mainFrame.InputChanged:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then dInput = i end end)
UserInputService.InputChanged:Connect(function(i)
    if i == dInput and drag then
        local delta = i.Position - dStart
        mainFrame.Position = UDim2.new(sPos.X.Scale, sPos.X.Offset + delta.X, sPos.Y.Scale, sPos.Y.Offset + delta.Y)
    end
end)

-- Sidebar
local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 160, 1, 0)
sidebar.BackgroundColor3 = Colors.SidebarBg
sidebar.BackgroundTransparency = 0.3
sidebar.BorderSizePixel = 0
sidebar.ZIndex = 2
sidebar.Parent = mainFrame
Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 12)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 40)
title.Position = UDim2.new(0, 15, 0, 10)
title.BackgroundTransparency = 1
title.Text = "moonlight.cc"
title.TextColor3 = Colors.TextLight
title.Font = Enum.Font.FredokaOne
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 3
title.Parent = sidebar

local tabBtns = Instance.new("Frame")
tabBtns.Size = UDim2.new(1, -20, 0, 280)
tabBtns.Position = UDim2.new(0, 10, 0, 55)
tabBtns.BackgroundTransparency = 1
tabBtns.ZIndex = 3
tabBtns.Parent = sidebar
Instance.new("UIListLayout", tabBtns).SortOrder = Enum.SortOrder.LayoutOrder

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -160, 1, 0)
content.Position = UDim2.new(0, 160, 0, 0)
content.BackgroundTransparency = 1
content.ZIndex = 3
content.Parent = mainFrame

local header = Instance.new("TextLabel")
header.Size = UDim2.new(1, -30, 0, 40)
header.Position = UDim2.new(0, 15, 0, 10)
header.BackgroundTransparency = 1
header.Text = "HELLO, " .. string.upper(player.DisplayName or "USER")
header.TextColor3 = Colors.TextLight
header.Font = Enum.Font.FredokaOne
header.TextSize = 18
header.TextXAlignment = Enum.TextXAlignment.Left
header.ZIndex = 3
header.Parent = content

local tabs, frames = {}, {}
local function createTab(name)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 28)
    btn.BackgroundColor3 = Colors.SidebarBg
    btn.BackgroundTransparency = 1
    btn.Text = "  " .. name
    btn.TextColor3 = Colors.TextMuted
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 12
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.ZIndex = 3
    btn.Parent = tabBtns
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local frm = Instance.new("Frame")
    frm.Size = UDim2.new(1, 0, 1, -50)
    frm.Position = UDim2.new(0, 0, 0, 50)
    frm.BackgroundTransparency = 1
    frm.Visible = false
    frm.ZIndex = 3
    frm.Parent = content
    local stitle = Instance.new("TextLabel")
    stitle.Size = UDim2.new(1, -30, 0, 20)
    stitle.Position = UDim2.new(0, 15, 0, 5)
    stitle.BackgroundTransparency = 1
    stitle.Text = name .. " Settings"
    stitle.TextColor3 = Colors.TextLight
    stitle.Font = Enum.Font.GothamBold
    stitle.TextSize = 12
    stitle.TextXAlignment = Enum.TextXAlignment.Left
    stitle.ZIndex = 3
    stitle.Parent = frm
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -30, 1, -35)
    container.Position = UDim2.new(0, 15, 0, 35)
    container.BackgroundTransparency = 1
    container.ZIndex = 3
    container.Parent = frm
    Instance.new("UIListLayout", container).SortOrder = Enum.SortOrder.LayoutOrder

    btn.MouseButton1Click:Connect(function()
        for _, b in pairs(tabs) do
            b.BackgroundTransparency = 1
            b.BackgroundColor3 = Colors.SidebarBg
            b.TextColor3 = Colors.TextMuted
        end
        for _, f in pairs(frames) do f.Visible = false end
        btn.BackgroundTransparency = 0.2
        btn.BackgroundColor3 = Colors.Highlight
        btn.TextColor3 = Colors.TextLight
        frm.Visible = true
    end)
    table.insert(tabs, btn)
    table.insert(frames, frm)
    return container, btn, frm
end

-- UI Helpers
local function createToggle(parent, text, cb)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1, 0, 0, 24)
    row.BackgroundTransparency = 1
    row.ZIndex = 3
    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(0.7, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Colors.TextMuted
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 3
    local btn = Instance.new("TextButton", row)
    btn.Size = UDim2.new(0, 45, 0, 20)
    btn.Position = UDim2.new(1, -45, 0, 2)
    btn.BackgroundColor3 = Colors.ToggleOff
    btn.Text = "OFF"
    btn.TextColor3 = Colors.TextLight
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.ZIndex = 3
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    local on = false
    btn.MouseButton1Click:Connect(function()
        on = not on
        btn.Text = on and "ON" or "OFF"
        btn.BackgroundColor3 = on and Colors.ToggleOn or Colors.ToggleOff
        lbl.TextColor3 = on and Colors.TextLight or Colors.TextMuted
        if cb then cb(on) end
    end)
    return lbl, btn
end

local function createSlider(parent, text, def, min, max, cb)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1, 0, 0, 32)
    row.BackgroundTransparency = 1
    row.ZIndex = 3
    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1, 0, 0, 16)
    lbl.BackgroundTransparency = 1
    lbl.Text = text .. ": " .. def
    lbl.TextColor3 = Colors.TextMuted
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 3
    local bar = Instance.new("Frame", row)
    bar.Size = UDim2.new(1, 0, 0, 4)
    bar.Position = UDim2.new(0, 0, 0, 22)
    bar.BackgroundColor3 = Colors.ToggleOff
    bar.BorderSizePixel = 0
    bar.ZIndex = 3
    local init = (def - min) / (max - min)
    local fill = Instance.new("Frame", bar)
    fill.Size = UDim2.new(init, 0, 1, 0)
    fill.BackgroundColor3 = Colors.SliderFill
    fill.BorderSizePixel = 0
    fill.ZIndex = 3
    local knob = Instance.new("TextButton", bar)
    knob.Text = ""
    knob.Size = UDim2.new(0, 10, 0, 10)
    knob.Position = UDim2.new(init, -5, 0.5, -5)
    knob.BackgroundColor3 = Colors.TextLight
    knob.ZIndex = 4
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local drag = false
    knob.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then drag = true end
    end)
    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then drag = true end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then drag = false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local p = math.clamp((i.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
            local v = math.floor(min + (max - min) * p)
            fill.Size = UDim2.new(p, 0, 1, 0)
            knob.Position = UDim2.new(p, -5, 0.5, -5)
            lbl.Text = text .. ": " .. v
            lbl.TextColor3 = Colors.TextLight
            if cb then cb(v) end
        end
    end)
end
local function createDropdown(parent, text, opts, defI, cb)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1, 0, 0, 24)
    row.BackgroundTransparency = 1
    row.ZIndex = 5
    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(0.6, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Colors.TextMuted
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 5
    local dbtn = Instance.new("TextButton", row)
    dbtn.Size = UDim2.new(0, 80, 0, 24)
    dbtn.Position = UDim2.new(1, -80, 0, 0)
    dbtn.BackgroundColor3 = Colors.ToggleOff
    dbtn.Text = opts[defI] .. " v"
    dbtn.TextColor3 = Colors.TextLight
    dbtn.Font = Enum.Font.GothamMedium
    dbtn.TextSize = 11
    dbtn.ZIndex = 6
    Instance.new("UICorner", dbtn).CornerRadius = UDim.new(0, 6)

    local lst = Instance.new("Frame", dbtn)
    lst.Size = UDim2.new(0, 80, 0, #opts * 24)
    lst.Position = UDim2.new(0, 0, 1, 2)
    lst.BackgroundColor3 = Colors.ToggleOff
    lst.Visible = false
    lst.ZIndex = 10
    Instance.new("UICorner", lst).CornerRadius = UDim.new(0, 6)
    Instance.new("UIListLayout", lst)

    for _, o in pairs(opts) do
        local ob = Instance.new("TextButton", lst)
        ob.Size = UDim2.new(1, 0, 0, 24)
        ob.BackgroundTransparency = 1
        ob.Text = o
        ob.TextColor3 = Colors.TextMuted
        ob.Font = Enum.Font.GothamMedium
        ob.TextSize = 11
        ob.ZIndex = 11
        ob.MouseButton1Click:Connect(function()
            dbtn.Text = o .. " v"
            lst.Visible = false
            lbl.TextColor3 = Colors.TextLight
            if cb then cb(o) end
        end)
    end
    dbtn.MouseButton1Click:Connect(function() lst.Visible = not lst.Visible end)
end

-- ============================================================
-- SECTION 8: UI TABS & CONTROLS
-- ============================================================
local silentAimC, silentAimB, silentAimF = createTab("Silent Aim")
local resolverC, resolverB, resolverF = createTab("Resolver")
local espC, espB, espF = createTab("ESP")      -- placeholder
local speedC, speedB, speedF = createTab("Speed") -- placeholder
-- ============================================================
-- ADDITIONAL ESP OPTIONS
-- ============================================================

-- Tracers
Sections.Visuals.PlayerESP:AddToggle("EspTracersEnabled", {Text = "Tracers", Default = false, Callback = function(a)
    Esp.Tracers.Enabled = a
end}):AddColorPicker("EspTracersColor", {Default = NewRGB(255, 255, 255), Title = "Color", Transparency = nil, Callback = function(a)
    Esp.Tracers.Color = a
end})
local Tracers = Sections.Visuals.PlayerESP:AddDependencyBox()
Tracers:AddDropdown("EspTracersOrigin", {Values = {"Bottom", "Top", "Center"}, Default = "Bottom", Text = "Origin", Callback = function(a)
    Esp.Tracers.Origin = a
end})
Tracers:AddSlider("EspTracersThickness", {Text = "Thickness", Default = 1, Min = 0.5, Max = 5, Rounding = 1, Compact = true, Callback = function(a)
    Esp.Tracers.Thickness = a
end})
Tracers:SetupDependencies({{Toggles["EspTracersEnabled"], true}})

-- Skeletons
Sections.Visuals.PlayerESP:AddToggle("EspSkeletonEnabled", {Text = "Skeleton", Default = false, Callback = function(a)
    Esp.Skeleton.Enabled = a
end}):AddColorPicker("EspSkeletonColor", {Default = NewRGB(255, 255, 255), Title = "Color", Transparency = nil, Callback = function(a)
    Esp.Skeleton.Color = a
end})
local Skeleton = Sections.Visuals.PlayerESP:AddDependencyBox()
Skeleton:AddSlider("EspSkeletonThickness", {Text = "Thickness", Default = 1, Min = 0.5, Max = 5, Rounding = 1, Compact = true, Callback = function(a)
    Esp.Skeleton.Thickness = a
end})
Skeleton:SetupDependencies({{Toggles["EspSkeletonEnabled"], true}})

-- Head Dot
Sections.Visuals.PlayerESP:AddToggle("EspHeadDotEnabled", {Text = "Head Dot", Default = false, Callback = function(a)
    Esp.HeadDot.Enabled = a
end}):AddColorPicker("EspHeadDotColor", {Default = NewRGB(255, 0, 0), Title = "Color", Transparency = nil, Callback = function(a)
    Esp.HeadDot.Color = a
end})
local HeadDot = Sections.Visuals.PlayerESP:AddDependencyBox()
HeadDot:AddSlider("EspHeadDotSize", {Text = "Size", Default = 5, Min = 1, Max = 15, Rounding = 0, Compact = true, Callback = function(a)
    Esp.HeadDot.Size = a
end})
HeadDot:SetupDependencies({{Toggles["EspHeadDotEnabled"], true}})

-- Footsteps
Sections.Visuals.PlayerESP:AddToggle("EspFootstepsEnabled", {Text = "Footsteps", Default = false, Callback = function(a)
    Esp.Footsteps.Enabled = a
end}):AddColorPicker("EspFootstepsColor", {Default = NewRGB(255, 255, 0), Title = "Color", Transparency = nil, Callback = function(a)
    Esp.Footsteps.Color = a
end})
local Footsteps = Sections.Visuals.PlayerESP:AddDependencyBox()
Footsteps:AddSlider("EspFootstepsLifetime", {Text = "Lifetime", Default = 3, Min = 0.5, Max = 10, Rounding = 1, Suffix = "s", Compact = true, Callback = function(a)
    Esp.Footsteps.Lifetime = a
end})
Footsteps:SetupDependencies({{Toggles["EspFootstepsEnabled"], true}})

-- 2D Radar
Sections.Visuals.PlayerESP:AddToggle("EspRadar2DEnabled", {Text = "2D Radar", Default = false, Callback = function(a)
    Esp.Radar.Enabled = a
end})
local Radar2D = Sections.Visuals.PlayerESP:AddDependencyBox()
Radar2D:AddSlider("EspRadarSize", {Text = "Size", Default = 150, Min = 50, Max = 400, Rounding = 0, Compact = true, Callback = function(a)
    Esp.Radar.Size = a
end})
Radar2D:AddSlider("EspRadarRange", {Text = "Range", Default = 200, Min = 50, Max = 500, Rounding = 0, Compact = true, Callback = function(a)
    Esp.Radar.Range = a
end})
Radar2D:AddColorPicker("EspRadarBackground", {Default = NewRGB(10, 10, 10), Title = "Background", Transparency = nil, Callback = function(a)
    Esp.Radar.Background = a
end})
Radar2D:AddColorPicker("EspRadarEnemy", {Default = NewRGB(255, 0, 0), Title = "Enemy Color", Transparency = nil, Callback = function(a)
    Esp.Radar.Enemy = a
end})
Radar2D:AddColorPicker("EspRadarTeam", {Default = NewRGB(0, 255, 0), Title = "Team Color", Transparency = nil, Callback = function(a)
    Esp.Radar.Team = a
end})
Radar2D:SetupDependencies({{Toggles["EspRadar2DEnabled"], true}})

-- Status Icons (knocked, grabbed, etc.)
Sections.Visuals.PlayerESP:AddToggle("EspStatusIconsEnabled", {Text = "Status Icons", Default = false, Callback = function(a)
    Esp.StatusIcons.Enabled = a
end})
local StatusIcons = Sections.Visuals.PlayerESP:AddDependencyBox()
StatusIcons:AddToggle("EspStatusKnocked", {Text = "Show Knocked", Default = true, Callback = function(a)
    Esp.StatusIcons.Knocked = a
end})
StatusIcons:AddToggle("EspStatusGrabbed", {Text = "Show Grabbed", Default = true, Callback = function(a)
    Esp.StatusIcons.Grabbed = a
end})
StatusIcons:AddToggle("EspStatusReloading", {Text = "Show Reloading", Default = true, Callback = function(a)
    Esp.StatusIcons.Reloading = a
end})
StatusIcons:SetupDependencies({{Toggles["EspStatusIconsEnabled"], true}})

-- Arrow Indicator (points to off-screen enemies)
Sections.Visuals.PlayerESP:AddToggle("EspArrowIndicatorEnabled", {Text = "Arrow Indicator", Default = false, Callback = function(a)
    Esp.Arrow.Enabled = a
end}):AddColorPicker("EspArrowColor", {Default = NewRGB(255, 0, 0), Title = "Color", Transparency = nil, Callback = function(a)
    Esp.Arrow.Color = a
end})
local Arrow = Sections.Visuals.PlayerESP:AddDependencyBox()
Arrow:AddSlider("EspArrowSize", {Text = "Size", Default = 20, Min = 10, Max = 50, Rounding = 0, Compact = true, Callback = function(a)
    Esp.Arrow.Size = a
end})
Arrow:AddSlider("EspArrowDistance", {Text = "Distance from Edge", Default = 50, Min = 10, Max = 200, Rounding = 0, Compact = true, Callback = function(a)
    Esp.Arrow.Distance = a
end})
Arrow:SetupDependencies({{Toggles["EspArrowIndicatorEnabled"], true}})

-- Player Count
Sections.Visuals.PlayerESP:AddToggle("EspPlayerCountEnabled", {Text = "Player Count", Default = false, Callback = function(a)
    Esp.PlayerCount.Enabled = a
end}):AddColorPicker("EspPlayerCountColor", {Default = NewRGB(255, 255, 255), Title = "Color", Transparency = nil, Callback = function(a)
    Esp.PlayerCount.Color = a
end})
local PlayerCount = Sections.Visuals.PlayerESP:AddDependencyBox()
PlayerCount:AddToggle("EspPlayerCountShowAlive", {Text = "Show Alive Count", Default = true, Callback = function(a)
    Esp.PlayerCount.ShowAlive = a
end})
PlayerCount:AddToggle("EspPlayerCountShowTotal", {Text = "Show Total Count", Default = true, Callback = function(a)
    Esp.PlayerCount.ShowTotal = a
end})
PlayerCount:AddSlider("EspPlayerCountTextSize", {Text = "Text Size", Default = 14, Min = 8, Max = 30, Rounding = 0, Compact = true, Callback = function(a)
    Esp.PlayerCount.TextSize = a
end})
PlayerCount:SetupDependencies({{Toggles["EspPlayerCountEnabled"], true}})
-- Silent Aim Tab
createToggle(silentAimC, "Enable Silent Aim", function(s)
    SilentAim.Enabled = s
    UpdateFOV()
    print("["..os.date("%X").."] Silent Aim: " .. tostring(s))
end)

createToggle(silentAimC, "Show FOV", function(s)
    SilentAim.ShowFOV = s
    UpdateFOV()
end)

createSlider(silentAimC, "FOV Radius", 263, 0, 500, function(v)
    SilentAim.FOVRadius = v
    UpdateFOV()
end)

createSlider(silentAimC, "Bullet Spread", 0, 0, 100, function(v)
    SilentAim.BulletSpread = v
end)

createDropdown(silentAimC, "Aim Part", {"Head", "UpperTorso", "LowerTorso", "Root"}, 1, function(o)
    SilentAim.HitPart = o
end)

createToggle(silentAimC, "Wall Check", function(s)
    SilentAim.WallCheck = s
end)

createToggle(silentAimC, "Use Custom Prediction", function(s)
    SilentAim.UseCustomPrediction = s
end)

createSlider(silentAimC, "Prediction Amount", 0.135, 0, 1, function(v)
    SilentAim.PredictionAmount = v / 100
end)

createToggle(silentAimC, "Humanization", function(s)
    SilentAim.HumanizationEnabled = s
end)

createSlider(silentAimC, "Humanization Value", 5, 0, 20, function(v)
    SilentAim.HumanizationValue = v
end)

createToggle(silentAimC, "Jump Offset", function(s)
    SilentAim.JumpOffsetEnabled = s
end)
createSlider(silentAimC, "Jump Offset Amount", 0, -5, 5, function(v)
    SilentAim.JumpOffset = v
end)

createToggle(silentAimC, "Anti Ground Shots", function(s)
    SilentAim.AntiGroundShots = s
end)
createSlider(silentAimC, "Anti Ground Factor", 2, 0, 10, function(v)
    SilentAim.AntiGroundShotsFactor = v
end)

-- Resolver Tab
createToggle(resolverC, "Enable Resolver", function(s)
    SilentAim.ResolverEnabled = s
end)

createDropdown(resolverC, "Resolver Method", {"Recalculate Velocity", "Suppress Velocity", "Move Direction"}, 1, function(o)
    SilentAim.ResolverMethod = o
end)

createSlider(resolverC, "Refresh Rate", 100, 10, 500, function(v)
    SilentAim.ResolverRefreshRate = v
end)

createDropdown(resolverC, "Resolver Mode", {"auto", "cluster", "predict", "exponential", "defensive"}, 1, function(o)
    getgenv().ue_resolver_mode = o
end)

createSlider(resolverC, "Refresh Time", 3, 0.5, 10, function(v)
    getgenv().serial_refreshtime = v
end)

createSlider(resolverC, "Forgiveness", 14.4, 1, 40, function(v)
    getgenv().serial_forgiveness = v
end)

createSlider(resolverC, "Void Bonus", 5, 0, 20, function(v)
    getgenv().serial_voidbonus = v
end)

createSlider(resolverC, "Distance Penalty", 2, 0, 5, function(v)
    getgenv().serial_distpenalty = v
end)

createSlider(resolverC, "Prediction Strength", 2.0, 0.1, 10, function(v)
    getgenv().ue_pred_mult = v
end)

-- Placeholder tabs
createToggle(espC, "Enable ESP")
createToggle(speedC, "WalkSpeed Override")

-- Default tab
silentAimB.BackgroundTransparency = 0.2
silentAimB.BackgroundColor3 = Colors.Highlight
silentAimB.TextColor3 = Colors.TextLight
silentAimF.Visible = true

-- ============================================================
-- SECTION 9: MAIN LOOP (target acquisition & FOV follow)
-- ============================================================
RunService.RenderStepped:Connect(function()
    if SilentAim.Enabled then
        SilentAim:FindTarget()
    end
    if SilentAim.ShowFOV and SilentAim.Enabled then
        FOVCircle.Position = UserInputService:GetMouseLocation()
    end
end)
-- ============================================================
-- ESP LOGIC EXTENSIONS
-- ============================================================

-- Tracers
do
    local TracerLines = {}
    local function UpdateTracers()
        for _, v in pairs(Players:GetPlayers()) do
            if v ~= LocalPlayer and v.Character and v.Character:FindFirstChild("HumanoidRootPart") then
                local root = v.Character.HumanoidRootPart
                local pos, onScreen = Camera:WorldToViewportPoint(root.Position)
                if onScreen then
                    if not TracerLines[v] then
                        TracerLines[v] = Drawing.new("Line")
                        TracerLines[v].Thickness = Esp.Tracers.Thickness or 1
                        TracerLines[v].Color = Esp.Tracers.Color or NewRGB(255,255,255)
                        TracerLines[v].Transparency = 1
                        TracerLines[v].Visible = true
                    end
                    local origin = Esp.Tracers.Origin == "Bottom" and Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y) or
                                   Esp.Tracers.Origin == "Top" and Vector2.new(Camera.ViewportSize.X/2, 0) or
                                   Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
                    TracerLines[v].From = origin
                    TracerLines[v].To = Vector2.new(pos.X, pos.Y)
                elseif TracerLines[v] then
                    TracerLines[v].Visible = false
                end
            end
        end
    end
    RunService.RenderStepped:Connect(function()
        if Esp.Tracers and Esp.Tracers.Enabled then UpdateTracers() end
    end)
end

-- Skeletons
do
    local function GetBonePositions(Character)
        if not Character then return end
        local bones = {}
        local humanoid = Character:FindFirstChild("Humanoid")
        if not humanoid then return end
        
        local parts = {"Head", "UpperTorso", "LowerTorso", "HumanoidRootPart"}
        for _, name in ipairs(parts) do
            local part = Character:FindFirstChild(name)
            if part then bones[name] = part.Position end
        end
        
        local limbs = {
            {"RightUpperArm", "RightLowerArm"},
            {"RightLowerArm", "RightHand"},
            {"LeftUpperArm", "LeftLowerArm"},
            {"LeftLowerArm", "LeftHand"},
            {"RightUpperLeg", "RightLowerLeg"},
            {"RightLowerLeg", "RightFoot"},
            {"LeftUpperLeg", "LeftLowerLeg"},
            {"LeftLowerLeg", "LeftFoot"}
        }
        for _, pair in ipairs(limbs) do
            local p1 = Character:FindFirstChild(pair[1])
            local p2 = Character:FindFirstChild(pair[2])
            if p1 and p2 then
                table.insert(bones, {p1.Position, p2.Position})
            end
        end
        return bones
    end
    
    local SkeletonLines = {}
    RunService.RenderStepped:Connect(function()
        if not Esp.Skeleton or not Esp.Skeleton.Enabled then 
            for _, line in pairs(SkeletonLines) do
                if line then line.Visible = false end
            end
            return 
        end
        
        for _, v in pairs(Players:GetPlayers()) do
            if v ~= LocalPlayer and v.Character then
                local bones = GetBonePositions(v.Character)
                if bones then
                    if not SkeletonLines[v] then SkeletonLines[v] = {} end
                    local index = 1
                    for _, bonePair in ipairs(bones) do
                        local p1, p2 = bonePair[1], bonePair[2]
                        if p1 and p2 then
                            if not SkeletonLines[v][index] then
                                SkeletonLines[v][index] = Drawing.new("Line")
                                SkeletonLines[v][index].Thickness = Esp.Skeleton.Thickness or 1
                                SkeletonLines[v][index].Color = Esp.Skeleton.Color or NewRGB(255,255,255)
                                SkeletonLines[v][index].Transparency = 1
                            end
                            local pos1, on1 = Camera:WorldToViewportPoint(p1)
                            local pos2, on2 = Camera:WorldToViewportPoint(p2)
                            if on1 and on2 then
                                SkeletonLines[v][index].From = Vector2.new(pos1.X, pos1.Y)
                                SkeletonLines[v][index].To = Vector2.new(pos2.X, pos2.Y)
                                SkeletonLines[v][index].Visible = true
                            else
                                SkeletonLines[v][index].Visible = false
                            end
                            index = index + 1
                        end
                    end
                end
            end
        end
    end)
end

-- Head Dot
do
    local HeadDots = {}
    RunService.RenderStepped:Connect(function()
        if not Esp.HeadDot or not Esp.HeadDot.Enabled then
            for _, dot in pairs(HeadDots) do
                if dot then dot.Visible = false end
            end
            return
        end
        
        for _, v in pairs(Players:GetPlayers()) do
            if v ~= LocalPlayer and v.Character then
                local head = v.Character:FindFirstChild("Head")
                if head then
                    if not HeadDots[v] then
                        HeadDots[v] = Drawing.new("Circle")
                        HeadDots[v].Radius = Esp.HeadDot.Size or 5
                        HeadDots[v].Color = Esp.HeadDot.Color or NewRGB(255,0,0)
                        HeadDots[v].Filled = true
                        HeadDots[v].Thickness = 1
                        HeadDots[v].Transparency = 1
                    end
                    local pos, on = Camera:WorldToViewportPoint(head.Position)
                    if on then
                        HeadDots[v].Position = Vector2.new(pos.X, pos.Y)
                        HeadDots[v].Visible = true
                    else
                        HeadDots[v].Visible = false
                    end
                end
            end
        end
    end)
end

-- Footsteps
do
    local FootstepPositions = {}
    RunService.RenderStepped:Connect(function()
        if not Esp.Footsteps or not Esp.Footsteps.Enabled then 
            for _, pos in pairs(FootstepPositions) do
                for _, dot in pairs(pos) do
                    if dot then dot.Visible = false end
                end
            end
            return 
        end
        
        for _, v in pairs(Players:GetPlayers()) do
            if v ~= LocalPlayer and v.Character then
                local root = v.Character:FindFirstChild("HumanoidRootPart")
                if root then
                    if not FootstepPositions[v] then FootstepPositions[v] = {} end
                    local pos = root.Position
                    local screen, on = Camera:WorldToViewportPoint(pos)
                    if on then
                        local dot = Drawing.new("Circle")
                        dot.Radius = 2
                        dot.Color = Esp.Footsteps.Color or NewRGB(255,255,0)
                        dot.Filled = true
                        dot.Transparency = 1
                        dot.Position = Vector2.new(screen.X, screen.Y)
                        table.insert(FootstepPositions[v], dot)
                        
                        if #FootstepPositions[v] > 20 then
                            local old = table.remove(FootstepPositions[v], 1)
                            if old then old:Remove() end
                        end
                    end
                end
            end
        end
    end)
end

-- Arrow Indicator (off-screen enemies)
do
    local Arrows = {}
    RunService.RenderStepped:Connect(function()
        if not Esp.Arrow or not Esp.Arrow.Enabled then
            for _, arrow in pairs(Arrows) do
                if arrow then arrow.Visible = false end
            end
            return
        end
        
        for _, v in pairs(Players:GetPlayers()) do
            if v ~= LocalPlayer and v.Character then
                local root = v.Character:FindFirstChild("HumanoidRootPart")
                if root then
                    if not Arrows[v] then
                        Arrows[v] = Drawing.new("Triangle")
                        Arrows[v].Thickness = 1
                        Arrows[v].Filled = true
                        Arrows[v].Color = Esp.Arrow.Color or NewRGB(255,0,0)
                        Arrows[v].Transparency = 1
                    end
                    local pos, on = Camera:WorldToViewportPoint(root.Position)
                    if not on then
                        local center = Camera.ViewportSize / 2
                        local dir = (root.Position - Camera.CFrame.Position).Unit
                        local angle = math.atan2(dir.X, dir.Z)
                        local edgeDist = Esp.Arrow.Distance or 50
                        local x = center.X + math.sin(angle) * (Camera.ViewportSize.X/2 - edgeDist)
                        local y = center.Y - math.cos(angle) * (Camera.ViewportSize.Y/2 - edgeDist)
                        x = math.clamp(x, edgeDist, Camera.ViewportSize.X - edgeDist)
                        y = math.clamp(y, edgeDist, Camera.ViewportSize.Y - edgeDist)
                        local size = Esp.Arrow.Size or 20
                        Arrows[v].PointA = Vector2.new(x - size/2, y + size/2)
                        Arrows[v].PointB = Vector2.new(x, y - size/2)
                        Arrows[v].PointC = Vector2.new(x + size/2, y + size/2)
                        Arrows[v].Visible = true
                    else
                        Arrows[v].Visible = false
                    end
                end
            end
        end
    end)
end

-- Player Count
do
    local PlayerCountText = Drawing.new("Text")
    PlayerCountText.Size = 14
    PlayerCountText.Font = 2
    PlayerCountText.Center = true
    PlayerCountText.Color = NewRGB(255,255,255)
    PlayerCountText.Transparency = 1
    PlayerCountText.Visible = false
    PlayerCountText.Position = Vector2.new(Camera.ViewportSize.X/2, 20)
    
    RunService.RenderStepped:Connect(function()
        if Esp.PlayerCount and Esp.PlayerCount.Enabled then
            local alive = 0
            local total = 0
            for _, v in pairs(Players:GetPlayers()) do
                if v ~= LocalPlayer then
                    total = total + 1
                    if v.Character and v.Character:FindFirstChild("Humanoid") and v.Character.Humanoid.Health > 0 then
                        alive = alive + 1
                    end
                end
            end
            local text = ""
            if Esp.PlayerCount.ShowAlive then text = "Alive: " .. alive end
            if Esp.PlayerCount.ShowTotal then text = (text ~= "" and text .. " | " or "") .. "Total: " .. total end
            PlayerCountText.Text = text
            PlayerCountText.Color = Esp.PlayerCount.Color or NewRGB(255,255,255)
            PlayerCountText.Size = Esp.PlayerCount.TextSize or 14
            PlayerCountText.Visible = true
        else
            PlayerCountText.Visible = false
        end
    end)
end
print("["..os.date("%X").."] moonlight.cc - Advanced Silent Aim with Resolver Loaded!")
local remoteNames = {}
for _, remote in ipairs(ShootingRemotes) do
    table.insert(remoteNames, remote.Name)
end
print("["..os.date("%X").."] Hooks active for remotes:", table.concat(remoteNames, ", "))                                