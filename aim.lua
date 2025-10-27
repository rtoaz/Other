local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local main = {
    enable = false,
    teamcheck = false,
    friendcheck = false
}

-- 获取最近的头部，保持原逻辑
local function getClosestHead()
    local closestHead
    local closestDistance = math.huge
    
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return nil
    end
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local skip = false
            
            if main.teamcheck and player.Team == LocalPlayer.Team then
                skip = true
            end
            
            if not skip and main.friendcheck and LocalPlayer:IsFriendsWith(player.UserId) then
                skip = true
            end
            
            if not skip then
                local character = player.Character
                local root = character:FindFirstChild("HumanoidRootPart")
                local head = character:FindFirstChild("Head")
                local humanoid = character:FindFirstChildOfClass("Humanoid")
                
                if root and head and humanoid and humanoid.Health > 0 then
                    local distance = (root.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
                    
                    if distance < closestDistance then
                        closestHead = head
                        closestDistance = distance
                    end
                end
            end
        end
    end
    
    return closestHead
end

-- 模拟正常Raycast的函数
local function simulateRaycast(origin, direction, params)
    local result = Workspace:Raycast(origin, direction, params)
    
    return result or {
        Instance = nil,
        Position = origin + direction,
        Normal = -direction.Unit,
        Material = Enum.Material.Air,
        Distance = (origin + direction - origin).Magnitude
    }
end

-- 改写后的Raycast hook
local oldRaycast

oldRaycast = hookfunction(Workspace.Raycast, function(self, origin, direction, raycastParams)
    if main.enable and not checkcaller() then
        local closestHead = getClosestHead()
        
        if closestHead then
            -- 模拟命中头部
            local headPos = closestHead.Position
            local distance = (headPos - origin).Magnitude
            local normal = (origin - headPos).Unit
            
            -- 随机化返回数据，降低检测风险
            if math.random(1, 10) > 2 then -- 80%概率返回修改后的结果
                return {
                    Instance = closestHead,
                    Position = headPos + Vector3.new(
                        math.random(-0.1, 0.1), -- 微小偏移，模拟真实命中
                        math.random(-0.1, 0.1),
                        math.random(-0.1, 0.1)
                    ),
                    Normal = normal,
                    Material = Enum.Material.Plastic,
                    Distance = distance
                }
            end
        end
    end
    
    -- 调用原始Raycast，保持正常行为
    local result = oldRaycast(self, origin, direction, raycastParams)
    return result or simulateRaycast(origin, direction, raycastParams)
end)

-- 保持UI部分不变
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "子弹追踪",
    Icon = "rbxassetid://129260712070622",
    IconThemed = true,
    Author = "idk",
    Folder = "CloudHub",
    Size = UDim2.fromOffset(300, 270),
    Transparent = true,
    Theme = "Dark",
    User = {
        Enabled = true,
        Callback = function()
            print("clicked")
        end,
        Anonymous = false
    },
    SideBarWidth = 200,
    ScrollBarEnabled = true,
})

Window:EditOpenButton({
    Title = "打开UI",
    Icon = "monitor",
    CornerRadius = UDim.new(0, 16),
    StrokeThickness = 2,
    Color = ColorSequence.new(
        Color3.fromHex("FF0F7B"),
        Color3.fromHex("F89B29")
    ),
    Draggable = true,
})

MainSection = Window:Section({
    Title = "子追",
    Opened = true,
})

Main = MainSection:Tab({
    Title = "设置",
    Icon = "Sword"
})

Main:Toggle({
    Title = "开启子弹追踪",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.enable = state
    end
})

Main:Toggle({
    Title = "开启队伍验证",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.teamcheck = state
    end
})

Main:Toggle({
    Title = "开启好友验证",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.friendcheck = state
    end
})
