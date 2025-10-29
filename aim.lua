local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local old_namecall
local main = {
    enable = false,
    teamcheck = false,
    friendcheck = false,
    wallbang = false  -- 默认关闭穿墙
}

-- 提升线程身份到8级（最高级别，用于更强的绕过检测，推荐Delta）
if set_thread_identity then
    set_thread_identity(8)  -- 最高权限级别
end

local closestHead = nil  -- 缓存最近目标，减少hook内计算

local function isPointInScreen(point)
    local screenPoint, onScreen = Camera:WorldToViewportPoint(point)
    return onScreen and screenPoint.Z > 0
end

local function updateClosestHead()
    closestHead = nil
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
                    -- 必须在屏幕内
                    if isPointInScreen(head.Position) then
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
end

-- 每帧更新目标（优化性能，避免hook内循环）
local updateConnection
updateConnection = RunService.Heartbeat:Connect(function()
    if main.enable then
        updateClosestHead()
    else
        closestHead = nil
    end
end)

-- 回到 __namecall hook，但用 getrawmetatable(game) 更隐蔽（避免直接 hookmetamethod 被检测）
local mt = getrawmetatable(game)
old_namecall = mt.__namecall
setreadonly(mt, false)

local new_namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if method == "Raycast" and self == Workspace and not checkcaller() then
        local origin = args[1]
        local direction = args[2]
        local params = args[3]

        -- 【修复追踪失效】：移除短距离过滤，只用相机位置 + 脚本过滤（枪射线不被误跳）
        local camPos = Camera.CFrame.Position
        local callingScript = getcallingscript()
        local skip = false

        -- 起点接近相机位置（枪origin通常枪口，非相机）
        if origin and (origin - camPos).Magnitude < 0.1 then
            skip = true
        end

        -- 特定问题脚本
        if callingScript and (callingScript.Name == "WaterGraphics" or callingScript.Name == "CameraController") then
            skip = true
        end

        if skip then
            return old_namecall(self, ...)
        end

        if main.enable and closestHead then
            local hitPos = closestHead.Position
            local toTarget = hitPos - origin
            local distance = toTarget.Magnitude
            if distance == 0 then 
                distance = 0.1
                toTarget = direction or Vector3.new(0, 0, -1)
            end

            local unitNormal = toTarget.Unit

            print("Raycast 追踪到目标: " .. closestHead.Parent.Name .. (main.wallbang and " [穿墙]" or ""))

            -- 【墙检测优化】：点积阈值 0.99（更精确直线判断）
            local targetDir = toTarget.Unit
            local shotDir = direction.Unit
            local dotProduct = targetDir:Dot(shotDir)

            local blocked = false
            if not main.wallbang then
                if dotProduct < 0.99 then  -- 严格直线匹配
                    blocked = true
                end
            end

            -- 如果被墙挡 → 原始射线（打墙）
            if blocked then
                return old_namecall(self, origin, direction, params)
            else
                local result = {
                    Instance = closestHead,
                    Position = hitPos,
                    Normal = unitNormal,
                    Material = Enum.Material.Plastic,
                    Distance = distance
                }
                return result
            end
        end
    end
    return old_namecall(self, ...)
end)

mt.__namecall = new_namecall
setreadonly(mt, true)

-- 额外：如果检测基于 fenv 泄漏，使用这个来清理环境（可选）
local cleanEnv = getfenv()
for k, v in pairs(cleanEnv) do
    if type(k) == "string" and (k:find("hook") or k:find("exploit")) then
        cleanEnv[k] = nil
    end
end

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
        print("子弹追踪已" .. (state and "开启" or "关闭"))
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

Main:Toggle({
    Title = "启用子弹穿墙",
    Image = "zap",
    Value = false,
    Callback = function(state)
        main.wallbang = state
        print("子弹穿墙已" .. (state and "开启" or "关闭"))
    end
})

-- 清理连接
game:BindToClose(function()
    if updateConnection then
        updateConnection:Disconnect()
    end
end)
