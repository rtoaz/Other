local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local RunService = game:GetService("RunService")
local old_namecall
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

-- 保存原始
old_getrawmetatable = getrawmetatable
local mt_game = old_getrawmetatable(game)
local original_namecall = mt_game.__namecall

-- 假 Raycast 结果（用于 namecall）
local function createFakeRaycastResult(origin, head)
    local hitPos = head.Position
    return {
        Instance = head,
        Position = hitPos,
        Normal = (origin - hitPos).Unit,
        Material = Enum.Material.Plastic,
        Distance = (hitPos - origin).Magnitude
    }
end

-- Beam函数
local function updateBulletLine(head)
    if not head then return end
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

    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end

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

-- 主hook：__namecall on game（保持namecall）
old_namecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if rawequal(self, Workspace) and method == "Raycast" then
        local origin = args[1] or Camera.CFrame.Position
        local direction = args[2] or (Camera.CFrame.LookVector * 1000)
        local params = args[3]

        if main.enable then
            local closestHead = getClosestHead()
            if closestHead then
                local hitResult = createFakeRaycastResult(origin, closestHead)
                
                spawn(function()
                    updateBulletLine(closestHead)
                end)
                
                return hitResult
            end
        end
    end
    return old_namecall(self, ...)
end))

-- 隐藏模式：用__index on game instance 伪装 metatable（增强隐藏）
local mt_game_index = getrawmetatable(game).__index or function() end
hookmetamethod(game, "__index", newcclosure(function(self, key)
    if rawequal(self, game) and key == "metatable" then  -- 拦截潜在 mt 检查
        -- 返回假 mt，只针对检测
        local fake_mt = {}
        for k, v in pairs(mt_game) do
            fake_mt[k] = (k == "__namecall" and original_namecall) or v
        end
        return fake_mt
    end
    return mt_game_index(self, key)
end))

-- 额外隐藏：Hook getrawmetatable
local new_getrawmetatable = newcclosure(function(tbl)
    if rawequal(tbl, game) then
        local fake_mt = {}
        for k, v in pairs(mt_game) do
            fake_mt[k] = (k == "__namecall") and original_namecall or v
        end
        return fake_mt
    end
    return old_getrawmetatable(tbl)
end)
getrawmetatable = new_getrawmetatable

-- 防冻结
RunService.Stepped:Connect(function()
    if Camera and Camera.Parent then
        Camera.CFrame = Camera.CFrame
    end
end)

-- UI：移除调试
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

MainSection = Window:Section({ Title = "子追", Opened = true, })

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
    Callback = function(state) main.teamcheck = state end
})

Main:Toggle({
    Title = "开启好友验证",
    Image = "bird",
    Value = false,
    Callback = function(state) main.friendcheck = state end
})
