-- 设置团队
game:GetService("ReplicatedStorage").RemoteFunction:InvokeServer("SetTeam", "Police")

wait(.75)

-- 每帧都创建新的连接（如您要求的重复连接）
while true do
    game:GetService("RunService").RenderStepped:Connect(function()
        for i,v in pairs(game:GetService("Players").LocalPlayer.Backpack:GetChildren()) do
            if v.Name == "Handcuffs" then 
                v.Parent = game:GetService("Players").LocalPlayer.Character
            end
        end
        game:GetService("ReplicatedStorage").Event:FireServer("Eject", game:GetService("Players").LocalPlayer)
    end)
    wait() -- 短暂等待，避免完全卡死
end
