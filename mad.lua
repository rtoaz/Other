local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local locations = {
    ReplicatedStorage = ReplicatedStorage,
    StarterPlayer = StarterPlayer,
    Workspace = Workspace,
    StarterGui = game:GetService("StarterGui")
}

local function short(t)
    return tostring(t):gsub("Instance: ", "")
end

local function dumpDescendants(root, maxPrint)
    maxPrint = maxPrint or 300
    local count = 0
    local results = {}
    for _, obj in ipairs(root:GetDescendants()) do
        if count >= maxPrint then break end
        local ty = obj.ClassName
        local name = obj.Name
        local path = obj:GetFullName()
        table.insert(results, {path = path, class = ty, name = name})
        count = count + 1
    end
    return results
end

local function findRemotesAndUseful(root)
    local remotes = {}
    for _, obj in ipairs(root:GetDescendants()) do
        local cls = obj.ClassName
        if cls == "RemoteEvent" or cls == "RemoteFunction" then
            table.insert(remotes, {path = obj:GetFullName(), class = cls, name = obj.Name})
        end
    end
    return remotes
end

local function findByKeywords(root, keywords)
    local found = {}
    local lowkeywords = {}
    for _, k in ipairs(keywords) do lowkeywords[#lowkeywords+1] = string.lower(k) end
    for _, obj in ipairs(root:GetDescendants()) do
        local lname = string.lower(obj.Name)
        for _, kw in ipairs(lowkeywords) do
            if string.find(lname, kw, 1, true) then
                table.insert(found, {path = obj:GetFullName(), class = obj.ClassName, name = obj.Name})
                break
            end
        end
    end
    return found
end

-- 主要流程
print("=== Safe Diagnostics Start ===")
print("LocalPlayer:", Players.LocalPlayer and Players.LocalPlayer.Name or "nil")

for label, loc in pairs(locations) do
    print(string.format("---- Scanning %s (%s) ----", label, short(loc)))
    -- 总体统计
    local all = dumpDescendants(loc, 500)
    print(string.format("  扫描到对象（上限500）：%d", #all))
    -- 列出前 40 条以便快速查看（控制台量大时先看这个）
    for i = 1, math.min(40, #all) do
        local it = all[i]
        print(string.format("    [%d] %s  (%s)", i, it.path, it.class))
    end

    -- 查找 Remotes
    local remotes = findRemotesAndUseful(loc)
    print(string.format("  RemoteEvent/RemoteFunction 个数: %d", #remotes))
    for i, r in ipairs(remotes) do
        print(string.format("    R%d: %s  (%s)", i, r.path, r.class))
    end

    -- 针对常见关键字再做模糊搜索（XP, Rank, Arrest, Eject, Team, Shop, Premium, Crate, Sound）
    local keys = {"xp","experience","rank","arrest","eject","team","shop","premium","crate","sound","handcuff","server","player"}
    local hits = findByKeywords(loc, keys)
    print(string.format("  包含常见关键字的对象数量: %d (显示前50)", #hits))
    for i = 1, math.min(50, #hits) do
        local h = hits[i]
        print(string.format("    H%d: %s  (%s)", i, h.path, h.class))
    end
end

print("=== Diagnostics End ===")
