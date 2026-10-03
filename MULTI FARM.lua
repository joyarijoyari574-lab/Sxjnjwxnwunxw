-- ================================================================
-- DARK HUB — MULTI FARM v4 (fullscreen black loading)
-- ================================================================
if not game:IsLoaded() then game.Loaded:Wait() end

local Players              = game:GetService("Players")
local Workspace            = game:GetService("Workspace")
local RunService           = game:GetService("RunService")
local CoreGui              = game:GetService("CoreGui")
local UserInputService     = game:GetService("UserInputService")
local TweenService         = game:GetService("TweenService")
local VirtualUser          = game:GetService("VirtualUser")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage    = game:GetService("ReplicatedStorage")
local VirtualInputManager  = game:GetService("VirtualInputManager")

while not Players.LocalPlayer do task.wait(0.1) end
local LP = Players.LocalPlayer
local originalGravity = Workspace.Gravity

-- ================================================================
-- KONSTANTA
-- ================================================================
local ApartmentData = {
    { ID = 7,  BuyPos = Vector3.new(1197.11, 3.71, -237.50), DoorPos = Vector3.new(1199.14, 3.71, -243.04), KitchenPos = Vector3.new(1202.15, -2.29, -220.04) },
    { ID = 8,  BuyPos = Vector3.new(1196.79, 3.71, -201.87), DoorPos = Vector3.new(1199.00, 3.71, -207.04), KitchenPos = Vector3.new(1202.14, -2.29, -180.56) },
    { ID = 9,  BuyPos = Vector3.new(1185.65, 3.71, -207.83), DoorPos = Vector3.new(1183.52, 3.71, -202.90), KitchenPos = Vector3.new(1180.38, -2.29, -188.99) },
    { ID = 10, BuyPos = Vector3.new(1185.42, 3.71, -243.37), DoorPos = Vector3.new(1183.58, 3.71, -238.20), KitchenPos = Vector3.new(1180.41, -2.29, -227.24) }
}

local SHOP_POS    = Vector3.new(510.50, 4.5, 598.28)
local SELL_POS    = SHOP_POS
local DEALER_POS  = Vector3.new(730.24, 3.70, 449.47)
local M_BAGS = {
    "Marshmallow", "Marshmellow", "Large Marshmallow Bag", "Large Marshmellow Bag",
    "Medium Marshmallow Bag", "Medium Marshmellow Bag", "Small Marshmallow Bag", "Small Marshmellow Bag"
}

local LOC_FakeID        = Vector3.new( 214.960, 1.857, -332.330)
local LOC_ApplyForCard  = Vector3.new( -49.210, 4.000, -310.810)
local CARD_FALLBACK_POS = Vector3.new( -39.090, 5.392, -329.700)

local CHIPS_BUY_LOC = Vector3.new(-759.197, 3.489, -194.846)
local CHIPS_COORDS = {
    A = Vector3.new(-478.83, 3.86, -438.92),
    B = Vector3.new(-461.69, 3.86, -461.25),
    C = Vector3.new(-461.69, 3.86, -472.88),
    D = Vector3.new(-462.75, 3.86, -521.94),
}
local CHIPS_POTS = {
    Vector3.new(-515.28, 3.86, -451.71), Vector3.new(-515.24, 3.86, -462.26),
    Vector3.new(-515.28, 3.86, -471.89), Vector3.new(-515.28, 3.86, -481.75),
    Vector3.new(-515.24, 3.86, -492.10), Vector3.new(-496.99, 3.86, -452.21),
    Vector3.new(-496.95, 3.86, -462.02), Vector3.new(-496.98, 3.86, -471.73),
    Vector3.new(-496.99, 3.86, -481.82), Vector3.new(-497.04, 3.86, -491.37),
}
local SC_HOMELESS = {
    Vector3.new(-315.35, 3.72,  -361.56), Vector3.new(-273.52, 3.85,  -211.32),
    Vector3.new(1102.42, 3.36,  527.05),  Vector3.new(52.89,   3.72,  -425.36),
    Vector3.new(152.88,  3.73,  -210.08), Vector3.new(-522.75, -7.86, -165.08),
    Vector3.new(65.12,   3.73,  68.10),   Vector3.new(26.04,   3.73,  217.89),
    Vector3.new(520.08,  3.87,  -295.52), Vector3.new(699.28,  3.72,  -427.05),
    Vector3.new(900.03,  3.94,  -283.12), Vector3.new(874.89,  3.73,  -63.02),
}
local SC_TUKAR = Vector3.new(-34.91, 4.56, -24.15)
local SC_COOK  = Vector3.new(-487.11, 3.86, -454.16)

local IDX_FLOUR  = 1
local IDX_POTATO = 2

local RE
pcall(function()
    RE = ReplicatedStorage:WaitForChild("RemoteEvents", 5):WaitForChild("ReliableRemoteEvent", 5)
end)

local MAX_SPEED = 150
local HOP_DIST  = 15
local MIN_DELAY = 0.04
local MAX_DELAY = 0.5

-- ================================================================
-- STATE
-- ================================================================
local STATE = {
    running          = false,
    step             = "IDLE",
    cycle            = 0,
    retry            = 0,
    lastError        = "",
    startTime        = 0,
    pot              = 1,
    homelessIdx      = 1,
    targetChips      = 1,      -- FIXED 1 per cycle
    hasApartment     = false,
    apartmentLocked  = false,
    aptKitchen       = nil,
    aptDoor          = nil,
    -- STATS
    marshBagsSold    = 0,
    hotChipsSold     = 0,
    cardsSwiped      = 0,
    moneyGained      = 0,
    startMoney       = nil,
}

-- ================================================================
-- MONEY READER (best-effort)
-- ================================================================
local function readMoney()
    local ls = LP:FindFirstChild("leaderstats")
    if ls then
        for _, v in ipairs(ls:GetChildren()) do
            if v:IsA("IntValue") or v:IsA("NumberValue") or v:IsA("StringValue") then
                local n = v.Name:lower()
                if n:find("money") or n:find("cash") or n:find("dollar") or n:find("coin") then
                    return tonumber(v.Value) or 0
                end
            end
        end
    end
    local pg = LP:FindFirstChild("PlayerGui")
    if pg then
        for _, d in ipairs(pg:GetDescendants()) do
            if d:IsA("TextLabel") then
                local t = d.Text
                if t then
                    local m = string.match(t, "%$%s*([%d,]+)")
                    if m then return tonumber((m:gsub(",", ""))) or 0 end
                end
            end
        end
    end
    return nil
end

-- ================================================================
-- LOADING SCREEN
-- ================================================================
local UI_Target = (gethui and gethui()) or CoreGui or LP:WaitForChild("PlayerGui")
for _, nm in ipairs({"MultiFarm_UI", "MultiFarm_Loading", "DarkHub_UI", "DarkHub_Loading", "AutoFullCycle_UI", "LENGER_CardScam_UI", "LuzorHub", "LuzorLoadingScreen"}) do
    local o = UI_Target:FindFirstChild(nm)
    if o then pcall(function() o:Destroy() end) end
end

local LoadGui = Instance.new("ScreenGui")
LoadGui.Name = "DarkHub_Loading"
LoadGui.ResetOnSpawn = false
LoadGui.DisplayOrder = 99998
LoadGui.IgnoreGuiInset = true
LoadGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
LoadGui.Parent = UI_Target

local LoadFrame = Instance.new("Frame", LoadGui)
LoadFrame.Size = UDim2.new(1, 0, 1, 0)
LoadFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
LoadFrame.BackgroundTransparency = 1
LoadFrame.BorderSizePixel = 0

local LoadText = Instance.new("TextLabel", LoadFrame)
LoadText.AnchorPoint = Vector2.new(0.5, 0.5)
LoadText.Position = UDim2.new(0.5, 0, 0.5, 0)
LoadText.Size = UDim2.new(0, 400, 0, 60)
LoadText.BackgroundTransparency = 1
LoadText.Font = Enum.Font.GothamBold
LoadText.Text = "wait..."
LoadText.TextColor3 = Color3.fromRGB(255, 255, 255)
LoadText.TextSize = 26
LoadText.TextTransparency = 1

local loadingActive = false
local dotThread = nil
local FADE_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function showLoading()
    if loadingActive then return end
    loadingActive = true
    LoadFrame.BackgroundTransparency = 1
    LoadText.TextTransparency = 1
    LoadText.Text = "wait..."
    TweenService:Create(LoadFrame, FADE_INFO, {BackgroundTransparency = 0}):Play()
    TweenService:Create(LoadText, FADE_INFO, {TextTransparency = 0}):Play()
    if dotThread then task.cancel(dotThread) end
    dotThread = task.spawn(function()
        local n = 0
        while loadingActive do
            n = (n % 3) + 1
            pcall(function() LoadText.Text = "wait" .. string.rep(".", n) end)
            task.wait(0.35)
        end
    end)
end

local function hideLoading()
    if not loadingActive then return end
    loadingActive = false
    if dotThread then task.cancel(dotThread); dotThread = nil end
    local t1 = TweenService:Create(LoadFrame, FADE_INFO, {BackgroundTransparency = 1})
    local t2 = TweenService:Create(LoadText, FADE_INFO, {TextTransparency = 1})
    t1:Play(); t2:Play()
    pcall(function() LoadText.Text = "wait..." end)
end

-- ================================================================
-- UI PANEL  (DARK HUB)
-- ================================================================
local Gui = Instance.new("ScreenGui")
Gui.Name = "DarkHub_UI"
Gui.ResetOnSpawn = false
Gui.DisplayOrder = 99999
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.Parent = UI_Target

local Panel = Instance.new("Frame", Gui)
Panel.Size = UDim2.new(0, 300, 0, 430)
Panel.Position = UDim2.new(0.05, 0, 0.15, 0)
Panel.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
Panel.BorderSizePixel = 0
Panel.Active = true
Instance.new("UICorner", Panel).CornerRadius = UDim.new(0, 10)
local ps = Instance.new("UIStroke", Panel); ps.Color = Color3.fromRGB(140, 60, 255); ps.Thickness = 1.5

local Head = Instance.new("Frame", Panel)
Head.Size = UDim2.new(1, 0, 0, 34)
Head.BackgroundColor3 = Color3.fromRGB(20, 10, 35)
Head.BorderSizePixel = 0
Instance.new("UICorner", Head).CornerRadius = UDim.new(0, 10)
local hFix = Instance.new("Frame", Head)
hFix.Size = UDim2.new(1, 0, 0, 10); hFix.Position = UDim2.new(0, 0, 1, -10)
hFix.BackgroundColor3 = Color3.fromRGB(20, 10, 35); hFix.BorderSizePixel = 0

local Title = Instance.new("TextLabel", Head)
Title.Size = UDim2.new(1, -40, 1, 0); Title.Position = UDim2.new(0, 12, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "🌑 DARK HUB"
Title.TextColor3 = Color3.fromRGB(180, 130, 255)
Title.Font = Enum.Font.GothamBlack; Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left

local CloseBtn = Instance.new("TextButton", Head)
CloseBtn.Size = UDim2.new(0, 22, 0, 22); CloseBtn.Position = UDim2.new(1, -26, 0.5, -11)
CloseBtn.BackgroundColor3 = Color3.fromRGB(35, 12, 12)
CloseBtn.Text = "×"; CloseBtn.TextColor3 = Color3.fromRGB(220, 80, 80)
CloseBtn.Font = Enum.Font.GothamBlack; CloseBtn.TextSize = 16; CloseBtn.AutoButtonColor = false
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 5)

local Body = Instance.new("Frame", Panel)
Body.Size = UDim2.new(1, -20, 1, -44); Body.Position = UDim2.new(0, 10, 0, 40)
Body.BackgroundTransparency = 1
local BL = Instance.new("UIListLayout", Body)
BL.Padding = UDim.new(0, 6); BL.SortOrder = Enum.SortOrder.LayoutOrder

-- Toggle button
local ToggleBtn = Instance.new("TextButton", Body)
ToggleBtn.Size = UDim2.new(1, 0, 0, 38)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(35, 12, 12)
ToggleBtn.Text = "▶ START MULTI FARM"
ToggleBtn.TextColor3 = Color3.fromRGB(220, 80, 80)
ToggleBtn.Font = Enum.Font.GothamBlack; ToggleBtn.TextSize = 13
ToggleBtn.AutoButtonColor = false; ToggleBtn.LayoutOrder = 1
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(0, 8)
local tStr = Instance.new("UIStroke", ToggleBtn)
tStr.Color = Color3.fromRGB(80, 25, 25); tStr.Thickness = 1

local function mkRow(order, h)
    local f = Instance.new("Frame", Body)
    f.Size = UDim2.new(1, 0, 0, h)
    f.BackgroundColor3 = Color3.fromRGB(18, 16, 24)
    f.LayoutOrder = order
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
    Instance.new("UIStroke", f).Color = Color3.fromRGB(50, 40, 70)
    return f
end

-- Chips/cycle info (fixed = 1)
local ChipsRow = mkRow(2, 26)
local ChipsLbl = Instance.new("TextLabel", ChipsRow)
ChipsLbl.Size = UDim2.new(1, -16, 1, 0); ChipsLbl.Position = UDim2.new(0, 10, 0, 0)
ChipsLbl.BackgroundTransparency = 1
ChipsLbl.Text = "🍟 Chips/cycle: 1"
ChipsLbl.TextColor3 = Color3.fromRGB(200, 200, 220)
ChipsLbl.Font = Enum.Font.GothamBold; ChipsLbl.TextSize = 11
ChipsLbl.TextXAlignment = Enum.TextXAlignment.Left

-- Info row (step/cycle/retry/runtime/err)
local InfoRow = mkRow(3, 78)
local InfoLbl = Instance.new("TextLabel", InfoRow)
InfoLbl.Size = UDim2.new(1, -16, 1, -8); InfoLbl.Position = UDim2.new(0, 8, 0, 4)
InfoLbl.BackgroundTransparency = 1
InfoLbl.TextXAlignment = Enum.TextXAlignment.Left
InfoLbl.TextYAlignment = Enum.TextYAlignment.Top
InfoLbl.TextColor3 = Color3.fromRGB(200, 180, 255)
InfoLbl.Font = Enum.Font.Code; InfoLbl.TextSize = 10
InfoLbl.Text = "Step   : IDLE\nCycle  : 0\nRetry  : 0\nRuntime: 00:00:00\nErr    : -"

-- Status row
local StatusRow = mkRow(4, 40)
local StatusLbl = Instance.new("TextLabel", StatusRow)
StatusLbl.Size = UDim2.new(1, -12, 1, -6); StatusLbl.Position = UDim2.new(0, 6, 0, 3)
StatusLbl.BackgroundTransparency = 1
StatusLbl.TextXAlignment = Enum.TextXAlignment.Left
StatusLbl.TextYAlignment = Enum.TextYAlignment.Top
StatusLbl.TextColor3 = Color3.fromRGB(140, 255, 180)
StatusLbl.Font = Enum.Font.GothamBold; StatusLbl.TextSize = 11
StatusLbl.TextWrapped = true
StatusLbl.Text = "Status: Idle"

local function setStatus(txt, col)
    pcall(function()
        StatusLbl.Text = "Status: " .. tostring(txt)
        if col then StatusLbl.TextColor3 = col end
    end)
end
local function setStep(name)
    STATE.step = name
    local rt = 0
    if STATE.startTime > 0 and STATE.running then rt = os.time() - STATE.startTime end
    local h = math.floor(rt / 3600); local m = math.floor((rt % 3600) / 60); local s = rt % 60
    InfoLbl.Text = string.format(
        "Step   : %s\nCycle  : %d\nRetry  : %d\nRuntime: %02d:%02d:%02d\nErr    : %s",
        name, STATE.cycle, STATE.retry, h, m, s, STATE.lastError ~= "" and STATE.lastError:sub(1, 30) or "-")
end

-- STATS row  📊 STATUS MULTI FARM
local StatsRow = mkRow(5, 118)
local StatsLbl = Instance.new("TextLabel", StatsRow)
StatsLbl.Size = UDim2.new(1, -12, 1, -6); StatsLbl.Position = UDim2.new(0, 6, 0, 3)
StatsLbl.BackgroundTransparency = 1
StatsLbl.TextXAlignment = Enum.TextXAlignment.Left
StatsLbl.TextYAlignment = Enum.TextYAlignment.Top
StatsLbl.TextColor3 = Color3.fromRGB(220, 210, 255)
StatsLbl.Font = Enum.Font.GothamBold; StatsLbl.TextSize = 11
StatsLbl.TextWrapped = true
StatsLbl.RichText = false
StatsLbl.Text = "📊 STATUS MULTI FARM\n⏱️ Multi Farm Time: 0h 0m 0s\n💰 Money Gained: $0\n🍡 Marshmallow Bags Sold: 0\n🍟 Hot-Chips Sold: 0\n💳 Cards Swiped: 0"

local function refreshStats()
    local rt = 0
    if STATE.startTime > 0 and STATE.running then rt = os.time() - STATE.startTime end
    local h = math.floor(rt / 3600)
    local m = math.floor((rt % 3600) / 60)
    local s = rt % 60
    StatsLbl.Text = string.format(
        "📊 STATUS MULTI FARM\n⏱️ Multi Farm Time: %dh %dm %ds\n💰 Money Gained: $%s\n🍡 Marshmallow Bags Sold: %d\n🍟 Hot-Chips Sold: %d\n💳 Cards Swiped: %d",
        h, m, s,
        tostring(math.floor(STATE.moneyGained or 0)),
        STATE.marshBagsSold or 0,
        STATE.hotChipsSold or 0,
        STATE.cardsSwiped or 0
    )
end

local function refreshToggle()
    local on = STATE.running
    ToggleBtn.Text = on and "■ STOP MULTI FARM" or "▶ START MULTI FARM"
    ToggleBtn.BackgroundColor3 = on and Color3.fromRGB(25, 10, 45) or Color3.fromRGB(35, 12, 12)
    ToggleBtn.TextColor3 = on and Color3.fromRGB(180, 130, 255) or Color3.fromRGB(220, 80, 80)
    tStr.Color = on and Color3.fromRGB(90, 50, 160) or Color3.fromRGB(80, 25, 25)
end
refreshToggle()

-- Drag
do
    local d, ds, sp
    Head.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            d = true; ds = i.Position; sp = Panel.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then d = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if d and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local dd = i.Position - ds
            Panel.Position = UDim2.new(sp.X.Scale, sp.X.Offset + dd.X, sp.Y.Scale, sp.Y.Offset + dd.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then d = false end
    end)
end

CloseBtn.MouseButton1Click:Connect(function()
    STATE.running = false
    hideLoading()
    pcall(function() Gui:Destroy() end)
    pcall(function() LoadGui:Destroy() end)
end)

-- ================================================================
-- ANTI-AFK
-- ================================================================
task.spawn(function()
    pcall(function()
        if getconnections then
            for _, c in ipairs(getconnections(LP.Idled)) do
                if c.Disable then c:Disable() end
            end
        end
        LP.Idled:Connect(function()
            pcall(function()
                VirtualUser:Button2Down(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
                task.wait(1)
                VirtualUser:Button2Up(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
            end)
        end)
    end)
end)

-- ================================================================
-- PROMPT
-- ================================================================
local function makePromptInstant(p)
    if p:IsA("ProximityPrompt") then
        pcall(function()
            p.HoldDuration = 0
            p.RequiresLineOfSight = false
        end)
    end
end
for _, o in ipairs(Workspace:GetDescendants()) do makePromptInstant(o) end
Workspace.DescendantAdded:Connect(makePromptInstant)
ProximityPromptService.PromptShown:Connect(makePromptInstant)

local function getPromptPos(p)
    local par = p.Parent
    if not par then return nil end
    if par:IsA("BasePart") then return par.Position end
    if par:IsA("Attachment") then return par.WorldPosition end
    if par:IsA("Model") then
        local rp = par.PrimaryPart or par:FindFirstChildOfClass("BasePart")
        if rp then return rp.Position end
    end
    if par:IsA("Folder") then
        local rp = par:FindFirstChildOfClass("BasePart")
        if rp then return rp.Position end
    end
    return nil
end

local function matchPromptText(actionText, keyword)
    if not keyword then return true end
    local t = string.lower(actionText or "")
    keyword = string.lower(keyword)
    if keyword == "lock" and string.find(t, "unlock") then return false end
    return string.find(t, keyword) ~= nil
end

local function firePrompt(p)
    if not p or not p.Enabled then return false end
    pcall(function()
        p.HoldDuration = 0
        p.RequiresLineOfSight = false
        p.MaxActivationDistance = 9e9
    end)
    local ok = false
    if fireproximityprompt then
        ok = pcall(function() fireproximityprompt(p, 0) end)
    end
    if not ok then
        pcall(function()
            p:InputHoldBegin(); task.wait(0.05); p:InputHoldEnd()
        end)
    end
    return true
end

local function firePromptAt(pos, maxDist, keyword)
    maxDist = maxDist or 10
    local best, bestD = nil, maxDist
    for _, o in ipairs(Workspace:GetDescendants()) do
        if o:IsA("ProximityPrompt") and o.Enabled then
            local p = getPromptPos(o)
            if p then
                local d = (pos - p).Magnitude
                if d <= bestD and matchPromptText(o.ActionText, keyword) then
                    bestD = d; best = o
                end
            end
        end
    end
    if not best then return false end
    return firePrompt(best)
end

local function findPromptNear(pos, radius, keyword)
    radius = radius or 20
    local best, bestD = nil, radius
    for _, o in ipairs(Workspace:GetDescendants()) do
        if o:IsA("ProximityPrompt") and o.Enabled then
            local p = getPromptPos(o)
            if p then
                local d = (pos - p).Magnitude
                if d < bestD and matchPromptText(o.ActionText, keyword) then
                    bestD = d; best = o
                end
            end
        end
    end
    return best, bestD
end

local function checkPromptExistsAt(pos, maxD, keyword)
    local p = findPromptNear(pos, maxD, keyword)
    return p ~= nil
end

-- ================================================================
-- INVENTORY
-- ================================================================
local function countTool(nameOrList)
    local c = 0
    local function check(cont)
        if not cont then return end
        for _, it in ipairs(cont:GetChildren()) do
            if it:IsA("Tool") then
                if type(nameOrList) == "table" then
                    for _, n in ipairs(nameOrList) do
                        if it.Name == n then c = c + 1; break end
                    end
                elseif it.Name == nameOrList then
                    c = c + 1
                end
            end
        end
    end
    check(LP.Character); check(LP:FindFirstChild("Backpack"))
    return c
end

local function hasTool(n) return countTool(n) > 0 end

local function equipTool(name)
    local ch = LP.Character
    if not ch then return false end
    local hum = ch:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    if ch:FindFirstChild(name) then return true end
    pcall(function() hum:UnequipTools() end)
    task.wait(0.1)
    local bp = LP:FindFirstChild("Backpack")
    if not bp then return false end
    local tool = bp:FindFirstChild(name)
    if not tool then
        for _, v in ipairs(bp:GetChildren()) do
            if v:IsA("Tool") and v.Name:lower():find(name:lower()) then
                tool = v; break
            end
        end
    end
    if not tool then return false end
    pcall(function() hum:EquipTool(tool) end)
    local t0 = os.clock()
    while os.clock() - t0 < 1.5 do
        if ch:FindFirstChild(tool.Name) then return true end
        task.wait(0.05)
    end
    return true
end

local function unequipAll()
    local ch = LP.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    if hum then pcall(function() hum:UnequipTools() end) end
end

local function countPotatoChips()
    local a = countTool("Chips")
    if a > 0 then return a end
    return countTool("Potato Chips")
end

local function getFakeIDCount()
    local c = 0
    local function chk(cont)
        if not cont then return end
        for _, v in ipairs(cont:GetChildren()) do
            if v:IsA("Tool") then
                local n = v.Name:lower()
                if n:find("fake") and n:find("id") then c = c + 1 end
            end
        end
    end
    chk(LP:FindFirstChild("Backpack")); chk(LP.Character)
    return c
end

-- ================================================================
-- GHOST MODE
-- ================================================================
local modifiedParts = {}
local ghostConn = nil

local function startGhostMode()
    if ghostConn then return end
    ghostConn = RunService.Heartbeat:Connect(function()
        local ch = LP.Character
        if not ch or not ch:FindFirstChild("HumanoidRootPart") then return end
        local hum = ch:FindFirstChild("Humanoid")
        if hum and hum.Sit then return end
        local hrp = ch.HumanoidRootPart
        local function proc(part)
            if not part or not part:IsA("BasePart") or part:IsA("Terrain") then return end
            if part:IsDescendantOf(ch) then return end
            if part:IsA("Seat") or part:IsA("VehicleSeat") or part.Name:lower():find("seat") then return end
            if not modifiedParts[part] then
                modifiedParts[part] = { CanCollide = part.CanCollide, CanTouch = part.CanTouch }
            end
            part.CanCollide = false; part.CanTouch = false
        end
        for _, p in ipairs(hrp:GetTouchingParts()) do proc(p) end
        local rp = RaycastParams.new()
        rp.FilterType = Enum.RaycastFilterType.Exclude
        rp.FilterDescendantsInstances = {ch}
        for _, d in ipairs({
            Vector3.new(0, -4, 0), hrp.CFrame.LookVector * 3.5, -hrp.CFrame.LookVector * 3.5,
            hrp.CFrame.RightVector * 3.5, -hrp.CFrame.RightVector * 3.5
        }) do
            local r = Workspace:Raycast(hrp.Position, d, rp)
            if r and r.Instance then proc(r.Instance) end
        end
    end)
end

local function stopGhostMode()
    if ghostConn then ghostConn:Disconnect(); ghostConn = nil end
    for p, s in pairs(modifiedParts) do
        if p and p.Parent then
            p.CanCollide = s.CanCollide; p.CanTouch = s.CanTouch
        end
    end
    modifiedParts = {}
end

-- ================================================================
-- TP
-- ================================================================
local tpBusy = false

local function _hopTP_internal(targetPos)
    local ch = LP.Character
    if not ch then return false, "no char" end
    local hum = ch:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false, "dead" end
    local hrp = ch:FindFirstChild("HumanoidRootPart")
    if not hrp then return false, "no hrp" end

    startGhostMode()

    local seat = hum.SeatPart
    local vehicle = seat and seat:FindFirstAncestorOfClass("Model")
    local vRoot = vehicle and (vehicle.PrimaryPart or seat)

    if not vehicle then
        hum.PlatformStand = true
        Workspace.Gravity = 0
    end

    local startPos, rot, tempWeld
    local tgt = targetPos + Vector3.new(0, 3, 0)

    if vehicle and vRoot then
        pcall(function()
            tempWeld = Instance.new("WeldConstraint")
            tempWeld.Part0 = hrp; tempWeld.Part1 = seat
            tempWeld.Name = "MF_TempWeld"; tempWeld.Parent = hrp
        end)
        pcall(function()
            vRoot.AssemblyLinearVelocity = Vector3.zero
            vRoot.AssemblyAngularVelocity = Vector3.zero
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)
        task.wait(0.05)
        startPos = vRoot.Position
        rot = vRoot.CFrame.Rotation
    else
        startPos = hrp.Position
        rot = hrp.CFrame.Rotation
    end

    local totalDist = (tgt - startPos).Magnitude
    local hopCount = math.max(1, math.ceil(totalDist / HOP_DIST))
    local hopDelay = math.clamp(HOP_DIST / MAX_SPEED, MIN_DELAY, MAX_DELAY)

    for i = 1, hopCount do
        if not STATE.running then break end
        local t = i / hopCount
        local sp = startPos:Lerp(tgt, t)
        if vehicle and vRoot then
            pcall(function() vehicle:PivotTo(CFrame.new(sp) * rot) end)
            pcall(function()
                if hrp.Parent and seat.Parent then
                    hrp.CFrame = seat.CFrame * CFrame.new(0, 1.5, 0)
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    hrp.AssemblyAngularVelocity = Vector3.zero
                end
                if vRoot.Parent then
                    vRoot.AssemblyLinearVelocity = Vector3.zero
                    vRoot.AssemblyAngularVelocity = Vector3.zero
                end
            end)
        else
            pcall(function()
                hrp.CFrame = CFrame.new(sp) * rot
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end)
        end
        task.wait(hopDelay)
    end

    if vehicle and vRoot then
        pcall(function() vehicle:PivotTo(CFrame.new(tgt) * rot) end)
        task.wait(0.12)
        pcall(function()
            if hrp.Parent and seat.Parent then
                hrp.CFrame = seat.CFrame * CFrame.new(0, 1.5, 0)
            end
        end)
        pcall(function() if tempWeld and tempWeld.Parent then tempWeld:Destroy() end end)
    else
        pcall(function()
            hrp.CFrame = CFrame.new(tgt) * rot
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)
        Workspace.Gravity = originalGravity
        if hum then hum.PlatformStand = false end
    end

    stopGhostMode()
    return true, "OK"
end

local function hopTP(targetPos, silent)
    if tpBusy then return false, "busy" end
    tpBusy = true
    if not silent then showLoading() end
    local ok, res = _hopTP_internal(targetPos)
    if not silent then hideLoading() end
    tpBusy = false
    return ok, res
end

local function _discreteStepTP(startP, endP, stepDist)
    stepDist = stepDist or 0.8
    local ch = LP.Character
    if not ch or not ch:FindFirstChild("HumanoidRootPart") then return false end
    local hrp = ch.HumanoidRootPart
    while STATE.running do
        local dist = (endP - hrp.Position).Magnitude
        if dist <= stepDist then
            hrp.CFrame = CFrame.new(endP)
            hrp.AssemblyLinearVelocity = Vector3.zero
            return true
        end
        hrp.CFrame = CFrame.new(hrp.Position + ((endP - hrp.Position).Unit * stepDist))
        hrp.AssemblyLinearVelocity = Vector3.zero
        task.wait(0.08)
    end
    return false
end

local function _blinkTP_internal(targetPos, isUnderground)
    local ch = LP.Character
    if not ch or not ch:FindFirstChild("HumanoidRootPart") then return false end
    startGhostMode()
    local hrp = ch.HumanoidRootPart
    local hum = ch:FindFirstChild("Humanoid")
    if hum then hum.PlatformStand = true end
    Workspace.Gravity = 0

    if isUnderground then
        local uy = -4
        _discreteStepTP(hrp.Position, Vector3.new(hrp.Position.X, uy, hrp.Position.Z))
        _discreteStepTP(hrp.Position, Vector3.new(targetPos.X, uy, targetPos.Z))
        _discreteStepTP(hrp.Position, targetPos)
    else
        _discreteStepTP(hrp.Position, targetPos)
    end

    Workspace.Gravity = originalGravity
    if hum then hum.PlatformStand = false end
    stopGhostMode()
    return true
end

local function blinkTP(targetPos, isUnderground, silent)
    if tpBusy then return false end
    tpBusy = true
    if not silent then showLoading() end
    local ok = _blinkTP_internal(targetPos, isUnderground)
    if not silent then hideLoading() end
    tpBusy = false
    return ok
end

local function bypassTP(targetPos)
    showLoading()
    local ch = LP.Character
    if ch and ch:FindFirstChild("HumanoidRootPart") then
        for _, p in ipairs(ch:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Velocity = Vector3.new(0, 9e9, 0)
        bv.Parent = ch.HumanoidRootPart
    end
    local newCh = LP.CharacterAdded:Wait()
    local newHrp = newCh:WaitForChild("HumanoidRootPart", 10)
    if newHrp then
        task.wait(0.5)
        newHrp.CFrame = CFrame.new(targetPos)
    end
    task.wait(1.2)
    hideLoading()
end

-- ================================================================
-- SEAT CHECK
-- ================================================================
local function isSeated()
    local ch = LP.Character
    if not ch then return false end
    local hum = ch:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    local seat = hum.SeatPart
    if not seat then return false end
    return seat:IsA("Seat") or seat:IsA("VehicleSeat")
end

local function waitSeated(timeout)
    timeout = timeout or 30
    local t0 = os.clock()
    while STATE.running and (os.clock() - t0) < timeout do
        if isSeated() then return true end
        task.wait(0.3)
    end
    return isSeated()
end

-- ================================================================
-- APARTMENT
-- ================================================================
local function findVacantApartment()
    for _, data in ipairs(ApartmentData) do
        local vacant = false
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("TextLabel") and string.find(string.upper(obj.Text), "VACANT") then
                local gui = obj:FindFirstAncestorOfClass("SurfaceGui") or obj:FindFirstAncestorOfClass("BillboardGui")
                local part = gui and (gui.Adornee or gui.Parent)
                if part and part:IsA("BasePart") and (part.Position - data.BuyPos).Magnitude <= 5 then
                    vacant = true; break
                end
            end
        end
        if vacant then return data end
    end
    return nil
end

local function secureDoor(doorPos)
    for i = 1, 10 do
        if not STATE.running then return false end
        if checkPromptExistsAt(doorPos, 8, "unlock") then return true end
        if checkPromptExistsAt(doorPos, 8, "lock") then
            firePromptAt(doorPos, 8, "lock")
            task.wait(0.5)
            if checkPromptExistsAt(doorPos, 8, "unlock") then return true end
            firePromptAt(doorPos, 8, "open")
            task.wait(0.7)
        else
            firePromptAt(doorPos, 8, "open")
            task.wait(0.5)
        end
    end
    return false
end

-- ================================================================
-- MARSHMALLOW
-- ================================================================
local function buyMarshIngredients()
    local target = 1
    while STATE.running do
        local w = countTool({"Water", "Water23"})
        local s = countTool("Sugar Block Bag")
        local g = countTool("Gelatin")
        if w >= target and s >= target and g >= target then return true end

        if RE then
            if g < target then
                pcall(function()
                    local buf = buffer.create(3)
                    buffer.writeu8(buf, 0, 24); buffer.writeu8(buf, 1, 19); buffer.writeu8(buf, 2, 1)
                    RE:FireServer(buf)
                end)
                task.wait(0.35)
            end
            if s < target then
                pcall(function()
                    local buf = buffer.create(3)
                    buffer.writeu8(buf, 0, 24); buffer.writeu8(buf, 1, 19); buffer.writeu8(buf, 2, 2)
                    RE:FireServer(buf)
                end)
                task.wait(0.35)
            end
            if w < target then
                pcall(function()
                    local buf = buffer.create(3)
                    buffer.writeu8(buf, 0, 24); buffer.writeu8(buf, 1, 19); buffer.writeu8(buf, 2, 3)
                    RE:FireServer(buf)
                end)
                task.wait(0.35)
            end
        end
        task.wait(0.4)
    end
    return false
end

local function putIngredient(toolNameOrList, waitAfter)
    if not STATE.running then return false end
    local init = countTool(toolNameOrList)
    if init == 0 then return false end

    local attempts = 0
    while STATE.running and countTool(toolNameOrList) >= init and attempts < 30 do
        if type(toolNameOrList) == "table" then
            for _, n in ipairs(toolNameOrList) do
                if countTool(n) > 0 then equipTool(n); break end
            end
        else
            equipTool(toolNameOrList)
        end
        task.wait(0.2)
        firePromptAt(STATE.aptKitchen, 10)
        task.wait(1.0)
        attempts = attempts + 1
    end

    if countTool(toolNameOrList) < init then
        if waitAfter and waitAfter > 0 then
            local t0 = os.clock()
            while STATE.running and (os.clock() - t0) < waitAfter do task.wait(0.5) end
        end
        return true
    end
    return false
end

local function collectMarshmallow()
    local init = countTool(M_BAGS)
    local timeout = 0
    while STATE.running and countTool(M_BAGS) <= init and timeout < 200 do
        equipTool("Empty Bag")
        firePromptAt(STATE.aptKitchen, 12)
        task.wait(0.3)
        timeout = timeout + 1
    end
    return countTool(M_BAGS) > init
end

local function sellAllMarshmallow()
    local initial = countTool(M_BAGS)
    for _, n in ipairs(M_BAGS) do
        while hasTool(n) and STATE.running do
            equipTool(n)
            task.wait(0.25)
            local ch = LP.Character
            if ch and ch:FindFirstChild(n) then
                firePromptAt(SELL_POS, 10)
                task.wait(0.4)
            else
                task.wait(0.2)
            end
        end
    end
    task.wait(0.4)
    local remaining = countTool(M_BAGS)
    local sold = initial - remaining
    if sold > 0 then
        STATE.marshBagsSold = STATE.marshBagsSold + sold
    end
end

-- ================================================================
-- FAKE ID / CARD
-- ================================================================
local function findFakeIDSellerPrompt()
    local f = Workspace:FindFirstChild("Folders")
    if not f then return nil end
    local npcs = f:FindFirstChild("NPCs")
    if not npcs then return nil end
    local s = npcs:FindFirstChild("FakeIDSeller")
    if not s then return nil end
    for _, d in ipairs(s:GetDescendants()) do
        if d:IsA("ProximityPrompt") then return d end
    end
    return nil
end

local function buyFakeID(maxAttempts)
    maxAttempts = maxAttempts or 12
    local p = findFakeIDSellerPrompt()
    if not p then return false, "no prompt" end
    pcall(function()
        p.HoldDuration = 0; p.RequiresLineOfSight = false
        p.MaxActivationDistance = 9e9; p.Enabled = true
    end)
    local startC = getFakeIDCount()
    for _ = 1, maxAttempts do
        if not STATE.running then return false, "cancelled" end
        pcall(function() fireproximityprompt(p) end)
        task.wait(0.4)
        if getFakeIDCount() > startC then return true, "got" end
    end
    return false, "fail"
end

local function findBankTellerPrompt()
    local f = Workspace:FindFirstChild("Folders")
    local npcs = f and f:FindFirstChild("NPCs")
    if not npcs then return nil end
    local t = npcs:FindFirstChild("Bank Teller")
    if not t then return nil end
    local up = t:FindFirstChild("UpperTorso")
    local at = up and up:FindFirstChild("Attachment")
    return at and at:FindFirstChild("ProximityPrompt")
end

local function checkApprovalNotif()
    local mg = LP.PlayerGui:FindFirstChild("Main")
    local n = mg and mg:FindFirstChild("BasicNotification")
    if not n or n.TextTransparency > 0 then return nil end
    local l = n.Text:lower()
    if l:find("not success") or l:find("unsuccess") or l:find("denied") or l:find("reject") or l:find("failed") then
        return false, n.Text
    end
    if l:find("successful") or l:find("success") or l:find("approved") or l:find("accepted") then
        return true, n.Text
    end
    return nil, n.Text
end

local function findCardPickup()
    for _, nm in ipairs({"CardPickup", "Card Pickup", "Card_Pickup", "CardPickUp", "cardpickup"}) do
        local o = Workspace:FindFirstChild(nm)
        if o then return o end
    end
    for _, o in ipairs(Workspace:GetDescendants()) do
        if o:IsA("Model") or o:IsA("BasePart") or o:IsA("Folder") then
            if o.Name:lower():gsub("[%s_]", "") == "cardpickup" then return o end
        end
    end
    return nil
end

local function findAvailableATM()
    local m = Workspace:FindFirstChild("Map")
    local a = m and m:FindFirstChild("ATMS")
    if not a then return nil end
    for _, at in ipairs(a:GetChildren()) do
        local scr = at:FindFirstChild("ATMScreen")
        if scr and scr.Transparency == 0 then return at end
    end
    return nil
end

-- ================================================================
-- CHIPS
-- ================================================================
local function fireBuyIndex(idx)
    if not RE then return false end
    return pcall(function()
        local buf = buffer.create(3)
        buffer.writeu8(buf, 0, 24); buffer.writeu8(buf, 1, 21); buffer.writeu8(buf, 2, idx)
        RE:FireServer(buf)
    end)
end

local function buyUntilEnough(idx, name, target, maxAttempts)
    maxAttempts = maxAttempts or 30
    if countTool(name) >= target then return true end
    local at = 0
    while STATE.running and at < maxAttempts do
        at = at + 1
        if not fireBuyIndex(idx) then return false end
        local dl = os.clock() + 2.5
        repeat task.wait(0.08) until countTool(name) >= target or os.clock() > dl
        if countTool(name) >= target then return true end
        task.wait(0.2)
    end
    return countTool(name) >= target
end

-- ================================================================
-- RETRY WRAPPER
-- ================================================================
local function retryable(name, fn, maxAttempts)
    maxAttempts = maxAttempts or 3
    for i = 1, maxAttempts do
        if not STATE.running then return false end
        STATE.retry = i - 1
        setStep(name)
        local ok, res = pcall(fn)
        if ok and res then
            STATE.retry = 0
            STATE.lastError = ""
            return true
        end
        STATE.lastError = (not ok) and tostring(res) or (name .. " failed")
        setStatus(name .. " retry " .. i, Color3.fromRGB(255, 200, 80))
        task.wait(1)
    end
    return false
end

-- ================================================================
-- STEPS
-- ================================================================
local function stepBuyApartment()
    if STATE.hasApartment and STATE.aptKitchen then return true end
    setStatus("BUYING APARTMENT...", Color3.fromRGB(255, 200, 80))
    local data = findVacantApartment()
    if not data then return false end
    bypassTP(data.BuyPos)
    if not STATE.running then return false end
    firePromptAt(data.BuyPos, 5, "purchase")
    task.wait(1)
    STATE.aptKitchen = data.KitchenPos
    STATE.aptDoor = data.DoorPos
    STATE.hasApartment = true
    return true
end

local function stepLockApartment()
    if STATE.apartmentLocked then return true end
    if not STATE.aptDoor then return true end
    setStatus("LOCKING APARTMENT...", Color3.fromRGB(255, 200, 80))
    blinkTP(STATE.aptDoor, false)
    task.wait(0.8)
    if not STATE.running then return false end
    local ok = secureDoor(STATE.aptDoor)
    if ok then STATE.apartmentLocked = true end
    return ok
end

local function stepGetVehicle()
    if isSeated() then return true end
    setStatus("GOING TO DEALER...", Color3.fromRGB(255, 200, 80))
    bypassTP(DEALER_POS)
    task.wait(1)
    if not STATE.running then return false end

    setStatus("WAITING SEATED...", Color3.fromRGB(255, 200, 80))
    for _ = 1, 15 do
        if not STATE.running then return false end
        firePromptAt(DEALER_POS, 12)
        task.wait(0.8)
        if isSeated() then return true end
    end
    return waitSeated(20)
end

local function stepBuyMarsh()
    setStatus("BUYING MARSHMALLOW MATERIAL...", Color3.fromRGB(255, 200, 80))
    local ok = hopTP(SHOP_POS)
    if not ok then return false end
    task.wait(0.4)
    if not STATE.running then return false end
    return buyMarshIngredients()
end

local function stepGoApartment()
    setStatus("GOING TO APARTMENT...", Color3.fromRGB(255, 200, 80))
    local ok = hopTP(STATE.aptKitchen)
    if not ok then return false end
    task.wait(0.4)
    return true
end

local function stepAddWater()
    setStatus("ADDING WATER...", Color3.fromRGB(80, 200, 255))
    if not STATE.aptKitchen then return false end
    return putIngredient({"Water", "Water23"}, 0)
end

local function stepBuyFakeID()
    if getFakeIDCount() > 0 then return true end
    setStatus("BUYING FAKE ID...", Color3.fromRGB(255, 200, 80))
    local ok = hopTP(LOC_FakeID)
    if not ok then return false end
    task.wait(0.4)
    if not STATE.running then return false end
    local okBuy, _ = buyFakeID(12)
    return okBuy and getFakeIDCount() > 0
end

local function stepApplyCard()
    if getFakeIDCount() == 0 then
        if hasTool("Card") then return true end
        return false
    end
    setStatus("APPLYING CARD...", Color3.fromRGB(255, 200, 80))
    local ok = hopTP(LOC_ApplyForCard)
    if not ok then return false end
    task.wait(0.5)
    if not STATE.running then return false end

    if not equipTool("Fake ID") then return false end
    task.wait(0.3)

    local p = findBankTellerPrompt()
    if not p then return false end
    pcall(function()
        p.HoldDuration = 0; p.RequiresLineOfSight = false; p.MaxActivationDistance = 9e9
    end)

    local attempts = 0
    while getFakeIDCount() > 0 and attempts < 20 do
        if not STATE.running then return false end
        pcall(function() fireproximityprompt(p) end)
        task.wait(0.5)
        attempts = attempts + 1
    end
    unequipAll()
    return getFakeIDCount() == 0
end

local function stepQuickApproval()
    setStatus("Checking approval (non-blocking)...", Color3.fromRGB(255, 200, 80))
    local t0 = tick()
    while STATE.running and tick() - t0 < 8 do
        local res = checkApprovalNotif()
        if res == true then
            setStatus("Approved ✔", Color3.fromRGB(0, 220, 100))
            task.wait(1)
            return true
        elseif res == false then
            setStatus("Denied — continue anyway", Color3.fromRGB(255, 200, 80))
            task.wait(1)
            return true
        end
        task.wait(0.3)
    end
    setStatus("Approval n/a · lanjut", Color3.fromRGB(200, 200, 200))
    return true
end

local function stepBuyPotatoFlour()
    setStatus("BUYING POTATO & FLOUR...", Color3.fromRGB(255, 200, 80))
    local ok = hopTP(CHIPS_BUY_LOC)
    if not ok then return false end
    task.wait(0.4)
    if not STATE.running then return false end
    buyUntilEnough(IDX_POTATO, "Potato", 1, 30)
    if not STATE.running then return false end
    buyUntilEnough(IDX_FLOUR, "Flour", 1, 30)
    if not STATE.running then return false end
    return countTool("Potato") > 0 and countTool("Flour") > 0
end

local function stepChipsSequence()
    setStatus("STARTING CHIPS MISSION...", Color3.fromRGB(80, 200, 255))

    hopTP(CHIPS_COORDS.A); task.wait(0.5)
    if not STATE.running then return false end
    firePromptAt(CHIPS_COORDS.A, 8); task.wait(0.9)

    hopTP(CHIPS_COORDS.B); task.wait(0.5)
    if not STATE.running then return false end
    equipTool("Potato"); task.wait(0.4)
    firePromptAt(CHIPS_COORDS.B, 8)
    local t0 = os.clock()
    while STATE.running and countTool("Potato") > 0 and os.clock() - t0 < 10 do task.wait(0.15) end
    task.wait(3)

    hopTP(CHIPS_COORDS.C); task.wait(0.5)
    if not STATE.running then return false end
    firePromptAt(CHIPS_COORDS.C, 8); task.wait(3)

    hopTP(CHIPS_COORDS.D); task.wait(0.5)
    if not STATE.running then return false end
    equipTool("Flour"); task.wait(0.4)
    firePromptAt(CHIPS_COORDS.D, 8)
    local t1 = os.clock()
    while STATE.running and countTool("Flour") > 0 and os.clock() - t1 < 10 do task.wait(0.15) end
    task.wait(3)

    local pot = CHIPS_POTS[STATE.pot]
    hopTP(pot); task.wait(0.5)
    if not STATE.running then return false end
    firePromptAt(pot, 8); task.wait(1.5)

    return true
end

local function stepAddSugarGelatin()
    setStatus("ADDING SUGAR + GELATIN...", Color3.fromRGB(255, 200, 80))
    if not STATE.aptKitchen then return false end
    if not putIngredient("Sugar Block Bag", 0) then return false end
    if not STATE.running then return false end
    if not putIngredient("Gelatin", 47) then return false end
    return true
end

local function stepAddEmptyBag()
    setStatus("ADDING EMPTY BAG...", Color3.fromRGB(80, 200, 255))
    equipTool("Empty Bag")
    task.wait(0.4)
    if not collectMarshmallow() then return false end
    if countTool({"Water", "Water23"}) > 0 then equipTool("Water") end
    return true
end

local function stepSellMarshmallow()
    setStatus("SELLING MARSHMALLOW...", Color3.fromRGB(0, 220, 100))
    local ok = hopTP(SELL_POS)
    if not ok then return false end
    task.wait(0.4)
    sellAllMarshmallow()
    return countTool(M_BAGS) == 0
end

local function stepClaimCard()
    if hasTool("Card") then return true end
    setStatus("CLAIMING CARD...", Color3.fromRGB(0, 220, 100))

    local card = nil
    for _ = 1, 30 do
        if not STATE.running then return false end
        card = findCardPickup()
        if card then break end
        task.wait(0.5)
    end

    if not card then
        hopTP(CARD_FALLBACK_POS); task.wait(1)
        local bestP = findPromptNear(CARD_FALLBACK_POS, 20)
        if bestP then
            pcall(function()
                bestP.HoldDuration = 0; bestP.RequiresLineOfSight = false; bestP.MaxActivationDistance = 9e9
            end)
            for _ = 1, 20 do
                if not STATE.running then return false end
                pcall(function() fireproximityprompt(bestP) end)
                task.wait(0.6)
                if hasTool("Card") then return true end
            end
        end
        return false
    end

    local cardPos
    if card:IsA("BasePart") then cardPos = card.Position
    elseif card:IsA("Model") then
        local rp = card.PrimaryPart or card:FindFirstChildOfClass("BasePart")
        if rp then cardPos = rp.Position end
    elseif card:IsA("Folder") then
        for _, c in ipairs(card:GetChildren()) do
            if c:IsA("BasePart") then cardPos = c.Position; break end
        end
    end
    if not cardPos then return false end

    local prompt
    for _, d in ipairs(card:GetDescendants()) do
        if d:IsA("ProximityPrompt") then prompt = d; break end
    end
    if not prompt then return false end
    pcall(function()
        prompt.HoldDuration = 0; prompt.RequiresLineOfSight = false; prompt.MaxActivationDistance = 9e9
    end)

    for _ = 1, 20 do
        if not STATE.running then return false end
        hopTP(cardPos); task.wait(0.5)
        pcall(function() fireproximityprompt(prompt) end)
        task.wait(0.6)
        if hasTool("Card") then return true end
    end
    return false
end

local function stepSwipeATM()
    setStatus("SWIPING ATM...", Color3.fromRGB(0, 220, 100))
    if not hasTool("Card") then return false end

    local atm
    for _ = 1, 20 do
        if not STATE.running then return false end
        atm = findAvailableATM()
        if atm then break end
        task.wait(0.5)
    end
    if not atm then return false end

    local att = atm:FindFirstChild("Attachment")
    local prompt = att and att:FindFirstChild("ProximityPrompt")
    if not prompt then return false end
    pcall(function()
        prompt.HoldDuration = 0; prompt.RequiresLineOfSight = false; prompt.MaxActivationDistance = 9e9
    end)

    local oldATM = LP.PlayerGui:FindFirstChild("ATM")
    if oldATM then oldATM:Destroy() end

    for _ = 1, 10 do
        if not STATE.running then return false end
        hopTP(atm.Position); task.wait(0.4)
        pcall(function() fireproximityprompt(prompt) end)
        task.wait(0.4)
        if LP.PlayerGui:FindFirstChild("ATM") then break end
    end

    local atmGui = LP.PlayerGui:FindFirstChild("ATM")
    if not atmGui then return false end

    equipTool("Card"); task.wait(0.4)
    local frame = atmGui:FindFirstChild("Frame")
    local swipe = frame and frame:FindFirstChild("Swipe")
    if not swipe then return false end

    local clicked = false
    if replicatesignal then
        clicked = pcall(function() replicatesignal(swipe.MouseButton1Click) end)
    end
    if not clicked then
        local p = swipe.AbsolutePosition
        local s = swipe.AbsoluteSize
        if p and s then
            VirtualInputManager:SendMouseButtonEvent(p.X + s.X/2, p.Y + s.Y/2, 0, true, game, 0)
            task.wait(0.05)
            VirtualInputManager:SendMouseButtonEvent(p.X + s.X/2, p.Y + s.Y/2, 0, false, game, 0)
        end
    end
    task.wait(0.6)
    unequipAll()
    STATE.cardsSwiped = STATE.cardsSwiped + 1
    return true
end

local function stepClaimChips()
    setStatus("CLAIMING CHIPS...", Color3.fromRGB(0, 220, 100))
    local pot = CHIPS_POTS[STATE.pot]
    hopTP(pot); task.wait(0.4)
    if not STATE.running then return false end

    local before = countPotatoChips()
    firePromptAt(pot, 8)
    local t0 = os.clock()
    while STATE.running and (os.clock() - t0) < 10 do
        if countPotatoChips() > before then break end
        task.wait(0.15)
    end
    task.wait(2)
    return countPotatoChips() > before
end

local function stepMakeHotChips()
    local raw = countPotatoChips()
    if raw == 0 then return true end
    setStatus("MAKING HOT CHIPS...", Color3.fromRGB(255, 160, 60))

    hopTP(SC_TUKAR); task.wait(0.4)
    if not STATE.running then return false end

    local attempts = 0
    local maxA = raw + 5
    local last = countPotatoChips()

    while STATE.running and countPotatoChips() > 0 and attempts < maxA do
        attempts = attempts + 1
        firePromptAt(SC_TUKAR, 30)
        task.wait(3)

        local now = countPotatoChips()
        if now >= last and attempts >= 3 and now == last then break end
        last = now
    end

    return countTool("Hot Chips") > 0
end

local function stepSellHomeless()
    if countTool("Hot Chips") == 0 then return true end
    setStatus("SELLING TO HOMELESS...", Color3.fromRGB(0, 220, 100))

    equipTool("Hot Chips"); task.wait(0.5)
    local startCount = countTool("Hot Chips")
    local safety = 0
    local maxS = startCount + #SC_HOMELESS

    while STATE.running and countTool("Hot Chips") > 0 and safety < maxS do
        safety = safety + 1
        local idx = STATE.homelessIdx
        local hPos = SC_HOMELESS[idx] or SC_HOMELESS[1]
        if not SC_HOMELESS[idx] then STATE.homelessIdx = 1; idx = 1 end

        if not LP.Character:FindFirstChild("Hot Chips") then
            equipTool("Hot Chips"); task.wait(0.3)
        end

        local before = countTool("Hot Chips")
        local ok = hopTP(hPos)
        if ok then
            task.wait(0.6)
            firePromptAt(hPos, 30); task.wait(0.6)
            firePromptAt(hPos, 30); task.wait(0.6)
        end

        STATE.homelessIdx = STATE.homelessIdx + 1
        if STATE.homelessIdx > #SC_HOMELESS then STATE.homelessIdx = 1 end
        task.wait(0.3)
        if countTool("Hot Chips") >= before and safety > 3 and before == countTool("Hot Chips") then
            break
        end
    end

    if STATE.running and countTool("Hot Chips") > 0 then
        hopTP(SC_COOK); task.wait(0.8)
    end

    local endCount = countTool("Hot Chips")
    local sold = startCount - endCount
    if sold > 0 then
        STATE.hotChipsSold = STATE.hotChipsSold + sold
    end

    return countTool("Hot Chips") == 0
end

-- ================================================================
-- MAIN CYCLE
-- ================================================================
local function runFullCycle()
    STATE.cycle = STATE.cycle + 1

    if not STATE.hasApartment then
        if not retryable("BUY_APARTMENT", stepBuyApartment, 3) then return false end
    end

    if not STATE.apartmentLocked then
        if not retryable("LOCK_APARTMENT", stepLockApartment, 3) then
            setStatus("Lock gagal, lanjut...", Color3.fromRGB(255, 200, 80))
        end
    end

    if not isSeated() then
        if not retryable("GET_VEHICLE", stepGetVehicle, 5) then return false end
    end

    if not retryable("BUY_MARSHMALLOW", stepBuyMarsh, 3) then return false end
    if not retryable("GO_APT", stepGoApartment, 3) then return false end
    if not retryable("ADD_WATER", stepAddWater, 3) then return false end
    if not retryable("BUY_FAKE_ID", stepBuyFakeID, 5) then return false end
    if not retryable("APPLY_CARD", stepApplyCard, 3) then return false end

    retryable("WAIT_APPROVAL", stepQuickApproval, 1)

    if not retryable("BUY_POTATO_FLOUR", stepBuyPotatoFlour, 3) then return false end
    if not retryable("CHIPS_SEQUENCE", stepChipsSequence, 3) then return false end
    if not retryable("BACK_APT", stepGoApartment, 3) then return false end
    if not retryable("ADD_SUGAR_GELATIN", stepAddSugarGelatin, 3) then return false end
    if not retryable("ADD_EMPTY_BAG", stepAddEmptyBag, 3) then return false end
    if not retryable("SELL_MARSHMALLOW", stepSellMarshmallow, 3) then return false end

    if not retryable("CLAIM_CARD", stepClaimCard, 3) then
        setStatus("Card claim failed, continue anyway", Color3.fromRGB(255, 200, 80))
    end

    if hasTool("Card") then
        retryable("SWIPE_ATM", stepSwipeATM, 3)
    end

    retryable("CLAIM_CHIPS", stepClaimChips, 3)
    retryable("MAKE_HOT_CHIPS", stepMakeHotChips, 3)
    retryable("SELL_HOMELESS", stepSellHomeless, 3)

    return true
end

-- ================================================================
-- START / STOP
-- ================================================================
local farmThread = nil

ToggleBtn.MouseButton1Click:Connect(function()
    if not STATE.running then
        STATE.running = true
        STATE.startTime = os.time()
        STATE.lastError = ""
        STATE.startMoney = readMoney()
        refreshToggle()
        setStatus("BOOTING...", Color3.fromRGB(180, 130, 255))

        farmThread = task.spawn(function()
            while STATE.running do
                local ok, err = pcall(runFullCycle)
                if not ok then
                    STATE.lastError = tostring(err)
                    setStatus("Cycle error: " .. tostring(err):sub(1, 40), Color3.fromRGB(255, 80, 80))
                    task.wait(3)
                end
                if not STATE.running then break end
                setStep("NEXT_CYCLE")
                setStatus("CYCLE COMPLETE — repeating...", Color3.fromRGB(0, 220, 100))
                task.wait(1.5)
            end
            STATE.running = false
            hideLoading()
            refreshToggle()
            setStatus("Stopped", Color3.fromRGB(180, 60, 60))
        end)
    else
        STATE.running = false
        hideLoading()
        refreshToggle()
        setStatus("Stopping...", Color3.fromRGB(255, 200, 80))
    end
end)

-- Background status updater (info + stats + money)
task.spawn(function()
    while Gui.Parent do
        pcall(function()
            if STATE.running then
                local rt = os.time() - STATE.startTime
                local h = math.floor(rt / 3600); local m = math.floor((rt % 3600) / 60); local s = rt % 60
                InfoLbl.Text = string.format(
                    "Step   : %s\nCycle  : %d\nRetry  : %d\nRuntime: %02d:%02d:%02d\nErr    : %s",
                    STATE.step, STATE.cycle, STATE.retry, h, m, s,
                    STATE.lastError ~= "" and STATE.lastError:sub(1, 32) or "-")

                -- money tracking
                local nowMoney = readMoney()
                if nowMoney and STATE.startMoney then
                    local d = nowMoney - STATE.startMoney
                    if d >= 0 then STATE.moneyGained = d end
                end
            end
            refreshStats()
        end)
        task.wait(0.5)
    end
end)

setStep("IDLE")
setStatus("Idle · atur chips/cycle lalu START", Color3.fromRGB(150, 150, 150))
refreshStats()
print("[DARK HUB] Loaded · MULTI FARM v4 · chips fixed 1 · dealer pakai BypassTP")