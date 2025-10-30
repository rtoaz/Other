local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local old
local main = {
    enable = false,
    teamcheck = false,
    friendcheck = false,
    wallcheck = false,  -- 子弹穿墙开关
    showline = true    -- 新增：显示目标连线
}

-- 连线绘制对象
local targetLine
local targetDot

-- 初始化连线
local function initLine()
    if not targetLine then
        targetLine = Drawing.new("Line")
        targetLine.Thickness = 2
        targetLine.Color = Color3.new(1, 1, 1)  -- 白色
        targetLine.Visible = false
        
        targetDot = Drawing.new("Circle")
        targetDot.Thickness = 2
        targetDot.Color = Color3.new(1, 1, 1)  -- 白色
        targetDot.Radius = 5
        targetDot.Filled = true
        targetDot.Visible = false
    end
end

-- 更新连线显示
local function updateTargetLine(targetHead)
    if not main.showline then
        if targetLine then
            targetLine.Visible = false
            targetDot.Visible = false
        end
        return
    end
    
    if not targetHead then
        if targetLine then
            targetLine.Visible = false
            targetDot.Visible = false
        end
        return
    end
    
    -- 将目标头部位置转换为屏幕坐标
    local headPosition = targetHead.Position
    local screenPoint, onScreen = Camera:WorldToScreenPoint(headPosition)
    
    if onScreen then
        -- 屏幕中心坐标
        local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        local targetPos = Vector2.new(screenPoint.X, screenPoint.Y)
        
        -- 更新连线位置
        targetLine.From = screenCenter
        targetLine.To = targetPos
        targetLine.Visible = true
        
        -- 更新目标点位置
        targetDot.Position = targetPos
        targetDot.Visible = true
    else
        targetLine.Visible = false
        targetDot.Visible = false
    end
end

-- 隐藏连线
local function hideTargetLine()
    if targetLine then
        targetLine.Visible = false
        targetDot.Visible = false
    end
end

local function getClosestHead()
    local closestHead
    local closestScreenDistance = math.huge

    if not LocalPlayer.Character then 
        hideTargetLine()
        return 
    end
    if not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then 
        hideTargetLine()
        return 
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
                local head = character:FindFirstChild("Head")
                local humanoid = character:FindFirstChildOfClass("Humanoid")

                if head and humanoid and humanoid.Health > 0 then
                    -- 将头部位置转换为屏幕坐标
                    local headPosition = head.Position
                    local screenPoint, onScreen = Camera:WorldToScreenPoint(headPosition)
                    
                    -- 只锁定视角内的玩家
                    if onScreen then
                        -- 计算与屏幕中心的距离
                        local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                        local screenPos = Vector2.new(screenPoint.X, screenPoint.Y)
                        local screenDistance = (screenPos - screenCenter).Magnitude
                        
                        -- 优先选择视角中间的玩家
                        if screenDistance < closestScreenDistance then
                            closestHead = head
                            closestScreenDistance = screenDistance
                        end
                    end
                end
            end
        end
    end
    
    -- 更新连线显示
    updateTargetLine(closestHead)
    
    return closestHead
end

-- 检查玩家是否被墙壁遮挡
local function isPlayerVisible(targetHead)
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return false
    end
    
    -- 从相机位置到目标头部发射一条射线
    local origin = Camera.CFrame.Position
    local direction = (targetHead.Position - origin).Unit
    local distance = (targetHead.Position - origin).Magnitude
    
    -- 使用RaycastParams设置忽略玩家自身
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
    
    local raycastResult = Workspace:Raycast(origin, direction * distance, raycastParams)
    
    -- 如果没有命中任何物体，或者命中的是目标玩家，则玩家可见
    if not raycastResult then
        return true
    end
    
    -- 检查是否命中了目标玩家
    local hitInstance = raycastResult.Instance
    while hitInstance and hitInstance ~= Workspace do
        if hitInstance:IsDescendantOf(targetHead.Parent) then
            return true
        end
        hitInstance = hitInstance.Parent
    end
    
    -- 命中了其他物体，玩家被遮挡
    return false
end

old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if method == "Raycast" and not checkcaller() then
        local origin = args[1] or Camera.CFrame.Position

        if main.enable then
            local closestHead = getClosestHead()
            if closestHead then
                -- 如果开启穿墙，或者玩家没有被墙壁遮挡，则直接锁定玩家
                if main.wallcheck or isPlayerVisible(closestHead) then
                    return {
                        Instance = closestHead,
                        Position = closestHead.Position,
                        Normal = (origin - closestHead.Position).Unit,
                        Material = Enum.Material.Plastic,
                        Distance = (closestHead.Position - origin).Magnitude
                    }
                else
                    -- 如果不开启穿墙且玩家被遮挡，则返回原始射线检测结果（会命中墙壁）
                    return old(self, ...)
                end
            end
        end
    end
    return old(self, ...)
end))

-- 初始化连线
initLine()

-- 每帧更新连线
local connection
connection = RunService.RenderStepped:Connect(function()
    -- 即使子弹追踪未开启，也获取最近的目标并显示连线
    getClosestHead()
end)

-- 当脚本结束时清理连线
game:GetService("Players").PlayerRemoving:Connect(function(player)
    if player == LocalPlayer then
        connection:Disconnect()
        if targetLine then
            targetLine:Remove()
            targetDot:Remove()
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
    Size = UDim2.fromOffset(300, 300),  -- 增加高度以容纳新按钮
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
        main.wallcheck = state
    end
})

Main:Toggle({
    Title = "显示目标连线",
    Image = "bird",
    Value = true,
    Callback = function(state)
        main.showline = state
        if not state then
            hideTargetLine()
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
