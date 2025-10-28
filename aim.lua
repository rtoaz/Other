local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local old
local main = {
    enable = false,
    teamcheck = false,
    friendcheck = false
}

local function getClosestHead()
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

-- 延迟钩子：随机3-5秒后执行，伪装正常加载
task.wait(math.random(3, 5))

-- 混淆键：用变量隐藏 "Raycast"
local rayKey = "Raycast"  -- 可以进一步字节码化，但简单起见

old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if method == rayKey and not checkcaller() then
        local origin = args[1] or Camera.CFrame.Position

        if main.enable then
            local closestHead = getClosestHead()
            if closestHead then
                -- 多层闭包：内层处理逻辑，外层返回
                return newcclosure(function()
                    return {
                        Instance = closestHead,
                        Position = closestHead.Position,
                        Normal = (origin - closestHead.Position).Unit,
                        Material = Enum.Material.Plastic,
                        Distance = (closestHead.Position - origin).Magnitude
                    }
                end)()
            end
        end
    end
    return old(self, ...)
end))

-- UI部分不变
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
