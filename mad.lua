local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
if not player then return end

-- 配置
local CONFIG = {
    USE_INTERVAL = 0.1,          -- 使用间隔（秒）
    RANDOM_DELAY = 0.1,          -- 随机延迟范围
    MAX_USES_PER_MINUTE = 100000000000,   -- 每分钟最大使用次数（避免异常）
    ENABLE_LOGGING = true
}

-- 状态跟踪
local state = {
    usageCount = 0,
    lastMinuteUsage = 0,
    lastMinuteReset = tick(),
    isActive = true
}

-- 日志函数
local function log(message)
    if CONFIG.ENABLE_LOGGING then
        print("[HandcuffXP] " .. message)
    end
end

-- 查找经验相关远程事件
local function findExperienceRemotes()
    local xpRemotes = {}
    local commonNames = {
        "Experience", "XP", "AddXP", "GiveXP", "AwardXP",
        "Handcuff", "Handcuffs", "Arrest", "Cuff",
        "ToolUse", "UseTool", "ToolRemote"
    }
    
    for _, name in ipairs(commonNames) do
        local remote = ReplicatedStorage:FindFirstChild(name)
        if remote and (remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction")) then
            xpRemotes[name] = remote
            log("Found XP remote: " .. name)
        end
    end
    
    return xpRemotes
end

local xpRemotes = findExperienceRemotes()

-- 模拟手铐使用获取经验
local function simulateHandcuffForXP()
    local char = player.Character
    if not char or not char:FindFirstChild("Humanoid") then
        log("Character not ready")
        return false
    end
    
    -- 检查使用频率限制
    local currentTime = tick()
    if currentTime - state.lastMinuteReset > 60 then
        state.lastMinuteUsage = 0
        state.lastMinuteReset = currentTime
    end
    
    if state.lastMinuteUsage >= CONFIG.MAX_USES_PER_MINUTE then
        log("Rate limit reached, waiting for reset")
        return false
    end
    
    -- 确保手铐装备
    local handcuffs = char:FindFirstChild("Handcuffs")
    if not handcuffs then
        local backpack = player:FindFirstChild("Backpack")
        if backpack then
            handcuffs = backpack:FindFirstChild("Handcuffs")
            if handcuffs and handcuffs:IsA("Tool") then
                handcuffs.Parent = char
                log("Equipped handcuffs")
            end
        end
    end
    
    if not handcuffs then
        log("No handcuffs available")
        return false
    end
    
    -- 尝试多种经验获取方式
    local success = false
    
    -- 方式1: 直接工具激活
    pcall(function() 
        handcuffs:Activate()
        wait(0.1)
        handcuffs:Deactivate()
        success = true
    end)
    
    -- 方式2: 通过经验相关远程事件
    for name, remote in pairs(xpRemotes) do
        pcall(function()
            if name:lower():find("xp") or name:lower():find("experience") then
                -- 经验相关事件
                if remote:IsA("RemoteEvent") then
                    remote:FireServer(player.Name, 10) -- 假设每次10经验
                else
                    remote:InvokeServer("AddXP", player.Name, 10)
                end
            else
                -- 手铐使用事件
                if remote:IsA("RemoteEvent") then
                    remote:FireServer(player.Name, "NPC_Target") -- 假设目标是NPC
                else
                    remote:InvokeServer("Use", player.Name)
                end
            end
            success = true
        end)
    end
    
    if success then
        state.usageCount = state.usageCount + 1
        state.lastMinuteUsage = state.lastMinuteUsage + 1
        
        if state.usageCount % 50 == 0 then
            log(string.format("Total uses: %d (This minute: %d)", 
                state.usageCount, state.lastMinuteUsage))
        end
    end
    
    return success
end

-- 主循环
local lastUseTime = 0
RunService.Heartbeat:Connect(function(dt)
    if not state.isActive then return end
    
    local currentTime = tick()
    if currentTime - lastUseTime >= CONFIG.USE_INTERVAL then
        -- 添加随机延迟使行为更自然
        local randomDelay = math.random() * CONFIG.RANDOM_DELAY
        wait(randomDelay)
        
        simulateHandcuffForXP()
        lastUseTime = tick()
    end
end)

-- UI控制（可选）
local function createControlGUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Parent = player.PlayerGui
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 200, 0, 100)
    frame.Position = UDim2.new(0, 10, 0, 10)
    frame.BackgroundColor3 = Color3.new(0, 0, 0)
    frame.BackgroundTransparency = 0.3
    frame.Parent = screenGui
    
    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.new(0, 180, 0, 30)
    toggle.Position = UDim2.new(0, 10, 0, 10)
    toggle.Text = "Auto Handcuff XP: ON"
    toggle.Parent = frame
    
    local countLabel = Instance.new("TextLabel")
    countLabel.Size = UDim2.new(0, 180, 0, 50)
    countLabel.Position = UDim2.new(0, 10, 0, 50)
    countLabel.Text = "Uses: 0"
    countLabel.TextColor3 = Color3.new(1, 1, 1)
    countLabel.BackgroundTransparency = 1
    countLabel.Parent = frame
    
    toggle.MouseButton1Click:Connect(function()
        state.isActive = not state.isActive
        toggle.Text = "Auto Handcuff XP: " .. (state.isActive and "ON" or "OFF")
    end)
    
    -- 更新计数器
    while true do
        countLabel.Text = string.format("Uses: %d\nThis Minute: %d/%d", 
            state.usageCount, state.lastMinuteUsage, CONFIG.MAX_USES_PER_MINUTE)
        wait(1)
    end
end

-- 启动GUI（可选）
pcall(createControlGUI)

log("Advanced handcuff XP system started")
