local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local RunService = game:GetService("RunService")
local old
local main = {
    enable = false,
    teamcheck = false,
    friendcheck = false,
    currentTargetHead = nil,  -- 跟踪当前目标头部，用于集中火力
    beam = nil,  -- 用于存储beam实例
    attachment0 = nil,  -- 枪口附件（假设从Camera起始）
    attachment1 = nil   -- 目标头部附件
}

-- 创建或更新直线Beam（从Camera到目标头部）
local function updateBulletLine(head)
    if not head then return end
    
    -- 清理旧的beam和附件
    if main.beam then
        main.beam:Destroy()
    end
    if main.attachment0 then
        main.attachment0:Destroy()
    end
    if main.attachment1 then
        main.attachment1:Destroy()
    end
    
    -- 创建Attachment0（从Camera位置，模拟枪口）
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
    
    -- 创建Attachment1（目标头部）
    main.attachment1 = Instance.new("Attachment")
    main.attachment1.Parent = head
    main.attachment1.CFrame = CFrame.new(0, 0, 0)  -- 头部中心
    
    -- 创建Beam（直线tracer效果）
    main.beam = Instance.new("Beam")
    main.beam.Attachment0 = main.attachment0
    main.beam.Attachment1 = main.attachment1
    main.beam.Color = ColorSequence.new(Color3.fromRGB(255, 0, 0))  -- 红色直线，可自定义
    main.beam.Transparency = NumberSequence.new(0.3)
    main.beam.Width0 = 0.5
    main.beam.Width1 = 0.5
    main.beam.Parent = Workspace
    
    -- 短暂延迟后清理beam（模拟子弹飞行时间，0.1秒后消失）
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
                        main.currentTargetHead = head  -- 更新当前目标，用于集中
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
        local direction = args[2] or (Camera.CFrame.LookVector * 1000)  -- 默认方向，如果未提供

        if main.enable then
            local closestHead = getClosestHead()
            if closestHead then
                -- 保持原hook：返回假Raycast结果击中头部
                local hitResult = {
                    Instance = closestHead,
                    Position = closestHead.Position,
                    Normal = (origin - closestHead.Position).Unit,
                    Material = Enum.Material.Plastic,
                    Distance = (closestHead.Position - origin).Magnitude
                }
                
                -- 新增：创建直线视觉效果（集中到同一目标）
                spawn(function()  -- 异步创建，避免阻塞
                    updateBulletLine(closestHead)
                end)
                
                return hitResult
            end
        end
    end
    return old(self, ...)
end))

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
