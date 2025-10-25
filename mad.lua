local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
if not player then return end

print("[Script] Loaded for player:", player.Name)

-- 等待角色加载
if not player.Character then
    player.CharacterAdded:Wait()
end

-- 查找所有远程对象
local function findAllRemotes()
    local remotes = {}
    
    local function searchFolder(folder)
        for _, child in ipairs(folder:GetChildren()) do
            if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then
                remotes[child.Name] = child
                print("[Script] Found remote:", child.Name, "("..child.ClassName..")")
            end
            if #child:GetChildren() > 0 then
                searchFolder(child)
            end
        end
    end
    
    searchFolder(ReplicatedStorage)
    return remotes
end

local allRemotes = findAllRemotes()

-- 手铐经验系统
local experienceCooldown = 0
local handcuffUsageCount = 0
local lastHandcuffTime = 0

-- 主要的手铐使用函数
local function useHandcuffsForXP()
    local char = player.Character
    if not char or not char:FindFirstChild("Humanoid") then return false end
    
    -- 确保手铐在角色身上
    local handcuffs = char:FindFirstChild("Handcuffs")
    if not handcuffs then
        -- 从背包拿手铐
        local backpack = player:FindFirstChild("Backpack")
        if backpack then
            local backpackHandcuffs = backpack:FindFirstChild("Handcuffs")
            if backpackHandcuffs and backpackHandcuffs:IsA("Tool") then
                backpackHandcuffs.Parent = char
                handcuffs = backpackHandcuffs
                print("[Script] Equipped handcuffs from backpack")
            end
        end
    end
    
    if not handcuffs or not handcuffs:IsA("Tool") then
        print("[Script] No handcuffs found")
        return false
    end
    
    -- 模拟手铐使用（多种方式尝试）
    local success = false
    
    -- 方式1: 直接激活工具
    pcall(function()
        handcuffs:Activate()
        success = true
    end)
    
    -- 方式2: 通过远程事件通知使用手铐
    local eventNames = {"Handcuff", "Handcuffs", "Arrest", "Cuff", "UseHandcuffs", "Experience", "XP"}
    for _, eventName in ipairs(eventNames) do
        if allRemotes[eventName] then
            pcall(function()
                if allRemotes[eventName]:IsA("RemoteEvent") then
                    allRemotes[eventName]:FireServer(player.Name, "HandcuffTarget")
                    success = true
                elseif allRemotes[eventName]:IsA("RemoteFunction") then
                    allRemotes[eventName]:InvokeServer("UseHandcuffs", player.Name)
                    success = true
                end
            end)
        end
    end
    
    -- 方式3: 尝试通用的工具使用事件
    if allRemotes["ToolRemote"] or allRemotes["UseTool"] then
        pcall(function()
            local toolRemote = allRemotes["ToolRemote"] or allRemotes["UseTool"]
            toolRemote:FireServer(handcuffs, Vector3.new(0, 0, 0)) -- 模拟点击位置
            success = true
        end)
    end
    
    if success then
        handcuffUsageCount = handcuffUsageCount + 1
        lastHandcuffTime = tick()
        print("[Script] Handcuffs used successfully (Total uses: "..handcuffUsageCount..")")
    end
    
    return success
end

-- 自动刷经验主循环
RunService.Heartbeat:Connect(function(dt)
    experienceCooldown = math.max(0, experienceCooldown - dt)
    
    if experienceCooldown <= 0 then
        -- 使用手铐刷经验
        if useHandcuffsForXP() then
            -- 成功使用手铐，设置冷却时间（可调整）
            experienceCooldown = 0.2 -- 0.5秒冷却，可以根据需要调整
            
            -- 每10次使用显示一次状态
            if handcuffUsageCount % 10 == 0 then
                print("[Script] Handcuff usage count:", handcuffUsageCount)
            end
        else
            -- 如果使用失败，稍后重试
            experienceCooldown = 1
        end
    end
end)

print("[Script] Auto handcuff XP system started")
