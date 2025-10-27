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
--（优化：复用 proxy，使用弱键表避免重复 newproxy，并只为严格符合条件的实例创建 proxy）
local proxyCache = setmetatable({}, { __mode = "k" }) -- 弱键表：键为原实例
local function shouldProxyInstance(inst)
    -- 严格判断：必须是 Instance、属于某个 Character（Model），并且该 Character 有对应玩家且不是本地玩家
    if not inst or type(inst) ~= "userdata" then return false end
    local ok, res = pcall(function()
        if not inst:IsA("Instance") then return false end
        -- 排除 UI / 脚本 / Camera 等
        if inst:IsDescendantOf(Camera) then return false end
        if LocalPlayer and LocalPlayer.Character and inst:IsDescendantOf(LocalPlayer.Character) then return false end
        if LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") and inst:IsDescendantOf(LocalPlayer:FindFirstChild("PlayerGui")) then return false end
        if LocalPlayer and LocalPlayer:FindFirstChild("PlayerScripts") and inst:IsDescendantOf(LocalPlayer:FindFirstChild("PlayerScripts")) then return false end
        -- 只针对 BasePart 或 Humanoid
        if not (inst:IsA("BasePart") or inst:IsA("Humanoid")) then return false end
        local parentModel = inst.Parent
        if not parentModel or not parentModel:IsA("Model") then return false end
        -- 模型必须关联到玩家且不是本地玩家
        local player = Players:GetPlayerFromCharacter(parentModel)
        if not player or player == LocalPlayer then return false end
        return true
    end)
    return ok and res
end

local function createProxy(instance)
    if not instance then return nil end
    if proxyCache[instance] then
        return proxyCache[instance]
    end
    -- 只有严格通过 shouldProxyInstance 的实例才会创建 proxy
    if not shouldProxyInstance(instance) then
        return nil
    end
    local proxy = newproxy(true)
    local mt = getmetatable(proxy)

    mt.__index = function(_, key)
        -- 只代理这些关键属性，其他全部透传给真实实例（避免破坏外部脚本逻辑）
        if key == "Position" or key == "CFrame" or key == "Health" then
            return safeCall(function() return instance[key] end)
        end
        -- 对于尝试读取 Name 等，直接返回真实值，避免 nil 导致其它脚本出错
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

    if not LocalPlayer or not LocalPlayer.Character then return nil end
    local localRoot = safeCall(function() return LocalPlayer.Character:FindFirstChild("HumanoidRootPart") end)
    if not localRoot then return nil end
    local localPos = localRoot.Position

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
                -- 只读取必要部件，避免触发 __index 钩子（我们会直接访问实例）
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
local lastIntercept = 0
local INTERCEPT_MIN_INTERVAL = 1 / 60 -- 最多每秒拦截 60 次（可调）
local ORIGIN_EPSILON = 0.5 -- origin 与 Camera 位置差距允许值（米）

if hookmetamethod then
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = {...}

        if method == "Raycast" and not checkcaller() and self == Workspace and main.enable then
            local origin = args[1] or (Camera and Camera.CFrame and Camera.CFrame.Position)
            if not origin then
                return oldNamecall(self, ...)
            end

            local camPos = Camera and Camera.CFrame and Camera.CFrame.Position
            if not camPos then
                return oldNamecall(self, ...)
            end
            if (origin - camPos).Magnitude > ORIGIN_EPSILON then
                return oldNamecall(self, ...)
            end

            local now = tick()
            if now - lastIntercept < INTERCEPT_MIN_INTERVAL then
                return oldNamecall(self, ...)
            end
            lastIntercept = now

            local closestHeadInst = safeCall(function() return getClosestHead(false) end)
            if closestHeadInst and typeof(closestHeadInst) == "Instance" then
                local ok, headPos = pcall(function() return closestHeadInst.Position end)
                if ok and headPos then
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

-- 拦截 __index 元方法，仅针对 Character 相关实例（严格版）
--（收紧拦截：绝不拦截 Camera / LocalPlayer 的部件 / PlayerGui / PlayerScripts / UI；只对非本地玩家 Character 下的 BasePart/Humanoid 进行代理）
if hookmetamethod then
    oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, key)
        -- 保护 Camera：不代理 Camera 及其子孙
        local okCamera, isCameraDesc = pcall(function() return typeof(self) == "Instance" and self:IsDescendantOf(Camera) end)
        if okCamera and isCameraDesc then
            return oldIndex(self, key)
        end

        -- 保护本地角色：任何属于本地 Character 的实例不代理
        local okLocalChar, isLocalCharDesc = pcall(function()
            if LocalPlayer and LocalPlayer.Character and typeof(self) == "Instance" then
                return self:IsDescendantOf(LocalPlayer.Character)
            end
            return false
        end)
        if okLocalChar and isLocalCharDesc then
            return oldIndex(self, key)
        end

        -- 保护本地 PlayerGui / PlayerScripts（避免 UI 报错）
        local okGui, isLocalGuiDesc = pcall(function()
            if LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") and typeof(self) == "Instance" then
                return self:IsDescendantOf(LocalPlayer.PlayerGui)
            end
            return false
        end)
        if okGui and isLocalGuiDesc then
            return oldIndex(self, key)
        end

        local okPS, isLocalPSDesc = pcall(function()
            if LocalPlayer and LocalPlayer:FindFirstChild("PlayerScripts") and typeof(self) == "Instance" then
                return self:IsDescendantOf(LocalPlayer.PlayerScripts)
            end
            return false
        end)
        if okPS and isLocalPSDesc then
            return oldIndex(self, key)
        end

        -- 仅在非常严格的条件下才代理：非本地玩家的 Character 下的 BasePart 或 Humanoid
        if not checkcaller() and (key == "Position" or key == "CFrame" or key == "Health") then
            local isa = safeCall(function() return typeof(self) == "Instance" and (self:IsA("BasePart") or self:IsA("Humanoid")) end)
            if not isa then
                return oldIndex(self, key)
            end

            -- 确认 parent 是 Character 且关联玩家不是本地玩家
            local okParent, parentRes = pcall(function() return typeof(self) == "Instance" and self.Parent end)
            if not okParent or not parentRes or not parentRes:IsA("Model") then
                return oldIndex(self, key)
            end

            local okGetPlayer, ownerPlayer = pcall(function() return Players:GetPlayerFromCharacter(parentRes) end)
            if not okGetPlayer or not ownerPlayer or ownerPlayer == LocalPlayer then
                return oldIndex(self, key)
            end

            -- 经过所有严格检查后，尝试从 proxy（若创建）返回值
            local proxy = safeCall(function() return createProxy(self) end)
            if proxy then
                -- 只返回被代理的关键属性，其他访问继续回退到原始 __index（保持兼容性）
                local okVal, val = pcall(function() return proxy[key] end)
                if okVal then
                    return val
                else
                    return oldIndex(self, key)
                end
            end
        end

        return oldIndex(self, key)
    end))
else
    warn("hookmetamethod not supported by this executor")
end

-- 加载 UI（保留你要求的简洁两行加载方式）
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
end)local Workspace = game:GetService("Workspace")
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
--（优化：复用 proxy，使用弱键表避免重复 newproxy，并只为严格符合条件的实例创建 proxy）
local proxyCache = setmetatable({}, { __mode = "k" }) -- 弱键表：键为原实例
local function shouldProxyInstance(inst)
    -- 严格判断：必须是 Instance、属于某个 Character（Model），并且该 Character 有对应玩家且不是本地玩家
    if not inst or type(inst) ~= "userdata" then return false end
    local ok, res = pcall(function()
        if not inst:IsA("Instance") then return false end
        -- 排除 UI / 脚本 / Camera 等
        if inst:IsDescendantOf(Camera) then return false end
        if LocalPlayer and LocalPlayer.Character and inst:IsDescendantOf(LocalPlayer.Character) then return false end
        if LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") and inst:IsDescendantOf(LocalPlayer:FindFirstChild("PlayerGui")) then return false end
        if LocalPlayer and LocalPlayer:FindFirstChild("PlayerScripts") and inst:IsDescendantOf(LocalPlayer:FindFirstChild("PlayerScripts")) then return false end
        -- 只针对 BasePart 或 Humanoid
        if not (inst:IsA("BasePart") or inst:IsA("Humanoid")) then return false end
        local parentModel = inst.Parent
        if not parentModel or not parentModel:IsA("Model") then return false end
        -- 模型必须关联到玩家且不是本地玩家
        local player = Players:GetPlayerFromCharacter(parentModel)
        if not player or player == LocalPlayer then return false end
        return true
    end)
    return ok and res
end

local function createProxy(instance)
    if not instance then return nil end
    if proxyCache[instance] then
        return proxyCache[instance]
    end
    -- 只有严格通过 shouldProxyInstance 的实例才会创建 proxy
    if not shouldProxyInstance(instance) then
        return nil
    end
    local proxy = newproxy(true)
    local mt = getmetatable(proxy)

    mt.__index = function(_, key)
        -- 只代理这些关键属性，其他全部透传给真实实例（避免破坏外部脚本逻辑）
        if key == "Position" or key == "CFrame" or key == "Health" then
            return safeCall(function() return instance[key] end)
        end
        -- 对于尝试读取 Name 等，直接返回真实值，避免 nil 导致其它脚本出错
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

    if not LocalPlayer or not LocalPlayer.Character then return nil end
    local localRoot = safeCall(function() return LocalPlayer.Character:FindFirstChild("HumanoidRootPart") end)
    if not localRoot then return nil end
    local localPos = localRoot.Position

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
                -- 只读取必要部件，避免触发 __index 钩子（我们会直接访问实例）
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
local lastIntercept = 0
local INTERCEPT_MIN_INTERVAL = 1 / 60 -- 最多每秒拦截 60 次（可调）
local ORIGIN_EPSILON = 0.5 -- origin 与 Camera 位置差距允许值（米）

if hookmetamethod then
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = {...}

        if method == "Raycast" and not checkcaller() and self == Workspace and main.enable then
            local origin = args[1] or (Camera and Camera.CFrame and Camera.CFrame.Position)
            if not origin then
                return oldNamecall(self, ...)
            end

            local camPos = Camera and Camera.CFrame and Camera.CFrame.Position
            if not camPos then
                return oldNamecall(self, ...)
            end
            if (origin - camPos).Magnitude > ORIGIN_EPSILON then
                return oldNamecall(self, ...)
            end

            local now = tick()
            if now - lastIntercept < INTERCEPT_MIN_INTERVAL then
                return oldNamecall(self, ...)
            end
            lastIntercept = now

            local closestHeadInst = safeCall(function() return getClosestHead(false) end)
            if closestHeadInst and typeof(closestHeadInst) == "Instance" then
                local ok, headPos = pcall(function() return closestHeadInst.Position end)
                if ok and headPos then
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

-- 拦截 __index 元方法，仅针对 Character 相关实例（严格版）
--（收紧拦截：绝不拦截 Camera / LocalPlayer 的部件 / PlayerGui / PlayerScripts / UI；只对非本地玩家 Character 下的 BasePart/Humanoid 进行代理）
if hookmetamethod then
    oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, key)
        -- 保护 Camera：不代理 Camera 及其子孙
        local okCamera, isCameraDesc = pcall(function() return typeof(self) == "Instance" and self:IsDescendantOf(Camera) end)
        if okCamera and isCameraDesc then
            return oldIndex(self, key)
        end

        -- 保护本地角色：任何属于本地 Character 的实例不代理
        local okLocalChar, isLocalCharDesc = pcall(function()
            if LocalPlayer and LocalPlayer.Character and typeof(self) == "Instance" then
                return self:IsDescendantOf(LocalPlayer.Character)
            end
            return false
        end)
        if okLocalChar and isLocalCharDesc then
            return oldIndex(self, key)
        end

        -- 保护本地 PlayerGui / PlayerScripts（避免 UI 报错）
        local okGui, isLocalGuiDesc = pcall(function()
            if LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") and typeof(self) == "Instance" then
                return self:IsDescendantOf(LocalPlayer.PlayerGui)
            end
            return false
        end)
        if okGui and isLocalGuiDesc then
            return oldIndex(self, key)
        end

        local okPS, isLocalPSDesc = pcall(function()
            if LocalPlayer and LocalPlayer:FindFirstChild("PlayerScripts") and typeof(self) == "Instance" then
                return self:IsDescendantOf(LocalPlayer.PlayerScripts)
            end
            return false
        end)
        if okPS and isLocalPSDesc then
            return oldIndex(self, key)
        end

        -- 仅在非常严格的条件下才代理：非本地玩家的 Character 下的 BasePart 或 Humanoid
        if not checkcaller() and (key == "Position" or key == "CFrame" or key == "Health") then
            local isa = safeCall(function() return typeof(self) == "Instance" and (self:IsA("BasePart") or self:IsA("Humanoid")) end)
            if not isa then
                return oldIndex(self, key)
            end

            -- 确认 parent 是 Character 且关联玩家不是本地玩家
            local okParent, parentRes = pcall(function() return typeof(self) == "Instance" and self.Parent end)
            if not okParent or not parentRes or not parentRes:IsA("Model") then
                return oldIndex(self, key)
            end

            local okGetPlayer, ownerPlayer = pcall(function() return Players:GetPlayerFromCharacter(parentRes) end)
            if not okGetPlayer or not ownerPlayer or ownerPlayer == LocalPlayer then
                return oldIndex(self, key)
            end

            -- 经过所有严格检查后，尝试从 proxy（若创建）返回值
            local proxy = safeCall(function() return createProxy(self) end)
            if proxy then
                -- 只返回被代理的关键属性，其他访问继续回退到原始 __index（保持兼容性）
                local okVal, val = pcall(function() return proxy[key] end)
                if okVal then
                    return val
                else
                    return oldIndex(self, key)
                end
            end
        end

        return oldIndex(self, key)
    end))
else
    warn("hookmetamethod not supported by this executor")
end

-- 加载 UI（保留你要求的简洁两行加载方式）
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
local Window = WindUI:CreateWindow({
    Title = "子弹追踪",
    Icon = "rbxassetid://129260712070622",
    IconThemed = true,
    Author = "idk"，
    Folder = "CloudHub",
    Size = UDim2.fromOffset(300， 270),
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
    Title = "打开UI"，
    Icon = "monitor",
    CornerRadius = UDim.new(0, 16),
    StrokeThickness = 2，
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
    Image = "bird"，
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
    Image = "bird"，
    Value = false,
    Callback = function(state)
        main.teamcheck = state
    end
})

Main:Toggle({
    Title = "开启好友验证",
    Image = "bird"，
    Value = false,
    Callback = function(state)
        main.friendcheck = state
    end
})

-- 优化反检测措施
local function antiDetect()
    if not main.enable then return end
    local dummy = math.random(1， 1000)
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
