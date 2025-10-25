local success, errorMsg = pcall(function()
    -- 设置队伍
    game:GetService("ReplicatedStorage").RemoteFunction:InvokeServer("SetTeam", "Police")
    wait(2)
    
    local player = game:GetService("Players").LocalPlayer
    local handcuffs = player.Backpack:FindFirstChild("Handcuffs")
    
    if handcuffs then
        handcuffs.Parent = player.Character
        wait(1)
        game:GetService("ReplicatedStorage").Event:FireServer("Eject")
        print("脚本执行成功")
    else
        warn("背包中没有手铐")
    end
end)

if not success then
    warn("脚本出错:", errorMsg)
end
