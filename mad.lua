-- 修复版脚本 - 移除冷却，修复事件触发
local debugLog = {}
local maxLogEntries = 100

local function addLog(message)
    table.insert(debugLog, 1, tostring(message))
    if #debugLog > maxLogEntries then
        table.remove(debugLog)
    end
    print("DEBUG: " .. message)
end

addLog("脚本开始执行 - 修复版")

-- 错误处理
local function errorHandler(err)
    addLog("❌ 发生错误: " .. tostring(err))
    addLog("📋 调试堆栈: " .. debug.traceback())
    return err
end

-- 状态变量（移除冷却相关）
local isHandcuffsEquipped = false
local correctEventName = "RedEvent" -- 根据日志修正的事件名称

-- 主高频循环函数
local function mainLoop()
    xpcall(function()
        local player = game:GetService("Players").LocalPlayer
        
        -- 检查玩家和角色
        if not player or not player.Character then
            addLog("玩家或角色未就绪")
            return
        end
        
        -- 检查背包和装备手铐
        local backpack = player.Backpack
        if backpack and not isHandcuffsEquipped then
            local handcuffs = backpack:FindFirstChild("Handcuffs")
            if handcuffs then
                addLog("找到手铐，正在装备...")
                handcuffs.Parent = player.Character
                isHandcuffsEquipped = true
                addLog("手铐装备完成")
            end
        end
        
        -- 触发事件（移除冷却机制）
        local remoteEvent = game:GetService("ReplicatedStorage"):FindFirstChild(correctEventName)
        
        if remoteEvent then
            -- 直接触发，无冷却限制
            remoteEvent:FireServer("Eject", player)
            addLog("Eject事件已触发")
        else
            addLog("未找到" .. correctEventName .. "远程事件")
        end
        
        -- 简化状态输出
        addLog("状态: 手铐装备=" .. tostring(isHandcuffsEquipped))
        
    end, errorHandler)
end

-- 初始化
local function initialize()
    addLog("设置队伍...")
    
    local success, result = xpcall(function()
        local remoteFunction = game:GetService("ReplicatedStorage"):FindFirstChildWhichIsA("RemoteFunction")
        if remoteFunction then
            return remoteFunction:InvokeServer("SetTeam", "Police")
        else
            error("未找到RemoteFunction")
        end
    end, errorHandler)
    
    if success then
        addLog("队伍设置成功")
    end
    
    -- 启动高频循环
    game:GetService("RunService").RenderStepped:Connect(mainLoop)
    addLog("高频循环已启动")
end

-- 启动脚本
xpcall(initialize, errorHandler)
