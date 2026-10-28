--[[
    ========================================================================
    CATOWARE // EXAMINATION - GTA 5 STYLE MOD MENU (CLEAN & STEALTH)
    Mobile Supported • ContextActionService (CAS) Movement Isolation
    Features: Clean Visuals, Big Head, Spam Taunt, Fast Reload, ViralFists
    ========================================================================
]]

if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local lp = Players.LocalPlayer
local cam = workspace.CurrentCamera or workspace:FindFirstChildOfClass("Camera")
local charsFolder = workspace:WaitForChild("Characters", 10) or workspace

-- ========================================================================
-- TOGGLES & CONFIGURATION
-- ========================================================================
local Toggles = {
    -- Visuals (Human-like / Clean)
    visuals_enabled = true,
    visual_highlights = true,
    visual_names = true,
    big_head = false,
    fullbright = false,
    nofog = false,
    hazard_immune = false,

    -- Combat & Weapons (Less blatant)
    no_recoil = false,
    fast_reload = false,
    auto_parry = false,
    auto_equip_viral = false,
    auto_punch = false,

    -- Movement & Player
    inf_stamina = true,
    speed_mult_toggle = false,

    -- Taunt & Fun
    spam_taunt = false,
    health_taunt = false,
    anim_speed_toggle = false,

    -- Menu
    floating_btn = true,
}

local Options = {
    big_head_size = 5,
    speed_mult = 1.2,
    felsi_reload = 1.5,
    squad_reload = 2.0,
    adminstal_speed = 1.5,
    parry_range = 12,
    punch_range = 10,
    anim_speed = 100,
}

-- Notifications
local function showNotification(msg)
    pcall(function()
        local pGui = lp:FindFirstChild("PlayerGui")
        if not pGui then return end
        local notifGui = pGui:FindFirstChild("CatowareNotification")
        if not notifGui then
            notifGui = Instance.new("ScreenGui")
            notifGui.Name = "CatowareNotification"
            notifGui.ResetOnSpawn = false
            notifGui.DisplayOrder = 100000
            notifGui.Parent = pGui
        end
        local label = Instance.new("TextLabel")
        label.Size = UDim2.fromOffset(260, 36)
        label.Position = UDim2.new(0.5, -130, 0.12, 0)
        label.BackgroundColor3 = Color3.fromRGB(15, 18, 26)
        label.BackgroundTransparency = 0.15
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 13
        label.Text = msg
        label.Parent = notifGui
        local corner = Instance.new("UICorner", label)
        corner.CornerRadius = UDim.new(0, 8)
        local stroke = Instance.new("UIStroke", label)
        stroke.Color = Color3.fromRGB(101, 111, 207)
        stroke.Thickness = 1.5
        task.delay(2.2, function()
            label:Destroy()
        end)
    end)
end

-- ========================================================================
-- TAUNT SYSTEM (RENDERSTEPPED + HEALTHCHANGED)
-- ========================================================================
local spamTauntConn = nil
local healthTauntConn = nil

local function updateTaunt()
    if spamTauntConn then
        spamTauntConn:Disconnect()
        spamTauntConn = nil
    end

    if Toggles.spam_taunt then
        local rs = game:GetService("ReplicatedStorage")
        local rsSvc = game:GetService("RunService")
        spamTauntConn = rsSvc.RenderStepped:Connect(function()
            pcall(function()
                local te = rs:FindFirstChild("TauntEvent")
                if te and te:IsA("RemoteEvent") then
                    te:FireServer()
                end
            end)
        end)
    end
end

local function setupHealthTaunt(char)
    if healthTauntConn then
        healthTauntConn:Disconnect()
        healthTauntConn = nil
    end
    local c = char or lp.Character
    if not c then return end
    local hum = c:WaitForChild("Humanoid", 5)
    if hum then
        healthTauntConn = hum.HealthChanged:Connect(function()
            if Toggles.health_taunt or Toggles.spam_taunt then
                pcall(function()
                    local te = ReplicatedStorage:FindFirstChild("TauntEvent")
                    if te and te:IsA("RemoteEvent") then
                        te:FireServer()
                    end
                end)
            end
        end)
    end
end

setupHealthTaunt(lp.Character)
lp.CharacterAdded:Connect(setupHealthTaunt)

local function fireSingleTaunt()
    pcall(function()
        local te = ReplicatedStorage:FindFirstChild("TauntEvent")
        if te and te:IsA("RemoteEvent") then
            te:FireServer()
            showNotification("Taunt Event Fired!")
        else
            showNotification("TauntEvent not found")
        end
    end)
end

-- ========================================================================
-- CLEAN HUMAN-LIKE VISUALS & BIG HEAD (USER SPECIFIED LOGIC)
-- ========================================================================
local activeHighlights = {}
local activeBillboards = {}
local originalHeadSizes = {}

local function findHeadPart(char)
    local head = char:FindFirstChild("Head", true)
    if not head then
        for _, desc in ipairs(char:GetDescendants()) do
            if desc:IsA("BasePart") and (desc.Name:lower():find("head") or desc.Name:lower():find("mask")) then
                head = desc
                break
            end
        end
    end
    return head
end

local function applyBigHead(char)
    local head = findHeadPart(char)
    if head and head:IsA("BasePart") then
        if not originalHeadSizes[head] then
            originalHeadSizes[head] = head.Size
        end
        if Toggles.big_head then
            local s = Options.big_head_size or 5
            head.Size = Vector3.new(s, s, s)
            head.CanCollide = false
            head.Transparency = 0.5
            head.LocalTransparencyModifier = 0.5
        else
            if originalHeadSizes[head] then
                head.Size = originalHeadSizes[head]
                head.Transparency = 0
                head.LocalTransparencyModifier = 0
            end
        end
    end
end

local function setupChar(char)
    if not (char and char:IsA("Model")) then return end
    local player = Players:GetPlayerFromCharacter(char)
    local isLocalPlayer = (player == lp)

    -- Apply or revert Big Head
    applyBigHead(char)

    if isLocalPlayer then
        return
    end

    local head = findHeadPart(char)
    if not (head and head:IsA("BasePart")) then return end
    local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 4)
    local nameStr = player and player.DisplayName or char.Name

    -- Clean Highlight
    local oldHi = char:FindFirstChild("CatowareHighlight") or char:FindFirstChildOfClass("Highlight")
    if oldHi and oldHi.Name == "CatowareHighlight" then oldHi:Destroy() end

    if Toggles.visuals_enabled and Toggles.visual_highlights then
        local h = Instance.new("Highlight")
        h.Name = "CatowareHighlight"
        h.Adornee = char
        h.FillTransparency = 0.85
        h.OutlineTransparency = 0.5
        h.FillColor = player and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(255, 50, 50)
        h.OutlineColor = Color3.fromRGB(255, 255, 255)
        h.Parent = char
        activeHighlights[char] = h
    end

    -- Clean Billboard
    local oldBg = head:FindFirstChild("CatowareBillboard") or head:FindFirstChildOfClass("BillboardGui")
    if oldBg and oldBg.Name == "CatowareBillboard" then oldBg:Destroy() end

    if Toggles.visuals_enabled and Toggles.visual_names then
        local bg = Instance.new("BillboardGui")
        bg.Name = "CatowareBillboard"
        bg.Size = UDim2.new(0, 130, 0, 30)
        bg.StudsOffset = Vector3.new(0, 2.5, 0)
        bg.AlwaysOnTop = true
        bg.MaxDistance = 1500
        bg.Parent = head
        bg.Adornee = head

        local tl = Instance.new("TextLabel")
        tl.Size = UDim2.new(1, 0, 1, 0)
        tl.BackgroundTransparency = 1
        tl.TextColor3 = player and Color3.fromRGB(220, 240, 255) or Color3.fromRGB(255, 220, 220)
        tl.TextStrokeTransparency = 0.4
        tl.Font = Enum.Font.GothamBold
        tl.TextSize = 12
        tl.Parent = bg

        if hum then
            tl.Text = nameStr .. " [" .. math.floor(hum.Health) .. "]"
            hum.HealthChanged:Connect(function(health)
                tl.Text = nameStr .. " [" .. math.floor(health) .. "]"
            end)
        else
            tl.Text = nameStr
        end
        activeBillboards[char] = bg
    end
end

local function refreshAllVisuals()
    for _, v in ipairs(charsFolder:GetChildren()) do
        if v:IsA("Model") then
            setupChar(v)
        end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= lp and p.Character then
            setupChar(p.Character)
        end
    end
end

charsFolder.ChildAdded:Connect(function(v)
    if v:IsA("Model") then
        task.wait(0.1)
        setupChar(v)
    end
end)

Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function(char)
        task.wait(0.1)
        setupChar(char)
    end)
end)

-- ========================================================================
-- STAMINA & MOVEMENT (HEARTBEAT LOOP)
-- ========================================================================
local function modStamina(char)
    local stateScript = char:WaitForChild("ClientHandler", 5) and char.ClientHandler:WaitForChild("State", 5)
    if stateScript and stateScript:IsA("ModuleScript") then
        local state = nil
        pcall(function() state = require(stateScript) end)
        if type(state) == "table" and state.stamina then
            RunService.Heartbeat:Connect(function()
                if Toggles.inf_stamina then
                    state.stamina.current = state.stamina.max
                end
                if Toggles.speed_mult_toggle and state.speed and type(state.speed) == "table" then
                    state.speed.run = math.min(18.5 * (Options.speed_mult or 1.2), 24.0)
                end
            end)
        end
    end
end

if lp.Character then modStamina(lp.Character) end
lp.CharacterAdded:Connect(modStamina)

-- ========================================================================
-- WEAPONS & COMBAT UTILITIES
-- ========================================================================
local function applyFastReload(char)
    local c = char or lp.Character
    if not c then return end
    if Toggles.fast_reload then
        local f = Options.felsi_reload or 1.5
        local s = Options.squad_reload or 2.0
        local a = Options.adminstal_speed or 1.5
        pcall(function()
            c:SetAttribute("FelsiReloadSpeedMult", f)
            c:SetAttribute("SquadReloadSpeedMultiplier", s)
            c:SetAttribute("AdminstalSpeedMult", a)
            lp:SetAttribute("FelsiReloadSpeedMult", f)
            lp:SetAttribute("SquadReloadSpeedMultiplier", s)
            lp:SetAttribute("AdminstalSpeedMult", a)
        end)
    else
        pcall(function()
            c:SetAttribute("FelsiReloadSpeedMult", 1)
            c:SetAttribute("SquadReloadSpeedMultiplier", 1)
            c:SetAttribute("AdminstalSpeedMult", 1)
            lp:SetAttribute("FelsiReloadSpeedMult", 1)
            lp:SetAttribute("SquadReloadSpeedMultiplier", 1)
            lp:SetAttribute("AdminstalSpeedMult", 1)
        end)
    end
end

local function getViralFistsSource()
    local source = nil
    pcall(function()
        source = ReplicatedStorage.ClassModels["DEV FOLDER"]["DEV MORPH"].sk8r.Tools.ViralFists
    end)
    return source
end

local function findViralFists()
    local char = lp.Character
    local backpack = lp:FindFirstChildOfClass("Backpack")
    return (char and char:FindFirstChild("ViralFists")) or (backpack and backpack:FindFirstChild("ViralFists"))
end

local function equipViralFists(autoEquip)
    local char = lp.Character
    local equipped = char and char:FindFirstChild("ViralFists")
    if equipped then return equipped end
    if not autoEquip then return nil end
    local tool = findViralFists()
    local backpack = lp:FindFirstChildOfClass("Backpack")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not tool then
        local source = getViralFistsSource()
        if not source or not source:IsA("Tool") or not backpack then return nil end
        tool = source:Clone()
        tool.Parent = backpack
    end
    if hum and tool then hum:EquipTool(tool) end
    return tool
end

local function fireViralKey(key)
    local char = lp.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local tool = equipViralFists(Toggles.auto_equip_viral)
    local event = ReplicatedStorage:FindFirstChild("ViralFistsKeyPressEvent")
    if tool and event then
        event:FireServer(key)
        return true
    end
    return false
end

-- World effects tick
RunService.Heartbeat:Connect(function()
    if Toggles.fullbright then
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
        Lighting.Brightness = 2
    end
    if Toggles.nofog then
        Lighting.FogEnd = 9e9
        Lighting.FogStart = 9e9
    end
    if Toggles.hazard_immune and cam then
        local aee = cam:FindFirstChild("__cameraTint")
        local rad = cam:FindFirstChild("RadiationColorCorrection")
        if aee then aee.Contrast = 0 end
        if rad then rad.Contrast = 0 end
    end
end)

-- Auto Punch tick
local lastPunch = 0
RunService.Heartbeat:Connect(function()
    if not Toggles.auto_punch then return end
    local now = os.clock()
    if now - lastPunch < 0.5 then return end
    local char = lp.Character
    local myHrp = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
    if not myHrp then return end
    local punchRemote = ReplicatedStorage:FindFirstChild("PunchEvent")
    if not punchRemote then return end

    for _, enemy in ipairs(charsFolder:GetChildren()) do
        if enemy:IsA("Model") and enemy ~= char and not Players:GetPlayerFromCharacter(enemy) then
            local eHrp = enemy:FindFirstChild("HumanoidRootPart") or enemy.PrimaryPart
            local eHum = enemy:FindFirstChildOfClass("Humanoid")
            if eHrp and eHum and eHum.Health > 0 then
                if (eHrp.Position - myHrp.Position).Magnitude <= (Options.punch_range or 10) then
                    lastPunch = now
                    punchRemote:FireServer()
                    break
                end
            end
        end
    end
end)

-- Auto Parry tick
local lastParry = 0
RunService.Heartbeat:Connect(function()
    if not Toggles.auto_parry then return end
    local now = os.clock()
    if now - lastParry < 0.65 then return end
    local char = lp.Character
    local myHrp = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
    if not myHrp then return end

    for _, enemy in ipairs(charsFolder:GetChildren()) do
        if enemy:IsA("Model") and enemy ~= char and not Players:GetPlayerFromCharacter(enemy) then
            local eHrp = enemy:FindFirstChild("HumanoidRootPart") or enemy.PrimaryPart
            local eHum = enemy:FindFirstChildOfClass("Humanoid")
            if eHrp and eHum and eHum.Health > 0 then
                if (eHrp.Position - myHrp.Position).Magnitude <= (Options.parry_range or 12) then
                    lastParry = now
                    fireViralKey("F")
                    break
                end
            end
        end
    end
end)

-- ========================================================================
-- GTA 5 STYLE MOD MENU GUI (MOBILE FRIENDLY + CAS ISOLATION)
-- ========================================================================
local playerGui = lp:WaitForChild("PlayerGui")
local oldGui = playerGui:FindFirstChild("CatowareGTAMenu")
if oldGui then oldGui:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CatowareGTAMenu"
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 9999
screenGui.Parent = playerGui

-- Root Frame (Positioned top-left, scaled cleanly for mobile & PC)
local rootFrame = Instance.new("Frame", screenGui)
rootFrame.Name = "Root"
rootFrame.BorderSizePixel = 0
rootFrame.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
rootFrame.BackgroundTransparency = 0.15
rootFrame.Size = UDim2.fromOffset(275, 410)
rootFrame.Position = UDim2.new(0, 20, 0.5, -205)
rootFrame.ClipsDescendants = true

local rootCorner = Instance.new("UICorner", rootFrame)
rootCorner.CornerRadius = UDim.new(0, 10)
local rootStroke = Instance.new("UIStroke", rootFrame)
rootStroke.Color = Color3.fromRGB(101, 111, 207)
rootStroke.Thickness = 2

-- Header Image (rbxassetid://1847902738)
local headerImage = Instance.new("ImageLabel", rootFrame)
headerImage.Name = "HeaderImage"
headerImage.BorderSizePixel = 0
headerImage.BackgroundColor3 = Color3.fromRGB(22, 24, 34)
headerImage.Image = "rbxassetid://1847902738"
headerImage.Size = UDim2.new(1, 0, 0, 72)
headerImage.ScaleType = Enum.ScaleType.Crop

local headerTitle = Instance.new("TextLabel", headerImage)
headerTitle.Name = "Title"
headerTitle.BackgroundTransparency = 1
headerTitle.Size = UDim2.new(1, 0, 0, 40)
headerTitle.Position = UDim2.fromOffset(0, 4)
headerTitle.Font = Enum.Font.GothamBold
headerTitle.Text = "CATOWARE"
headerTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
headerTitle.TextSize = 22
local titleStroke = Instance.new("UIStroke", headerTitle)
titleStroke.Color = Color3.fromRGB(0, 0, 0)
titleStroke.Thickness = 2

local creatorLabel = Instance.new("TextLabel", headerImage)
creatorLabel.Name = "Creator"
creatorLabel.BackgroundTransparency = 1
creatorLabel.Size = UDim2.new(0.6, 0, 0, 18)
creatorLabel.Position = UDim2.fromOffset(10, 46)
creatorLabel.Font = Enum.Font.Gotham
creatorLabel.RichText = true
creatorLabel.Text = [[by <font color="rgb(101,111,207)"><b>Project Xeal</b></font>]]
creatorLabel.TextColor3 = Color3.fromRGB(200, 205, 225)
creatorLabel.TextSize = 12
creatorLabel.TextXAlignment = Enum.TextXAlignment.Left

-- Category Bar
local subBar = Instance.new("Frame", rootFrame)
subBar.Name = "SubBar"
subBar.BorderSizePixel = 0
subBar.BackgroundColor3 = Color3.fromRGB(20, 23, 34)
subBar.Size = UDim2.new(1, 0, 0, 26)
subBar.Position = UDim2.fromOffset(0, 72)

local subTitle = Instance.new("TextLabel", subBar)
subTitle.Name = "CategoryTitle"
subTitle.BackgroundTransparency = 1
subTitle.Size = UDim2.new(0.65, 0, 1, 0)
subTitle.Position = UDim2.fromOffset(10, 0)
subTitle.Font = Enum.Font.GothamBold
subTitle.Text = "MAIN MENU"
subTitle.TextColor3 = Color3.fromRGB(130, 145, 245)
subTitle.TextSize = 12
subTitle.TextXAlignment = Enum.TextXAlignment.Left

local pageCounter = Instance.new("TextLabel", subBar)
pageCounter.Name = "PageNumber"
pageCounter.BackgroundTransparency = 1
pageCounter.Size = UDim2.new(0.3, 0, 1, 0)
pageCounter.Position = UDim2.new(0.68, 0, 0, 0)
pageCounter.Font = Enum.Font.GothamBold
pageCounter.RichText = true
pageCounter.Text = [[1/<font color="rgb(101,111,207)">6</font>]]
pageCounter.TextColor3 = Color3.fromRGB(255, 255, 255)
pageCounter.TextSize = 12
pageCounter.TextXAlignment = Enum.TextXAlignment.Right

-- Features List Container
local featuresFrame = Instance.new("Frame", rootFrame)
featuresFrame.Name = "FeaturesFrame"
featuresFrame.BackgroundTransparency = 1
featuresFrame.BorderSizePixel = 0
featuresFrame.Size = UDim2.new(1, -8, 0, 255)
featuresFrame.Position = UDim2.fromOffset(4, 102)

local listLayout = Instance.new("UIListLayout", featuresFrame)
listLayout.Padding = UDim.new(0, 3)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- Footer Touch Controls
local arrowFrame = Instance.new("Frame", rootFrame)
arrowFrame.Name = "ArrowFrame"
arrowFrame.BorderSizePixel = 0
arrowFrame.BackgroundColor3 = Color3.fromRGB(16, 18, 28)
arrowFrame.Size = UDim2.new(1, 0, 0, 52)
arrowFrame.Position = UDim2.new(0, 0, 1, -52)

local footerLayout = Instance.new("UIListLayout", arrowFrame)
footerLayout.FillDirection = Enum.FillDirection.Horizontal
footerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
footerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
footerLayout.Padding = UDim.new(0, 5)

-- Floating Mobile Reopen Button (Drag & Tap friendly)
local reopenBtn = Instance.new("TextButton", screenGui)
reopenBtn.Name = "ReopenButton"
reopenBtn.Size = UDim2.fromOffset(48, 48)
reopenBtn.Position = UDim2.new(0, 12, 0.45, 0)
reopenBtn.BackgroundColor3 = Color3.fromRGB(18, 20, 32)
reopenBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
reopenBtn.Font = Enum.Font.GothamBold
reopenBtn.TextSize = 18
reopenBtn.Text = "≡"
reopenBtn.Visible = false

local reopenCorner = Instance.new("UICorner", reopenBtn)
reopenCorner.CornerRadius = UDim.new(1, 0)
local reopenStroke = Instance.new("UIStroke", reopenBtn)
reopenStroke.Color = Color3.fromRGB(101, 111, 207)
reopenStroke.Thickness = 2

-- ========================================================================
-- MENU DEFINITIONS (CLEAN / LESS BLATANT)
-- ========================================================================
local submenus = {}
local currentSubmenuKey = "root"
local selectedIndex = 1
local isMenuOpen = true

local function createSubmenu(key, title)
    submenus[key] = { title = title, items = {} }
end

local function addItem(submenuKey, itemData)
    table.insert(submenus[submenuKey].items, itemData)
end

-- 1. ROOT
createSubmenu("root", "MAIN MENU")
addItem("root", { type = "submenu", title = "Visuals & BigHead", target = "visuals" })
addItem("root", { type = "submenu", title = "Combat & Parry", target = "combat" })
addItem("root", { type = "submenu", title = "Movement & Stamina", target = "movement" })
addItem("root", { type = "submenu", title = "Taunt & ViralFists", target = "taunt" })
addItem("root", { type = "submenu", title = "Menu Settings", target = "settings" })
addItem("root", { type = "button", title = "Close / Hide Menu", action = function() setMenuVisible(false) end })

-- 2. VISUALS & BIG HEAD
createSubmenu("visuals", "VISUALS & BIG HEAD")
addItem("visuals", { type = "toggle", title = "Enable Visuals", key = "visuals_enabled", callback = refreshAllVisuals })
addItem("visuals", { type = "toggle", title = "Subtle Highlights", key = "visual_highlights", callback = refreshAllVisuals })
addItem("visuals", { type = "toggle", title = "Name + Health Billboard", key = "visual_names", callback = refreshAllVisuals })
addItem("visuals", { type = "toggle", title = "Big Head (5x5 Hitbox)", key = "big_head", callback = refreshAllVisuals })
addItem("visuals", { type = "slider", title = "Big Head Size", key = "big_head_size", min = 2, max = 10, step = 1, callback = refreshAllVisuals })
addItem("visuals", { type = "toggle", title = "FullBright", key = "fullbright" })
addItem("visuals", { type = "toggle", title = "No Fog", key = "nofog" })
addItem("visuals", { type = "toggle", title = "No Radiation Effect", key = "hazard_immune" })
addItem("visuals", { type = "back", title = "« Back to Main" })

-- 3. COMBAT & WEAPONS
createSubmenu("combat", "COMBAT & PARRY")
addItem("combat", { type = "toggle", title = "Fast Reload", key = "fast_reload", callback = function() applyFastReload() end })
addItem("combat", { type = "slider", title = "Felsi Reload Speed", key = "felsi_reload", min = 1, max = 5, step = 0.5, callback = function() applyFastReload() end })
addItem("combat", { type = "slider", title = "Squad Reload Speed", key = "squad_reload", min = 1, max = 5, step = 0.5, callback = function() applyFastReload() end })
addItem("combat", { type = "slider", title = "Adminstal Speed", key = "adminstal_speed", min = 1, max = 5, step = 0.5, callback = function() applyFastReload() end })
addItem("combat", { type = "toggle", title = "Auto Parry (ViralFists)", key = "auto_parry" })
addItem("combat", { type = "slider", title = "Parry Range", key = "parry_range", min = 6, max = 25, step = 1 })
addItem("combat", { type = "toggle", title = "Auto Punch", key = "auto_punch" })
addItem("combat", { type = "slider", title = "Punch Range", key = "punch_range", min = 5, max = 20, step = 1 })
addItem("combat", { type = "button", title = "Remove Shields", action = function()
    local cnt = 0
    for _, v in ipairs(workspace:GetDescendants()) do
        if v.Name == "Shield" and v:IsA("BasePart") then v:Destroy(); cnt = cnt + 1 end
    end
    showNotification("Shields removed: " .. tostring(cnt))
end })
addItem("combat", { type = "back", title = "« Back to Main" })

-- 4. MOVEMENT & STAMINA
createSubmenu("movement", "MOVEMENT & STAMINA")
addItem("movement", { type = "toggle", title = "Infinite Stamina", key = "inf_stamina" })
addItem("movement", { type = "toggle", title = "Sprint Speed Mult", key = "speed_mult_toggle" })
addItem("movement", { type = "slider", title = "Speed Multiplier", key = "speed_mult", min = 1.0, max = 2.0, step = 0.05 })
addItem("movement", { type = "back", title = "« Back to Main" })

-- 5. TAUNT & VIRAL FISTS
createSubmenu("taunt", "TAUNT & VIRAL FISTS")
addItem("taunt", { type = "toggle", title = "Spam Taunt (RenderStepped)", key = "spam_taunt", callback = updateTaunt })
addItem("taunt", { type = "toggle", title = "HealthChanged Taunt", key = "health_taunt" })
addItem("taunt", { type = "button", title = "Taunt Once", action = fireSingleTaunt })
addItem("taunt", { type = "button", title = "Equip ViralFists", action = function()
    local t = equipViralFists(true)
    if t then showNotification("ViralFists equipped!") else showNotification("ViralFists not found") end
end })
addItem("taunt", { type = "toggle", title = "Auto Equip ViralFists", key = "auto_equip_viral" })
addItem("taunt", { type = "button", title = "ViralFists Skill [F]", action = function() fireViralKey("F"); showNotification("Fired [F]") end })
addItem("taunt", { type = "button", title = "ViralFists Skill [G]", action = function() fireViralKey("G"); showNotification("Fired [G]") end })
addItem("taunt", { type = "toggle", title = "Animation Speed Hack", key = "anim_speed_toggle" })
addItem("taunt", { type = "slider", title = "Anim Speed Value", key = "anim_speed", min = 1, max = 500, step = 5 })
addItem("taunt", { type = "back", title = "« Back to Main" })

-- 6. SETTINGS
createSubmenu("settings", "MENU SETTINGS")
addItem("settings", { type = "toggle", title = "Floating Open Button", key = "floating_btn", callback = function(v)
    reopenBtn.Visible = v and not isMenuOpen
end })
addItem("settings", { type = "button", title = "Hide Menu [RightShift]", action = function() setMenuVisible(false) end })
addItem("settings", { type = "back", title = "« Back to Main" })

-- ========================================================================
-- RENDER ENGINE
-- ========================================================================
local rowFrames = {}
local MAX_VISIBLE_ROWS = 7
local scrollOffset = 0

local function getActiveSubmenu()
    return submenus[currentSubmenuKey] or submenus["root"]
end

local function buildItemRow(index)
    local row = Instance.new("TextButton", featuresFrame)
    row.Name = "Row_" .. tostring(index)
    row.Size = UDim2.new(1, 0, 0, 32)
    row.BorderSizePixel = 0
    row.BackgroundColor3 = Color3.fromRGB(18, 20, 30)
    row.BackgroundTransparency = 0.35
    row.AutoButtonColor = false
    row.Text = ""

    local corner = Instance.new("UICorner", row)
    corner.CornerRadius = UDim.new(0, 6)

    local accentBar = Instance.new("Frame", row)
    accentBar.Name = "Accent"
    accentBar.BorderSizePixel = 0
    accentBar.BackgroundColor3 = Color3.fromRGB(101, 111, 207)
    accentBar.Size = UDim2.new(0, 4, 1, 0)
    accentBar.Visible = false

    local titleLbl = Instance.new("TextLabel", row)
    titleLbl.Name = "ItemTitle"
    titleLbl.BackgroundTransparency = 1
    titleLbl.Size = UDim2.new(0.65, -10, 1, 0)
    titleLbl.Position = UDim2.fromOffset(12, 0)
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextColor3 = Color3.fromRGB(240, 240, 245)
    titleLbl.TextSize = 13
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left

    local valLbl = Instance.new("TextLabel", row)
    valLbl.Name = "ItemValue"
    valLbl.BackgroundTransparency = 1
    valLbl.Size = UDim2.new(0.35, -10, 1, 0)
    valLbl.Position = UDim2.new(0.65, 0, 0, 0)
    valLbl.Font = Enum.Font.GothamBold
    valLbl.RichText = true
    valLbl.TextColor3 = Color3.fromRGB(200, 205, 230)
    valLbl.TextSize = 12
    valLbl.TextXAlignment = Enum.TextXAlignment.Right

    return row
end

for i = 1, MAX_VISIBLE_ROWS do
    rowFrames[i] = buildItemRow(i)
end

local function renderMenu()
    local submenu = getActiveSubmenu()
    local totalItems = #submenu.items
    if totalItems == 0 then return end

    if selectedIndex > totalItems then selectedIndex = totalItems end
    if selectedIndex < 1 then selectedIndex = 1 end

    if selectedIndex > scrollOffset + MAX_VISIBLE_ROWS then
        scrollOffset = selectedIndex - MAX_VISIBLE_ROWS
    elseif selectedIndex <= scrollOffset then
        scrollOffset = selectedIndex - 1
    end
    if scrollOffset < 0 then scrollOffset = 0 end

    subTitle.Text = submenu.title
    pageCounter.Text = string.format("%d/<font color=\"rgb(101,111,207)\">%d</font>", selectedIndex, totalItems)

    for i = 1, MAX_VISIBLE_ROWS do
        local row = rowFrames[i]
        local itemIndex = scrollOffset + i
        local item = submenu.items[itemIndex]

        if item then
            row.Visible = true
            local isSelected = (itemIndex == selectedIndex)
            local accent = row:FindFirstChild("Accent")
            local titleLbl = row:FindFirstChild("ItemTitle")
            local valLbl = row:FindFirstChild("ItemValue")

            titleLbl.Text = item.title

            if isSelected then
                row.BackgroundColor3 = Color3.fromRGB(245, 246, 255)
                row.BackgroundTransparency = 0
                titleLbl.TextColor3 = Color3.fromRGB(15, 18, 25)
                if accent then accent.Visible = true end
            else
                row.BackgroundColor3 = Color3.fromRGB(18, 20, 30)
                row.BackgroundTransparency = 0.35
                titleLbl.TextColor3 = Color3.fromRGB(235, 235, 245)
                if accent then accent.Visible = false end
            end

            if item.type == "submenu" then
                valLbl.Text = isSelected and "<font color=\"rgb(80,90,190)\"><b>»</b></font>" or "<font color=\"rgb(150,155,180)\">»</font>"
            elseif item.type == "toggle" then
                local state = Toggles[item.key] == true
                if state then
                    valLbl.Text = isSelected and "<font color=\"rgb(20,160,70)\"><b>[ON]</b></font>" or "<font color=\"rgb(70,230,120)\"><b>[ON]</b></font>"
                else
                    valLbl.Text = isSelected and "<font color=\"rgb(180,40,40)\"><b>[OFF]</b></font>" or "<font color=\"rgb(240,70,80)\"><b>[OFF]</b></font>"
                end
            elseif item.type == "slider" then
                local val = Options[item.key] or item.min
                valLbl.Text = isSelected
                    and string.format("<font color=\"rgb(50,60,150)\">◄</font> <b>%s</b> <font color=\"rgb(50,60,150)\">►</font>", tostring(val))
                    or string.format("<font color=\"rgb(130,140,210)\">◄</font> %s <font color=\"rgb(130,140,210)\">►</font>", tostring(val))
            elseif item.type == "button" then
                valLbl.Text = isSelected and "<font color=\"rgb(50,60,150)\"><b>[RUN]</b></font>" or "<font color=\"rgb(130,140,210)\">[RUN]</font>"
            elseif item.type == "back" then
                valLbl.Text = isSelected and "<font color=\"rgb(50,60,150)\"><b>↩</b></font>" or "<font color=\"rgb(130,140,210)\">↩</font>"
            else
                valLbl.Text = ""
            end
        else
            row.Visible = false
        end
    end
end

-- ========================================================================
-- NAVIGATION HANDLERS
-- ========================================================================
local function navigateUp()
    local submenu = getActiveSubmenu()
    local count = #submenu.items
    if count == 0 then return end
    selectedIndex = selectedIndex - 1
    if selectedIndex < 1 then selectedIndex = count end
    renderMenu()
end

local function navigateDown()
    local submenu = getActiveSubmenu()
    local count = #submenu.items
    if count == 0 then return end
    selectedIndex = selectedIndex + 1
    if selectedIndex > count then selectedIndex = 1 end
    renderMenu()
end

local function selectCurrentItem()
    local submenu = getActiveSubmenu()
    local item = submenu.items[selectedIndex]
    if not item then return end

    if item.type == "submenu" then
        currentSubmenuKey = item.target
        selectedIndex = 1
        scrollOffset = 0
        renderMenu()
    elseif item.type == "back" then
        currentSubmenuKey = "root"
        selectedIndex = 1
        scrollOffset = 0
        renderMenu()
    elseif item.type == "toggle" then
        Toggles[item.key] = not Toggles[item.key]
        if item.callback then pcall(item.callback, Toggles[item.key]) end
        renderMenu()
    elseif item.type == "button" then
        if item.action then pcall(item.action) end
        renderMenu()
    elseif item.type == "slider" then
        local cur = Options[item.key] or item.min
        local nextVal = cur + item.step
        if nextVal > item.max then nextVal = item.min end
        Options[item.key] = math.floor(nextVal * 100 + 0.5) / 100
        if item.callback then pcall(item.callback, Options[item.key]) end
        renderMenu()
    end
end

local function navigateLeft()
    local submenu = getActiveSubmenu()
    local item = submenu.items[selectedIndex]
    if not item then return end

    if item.type == "slider" then
        local cur = Options[item.key] or item.min
        local nextVal = cur - item.step
        if nextVal < item.min then nextVal = item.min end
        Options[item.key] = math.floor(nextVal * 100 + 0.5) / 100
        if item.callback then pcall(item.callback, Options[item.key]) end
        renderMenu()
    elseif item.type == "toggle" then
        Toggles[item.key] = false
        if item.callback then pcall(item.callback, false) end
        renderMenu()
    end
end

local function navigateRight()
    local submenu = getActiveSubmenu()
    local item = submenu.items[selectedIndex]
    if not item then return end

    if item.type == "slider" then
        local cur = Options[item.key] or item.min
        local nextVal = cur + item.step
        if nextVal > item.max then nextVal = item.max end
        Options[item.key] = math.floor(nextVal * 100 + 0.5) / 100
        if item.callback then pcall(item.callback, Options[item.key]) end
        renderMenu()
    elseif item.type == "toggle" then
        Toggles[item.key] = true
        if item.callback then pcall(item.callback, true) end
        renderMenu()
    elseif item.type == "submenu" or item.type == "button" or item.type == "back" then
        selectCurrentItem()
    end
end

local function navigateBack()
    if currentSubmenuKey ~= "root" then
        currentSubmenuKey = "root"
        selectedIndex = 1
        scrollOffset = 0
        renderMenu()
    else
        setMenuVisible(false)
    end
end

-- ========================================================================
-- ROW TOUCH & TOUCH NAVIGATION BAR
-- ========================================================================
for i = 1, MAX_VISIBLE_ROWS do
    local row = rowFrames[i]
    row.Activated:Connect(function()
        local itemIndex = scrollOffset + i
        if selectedIndex == itemIndex then
            selectCurrentItem()
        else
            selectedIndex = itemIndex
            renderMenu()
        end
    end)
end

local function createFooterButton(text, onClick, width)
    local btn = Instance.new("TextButton", arrowFrame)
    btn.Size = UDim2.fromOffset(width or 38, 36)
    btn.BackgroundColor3 = Color3.fromRGB(24, 28, 42)
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.GothamBold
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 14
    local corner = Instance.new("UICorner", btn)
    corner.CornerRadius = UDim.new(0, 6)
    btn.Activated:Connect(onClick)
    return btn
end

createFooterButton("▲", navigateUp)
createFooterButton("▼", navigateDown)
createFooterButton("◄", navigateLeft)
createFooterButton("►", navigateRight)
createFooterButton("SELECT", selectCurrentItem, 58)
createFooterButton("BACK", navigateBack, 46)

function setMenuVisible(visible)
    isMenuOpen = visible
    rootFrame.Visible = visible
    if Toggles.floating_btn then
        reopenBtn.Visible = not visible
    else
        reopenBtn.Visible = false
    end
end

reopenBtn.Activated:Connect(function()
    setMenuVisible(true)
end)

-- ========================================================================
-- CAS BINDING (SINKS ARROW KEYS TO PREVENT MOVEMENT)
-- ========================================================================
local ACTION_NAME = "CatowareGTANavControls"
local NAV_PRIORITY = Enum.ContextActionPriority.High.Value + 3000

local function handleCAS(actionName, inputState, inputObject)
    if not isMenuOpen then
        return Enum.ContextActionResult.Pass
    end

    if inputState == Enum.UserInputState.Begin then
        local code = inputObject.KeyCode
        if code == Enum.KeyCode.Up then
            navigateUp()
        elseif code == Enum.KeyCode.Down then
            navigateDown()
        elseif code == Enum.KeyCode.Left then
            navigateLeft()
        elseif code == Enum.KeyCode.Right then
            navigateRight()
        elseif code == Enum.KeyCode.Return or code == Enum.KeyCode.KeypadEnter then
            selectCurrentItem()
        elseif code == Enum.KeyCode.Backspace or code == Enum.KeyCode.Escape then
            navigateBack()
        end
    end

    -- SINK INPUT COMPLETELY SO CHARACTER DOES NOT MOVE
    return Enum.ContextActionResult.Sink
end

ContextActionService:BindActionAtPriority(
    ACTION_NAME,
    handleCAS,
    false,
    NAV_PRIORITY,
    Enum.KeyCode.Up,
    Enum.KeyCode.Down,
    Enum.KeyCode.Left,
    Enum.KeyCode.Right,
    Enum.KeyCode.Return,
    Enum.KeyCode.KeypadEnter,
    Enum.KeyCode.Backspace,
    Enum.KeyCode.Escape
)

-- Global Hotkey to Toggle Menu (RightShift / Insert)
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe and input.KeyCode ~= Enum.KeyCode.RightShift and input.KeyCode ~= Enum.KeyCode.Insert then return end
    if input.KeyCode == Enum.KeyCode.RightShift or input.KeyCode == Enum.KeyCode.Insert then
        setMenuVisible(not isMenuOpen)
    end
end)

-- Initial Render
renderMenu()
showNotification("Catoware GTA Menu Loaded! [RightShift]")
