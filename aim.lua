local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local main = {
    enable = false,
    teamcheck = false,
    friendcheck = false,
    hitrate = 100,    -- 命中率 0-100，默认 100
    drawLine = false, -- 是否绘制连线（默认关闭）
    drawCircle = false -- 是否绘制头部圆（默认关闭）
}

-- Drawing 支持检测与对象（可能在不同执行环境不可用）
local DrawingAvailable = false
local lineDrawing, circleDrawing = nil, nil
do
    local ok, _ = pcall(function()
        local tline = Drawing.new("Line")
        tline:Remove()
    end)
    DrawingAvailable = ok
    if DrawingAvailable then
        lineDrawing = Drawing.new("Line")
        circleDrawing = Drawing.new("Circle")

        -- 线设置（白色），默认隐藏
        lineDrawing.Color = Color3.new(1,1,1)
        lineDrawing.Thickness = 2
        lineDrawing.Transparency = 1
        lineDrawing.Visible = false

        -- 圆设置（白色，空心），默认隐藏
        circleDrawing.Radius = 8 -- 屏幕像素半径（适中大小）
        circleDrawing.Filled = false
        circleDrawing.Color = Color3.new(1,1,1)
        circleDrawing.Thickness = 2
        circleDrawing.Transparency = 1
        circleDrawing.Visible = false
    else
        warn("[BulletTracer] Drawing API not available — visuals disabled.")
    end
end

-- 获取最近的头部（仅限摄像机可见范围内）
local function getClosestHead()
    local closestHead
    local closestDistance = math.huge

    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return nil
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
                    -- 判断头部是否在摄像机视野内
                    local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                    if onScreen and screenPos.Z > 0 then
                        -- 距离检测（使用 root 到本地 root 的距离）
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

-- 模拟正常Raycast的函数（备用）
local function simulateRaycast(origin, direction, params)
    local result = Workspace:Raycast(origin, direction, params)

    return result or {
        Instance = nil,
        Position = origin + direction,
        Normal = -direction.Unit,
        Material = Enum.Material.Air,
        Distance = (origin + direction - origin).Magnitude
    }
end

-- 改写后的Raycast hook（保持原有行为并注入命中逻辑）
local oldRaycast
oldRaycast = hookfunction(Workspace.Raycast, function(self, origin, direction, raycastParams)
    if main.enable and not checkcaller() then
        local closestHead = getClosestHead()

        if closestHead then
            local headPos = closestHead.Position
            local distance = (headPos - origin).Magnitude
            local diff = origin - headPos
            local normalDirection = diff.Magnitude > 0 and diff.Unit or Vector3.new(0, 1, 0)

            -- 命中率控制
            local roll = math.random(1, 100)
            if roll <= math.clamp(main.hitrate, 0, 100) then
                -- 模拟命中头部，加入轻微偏移，降低检测风险
                return {
                    Instance = closestHead,
                    Position = headPos + Vector3.new(
                        (math.random() - 0.5) * 0.2,
                        (math.random() - 0.5) * 0.2,
                        (math.random() - 0.5) * 0.2
                    ),
                    Normal = normalDirection,
                    Material = Enum.Material.Plastic,
                    Distance = distance
                }
            end
        end
    end

    local result = oldRaycast(self, origin, direction, raycastParams)
    return result or simulateRaycast(origin, direction, raycastParams)
end)

-- UI部分（WindUI），并加入命中率滑块与视觉开关（默认关闭）
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "子弹追踪",
    Icon = "rbxassetid://129260712070622",
    IconThemed = true,
    Author = "idk",
    Folder = "CloudHub",
    Size = UDim2.fromOffset(300, 420), -- 增高以容纳更多控件
    Transparent = true,
    Theme = "Dark",
    User = {
        Enabled = true,
        Callback = function()
            print("clicked")
        end,
        Anonymous = false
    },
    SideBarWidth = 200,
    ScrollBarEnabled = true,
})

Window:EditOpenButton({
    Title = "打开UI",
    Icon = "monitor",
    CornerRadius = UDim.new(0, 16),
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

Main = MainSection:Tab({
    Title = "设置",
    Icon = "Sword"
})

-- 注意：下面的 Toggle 都使用你提供的“正确句式”，并确保 Value = false（默认关闭）

Main:Toggle({
    Title = "开启子弹追踪",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.enable = state
        -- 关闭时确保所有可视化被隐藏
        if not state and DrawingAvailable then
            lineDrawing.Visible = false
            circleDrawing.Visible = false
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

-- 命中率滑块
Main:Slider({
    Title = "命中率 (%)",
    Value = { Min = 0, Max = 100, Default = 100 },
    Callback = function(Value)
        local v = tonumber(Value) or 100
        if v < 0 then v = 0 end
        if v > 100 then v = 100 end
        main.hitrate = v
        print("命中率已设置为:", main.hitrate)
    end
})

-- 显示连线（默认 false）
Main:Toggle({
    Title = "显示连线",
    Image = "line",
    Value = false,
    Callback = function(state)
        main.drawLine = state
        -- 立即同步隐藏（显示由渲染循环控制）
        if DrawingAvailable and not state then
            lineDrawing.Visible = false
        end
        if not DrawingAvailable and state then
            warn("[BulletTracer] Drawing API not available — cannot show line.")
        end
    end
})

-- 显示目标圈（默认 false）
Main:Toggle({
    Title = "显示目标圈",
    Image = "circle",
    Value = false,
    Callback = function(state)
        main.drawCircle = state
        if DrawingAvailable and not state then
            circleDrawing.Visible = false
        end
        if not DrawingAvailable and state then
            warn("[BulletTracer] Drawing API not available — cannot show circle.")
        end
    end
})

-- 可视化更新循环（使用 RenderStepped）
local function updateVisuals()
    if not DrawingAvailable then
        return
    end

    -- 每帧更新锁定目标并渲染线和圆
    RunService.RenderStepped:Connect(function()
        -- 先隐藏默认
        lineDrawing.Visible = false
        circleDrawing.Visible = false

        if not main.enable then
            return
        end

        local targetHead = getClosestHead()
        if targetHead and targetHead.Parent then
            local screenPos, onScreen = Camera:WorldToViewportPoint(targetHead.Position)
            if onScreen and screenPos.Z > 0 then
                local screenX, screenY = screenPos.X, screenPos.Y
                -- 屏幕中心（从中心连线到目标）
                local centerX = Camera.ViewportSize.X / 2
                local centerY = Camera.ViewportSize.Y / 2

                -- 绘制线条（严格依赖两个开关：main.enable 与 main.drawLine）
                if main.drawLine then
                    lineDrawing.From = Vector2.new(centerX, centerY)
                    lineDrawing.To = Vector2.new(screenX, screenY)
                    lineDrawing.Visible = true
                end

                -- 绘制头部圆形（严格依赖 main.drawCircle）
                if main.drawCircle then
                    circleDrawing.Position = Vector2.new(screenX, screenY)
                    circleDrawing.Visible = true
                end
            end
        end
    end)
end

-- 启动视觉更新（如果支持）
if DrawingAvailable then
    updateVisuals()
end
