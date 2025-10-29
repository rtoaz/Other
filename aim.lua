local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

local old
local main = {
    enable = false,
    teamcheck = false,
    friendcheck = false,
    visiblecheck = false,
    hitChance = 100,
    targetPart = "Head",
    fovRadius = 130,
    fovVisible = false
}

-- Drawing objects
local fov_circle = Drawing.new("Circle")
fov_circle.Thickness = 1
fov_circle.NumSides = 100
fov_circle.Radius = main.fovRadius
fov_circle.Filled = false
fov_circle.Visible = false
fov_circle.ZIndex = 999
fov_circle.Transparency = 1
fov_circle.Color = Color3.fromRGB(54, 57, 241)

local function getMousePosition()
    return Vector2.new(Mouse.X, Mouse.Y)
end

local function getPositionOnScreen(Vector)
    local Vec3, OnScreen = Camera:WorldToScreenPoint(Vector)
    return Vector2.new(Vec3.X, Vec3.Y), OnScreen
end

local function IsPlayerVisible(targetPart)
    if not targetPart then return false end
    local LocalCharacter = LocalPlayer.Character
    if not LocalCharacter then return false end
    
    local castPoints = {targetPart.Position}
    local ignoreList = {LocalCharacter}
    
    local obscuringParts = Camera:GetPartsObscuringTarget(castPoints, ignoreList)
    return #obscuringParts == 0
end

local ValidTargetParts = {"Head", "HumanoidRootPart"}

local function getClosestTarget()
    local closestTarget
    local closestDistance = math.huge
    local mousePos = getMousePosition()

    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return nil end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local skip = false

            if main.teamcheck and player.Team == LocalPlayer.Team then
                skip = true
            end

            if not skip and main.friendcheck and LocalPlayer:IsFriendsWith(player.UserId) then
                skip = true
            end

            if not skip then
                local character = player.Character
                local root = character:FindFirstChild("HumanoidRootPart")
                local humanoid = character:FindFirstChildOfClass("Humanoid")

                if root and humanoid and humanoid.Health > 0 then
                    local target
                    if main.targetPart == "Random" then
                        target = character[ValidTargetParts[math.random(1, #ValidTargetParts)]]
                    else
                        target = character:FindFirstChild(main.targetPart)
                    end

                    if target then
                        if main.visiblecheck and not IsPlayerVisible(target) then
                            continue
                        end

                        local screenPos, onScreen = getPositionOnScreen(target.Position)
                        if onScreen then
                            local distance = (mousePos - screenPos).Magnitude
                            if distance < main.fovRadius and distance < closestDistance then
                                closestTarget = target
                                closestDistance = distance
                            end
                        end
                    end
                end
            end
        end
    end
    return closestTarget
end

old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if method == "Raycast" and not checkcaller() then
        local hitChance = math.random() * 100 <= main.hitChance
        if main.enable and hitChance then
            local origin = args[1] or Camera.CFrame.Position
            local closestTarget = getClosestTarget()
            if closestTarget then
                return {
                    Instance = closestTarget,
                    Position = closestTarget.Position,
                    Normal = (closestTarget.Position - origin).Unit,
                    Material = Enum.Material.Plastic,
                    Distance = (closestTarget.Position - origin).Magnitude
                }
            end
        end
    end
    return old(self, ...)
end))

-- FOV Update Loop
RunService.RenderStepped:Connect(function()
    if main.fovVisible then
        fov_circle.Visible = true
        fov_circle.Position = getMousePosition()
        fov_circle.Radius = main.fovRadius
    else
        fov_circle.Visible = false
    end
end)

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "子弹追踪",
    Icon = "rbxassetid://115895976319223",
    IconThemed = true,
    Author = "idk",
    Folder = "CloudHub",
    Size = UDim2.fromOffset(300, 400),
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
    Title = "打开UI",
    Icon = "monitor",
    CornerRadius = UDim.new(0,16),
    StrokeThickness = 2,
    Color = ColorSequence.new(
        Color3.fromHex("FF0F7B"), 
        Color3.fromHex("F89B29")
    ),
    Draggable = true,
})

local MainSection = Window:Section({
    Title = "子追",
    Opened = true,
})

local MainTab = MainSection:Tab({ Title = "设置", Icon = "Sword" })

MainTab:Toggle({
    Title = "开启子弹追踪",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.enable = state
    end
})

MainTab:Toggle({
    Title = "开启队伍验证",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.teamcheck = state
    end
})

MainTab:Toggle({
    Title = "开启好友验证",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.friendcheck = state
    end
})

MainTab:Toggle({
    Title = "开启可见验证",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.visiblecheck = state
    end
})

MainTab:Dropdown({
    Title = "目标部位",
    Values = {"Head", "HumanoidRootPart", "Random"},
    Value = "Head",
    Multi = false,
    Callback = function(value)
        main.targetPart = value
    end
})

MainTab:Slider({
    Title = "命中率 (%)",
    Value = { Min = 0, Max = 100, Default = 100 },
    Callback = function(value)
        main.hitChance = value
    end
})

local FOVTab = MainSection:Tab({ Title = "FOV", Icon = "Eye" })

FOVTab:Toggle({
    Title = "显示FOV圆",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.fovVisible = state
    end
})

FOVTab:Slider({
    Title = "FOV半径",
    Value = { Min = 50, Max = 300, Default = 130 },
    Callback = function(value)
        main.fovRadius = value
    end
})
