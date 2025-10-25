-- 修复版脚本 - 针对游戏中的远程事件
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
    return err
end

local function tryFireEvent(eventName, ...)
    local event = game:GetService("ReplicatedStorage"):FindFirstChild(eventName)
    if event then
        addLog("尝试触发事件: " .. eventName)
        local success, result = pcall(function()
            return event:FireServer(...)
        end)
        if success then
            addLog("✅ 事件触发成功: " .. eventName)
            return true
        else
            addLog("❌ 事件触发失败: " .. tostring(result))
        end
    else
        addLog("❌ 事件不存在: " .. eventName)
    end
    return false
end

local function main()
    addLog("1. 设置队伍为Police...")
    local success, result = xpcall(function()
        return game:GetService("ReplicatedStorage").RemoteFunction:InvokeServer("SetTeam", "Police")
    end, errorHandler)
    
    if success then
        addLog("✅ 队伍设置成功")
    else
        addLog("❌ 队伍设置失败: " .. tostring(result))
    end
    
    wait(0.75)
    
    addLog("2. 开始装备手铐和触发事件...")
    game:GetService("RunService").RenderStepped:Connect(function()
        xpcall(function()
            local player = game:GetService("Players").LocalPlayer
            if not player or not player.Character then return end
            
            -- 检查手铐是否已在角色身上
            local handcuff = player.Character:FindFirstChild("Handcuffs")
            if handcuff then
                addLog("✅ 手铐已装备: " .. handcuff.Name)
                
                -- 根据您的游戏，尝试不同的事件和参数组合
                -- 优先级1: RedEvent (最可能正确)
                if tryFireEvent("RedEvent", "Eject") then return end
                
                -- 优先级2: PostieSent (备选)
                if tryFireEvent("PostieSent", "Eject") then return end
                
                -- 优先级3: PostieReceived (备选)
                if tryFireEvent("PostieReceived", "Eject") then return end
                
                -- 优先级4: 尝试不带参数
                if tryFireEvent("RedEvent") then return end
                if tryFireEvent("PostieSent") then return end
                
                addLog("❌ 所有事件尝试均失败")
            else
                -- 装备手铐逻辑
                addLog("手铐未装备，检查背包...")
                local backpack = player:FindFirstChild("Backpack")
                if backpack then
                    local handcuff = backpack:FindFirstChild("Handcuffs")
                    if handcuff then
                        handcuff.Parent = player.Character
                        addLog("✅ 手铐装备完成")
                    else
                        addLog("❌ 背包中未找到Handcuffs")
                    end
                end
            end
        end, errorHandler)
    end)
end

xpcall(main, errorHandler)
addLog("脚本初始化完成")
