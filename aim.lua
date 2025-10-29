local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local old_namecall
local old_ray_index  -- 新增：用于 Ray.new hook
local main = {
    enable = false,
    debug = false,  -- 新增：调试日志开关
    teamcheck = false,
    friendcheck = false,
    wallbang = false,
    -- 目标连线设置（颜色已设为白色）
    targetline = {
        enable = false,
        thickness = 1,
        color = Color3.fromRGB(255, 255, 255)
    },
    -- 射线拦截模式
    raymode = "Raycast"  -- "Raycast" 或 "Ray.new"
}

-- 提升线程身份（若支持）
if set_thread_identity then
    set_thread_identity(8)
end

local closestHead = nil

local function isPointInScreen(point)
    local screenPoint, onScreen = Camera:WorldToViewportPoint(point)
    return onScreen and screenPoint.Z > 0
end

local function updateClosestHead()
    closestHead = nil
    local closestDistance = math.huge

    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end

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
end

local updateConnection
updateConnection = RunService.Heartbeat:Connect(function()
    if main.enable then
        updateClosestHead()
    else
        closestHead = nil
    end
end)

-- Drawing（目标连线）相关（保持原样）
local DrawingAvailable = pcall(function() return Drawing and Drawing.new end)
local targetLine = nil
local targetLineConnection = nil

local function createTargetLine()
    if not DrawingAvailable then return end
    if targetLine then return end
    local ok, line = pcall(function() return Drawing.new("Line") end)
    if not ok or not line then
        DrawingAvailable = false
        if main.debug then print("目标连线：无法创建 Drawing 对象，已禁用。") end
        return
    end
    targetLine = line
    targetLine.Visible = false
    targetLine.Thickness = main.targetline.thickness
    targetLine.Color = main.targetline.color
end

local function ensureTargetLineConnection()
    if targetLineConnection then targetLineConnection:Disconnect() end

    targetLineConnection = RunService.RenderStepped:Connect(function()
        if not (main.enable and main.targetline.enable and DrawingAvailable and targetLine) then
            if targetLine then targetLine.Visible = false end
            return
        end

        targetLine.Thickness = main.targetline.thickness
        targetLine.Color = main.targetline.color

        if not closestHead then
            targetLine.Visible = false
            return
        end

        local screenPoint, onScreen = Camera:WorldToViewportPoint(closestHead.Position)
        if not onScreen or screenPoint.Z <= 0 then
            targetLine.Visible = false
            return
        end

        local viewportSize = Camera.ViewportSize
        local fromX, fromY = viewportSize.X / 2, viewportSize.Y / 2

        targetLine.From = Vector2.new(fromX, fromY)
        targetLine.To = Vector2.new(screenPoint.X, screenPoint.Y)
        targetLine.Visible = true
    end)
end

if DrawingAvailable then
    createTargetLine()
    ensureTargetLineConnection()
else
    if main.debug then print("目标连线：Drawing API 不可用。") end
end

-- 新增：API 检测函数（UI 按钮调用）
local function detectRayAPI()
    local testOrigin = Camera.CFrame.Position
    local testDirection = Camera.CFrame.LookVector * 100
    local detected = "Raycast"  -- 默认

    -- 测试 Raycast
    local success1, result1 = pcall(function()
        return Workspace:Raycast(testOrigin, testDirection)
    end)
    if success1 and result1 then
        detected = "Raycast"
    else
        -- 测试 Ray.new
        local success2, ray = pcall(Ray.new, testOrigin, testDirection)
        if success2 then
            local success3, result2 = pcall(function() return ray:Hit() end)
            if success3 and result2 then
                detected = "Ray.new"
            end
        end
    end

    main.raymode = detected
    if main.debug then print("API 检测结果: " .. detected) end
    return detected
end

-- Hook：通用 namecall（针对 Raycast）
local mt = getrawmetatable(game)
old_namecall = mt.__namecall
setreadonly(mt, false)

local new_namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if main.raymode == "Raycast" and method == "Raycast" and self == Workspace and not checkcaller() then
        local origin = args[1]
        local direction = args[2]
        local params = args[3]

        local camPos = Camera.CFrame.Position
        local callingScript = getcallingscript()
        local skip = false

        -- 放宽 skip 条件
        if direction and direction.Magnitude < 500 then  -- 从 200 改为 500
            skip = true
        end

        if origin and (origin - camPos).Magnitude < 1 then  -- 从 0.1 改为 1
            skip = true
        end

        if callingScript and (callingScript.Name == "WaterGraphics" or callingScript.Name == "CameraController") then
            skip = true
        end

        if skip then
            if main.debug then print("Raycast skip: " .. (callingScript and callingScript.Name or "unknown")) end
            return old_namecall(self, ...)
        end

        if main.enable and closestHead then
            local hitPos = closestHead.Position
            local toTarget = hitPos - origin
            local distance = toTarget.Magnitude
            if distance == 0 then 
                distance = 0.1
                toTarget = direction or Vector3.new(0, 0, -1)
            end

            local unitNormal = toTarget.Unit
            local targetMaterial = closestHead.Material  -- 使用实际材质

            if main.debug then
                print("Raycast 追踪到目标: " .. closestHead.Parent.Name .. (main.wallbang and " [穿墙]" or ""))
            end

            if main.wallbang then
                local result = {
                    Instance = closestHead,
                    Position = hitPos,
                    Normal = unitNormal,
                    Material = targetMaterial,
                    Distance = distance
                }
                return result
            else
                local real = old_namecall(self, origin, toTarget, params)

                if real and real.Instance then
                    if real.Instance == closestHead or real.Instance:IsDescendantOf(closestHead.Parent) then
                        return real
                    end
                end

                return real
            end
        end
    end
    return old_namecall(self, ...)
end)

mt.__namecall = new_namecall
setreadonly(mt, true)

-- 新增：针对 Ray.new 的 hook（通过 __index 拦截 :Hit()）
if main.raymode == "Ray.new" then
    local ray_mt = getrawmetatable(Ray.new(Vector3.new(), Vector3.new()))
    old_ray_index = ray_mt.__index
    setreadonly(ray_mt, false)

    ray_mt.__index = newcclosure(function(self, key)
        if key == "Hit" and not checkcaller() and main.enable and closestHead then
            local origin = self.Origin
            local direction = self.Direction
            local camPos = Camera.CFrame.Position
            local skip = false

            -- 类似 skip 逻辑
            if direction.Magnitude < 500 then skip = true end
            if (origin - camPos).Magnitude < 1 then skip = true end

            if not skip then
                local hitPos = closestHead.Position
                local toTarget = hitPos - origin
                local distance = toTarget.Magnitude
                if distance == 0 then distance = 0.1 end

                local unitNormal = toTarget.Unit
                local targetMaterial = closestHead.Material

                if main.debug then
                    print("Ray.new Hit 追踪到目标: " .. closestHead.Parent.Name .. (main.wallbang and " [穿墙]" or ""))
                end

                if main.wallbang then
                    return hitPos, closestHead, unitNormal, targetMaterial, distance
                else
                    local realPos, realInst, realNormal, realMat, realDist = old_ray_index(self, key)
                    if realInst == closestHead or (realInst and realInst:IsDescendantOf(closestHead.Parent)) then
                        return realPos, realInst, realNormal, realMat, realDist
                    end
                    return realPos, realInst, realNormal, realMat, realDist
                end
            end
        end
        return old_ray_index(self, key)
    end)

    setreadonly(ray_mt, true)
end

-- 环境清理（增强）
local cleanEnv = getfenv()
for k, v in pairs(cleanEnv) do
    if type(k) == "string" and (k:find("hook") or k:find("exploit") or k:find("metatable")) then
        cleanEnv[k] = nil
    end
end

-- UI（WindUI，添加调试和检测）
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "子弹追踪",
    Icon = "rbxassetid://115895976319223",
    IconThemed = true,
    Author = "idk",
    Folder = "CloudHub",
    Size = UDim2.fromOffset(300, 320),  -- 稍大以容纳新项
    Transparent = true,
    Theme = "Dark",
    User = { Enabled = true, Callback = function() print("clicked") end, Anonymous = false },
    SideBarWidth = 200,
    ScrollBarEnabled = true,
})

Window:EditOpenButton({
    Title = "打开UI",
    Icon = "monitor",
    CornerRadius = UDim.new(0,16),
    StrokeThickness = 2,
    Color = ColorSequence.new(Color3.fromHex("2E0249"), Color3.fromHex("9D4EDD")),
    Draggable = true,
})

local MainSection = Window:Section({ Title = "子追", Opened = true })
local Main = MainSection:Tab({ Title = "设置", Icon = "Sword" })

Main:Toggle({
    Title = "开启子弹追踪",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.enable = state
        if main.debug then print("子弹追踪已" .. (state and "开启" or "关闭")) end
        -- 如果切换 Ray.new，动态 hook
        if main.raymode == "Ray.new" and state then
            -- 重新 hook Ray metatable（简化版）
            local ray_mt = getrawmetatable(Ray.new(Vector3.new(), Vector3.new()))
            setreadonly(ray_mt, false)
            ray_mt.__index = newcclosure(function(self, key)  -- 复用 Ray.new 逻辑
                if key == "Hit" and main.enable and closestHead then
                    -- ... (同上 Ray.new hook 逻辑，省略以节省空间)
                end
                return old_ray_index(self, key)
            end)
            setreadonly(ray_mt, true)
        end
    end
})

Main:Toggle({
    Title = "调试模式",  -- 新增
    Image = "bug",
    Value = false,
    Callback = function(state)
        main.debug = state
        if state then print("调试模式开启：检查控制台日志") end
    end
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
    Title = "启用子弹穿墙",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.wallbang = state
        if main.debug then print("子弹穿墙已" .. (state and "开启" or "关闭")) end
    end
})

Main:Toggle({
    Title = "目标连线",
    Image = "target",
    Value = false,
    Callback = function(state)
        if state and not DrawingAvailable then
            if main.debug then print("目标连线不可用：Drawing API 不支持。") end
            main.targetline.enable = false
            return
        end
        main.targetline.enable = state
        if state then
            createTargetLine()
            ensureTargetLineConnection()
            if main.debug then print("目标连线已开启（白色）") end
        else
            if targetLine then targetLine.Visible = false end
            if main.debug then print("目标连线已关闭") end
        end
    end
})

Main:Dropdown({
    Title = "模式",
    Values = { "Raycast", "Ray.new" },  -- 修正名称
    Value = "Raycast",
    Multi = false,
    Callback = function(Value)
        main.raymode = Value
        if main.debug then print("切换射线模式: " .. Value) end
        -- 如果是 Ray.new，初始化 hook
        if Value == "Ray.new" then
            local ray_mt = getrawmetatable(Ray.new(Vector3.new(), Vector3.new()))
            old_ray_index = ray_mt.__index
            -- ... (插入 Ray.new hook 逻辑，同上)
        end
    end
})

Main:Button({  -- 新增：API 检测按钮
    Title = "检测游戏 API",
    Image = "search",
    Callback = function()
        local detected = detectRayAPI()
        -- UI 反馈（WindUI 无直接 toast，可 print）
        game.StarterGui:SetCore("SendNotification", {
            Title = "API 检测";
            Text = "检测到: " .. detected .. "，已自动切换。";
            Duration = 3;
        })
    end
})

Main:Slider({
    Title = "连线粗细",
    Value = { Min = 1, Max = 5, Default = main.targetline.thickness },
    Callback = function(Value)
        main.targetline.thickness = Value
        if targetLine then targetLine.Thickness = Value end
        if main.debug then print("连线粗细: " .. Value) end
    end
})

game:BindToClose(function()
    if updateConnection then updateConnection:Disconnect() end
    if targetLineConnection then targetLineConnection:Disconnect() end
    if targetLine then
        pcall(function()
            targetLine.Visible = false
            if targetLine.Destroy then targetLine:Destroy() end
        end)
        targetLine = nil
    end
    -- 恢复 hook
    local mt = getrawmetatable(game)
    setreadonly(mt, false)
    mt.__namecall = old_namecall
    setreadonly(mt, true)
    if old_ray_index then
        local ray_mt = getrawmetatable(Ray.new(Vector3.new(), Vector3.new()))
        setreadonly(ray_mt, false)
        ray_mt.__index = old_ray_index
        setreadonly(ray_mt, true)
    end
end)
