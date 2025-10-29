local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local old_namecall
local main = {
    enable = false,
    teamcheck = false,
    friendcheck = false,
    wallbang = false
}

-- 提升线程身份到8级（最高级别，用于更强的绕过检测，推荐Delta）
if set_thread_identity then
    set_thread_identity(8)  -- 最高权限级别
end

local function isPointInScreen(point)
    local screenPoint, onScreen = Camera:WorldToViewportPoint(point)
    return onScreen and screenPoint.Z > 0
end

local function getClosestHeadInView()
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
                    -- 必须在屏幕内
                    if isPointInScreen(head.Position) then
                        local distance = (root.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
                        if distance < closestDistance then
                            closestHead = head
                            closestDistance = distance
                        end
                    end
                end
            end
        end
    end
    return closestHead
end

-- 回到 __namecall hook，但用 getrawmetatable(game) 更隐蔽（避免直接 hookmetamethod 被检测）
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

        -- 【终极修复相机冻结】：多层过滤（位置 + 方向 + 调用者）
        local camPos = Camera.CFrame.Position
        local camLook = Camera.CFrame.LookVector
        if origin and (origin - camPos).Magnitude < 1 and direction then
            local dirUnit = direction.Unit
            if dirUnit.Magnitude > 0 and (dirUnit - camLook).Magnitude < 0.01 then  -- 方向匹配相机前向
                return old_namecall(self, ...)
            end
            if direction.Magnitude < 100 then  -- 短距离射线
                return old_namecall(self, ...)
            end
        end

        -- 过滤所有相机相关脚本（扩展到 PlayerScripts 下所有）
        local callingScript = getcallingscript()
        if callingScript then
            local parent = callingScript.Parent
            if parent and (parent.Name == "CameraController" or parent.Name == "WaterGraphics" or parent:IsA("PlayerScripts")) then
                return old_namecall(self, ...)
            end
        end

        if main.enable then
            local closestHead = getClosestHeadInView()
            if closestHead then
                local hitPos = closestHead.Position
                local toTarget = hitPos - origin
                local distance = toTarget.Magnitude
                if distance == 0 then 
                    distance = 0.1
                    toTarget = direction or Vector3.new(0, 0, -1)
                end

                local unitNormal = toTarget.Unit

                print("Raycast 追踪到目标: " .. closestHead.Parent.Name .. (main.wallbang and " [穿墙]" or ""))

                -- 构造测试参数：忽略目标角色
                local testParams
                if params then
                    testParams = Instance.new("RaycastParams")
                    testParams.FilterType = params.FilterType
                    testParams.IgnoreWater = params.IgnoreWater

                    -- 复制过滤列表
                    local filterList = {}
                    for _, inst in ipairs(params.FilterDescendantsInstances) do
                        table.insert(filterList, inst)
                    end

                    -- 调整以忽略目标角色
                    local targetChar = closestHead.Parent
                    if params.FilterType == Enum.RaycastFilterType.Exclude then
                        -- Exclude: 添加目标到排除列表
                        table.insert(filterList, targetChar)
                    else
                        -- Include: 从包含列表移除目标
                        local targetIndex = table.find(filterList, targetChar)
                        if targetIndex then
                            table.remove(filterList, targetIndex)
                        end
                    end

                    testParams.FilterDescendantsInstances = filterList
                else
                    -- 默认参数：排除目标
                    testParams = Instance.new("RaycastParams")
                    testParams.FilterType = Enum.RaycastFilterType.Exclude
                    testParams.FilterDescendantsInstances = {closestHead.Parent}
                    testParams.IgnoreWater = false
                end

                -- 测试射线：检查路径是否通畅（忽略目标）
                local testResult = old_namecall(self, origin, toTarget, testParams)
                local blocked = testResult and testResult.Distance < distance - 0.1

                -- 如果通畅或启用穿墙，则伪造命中
                if not blocked or main.wallbang then
                    local result = {
                        Instance = closestHead,
                        Position = hitPos,
                        Normal = unitNormal,
                        Material = Enum.Material.Plastic,
                        Distance = distance
                    }
                    return result
                end
                -- 否则，使用原始射线（尊重墙体）
            end
        end
    end
    return old_namecall(self, ...)
end)

mt.__namecall = new_namecall
setreadonly(mt, true)

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
        print("子弹追踪已" .. (state and "开启" or "关闭"))
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
    Title = "启用子弹穿墙",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.wallbang = state
        print("子弹穿墙已" .. (state and "开启" or "关闭"))
    end
})
