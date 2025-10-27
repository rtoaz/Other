local Workspace = game:GetService("Workspace") 
local Players = game:GetService("Players") 
local LocalPlayer = Players.LocalPlayer 
local Camera = Workspace.CurrentCamera 
local oldNamecall, oldIndex 

local main = {
    enable = false,
    teamcheck = false,
    friendcheck = false
}

-- 伪装实例属性访问
local function createProxy(instance)
    local proxy = newproxy(true)
    local mt = getmetatable(proxy)
    
    mt.__index = function(_, key)
        -- 拦截敏感属性访问
        if key == "Position" or key == "CFrame" or key == "Health" then
            -- 随机延迟以模拟正常访问
            wait(math.random(0.001, 0.005))
            return instance[key]
        end
        return instance[key]
    end
    
    mt.__tostring = function()
        return tostring(instance)
    end
    
    return proxy
end

-- 获取最近的玩家头部
local function getClosestHead()
    local closestHead
    local closestDistance = math.huge
    
    if not LocalPlayer.Character then
        return
    end
    
    local localRoot = createProxy(LocalPlayer.Character:FindFirstChild("HumanoidRootPart"))
    if not localRoot then
        return
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
                local root = createProxy(character:FindFirstChild("HumanoidRootPart"))
                local head = createProxy(character:FindFirstChild("Head"))
                local humanoid = createProxy(character:FindFirstChildOfClass("Humanoid"))
                
                if root and head and humanoid and humanoid.Health > 0 then
                    local distance = (root.Position - localRoot.Position).Magnitude
                    if distance < closestDistance then
                        closestHead = head
                        closestDistance = distance
                    end
                end
            end
        end
    end
    
    return closestHead
end

-- 钩子元方法：拦截 Raycast
oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}
    
    if method == "Raycast" and not checkcaller() and main.enable then
        local origin = args[1] or Camera.CFrame.Position
        local closestHead = getClosestHead()
        
        if closestHead then
            -- 伪造 Raycast 结果
            return {
                Instance = closestHead,
                Position = closestHead.Position + Vector3.new(
                    math.random(-0.1, 0.1),
                    math.random(-0.1, 0.1),
                    math.random(-0.1, 0.1)
                ), -- 轻微随机偏移
                Normal = (origin - closestHead.Position).Unit,
                Material = Enum.Material.Plastic,
                Distance = (closestHead.Position - origin).Magnitude
            }
        end
    end
    
    return oldNamecall(self, ...)
end))

-- 拦截 __index 元方法以绕过属性检测
oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, key)
    if not checkcaller() and (key == "Position" or key == "CFrame" or key == "Health") then
        -- 伪装属性访问
        local proxy = createProxy(self)
        return proxy[key]
    end
    return oldIndex(self, key)
end))

-- 加载 UI（保持隐蔽）
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
        Enabled = false, -- 禁用用户交互记录以降低检测风险
        Callback = function() end,
        Anonymous = true
    },
    SideBarWidth = 200,
    ScrollBarEnabled = false -- 禁用滚动条以减少 UI 痕迹
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

local MainSection = Window:Section({
    Title = "子追",
    Opened = false -- 默认关闭以降低可见性
})

local Main = MainSection:Tab({
    Title = "设置",
    Icon = "Sword"
})

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

-- 添加反检测措施
local function antiDetect()
    -- 随机化调用栈
    local function dummy()
        return math.random(1, 1000)
    end
    
    for _ = 1, math.random(5, 10) do
        dummy()
    end
    
    -- 伪装正常玩家行为
    if LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = humanoid.WalkSpeed + math.random(-0.1, 0.1)
        end
    end
end

-- 定期运行反检测
game:GetService("RunService").Heartbeat:Connect(function()
    if main.enable then
        antiDetect()
    end
end)
