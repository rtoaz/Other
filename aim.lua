--多功能版
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local old
local main = {
    enable = false,
    teamcheck = false,
    friendcheck = false,
    enablenpc = false
}

-- 添加性能优化变量
local lastPlayerCheck = 0
local lastNpcCheck = 0
local cachedClosestHead = nil
local cachedClosestNpcHead = nil
local CACHE_DURATION = 0.1 -- 缓存时间（秒）

local function getClosestHead()
    -- 添加缓存检查，避免每帧都计算
    if tick() - lastPlayerCheck < CACHE_DURATION and cachedClosestHead then
        return cachedClosestHead
    end
    
    local closestHead
    local closestDistance = math.huge
    
    if not LocalPlayer.Character then return end
    if not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
    
    local localHrp = LocalPlayer.Character.HumanoidRootPart
    
    -- 添加距离限制，避免遍历太远的玩家
    local MAX_DISTANCE = 500
    
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
                    local distance = (root.Position - localHrp.Position).Magnitude
                    -- 添加距离检查
                    if distance < closestDistance and distance < MAX_DISTANCE then
                        closestHead = head
                        closestDistance = distance
                    end
                end
            end
        end
    end
    
    -- 更新缓存
    lastPlayerCheck = tick()
    cachedClosestHead = closestHead
    return closestHead
end

local function getClosestNpcHead()
    -- 添加缓存检查
    if tick() - lastNpcCheck < CACHE_DURATION and cachedClosestNpcHead then
        return cachedClosestNpcHead
    end
    
    local closestHead
    local closestDistance = math.huge
    
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
    local localHrp = LocalPlayer.Character.HumanoidRootPart
    
    -- 添加距离限制
    local MAX_DISTANCE = 500
    
    -- 优化NPC搜索，避免遍历所有后代
    for _, object in ipairs(Workspace:GetChildren()) do
        if object:IsA("Model") then
            -- 先快速检查距离
            local hrp = object:FindFirstChild("HumanoidRootPart") or object.PrimaryPart
            if hrp then
                local distance = (hrp.Position - localHrp.Position).Magnitude
                if distance > MAX_DISTANCE then
                    continue
                end
            end
            
            local humanoid = object:FindFirstChildOfClass("Humanoid")
            local head = object:FindFirstChild("Head")
            
            if humanoid and humanoid.Health > 0 and head then
                local isPlayer = false
                -- 优化玩家检查
                if object:FindFirstChild("Humanoid") then
                    for _, pl in ipairs(Players:GetPlayers()) do
                        if pl.Character == object then
                            isPlayer = true
                            break
                        end
                    end
                end
                
                if not isPlayer then
                    local distance = (hrp.Position - localHrp.Position).Magnitude
                    if distance < closestDistance then
                        closestHead = head
                        closestDistance = distance
                    end
                end
            end
        end
    end
    
    -- 更新缓存
    lastNpcCheck = tick()
    cachedClosestNpcHead = closestHead
    return closestHead
end

old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}
    
    if method == "Raycast" and not checkcaller() then
        local origin = args[1] or Camera.CFrame.Position
        
        -- 添加安全检查
        if not main.enable and not main.enablenpc then
            return old(self, ...)
        end
        
        if main.enable then
            local success, closestHead = pcall(getClosestHead)
            if success and closestHead then
                return {
                    Instance = closestHead,
                    Position = closestHead.Position,
                    Normal = (origin - closestHead.Position).Unit,
                    Material = Enum.Material.Plastic,
                    Distance = (closestHead.Position - origin).Magnitude
                }
            end
        end
        
        if main.enablenpc then
            local success, closestNpcHead = pcall(getClosestNpcHead)
            if success and closestNpcHead then
                return {
                    Instance = closestNpcHead,
                    Position = closestNpcHead.Position,
                    Normal = (origin - closestNpcHead.Position).Unit,
                    Material = Enum.Material.Plastic,
                    Distance = (closestNpcHead.Position - origin).Magnitude
                }
            end
        end
    end
    return old(self, ...)
end))

-- 添加性能监控（可选）
spawn(function()
    while wait(5) do
        -- 定期清理缓存，避免内存泄漏
        if tick() - lastPlayerCheck > 10 then
            cachedClosestHead = nil
        end
        if tick() - lastNpcCheck > 10 then
            cachedClosestNpcHead = nil
        end
    end
end)

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
        -- 清除缓存，确保重新计算
        cachedClosestHead = nil
        lastPlayerCheck = 0
    end
})

Main:Toggle({
    Title = "开启队伍验证",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.teamcheck = state
        cachedClosestHead = nil
        lastPlayerCheck = 0
    end
})

Main:Toggle({
    Title = "开启好友验证",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.friendcheck = state
        cachedClosestHead = nil
        lastPlayerCheck = 0
    end
})

Main:Toggle({
    Title = "开启NPC子弹追踪",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.enablenpc = state
        cachedClosestNpcHead = nil
        lastNpcCheck = 0
    end
})
