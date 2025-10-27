local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local main = {
    enable = false,
    teamcheck = false,
    friendcheck = false
}

-- Da Hood / Adonis-like Anti-Cheat Bypass (adapted for 2025)
local tablefind = table.find
local MainEvent = ReplicatedStorage:FindFirstChild("MainEvent") -- Adjust if different
local Flags = {"CHECKER_1", "TeleportDetect", "OneMoreTime", "indexInstance"} -- Common flags, add more if needed

-- Clean existing indexInstance flags (run once)
spawn(function()
    while true do
        wait(1)
        for _, obj in pairs(getgc(true)) do
            if type(obj) == "table" and rawget(obj, "indexInstance") then
                obj.indexInstance = nil
                print("Cleaned indexInstance flag")
            end
        end
    end
end)

-- Hook __newindex to prevent setting indexInstance or ws/jp
local mt = getrawmetatable(game)
local old_newindex = mt.__newindex

setreadonly(mt, false)

mt.__newindex = newcclosure(function(self, key, value)
    if checkcaller() then
        return old_newindex(self, key, value)
    end
    
    if key == "indexInstance" then
        print("Blocked indexInstance set")
        return -- Ignore setting
    end
    
    if self:IsA("Humanoid") and (key == "WalkSpeed" or key == "JumpPower") then
        return -- Block AC resets
    end
    
    return old_newindex(self, key, value)
end)

-- Hook __index to bypass checks
local old_index = mt.__index

mt.__index = newcclosure(function(self, key)
    if checkcaller() then
        return old_index(self, key)
    end
    
    if key == "indexInstance" then
        return false -- Spoof as not flagged
    end
    
    return old_index(self, key)
end)

setreadonly(mt, true)

-- Original Raycast hook with __namecall (now protected by bypass)
local old_namecall

old_namecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    -- Bypass detections (e.g., FireServer flags)
    if method == "FireServer" and MainEvent and self == MainEvent and tablefind(Flags, args[1]) then
        print("Bypassed FireServer flag: " .. tostring(args[1]))
        return
    end

    -- Anti-crash (if applicable)
    if not checkcaller() and getfenv(2).crash then
        local fenv = getfenv(2)
        fenv.crash = function() end
        setfenv(2, fenv)
    end

    -- Bullet Tracking: Hook Raycast
    if method == "Raycast" and self == Workspace and main.enable and not checkcaller() then
        local origin = args[1]
        local closestHead = getClosestHead()
        
        if closestHead then
            print("Raycast hooked - targeting head") -- Debug
            local hitPosition = closestHead.Position
            local normal = (origin.Position - hitPosition).Unit -- Handle CFrame origin
            local distance = (hitPosition - origin.Position).Magnitude
            
            -- Return proper RaycastResult for modern Roblox (2025+)
            return RaycastResult.new(closestHead, hitPosition, normal, Enum.Material.Plastic, distance)
        end
    end

    return old_namecall(self, ...)
end))

local function getClosestHead()
    local closestHead
    local closestDistance = math.huge

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
        print("子弹追踪已" .. (state and "开启" or "关闭") .. " - 检查控制台以确认钩子触发")
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
