local Workspace = game:GetService("Workspace") 
local Players = game:GetService("Players") 
local LocalPlayer = Players.LocalPlayer 
local Camera = Workspace.CurrentCamera 
local oldNamecall, oldIndex 

local main = {
    enable = false,
    teamcheck = false,
    friendcheck = false,
    hookMode = "Raycast" -- 新增：拦截模式（"Raycast" 或 "Ray.new"）
}

-- 伪装实例属性访问
local function createProxy(instance)
    if not instance then return nil end
    local proxy = newproxy(true)
    local mt = getmetatable(proxy)
    
    mt.__index = function(_, key)
        -- 拦截敏感属性访问
        if key == "Position" or key == "CFrame" or key == "Health" then
            -- 注意：已移除 yield/wait，避免在属性访问时让出线程导致输入/相机卡住
            return instance[key]
        end
        return instance[key]
    end
    
    mt.__tostring = function()
        return tostring(instance)
    end
    
    return proxy
end

-- 获取最近的玩家头部
local function getClosestHead()
    local closestHead
    local closestDistance = math.huge
    
    if not (LocalPlayer and LocalPlayer.Character) then
        return
    end
    
    local localRootInst = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not localRootInst then
        return
    end
    -- 仅在必要时包装 proxy，避免在循环里频繁创建
    local localRoot = localRootInst

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
                local rootInst = character:FindFirstChild("HumanoidRootPart")
                local headInst = character:FindFirstChild("Head")
                local humanoidInst = character:FindFirstChildOfClass("Humanoid")
                
                if rootInst and headInst and humanoidInst and humanoidInst.Health and humanoidInst.Health > 0 then
                    -- 检查是否在摄像机视角内
                    local screenPos, onScreen = Camera:WorldToViewportPoint(headInst.Position)
                    -- WorldToViewportPoint 返回 (Vector3 screenPoint, boolean onScreen)
                    if onScreen and screenPos.Z > 0 and screenPos.X > 0 and screenPos.X < Camera.ViewportSize.X and screenPos.Y > 0 and screenPos.Y < Camera.ViewportSize.Y then
                        -- 仅计算视野内玩家
                        local ok, distance = pcall(function()
                            return (rootInst.Position - localRoot.Position).Magnitude
                        end)
                        if ok and distance and distance < closestDistance then
                            closestHead = headInst
                            closestDistance = distance
                        end
                    end
                end
            end
        end
    end
    
    return closestHead
end

-- 钩子元方法：拦截 Raycast
oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}
    
    if method == "Raycast" and not checkcaller() and main.enable and main.hookMode == "Raycast" then
        local origin = args[1] or (Camera and Camera.CFrame and Camera.CFrame.Position) or Vector3.new()
        local closestHead = getClosestHead()
        
        if closestHead then
            -- 伪造 Raycast 结果
            return {
                Instance = closestHead,
                Position = closestHead.Position + Vector3.new(
                    (math.random(-100,100) * 0.001),
                    (math.random(-100,100) * 0.001),
                    (math.random(-100,100) * 0.001)
                ), -- 轻微随机偏移
                Normal = (origin - closestHead.Position).Unit,
                Material = Enum.Material.Plastic,
                Distance = (closestHead.Position - origin).Magnitude
            }
        end
    end

    -- 当以旧 API (FindPartOnRay / FindPartOnRayWithIgnoreList / FindPartOnRayWithWhitelist) 调用时：
    if not checkcaller() and main.enable and main.hookMode == "Ray.new" then
        -- 兼容性：拦截 FindPartOnRay 系列以返回类似 Raycast 的伪造命中
        if method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRayWithWhitelist" then
            local rayArg = args[1]
            local origin, direction
            -- Ray 对象包含 Origin 与 Direction
            if typeof(rayArg) == "Ray" then
                origin = rayArg.Origin
                direction = rayArg.Direction
            end

            if origin and direction then
                local closestHead = getClosestHead()
                if closestHead then
                    local hitPos = closestHead.Position + Vector3.new(
                        (math.random(-100,100) * 0.001),
                        (math.random(-100,100) * 0.001),
                        (math.random(-100,100) * 0.001)
                    )
                    local normal = (origin - closestHead.Position).Unit
                    local material = Enum.Material.Plastic

                    -- FindPartOnRay 返回：part, position, normal, material
                    return closestHead, hitPos, normal, material
                end
            end
        end
    end

    return oldNamecall(self, ...)
end))

-- 拦截 __index 元方法以绕过属性检测
oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, key)
    if not checkcaller() and (key == "Position" or key == "CFrame" or key == "Health") then
        -- 伪装属性访问（移除会让出线程的操作）
        local proxy = createProxy(self)
        return proxy and proxy[key]
    end
    return oldIndex(self, key)
end))

-- 加载 UI（保持隐蔽）
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
        Enabled = false, -- 禁用用户交互记录以降低检测风险
        Callback = function() end,
        Anonymous = true
    },
    SideBarWidth = 200,
    ScrollBarEnabled = false -- 禁用滚动条以减少 UI 痕迹
})

Window:EditOpenButton({
    Title = "打开UI",
    Icon = "monitor",
    CornerRadius = UDim.new(0,16),
    StrokeThickness = 2,
    Color = ColorSequence.new(
        Color3.fromHex("DA70D6"),
        Color3.fromHex("9932CC")
    ),
    Draggable = true,
})

local MainSection = Window:Section({
    Title = "子追",
    Opened = false -- 默认关闭以降低可见性
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

-- 下拉菜单：选择拦截类型（不可多选，默认 Raycast）
Main:Dropdown({
    Title = "下拉菜单",
    Values = { "Raycast", "Ray.new" },
    Value = "Raycast", -- 默认值
    Multi = false, -- 是否多选
    Callback = function(Value)
        print("选中:", Value)
        main.hookMode = Value
    end
})

-- 添加反检测措施
local function antiDetect()
    -- 随机化调用栈
    local function dummy()
        return math.random(1, 1000)
    end
    
    for _ = 1, math.random(5, 10) do
        dummy()
    end
    
    -- 伪装正常玩家行为
    if LocalPlayer and LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            -- 暂停对 WalkSpeed 的写入以避免误写导致移动/视角异常
            -- local ok, current = pcall(function() return tonumber(humanoid.WalkSpeed) end)
            -- if ok and current then
            --     local delta = (math.random(-10,10) * 0.01) -- 安全小幅度变动
            --     pcall(function() humanoid.WalkSpeed = current + delta end)
            -- end
        end
    end
end

-- 定期运行反检测
game:GetService("RunService").Heartbeat:Connect(function()
    if main.enable then
        antiDetect()
    end
end)

-- ========== 为 Ray.new 模式增加 Ray.new 替换（保持与 FindPartOnRay 系列的兼容） ==========
do
    local ok, RayTable = pcall(function() return Ray end)
    if ok and type(RayTable) == "table" and RayTable.new then
        local oldRayNew = RayTable.new
        RayTable.new = newcclosure(function(origin, direction)
            if checkcaller() or not main.enable or main.hookMode ~= "Ray.new" then
                return oldRayNew(origin, direction)
            end

            -- 尝试获取最近头部并修改方向
            local closestHead = getClosestHead()
            if closestHead and origin and typeof(direction) == "Vector3" then
                local success, newDir = pcall(function()
                    local vecToHead = (closestHead.Position - origin)
                    local len = direction.Magnitude
                    if len <= 0 then len = vecToHead.Magnitude end
                    return vecToHead.Unit * len
                end)
                if success and newDir then
                    return oldRayNew(origin, newDir)
                end
            end

            return oldRayNew(origin, direction)
        end)
    end
end
