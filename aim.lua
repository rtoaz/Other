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
    initialized = false -- 添加初始化状态
}

-- 安全获取角色部件的函数
local function safeGetCharacterParts(character)
    if not character or not character:IsA("Model") then
        return nil, nil, nil
    end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        return nil, nil, nil
    end
    
    local root = character:FindFirstChild("HumanoidRootPart")
    local head = character:FindFirstChild("Head")
    
    if not root or not head then
        return nil, nil, nil
    end
    
    return root, head, humanoid
end

local function getClosestHead()
    if not main.initialized then return end -- 未初始化时不执行
    
    local closestHead
    local closestDistance = math.huge
    
    if not LocalPlayer.Character then return end
    local localRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not localRoot then return end
    
    local localPosition = localRoot.Position
    local localTeam = LocalPlayer.Team
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        
        local character = player.Character
        local root, head, humanoid = safeGetCharacterParts(character)
        
        if root and head and humanoid then
            -- 团队检查
            if main.teamcheck and player.Team == localTeam then
                continue
            end
            
            -- 好友检查
            if main.friendcheck and LocalPlayer:IsFriendsWith(player.UserId) then
                continue
            end
            
            local distance = (root.Position - localPosition).Magnitude
            if distance < closestDistance then
                closestHead = head
                closestDistance = distance
            end
        end
    end
    
    return closestHead
end

local function getClosestNpcHead()
    if not main.initialized then return end -- 未初始化时不执行
    
    local closestHead
    local closestDistance = math.huge
    
    if not LocalPlayer.Character then return end
    local localRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not localRoot then return end
    
    local localPosition = localRoot.Position
    
    for _, object in ipairs(Workspace:GetDescendants()) do
        if object:IsA("Model") then
            local root, head, humanoid = safeGetCharacterParts(object)
            
            if root and head and humanoid then
                -- 检查是否为玩家角色
                local isPlayer = false
                for _, pl in ipairs(Players:GetPlayers()) do
                    if pl.Character == object then
                        isPlayer = true
                        break
                    end
                end
                
                if not isPlayer then
                    local distance = (root.Position - localPosition).Magnitude
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
    print("子弹追踪初始化完成")
end

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "子弹追踪",
    Icon = "rbxassetid://129260712070622",
    IconThemed = true,
    Author = "idk",
    Folder = "CloudHub",
    Size = UDim2.fromOffset(300, 320), -- 增加高度以容纳新按钮
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

-- 添加初始化按钮
local initButton
initButton = Main:Button({
    Title = "初始化子弹追踪",
    Image = "bird",
    Callback = function()
        initializeAimBot()
        -- 禁用按钮并改变文本
        initButton:SetText("已初始化")
        initButton:SetDisabled(true)
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
