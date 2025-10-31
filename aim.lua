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
    }
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

local function getClosestHead()
    local closestHead
    local closestDistance = math.huge

    if not LocalPlayer.Character then return end
    if not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end

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
                    local distance = (root.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
                    if distance < closestDistance then
                        closestHead = head
                        closestDistance = distance
                    end
                end
            end
        end
    end
    return closestHead
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

    return velMag > 0 -- 任何有速度的物体也当作投掷物
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

local heartbeatConn
heartbeatConn = RunService.Heartbeat:Connect(function(dt)
    if not main.enable then return end
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end

    local targetHead = getClosestHead()
    if not targetHead then return end

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
                    part.Velocity = dirUnit * speed
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
    Title = "榴弹追踪",
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
