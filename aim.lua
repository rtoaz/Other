local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local RunService = game:GetService("RunService")
local old_index
local old_getrawmetatable
local main = {
    enable = false,
    hooked = false,
    teamcheck = false,
    friendcheck = false,
    currentTargetHead = nil,
    lastTargetUpdate = 0,
    updateInterval = 0.2
}

-- 保存原始（延迟到启用时）
local function setupHiding()
    old_getrawmetatable = getrawmetatable
    local mt_game = old_getrawmetatable(game)
    local mt_ws = old_getrawmetatable(Workspace)
    local original_index_game = mt_game.__index
    local original_index_ws = mt_ws.__index
    local original_namecall = mt_game.__namecall  -- 备用

    -- 隐藏：Hook getrawmetatable（增强：添加__newindex伪装）
    local new_getrawmetatable = newcclosure(function(tbl)
        if rawequal(tbl, game) then
            local fake_mt = {}
            for k, v in pairs(mt_game) do
                fake_mt[k] = (k == "__index" or k == "__newindex" or k == "__namecall") and original_namecall or v
            end
            -- 简单hash伪装（针对Knightmare）
            fake_mt.hash = tostring(original_namecall):sub(1, 10) .. "fake"
            return fake_mt
        elseif rawequal(tbl, Workspace) then
            local fake_mt = {}
            for k, v in pairs(mt_ws) do
                fake_mt[k] = (k == "__index" or k == "__newindex") and original_index_ws or v
            end
            return fake_mt
        end
        return old_getrawmetatable(tbl)
    end)
    getrawmetatable = new_getrawmetatable

    -- 隐藏：Hook __index for game（拦截metatable查询）
    local mt_game_index = mt_game.__index or function() end
    hookmetamethod(game, "__index", newcclosure(function(self, key)
        if rawequal(self, game) and (key == "metatable" or key == "rawmetatable") then
            local fake_mt = {}
            for k, v in pairs(mt_game) do
                fake_mt[k] = (k == "__namecall" and original_namecall) or v
            end
            fake_mt.hash = tostring(original_namecall):sub(1, 10) .. "fake"
            return fake_mt
        end
        return mt_game_index(self, key)
    end))

    -- 新增：Hook __newindex for game/Workspace（防止属性修改检测）
    local mt_game_newindex = mt_game.__newindex or function() end
    hookmetamethod(game, "__newindex", newcclosure(function(self, key, value)
        if rawequal(self, game) and (key == "__namecall" or key == "metatable") then
            return  -- 阻塞篡改
        end
        return mt_game_newindex(self, key, value)
    end))

    local mt_ws_newindex = mt_ws.__newindex or function() end
    hookmetamethod(Workspace, "__newindex", newcclosure(function(self, key, value)
        if rawequal(self, Workspace) and key == "Raycast" then
            return  -- 保护Raycast
        end
        return mt_ws_newindex(self, key, value)
    end))
end

-- 假Raycast函数（支持params）
local fakeRaycast = newcclosure(function(origin, direction, params)
    if not main.enable then
        return Workspace:Raycast(origin, direction, params)
    end

    local closestHead = getClosestHead()
    if closestHead then
        local hitPos = closestHead.Position
        local hitResult = {
            Instance = closestHead,
            Position = hitPos,
            Normal = (origin - hitPos).Unit,
            Material = Enum.Material.Plastic,
            Distance = (hitPos - origin).Magnitude
        }
        
        spawn(function()
            updateBulletLine(closestHead)
        end)
        
        return hitResult
    end
    
    return Workspace:Raycast(origin, direction, params)
end)

local function createFakeRaycastResult(origin, head)  -- 备用
    local hitPos = head.Position
    return {
        Instance = head,
        Position = hitPos,
        Normal = (origin - hitPos).Unit,
        Material = Enum.Material.Plastic,
        Distance = (hitPos - origin).Magnitude
    }
end

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
    
    game:GetService("Debris"):AddItem({main.beam, originPart}, 0.1)
end

-- 优化版getClosestHead
local function getClosestHead()
    local now = tick()
    if now - main.lastTargetUpdate < main.updateInterval then
        return main.currentTargetHead
    end
    main.lastTargetUpdate = now

    local closestHead
    local closestDistance = math.huge
    local playerPos = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character.HumanoidRootPart.Position

    if not playerPos then return end

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
                    local distance = (root.Position - playerPos).Magnitude
                    if distance < 300 and distance < closestDistance then
                        closestHead = head
                        closestDistance = distance
                    end
                end
            end
        end
    end
    main.currentTargetHead = closestHead
    return closestHead
end

local function setupIndexHook()
    old_index = hookmetamethod(Workspace, "__index", newcclosure(function(self, key)
        -- 白名单Camera保护
        if rawequal(self, Camera) then
            return old_index(self, key)
        end
        
        if rawequal(self, Workspace) and key == "Raycast" then
            return fakeRaycast
        end
        return old_index(self, key)
    end))
end

-- UI
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
        if state and not main.hooked then
            setupHiding()
            setupIndexHook()
            main.hooked = true
        end
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
