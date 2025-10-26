-- 多功能版
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local old
local main = {
    enable = false,
    teamcheck = false,
    friendcheck = false,
    enablenpc = false
}

-- // CHANGES: 少量新增参数（仅用于性能/兼容性调优）
local _THROTTLE = 0.02        -- 最小重定向间隔（秒），增加会降低 CPU 占用但可能稍降命中率
local _LAST_REDIRECT = 0
local _NPC_MAX_RADIUS = 120   -- NPC 搜索最大半径（stud），减少搜索开销

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

    -- 为了降低开销：限制搜索半径并尽量只遍历 Workspace 的直接子项（避免 GetDescendants 全遍历）
    for _, object in ipairs(Workspace:GetChildren()) do
        if object:IsA("Model") then
            local humanoid = object:FindFirstChildOfClass("Humanoid")
            local hrp = object:FindFirstChild("HumanoidRootPart") or object.PrimaryPart
            local head = object:FindFirstChild("Head")

            if humanoid and hrp and humanoid.Health > 0 then
                -- 排除玩家角色
                local isPlayer = false
                for _, pl in ipairs(Players:GetPlayers()) do
                    if pl.Character == object then
                        isPlayer = true
                        break
                    end
                end

                if not isPlayer and head then
                    local distance = (hrp.Position - localHrp.Position).Magnitude
                    if distance <= _NPC_MAX_RADIUS and distance < closestDistance then
                        closestHead = head
                        closestDistance = distance
                    end
                end
            end
        end
    end
    return closestHead
end

-- 关键改动：不再返回普通 table，而是重定向 Raycast 的 direction（args[2]），然后调用原始 Raycast 获取真正的 RaycastResult
old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if method == "Raycast" and not checkcaller() then
        local origin = args[1] or (Camera and Camera.CFrame.Position)
        -- 节流，避免每次 Raycast 都做昂贵计算
        local now = tick()
        if now - _LAST_REDIRECT < _THROTTLE then
            return old(self, ...)
        end

        if main.enable then
            _LAST_REDIRECT = now
            -- 优先玩家头
            local closestHead = getClosestHead()
            if closestHead then
                if origin and args[2] then
                    local origDir = args[2]
                    local len = origDir.Magnitude
                    if len <= 0 then len = 1000 end
                    local newDir = (closestHead.Position - origin).Unit * len
                    args[2] = newDir
                    return old(self, unpack(args))
                else
                    return old(self, ...)
                end
            end
        end

        if main.enablenpc then
            _LAST_REDIRECT = now
            local closestNpcHead = getClosestNpcHead()
            if closestNpcHead then
                if origin and args[2] then
                    local origDir = args[2]
                    local len = origDir.Magnitude
                    if len <= 0 then len = 1000 end
                    local newDir = (closestNpcHead.Position - origin).Unit * len
                    args[2] = newDir
                    return old(self, unpack(args))
                else
                    return old(self, ...)
                end
            end
        end
    end
    return old(self, ...)
end))

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
