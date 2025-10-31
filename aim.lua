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

local function pickBestTargetFromView()
    if not LocalPlayer.Character then return nil end
    if not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return nil end

    local viewportSize = Camera.ViewportSize
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

RunService.RenderStepped:Connect(function()
    local best = pickBestTargetFromView()
    main.currentTarget = best

    if targetLineDrawing then
        if main.targetLine and best and best.Parent then
            local screenPos, onScreen = Camera:WorldToViewportPoint(best.Position)
            if onScreen then
                local viewportSize = Camera.ViewportSize
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
end)

-- 仅在短时间窗口内拦截 Raycast，避免阻塞渲染（默认短窗 0.12s）
local interceptWindowEnd = 0
local INTERCEPT_WINDOW = 0.12
local ORIGIN_DIST_THRESHOLD = 10       -- origin 距离摄像机阈值（可调）
local DIRECTION_DOT_THRESHOLD = 0.90  -- 射线方向与相机朝向夹角阈值（越接近 1 要求越严格）

local function startInterceptWindow()
    interceptWindowEnd = tick() + INTERCEPT_WINDOW
end

local function onInputBegan(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        startInterceptWindow()
    end
end

UserInputService.InputBegan:Connect(onInputBegan)
-- 兼容 LocalPlayer:GetMouse() 触发（有些环境/工具需要）
pcall(function()
    local m = LocalPlayer:GetMouse()
    if m then
        m.Button1Down:Connect(function()
            startInterceptWindow()
        end)
    end
end)

old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if method == "Raycast" and not checkcaller() then
        local origin = args[1] or (Camera and Camera.CFrame and Camera.CFrame.Position) or Vector3.new()
        local directionArg = args[2]

        if not main.enable then
            return old(self, ...)
        end

        -- 只在拦截窗口内尝试伪造
        if tick() > interceptWindowEnd then
            return old(self, ...)
        end

        -- origin 必须靠近摄像机（避免拦截引擎/远程射线）
        local camPos = (Camera and Camera.CFrame and Camera.CFrame.Position) or origin
        local originDist = (origin - camPos).Magnitude
        if originDist > ORIGIN_DIST_THRESHOLD then
            return old(self, ...)
        end

        -- 计算传入方向（若无则使用 Camera.LookVector）
        local dirVec
        if typeof(directionArg) == "Vector3" then
            dirVec = directionArg
        else
            dirVec = (Camera and Camera.CFrame and Camera.CFrame.LookVector) or Vector3.new(0,0,-1)
        end
        local dirUnit = (dirVec.Magnitude > 0) and dirVec.Unit or dirVec
        local lookUnit = (Camera and Camera.CFrame and Camera.CFrame.LookVector) or dirUnit

        -- 方向与摄像机朝向要一致，避免拦截到与玩家视角毫不相关的射线
        local dot = dirUnit:Dot(lookUnit)
        if dot < DIRECTION_DOT_THRESHOLD then
            return old(self, ...)
        end

        -- 现在安全地尝试伪造命中：优先使用缓存目标
        local closestHead = main.currentTarget or pickBestTargetFromView()
        if closestHead then
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
