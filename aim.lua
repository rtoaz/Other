local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local old

local main = {
    enable = false,
    teamcheck = false,
    friendcheck = false,
    wallbang = false,
    targetLine = false,
    currentTarget = nil
}

-- Drawing 支持（目标连线）
local DrawingAvailable, Drawing = pcall(function() return Drawing end)
local targetLineDrawing = nil
if DrawingAvailable and Drawing then
    local ok, lineObj = pcall(function()
        local l = Drawing.new("Line")
        l.Visible = false
        l.From = Vector2.new(0,0)
        l.To = Vector2.new(0,0)
        l.Color = Color3.fromRGB(255,255,255)
        l.Thickness = 1.5
        l.Transparency = 1
        return l
    end)
    if ok then
        targetLineDrawing = lineObj
    end
end

-- 调整与节流参数（可根据需要微调）
local UPDATE_HZ = 30                       -- 目标缓存更新频率（Hz）
local HEARTBEAT_INTERVAL = 1 / UPDATE_HZ
local INTERCEPT_WINDOW = 0.03              -- 仅在开火瞬间短窗内拦截（秒）
local ORIGIN_DIST_THRESHOLD = 5            -- origin 距离摄像机阈值（更严格）
local DIRECTION_DOT_THRESHOLD = 0.97      -- 射线方向与相机朝向一致性阈值（更严格）

-- 缓存 viewportSize，避免每帧频繁读取
local cachedViewportSize = Vector2.new(0,0)
local function updateViewportCache()
    if Camera and Camera.ViewportSize then
        local vs = Camera.ViewportSize
        if vs ~= cachedViewportSize then
            cachedViewportSize = vs
        end
    end
end
updateViewportCache()

-- 选择视角内最佳目标（距离屏幕中心最近）
local function pickBestTargetFromView()
    if not LocalPlayer.Character then return nil end
    if not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return nil end
    if not Camera then return nil end

    local viewportSize = cachedViewportSize
    if viewportSize.X == 0 and Camera.ViewportSize then
        viewportSize = Camera.ViewportSize
        cachedViewportSize = viewportSize
    end

    local center = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
    local best = nil
    local bestScore = math.huge

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
                    local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                    if onScreen then
                        local screenVec = Vector2.new(screenPos.X, screenPos.Y)
                        local distToCenter = (screenVec - center).Magnitude
                        if distToCenter < bestScore then
                            best = head
                            bestScore = distToCenter
                        end
                    end
                end
            end
        end
    end

    return best
end

-- 用 Heartbeat 节流更新目标与连线（避免在 RenderStepped 做大量工作）
do
    local accumulator = 0
    RunService.Heartbeat:Connect(function(dt)
        accumulator = accumulator + dt
        if accumulator >= HEARTBEAT_INTERVAL then
            accumulator = accumulator - HEARTBEAT_INTERVAL

            -- 更新 viewport 缓存（若有变化）
            updateViewportCache()

            -- 更新缓存目标
            local best = pickBestTargetFromView()
            main.currentTarget = best

            -- 更新连线（仅在 targetLine 打开时）
            if targetLineDrawing then
                if main.targetLine and best and best.Parent then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(best.Position)
                    if onScreen then
                        local viewportSize = cachedViewportSize
                        local center = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
                        targetLineDrawing.From = center
                        targetLineDrawing.To = Vector2.new(screenPos.X, screenPos.Y)
                        targetLineDrawing.Visible = true
                    else
                        targetLineDrawing.Visible = false
                    end
                else
                    targetLineDrawing.Visible = false
                end
            end
        end
    end)
end

-- 开火短窗口控制（只在短时间内拦截 Raycast）
local interceptWindowEnd = 0
local function startInterceptWindow()
    interceptWindowEnd = tick() + INTERCEPT_WINDOW
end

-- 输入监听（鼠标/触摸）——尽量用非阻塞、轻量的连接
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    local t = input.UserInputType
    if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
        startInterceptWindow()
    end
end)

-- 兼容 LocalPlayer:GetMouse()（有些环境需要）
pcall(function()
    local m = LocalPlayer and LocalPlayer:GetMouse()
    if m then
        m.Button1Down:Connect(function()
            startInterceptWindow()
        end)
    end
end)

-- 保守化的 Raycast 拦截（仅在严格条件下返回伪造命中）
old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if method == "Raycast" and not checkcaller() then
        -- 不在拦截窗口则直接放行
        if tick() > interceptWindowEnd then
            return old(self, ...)
        end

        -- 如果功能没开也放行
        if not main.enable then
            return old(self, ...)
        end

        -- 获取 origin 与方向（尽量轻量）
        local origin = args[1] or (Camera and Camera.CFrame and Camera.CFrame.Position) or Vector3.new()
        local directionArg = args[2]

        -- origin 必须非常靠近摄像机
        local camPos = (Camera and Camera.CFrame and Camera.CFrame.Position) or origin
        local originDist = (origin - camPos).Magnitude
        if originDist > ORIGIN_DIST_THRESHOLD then
            return old(self, ...)
        end

        -- 获取传入方向或用摄像机朝向作为备选
        local dirVec
        if typeof(directionArg) == "Vector3" then
            dirVec = directionArg
        else
            dirVec = (Camera and Camera.CFrame and Camera.CFrame.LookVector) or Vector3.new(0,0,-1)
        end
        local dirUnit = (dirVec.Magnitude > 0) and dirVec.Unit or dirVec
        local lookUnit = (Camera and Camera.CFrame and Camera.CFrame.LookVector) or dirUnit

        -- 方向一致性阈值（避免拦截非玩家视角的射线）
        local dot = dirUnit:Dot(lookUnit)
        if dot < DIRECTION_DOT_THRESHOLD then
            return old(self, ...)
        end

        -- 优先使用缓存目标（极轻量操作）
        local closestHead = main.currentTarget
        if not closestHead then
            return old(self, ...)
        end

        -- 构造伪造命中信息并返回（不做额外真实 raycast）
        local toTarget = (closestHead.Position - origin)
        local targetDist = toTarget.Magnitude
        if targetDist <= 0 then
            return old(self, ...)
        end

        return {
            Instance = closestHead,
            Position = closestHead.Position,
            Normal = (origin - closestHead.Position).Unit,
            Material = Enum.Material.Plastic,
            Distance = targetDist
        }
    end

    return old(self, ...)
end))

-- UI（WindUI）
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "子弹追踪",
    Icon = "rbxassetid://115895976319223",
    IconThemed = true,
    Author = "idk",
    Folder = "CloudHub",
    Size = UDim2.fromOffset(320, 300),
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
    Title = "开启子弹穿墙",
    Image = "shield",
    Value = false,
    Callback = function(state)
        main.wallbang = state
    end
})

Main:Toggle({
    Title = "显示目标连线",
    Image = "line",
    Value = false,
    Callback = function(state)
        main.targetLine = state
        if targetLineDrawing then
            targetLineDrawing.Visible = state
        end
    end
})
