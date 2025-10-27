local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local main = {
    enable = false,
    teamcheck = false,
    friendcheck = false,
    hitrate = 100 -- 命中率 0-100，默认 100
}

-- 获取最近的头部（仅限摄像机可见范围内）
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
                    -- 判断头部是否在摄像机视野内
                    local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                    if onScreen and screenPos.Z > 0 then
                        -- 距离检测
                        local distance = (root.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
                        if distance < closestDistance then
                            closestHead = head
                            closestDistance = distance
                        end
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
            local headPos = closestHead.Position
            local distance = (headPos - origin).Magnitude
            local diff = origin - headPos
            local normalDirection = diff.Magnitude > 0 and diff.Unit or Vector3.new(0, 1, 0)

            -- 命中率控制
            local roll = math.random(1, 100)
            if roll <= math.clamp(main.hitrate, 0, 100) then
                -- 模拟命中头部，加入轻微偏移
                return {
                    Instance = closestHead,
                    Position = headPos + Vector3.new(
                        (math.random() - 0.5) * 0.2,
                        (math.random() - 0.5) * 0.2,
                        (math.random() - 0.5) * 0.2
                    ),
                    Normal = normalDirection,
                    Material = Enum.Material.Plastic,
                    Distance = distance
                }
            end
        end
    end

    local result = oldRaycast(self, origin, direction, raycastParams)
    return result or simulateRaycast(origin, direction, raycastParams)
end)

-- UI部分
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "子弹追踪",
    Icon = "rbxassetid://129260712070622",
    IconThemed = true,
    Author = "idk",
    Folder = "CloudHub",
    Size = UDim2.fromOffset(300, 340),
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

-- 命中率滑块
Main:Slider({
    Title = "命中率 (%)",
    Value = { Min = 0, Max = 100, Default = 100 },
    Callback = function(Value)
        local v = tonumber(Value) or 100
        if v < 0 then v = 0 end
        if v > 100 then v = 100 end
        main.hitrate = v
        print("命中率已设置为:", main.hitrate)
    end
})
