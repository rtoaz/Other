-- 多功能版
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local old

-- 配置参数
local CONFIG = {
    MAX_DISTANCE = 200, -- 最大检测距离
    UPDATE_INTERVAL = 0.2, -- 更新间隔（秒）
    MAX_TARGETS = 20 -- 最大目标数量限制
}

local main = {
    enable = false,
    teamcheck = false,
    friendcheck = false,
    enablenpc = false
}

-- 缓存系统
local cache = {
    playerTargets = {},
    npcTargets = {},
    lastUpdate = 0,
    currentPlayerTarget = nil,
    currentNpcTarget = nil
}

-- 安全包装函数
local function safeFindFirstChild(instance, name)
    local success, result = pcall(function()
        return instance:FindFirstChild(name)
    end)
    return success and result or nil
end

local function safeGetPlayers()
    local success, result = pcall(function()
        return Players:GetPlayers()
    end)
    return success and result or {}
end

local function safeGetDescendants(workspace)
    local success, result = pcall(function()
        return workspace:GetDescendants()
    end)
    return success and result or {}
end

-- 优化的目标查找函数
local function updateTargets()
    if tick() - cache.lastUpdate < CONFIG.UPDATE_INTERVAL then
        return
    end
    
    cache.lastUpdate = tick()
    
    -- 清空缓存
    cache.playerTargets = {}
    cache.npcTargets = {}
    cache.currentPlayerTarget = nil
    cache.currentNpcTarget = nil
    
    -- 安全检查本地玩家
    if not LocalPlayer or not LocalPlayer.Character then return end
    local localHrp = safeFindFirstChild(LocalPlayer.Character, "HumanoidRootPart")
    if not localHrp then return end
    
    local localPosition = localHrp.Position
    
    -- 查找玩家目标（优化版本）
    if main.enable then
        local players = safeGetPlayers()
        local targetCount = 0
        
        for _, player in ipairs(players) do
            if targetCount >= CONFIG.MAX_TARGETS then break end
            
            if player ~= LocalPlayer and player.Character then
                -- 快速检查
                local skip = false
                
                if main.teamcheck and player.Team == LocalPlayer.Team then
                    skip = true
                end
                
                if not skip and main.friendcheck and LocalPlayer:IsFriendsWith(player.UserId) then
                    skip = true
                end
                
                if not skip then
                    local character = player.Character
                    local hrp = safeFindFirstChild(character, "HumanoidRootPart")
                    local head = safeFindFirstChild(character, "Head")
                    local humanoid = safeFindFirstChild(character, "Humanoid")
                    
                    if hrp and head and humanoid then
                        -- 快速距离检查
                        local distance = (hrp.Position - localPosition).Magnitude
                        if distance < CONFIG.MAX_DISTANCE then
                            table.insert(cache.playerTargets, {
                                head = head,
                                distance = distance,
                                position = hrp.Position
                            })
                            targetCount = targetCount + 1
                        end
                    end
                end
            end
        end
        
        -- 找到最近的玩家目标
        if #cache.playerTargets > 0 then
            table.sort(cache.playerTargets, function(a, b)
                return a.distance < b.distance
            end)
            cache.currentPlayerTarget = cache.playerTargets[1].head
        end
    end
    
    -- 查找NPC目标（优化版本）
    if main.enablenpc then
        local descendants = safeGetDescendants(Workspace)
        local targetCount = 0
        
        for _, object in ipairs(descendants) do
            if targetCount >= CONFIG.MAX_TARGETS then break end
            
            if object:IsA("Model") then
                local hrp = safeFindFirstChild(object, "HumanoidRootPart") or object.PrimaryPart
                local head = safeFindFirstChild(object, "Head")
                local humanoid = safeFindFirstChild(object, "Humanoid")
                
                if hrp and head and humanoid and humanoid.Health > 0 then
                    -- 检查是否为玩家角色
                    local isPlayer = false
                    for _, player in ipairs(Players:GetPlayers()) do
                        if player.Character == object then
                            isPlayer = true
                            break
                        end
                    end
                    
                    if not isPlayer then
                        local distance = (hrp.Position - localPosition).Magnitude
                        if distance < CONFIG.MAX_DISTANCE then
                            table.insert(cache.npcTargets, {
                                head = head,
                                distance = distance,
                                position = hrp.Position
                            })
                            targetCount = targetCount + 1
                        end
                    end
                end
            end
        end
        
        -- 找到最近的NPC目标
        if #cache.npcTargets > 0 then
            table.sort(cache.npcTargets, function(a, b)
                return a.distance < b.distance
            end)
            cache.currentNpcTarget = cache.npcTargets[1].head
        end
    end
end

-- 使用单独的线程更新目标
local updateConnection
local function startUpdateLoop()
    if updateConnection then
        updateConnection:Disconnect()
    end
    
    updateConnection = RunService.Heartbeat:Connect(function()
        local success, err = pcall(updateTargets)
        if not success then
            warn("目标更新错误: " .. tostring(err))
        end
    end)
end

-- 简化的钩子函数
old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    
    if method == "Raycast" and not checkcaller() then
        local args = {...}
        local origin = args[1] or Camera.CFrame.Position
        
        -- 快速检查是否有可用目标
        if main.enable and cache.currentPlayerTarget then
            return {
                Instance = cache.currentPlayerTarget,
                Position = cache.currentPlayerTarget.Position,
                Normal = (origin - cache.currentPlayerTarget.Position).Unit,
                Material = Enum.Material.Plastic,
                Distance = (cache.currentPlayerTarget.Position - origin).Magnitude
            }
        end
        
        if main.enablenpc and cache.currentNpcTarget then
            return {
                Instance = cache.currentNpcTarget,
                Position = cache.currentNpcTarget.Position,
                Normal = (origin - cache.currentNpcTarget.Position).Unit,
                Material = Enum.Material.Plastic,
                Distance = (cache.currentNpcTarget.Position - origin).Magnitude
            }
        end
    end
    
    return old(self, ...)
end))

-- 启动更新循环
startUpdateLoop()

-- UI部分保持不变
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
        cache.lastUpdate = 0 -- 强制立即更新
    end
})

Main:Toggle({
    Title = "开启队伍验证",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.teamcheck = state
        cache.lastUpdate = 0
    end
})

Main:Toggle({
    Title = "开启好友验证",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.friendcheck = state
        cache.lastUpdate = 0
    end
})

Main:Toggle({
    Title = "开启NPC子弹追踪",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.enablenpc = state
        cache.lastUpdate = 0
    end
})

-- 添加性能监控
spawn(function()
    while wait(10) do
        -- 定期清理和重置
        if not main.enable and not main.enablenpc then
            cache.playerTargets = {}
            cache.npcTargets = {}
            cache.currentPlayerTarget = nil
            cache.currentNpcTarget = nil
        end
    end
end)
