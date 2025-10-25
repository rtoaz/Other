game:GetService("ReplicatedStorage").RemoteFunction:InvokeServer("SetTeam", "Police")
wait(.75)

-- 使用 RenderStepped 但修复了语法错误
game:GetService("RunService").RenderStepped:Connect(function()
    -- 装备手铐
    for i, v in pairs(game:GetService("Players").LocalPlayer.Backpack:GetChildren()) do
        if v.Name == "Handcuffs" then
            v.Parent = game:GetService("Players").LocalPlayer.Character
            break
        end
    end
    
    -- 执行弹出操作
    game:GetService("ReplicatedStorage").Event:FireServer("Eject", game:GetService("Players").LocalPlayer)
end)
