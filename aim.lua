local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local old
local main = {
    enable = false,
    teamcheck = false,
    friendcheck = false
}

local function getClosestHead()
    local closestHead
    local closestDistance = math.huge
    
    if not LocalPlayer.Character then
        return
    end
    
    if not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return
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

-- Hook __index on Workspace metatable to fake Raycast method
local mt = getrawmetatable(game)
local old_index = mt.__index

setreadonly(mt, false)

mt.__index = newcclosure(function(self, key)
    if checkcaller() then
        return old_index(self, key)
    end
    
    if self == Workspace and typeof(key) == "string" and key:lower() == "raycast" and main.enable then
        return newcclosure(function(origin, direction, raycastParams)
            local closestHead = getClosestHead()
            
            if closestHead then
                local originPos = origin.Position or origin
                local hitPosition = closestHead.Position
                local normal = (originPos - hitPosition).Unit
                local distance = (hitPosition - originPos).Magnitude
                
                -- 返回与原 Raycast 相同的 table 结构
                return {
                    Instance = closestHead,
                    Position = hitPosition,
                    Normal = normal,
                    Material = Enum.Material.Plastic,
                    Distance = distance
                }
            end
            
            -- Fallback to original Raycast
            return old_index(self, "Raycast")(origin, direction, raycastParams)
        end)
    end
    
    return old_index(self, key)
end)

setreadonly(mt, true)

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
    CornerRadius = UDim.new(0,16),
    StrokeThickness = 2,
    Color = ColorSequence.new(Color3.fromHex("FF0F7B"), Color3.fromHex("F89B29")),
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
        print("子弹追踪已" .. (state and "开启" or "关闭")) -- 添加调试输出
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
