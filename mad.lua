local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
if not player then return end

print("[Handcuff XP] 脚本加载 - 玩家:", player.Name)

-- 等待角色加载
if not player.Character then
    player.CharacterAdded:Wait()
end

-- 状态跟踪
local state = {
    handcuffsEquipped = false,
    lastEjectTime = 0,
    ejectCount = 0,
    usageCount = 0
}

-- 查找远程事件
local function findRemoteEvents()
    local events = {}
    
    local function searchFolder(folder)
        for _, child in ipairs(folder:GetChildren()) do
            if child:IsA("RemoteEvent") then
                events[child.Name] = child
            end
            if #child:GetChildren() > 0 then
                searchFolder(child)
            end
        end
    end
    
    searchFolder(ReplicatedStorage)
    return events
end

local remoteEvents = findRemoteEvents()
print("[Handcuff XP] 找到的远程事件:")
for name, event in pairs(remoteEvents) do
    print("  " .. name)
end

-- 设置队伍
local function setTeam()
    local remoteFunction = ReplicatedStorage:FindFirstChildWhichIsA("RemoteFunction")
    if remoteFunction then
        local success, result = pcall(function()
            return remoteFunction:InvokeServer("SetTeam", "Police")
        end)
        if success then
            print("[Handcuff XP] 队伍设置成功")
        else
            print("[Handcuff XP] 队伍设置失败:", result)
        end
    end
end

setTeam()

-- 主循环 - 使用RenderStepped每帧触发
RunService.RenderStepped:Connect(function()
    local char = player.Character
    if not char then return end
    
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return end
    
    -- 装备手铐逻辑
    if not state.handcuffsEquipped then
        local handcuffs = backpack:FindFirstChild("Handcuffs")
        if handcuffs and handcuffs:IsA("Tool") then
            -- 确保手铐不在角色身上
            if not char:FindFirstChild("Handcuffs") then
                local success, err = pcall(function()
                    handcuffs.Parent = char
                end)
                if success then
                    state.handcuffsEquipped = true
                    print("[Handcuff XP] 手铐装备成功")
                else
                    print("[Handcuff XP] 手铐装备失败:", err)
                end
            else
                state.handcuffsEquipped = true
            end
        end
    end
    
    -- 手铐使用和Eject逻辑 - 每帧触发
    if state.handcuffsEquipped then
        local handcuffs = char:FindFirstChild("Handcuffs")
        if handcuffs and handcuffs:IsA("Tool") then
            -- 激活手铐（模拟使用）
            pcall(function()
                handcuffs:Activate()
            end)
            
            state.usageCount = state.usageCount + 1
            
            -- 触发Eject事件（每帧触发）
            for eventName, remoteEvent in pairs(remoteEvents) do
                pcall(function()
                    remoteEvent:FireServer("Eject", player.Name)
                    state.ejectCount = state.ejectCount + 1
                    
                    -- 每100次使用输出一次状态
                    if state.ejectCount % 100 == 0 then
                        print(string.format("[Handcuff XP] 使用次数: %d, Eject次数: %d", 
                            state.usageCount, state.ejectCount))
                    end
                end)
            end
        end
    end
end)

print("[Handcuff XP] RenderStepped脚本启动完成 - 每帧触发模式")
