-- 修复版脚本
local debugLog = {}
local maxLogEntries = 50

local function addLog(message)
    table.insert(debugLog, 1, message)
    if #debugLog > maxLogEntries then
        table.remove(debugLog)
    end
    print("DEBUG: " .. message)
end

addLog("脚本开始执行")

local function errorHandler(err)
    addLog("发生错误: " .. tostring(err))
    
    addLog("=== 最近操作记录 ===")
    for i, logEntry in ipairs(debugLog) do
        if i <= 10 then
            addLog(logEntry)
        end
    end
    
    return err
end

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
            local player = game:GetService("Players").LocalPlayer
            addLog("玩家: " .. tostring(player and player.Name or "nil"))
            
            if player and player.Character then
                addLog("角色存在")
                
                -- 修复1: 检查角色身上是否已有手铐
                local character = player.Character
                local handcuffInCharacter = character:FindFirstChild("Handcuff") or character:FindFirstChild("Handcuffs")
                
                if handcuffInCharacter then
                    addLog("✅ 手铐已在角色身上: " .. handcuffInCharacter.Name)
                    
                    -- 修复2: 正确触发远程事件
                    local remoteEvent = game:GetService("ReplicatedStorage"):FindFirstChild("Event")
                    
                    if not remoteEvent then
                        -- 尝试查找其他可能的事件名称
                        remoteEvent = game:GetService("ReplicatedStorage"):FindFirstChild("RemoteEvent")
                        if not remoteEvent then
                            -- 列出所有远程事件以便调试
                            addLog("可用的远程事件:")
                            for i, child in ipairs(game:GetService("ReplicatedStorage"):GetChildren()) do
                                if child:IsA("RemoteEvent") then
                                    addLog("  - " .. child.Name)
                                end
                            end
                        end
                    end
                    
                    if remoteEvent then
                        addLog("找到远程事件: " .. remoteEvent.Name)
                        addLog("触发Eject事件...")
                        
                        -- 尝试不同的参数格式
                        local success, err = pcall(function()
                            remoteEvent:FireServer("Eject", player)
                        end)
                        
                        if not success then
                            addLog("第一种参数格式失败: " .. tostring(err))
                            
                            -- 尝试其他参数格式
                            local success2, err2 = pcall(function()
                                remoteEvent:FireServer("Eject")
                            end)
                            
                            if not success2 then
                                addLog("第二种参数格式失败: " .. tostring(err2))
                                
                                -- 尝试只传递玩家
                                local success3, err3 = pcall(function()
                                    remoteEvent:FireServer(player)
                                end)
                                
                                if not success3 then
                                    addLog("第三种参数格式失败: " .. tostring(err3))
                                else
                                    addLog("✅ 第三种参数格式成功")
                                end
                            else
                                addLog("✅ 第二种参数格式成功")
                            end
                        else
                            addLog("✅ 第一种参数格式成功")
                        end
                    else
                        addLog("❌ 未找到合适的远程事件")
                    end
                else
                    addLog("手铐不在角色身上，检查背包...")
                    
                    local backpack = player.Backpack
                    if backpack then
                        addLog("背包存在，子项数量: " .. #backpack:GetChildren())
                        
                        -- 修复3: 尝试不同的手铐名称
                        local handcuffNames = {"Handcuff", "Handcuffs", "Cuffs", "HandcuffTool"}
                        local foundHandcuff = nil
                        
                        for _, name in ipairs(handcuffNames) do
                            local tool = backpack:FindFirstChild(name)
                            if tool then
                                foundHandcuff = tool
                                addLog("找到工具: " .. name)
                                break
                            end
                        end
                        
                        if foundHandcuff then
                            addLog("尝试装备手铐: " .. foundHandcuff.Name)
                            foundHandcuff.Parent = player.Character
                            addLog("手铐装备完成")
                        else
                            addLog("❌ 未找到手铐，可用工具:")
                            for i, tool in ipairs(backpack:GetChildren()) do
                                if tool:IsA("Tool") then
                                    addLog("  - " .. tool.Name)
                                end
                            end
                        end
                    else
                        addLog("❌ 背包不存在")
                    end
                end
            else
                addLog("❌ 玩家或角色不存在")
            end
        end, errorHandler)
    end)
end

xpcall(main, errorHandler)
addLog("脚本初始化完成")
