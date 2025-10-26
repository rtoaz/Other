-- 多功能版（修复加载问题的完整脚本）
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Camera = Workspace.CurrentCamera

-- 必须在客户端（LocalScript）运行
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    warn("[子弹追踪] LocalPlayer 未找到 — 请在客户端 (LocalScript) 中运行此脚本。脚本停止加载。")
    return
end

-- 设置
local main = {
    enable = false,
    teamcheck = false,
    friendcheck = false
}

-- 使用 UserId 作为键，避免持有玩家对象导致引用问题
local PlayerParts = {} -- [userId] = { Root = Instance, Head = Instance, Humanoid = Instance, Alive = bool, Player = Player }

local function clearPartsForUserId(uid)
    PlayerParts[uid] = nil
end

local function safeWaitForChild(parent, name, timeout)
    local ok, result = pcall(function()
        return parent:WaitForChild(name, timeout)
    end)
    if ok then
        return result
    end
    return nil
end

local function cacheCharacterParts(player)
    if not player then return end
    local uid = player.UserId
    PlayerParts[uid] = nil

    if not player.Character then return end
    local char = player.Character

    local root = safeWaitForChild(char, "HumanoidRootPart", 2)
    local head = safeWaitForChild(char, "Head", 2)
    local humanoid
    pcall(function() humanoid = char:FindFirstChildOfClass("Humanoid") end)

    if root and head and humanoid and humanoid.Health > 0 then
        PlayerParts[uid] = {Root = root, Head = head, Humanoid = humanoid, Alive = true, Player = player}
        -- Humanoid 死亡时标记
        local conn
        conn = humanoid.Died:Connect(function()
            if conn then conn:Disconnect() end
            if PlayerParts[uid] then PlayerParts[uid].Alive = false end
        end)
    else
        PlayerParts[uid] = nil
    end
end

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        task.defer(function() cacheCharacterParts(player) end)
    end)
    if player.Character then
        task.defer(function() cacheCharacterParts(player) end)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    clearPartsForUserId(player.UserId)
end)

-- 初始化
for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        if player.Character then
            task.defer(function() cacheCharacterParts(player) end)
        end
        player.CharacterAdded:Connect(function()
            task.defer(function() cacheCharacterParts(player) end)
        end)
    end
end

-- 背景计算最近头（节流）
local aimTargetHead = nil
local aimTargetPos = nil
local updateInterval = 0.08 -- 80ms
local lastUpdate = 0

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
            if player ~= LocalPlayer then
                if main.teamcheck and player.Team == LocalPlayer.Team then
                    -- skip
                else
                    if main.friendcheck and LocalPlayer:IsFriendsWith(player.UserId) then
                        -- skip
                    else
                        local ok, health = pcall(function() return parts.Humanoid.Health end)
                        if ok and health and health > 0 then
                            local ok2, rootPos = pcall(function() return parts.Root.Position end)
                            if ok2 and rootPos then
                                local dist = (rootPos - myPos).Magnitude
                                if dist < bestDist then
                                    bestDist = dist
                                    bestHead = parts.Head
                                end
                            end
                        else
                            parts.Alive = false
                        end
                    end
                end
            end
        end
    end

    aimTargetHead = bestHead
    if bestHead then
        local ok, pos = pcall(function() return bestHead.Position end)
        aimTargetPos = (ok and pos) and pos or nil
    else
        aimTargetPos = nil
    end
end

RunService.Heartbeat:Connect(function(dt)
    local now = tick()
    if now - lastUpdate >= updateInterval then
        computeClosestHead()
        lastUpdate = now
    end
end)

-- Hook Raycast：注意正确保存旧的 namecall（避免 nil 问题）
local hookSucceeded = false
local oldNamecall

local ok, err = pcall(function()
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = {...}

        if method == "Raycast" and not checkcaller() then
            if not main.enable then
                return oldNamecall(self, ...)
            end

            if aimTargetHead and aimTargetPos then
                local origin = args[1]
                if typeof(origin) ~= "Vector3" then
                    if Camera and Camera.CFrame then
                        origin = Camera.CFrame.Position
                    else
                        origin = Vector3.new(0,0,0)
                    end
                end

                local success, normal = pcall(function()
                    local dir = origin - aimTargetPos
                    return (dir.Magnitude > 0) and dir.Unit or Vector3.new(0,1,0)
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

        return oldNamecall(self, ...)
    end))
end)

if ok and oldNamecall then
    hookSucceeded = true
else
    warn("[子弹追踪] 无法安装 hookmetamethod: "..tostring(err))
end

-- WindUI（安全加载）
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
    warn("[子弹追踪] WindUI 加载失败，UI 不可用: "..tostring(WindUI))
end

-- 调试/清理接口
_G.__CloudHub_Cleanup = function()
    PlayerParts = {}
    aimTargetHead = nil
    aimTargetPos = nil
    main.enable = false
    if hookSucceeded and oldNamecall then
        -- 无法安全移除 hookmetamethod，但你可以选择重置行为：关闭 enable 并清理缓存
        warn("[子弹追踪] 已清理缓存与禁用功能（hook 保持不变）。")
    end
end
