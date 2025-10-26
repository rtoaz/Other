-- 多功能版
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- 设置
local main = {
    enable = false,
    teamcheck = false,
    friendcheck = false
}

-- 使用 UserId 作为键，避免持有玩家对象导致引用问题
local PlayerParts = {} -- [userId] = { Root = Instance, Head = Instance, Humanoid = Instance, Alive = bool }
local function clearPartsForUserId(uid)
    PlayerParts[uid] = nil
end

-- 安全尝试等待子项（避免无限等待）
local function safeWaitForChild(parent, name, timeout)
    local success, inst = pcall(function()
        return parent:WaitForChild(name, timeout)
    end)
    if success then return inst end
    return nil
end

-- 更新单名玩家缓存（在 CharacterAdded / Humanoid 死亡 / PlayerRemoving 时使用）
local function cacheCharacterParts(player)
    if not player then return end
    local uid = player.UserId
    PlayerParts[uid] = nil

    if not player.Character then return end
    local char = player.Character

    -- 尝试安全等待必要部件（短超时）
    local root = safeWaitForChild(char, "HumanoidRootPart", 2)
    local head = safeWaitForChild(char, "Head", 2)
    local humanoid = nil
    local ok, h = pcall(function() return char:FindFirstChildOfClass("Humanoid") end)
    if ok then humanoid = h end

    if root and head and humanoid and humanoid.Health > 0 then
        PlayerParts[uid] = {Root = root, Head = head, Humanoid = humanoid, Alive = true, Player = player}
        -- 当 Humanoid 死亡或移除时清理缓存
        local conn
        conn = humanoid.Died:Connect(function()
            if conn then conn:Disconnect() end
            if PlayerParts[uid] then PlayerParts[uid].Alive = false end
        end)
    else
        PlayerParts[uid] = nil
    end
end

-- 监听玩家加入/离开/重生，维护缓存
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        -- small delay to allow parts to exist, then cache
        task.defer(function()
            cacheCharacterParts(player)
        end)
    end)
    -- if player already has character
    if player.Character then
        task.defer(function()
            cacheCharacterParts(player)
        end)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    clearPartsForUserId(player.UserId)
end)

-- 初始化现有玩家缓存
for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        if player.Character then
            cacheCharacterParts(player)
        end
        player.CharacterAdded:Connect(function()
            task.defer(function()
                cacheCharacterParts(player)
            end)
        end)
    end
end

-- === 背景更新最接近头部（节流） ===
local aimTargetHead = nil   -- Instance (Head)
local aimTargetPos = nil    -- Vector3
local updateInterval = 0.08 -- 80ms 更新一次（12.5Hz），可调
local lastUpdate = 0

-- 计算最近头的函数（只在心跳循环内运行）
local function computeClosestHead()
    if not LocalPlayer or not LocalPlayer.Character then
        aimTargetHead = nil
        aimTargetPos = nil
        return
    end
    local myRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot then
        aimTargetHead = nil
        aimTargetPos = nil
        return
    end

    local myPos = myRoot.Position
    local bestHead = nil
    local bestDist = math.huge

    for uid, parts in pairs(PlayerParts) do
        if parts and parts.Alive and parts.Root and parts.Head and parts.Humanoid and parts.Player then
            local player = parts.Player
            -- 跳过自己或者无效玩家
            if player ~= LocalPlayer then
                -- 队伍过滤
                if main.teamcheck and player.Team == LocalPlayer.Team then
                    -- skip
                else
                    -- 好友过滤
                    if main.friendcheck and LocalPlayer:IsFriendsWith(player.UserId) then
                        -- skip
                    else
                        -- 当前生命值检查（避免死亡后残留）
                        local ok, health = pcall(function() return parts.Humanoid.Health end)
                        if ok and health and health > 0 then
                            local success, rootPos = pcall(function() return parts.Root.Position end)
                            if success and rootPos then
                                local dist = (rootPos - myPos).Magnitude
                                if dist < bestDist then
                                    bestDist = dist
                                    bestHead = parts.Head
                                end
                            end
                        else
                            -- 标记为不活跃，下一轮可能被清理
                            parts.Alive = false
                        end
                    end
                end
            end
        end
    end

    aimTargetHead = bestHead
    if bestHead then
        -- 捕获位置快照，避免在钩子内读取实例属性
        local ok, pos = pcall(function() return bestHead.Position end)
        aimTargetPos = (ok and pos) and pos or nil
    else
        aimTargetPos = nil
    end
end

-- 心跳循环：节流并持续维护 aimTarget
RunService.Heartbeat:Connect(function(dt)
    local now = tick()
    if now - lastUpdate >= updateInterval then
        computeClosestHead()
        lastUpdate = now
    end
end)

-- === Hook Raycast：钩子里只做最小读取 ===
-- 保存原始 hook 返回值
local oldHook = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    -- 仅处理 Raycast 且来自非脚本调用（防止对自己钩子造成影响）
    if method == "Raycast" and not checkcaller() then
        -- 如果未启用则调用原方法
        if not main.enable then
            return old(self, ...)
        end

        -- 如果有缓存的目标头并且有效，则返回伪造的 RaycastResult（结构化的 table）
        if aimTargetHead and aimTargetPos then
            -- origin 可以是在 args[1]，如果不存在则尝试相机位置
            local origin = args[1]
            if typeof(origin) ~= "Vector3" then
                if Camera and Camera.CFrame then
                    origin = Camera.CFrame.Position
                else
                    origin = Vector3.new(0,0,0)
                end
            end

            -- 计算 normal & distance 在外面尽量用缓存值
            local success, normal = pcall(function()
                local dir = origin - aimTargetPos
                return dir.Magnitude > 0 and dir.Unit or Vector3.new(0,1,0)
            end)
            local dist = (aimTargetPos - origin).Magnitude

            return {
                Instance = aimTargetHead,
                Position = aimTargetPos,
                Normal = success and normal or Vector3.new(0,1,0),
                Material = Enum.Material.Plastic,
                Distance = dist
            }
        end
    end

    return old(self, ...)
end))

-- === WindUI（保持原有 UI，不影响性能） ===
local WindUILoadSuccess, WindUI = pcall(function()
    return loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
end)

if WindUILoadSuccess and WindUI then
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

    local MainSection = Window:Section({ Title = "子追", Opened = true })
    local Main = MainSection:Tab({ Title = "设置", Icon = "Sword" })

    Main:Toggle({
        Title = "开启子弹追踪",
        Image = "bird",
        Value = false,
        Callback = function(state) main.enable = state end
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
else
    warn("WindUI 加载失败，UI 将不可用")
end

-- 最后：提供手动清理入口（调试用）
_G.__CloudHub_Cleanup = function()
    -- 清理缓存与引用（不一定解除 hook）
    PlayerParts = {}
    aimTargetHead = nil
    aimTargetPos = nil
end
