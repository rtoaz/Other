local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local old

-- 设置
local main = {
    enable = false,
    teamcheck = false,
    friendcheck = false
}

-- 缓存最近玩家头部
local cachedHead
local raycastResult = {
    Instance = nil,
    Position = Vector3.new(),
    Normal = Vector3.new(),
    Material = Enum.Material.Plastic,
    Distance = 0
}

-- 异步更新最近玩家头部
RunService.Heartbeat:Connect(function()
    if not main.enable then return end
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end

    local localHrp = LocalPlayer.Character.HumanoidRootPart
    local closest
    local shortest = math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local skip = false
            if main.teamcheck and player.Team == LocalPlayer.Team then skip = true end
            if not skip and main.friendcheck and LocalPlayer:IsFriendsWith(player.UserId) then skip = true end
            if skip then continue end

            local hrp = player.Character:FindFirstChild("HumanoidRootPart")
            local head = player.Character:FindFirstChild("Head")
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")

            if hrp and head and humanoid and humanoid.Health > 0 then
                local dist = (hrp.Position - localHrp.Position).Magnitude
                if dist < shortest then
                    closest = head
                    shortest = dist
                end
            end
        end
    end

    cachedHead = closest
    if cachedHead then
        raycastResult.Instance = cachedHead
        raycastResult.Position = cachedHead.Position
        raycastResult.Normal = (Camera.CFrame.Position - cachedHead.Position).Unit
        raycastResult.Distance = (cachedHead.Position - Camera.CFrame.Position).Magnitude
    else
        raycastResult.Instance = nil
    end
end)

-- Hook Raycast，只返回缓存好的数据
old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if method == "Raycast" and not checkcaller() and main.enable then
        if cachedHead then
            return raycastResult
        end
    end

    return old(self, ...)
end))

-- WindUI 界面
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

-- 主界面
MainSection = Window:Section({
    Title = "子追",
    Opened = true,
})

Main = MainSection:Tab({ Title = "设置", Icon = "Sword" })

-- 开启子弹追踪
Main:Toggle({
    Title = "开启子弹追踪",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.enable = state
    end
})

-- 队伍验证
Main:Toggle({
    Title = "开启队伍验证",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.teamcheck = state
    end
})

-- 好友验证
Main:Toggle({
    Title = "开启好友验证",
    Image = "bird",
    Value = false,
    Callback = function(state)
        main.friendcheck = state
    end
})
