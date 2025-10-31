local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local RunService = game:GetService("RunService")
local old
local main = {
    enable = false,
    teamcheck = false,
    friendcheck = false,
    wallbang = false,
    line = false  -- 新增：连线开关
}

-- 缓存最近目标（每帧更新一次，避免每个Raycast遍历）
local cachedTarget = nil
local lastUpdate = 0
local UPDATE_INTERVAL = 1/30  -- 约30FPS更新，减少计算

-- 新增：连线Drawing对象
local line = Drawing.new("Line")
line.Color = Color3.new(1, 1, 1)  -- 默认白色
line.Thickness = 2
line.Transparency = 1  -- 不透明
line.Visible = false

local function getScreenCenter()
    local viewportSize = Camera.ViewportSize
    return Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
end

local function updateCachedTarget(origin)
    cachedTarget = nil
    local closestScreenDistance = math.huge

    if not LocalPlayer.Character then return end
    if not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    rayParams.FilterDescendantsInstances = {LocalPlayer.Character}

    local screenCenter = getScreenCenter()

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
                    -- 检查是否在视角内
                    local screenPos, onScreen = Camera:WorldToScreenPoint(head.Position)
                    local inView = onScreen and screenPos.X > 0 and screenPos.X < Camera.ViewportSize.X and screenPos.Y > 0 and screenPos.Y < Camera.ViewportSize.Y
                    
                    if inView then
                        local screenDistance = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                        
                        -- LOS检查（仅当穿墙关闭时）
                        local hasLOS = true
                        if not main.wallbang then
                            local direction = (head.Position - origin).Unit * 999  -- 足够长的方向
                            local losResult = Workspace:Raycast(origin, direction, rayParams)
                            if losResult and not losResult.Instance:IsDescendantOf(character) then
                                hasLOS = false
                            end
                        end

                        if hasLOS and screenDistance < closestScreenDistance then
                            cachedTarget = head  -- 修正变量名
                            closestScreenDistance = screenDistance
                        end
                    end
                end
            end
        end
    end
end

-- 每帧更新缓存和连线（优化性能）
RunService.Heartbeat:Connect(function()
    local now = tick()
    if now - lastUpdate >= UPDATE_INTERVAL then
        local origin = Camera.CFrame.Position  -- 用相机位置作为默认origin
        updateCachedTarget(origin)
        lastUpdate = now
    end

    -- 新增：更新连线（从屏幕中心到目标屏幕位置）
    if main.line and main.enable and cachedTarget then
        local screenCenter = getScreenCenter()
        local screenPos, onScreen = Camera:WorldToScreenPoint(cachedTarget.Position)
        if onScreen then
            line.From = screenCenter
            line.To = Vector2.new(screenPos.X, screenPos.Y)
            line.Visible = true
        else
            line.Visible = false
        end
    else
        line.Visible = false
    end
end)

old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if method == "Raycast" and not checkcaller() then
        local origin = args[1] or Camera.CFrame.Position
        local direction = args[2] or Vector3.new(0,0,-1) * 1000  -- 默认方向，如果没提供

        if main.enable and cachedTarget then
            -- 确保目标还在视野内（简单检查）
            local screenPos, onScreen = Camera:WorldToScreenPoint(cachedTarget.Position)
            if onScreen then
                return RaycastResult.new(  -- 用RaycastResult构造函数，更完整
                    cachedTarget,
                    cachedTarget.Position,
                    (origin - cachedTarget.Position).Unit,
                    Enum.Material.Plastic,
                    (cachedTarget.Position - origin).Magnitude
                )
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
        if state then
            print("子弹追踪已开启")  -- 调试print
        else
            cachedTarget = nil
            print("子弹追踪已关闭")
        end
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
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.wallbang = state
    end
})

-- 新增：连线Toggle
Main:Toggle({
    Title = "开启目标连线",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.line = state
        line.Visible = false  -- 关闭时隐藏
        if state then
            print("目标连线已开启")
        else
            print("目标连线已关闭")
        end
    end
})
