local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Plr = game:GetService("Players")
local LP = Plr.LocalPlayer

local Part = Instance.new("Part", workspace)
Part.Material = Enum.Material.ForceField
Part.Anchored = true
Part.CanCollide = false
Part.CastShadow = false
Part.Shape = Enum.PartType.Ball
Part.Color = Color3.fromRGB(132, 0, 255)
Part.Transparency = 0.5

local BaseGui = Instance.new("ScreenGui", game.CoreGui)
BaseGui.Name = "BaseGui"

local TL = Instance.new("TextLabel", BaseGui)
TL.Name = "TL"
TL.Parent = BaseGui
TL.BackgroundColor3 = Color3.new(1, 1, 1)
TL.BackgroundTransparency = 1
TL.BorderColor3 = Color3.new(0, 0, 0)
TL.Position = UDim2.new(0.95, -300, 0.85, 0)
TL.Size = UDim2.new(0, 300, 0, 50)
TL.FontFace = Font.new("rbxassetid://12187370000", Enum.FontWeight.Bold)
TL.Text = ""
TL.TextColor3 = Color3.new(1, 1, 1)
TL.TextScaled = true
TL.TextSize = 14
TL.TextWrapped = true
TL.Visible = true
TL.RichText = true

local function rainbowColor(hue)
  return Color3.fromHSV(hue, 1, 1)
end

local function updateRainbowText(distance, ballSpeed, spamRadius, minDistance)
  local hue = (tick() * 0.1) % 1
  local color1 = rainbowColor(hue)
  local color2 = rainbowColor((hue + 0.3) % 1)
  local color3 = rainbowColor((hue + 0.6) % 1)
  local color4 = rainbowColor((hue + 0.9) % 1)

  TL.Text = string.format(
  "<font color='#%s'>distance: %s</font>\n"..
  "<font color='#%s'>ballSpeed: %s</font>\n"..
  "<font color='#%s'>spamRadius: %s</font>\n"..
  "<font color='#%s'>minDistance: %s</font>",
  color1:ToHex(), tostring(distance),
  color2:ToHex(), tostring(ballSpeed),
  color3:ToHex(), tostring(spamRadius),
  color4:ToHex(), tostring(minDistance)
  )
end

local last1, last2
local Cam = workspace.CurrentCamera

local function ZJ()
  local Nearest, Min = nil, math.huge
  for A, B in next, workspace.Alive:GetChildren() do
    if B.Name ~= LP.Name and B:FindFirstChild("HumanoidRootPart") then
      local distance = LP:DistanceFromCharacter(B:GetPivot().Position)
      if distance < Min then
        Min = distance
        Nearest = B
      end
    end
  end
  return Min
end

local function Parry()
  task.spawn(function() game:GetService("VirtualInputManager"):SendMouseButtonEvent(0, 0, 0, true, nil, 0) end)
end

local function GetBall()
  for a, b in next, workspace.Balls:GetChildren() do
    if b:IsA("BasePart") and b:GetAttribute("realBall") then
      return b
    end
  end
end

local function IsTarget(a)
  return a:GetAttribute("target") == LP.Name
end

local function IsSpamming(a, b)
  if not type(last1) == "number" then return false end
  if not type(last2) == "number" then return false end
  if last1 - last2 > 0.8 then
    return false
  end
  if a > b then
    return false
  end
  if #workspace.Alive:GetChildren() <= 1 then
    return false
  end
  return true
end

local function addRainbowTitleToLocalPlayer(player, titleText)
    local function addTitleToCharacter(character)
        local head = character:FindFirstChild("Head") or character:WaitForChild("Head")
        local old = head:FindFirstChild("PlayerTitle")
        if old then old:Destroy() end
        local billboardGui = Instance.new("BillboardGui")
        billboardGui.Name = "PlayerTitle"
        billboardGui.Adornee = head
        billboardGui.Size = UDim2.new(4, 0, 1, 0)
        billboardGui.StudsOffset = Vector3.new(0, 2, 0)
        billboardGui.AlwaysOnTop = true
        billboardGui.MaxDistance = 1000
        local textLabel = Instance.new("TextLabel")
        textLabel.Size = UDim2.new(1, 0, 1, 0)
        textLabel.BackgroundTransparency = 1
        textLabel.Text = titleText
        textLabel.TextScaled = true
        textLabel.Font = Enum.Font.GothamBold
        textLabel.TextWrapped = true
        textLabel.Parent = billboardGui
        local stroke = Instance.new("UIStroke")
        stroke.Thickness = 1
        stroke.Color = Color3.new(1, 1, 1)
        stroke.Parent = textLabel
        local gradient = Instance.new("UIGradient")
        gradient.Rotation = 90
        gradient.Parent = textLabel
        local connection
        connection = game:GetService("RunService").RenderStepped:Connect(function()
            local time = tick() * 0.5
            gradient.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromHSV(time % 1, 1, 1)),
                ColorSequenceKeypoint.new(0.2, Color3.fromHSV((time + 0.2) % 1, 1, 1)),
                ColorSequenceKeypoint.new(0.4, Color3.fromHSV((time + 0.4) % 1, 1, 1)),
                ColorSequenceKeypoint.new(0.6, Color3.fromHSV((time + 0.6) % 1, 1, 1)),
                ColorSequenceKeypoint.new(0.8, Color3.fromHSV((time + 0.8) % 1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromHSV(time % 1, 1, 1))
            })
        end)
        billboardGui.AncestryChanged:Connect(function()
            if not billboardGui:IsDescendantOf(game) then
                if connection then connection:Disconnect() end
            end
        end)
        billboardGui.Parent = head
    end
    local character = player.Character or player.CharacterAdded:Wait()
    addTitleToCharacter(character)
    player.CharacterAdded:Connect(addTitleToCharacter)
end
addRainbowTitleToLocalPlayer(LP, "AlienX VIP")
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Syndromehsh/Lua/baff0bc41893a32f8e997d840241ad4b3d26ab4d/AlienX/AlienX%20Wind%203.0%20UI.txt"))()

local Window = WindUI:CreateWindow({
    Title = 'AlienX<font color="#00FF00">2.0</font>/ 战争大亨|XI团队出品必是精品',
    Icon = "rbxassetid://4483362748",
    IconThemed = true,
    Author = "AlienX",
    Folder = "CloudHub",
    Size = UDim2.fromOffset(580, 440),
    Transparent = true,
    Theme = "Dark",
    User = {
        Enabled = true,
        Callback = function() print("clicked") end,
        Anonymous = false
    },
    SideBarWidth = 200,
    ScrollBarEnabled = true,
})

Window:EditOpenButton({
    Title = "打开脚本",
    Icon = "monitor",
    CornerRadius = UDim.new(0,16),
    StrokeThickness = 4,
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromHex("FF0000")),
        ColorSequenceKeypoint.new(0.16, Color3.fromHex("FF7F00")),
        ColorSequenceKeypoint.new(0.33, Color3.fromHex("FFFF00")),
        ColorSequenceKeypoint.new(0.5, Color3.fromHex("00FF00")),
        ColorSequenceKeypoint.new(0.66, Color3.fromHex("0000FF")),
        ColorSequenceKeypoint.new(0.83, Color3.fromHex("4B0082")),
        ColorSequenceKeypoint.new(1, Color3.fromHex("9400D3"))
    }),
    Draggable = true,
})

local LockSection = Window:Section({
    Title = "稳定功能",
    Opened = true,
})

local function AddTab(section, title, icon)
    return section:Tab({Title = title, Icon = icon})
end

local function Btn(tab, title, callback)
    return tab:Button({Title = title, Callback = callback})
end

local function Tg(tab, title, value, callback)
    return tab:Toggle({Title = title, Image = "bird", Value = value, Callback = callback})
end

local function Sld(tab, title, min, max, default, callback)
    return tab:Slider({Title = title, Step = 1, Value = {Min = min, Max = max, Default = default}, Callback = callback})
end

local A = AddTab(LockSection, "传送", "rbxassetid://3944688398")
local B = AddTab(LockSection, "自动", "rbxassetid://4450736564")
local C = AddTab(LockSection, "透视", "rbxassetid://104955103991281")
local D = AddTab(LockSection, "辅助", "rbxassetid://4483362458")
local E = AddTab(LockSection, "自瞄", "rbxassetid://4483345998")

local FunSection = Window:Section({
    Title = "娱乐功能",
    Opened = true,
})

local F = AddTab(FunSection, "攻击", "rbxassetid://4384392464")
local G = AddTab(FunSection, "武器", "rbxassetid://94831304996747")
local H = AddTab(FunSection, "玩家", "rbxassetid://4335480896")
local I = AddTab(FunSection, "子追", "rbxassetid://4483345998")

Window:SelectTab(1)

local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local PlayerList = {}
for _, player in pairs(Players:GetPlayers()) do
    if player ~= LP then
        PlayerList[#PlayerList + 1] = player.Name
    end
end

local Positions = {
    ["Alpha"] = CFrame.new(-1197, 65, -4790),
    ["Bravo"] = CFrame.new(-220, 65, -4919),
    ["Charlie"] = CFrame.new(797, 65, -4740),
    ["Delta"] = CFrame.new(2044, 65, -3984),
    ["Echo"] = CFrame.new(2742, 65, -3031),
    ["Foxtrot"] = CFrame.new(3045, 65, -1788),
    ["Golf"] = CFrame.new(3376, 65, -562),
    ["Hotel"] = CFrame.new(3290, 65, 587),
    ["Juliet"] = CFrame.new(2955, 65, 1804),
    ["Kilo"] = CFrame.new(2569, 65, 2926),
    ["Lima"] = CFrame.new(989, 65, 3419),
    ["Omega"] = CFrame.new(-319, 65, 3932),
    ["Romeo"] = CFrame.new(-1479, 65, 3722),
    ["Sierra"] = CFrame.new(-2528, 65, 2549),
    ["Tango"] = CFrame.new(-3018, 65, 1503),
    ["Victor"] = CFrame.new(-3587, 65, 634),
    ["Yankee"] = CFrame.new(-3957, 65, -287),
    ["Zulu"] = CFrame.new(-4049, 65, -1334)
}

Btn(A, "当前玩家基地: " .. LP.Team.Name, function() end)
A:Dropdown({
    Title = "传送基地", 
    Values = {"Alpha", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot", "Golf", "Hotel", "Juliet", "Kilo", "Lima", "Omega", "Romeo", "Sierra", "Tango", "Victor", "Yankee", "Zulu"}, 
    Value = "Alpha", 
    Callback = function(d) 
        if LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
            LP.Character:FindFirstChild("HumanoidRootPart").CFrame = Positions[d]
        end
    end
})

local function GetAvailableBases()
    local bases = {}
    if not ExcludedBases then
        ExcludedBases = {}
    end
    if not workspace:FindFirstChild("Tycoon") or not workspace.Tycoon:FindFirstChild("Tycoons") then
        warn("Tycoon or Tycoons folder not found")
        return bases
    end
    
    local tycoons = workspace.Tycoon.Tycoons:GetChildren()
    for _, tycoon in ipairs(tycoons) do
        if not table.find(ExcludedBases, tycoon.Name) then
            table.insert(bases, tycoon.Name)
        end
    end
    
    return bases
end

local BasesDropdown = B:Dropdown({
    Title = "基地白名单{排除列表}", 
    Values = GetAvailableBases(), 
    Multi = true, 
    Default = {}, 
    Callback = function(Values) 
        ExcludedBases = Values 
    end
})

Btn(B, "刷新基地列表", function()
    BasesDropdown:Refresh(GetAvailableBases())
end)

Tg(B,"自动箱子",false,function(value)
        getgenv().auto = value
    end
)

Tg(B,"自动升级",false,function(value)
        getgenv().autoTeleport = value
    end
)


B:Divider()


B:Button({
    Title = "自动重生",
    Description = "正在开发中..",
    Locked = true,
})

B:Button({
    Title = "自动空投",
    Description = "正在开发中..",
    Locked = true,
})



getgenv().ESPEnabled = false
getgenv().ShowBox = false
getgenv().ShowHealth = false
getgenv().ShowName = false
getgenv().ShowDistance = false
getgenv().ShowTracer = false
getgenv().TeamCheck = false
getgenv().ShowSkeleton = false
getgenv().ShowRadar = false
getgenv().ShowPlayerCount = false
getgenv().ShowWeapon = false
getgenv().ShowFOV = false
getgenv().OutOfViewArrows = false
getgenv().Chams = false

getgenv().TracerColor = Color3.new(1, 0, 0)
getgenv().SkeletonColor = Color3.new(0.2, 0.8, 1)
getgenv().BoxColor = Color3.new(1, 1, 1)
getgenv().HealthBarColor = Color3.new(0, 1, 0)
getgenv().HealthTextColor = Color3.new(1, 1, 1)
getgenv().NameColor = Color3.new(1, 1, 1)
getgenv().DistanceColor = Color3.new(1, 1, 0)
getgenv().WeaponColor = Color3.new(1, 0.5, 0)
getgenv().ArrowColor = Color3.new(1, 0, 0)
getgenv().FOVColor = Color3.new(1, 1, 1)
getgenv().ChamsColor = Color3.new(1, 0, 0)

getgenv().BoxThickness = 1
getgenv().TracerThickness = 1
getgenv().SkeletonThickness = 2
getgenv().FOVRadius = 100
getgenv().ArrowSize = 15

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local function getGradientColor(time)
    local r = math.sin(time * 2) * 0.5 + 0.5
    local g = math.sin(time * 3) * 0.5 + 0.5
    local b = math.sin(time * 4) * 0.5 + 0.5
    return Color3.new(r, g, b)
end

local playerCountText = Drawing.new("Text")
playerCountText.Visible = false
playerCountText.Color = Color3.new(1, 1, 1)
playerCountText.Size = 20
playerCountText.Font = Drawing.Fonts.Monospace
playerCountText.Outline = true
playerCountText.OutlineColor = Color3.new(0, 0, 0)
playerCountText.Position = Vector2.new(Camera.ViewportSize.X / 2, 10)

local fovCircle = Drawing.new("Circle")
fovCircle.Visible = false
fovCircle.Color = getgenv().FOVColor
fovCircle.Thickness = 1
fovCircle.Filled = false
fovCircle.Radius = getgenv().FOVRadius
fovCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

local function updatePlayerCount()
    local playerCount = #Players:GetPlayers()
    playerCountText.Text = "在线玩家: " .. playerCount
    playerCountText.Visible = getgenv().ESPEnabled and getgenv().ShowPlayerCount

    local time = tick()
    playerCountText.Color = getGradientColor(time)
end

local function updateFOV()
    fovCircle.Visible = getgenv().ShowFOV
    fovCircle.Color = getgenv().FOVColor
    fovCircle.Radius = getgenv().FOVRadius
    fovCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
end

local ESPComponents = {}

local function createESP(player)
    local box = Drawing.new("Square")
    box.Visible = false
    box.Color = getgenv().BoxColor
    box.Thickness = getgenv().BoxThickness
    box.Filled = false

    local healthBar = Drawing.new("Square")
    healthBar.Visible = false
    healthBar.Color = getgenv().HealthBarColor
    healthBar.Thickness = 1
    healthBar.Filled = true

    local healthBarBackground = Drawing.new("Square")
    healthBarBackground.Visible = false
    healthBarBackground.Color = Color3.new(0, 0, 0)
    healthBarBackground.Transparency = 0.5
    healthBarBackground.Thickness = 1
    healthBarBackground.Filled = true

    local healthBarBorder = Drawing.new("Square")
    healthBarBorder.Visible = false
    healthBarBorder.Color = Color3.new(1, 1, 1)
    healthBarBorder.Thickness = 1
    healthBarBorder.Filled = false

    local healthText = Drawing.new("Text")
    healthText.Visible = false
    healthText.Color = getgenv().HealthTextColor
    healthText.Size = 14
    healthText.Font = Drawing.Fonts.Monospace
    healthText.Outline = true
    healthText.OutlineColor = Color3.new(0, 0, 0)

    local nameText = Drawing.new("Text")
    nameText.Visible = false
    nameText.Color = getgenv().NameColor
    nameText.Size = 16
    nameText.Font = Drawing.Fonts.Monospace
    nameText.Outline = true
    nameText.OutlineColor = Color3.new(0, 0, 0)

    local distanceText = Drawing.new("Text")
    distanceText.Visible = false
    distanceText.Color = getgenv().DistanceColor
    distanceText.Size = 14
    distanceText.Font = Drawing.Fonts.Monospace
    distanceText.Outline = true
    distanceText.OutlineColor = Color3.new(0, 0, 0)

    local weaponText = Drawing.new("Text")
    weaponText.Visible = false
    weaponText.Color = getgenv().WeaponColor
    weaponText.Size = 14
    weaponText.Font = Drawing.Fonts.Monospace
    weaponText.Outline = true
    weaponText.OutlineColor = Color3.new(0, 0, 0)

    local tracer = Drawing.new("Line")
    tracer.Visible = false
    tracer.Color = getgenv().TracerColor
    tracer.Thickness = getgenv().TracerThickness

    local arrow = Drawing.new("Triangle")
    arrow.Visible = false
    arrow.Color = getgenv().ArrowColor
    arrow.Filled = true
    arrow.Thickness = 1

    local skeletonLines = {}
    local skeletonPoints = {}

    local function createSkeleton()
        for i = 1, 15 do
            skeletonLines[i] = Drawing.new("Line")
            skeletonLines[i].Visible = false
            skeletonLines[i].Color = getgenv().SkeletonColor
            skeletonLines[i].Thickness = getgenv().SkeletonThickness
        end

        skeletonPoints["Head"] = Drawing.new("Circle")
        skeletonPoints["Head"].Visible = false
        skeletonPoints["Head"].Color = Color3.new(1, 0.5, 0)
        skeletonPoints["Head"].Thickness = 2
        skeletonPoints["Head"].Filled = true
        skeletonPoints["Head"].Radius = 4
    end

    createSkeleton()

    local lastHealth = 100
    local healthChangeTime = 0
    local smoothHealth = 100

    ESPComponents[player] = {
        box = box,
        healthBar = healthBar,
        healthBarBackground = healthBarBackground,
        healthBarBorder = healthBarBorder,
        healthText = healthText,
        nameText = nameText,
        distanceText = distanceText,
        weaponText = weaponText,
        tracer = tracer,
        arrow = arrow,
        skeletonLines = skeletonLines,
        skeletonPoints = skeletonPoints
    }

    RunService.RenderStepped:Connect(function()
        if not getgenv().ESPEnabled or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") or not player.Character:FindFirstChild("Humanoid") or player == LocalPlayer then
            box.Visible = false
            healthBar.Visible = false
            healthBarBackground.Visible = false
            healthBarBorder.Visible = false
            healthText.Visible = false
            nameText.Visible = false
            distanceText.Visible = false
            weaponText.Visible = false
            tracer.Visible = false
            arrow.Visible = false
            for _, line in pairs(skeletonLines) do
                line.Visible = false
            end
            for _, point in pairs(skeletonPoints) do
                point.Visible = false
            end
            return
        end

        if getgenv().TeamCheck and player.Team == LocalPlayer.Team then
            box.Visible = false
            healthBar.Visible = false
            healthBarBackground.Visible = false
            healthBarBorder.Visible = false
            healthText.Visible = false
            nameText.Visible = false
            distanceText.Visible = false
            weaponText.Visible = false
            tracer.Visible = false
            arrow.Visible = false
            for _, line in pairs(skeletonLines) do
                line.Visible = false
            end
            for _, point in pairs(skeletonPoints) do
                point.Visible = false
            end
            return
        end

        local character = player.Character
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        local humanoid = character:FindFirstChild("Humanoid")

        if rootPart and humanoid and humanoid.Health > 0 then
            local rootPos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
            local headPos, _ = Camera:WorldToViewportPoint(rootPart.Position + Vector3.new(0, 3, 0))
            local legPos, _ = Camera:WorldToViewportPoint(rootPart.Position - Vector3.new(0, 3, 0))

            local weaponName = "无武器"
            for _, tool in ipairs(character:GetChildren()) do
                if tool:IsA("Tool") then
                    weaponName = tool.Name
                    break
                end
            end

            if getgenv().ShowBox and onScreen then
                box.Size = Vector2.new(1000 / rootPos.Z, headPos.Y - legPos.Y)
                box.Position = Vector2.new(rootPos.X - box.Size.X / 2, rootPos.Y - box.Size.Y / 2)
                box.Visible = true
                box.Color = getgenv().BoxColor
                box.Thickness = getgenv().BoxThickness
            else
                box.Visible = false
            end

            if getgenv().ShowHealth and onScreen then
                local healthPercentage = humanoid.Health / humanoid.MaxHealth
                local barWidth = 50
                local barHeight = 5
                local barX = headPos.X - barWidth / 2
                local barY = headPos.Y - 20

                healthBarBackground.Size = Vector2.new(barWidth, barHeight)
                healthBarBackground.Position = Vector2.new(barX, barY)
                healthBarBackground.Visible = true

                healthBarBorder.Size = Vector2.new(barWidth, barHeight)
                healthBarBorder.Position = Vector2.new(barX, barY)
                healthBarBorder.Visible = true

                smoothHealth = smoothHealth + (humanoid.Health - smoothHealth) * 0.1
                local smoothHealthPercentage = smoothHealth / humanoid.MaxHealth

                healthBar.Size = Vector2.new(barWidth * smoothHealthPercentage, barHeight)
                healthBar.Position = Vector2.new(barX, barY)

                if smoothHealthPercentage >= 0.8 then
                    healthBar.Color = Color3.new(0, 1, 0)
                elseif smoothHealthPercentage >= 0.5 then
                    healthBar.Color = Color3.new(1, 1, 0)
                elseif smoothHealthPercentage >= 0.2 then
                    healthBar.Color = Color3.new(1, 0.5, 0)
                else
                    healthBar.Color = Color3.new(1, 0, 0)
                end

                healthBar.Visible = true

                if humanoid.Health ~= lastHealth then
                    healthChangeTime = tick()
                    lastHealth = humanoid.Health
                end

                if tick() - healthChangeTime < 0.5 then
                    healthBar.Color = Color3.new(1, 0, 0)
                end

                healthText.Position = Vector2.new(barX + barWidth + 5, barY - 5)
                healthText.Text = math.floor(humanoid.Health) .. "/" .. math.floor(humanoid.MaxHealth)
                healthText.Visible = true
            else
                healthBar.Visible = false
                healthBarBackground.Visible = false
                healthBarBorder.Visible = false
                healthText.Visible = false
            end

            if getgenv().ShowName and onScreen then
                nameText.Position = Vector2.new(headPos.X, headPos.Y - 35)
                nameText.Text = player.Name
                nameText.Visible = true

                if getgenv().ShowDistance then
                    local distance = (LocalPlayer.Character.HumanoidRootPart.Position - rootPart.Position).Magnitude
                    distanceText.Position = Vector2.new(headPos.X, headPos.Y + 10)
                    distanceText.Text = math.floor(distance) .. "m"
                    distanceText.Visible = true
                else
                    distanceText.Visible = false
                end

                if getgenv().ShowWeapon then
                    weaponText.Position = Vector2.new(headPos.X, headPos.Y - 50)
                    weaponText.Text = weaponName
                    weaponText.Visible = true
                else
                    weaponText.Visible = false
                end
            else
                nameText.Visible = false
                distanceText.Visible = false
                weaponText.Visible = false
            end

            if getgenv().ShowTracer then
                local head = character:FindFirstChild("Head")
                if head then
                    local headPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                    if onScreen then
                        tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                        tracer.To = Vector2.new(headPos.X, headPos.Y)
                        tracer.Visible = true
                        tracer.Color = getgenv().TracerColor
                        tracer.Thickness = getgenv().TracerThickness
                        
                        local distance = (LocalPlayer.Character.HumanoidRootPart.Position - rootPart.Position).Magnitude
                        if distance < 20 then
                            tracer.Color = Color3.new(0, 1, 0)
                        elseif distance < 50 then
                            tracer.Color = Color3.new(1, 1, 0) 
                        else
                            tracer.Color = getgenv().TracerColor 
                        end
                    else
                        tracer.Visible = false
                    end
                else
                    tracer.Visible = false
                end
            else
                tracer.Visible = false
            end

            if getgenv().OutOfViewArrows and not onScreen then
                local direction = (rootPart.Position - Camera.CFrame.Position).Unit
                local dotProduct = Camera.CFrame.RightVector:Dot(direction)
                local crossProduct = Camera.CFrame.RightVector:Cross(direction)
                
                local screenPosition = Vector2.new(
                    Camera.ViewportSize.X / 2 + dotProduct * Camera.ViewportSize.X / 3,
                    Camera.ViewportSize.Y / 2 - crossProduct.Y * Camera.ViewportSize.Y / 3
                )
                
                screenPosition = Vector2.new(
                    math.clamp(screenPosition.X, getgenv().ArrowSize, Camera.ViewportSize.X - getgenv().ArrowSize),
                    math.clamp(screenPosition.Y, getgenv().ArrowSize, Camera.ViewportSize.Y - getgenv().ArrowSize)
                )
                
                local angle = math.atan2(screenPosition.Y - Camera.ViewportSize.Y / 2, screenPosition.X - Camera.ViewportSize.X / 2)
                
                arrow.PointA = screenPosition
                arrow.PointB = Vector2.new(
                    screenPosition.X - getgenv().ArrowSize * math.cos(angle - 0.5),
                    screenPosition.Y - getgenv().ArrowSize * math.sin(angle - 0.5)
                )
                arrow.PointC = Vector2.new(
                    screenPosition.X - getgenv().ArrowSize * math.cos(angle + 0.5),
                    screenPosition.Y - getgenv().ArrowSize * math.sin(angle + 0.5)
                )
                
                arrow.Color = getgenv().ArrowColor
                arrow.Visible = true
            else
                arrow.Visible = false
            end

            if getgenv().ShowSkeleton and onScreen then
                local head = character:FindFirstChild("Head")
                local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
                local leftArm = character:FindFirstChild("Left Arm") or character:FindFirstChild("LeftUpperArm")
                local rightArm = character:FindFirstChild("Right Arm") or character:FindFirstChild("RightUpperArm")
                local leftLeg = character:FindFirstChild("Left Leg") or character:FindFirstChild("LeftUpperLeg")
                local rightLeg = character:FindFirstChild("Right Leg") or character:FindFirstChild("RightUpperLeg")
                
                if head and torso and leftArm and rightArm and leftLeg and rightLeg then
                    local headPos = Camera:WorldToViewportPoint(head.Position)
                    local torsoPos = Camera:WorldToViewportPoint(torso.Position)
                    local leftArmPos = Camera:WorldToViewportPoint(leftArm.Position)
                    local rightArmPos = Camera:WorldToViewportPoint(rightArm.Position)
                    local leftLegPos = Camera:WorldToViewportPoint(leftLeg.Position)
                    local rightLegPos = Camera:WorldToViewportPoint(rightLeg.Position)

                    skeletonPoints["Head"].Position = Vector2.new(headPos.X, headPos.Y)
                    skeletonPoints["Head"].Visible = true

                    skeletonLines[1].From = Vector2.new(headPos.X, headPos.Y)
                    skeletonLines[1].To = Vector2.new(torsoPos.X, torsoPos.Y) 
                    skeletonLines[1].Visible = true

                    skeletonLines[2].From = Vector2.new(torsoPos.X, torsoPos.Y)
                    skeletonLines[2].To = Vector2.new(leftArmPos.X, leftArmPos.Y)
                    skeletonLines[2].Visible = true

                    skeletonLines[3].From = Vector2.new(torsoPos.X, torsoPos.Y)
                    skeletonLines[3].To = Vector2.new(rightArmPos.X, rightArmPos.Y)
                    skeletonLines[3].Visible = true

                    skeletonLines[4].From = Vector2.new(torsoPos.X, torsoPos.Y)
                    skeletonLines[4].To = Vector2.new(leftLegPos.X, leftLegPos.Y)
                    skeletonLines[4].Visible = true

                    skeletonLines[5].From = Vector2.new(torsoPos.X, torsoPos.Y)
                    skeletonLines[5].To = Vector2.new(rightLegPos.X, rightLegPos.Y)
                    skeletonLines[5].Visible = true

                    if character:FindFirstChild("LeftLowerArm") then
                        local leftLowerArmPos = Camera:WorldToViewportPoint(character.LeftLowerArm.Position)
                        skeletonLines[6].From = Vector2.new(leftArmPos.X, leftArmPos.Y)
                        skeletonLines[6].To = Vector2.new(leftLowerArmPos.X, leftLowerArmPos.Y)
                        skeletonLines[6].Visible = true
                    end

                    if character:FindFirstChild("RightLowerArm") then
                        local rightLowerArmPos = Camera:WorldToViewportPoint(character.RightLowerArm.Position)
                        skeletonLines[7].From = Vector2.new(rightArmPos.X, rightArmPos.Y)
                        skeletonLines[7].To = Vector2.new(rightLowerArmPos.X, rightLowerArmPos.Y)
                        skeletonLines[7].Visible = true
                    end

                    if character:FindFirstChild("LeftLowerLeg") then
                        local leftLowerLegPos = Camera:WorldToViewportPoint(character.LeftLowerLeg.Position)
                        skeletonLines[8].From = Vector2.new(leftLegPos.X, leftLegPos.Y)
                        skeletonLines[8].To = Vector2.new(leftLowerLegPos.X, leftLowerLegPos.Y)
                        skeletonLines[8].Visible = true
                    end

                    if character:FindFirstChild("RightLowerLeg") then
                        local rightLowerLegPos = Camera:WorldToViewportPoint(character.RightLowerLeg.Position)
                        skeletonLines[9].From = Vector2.new(rightLegPos.X, rightLegPos.Y)
                        skeletonLines[9].To = Vector2.new(rightLowerLegPos.X, rightLowerLegPos.Y)
                        skeletonLines[9].Visible = true
                    end
                else
                    for _, line in pairs(skeletonLines) do
                        line.Visible = false
                    end
                    for _, point in pairs(skeletonPoints) do
                        point.Visible = false
                    end
                end
            else
                for _, line in pairs(skeletonLines) do
                    line.Visible = false
                end
                for _, point in pairs(skeletonPoints) do
                    point.Visible = false
                end
            end
        else
            box.Visible = false
            healthBar.Visible = false
            healthBarBackground.Visible = false
            healthBarBorder.Visible = false
            healthText.Visible = false
            nameText.Visible = false
            distanceText.Visible = false
            weaponText.Visible = false
            tracer.Visible = false
            arrow.Visible = false
            for _, line in pairs(skeletonLines) do
                line.Visible = false
            end
            for _, point in pairs(skeletonPoints) do
                point.Visible = false
            end
        end
    end)
end

local radar = Drawing.new("Circle")
radar.Visible = false
radar.Color = Color3.new(1, 1, 1)
radar.Thickness = 2
radar.Filled = false
radar.Radius = 100
radar.Position = Vector2.new(Camera.ViewportSize.X - 120, 120)

local radarCenter = Drawing.new("Circle")
radarCenter.Visible = false
radarCenter.Color = Color3.new(1, 1, 1)
radarCenter.Thickness = 2
radarCenter.Filled = true
radarCenter.Radius = 3
radarCenter.Position = radar.Position

local radarDirection = Drawing.new("Line")
radarDirection.Visible = false
radarDirection.Color = Color3.new(1, 1, 1)
radarDirection.Thickness = 2

local radarGridLines = {}
for i = 1, 4 do
    radarGridLines[i] = Drawing.new("Line")
    radarGridLines[i].Visible = false
    radarGridLines[i].Color = Color3.new(0.5, 0.5, 0.5)
    radarGridLines[i].Thickness = 1
end

local radarRangeText = Drawing.new("Text")
radarRangeText.Visible = false
radarRangeText.Color = Color3.new(1, 1, 1)
radarRangeText.Size = 14
radarRangeText.Font = Drawing.Fonts.Monospace
radarRangeText.Outline = true
radarRangeText.OutlineColor = Color3.new(0, 0, 0)
radarRangeText.Text = "100m"

local radarPlayers = {}

local function updateRadar()
    if not getgenv().ShowRadar then
        radar.Visible = false
        radarCenter.Visible = false
        radarDirection.Visible = false
        radarRangeText.Visible = false
        
        for _, line in pairs(radarGridLines) do
            line.Visible = false
        end
        
        for _, player in pairs(radarPlayers) do
            if player.dot then player.dot.Visible = false end
            if player.direction then player.direction.Visible = false end
            if player.name then player.name.Visible = false end
        end
        return
    end

    radar.Visible = true
    radarCenter.Visible = true
    radarDirection.Visible = true
    radarRangeText.Visible = true
    
    radarRangeText.Position = Vector2.new(radar.Position.X, radar.Position.Y + radar.Radius + 5)
    
    for i = 1, 4 do
        local angle = (i-1) * math.pi / 2
        radarGridLines[i].From = radar.Position
        radarGridLines[i].To = Vector2.new(
            radar.Position.X + math.cos(angle) * radar.Radius,
            radar.Position.Y + math.sin(angle) * radar.Radius
        )
        radarGridLines[i].Visible = true
    end
    
    radarDirection.From = radar.Position
    radarDirection.To = Vector2.new(radar.Position.X, radar.Position.Y - radar.Radius)

    for _, player in pairs(Players:GetPlayers()) do
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player ~= LocalPlayer then
            local rootPart = player.Character.HumanoidRootPart
            local relativePosition = rootPart.Position - LocalPlayer.Character.HumanoidRootPart.Position
            
            local radarX = radar.Position.X + (relativePosition.X / 10)
            local radarY = radar.Position.Y + (relativePosition.Z / 10)
            
            local distanceFromCenter = math.sqrt((radarX - radar.Position.X)^2 + (radarY - radar.Position.Y)^2)
            
            if distanceFromCenter > radar.Radius then
                local angle = math.atan2(radarY - radar.Position.Y, radarX - radar.Position.X)
                radarX = radar.Position.X + math.cos(angle) * radar.Radius
                radarY = radar.Position.Y + math.sin(angle) * radar.Radius
            end
            
            if not radarPlayers[player] then
                radarPlayers[player] = {
                    dot = Drawing.new("Circle"),
                    direction = Drawing.new("Line"),
                    name = Drawing.new("Text")
                }
                
                radarPlayers[player].dot.Thickness = 1
                radarPlayers[player].dot.Filled = true
                radarPlayers[player].dot.Radius = 4
                
                radarPlayers[player].direction.Thickness = 2
                radarPlayers[player].direction.Visible = true
                
                radarPlayers[player].name.Size = 12
                radarPlayers[player].name.Font = Drawing.Fonts.Monospace
                radarPlayers[player].name.Outline = true
                radarPlayers[player].name.OutlineColor = Color3.new(0, 0, 0)
            end
            
            if player.Team == LocalPlayer.Team then
                radarPlayers[player].dot.Color = Color3.new(0, 1, 0)  
                radarPlayers[player].direction.Color = Color3.new(0, 0.8, 0)
                radarPlayers[player].name.Color = Color3.new(0, 1, 0)
            else
                radarPlayers[player].dot.Color = Color3.new(1, 0, 0) 
                radarPlayers[player].direction.Color = Color3.new(1, 0, 0)
                radarPlayers[player].name.Color = Color3.new(1, 0, 0)
            end
            
            radarPlayers[player].dot.Position = Vector2.new(radarX, radarY)
            radarPlayers[player].dot.Visible = true
            
            local lookVector = rootPart.CFrame.LookVector
            local directionLength = 10
            radarPlayers[player].direction.From = Vector2.new(radarX, radarY)
            radarPlayers[player].direction.To = Vector2.new(
                radarX + lookVector.X * directionLength,
                radarY + lookVector.Z * directionLength
            )
            
            radarPlayers[player].name.Position = Vector2.new(radarX, radarY - 15)
            radarPlayers[player].name.Text = player.Name
            radarPlayers[player].name.Visible = distanceFromCenter <= radar.Radius
        elseif radarPlayers[player] then
            radarPlayers[player].dot.Visible = false
            radarPlayers[player].direction.Visible = false
            radarPlayers[player].name.Visible = false
        end
    end
    
    for player, components in pairs(radarPlayers) do
        if not Players:FindFirstChild(player.Name) then
            components.dot.Visible = false
            components.direction.Visible = false
            components.name.Visible = false
            radarPlayers[player] = nil
        end
    end
end

RunService.RenderStepped:Connect(updateRadar)
RunService.RenderStepped:Connect(updatePlayerCount)
RunService.RenderStepped:Connect(updateFOV)

for _, player in pairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        createESP(player)
    end
end

Players.PlayerAdded:Connect(function(player)
    if player ~= LocalPlayer then
        createESP(player)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    if ESPComponents[player] then
        for _, component in pairs(ESPComponents[player]) do
            if typeof(component) == "table" then
                for _, drawing in pairs(component) do
                    drawing:Remove()
                end
            else
                component:Remove()
            end
        end
        ESPComponents[player] = nil
    end
end)

C:Toggle({
    Title = "透视开启", 
    Value = false, 
    Callback = function(Value)
        getgenv().ESPEnabled = Value
    end
})

C:Toggle({
    Title = "模型透视", 
    Value = false, 
    Callback = function(Value)
        getgenv().ShowSkeleton = Value
    end
})

C:Toggle({
    Title = "方框透视", 
    Value = false, 
    Callback = function(Value)
        getgenv().ShowBox = Value
    end
})



C:Toggle({
    Title = "射线透视", 
    Value = false, 
    Callback = function(Value)
        getgenv().ShowTracer = Value
    end
})

C:Toggle({
    Title = "名字透视", 
    Value = false, 
    Callback = function(Value)
        getgenv().ShowName = Value
    end
})


local blockFDMG = false
local oldNamecall = nil
local isHookActive = false

local function initHook()
    if isHookActive then return end
    
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        if blockFDMG and getnamecallmethod() == "FireServer" and tostring(self) == "FDMG" then
            return nil
        end
        return oldNamecall(self, ...)
    end)
    
    isHookActive = true
end

local function removeHook()
    if not isHookActive or not oldNamecall then return end
    
    hookmetamethod(game, "__namecall", oldNamecall)
    oldNamecall = nil
    isHookActive = false
end

D:Button({
    Title = "坠落无伤害",
    Value = false,
    Callback = function(value)
        blockFDMG = value
        
        if value then
            if not isHookActive then
                initHook()
            end
        else
            if isHookActive then
                removeHook()
            end
        end
    end
})

D:Button({
    Title = "删除所有门",
    Callback = function()
       for k,v in pairs(Workspace.Tycoon.Tycoons:GetChildren()) do
            for x,y in pairs(v.PurchasedObjects:GetChildren()) do
                if(y.Name:find("Door") or y.Name:find("Gate")) then y:destroy(); end;
            end;
        end;
    end})

D:Toggle({
    Title = "无cd状态",
    Callback = function()
        local ContextActions = game:GetService("Workspace")[game.Players.LocalPlayer.Name].ContextActions
        local ContextMain = require(ContextActions.ContextMain)
        
        ContextMain:New({
            RobPlayerLength = 0.1,
            FixWallLength = 0.1,
            CrackSafeLength = 0.1,
            RobSafeLength = 0.1,
            RobRegisterLength = 0.1,
            PickCellLength = 0.1,
            SkinAnimalLength = 0.1
        }, 200, {
            "Get out of my shop! Outlaws are not welcome here!",
            "Hey, scoundrel! Get out before I call the sheriff!",
            "You're an outlaw! We don't serve your type here!"
        }, {
            "This here's a bandit camp! Get out!",
            "Get lost, cowboy!",
            "Are you an outlaw? Didn't think so! Scram!"
        })
    end
})

local deathPosition = nil
local deathOrientation = nil

local function setupDeathTracking()
    local player = game.Players.LocalPlayer
    
    player.CharacterAdded:Connect(function(character)
        local humanoid = character:WaitForChild("Humanoid")
        
        humanoid.Died:Connect(function()
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            if rootPart then
                deathPosition = rootPart.Position
                deathOrientation = rootPart.CFrame - rootPart.Position
                print("死亡位置已记录: " .. tostring(deathPosition))
            end
        end)
    end)
    
    if player.Character then
        local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.Died:Connect(function()
                local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
                if rootPart then
                    deathPosition = rootPart.Position
                    deathOrientation = rootPart.CFrame - rootPart.Position
                    print("死亡位置已记录: " .. tostring(deathPosition))
                end
            end)
        end
    end
end

setupDeathTracking()

D:Button({
    Title = "原地重生",
    Description = "在死亡位置重生角色",
    Callback = function()
        if not deathPosition then
            return
        end
        
        local player = game.Players.LocalPlayer
        local character = player.Character
        
        if character then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 then

                return
            end
        end
        
        local connection
        connection = player.CharacterAdded:Connect(function(newCharacter)
            local newRootPart = newCharacter:WaitForChild("HumanoidRootPart", 5)
            local newHumanoid = newCharacter:WaitForChild("Humanoid", 5)
            
            if newRootPart and newHumanoid then
                wait(0.5)
                
                newRootPart.CFrame = CFrame.new(deathPosition) * deathOrientation
                
                
                deathPosition = nil
                deathOrientation = nil
            end
            
            if connection then
                connection:Disconnect()
            end
        end)
        
        if not character then
            local currentTeam = player.Team
            player.Team = nil
            wait(0.1)
            player.Team = currentTeam
        else
            player:LoadCharacter()
        end
        
        delay(10, function()
            if connection then
                connection:Disconnect()
                WindUI:Notify({
                    Title = "超时",
                    Content = "重生过程超时",
                    Duration = 3,
                })
            end
        end)
    end
})

local fov = 0
local maxDistance = 50
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Cam = workspace.CurrentCamera

local FOVring = Drawing.new("Circle")
FOVring.Visible = false
FOVring.Thickness = 0.5
FOVring.Color = Color3.new(1, 1, 1)
FOVring.Filled = false
FOVring.Radius = fov
FOVring.Position = Cam.ViewportSize / 2

local autoAimEnabled = false
local fovVisible = false
local ignoreCover = false
local aimTarget = "敌对"
local aimPosition = "Head"
local fovColor = Color3.new(1, 1, 1)
local rainbowEnabled = false

local function updateDrawings()
    FOVring.Position = Cam.ViewportSize / 2
end

local function onKeyDown(input)
    if input.KeyCode == Enum.KeyCode.Delete then
        RunService:UnbindFromRenderStep("FOVUpdate")
        FOVring:Remove()
    end
end

UserInputService.InputBegan:Connect(onKeyDown)

local function lookAt(target)
    local lookVector = (target - Cam.CFrame.Position).unit
    local newCFrame = CFrame.new(Cam.CFrame.Position, Cam.CFrame.Position + lookVector)
    Cam.CFrame = newCFrame
end

local function getClosestPlayerInFOV(trg_part)
    local nearest = nil
    local last = math.huge
    local playerMousePos = Cam.ViewportSize / 2
    
    for _, player in ipairs(Plr:GetPlayers()) do
        if player ~= LP and (aimTarget == "全部" or player.TeamColor ~= LP.TeamColor) then
            local character = player.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local part = character and character:FindFirstChild(trg_part)
            
            if part and humanoid and humanoid.Health > 0 then
                local ePos, isVisible = Cam:WorldToViewportPoint(part.Position)
                local distance = (Vector2.new(ePos.x, ePos.y) - playerMousePos).Magnitude
                
                if distance < last and isVisible and distance < fov then
                    if (part.Position - Cam.CFrame.Position).Magnitude <= tonumber(maxDistance) then
                        if not ignoreCover or #Cam:GetPartsObscuringTarget({part.Position}, {character, LP.Character}) == 0 then
                            last = distance
                            nearest = player
                        end
                    end
                end
            end
        end
    end
    
    return nearest
end

Tg(E, "玩家自瞄", false, function(t)
    autoAimEnabled = t
end)

Tg(E, "显示范围", false, function(t)
    fovVisible = t
    FOVring.Visible = fovVisible
end)

Tg(E, "掩体不瞄", false, function(t)
    ignoreCover = t
end)

Sld(E, "自瞄范围", 1, 200, fov, function(s)
    fov = tonumber(s)
    FOVring.Radius = fov
end)

Sld(E, "自瞄距离", 1, 1200, maxDistance, function(s)
    maxDistance = tonumber(s)
end)

Sld(E, "自瞄圈粗细", 1, 10, FOVring.Thickness, function(s)
    FOVring.Thickness = tonumber(s)
end)

E:Dropdown({
    Title = "选择自瞄目标", 
    Values = {"敌对", "全部"}, 
    Value = "敌对", 
    Callback = function(value) 
        aimTarget = value 
    end
})

E:Dropdown({
    Title = "选择自瞄位置", 
    Values = {"头部", "躯干"}, 
    Value = "头部", 
    Callback = function(value)
        if value == "头部" then
            aimPosition = "Head"
        elseif value == "躯干" then
            aimPosition = "Torso"
        end
    end
})

E:Dropdown({
    Title = "选择圈的颜色", 
    Values = {"红", "黄", "蓝", "绿", "青", "紫", "彩虹"}, 
    Value = "红", 
    Callback = function(value)
        if value == "彩虹" then
            rainbowEnabled = true
        else
            rainbowEnabled = false
            local colors = {
                ["红"] = Color3.new(1, 0, 0),
                ["黄"] = Color3.new(1, 1, 0),
                ["蓝"] = Color3.new(0, 0, 1),
                ["绿"] = Color3.new(0, 1, 0),
                ["青"] = Color3.new(0, 1, 1),
                ["紫"] = Color3.new(1, 0, 1)
            }
            FOVring.Color = colors[value]
        end
    end
})

local excludeTargetsDropdown = F:Dropdown({
    Title = "不攻击的玩家(多选)", 
    Values = PlayerList, 
    Value = {}, 
    Multi = true, 
    AllowNone = true, 
    Callback = function(values) 
        C_NPlayers = values or {} 
    end
})

Btn(F, "刷新玩家列表", function()
    PlayerList = {}
    for _, player in ipairs(Plr:GetPlayers()) do
        if player ~= LP then
            table.insert(PlayerList, player.Name)
        end
    end
    excludeTargetsDropdown:Refresh(PlayerList)
end)

Btn(F, "获取RPG", function()
    local Players = game:GetService("Players")
    local localPlayer = Players.LocalPlayer
    local TycoonsFolder = workspace.Tycoon.Tycoons
    local savedPosition
    
    local function findNearestTeleportPosition()
        local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
        local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
        local playerPosition = humanoidRootPart.Position
        local closestDistance = math.huge
        local closestCFrame = nil
        
        for _, tycoonModel in ipairs(TycoonsFolder:GetChildren()) do
            if tycoonModel:IsA("Model") then
                local purchasedObjects = tycoonModel:FindFirstChild("PurchasedObjects")
                if purchasedObjects then
                    local rpgGiver = purchasedObjects:FindFirstChild("RPG Giver")
                    if rpgGiver then
                        local prompt = rpgGiver:FindFirstChild("Prompt")
                        if prompt and prompt:IsA("BasePart") then
                            local distance = (playerPosition - prompt.Position).Magnitude
                            if distance < closestDistance then
                                closestDistance = distance
                                closestCFrame = prompt.CFrame
                            end
                        end
                    end
                end
            end
        end
        
        return closestCFrame
    end
    
    local function teleportPlayer()
        local character = localPlayer.Character
        if not character then
            return
        end
        
        local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        if humanoidRootPart then
            savedPosition = humanoidRootPart.CFrame
        end
        
        local targetCFrame = findNearestTeleportPosition()
        if targetCFrame then
            humanoidRootPart.CFrame = targetCFrame
            
            spawn(function()
                while wait(0.5) do
                    if not character.Parent then
                        break
                    end
                    
                    local backpack = localPlayer:FindFirstChild("Backpack")
                    if backpack and backpack:FindFirstChild("RPG") then
                        humanoidRootPart.CFrame = savedPosition
                        break
                    end
                end
            end)
        else
            WindUI:Notify({
                Title = "ERROR",
                Content = "未能找到附近的RPG",
                Duration = 4,
            })
        end
    end
    
    teleportPlayer()
end)

local loopActive = false
local rpgAttackThread = nil

Tg(F, "RPG轰炸", false, function(t)
    loopActive = t
    
    if t then
        if rpgAttackThread then
            coroutine.close(rpgAttackThread)
            rpgAttackThread = nil
        end
        
        rpgAttackThread = coroutine.create(function()
            local Players = game:GetService("Players")
            local LocalPlayer = Players.LocalPlayer
            local ReplicatedStorage = game:GetService("ReplicatedStorage")
            local RocketSystem = ReplicatedStorage:WaitForChild("RocketSystem")
            local FireRocket = RocketSystem.Events.FireRocket
            local RocketHit = RocketSystem.Events.RocketHit
            local attackPhase = "attack"
            local phaseStartTime = os.clock()
            
            while loopActive do
                local currentTime = os.clock()
                local elapsed = currentTime - phaseStartTime
                
                if not loopActive then break end
                
                if attackPhase == "attack" then
                    if elapsed >= 3 then
                        attackPhase = "pause"
                        phaseStartTime = os.clock()
                    else
                        local character = LocalPlayer.Character
                        if character and character:FindFirstChild("HumanoidRootPart") then
                            local attackPosition = character.HumanoidRootPart.Position + Vector3.new(0, 1000, 0)
                            local weapon = character:FindFirstChild("RPG")
                            
                            if weapon then
                                for _, player in ipairs(Players:GetPlayers()) do
                                    if player ~= LocalPlayer and player.Character and not table.find(C_NPlayers, player.Name) then
                                        local target = player.Character:FindFirstChild("HumanoidRootPart")
                                        if target then
                                            FireRocket:InvokeServer(Vector3.new(), weapon, weapon, attackPosition)
                                            RocketHit:FireServer(attackPosition, Vector3.new(), weapon, weapon, target, nil, "asdfghvcqawRocket4")
                                            task.wait(0.3)
                                        end
                                    end
                                end
                            end
                        end
                    end
                elseif attackPhase == "pause" then
                    if elapsed >= 2 then
                        attackPhase = "attack"
                        phaseStartTime = os.clock()
                    end
                end
                
                task.wait(0.1)
            end
        end)
        
        coroutine.resume(rpgAttackThread)
    else
        if rpgAttackThread then
            coroutine.close(rpgAttackThread)
            rpgAttackThread = nil
        end
    end
end)

local shieldAttackActive = false
local shieldAttackThread = nil

Tg(F, "护盾攻击", false, function(t)
    shieldAttackActive = t
    
    if t then
        if shieldAttackThread then
            coroutine.close(shieldAttackThread)
            shieldAttackThread = nil
        end
        
        shieldAttackThread = coroutine.create(function()
            while shieldAttackActive do
                if not shieldAttackActive then break end
                
                local rpg = LP.Character and LP.Character:FindFirstChild("RPG")
                if not rpg then
                    task.wait(1)
                    continue
                end
                
                local attackPosition = LP.Character.HumanoidRootPart.Position + Vector3.new(0, 1000, 0)
                local tycoonFolder = workspace:WaitForChild("Tycoon"):WaitForChild("Tycoons")
                
                for _, tycoon in ipairs(tycoonFolder:GetChildren()) do
                    if not shieldAttackActive then break end
                    
                    if tycoon:FindFirstChild("Owner") and tycoon.Owner.Value ~= LP then
                        local shield = tycoon:FindFirstChild("PurchasedObjects", true) and
                                      tycoon.PurchasedObjects:FindFirstChild("Base Shield", true) and
                                      tycoon.PurchasedObjects["Base Shield"]:FindFirstChild("Shield", true) and
                                      tycoon.PurchasedObjects["Base Shield"].Shield:FindFirstChild("Shield4", true)
                        
                        if shield then
                            local fireArgs = { Vector3.new(0, 0, 0), rpg, rpg, attackPosition }
                            
                            for _ = 1, 2 do
                                local hitArgs = {attackPosition, Vector3.new(0, -1, 0), rpg, rpg, shield, nil, string.format("%sRocket%d", string.char(math.random(65, 90)), math.random(1, 1000))}
                                RocketSystem.Events.RocketHit:FireServer(unpack(hitArgs))
                                RocketSystem.Events.FireRocket:InvokeServer(unpack(fireArgs))
                                task.wait(0.3)
                            end
                        end
                    end
                end
                
                task.wait(0.3)
            end
        end)
        
        coroutine.resume(shieldAttackThread)
    else
        if shieldAttackThread then
            coroutine.close(shieldAttackThread)
            shieldAttackThread = nil
        end
    end
end)

RunService.RenderStepped:Connect(function()
    updateDrawings()
    
    if autoAimEnabled then
        local closestPlayer = getClosestPlayerInFOV(aimPosition)
        if closestPlayer and closestPlayer.Character and closestPlayer.Character:FindFirstChild(aimPosition) then
            lookAt(closestPlayer.Character[aimPosition].Position)
        end
    end
    
    if rainbowEnabled then
        local t = tick() * 2
        local r = math.abs(math.sin(t))
        local g = math.abs(math.sin(t + 2 * math.pi / 3))
        local b = math.abs(math.sin(t + 4 * math.pi / 3))
        FOVring.Color = Color3.new(r, g, b)
    end
end)

pcall(function()
getgenv().autoTeleport = false 
local function getDistance(objectPosition)
    local player = game.Players.LocalPlayer
    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        local playerPosition = player.Character.HumanoidRootPart.Position
        return (objectPosition - playerPosition).Magnitude
    end
    return math.huge
end

local function getClosestNeon()
    local player = game.Players.LocalPlayer
    local teamName = player.Team.Name
    local buttonsFolder = workspace.Tycoon.Tycoons:FindFirstChild(teamName).UnpurchasedButtons

    if buttonsFolder then
        local closestNeon = nil
        local closestDistance = math.huge 

        for _, button in pairs(buttonsFolder:GetChildren()) do
            if not button:FindFirstChild("Mission") then
                local neon = button:FindFirstChild("Neon")
                local price = button:FindFirstChild("Price")

                if neon and price and price.Value ~= 0 then
                    local distance = getDistance(neon.Position)
                    if distance < closestDistance then
                        closestNeon = neon
                        closestDistance = distance
                    end
                end
            end
        end

        return closestNeon
    end

    return nil
end

local function teleportToClosestNeon()
    local player = game.Players.LocalPlayer

    while getgenv().autoTeleport do
        wait(0.2) 

        local closestNeon = getClosestNeon()

        if closestNeon then
            if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                player.Character.HumanoidRootPart.CFrame = CFrame.new(closestNeon.Position)
            end
        else
            warn("no neon found")
        end
    end
end

local function checkTeleportToggle()
    while true do
        wait(0.5)
        if getgenv().autoTeleport then
            teleportToClosestNeon()
        end
    end
end

spawn(checkTeleportToggle)
end)

pcall(function()
    local ps = game:GetService("Players")
    local ws = game:GetService("Workspace")
    local rs = game:GetService("ReplicatedStorage")
    local rss = game:GetService("RunService")

    local lp = ps.LocalPlayer
    local crateRemote = rs:FindFirstChild("TankCrates") and rs.TankCrates:FindFirstChild("WeldCrate")
    local hrp
    getgenv().auto = false
    local currentCrate 
    local lastCrateCheck = 0
    local crateCheckInterval = 5 

    local function setupCharacter()
        if lp.Character then
            hrp = lp.Character:WaitForChild("HumanoidRootPart")
        end
    end

    setupCharacter()
    lp.CharacterAdded:Connect(function()
        setupCharacter()
    end)

    local function tp(target)
        if not getgenv().auto or not target or not hrp then return end
        
        local cf = typeof(target) == "CFrame" and target or target.CFrame
        local success = pcall(function()
            local randomOffset = Vector3.new(
                math.random(-2, 2),
                0,
                math.random(-2, 2)
            )
            hrp.CFrame = cf + randomOffset
        end)
        
        if not success then
            warn("Teleport failed")
        end
    end

    local function firePrompt(prompt, crate)
        if not prompt then return end
        
        prompt.MaxActivationDistance = 10
        fireproximityprompt(prompt, 1)
        
        if crate and crateRemote then
            task.wait(0.1) 
            pcall(crateRemote.InvokeServer, crateRemote, crate)
        end
    end

    local function findCrate()
        local crateWorkspace = ws:FindFirstChild("Game Systems") and ws["Game Systems"]:FindFirstChild("Crate Workspace")
        if not crateWorkspace then return nil end
        
        for _, c in ipairs(crateWorkspace:GetChildren()) do
            if c:GetAttribute("Owner") ~= lp.Name then
                return c
            end
        end
        return nil
    end

    local function getTycoon()
        local leaderstats = lp:FindFirstChild("leaderstats")
        if not leaderstats then return nil end
        
        local team = leaderstats:FindFirstChild("Team")
        if not team then return nil end
        
        return ws.Tycoon.Tycoons:FindFirstChild(team.Value)
    end

    local function getSellPoint(tycoon)
        if not tycoon then return nil end
        
        local essentials = tycoon:FindFirstChild("Essentials")
        if not essentials then return nil end
        
        local oilCollector = essentials:FindFirstChild("Oil Collector")
        if not oilCollector then return nil end
        
        local cratePromptPart = oilCollector:FindFirstChild("CratePromptPart")
        if not cratePromptPart then return nil end
        
        return cratePromptPart
    end

    local function getWaitPoint(tycoon)
        if not tycoon then return nil end
        
        local floor = tycoon:FindFirstChild("Floor")
        if not floor then return nil end
        
        local floorOrigin = floor:FindFirstChild("FloorOrigin")
        if not floorOrigin then return nil end
        
        return CFrame.new(
            floorOrigin.Position.X + math.random(-10, 10),
            floorOrigin.Position.Y + 3,
            floorOrigin.Position.Z + math.random(-10, 10)
        )
    end

    local function sellCrate(tycoon)
        if not tycoon then return false end
        
        local sellPoint = getSellPoint(tycoon)
        if not sellPoint then return false end
        
        tp(sellPoint)
        task.wait(0.1) 
        
        local sellPrompt = sellPoint:FindFirstChild("SellPrompt")
        if sellPrompt then
            firePrompt(sellPrompt)
            task.wait(0.1)
            return true
        end
        
        return false
    end

    function autofarmLoop()
        while getgenv().auto and task.wait(0.1) do
            local tycoon = getTycoon()
            if not tycoon then continue end

            local holdingCrate = false
            local crateWorkspace = ws:FindFirstChild("Game Systems") and ws["Game Systems"]:FindFirstChild("Crate Workspace")
            if crateWorkspace then
                for _, crate in ipairs(crateWorkspace:GetChildren()) do
                    if crate:GetAttribute("Holding") == lp.Name then
                        holdingCrate = true
                        currentCrate = crate
                        break
                    end
                end
            end

            if holdingCrate then
                if sellCrate(tycoon) then
                    currentCrate = nil
                    task.wait(1)
                end
            else
                local currentTime = tick()
                if currentTime - lastCrateCheck > crateCheckInterval then
                    lastCrateCheck = currentTime
                    
                    local nextCrate = findCrate()
                    if nextCrate then
                        currentCrate = nextCrate
                        tp(nextCrate)
                        task.wait(0.5)
                        
                        local prompt = nextCrate:FindFirstChild("StealPrompt")
                        if prompt then
                            firePrompt(prompt, nextCrate)
                            task.wait(0.01) 
                        end
                    else
                        local waitPoint = getWaitPoint(tycoon)
                        if waitPoint then
                            tp(waitPoint)
                            task.wait(0.1)
                            if getgenv().auto then
                                local humanoid = lp.Character and lp.Character:FindFirstChild("Humanoid")
                                if humanoid then
                                    humanoid.Jump = true
                                    task.wait(0.2)
                                    humanoid.Jump = false
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    spawn(function()
        while task.wait(0.1) do
            if getgenv().auto then
                autofarmLoop()
            end
        end
    end)
end)