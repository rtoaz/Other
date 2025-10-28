local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local RunService = game:GetService("RunService")
local old_index
local old_getrawmetatable
local main = {
    enable = false,
    teamcheck = false,
    friendcheck = false,
    currentTargetHead = nil,
    beam = nil,
    attachment0 = nil,
    attachment1 = nil
}

-- 保存原始 getrawmetatable 和 metatable 用于隐藏 hook
old_getrawmetatable = getrawmetatable
local mt = old_getrawmetatable(Workspace)
local original_index = mt.__index  -- 保存原始 __index 以供检测使用

-- 假 Raycast 函数：实现核心逻辑，但不阻塞（异步处理视觉效果）
local fakeRaycast = newcclosure(function(origin, direction, params)
    -- 确保不冻结摄像机：直接返回原始 Raycast，如果未启用或无目标
    if not main.enable then
        return old_index(Workspace, "Raycast")(origin, direction, params)
    end
    
    local closestHead = getClosestHead()
    if closestHead then
        local hitResult = {
            Instance = closestHead,
            Position = closestHead.Position,
            Normal = (origin - closestHead.Position).Unit,
            Material = Enum.Material.Plastic,
            Distance = (closestHead.Position - origin).Magnitude
        }
        
        -- 异步视觉效果，避免阻塞 Raycast 调用（防止摄像机冻结）
        spawn(function()
            updateBulletLine(closestHead)
        end)
        
        return hitResult
    end
    
    -- 回退到原始 Raycast
    return old_index(Workspace, "Raycast")(origin, direction, params)
end)

-- 创建或更新直线Beam（从Camera到目标头部）
local function updateBulletLine(head)
    if not head then return end
    
    -- 清理旧的
    if main.beam then main.beam:Destroy() end
    if main.attachment0 then main.attachment0:Destroy() end
    if main.attachment1 then main.attachment1:Destroy() end
    
    local originPart = Instance.new("Part")
    originPart.Name = "BulletOrigin"
    originPart.Anchored = true
    originPart.CanCollide = false
    originPart.Transparency = 1
    originPart.Size = Vector3.new(0.1, 0.1, 0.1)
    originPart.CFrame = CFrame.new(Camera.CFrame.Position)
    originPart.Parent = Workspace
    main.attachment0 = Instance.new("Attachment")
    main.attachment0.Parent = originPart
    
    main.attachment1 = Instance.new("Attachment")
    main.attachment1.Parent = head
    main.attachment1.CFrame = CFrame.new(0, 0, 0)
    
    main.beam = Instance.new("Beam")
    main.beam.Attachment0 = main.attachment0
    main.beam.Attachment1 = main.attachment1
    main.beam.Color = ColorSequence.new(Color3.fromRGB(255, 0, 0))
    main.beam.Transparency = NumberSequence.new(0.3)
    main.beam.Width0 = 0.5
    main.beam.Width1 = 0.5
    main.beam.Parent = Workspace
    
    game:GetService("Debris"):AddItem(main.beam, 0.1)
    game:GetService("Debris"):AddItem(originPart, 0.1)
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
                    local distance = (root.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
                    if distance < closestDistance then
                        closestHead = head
                        closestDistance = distance
                        main.currentTargetHead = head
                    end
                end
            end
        end
    end
    return closestHead
end

-- Hook __index 使用 hookmetamethod (针对 Workspace，确保精确拦截 Raycast)
old_index = hookmetamethod(Workspace, "__index", newcclosure(function(self, key)
    -- 只针对 Workspace 的 Raycast 进行拦截，避免干扰其他（如摄像机相关）
    if rawequal(self, Workspace) and key == "Raycast" then
        return fakeRaycast  -- 返回假 Raycast 函数
    end
    
    -- 否则调用原始 __index
    return old_index(self, key)
end))

-- Hook getrawmetatable 以隐藏 __index hook (更新为 Workspace 的 mt)
local new_getrawmetatable = newcclosure(function(tbl)
    if rawequal(tbl, Workspace) then
        local fake_mt = {}
        for k, v in pairs(mt) do
            fake_mt[k] = (k == "__index" and original_index) or v
        end
        return fake_mt
    end
    return old_getrawmetatable(tbl)
end)
getrawmetatable = new_getrawmetatable

-- 额外保护：确保摄像机不被冻结，通过 RunService 心跳更新 Camera（如果需要）
RunService.Heartbeat:Connect(function()
    if Camera and Camera.Parent then
        -- 轻量检查/强制更新 CFrame，避免任何潜在冻结（可选，仅在检测到问题时启用）
        Camera.CFrame = Camera.CFrame  -- 无操作重置，防止 stale
    end
end)

-- 原UI代码保持不变
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
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
