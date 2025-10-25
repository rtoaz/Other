local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

-- 如果玩家数据未加载则等待
if not player then
    Players.PlayerAdded:Wait()
    player = Players.LocalPlayer
end

-- 打印调试信息到控制台
local function log(...)
    print("[MadCity-AutoXP]", ...)
end

-- 扫描所有 RemoteEvent / RemoteFunction
local remotes = {}
for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
    if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
        remotes[#remotes+1] = obj
    end
end
log("找到 Remotes 数量:", #remotes)

-- 查找函数：模糊匹配名字
local function findRemote(keyword)
    for _, r in ipairs(remotes) do
        if string.find(string.lower(r.Name), string.lower(keyword)) then
            return r
        end
    end
    return nil
end

-- 安全调用（自动判断类型）
local function callRemote(remote, ...)
    if not remote then return end
    if remote:IsA("RemoteFunction") then
        local ok, res = pcall(function()
            return remote:InvokeServer(...)
        end)
        if not ok then
            log("InvokeServer 调用失败:", remote.Name, res)
        else
            log("InvokeServer 成功:", remote.Name)
        end
    elseif remote:IsA("RemoteEvent") then
        local ok, res = pcall(function()
            remote:FireServer(...)
        end)
        if not ok then
            log("FireServer 调用失败:", remote.Name, res)
        else
            log("FireServer 成功:", remote.Name)
        end
    end
end

-- 自动装备背包物品
local function equipTool(toolName)
    local backpack = player:FindFirstChild("Backpack")
    local char = player.Character
    if not backpack or not char then return end
    local tool = backpack:FindFirstChild(toolName)
    if tool and not char:FindFirstChild(tool.Name) then
        tool.Parent = char
        log("已装备:", toolName)
    end
end

-- 自动调用经验或行动远程
spawn(function()
    local xpRemote = findRemote("XP") or findRemote("Experience")
    local arrestRemote = findRemote("Arrest") or findRemote("Eject")
    local teamRemote = findRemote("Team") or findRemote("SetTeam")

    while task.wait(1) do
        -- 自动切换队伍
        callRemote(teamRemote, "Police")
        -- 自动使用功能
        callRemote(arrestRemote, player)
        -- 自动刷经验
        callRemote(xpRemote, math.random(5,10))
        -- 自动装备手铐
        equipTool("Handcuffs")
    end
end)

log("脚本启动完成。等待触发远程事件...")
