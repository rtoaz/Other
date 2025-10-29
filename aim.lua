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
    wallbang = false
}

-- 提升线程身份到8级（最高级别，用于更强的过检测，推荐Delta）
if set_thread_identity then
    set_thread_identity(8)  -- 最高权限级别
end

local closestHead = nil  -- 缓存最近目标，减少hook内计算

-- 目标连线配置（默认白色）
local drawLineEnabled = false
local lineThickness = 1
local lineColor = Color3.fromRGB(255, 255, 255) -- 默认白色
local targetLine = nil
if Drawing and Drawing.new then
    targetLine = Drawing.new("Line")
    targetLine.Visible = false
    targetLine.Thickness = lineThickness
    targetLine.Color = lineColor
    targetLine.Transparency = 1
end

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

-- 绘制连线（RenderStepped 确保与渲染同步）
local lineConnection
lineConnection = RunService.RenderStepped:Connect(function()
    if targetLine then
        -- 当且仅当功能开启、连线开关开启且存在目标且目标在屏幕内时显示连线
        if main.enable and drawLineEnabled and closestHead and isPointInScreen(closestHead.Position) then
            local screenPoint, onScreen = Camera:WorldToViewportPoint(closestHead.Position)
            if onScreen then
                local from = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2) -- 屏幕中心
                local to = Vector2.new(screenPoint.X, screenPoint.Y)
                targetLine.From = from
                targetLine.To = to
                targetLine.Thickness = lineThickness
                targetLine.Color = lineColor
                targetLine.Visible = true
            else
                targetLine.Visible = false
            end
        else
            targetLine.Visible = false
        end
    end
end)

--  __namecall hook，但用 getrawmetatable(game) 
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

        -- 解决相机冻结 + 错误
        local camPos = Camera.CFrame.Position
        local callingScript = getcallingscript()
        local skip = false

        -- 短距离射线（相机/内部检测通常 < 100，根据Roblox FPS游戏典型值调整）
        if direction and direction.Magnitude < 100 then
            skip = true
        end

        -- 特定问题脚本
        if callingScript and (callingScript.Name == "WaterGraphics" or callingScript.Name == "CameraController") then
            skip = true
        end

        if skip then
            return old_namecall(self, ...)
        end

        -- 新增：仅对起点接近相机（<20 studs）的长距离射线应用追踪（全自动适应第一人称枪口/相机射击）
        local dist = origin and (origin - camPos).Magnitude or math.huge
        if dist > 20 then
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

            -- 穿墙开关控制是否忽略墙，但当前总是命中视野内目标
            if main.wallbang then
                -- 穿墙开启：保持原来“直接命中头部”的行为
                local result = {
                    Instance = closestHead,
                    Position = hitPos,
                    Normal = unitNormal,
                    Material = Enum.Material.Plastic,
                    Distance = distance
                }
                return result
            else
                -- 非穿墙：执行真实射线检测，确保路径上没有障碍
                -- 使用原始的 namecall（old_namecall）来得到真实的射线结果
                local real = old_namecall(self, origin, toTarget, params)

                -- 如果真实射线直接命中头或头的子对象，则返回真实结果（命中）
                if real and real.Instance then
                    -- 若真实命中的是目标或其子对象，直接返回真实结果
                    if real.Instance == closestHead or real.Instance:IsDescendantOf(closestHead.Parent) then
                        return real
                    else
                        -- 否则真实命中的是墙或其他物体，按真实结果返回（可能为 nil 或其他实例）
                        return real
                    end
                end

                -- 如果真实射线没有命中任何东西（极少数情况），返回真实结果（nil）
                return real
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
        Color3.fromHex("2E0249"), 
        Color3.fromHex("9D4EDD")
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
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.wallbang = state
        print("子弹穿墙已" .. (state and "开启" or "关闭"))
    end
})

-- 新增：目标连线开关与连线粗细（默认白色）
Main:Toggle({
    Title = "显示目标连线",
    Image = "line",
    Value = false,
    Callback = function(state)
        drawLineEnabled = state
        if targetLine then
            targetLine.Visible = state and main.enable and closestHead ~= nil
        end
    end
})

Main:Slider({
    Title = "连线粗细",
    Value = { Min = 1, Max = 10, Default = 1 },
    Callback = function(Value)
        -- 保证为正整数
        lineThickness = math.max(1, math.floor(Value))
        if targetLine then
            targetLine.Thickness = lineThickness
        end
    end
})

-- 强制同步连线初始状态，确保默认关闭（防止 UI 库在创建控件时触发回调造成意外开启）
drawLineEnabled = false
if targetLine then
    targetLine.Visible = false
    targetLine.Thickness = lineThickness
    targetLine.Color = lineColor
end
-- 清理连接
game:BindToClose(function()
    if updateConnection then
        updateConnection:Disconnect()
    end
    if lineConnection then
        lineConnection:Disconnect()
    end
    if targetLine then
        pcall(function() targetLine:Remove() end)
    end
end)
