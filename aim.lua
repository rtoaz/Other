local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local old

local main = {
    enable = false,
    teamcheck = false,
    friendcheck = false
}

local closestHead
local lastUpdate = 0
local UPDATE_INTERVAL = 0.05 -- 每 0.05 秒更新一次目标

-- 获取最近玩家头部
local function getClosestHead()
    local closest
    local shortest = math.huge

    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
    local localHrp = LocalPlayer.Character.HumanoidRootPart

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local skip = false
            if main.teamcheck and player.Team == LocalPlayer.Team then skip = true end
            if not skip and main.friendcheck and LocalPlayer:IsFriendsWith(player.UserId) then skip = true end
            if skip then continue end

            local hrp = player.Character:FindFirstChild("HumanoidRootPart")
            local head = player.Character:FindFirstChild("Head")
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")

            if hrp and head and humanoid and humanoid.Health > 0 then
                local dist = (hrp.Position - localHrp.Position).Magnitude
                if dist < shortest then
                    closest = head
                    shortest = dist
                end
            end
        end
    end
    return closest
end

-- Hook Raycast
old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if method == "Raycast" and not checkcaller() then
        if main.enable then
            local now = tick()
            if now - lastUpdate >= UPDATE_INTERVAL then
                closestHead = getClosestHead()
                lastUpdate = now
            end

            if closestHead and closestHead.Parent then
                local origin = args[1] or Camera.CFrame.Position
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
