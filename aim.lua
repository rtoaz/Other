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

-- 新实现：手动相机跟随（在开启子弹追踪时启用），并在关闭时恢复原始相机状态
local _savedCameraState = {
    CameraType = nil,
    CameraSubject = nil,
    CameraCFrame = nil,
}
local manualFollow = {
    enabled = false,
    offset = nil, -- Vector3
}

-- helper: try to get a valid root part (HumanoidRootPart preferred)
local function getLocalRoot()
    if LocalPlayer and LocalPlayer.Character then
        return LocalPlayer.Character:FindFirstChild("HumanoidRootPart") or LocalPlayer.Character:FindFirstChild("Torso") or LocalPlayer.Character:FindFirstChild("UpperTorso")
    end
    return nil
end

-- 启用手动跟随：保存当前相机状态，计算并保存 offset（相机位置相对于角色位置）
local function enableManualFollow()
    if manualFollow.enabled then return end
    local root = getLocalRoot()
    if not root or not Camera then return end

    -- 保存当前相机状态以便恢复
    _savedCameraState.CameraType = Camera.CameraType
    _savedCameraState.CameraSubject = Camera.CameraSubject
    _savedCameraState.CameraCFrame = Camera.CFrame

    -- 计算并保存偏移（世界空间）
    manualFollow.offset = Camera.CFrame.Position - root.Position

    -- 切换到 Scriptable，由我们驱动 Camera.CFrame
    Camera.CameraType = Enum.CameraType.Scriptable

    manualFollow.enabled = true
end

-- 关闭手动跟随并恢复相机状态
local function disableManualFollow()
    if not manualFollow.enabled then return end
    if Camera then
        -- 恢复之前保存的相机类型和主体（如果存在）
        if _savedCameraState.CameraType then
            Camera.CameraType = _savedCameraState.CameraType
        end
        if _savedCameraState.CameraSubject then
            Camera.CameraSubject = _savedCameraState.CameraSubject
        end
        -- 恢复 CFrame（有助于减少跳动）
        if _savedCameraState.CameraCFrame then
            Camera.CFrame = _savedCameraState.CameraCFrame
        end
    end
    manualFollow.enabled = false
    manualFollow.offset = nil
end

-- RenderStepped 驱动：当手动跟随启用时设置 Camera.CFrame
RunService.RenderStepped:Connect(function(dt)
    -- 优先确保 Camera / LocalPlayer 存在
    if not LocalPlayer or not Camera then return end

    if main.enable then
        -- 当用户开启子弹追踪时，启用手动跟随（如果尚未启用）
        if not manualFollow.enabled then
            enableManualFollow()
        end

        if manualFollow.enabled then
            local root = getLocalRoot()
            if root and manualFollow.offset then
                -- 计算期望相机位置 = 角色位置 + 偏移（保持与开启时相对位置不变）
                local targetPos = root.Position
                local camPos = targetPos + manualFollow.offset

                -- 令摄像机朝向角色中心（保持稳定跟随）
                Camera.CFrame = CFrame.new(camPos, targetPos)
            else
                -- 如果角色丢失，先不要做任何写入（等待下一帧恢复）
            end
        end
    else
        -- 子弹追踪关闭 -> 如果手动跟随正在运行，恢复原相机并关闭手动跟随
        if manualFollow.enabled then
            disableManualFollow()
        end
        -- 不对相机做其它干涉，交还给游戏或玩家
    end
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
