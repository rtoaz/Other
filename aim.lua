local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local main = {
    enable = false,
    fovVisible = false,
    showRay = false, -- 新增射线显示控制
    teamcheck = false,
    friendcheck = false,
    fov = 100, -- 可调整FOV (屏幕像素)
    fovColor = Color3.fromRGB(255, 255, 255) -- 默认白色
}

-- 清理现有的 indexInstance 标志 (通用循环)
spawn(function()
    while true do
        wait(1)
        for _, obj in pairs(getgc(true)) do
            if type(obj) == "table" and rawget(obj, "indexInstance") then
                obj.indexInstance = nil
                print("已清理 indexInstance 标志")
            end
        end
    end
end)

-- 钩子 __newindex 以防止设置 indexInstance 或 ws/jp (通用防AC重置)
local mt = getrawmetatable(game)
local old_newindex = mt.__newindex

setreadonly(mt, false)

mt.__newindex = newcclosure(function(self, key, value)
    if checkcaller() then
        return old_newindex(self, key, value)
    end
    
    if key == "indexInstance" then
        print("已阻止 indexInstance 设置")
        return -- 忽略设置
    end
    
    if self:IsA("Humanoid") and (key == "WalkSpeed" or key == "JumpPower") then
        return -- 阻止 AC 重置
    end
    
    return old_newindex(self, key, value)
end)

-- 钩子 __index 以绕过检查 (伪装未标记)
local old_index = mt.__index

mt.__index = newcclosure(function(self, key)
    if checkcaller() then
        return old_index(self, key)
    end
    
    if key == "indexInstance" then
        return false -- 伪装为未被标记
    end
    
    return old_index(self, key)
end)

setreadonly(mt, true)

-- 强制相机跟随修复 (使用 RenderStepped 以更平滑更新)
spawn(function()
    RunService.RenderStepped:Connect(function()
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            Camera.CameraSubject = LocalPlayer.Character.Humanoid
            Camera.CameraType = Enum.CameraType.Custom
        end
    end)
end)

-- Raycast 钩子带方向长度检查 (优先跳过短射线以修复相机)
local old_namecall

old_namecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    -- 通用反崩溃 (如果适用)
    if not checkcaller() and getfenv(2).crash then
        local fenv = getfenv(2)
        fenv.crash = function() end
        setfenv(2, fenv)
    end

    -- Raycast 钩子：仅针对长射线 (射击) 修改，跳过短射线 (相机)
    if main.enable and method == "Raycast" and self == Workspace and not checkcaller() then
        local origin = args[1]
        local direction = args[2]
        local raycastParams = args[3]
        
        -- 修复 origin 类型：如果是 CFrame，取 Position
        local originPos = typeof(origin) == "CFrame" and origin.Position or origin
        
        -- 关键修复：如果方向长度 < 50，则跳过 (相机短射线，通常 <50 studs)
        if direction and direction.Magnitude < 50 then
            return old_namecall(self, ...)
        end
        
        -- 如果起点来自相机则额外跳过 (但现在方向检查为主)
        local cameraPos = Camera.CFrame.Position
        if (originPos - cameraPos).Magnitude < 5 then
            return old_namecall(self, ...)
        end
        
        -- 检查是否为射击上下文 (参数过滤自身角色)
        local isShooting = false
        
        if raycastParams and raycastParams.FilterType == Enum.RaycastFilterType.Blacklist then
            for _, filter in ipairs(raycastParams.FilterDescendantsInstances) do
                if filter == LocalPlayer.Character then
                    isShooting = true
                    break
                end
            end
        end
        
        -- 额外检查：如果方向很长且起点不是相机相关，视为射击
        if not isShooting and direction and direction.Magnitude > 100 then
            isShooting = true
        end
        
        if isShooting then
            local closestHead = getClosestHead()
            
            if closestHead and closestHead.Parent ~= LocalPlayer.Character then
                print("Raycast 已钩子 - 瞄准头部 (射击上下文): " .. closestHead.Parent.Name) -- 调试输出目标玩家名
                -- 执行原始Raycast以获取真实结果作为备选
                local originalResult = old_namecall(self, ...)
                
                if originalResult and originalResult.Instance then
                    -- 如果原始有击中，使用它（避免子弹消失）
                    return originalResult
                end
                
                local hitPosition = closestHead.Position
                local rayDirection = hitPosition - originPos
                local distance = math.min(rayDirection.Magnitude, direction.Magnitude) -- 限制距离不超过原方向长度
                local normal = (rayDirection.Unit * -1) -- 表面法线
                local material = closestHead.Material
                
                -- 创建假 RaycastResult (使用表模拟属性，避免方法调用错误)
                local fakeResult = {
                    Instance = closestHead,
                    Position = hitPosition,
                    Normal = normal,
                    Material = material,
                    Distance = distance
                }
                
                return fakeResult
            else
                print("无有效目标或锁定到自身 - 执行原始Raycast") -- 调试
                return old_namecall(self, ...) -- 始终返回原始，避免nil导致吞子弹
            end
        end
    end
    
    return old_namecall(self, ...)
end))

local function getClosestHead()
    local closestHead
    local closestDistance = main.fov * main.fov -- 使用平方以避免sqrt计算
    
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return
    end
    
    -- FOV现在固定在屏幕中心
    local viewportSize = Camera.ViewportSize
    local centerPos = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character ~= LocalPlayer.Character then -- 双重排除自身
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
                
                if head and humanoid and humanoid.Health > 0 and character ~= LocalPlayer.Character then -- 再次排除
                    -- 使用2D屏幕FOV检查 (中心点)
                    local screenPos, onScreen = Camera:WorldToScreenPoint(head.Position)
                    if onScreen then
                        local screenVector = Vector2.new(screenPos.X, screenPos.Y)
                        local distance2D = (screenVector - centerPos).Magnitude
                        
                        if distance2D * distance2D < closestDistance then
                            closestHead = head
                            closestDistance = distance2D * distance2D
                        end
                    end
                end
            end
        end
    end
    
    return closestHead
end

-- FOV显示使用ScreenGui (替代Drawing, 更兼容)
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FOVGui"
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
screenGui.ResetOnSpawn = false

local fovFrame = Instance.new("Frame")
fovFrame.Name = "FOVCircle"
fovFrame.Size = UDim2.new(0, main.fov * 2, 0, main.fov * 2)
fovFrame.Position = UDim2.new(0.5, -main.fov, 0.5, -main.fov) -- 固定在屏幕中心
fovFrame.BackgroundTransparency = 1
fovFrame.BorderSizePixel = 0
fovFrame.Visible = false
fovFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0.5, 0)
corner.Parent = fovFrame

local stroke = Instance.new("UIStroke")
stroke.Color = main.fovColor
stroke.Thickness = 3
stroke.Transparency = 0
stroke.Parent = fovFrame

-- 射线显示使用ScreenGui (模拟细线条从屏幕中心到目标屏幕位置)
local rayLine = Instance.new("Frame")
rayLine.Name = "RayLine"
rayLine.AnchorPoint = Vector2.new(0, 0.5) -- 锚点调整以从起点开始
rayLine.Size = UDim2.new(0, 0, 0, 2) -- 初始细高度 (厚度)
rayLine.BackgroundTransparency = 1
rayLine.BorderSizePixel = 0
rayLine.Visible = false
rayLine.Parent = screenGui

local rayStroke = Instance.new("UIStroke")
rayStroke.Color = main.fovColor
rayStroke.Thickness = 2
rayStroke.Transparency = 0
rayStroke.Parent = rayLine

RunService.RenderStepped:Connect(function()
    if main.enable then
        local viewportSize = Camera.ViewportSize
        local centerPos = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
        
        -- FOV更新 (独立控制，固定中心)
        if main.fovVisible then
            fovFrame.Position = UDim2.new(0.5, -main.fov, 0.5, -main.fov)
            fovFrame.Size = UDim2.new(0, main.fov * 2, 0, main.fov * 2)
            fovFrame.Visible = true
            stroke.Color = main.fovColor
            print("FOV显示已更新 - 固定中心") -- 调试: 确认FOV独立显示
        else
            fovFrame.Visible = false
        end
        
        -- 射线更新 (独立，从中心到目标，模拟细线)
        if main.showRay then
            local closestHead = getClosestHead()
            if closestHead and closestHead.Parent ~= LocalPlayer.Character then
                local screenPos, onScreen = Camera:WorldToScreenPoint(closestHead.Position)
                if onScreen then
                    local from = centerPos
                    local to = Vector2.new(screenPos.X, screenPos.Y)
                    local distance = (to - from).Magnitude
                    
                    if distance > 0 then
                        rayLine.Position = UDim2.new(0, from.X, 0, from.Y)
                        rayLine.Size = UDim2.new(0, distance, 0, 2) -- X=长度, Y=厚度
                        rayLine.Visible = true
                        rayStroke.Color = main.fovColor
                        
                        -- 旋转线条以匹配方向
                        local angle = math.atan2(to.Y - from.Y, to.X - from.X) * 180 / math.pi
                        rayLine.Rotation = angle
                        
                        print("射线已更新 - 长度:", distance, "角度:", angle) -- 调试: 确认射线
                    else
                        rayLine.Visible = false
                    end
                else
                    rayLine.Visible = false
                end
            else
                rayLine.Visible = false
            end
        else
            rayLine.Visible = false
        end
    else
        fovFrame.Visible = false
        rayLine.Visible = false
    end
end)

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
local Window = WindUI:CreateWindow({
    Title = "子弹追踪",
    Icon = "rbxassetid://129260712070622",
    IconThemed = true,
    Author = "idk",
    Folder = "CloudHub",
    Size = UDim2.fromOffset(300, 350),
    Transparent = true,
    Theme = "Dark",
    User = {
        Enabled = true,
        Callback = function()
            print("clicked")
        end,
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
    Color = ColorSequence.new(Color3.fromHex("FF0F7B"), Color3.fromHex("F89B29")),
    Draggable = true,
})

local MainSection = Window:Section({
    Title = "子追",
    Opened = true,
})

local Main = MainSection:Tab({
    Title = "设置",
    Icon = "Sword"
})

Main:Toggle({
    Title = "开启子弹追踪",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.enable = state
        print("Raycast追踪已" .. (state and "开启" or "关闭") .. " - 使用通用绕过。检查控制台钩子触发。")
    end
})

Main:Toggle({  -- FOV开启按钮
    Title = "开启FOV显示",
    Value = false, -- 初始值
    Type = "Toggle", -- 或 "Checkbox"
    Callback = function(Value)
        main.fovVisible = Value
        print("FOV显示状态:", Value)
    end
})

Main:Toggle({  -- 射线开启按钮
    Title = "显示射线",
    Value = false, -- 初始值
    Type = "Toggle", -- 或 "Checkbox"
    Callback = function(Value)
        main.showRay = Value
        print("射线显示状态:", Value)
    end
})

Main:Slider({
    Title = "FOV",
    Value = { Min = 50, Max = 500, Default = 100 },
    Callback = function(Value)
        main.fov = Value
        print("FOV设置为: " .. Value)
    end
})

Main:Colorpicker({
    Title = "FOV颜色选择",
    Default = Color3.fromRGB(255, 255, 255), -- 默认白色
    Callback = function(Color, Transparency)
        main.fovColor = Color
        stroke.Transparency = Transparency -- 同步透明度 (0=不透明, 1=透明)
        rayStroke.Transparency = Transparency
        print("FOV颜色设置为:", Color, "透明度:", Transparency)
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
