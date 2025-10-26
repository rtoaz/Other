--多功能版
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService") -- 添加RunService
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local old
local main = {
    enable = false,
    teamcheck = false,
    friendcheck = false,
    enablenpc = false
}

-- 添加初始化状态和性能优化
local initialized = false
local lastSearchTime = 0
local searchInterval = 0.5 -- 每0.5秒搜索一次

local function getClosestHead()
    -- 限制搜索频率
    if tick() - lastSearchTime < searchInterval then
        return nil
    end
    lastSearchTime = tick()
    
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
                    -- 添加距离限制
                    if distance < closestDistance and distance < 500 then
                        closestHead = head
                        closestDistance = distance
                    end
                end
            end
        end
    end
    return closestHead
end

local function getClosestNpcHead()
    -- 限制搜索频率
    if tick() - lastSearchTime < searchInterval then
        return nil
    end
    
    local closestHead
    local closestDistance = math.huge
    
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
    local localHrp = LocalPlayer.Character.HumanoidRootPart
    
    -- 只搜索Workspace的直接子对象
    for _, object in ipairs(Workspace:GetChildren()) do
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
                    -- 添加距离限制
                    if distance < closestDistance and distance < 500 then
                        closestHead = head
                        closestDistance = distance
                    end
                end
            end
        end
    end
    return closestHead
end

-- 初始化钩子函数
local function initializeHook()
    if initialized then return end
    
    old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        if not initialized then return old(self, ...) end
        
        local method = getnamecallmethod()
        local args = {...}
        
        -- 只在必要时处理Raycast调用
        if method == "Raycast" and not checkcaller() then
            local origin = args[1] or Camera.CFrame.Position
            
            -- 限制处理频率
            if tick() - lastSearchTime < searchInterval then
                return old(self, ...)
            end
            
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
    
    initialized = true
end

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "子弹追踪",
    Icon = "rbxassetid://129260712070622",
    IconThemed = true,
    Author = "idk",
    Folder = "CloudHub",
    Size = UDim2.fromOffset(300, 300),
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
    Image = "power",
    Callback = function()
        initializeHook()
        initButton:Update({
            Title = "已初始化",
            Image = "check",
            Callback = function() 
                print("已经初始化完成！")
            end
        })
    end
})

Main:Toggle({
    Title = "开启子弹追踪",
    Image = "bird",
    Value = false,
    Callback = function(state)
        if not initialized then
            print("请先点击初始化按钮！")
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
        if not initialized then
            print("请先点击初始化按钮！")
            return
        end
        main.enablenpc = state
    end
})
