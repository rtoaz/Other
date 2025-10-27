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

-- 错误处理包装器
local function safeCall(func, ...)
    local success, result = pcall(func, ...)
    if not success then
        warn("Error in function: " .. tostring(result))
        return nil
    end
    return result
end

-- 伪装实例属性访问
local function createProxy(instance)
    if not instance then return nil end
    local proxy = newproxy(true)
    local mt = getmetatable(proxy)
    
    mt.__index = function(_, key)
        if key == "Position" or key == "CFrame" or key == "Health" then
            return safeCall(function() return instance[key] end)
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

    if not LocalPlayer.Character then return nil end
    local localRoot = safeCall(function() return createProxy(LocalPlayer.Character:FindFirstChild("HumanoidRootPart")) end)
    if not localRoot then return nil end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local skip = false

            if main.teamcheck and safeCall(function() return player.Team == LocalPlayer.Team end) then
                skip = true
            end

            if not skip and main.friendcheck and safeCall(function() return LocalPlayer:IsFriendsWith(player.UserId) end) then
                skip = true
            end

            if not skip then
                local character = player.Character
                local root = safeCall(function() return createProxy(character:FindFirstChild("HumanoidRootPart")) end)
                local head = safeCall(function() return createProxy(character:FindFirstChild("Head")) end)
                local humanoid = safeCall(function() return createProxy(character:FindFirstChildOfClass("Humanoid")) end)

                if root and head and humanoid and safeCall(function() return humanoid.Health > 0 end) then
                    local distance = safeCall(function() return (root.Position - localRoot.Position).Magnitude end)
                    if distance and distance < closestDistance then
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
if hookmetamethod then
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = {...}

        if method == "Raycast" and not checkcaller() and self == Workspace and main.enable then
            local origin = args[1] or Camera.CFrame.Position
            local closestHead = safeCall(getClosestHead)
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
else
    warn("hookmetamethod not supported by this executor")
end

-- 拦截 __index 元方法，仅针对 Character 相关实例
if hookmetamethod then
    oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, key)
        if not checkcaller() and (key == "Position" or key == "CFrame" or key == "Health") then
            if safeCall(function() return self:IsA("BasePart") or self:IsA("Humanoid") end) then
                local proxy = safeCall(function() return createProxy(self) end)
                if proxy then
                    return proxy[key]
                end
            end
        end
        return oldIndex(self, key)
    end))
else
    warn("hookmetamethod not supported by this executor")
end

-- 加载 UI
local success, WindUI = pcall(function()
    return loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
end)
if not success then
    warn("Failed to load WindUI: " .. tostring(WindUI))
    return
end

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
    CornerRadius = UDim.new(0, 16),
    StrokeThickness = 2,
    Color = ColorSequence.new(
        Color3.fromHex("FF0F7B"), 
        Color3.fromHex("F89B29")
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
    if not main.enable then return end
    local dummy = math.random(1, 1000)
    if LocalPlayer.Character then
        local humanoid = safeCall(function() return LocalPlayer.Character:FindFirstChildOfClass("Humanoid") end)
        if humanoid then
            safeCall(function() humanoid.WalkSpeed = 16 + math.random(-0.05, 0.05) end)
        end
    end
end

-- 降低频率的反检测
game:GetService("RunService").Stepped:Connect(function()
    if main.enable and math.random() < 0.1 then
        safeCall(antiDetect)
    end
end)
