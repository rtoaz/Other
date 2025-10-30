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
    drawLine = false, -- 目标连线，默认关闭
    lineColor = Color3.fromRGB(255,255,255), -- 默认白色
    bulletPenetration = false, -- 子弹穿墙，默认关闭
    rayMode = "Raycast" -- 模式选择，默认 Raycast
}

-- 尝试创建 Drawing 线条（如果环境支持）
local DrawLineObject
pcall(function()
    DrawLineObject = Drawing and Drawing.new and Drawing.new("Line")
    if DrawLineObject then
        DrawLineObject.Visible = false
        DrawLineObject.Thickness = 2
        DrawLineObject.Transparency = 1
        DrawLineObject.Color = main.lineColor
    end
end)

local function firstHitBetween(origin, targetPos)
    local direction = targetPos - origin
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = { (LocalPlayer.Character or Workspace) }
    return Workspace:Raycast(origin, direction, params)
end

local function getClosestHead()
    local closestHead
    local closestScreenDistance = math.huge
    local closestWorldDistance = math.huge

    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end

    local viewportSize = Camera.ViewportSize
    local screenCenter = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
    local localRootPos = LocalPlayer.Character.HumanoidRootPart.Position

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local skip = false
            if main.teamcheck and player.Team == LocalPlayer.Team then skip = true end
            if not skip and main.friendcheck and LocalPlayer:IsFriendsWith(player.UserId) then skip = true end

            if not skip then
                local character = player.Character
                local root = character:FindFirstChild("HumanoidRootPart")
                local head = character:FindFirstChild("Head")
                local humanoid = character:FindFirstChildOfClass("Humanoid")

                if root and head and humanoid and humanoid.Health > 0 then
                    local screenPoint, onScreen = Camera:WorldToViewportPoint(head.Position)
                    local screen2D = Vector2.new(screenPoint.X, screenPoint.Y)
                    local inViewport = onScreen ~= nil and onScreen or (screenPoint.Z > 0)

                    if inViewport and screen2D.X >= 0 and screen2D.X <= viewportSize.X and screen2D.Y >= 0 and screen2D.Y <= viewportSize.Y then
                        local screenDistance = (screen2D - screenCenter).Magnitude
                        local worldDistance = (root.Position - localRootPos).Magnitude
                        if screenDistance < closestScreenDistance or (math.abs(screenDistance - closestScreenDistance) < 1e-4 and worldDistance < closestWorldDistance) then
                            closestHead = head
                            closestScreenDistance = screenDistance
                            closestWorldDistance = worldDistance
                        end
                    end
                end
            end
        end
    end
    return closestHead
end

-- 根据模式返回允许拦截的方法集合（单选模式）
local function getAllowedMethodsForMode(mode)
    if mode == "Raycast" then
        return { ["Raycast"] = true }
    elseif mode == "FindPartOnRay" then
        return {
            ["FindPartOnRay"] = true
        }
    elseif mode == "FindPartOnRayWithIgnoreList" then
        return {
            ["FindPartOnRayWithIgnoreList"] = true
        }
    elseif mode == "FindPartOnRayWithWhitelist" then
        return {
            ["FindPartOnRayWithWhitelist"] = true
        }
    else
        return {}
    end
end

local allowedMethods = getAllowedMethodsForMode(main.rayMode)

old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if not checkcaller() and main.enable and allowedMethods[method] then
        local targetHead = getClosestHead()
        if not targetHead then return old(self, ...) end

        local origin
        local headPos = targetHead.Position
        if typeof(args[1]) == "Vector3" then
            origin = args[1]
        elseif typeof(args[1]) == "Ray" then
            origin = args[1].Origin
        else
            origin = Camera and Camera.CFrame.Position or Workspace.CurrentCamera.CFrame.Position
        end

        local vectorToHead = (headPos - origin)
        local distToHead = vectorToHead.Magnitude
        local rayResult = firstHitBetween(origin, headPos)

        if main.bulletPenetration then
            if method == "Raycast" then
                return {
                    Instance = targetHead,
                    Position = headPos,
                    Normal = (origin - headPos).Unit,
                    Material = Enum.Material.Plastic,
                    Distance = distToHead
                }
            else
                return targetHead, headPos, (origin - headPos).Unit
            end
        else
            if rayResult and rayResult.Instance then
                if rayResult.Instance:IsDescendantOf(targetHead.Parent) then
                    if method == "Raycast" then
                        return {
                            Instance = targetHead,
                            Position = headPos,
                            Normal = (origin - headPos).Unit,
                            Material = Enum.Material.Plastic,
                            Distance = distToHead
                        }
                    else
                        return targetHead, headPos, (origin - headPos).Unit
                    end
                else
                    return old(self, ...)
                end
            else
                if method == "Raycast" then
                    return {
                        Instance = targetHead,
                        Position = headPos,
                        Normal = (origin - headPos).Unit,
                        Material = Enum.Material.Plastic,
                        Distance = distToHead
                    }
                else
                    return targetHead, headPos, (origin - headPos).Unit
                end
            end
        end
    end

    return old(self, ...)
end))

RunService.RenderStepped:Connect(function()
    if DrawLineObject then
        DrawLineObject.Visible = false
        if main.drawLine and main.enable then
            local head = getClosestHead()
            if head and head.Parent then
                local screenPoint, onScreen = Camera:WorldToViewportPoint(head.Position)
                local viewportSize = Camera.ViewportSize
                local screen2D = Vector2.new(screenPoint.X, screenPoint.Y)
                local inViewport = onScreen ~= nil and onScreen or (screenPoint.Z > 0)
                if inViewport and screen2D.X >= 0 and screen2D.X <= viewportSize.X and screen2D.Y >= 0 and screen2D.Y <= viewportSize.Y then
                    local screenCenter = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
                    DrawLineObject.Color = main.lineColor
                    DrawLineObject.From = screenCenter
                    DrawLineObject.To = screen2D
                    DrawLineObject.Visible = true
                end
            end
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
    Size = UDim2.fromOffset(300, 340),
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
    Callback = function(state) main.enable = state end
})

Main:Toggle({
    Title = "开启队伍验证",
    Image = "bird",
    Value = false,
    Callback = function(state) main.teamcheck = state end
})

Main:Toggle({
    Title = "开启好友验证",
    Image = "bird",
    Value = false,
    Callback = function(state) main.friendcheck = state end
})

Main:Toggle({
    Title = "目标连线",
    Image = "bird",
    Value = false,
    Callback = function(state) main.drawLine = state end
})

Main:Toggle({
    Title = "子弹穿墙",
    Image = "shield",
    Value = false,
    Callback = function(state) main.bulletPenetration = state end
})

-- 模式下拉（仅单选），选项拆分为单独模式
Main:Dropdown({
    Title = "模式",
    Values = { "Raycast", "FindPartOnRay", "FindPartOnRayWithIgnoreList", "FindPartOnRayWithWhitelist" },
    Value = "Raycast", -- 默认值
    Multi = false,
    Callback = function(Value)
        print("选中:", Value)
        main.rayMode = Value
        allowedMethods = getAllowedMethodsForMode(Value)
    end
})
