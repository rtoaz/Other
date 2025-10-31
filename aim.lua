local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local old
local main = {
    enable = false,
    teamcheck = false,
    friendcheck = false,
    wallbang = false -- 子弹穿墙模式，默认关闭
}

-- 新增：目标连线开关（默认关闭）与绘图对象（默认白色）
main.targetLine = false
local DrawingAvailable, Drawing = pcall(function() return Drawing end)
local targetLineDrawing = nil
if DrawingAvailable and Drawing then
    local ok, lineObj = pcall(function()
        local l = Drawing.new("Line")
        l.Visible = false
        l.From = Vector2.new(0,0)
        l.To = Vector2.new(0,0)
        l.Color = Color3.fromRGB(255,255,255) -- 默认白色
        l.Thickness = 1.5
        l.Transparency = 1
        return l
    end)
    if ok then
        targetLineDrawing = lineObj
    end
end

local function getClosestHead()
    local closestHead
    local closestScore = math.huge

    if not LocalPlayer.Character then return end
    if not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end

    local viewportSize = Camera.ViewportSize
    local center = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)

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
                    local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                    -- 只考虑视角内的玩家
                    if onScreen then
                        local screenVec = Vector2.new(screenPos.X, screenPos.Y)
                        local distToCenter = (screenVec - center).Magnitude
                        -- 优先视线中间（距离中心小的优先），同时作为评分使用
                        if distToCenter < closestScore then
                            closestHead = head
                            closestScore = distToCenter
                        end
                    end
                end
            end
        end
    end
    return closestHead
end

old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if method == "Raycast" and not checkcaller() then
        local origin = args[1] or Camera.CFrame.Position

        if main.enable then
            local closestHead = getClosestHead()
            if closestHead then
                local direction = (closestHead.Position - origin).Unit
                local distance = (closestHead.Position - origin).Magnitude

                -- 使用原始（被保存的）metamethod来执行真实的射线检测以判断是否被遮挡
                local realResult = old(self, origin, direction * distance)

                -- 当“穿墙模式关闭”且射线检测到的第一个命中不是目标（即被墙或其他物体挡住）时，调用原始行为（不伪造命中）
                if not main.wallbang then
                    if realResult and realResult.Instance then
                        -- 如果真实命中的是目标或目标的子部件，则允许伪造命中（视为未被阻挡）
                        if realResult.Instance:IsDescendantOf(closestHead.Parent) == false then
                            return old(self, ...)
                        end
                    else
                        -- 没有真实命中（视线透明），继续走后面的伪造命中逻辑（允许命中）
                        -- do nothing here, 会走到返回伪造命中的代码
                    end
                end

                -- 否则（穿墙模式打开 或 目标可见），返回伪造的命中结果
                return {
                    Instance = closestHead,
                    Position = closestHead.Position,
                    Normal = (origin - closestHead.Position).Unit,
                    Material = Enum.Material.Plastic,
                    Distance = distance
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
    Title = "开启子弹穿墙",
    Image = "shield",
    Value = false,
    Callback = function(state)
        main.wallbang = state
    end
})

-- 增加 UI 开关：目标连线（默认白色，默认关闭，子弹追踪未开启也有效）
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

-- 更新连线位置（每帧）——即使子弹追踪未开启也会生效
local RunService = game:GetService("RunService")
RunService.RenderStepped:Connect(function()
    if targetLineDrawing then
        if main.targetLine then
            local target = getClosestHead()
            if target and target.Parent then
                local screenPos, onScreen = Camera:WorldToViewportPoint(target.Position)
                if onScreen then
                    local viewportSize = Camera.ViewportSize
                    local center = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
                    -- 从视角中心到目标头部的连线
                    targetLineDrawing.From = center
                    targetLineDrawing.To = Vector2.new(screenPos.X, screenPos.Y)
                    targetLineDrawing.Visible = true
                else
                    targetLineDrawing.Visible = false
                end
            else
                targetLineDrawing.Visible = false
            end
        else
            targetLineDrawing.Visible = false
        end
    end
end)
