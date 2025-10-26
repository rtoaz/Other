-- 多功能版（优化版）
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local old

-- 配置
local main = {
    enable = false,
    teamcheck = false,
    friendcheck = false
}

-- 缓存玩家部位
local PlayerParts = {}

local function updatePlayerParts(player)
    if player.Character then
        local root = player.Character:FindFirstChild("HumanoidRootPart")
        local head = player.Character:FindFirstChild("Head")
        local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
        if root and head and humanoid and humanoid.Health > 0 then
            PlayerParts[player] = {Root = root, Head = head, Humanoid = humanoid}
        else
            PlayerParts[player] = nil
        end
    else
        PlayerParts[player] = nil
    end
end

-- 初始化已有玩家
for _, player in ipairs(Players:GetPlayers()) do
    updatePlayerParts(player)
end

-- 玩家加入/离开
Players.PlayerAdded:Connect(updatePlayerParts)
Players.PlayerRemoving:Connect(function(player)
    PlayerParts[player] = nil
end)
-- 玩家重生时更新
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        updatePlayerParts(player)
    end)
end)
for _, player in ipairs(Players:GetPlayers()) do
    if player.Character then
        player.Character:WaitForChild("HumanoidRootPart", 5)
        updatePlayerParts(player)
        player.Character:WaitForChild("Humanoid", 5)
    end
    player.CharacterAdded:Connect(function()
        updatePlayerParts(player)
    end)
end

-- 节流最近头部计算
local closestCached = nil
local lastUpdate = 0
local updateInterval = 0.05 -- 每50ms更新一次

local function getClosestHead()
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
    local now = tick()
    if now - lastUpdate < updateInterval then
        return closestCached
    end

    local myRoot = LocalPlayer.Character.HumanoidRootPart.Position
    local closestHead = nil
    local closestDistance = math.huge

    for player, parts in pairs(PlayerParts) do
        if player ~= LocalPlayer and parts and parts.Humanoid.Health > 0 then
            if main.teamcheck and player.Team == LocalPlayer.Team then continue end
            if main.friendcheck and LocalPlayer:IsFriendsWith(player.UserId) then continue end

            local distance = (parts.Root.Position - myRoot).Magnitude
            if distance < closestDistance then
                closestDistance = distance
                closestHead = parts.Head
            end
        end
    end

    closestCached = closestHead
    lastUpdate = now
    return closestHead
end

-- Hook Raycast
old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if method == "Raycast" and not checkcaller() then
        local origin = args[1] or Camera.CFrame.Position

        if main.enable then
            local closestHead = getClosestHead()
            if closestHead then
                return {
                    Instance = closestHead,
                    Position = closestHead.Position,
                    Normal = (origin - closestHead.Position).Unit,
                    Material = Enum.Material.Plastic,
                    Distance = (closestHead.Position - origin).Magnitude
                }
            end
        end
    end

    return old(self, ...)
end))

-- WindUI
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
