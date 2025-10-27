local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local oldNamecall, oldIndex
local RunService = game:GetService("RunService")

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
--（优化：复用 proxy，使用弱键表避免重复 newproxy）
local proxyCache = setmetatable({}, { __mode = "k" }) -- 弱键表：键为原实例
local function createProxy(instance)
    if not instance then return nil end
    if proxyCache[instance] then
        return proxyCache[instance]
    end
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

    proxyCache[instance] = proxy
    return proxy
end

-- 获取最近的玩家头部
--（优化：节流 + 单独周期更新缓存，避免在每次 Raycast 中做完整遍历）
local TARGET_UPDATE_RATE = 8 -- 每秒更新目标次数（可按需降低，例如 4 或 增大到 15）
local cachedHead = nil
local lastUpdateTime = 0
local accum = 0

local function computeClosestHead()
    local closestHead
    local closestDistance = math.huge

    if not LocalPlayer.Character then return nil end
    local localRoot = safeCall(function() return LocalPlayer.Character:FindFirstChild("HumanoidRootPart") end)
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
                local root = safeCall(function() return character:FindFirstChild("HumanoidRootPart") end)
                local head = safeCall(function() return character:FindFirstChild("Head") end)
                local humanoid = safeCall(function() return character:FindFirstChildOfClass("Humanoid") end)

                if root and head and humanoid and safeCall(function() return humanoid.Health > 0 end) then
                    local success, distance = pcall(function()
                        return (root.Position - localRoot.Position).Magnitude
                    end)
                    if success and distance and distance < closestDistance then
                        -- 只缓存真实实例（创建 proxy 留给需要时）
                        closestHead = head
                        closestDistance = distance
                    end
                end
            end
        end
    end
    return closestHead
end

local function getClosestHead(force)
    local now = tick()
    if not force and cachedHead and (now - lastUpdateTime) < (1 / TARGET_UPDATE_RATE) then
        return cachedHead
    end
    local newHead = safeCall(computeClosestHead)
    cachedHead = newHead
    lastUpdateTime = now
    return cachedHead
end

-- 周期性更新缓存（降低 Raycast 热路径重复计算）
RunService.Heartbeat:Connect(function(dt)
    if not main.enable then return end
    accum = accum + dt
    local interval = 1 / TARGET_UPDATE_RATE
    if accum >= interval then
        safeCall(function()
            cachedHead = computeClosestHead()
            lastUpdateTime = tick()
        end)
        accum = accum - interval
        if accum < 0 then accum = 0 end
    end
end)

-- 钩子元方法：拦截 Raycast
if hookmetamethod then
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = {...}

        if method == "Raycast" and not checkcaller() and self == Workspace and main.enable then
            local origin = args[1] or (Camera and Camera.CFrame.Position)
            local closestHeadInst = safeCall(function() return getClosestHead(false) end)
            if closestHeadInst then
                local headProxy = safeCall(function() return createProxy(closestHeadInst) end) or closestHeadInst
                local success, pos = pcall(function() return headProxy.Position end)
                if success and pos then
                    return {
                        Instance = closestHeadInst,
                        Position = pos + Vector3.new(math.random(-0.05, 0.05), math.random(-0.05, 0.05), math.random(-0.05, 0.05)),
                        Normal = (origin - pos).Unit,
                        Material = Enum.Material.Plastic,
                        Distance = (pos - origin).Magnitude
                    }
                end
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
        -- 排除 Camera 相关实例，防止摄像机读取被代理导致的不同步
        local isCameraDescendant = false
        local ok, res = pcall(function()
            return typeof(self) == "Instance" and self:IsDescendantOf(Camera)
        end)
        if ok and res then
            return oldIndex(self, key)
        end

        if not checkcaller() and (key == "Position" or key == "CFrame" or key == "Health") then
            local isa = safeCall(function() return self:IsA("BasePart") or self:IsA("Humanoid") end)
            if isa then
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
        -- 当关闭时清空缓存
        if not state then
            cachedHead = nil
            lastUpdateTime = 0
        else
            -- 强制立即计算一次，避免第一次射击卡顿
            safeCall(function() cachedHead = computeClosestHead(); lastUpdateTime = tick() end)
        end
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
--（把 Stepped 换成 Heartbeat，频率更稳定）
RunService.Heartbeat:Connect(function()
    if main.enable and math.random() < 0.06 then
        safeCall(antiDetect)
    end
end)
