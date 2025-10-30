local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local old
local main = {
    enable = false,
    teamcheck = false,
    friendcheck = false,
    throughWalls = false, -- 子弹穿墙，默认关闭
    hitChance = 100 -- 命中率（百分比），默认100
}

-- 随机种子（用于命中率判断）
math.randomseed(tick())

-- 缓存目标以减少频繁计算（避免卡顿）
local cachedTarget = nil
local cachedTargetUnobstructed = false -- 缓存目标是否在上次检测时未被遮挡
local cacheInterval = 0.08 -- 每 0.08s 更新一次目标（约 12.5Hz），可根据需要调低频率以降低卡顿
local cacheAccum = 0

-- 复用 RaycastParams 避免频繁创建
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Blacklist
rayParams.FilterDescendantsInstances = {}
rayParams.IgnoreWater = true

-- 6
local function getClosestHead(origin)
    local closestHead
    local closestScreenDist = math.huge

    if not LocalPlayer or not LocalPlayer.Character then return end
    if not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end

    if not Camera or not Camera:IsA("Camera") then
        Camera = Workspace.CurrentCamera
        if not Camera then return end
    end

    origin = origin or Camera.CFrame.Position

    local viewportSize = Camera.ViewportSize
    local screenCenter = Vector2.new(viewportSize.X/2, viewportSize.Y/2)

    -- 更新过滤黑名单（包含本地角色以外的忽略项）
    rayParams.FilterDescendantsInstances = {LocalPlayer.Character}

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
                local head = character:FindFirstChild("Head")
                local humanoid = character:FindFirstChildOfClass("Humanoid")

                if head and humanoid and humanoid.Health > 0 then
                    local screenPoint, onScreen = Camera:WorldToViewportPoint(head.Position)
                    -- 要求 onScreen 为 true：仅锁定那些处于屏幕视野内的目标（即使被遮挡仍视为候选）
                    if onScreen and screenPoint.Z > 0 then
                        local screen2 = Vector2.new(screenPoint.X, screenPoint.Y)
                        local screenDist = (screen2 - screenCenter).Magnitude

                        if screenDist < closestScreenDist then
                            closestScreenDist = screenDist
                            closestHead = head
                        end
                    end
                end
            end
        end
    end

    return closestHead
end

-- 更兼容的 __namecall 钩子（保留原始 direction 长度，保证远近一致性）
old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if method == "Raycast" and not checkcaller() then
        -- origin = args[1], direction = args[2], params = args[3]（常见签名）
        local origin = args[1] or (Camera and Camera.CFrame.Position) or Workspace.CurrentCamera.CFrame.Position
        local origDirection = args[2]

        -- 仅在开启子弹追踪且有缓存目标时尝试修改参数
        if main.enable and cachedTarget then
            -- 如果 cachedTarget.Position 无效则回退
            local okPos = pcall(function() return cachedTarget.Position end)
            if okPos and cachedTarget.Position then
                -- 只有当允许穿墙或缓存时目标未被遮挡，才可能修改射线
                if main.throughWalls or cachedTargetUnobstructed then
                    -- 命中率判定
                    local roll = math.random(1, 100)
                    if roll <= main.hitChance then
                        -- 计算指向目标的单位向量
                        local toTarget = (cachedTarget.Position - origin)
                        if toTarget.Magnitude > 0 then
                            -- 如果原始 direction 存在并且是 Vector3，则保留其长度（Magnitude）
                            local newDirection = nil
                            if typeof(origDirection) == "Vector3" and origDirection.Magnitude > 0 then
                                newDirection = toTarget.Unit * origDirection.Magnitude
                            else
                                -- 否则使用到目标的完整向量（保证能打到目标）
                                newDirection = toTarget
                            end

                            -- 构造新的参数列表，替换 direction（args[2]）
                            local newArgs = {unpack(args)}
                            newArgs[2] = newDirection

                            -- 调用原始方法，返回真实的 RaycastResult（userdata），避免破坏渲染/类型期望
                            return old(self, table.unpack(newArgs))
                        end
                    end
                end
            end
        end
    end

    -- 默认行为：调用原始方法
    return old(self, ...)
end))

-- 周期性更新 cachedTarget 与 cachedTargetUnobstructed，减少每次射线调用时的计算量
local RunService = game:GetService("RunService")
RunService.Heartbeat:Connect(function(dt)
    cacheAccum = cacheAccum + dt
    if cacheAccum >= cacheInterval then
        cacheAccum = 0
        if main.enable then
            local ok, target, unob = pcall(function()
                -- 选取视角内最优目标（不考虑遮挡）
                local head = getClosestHead(Camera and Camera.CFrame.Position or nil)
                if not head then
                    return nil, nil
                end

                -- 检查当前帧该目标是否未被遮挡（射线检测）
                local direction = head.Position - (Camera and Camera.CFrame.Position or workspace.CurrentCamera.CFrame.Position)
                local ray = Workspace:Raycast((Camera and Camera.CFrame.Position or workspace.CurrentCamera.CFrame.Position), direction, rayParams)
                local unobstructed = false
                if ray then
                    if ray.Instance and ray.Instance:IsDescendantOf(head.Parent) then
                        unobstructed = true
                    else
                        unobstructed = false
                    end
                else
                    unobstructed = true
                end

                return head, unobstructed
            end)

            if ok then
                cachedTarget = target
                cachedTargetUnobstructed = unob or false
            else
                cachedTarget = nil
                cachedTargetUnobstructed = false
            end
        else
            cachedTarget = nil
            cachedTargetUnobstructed = false
        end
    end
end)

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "子弹追踪",
    Icon = "rbxassetid://115895976319223",
    IconThemed = true,
    Author = "idk",
    Folder = "Hub",
    Size = UDim2.fromOffset(300, 380),
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
        if not state then cachedTarget = nil cachedTargetUnobstructed = false end
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
    Title = "子弹穿墙",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.throughWalls = state
    end
})

-- 命中率滑块（默认 100）
Main:Slider({
    Title = "命中率",
    Value = { Min = 0, Max = 100, Default = 100 },
    Callback = function(Value)
        main.hitChance = math.clamp(math.floor(Value), 0, 100)
        print("命中率:", main.hitChance)
    end
})

-- ===== 增加：目标连线（默认白色） =====
local DrawingAvailable, drawNew = pcall(function() return Drawing.new end)
local LineCreationOk = false
local targetLine
if DrawingAvailable and drawNew then
    local ok, obj = pcall(function() return drawNew("Line") end)
    if ok and obj then
        targetLine = obj
        LineCreationOk = true
        targetLine.Color = Color3.fromRGB(255,255,255) -- 默认白色
        targetLine.Thickness = 1
        targetLine.Transparency = 1
        targetLine.Visible = false
    end
end

main.drawLine = false -- 默认关闭连线

RunService.RenderStepped:Connect(function()
    if not Camera or not Camera:IsA("Camera") then
        Camera = Workspace.CurrentCamera
        if not Camera then
            if targetLine then targetLine.Visible = false end
            return
        end
    end

    if main.enable and main.drawLine and LineCreationOk then
        local closest = cachedTarget
        if closest and closest.Parent then
            local screenPoint, onScreen = Camera:WorldToViewportPoint(closest.Position)
            if onScreen and screenPoint.Z > 0 then
                local viewportSize = Camera.ViewportSize
                local screenCenter = Vector2.new(viewportSize.X/2, viewportSize.Y/2)

                targetLine.From = screenCenter
                targetLine.To = Vector2.new(screenPoint.X, screenPoint.Y)
                targetLine.Visible = true
            else
                targetLine.Visible = false
            end
        else
            targetLine.Visible = false
        end
    else
        if targetLine then targetLine.Visible = false end
    end
end)

-- UI: 增加连线开关
Main:Toggle({
    Title = "显示目标连线",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.drawLine = state
        if targetLine then targetLine.Visible = state and main.enable end
    end
})
