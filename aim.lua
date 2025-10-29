local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local old_namecall
local main = {
    enable = false,
    teamcheck = false,
    friendcheck = false,
    wallbang = false,
    -- 新增：目标连线设置（颜色已设为白色）
    targetline = {
        enable = false,
        thickness = 1, -- 默认粗细
        color = Color3.fromRGB(255, 255, 255) -- 已改为白色
    },
    -- 新增：射线拦截模式（默认为原来的 Raycast）
    raymode = "Raycast" -- 可选 "Raycast" 或 "Ray.naw"
}

-- 提升线程身份到8级（若环境支持）
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

-- Drawing（目标连线）相关准备
local DrawingAvailable = false
local targetLine = nil
local targetLineConnection = nil

if pcall(function() return Drawing and Drawing.new end) then
    DrawingAvailable = true
else
    DrawingAvailable = false
end

local function createTargetLine()
    if not DrawingAvailable then
        return
    end
    if targetLine then return end
    local ok, line = pcall(function()
        return Drawing.new("Line")
    end)
    if not ok or not line then
        DrawingAvailable = false
        print("目标连线：无法创建 Drawing 对象，已禁用目标连线功能。")
        return
    end
    targetLine = line
    targetLine.Visible = false
    targetLine.Thickness = main.targetline.thickness or 1
    targetLine.Color = main.targetline.color or Color3.fromRGB(255,255,255)
end

local function ensureTargetLineConnection()
    if targetLineConnection then
        targetLineConnection:Disconnect()
        targetLineConnection = nil
    end

    targetLineConnection = RunService.RenderStepped:Connect(function()
        if not (main.enable and main.targetline.enable and DrawingAvailable and targetLine) then
            if targetLine then targetLine.Visible = false end
            return
        end

        targetLine.Thickness = main.targetline.thickness or 1
        targetLine.Color = main.targetline.color or Color3.fromRGB(255,255,255)

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
        local fromX = viewportSize.X / 2
        local fromY = viewportSize.Y / 2

        targetLine.From = Vector2.new(fromX, fromY)
        targetLine.To = Vector2.new(screenPoint.X, screenPoint.Y)
        targetLine.Visible = true
    end)
end

if DrawingAvailable then
    createTargetLine()
    ensureTargetLineConnection()
else
    print("目标连线：Drawing API 不可用，目标连线功能被跳过。")
end

-- namecall hook（保留你原有的行为与防护逻辑）
local mt = getrawmetatable(game)
old_namecall = mt.__namecall
setreadonly(mt, false)

local new_namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    -- 使用 main.raymode 而不是硬编码 "Raycast"
    if method == main.raymode and self == Workspace and not checkcaller() then
        local origin = args[1]
        local direction = args[2]
        local params = args[3]

        local camPos = Camera.CFrame.Position
        local callingScript = getcallingscript()
        local skip = false

        if direction and direction.Magnitude < 200 then
            skip = true
        end

        if origin and (origin - camPos).Magnitude < 0.1 then
            skip = true
        end

        if callingScript and (callingScript.Name == "WaterGraphics" or callingScript.Name == "CameraController") then
            skip = true
        end

        if skip then
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

            print(main.raymode .. " 追踪到目标: " .. closestHead.Parent.Name .. (main.wallbang and " [穿墙]" or ""))

            if main.wallbang then
                local result = {
                    Instance = closestHead,
                    Position = hitPos,
                    Normal = unitNormal,
                    Material = Enum.Material.Plastic,
                    Distance = distance
                }
                return result
            else
                local real = old_namecall(self, origin, toTarget, params)

                if real and real.Instance then
                    if real.Instance == closestHead or real.Instance:IsDescendantOf(closestHead.Parent) then
                        return real
                    else
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

-- 环境清理（可选）
local cleanEnv = getfenv()
for k, v in pairs(cleanEnv) do
    if type(k) == "string" and (k:find("hook") or k:find("exploit")) then
        cleanEnv[k] = nil
    end
end

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
        Color3.fromHex("2E0249"), 
        Color3.fromHex("9D4EDD")
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

-- 目标连线开关（颜色为白色）
Main:Toggle({
    Title = "目标连线",
    Image = "target",
    Value = false,
    Callback = function(state)
        if state and not DrawingAvailable then
            print("目标连线不可用：当前环境不支持 Drawing API。")
            main.targetline.enable = false
            return
        end

        main.targetline.enable = state
        if state then
            createTargetLine()
            ensureTargetLineConnection()
            print("目标连线已开启（白色）")
        else
            if targetLine then
                targetLine.Visible = false
            end
            print("目标连线已关闭")
        end
    end
})

-- 模式选择菜单
Main:Dropdown({
    Title = "模式",
    Values = { "Raycast", "Ray.naw" },
    Value = "Raycast",
    Multi = false,
    Callback = function(Value)
        -- 将选择的值保存到 main.raymode，名字必须与 getnamecallmethod() 返回的字符串一致
        main.raymode = Value
        print("选中射线方法:", Value)
    end
})

-- 连线粗细调整
Main:Slider({
    Title = "连线粗细",
    Value = { Min = 1, Max = 5, Default = main.targetline.thickness },
    Callback = function(Value)
        main.targetline.thickness = Value
        if targetLine then
            targetLine.Thickness = Value
        end
        -- 打印便于调试
        print("连线粗细:", Value)
    end
})

game:BindToClose(function()
    if updateConnection then
        updateConnection:Disconnect()
    end
    if targetLineConnection then
        targetLineConnection:Disconnect()
    end
    if targetLine then
        pcall(function()
            targetLine.Visible = false
            if targetLine.Destroy then
                targetLine:Destroy()
            end
        end)
        targetLine = nil
    end
end)
