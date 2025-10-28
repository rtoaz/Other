local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local old_namecall
local main = {
    enable = false,
    teamcheck = false,
    friendcheck = false
}

-- 提升线程身份到8级（最高级别，用于更强的绕过检测，如果你的执行器支持）
if set_thread_identity then
    set_thread_identity(8)  -- 最高权限级别
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

-- __namecall hook for Raycast
local mt = getrawmetatable(game)
old_namecall = mt.__namecall
setreadonly(mt, false)

local new_namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if method == "Raycast" and self == Workspace and not checkcaller() then
        local origin = args[1]
        local direction = args[2]
        local params = args[3]

        if main.enable then
            local closestHead = getClosestHead()
            if closestHead then
                -- 检查如果head在params.Blacklist中，跳过（兼容忽略列表）
                if params and params.FilterType == Enum.RaycastFilterType.Blacklist then
                    local blacklisted = false
                    for _, ignore in ipairs(params.FilterDescendantsInstances or {}) do
                        if closestHead:IsDescendantOf(ignore) then
                            blacklisted = true
                            break
                        end
                    end
                    if blacklisted then
                        return old_namecall(self, ...)
                    end
                end

                local hitPos = closestHead.Position
                local dirVector = (hitPos - origin).Unit * direction.Magnitude
                local unitNormal = (origin - hitPos).Unit  -- 修正normal为负方向（标准hack）
                local distance = (hitPos - origin).Magnitude
                print("Raycast 追踪到目标: " .. closestHead.Parent.Name .. " at distance: " .. distance)  -- 调试
                return RaycastResult.new(closestHead, hitPos, unitNormal, Enum.Material.Plastic, distance)
            end
        end
    end
    return old_namecall(self, ...)
end)

mt.__namecall = new_namecall
setreadonly(mt, true)

-- 新：相机跟随管理器（用于修复“开启子弹追踪相机冻结不跟随人物”的问题）
-- 说明：
--  * 只在 main.enable == true 时强制确保 CameraType 为 Custom 且 CameraSubject 指向当前角色的 Humanoid。
--  * 通过 RenderStepped 进行检测，但仅在需要修改时才写入 Camera 属性，避免干扰玩家手动切换相机并降低卡顿风险。
local cameraEnforcerConnection
cameraEnforcerConnection = RunService.RenderStepped:Connect(function()
    -- 如果没有角色或摄像机，跳过
    if not LocalPlayer or not LocalPlayer.Character or not Camera then
        return
    end

    -- 只在子弹追踪开启时修正相机，避免无谓干涉
    if main.enable then
        local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            -- 仅在必须时修改，减少写入导致的“冻结”
            if Camera.CameraType ~= Enum.CameraType.Custom then
                Camera.CameraType = Enum.CameraType.Custom
            end
            if Camera.CameraSubject ~= humanoid then
                Camera.CameraSubject = humanoid
            end
        end
    end
    -- 当 main.enable == false 时我们不主动恢复或修改相机，让游戏/玩家控制恢复默认行为
end)

-- 额外：如果检测基于 fenv 泄漏，使用这个来清理环境（可选）
local cleanEnv = getfenv()
for k, v in pairs(cleanEnv) do
    if type(k) == "string" and (k:find("hook") or k:find("exploit")) then
        cleanEnv[k] = nil
    end
end

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
        print("子弹追踪已" .. (state and "开启" or "关闭"))  -- 添加打印调试
        -- 注：相机跟随管理器会在 RenderStepped 中自动响应 main.enable 的变化
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
