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
    fovOnly = false,  -- FOV 限制开关，默认关
    fovAngle = 45,
    fovColor = Color3.fromRGB(255, 255, 255)
}

-- 缓存变量
local closestHeadCache = nil
local lastCacheUpdate = 0
local cacheInterval = 0.05

-- FOV 圆圈 Drawing 对象
local fovCircle = Drawing.new("Circle")
fovCircle.Color = main.fovColor
fovCircle.Thickness = 2
fovCircle.NumSides = 100
fovCircle.Radius = 0
fovCircle.Filled = false
fovCircle.Transparency = 1
fovCircle.Visible = false

-- 目标连线 Drawing 对象（新增：默认白色，不能通过 UI 修改）
local targetLine = Drawing.new("Line")
targetLine.Color = Color3.fromRGB(255, 255, 255) -- 默认白色
targetLine.Thickness = 2
targetLine.Transparency = 1
targetLine.Visible = false

-- 穿墙检查函数
local function hasWall(origin, targetPos)
    local direction = targetPos - origin
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    if closestHeadCache and closestHeadCache.Parent then
        raycastParams.FilterDescendantsInstances[#raycastParams.FilterDescendantsInstances + 1] = closestHeadCache.Parent
    end
    local result = Workspace:Raycast(origin, direction, raycastParams)
    return result ~= nil and result.Instance ~= closestHeadCache
end

-- 修改：updateClosestHeadCache，非FOV模式下锁定屏幕中间偏好玩家
local function updateClosestHeadCache()
    local currentTime = tick()
    if currentTime - lastCacheUpdate < cacheInterval then
        return closestHeadCache
    end
    
    local closestHead
    local closestMetric = math.huge  -- 排序指标：FOV模式用3D距离，非FOV用屏幕距离

    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        closestHeadCache = nil
        lastCacheUpdate = currentTime
        return nil
    end

    local localRoot = LocalPlayer.Character.HumanoidRootPart
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

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
                    local distance3D = (root.Position - localRoot.Position).Magnitude
                    if distance3D < 500 then
                        local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                        local screenDistance = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                        
                        if onScreen then  -- 必须在屏幕上可见
                            local currentMetric
                            if main.fovOnly then
                                -- FOV模式：FOV锥内 + 3D距离优先
                                local fovRadius = math.tan(math.rad(main.fovAngle)) * (Camera.ViewportSize.Y / 2) / math.tan(math.rad(Camera.FieldOfView / 2))
                                if screenDistance < fovRadius then
                                    currentMetric = distance3D
                                else
                                    continue  -- 不在FOV内，跳过
                                end
                            else
                                -- 非FOV模式：屏幕中间偏好 + 屏幕距离优先
                                currentMetric = screenDistance
                            end
                            
                            if currentMetric < closestMetric then
                                closestHead = head
                                closestMetric = currentMetric
                            end
                        end
                    end
                end
            end
        end
    end
    
    closestHeadCache = closestHead
    lastCacheUpdate = currentTime
    return closestHead
end

-- RunService 连接
local heartbeatConnection
local function startCacheUpdate()
    if heartbeatConnection then return end
    heartbeatConnection = RunService.Heartbeat:Connect(function()
        if main.enable then
            updateClosestHeadCache()
        end
    end)
end

local function stopCacheUpdate()
    if heartbeatConnection then
        heartbeatConnection:Disconnect()
        heartbeatConnection = nil
    end
end

-- FOV 圆圈更新连接
local renderConnection
local function startFOVDrawing()
    if renderConnection then return end
    renderConnection = RunService.RenderStepped:Connect(function()
        if main.enable and main.fovOnly then
            local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
            local fovRadius = math.tan(math.rad(main.fovAngle)) * (Camera.ViewportSize.Y / 2) / math.tan(math.rad(Camera.FieldOfView / 2))
            
            fovCircle.Position = screenCenter
            fovCircle.Radius = fovRadius
            fovCircle.Color = main.fovColor
            fovCircle.Visible = true
        else
            fovCircle.Visible = false
        end
    end)
end

local function stopFOVDrawing()
    if renderConnection then
        renderConnection:Disconnect()
        renderConnection = nil
    end
    fovCircle.Visible = false
end

-- 新增：目标连线绘制（始终默认白色），独立 RenderStepped 连接
local targetRenderConnection
local function startTargetLineDrawing()
    if targetRenderConnection then return end
    targetRenderConnection = RunService.RenderStepped:Connect(function()
        if main.enable then
            -- 尝试使用缓存的目标（缓存由 Heartbeat 更新）
            local success, cached = pcall(function() return updateClosestHeadCache() end)
            local head = (success and cached) and cached or closestHeadCache

            if head and head.Parent then
                local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                if onScreen then
                    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                    targetLine.From = screenCenter
                    targetLine.To = Vector2.new(screenPos.X, screenPos.Y)
                    targetLine.Color = Color3.fromRGB(255, 255, 255) -- 确保为白色
                    targetLine.Visible = true
                else
                    targetLine.Visible = false
                end
            else
                targetLine.Visible = false
            end
        else
            targetLine.Visible = false
        end
    end)
end

local function stopTargetLineDrawing()
    if targetRenderConnection then
        targetRenderConnection:Disconnect()
        targetRenderConnection = nil
    end
    targetLine.Visible = false
end

-- Raycast 钩子
old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if method == "Raycast" and not checkcaller() then
        local origin = args[1] or Camera.CFrame.Position

        if main.enable then
            local success, closestHead = pcall(updateClosestHeadCache)
            if success and closestHead then
                local targetPos = closestHead.Position
                local hasObstacle = hasWall(origin, targetPos)
                
                if main.wallbang or not hasObstacle then
                    local direction = (targetPos - origin).Unit
                    if direction.Magnitude > 0 then
                        return {
                            Instance = closestHead,
                            Position = targetPos,
                            Normal = direction,
                            Material = Enum.Material.Plastic,
                            Distance = (targetPos - origin).Magnitude
                        }
                    end
                end
            end
        end
    end
    return old(self, ...)
end))

-- 启用逻辑
local function onEnableChanged(state)
    main.enable = state
    if state then
        startCacheUpdate()
        startFOVDrawing()
        startTargetLineDrawing() -- 启动目标连线绘制
        wait(0.1)
    else
        stopCacheUpdate()
        stopFOVDrawing()
        stopTargetLineDrawing() -- 停止目标连线绘制
        closestHeadCache = nil
    end
end

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "子弹追踪",
    Icon = "rbxassetid://115895976319223",
    IconThemed = true,
    Author = "idk",
    Folder = "CloudHub",
    Size = UDim2.fromOffset(300, 320),
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
        onEnableChanged(state)
    end
})

Main:Toggle({
    Title = "开启穿墙",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.wallbang = state
        closestHeadCache = nil
        print("穿墙模式:", state and "开启" or "关闭")
    end
})

Main:Toggle({
    Title = "FOV",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.fovOnly = state
        closestHeadCache = nil
        print("锁定模式:", state and "仅FOV内" or "屏幕中间偏好")
    end
})

Main:Toggle({
    Title = "开启队伍验证",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.teamcheck = state
        closestHeadCache = nil
    end
})

Main:Toggle({
    Title = "开启好友验证",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.friendcheck = state
        closestHeadCache = nil
    end
})

Main:Slider({
    Title = "FOV 大小",
    Value = { Min = 10, Max = 90, Default = 45 },
    Callback = function(Value)
        main.fovAngle = Value
        closestHeadCache = nil
        print("FOV 大小:", Value)
    end
})

Main:Colorpicker({
    Title = "FOV 颜色",
    Default = Color3.fromRGB(255, 255, 255),
    Callback = function(Color, Transparency)
        main.fovColor = Color
        fovCircle.Color = Color
        fovCircle.Transparency = 1 - Transparency
        print("FOV 颜色:", Color)
    end
})
