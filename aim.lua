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
local fovCircle

-- ======== 调试打印 ========
local function debugPrint(...)
    if not main.debug then return end
    print("[BulletTracker DEBUG]", ...)
end

local function clearVisuals()
    for _, v in ipairs(visualBeams) do if v and v.Parent then v:Destroy() end end
    for _, v in ipairs(visualSpheres) do if v and v.Parent then v:Destroy() end end
    visualBeams, visualSpheres = {}, {}
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

-- ======== Beam / Sphere ========
local function updateVisualsForTarget(targetHead)
    clearVisuals()
    if not targetHead then return end

    if main.showLine then
        local originPart = Instance.new("Part")
        originPart.Size = Vector3.new(0.1, 0.1, 0.1)
        originPart.Transparency = 1
        originPart.Anchored = true
        originPart.CanCollide = false
        originPart.CFrame = Camera.CFrame * CFrame.new(0, 0, -1)
        originPart.Parent = Workspace

        local att0 = Instance.new("Attachment", originPart)
        local att1 = Instance.new("Attachment", targetHead)
        local beam = Instance.new("Beam")
        beam.Attachment0 = att0
        beam.Attachment1 = att1
        beam.FaceCamera = true
        beam.Width0, beam.Width1 = 0.06, 0.06
        beam.Color = ColorSequence.new(Color3.new(1, 1, 1))
        beam.Parent = originPart
        table.insert(visualBeams, originPart)
    end

    if main.showSphere then
        local s = Instance.new("Part")
        s.Shape = Enum.PartType.Ball
        s.Size = Vector3.new(0.4, 0.4, 0.4)
        s.Anchored, s.CanCollide = true, false
        s.Material = Enum.Material.Neon
        s.Color = Color3.new(1, 1, 1)
        s.CFrame = CFrame.new(targetHead.Position)
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

RunService.RenderStepped:Connect(function()
    updateFOVCircle()

    if not main.enable then
        if #visualBeams > 0 or #visualSpheres > 0 then clearVisuals() end
        return
    end

    local target = getClosestHead()
    if target then
        if main.showSphere and #visualSpheres > 0 and visualSpheres[1] then
            visualSpheres[1].CFrame = CFrame.new(target.Position)
        end
        if main.showLine and #visualBeams > 0 then
            for _, o in ipairs(visualBeams) do
                if o and o.Parent then o.CFrame = Camera.CFrame * CFrame.new(0,0,-1) end
            end
        end
    end
end)

-- ======== Hook metamethod (Raycast) ========
local old
old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod and getnamecallmethod() or ""
    if method == "Raycast" and self == Workspace and main.enable then
        if math.random(1,100) <= main.hitChance then
            local head = getClosestHead()
            if head then
                updateVisualsForTarget(head)
                return {
                    Instance = head,
                    Position = head.Position,
                    Normal = Vector3.new(0, 1, 0),
                    Material = Enum.Material.Plastic,
                    Distance = (Camera.CFrame.Position - head.Position).Magnitude
                }
            end
        end
    end
    return old(self, ...)
end))

-- ======== UI (WindUI) ========
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
local Window = WindUI:CreateWindow({
    Title = "子弹追踪",
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
    Title = "开启子弹追踪",
    Image = "bird",
    Value = false,
    Callback = function(s) main.enable = s; if not s then clearVisuals() end end
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
    Title = "显示目标连线 (Beam)",
    Image = "line",
    Value = false,
    Callback = function(s) main.showLine = s; if not s then clearVisuals() end end
})
Main:Toggle({
    Title = "显示目标标记球",
    Image = "circle",
    Value = false,
    Callback = function(s) main.showSphere = s; if not s then clearVisuals() end end
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
