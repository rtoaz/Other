local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local old
local main = {
    enable = false,
    wallbang = false,
    teamcheck = false,
    friendcheck = false,
    drawLine = false  -- 新增：连线开关
}

-- 缓存目标
local cachedClosestHead = nil
local line = Drawing.new("Line")
line.Visible = false
line.Color = Color3.fromRGB(255, 255, 255)  -- 白色
line.Thickness = 2
line.Transparency = 1

local function updateClosestHead()
    cachedClosestHead = nil
    local closestScreenDistance = math.huge
    local viewportSize = Camera.ViewportSize
    local screenCenter = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)

    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return
    end

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
                    local screenPoint, onScreen = Camera:WorldToViewportPoint(head.Position)
                    if onScreen and screenPoint.Z > 0 then
                        local screenDist = (Vector2.new(screenPoint.X, screenPoint.Y) - screenCenter).Magnitude
                        if screenDist < closestScreenDistance then
                            cachedClosestHead = head
                            closestScreenDistance = screenDist
                        end
                    end
                end
            end
        end
    end
end

-- 每帧更新目标 + 连线
RunService.Heartbeat:Connect(function()
    if main.enable then
        updateClosestHead()

        -- 更新连线
        if main.drawLine and cachedClosestHead then
            local headScreen, onScreen = Camera:WorldToViewportPoint(cachedClosestHead.Position)
            if onScreen then
                local center = Camera.ViewportSize / 2
                line.From = center
                line.To = Vector2.new(headScreen.X, headScreen.Y)
                line.Visible = true
            else
                line.Visible = false
            end
        else
            line.Visible = false
        end
    else
        cachedClosestHead = nil
        line.Visible = false
    end
end)

-- 清理连线（退出时）
game:GetService("Players").PlayerRemoving:Connect(function(plr)
    if plr == LocalPlayer then
        line:Remove()
    end
end)

-- Raycast Hook
old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if method == "Raycast" and not checkcaller() and self == Workspace then
        local origin = args[1]
        local direction = args[2]
        local raycastParams = args[3]

        if main.enable and cachedClosestHead then
            local headDirection = cachedClosestHead.Position - origin
            local headDistance = headDirection.Magnitude
            headDirection = headDirection.Unit * math.max(headDistance, direction.Magnitude)

            if main.wallbang then
                -- 穿墙：强制击中
                return {
                    Instance = cachedClosestHead,
                    Position = cachedClosestHead.Position,
                    Normal = (origin - cachedClosestHead.Position).Unit,
                    Material = Enum.Material.Plastic,
                    Distance = headDistance
                }
            else
                -- 非穿墙：调整方向，真实检测
                return old(self, origin, headDirection, raycastParams)
            end
        end
    end
    return old(self, ...)
end))

-- WindUI
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "子弹追踪",
    Icon = "rbxassetid://115895976319223",
    IconThemed = true,
    Author = "idk",
    Folder = "CloudHub",
    Size = UDim2.fromOffset(300，270)，
    Transparent = true,
    Theme = "Dark",
    User = { Enabled = true, Callback = function() print("clicked") end, Anonymous = false },
    SideBarWidth = 200,
    ScrollBarEnabled = true,
})

Window:EditOpenButton({
    Title = "打开UI",
    Icon = "monitor",
    CornerRadius = UDim.new(0,16),
    StrokeThickness = 2,
    Color = ColorSequence.new(Color3.fromHex("FF0F7B"), Color3.fromHex("F89B29")),
    Draggable = true,
})

local MainSection = Window:Section({ Title = "子追", Opened = true })
local Main = MainSection:Tab({ Title = "设置", Icon = "Sword" })

Main:Toggle({
    Title = "开启子弹追踪",
    Image = "bird",
    Value = false,
    Callback = function(state) main.enable = state end
})

Main:Toggle({
    Title = "开启子弹穿墙",
    Image = "bird",
    Value = false,
    Callback = function(state) main.wallbang = state end
})

Main:Toggle({
    Title = "目标连线",   -- 新增
    Image = "bird",
    Value = false,
    Callback = function(state) main.drawLine = state end
})

Main:Toggle({
    Title = "开启队伍验证",
    Image = "bird",
    Value = false,
    Callback = function(state) main.teamcheck = state end
})

Main:Toggle({
    Title = "开启好友验证",
    Image = "bird",
    Value = false,
    Callback = function(state) main.friendcheck = state end
})
