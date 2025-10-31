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

old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if method == "Raycast" and not checkcaller() then
        local origin = args[1] or (Camera and Camera.CFrame and Camera.CFrame.Position) or Vector3.new()
        -- 仅拦截靠近摄像机的射线（避免拦截引擎/渲染使用的全局射线）
        local camPos = (Camera and Camera.CFrame and Camera.CFrame.Position) or origin
        local originDist = (origin - camPos).Magnitude
        if originDist > 20 then
            return old(self, ...)
        end

        if main.enable then
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
