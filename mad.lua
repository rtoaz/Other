-- 超级详细调试版
local debugLog = {}
local maxLogEntries = 50 -- 限制日志条目数量，避免内存溢出

local function addLog(message)
    table.insert(debugLog, 1, message) -- 添加到开头，最新的在最前面
    if #debugLog > maxLogEntries then
        table.remove(debugLog) -- 移除最旧的条目
    end
    print("DEBUG: " .. message)
end

addLog("脚本开始执行")

-- 设置错误处理函数
local function errorHandler(err)
    addLog("发生错误: " .. tostring(err))
    
    -- 输出最近的日志
    addLog("=== 最近操作记录 ===")
    for i, logEntry in ipairs(debugLog) do
        if i <= 10 then -- 只显示最近10条
            addLog(logEntry)
        end
    end
    
    return err
end

-- 主执行函数
local function main()
    addLog("1. 设置队伍...")
    local success, result = xpcall(function()
        return game:GetService("ReplicatedStorage").RemoteFunction:InvokeServer("SetTeam", "Police")
    end, errorHandler)
    
    if success then
        addLog("✅ 队伍设置成功")
    else
        addLog("❌ 队伍设置失败")
    end
    
    addLog("2. 等待0.75秒...")
    wait(0.75)
    
    addLog("3. 开始高频循环...")
    game:GetService("RunService").RenderStepped:Connect(function()
        xpcall(function()
            -- 您的原始代码逻辑在这里...
            local player = game:GetService("Players").LocalPlayer
            addLog("玩家: " .. tostring(player and player.Name or "nil"))
            
            if player and player.Character then
                addLog("角色存在")
                
                local backpack = player.Backpack
                if backpack then
                    addLog("背包存在，子项数量: " .. #backpack:GetChildren())
                    
                    for i, v in pairs(backpack:GetChildren()) do
                        addLog("检查工具: " .. tostring(v) .. ", 名称: " .. tostring(v.Name))
                        if v.Name == "Handcuffs" then
                            addLog("找到手铐，尝试装备...")
                            v.Parent = player.Character
                            addLog("手铐装备完成")
                            break
                        end
                    end
                else
                    addLog("❌ 背包不存在")
                end
                
                local remoteEvent = game:GetService("ReplicatedStorage"):FindFirstChild("Event")
                if remoteEvent then
                    addLog("触发Eject事件...")
                    remoteEvent:FireServer("Eject", player)
                    addLog("Eject事件已触发")
                else
                    addLog("❌ 未找到Event远程事件")
                end
            else
                addLog("❌ 玩家或角色不存在")
            end
        end, errorHandler)
    end)
end

-- 启动主函数
xpcall(main, errorHandler)
addLog("脚本初始化完成")
