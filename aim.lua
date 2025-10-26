-- 多功能版
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- 配置
local main = {
    enable = false,          -- 玩家子弹追踪
    teamcheck = false,       -- 队伍检查
    friendcheck = false,     -- 好友检查
    enablenpc = false,       -- NPC 子弹追踪
    maxDistance = 500,       -- 最大追踪距离（世界单位）
    updateRate = 0.12        -- 搜索更新频率（秒）——调小更灵敏但消耗更高
}

-- 缓存（由 Heartbeat 周期更新）
local cachedPlayerHead = nil
local cachedPlayerHeadPos = nil
local cachedPlayerDistSq = math.huge

local cachedNpcHead = nil
local cachedNpcHeadPos = nil
local cachedNpcDistSq = math.huge

-- 连接句柄（防止重复连接）
local heartbeatConn = nil

-- 初始化提示
local function initialize()
    print("初始化成功")
end

-- 安全的玩家判断（检查是否活着并可用）
local function isValidPlayerCharacter(character)
    if not character then return false end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    local head = character:FindFirstChild("Head")
    if not hrp or not head then return false end
    return true
end

-- Heartbeat 更新函数：周期性扫描并更新最近玩家与 NPC 的头部（只做轻量运算）
local function startCaching()
    if heartbeatConn and heartbeatConn.Connected then return end

    heartbeatConn = RunService.Heartbeat:Connect(function(dt)
        -- 仅在至少开启一项功能时才搜索，避免不必要开销
        if not main.enable and not main.enablenpc then
            cachedPlayerHead = nil
            cachedNpcHead = nil
            cachedPlayerDistSq = math.huge
            cachedNpcDistSq = math.huge
            return
        end

        -- 必要条件：本地角色存在且有 HRP
        if not LocalPlayer or not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            cachedPlayerHead = nil
            cachedNpcHead = nil
            cachedPlayerDistSq = math.huge
            cachedNpcDistSq = math.huge
            return
        end

        local localHrp = LocalPlayer.Character.HumanoidRootPart
        local maxDistSq = main.maxDistance * main.maxDistance

        -- 更新最近玩家头（如果启用）
        if main.enable then
            local bestHead = nil
            local bestDistSq = maxDistSq

            -- 遍历玩家（People count 通常比较少）
            for _, pl in ipairs(Players:GetPlayers()) do
                if pl ~= LocalPlayer and pl.Character and isValidPlayerCharacter(pl.Character) then
                    -- 队伍 / 好友 检查
                    if main.teamcheck and pl.Team == LocalPlayer.Team then
                        -- skip
                    elseif main.friendcheck and LocalPlayer:IsFriendsWith(pl.UserId) then
                        -- skip
                    else
                        local root = pl.Character:FindFirstChild("HumanoidRootPart")
                        local head = pl.Character:FindFirstChild("Head")
                        if root and head then
                            local diff = root.Position - localHrp.Position
                            local distSq = diff.X*diff.X + diff.Y*diff.Y + diff.Z*diff.Z
                            if distSq < bestDistSq then
                                bestDistSq = distSq
                                bestHead = head
                            end
                        end
                    end
                end
            end

            cachedPlayerHead = bestHead
            cachedPlayerHeadPos = bestHead and bestHead.Position or nil
            cachedPlayerDistSq = bestDistSq or math.huge
        else
            cachedPlayerHead = nil
            cachedPlayerHeadPos = nil
            cachedPlayerDistSq = math.huge
        end

        -- 更新最近 NPC 头（如果启用）
        if main.enablenpc then
            local bestHead = nil
            local bestDistSq = maxDistSq

            -- 遍历 Workspace 的一层或全部 descendants：
            -- 为了兼顾可靠性，这里使用 GetDescendants，但在非常庞大的场景下可以改为更有针对性的层级（以提升性能）
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("Model") then
                    local humanoid = obj:FindFirstChildOfClass("Humanoid")
                    local hrp = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart
                    local head = obj:FindFirstChild("Head")
                    if humanoid and hrp and head and humanoid.Health > 0 then
                        -- 确保这个 Model 不是任何玩家的角色
                        local isPlayerModel = false
                        -- 由于 Players 表通常较小，这里用循环判断是合理的
                        for _, pl in ipairs(Players:GetPlayers()) do
                            if pl.Character == obj then
                                isPlayerModel = true
                                break
                            end
                        end
                        if not isPlayerModel then
                            local diff = hrp.Position - localHrp.Position
                            local distSq = diff.X*diff.X + diff.Y*diff.Y + diff.Z*diff.Z
                            if distSq < bestDistSq then
                                bestDistSq = distSq
                                bestHead = head
                            end
                        end
                    end
                end
            end

            cachedNpcHead = bestHead
            cachedNpcHeadPos = bestHead and bestHead.Position or nil
            cachedNpcDistSq = bestDistSq or math.huge
        else
            cachedNpcHead = nil
            cachedNpcHeadPos = nil
            cachedNpcDistSq = math.huge
        end
    end)
end

-- 停止缓存连接（当脚本卸载或不再需要时可调用）
local function stopCaching()
    if heartbeatConn then
        heartbeatConn:Disconnect()
        heartbeatConn = nil
    end
    cachedPlayerHead = nil
    cachedNpcHead = nil
    cachedPlayerDistSq = math.huge
    cachedNpcDistSq = math.huge
end

-- 启动初次缓存
startCaching()

-- 钩子 Raycast 方法（保持轻量）：只用缓存的数据，不再遍历大量对象
local old
old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    -- 只拦截 Raycast（且不是本脚本自身调用）
    if method == "Raycast" and not checkcaller() then
        local origin = args[1] or (Camera and Camera.CFrame and Camera.CFrame.Position) or Vector3.new()

        -- 优先玩家（如果启用且缓存中有目标且在 maxDistance 内）
        if main.enable and cachedPlayerHead and cachedPlayerHeadPos then
            -- 复原距离检查（使用平方距离）
            local diff = cachedPlayerHeadPos - origin
            local distSq = diff.X*diff.X + diff.Y*diff.Y + diff.Z*diff.Z
            if distSq <= (main.maxDistance * main.maxDistance) then
                -- 返回一个类似 RaycastResult 的表格（轻量）
                return {
                    Instance = cachedPlayerHead,
                    Position = cachedPlayerHeadPos,
                    Normal = (origin - cachedPlayerHeadPos).Unit,
                    Material = Enum.Material.Plastic,
                    Distance = math.sqrt(distSq)
                }
            end
        end

        -- 然后 NPC（如果启用）
        if main.enablenpc and cachedNpcHead and cachedNpcHeadPos then
            local diff = cachedNpcHeadPos - origin
            local distSq = diff.X*diff.X + diff.Y*diff.Y + diff.Z*diff.Z
            if distSq <= (main.maxDistance * main.maxDistance) then
                return {
                    Instance = cachedNpcHead,
                    Position = cachedNpcHeadPos,
                    Normal = (origin - cachedNpcHeadPos).Unit,
                    Material = Enum.Material.Plastic,
                    Distance = math.sqrt(distSq)
                }
            end
        end
    end

    -- 不是我们关心的情况，继续原始调用
    return old(self, ...)
end))

-- 加载 UI 库
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

-- 创建 UI 窗口（保持原样）
local Window = WindUI:CreateWindow({
    Title = "子弹追踪",
    Icon = "rbxassetid://129260712070622",
    IconThemed = true,
    Author = "idk",
    Folder = "CloudHub",
    Size = UDim2.fromOffset(300, 300),
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

local MainSection = Window:Section({
    Title = "子追",
    Opened = true,
})

local Main = MainSection:Tab({ Title = "设置", Icon = "Sword" })

Main:Button({
    Title = "初始化",
    Image = "gear",
    Callback = function()
        initialize()
    end
})

Main:Toggle({
    Title = "开启玩家子弹追踪",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.enable = state
        -- 当任一功能开启时确保缓存运行；全部关闭时停止缓存
        if main.enable or main.enablenpc then
            startCaching()
        else
            stopCaching()
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

Main:Toggle({
    Title = "开启NPC子弹追踪",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.enablenpc = state
        if main.enable or main.enablenpc then
            startCaching()
        else
            stopCaching()
        end
    end
})
