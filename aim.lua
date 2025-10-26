-- 多功能版
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local old
local main = {
    enable = false,
    teamcheck = false,
    friendcheck = false,
    enablenpc = false,
    maxDistance = 500, -- 新增：最大追踪距离
    npcUpdateRate = 0.18 -- NPC 扫描频率
}

-- 初始化提示
local function initialize()
    print("初始化成功")
end

-- 获取最近的玩家头部（原有玩家追踪代码，不改动）
local function getClosestHead()
    local closestHead
    local closestDistance = main.maxDistance
    
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return nil
    end
    
    local localHrp = LocalPlayer.Character.HumanoidRootPart
    
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
                    local distance = (root.Position - localHrp.Position).Magnitude
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

-- NPC 缓存（优化版）
local cachedNpcHead = nil
local cachedNpcHeadPos = nil
local cachedNpcDistSq = math.huge
local npcUpdateTimer = 0
local npcFolder = Workspace:FindFirstChild("NPCs") -- 请根据游戏实际 NPC 容器修改路径

-- Heartbeat 周期更新 NPC
RunService.Heartbeat:Connect(function(dt)
    if main.enablenpc then
        npcUpdateTimer = npcUpdateTimer + dt
        if npcUpdateTimer >= main.npcUpdateRate then
            npcUpdateTimer = 0
            cachedNpcHead = nil
            cachedNpcHeadPos = nil
            cachedNpcDistSq = main.maxDistance * main.maxDistance

            if npcFolder and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local localHrp = LocalPlayer.Character.HumanoidRootPart
                for _, npc in ipairs(npcFolder:GetChildren()) do
                    if npc:IsA("Model") then
                        local humanoid = npc:FindFirstChildOfClass("Humanoid")
                        local hrp = npc:FindFirstChild("HumanoidRootPart") or npc.PrimaryPart
                        local head = npc:FindFirstChild("Head")
                        if humanoid and hrp and head and humanoid.Health > 0 then
                            local diff = hrp.Position - localHrp.Position
                            local distSq = diff.X*diff.X + diff.Y*diff.Y + diff.Z*diff.Z
                            if distSq < cachedNpcDistSq then
                                cachedNpcDistSq = distSq
                                cachedNpcHead = head
                                cachedNpcHeadPos = head.Position
                            end
                        end
                    end
                end
            end
        end
    else
        cachedNpcHead = nil
        cachedNpcHeadPos = nil
        cachedNpcDistSq = math.huge
    end
end)

-- 钩子 Raycast 方法
old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}
    
    if method == "Raycast" and not checkcaller() then
        local origin = args[1] or Camera.CFrame.Position
        
        -- 玩家子弹追踪（保持原有逻辑）
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
        
        -- NPC 子弹追踪（优化后缓存读取）
        if main.enablenpc and cachedNpcHead and cachedNpcHeadPos then
            local diff = cachedNpcHeadPos - origin
            local distSq = diff.X*diff.X + diff.Y*diff.Y + diff.Z*diff.Z
            if distSq <= (main.maxDistance * main.maxDistance) then
                return {
                    Instance = cachedNpcHead,
                    Position = cachedNpcHeadPos,
                    Normal = (origin - cachedNpcHeadPos).Unit,
                    Material = Enum.Material.Plastic,
                    Distance = math.sqrt(distSq)
                }
            end
        end
    end
    return old(self, ...)
end))

-- 加载 UI 库
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

-- 创建 UI 窗口
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

-- 添加初始化按钮
Main:Button({
    Title = "初始化",
    Image = "gear",
    Callback = function()
        initialize()
    end
})

Main:Toggle({
    Title = "开启子弹追踪",
    Image = "bird",
    Value = false,
    Callback = function(state)
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
        main.enablenpc = state
    end
})
