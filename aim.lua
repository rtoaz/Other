local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local RunService = game:GetService("RunService")
local mt = getrawmetatable(game)
local old_index = mt.__index
local main = {
    enable = false,
    teamcheck = false,
    friendcheck = false,
    drawline = false
}

local line = Drawing.new("Line")
line.Color = Color3.new(1, 0, 0)
line.Thickness = 2
line.Transparency = 1
line.Visible = false

local connection

local function getClosestHead()
    local closestHead
    local closestDistance = math.huge

    if not LocalPlayer.Character then return end
    if not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end

    local cam_pos = Camera.CFrame.Position
    local look = Camera.CFrame.LookVector

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
                    local to_head = (head.Position - cam_pos).Unit
                    local dot = look:Dot(to_head)
                    if dot > 0 then
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
    return closestHead
end

local drawConnection
drawConnection = function()
    if not main.enable or not main.drawline then
        line.Visible = false
        return
    end

    local closestHead = getClosestHead()
    if closestHead then
        local screenpos, onscreen = Camera:WorldToScreenPoint(closestHead.Position)
        if onscreen then
            local centerX = Camera.ViewportSize.X / 2
            local centerY = Camera.ViewportSize.Y / 2
            line.From = Vector2.new(centerX, centerY)
            line.To = Vector2.new(screenpos.X, screenpos.Y)
            line.Visible = true
        else
            line.Visible = false
        end
    else
        line.Visible = false
    end
end

mt.__index = newcclosure(function(self, key)
    if self == Workspace and key == "Raycast" and not checkcaller() then
        local raycast_func = old_index(self, key)
        if main.enable then
            local closestHead = getClosestHead()
            if closestHead then
                return newcclosure(function(origin, direction, params)
                    local origin_pos = origin or Camera.CFrame.Position
                    local hitpos = closestHead.Position
                    local dist = (hitpos - origin_pos).Magnitude
                    return {
                        Instance = closestHead,
                        Position = hitpos,
                        Normal = (origin_pos - hitpos).Unit,
                        Material = Enum.Material.Plastic,
                        Distance = dist
                    }
                end)
            end
        end
        return raycast_func
    end
    return old_index(self, key)
end)

local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/main.lua"))()
local Window = WindUI:CreateWindow({
    Title = "子弹追踪",
    Icon = "rbxassetid://129260712070622",
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
        if not state then
            line.Visible = false
        end
    end
})

Main:Toggle({
    Title = "开启连线",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.drawline = state
        if state then
            connection = RunService.Heartbeat:Connect(drawConnection)
        else
            if connection then
                connection:Disconnect()
                connection = nil
            end
            line.Visible = false
        end
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
