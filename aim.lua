local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local main = {
    enable = false,
    teamcheck = false,
    friendcheck = false,
    fov = 100, -- 可调整FOV
    fovColor = Color3.fromRGB(255, 255, 255) -- 默认白色
}

-- Da Hood / Adonis-like 反作弊绕过
local tablefind = table.find
local MainEvent = ReplicatedStorage:WaitForChild("MainEvent", 5) -- Da Hood 特定
local Flags = {"CHECKER_1", "TeleportDetect", "OneMoreTime", "indexInstance"} -- 常见标志

-- 清理现有的 indexInstance 标志 (运行一次)
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

-- 钩子 __newindex 以防止设置 indexInstance 或 ws/jp
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

-- 钩子 __index 以绕过检查
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

-- Raycast 钩子带相机跳过 (修复冻结和开火问题)
local old_namecall

old_namecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    -- 绕过检测 (例如，FireServer 标志)
    if method == "FireServer" and MainEvent and self == MainEvent and tablefind(Flags, args[1]) then
        print("已绕过 FireServer 标志: " .. tostring(args[1]))
        return
    end

    -- 反崩溃 (如果适用)
    if not checkcaller() and getfenv(2).crash then
        local fenv = getfenv(2)
        fenv.crash = function() end
        setfenv(2, fenv)
    end

    -- Raycast 钩子：仅针对射击修改 (跳过相机射线)
    if main.enable and method == "Raycast" and self == Workspace and not checkcaller() then
        local origin = args[1]
        local direction = args[2]
        local raycastParams = args[3]
        
        -- 如果起点来自相机则跳过 (防止相机冻结)
        local cameraPos = Camera.CFrame.Position
        if (origin - cameraPos).Magnitude < 5 then -- 相机射线容差
            return old_namecall(self, ...)
        end
        
        -- 可选：检查是否为射击上下文 (例如，参数过滤自身角色)
        local isShooting = true
        
        if raycastParams then
            if raycastParams.FilterType == Enum.RaycastFilterType.Blacklist and tablefind(raycastParams.FilterDescendantsInstances, LocalPlayer.Character) then
                isShooting = true
            else
                isShooting = false -- 跳过非射击射线
            end
        end
        
        if isShooting then
            local closestHead = getClosestHead()
            
            if closestHead then
                print("Raycast 已钩子 - 瞄准头部 (射击上下文)") -- 调试
                local hitPosition = closestHead.Position
                local normal = (origin - hitPosition).Unit
                local distance = (hitPosition - origin).Magnitude
                
                -- 为兼容性返回 RaycastResult
                return RaycastResult.new(closestHead, hitPosition, normal, Enum.Material.Plastic, distance)
            end
        end
    end
    
    return old_namecall(self, ...)
end))

local function getClosestHead()
    local closestHead
    local closestDistance = main.fov
    
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return
    end
    
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

-- FOV 圆圈用于视觉反馈 (绘制在屏幕上)
local fovCircle = Drawing.new("Circle")
fovCircle.Visible = false
fovCircle.Radius = main.fov
fovCircle.Color = main.fovColor -- 默认白色
fovCircle.Thickness = 2
fovCircle.Filled = false
fovCircle.Transparency = 1

RunService.RenderStepped:Connect(function()
    if main.enable then
        local mousePos = UserInputService:GetMouseLocation()
        fovCircle.Position = Vector2.new(mousePos.X, mousePos.Y)
        fovCircle.Visible = true
        fovCircle.Radius = main.fov -- 同步FOV变化
        fovCircle.Color = main.fovColor -- 同步颜色变化
    else
        fovCircle.Visible = false
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
        print("追踪已" .. (state and "开启" or "关闭") .. " - 已跳过相机Raycast以防冻结。检查控制台钩子触发。")
    end
})

Main:Slider({
    Title = "FOV (视野范围)",
    Min = 50,
    Max = 500,
    Value = 100,
    Callback = function(value)
        main.fov = value
        print("FOV设置为: " .. value)
    end
})

Main:Colorpicker({
    Title = "FOV颜色选择",
    Default = Color3.fromRGB(255, 255, 255), -- 默认白色
    Callback = function(Color, Transparency)
        main.fovColor = Color
        print("FOV颜色设置为:", Color)
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
