-- 修复远程事件调用
local function triggerEjectEvent()
    local remoteEvents = {
        "RedEvent",      -- 最可能是正确的事件
        "PostieSent",    -- 备选事件
        "Event"          -- 原始事件名称
    }
    
    for _, eventName in ipairs(remoteEvents) do
        local event = game:GetService("ReplicatedStorage"):FindFirstChild(eventName)
        if event then
            addLog("尝试使用事件: " .. eventName)
            
            -- 尝试不同的参数组合
            local success, err = pcall(function()
                event:FireServer("Eject")
            end)
            
            if success then
                addLog("✅ 事件调用成功: " .. eventName)
                return true
            else
                addLog("❌ 事件调用失败: " .. tostring(err))
            end
        end
    end
    
    return false
end

-- 在需要的地方调用
if handcuffInCharacter then
    addLog("✅ 手铐已装备，触发Eject事件...")
    triggerEjectEvent()
end
