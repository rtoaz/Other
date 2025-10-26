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

-- 修复卡死问题：简化逻辑，只保留最基本的功能
local function getClosestHead()
    if not main.initialized or not main.enable then return end
    if not LocalPlayer or not LocalPlayer.Character then return end
    
    local localRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not localRoot then return end
    
    local closestHead = nil
    local closestDistance = 500 -- 限制搜索距离
    
    for _, player in Players:GetPlayers() do
        if player == LocalPlayer then continue end
        
        local character = player.Character
        if not character then continue end
        
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end
        
        local root = character:FindFirstChild("HumanoidRootPart")
        local head = character:FindFirstChild("Head")
        if not root or not head then continue end
        
        -- 团队检查
        if main.teamcheck and player.Team == LocalPlayer.Team then continue end
        
        -- 好友检查
        if main.friendcheck and player:IsFriendsWith(LocalPlayer.UserId) then continue end
        
        local distance = (root.Position - localRoot.Position).Magnitude
        if distance < closestDistance then
            closestHead = head
            closestDistance = distance
        end
    end
    
    return closestHead
end

local function getClosestNpcHead()
    if not main.initialized then return end
    
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
    
    old = hookmetamethod(game, "__namecall", function(self, ...)
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
    end)
    
    main.initialized = true
    return true
end

-- 创建UI
local success, WindUI = pcall(function()
    return loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
end)

if not success then
    -- 如果WindUI加载失败，创建一个简单的UI
    local function createSimpleUI()
        local ScreenGui = Instance.new("ScreenGui")
        ScreenGui.Parent = game.Players.LocalPlayer.PlayerGui
        
        local Frame = Instance.new("Frame")
        Frame.Size = UDim2.new(0, 200, 0, 200)
        Frame.Position = UDim2.new(0, 10, 0, 10)
        Frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        Frame.Parent = ScreenGui
        
        local initButton = Instance.new("TextButton")
        initButton.Size = UDim2.new(0, 180, 0, 30)
        initButton.Position = UDim2.new(0, 10, 0, 10)
        initButton.Text = "初始化子弹追踪"
        initButton.Parent = Frame
        initButton.MouseButton1Click:Connect(function()
            if initializeAimBot() then
                initButton.Text = "已初始化"
                initButton.Active = false
            end
        end)
        
        -- 其他控件...
    end
    
    createSimpleUI()
else
    -- 使用WindUI创建界面
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

    local MainSection = Window:Section({
        Title = "子追",
        Opened = true,
    })

    local Main = MainSection:Tab({ Title = "设置", Icon = "Sword" })

    -- 初始化按钮
    local initButton
    initButton = Main:Button({
        Title = "初始化子弹追踪",
        Image = "bird",
        Callback = function()
            if initializeAimBot() then
                -- 尝试更新按钮状态
                pcall(function()
                    initButton:SetText("已初始化")
                    initButton:SetDisabled(true)
                end)
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
end
