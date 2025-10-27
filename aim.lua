local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local main = {
    enable = false,
    teamcheck = false,
    friendcheck = false,
    hitChance = 100,     -- 命中率 0-100
    showLine = false,    -- 绘制连线（Beam）
    showSphere = false,  -- 绘制头部球（Part）
    centerAngle = 10     -- 允许的角度偏差（度），目标必须在摄像机中心 +/- centerAngle 度内
}

-- 存放用于视觉的实例
local visualBeams = {}
local visualSpheres = {}

-- 清理视觉对象
local function clearVisuals()
    for _, v in ipairs(visualBeams) do
        if v and v.Parent then v:Destroy() end
    end
    visualBeams = {}

    for _, v in ipairs(visualSpheres) do
        if v and v.Parent then v:Destroy() end
    end
    visualSpheres = {}
end

-- 判断部件是否在摄像机中心附近（基于角度阈值）
local function isNearCameraCenter(part, angleDeg)
    if not part or not Camera or not Camera.CFrame then return false end
    local camCF = Camera.CFrame
    local camPos = camCF.Position
    local look = camCF.LookVector

    local dir = part.Position - camPos
    local mag = dir.Magnitude
    if mag <= 0 then return false end

    local dot = look:Dot(dir.Unit) -- cos(theta)
    local threshold = math.cos(math.rad(math.max(0, math.min(89.9, angleDeg))))
    return dot >= threshold
end

-- 获取最近的头部（只考虑摄像机中心附近的玩家）
local function getClosestHead()
    local closestHead = nil
    local closestDistance = math.huge

    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return nil
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
                local char = player.Character
                local root = char:FindFirstChild("HumanoidRootPart")
                local head = char:FindFirstChild("Head")
                local humanoid = char:FindFirstChildOfClass("Humanoid")

                if root and head and humanoid and humanoid.Health > 0 then
                    -- 先判断是否位于摄像机中心附近（角度判断）
                    if isNearCameraCenter(head, main.centerAngle) then
                        -- 再判断是否在摄像机视锥内（可选但更安全）
                        local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                        if onScreen and screenPos.Z > 0 then
                            local dist = (root.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
                            if dist < closestDistance then
                                closestDistance = dist
                                closestHead = head
                            end
                        end
                    end
                end
            end
        end
    end

    return closestHead
end

-- 更新/绘制视觉效果（Beam + Sphere，根据开关）
local function updateVisualsForTarget(targetHead)
    clearVisuals()
    if not targetHead then return end

    if main.showLine then
        -- Beam 需要两个 Attachment：一个放在摄像机（用 Camera 或 屏幕前方创建空Part），另一个放在目标头部
        -- 为避免在 Camera 上创建 Attachment（某些环境不允许），我们创建一个临时不可见 Part 放于摄像机前方并附加
        local originPart = Instance.new("Part")
        originPart.Size = Vector3.new(0.1,0.1,0.1)
        originPart.Transparency = 1
        originPart.Anchored = true
        originPart.CanCollide = false
        originPart.CFrame = Camera.CFrame * CFrame.new(0,0,-1) -- 摄像机前方一点
        originPart.Parent = Workspace

        local att0 = Instance.new("Attachment", originPart)
        local att1 = Instance.new("Attachment", targetHead)

        local beam = Instance.new("Beam")
        beam.Attachment0 = att0
        beam.Attachment1 = att1
        beam.FaceCamera = true
        beam.Width0 = 0.06
        beam.Width1 = 0.06
        beam.Color = ColorSequence.new(Color3.new(1,1,1))
        beam.LightEmission = 1
        beam.Parent = originPart -- 父级可放 Workspace，beam 会跟随
        table.insert(visualBeams, originPart) -- 保存 originPart（包含 beam）
    end

    if main.showSphere then
        local sphere = Instance.new("Part")
        sphere.Shape = Enum.PartType.Ball
        sphere.Size = Vector3.new(0.4,0.4,0.4)
        sphere.Anchored = true
        sphere.CanCollide = false
        sphere.Material = Enum.Material.Neon
        sphere.Color = Color3.new(1,1,1)
        sphere.CFrame = CFrame.new(targetHead.Position)
        sphere.Parent = Workspace
        table.insert(visualSpheres, sphere)
    end
end

-- 将视觉对象随目标位置更新（每帧）
RunService.RenderStepped:Connect(function()
    if not main.enable then
        -- 如果关闭则清理视觉并返回
        if #visualBeams > 0 or #visualSpheres > 0 then
            clearVisuals()
        end
        return
    end

    -- 如果显示球，则把球位置同步到目标头部
    if main.showSphere and #visualSpheres > 0 then
        local target = getClosestHead()
        if target and visualSpheres[1] and visualSpheres[1].Parent then
            visualSpheres[1].CFrame = CFrame.new(target.Position)
        end
    end

    -- 对于 beam 的 originPart 我们也需要不断更新其位置到摄像机前方
    if main.showLine and #visualBeams > 0 then
        for _, originPart in ipairs(visualBeams) do
            if originPart and originPart.Parent then
                originPart.CFrame = Camera.CFrame * CFrame.new(0,0,-1)
            end
        end
    end
end)

-- 备用 Raycast wrapper（如果原始返回 nil 则提供默认结构）
local function simulateRaycast(origin, direction, params)
    local result = Workspace:Raycast(origin, direction, params)
    return result or {
        Instance = nil,
        Position = origin + direction,
        Normal = -direction.Unit,
        Material = Enum.Material.Air,
        Distance = (origin + direction - origin).Magnitude
    }
end

-- Hook Raycast：在 main.enable 时尝试注入命中
local oldRaycast = hookfunction(Workspace.Raycast, function(self, origin, direction, raycastParams)
    if main.enable then
        -- 命中率判定
        local roll = math.random(1, 100)
        if roll <= math.clamp(main.hitChance, 0, 100) then
            local targetHead = getClosestHead()
            if targetHead then
                -- 更新视觉（如果开启）
                updateVisualsForTarget(targetHead)

                local headPos = targetHead.Position
                local diff = origin - headPos
                local normal = (diff.Magnitude > 0) and diff.Unit or Vector3.new(0,1,0)
                local dist = (headPos - origin).Magnitude

                return {
                    Instance = targetHead,
                    Position = headPos + Vector3.new((math.random() - 0.5) * 0.2, (math.random() - 0.5) * 0.2, (math.random() - 0.5) * 0.2),
                    Normal = normal,
                    Material = Enum.Material.Plastic,
                    Distance = dist
                }
            end
        end
    end

    local result = oldRaycast(self, origin, direction, raycastParams)
    return result or simulateRaycast(origin, direction, raycastParams)
end)

-- UI（WindUI）
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
local Window = WindUI:CreateWindow({
    Title = "子弹追踪",
    Icon = "rbxassetid://129260712070622",
    IconThemed = true,
    Author = "idk",
    Folder = "CloudHub",
    Size = UDim2.fromOffset(320, 460),
    Transparent = true,
    Theme = "Dark",
})

local MainSection = Window:Section({ Title = "子追", Opened = true })
local Main = MainSection:Tab({ Title = "设置", Icon = "Sword" })

-- 基本开关
Main:Toggle({
    Title = "开启子弹追踪",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.enable = state
        if not state then
            clearVisuals()
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

-- 命中率滑块
Main:Slider({
    Title = "命中率 (%)",
    Value = { Min = 0, Max = 100, Default = 100 },
    Callback = function(Value)
        local v = tonumber(Value) or 100
        main.hitChance = math.clamp(v, 0, 100)
        print("命中率已设置为:", main.hitChance)
    end
})

-- 视中心角度滑块（只锁定摄像机中心 ± angle 度内的玩家）
Main:Slider({
    Title = "中心角度 (度)",
    Value = { Min = 0, Max = 45, Default = 10 },
    Callback = function(Value)
        local v = tonumber(Value) or 10
        main.centerAngle = math.clamp(v, 0, 45)
        print("中心角度已设置为:", main.centerAngle)
    end
})

-- 可视化开关
Main:Toggle({
    Title = "显示目标连线 (Beam)",
    Image = "line",
    Value = false,
    Callback = function(state)
        main.showLine = state
        if not state then clearVisuals() end
    end
})

Main:Toggle({
    Title = "显示目标标记球",
    Image = "circle",
    Value = false,
    Callback = function(state)
        main.showSphere = state
        if not state then clearVisuals() end
    end
})
