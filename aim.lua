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
local proxyCache = setmetatable({}, { __mode = "k" })
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
local TARGET_UPDATE_RATE = 6 -- 每秒更新次数（可调：2~10）
local cachedHead = nil
local lastUpdateTime = 0
local accum = 0

local function computeClosestHead()
    local closestHead
    local closestDistance = math.huge

    if not LocalPlayer.Character then return nil end
    local localRoot = safeCall(function() return LocalPlayer.Character:FindFirstChild("HumanoidRootPart") end)
    if not localRoot then return nil end
    local localPos = localRoot.Position

    -- 避免大量 pcall：对外层主要逻辑使用较少的 pcall
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local skip = false

            if main.teamcheck then
                local ok, sameTeam = pcall(function() return player.Team == LocalPlayer.Team end)
                if ok and sameTeam then skip = true end
            end

            if not skip and main.friendcheck then
                local ok, isFriend = pcall(function() return LocalPlayer:IsFriendsWith(player.UserId) end)
                if ok and isFriend then skip = true end
            end

            if not skip then
                local character = player.Character
                local root = character:FindFirstChild("HumanoidRootPart")
                local head = character:FindFirstChild("Head")
                local humanoid = character:FindFirstChildOfClass("Humanoid")

                if root and head and humanoid and humanoid.Health > 0 then
                    local distance = (root.Position - localPos).Magnitude
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
--（优化：只拦截从摄像机 origin 发起的射线；限制拦截频率；使用缓存并避免每次分配大量对象）
local lastIntercept = 0
local INTERCEPT_MIN_INTERVAL = 1 / 60 -- 最多每秒拦截 60 次（可调：降低到 30 或更少）
local ORIGIN_EPSILON = 0.5 -- origin 与 Camera 位置差距允许值（米）

if hookmetamethod then
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = {...}

        if method == "Raycast" and not checkcaller() and self == Workspace and main.enable then
            local origin = args[1] or (Camera and Camera.CFrame.Position)
            if not origin then
                return oldNamecall(self, ...)
            end

            -- 限制只处理摄像机发起或非常接近摄像机的 origin（减少误拦截）
            local camPos = Camera and Camera.CFrame and Camera.CFrame.Position
            if not camPos then
                return oldNamecall(self, ...)
            end
            if (origin - camPos).Magnitude > ORIGIN_EPSILON then
                return oldNamecall(self, ...)
            end

            -- 限制拦截频率，避免热路径过于频繁
            local now = tick()
            if now - lastIntercept < INTERCEPT_MIN_INTERVAL then
                return oldNamecall(self, ...)
            end
            lastIntercept = now

            local closestHeadInst = safeCall(function() return getClosestHead(false) end)
            if closestHeadInst then
                -- 直接使用真实实例位置（避免频繁 newproxy）
                local ok, headPos = pcall(function() return closestHeadInst.Position end)
                if ok and headPos then
                    -- 轻微抖动以模拟不完美瞄准
                    local jitter = Vector3.new(math.random() * 0.1 - 0.05, math.random() * 0.1 - 0.05, math.random() * 0.1 - 0.05)
                    local hitPos = headPos + jitter
                    local normal = (origin - headPos)
                    if normal.Magnitude > 0 then normal = normal.Unit else normal = Vector3.new(0,1,0) end
                    return {
                        Instance = closestHeadInst,
                        Position = hitPos,
                        Normal = normal,
                        Material = Enum.Material.Plastic,
                        Distance = (hitPos - origin).Magnitude
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
--（收紧拦截：绝不拦截 Camera 或 LocalPlayer 的部件；只对非本地玩家的 BasePart/Humanoid 代理）
if hookmetamethod then
    oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, key)
        -- 保护摄像机及本地角色：不代理它们，直接返回原始值
        local okCamera, isCameraDesc = pcall(function() return typeof(self) == "Instance" and self:IsDescendantOf(Camera) end)
        if okCamera and isCameraDesc then
            return oldIndex(self, key)
        end

        local okLocal, isLocalDesc = pcall(function()
            if LocalPlayer and LocalPlayer.Character and typeof(self) == "Instance" then
                return self:IsDescendantOf(LocalPlayer.Character)
            end
            return false
        end)
        if okLocal and isLocalDesc then
            return oldIndex(self, key)
        end

        -- 仅在非本地的 BasePart 或 Humanoid 上代理 Position/CFrame/Health
        if not checkcaller() and (key == "Position" or key == "CFrame" or key == "Health") then
            local isa = safeCall(function() return self:IsA and (self:IsA("BasePart") or self:IsA("Humanoid")) end)
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
RunService.Heartbeat:Connect(function()
    if main.enable and math.random() < 0.06 then
        safeCall(antiDetect)
    end
end)
