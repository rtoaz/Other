-- 测试
print("脚本开始加载...")

-- 等待游戏完全加载
local function waitForGameLoad()
    local startTime = tick()
    while not game:IsLoaded() do
        wait(0.1)
        if tick() - startTime > 10 then
            print("❌ 游戏加载超时")
            return false
        end
    end
    return true
end

if not waitForGameLoad() then
    print("❌ 游戏加载失败，脚本停止")
    return
end

print("✅ 游戏加载完成")

-- 等待玩家加载
local function waitForPlayer()
    local players = game:GetService("Players")
    local startTime = tick()
    
    while not players.LocalPlayer do
        wait(0.5)
        if tick() - startTime > 10 then
            print("❌ 玩家加载超时")
            return nil
        end
    end
    
    return players.LocalPlayer
end

local player = waitForPlayer()
if not player then
    print("❌ 无法获取本地玩家")
    return
end

print("✅ 玩家加载完成:", player.Name)

-- 简单的调试日志系统
local debugLog = {}
local function addLog(message)
    table.insert(debugLog, message)
    print("DEBUG:", message)
    
    -- 限制日志数量
    if #debugLog > 20 then
        table.remove(debugLog, 1)
    end
end

addLog("脚本初始化开始")

-- 主功能
local function main()
    addLog("1. 尝试设置队伍...")
    
    local success, result = pcall(function()
        return game:GetService("ReplicatedStorage").RemoteFunction:InvokeServer("SetTeam", "Police")
    end)
    
    if success then
        addLog("✅ 队伍设置成功")
    else
        addLog("❌ 队伍设置失败: " .. tostring(result))
    end
    
    wait(1)
    
    addLog("2. 开始装备手铐...")
    
    -- 等待角色生成
    if not player.Character then
        player.CharacterAdded:Wait()
    end
    wait(1) -- 确保角色完全加载
    
    addLog("角色已就绪")
    
    -- 装备手铐
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        local handcuff = backpack:FindFirstChild("Handcuffs")
        if handcuff then
            handcuff.Parent = player.Character
            addLog("✅ 手铐装备完成")
        else
            addLog("❌ 背包中未找到手铐")
            -- 列出背包中所有工具
            for _, item in pairs(backpack:GetChildren()) do
                if item:IsA("Tool") then
                    addLog("背包工具: " .. item.Name)
                end
            end
        end
    else
        addLog("❌ 背包不存在")
    end
    
    addLog("3. 尝试触发事件...")
    
    -- 简单的事件触发测试
    local events = {"RedEvent", "PostieSent", "Event"}
    for _, eventName in pairs(events) do
        local event = game:GetService("ReplicatedStorage"):FindFirstChild(eventName)
        if event then
            addLog("找到事件: " .. eventName)
            local success, err = pcall(function()
                event:FireServer("Eject")
            end)
            if success then
                addLog("✅ 事件触发成功: " .. eventName)
            else
                addLog("❌ 事件触发失败: " .. tostring(err))
            end
        end
    end
    
    addLog("🎯 脚本执行完成")
end

-- 安全执行主函数
local success, err = pcall(main)
if not success then
    print("❌ 脚本执行错误:", err)
end
