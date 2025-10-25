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

addLog("脚本开始执行 - 纯装备手铐功能版")

-- 增强的错误处理
local function errorHandler(err)
    addLog("❌❌ 发生错误: " .. tostring(err))
    addLog("📋📋 调试堆栈: " .. debug.traceback())
    
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
                addLog("🔍🔍 找到手铐，正在装备...")
                handcuffs.Parent = player.Character
                isHandcuffsEquipped = true
                addLog("✅ 手铐装备完成")
            else
                addLog("❌❌ 背包中未找到手铐")
                -- 列出背包中的所有工具用于调试
                local tools = {}
                for _, item in pairs(backpack:GetChildren()) do
                    table.insert(tools, item.Name)
                end
                addLog("📦📦 背包内容: " .. table.concat(tools, ", "))
            end
        end
        
        -- 状态监控
        addLog("📊📊 状态: 手铐装备=" .. tostring(isHandcuffsEquipped))
        
    end, errorHandler)
end

-- 初始化函数
local function initialize()
    addLog("1. 启动高频循环...")
    
    -- 保持高频循环
    game:GetService("RunService").RenderStepped:Connect(function()
        mainLoop()
    end)
    
    addLog("✅ 高频循环已启动")
end

-- 启动脚本
xpcall(initialize, errorHandler)
addLog("🎯🎯 脚本初始化完成，纯装备手铐功能运行中")
