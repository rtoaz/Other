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
    lineWidth = 2,
    fovAngle = 45
}

-- 缓存变量
local closestHeadCache = nil
local lastCacheUpdate = 0
local cacheInterval = 0.05

-- Drawing 对象（用于连线）
local targetLine = Drawing.new("Line")
targetLine.Color = Color3.fromRGB(255, 255, 255)  -- 修改：改为白色线条
targetLine.Transparency = 1
targetLine.Thickness = main.lineWidth
targetLine.Visible = false

-- updateClosestHeadCache 函数（不变）
local function updateClosestHeadCache()
    local currentTime = tick()
    if currentTime - lastCacheUpdate < cacheInterval then
        return closestHeadCache
    end
    
    local closestHead
    local closestDistance = math.huge

    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        closestHeadCache = nil
        lastCacheUpdate = currentTime
        return nil
    end

    local localRoot = LocalPlayer.Character.HumanoidRootPart
    local camPos = Camera.CFrame.Position

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
                    local distance = (root.Position - localRoot.Position).Magnitude
                    if distance < closestDistance and distance < 500 then
                        -- FOV 检查
                        local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                        local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                        local screenDistance = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                        local fovRadius = math.tan(math.rad(main.fovAngle)) * (Camera.ViewportSize.Y / 2) / math.tan(math.rad(Camera.FieldOfView / 2))
                        
                        if onScreen and screenDistance < fovRadius then
                            closestHead = head
                            closestDistance = distance
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

-- RenderStepped 连接（用于绘制连线）
local renderConnection
local function startLineDrawing()
    if renderConnection then return end
    renderConnection = RunService.RenderStepped:Connect(function()
        if main.enable then
            local closestHead = closestHeadCache
            if closestHead then
                local camPos = Camera.CFrame.Position
                local headPos = closestHead.Position
                
                -- 更新线条端点
                local screenFrom, _ = Camera:WorldToViewportPoint(camPos)
                local screenTo, onScreen = Camera:WorldToViewportPoint(headPos)
                
                targetLine.From = Vector2.new(screenFrom.X, screenFrom.Y)
                targetLine.To = Vector2.new(screenTo.X, screenTo.Y)
                targetLine.Thickness = main.lineWidth
                targetLine.Visible = onScreen
            else
                targetLine.Visible = false
            end
        else
            targetLine.Visible = false
        end
    end)
end

local function stopLineDrawing()
    if renderConnection then
        renderConnection:Disconnect()
        renderConnection = nil
    end
    targetLine.Visible = false
end

old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if method == "Raycast" and not checkcaller() then
        local origin = args[1] or Camera.CFrame.Position

        if main.enable then
            local success, closestHead = pcall(updateClosestHeadCache)
            if success and closestHead then
                local targetPos = closestHead.Position
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
    return old(self, ...)
end))

-- 启用逻辑
local function onEnableChanged(state)
    main.enable = state
    if state then
        startCacheUpdate()
        startLineDrawing()
        wait(0.1)
    else
        stopCacheUpdate()
        stopLineDrawing()
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
    Size = UDim2.fromOffset(300, 300),
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
    Title = "开启连线显示",
    Image = "bird",
    Value = true,
    Callback = function(state)
        targetLine.Visible = state and main.enable
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
    Title = "连线粗细",
    Value = { Min = 1, Max = 10, Default = 2 },
    Callback = function(Value)
        main.lineWidth = Value
        targetLine.Thickness = Value
        print("连线粗细:", Value)
    end
})
