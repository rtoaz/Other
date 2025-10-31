local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local old
local main = {
    enable = false,
    wallbang = false,  -- 穿墙开关，默认 false
    teamcheck = false,
    friendcheck = false
}

local function getClosestHead()
    local closestHead
    local closestDistance = math.huge

    if not LocalPlayer.Character then return end
    if not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end

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

old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if method == "Raycast" and not checkcaller() and self == Workspace then  -- 确保是 Workspace:Raycast
        local origin = args[1]
        local direction = args[2]  -- 原方向
        local raycastParams = args[3]  -- 参数（过滤等）

        if main.enable then
            local closestHead = getClosestHead()
            if closestHead then
                -- 计算到头部的方向向量（锁定）
                local headDirection = closestHead.Position - origin
                local headDistance = headDirection.Magnitude
                headDirection = headDirection.Unit * headDistance  -- 带长度的方向

                if main.wallbang then
                    -- 穿墙：直接返回头部击中
                    return {
                        Instance = closestHead,
                        Position = closestHead.Position,
                        Normal = (origin - closestHead.Position).Unit,
                        Material = Enum.Material.Plastic,
                        Distance = headDistance
                    }
                else
                    -- 非穿墙：真实 Raycast 到头部方向
                    local result = Workspace:Raycast(origin, headDirection, raycastParams)
                    if result then
                        -- 如果击中的是目标玩家身体（或头部），返回它；否则返回墙
                        local hitCharacter = result.Instance.Parent
                        local isTargetPlayer = hitCharacter == closestHead.Parent
                        if isTargetPlayer then
                            -- 击中目标，调整为头部位置（精确击头）
                            return {
                                Instance = closestHead,
                                Position = closestHead.Position,
                                Normal = result.Normal,
                                Material = result.Material,
                                Distance = (closestHead.Position - origin).Magnitude
                            }
                        else
                            -- 击中墙，返回墙结果
                            return result
                        end
                    else
                        -- 无击中，直接返回头部（空旷环境）
                        return {
                            Instance = closestHead,
                            Position = closestHead.Position,
                            Normal = (origin - closestHead.Position).Unit,
                            Material = Enum.Material.Plastic,
                            Distance = headDistance
                        }
                    end
                end
            end
        end
    end
    return old(self, ...)
end))

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "子弹追踪",
    Icon = "rbxassetid://115895976319223",
    IconThemed = true,
    Author = "idk",
    Folder = "CloudHub",
    Size = UDim2.fromOffset(300, 270),
    Transparent = true,
    Theme = "Dark",
    User = {
        Enabled = true,
        Callback = function() print("clicked") end,
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

Main = MainSection:Tab({ Title = "设置", Icon = "Sword" })

Main:Toggle({
    Title = "开启子弹追踪",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.enable = state
    end
})

Main:Toggle({
    Title = "开启子弹穿墙",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.wallbang = state
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
