local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local old
local main = {
    enable = false,
    teamcheck = false,
    friendcheck = false,
    throughWalls = false, -- 子弹穿墙，默认关闭（注意：锁定视角内目标不再依赖可见性）
    hitChance = 100 -- 命中率（百分比），默认100
}

-- 随机种子（用于命中率判断）
math.randomseed(tick())

-- 缓存目标以减少频繁计算（避免卡顿）
local cachedTarget = nil
local cacheInterval = 0.08 -- 每 0.08s 更新一次目标（约 12.5Hz），可根据需要调低频率以降低卡顿
local cacheAccum = 0

-- 复用 RaycastParams 避免频繁创建（仍保留以供需要）
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Blacklist
rayParams.FilterDescendantsInstances = {}
rayParams.IgnoreWater = true

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

-- 更保守/安全的 __namecall 钩子（只拦截 Workspace:Raycast，类型检查、pcall 回退）
old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    -- 只拦截 Workspace:Raycast 的调用（避免拦截到其它对象的同名方法）
    if method == "Raycast" and not checkcaller() and self == Workspace then
        -- 常见签名：Workspace:Raycast(origin: Vector3, direction: Vector3, params?: RaycastParams)
        local origin = args[1]
        local origDirection = args[2]
        local params = args[3]

        -- 类型严格检查：只有当 origin 是 Vector3 时才处理；direction 若存在也应为 Vector3
        if typeof(origin) ~= "Vector3" or (origDirection ~= nil and typeof(origDirection) ~= "Vector3") then
            return old(self, ...) -- 回退：不是我们期望的调用签名
        end

        -- 只有在启用并有缓存目标时尝试修改射线
        if main.enable and cachedTarget then
            local okPos = pcall(function() return cachedTarget.Position end)
            if okPos and cachedTarget.Position then
                -- 命中率判定
                local roll = math.random(1, 100)
                if roll <= main.hitChance then
                    -- 读取原始 direction 的长度（保留武器期望的射程）
                    local origMag = 1000
                    if typeof(origDirection) == "Vector3" and origDirection.Magnitude > 0 then
                        origMag = origDirection.Magnitude
                    end

                    -- 计算到目标的向量并做简单移动预测
                    local toTarget = (cachedTarget.Position - origin)
                    -- 简单预测时间：与距离成正比的短时预测（可调）
                    local predictTime = math.clamp(toTarget.Magnitude / 100, 0, 0.5)
                    local predictedPos = cachedTarget.Position
                    -- 尝试从目标根部取速度（若存在）
                    local root = cachedTarget.Parent and cachedTarget.Parent:FindFirstChild("HumanoidRootPart")
                    if root and root:IsA("BasePart") then
                        predictedPos = cachedTarget.Position + root.Velocity * predictTime
                    end

                    toTarget = (predictedPos - origin)

                    if toTarget.Magnitude > 0 then
                        -- 保留原始射线长度，但至少覆盖到目标（加少量缓冲以避免被截断）
                        local neededMag = toTarget.Magnitude + 5 -- 5 studs buffer
                        local newMag = math.max(origMag, neededMag)
                        local newDirection = toTarget.Unit * newMag

                        -- 用受控签名调用原始方法（不要 table.unpack 原始 args，避免把错误类型重新传出）
                        local ok, result = pcall(function()
                            return old(self, origin, newDirection, params)
                        end)

                        if ok then
                            return result -- 成功，返回真实 RaycastResult userdata
                        else
                            -- 如果调用失败，安全回退到原始调用
                            return old(self, ...)
                        end
                    end
                end
            end
        end
    end

    -- 其他情况：调用原始方法（不改动）
    return old(self, ...)
end))

-- 周期性更新 cachedTarget，减少每次射线调用时的计算量（不再记录可见性，视角内即为候选）
local RunService = game:GetService("RunService")
RunService.Heartbeat:Connect(function(dt)
    cacheAccum = cacheAccum + dt
    if cacheAccum >= cacheInterval then
        cacheAccum = 0
        if main.enable then
            local ok, target = pcall(function()
                -- 选取视角内最优目标（不考虑遮挡）
                return getClosestHead(Camera and Camera.CFrame.Position or nil)
            end)
            if ok then
                cachedTarget = target
            else
                cachedTarget = nil
            end
        else
            cachedTarget = nil
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
        if not state then cachedTarget = nil end
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
    Image = "shield",
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
    Image = "eye",
    Value = false,
    Callback = function(state)
        main.drawLine = state
        if targetLine then targetLine.Visible = state and main.enable end
    end
})
