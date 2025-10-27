local Workspace = game:GetService("Workspace") 
local Players = game:GetService("Players") 
local LocalPlayer = Players.LocalPlayer 
local Camera = Workspace.CurrentCamera 
-- local oldNamecall, oldIndex  -- 注释掉钩子函数相关的变量

local main = {
    enable = false,
    teamcheck = false,
    friendcheck = false
}

-- 伪装实例属性访问（暂时不使用）
-- local function createProxy(instance)
--     ...（保持不变）
-- end

-- 获取最近的玩家头部（暂时不使用）
-- local function getClosestHead()
--     ...（保持不变）
-- end

-- 钩子元方法：拦截 Raycast（暂时注释掉）
-- oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
--     ...（保持不变）
-- end))

-- 拦截 __index 元方法以绕过属性检测（暂时注释掉）
-- oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, key)
--     ...（保持不变）
-- end))

-- 加载 UI（保持隐蔽）
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
local Window = WindUI:CreateWindow({
    Title = "子弹追踪",
    Icon = "rbxassetid://129260712070622",
    IconThemed = true,
    Author = "idk",
    Folder = "CloudHub",
    Size = UDim2.fromOffset(300, 270),
    Transparent = false, -- 改为非透明，避免覆盖整个屏幕
    Theme = "Dark",
    User = {
        Enabled = false,
        Callback = function() end,
        Anonymous = true
    },
    SideBarWidth = 200,
    ScrollBarEnabled = false
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

-- ... 其余UI代码保持不变

-- 反检测措施（暂时注释掉，因为钩子函数被注释了）
-- local function antiDetect()
--     ...（保持不变）
-- end

-- game:GetService("RunService").Heartbeat:Connect(function()
--     if main.enable then
--         antiDetect()
--     end
-- end)
