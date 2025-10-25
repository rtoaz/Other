local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
if not player then
    warn("[Script] LocalPlayer unavailable. Make sure this is a LocalScript (client).")
    return
end

print("[Script] Loaded for player:", player.Name)

-- 帮助函数：安全查找 remote（不会直接报错）
local function findRemoteByNameOrType(parent, name, className)
    if not parent then return nil end
    local obj = parent:FindFirstChild(name)
    if obj and obj:IsA(className) then return obj end
    -- 尝试找第一个指定类型的对象作为后备
    for _,c in ipairs(parent:GetChildren()) do
        if c:IsA(className) then
            return c
        end
    end
    return nil
end

local remoteFunction = findRemoteByNameOrType(ReplicatedStorage, "RemoteFunction", "RemoteFunction")
local remoteEvent = findRemoteByNameOrType(ReplicatedStorage, "Event", "RemoteEvent")

print("[Script] RemoteFunction:", tostring(remoteFunction))
print("[Script] RemoteEvent:", tostring(remoteEvent))

-- 尝试设置队伍（包裹 pcall，避免直接崩溃）
if remoteFunction and remoteFunction:IsA("RemoteFunction") then
    local ok, res = pcall(function()
        return remoteFunction:InvokeServer("SetTeam", "Police")
    end)
    if not ok then
        warn("[Script] InvokeServer(SetTeam) failed:", res)
    else
        print("[Script] InvokeServer(SetTeam) result:", res)
    end
else
    warn("[Script] RemoteFunction not found or not a RemoteFunction. Check name/location.")
end

-- 帧循环：搬手铐 & 有节制地触发 Eject（如果 remoteEvent 存在）
local FIRE_INTERVAL = 1 -- 每秒最多触发一次，降低被检测的概率
local sinceLastFire = FIRE_INTERVAL

RunService.RenderStepped:Connect(function(dt)
    -- 字段检查
    local char = player.Character
    local backpack = player:FindFirstChild("Backpack")
    if backpack and char then
        for _, item in ipairs(backpack:GetChildren()) do
            if item and item.Name == "Handcuffs" then
                -- 小心搬运，封装在 pcall
                local success, err = pcall(function()
                    item.Parent = char
                end)
                if not success then
                    warn("[Script] move Handcuffs failed:", err)
                else
                    -- optional: print("Handcuffs moved")
                end
            end
        end
    end

    -- 控制频率触发 remoteEvent
    sinceLastFire = sinceLastFire + dt
    if sinceLastFire >= FIRE_INTERVAL then
        sinceLastFire = 0
        if remoteEvent and remoteEvent:IsA("RemoteEvent") then
            local ok, err = pcall(function()
                -- 注意：很多服务端不接受 Player 对象作为参数。发送较简单的标识（例如 player.Name）或只发送命令字。
                remoteEvent:FireServer("Eject", player.Name)
            end)
            if not ok then
                warn("[Script] FireServer(Eject) failed:", err)
            end
        else
            -- 不要一直警告，避免输出刷屏
        end
    end
end)
