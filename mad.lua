-- 功能优先调试版
local debugLog = {}
local maxLogEntries = 100 -- 增加日志容量

local function addLog(message)
    table.insert(debugLog, 1, tostring(message))
    if #debugLog > maxLogEntries then
        table.remove(debugLog)
    end
    print("DEBUG: " .. message)
end

addLog("脚本开始执行 - 功能优先版本")

-- 增强的错误处理
local function errorHandler(err)
    addLog("❌ 发生错误: " .. tostring(err))
    addLog("📋 调试堆栈: " .. debug.traceback())
    
    -- 显示最近日志
    addLog("=== 最近操作记录 ===")
    for i, logEntry in ipairs(debugLog) do
        if i <= 15 then
            addLog("#" .. i .. ": " .. logEntry)
        end
    end
    
    return err
end

-- 状态变量
local isHandcuffsEquipped = false
local lastEjectTime = 0
local EJECT_COOLDOWN = 1 -- 事件触发冷却时间

-- 主高频循环函数
local function mainLoop()
    xpcall(function()
        local player = game:GetService("Players").LocalPlayer
        
        -- 检查玩家和角色
        if not player then
            addLog("玩家对象为空")
            return
        end
        
        if not player.Character then
            addLog("角色未加载，等待中...")
            return
        end
        
        -- 检查背包
        local backpack = player.Backpack
        if not backpack then
            addLog("背包未找到")
            return
        end
        
        -- 查找并装备手铐（如果未装备）
        if not isHandcuffsEquipped then
            local handcuffs = backpack:FindFirstChild("Handcuffs")
            if handcuffs then
                addLog("🔍 找到手铐，正在装备...")
                handcuffs.Parent = player.Character
                isHandcuffsEquipped = true
                addLog("✅ 手铐装备完成")
            else
                addLog("❌ 背包中未找到手铐")
                -- 列出背包中的所有工具用于调试
                local tools = {}
                for _, item in pairs(backpack:GetChildren()) do
                    table.insert(tools, item.Name)
                end
                addLog("📦 背包内容: " .. table.concat(tools, ", "))
            end
        end
        
        -- 触发Eject事件（带冷却时间）
        local currentTime = tick()
        if currentTime - lastEjectTime >= EJECT_COOLDOWN then
            local remoteEvent = game:GetService("ReplicatedStorage"):FindFirstChild("Event")
            
            if remoteEvent then
                addLog("🚀 触发Eject事件...")
                remoteEvent:FireServer("Eject", player)
                addLog("✅ Eject事件已发送")
                lastEjectTime = currentTime
            else
                addLog("❌ 未找到Event远程事件")
                -- 列出ReplicatedStorage中的所有远程对象用于调试
                local remoteObjects = {}
                for _, obj in pairs(game:GetService("ReplicatedStorage"):GetChildren()) do
                    if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                        table.insert(remoteObjects, obj.Name .. "(" .. obj.ClassName .. ")")
                    end
                end
                addLog("🔌 可用的远程对象: " .. table.concat(remoteObjects, ", "))
            end
        else
            addLog("⏰ Eject冷却中...")
        end
        
        -- 状态监控
        addLog("📊 状态: 手铐装备=" .. tostring(isHandcuffsEquipped) .. 
               ", 冷却剩余=" .. tostring(EJECT_COOLDOWN - (currentTime - lastEjectTime)))
        
    end, errorHandler)
end

-- 初始化函数
local function initialize()
    addLog("1. 设置队伍...")
    
    local success, result = xpcall(function()
        -- 尝试找到正确的远程函数
        local remoteFunction = game:GetService("ReplicatedStorage"):FindFirstChildWhichIsA("RemoteFunction")
        if remoteFunction then
            addLog("找到RemoteFunction: " .. remoteFunction.Name)
            return remoteFunction:InvokeServer("SetTeam", "Police")
        else
            error("未找到任何RemoteFunction")
        end
    end, errorHandler)
    
    if success then
        addLog("✅ 队伍设置成功")
    else
        addLog("❌ 队伍设置失败，但继续执行其他功能")
    end
    
    addLog("2. 启动高频循环...")
    
    -- 保持高频循环
    game:GetService("RunService").RenderStepped:Connect(function()
        mainLoop()
    end)
    
    addLog("✅ 高频循环已启动")
end

-- 启动脚本
xpcall(initialize, errorHandler)
addLog("🎯 脚本初始化完成，高频循环运行中")
