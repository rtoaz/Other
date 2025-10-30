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

-- 自己猜这里是什么
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

-- Hook 中尽量使用缓存的目标以减少每次被调用时的开销
old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if method == "Raycast" and not checkcaller() then
        local origin = args[1] or (Camera and Camera.CFrame.Position) or Workspace.CurrentCamera.CFrame.Position

        if main.enable and cachedTarget then
            -- 在返回缓存目标前，检查穿墙设置与缓存的可见性结果：
            -- 只有当 main.throughWalls == true 或 cachedTargetUnobstructed == true 才会返回目标，
            -- 否则将继续执行原始射线（避免穿墙）。
            if main.throughWalls or cachedTargetUnobstructed then
                local roll = math.random(1, 100)
                if roll <= main.hitChance then
                    return {
                        Instance = cachedTarget,
                        Position = cachedTarget.Position,
                        Normal = (origin - cachedTarget.Position).Unit,
                        Material = Enum.Material.Plastic,
                        Distance = (cachedTarget.Position - origin).Magnitude
                    }
                end
            end
            -- 若不满足穿墙或可见性条件，落回原始行为（即不强制命中）
        end
    end
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
    Folder = "CloudHub",
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
    Title = "子弹穿墙（允许穿墙）",
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
