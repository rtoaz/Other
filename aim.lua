local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local main = {
    enable = false,
    teamcheck = false,
    friendcheck = false,
    hitChance = 100,
    centerAngle = 10,
    showLine = false,
    showSphere = false,
    showFOV = false,
    fovColor = Color3.new(1, 1, 1),
    debug = true
}

-- 视觉容器
local visualBeams = {}
local visualSpheres = {}
local bulletLines = {} -- 新增：子弹轨迹线
local fovCircle

-- 新增：集束目标点
local targetPosition = nil
local activeBullets = {} -- 追踪活跃子弹

-- ======== 调试打印 ========
local function debugPrint(...)
    if not main.debug then return end
    print("[BulletTracker DEBUG]", ...)
end

local function clearVisuals()
    for _, v in ipairs(visualBeams) do if v and v.Parent then v:Destroy() end end
    for _, v in ipairs(visualSpheres) do if v and v.Parent then v:Destroy() end end
    for _, v in ipairs(bulletLines) do if v and v.Parent then v:Destroy() end end
    visualBeams, visualSpheres, bulletLines = {}, {}, {}
end

-- ======== 摄像机中心判断 ========
local function isNearCameraCenter(part, angleDeg)
    if not part or not Camera then return false end
    local camCF = Camera.CFrame
    local dir = part.Position - camCF.Position
    if dir.Magnitude == 0 then return false end
    local dot = camCF.LookVector:Dot(dir.Unit)
    local threshold = math.cos(math.rad(angleDeg))
    return dot >= threshold
end

-- ======== 获取最近头部 ========
local function getClosestHead()
    local closest, minDist = nil, math.huge
    local lpChar = LocalPlayer.Character
    if not lpChar or not lpChar:FindFirstChild("HumanoidRootPart") then return end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local skip = false
            if main.teamcheck and plr.Team == LocalPlayer.Team then skip = true end
            if not skip and main.friendcheck and LocalPlayer:IsFriendsWith(plr.UserId) then skip = true end
            if skip then continue end

            local char, head = plr.Character, plr.Character:FindFirstChild("Head")
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not (head and hum and hum.Health > 0) then continue end
            if isNearCameraCenter(head, main.centerAngle) then
                local dist = (lpChar.HumanoidRootPart.Position - head.Position).Magnitude
                if dist < minDist then
                    minDist = dist
                    closest = head
                end
            end
        end
    end
    return closest
end

-- ======== 新增：子弹检测函数 ========
local function isBullet(part)
    if not part:IsA("BasePart") then return false end
    
    -- 检测子弹的常见特征
    local isProjectile = part.Velocity.Magnitude > 50 -- 高速移动
    local nameMatch = string.find(part.Name:lower(), "bullet") or 
                     string.find(part.Name:lower(), "shot") or
                     string.find(part.Name:lower(), "projectile") or
                     string.find(part.Name:lower(), "ammo")
    
    return isProjectile and (nameMatch or part.Size.Magnitude < 2) -- 小物体
end

-- ======== 新增：子弹轨迹修改 ========
local function modifyBulletTrajectory(bullet)
    if not targetPosition or not bullet.Parent then return end
    
    local currentPos = bullet.Position
    local targetDir = (targetPosition - currentPos).Unit
    local originalSpeed = bullet.Velocity.Magnitude
    
    -- 计算新的速度方向（指向集束点）
    local newVelocity = targetDir * originalSpeed
    
    -- 应用新的轨迹
    bullet.Velocity = newVelocity
    
    -- 显示子弹轨迹线
    if main.showLine then
        local beam = Instance.new("Part")
        beam.Size = Vector3.new(0.1, 0.1, (currentPos - targetPosition).Magnitude)
        beam.Material = Enum.Material.Neon
        beam.Color = Color3.new(1, 0, 0) -- 红色轨迹线
        beam.Anchored = true
        beam.CanCollide = false
        beam.CFrame = CFrame.lookAt(currentPos, targetPosition) * CFrame.new(0, 0, -beam.Size.Z/2)
        beam.Parent = Workspace
        
        table.insert(bulletLines, beam)
        
        -- 2秒后清除轨迹线
        task.delay(2, function()
            if beam and beam.Parent then
                beam:Destroy()
            end
        end)
    end
end

-- ======== 更新视觉显示（集束版） ========
local function updateVisualsForTarget(targetHead)
    clearVisuals()
    if not targetHead then 
        targetPosition = nil
        return 
    end

    -- 设置集束目标点（头部稍微向上偏移）
    targetPosition = targetHead.Position + Vector3.new(0, 0.3, 0)

    if main.showLine then
        -- 显示从相机到集束点的引导线
        local origin = Camera.CFrame.Position
        local beamPart = Instance.new("Part")
        beamPart.Size = Vector3.new(0.1, 0.1, (origin - targetPosition).Magnitude)
        beamPart.Material = Enum.Material.Neon
        beamPart.Color = Color3.new(0, 1, 0) -- 绿色引导线
        beamPart.Anchored = true
        beamPart.CanCollide = false
        beamPart.CFrame = CFrame.lookAt(origin, targetPosition) * CFrame.new(0, 0, -beamPart.Size.Z/2)
        beamPart.Parent = Workspace
        table.insert(visualBeams, beamPart)
    end

    if main.showSphere then
        -- 显示集束目标点标记
        local s = Instance.new("Part")
        s.Shape = Enum.PartType.Ball
        s.Size = Vector3.new(0.6, 0.6, 0.6) -- 稍大的球体
        s.Anchored, s.CanCollide = true, false
        s.Material = Enum.Material.Neon
        s.Color = Color3.new(1, 0, 0) -- 红色表示集束点
        s.CFrame = CFrame.new(targetPosition)
        s.Parent = Workspace
        table.insert(visualSpheres, s)
    end
end

-- ======== FOV Circle ========
local function createFOVCircle()
    if fovCircle then fovCircle:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.Name = "FOVCircle"
    gui.Parent = game:GetService("CoreGui")

    local frame = Instance.new("Frame")
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Position = UDim2.new(0.5, 0, 0.5, 0)
    frame.Size = UDim2.new(0, 200, 0, 200)
    frame.BackgroundTransparency = 1

    local uiCorner = Instance.new("UICorner")
    uiCorner.CornerRadius = UDim.new(1, 0)
    uiCorner.Parent = frame

    local circleOutline = Instance.new("UIStroke")
    circleOutline.Thickness = 2
    circleOutline.Color = main.fovColor
    circleOutline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    circleOutline.Parent = frame

    frame.Parent = gui
    fovCircle = frame
end

local function updateFOVCircle()
    if not main.showFOV then
        if fovCircle then fovCircle.Visible = false end
        return
    end
    if not fovCircle then createFOVCircle() end
    fovCircle.Visible = true
    local size = math.clamp(main.centerAngle * 10, 50, 600)
    fovCircle.Size = UDim2.new(0, size, 0, size)
    fovCircle.UIStroke.Color = main.fovColor
end

-- ======== 新增：子弹监控系统 ========
local function setupBulletMonitoring()
    local connection
    connection = Workspace.DescendantAdded:Connect(function(descendant)
        if not main.enable or not isBullet(descendant) then return end
        
        -- 等待子弹完全初始化
        task.wait(0.02)
        
        if math.random(1,100) <= main.hitChance then
            -- 将子弹加入活跃列表
            table.insert(activeBullets, descendant)
            
            -- 为子弹添加销毁监听
            descendant.AncestryChanged:Connect(function()
                for i, bullet in ipairs(activeBullets) do
                    if bullet == descendant then
                        table.remove(activeBullets, i)
                        break
                    end
                end
            end)
        end
    end)
    
    return connection
end

-- ======== 主循环（集束版） ========
local bulletMonitor = setupBulletMonitoring()

RunService.RenderStepped:Connect(function()
    updateFOVCircle()

    if not main.enable then
        if #visualBeams > 0 or #visualSpheres > 0 then 
            clearVisuals() 
        end
        targetPosition = nil
        activeBullets = {}
        return
    end

    -- 更新集束目标点
    local target = getClosestHead()
    if target then
        if targetPosition then
            -- 平滑更新目标点位置
            targetPosition = targetPosition:Lerp(target.Position + Vector3.new(0, 0.3, 0), 0.3)
        else
            targetPosition = target.Position + Vector3.new(0, 0.3, 0)
        end
        updateVisualsForTarget(target)
    else
        targetPosition = nil
        clearVisuals()
    end

    -- 更新活跃子弹轨迹（实现集束效果）
    for i = #activeBullets, 1, -1 do
        local bullet = activeBullets[i]
        if bullet and bullet.Parent and targetPosition then
            modifyBulletTrajectory(bullet)
        else
            table.remove(activeBullets, i)
        end
    end
end)

-- ======== UI (WindUI) ========
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
local Window = WindUI:CreateWindow({
    Title = "子弹集束追踪",
    Icon = "rbxassetid://129260712070622",
    IconThemed = true,
    Folder = "CloudHub",
    Size = UDim2.fromOffset(330, 520),
    Transparent = true,
    Theme = "Dark",
})

local MainSection = Window:Section({ Title = "子追", Opened = true })
local Main = MainSection:Tab({ Title = "设置", Icon = "Sword" })

Main:Toggle({
    Title = "开启子弹集束",
    Image = "bird",
    Value = false,
    Callback = function(s) 
        main.enable = s; 
        if not s then 
            clearVisuals() 
            targetPosition = nil
            activeBullets = {}
        end
    end
})

Main:Toggle({
    Title = "开启队伍验证",
    Image = "bird",
    Value = false,
    Callback = function(s) main.teamcheck = s end
})

Main:Toggle({
    Title = "开启好友验证",
    Image = "bird",
    Value = false,
    Callback = function(s) main.friendcheck = s end
})

Main:Slider({
    Title = "命中率 (%)",
    Value = {Min=0, Max=100, Default=100},
    Callback = function(v) main.hitChance = v end
})

Main:Slider({
    Title = "中心角度 (度)",
    Value = {Min=0, Max=45, Default=10},
    Callback = function(v) main.centerAngle = v end
})

Main:Toggle({
    Title = "显示子弹轨迹线",
    Image = "line",
    Value = false,
    Callback = function(s) 
        main.showLine = s; 
        if not s then 
            for _, v in ipairs(visualBeams) do if v and v.Parent then v:Destroy() end end
            for _, v in ipairs(bulletLines) do if v and v.Parent then v:Destroy() end end
            visualBeams, bulletLines = {}, {}
        end
    end
})

Main:Toggle({
    Title = "显示集束目标点",
    Image = "circle",
    Value = false,
    Callback = function(s) 
        main.showSphere = s; 
        if not s then 
            for _, v in ipairs(visualSpheres) do if v and v.Parent then v:Destroy() end end
            visualSpheres = {}
        end
    end
})

Main:Toggle({
    Title = "显示FOV圆圈",
    Image = "circle",
    Value = false,
    Callback = function(s)
        main.showFOV = s
        if s then createFOVCircle() else if fovCircle then fovCircle.Visible=false end end
    end
})

Main:Colorpicker({
    Title = "FOV颜色选择器",
    Default = Color3.fromRGB(255, 255, 255),
    Callback = function(Color)
        main.fovColor = Color
        if fovCircle and fovCircle:FindFirstChildOfClass("UIStroke") then
            fovCircle:FindFirstChildOfClass("UIStroke").Color = Color
        end
    end
})

-- 清理函数
game:GetService("Players").LocalPlayer.CharacterAdded:Connect(function()
    clearVisuals()
    targetPosition = nil
    activeBullets = {}
end)
