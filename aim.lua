local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")  -- 新增：用于定时更新缓存
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local old
local main = {
    enable = false,
    teamcheck = false,
    friendcheck = false
}

-- 新增：缓存变量
local closestHeadCache = nil
local lastCacheUpdate = 0
local cacheInterval = 0.05  -- 每 0.05 秒更新一次缓存（可调，降低到 0.1 以进一步优化）

-- 修改：优化 getClosestHead，只更新缓存
local function updateClosestHeadCache()
    local currentTime = tick()
    if currentTime - lastCacheUpdate < cacheInterval then
        return closestHeadCache  -- 使用缓存
    end
    
    local closestHead
    local closestDistance = math.huge

    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        closestHeadCache = nil
        lastCacheUpdate = currentTime
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
                    local distance = (root.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
                    if distance < closestDistance and distance < 500 then  -- 新增：距离过滤，避免远距离无效追踪
                        closestHead = head
                        closestDistance = distance
                    end
                end
            end
        end
    end
    
    closestHeadCache = closestHead
    lastCacheUpdate = currentTime
    return closestHead
end

-- 新增：RunService 连接，用于定期更新缓存（低开销）
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

old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if method == "Raycast" and not checkcaller() then
        local origin = args[1] or Camera.CFrame.Position

        if main.enable then
            -- 修改：使用缓存，并添加 pcall 错误处理
            local success, closestHead = pcall(updateClosestHeadCache)
            if success and closestHead then
                local targetPos = closestHead.Position
                local direction = (targetPos - origin).Unit
                if direction.Magnitude > 0 then  -- 避免 NaN
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

-- 新增：启用时启动缓存更新
local function onEnableChanged(state)
    main.enable = state
    if state then
        startCacheUpdate()
        wait(0.1)  -- 新增：轻微延迟，避免瞬间高负载
    else
        stopCacheUpdate()
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
        onEnableChanged(state)  -- 修改：使用新函数处理启用逻辑
    end
})

Main:Toggle({
    Title = "开启队伍验证",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.teamcheck = state
        closestHeadCache = nil  -- 新增：切换时清缓存
    end
})

Main:Toggle({
    Title = "开启好友验证",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.friendcheck = state
        closestHeadCache = nil  -- 新增：切换时清缓存
    end
})
