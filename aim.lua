--多功能版
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local old
local main = {
    enable = false,
    teamcheck = false,
    friendcheck = false,
    enablenpc = false,
    initialized = false
}

-- 彻底修复卡死问题：简化逻辑，避免任何可能导致无限循环的情况
local function getClosestHead()
    if not main.initialized or not main.enable then return end
    
    -- 基本安全检查
    if not LocalPlayer or not LocalPlayer.Character then return end
    local localRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not localRoot then return end
    
    local closestHead = nil
    local closestDistance = 1000 -- 设置最大距离限制
    
    local localPos = localRoot.Position
    local localTeam = LocalPlayer.Team
    
    -- 直接遍历玩家，避免复杂逻辑
    for _, player in ipairs(Players:GetPlayers()) do
        -- 跳过自己
        if player == LocalPlayer then goto continue end
        
        -- 跳过无效玩家
        if not player.Character then goto continue end
        
        local character = player.Character
        
        -- 跳过死亡玩家
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then goto continue end
        
        -- 跳过没有必要部件的玩家
        local root = character:FindFirstChild("HumanoidRootPart")
        local head = character:FindFirstChild("Head")
        if not root or not head then goto continue end
        
        -- 团队检查
        if main.teamcheck and player.Team == localTeam then goto continue end
        
        -- 好友检查
        if main.friendcheck and LocalPlayer:IsFriendsWith(player.UserId) then goto continue end
        
        -- 计算距离
        local distance = (root.Position - localPos).Magnitude
        if distance < closestDistance then
            closestHead = head
            closestDistance = distance
        end
        
        ::continue::
    end
    
    return closestHead
end

local function getClosestNpcHead()
    local closestHead
    local closestDistance = math.huge
    
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
    local localHrp = LocalPlayer.Character.HumanoidRootPart
    
    for _, object in ipairs(Workspace:GetDescendants()) do
        if object:IsA("Model") then
            local humanoid = object:FindFirstChildOfClass("Humanoid")
            local hrp = object:FindFirstChild("HumanoidRootPart") or object.PrimaryPart
            local head = object:FindFirstChild("Head")
            
            if humanoid and hrp and humanoid.Health > 0 then
                local isPlayer = false
                for _, pl in ipairs(Players:GetPlayers()) do
                    if pl.Character == object then
                        isPlayer = true
                        break
                    end
                end
                
                if not isPlayer and head then
                    local distance = (hrp.Position - localHrp.Position).Magnitude
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

-- 初始化函数
local function initializeAimBot()
    if main.initialized then return end
    
    old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = {...}
        
        if method == "Raycast" and not checkcaller() then
            local origin = args[1] or Camera.CFrame.Position
            
            if main.enable then
                local closestHead = getClosestHead()
                if closestHead then
                    return {
                        Instance = closestHead,
                        Position = closestHead.Position,
                        Normal = (origin - closestHead.Position).Unit,
                        Material = Enum.Material.Plastic,
                        Distance = (closestHead.Position - origin).Magnitude
                    }
                end
            end
            
            if main.enablenpc then
                local closestNpcHead = getClosestNpcHead()
                if closestNpcHead then
                    return {
                        Instance = closestNpcHead,
                        Position = closestNpcHead.Position,
                        Normal = (origin - closestNpcHead.Position).Unit,
                        Material = Enum.Material.Plastic,
                        Distance = (closestNpcHead.Position - origin).Magnitude
                    }
                end
            end
        end
        return old(self, ...)
    end))
    
    main.initialized = true
    print("子弹追踪初始化成功")
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

-- 修复初始化按钮显示问题
local initButton
initButton = Main:Button({
    Title = "初始化子弹追踪",
    Image = "bird",
    Callback = function()
        initializeAimBot()
        if main.initialized then
            -- 尝试直接修改按钮属性
            pcall(function()
                initButton.Title = "已初始化"
                initButton:SetDisabled(true)
            end)
            
            -- 如果上面的方法失败，尝试重新创建按钮
            if not initButton then
                initButton = Main:Button({
                    Title = "已初始化",
                    Image = "bird",
                    Disabled = true
                })
            end
        end
    end
})

Main:Toggle({
    Title = "开启子弹追踪",
    Image = "bird",
    Value = false,
    Callback = function(state)
        if not main.initialized then
            warn("请先初始化子弹追踪！")
            return
        end
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
        if not main.initialized then
            warn("请先初始化子弹追踪！")
            return
        end
        main.enablenpc = state
    end
})
