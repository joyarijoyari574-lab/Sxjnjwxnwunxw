local scriptOk, scriptErr = pcall(function()

if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
while not Players.LocalPlayer do task.wait(0.1) end
local LocalPlayer = Players.LocalPlayer

pcall(function()
    LocalPlayer.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam
end)

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")
local ProximityPromptService = game:GetService("ProximityPromptService")

local isFarming = false
local farmThread = nil
local startTime = 0

local settings = {
    batchAmount = 1,
    loopBatch = true,
    stopIfDead = true
}

local mBags = {
    "Marshmallow", "Marshmellow", "Large Marshmallow Bag", "Large Marshmellow Bag",
    "Medium Marshmallow Bag", "Medium Marshmellow Bag", "Small Marshmallow Bag", "Small Marshmellow Bag"
}

-- ==========================================
-- KOORDINAT
-- ==========================================
local shopPos = Vector3.new(510.50, 4.5, 598.28)
local sellPos = shopPos
local DEALER_POS = Vector3.new(730.24, 3.70, 449.47)

local ApartmentData = {
    { ID = 7,  BuyPos = Vector3.new(1197.11, 3.71, -237.50), DoorPos = Vector3.new(1199.14, 3.71, -243.04), KitchenPos = Vector3.new(1202.15, -2.29, -220.04) },
    { ID = 8,  BuyPos = Vector3.new(1196.79, 3.71, -201.87), DoorPos = Vector3.new(1199.00, 3.71, -207.04), KitchenPos = Vector3.new(1202.14, -2.29, -180.56) },
    { ID = 9,  BuyPos = Vector3.new(1185.65, 3.71, -207.83), DoorPos = Vector3.new(1183.52, 3.71, -202.90), KitchenPos = Vector3.new(1180.38, -2.29, -188.99) },
    { ID = 10, BuyPos = Vector3.new(1185.42, 3.71, -243.37), DoorPos = Vector3.new(1183.58, 3.71, -238.20), KitchenPos = Vector3.new(1180.41, -2.29, -227.24) }
}

_G.OwnedKitchenPos = nil
_G.OwnedDoorPos = nil
_G.ApartmentOwned = false
local originalGravity = Workspace.Gravity

-- ==========================================
-- ANTI-AFK
-- ==========================================
task.spawn(function()
    pcall(function()
        if getconnections then
            for _, conn in ipairs(getconnections(LocalPlayer.Idled)) do
                if conn.Disable then conn:Disable()
                elseif conn.Disconnect then conn:Disconnect() end
            end
        else
            local vim = game:GetService("VirtualInputManager")
            LocalPlayer.Idled:Connect(function()
                vim:SendKeyEvent(true, Enum.KeyCode.F15, false, game)
                task.wait(0.05)
                vim:SendKeyEvent(false, Enum.KeyCode.F15, false, game)
            end)
        end
    end)
end)

-- ==========================================
-- INSTANT PROXIMITY PROMPT
-- ==========================================
local function makePromptInstant(prompt)
    if prompt:IsA("ProximityPrompt") then
        prompt.HoldDuration = 0
        prompt.RequiresLineOfSight = false
    end
end

for _, obj in ipairs(Workspace:GetDescendants()) do makePromptInstant(obj) end
Workspace.DescendantAdded:Connect(makePromptInstant)
ProximityPromptService.PromptShown:Connect(makePromptInstant)

-- ==========================================
-- INVENTORY MANAGER
-- ==========================================
local function countTool(nameOrList)
    local count = 0
    local char = LocalPlayer.Character
    local backpack = LocalPlayer:FindFirstChild("Backpack")

    local function checkContainer(container)
        if not container then return end
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") then
                if type(nameOrList) == "table" then
                    for _, name in ipairs(nameOrList) do
                        if item.Name == name then count = count + 1 end
                    end
                elseif item.Name == nameOrList then
                    count = count + 1
                end
            end
        end
    end

    checkContainer(char)
    checkContainer(backpack)
    return count
end

local function hasTool(toolName) return countTool(toolName) > 0 end

local function equipTool(toolName)
    local char = LocalPlayer.Character
    if not char then return false end
    local humanoid = char:FindFirstChild("Humanoid")
    if not humanoid then return false end

    if char:FindFirstChild(toolName) then return true end
    humanoid:UnequipTools()
    task.wait(0.05)

    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local targetTool = backpack and backpack:FindFirstChild(toolName)

    if targetTool then
        humanoid:EquipTool(targetTool)
        task.wait(0.1)
        return true
    end
    return false
end

-- ==========================================
-- PROMPT HELPERS
-- ==========================================
local function matchPromptText(actionText, keyword)
    if not keyword then return true end
    local text = string.lower(actionText or "")
    keyword = string.lower(keyword)
    if keyword == "lock" and string.find(text, "unlock") then return false end
    return string.find(text, keyword) ~= nil
end

local function firePromptAt(pos, maxDist, keyword)
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Enabled then
            local pPos = obj.Parent and (obj.Parent:IsA("BasePart") and obj.Parent.Position or (obj.Parent:IsA("Attachment") and obj.Parent.WorldPosition))
            if pPos and (pos - pPos).Magnitude <= maxDist then
                if matchPromptText(obj.ActionText, keyword) then
                    obj.RequiresLineOfSight = false
                    obj.HoldDuration = 0
                    if fireproximityprompt then
                        fireproximityprompt(obj, 0)
                    else
                        obj:InputHoldBegin(); task.wait(0.05); obj:InputHoldEnd()
                    end
                    return true
                end
            end
        end
    end
    return false
end

local function checkPromptExistsAt(pos, maxDist, keyword)
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Enabled then
            local pPos = obj.Parent and (obj.Parent:IsA("BasePart") and obj.Parent.Position or (obj.Parent:IsA("Attachment") and obj.Parent.WorldPosition))
            if pPos and (pos - pPos).Magnitude <= maxDist then
                if matchPromptText(obj.ActionText, keyword) then
                    return true
                end
            end
        end
    end
    return false
end

local function secureDoor(doorPos)
    local maxAttempts = 10
    for i = 1, maxAttempts do
        if not isFarming then return false end
        if checkPromptExistsAt(doorPos, 8, "unlock") then return true end
        if checkPromptExistsAt(doorPos, 8, "lock") then
            firePromptAt(doorPos, 8, "lock")
            task.wait(0.5)
            if checkPromptExistsAt(doorPos, 8, "unlock") then
                return true
            else
                firePromptAt(doorPos, 8, "open")
                task.wait(0.7)
            end
        else
            firePromptAt(doorPos, 8, "open")
            task.wait(0.5)
        end
    end
    return false
end

local function checkDeathStatus()
    if settings.stopIfDead then
        local char = LocalPlayer.Character
        if not char then return true end
        local hum = char:FindFirstChild("Humanoid")
        if hum and hum.Health <= 0 then return true end
    end
    return false
end

-- ==========================================
-- UI + LOADING SCREEN
-- ==========================================
local UI_Target = (gethui and gethui()) or CoreGui or LocalPlayer:WaitForChild("PlayerGui")

for _, name in ipairs({"LuzorHub", "LuzorLoadingScreen"}) do
    if UI_Target:FindFirstChild(name) then UI_Target[name]:Destroy() end
end

local LoadGui = Instance.new("ScreenGui")
LoadGui.Name = "LuzorLoadingScreen"
LoadGui.IgnoreGuiInset = true
LoadGui.ResetOnSpawn = false
LoadGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
LoadGui.DisplayOrder = 999
LoadGui.Parent = UI_Target

local LoadFrame = Instance.new("Frame")
LoadFrame.Size = UDim2.new(1, 0, 1, 0)
LoadFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
LoadFrame.BackgroundTransparency = 1
LoadFrame.Parent = LoadGui

local LoadText = Instance.new("TextLabel")
LoadText.AnchorPoint = Vector2.new(0.5, 0.5)
LoadText.Position = UDim2.new(0.5, 0, 0.5, 0)
LoadText.Size = UDim2.new(0, 250, 0, 50)
LoadText.BackgroundTransparency = 1
LoadText.Font = Enum.Font.GothamBold
LoadText.Text = "wait..."
LoadText.TextColor3 = Color3.fromRGB(255, 255, 255)
LoadText.TextSize = 26
LoadText.TextTransparency = 1
LoadText.Parent = LoadFrame

local isLoading = false
local function showLoadingScreen()
    isLoading = true
    task.spawn(function()
        local dots = 0
        while isLoading do
            dots = (dots + 1) % 4
            LoadText.Text = "wait" .. string.rep(".", dots)
            task.wait(0.35)
        end
    end)
    local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(LoadFrame, tweenInfo, {BackgroundTransparency = 0}):Play()
    local fadeText = TweenService:Create(LoadText, tweenInfo, {TextTransparency = 0})
    fadeText:Play()
    fadeText.Completed:Wait()
end

local function hideLoadingScreen()
    local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(LoadFrame, tweenInfo, {BackgroundTransparency = 1}):Play()
    local fadeText = TweenService:Create(LoadText, tweenInfo, {TextTransparency = 1})
    fadeText:Play()
    fadeText.Completed:Wait()
    isLoading = false
end

-- ==========================================
-- GHOST MODE (buat nembus tembok)
-- ==========================================
local modifiedParts = {}
local ghostConn = nil

local function startGhostMode()
    if ghostConn then return end

    ghostConn = RunService.Heartbeat:Connect(function()
        local char = LocalPlayer.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then return end

        local hum = char:FindFirstChild("Humanoid")
        if hum and hum.Sit then return end

        local hrp = char.HumanoidRootPart

        local function processNoclipPart(part)
            if not part or not part:IsA("BasePart") or part:IsA("Terrain") then return end
            if part:IsDescendantOf(char) then return end

            if part:IsA("Seat") or part:IsA("VehicleSeat") or part.Name:lower():find("seat") then return end
            local model = part:FindFirstAncestorOfClass("Model")
            if model and (model:FindFirstChildOfClass("VehicleSeat", true) or model:FindFirstChildOfClass("Seat", true)) then
                return
            end

            if not modifiedParts[part] then
                modifiedParts[part] = { CanCollide = part.CanCollide, CanTouch = part.CanTouch }
            end
            part.CanCollide = false
            part.CanTouch = false
        end

        for _, part in ipairs(hrp:GetTouchingParts()) do
            processNoclipPart(part)
        end

        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {char}

        local checkDirs = {
            Vector3.new(0, -4, 0),
            hrp.CFrame.LookVector * 3.5,
            -hrp.CFrame.LookVector * 3.5,
            hrp.CFrame.RightVector * 3.5,
            -hrp.CFrame.RightVector * 3.5
        }
        for _, dir in ipairs(checkDirs) do
            local res = workspace:Raycast(hrp.Position, dir, params)
            if res and res.Instance then
                processNoclipPart(res.Instance)
            end
        end
    end)
end

local function stopGhostMode()
    if ghostConn then ghostConn:Disconnect(); ghostConn = nil end
    for part, state in pairs(modifiedParts) do
        if part and part.Parent then
            part.CanCollide = state.CanCollide
            part.CanTouch = state.CanTouch
        end
    end
    modifiedParts = {}
end

-- ==========================================
-- DISCRETE STEP TP (untuk blink)
-- ==========================================
local function discreteStepTP(startP, endP)
    local stepDistance = 0.8
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return false end
    local hrp = char.HumanoidRootPart

    while isFarming do
        if checkDeathStatus() then return false end
        local dist = (endP - hrp.Position).Magnitude
        if dist <= stepDistance then
            hrp.CFrame = CFrame.new(endP)
            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            return true
        else
            hrp.CFrame = CFrame.new(hrp.Position + ((endP - hrp.Position).Unit * stepDistance))
            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        end
        task.wait(0.08)
    end
    return false
end

-- blinkTeleport dengan opsi isUnderground (nembus tembok/lantai)
local function blinkTeleport(targetPos, isUnderground)
    if isUnderground then showLoadingScreen() end
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild('HumanoidRootPart') then
        if isUnderground then hideLoadingScreen() end
        return
    end

    startGhostMode()
    local hrp = char.HumanoidRootPart
    local humanoid = char:FindFirstChild('Humanoid')
    humanoid.PlatformStand = true
    Workspace.Gravity = 0

    if isUnderground then
        local underY = -4
        discreteStepTP(hrp.Position, Vector3.new(hrp.Position.X, underY, hrp.Position.Z))
        discreteStepTP(hrp.Position, Vector3.new(targetPos.X, underY, targetPos.Z))
        discreteStepTP(hrp.Position, targetPos)
    else
        discreteStepTP(hrp.Position, targetPos)
    end

    Workspace.Gravity = originalGravity
    humanoid.PlatformStand = false

    stopGhostMode()

    if isUnderground then hideLoadingScreen() end
end

-- BypassTP (dipakai untuk SetupApartment beli apt, karena butuh respawn)
local function BypassTP(targetPos)
    showLoadingScreen()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local hrp = char.HumanoidRootPart
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Velocity = Vector3.new(0, 9e9, 0)
        bv.Parent = hrp
    end

    local newChar = LocalPlayer.CharacterAdded:Wait()
    local newHrp = newChar:WaitForChild("HumanoidRootPart", 10)
    if newHrp then
        task.wait(0.5)
        newHrp.CFrame = CFrame.new(targetPos)
    end
    task.wait(1.2)
    hideLoadingScreen()
end

-- ==========================================
-- KILL TP DEALER — pakai underground blink (nembus tembok)
-- ==========================================
local function killTPDealer()
    blinkTeleport(DEALER_POS, true)
    return true
end

-- ==========================================
-- VEHICLE TP — SIMPLE HOP (no weld, no heartbeat)
-- ==========================================
local VEH_MAX_SPEED = 150
local vehTpBusy = false

local function doVehicleTP(targetCFrame)
    if vehTpBusy then return false, "Busy" end

    local char = LocalPlayer.Character
    if not char then return false, "No character" end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return false, "No humanoid" end
    if hum.Health <= 0 then return false, "Dead" end

    local seat = hum.SeatPart
    if not seat then return false, "Not seated in vehicle" end

    local vehicle = seat:FindFirstAncestorOfClass("Model")
    if not vehicle then return false, "No vehicle model" end

    local vRoot = vehicle.PrimaryPart or seat
    if not vRoot then return false, "No vehicle root" end

    vehTpBusy = true
    showLoadingScreen()

    local startPos  = vRoot.Position
    local targetPos = targetCFrame.Position + Vector3.new(0, 3, 0)
    local rot       = vRoot.CFrame.Rotation
    local totalDist = (targetPos - startPos).Magnitude

    local HOP_DIST = 30
    local hopCount = math.max(1, math.ceil(totalDist / HOP_DIST))
    local hopDelay = math.clamp(HOP_DIST / VEH_MAX_SPEED, 0.05, 0.5)

    for i = 1, hopCount do
        if not isFarming then break end
        local t = i / hopCount
        local stepPos = startPos:Lerp(targetPos, t)
        pcall(function()
            vehicle:PivotTo(CFrame.new(stepPos) * rot)
        end)
        task.wait(hopDelay)
    end

    pcall(function()
        vehicle:PivotTo(CFrame.new(targetPos) * rot)
    end)
    task.wait(0.25)

    vehTpBusy = false
    hideLoadingScreen()
    return true, string.format("OK (%d hop)", hopCount)
end

-- ==========================================
-- WAIT FOR VEHICLE
-- ==========================================
local function waitForVehicle()
    local startTimeWait = os.clock()
    while isFarming do
        if checkDeathStatus() then return false end
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and hum.SeatPart then
                task.wait(0.5)
                return true
            end
        end
        if (os.clock() - startTimeWait) > 60 then return false end
        task.wait(0.3)
    end
    return false
end

-- ==========================================
-- ELEGANT MENU / UI
-- ==========================================
local Gui = Instance.new("ScreenGui")
Gui.Name = "LuzorHub"
Gui.ResetOnSpawn = false
Gui.DisplayOrder = 99999
Gui.Parent = UI_Target

local Win = Instance.new("Frame")
Win.Size = UDim2.new(0, 190, 0, 160)
Win.Position = UDim2.new(0.5, -95, 0.4, -80)
Win.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
Win.BorderSizePixel = 0
Win.Parent = Gui
Instance.new("UICorner", Win).CornerRadius = UDim.new(0, 8)
local WinStroke = Instance.new("UIStroke", Win)
WinStroke.Color = Color3.fromRGB(60, 50, 90)
WinStroke.Thickness = 1.5

local Topbar = Instance.new("Frame")
Topbar.Size = UDim2.new(1, 0, 0, 30)
Topbar.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
Topbar.BorderSizePixel = 0
Topbar.Parent = Win
Instance.new("UICorner", Topbar).CornerRadius = UDim.new(0, 8)

local TopCover = Instance.new("Frame")
TopCover.Size = UDim2.new(1, 0, 0, 8)
TopCover.Position = UDim2.new(0, 0, 1, -8)
TopCover.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
TopCover.BorderSizePixel = 0
TopCover.Parent = Topbar

local Title = Instance.new("TextLabel")
Title.Text = "dark farm"
Title.Size = UDim2.new(1, -20, 1, 0)
Title.Position = UDim2.new(0, 12, 0, 0)
Title.BackgroundTransparency = 1
Title.TextColor3 = Color3.fromRGB(255, 140, 180)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 12
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Topbar

local Container = Instance.new("Frame")
Container.Size = UDim2.new(1, -24, 1, -40)
Container.Position = UDim2.new(0, 12, 0, 38)
Container.BackgroundTransparency = 1
Container.BorderSizePixel = 0
Container.Parent = Win

local UIList = Instance.new("UIListLayout", Container)
UIList.HorizontalAlignment = Enum.HorizontalAlignment.Center
UIList.SortOrder = Enum.SortOrder.LayoutOrder
UIList.Padding = UDim.new(0, 8)

local FarmRow = Instance.new("Frame")
FarmRow.Size = UDim2.new(1, 0, 0, 22)
FarmRow.BackgroundTransparency = 1
FarmRow.Parent = Container

local FarmLabel = Instance.new("TextLabel")
FarmLabel.Text = "Farming"
FarmLabel.Size = UDim2.new(0.5, 0, 1, 0)
FarmLabel.BackgroundTransparency = 1
FarmLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
FarmLabel.Font = Enum.Font.GothamMedium
FarmLabel.TextSize = 11
FarmLabel.TextXAlignment = Enum.TextXAlignment.Left
FarmLabel.Parent = FarmRow

local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(0, 36, 0, 16)
ToggleBtn.AnchorPoint = Vector2.new(1, 0.5)
ToggleBtn.Position = UDim2.new(1, 0, 0.5, 0)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
ToggleBtn.Text = "OFF"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.TextSize = 9
ToggleBtn.Parent = FarmRow
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(0, 4)

local SliderRow = Instance.new("Frame")
SliderRow.Size = UDim2.new(1, 0, 0, 24)
SliderRow.BackgroundTransparency = 1
SliderRow.Parent = Container

local SliderLabel = Instance.new("TextLabel")
SliderLabel.Text = "[ 1 | $190 ]"
SliderLabel.Size = UDim2.new(1, 0, 0, 12)
SliderLabel.BackgroundTransparency = 1
SliderLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
SliderLabel.Font = Enum.Font.GothamMedium
SliderLabel.TextSize = 11
SliderLabel.TextXAlignment = Enum.TextXAlignment.Left
SliderLabel.Parent = SliderRow

local SliderBg = Instance.new("TextButton")
SliderBg.Text = ""
SliderBg.Size = UDim2.new(1, 0, 0, 4)
SliderBg.Position = UDim2.new(0, 0, 0, 18)
SliderBg.BackgroundColor3 = Color3.fromRGB(36, 36, 48)
SliderBg.AutoButtonColor = false
SliderBg.Parent = SliderRow
Instance.new("UICorner", SliderBg).CornerRadius = UDim.new(1, 0)

local SliderFill = Instance.new("Frame")
SliderFill.Size = UDim2.new((settings.batchAmount/50), 0, 1, 0)
SliderFill.BackgroundColor3 = Color3.fromRGB(255, 140, 180)
SliderFill.Parent = SliderBg
Instance.new("UICorner", SliderFill).CornerRadius = UDim.new(1, 0)

local SliderKnob = Instance.new("Frame")
SliderKnob.Size = UDim2.new(0, 10, 0, 10)
SliderKnob.AnchorPoint = Vector2.new(0.5, 0.5)
SliderKnob.Position = UDim2.new(1, 0, 0.5, 0)
SliderKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
SliderKnob.Parent = SliderFill
Instance.new("UICorner", SliderKnob).CornerRadius = UDim.new(1, 0)

local StatRow = Instance.new("Frame")
StatRow.Size = UDim2.new(1, 0, 0, 45)
StatRow.BackgroundTransparency = 1
StatRow.Parent = Container

local UIListStats = Instance.new("UIListLayout", StatRow)
UIListStats.Padding = UDim.new(0, 4)

local StatStatus = Instance.new("TextLabel")
StatStatus.Size = UDim2.new(1, 0, 0, 12)
StatStatus.BackgroundTransparency = 1
StatStatus.Text = "Status: Idle"
StatStatus.TextColor3 = Color3.fromRGB(160, 160, 180)
StatStatus.Font = Enum.Font.GothamMedium
StatStatus.TextSize = 10
StatStatus.TextXAlignment = Enum.TextXAlignment.Left
StatStatus.Parent = StatRow

local StatMS = Instance.new("TextLabel")
StatMS.Size = UDim2.new(1, 0, 0, 12)
StatMS.BackgroundTransparency = 1
StatMS.Text = "MS : [ 0 ]"
StatMS.TextColor3 = Color3.fromRGB(160, 160, 180)
StatMS.Font = Enum.Font.GothamMedium
StatMS.TextSize = 10
StatMS.TextXAlignment = Enum.TextXAlignment.Left
StatMS.Parent = StatRow

local StatTime = Instance.new("TextLabel")
StatTime.Size = UDim2.new(1, 0, 0, 12)
StatTime.BackgroundTransparency = 1
StatTime.Text = "time : [ 00:00 ]"
StatTime.TextColor3 = Color3.fromRGB(160, 160, 180)
StatTime.Font = Enum.Font.GothamMedium
StatTime.TextSize = 10
StatTime.TextXAlignment = Enum.TextXAlignment.Left
StatTime.Parent = StatRow

local function updateStatusText(text)
    pcall(function()
        StatStatus.Text = "Status: " .. tostring(text)
    end)
end

local dragging, dragInput, dragStart, startPos
Topbar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = input.Position; startPos = Win.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
Topbar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        Win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

local isDraggingSlider = false
local function updateSlider(input)
    local relativeX = math.clamp(input.Position.X - SliderBg.AbsolutePosition.X, 0, SliderBg.AbsoluteSize.X)
    local percentage = relativeX / SliderBg.AbsoluteSize.X
    local min, max = 1, 50
    settings.batchAmount = math.floor(min + (percentage * (max - min)))
    SliderFill.Size = UDim2.new(percentage, 0, 1, 0)
    local cost = settings.batchAmount * 190
    SliderLabel.Text = string.format("[ %d | $%d ]", settings.batchAmount, cost)
end

SliderBg.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDraggingSlider = true; updateSlider(input)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then isDraggingSlider = false end
end)
UserInputService.InputChanged:Connect(function(input)
    if isDraggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        updateSlider(input)
    end
end)

-- ==========================================
-- SETUP APARTMENT (ORIGINAL)
-- ==========================================
local function SetupApartment()
    updateStatusText("BUY APARTMENT...")

    local targetData = nil
    for _, data in ipairs(ApartmentData) do
        if not isFarming then return false end
        local isVacant = false
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("TextLabel") and string.find(string.upper(obj.Text), "VACANT") then
                local gui = obj:FindFirstAncestorOfClass("SurfaceGui") or obj:FindFirstAncestorOfClass("BillboardGui")
                local uiPart = gui and (gui.Adornee or gui.Parent)
                if uiPart and uiPart:IsA("BasePart") and (uiPart.Position - data.BuyPos).Magnitude <= 5 then
                    isVacant = true; break
                end
            end
        end
        if isVacant then targetData = data; break end
    end

    if not targetData then
        updateStatusText("No Vacant Apt!")
        return false
    end

    BypassTP(targetData.BuyPos)
    if not isFarming then return false end

    firePromptAt(targetData.BuyPos, 5, "purchase")
    task.wait(1)

    _G.OwnedKitchenPos = targetData.KitchenPos
    _G.OwnedDoorPos = targetData.DoorPos
    _G.ApartmentOwned = true

    blinkTeleport(targetData.DoorPos, false)
    if not isFarming then return false end
    task.wait(0.8)

    secureDoor(targetData.DoorPos)

    return true
end

-- ==========================================
-- BUY INGREDIENTS
-- ==========================================
local function robustBuy()
    local target = settings.batchAmount
    while isFarming do
        if checkDeathStatus() then return end
        local wCount = countTool({"Water", "Water23"})
        local sCount = countTool("Sugar Block Bag")
        local gCount = countTool("Gelatin")
        if wCount >= target and sCount >= target and gCount >= target then break end

        local rs = ReplicatedStorage:FindFirstChild("RemoteEvents")
        if rs and rs:FindFirstChild("ReliableRemoteEvent") then
            local remote = rs.ReliableRemoteEvent
            if gCount < target then
                local buf = buffer.create(3)
                buffer.writeu8(buf, 0, 24); buffer.writeu8(buf, 1, 19); buffer.writeu8(buf, 2, 1)
                remote:FireServer(buf); task.wait(0.35)
            end
            if sCount < target then
                local buf = buffer.create(3)
                buffer.writeu8(buf, 0, 24); buffer.writeu8(buf, 1, 19); buffer.writeu8(buf, 2, 2)
                remote:FireServer(buf); task.wait(0.35)
            end
            if wCount < target then
                local buf = buffer.create(3)
                buffer.writeu8(buf, 0, 24); buffer.writeu8(buf, 1, 19); buffer.writeu8(buf, 2, 3)
                remote:FireServer(buf); task.wait(0.35)
            end
        end
        task.wait(0.4)
    end
end

-- ==========================================
-- PUT INGREDIENT
-- ==========================================
local function robustPutIngredient(toolNameOrList, waitTimeAfter)
    if not isFarming then return false end
    local initialCount = countTool(toolNameOrList)
    if initialCount == 0 then return false end

    local attempts = 0
    local maxAttempts = 30

    while isFarming and countTool(toolNameOrList) >= initialCount and attempts < maxAttempts do
        if checkDeathStatus() then return false end
        if type(toolNameOrList) == "table" then
            for _, name in ipairs(toolNameOrList) do
                if countTool(name) > 0 then equipTool(name); break end
            end
        else
            equipTool(toolNameOrList)
        end
        task.wait(0.2)
        firePromptAt(_G.OwnedKitchenPos, 10)
        task.wait(1.2)
        attempts = attempts + 1
    end

    if countTool(toolNameOrList) < initialCount then
        if waitTimeAfter and waitTimeAfter > 0 then
            local waitStart = os.clock()
            while isFarming and (os.clock() - waitStart) < waitTimeAfter do
                if checkDeathStatus() then return false end
                task.wait(0.5)
            end
        end
        return true
    end
    return false
end

-- ==========================================
-- COOK ONE BATCH
-- ==========================================
local function cookOneBatch()
    updateStatusText("COOKING WATER...")
    local wOk = robustPutIngredient({"Water", "Water23"}, 23)
    if not wOk then return false end
    if not isFarming then return false end

    updateStatusText("COOKING SUGAR...")
    robustPutIngredient("Sugar Block Bag", 0)
    if not isFarming then return false end

    updateStatusText("COOKING GELATIN...")
    robustPutIngredient("Gelatin", 47)
    if not isFarming then return false end

    return true
end

-- ==========================================
-- COLLECT MARSHMALLOW
-- ==========================================
local function collectMarshmallow()
    updateStatusText("COLLECTING MARSHMALLOW...")
    local initialMarshmallows = countTool(mBags)
    local timeout = 0
    local maxTimeout = 200

    while isFarming and countTool(mBags) <= initialMarshmallows and timeout < maxTimeout do
        if checkDeathStatus() then return false end
        equipTool("Empty Bag")
        firePromptAt(_G.OwnedKitchenPos, 12)
        task.wait(0.3)
        timeout = timeout + 1
    end

    if countTool(mBags) > initialMarshmallows then
        if countTool({"Water", "Water23"}) > 0 then equipTool("Water") end
        return true
    end
    return false
end

-- ==========================================
-- SELL ALL BAGS
-- ==========================================
local function sellAllBags()
    if not isFarming then return end
    updateStatusText("SELLING...")
    for _, name in ipairs(mBags) do
        while hasTool(name) and isFarming do
            if checkDeathStatus() then isFarming = false break end
            equipTool(name)
            task.wait(0.25)
            local char = LocalPlayer.Character
            if char and char:FindFirstChild(name) then
                firePromptAt(sellPos, 10); task.wait(0.4)
            else
                task.wait(0.2)
            end
        end
    end
    task.wait(0.4)
end

-- ==========================================
-- RUN FARM
-- ==========================================
local function RunFarm()
    -- 1. BUY APARTMENT + LOCK DOOR
    if not _G.ApartmentOwned or not _G.OwnedKitchenPos then
        if not SetupApartment() then
            isFarming = false
            return
        end
        if not isFarming then return end
    end

    -- 2. BLINK TP KE DEALER (UNDERGROUND - nembus tembok)
    updateStatusText("GOING TO DEALER...")
    killTPDealer()
    if not isFarming then return end
    task.wait(1)

    -- 3. WAIT MOTOR
    updateStatusText("WAITING FOR MOTOR...")
    if not waitForVehicle() then
        isFarming = false
        return
    end
    task.wait(0.5)

    -- 4. LOOP
    while isFarming do
        if checkDeathStatus() then isFarming = false break end

        updateStatusText("GOING TO SHOP...")
        local ok, msg = doVehicleTP(CFrame.new(shopPos))
        if not ok then
            updateStatusText("TP Shop Failed: " .. tostring(msg))
            isFarming = false; break
        end
        task.wait(0.3)

        updateStatusText("BUYING INGREDIENTS...")
        robustBuy()
        if not isFarming then break end

        updateStatusText("GOING TO APARTMENT...")
        ok, msg = doVehicleTP(CFrame.new(_G.OwnedKitchenPos))
        if not ok then
            updateStatusText("TP Apt Failed: " .. tostring(msg))
            isFarming = false; break
        end
        task.wait(0.3)

        while isFarming
              and countTool({"Water", "Water23"}) > 0
              and countTool("Sugar Block Bag") > 0
              and countTool("Gelatin") > 0 do
            if checkDeathStatus() then isFarming = false; break end

            if not cookOneBatch() then
                isFarming = false; break
            end
            if not isFarming then break end

            collectMarshmallow()
            if not isFarming then break end
        end
        if not isFarming then break end

        updateStatusText("RETURNING TO SHOP...")
        ok, msg = doVehicleTP(CFrame.new(shopPos))
        if not ok then
            updateStatusText("TP Shop Failed: " .. tostring(msg))
            isFarming = false; break
        end
        task.wait(0.3)

        sellAllBags()
        if not isFarming then break end

        updateStatusText("FARM COMPLETE — LOOPING...")
        task.wait(1)

        if not settings.loopBatch then break end
    end

    isFarming = false
end

-- ==========================================
-- UI TOGGLE
-- ==========================================
local function setUIState(running)
    if running then
        ToggleBtn.Text = "ON"
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 80)
        SliderBg.Active = false
    else
        ToggleBtn.Text = "OFF"
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
        if StatStatus.Text ~= "Status: Stopped (Died)" then
            updateStatusText("Idle")
        end
        SliderBg.Active = true
    end
end

ToggleBtn.MouseButton1Click:Connect(function()
    isFarming = not isFarming
    if isFarming then
        startTime = os.time()
    end
    setUIState(isFarming)

    if isFarming then
        updateStatusText("running")
        farmThread = task.spawn(function()
            RunFarm()
            if isFarming then
                isFarming = false
                setUIState(false)
            end
        end)
    end
end)

-- ==========================================
-- BACKGROUND TRACKER
-- ==========================================
task.spawn(function()
    while task.wait(0.5) do
        if not Gui.Parent then break end

        local msCount = countTool(mBags)
        StatMS.Text = string.format("MS : [ %d ]", msCount)

        if isFarming and startTime > 0 then
            local elapsed = os.time() - startTime
            local hours = math.floor(elapsed / 3600)
            local mins = math.floor((elapsed % 3600) / 60)
            local secs = elapsed % 60

            if hours > 0 then
                StatTime.Text = string.format("time : [ %02d:%02d:%02d ]", hours, mins, secs)
            else
                StatTime.Text = string.format("time : [ %02d:%02d ]", mins, secs)
            end
        else
            StatTime.Text = "time : [ 00:00 ]"
        end

        if isFarming and checkDeathStatus() then
            StatStatus.Text = "Status: Stopped (Died)"
            isFarming = false
            setUIState(false)
        end
    end
end)

end)
if not scriptOk then warn("Error:", scriptErr) end