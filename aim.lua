local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local RunService = game:GetService("RunService")
local old
local main = {
    enable = false,
    teamcheck = false,
    friendcheck = false,
    wallpen = false,
    line = false
}

local function IsVisible(head)
    if not head or not head.Parent then return false end
    local rayOrigin = Camera.CFrame.Position
    local rayDirection = (head.Position - rayOrigin).Unit * 5000
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendants = {LocalPlayer.Character, Camera}
    params.IgnoreWater = true
    local result = Workspace:Raycast(rayOrigin, rayDirection, params)
    return not result or result.Instance:IsDescendantOf(head.Parent)
end

local function getClosestHead()
    local closestHead
    local closestDistance = math.huge

    if not LocalPlayer.Character then return end
    if not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end

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
                local head = character:FindFirstChild("Head")
                local humanoid = character:FindFirstChildOfClass("Humanoid")

                if root and head and humanoid and humanoid.Health > 0 then
                    local viewportPoint, onScreen = Camera:WorldToViewportPoint(head.Position)
                    if onScreen then
                        if not main.wallpen and not IsVisible(head) then
                            -- skip if wall check enabled and not visible
                        else
                            local distance = (root.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
                            if distance < closestDistance then
                                closestHead = head
                                closestDistance = distance
                            end
                        end
                    end
                end
            end
        end
    end
    return closestHead
end

old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if method == "Raycast" and not checkcaller() then
        local origin = args[1] or Camera.CFrame.Position

        if main.enable then
            local closestHead = getClosestHead()
            if closestHead then
                return {
                    Instance = closestHead,
                    Position = closestHead.Position,
                    Normal = (origin - closestHead.Position).Unit,
                    Material = Enum.Material.Plastic,
                    Distance = (closestHead.Position - origin).Magnitude
                }
            end
        end
    end
    return old(self, ...)
end))

local tracerLine = Drawing.new("Line")
tracerLine.Color = Color3.new(1, 1, 1)
tracerLine.Thickness = 2
tracerLine.Transparency = 1
tracerLine.Visible = false

RunService.RenderStepped:Connect(function()
    if main.enable and main.line then
        local closestHead = getClosestHead()
        if closestHead then
            local screenPos = Camera:WorldToViewportPoint(closestHead.Position)
            tracerLine.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
            tracerLine.To = Vector2.new(screenPos.X, screenPos.Y)
            tracerLine.Visible = true
        else
            tracerLine.Visible = false
        end
    else
        tracerLine.Visible = false
    end
end)

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "子弹追踪",
    Icon = "rbxassetid://115895976319223",
    IconThemed = true,
    Author = "idk",
    Folder = "CloudHub",
    Size = UDim2.fromOffset(300, 270),
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

MainSection = Window:Section({
    Title = "子追",
    Opened = true,
})

Main = MainSection:Tab({ Title = "设置", Icon = "Sword" })

Main:Toggle({
    Title = "开启子弹追踪",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.enable = state
    end
})

Main:Toggle({
    Title = "开启队伍验证",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.teamcheck = state
    end
})

Main:Toggle({
    Title = "开启好友验证",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.friendcheck = state
    end
})

Main:Toggle({
    Title = "开启子弹穿墙",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.wallpen = state
    end
})

Main:Toggle({
    Title = "开启目标连线",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.line = state
    end
})
