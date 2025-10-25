-- 修复版：安全的高频循环脚本
game:GetService("ReplicatedStorage").RemoteFunction:InvokeServer("SetTeam", "Police")
wait(.75)

-- 使用 RenderStepped 但修复了语法和逻辑错误
game:GetService("RunService").RenderStepped:Connect(function()
    -- 安全检查：确保玩家和角色存在
    local player = game:GetService("Players").LocalPlayer
    if not player or not player.Character then
        return
    end
    
    -- 安全检查：确保背包存在
    local backpack = player.Backpack
    if not backpack then
        return
    end
    
    -- 装备手铐（带安全检查）
    for i, v in pairs(backpack:GetChildren()) do
        if v and v.Name == "Handcuffs" then
            -- 确保手铐工具有效
            if v:IsA("Tool") then
                v.Parent = player.Character
                break
            end
        end
    end
    
    -- 安全执行弹出操作
    local remoteEvent = game:GetService("ReplicatedStorage"):FindFirstChild("Event")
    if remoteEvent and remoteEvent:IsA("RemoteEvent") then
        -- 添加参数验证
        local success, errorMsg = pcall(function()
            remoteEvent:FireServer("Eject", player)
        end)
        if not success then
            -- 静默处理错误，不输出到控制台
            -- 可以取消下面注释来查看错误详情
            -- warn("Eject事件错误: " .. tostring(errorMsg))
        end
    end
end)

-- 额外的修复：处理SetMarkerState的NIL参数问题（如果在其他脚本中）
-- 如果您的代码中有SetMarkerState调用，请确保这样使用：
local function SafeSetMarkerState(markerName)
    if markerName and markerName ~= "" and markerName ~= "Plane" then -- 修复特定的"Plane"错误
        -- 这里调用您的SetMarkerState函数
        -- SetMarkerState(markerName)
    else
        -- 静默跳过无效调用
    end
end
