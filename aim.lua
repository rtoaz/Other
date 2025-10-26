local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local main = {
    enable = false,
    teamcheck = false,
    friendcheck = false,
    initialized = false,
    lastTarget = nil
}

-- 安全的角色部件获取函数
local function getValidCharacter(player)
    if not player or player == LocalPlayer then return nil end
    
    local character = player.Character
    if not character then return nil end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    local head = character:FindFirstChild("Head")
    
    if humanoid and humanoid.Health > 0 and rootPart and head then
        return character, humanoid, rootPart, head
    end
    
    return nil
end

-- 优化的最近目标查找
local function findClosestTarget()
    if not main.initialized or not main.enable then return nil end
    
    local localChar = LocalPlayer.Character
    if not localChar then return nil end
    
    local localRoot = localChar:FindFirstChild("HumanoidRootPart")
    if not localRoot then return nil end
    
    local localPos = localRoot.Position
    local localTeam = LocalPlayer.Team
    
    local closestTarget = nil
    local closestDistance = math.huge
    local maxDistance = 1000 -- 限制最大距离避免性能问题
    
    -- 使用缓存减少重复计算
    if main.lastTarget and main.lastTarget.Parent then
        local targetChar = main.lastTarget.Parent
        local player = Players:GetPlayerFromCharacter(targetChar)
        if player and getValidCharacter(player) then
            local distance = (main.lastTarget.Position - localPos).Magnitude
            if distance <= maxDistance then
                -- 检查团队和好友设置
                if not (main.teamcheck and player.Team == localTeam) and
                   not (main.friendcheck and LocalPlayer:IsFriendsWith(player.UserId)) then
                    return main.lastTarget
                end
            end
        end
    end
    
    -- 遍历所有玩家寻找最近目标
    for _, player in ipairs(Players:GetPlayers()) do
        local char, humanoid, root, head = getValidCharacter(player)
        if char and root and head then
            -- 团队检查
            if main.teamcheck and player.Team == localTeam then
                continue
            end
            
            -- 好友检查
            if main.friendcheck and LocalPlayer:IsFriendsWith(player.UserId) then
                continue
            end
            
            local distance = (root.Position - localPos).Magnitude
            if distance <= maxDistance and distance < closestDistance then
                closestDistance = distance
                closestTarget = head
            end
        end
    end
    
    main.lastTarget = closestTarget
    return closestTarget
end

-- 初始化函数
local function initializeAimBot()
    if main.initialized then 
        print("子弹追踪已经初始化")
        return 
    end
    
    -- 钩子函数
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        
        if method == "Raycast" and not checkcaller() and main.enable then
            local closestHead = findClosestTarget()
            if closestHead then
                local args = {...}
                local origin = args[1] or Camera.CFrame.Position
                
                return {
                    Instance = closestHead,
                    Position = closestHead.Position,
                    Normal = (origin - closestHead.Position).Unit,
                    Material = Enum.Material.Plastic,
                    Distance = (closestHead.Position - origin).Magnitude
                }
            end
        end
        
        return oldNamecall(self, ...)
    end)
    
    main.initialized = true
    print("子弹追踪初始化成功")
end

-- UI界面
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "子弹追踪",
    Icon = "rbxassetid://129260712070622",
    IconThemed = true,
    Author = "🦐🐔8修",
    Folder = "CloudHub",
    Size = UDim2.fromOffset(320, 350),
    Transparent = true,
    Theme = "Dark",
    User = {
        Enabled = true,
        Callback = function() print("用户信息点击") end,
        Anonymous = false
    },
    SideBarWidth = 200,
    ScrollBarEnabled = true,
})

Window:EditOpenButton({
    Title = "打开设置",
    Icon = "settings",
    CornerRadius = UDim.new(0, 16),
    StrokeThickness = 2,
    Color = ColorSequence.new(
        Color3.fromHex("FF0F7B"), 
        Color3.fromHex("F89B29")
    ),
    Draggable = true,
})

local MainSection = Window:Section({
    Title = "子弹追踪设置",
    Opened = true,
})

local MainTab = MainSection:Tab({ Title = "主要设置", Icon = "target" })

-- 初始化按钮变量
local initButtonRef = nil

-- 初始化按钮
initButtonRef = MainTab:Button({
    Title = "点击初始化子弹追踪",
    Image = "zap",
    Callback = function()
        local success, errorMsg = pcall(function()
            initializeAimBot()
        end)
        
        if success then
            -- 成功初始化后更新按钮状态
            initButtonRef:SetText("✅ 已初始化")
            initButtonRef:SetDisabled(true)
            print("初始化按钮状态已更新")
        else
            warn("初始化失败: " .. tostring(errorMsg))
            initButtonRef:SetText("❌ 初始化失败")
        end
    end
})

-- 子弹追踪开关
MainTab:Toggle({
    Title = "开启子弹追踪",
    Image = "crosshair",
    Value = false,
    Callback = function(state)
        if not main.initialized then
            warn("请先初始化子弹追踪！")
            return false -- 返回false让toggle回到关闭状态
        end
        main.enable = state
        print("子弹追踪: " .. (state and "开启" or "关闭"))
    end
})

-- 团队检查
MainTab:Toggle({
    Title = "忽略队友",
    Image = "users",
    Value = false,
    Callback = function(state)
        main.teamcheck = state
        main.lastTarget = nil -- 清除缓存
    end
})

-- 好友检查
MainTab:Toggle({
    Title = "忽略好友",
    Image = "user-check",
    Value = false,
    Callback = function(state)
        main.friendcheck = state
        main.lastTarget = nil -- 清除缓存
    end
})

-- 性能设置标签
local PerfTab = MainSection:Tab({ Title = "性能设置", Icon = "gauge" })

PerfTab:Button({
    Title = "清除目标缓存",
    Image = "trash-2",
    Callback = function()
        main.lastTarget = nil
        print("目标缓存已清除")
    end
})

PerfTab:Label({
    Title = "性能提示",
    Content = "最大锁定距离: 1000 studs\n使用目标缓存提升性能"
})

print("子弹追踪界面加载完成")
