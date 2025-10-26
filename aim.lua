-- 服务声明
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- 变量声明
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local old
local currentTargetHead = nil

-- 配置表
local main = {
    enable = false,
    teamcheck = false,
    friendcheck = false,
    enablenpc = false,
    continuousTracking = false
}

-- 获取最近的玩家头部
-- （实现已优化：后台周期更新缓存、平方距离、缓存玩家列表、尽量少调用 FindFirstChild）
local function _getClosestHead_internal(localHrp, playersList, maxSearchRadiusSq)
    local closestHead = nil
    local closestDistanceSq = math.huge
    if not localHrp then return nil end

    for i = 1, #playersList do
        local player = playersList[i]
        if player ~= LocalPlayer then
            local character = player.Character
            if character then
                local humanoid = character:FindFirstChildOfClass("Humanoid")
                local head = character:FindFirstChild("Head")
                local hrp = character:FindFirstChild("HumanoidRootPart")
                if humanoid and hrp and head and humanoid.Health > 0 then
                    local skip = false
                    if main.teamcheck and player.Team == LocalPlayer.Team then
                        skip = true
                    end
                    if not skip and main.friendcheck and LocalPlayer:IsFriendsWith(player.UserId) then
                        skip = true
                    end
                    if not skip then
                        local dx = hrp.Position.X - localHrp.Position.X
                        local dy = hrp.Position.Y - localHrp.Position.Y
                        local dz = hrp.Position.Z - localHrp.Position.Z
                        local distSq = dx*dx + dy*dy + dz*dz
                        if (not maxSearchRadiusSq or distSq <= maxSearchRadiusSq) and distSq < closestDistanceSq then
                            closestDistanceSq = distSq
                            closestHead = head
                        end
                    end
                end
            end
        end
    end

    return closestHead
end

local function _getClosestNpcHead_internal(localHrp, playersCharSet, maxSearchRadiusSq)
    local closestHead = nil
    local closestDistanceSq = math.huge
    if not localHrp then return nil end

    -- 遍历 Workspace 子项一次（GetDescendants 还是可能重，但只在后台周期做）
    local desc = Workspace:GetDescendants()
    for i = 1, #desc do
        local object = desc[i]
        if object:IsA("Model") then
            -- 跳过玩家角色
            if not playersCharSet[object] then
                local humanoid = object:FindFirstChildOfClass("Humanoid")
                if humanoid and humanoid.Health > 0 then
                    local hrp = object:FindFirstChild("HumanoidRootPart") or object.PrimaryPart
                    local head = object:FindFirstChild("Head")
                    if hrp and head then
                        local dx = hrp.Position.X - localHrp.Position.X
                        local dy = hrp.Position.Y - localHrp.Position.Y
                        local dz = hrp.Position.Z - localHrp.Position.Z
                        local distSq = dx*dx + dy*dy + dz*dz
                        if (not maxSearchRadiusSq or distSq <= maxSearchRadiusSq) and distSq < closestDistanceSq then
                            closestDistanceSq = distSq
                            closestHead = head
                        end
                    end
                end
            end
        end
    end

    return closestHead
end

-- 每帧更新目标头部位置
-- （注意：此函数将保留，但现在我们不在 RenderStepped 做昂贵遍历）
local function updateTarget()
    if main.continuousTracking then
        if main.enable then
            currentTargetHead = currentTargetHead -- 背景循环会更新缓存，不在这里做遍历
        elseif main.enablenpc then
            currentTargetHead = currentTargetHead
        else
            currentTargetHead = nil
        end
    else
        currentTargetHead = nil
    end
end

-- 连接到 RenderStepped 以持续更新目标
RunService.RenderStepped:Connect(updateTarget)

-- 修改 Raycast 钩子以支持持续追踪
-- （优化：不在钩子内进行遍历；使用可复用表以降低分配）
do
    -- 可配置：后台目标更新间隔（秒），增大以减少卡顿（默认 0.12），测试时可设 0.2-0.5
    local targetUpdateInterval = 0.12
    local maxSearchRadius = 1000 -- 可选限制，设为 nil 表示不限制
    local maxSearchRadiusSq = maxSearchRadius and (maxSearchRadius * maxSearchRadius) or nil

    -- 缓存 Players 列表并监听变更，避免频繁调用 GetPlayers()
    local playersList = {}
    local playersCharSet = {}

    local function rebuildPlayersCache()
        playersList = Players:GetPlayers()
        playersCharSet = {}
        for i = 1, #playersList do
            local pl = playersList[i]
            if pl.Character then
                playersCharSet[pl.Character] = true
            end
        end
    end

    rebuildPlayersCache()
    Players.PlayerAdded:Connect(function(pl)
        table.insert(playersList, pl)
        if pl.Character then playersCharSet[pl.Character] = true end
        pl.CharacterAdded:Connect(function(char) playersCharSet[char] = true end)
        pl.CharacterRemoving:Connect(function(char) playersCharSet[char] = nil end)
    end)
    Players.PlayerRemoving:Connect(function(pl)
        for i = #playersList, 1, -1 do
            if playersList[i] == pl then
                table.remove(playersList, i)
                break
            end
        end
    end)

    -- 监听本地角色变化以保持 localHrp 引用
    local localHrp = (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")) or nil
    if LocalPlayer.Character then
        if LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            localHrp = LocalPlayer.Character.HumanoidRootPart
        end
    end
    LocalPlayer.CharacterAdded:Connect(function(char)
        task.wait(0.05)
        if char and char:FindFirstChild("HumanoidRootPart") then
            localHrp = char:FindFirstChild("HumanoidRootPart")
        end
    end)
    LocalPlayer.CharacterRemoving:Connect(function(char)
        if localHrp and char == LocalPlayer.Character then
            localHrp = nil
        end
    end)

    -- 后台循环异步更新 currentTargetHead（绝不阻塞主线程）
    task.spawn(function()
        while true do
            local enabled = main.enable or main.enablenpc
            if enabled and localHrp then
                -- 重新构建玩家角色集合以判断 NPC
                playersCharSet = {}
                for i = 1, #playersList do
                    local pl = playersList[i]
                    if pl.Character then playersCharSet[pl.Character] = true end
                end

                if main.enable and not main.enablenpc then
                    currentTargetHead = _getClosestHead_internal(localHrp, playersList, maxSearchRadiusSq)
                elseif main.enablenpc and not main.enable then
                    currentTargetHead = _getClosestNpcHead_internal(localHrp, playersCharSet, maxSearchRadiusSq)
                else
                    -- 当 enable 和 enablenpc 同时为 true 时优先玩家
                    if main.enable then
                        currentTargetHead = _getClosestHead_internal(localHrp, playersList, maxSearchRadiusSq) or _getClosestNpcHead_internal(localHrp, playersCharSet, maxSearchRadiusSq)
                    else
                        currentTargetHead = nil
                    end
                end
            else
                currentTargetHead = nil
            end

            task.wait(targetUpdateInterval)
        end
    end)

    -- 复用的虚拟 Raycast 返回表，避免每次分配
    local reusableRayResult = {
        Instance = nil,
        Position = Vector3.new(0,0,0),
        Normal = Vector3.new(0,1,0),
        Material = Enum.Material.Plastic,
        Distance = 0
    }

    old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = {...}

        if method == "Raycast" and not checkcaller() then
            local origin = args[1] or (Camera and Camera.CFrame and Camera.CFrame.Position) or Vector3.new(0,0,0)

            -- 仅使用已缓存的目标（由后台循环周期性更新）
            if currentTargetHead and (main.enable or main.enablenpc) then
                local headPos = currentTargetHead.Position
                local diffX = origin.X - headPos.X
                local diffY = origin.Y - headPos.Y
                local diffZ = origin.Z - headPos.Z
                local normal = Vector3.new(diffX, diffY, diffZ)
                local dist = math.sqrt(diffX*diffX + diffY*diffY + diffZ*diffZ)

                if normal.Magnitude > 0 then
                    normal = normal.Unit
                else
                    normal = Vector3.new(0,1,0)
                end

                reusableRayResult.Instance = currentTargetHead
                reusableRayResult.Position = headPos
                reusableRayResult.Normal = normal
                reusableRayResult.Distance = dist
                reusableRayResult.Material = Enum.Material.Plastic

                return reusableRayResult
            end
        end

        return old(self, ...)
    end))
end

-- UI 创建
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

-- UI 界面设置
MainSection = Window:Section({
    Title = "子追",
    Opened = true,
})

Main = MainSection:Tab({
    Title = "设置",
    Icon = "Sword"
})

-- 功能开关
Main:Toggle({
    Title = "开启子弹追踪",
    Image = "bird",
    Value = false,
    Callback = function(state) 
        main.enable = state
        -- 立即触发一次后台更新（通过改写 localHrp 的方式或让后台循环即时生效）
    end
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

Main:Toggle({
    Title = "开启NPC子弹追踪",
    Image = "bird",
    Value = false,
    Callback = function(state) main.enablenpc = state end
})

Main:Toggle({
    Title = "开启持续追踪",
    Image = "bird",
    Value = false,
    Callback = function(state) main.continuousTracking = state end
})
