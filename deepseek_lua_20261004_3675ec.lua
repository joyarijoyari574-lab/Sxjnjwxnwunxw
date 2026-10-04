-- ================================================================
-- DARK HUB PREMIUM V3.8 — ARCANE UI EDITION
-- Farm: Chips + Box | FakeName (LENGER Method) | NO Inf Stamina
-- ================================================================

local Arcane = loadstring(game:HttpGet("https://raw.githubusercontent.com/Da7mu/Ui-Collection/refs/heads/main/Arcane%20Ui/Library.lua"))()

local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Http = game:GetService("HttpService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local plr = game.Players.LocalPlayer

-- Anti-AFK
do
    local VU = game:GetService("VirtualUser")
    plr.Idled:Connect(function()
        VU:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        task.wait(1)
        VU:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    end)
end

-- ================================================================
-- STATE
-- ================================================================
local Flags = {
    BoxESP=false, Tracer=false,
    ESPName=true, ESPDist=true, ESPHPBar=true, ESPWeapon=true, ESPSkeleton=false, ESPMasak=true,
    TPNoClip=false, AimLock=false,
    WallCheck=false,
    InvScan=false, InstantInteract=false,
    HybridSpeed=false, AuraKill=false,
}
local AimFOV_Radius = 120
local SilentFOV_Radius = 120
local AimMax_Dist = 300
local TracerMaxDist = 300
local ESPMaxDist = 500
local AimSmooth = 0.85
local AimTarget = nil
local AimPart = "Head"
local AimMode = "PC"
local BoxESPMode = "FULL"
local AimWhitelist = {}
local BlinkMode = "PC"
local SilentAim = false
local SilentAimWallbang = false
local ShowAimFOV = true
local ShowSilentFOV = true
local SilentMode = "PC"
local SilentPart = "Head"
local Running = true
local tpBusy = false
local _htpo = { fn = function() end }
local _overlayActive = false

-- ================================================================
-- HELPERS
-- ================================================================
local SAVEFILE = "hndrixx_settings.json"
local function saveSettings()
    pcall(function()
        writefile(SAVEFILE, Http:JSONEncode({
            Flags = { BoxESP=Flags.BoxESP, Tracer=Flags.Tracer, TPNoClip=Flags.TPNoClip,
                AimLock=Flags.AimLock, WallCheck=Flags.WallCheck, InvScan=Flags.InvScan,
                InstantInteract=Flags.InstantInteract, HybridSpeed=Flags.HybridSpeed, AuraKill=Flags.AuraKill },
            AimFOV_Radius = AimFOV_Radius, AimMax_Dist = AimMax_Dist,
        }))
    end)
end
local function loadSettings()
    pcall(function()
        if isfile and isfile(SAVEFILE) then
            local d = Http:JSONDecode(readfile(SAVEFILE))
            if d.Flags then for k,v in pairs(d.Flags) do if Flags[k]~=nil then Flags[k]=v end end end
            if d.AimFOV_Radius then AimFOV_Radius=d.AimFOV_Radius end
            if d.AimMax_Dist then AimMax_Dist=d.AimMax_Dist end
        end
    end)
end

-- ================================================================
-- INSTANT INTERACT — versi makePromptInstant
-- ================================================================
local _instConn1, _instConn2

local function makePromptInstant(prompt)
    if prompt:IsA("ProximityPrompt") then
        prompt.HoldDuration = 0
        prompt.RequiresLineOfSight = false
    end
end

local function startInstantInteract()
    -- Hapus semua prompt yang ada dulu (jangan tergantung toggle, ini 1x saja)
    for _, obj in ipairs(Workspace:GetDescendants()) do makePromptInstant(obj) end
    if not _instConn1 then
        _instConn1 = Workspace.DescendantAdded:Connect(makePromptInstant)
    end
    if not _instConn2 then
        _instConn2 = ProximityPromptService.PromptShown:Connect(makePromptInstant)
    end
end

-- Start langsung (InstantInteract = selalu aktifkan; toggle hanya jadi kontrol butuh/nggak)
startInstantInteract()

-- ================================================================
-- ESP Drawing
-- ================================================================
local ESP = {}
local FovCircle = Drawing.new("Circle")
FovCircle.Thickness=1.5; FovCircle.Color=Color3.fromRGB(0,170,255)
FovCircle.Filled=false; FovCircle.NumSides=64; FovCircle.Visible=false
local SilentFovCircle = Drawing.new("Circle")
SilentFovCircle.Thickness=1.5; SilentFovCircle.Color=Color3.fromRGB(0,170,255)
SilentFovCircle.Filled=false; SilentFovCircle.NumSides=64; SilentFovCircle.Visible=false
local SilentLine = Drawing.new("Line")
SilentLine.Thickness=1.5; SilentLine.Color=Color3.fromRGB(0,170,255)
SilentLine.Transparency=1; SilentLine.Visible=false

local function removeESP(p)
    if not ESP[p] then return end
    local _e=ESP[p]
    if _e.corners then for _,c in ipairs(_e.corners) do pcall(function() c:Remove() end) end end
    if _e.skeleton then for _,s in ipairs(_e.skeleton) do pcall(function() s:Remove() end) end end
    for k,d in pairs(_e) do if k~="corners" and k~="skeleton" then pcall(function() d:Remove() end) end end
    ESP[p]=nil
end
local function _mkLine(thick, col)
    local d = Drawing.new("Line"); d.Thickness=thick; d.Color=col; d.Visible=false; return d
end
local function _mkText(sz, col)
    local d = Drawing.new("Text")
    d.Size=sz; d.Color=col; d.Outline=true; d.OutlineColor=Color3.fromRGB(0,0,0)
    d.Center=true; d.Font=Drawing.Fonts.Plex; d.Visible=false; return d
end
local function _hideESP(e)
    e.box.Visible=false; e.hpbg.Visible=false; e.hpbar.Visible=false
    e.hpnum.Visible=false; e.dispname.Visible=false; e.username.Visible=false
    e.dist.Visible=false; e.weapon.Visible=false; e.masak.Visible=false; e.tracer.Visible=false
    for _,c in ipairs(e.corners) do c.Visible=false end
    for _,s in ipairs(e.skeleton) do s.Visible=false end
end
local function createESP(p)
    if ESP[p] or p == plr then return end
    local _c = {}
    for ci = 1, 8 do
        local cl = Drawing.new("Line")
        cl.Thickness=2; cl.Color=Color3.fromRGB(0,170,255); cl.Visible=false
        _c[ci] = cl
    end
    local _sk = {}
    for si = 1, 15 do
        local sl = Drawing.new("Line")
        sl.Thickness=1.2; sl.Color=Color3.fromRGB(0,170,255); sl.Visible=false
        _sk[si] = sl
    end
    local e = {
        box=Drawing.new("Square"), hpbg=Drawing.new("Square"), hpbar=Drawing.new("Square"),
        hpnum=_mkText(10,Color3.fromRGB(255,255,255)),
        dispname=_mkText(13,Color3.fromRGB(255,255,255)),
        username=_mkText(11,Color3.fromRGB(180,200,220)),
        dist=_mkText(11,Color3.fromRGB(160,180,210)),
        weapon=_mkText(11,Color3.fromRGB(0,200,255)),
        tracer=_mkLine(1.2,Color3.fromRGB(0,170,255)),
        masak=_mkText(13,Color3.fromRGB(0,255,120)),
        corners=_c, skeleton=_sk,
    }
    e.box.Thickness=1.5; e.box.Filled=false
    e.hpbg.Thickness=1; e.hpbg.Filled=true; e.hpbg.Color=Color3.fromRGB(0,0,0)
    e.hpbar.Thickness=1; e.hpbar.Filled=true
    ESP[p] = e
end

-- ================================================================
-- TP SYSTEM
-- ================================================================
local RESPAWN_WARP = Vector3.new(999999, 9999999, 999999)

local TPOverlay = Instance.new("ScreenGui")
TPOverlay.Name = "DARKHUB_TPOverlay"
TPOverlay.ResetOnSpawn = false
TPOverlay.DisplayOrder = 5
TPOverlay.IgnoreGuiInset = true
TPOverlay.Enabled = false
TPOverlay.Parent = CoreGui

local OvBG = Instance.new("Frame", TPOverlay)
OvBG.Size = UDim2.new(1,0,1,0)
OvBG.BackgroundColor3 = Color3.fromRGB(6, 10, 20)
OvBG.BackgroundTransparency = 1
OvBG.BorderSizePixel = 0
OvBG.ZIndex = 9999

local ovCenter = Instance.new("Frame", OvBG)
ovCenter.Size = UDim2.new(0, 320, 0, 130)
ovCenter.AnchorPoint = Vector2.new(0.5, 0.5)
ovCenter.Position = UDim2.new(0.5, 0, 0.5, 0)
ovCenter.BackgroundTransparency = 1
ovCenter.ZIndex = 10000

local ovLabel = Instance.new("TextLabel", ovCenter)
ovLabel.Size = UDim2.new(1, 0, 0, 20)
ovLabel.Position = UDim2.new(0, 0, 0, 80)
ovLabel.BackgroundTransparency = 1
ovLabel.Text = "Teleporting, please wait"
ovLabel.TextColor3 = Color3.fromRGB(160, 180, 210)
ovLabel.Font = Enum.Font.Gotham
ovLabel.TextSize = 13
ovLabel.ZIndex = 10001

local function showTPOverlay()
    _overlayActive = true
    FovCircle.Visible = false
    for _, e in pairs(ESP) do _hideESP(e) end
    OvBG.BackgroundTransparency = 0
    TPOverlay.Enabled = true
end
_htpo.fn = function()
    TPOverlay.Enabled = false
    OvBG.BackgroundTransparency = 1
    _overlayActive = false
end

local function closeBonusTPOverlay() _htpo.fn() end

local function doSuicideTP(loc)
    tpBusy = true
    ovLabel.Text = "RESPAWNING..."
    showTPOverlay()
    local ch = plr.Character
    local hrp0 = ch and ch:FindFirstChild("HumanoidRootPart")
    if not hrp0 then tpBusy=false; closeBonusTPOverlay(); return end
    hrp0.CFrame = CFrame.new(RESPAWN_WARP)
    local newChar = plr.CharacterAdded:Wait()
    local hrp = newChar:WaitForChild("HumanoidRootPart", 10)
    local hum = newChar:WaitForChild("Humanoid", 10)
    if not hrp or not hum then tpBusy=false; closeBonusTPOverlay(); return end
    local waited = 0
    while hum.Health <= 0 and waited < 5 do task.wait(0.1); waited += 0.1 end
    task.wait(0.8)
    ovLabel.Text = "TELEPORTING TO " .. loc.name
    local targetCF = CFrame.new(loc.x, loc.y + 3, loc.z)
    for _ = 1, 4 do hrp.CFrame = targetCF; task.wait(0.15) end
    task.wait(0.1)
    closeBonusTPOverlay()
    tpBusy = false
end

local TP_OTHERS = {
    {name="Bag Store", x=992.77, y=3.78, z=422.53},
    {name="Bank", x=-48.64, y=3.73, z=-320.46},
    {name="Binary Store", x=-281.06, y=3.74, z=251.23},
    {name="Boutique Store", x=992.60, y=3.78, z=453.07},
    {name="Box Job", x=-578.48, y=3.53, z=-74.82},
    {name="Buy Marshmellow", x=510.38, y=3.59, z=603.50},
    {name="Cap Store", x=-270.15, y=3.88, z=-331.36},
    {name="Casino", x=1152.53, y=20.32, z=-26.31},
    {name="Chips Cook", x=-487.11, y=3.86, z=-454.16},
    {name="Chips Store", x=-773.72, y=3.66, z=-187.54},
    {name="Chips Tukar", x=-34.91, y=4.56, z=-24.15},
    {name="Clothes Store 1", x=-202.62, y=3.48, z=-58.82},
    {name="Clothes Store 2", x=-747.62, y=3.76, z=571.96},
    {name="Dealer", x=730.24, y=3.7, z=449.47},
    {name="Deli Grocery", x=-364.30, y=3.61, z=-325.87},
    {name="Fake Card", x=216.28, y=3.73, z=-331.79},
    {name="Food Corp", x=365.69, y=3.48, z=-349.23},
    {name="Glasses Store", x=-697.77, y=4.21, z=-336.85},
    {name="Gun Sell", x=75.09, y=3.76, z=26.53},
    {name="Gun Store 1", x=215.77, y=3.73, z=-179.89},
    {name="Gun Store 2", x=-468.37, y=3.86, z=349.56},
    {name="Gun Tier", x=1114.80, y=3.78, z=167.36},
    {name="Haircut", x=52.73, y=3.73, z=-71.39},
    {name="Jewerely Store", x=-75.48, y=4.29, z=-176.28},
    {name="Shoes Store", x=524.48, y=3.75, z=-196.93},
    {name="Store 1", x=904.05, y=3.53, z=-87.44},
    {name="Store 2", x=530.13, y=3.46, z=430.07},
    {name="Tattoo Shop", x=951.72, y=3.83, z=-72.93},
    {name="The Deli 2", x=-662.23, y=3.98, z=159.33},
    {name="MAL", x=-747.1, y=3.8, z=649.1},
    {name="Spawn Gun", x=-867.6, y=3.5, z=468.0},
    {name="RPT YGZ", x=22.7, y=3.8, z=308.3},
    {name="Salon", x=-1125.5, y=3.7, z=-14.3},
}
local TP_OTHERS_MAP = {}
local TP_OTHERS_NAMES = {}
for _, loc in ipairs(TP_OTHERS) do
    TP_OTHERS_MAP[loc.name] = loc
    table.insert(TP_OTHERS_NAMES, loc.name)
end

-- ================================================================
-- FARM STATUS OVERLAY
-- ================================================================
local FarmStatusGui = Instance.new("ScreenGui")
FarmStatusGui.Name = "DARKHUB_FarmStatus"
FarmStatusGui.ResetOnSpawn = false
FarmStatusGui.DisplayOrder = 90
FarmStatusGui.Parent = CoreGui

local FarmStatusLbl = Instance.new("TextLabel")
FarmStatusLbl.Size = UDim2.new(0, 460, 0, 46)
FarmStatusLbl.Position = UDim2.new(0.5, -230, 0, 24)
FarmStatusLbl.BackgroundColor3 = Color3.fromRGB(14, 20, 38)
FarmStatusLbl.BackgroundTransparency = 0.1
FarmStatusLbl.BorderSizePixel = 0
FarmStatusLbl.Text = ""
FarmStatusLbl.TextColor3 = Color3.fromRGB(0, 170, 255)
FarmStatusLbl.Font = Enum.Font.GothamBold
FarmStatusLbl.TextSize = 14
FarmStatusLbl.Visible = false
FarmStatusLbl.Parent = FarmStatusGui
Instance.new("UICorner", FarmStatusLbl).CornerRadius = UDim.new(0, 10)
local fssk = Instance.new("UIStroke", FarmStatusLbl)
fssk.Color = Color3.fromRGB(0, 170, 255)
fssk.Thickness = 1.5

local function setFarmStatus(text, color)
    if text then
        FarmStatusLbl.Text = text
        if color then FarmStatusLbl.TextColor3 = color end
        FarmStatusLbl.Visible = true
    else
        FarmStatusLbl.Visible = false
    end
end

-- ================================================================
-- FARM HELPERS
-- ================================================================
local originalGravity = workspace.Gravity
local modifiedParts = {}
local ghostConn = nil

local function startGhostMode()
    if ghostConn then return end
    ghostConn = RunService.Heartbeat:Connect(function()
        local char = plr.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then return end
        local hum = char:FindFirstChild("Humanoid")
        if hum and hum.Sit then return end
        local hrp = char.HumanoidRootPart
        local function proc(part)
            if not part or not part:IsA("BasePart") or part:IsA("Terrain") then return end
            if part:IsDescendantOf(char) then return end
            if part:IsA("Seat") or part:IsA("VehicleSeat") or part.Name:lower():find("seat") then return end
            if not modifiedParts[part] then
                modifiedParts[part] = { CanCollide=part.CanCollide, CanTouch=part.CanTouch }
            end
            part.CanCollide = false
            part.CanTouch = false
        end
        for _, part in ipairs(hrp:GetTouchingParts()) do proc(part) end
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {char}
        for _, dir in ipairs({Vector3.new(0,-4,0), hrp.CFrame.LookVector*3.5, -hrp.CFrame.LookVector*3.5,
            hrp.CFrame.RightVector*3.5, -hrp.CFrame.RightVector*3.5}) do
            local res = workspace:Raycast(hrp.Position, dir, params)
            if res and res.Instance then proc(res.Instance) end
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

local function genBlinkTeleport(targetPos, isUnderground, isRunning)
    local char = plr.Character
    if not char or not char:FindFirstChild('HumanoidRootPart') then return end
    startGhostMode()
    local hrp = char.HumanoidRootPart
    local humanoid = char:FindFirstChild('Humanoid')
    if humanoid then humanoid.PlatformStand = true end
    Workspace.Gravity = 0
    local function step(startP, endP)
        local stepDist = 0.8
        while isRunning() do
            local h = char:FindFirstChildOfClass("Humanoid")
            if not h or h.Health <= 0 then return false end
            local dist = (endP - hrp.Position).Magnitude
            if dist <= stepDist then
                hrp.CFrame = CFrame.new(endP)
                hrp.AssemblyLinearVelocity = Vector3.new(0,0,0)
                return true
            else
                hrp.CFrame = CFrame.new(hrp.Position + ((endP - hrp.Position).Unit * stepDist))
                hrp.AssemblyLinearVelocity = Vector3.new(0,0,0)
            end
            task.wait(0.08)
        end
        return false
    end
    if isUnderground then
        local underY = -4
        step(hrp.Position, Vector3.new(hrp.Position.X, underY, hrp.Position.Z))
        step(hrp.Position, Vector3.new(targetPos.X, underY, targetPos.Z))
        step(hrp.Position, targetPos)
    else
        step(hrp.Position, targetPos)
    end
    Workspace.Gravity = originalGravity
    if humanoid then humanoid.PlatformStand = false end
    stopGhostMode()
end

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
            local pPos = obj.Parent and (obj.Parent:IsA("BasePart") and obj.Parent.Position
                or (obj.Parent:IsA("Attachment") and obj.Parent.WorldPosition))
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

local function equipTool(toolName)
    local char = plr.Character
    if not char then return false end
    local humanoid = char:FindFirstChild("Humanoid")
    if not humanoid then return false end
    if char:FindFirstChild(toolName) then return true end
    humanoid:UnequipTools()
    task.wait(0.05)
    local backpack = plr:FindFirstChild("Backpack")
    if not backpack then return false end
    local targetTool = backpack:FindFirstChild(toolName)
    if not targetTool then
        for _, v in pairs(backpack:GetChildren()) do
            if v:IsA("Tool") and v.Name:lower():find(toolName:lower()) then
                targetTool = v; break
            end
        end
    end
    if targetTool then
        humanoid:EquipTool(targetTool)
        task.wait(0.15)
        return true
    end
    return false
end

-- ================================================================
-- CHIPS FARM
-- ================================================================
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
local ChipsST = { running=false, pot=1, cycle=0 }

local function doChipsFarm()
    while ChipsST.running and Running do
        local pot = CHIPS_POTS[ChipsST.pot]
        ChipsST.cycle += 1
        setFarmStatus(("CHIPS · Siklus #%d · Pot %d"):format(ChipsST.cycle, ChipsST.pot),
            Color3.fromRGB(255, 200, 80))

        setFarmStatus("Step A · Station A", Color3.fromRGB(80, 200, 255))
        genBlinkTeleport(CHIPS_COORDS.A, true, function() return ChipsST.running end)
        if not ChipsST.running then break end
        firePromptAt(CHIPS_COORDS.A, 8)

        setFarmStatus("Step B · Potato", Color3.fromRGB(255, 200, 80))
        genBlinkTeleport(CHIPS_COORDS.B, true, function() return ChipsST.running end)
        if not ChipsST.running then break end
        equipTool("Potato"); task.wait(0.25)
        firePromptAt(CHIPS_COORDS.B, 8); task.wait(2)

        setFarmStatus("Step C · Station C", Color3.fromRGB(200, 200, 200))
        genBlinkTeleport(CHIPS_COORDS.C, true, function() return ChipsST.running end)
        if not ChipsST.running then break end
        firePromptAt(CHIPS_COORDS.C, 8); task.wait(2)

        setFarmStatus("Step D · Flour", Color3.fromRGB(220, 180, 100))
        genBlinkTeleport(CHIPS_COORDS.D, true, function() return ChipsST.running end)
        if not ChipsST.running then break end
        equipTool("Flour"); task.wait(0.25)
        firePromptAt(CHIPS_COORDS.D, 8); task.wait(2)

        setFarmStatus(("Step E · Pot %d..."):format(ChipsST.pot), Color3.fromRGB(255, 160, 60))
        genBlinkTeleport(pot, true, function() return ChipsST.running end)
        if not ChipsST.running then break end
        firePromptAt(pot, 8); task.wait(0.5)

        for i = 1, 60 do
            if not ChipsST.running then break end
            task.wait(1)
            if i % 5 == 0 then
                setFarmStatus(("Memasak... sisa %ds"):format(60 - i), Color3.fromRGB(255, 160, 60))
            end
        end

        if not ChipsST.running then break end
        setFarmStatus("Claim Chips!", Color3.fromRGB(0, 220, 100))
        genBlinkTeleport(pot, true, function() return ChipsST.running end)
        if not ChipsST.running then break end
        firePromptAt(pot, 8); task.wait(1)
        setFarmStatus(("Siklus #%d selesai!"):format(ChipsST.cycle), Color3.fromRGB(0, 220, 100))
        task.wait(0.8)
    end
    ChipsST.running = false
    setFarmStatus(nil)
end

-- ================================================================
-- BOX FARM
-- ================================================================
local BOX_A = Vector3.new(-551.47, 3.54, -84.97)
local BOX_B = Vector3.new(-401.96, 3.36, -70.98)
local BoxST = { running=false, cycle=0 }

local function doBoxFarm()
    while BoxST.running and Running do
        BoxST.cycle += 1
        setFarmStatus(("BOX · Siklus #%d"):format(BoxST.cycle), Color3.fromRGB(80, 200, 255))

        setFarmStatus("Step 1 · TP → Titik A", Color3.fromRGB(80, 200, 255))
        genBlinkTeleport(BOX_A, true, function() return BoxST.running end)
        if not BoxST.running then break end
        task.wait(0.3)
        firePromptAt(BOX_A, 20)
        task.wait(0.5)
        if not BoxST.running then break end

        setFarmStatus("Step 2 · TP → Titik B", Color3.fromRGB(255, 200, 80))
        genBlinkTeleport(BOX_B, true, function() return BoxST.running end)
        if not BoxST.running then break end
        task.wait(0.3)

        setFarmStatus("Step 3 · Equip Crate", Color3.fromRGB(220, 180, 100))
        equipTool("Crate"); task.wait(0.3)
        if not BoxST.running then break end

        setFarmStatus("Step 4 · Prompt di B", Color3.fromRGB(0, 220, 100))
        firePromptAt(BOX_B, 20); task.wait(0.5)
        setFarmStatus(("Siklus #%d selesai! Looping..."):format(BoxST.cycle), Color3.fromRGB(0, 220, 100))
        task.wait(0.5)
    end
    BoxST.running = false
    setFarmStatus(nil)
end

-- ================================================================
-- WALL SELECTOR
-- ================================================================
local wsSelectMode = false
local wsSelected = {}
local wsDisabled = {}
local wsHighlights = {}
local wsMouse = plr:GetMouse()
local wsCam = workspace.CurrentCamera
local wsHoverBox = Instance.new("SelectionBox", workspace)
wsHoverBox.Color3 = Color3.fromRGB(0,170,255)
wsHoverBox.LineThickness = 0.05
wsHoverBox.SurfaceTransparency = 0.88
wsHoverBox.SurfaceColor3 = Color3.fromRGB(0,170,255)

local function wsGetTarget()
    local unitRay = wsCam:ScreenPointToRay(wsMouse.X, wsMouse.Y)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local chars = {}
    for _, p in ipairs(game.Players:GetPlayers()) do
        if p.Character then table.insert(chars, p.Character) end
    end
    params.FilterDescendantsInstances = chars
    local r = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, params)
    if r then return r.Instance end
end
local function wsAddHL(part)
    if wsHighlights[part] then return end
    local b = Instance.new("SelectionBox", workspace)
    b.Adornee = part; b.Color3 = Color3.fromRGB(0,170,255)
    b.LineThickness = 0.07; b.SurfaceTransparency = 0.75
    b.SurfaceColor3 = Color3.fromRGB(0,170,255)
    wsHighlights[part] = b
end
local function wsRemoveHL(part)
    if wsHighlights[part] then wsHighlights[part]:Destroy(); wsHighlights[part] = nil end
end
local function wsDoSelect(part)
    if not part or not part:IsA("BasePart") then return end
    local anc = part.Parent
    while anc do
        if anc:IsA("Model") and anc:FindFirstChildOfClass("Humanoid") then return end
        anc = anc.Parent
    end
    if wsSelected[part] then wsSelected[part] = nil; wsRemoveHL(part)
    else wsSelected[part] = true; wsAddHL(part) end
end
local function wsDoDisable()
    for part in pairs(wsSelected) do
        if part and part.Parent then
            wsDisabled[part] = { trans=part.Transparency, collide=part.CanCollide, shadow=part.CastShadow }
            pcall(function() part.Transparency=0.9; part.CanCollide=false; part.CastShadow=false end)
            wsRemoveHL(part)
        end
    end
    wsSelected = {}
end
local function wsDoRestore()
    for part, p in pairs(wsDisabled) do
        if part and part.Parent then
            pcall(function() part.Transparency=p.trans; part.CanCollide=p.collide; part.CastShadow=p.shadow end)
        end
    end
    wsDisabled = {}
end
local function wsDoClr()
    for part in pairs(wsSelected) do wsRemoveHL(part) end
    wsSelected = {}; wsHoverBox.Adornee = nil
end

RunService.RenderStepped:Connect(function()
    if not wsSelectMode then wsHoverBox.Adornee = nil; return end
    local t = wsGetTarget()
    wsHoverBox.Adornee = (t and not wsSelected[t]) and t or nil
end)
wsMouse.Button1Down:Connect(function()
    if not wsSelectMode then return end
    local t = wsGetTarget()
    if t then wsDoSelect(t) end
end)

loadSettings()

-- ================================================================
-- ARCANE UI CONSTRUCTION
-- ================================================================
local Window = Arcane:Window({
    Name = "DARK HUB",
    User = plr.Name,
    Logo = "74223698588684"
})

-- ================================ MAIN ============================
local MainTab = Window:Page({ Name = "Main", Icon = "home" })

local MainFeatures = MainTab:SubPage({ Name = "Features", Icon = "zap" })
local MFL = MainFeatures:Section({ Name = "Main Features", Side = 1 })
local MFR = MainFeatures:Section({ Name = "Blink Options", Side = 2 })

MFL:Toggle({ Name="Instant Interact", Default=false, Flag="InstantInteract",
    Callback=function(s)
        Flags.InstantInteract=s
        if s then
            -- apply ulang ke semua descendant (bukan cuma 1x)
            for _, obj in ipairs(Workspace:GetDescendants()) do makePromptInstant(obj) end
        end
        saveSettings()
    end })
MFL:Toggle({ Name="Inv Scan", Default=false, Flag="InvScan",
    Callback=function(s) Flags.InvScan=s; saveSettings() end })
MFL:Toggle({ Name="Speed Hack", Default=false, Flag="HybridSpeed",
    Callback=function(s) Flags.HybridSpeed=s; saveSettings() end })
MFL:Toggle({ Name="NoClip", Default=false, Flag="AuraKill",
    Callback=function(s) Flags.AuraKill=s; saveSettings() end })

MFR:Toggle({ Name="Blink TP (NoClip)", Default=false, Flag="TPNoClip",
    Callback=function(s) Flags.TPNoClip=s; saveSettings() end })
MFR:Dropdown({ Name="Blink Mode", Items={"PC","HP"}, Default="PC", Flag="BlinkMode",
    Callback=function(v) BlinkMode=v end })

-- Wall Selector
local WSSub = MainTab:SubPage({ Name = "Wall Selector", Icon = "list" })
local WSL = WSSub:Section({ Name = "Controls", Side = 1 })
local WSR = WSSub:Section({ Name = "Actions", Side = 2 })
WSL:Toggle({ Name="Select Mode", Default=false, Flag="WSSelect",
    Callback=function(s) wsSelectMode = s; if not s then wsHoverBox.Adornee=nil end end })
WSL:Button({ Name="Hotkeys: [P] Toggle | [M] Disable | [L] Restore | [K] Clear", Callback=function() end })
WSR:Button({ Name="[M] Disable Selected", Callback=wsDoDisable })
WSR:Button({ Name="[L] Restore Selected", Callback=wsDoRestore })
WSR:Button({ Name="[K] Clear Selection", Callback=wsDoClr })

-- ============================================================
-- FAKE NAME — LENGER METHOD (NameTag + RankTag)
-- ============================================================
local FNSub = MainTab:SubPage({ Name = "Fake Name", Icon = "user" })
local FNL = FNSub:Section({ Name = "Rename In-Game (LENGER)", Side = 1 })

local fnInput1Ref, fnInput2Ref
local fnStatusRef

FNL:Textbox({ Name="In-Game Name (NameTag)", Placeholder="contoh: Player01", Flag="FNGameName",
    Callback=function(text) fnInput1Ref = text end })
FNL:Textbox({ Name="Username (RankTag)", Placeholder="contoh: player01", Flag="FNUsername",
    Callback=function(text) fnInput2Ref = text end })

FNL:Button({ Name="Apply Rename", Callback=function()
    local ok = false
    pcall(function()
        local char = game.Players.LocalPlayer.Character
        -- Support folder Characters atau langsung di workspace
        local myChar = (workspace:FindFirstChild("Characters")
            and workspace.Characters:FindFirstChild(game.Players.LocalPlayer.Name))
            or char
        if not myChar or not myChar:FindFirstChild("Head") then return end

        local name1 = fnInput1Ref or ""
        local name2 = fnInput2Ref or ""

        -- NameTag (In-Game Name)
        if name1 ~= "" then
            local tag1 = myChar.Head:FindFirstChild("NameTag")
            if tag1 then
                local lbl = tag1:FindFirstChild("MainFrame")
                    and tag1.MainFrame:FindFirstChild("NameLabel")
                if lbl then
                    lbl.Text = name1
                    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
                    lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                    lbl.TextStrokeTransparency = 0.5
                    ok = true
                end
            end
        end

        -- RankTag (Username)
        if name2 ~= "" then
            local tag2 = myChar.Head:FindFirstChild("RankTag")
            if tag2 then
                local lbl = tag2:FindFirstChild("MainFrame")
                    and tag2.MainFrame:FindFirstChild("NameLabel")
                if lbl then
                    lbl.Text = name2
                    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
                    lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                    lbl.TextStrokeTransparency = 0.5
                    ok = true
                end
            end
        end
    end)

    Arcane:Notification({
        Name = "Fake Name",
        Description = ok and "Applied!" or "Tag not found",
        Duration = 3,
        Icon = ok and "check" or "x",
        Color = ok and Color3.fromRGB(52, 255, 164) or Color3.fromRGB(255, 80, 80)
    })
end })

-- Performance
local PerfSub = MainTab:SubPage({ Name = "Performance", Icon = "settings" })
local PerfL = PerfSub:Section({ Name = "Optimization", Side = 1 })
PerfL:Button({ Name="Reduce Grafik (Need Rejoin)", Callback=function()
    task.spawn(function()
        local Lighting = game:GetService("Lighting")
        for _, v in ipairs(Lighting:GetChildren()) do
            if v:IsA("PostEffect") then pcall(function() v:Destroy() end) end
        end
        pcall(function()
            Lighting.GlobalShadows = false; Lighting.FogEnd = 9e9; Lighting.Brightness = 2
        end)
        local localChar = plr.Character
        local function handleInstance(inst)
            if inst:IsA("BasePart") then
                if localChar and inst:IsDescendantOf(localChar) then return end
                pcall(function() inst.Material = Enum.Material.SmoothPlastic; inst.Reflectance = 0 end)
            end
            if inst:IsA("Texture") or inst:IsA("Decal") then
                if localChar and inst:IsDescendantOf(localChar) then return end
                pcall(function() inst.Transparency = 1 end)
            end
        end
        local all = workspace:GetDescendants()
        for i = 1, #all, 100 do
            for j = i, math.min(i+99, #all) do pcall(function() handleInstance(all[j]) end) end
            task.wait()
        end
        pcall(function()
            local t = workspace:FindFirstChild("Terrain")
            if t then t.WaterWaveSize=0; t.WaveSpeed=0; t.WaterReflectance=0; t.WaterTransparency=1 end
        end)
        pcall(function()
            settings().Physics.AllowSleep = true
            settings().Rendering.QualityLevel = 1
            settings().Rendering.TextureQuality = Enum.TextureQuality.Low
        end)
    end)
end })

-- ================================ COMBAT ==========================
local CombatTab = Window:Page({ Name = "Combat", Icon = "swords" })

local AimSub = CombatTab:SubPage({ Name = "Aimbot", Icon = "crosshair" })
local AimL = AimSub:Section({ Name = "Aimbot", Side = 1 })
local AimR = AimSub:Section({ Name = "Silent Aim", Side = 2 })

local AutoAimToggle = AimL:Toggle({ Name="Auto Aim", Default=false, Flag="AimLock",
    Callback=function(s) Flags.AimLock=s; saveSettings() end })
AimL:Dropdown({ Name="Mode", Items={"PC","HP"}, Default="PC", Flag="AimMode",
    Callback=function(v) AimMode=v; AimTarget=nil end })
AimL:Dropdown({ Name="Target Part", Items={"Head","Body"}, Default="Head", Flag="AimPart",
    Callback=function(v) AimPart=v; AimTarget=nil end })
AimL:Toggle({ Name="Wall Check", Default=false, Flag="WallCheck",
    Callback=function(s) Flags.WallCheck=s; saveSettings() end })
AutoAimToggle:Keybind({ Default=Enum.KeyCode.LeftAlt, Mode="Toggle", Flag="AimKeybind" })

AimR:Toggle({ Name="Silent Aim", Default=false, Flag="SilentAim",
    Callback=function(s) SilentAim=s end })
AimR:Toggle({ Name="Silent Wallbang", Default=false, Flag="SilentWallbang",
    Callback=function(s) SilentAimWallbang=s end })
AimR:Dropdown({ Name="Mode", Items={"PC","HP"}, Default="PC", Flag="SilentMode",
    Callback=function(v) SilentMode=v end })
AimR:Dropdown({ Name="Part", Items={"Head","Body"}, Default="Head", Flag="SilentPart",
    Callback=function(v) SilentPart=v end })

local FOVSub = CombatTab:SubPage({ Name = "FOV & Tuning", Icon = "list" })
local FOVL = FOVSub:Section({ Name = "FOV & Smoothing", Side = 1 })
local FOVR = FOVSub:Section({ Name = "Display", Side = 2 })

FOVL:Slider({ Name="Aimbot FOV", Min=30, Max=400, Default=120, Suffix=" px", Flag="AimFOV",
    Callback=function(v) AimFOV_Radius=v; saveSettings() end })
FOVL:Slider({ Name="Silent FOV", Min=30, Max=400, Default=120, Suffix=" px", Flag="SilentFOV",
    Callback=function(v) SilentFOV_Radius=v end })
FOVL:Slider({ Name="Max Distance", Min=50, Max=1000, Default=300, Suffix=" studs", Flag="AimDist",
    Callback=function(v) AimMax_Dist=v; saveSettings() end })
FOVL:Slider({ Name="Smoothness", Min=1, Max=100, Default=85, Suffix="%", Flag="AimSmooth",
    Callback=function(v) AimSmooth=math.clamp(v/100, 0.01, 0.99); saveSettings() end })
FOVR:Toggle({ Name="Show Aimbot FOV", Default=true, Flag="ShowAimFOV",
    Callback=function(s) ShowAimFOV=s end })
FOVR:Toggle({ Name="Show Silent FOV", Default=true, Flag="ShowSilentFOV",
    Callback=function(s) ShowSilentFOV=s end })

local WLSub = CombatTab:SubPage({ Name = "Whitelist", Icon = "save" })
local WLL = WLSub:Section({ Name = "Whitelist", Side = 1 })
WLL:Textbox({ Name="Usernames (comma separated)", Placeholder="user1,user2", Flag="WLInput",
    Callback=function(text)
        AimWhitelist = {}
        for name in string.gmatch(text or "", "[^,]+") do
            local n = name:gsub("^%s+", ""):gsub("%s+$", "")
            if n ~= "" then AimWhitelist[n] = true end
        end
    end })
WLL:Button({ Name="Clear Whitelist", Callback=function() AimWhitelist = {} end })

-- ================================ VISUAL ==========================
local VisualTab = Window:Page({ Name = "Visual", Icon = "eye" })

local ESPSub = VisualTab:SubPage({ Name = "ESP", Icon = "scan-eye" })
local ESPL = ESPSub:Section({ Name = "ESP Features", Side = 1 })
local ESPR = ESPSub:Section({ Name = "Distances", Side = 2 })

ESPL:Toggle({ Name="Box ESP", Default=false, Flag="BoxESP",
    Callback=function(s) Flags.BoxESP=s; saveSettings() end })
ESPL:Dropdown({ Name="Box Mode", Items={"FULL","CORNER"}, Default="FULL", Flag="BoxMode",
    Callback=function(v) BoxESPMode=v end })
ESPL:Toggle({ Name="Tracer", Default=false, Flag="Tracer",
    Callback=function(s) Flags.Tracer=s; saveSettings() end })
ESPL:Toggle({ Name="Name", Default=true, Flag="ESPName", Callback=function(s) Flags.ESPName=s end })
ESPL:Toggle({ Name="Distance", Default=true, Flag="ESPDist", Callback=function(s) Flags.ESPDist=s end })
ESPL:Toggle({ Name="HP Bar", Default=true, Flag="ESPHPBar", Callback=function(s) Flags.ESPHPBar=s end })
ESPL:Toggle({ Name="GUN", Default=true, Flag="ESPWeapon", Callback=function(s) Flags.ESPWeapon=s end })
ESPL:Toggle({ Name="Skeleton", Default=false, Flag="ESPSkeleton", Callback=function(s) Flags.ESPSkeleton=s end })
ESPL:Toggle({ Name="Masak", Default=true, Flag="ESPMasak", Callback=function(s) Flags.ESPMasak=s end })

ESPR:Slider({ Name="ESP Distance", Min=10, Max=5000, Default=500, Suffix=" studs", Flag="ESPDistSlider",
    Callback=function(v) ESPMaxDist=v end })
ESPR:Slider({ Name="Tracer Distance", Min=50, Max=1000, Default=300, Suffix=" studs", Flag="TracerDistSlider",
    Callback=function(v) TracerMaxDist=v end })

local SpecSub = VisualTab:SubPage({ Name = "Spectate", Icon = "user" })
local SpecL = SpecSub:Section({ Name = "Spectate Player", Side = 1 })
local specList = { "None" }
for _, p in ipairs(game.Players:GetPlayers()) do
    if p ~= plr then table.insert(specList, p.Name) end
end
local specSelected = "None"
local specConn = nil
local specTarget = nil

SpecL:Dropdown({ Name="Player", Items=specList, Default="None", Flag="SpecPlayer",
    Callback=function(v) specSelected = v end })
local function stopSpectate()
    if specConn then specConn:Disconnect(); specConn = nil end
    specTarget = nil
    local cam = workspace.CurrentCamera
    pcall(function()
        cam.CameraType = Enum.CameraType.Custom
        cam.CameraSubject = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
    end)
end
SpecL:Button({ Name="Start Spectate", Callback=function()
    stopSpectate()
    local targetP = game.Players:FindFirstChild(specSelected)
    if not targetP or not targetP.Character then return end
    specTarget = targetP
    local cam = workspace.CurrentCamera
    pcall(function()
        local hum = targetP.Character:FindFirstChildOfClass("Humanoid")
        cam.CameraType = Enum.CameraType.Custom
        cam.CameraSubject = hum
    end)
    specConn = RunService.RenderStepped:Connect(function()
        if not specTarget or not specTarget.Parent then stopSpectate(); return end
        local char = specTarget.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if cam.CameraType ~= Enum.CameraType.Custom then cam.CameraType = Enum.CameraType.Custom end
        if hum and cam.CameraSubject ~= hum then cam.CameraSubject = hum end
    end)
end })
SpecL:Button({ Name="Stop Spectate", Callback=stopSpectate })

-- ================================ FARM ============================
local FarmTab = Window:Page({ Name = "Farm", Icon = "list" })

local ChipsSub = FarmTab:SubPage({ Name = "Chips", Icon = "list" })
local ChipsL = ChipsSub:Section({ Name = "Auto Farm Chips", Side = 1 })
local ChipsR = ChipsSub:Section({ Name = "Pot", Side = 2 })

ChipsL:Toggle({ Name="Start Chips Farm", Default=false, Flag="ChipsFarm",
    Callback=function(s)
        if s then
            if ChipsST.running then return end
            ChipsST.running = true; ChipsST.cycle = 0
            task.spawn(function()
                local ok, err = pcall(doChipsFarm)
                if not ok then warn("[ChipsFarm] Error:", err) end
                ChipsST.running = false
                setFarmStatus(nil)
            end)
        else
            ChipsST.running = false
            setFarmStatus(nil)
        end
    end })

local potOptions = {}
for i = 1, 10 do table.insert(potOptions, "Pot "..i) end
ChipsR:Dropdown({ Name="Pilih Pot", Items=potOptions, Default="Pot 1", Flag="ChipsPot",
    Callback=function(v)
        local n = tonumber(string.match(v, "%d+"))
        if n then ChipsST.pot = n end
    end })

local BoxSub = FarmTab:SubPage({ Name = "Box", Icon = "list" })
local BoxL = BoxSub:Section({ Name = "Auto Farm Box", Side = 1 })
BoxL:Toggle({ Name="Start Box Farm", Default=false, Flag="BoxFarm",
    Callback=function(s)
        if s then
            if BoxST.running then return end
            BoxST.running = true; BoxST.cycle = 0
            task.spawn(function()
                local ok, err = pcall(doBoxFarm)
                if not ok then warn("[BoxFarm] Error:", err) end
                BoxST.running = false
                setFarmStatus(nil)
            end)
        else
            BoxST.running = false
            setFarmStatus(nil)
        end
    end })

-- ================================ TP ==============================
local TPTab = Window:Page({ Name = "TP", Icon = "crosshair" })

local TPOthersSub = TPTab:SubPage({ Name = "Others", Icon = "list" })
local TPOL = TPOthersSub:Section({ Name = "Others (Kill TP)", Side = 1 })
local TPOR = TPOthersSub:Section({ Name = "Actions", Side = 2 })

local killTPSelected = TP_OTHERS_NAMES[1] or "Bag Store"
TPOL:Dropdown({
    Name = "Location",
    Items = TP_OTHERS_NAMES,
    Default = killTPSelected,
    Flag = "KillTPLoc",
    SearchBarEnabled = true,
    Callback = function(v) killTPSelected = v end,
})

TPOR:Button({ Name="KILL TP", Callback=function()
    if tpBusy then return end
    local loc = TP_OTHERS_MAP[killTPSelected]
    if not loc then return end
    task.spawn(function() doSuicideTP(loc) end)
end })

-- ================================ INFO ============================
local InfoTab = Window:Page({ Name = "Info", Icon = "settings" })
local InfoSub = InfoTab:SubPage({ Name = "About", Icon = "user" })
local InfoR = InfoSub:Section({ Name = "Warning", Side = 1 })
InfoR:Button({ Name="USE AT YOUR OWN RISK — No responsibility for bans. DO NOT RE-SELL / RE-SHARE!", Callback=function() end })

-- ================================ CONFIG ==========================
local ConfigTab = Window:Page({ Name = "Config", Icon = "save" })
local ConfigSub = ConfigTab:SubPage({ Name = "Configs", Icon = "save" })
ConfigSub:Config()

-- ================================================================
-- BLINK HP PANEL
-- ================================================================
local HPPanel = Instance.new("Frame")
HPPanel.Name = "DARKHUB_HPPanel"
HPPanel.Size = UDim2.new(0, 58, 0, 58)
HPPanel.Position = UDim2.new(0, 16, 0.5, -29)
HPPanel.BackgroundColor3 = Color3.fromRGB(14, 20, 38)
HPPanel.Active = true
HPPanel.Visible = false
HPPanel.ZIndex = 100
HPPanel.Parent = CoreGui
Instance.new("UICorner", HPPanel).CornerRadius = UDim.new(0, 14)
Instance.new("UIStroke", HPPanel).Color = Color3.fromRGB(0, 170, 255)

local HPTBtn = Instance.new("TextButton", HPPanel)
HPTBtn.Size = UDim2.new(1, -10, 1, -10)
HPTBtn.Position = UDim2.new(0, 5, 0, 5)
HPTBtn.BackgroundColor3 = Color3.fromRGB(18, 24, 44)
HPTBtn.Text = "T"
HPTBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
HPTBtn.Font = Enum.Font.GothamBlack
HPTBtn.TextSize = 22
HPTBtn.AutoButtonColor = false
HPTBtn.ZIndex = 101
Instance.new("UICorner", HPTBtn).CornerRadius = UDim.new(0, 10)

do
    local hpDragging, hpDragStart, hpStartPos = false, nil, nil
    HPPanel.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            hpDragging = true; hpDragStart = inp.Position; hpStartPos = HPPanel.Position
            inp.Changed:Connect(function()
                if inp.UserInputState == Enum.UserInputState.End then hpDragging = false end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(inp)
        if hpDragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            local delta = inp.Position - hpDragStart
            HPPanel.Position = UDim2.new(hpStartPos.X.Scale, hpStartPos.X.Offset + delta.X,
                hpStartPos.Y.Scale, hpStartPos.Y.Offset + delta.Y)
        end
    end)
    UIS.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            hpDragging = false
        end
    end)
end

HPTBtn.MouseButton1Click:Connect(function()
    if not Flags.TPNoClip then return end
    local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        TweenService:Create(hrp, TweenInfo.new(0.15, Enum.EasingStyle.Linear),
            { CFrame = hrp.CFrame * CFrame.new(0, 0, -6) }):Play()
    end
end)
RunService.RenderStepped:Connect(function()
    HPPanel.Visible = (BlinkMode == "HP" and Flags.TPNoClip)
end)

-- ================================================================
-- CORE LOGIC LOOPS (Inf Stamina DIHAPUS)
-- ================================================================
local HS_ANIM_SPEED = 22
local HS_PUSH = 3
RunService.Heartbeat:Connect(function(dt)
    if not Flags.HybridSpeed then return end
    local char = plr.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return end
    if hum.WalkSpeed ~= HS_ANIM_SPEED then hum.WalkSpeed = HS_ANIM_SPEED end
    if hum.MoveDirection.Magnitude > 0 then
        root.CFrame = root.CFrame + hum.MoveDirection * HS_PUSH * dt
    end
end)

-- NoClip
local NC_CollideData = {}
local function NC_Cache(char)
    NC_CollideData = {}
    for _, part in ipairs(char:GetChildren()) do
        pcall(function()
            if part:IsA("BasePart") then NC_CollideData[part.Name] = part.CanCollide end
        end)
    end
end
if plr.Character then pcall(function() NC_Cache(plr.Character) end) end
plr.CharacterAdded:Connect(function(c) NC_Cache(c) end)

local _ncInstalled = false
local function NC_Install()
    if _ncInstalled then return end
    _ncInstalled = true
    pcall(function()
        local meta = getrawmetatable(game)
        local oldIndex = meta.__index
        setreadonly(meta, false)
        meta.__index = function(self, index)
            if index == "CanCollide" and typeof(self) == "Instance" and self.Name and NC_CollideData[self.Name] then
                return NC_CollideData[self.Name]
            end
            return oldIndex(self, index)
        end
        setreadonly(meta, true)
    end)
end
local noclipActive = false
local function enableAura()
    if noclipActive then return end
    NC_Install()
    noclipActive = true
    RunService:BindToRenderStep("NoClip", 400, function()
        if not Flags.AuraKill then return end
        local char = plr.Character
        if not char then return end
        local hum = char:FindFirstChild("Humanoid")
        if not hum or hum.Health <= 0 then return end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                pcall(function() part.CanCollide = false end)
            end
        end
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then pcall(function() root.CanCollide = false end) end
    end)
end
local function disableAura()
    if not noclipActive then return end
    noclipActive = false
    RunService:UnbindFromRenderStep("NoClip")
    local char = plr.Character
    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and NC_CollideData[part.Name] ~= nil then
                pcall(function() part.CanCollide = NC_CollideData[part.Name] end)
            end
        end
    end
end
plr.CharacterAdded:Connect(function(c) if noclipActive then disableAura() end; task.wait(0.5); NC_Cache(c) end)
task.spawn(function()
    local last = Flags.AuraKill
    while Running do
        task.wait(0.3)
        if Flags.AuraKill ~= last then
            last = Flags.AuraKill
            if last then enableAura() else disableAura() end
        end
    end
end)

UIS.InputBegan:Connect(function(input)
    if not Running then return end
    if Flags.TPNoClip and BlinkMode == "PC" and input.KeyCode == Enum.KeyCode.T then
        local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            TweenService:Create(hrp, TweenInfo.new(0.15, Enum.EasingStyle.Linear),
                { CFrame = hrp.CFrame * CFrame.new(0,0,-6) }):Play()
        end
    end
end)

UIS.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    if inp.KeyCode == Enum.KeyCode.P then
        wsSelectMode = not wsSelectMode
        if not wsSelectMode then wsHoverBox.Adornee = nil end
    elseif inp.KeyCode == Enum.KeyCode.M then wsDoDisable()
    elseif inp.KeyCode == Enum.KeyCode.L then wsDoRestore()
    elseif inp.KeyCode == Enum.KeyCode.K then wsDoClr() end
end)

-- Silent Aim hook
task.spawn(function()
    local function searchGc(fname)
        local ok, gc = pcall(getgc)
        if not ok then return nil end
        for _, v in pairs(gc) do
            if type(v) == "function" then
                local ok2, info = pcall(debug.getinfo, v)
                if ok2 and info and info.name == fname then return v end
            end
        end
    end
    local tries = 0
    while tries < 30 do
        task.wait(1); tries = tries + 1
        local cb = searchGc("CastBlacklist")
        local cw = searchGc("CastWhitelist")
        if cb and cw then
            local OldCast = hookfunction(cb, function(...)
                if not SilentAim then return OldCast(...) end
                local cam = workspace.CurrentCamera
                local vp2 = cam.ViewportSize
                local saOrigin = SilentMode == "HP" and Vector2.new(vp2.X/2, vp2.Y/2) or UIS:GetMouseLocation()
                local Target, LowestDist = nil, math.huge
                for _, p in pairs(game.Players:GetPlayers()) do
                    local ch = p.Character
                    if p == plr or not ch then continue end
                    local hrp = ch:FindFirstChild("HumanoidRootPart")
                    local hum = ch:FindFirstChildOfClass("Humanoid")
                    if not hrp or not hum or hum.Health <= 0 then continue end
                    local sp, onScreen = cam:WorldToViewportPoint(hrp.Position)
                    if not onScreen then continue end
                    local d = (saOrigin - Vector2.new(sp.X, sp.Y)).Magnitude
                    if d < SilentFOV_Radius and d < LowestDist then
                        Target = p; LowestDist = d
                    end
                end
                if Target then
                    local args = {...}
                    local hitPart = Target.Character and Target.Character:FindFirstChild(SilentPart == "Head" and "Head" or "HumanoidRootPart")
                    if hitPart then
                        args[2] = hitPart.Position - args[1]
                        if SilentAimWallbang then
                            args[3] = {Target.Character}
                            return cw(table.unpack(args))
                        end
                    end
                    return OldCast(table.unpack(args))
                end
                return OldCast(...)
            end)
            break
        end
    end
end)

for _, p in pairs(game.Players:GetPlayers()) do createESP(p) end
game.Players.PlayerAdded:Connect(createESP)
game.Players.PlayerRemoving:Connect(removeESP)

local espCache = {}
local espConns = {}
local ESP_MASAK_KW = {"water","sugar","gelatin","marshmallow"}
local function isKW(name)
    local n = name:lower()
    for _, kw in ipairs(ESP_MASAK_KW) do if n:find(kw) then return true end end
    return false
end
local function rebuildCache(p)
    if not p or not p.Parent then return end
    local hb, wn = false, nil
    pcall(function()
        local bp = p.Backpack
        if bp then for _, v in ipairs(bp:GetChildren()) do
            if v:IsA("Tool") and isKW(v.Name) then hb = true end
        end end
        local ch = p.Character
        if ch then for _, v in ipairs(ch:GetChildren()) do
            if v:IsA("Tool") then
                if isKW(v.Name) then hb = true else wn = v.Name end
            end
        end end
    end)
    espCache[p] = {hasBahan = hb, wName = wn}
end
local function connectESPPlayer(p)
    if p == plr or espConns[p] then return end
    local conns = {}
    espConns[p] = conns
    rebuildCache(p)
    if p.Backpack then
        table.insert(conns, p.Backpack.ChildAdded:Connect(function() rebuildCache(p) end))
        table.insert(conns, p.Backpack.ChildRemoved:Connect(function() rebuildCache(p) end))
    end
    local function watchChar(ch)
        if not ch then return end
        table.insert(conns, ch.ChildAdded:Connect(function(v) if v:IsA("Tool") then rebuildCache(p) end end))
        table.insert(conns, ch.ChildRemoved:Connect(function(v) if v:IsA("Tool") then rebuildCache(p) end end))
        rebuildCache(p)
    end
    if p.Character then watchChar(p.Character) end
    table.insert(conns, p.CharacterAdded:Connect(function(ch) task.wait(0.1); watchChar(ch) end))
end
for _, p in ipairs(game.Players:GetPlayers()) do connectESPPlayer(p) end
game.Players.PlayerAdded:Connect(connectESPPlayer)

local SKEL_BONES = {
    {"Head","UpperTorso"}, {"UpperTorso","LowerTorso"},
    {"UpperTorso","RightUpperArm"}, {"RightUpperArm","RightLowerArm"}, {"RightLowerArm","RightHand"},
    {"UpperTorso","LeftUpperArm"}, {"LeftUpperArm","LeftLowerArm"}, {"LeftLowerArm","LeftHand"},
    {"LowerTorso","RightUpperLeg"}, {"RightUpperLeg","RightLowerLeg"}, {"RightLowerLeg","RightFoot"},
    {"LowerTorso","LeftUpperLeg"}, {"LeftUpperLeg","LeftLowerLeg"}, {"LeftLowerLeg","LeftFoot"},
    {"RightUpperLeg","LeftUpperLeg"},
}
local wpRayParams = RaycastParams.new()
wpRayParams.FilterType = Enum.RaycastFilterType.Blacklist

local RMB = false
UIS.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton2 then RMB = true end
end)
UIS.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton2 then RMB = false; AimTarget = nil end
end)

RunService.RenderStepped:Connect(function()
    if not Running then
        pcall(function() FovCircle:Remove(); SilentFovCircle:Remove(); SilentLine:Remove() end)
        return
    end
    if _overlayActive then
        FovCircle.Visible=false; SilentFovCircle.Visible=false; SilentLine.Visible=false
        for _, e in pairs(ESP) do _hideESP(e) end
        return
    end

    local cam = workspace.CurrentCamera
    local vp = cam.ViewportSize
    local mousePos = UIS:GetMouseLocation()
    local localChar = plr.Character
    local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")
    local fovCenter = (AimMode == "HP") and Vector2.new(vp.X/2, vp.Y/2) or mousePos

    FovCircle.Radius = AimFOV_Radius
    FovCircle.Visible = Flags.AimLock and ShowAimFOV

    do
        if SilentAim then
            local saOrigin = SilentMode == "HP" and Vector2.new(vp.X/2, vp.Y/2) or mousePos
            local bestWorldD, bestScreenPos = math.huge, nil
            for _, p in pairs(game.Players:GetPlayers()) do
                if p == plr then continue end
                local ch = p.Character
                if not ch then continue end
                local hum = ch:FindFirstChildOfClass("Humanoid")
                local part = ch:FindFirstChild(SilentPart == "Head" and "Head" or "HumanoidRootPart")
                if not part or not hum or hum.Health <= 0 then continue end
                local sp, onScreen = cam:WorldToViewportPoint(part.Position)
                if not onScreen or sp.Z <= 0 then continue end
                local screenPos = Vector2.new(sp.X, sp.Y)
                if (saOrigin - screenPos).Magnitude > SilentFOV_Radius then continue end
                local worldD = localRoot and (part.Position - localRoot.Position).Magnitude or math.huge
                if worldD < bestWorldD then bestWorldD = worldD; bestScreenPos = screenPos end
            end
            if bestScreenPos then
                SilentFovCircle.Position = (SilentMode == "HP") and bestScreenPos or saOrigin
                SilentFovCircle.Radius = SilentFOV_Radius
                SilentFovCircle.Visible = ShowSilentFOV
                SilentLine.From = saOrigin
                SilentLine.To = bestScreenPos
                SilentLine.Visible = ShowSilentFOV
            else
                SilentFovCircle.Position = saOrigin
                SilentFovCircle.Radius = SilentFOV_Radius
                SilentFovCircle.Visible = ShowSilentFOV
                SilentLine.Visible = false
            end
        else
            SilentFovCircle.Visible = false
            SilentLine.Visible = false
        end
    end

    if AimTarget then
        local tHum = AimTarget.Parent and AimTarget.Parent:FindFirstChildOfClass("Humanoid")
        if not tHum or tHum.Health <= 0 then AimTarget = nil end
    end
    if AimTarget and AimMode == "PC" then
        local sp, onScreen = cam:WorldToScreenPoint(AimTarget.Position)
        if not onScreen then AimTarget = nil
        else
            local d = math.sqrt((sp.X - fovCenter.X)^2 + (sp.Y - fovCenter.Y)^2)
            if d > AimFOV_Radius then AimTarget = nil end
        end
    end

    local shouldAim = Flags.AimLock and localRoot and (AimMode == "HP" or RMB)
    if shouldAim then
        if AimMode == "HP" or not AimTarget then
            local bestDist, bestPart = math.huge, nil
            for _, p in pairs(game.Players:GetPlayers()) do
                if p == plr or AimWhitelist[p.Name] then continue end
                local ch = p.Character
                local hum = ch and ch:FindFirstChildOfClass("Humanoid")
                local targetPart = ch and ch:FindFirstChild(AimPart == "Head" and "Head" or "HumanoidRootPart")
                if not targetPart or not hum or hum.Health <= 0 then continue end
                if (targetPart.Position - localRoot.Position).Magnitude > AimMax_Dist then continue end
                local sp, onScreen = cam:WorldToScreenPoint(targetPart.Position)
                if not onScreen then continue end
                if Flags.WallCheck then
                    local camPos = cam.CFrame.Position
                    local dir = targetPart.Position - camPos
                    wpRayParams.FilterDescendantsInstances = {cam, plr.Character}
                    local hit = workspace:Raycast(camPos, dir.Unit * dir.Magnitude, wpRayParams)
                    if hit and not hit.Instance:IsDescendantOf(ch) then continue end
                end
                local d = math.sqrt((sp.X-fovCenter.X)^2 + (sp.Y-fovCenter.Y)^2)
                if d <= AimFOV_Radius and d < bestDist then bestDist = d; bestPart = targetPart end
            end
            AimTarget = bestPart
        end
        if AimTarget then
            local targetCF = CFrame.lookAt(cam.CFrame.Position, AimTarget.Position)
            cam.CFrame = cam.CFrame:Lerp(targetCF, AimSmooth)
            FovCircle.Color = Color3.fromRGB(255, 80, 80)
        else
            FovCircle.Color = Color3.fromRGB(0, 170, 255)
        end
    else
        if AimMode == "PC" and not RMB then AimTarget = nil end
        FovCircle.Color = Color3.fromRGB(0, 170, 255)
    end
    if AimMode == "HP" and AimTarget then
        local sp2, vis2 = cam:WorldToViewportPoint(AimTarget.Position)
        if vis2 and sp2.Z > 0 then FovCircle.Position = Vector2.new(sp2.X, sp2.Y)
        else FovCircle.Position = fovCenter end
    else
        FovCircle.Position = fovCenter
    end

    -- ESP render
    local anyESP = Flags.BoxESP or Flags.Tracer or Flags.ESPName or Flags.ESPDist or Flags.ESPHPBar or Flags.ESPWeapon or Flags.ESPSkeleton or Flags.ESPMasak
    for p, e in pairs(ESP) do
        local ch = p.Character
        local hum = ch and ch:FindFirstChildOfClass("Humanoid")
        local root = ch and ch:FindFirstChild("HumanoidRootPart")
        if not anyESP or not ch or not hum or not root then _hideESP(e); continue end
        local pos3, onScreen = cam:WorldToViewportPoint(root.Position)
        if not onScreen or pos3.Z <= 0 then _hideESP(e); continue end
        local isDead = hum.Health <= 0
        if localRoot and (root.Position - localRoot.Position).Magnitude > ESPMaxDist then _hideESP(e); continue end

        if Flags.ESPSkeleton and ch then
            local W2 = isDead and Color3.fromRGB(255, 80, 100) or Color3.fromRGB(0, 170, 255)
            for si, bone in ipairs(SKEL_BONES) do
                local p1 = ch:FindFirstChild(bone[1])
                local p2 = ch:FindFirstChild(bone[2])
                local sk = e.skeleton[si]
                if p1 and p2 then
                    local s1, v1 = cam:WorldToViewportPoint(p1.Position)
                    local s2, v2 = cam:WorldToViewportPoint(p2.Position)
                    if v1 and v2 and s1.Z>0 and s2.Z>0 then
                        sk.From=Vector2.new(s1.X,s1.Y); sk.To=Vector2.new(s2.X,s2.Y)
                        sk.Color=W2; sk.Visible=true
                    else sk.Visible=false end
                else sk.Visible=false end
            end
        else
            for _,s in ipairs(e.skeleton) do s.Visible=false end
        end

        local topPos = cam:WorldToViewportPoint(root.Position + Vector3.new(0, 3.2, 0))
        local botPos = cam:WorldToViewportPoint(root.Position - Vector3.new(0, 3.5, 0))
        local sY = math.abs(botPos.Y - topPos.Y)
        local sX = sY * 0.6
        local bx = pos3.X - sX / 2
        local by = math.min(topPos.Y, botPos.Y)

        local cache = espCache[p] or {hasBahan=false, wName=nil}
        local hasBahan = cache.hasBahan
        local wName = cache.wName
        local W = isDead and Color3.fromRGB(255, 80, 100) or Color3.fromRGB(0, 170, 255)
        if Flags.BoxESP then
            e.box.Color=W; e.box.Size=Vector2.new(sX,sY); e.box.Position=Vector2.new(bx,by)
            e.box.Visible=(BoxESPMode=="FULL")
            local showC=(BoxESPMode=="CORNER")
            local cL=math.min(sX,sY)*0.25
            local cx=e.corners
            cx[1].From=Vector2.new(bx,by); cx[1].To=Vector2.new(bx+cL,by)
            cx[2].From=Vector2.new(bx,by); cx[2].To=Vector2.new(bx,by+cL)
            cx[3].From=Vector2.new(bx+sX,by); cx[3].To=Vector2.new(bx+sX-cL,by)
            cx[4].From=Vector2.new(bx+sX,by); cx[4].To=Vector2.new(bx+sX,by+cL)
            cx[5].From=Vector2.new(bx,by+sY); cx[5].To=Vector2.new(bx+cL,by+sY)
            cx[6].From=Vector2.new(bx,by+sY); cx[6].To=Vector2.new(bx,by+sY-cL)
            cx[7].From=Vector2.new(bx+sX,by+sY); cx[7].To=Vector2.new(bx+sX-cL,by+sY)
            cx[8].From=Vector2.new(bx+sX,by+sY); cx[8].To=Vector2.new(bx+sX,by+sY-cL)
            for ci=1,8 do cx[ci].Color=W; cx[ci].Visible=showC end
        else
            e.box.Visible=false
            for ci=1,8 do e.corners[ci].Visible=false end
        end
        local hp=math.clamp(hum.Health/math.max(hum.MaxHealth,1),0,1)
        local barH=math.max(1,sY*hp)
        local barX=bx-7
        local hpCol=hp>0.5 and Color3.fromRGB(0,220,0) or hp>0.2 and Color3.fromRGB(255,165,0) or Color3.fromRGB(255,0,0)
        if Flags.ESPHPBar then
            e.hpbg.Size=Vector2.new(4,sY); e.hpbg.Position=Vector2.new(barX,by)
            e.hpbg.Color=Color3.fromRGB(0,0,0); e.hpbg.Filled=false; e.hpbg.Thickness=1; e.hpbg.Visible=true
            e.hpbar.Color=hpCol; e.hpbar.Size=Vector2.new(4,barH)
            e.hpbar.Position=Vector2.new(barX,by+(sY-barH)); e.hpbar.Filled=true; e.hpbar.Visible=true
            e.hpnum.Text=math.floor(hum.Health).."HP"; e.hpnum.Size=11
            e.hpnum.Position=Vector2.new(barX+2,by-1); e.hpnum.Center=false
            e.hpnum.Color=hpCol; e.hpnum.Visible=true
        else
            e.hpbg.Visible=false; e.hpbar.Visible=false; e.hpnum.Visible=false
        end
        local distNow = localRoot and (root.Position-localRoot.Position).Magnitude or 100
        local tSize = math.clamp(math.floor(14 - distNow/40), 8, 14)
        if Flags.ESPName then
            e.dispname.Text=(p.DisplayName or p.Name).."(@"..p.Name..")"
            e.dispname.Size=tSize; e.dispname.Color=W
            e.dispname.Position=Vector2.new(pos3.X,by-14); e.dispname.Visible=true
            e.username.Visible=false
        else
            e.dispname.Visible=false; e.username.Visible=false
        end
        local dist=localRoot and math.floor((root.Position-localRoot.Position).Magnitude) or 0
        local nY=by+sY+3
        if Flags.ESPDist then
            e.dist.Text=dist.."m"; e.dist.Size=tSize; e.dist.Color=W
            e.dist.Position=Vector2.new(pos3.X,nY); e.dist.Visible=true
            nY=nY+13
        else e.dist.Visible=false end
        if Flags.ESPWeapon and wName then
            e.weapon.Text=wName; e.weapon.Color=Color3.fromRGB(0,170,255)
            e.weapon.Position=Vector2.new(pos3.X,nY); e.weapon.Visible=true
        else e.weapon.Visible=false end
        if Flags.ESPMasak and hasBahan then
            e.masak.Text="MASAK"; e.masak.Position=Vector2.new(bx+sX+4,by+sY/2-6)
            e.masak.Center=false; e.masak.Visible=true
        else e.masak.Visible=false end
        local tracerDist=localRoot and (root.Position-localRoot.Position).Magnitude or 999
        if Flags.Tracer and tracerDist<TracerMaxDist then
            local vp2=cam.ViewportSize
            e.tracer.From=Vector2.new(vp2.X/2,vp2.Y)
            e.tracer.To=Vector2.new(pos3.X,by+sY)
            e.tracer.Color=W; e.tracer.Visible=true
        else e.tracer.Visible=false end
    end
end)

Window:Watermark({ Title = "DARK HUB" })

Arcane:Notification({
    Name = "DARK HUB loaded",
    Description = "FakeName (LENGER) | InstantInteract | No Inf Stamina",
    Duration = 6,
    Icon = "check",
    Color = Color3.fromRGB(0, 170, 255)
})