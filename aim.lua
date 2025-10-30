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
    bulletPenetration = false, -- 子弹穿墙开关（false = 不穿墙，true = 强制命中头部）
    drawLine = false, -- 目标连线开关（默认关闭）
}

-- 获取视角中心优先的最近玩家头部
local function getClosestHead()
    local closestHead
    local closestScreenDistance = math.huge

    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end

    local screenCenter = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)

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
                        local distanceToCenter = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                        if distanceToCenter < closestScreenDistance then
                            closestHead = head
                            closestScreenDistance = distanceToCenter
                        end
                    end
                end
            end
        end
    end
    return closestHead
end

-- Hook Raycast 进行子弹追踪
old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if method == "Raycast" and not checkcaller() then
        local origin = args[1] or Camera.CFrame.Position
        local direction = args[2] or (Camera.CFrame.LookVector * 1000)

        if main.enable then
            local closestHead = getClosestHead()
            if closestHead then
                -- 如果开启了穿墙（强制命中），直接返回目标头部的信息
                if main.bulletPenetration then
                    return {
                        Instance = closestHead,
                        Position = closestHead.Position,
                        Normal = (origin - closestHead.Position).Unit,
                        Material = Enum.Material.Plastic,
                        Distance = (closestHead.Position - origin).Magnitude
                    }
                else
                    -- 否则使用原始 metamethod 对 Workspace 做一次明确的 LOS（Raycast）检测
                    -- 这样可以避免部分游戏/调用路径导致直接使用 realResult 判断失效的情况
                    local rayParams = RaycastParams.new()
                    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
                    rayParams.FilterDescendantsInstances = {LocalPlayer.Character}
                    rayParams.IgnoreWater = true

                    local dirToHead = (closestHead.Position - origin)
                    -- 使用 old 直接以 Workspace 作为 self 调用原始 metamethod，避免再次触发 hook
                    local losResult = nil
                    local success, res = pcall(function()
                        return old(Workspace, origin, dirToHead, rayParams)
                    end)
                    if success then losResult = res end

                    -- 如果 LOS 检测命中了东西
                    if losResult and losResult.Instance then
                        local hitInst = losResult.Instance
                        if hitInst == closestHead or hitInst:IsDescendantOf(closestHead.Parent) then
                            -- 可以直射命中头部 -> 指向头部
                            return {
                                Instance = closestHead,
                                Position = closestHead.Position,
                                Normal = (origin - closestHead.Position).Unit,
                                Material = Enum.Material.Plastic,
                                Distance = (closestHead.Position - origin).Magnitude
                            }
                        else
                            -- 被遮挡（墙体等）-> 返回真实 LOS 结果（例如墙体）
                            return losResult
                        end
                    else
                        -- LOS 检测没命中（极少或异常情况）：为了兼容性，退回到调用处的原始 Raycast 结果
                        -- 这里用 pcall 调用原始 metamethod 以避免意外崩溃
                        local ok, originalResult = pcall(function() return old(self, unpack(args)) end)
                        if ok and originalResult then
                            return originalResult
                        end
                        -- 如果都没有可用结果，则作为最后手段指向头部
                        return {
                            Instance = closestHead,
                            Position = closestHead.Position,
                            Normal = (origin - closestHead.Position).Unit,
                            Material = Enum.Material.Plastic,
                            Distance = (closestHead.Position - origin).Magnitude
                        }
                    end
                end
            end
        end
    end
    return old(self, ...)
end))

-- UI加载
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

-- 新增：子弹穿墙开关（默认 false）
Main:Toggle({
    Title = "开启子弹穿墙",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.bulletPenetration = state
    end
})

-- 新增：目标连线开关（默认 false）
Main:Toggle({
    Title = "开启目标连线",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.drawLine = state
    end
})

-- 目标连线（使用 Drawing，如果可用则显示从屏幕中心到目标头部的线）
local drawingEnabled, Drawing = pcall(function() return Drawing end)
local targetLine
if drawingEnabled and Drawing then
    local success, ok = pcall(function()
        targetLine = Drawing.new("Line")
        targetLine.Visible = false
        targetLine.Transparency = 1
        targetLine.Thickness = 2
        targetLine.From = Vector2.new(0,0)
        targetLine.To = Vector2.new(0,0)
        targetLine.Color = Color3.fromRGB(255, 255, 255) -- 默认白色
    end)
    if not success then
        targetLine = nil
    end
end

-- 更新连线的渲染逻辑
RunService.RenderStepped:Connect(function()
    if not Camera then return end
    if not LocalPlayer.Character then
        if targetLine then targetLine.Visible = false end
        return
    end

    if main.enable and main.drawLine and targetLine then
        local closestHead = getClosestHead()
        if closestHead then
            local screenCenter = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
            local toPos, onScreen = Camera:WorldToViewportPoint(closestHead.Position)
            if onScreen then
                targetLine.From = screenCenter -- 从屏幕中间开始
                targetLine.To = Vector2.new(toPos.X, toPos.Y)
                targetLine.Visible = true
            else
                targetLine.Visible = false
            end
        else
            targetLine.Visible = false
        end
    else
        if targetLine then targetLine.Visible = false end
    end
end)
