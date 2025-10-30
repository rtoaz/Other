local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local old
local main = {
    enable = false,
    teamcheck = false,
    friendcheck = false
}

local function getClosestHead()
    local closestHead
    local closestScreenDistance = math.huge
    local closestWorldDistance = math.huge

    if not LocalPlayer.Character then return end
    if not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end

    local viewportSize = Camera.ViewportSize
    local screenCenter = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
    local localRootPos = LocalPlayer.Character.HumanoidRootPart.Position

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
                    -- 尝试使用 WorldToViewportPoint（有些环境会返回两个值）
                    local screenPoint, onScreen = Camera:WorldToViewportPoint(head.Position)
                    local screen2D = Vector2.new(screenPoint.X, screenPoint.Y)
                    local inViewport = false

                    if onScreen ~= nil then
                        inViewport = onScreen
                    else
                        inViewport = (screenPoint.Z > 0)
                    end

                    -- 确保在屏幕范围内（0..ViewportSize）
                    if inViewport and screen2D.X >= 0 and screen2D.X <= viewportSize.X and screen2D.Y >= 0 and screen2D.Y <= viewportSize.Y then
                        local screenDistance = (screen2D - screenCenter).Magnitude
                        local worldDistance = (root.Position - localRootPos).Magnitude

                        -- 优先视野中更靠中心的目标；若相等（或非常接近），使用世界距离作次要判断
                        if screenDistance < closestScreenDistance or (math.abs(screenDistance - closestScreenDistance) < 1e-4 and worldDistance < closestWorldDistance) then
                            closestHead = head
                            closestScreenDistance = screenDistance
                            closestWorldDistance = worldDistance
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
