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
        -- 仅拦截特定属性，避免干扰 UI
        if key == "Position" or key == "CFrame" or key == "Health" then
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

    if not LocalPlayer.Character then return end
    local localRoot = createProxy(LocalPlayer.Character:FindFirstChild("HumanoidRootPart"))
    if not localRoot then return end

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

    -- 仅拦截 Workspace 的 Raycast 调用，避免干扰 UI
    if method == "Raycast" and not checkcaller() and self == Workspace and main.enable then
        local origin = args[1] or Camera.CFrame.Position
        local closestHead = getClosestHead()
        if closestHead then
            return {
                Instance = closestHead,
                Position = closestHead.Position + Vector3.new(math.random(-0.05, 0.05), math.random(-0.05, 0.05), math.random(-0.05, 0.05)),
                Normal = (origin - closestHead.Position).Unit,
                Material = Enum.Material.Plastic,
                Distance = (closestHead.Position - origin).Magnitude
            }
        end
    end
    return oldNamecall(self, ...)
end))

-- 拦截 __index 元方法，仅针对 Character 相关实例
oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, key)
    if not checkcaller() and (key == "Position" or key == "CFrame" or key == "Health") then
        -- 仅对 Character 相关实例应用代理，避免干扰 UI 对象
        if self:IsA("BasePart") or self:IsA("Humanoid") then
            local proxy = createProxy(self)
            return proxy[key]
        end
    end
    return oldIndex(self, key)
end))

-- 加载 UI
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
        Enabled = false,
        Callback = function() end,
        Anonymous = true
    },
    SideBarWidth = 200,
    ScrollBarEnabled = false,
})

Window:EditOpenButton({
    Title = "打开UI",
    Icon = "monitor",
    CornerRadius = UDim.new(0,16),
    StrokeThickness = 2,
    Color = ColorSequence.new(
        Color3.fromHex("2E0249")， 
        Color3.fromHex("9D4EDD")
    ),
    Draggable = true,
})

local MainSection = Window:Section({
    Title = "子追",
    Opened = false,
})

local Main = MainSection:Tab({ Title = "设置", Icon = "Sword" })

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

-- 优化反检测措施
local function antiDetect()
    -- 减少性能消耗，仅在必要时运行
    if not main.enable then return end
    local dummy = math.random(1, 1000)
    if LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = 16 + math.random(-0.05, 0.05) -- 恢复默认速度并轻微随机化
        end
    end
end

-- 降低 Heartbeat 频率
game:GetService("RunService").Stepped:Connect(function()
    if main.enable and math.random() < 0.1 then -- 10% 概率运行
        antiDetect()
    end
end)
