local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local main = {
    enable = false,
    teamcheck = false,
    friendcheck = false,
    trackSpeed = 120,
    projectileKeywords = {
        "grenade","bomb","projectile","thrown","frag","molotov","nade","explosive"
    },
    -- 连线颜色（默认白色）
    lineColor = Color3.fromRGB(255,255,255),
    lineThickness = 2,
}

local function isPartInCharacter(part)
    if not part or not part.Parent then return false end
    return part:FindFirstAncestorOfClass("Model") and part:FindFirstAncestorOfClass("Model"):FindFirstChildOfClass("Humanoid") ~= nil
end

local function nameContainsKeyword(name)
    if not name or type(name) ~= "string" then return false end
    local lower = string.lower(name)
    for _, kw in ipairs(main.projectileKeywords) do
        if string.find(lower, kw, 1, true) then
            return true
        end
    end
    return false
end

-- 新：只考虑视野内玩家，且更靠近屏幕中心更优先
local function getPriorityHeadInView()
    if not LocalPlayer.Character then return end
    if not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end

    local viewportSize = Camera.ViewportSize
    if not viewportSize or viewportSize.X == 0 then
        viewportSize = Vector2.new(1920,1080)
    end
    local screenCenter = Vector2.new(viewportSize.X/2, viewportSize.Y/2)

    local bestHead = nil
    local bestScore = math.huge -- 越小越优先（屏幕距离为主要评分项，次要用世界距离）

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
                local root = character:FindFirstChild("HumanoidRootPart")

                if head and humanoid and humanoid.Health > 0 and root then
                    -- 投影到屏幕空间
                    local onScreen, screenX, screenY = false, 0, 0
                    -- WorldToViewportPoint 返回 (Vector3, onScreen) in some env. 使用 unpack style safe:
                    local success, sx, sy, sz = pcall(function()
                        local v3, on = Camera:WorldToViewportPoint(head.Position)
                        return v3.X, v3.Y, v3.Z, on
                    end)
                    -- Use safe call above isn't ideal for all runtimes; instead use direct:
                    local v3, onScreenFlag = Camera:WorldToViewportPoint(head.Position)
                    local screenPos = Vector2.new(v3.X, v3.Y)
                    local z = v3.Z

                    -- 判定：z>0 且在屏幕范围内
                    if z > 0 and screenPos.X >= 0 and screenPos.Y >= 0 and screenPos.X <= viewportSize.X and screenPos.Y <= viewportSize.Y then
                        -- 计算屏幕距离（中心优先）
                        local screenDist = (screenPos - screenCenter).Magnitude
                        -- 次要评分：世界距离，防止远处看起来靠近中心的对象被优先（适度加权）
                        local worldDist = (root.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
                        -- 综合评分：屏幕距离 + worldDist * 0.05
                        local score = screenDist + worldDist * 0.05

                        if score < bestScore then
                            bestScore = score
                            bestHead = head
                        end
                    end
                end
            end
        end
    end

    return bestHead
end

local function isLikelyProjectile(inst)
    if not inst then return false end
    if not inst:IsA("BasePart") then return false end

    if isPartInCharacter(inst) then return false end

    if nameContainsKeyword(inst.Name) or (inst.Parent and nameContainsKeyword(inst.Parent.Name)) then
        return true
    end

    local velMag = 0
    local success, aval = pcall(function() return inst.AssemblyLinearVelocity end)
    if success and typeof(aval) == "Vector3" then
        velMag = aval.Magnitude
    else
        velMag = (inst.Velocity or Vector3.new()).Magnitude
    end

    if inst:GetAttribute("IsProjectile") then
        return true
    end

    -- 改为：任何有速度且在世界上有运动的物体都认为是投掷物（用户要求没有最小速度判定）
    return velMag > 0
end

local trackedProjectiles = {}

local function trackProjectile(part)
    if not part or not part:IsA("BasePart") then return end
    if trackedProjectiles[part] then return end

    trackedProjectiles[part] = { lastUpdate = tick(), timeoutCheck = tick() }

    local function cleanup()
        trackedProjectiles[part] = nil
    end

    local conn1
    conn1 = part.AncestryChanged:Connect(function(_, parent)
        if not parent or not part:IsDescendantOf(game) then
            if conn1 then conn1:Disconnect() end
            cleanup()
        end
    end)
end

-- Drawing 目标连线（尝试安全创建，某些环境可能没有 Drawing 支持）
local line
local hasDrawing = pcall(function()
    line = Drawing and Drawing.new and Drawing.new("Line")
    return true
end)

if hasDrawing and line then
    -- 初始化属性
    line.Visible = false
    line.Color = main.lineColor
    line.Thickness = main.lineThickness
    line.Transparency = 1
else
    line = nil
end

local heartbeatConn
heartbeatConn = RunService.Heartbeat:Connect(function(dt)
    if not main.enable then
        if line then
            line.Visible = false
        end
        return
    end
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        if line then line.Visible = false end
        return
    end

    local targetHead = getPriorityHeadInView()
    if not targetHead then
        if line then line.Visible = false end
        return
    end

    -- 更新连线：从屏幕中间到目标屏幕位置
    if line then
        local v3 = Camera:WorldToViewportPoint(targetHead.Position)
        local screenPos = Vector2.new(v3.X, v3.Y)
        local viewportSize = Camera.ViewportSize
        local screenCenter = Vector2.new(viewportSize.X/2, viewportSize.Y/2)
        line.From = screenCenter
        line.To = screenPos
        line.Color = main.lineColor
        line.Thickness = main.lineThickness
        line.Visible = true
    end

    -- 把投掷物追踪向可见目标（使用已有 trackedProjectiles 表）
    for part, meta in pairs(trackedProjectiles) do
        if not part or not part.Parent or not part:IsDescendantOf(game) then
            trackedProjectiles[part] = nil
        else
            local direction = (targetHead.Position - part.Position)
            local dist = direction.Magnitude
            if dist <= 0.5 then
                pcall(function()
                    part.Velocity = Vector3.new(0, 0, 0)
                    part.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                end)
            else
                local dirUnit = direction.Unit
                local speed = math.clamp(main.trackSpeed + dist * 0.8, 40, 1000)

                pcall(function()
                    part.AssemblyLinearVelocity = dirUnit * speed
                end)

                pcall(function()
                    part.Velocity = dirUnit * speed
                end)

                pcall(function()
                    if part.AssemblyAngularVelocity then
                        part.AssemblyAngularVelocity = Vector3.new(0,0,0)
                    end
                end)
            end

            if meta and meta.timeoutCheck and tick() - meta.timeoutCheck > 25 then
                trackedProjectiles[part] = nil
            end
        end
    end
end)

local addedConn
addedConn = Workspace.DescendantAdded:Connect(function(desc)
    if not desc then return end
    if desc:IsA("BasePart") then
        task.defer(function()
            if not desc or not desc.Parent then return end
            if isLikelyProjectile(desc) then
                trackProjectile(desc)
            end
        end)
    end
end)

for _, desc in ipairs(Workspace:GetDescendants()) do
    if desc:IsA("BasePart") then
        if isLikelyProjectile(desc) then
            trackProjectile(desc)
        end
    end
end

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "投掷物追踪",
    Icon = "rbxassetid://115895976319223",
    IconThemed = true,
    Author = "idk",
    Folder = "CloudHub",
    Size = UDim2.fromOffset(300, 320),
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
    Title = "投掷追踪",
    Opened = true,
})

Main = MainSection:Tab({ Title = "设置", Icon = "Sword" })

Main:Toggle({
    Title = "开启投掷物追踪",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.enable = state
        if not state then
            for part,_ in pairs(trackedProjectiles) do
                trackedProjectiles[part] = nil
            end
            if line then line.Visible = false end
        else
            for _, desc in ipairs(Workspace:GetDescendants()) do
                if desc:IsA("BasePart") and isLikelyProjectile(desc) then
                    trackProjectile(desc)
                end
            end
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

Main:Slider({
    Title = "追踪速度",
    Value = { Min = 20, Max = 1000, Default = main.trackSpeed },
    Callback = function(Value)
        main.trackSpeed = Value
        print("追踪速度设置为:", Value)
    end
})
