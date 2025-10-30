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
    drawline = false, -- 新增：控制目标连线显示，默认关闭
    wallbang = false  -- 新增：子弹穿墙控制，默认关闭
}

-- 返回最优先（视角内且靠近屏幕中心，若中心距离接近则选更近的世界距离）的头部
local function getClosestHead()
    local closestHead
    local bestCenterDist = math.huge
    local bestWorldDist = math.huge

    if not LocalPlayer.Character then return end
    local localRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not localRoot then return end

    local viewportSize = Camera.ViewportSize
    local screenCenter = Vector2.new(viewportSize.X/2, viewportSize.Y/2)

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
                    local viewportPoint = Camera:WorldToViewportPoint(head.Position)
                    local z = viewportPoint.Z
                    if z > 0 then
                        local screenPos = Vector2.new(viewportPoint.X, viewportPoint.Y)
                        if screenPos.X >= 0 and screenPos.X <= viewportSize.X and screenPos.Y >= 0 and screenPos.Y <= viewportSize.Y then
                            local centerDist = (screenPos - screenCenter).Magnitude
                            local worldDist = (root.Position - localRoot.Position).Magnitude

                            local EPS = 1.0
                            if centerDist + 0.0001 < bestCenterDist - EPS then
                                closestHead = head
                                bestCenterDist = centerDist
                                bestWorldDist = worldDist
                            elseif math.abs(centerDist - bestCenterDist) <= EPS then
                                if worldDist < bestWorldDist then
                                    closestHead = head
                                    bestCenterDist = centerDist
                                    bestWorldDist = worldDist
                                end
                            elseif centerDist < bestCenterDist - EPS then
                                closestHead = head
                                bestCenterDist = centerDist
                                bestWorldDist = worldDist
                            end
                        end
                    end
                end
            end
        end
    end

    return closestHead
end

-- 用于连线的目标查找：与 getClosestHead 逻辑一致，但总是可用（不依赖 main.enable）
local function getLineTarget()
    local targetHead
    local targetScreenPos
    if not LocalPlayer.Character then return nil end
    local localRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not localRoot then return nil end

    local viewportSize = Camera.ViewportSize
    local screenCenter = Vector2.new(viewportSize.X/2, viewportSize.Y/2)
    local bestCenterDist = math.huge
    local bestWorldDist = math.huge

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
                    local viewportPoint = Camera:WorldToViewportPoint(head.Position)
                    local z = viewportPoint.Z
                    if z > 0 then
                        local screenPos = Vector2.new(viewportPoint.X, viewportPoint.Y)
                        if screenPos.X >= 0 and screenPos.X <= viewportSize.X and screenPos.Y >= 0 and screenPos.Y <= viewportSize.Y then
                            local centerDist = (screenPos - screenCenter).Magnitude
                            local worldDist = (root.Position - localRoot.Position).Magnitude

                            local EPS = 1.0
                            if centerDist + 0.0001 < bestCenterDist - EPS then
                                targetHead = head
                                targetScreenPos = screenPos
                                bestCenterDist = centerDist
                                bestWorldDist = worldDist
                            elseif math.abs(centerDist - bestCenterDist) <= EPS then
                                if worldDist < bestWorldDist then
                                    targetHead = head
                                    targetScreenPos = screenPos
                                    bestCenterDist = centerDist
                                    bestWorldDist = worldDist
                                end
                            elseif centerDist < bestCenterDist - EPS then
                                targetHead = head
                                targetScreenPos = screenPos
                                bestCenterDist = centerDist
                                bestWorldDist = worldDist
                            end
                        end
                    end
                end
            end
        end
    end

    if targetHead then
        return targetHead, targetScreenPos
    else
        return nil
    end
end

old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if method == "Raycast" and not checkcaller() then
        local origin = args[1] or Camera.CFrame.Position

        -- 当启用子弹追踪并找得到目标头时，按 wallbang 设置决定是否穿墙
        if main.enable then
            local closestHead = getClosestHead()
            if closestHead then
                -- 如果开启穿墙，直接替换结果（穿墙）
                if main.wallbang then
                    return {
                        Instance = closestHead,
                        Position = closestHead.Position,
                        Normal = (origin - closestHead.Position).Unit,
                        Material = Enum.Material.Plastic,
                        Distance = (closestHead.Position - origin).Magnitude
                    }
                else
                    -- 未开启穿墙：先执行原始 Raycast，检查是否在到达目标前命中其它物体
                    local originalResult = old(self, ...)
                    if originalResult and originalResult.Instance then
                        -- 如果原始命中的是目标头（或其子级），则返回原始命中结果（或用目标结果）
                        local hit = originalResult.Instance
                        local anc = hit
                        local hitIsTarget = false
                        while anc do
                            if anc == closestHead then
                                hitIsTarget = true
                                break
                            end
                            anc = anc.Parent
                        end

                        if hitIsTarget then
                            -- 原始已经击中目标头，保留原始结果（更安全）
                            return originalResult
                        else
                            -- 原始在到达目标前命中了别的东西 --> 不替换（不穿墙）
                            return originalResult
                        end
                    else
                        -- 原始没有命中任何东西，允许替换为目标（即不会被遮挡）
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

-- 新增：控制目标连线开关
Main:Toggle({
    Title = "显示目标连线",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.drawline = state
    end
})

-- 新增：子弹穿墙开关
Main:Toggle({
    Title = "子弹穿墙",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.wallbang = state
    end
})

-- Drawing line (默认白色)，在有目标且目标在视口内时显示；连线在未开启子弹追踪时也可用
local line = Drawing and Drawing.new and Drawing.new("Line") or nil
if line then
    line.Thickness = 2
    line.Transparency = 1
    line.Visible = false
    line.From = Vector2.new(0,0)
    line.To = Vector2.new(0,0)
    line.Color = Color3.fromRGB(255,255,255) -- 默认白色
end

-- 每帧更新连线状态
RunService.RenderStepped:Connect(function()
    if not line then return end

    if not main.drawline then
        line.Visible = false
        return
    end

    local targetHead, screenPos = getLineTarget()
    if targetHead and screenPos then
        local vp = Camera:WorldToViewportPoint(targetHead.Position)
        if vp.Z > 0 then
            local sp = Vector2.new(vp.X, vp.Y)
            local viewportSize = Camera.ViewportSize
            local screenCenter = Vector2.new(viewportSize.X/2, viewportSize.Y/2)

            line.From = screenCenter
            line.To = sp
            line.Visible = true
        else
            line.Visible = false
        end
    else
        line.Visible = false
    end
end)
