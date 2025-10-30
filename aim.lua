local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local old
local main = {
    enable = false,
    teamcheck = false,
    friendcheck = false,
    bulletPenetration = false, -- 子弹穿墙开关
    drawLine = false, -- 目标连线开关
}

-- 获取视角中心优先的最近玩家头部
local function getClosestHead()
    local closestHead
    local closestScreenDistance = math.huge

    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end

    local screenCenter = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)

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
                local head = character:FindFirstChild("Head")
                local humanoid = character:FindFirstChildOfClass("Humanoid")

                if head and humanoid and humanoid.Health > 0 then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                    if onScreen then
                        local distanceToCenter = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                        if distanceToCenter < closestScreenDistance then
                            closestHead = head
                            closestScreenDistance = distanceToCenter
                        end
                    end
                end
            end
        end
    end
    return closestHead
end

-- Hook Raycast 修改方向
old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if method == "Raycast" and not checkcaller() then
        local origin = args[1] or Camera.CFrame.Position
        local direction = args[2] or (Camera.CFrame.LookVector * 1000)

        if main.enable then
            local closestHead = getClosestHead()
            if closestHead then
                if main.bulletPenetration then
                    -- 开启穿墙：强制命中头部
                    return {
                        Instance = closestHead,
                        Position = closestHead.Position,
                        Normal = (origin - closestHead.Position).Unit,
                        Material = Enum.Material.Plastic,
                        Distance = (closestHead.Position - origin).Magnitude
                    }
                else
                    -- 不穿墙：修改射线方向，但长度保持原射线长度
                    local originalMagnitude = direction.Magnitude
                    local newDirection = (closestHead.Position - origin).Unit * originalMagnitude
                    args[2] = newDirection
                    return old(self, table.unpack(args))
                end
            end
        end
    end
    return old(self, ...)
end))

-- UI加载
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
        main.bulletPenetration = state
    end
})

Main:Toggle({
    Title = "开启目标连线",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.drawLine = state
    end
})

-- 目标连线（屏幕中心 -> 目标头部）
local drawingEnabled, Drawing = pcall(function() return Drawing end)
local targetLine
if drawingEnabled and Drawing then
    local success, ok = pcall(function()
        targetLine = Drawing.new("Line")
        targetLine.Visible = false
        targetLine.Transparency = 1
        targetLine.Thickness = 2
        targetLine.From = Vector2.new(0,0)
        targetLine.To = Vector2.new(0,0)
        targetLine.Color = Color3.fromRGB(255, 255, 255) -- 默认白色
    end)
    if not success then
        targetLine = nil
    end
end

RunService.RenderStepped:Connect(function()
    if not Camera then return end
    if not LocalPlayer.Character then
        if targetLine then targetLine.Visible = false end
        return
    end

    if main.enable and main.drawLine and targetLine then
        local closestHead = getClosestHead()
        if closestHead then
            local screenCenter = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
            local toPos, onScreen = Camera:WorldToViewportPoint(closestHead.Position)
            if onScreen then
                targetLine.From = screenCenter
                targetLine.To = Vector2.new(toPos.X, toPos.Y)
                targetLine.Visible = true
            else
                targetLine.Visible = false
            end
        else
            targetLine.Visible = false
        end
    else
        if targetLine then targetLine.Visible = false end
    end
end)
