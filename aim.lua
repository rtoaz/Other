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
    maxdistance = 1000, -- 添加最大距离限制
    updateinterval = 0.1 -- 减少更新频率
}

local cachedClosestHead = nil
local lastUpdate = 0

-- 优化后的获取最近头部函数
local function getClosestHead()
    local currentTime = tick()
    
    -- 使用缓存，减少计算频率
    if currentTime - lastUpdate < main.updateinterval and cachedClosestHead then
        return cachedClosestHead
    end
    
    lastUpdate = currentTime
    cachedClosestHead = nil
    
    if not LocalPlayer.Character then return nil end
    if not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return nil end

    local localRoot = LocalPlayer.Character.HumanoidRootPart
    local localPosition = localRoot.Position
    local closestHead
    local closestDistance = main.maxdistance

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            -- 提前检查，减少不必要的计算
            if main.teamcheck and player.Team == LocalPlayer.Team then
                continue
            end

            if main.friendcheck and LocalPlayer:IsFriendsWith(player.UserId) then
                continue
            end

            local character = player.Character
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            
            -- 检查角色有效性
            if not humanoid or humanoid.Health <= 0 then
                continue
            end

            local root = character:FindFirstChild("HumanoidRootPart")
            local head = character:FindFirstChild("Head")
            
            if root and head then
                local distance = (root.Position - localPosition).Magnitude
                
                -- 只考虑在最大距离内的目标
                if distance < closestDistance then
                    closestHead = head
                    closestDistance = distance
                end
            end
        end
    end
    
    cachedClosestHead = closestHead
    return closestHead
end

-- 使用更安全的钩子方法
local function safeHook()
    old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()
        
        -- 只在必要时处理Raycast调用
        if method == "Raycast" and not checkcaller() and main.enable then
            local args = {...}
            local origin = args[1] or Camera.CFrame.Position
            
            -- 添加安全检查
            if not origin then
                return old(self, ...)
            end

            local closestHead = getClosestHead()
            if closestHead then
                -- 添加更真实的Raycast结果
                local headPosition = closestHead.Position
                local direction = (headPosition - origin).Unit
                local distance = (headPosition - origin).Magnitude
                
                -- 确保距离合理
                if distance <= main.maxdistance then
                    return {
                        Instance = closestHead,
                        Position = headPosition,
                        Normal = -direction, -- 修正法线方向
                        Material = Enum.Material.Plastic,
                        Distance = distance
                    }
                end
            end
        end
        return old(self, ...)
    end)
end

-- 延迟初始化，避免立即执行被检测
local success, err = pcall(safeHook)
if not success then
    warn("钩子初始化失败:", err)
    -- 可以选择其他实现方式
end

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
        -- 关闭时清除缓存
        if not state then
            cachedClosestHead = nil
        end
    end
})

Main:Toggle({
    Title = "开启队伍验证",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.teamcheck = state
        cachedClosestHead = nil -- 清除缓存
    end
})

Main:Toggle({
    Title = "开启好友验证",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.friendcheck = state
        cachedClosestHead = nil -- 清除缓存
    end
})

-- 添加距离设置
Main:Slider({
    Title = "最大距离",
    Image = "ruler",
    Value = 1000,
    Min = 100,
    Max = 5000,
    Callback = function(value)
        main.maxdistance = value
        cachedClosestHead = nil
    end
})

-- 添加性能提示
warn("子弹追踪已加载，建议谨慎使用以避免被检测")
