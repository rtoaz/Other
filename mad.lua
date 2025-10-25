local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
if not player then
    warn("[Script] LocalPlayer unavailable. Make sure this is a LocalScript (client).")
    return
end

print("[Script] Loaded for player:", player.Name)

-- 等待角色加载
if not player.Character then
    player.CharacterAdded:Wait()
end

-- 帮助函数
local function findRemoteByNameOrType(parent, name, className)
    if not parent then return nil end
    local obj = parent:FindFirstChild(name)
    if obj and obj:IsA(className) then return obj end
    for _,c in ipairs(parent:GetChildren()) do
        if c:IsA(className) then
            return c
        end
    end
    return nil
end

local remoteFunction = findRemoteByNameOrType(ReplicatedStorage, "RemoteFunction", "RemoteFunction")
local remoteEvent = findRemoteByNameOrType(ReplicatedStorage, "Event", "RemoteEvent")

-- 设置队伍逻辑
if remoteFunction and remoteFunction:IsA("RemoteFunction") then
    local ok, res = pcall(function()
        return remoteFunction:InvokeServer("SetTeam", "Police")
    end)
    if ok then
        print("[Script] Team set successfully:", res)
    else
        warn("[Script] SetTeam failed:", res)
    end
end

-- 手铐装备逻辑
local FIRE_INTERVAL = 1
local sinceLastFire = FIRE_INTERVAL

RunService.RenderStepped:Connect(function(dt)
    local char = player.Character
    local backpack = player:FindFirstChild("Backpack")
    
    -- 装备手铐（添加了更严格的检查）
    if backpack and char and char:FindFirstChild("Humanoid") then
        for _, item in ipairs(backpack:GetChildren()) do
            if item and item:IsA("Tool") and item.Name == "Handcuffs" then
                -- 确保手铐不在角色身上再移动
                if not char:FindFirstChild("Handcuffs") then
                    local success, err = pcall(function()
                        item.Parent = char
                    end)
                    if success then
                        print("[Script] Handcuffs equipped successfully")
                    else
                        warn("[Script] Failed to equip handcuffs:", err)
                    end
                end
            end
        end
    end

    -- Eject逻辑保持不变
    sinceLastFire = sinceLastFire + dt
    if sinceLastFire >= FIRE_INTERVAL then
        sinceLastFire = 0
        if remoteEvent and remoteEvent:IsA("RemoteEvent") then
            local ok, err = pcall(function()
                remoteEvent:FireServer("Eject", player.Name)
            end)
            if not ok then
                warn("[Script] FireServer(Eject) failed:", err)
            end
        end
    end
end)
