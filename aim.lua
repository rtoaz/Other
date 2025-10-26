local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local oldNamecall
local oldIndex
local main = {
    enable = false,
    teamcheck = false,
    friendcheck = false,
    enablenpc = false,
    wallhack = true,
    hit_rate = 100,
    method = "Raycast",
    draw_line = false,
    line_thickness = 1,
    draw_circle = false,
    circle_scale = 3
}

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

local function getClosestNpcHead()
    local closestHead
    local closestDistance = math.huge
    
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
    local localHrp = LocalPlayer.Character.HumanoidRootPart
    
    for _, object in ipairs(Workspace:GetDescendants()) do
        if object:IsA("Model") then
            local humanoid = object:FindFirstChildOfClass("Humanoid")
            local hrp = object:FindFirstChild("HumanoidRootPart") or object.PrimaryPart
            local head = object:FindFirstChild("Head")
            
            if humanoid and hrp and humanoid.Health > 0 then
                local isPlayer = false
                for _, pl in ipairs(Players:GetPlayers()) do
                    if pl.Character == object then
                        isPlayer = true
                        break
                    end
                end
                
                if not isPlayer and head then
                    local distance = (hrp.Position - localHrp.Position).Magnitude
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

local function getOriginAndDirection(self, method, args)
    local origin, direction
    if method == "Raycast" then
        origin = args[1]
        direction = args[2]
    elseif method:find("FindPartOnRay") then
        local ray = args[1]
        origin = ray.Origin
        direction = ray.Direction
    elseif method == "ScreenPointToRay" or method == "ViewportPointToRay" then
        origin = Camera.CFrame.Position
    end
    return origin, direction
end

oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}
    
    if main.enable and main.method == method and not checkcaller() and (self == Workspace or self == Camera) then
        if math.random(100) <= main.hit_rate then
            local closestHead = getClosestHead()
            if not closestHead and main.enablenpc then
                closestHead = getClosestNpcHead()
            end
            if closestHead then
                local origin = getOriginAndDirection(self, method, args)
                if not origin then origin = Camera.CFrame.Position end
                local direction = (closestHead.Position - origin).Unit
                local dist = (closestHead.Position - origin).Magnitude
                
                local visible = true
                if not main.wallhack then
                    local params = RaycastParams.new()
                    params.FilterType = Enum.RaycastFilterType.Exclude
                    params.FilterDescendants = {LocalPlayer.Character}
                    local result = Workspace:Raycast(origin, direction * dist, params)
                    if result and not result.Instance:IsDescendantOf(closestHead.Parent) then
                        visible = false
                    end
                end
                
                if visible then
                    local hitPos = origin + direction * dist
                    local normal = -direction
                    local material = Enum.Material.Plastic
                    
                    if method == "Raycast" then
                        return {
                            Instance = closestHead,
                            Position = hitPos,
                            Normal = normal,
                            Material = material,
                            Distance = dist
                        }
                    elseif method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRayWithWhitelist" then
                        return closestHead, hitPos, normal, material
                    elseif method == "ScreenPointToRay" or method == "ViewportPointToRay" then
                        return Ray.new(origin, direction * 999)
                    end
                end
            end
        end
    end
    return oldNamecall(self, ...)
end))

oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, index)
    if main.enable and main.method == "Mouse.Hit/Target" and not checkcaller() and self == LocalPlayer:GetMouse() and (index == "Hit" or index == "Target") then
        if math.random(100) <= main.hit_rate then
            local closestHead = getClosestHead()
            if not closestHead and main.enablenpc then
                closestHead = getClosestNpcHead()
            end
            if closestHead then
                local origin = self.Origin.Position
                local direction = (closestHead.Position - origin).Unit
                local dist = (closestHead.Position - origin).Magnitude
                
                local visible = true
                if not main.wallhack then
                    local params = RaycastParams.new()
                    params.FilterType = Enum.RaycastFilterType.Exclude
                    params.FilterDescendants = {LocalPlayer.Character}
                    local result = Workspace:Raycast(origin, direction * dist, params)
                    if result and not result.Instance:IsDescendantOf(closestHead.Parent) then
                        visible = false
                    end
                end
                
                if visible then
                    if index == "Hit" then
                        return CFrame.new(origin, closestHead.Position)
                    elseif index == "Target" then
                        return closestHead
                    end
                end
            end
        end
    end
    return oldIndex(self, index)
end))

local line = Drawing.new("Line")
line.Visible = false
line.Color = Color3.fromRGB(255, 255, 255)
line.Thickness = 1
line.Transparency = 1

local circle = Drawing.new("Circle")
circle.Visible = false
circle.Color = Color3.fromRGB(255, 255, 255)
circle.Thickness = 1
circle.NumSides = 12
circle.Filled = false
circle.Transparency = 1

local function updateVisuals()
    local closestHead = getClosestHead()
    if not closestHead and main.enablenpc then
        closestHead = getClosestNpcHead()
    end
    if main.enable and closestHead then
        local pos3d = closestHead.Position
        local screenPos, onScreen = Camera:WorldToViewportPoint(pos3d)
        local pos2d = Vector2.new(screenPos.X, screenPos.Y)
        if onScreen then
            if main.draw_line then
                local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                line.From = center
                line.To = pos2d
                line.Thickness = main.line_thickness
                line.Visible = true
            else
                line.Visible = false
            end
            if main.draw_circle then
                local dist = screenPos.Z
                local headRadius3d = closestHead.Size.Y / 2
                local fovRad = math.rad(Camera.FieldOfView)
                local screenHeight = Camera.ViewportSize.Y
                local projectedRadius = (headRadius3d / dist) * (screenHeight / (2 * math.tan(fovRad / 2)))
                circle.Position = pos2d
                circle.Radius = projectedRadius * main.circle_scale
                circle.Visible = true
            else
                circle.Visible = false
            end
        else
            line.Visible = false
            circle.Visible = false
        end
    else
        line.Visible = false
        circle.Visible = false
    end
end

RunService.RenderStepped:Connect(updateVisuals)

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "子弹追踪",
    Icon = "rbxassetid://129260712070622",
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
    Title = "开启NPC子弹追踪",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.enablenpc = state
    end
})

Main:Toggle({
    Title = "子弹穿墙",
    Image = "bird",
    Value = true,
    Callback = function(state)
        main.wallhack = state
    end
})

Main:Slider({
    Title = "命中率 (%)",
    Min = 0,
    Max = 100,
    Value = 100,
    Callback = function(value)
        main.hit_rate = value
    end
})

Main:Dropdown({
    Title = "追踪方式",
    Options = {"Raycast", "FindPartOnRay", "FindPartOnRayWithIgnoreList", "FindPartOnRayWithWhitelist", "ScreenPointToRay", "ViewportPointToRay", "Mouse.Hit/Target"},
    Value = "Raycast",
    Callback = function(value)
        main.method = value
    end
})

Visuals = MainSection:Tab({ Title = "视觉", Icon = "Eye" })

Visuals:Toggle({
    Title = "目标连线 (白线)",
    Value = false,
    Callback = function(state)
        main.draw_line = state
    end
})

Visuals:Slider({
    Title = "线厚度",
    Min = 1,
    Max = 10,
    Value = 1,
    Callback = function(value)
        main.line_thickness = value
    end
})

Visuals:Toggle({
    Title = "显示目标 (头上圆)",
    Value = false,
    Callback = function(state)
        main.draw_circle = state
    end
})

Visuals:Slider({
    Title = "圆大小缩放",
    Min = 1,
    Max = 10,
    Value = 3,
    Callback = function(value)
        main.circle_scale = value
    end
})