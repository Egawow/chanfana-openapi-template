


-- ══════════════════════════════════════════════════════════════════════
-- [ DELTA EXECUTOR - EVOMON AUTO FARM SCRIPT v3.6 MERGED FIX ]
-- Features : Auto Battle / Auto Chest / Auto Catch / Auto Escape
--            Auto Heal (fixed via BattlePetHeadModule HP source + UI SelfHpText + Exact ReqOperateBattle Args)
--            [v3.6 HEAL PRIORITY FIX] ความถี่เร็วสุด 0.1 วินาที + หยุด Battle ชั่วคราวเพื่อ Heal ทันที + เช็คเลือดเพิ่มจริง
--            Auto TP by Level / Manual TP
--            Top 5 Potential / Top 5 Power → Set Team
--            Auto Boss (สแกนทันทีไม่ต้องกด Rescan) / Auto Fast Boss (NPC 10000 + World Battle ID 900000X ยึด Target World เป็นหลัก) / Auto NPC / Auto Tower / Auto Task
--            Auto Pet Manager / Anti-AFK
--            Element Advantage Scanner + Auto Switch + Play Till Dead (merged)
--            [v3.6 OPTIMIZED] Instant GUI Loading + Safe Non-blocking Remotes & Modules
--            [FAST BOSS SLIDER FIX] เลื่อนสไลด์ซ้าย-ขวาเลือกโลกอิสระ + ปุ่มเลื่อนโลกซ้าย-ขวา (ลบ Start/Max World)
-- UI Lib   : Fluent by dawid-scripts
-- ══════════════════════════════════════════════════════════════════════

print("[Delta X — Evomon v3.6] Script starting... downloading libraries...")

-- ────────────────────────────────────────────────────────────────────
-- SECTION 1 : LOAD LIBRARIES
-- ────────────────────────────────────────────────────────────────────
local Fluent = loadstring(game:HttpGet(
    "https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"
))()
local SaveManager = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"
))()
local InterfaceManager = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"
))()

print("[Delta X — Evomon v3.6] Libraries loaded! Loading services & modules...")

-- ────────────────────────────────────────────────────────────────────
-- SECTION 2 : SERVICES
-- ────────────────────────────────────────────────────────────────────
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")
local VirtualUser       = game:GetService("VirtualUser")
local LocalPlayer       = Players.LocalPlayer

if not table.find then
    function table.find(t, value)
        for i, v in ipairs(t) do
            if v == value then
                return i
            end
        end
        return nil
    end
end

-- ────────────────────────────────────────────────────────────────────
-- SECTION 3 : GAME MODULES (OPTIMIZED: NON-BLOCKING & INSTANT LOAD)
-- ────────────────────────────────────────────────────────────────────
local function safeRequire(...)
    local path = ReplicatedStorage
    for _, name in ipairs({...}) do
        if not path then return nil end
        local child = path:FindFirstChild(name)
        if not child then
            child = path:WaitForChild(name, 1.5)
        end
        if not child then return nil end
        path = child
    end
    local ok, result = pcall(require, path)
    return (ok and type(result) == "table") and result or nil
end

local ConfigDataManager = safeRequire("Core", "Config", "ConfigDataManager")
local ConfigConst       = safeRequire("Core", "Config", "ConfigConst")
local BattleService     = safeRequire("Script", "Battle", "BattleService")
local PetStorage        = safeRequire("Storage", "PetStorage")
local PetComm           = safeRequire("Script", "Pet", "PetComm")
local AttrConst         = safeRequire("Script", "Attr", "Basic", "AttrConst")

local RefreshService  = safeRequire("Script", "RefreshSystem", "RefreshService")
local CreatureService = safeRequire("Script", "Creature", "CreatureService")
local CreatureConst   = safeRequire("Script", "Creature", "Basic", "CreatureConst")
local PetServiceModule   = safeRequire("Script", "Pet", "PetService")
local PetGroupStorageMod = safeRequire("Storage", "PetGroupStorage")
local ErrorCode          = safeRequire("Core", "Tools", "ErrorCode")

local ElementModule              = safeRequire("Script", "Element", "ElementModule")
local BattleDataGetModule        = safeRequire("Script", "MainBattleWindow", "BattleDataGetModule")
local MainBattleWindowController = safeRequire("Controller", "MainBattleWindowController")
local BattlePetHeadModule        = safeRequire("Script", "HeadDisplay", "BattlePetHeadModule")

local EC_SUCCEEDED = (ErrorCode and ErrorCode.SUCCEEDED) or 0

-- ────────────────────────────────────────────────────────────────────
-- SECTION 4 : REMOTE & BINDABLE PATHS (OPTIMIZED: NON-BLOCKING)
-- ────────────────────────────────────────────────────────────────────
local function waitFor(parent, ...)
    local node = parent
    for _, name in ipairs({...}) do
        if not node then return nil end
        local child = node:FindFirstChild(name)
        if not child then
            child = node:WaitForChild(name, 1.5)
        end
        node = child
    end
    return node
end

local RemoteBattle          = waitFor(ReplicatedStorage, "Remote", "Battle")
local BindableBattle        = waitFor(ReplicatedStorage, "Bindable", "Battle")
local ReqEnterPetBattle     = waitFor(RemoteBattle, "ReqEnterPetBattle")
local ReqOperateBattle      = waitFor(RemoteBattle, "ReqOperateBattle")
local ResSettleBattle       = waitFor(RemoteBattle, "ResSettleBattle")
local ResStatisticsBattle   = waitFor(RemoteBattle, "ResStatisticsBattle")
local ClientBattleStart     = waitFor(BindableBattle, "ClientBattleStart")
local ClientEnterBattleFail = waitFor(BindableBattle, "ClientEnterBattleFail")
local ReqSetPetGroupList    = waitFor(ReplicatedStorage, "Remote", "PetGroup", "ReqSetPetGroupList")
local ReqClaimChest         = waitFor(ReplicatedStorage, "Remote", "Chest", "ReqClaimExploreReward")
local ChestFolder           = waitFor(Workspace, "RuntimeCache", "RuntimeCacheClient", "Chest")

local RemoteDialogue               = waitFor(ReplicatedStorage, "Remote", "Dialogue")
local ReqMarkDialogueTalkCompleted = RemoteDialogue and (RemoteDialogue:FindFirstChild("ReqMarkDialogueTalkCompleted") or RemoteDialogue:WaitForChild("ReqMarkDialogueTalkCompleted", 1.5))
local ResDialogueEnded             = RemoteDialogue and (RemoteDialogue:FindFirstChild("ResDialogueEnded") or RemoteDialogue:WaitForChild("ResDialogueEnded", 1.5))
local ReqCanEnterBattle            = waitFor(RemoteBattle, "ReqCanEnterBattle")
local ReqEnterNpcBattle            = waitFor(RemoteBattle, "ReqEnterNpcBattle")
local ReqAutoBattle                = waitFor(RemoteBattle, "ReqAutoBattle")

local RemoteTask      = waitFor(ReplicatedStorage, "Remote", "Task")
local ReqReceiveTask  = RemoteTask and (RemoteTask:FindFirstChild("ReqReceiveTask") or RemoteTask:WaitForChild("ReqReceiveTask", 1.5))
local ReqCompleteTask = RemoteTask and (RemoteTask:FindFirstChild("ReqCompleteTask") or RemoteTask:WaitForChild("ReqCompleteTask", 1.5))

local RemoteDungeon              = waitFor(ReplicatedStorage, "Remote", "Dungeon")
local ReqEnterTowerDungeonBattle = RemoteDungeon and (RemoteDungeon:FindFirstChild("ReqEnterTowerDungeonBattle") or RemoteDungeon:WaitForChild("ReqEnterTowerDungeonBattle", 1.5))

local ReqUseBattleItem = waitFor(RemoteBattle, "ReqUseBattleItem")
    or waitFor(RemoteBattle, "ReqUseItem")
    or waitFor(RemoteBattle, "ReqUseProp")
local RemoteItem = waitFor(ReplicatedStorage, "Remote", "Item")
local ReqUseItemGlobal = RemoteItem and (
    RemoteItem:FindFirstChild("ReqUseItem")
    or RemoteItem:FindFirstChild("ReqUseProp")
    or RemoteItem:FindFirstChild("ReqUseBattleItem")
)

local HealRemoteCandidates = {}
if ReqUseBattleItem then table.insert(HealRemoteCandidates, {name = "ReqUseBattleItem", remote = ReqUseBattleItem}) end
if ReqUseItemGlobal then table.insert(HealRemoteCandidates, {name = "ReqUseItemGlobal", remote = ReqUseItemGlobal}) end
if ReqOperateBattle then table.insert(HealRemoteCandidates, {name = "ReqOperateBattle", remote = ReqOperateBattle}) end

print("[AutoHeal] Heal remote candidates found:", #HealRemoteCandidates)
for i, c in ipairs(HealRemoteCandidates) do
    print(string.format("  #%d %s -> %s", i, c.name, tostring(c.remote)))
end

-- ────────────────────────────────────────────────────────────────────
-- SECTION 4B + 4C : BOSS SCANNER FULL UNION (INSTANT AUTOMATIC SCAN)
-- ────────────────────────────────────────────────────────────────────
local BOSS_MANUAL_MAP = {
    [10003]  = 9000003,
    [10009]  = 9000006,
    [100011] = 9000007,
}
local BOSS_DISPLAY_REMAP = {
    [10009]  = 10006,
    [100011] = 10007,
}

local function getDisplayNpcId(npcId)
    return BOSS_DISPLAY_REMAP[npcId] or npcId
end

local function getRealNpcId(displayId)
    for realId, fakeId in pairs(BOSS_DISPLAY_REMAP) do
        if fakeId == displayId then
            return realId
        end
    end
    return displayId
end

local BOSS_BATTLE_FALLBACK = {}
do
    for i = 1, 999 do
        local npcId = 10000 + i
        BOSS_BATTLE_FALLBACK[npcId] = BOSS_MANUAL_MAP[npcId] or (9000000 + i)
    end
end

local function getConfig(cfgId)
    local ok, cfg = pcall(function()
        return ConfigDataManager.getConfig(ConfigConst.ConfigName.NPC, cfgId)
    end)
    if ok and typeof(cfg) == "table" then
        return cfg
    end
    return nil
end

local function isBossConfig(cfg)
    if typeof(cfg) ~= "table" then return false end
    local v = cfg.bossType
    if typeof(v) == "number" then return v ~= 0 end
    if typeof(v) == "boolean" then return v end
    if typeof(v) == "string" then return v ~= "" and v ~= "0" end
    return false
end

local function extractBattleId(cfg, npcId)
    if npcId and BOSS_MANUAL_MAP[npcId] then
        return BOSS_MANUAL_MAP[npcId], "manual"
    end
    if typeof(cfg) == "table" then
        local fields = {
            "battleId", "battle", "battleConfigId",
            "bossBattleId", "npcBattleId", "fightId", "battleID",
        }
        for _, f in ipairs(fields) do
            local val = cfg[f]
            if typeof(val) == "number" and val > 0 then
                return val, "config"
            end
        end
        local bList = cfg.battleList
        if typeof(bList) == "table" then
            for _, v in ipairs(bList) do
                if typeof(v) == "number" and v > 0 then
                    return v, "config"
                end
                if typeof(v) == "table" and typeof(v.battleId) == "number" and v.battleId > 0 then
                    return v.battleId, "config"
                end
            end
        end
        local bArr = cfg.battles
        if typeof(bArr) == "table" then
            for _, v in ipairs(bArr) do
                if typeof(v) == "number" and v > 0 then
                    return v, "config"
                end
            end
        end
    end
    if npcId and BOSS_BATTLE_FALLBACK[npcId] then
        return BOSS_BATTLE_FALLBACK[npcId], "fallback"
    end
    return 0, "none"
end

local function createEntry(npcId)
    local cfg = getConfig(npcId)
    local name = "Boss " .. tostring(npcId)
    if cfg and typeof(cfg.name) == "string" and cfg.name ~= "" then
        name = cfg.name
    end
    local battleId, battleSource = extractBattleId(cfg, npcId)
    return {
        npcId = npcId,
        displayNpcId = getDisplayNpcId(npcId),
        displayName = name,
        battleId = battleId or 0,
        battleSource = battleSource or "none",
        hasBattle = (battleId or 0) ~= 0,
        fromManual = false,
        fromAlive = false,
        fromCooldown = false,
        fromConfig = false,
        status = "UNKNOWN",
        sourceText = "",
        name = "",
    }
end

local function ensureEntry(map, npcId)
    if not map[npcId] then
        map[npcId] = createEntry(npcId)
    end
    return map[npcId]
end

local function finalizeEntry(e)
    local parts = {}
    if e.fromAlive then parts[#parts + 1] = "ALIVE" end
    if e.fromCooldown then parts[#parts + 1] = "COOLDOWN" end
    if e.fromManual then parts[#parts + 1] = "MANUAL" end
    if e.fromConfig then parts[#parts + 1] = "CONFIG" end
    e.sourceText = (#parts > 0) and table.concat(parts, "+") or "UNKNOWN"
    if e.fromAlive then
        e.status = "ALIVE"
    elseif e.fromCooldown then
        e.status = "COOLDOWN"
    elseif e.fromManual then
        e.status = "MANUAL"
    elseif e.fromConfig then
        e.status = "AVAILABLE"
    end
    e.name = string.format("%s (%d) [%s]", e.displayName, e.displayNpcId, e.sourceText)
end

-- สแกนบอสทั้งหมดทันที (Instant Auto-Scan) โดยตัดการรอ task.wait ออก ทำให้ได้รายชื่อครบตั้งแต่โหลด
local function scanAllBosses()
    local map = {}
    for npcId in pairs(BOSS_MANUAL_MAP) do
        local e = ensureEntry(map, npcId)
        e.fromManual = true
    end
    local creatureList = nil
    if CreatureService and typeof(CreatureService.getCreatureListByType) == "function" then
        local ok, a, b = pcall(function()
            return CreatureService.getCreatureListByType(CreatureConst and CreatureConst.CreatureType and CreatureConst.CreatureType.NPC or 2)
        end)
        if ok then
            if typeof(a) == "table" and b == nil then
                creatureList = a
            elseif typeof(b) == "table" then
                creatureList = b
            end
        end
    end
    if typeof(creatureList) == "table" then
        for _, c in pairs(creatureList) do
            if typeof(c) == "table" and c.configId then
                local cfg = getConfig(c.configId)
                if isBossConfig(cfg) then
                    local e = ensureEntry(map, c.configId)
                    e.fromAlive = true
                end
            end
        end
    end
    if RefreshService and typeof(RefreshService.getBossRefreshInfoList) == "function" then
        local ok, refreshList = pcall(function()
            return RefreshService.getBossRefreshInfoList()
        end)
        if ok and typeof(refreshList) == "table" then
            for _, r in ipairs(refreshList) do
                if typeof(r) == "table" and r.npcId then
                    local e = ensureEntry(map, r.npcId)
                    e.fromCooldown = true
                end
            end
        end
    end
    for cfgId = 10001, 10100 do
        local cfg = getConfig(cfgId)
        if isBossConfig(cfg) then
            local e = ensureEntry(map, cfgId)
            e.fromConfig = true
        end
    end
    local result = {}
    for _, e in pairs(map) do
        finalizeEntry(e)
        result[#result + 1] = e
    end
    table.sort(result, function(a, b)
        if a.displayNpcId ~= b.displayNpcId then
            return a.displayNpcId < b.displayNpcId
        end
        return a.npcId < b.npcId
    end)
    if #result == 0 then
        result[1] = {
            npcId = 0,
            displayNpcId = 0,
            displayName = "None",
            battleId = 0,
            battleSource = "none",
            hasBattle = false,
            fromManual = false,
            fromAlive = false,
            fromCooldown = false,
            fromConfig = false,
            status = "NONE",
            sourceText = "NONE",
            name = "No Boss Found",
        }
    end
    return result
end

-- สแกนทันทีตั้งแต่โหลดสคริปต์ ทำให้ Dropdown มีรายชื่อบอสครบถ้วนไม่ต้องกด Rescan
local BOSS_LIST = scanAllBosses()
print("=== Boss Scan Result ===")
print(string.format("Total: %d bosses automatically scanned!", #BOSS_LIST))

-- ────────────────────────────────────────────────────────────────────
-- SECTION 5B : CATCH WINDOW CHECKER
-- ────────────────────────────────────────────────────────────────────
local _catchWindow = nil
local _cwLastRefresh = 0
local function getCatchWindow()
    local now = os.clock()
    if _catchWindow and _catchWindow.Parent and (now - _cwLastRefresh) < 2 then
        return _catchWindow
    end
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    local prefabs = pg and pg:FindFirstChild("UIPrefabs")
    local win = prefabs and prefabs:FindFirstChild("BattleCatchPetWindow")
    _catchWindow, _cwLastRefresh = win, now
    return win
end

local function isCatchWindowOpen()
    local win = getCatchWindow()
    return win ~= nil and win.Enabled == true
end

local function waitForCatchWindowEnabled(maxWait)
    maxWait = maxWait or 0.5
    local elapsed = 0
    local step = 0.05
    while elapsed < maxWait do
        if isCatchWindowOpen() then
            return true
        end
        task.wait(step)
        elapsed += step
    end
    return isCatchWindowOpen()
end

-- ────────────────────────────────────────────────────────────────────
-- SECTION 6 : CONFIG & STATE
-- ────────────────────────────────────────────────────────────────────
local CFG = {
    ElemAdvEnabled       = false,
    ElemAdvAutoSwitch    = false,
    ElemAdvMinRate       = 2.0,
    ElemAdvScanDelay     = 0.75,
    ElemAdvActionType    = 3,
    ElemAdvSourcePos     = 1,
    ElemAdvTargetPos     = 1,
    ElemAdvShowGUI       = true,
    ElemAdvMaxRows       = 80,
    ElemAdvSwitchOnlyWhenDead = true,
    ElemAdvDeadHpPercent = 0,
    AutoTower           = false,
    AutoTowerDelay      = 5,
    AutoTowerAutoBattle = false,
    PetMgrEnabled       = false,
    PetMgrKeepTiers     = {4, 5},
    PetMgrKeepShiny     = true,
    PetMgrKeepColorful  = true,
    PetMgrAutoLock      = true,
    PetMgrAutoDelete    = false,
    PetMgrScanInterval  = 1.0,
    PetMgrRequestDelay  = 0.05,
    PetMgrBatchSize     = 25,
    PetMgrVerbose       = false,
    AutoTask            = false,
    TaskReceiveDelay    = 0.5,
    TaskClaimDelay      = 0.5,
    TaskLoopInterval    = 30,
    TaskAutoReceive     = true,
    TaskAutoClaim       = true,
    AutoBattle          = false,
    AutoHeal            = false,
    HealDelay           = 0.1, -- [MODIFIED] ความถี่ตรวจ HP ใน battle เร็วสุดที่ 0.1 วินาที!
    HealThreshold       = 50,
    HealItemPriority    = {2000001, 2000002, 2000003},
    HealTargetPos       = 1,
    HealSourcePos       = 1,
    HealForceMode       = false,
    AutoEnterBattle     = false,
    AutoChest           = false,
    AutoCatch           = false,
    AutoEscape          = false,
    BallItemId          = 2000015,
    ScanDelay           = 0.4,
    CatchDelay          = 1.0,
    EscapeDelay         = 1.0,
    ChestClaimDelay     = 0.3,
    ChestScanDelay      = 2.0,
    PreCheckDelay       = 0.3,
    WindowCheckDelay    = 0.5,
    AutoTP              = false,
    TPCheckInterval     = 10,
    TPHeight            = 10,
    TPMaxRetries        = 3,
    TPDebug             = true,
    AutoNPC             = false,
    NPCLoopDelay        = 2.5,
    AutoBoss            = false,
    AutoBossDelay       = 6,
    AutoBossAutoBattle  = false,
    -- [MODIFIED] Auto Fast Boss Mode Settings (ยึด Target World เป็นหลักตัวเดียว ลบ Start/Max World ออก)
    AutoFastBoss        = false,
    FastBossMode        = "Manual / Single World (สไลด์เลือกโลกอิสระ)",
    FastBossTargetWorld = 1, -- ยึด Target World เป็นหลักตัวเดียว
    AutoFastBossDelay   = 5,
    AutoFastBossAutoBattle = true,
    AntiAFK             = false,
    AutoBattleResync    = 2.0,
}

local State = {
    elemAdvStatus        = "OFF",
    elemAdvEnemyName     = "—",
    elemAdvEnemyElements = "",
    elemAdvBestPet       = "—",
    elemAdvBestRate      = 0,
    elemAdvCandidates    = 0,
    elemAdvLastSwitch    = 0,
    elemAdvBusy          = false,
    elemAdvLockedUid     = nil,
    elemAdvLockedName    = "—",
    towerStatus          = "OFF",
    inTowerBattle        = false,
    petMgrStatus         = "OFF",
    petMgrCycle          = 0,
    petMgrLastScan       = 0,
    petMgrLocked         = 0,
    petMgrDeleted        = 0,
    petMgrScanned        = 0,
    petMgrKept           = 0,
    petMgrRunning        = false,
    petMgrStop           = false,
    isFighting           = false,
    taskBusy             = false,
    taskStatus           = "OFF",
    taskLastRun          = 0,
    taskReceived         = 0,
    taskClaimed          = 0,
    healBusy             = false,
    isHealing            = false, -- [NEW] สถานะกำลังใช้ยา Heal เพื่อหยุด Auto Battle หรือการทำสิ่งอื่นชั่วคราว
    lastHealAt           = 0,
    healStatus           = "OFF",
    enterCooldown        = false,
    catchBusy            = false,
    escapeBusy           = false,
    chestBusy            = false,
    lastEnterAt          = 0,
    enterTimeout         = 6,
    lastTPAreaId         = nil,
    lastTPLevel          = nil,
    currentLevel         = nil,
    tpStatus             = "IDLE",
    npcStatus            = "OFF",
    bossStatus           = "OFF",
    fastBossStatus       = "OFF",
    inNpcBattle          = false,
    inBossBattle         = false,
    afkStatus            = "OFF",
    lastAutoBattleSent   = 0,
}

-- ────────────────────────────────────────────────────────────────────
-- SECTION 6B : AUTO PET MANAGER HELPERS
-- ────────────────────────────────────────────────────────────────────
local _petMgrTierSet = {}
local function rebuildTierSet()
    _petMgrTierSet = {}
    for _, tier in ipairs(CFG.PetMgrKeepTiers) do
        _petMgrTierSet[tier] = true
    end
end
rebuildTierSet()

local function getPetTeamSet_Mgr()
    local teamSet = {}
    if not PetGroupStorageMod then return teamSet end
    local ok, groupData = pcall(function()
        return PetGroupStorageMod.getPetGroup()
    end)
    if not ok or not groupData then return teamSet end
    local groupList = groupData.petGroupList or groupData.groupList or groupData
    if typeof(groupList) ~= "table" then return teamSet end
    for _, group in pairs(groupList) do
        if typeof(group) == "table" then
            local uuids = group.petUuids or group.uuids or group.pets or {}
            if typeof(uuids) == "table" then
                for _, uuid in ipairs(uuids) do
                    if typeof(uuid) == "string" and uuid ~= "" then
                        teamSet[uuid] = true
                    end
                end
            end
        end
    end
    return teamSet
end

local function getPetList_Mgr()
    if PetServiceModule and PetServiceModule.getPlayerPetData then
        local ok, success, petData = pcall(function()
            return PetServiceModule.getPlayerPetData()
        end)
        if ok and success and petData and typeof(petData.petList) == "table" then
            return petData.petList, nil
        end
        if ok and typeof(success) == "table" and typeof(success.petList) == "table" then
            return success.petList, nil
        end
    end
    if PetStorage and PetStorage.getPlayerPetData then
        local ok, data = pcall(function()
            return PetStorage.getPlayerPetData()
        end)
        if ok and data and typeof(data.petList) == "table" then
            return data.petList, nil
        end
    end
    return nil, "ไม่สามารถดึง petList ได้"
end

local function getPetKeepReasons_Mgr(pet)
    local reasons = {}
    if _petMgrTierSet[pet.talentId] then
        reasons[#reasons + 1] = "Tier:" .. tostring(pet.talentId)
    end
    if CFG.PetMgrKeepShiny and pet.shinyTypeId == 2 then
        reasons[#reasons + 1] = "Shiny"
    end
    if CFG.PetMgrKeepColorful then
        if typeof(pet.colorful) == "table" and typeof(pet.colorful.colorId) == "number" then
            reasons[#reasons + 1] = "Colorful"
        end
    end
    return reasons
end

local function setPetLocked_Mgr(uuid, locked)
    if not PetServiceModule then return false, "PetServiceModule nil" end
    if PetServiceModule.reqSetPetLocked then
        local ok, result = pcall(function()
            return PetServiceModule.reqSetPetLocked(uuid, locked)
        end)
        if ok then
            local success = (result == EC_SUCCEEDED) or (result == true)
            return success, result
        end
    end
    if PetServiceModule.setLocked then
        local ok, result = pcall(function()
            return PetServiceModule.setLocked(uuid, locked)
        end)
        if ok then
            return (result == EC_SUCCEEDED or result == true), result
        end
    end
    return false, "NoMethod"
end

local function removePetBatch_Mgr(uuidList)
    if not PetServiceModule then return false, "PetServiceModule nil" end
    if #uuidList == 0 then return true, "empty" end
    if PetServiceModule.reqRemovePets then
        local ok, result = pcall(function()
            return PetServiceModule.reqRemovePets(uuidList)
        end)
        if ok then
            return (result == EC_SUCCEEDED or result == true), result
        end
    end
    if PetServiceModule.removePets then
        local ok, result = pcall(function()
            return PetServiceModule.removePets(uuidList)
        end)
        if ok then
            return (result == EC_SUCCEEDED or result == true), result
        end
    end
    if PetServiceModule.reqDeletePet and #uuidList == 1 then
        local ok, result = pcall(function()
            return PetServiceModule.reqDeletePet(uuidList[1])
        end)
        if ok then
            return (result == EC_SUCCEEDED or result == true), result
        end
    end
    return false, "NoMethod"
end

local function deleteWithFallback_Mgr(toDelete)
    if #toDelete == 0 then return 0 end
    local batchSize = math.max(1, CFG.PetMgrBatchSize)
    local deletedCount = 0
    for i = 1, #toDelete, batchSize do
        if State.petMgrStop then break end
        local batch = {}
        for j = i, math.min(i + batchSize - 1, #toDelete) do
            batch[#batch + 1] = toDelete[j]
        end
        local success = false
        success = select(1, removePetBatch_Mgr(batch))
        if success then
            deletedCount += #batch
        else
            if #batch > 1 then
                for _, uuid in ipairs(batch) do
                    if State.petMgrStop then break end
                    local ok1 = select(1, removePetBatch_Mgr({uuid}))
                    if ok1 then
                        deletedCount += 1
                    end
                    if CFG.PetMgrRequestDelay > 0 then
                        task.wait(CFG.PetMgrRequestDelay)
                    end
                end
            end
        end
        if CFG.PetMgrRequestDelay > 0 then
            task.wait(CFG.PetMgrRequestDelay)
        end
    end
    return deletedCount
end

local function petMgrScanOnce()
    local petList, err = getPetList_Mgr()
    if not petList then
        State.petMgrStatus = "Error: " .. (err or "unknown")
        return
    end
    local teamSet = getPetTeamSet_Mgr()
    local toLock = {}
    local toDelete = {}
    local scanCount = 0
    local keptCount = 0
    for uuid, pet in pairs(petList) do
        if typeof(uuid) ~= "string" or uuid == "" then continue end
        if typeof(pet) ~= "table" then continue end
        scanCount += 1
        local reasons = getPetKeepReasons_Mgr(pet)
        local isValuable = #reasons > 0
        if isValuable then
            keptCount += 1
            if CFG.PetMgrAutoLock and pet.locked ~= true then
                toLock[#toLock + 1] = {uuid = uuid, reason = table.concat(reasons, "+")}
            end
        else
            if CFG.PetMgrAutoDelete and pet.locked ~= true and pet.loved ~= true and not teamSet[uuid] then
                toDelete[#toDelete + 1] = uuid
            end
        end
    end
    local lockedCount = 0
    local deletedCount = 0
    if CFG.PetMgrAutoLock and #toLock > 0 then
        for _, item in ipairs(toLock) do
            if State.petMgrStop then break end
            local ok = select(1, setPetLocked_Mgr(item.uuid, true))
            if ok then lockedCount += 1 end
            if CFG.PetMgrRequestDelay > 0 then
                task.wait(CFG.PetMgrRequestDelay)
            end
        end
    end
    if CFG.PetMgrAutoDelete and #toDelete > 0 then
        deletedCount = deleteWithFallback_Mgr(toDelete)
    end
    State.petMgrCycle += 1
    State.petMgrScanned = scanCount
    State.petMgrKept = keptCount
    State.petMgrLocked = lockedCount
    State.petMgrDeleted = deletedCount
    State.petMgrLastScan = os.clock()
    State.petMgrStatus = string.format(
        "Cycle %d | Scan:%d Keep:%d Lock:%d Del:%d",
        State.petMgrCycle, scanCount, keptCount, lockedCount, deletedCount
    )
end

-- ────────────────────────────────────────────────────────────────────
-- SECTION 6C : ELEMENT ADVANTAGE HELPERS
-- ────────────────────────────────────────────────────────────────────
local ELEM_PET_CFG_NAME = nil
local ELEM_TYPE_CFG_NAME = nil
if ConfigConst and ConfigConst.ConfigName then
    ELEM_PET_CFG_NAME = ConfigConst.ConfigName.PET
    ELEM_TYPE_CFG_NAME = ConfigConst.ConfigName.ELEMENT_TYPE
end

local function getElemPetConfig(petConfigId)
    if typeof(petConfigId) ~= "number" then return nil end
    if not ConfigDataManager or not ELEM_PET_CFG_NAME then return nil end
    local ok, cfg = pcall(function()
        return ConfigDataManager.getConfig(ELEM_PET_CFG_NAME, petConfigId)
    end)
    if ok and typeof(cfg) == "table" then return cfg end
    return nil
end

local function getElemTypeConfig(elementId)
    if typeof(elementId) ~= "number" then return nil end
    if not ConfigDataManager or not ELEM_TYPE_CFG_NAME then return nil end
    local ok, cfg = pcall(function()
        return ConfigDataManager.getConfig(ELEM_TYPE_CFG_NAME, elementId)
    end)
    if ok and typeof(cfg) == "table" then return cfg end
    return nil
end

local function getElementName(elementId)
    local cfg = getElemTypeConfig(elementId)
    if cfg and typeof(cfg.name) == "string" and cfg.name ~= "" then
        return cfg.name
    end
    return tostring(elementId or "?")
end

local function elementListToText(elementList)
    if typeof(elementList) ~= "table" or #elementList == 0 then
        return "None"
    end
    local names = {}
    for _, id in ipairs(elementList) do
        names[#names + 1] = getElementName(id)
    end
    return table.concat(names, ", ")
end

local function getPetElementsByConfigId(configId)
    local cfg = getElemPetConfig(configId)
    if cfg and typeof(cfg.elements) == "table" then
        local out = {}
        for _, elementId in ipairs(cfg.elements) do
            if typeof(elementId) == "number" then
                out[#out + 1] = elementId
            end
        end
        return out
    end
    return {}
end

local function getPetNameByConfigId_Elem(configId)
    local cfg = getElemPetConfig(configId)
    if cfg and typeof(cfg.name) == "string" and cfg.name ~= "" then
        return cfg.name
    end
    return "Pet#" .. tostring(configId or "?")
end

local function getElemBattleData()
    local battle = nil
    if BattleService then
        local ok, result = pcall(BattleService.getCurrentBattle)
        if ok and typeof(result) == "table" then
            battle = result
        end
    end
    if not battle and MainBattleWindowController then
        if typeof(MainBattleWindowController.getBattleDataCache) == "function" then
            local ok, result = pcall(MainBattleWindowController.getBattleDataCache)
            if ok and typeof(result) == "table" then
                battle = result
            end
        end
    end
    return battle
end

local function getElemCurrentEnemyPet(battleData)
    if not battleData then return nil end
    if MainBattleWindowController and typeof(MainBattleWindowController.getCurrentEnemyPet) == "function" then
        local ok, pet = pcall(function()
            return MainBattleWindowController.getCurrentEnemyPet(battleData)
        end)
        if ok and typeof(pet) == "table" then return pet end
    end
    if BattleDataGetModule then
        local isBoss = false
        if typeof(BattleDataGetModule.isServerBossBattle) == "function" then
            local ok2, r = pcall(BattleDataGetModule.isServerBossBattle, battleData)
            if ok2 then isBoss = r end
        end
        if isBoss and typeof(BattleDataGetModule.getCurrentBossPet) == "function" then
            local ok3, pet = pcall(BattleDataGetModule.getCurrentBossPet, battleData)
            if ok3 and typeof(pet) == "table" then return pet end
        end
        if typeof(BattleDataGetModule.getActivePetsData) == "function" then
            local ok4, active = pcall(BattleDataGetModule.getActivePetsData, battleData)
            if ok4 and typeof(active) == "table" and typeof(active.enemyPets) == "table" then
                return active.enemyPets[1]
            end
        end
    end
    return nil
end

local BATTLE_HP_FIELDS = {"hp", "curHp", "currentHp", "nowHp", "hpValue", "life", "curHP", "hpCur"}
local BATTLE_MAXHP_FIELDS = {"maxHp", "hpMax", "maxHP", "hpMaxValue", "maxLife", "fullHp", "totalHp"}

local function extractPetHp(pet)
    if typeof(pet) ~= "table" then return nil, nil, -1 end
    local hp, maxHp = nil, nil
    for _, f in ipairs(BATTLE_HP_FIELDS) do
        if typeof(pet[f]) == "number" then
            hp = pet[f]
            break
        end
    end
    for _, f in ipairs(BATTLE_MAXHP_FIELDS) do
        if typeof(pet[f]) == "number" and pet[f] > 0 then
            maxHp = pet[f]
            break
        end
    end
    if (not hp or not maxHp) then
        for _, sub in ipairs({pet.attr, pet.status, pet.battleData, pet.data, pet.hpInfo}) do
            if typeof(sub) == "table" then
                if not hp then
                    for _, f in ipairs(BATTLE_HP_FIELDS) do
                        if typeof(sub[f]) == "number" then
                            hp = sub[f]
                            break
                        end
                    end
                end
                if not maxHp then
                    for _, f in ipairs(BATTLE_MAXHP_FIELDS) do
                        if typeof(sub[f]) == "number" and sub[f] > 0 then
                            maxHp = sub[f]
                            break
                        end
                    end
                end
            end
        end
    end
    local pct = -1
    if typeof(hp) == "number" and typeof(maxHp) == "number" and maxHp > 0 then
        pct = math.floor((hp / maxHp) * 100)
    elseif typeof(hp) == "number" and hp <= 0 then
        pct = 0
    end
    return hp, maxHp, pct
end

local function collectElemBattleTeamPets(battleData)
    local list = {}
    if not battleData then return list end
    if not BattleDataGetModule then return list end
    if typeof(BattleDataGetModule.buildSelfBattlePetListForSwitch) ~= "function" then
        return list
    end
    local ok, switchList = pcall(function()
        return BattleDataGetModule.buildSelfBattlePetListForSwitch(battleData)
    end)
    if not ok or typeof(switchList) ~= "table" then return list end
    for _, pet in ipairs(switchList) do
        if typeof(pet) == "table" and typeof(pet.configId) == "number" then
            local slotText = "Team"
            if typeof(pet.index) == "number" then
                slotText = "Slot " .. pet.index
            elseif typeof(pet.groupPos) == "number" then
                slotText = "Pos " .. pet.groupPos
            end
            if pet.isInField == true then
                slotText = slotText .. " (Active)"
            end
            local hp, maxHp, hpPct = extractPetHp(pet)
            local isDead = false
            if hpPct == 0 then isDead = true end
            if pet.isDead == true or pet.dead == true or pet.isFaint == true then isDead = true end
            list[#list + 1] = {
                source     = "BattleTeam",
                uid        = pet.uuid or "",
                battleUid  = pet.uid or "",
                configId   = pet.configId,
                name       = getPetNameByConfigId_Elem(pet.configId),
                elements   = getPetElementsByConfigId(pet.configId),
                slotText   = slotText,
                canOperate = true,
                isInField  = pet.isInField or false,
                switchIndex = pet.index,
                groupPos    = pet.groupPos,
                targetUid   = pet.uid or pet.uuid or "",
                hp = hp,
                maxHp = maxHp,
                hpPercent = hpPct,
                isDead = isDead,
            }
        end
    end
    return list
end

local function getActiveTeamPet(battleData)
    local team = collectElemBattleTeamPets(battleData)
    for _, p in ipairs(team) do
        if p.isInField then
            return p
        end
    end
    return nil
end

local function collectElemBagPets()
    local list = {}
    local seenUid = {}
    local playerPetData = nil
    if PetStorage and typeof(PetStorage.getPlayerPetData) == "function" then
        local ok, data = pcall(PetStorage.getPlayerPetData)
        if ok and typeof(data) == "table" then
            playerPetData = data
        end
    end
    if not playerPetData and PetServiceModule and typeof(PetServiceModule.getPlayerPetData) == "function" then
        local ok2, result1, result2 = pcall(function()
            return PetServiceModule.getPlayerPetData()
        end)
        if ok2 then
            if typeof(result1) == "table" and typeof(result1.petList) == "table" then
                playerPetData = result1
            elseif typeof(result2) == "table" and typeof(result2.petList) == "table" then
                playerPetData = result2
            end
        end
    end
    if not playerPetData or typeof(playerPetData.petList) ~= "table" then
        return list
    end
    for uid, petData in pairs(playerPetData.petList) do
        if typeof(uid) == "string" and uid ~= "" and typeof(petData) == "table" then
            local configId = petData.configId
            if typeof(configId) == "number" and not seenUid[uid] then
                seenUid[uid] = true
                list[#list + 1] = {
                    source     = "Bag",
                    uid        = uid,
                    battleUid  = petData.uid or "",
                    configId   = configId,
                    name       = getPetNameByConfigId_Elem(configId),
                    elements   = getPetElementsByConfigId(configId),
                    slotText   = "Bag",
                    canOperate = false,
                    isInField  = false,
                    targetUid  = "",
                }
            end
        end
    end
    return list
end

local function calcBestAdvantageRate(ownElements, enemyElements)
    if not ElementModule then return 0, nil, nil end
    if typeof(ownElements) ~= "table" or typeof(enemyElements) ~= "table" then
        return 0, nil, nil
    end
    if #ownElements == 0 or #enemyElements == 0 then return 0, nil, nil end
    if typeof(ElementModule.calculateMultiElementRestraintRate) ~= "function" then
        return 0, nil, nil
    end
    local bestRate = 0
    local bestAtkElement = nil
    local bestResult = nil
    for _, atkElement in ipairs(ownElements) do
        if typeof(atkElement) == "number" then
            local ok, result = pcall(function()
                return ElementModule.calculateMultiElementRestraintRate(atkElement, enemyElements)
            end)
            if ok and typeof(result) == "table" then
                local isOk = (result.result == 0)
                if not isOk and EC_SUCCEEDED then
                    isOk = (result.result == EC_SUCCEEDED)
                end
                if not isOk and ErrorCode then
                    isOk = (result.result == (ErrorCode.SUCCEEDED or 0))
                end
                if isOk then
                    local rate = result.rate
                    if typeof(rate) == "number" and rate > bestRate then
                        bestRate = rate
                        bestAtkElement = atkElement
                        bestResult = result
                    end
                end
            end
        end
    end
    return bestRate, bestAtkElement, bestResult
end

local function buildElemCandidates()
    local battleData = getElemBattleData()
    local enemyPet = getElemCurrentEnemyPet(battleData)
    local enemyConfigId = nil
    if typeof(enemyPet) == "table" then
        enemyConfigId = enemyPet.configId
    end
    local enemyName = "No Enemy"
    if typeof(enemyConfigId) == "number" then
        enemyName = getPetNameByConfigId_Elem(enemyConfigId)
    end
    local enemyElements = {}
    if typeof(enemyConfigId) == "number" then
        enemyElements = getPetElementsByConfigId(enemyConfigId)
    end
    local merged = {}
    local seenKey = {}
    local function addPet(pet)
        if typeof(pet) ~= "table" then return end
        local key = ""
        if typeof(pet.uid) == "string" and pet.uid ~= "" then
            key = "uid:" .. pet.uid
        elseif typeof(pet.battleUid) == "string" and pet.battleUid ~= "" then
            key = "buid:" .. pet.battleUid
        else
            key = "cfg:" .. tostring(pet.configId) .. ":" .. tostring(pet.source) .. ":" .. tostring(pet.slotText)
        end
        if seenKey[key] then return end
        seenKey[key] = true
        merged[#merged + 1] = pet
    end
    for _, p in ipairs(collectElemBattleTeamPets(battleData)) do
        addPet(p)
    end
    for _, p in ipairs(collectElemBagPets()) do
        addPet(p)
    end
    local rows = {}
    if #enemyElements > 0 then
        for _, pet in ipairs(merged) do
            local rate, atkElement, calcResult = calcBestAdvantageRate(pet.elements, enemyElements)
            if rate >= CFG.ElemAdvMinRate then
                pet.advantageRate = rate
                pet.bestAtkElement = atkElement
                pet.effect = calcResult and calcResult.effect or nil
                rows[#rows + 1] = pet
            end
        end
    end
    table.sort(rows, function(a, b)
        local rateA = a.advantageRate or 0
        local rateB = b.advantageRate or 0
        if rateA ~= rateB then return rateA > rateB end
        if a.source == "BattleTeam" and b.source ~= "BattleTeam" then return true end
        if b.source == "BattleTeam" and a.source ~= "BattleTeam" then return false end
        return tostring(a.name or "") < tostring(b.name or "")
    end)
    return battleData, enemyPet, enemyName, enemyElements, rows
end

local function elemSwitchPet(petRecord)
    if not petRecord then return false, "nil pet" end
    if petRecord.source ~= "BattleTeam" then return false, "Not BattleTeam" end
    if not petRecord.canOperate then return false, "Cannot operate" end
    if petRecord.isInField then return false, "Already active" end
    if not ReqOperateBattle then return false, "No remote" end
    local targetUid = petRecord.targetUid or petRecord.battleUid or petRecord.uid
    if not targetUid or targetUid == "" then return false, "No uid" end
    local payload = {
        sourcePos = CFG.ElemAdvSourcePos or 1,
        targetPos = CFG.ElemAdvTargetPos or 1,
        targetUid = tostring(targetUid),
        actionType = CFG.ElemAdvActionType or 3,
    }
    local ok, result = pcall(function()
        return ReqOperateBattle:InvokeServer(payload)
    end)
    if ok then
        State.elemAdvLastSwitch = os.clock()
        return true, tostring(result)
    end
    return false, tostring(result)
end

local function findBestTeamSwitch(rows)
    for _, pet in ipairs(rows) do
        if pet.source == "BattleTeam" and pet.canOperate and not pet.isInField then
            return pet
        end
    end
    return nil
end

local function getElemPetBattleUid(pet)
    if typeof(pet) ~= "table" then return "" end
    if typeof(pet.battleUid) == "string" and pet.battleUid ~= "" then return pet.battleUid end
    if typeof(pet.targetUid) == "string" and pet.targetUid ~= "" then return pet.targetUid end
    if typeof(pet.uid) == "string" and pet.uid ~= "" then return pet.uid end
    return ""
end

local function isElemPetDead(pet)
    if typeof(pet) ~= "table" then return true end
    if pet.isDead == true or pet.dead == true or pet.isFaint == true then return true end
    if typeof(pet.hpPercent) == "number" and pet.hpPercent >= 0 then
        return pet.hpPercent <= (CFG.ElemAdvDeadHpPercent or 0)
    end
    return false
end

local function findElemRowByUid(rows, uid)
    if typeof(rows) ~= "table" or typeof(uid) ~= "string" or uid == "" then
        return nil
    end
    for _, r in ipairs(rows) do
        if getElemPetBattleUid(r) == uid then
            return r
        end
    end
    return nil
end

local function getAliveTeamAdvRows(rows)
    local out = {}
    for _, pet in ipairs(rows) do
        if pet.source == "BattleTeam" and pet.canOperate and not isElemPetDead(pet) then
            out[#out + 1] = pet
        end
    end
    return out
end

-- ────────────────────────────────────────────────────────────────────
-- SECTION 7 : AREA CONFIGS & LEVEL MAP
-- ────────────────────────────────────────────────────────────────────
local AreaConfigs = {
    [1000001] = "World1WildArea1",     [1000002] = "World1GrassArea1",
    [1000003] = "World1WaterArea1",    [1000004] = "World1FireArea1",
    [1000005] = "World1MountainArea1", [1000006] = "World1MountainArea2",
    [1000007] = "World1MountainArea3", [1000008] = "World1GymArea1",
    [1000009] = "World1GrassArea2",    [1000010] = "World1FlyingArea1",
    [1000011] = "World1FlyArea3",      [1000012] = "World1WaterArea3",
    [1000013] = "World1BossArea1",
    [1001] = "World1Island1",  [1002] = "World1Island2",  [1003] = "World1Island3",
    [1004] = "World1Island4",  [1005] = "World1Island5",  [1006] = "World1Island6",
    [1007] = "World1Island7",  [1008] = "World1Island8",  [1009] = "World1Island9",
    [1010] = "World1Island10", [1011] = "World1BossIsland1",
    [1012] = "World1SummonIsland1", [1013] = "World1SummonIsland2",
    [1014] = "World1SummonIsland3", [1015] = "World1Island11",
    [1016] = "MainCity", [1017] = "World1Island12", [1018] = "World1Island13",
    [1019] = "World1Island14", [1020] = "World1Island15",
}

local LevelToAreaMap = {
    [0] = 1001,  [7] = 1002,  [14] = 1003, [21] = 1004, [28] = 1005, [35] = 1006,
    [42] = 1007, [49] = 1008, [56] = 1009, [63] = 1010, [70] = 1015,
    [77] = 1017, [84] = 1018, [91] = 1019, [98] = 1020,
}

local AreaNameList, AreaNameToId = {}, {}
do
    for id, name in pairs(AreaConfigs) do
        if not table.find(AreaNameList, name) then
            table.insert(AreaNameList, name)
            AreaNameToId[name] = id
        end
    end
    table.sort(AreaNameList)
end

-- ────────────────────────────────────────────────────────────────────
-- SECTION 8 : NPC LIST
-- ────────────────────────────────────────────────────────────────────
local NPC_LIST = {
    { name = "NPC #1", npcId = 10000, battleId = 11000024, dialogueMarkId = 100000, dialogueEndId = 100001, canEnterType = 4 },
    { name = "NPC #2", npcId = 10001, battleId = 11000025, dialogueMarkId = 100002, dialogueEndId = 100003, canEnterType = 4 },
    { name = "NPC #3", npcId = 10002, battleId = 11000026, dialogueMarkId = 100004, dialogueEndId = 100005, canEnterType = 4 },
    { name = "NPC #4", npcId = 10003, battleId = 11000027, dialogueMarkId = 100006, dialogueEndId = 100007, canEnterType = 4 },
    { name = "NPC #5", npcId = 10004, battleId = 11000028, dialogueMarkId = 100008, dialogueEndId = 100009, canEnterType = 4 },
}

local function buildNameList(list)
    local out = {}
    for _, v in ipairs(list) do
        table.insert(out, v.name)
    end
    return out
end

local NPC_NAMES = buildNameList(NPC_LIST)
local BOSS_NAMES = buildNameList(BOSS_LIST)
local selectedNPC = NPC_LIST[1]
local selectedBoss = BOSS_LIST[1]

-- ────────────────────────────────────────────────────────────────────
-- SECTION 9 : PET UID RESOLVER
-- ────────────────────────────────────────────────────────────────────
local DEFAULT_PET_UID = "03f77cc8-e683-4dab-addc-1e27ada6ce8e"
local function getFirstPetUid()
    if PetServiceModule and typeof(PetServiceModule.getMainPetUid) == "function" then
        local ok, mainUid = pcall(function()
            return PetServiceModule.getMainPetUid()
        end)
        if ok and typeof(mainUid) == "string" and mainUid ~= "" then
            return mainUid
        end
    end
    if PetServiceModule and typeof(PetServiceModule.getPlayerPetData) == "function" then
        local ok, a, b = pcall(function()
            return PetServiceModule.getPlayerPetData()
        end)
        if ok then
            local data = nil
            if typeof(a) == "table" and typeof(a.petList) == "table" then
                data = a
            elseif typeof(b) == "table" and typeof(b.petList) == "table" then
                data = b
            end
            if data then
                for id in pairs(data.petList) do
                    if typeof(id) == "string" and id ~= "" then
                        return id
                    end
                end
            end
        end
    end
    if PetStorage then
        if typeof(PetStorage.getMainPet) == "function" then
            local ok, main = pcall(function()
                return PetStorage.getMainPet()
            end)
            if ok and typeof(main) == "string" and main ~= "" then
                return main
            end
        end
        if typeof(PetStorage.getPlayerPetData) == "function" then
            local ok, data = pcall(function()
                return PetStorage.getPlayerPetData()
            end)
            if ok and typeof(data) == "table" and typeof(data.petList) == "table" then
                for id in pairs(data.petList) do
                    if typeof(id) == "string" and id ~= "" then
                        return id
                    end
                end
            end
        end
    end
    return DEFAULT_PET_UID
end

-- ────────────────────────────────────────────────────────────────────
-- SECTION 10 : NPC & BOSS ACTIONS (MODIFIED WITH FAST BOSS)
-- ────────────────────────────────────────────────────────────────────
local function executeNPCBattle(npc)
    local ok, err = pcall(function()
        if ReqMarkDialogueTalkCompleted then
            ReqMarkDialogueTalkCompleted:FireServer(npc.dialogueMarkId)
            task.wait(0.3)
        end
        if ResDialogueEnded then
            ResDialogueEnded:InvokeServer(npc.npcId, npc.dialogueEndId, true)
            task.wait(0.3)
        end
        if ReqCanEnterBattle then
            ReqCanEnterBattle:InvokeServer(npc.canEnterType)
            task.wait(0.2)
            ReqCanEnterBattle:InvokeServer(npc.canEnterType)
            task.wait(0.3)
        end
        if ReqEnterNpcBattle then
            local petUid = (typeof(npc.petUid) == "string" and npc.petUid ~= "") and npc.petUid or getFirstPetUid()
            ReqEnterNpcBattle:FireServer(npc.npcId, npc.battleId, petUid)
        end
    end)
    if not ok then warn("[AutoNPC]", err) end
end

local function enterBoss(boss)
    boss = boss or selectedBoss
    if not boss or not boss.hasBattle or boss.battleId == 0 then
        warn("[AutoBoss] Boss has no valid battleId:", boss and boss.name or "nil")
        return false
    end
    local petUid = (typeof(boss.petUid) == "string" and boss.petUid ~= "") and boss.petUid or getFirstPetUid()
    local ok, err = pcall(function()
        if ReqEnterNpcBattle then
            ReqEnterNpcBattle:FireServer(boss.npcId, boss.battleId, petUid)
        end
    end)
    if not ok then warn("[AutoBoss]", err); return false end
    return true
end

-- ฟังก์ชันสำหรับเข้าสู้ในโหมด Auto Fast Boss โดยใช้ NPC 10000 คงที่ และปรับ Battle ID ตามเลขโลก (9000000 + World)
local function enterFastBoss(worldNum)
    if not ReqEnterNpcBattle then return false, "Remote not found" end
    worldNum = tonumber(worldNum) or 1
    local npcId = 10000           -- [1] คงที่ที่ค่า 10000 เสมอเฉพาะโหมด Fast Boss
    local battleId = 9000000 + worldNum -- [2] เรียกเลขท้ายเป็นโลก เช่น 9000009 คือ world 9
    local petUid = getFirstPetUid()     -- [3] UUID ของ pet ที่เราใช้สู้
    
    local ok, err = pcall(function()
        ReqEnterNpcBattle:FireServer(npcId, battleId, petUid)
    end)
    if not ok then return false, tostring(err) end
    print(string.format("[AutoFastBoss] Fired ReqEnterNpcBattle | NPC: %d | BattleID: %d | Pet: %s", npcId, battleId, tostring(petUid)))
    return true, string.format("World %d (ID: %d)", worldNum, battleId)
end

local function setServerAutoBattle(on)
    pcall(function()
        if ReqAutoBattle then ReqAutoBattle:InvokeServer(on) end
    end)
end

local function enterTowerBattle()
    if not ReqEnterTowerDungeonBattle then
        return false, "Remote not found"
    end
    local ok, result = pcall(function()
        return ReqEnterTowerDungeonBattle:InvokeServer()
    end)
    if not ok then
        return false, tostring(result)
    end
    return true, tostring(result)
end

local function forceSetAutoBattle(on)
    if BattleService then
        pcall(BattleService.autoBattle, on)
        pcall(function()
            if BattleService.setAutoBattle then
                BattleService.setAutoBattle(on)
            end
        end)
    end
    pcall(function()
        if ReqAutoBattle then
            ReqAutoBattle:InvokeServer(on)
        end
    end)
    State.lastAutoBattleSent = os.clock()
end

-- ────────────────────────────────────────────────────────────────────
-- SECTION 11 : PET ANALYSIS HELPERS
-- ────────────────────────────────────────────────────────────────────
local SIX_ATTRS = {}
if AttrConst and AttrConst.ATTR then
    SIX_ATTRS = {
        { id = AttrConst.ATTR.HP_BASE_VALUE,         name = "HP" },
        { id = AttrConst.ATTR.BASE_ATK_BASE_VALUE,   name = "ATK" },
        { id = AttrConst.ATTR.SPECIAL_ATK_BASE_VALUE,name = "SP.ATK" },
        { id = AttrConst.ATTR.BASE_DEF_BASE_VALUE,   name = "DEF" },
        { id = AttrConst.ATTR.SPECIAL_DEF_BASE_VALUE,name = "SP.DEF" },
        { id = AttrConst.ATTR.SPEED_BASE_VALUE,      name = "SPD" },
    }
end

local function getNatureEffects(petData)
    local effects = {}
    if not ConfigDataManager or not ConfigConst or not ConfigConst.ConfigName then return effects end
    local natureId = petData.natureId
    if typeof(natureId) ~= "number" or natureId == 0 then return effects end
    local ok, cfg = pcall(function()
        return ConfigDataManager.getConfig(ConfigConst.ConfigName.PET_NATURE, natureId)
    end)
    if ok and typeof(cfg) == "table" and typeof(cfg.effect) == "table" then
        for _, eff in ipairs(cfg.effect) do
            if typeof(eff) == "table" and #eff >= 2 then
                effects[eff[1]] = eff[2]
            end
        end
    end
    return effects
end

local function getNatureName(petData)
    if not ConfigDataManager or not ConfigConst or not ConfigConst.ConfigName then return "None" end
    local natureId = petData.natureId
    if typeof(natureId) ~= "number" or natureId == 0 then return "None" end
    local ok, cfg = pcall(function()
        return ConfigDataManager.getConfig(ConfigConst.ConfigName.PET_NATURE, natureId)
    end)
    if ok and typeof(cfg) == "table" then return cfg.name or "Unknown" end
    return "Unknown"
end

local function getTalentInfo(petData)
    if not ConfigDataManager or not ConfigConst or not ConfigConst.ConfigName then return "?", 0 end
    local talentId = petData.talentId
    if typeof(talentId) ~= "number" then return "?", 0 end
    local ok, cfg = pcall(function()
        return ConfigDataManager.getConfig(ConfigConst.ConfigName.PET_TALENT, talentId)
    end)
    if ok and typeof(cfg) == "table" then
        local grade = cfg.des or "?"
        local power = 0
        if typeof(cfg.value) == "table" and typeof(cfg.value[1]) == "number" then
            power = cfg.value[1]
        end
        return grade, power
    end
    return "?", 0
end

local function getPetName(petData)
    if typeof(petData.name) == "string" and petData.name ~= "" then return petData.name end
    if not ConfigDataManager or not ConfigConst or not ConfigConst.ConfigName then return "Unknown" end
    local ok, cfg = pcall(function()
        return ConfigDataManager.getConfig(ConfigConst.ConfigName.PET, petData.configId)
    end)
    if ok and typeof(cfg) == "table" then return cfg.name or "Unknown" end
    return "Unknown"
end

local function calculateLv1Potential(petData)
    local stats, totalPotential, totalTalent = {}, 0, 0
    local natureEffects = getNatureEffects(petData)
    for _, attr in ipairs(SIX_ATTRS) do
        local attrId = attr.id
        local baseValue = 0
        if PetComm then
            local ok, bv = pcall(function()
                return PetComm.getPetBaseValue(petData, attrId)
            end)
            if ok and typeof(bv) == "number" then baseValue = bv end
        end
        local talentValue = (typeof(petData.talentList) == "table") and (petData.talentList[attrId] or 0) or 0
        local natureEff = natureEffects[attrId] or 0
        local potential = baseValue + talentValue + natureEff
        stats[attrId] = {
            name = attr.name,
            base = baseValue,
            talent = talentValue,
            nature = natureEff,
            potential = potential,
        }
        totalPotential += potential
        totalTalent += talentValue
    end
    return totalPotential, totalTalent, stats
end

local function calculateCurrentPower(petData)
    local statValues, totalStats, totalTalent = {}, 0, 0
    local natureEffects = getNatureEffects(petData)
    for _, attr in ipairs(SIX_ATTRS) do
        local attrId = attr.id
        local baseValue = 0
        if PetComm then
            local ok, val = pcall(function()
                local _, v = PetComm.getPetAttrValue(petData, attrId)
                return v
            end)
            if ok and typeof(val) == "number" then baseValue = val end
        end
        local talentValue = (typeof(petData.talentList) == "table") and (petData.talentList[attrId] or 0) or 0
        local natureEff = natureEffects[attrId] or 0
        statValues[attrId] = {
            name = attr.name,
            value = baseValue,
            talent = talentValue,
            nature = natureEff,
        }
        totalStats += baseValue
        totalTalent += talentValue
    end
    return totalStats, totalTalent, statValues
end

local function setTeam(top5UUIDs)
    if not ReqSetPetGroupList then return false, "Remote not found" end
    local args = {
        {
            { name = "", petUuids = top5UUIDs },
            { name = "", petUuids = {} },
            { name = "", petUuids = {} },
        }
    }
    local ok, result = pcall(function()
        return ReqSetPetGroupList:InvokeServer(unpack(args))
    end)
    return ok, tostring(result)
end

local function scanAndRankPets(mode)
    if not PetStorage then return nil, "PetStorage not found" end
    local playerPetData = PetStorage.getPlayerPetData()
    if not playerPetData or typeof(playerPetData.petList) ~= "table" then
        return nil, "petList not found"
    end
    local allPets = {}
    for uuid, petData in pairs(playerPetData.petList) do
        if typeof(uuid) == "string" and typeof(petData) == "table" then
            local score, totalTalent, statDetail
            if mode == "potential" then
                score, totalTalent, statDetail = calculateLv1Potential(petData)
            else
                score, totalTalent, statDetail = calculateCurrentPower(petData)
            end
            local talentGrade, talentPower = getTalentInfo(petData)
            table.insert(allPets, {
                uuid        = uuid,
                name        = getPetName(petData),
                configId    = petData.configId or 0,
                level       = petData.level or 0,
                score       = score,
                totalTalent = totalTalent,
                talentGrade = talentGrade,
                talentPower = talentPower,
                natureName  = getNatureName(petData),
                statDetail  = statDetail,
                locked      = petData.locked or false,
                loved       = petData.loved or false,
            })
        end
    end
    table.sort(allPets, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        if a.totalTalent ~= b.totalTalent then return a.totalTalent > b.totalTalent end
        return a.uuid < b.uuid
    end)
    return allPets, nil
end

local function formatPetLines(allPets, mode)
    local lines = {}
    local displayCount = math.min(5, #allPets)
    local header = mode == "potential" and "TOP 5 Lv.1 POTENTIAL" or "TOP 5 CURRENT POWER"
    table.insert(lines, header)
    table.insert(lines, string.rep("─", 40))
    for i = 1, displayCount do
        local p = allPets[i]
        local scoreLabel = mode == "potential" and "Potential" or "Power"
        table.insert(lines, string.format("#%d  %s  (Lv.%d)", i, p.name, p.level))
        table.insert(lines, string.format("    Grade: %-5s  Nature: %s", p.talentGrade, p.natureName))
        table.insert(lines, string.format("    %s: %d  (Talent: %d)", scoreLabel, p.score, p.totalTalent))
        for _, attr in ipairs(SIX_ATTRS) do
            local s = p.statDetail[attr.id]
            if s then
                local val = mode == "potential" and s.potential or s.value
                local natStr = s.nature > 0 and ("+" .. s.nature) or (s.nature < 0 and tostring(s.nature) or "0")
                table.insert(lines, string.format("    %-8s %5d  [T:%d N:%s]", s.name, val, s.talent, natStr))
            end
        end
        local tags = {}
        if p.locked then table.insert(tags, "Locked") end
        if p.loved then table.insert(tags, "Loved") end
        if #tags > 0 then table.insert(lines, "    " .. table.concat(tags, " ")) end
        table.insert(lines, "    UUID: " .. p.uuid)
        if i < displayCount then table.insert(lines, string.rep("─", 40)) end
    end
    return lines
end

-- ────────────────────────────────────────────────────────────────────
-- SECTION 12 : BATTLE STATE LISTENERS (MODIFIED WITH FAST BOSS SEQUENTIAL TARGET ADVANCE)
-- ────────────────────────────────────────────────────────────────────
if ClientBattleStart then
    ClientBattleStart.Event:Connect(function()
        State.isFighting = true
        State.enterCooldown = false
        if CFG.AutoBattle and not State.isHealing then
            task.spawn(function()
                task.wait(0.3)
                if not State.isHealing then
                    forceSetAutoBattle(true)
                end
            end)
        end
    end)
end

local function onBattleEnd()
    State.isFighting = false
    State.enterCooldown = false
    State.catchBusy = false
    State.escapeBusy = false
    State.inNpcBattle = false
    State.inBossBattle = false
    State.inTowerBattle = false
    State.elemAdvLockedUid = nil
    State.elemAdvLockedName = "—"
    
    -- ถ้าเปิดแบบ Sequential เมื่อจบการต่อสู้ ให้เลื่อน Target World ถัดไปทันที (วนลูป 1-20)
    if CFG.AutoFastBoss and string.find(tostring(CFG.FastBossMode), "Sequential") then
        local nextW = (tonumber(CFG.FastBossTargetWorld) or 1) + 1
        if nextW > 20 then
            nextW = 1
        end
        CFG.FastBossTargetWorld = nextW
        pcall(function()
            if _G.FastBossSliderRef then _G.FastBossSliderRef:SetValue(nextW) end
        end)
        print("[AutoFastBoss] Battle ended -> Advanced Target World to:", nextW)
    end
end
if ResSettleBattle then ResSettleBattle.OnClientEvent:Connect(onBattleEnd) end
if ResStatisticsBattle then ResStatisticsBattle.OnClientEvent:Connect(onBattleEnd) end
if ClientEnterBattleFail then
    ClientEnterBattleFail.Event:Connect(function()
        State.isFighting = false
        State.enterCooldown = false
        State.inNpcBattle = false
        State.inBossBattle = false
    end)
end

-- ────────────────────────────────────────────────────────────────────
-- SECTION 13 : CREATURE CACHE HELPERS
-- ────────────────────────────────────────────────────────────────────
local _cachedCC, _ccLastCheck = nil, 0
local function getCreatureCache()
    local now = os.clock()
    if _cachedCC and (now - _ccLastCheck) < 2 then
        return _cachedCC
    end
    local rt = Workspace:FindFirstChild("RuntimeCache")
    local srv = rt and rt:FindFirstChild("RuntimeCacheServer")
    local cc = srv and srv:FindFirstChild("CreatureModelCache")
    _cachedCC, _ccLastCheck = cc, now
    return cc
end

local function getMyPosition()
    if LocalPlayer.Character then
        local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then return hrp.Position end
    end
    local cache = getCreatureCache()
    if cache then
        for _, folder in ipairs(cache:GetChildren()) do
            local c = folder:FindFirstChild(LocalPlayer.Name)
            if c then
                if c:IsA("Model") and c.PrimaryPart then return c.PrimaryPart.Position end
                local p = c:FindFirstChildWhichIsA("BasePart", true) or folder:FindFirstChildWhichIsA("BasePart", true)
                if p then return p.Position end
            end
        end
    end
    return nil
end

local function getFolderPosition(folder)
    local model = folder:FindFirstChildOfClass("Model")
    if model then
        if model.PrimaryPart then return model.PrimaryPart.Position end
        local b = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
        if b then return b.Position end
    end
    local b = folder:FindFirstChildWhichIsA("BasePart", true)
    return b and b.Position or nil
end

local _myUid, _uidLastChk = nil, 0
local function getMyDynamicUid()
    local now = os.clock()
    if _myUid and (now - _uidLastChk) < 3 then return _myUid end
    local cache = getCreatureCache()
    if cache then
        for _, folder in ipairs(cache:GetChildren()) do
            if folder:FindFirstChild(LocalPlayer.Name) then
                _myUid, _uidLastChk = folder.Name, now
                return _myUid
            end
        end
    end
    _myUid = nil
    return nil
end

local function getTargetUids()
    local myUid = getMyDynamicUid()
    local myPos = getMyPosition()
    if not myPos then return {} end
    local cache = getCreatureCache()
    if not cache then return {} end
    local list = {}
    for _, folder in ipairs(cache:GetChildren()) do
        if folder.Name ~= myUid and tonumber(folder.Name) then
            local ep = getFolderPosition(folder)
            if ep then
                list[#list + 1] = {uid = folder.Name, distance = (myPos - ep).Magnitude}
            end
        end
    end
    table.sort(list, function(a, b)
        return a.distance < b.distance
    end)
    local uids = {}
    for i, d in ipairs(list) do
        uids[i] = d.uid
    end
    return uids
end

-- ────────────────────────────────────────────────────────────────────
-- SECTION 14 : CONDITION CHECKERS
-- ────────────────────────────────────────────────────────────────────
local function isInBattle()
    if State.isFighting then return true end
    if BattleService then
        local ok, cur = pcall(BattleService.getCurrentBattle)
        if ok and cur then return true end
    end
    if State.inNpcBattle then return true end
    if State.inBossBattle then return true end
    return false
end

local function canEnterBattle()
    if State.isFighting or State.enterCooldown then return false end
    if BattleService then
        local ok, cur = pcall(BattleService.getCurrentBattle)
        if ok and cur then return false end
    end
    return true
end

-- ────────────────────────────────────────────────────────────────────
-- SECTION 14B : AUTO HEAL HELPERS (MODIFIED WITH UI HP SOURCE & EXACT REQOPERATEBATTLE ARGS)
-- ────────────────────────────────────────────────────────────────────
local _healDebugDumped = false
local function dumpBattleStructure(battle, label)
    if _healDebugDumped then return end
    _healDebugDumped = true
    print("═══════ [AutoHeal] BATTLE STRUCTURE DUMP ═══════")
    print("Label:", label)
    if typeof(battle) ~= "table" then
        print("  battle is not a table:", typeof(battle))
        return
    end
    for key, val in pairs(battle) do
        local valType = typeof(val)
        if valType == "table" then
            print(string.format("  [%s] = table", tostring(key)))
            local count = 0
            for k2, v2 in pairs(val) do
                count += 1
                if count <= 10 then
                    local v2Type = typeof(v2)
                    if v2Type == "table" then
                        local subKeys = {}
                        for k3 in pairs(v2) do
                            subKeys[#subKeys + 1] = tostring(k3)
                            if #subKeys >= 15 then break end
                        end
                        print(string.format("    [%s] = table { %s }", tostring(k2), table.concat(subKeys, ", ")))
                    else
                        print(string.format("    [%s] = %s: %s", tostring(k2), v2Type, tostring(v2)))
                    end
                end
            end
            print(string.format("  [%s] total entries: %d", tostring(key), count))
        else
            print(string.format("  [%s] = %s: %s", tostring(key), valType, tostring(val)))
        end
    end
    print("═══════ END DUMP ═══════")
end

local _cachedBattle, _cachedBattleTime = nil, 0
local function getCurrentBattleData()
    local now = os.clock()
    if _cachedBattle and (now - _cachedBattleTime) < 0.3 then
        return _cachedBattle
    end
    if not BattleService then return nil end
    local ok, battle = pcall(BattleService.getCurrentBattle)
    if ok and battle then
        _cachedBattle = battle
        _cachedBattleTime = now
        dumpBattleStructure(battle, "getCurrentBattle")
        return battle
    end
    _cachedBattle = nil
    return nil
end

local _battlePetHeadInternal = nil
local function getBattlePetHeadInternal()
    if _battlePetHeadInternal then
        return _battlePetHeadInternal
    end
    if not BattlePetHeadModule then
        return nil
    end
    local fnNames = {
        "initBattlePetHeadDisplay",
        "updateBattlePetHeadDisplay",
        "updateBattlePetHeadIceBar",
        "resolveEnabled",
    }
    for _, fnName in ipairs(fnNames) do
        local fn = BattlePetHeadModule[fnName]
        if typeof(fn) == "function" then
            for i = 1, 20 do
                local ok, upName, upValue = pcall(function()
                    if debug and typeof(debug.getupvalue) == "function" then
                        return debug.getupvalue(fn, i)
                    elseif typeof(getupvalue) == "function" then
                        return getupvalue(fn, i)
                    end
                end)
                if ok then
                    local up = upValue ~= nil and upValue or upName
                    if typeof(up) == "table" and typeof(up._battlePetDisplayDataMap) == "table" then
                        _battlePetHeadInternal = up
                        print("[AutoHeal] Hooked BattlePetHead internal from:", fnName, "upvalue", i)
                        return _battlePetHeadInternal
                    end
                end
            end
        end
    end
    return nil
end

local function getBattlePetHeadHpPercent(battleUid)
    if typeof(battleUid) ~= "string" or battleUid == "" then
        return nil, nil, -1
    end
    local internal = getBattlePetHeadInternal()
    local dataMap = internal and internal._battlePetDisplayDataMap
    local rec = dataMap and dataMap[battleUid]
    if typeof(rec) ~= "table" then
        return nil, nil, -1
    end
    local hp = tonumber(rec.currentHp)
    local maxHp = tonumber(rec.maxHp)
    if hp and maxHp and maxHp > 0 then
        hp = math.clamp(hp, 0, maxHp)
        return hp, maxHp, math.floor((hp / maxHp) * 100)
    end
    return nil, nil, -1
end

local function getBattleTeamPetSlot(pos)
    pos = pos or 1
    local elemBattle = getElemBattleData()
    if not elemBattle then return nil end
    local team = collectElemBattleTeamPets(elemBattle)
    if #team == 0 then return nil end
    local slot = nil
    if pos == 1 then
        for _, p in ipairs(team) do
            if p.isInField then
                slot = p
                break
            end
        end
    end
    slot = slot or team[pos] or team[1]
    return slot
end

local function getMyPetIdsInBattle(pos)
    local slot = getBattleTeamPetSlot(pos)
    if slot then
        return {
            petUuid   = (typeof(slot.uid) == "string" and slot.uid) or "",
            battleUid = (typeof(slot.battleUid) == "string" and slot.battleUid ~= "" and slot.battleUid)
                or (typeof(slot.targetUid) == "string" and slot.targetUid) or "",
            slot = slot,
        }
    end
    return {
        petUuid   = getFirstPetUid() or "",
        battleUid = "",
        slot      = nil,
    }
end

-- ฟังก์ชันตรวจสอบเลือดจาก GUI ตาม Path :
-- game:GetService("Players").LocalPlayer.PlayerGui.UIPrefabs.MainBattleWindow.MainCanvasGroup.SelfPetInfoFrame.SelfPetInfoAreaFrame.SelfPetInfoArea.SelfHpArea.SelfHpText
local function getUIBattlePetHp()
    local ok, cur, max, pct = pcall(function()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if not pg then return nil, nil, -1 end
        
        -- 1. เช็คตาม Path ตรงที่กำหนด: UIPrefabs -> MainBattleWindow...
        local prefabs = pg:FindFirstChild("UIPrefabs")
        local win = prefabs and prefabs:FindFirstChild("MainBattleWindow")
        
        -- 2. Fallback: กรณี MainBattleWindow ถูกย้ายมาอยู่ใต้ PlayerGui โดยตรงตอน Battle
        if not win then
            win = pg:FindFirstChild("MainBattleWindow")
        end
        
        local hpText = nil
        if win then
            local canvas = win:FindFirstChild("MainCanvasGroup")
            local infoFrame = canvas and canvas:FindFirstChild("SelfPetInfoFrame")
            local areaFrame = infoFrame and infoFrame:FindFirstChild("SelfPetInfoAreaFrame")
            local area = areaFrame and areaFrame:FindFirstChild("SelfPetInfoArea")
            local hpArea = area and area:FindFirstChild("SelfHpArea")
            hpText = hpArea and hpArea:FindFirstChild("SelfHpText")
        end
        
        -- 3. Fallback: ค้นหาแบบ Recursive ถ้าหาตาม Path ปกติไม่เจอ
        if not hpText then
            local searchRoot = win or prefabs or pg
            hpText = searchRoot:FindFirstChild("SelfHpText", true)
        end
        
        if hpText and (hpText:IsA("TextLabel") or hpText:IsA("TextBox") or type(hpText.Text) == "string") then
            local textStr = tostring(hpText.Text)
            -- รองรับรูปแบบ "366 / 542", "366/542", "HP: 366 / 542" ฯลฯ
            local cStr, mStr = string.match(textStr, "(%d+)%s*/%s*(%d+)")
            local cVal = tonumber(cStr)
            local mVal = tonumber(mStr)
            if cVal and mVal and mVal > 0 then
                local calcPct = math.floor((cVal / mVal) * 100)
                return cVal, mVal, math.clamp(calcPct, 0, 100)
            end
        end
        return nil, nil, -1
    end)
    
    if ok and pct and pct >= 0 then
        return cur, max, pct
    end
    return nil, nil, -1
end

local function getPetHpPercent(pos)
    pos = pos or 1
    -- [1] PRIORITY CHECK: เช็คเลือดจาก UI SelfHpText ตามที่กำหนด (แม่นยำและเสถียรที่สุดสำหรับ Active Pet)
    if pos == 1 or pos == CFG.HealTargetPos then
        local _, _, uiPct = getUIBattlePetHp()
        if uiPct and uiPct >= 0 then
            return uiPct
        end
    end

    do
        local ids = getMyPetIdsInBattle(pos)
        if ids and ids.battleUid ~= "" then
            local _, _, pct = getBattlePetHeadHpPercent(ids.battleUid)
            if pct >= 0 then
                return pct
            end
        end
        if ids and ids.slot and typeof(ids.slot.hpPercent) == "number" and ids.slot.hpPercent >= 0 then
            return ids.slot.hpPercent
        end
    end
    local battle = getCurrentBattleData()
    if not battle then
        return -1
    end
    local teamFieldNames = {
        "myTeam", "playerTeam", "selfTeam",
        "myPetList", "playerPets", "selfPets",
        "teamList", "petTeam", "myPets",
        "atkTeam", "attackTeam",
    }
    local hpFieldNames = {"hp", "currentHp", "hpValue", "curHp", "nowHp", "life"}
    local maxHpFieldNames = {"maxHp", "hpMax", "hpMaxValue", "maxLife", "fullHp", "totalHp"}
    for _, teamField in ipairs(teamFieldNames) do
        local team = battle[teamField]
        if typeof(team) ~= "table" then continue end
        local slot = nil
        if typeof(team[pos]) == "table" then
            slot = team[pos]
        elseif pos == 1 then
            for _, v in pairs(team) do
                if typeof(v) == "table" then
                    slot = v
                    break
                end
            end
        end
        if typeof(slot) == "table" then
            local hp, maxHp = nil, nil
            for _, f in ipairs(hpFieldNames) do
                if typeof(slot[f]) == "number" then hp = slot[f]; break end
            end
            for _, f in ipairs(maxHpFieldNames) do
                if typeof(slot[f]) == "number" and slot[f] > 0 then maxHp = slot[f]; break end
            end
            if hp and maxHp then
                return math.floor((hp / maxHp) * 100)
            end
        end
    end
    local statusFieldNames = {
        "battleStatus", "petStatus", "petStatusList",
        "statusList", "unitStatus", "petHpMap",
    }
    for _, statusField in ipairs(statusFieldNames) do
        local status = battle[statusField]
        if typeof(status) ~= "table" then continue end
        local slot = status[pos]
        if typeof(slot) ~= "table" and pos == 1 then
            for _, v in pairs(status) do
                if typeof(v) == "table" then
                    slot = v
                    break
                end
            end
        end
        if typeof(slot) == "table" then
            local hp, maxHp = nil, nil
            for _, f in ipairs(hpFieldNames) do
                if typeof(slot[f]) == "number" then hp = slot[f]; break end
            end
            for _, f in ipairs(maxHpFieldNames) do
                if typeof(slot[f]) == "number" and slot[f] > 0 then maxHp = slot[f]; break end
            end
            if hp and maxHp then
                return math.floor((hp / maxHp) * 100)
            end
        end
    end
    return -1
end

-- ฟังก์ชันค้นหา Battle UID ของ Pet ที่กำลังต่อสู้จริง (เช่น "30805") ให้แม่นยำ 100%
local function getFightingPetBattleUid(pos)
    pos = pos or 1
    
    -- 1. ค้นหาจาก getMyPetIdsInBattle (ผ่าน BattleDataGetModule / buildSelfBattlePetListForSwitch)
    local ids = getMyPetIdsInBattle(pos)
    if ids and typeof(ids.battleUid) == "string" and ids.battleUid ~= "" and ids.battleUid ~= ids.petUuid then
        return ids.battleUid
    end
    if ids and typeof(ids.battleUid) == "number" and ids.battleUid > 0 then
        return tostring(ids.battleUid)
    end

    -- 2. ค้นหาจาก BattlePetHeadModule._battlePetDisplayDataMap โดยเทียบกับค่า HP จาก GUI
    local internal = getBattlePetHeadInternal()
    if internal and typeof(internal._battlePetDisplayDataMap) == "table" then
        local uiCur, uiMax, _ = getUIBattlePetHp()
        for uidStr, rec in pairs(internal._battlePetDisplayDataMap) do
            if typeof(rec) == "table" then
                -- กรณีมี flag บ่งบอกว่าเป็นตัวเรา
                if rec.isSelf == true or rec.isPlayer == true or rec.isMyTeam == true or rec.side == 1 or rec.team == 1 or rec.isAlly == true then
                    return tostring(uidStr)
                end
            end
        end
        -- ถ้าไม่มี flag ลองเทียบตัวเลข HP/MaxHP กับ GUI SelfHpText
        for uidStr, _ in pairs(internal._battlePetDisplayDataMap) do
            if tostring(uidStr):match("^%d+$") and #tostring(uidStr) <= 10 then
                local hp, maxHp, _ = getBattlePetHeadHpPercent(uidStr)
                if (uiCur and hp and math.abs(uiCur - hp) <= 1) or (uiMax and maxHp and math.abs(uiMax - maxHp) <= 1) then
                    return tostring(uidStr)
                end
            end
        end
        -- ถ้ายังไม่เจอ ลองเอาคีย์แรกที่เป็นตัวเลขสั้นๆ (Battle UID)
        for uidStr, _ in pairs(internal._battlePetDisplayDataMap) do
            if tostring(uidStr):match("^%d+$") and #tostring(uidStr) <= 10 then
                return tostring(uidStr)
            end
        end
    end

    -- 3. ค้นหาใน getCurrentBattleData()
    local battle = getCurrentBattleData() or getElemBattleData()
    if battle and typeof(battle) == "table" then
        if BattleDataGetModule then
            if typeof(BattleDataGetModule.getActivePetsData) == "function" then
                local ok, activeData = pcall(BattleDataGetModule.getActivePetsData, battle)
                if ok and typeof(activeData) == "table" then
                    for _, field in ipairs({"selfPets", "myPets", "playerPets", "teamPets", "selfTeam"}) do
                        local list = activeData[field]
                        if typeof(list) == "table" then
                            local petObj = list[pos] or list[1]
                            if typeof(petObj) == "table" then
                                local uid = petObj.uid or petObj.battleUid or petObj.id or petObj.unitId or petObj.targetUid
                                if uid and tostring(uid) ~= "" then
                                    return tostring(uid)
                                end
                            end
                        end
                    end
                end
            end
            if typeof(BattleDataGetModule.getCurrentSelfPet) == "function" then
                local ok, petObj = pcall(BattleDataGetModule.getCurrentSelfPet, battle)
                if ok and typeof(petObj) == "table" then
                    local uid = petObj.uid or petObj.battleUid or petObj.id or petObj.unitId
                    if uid and tostring(uid) ~= "" then
                        return tostring(uid)
                    end
                end
            end
        end

        for _, field in ipairs({"myTeam", "playerTeam", "selfTeam", "myPetList", "playerPets", "selfPets", "teamList", "petTeam", "myPets", "atkTeam", "attackTeam"}) do
            local team = battle[field]
            if typeof(team) == "table" then
                local slot = team[pos]
                if typeof(slot) ~= "table" and pos == 1 then
                    for _, v in pairs(team) do
                        if typeof(v) == "table" then slot = v; break end
                    end
                end
                if typeof(slot) == "table" then
                    local uid = slot.uid or slot.battleUid or slot.id or slot.unitId or slot.targetUid
                    if uid and tostring(uid) ~= "" then
                        return tostring(uid)
                    end
                end
            end
        end
    end

    -- 4. Fallback สุดท้าย
    if ids and ids.battleUid and tostring(ids.battleUid) ~= "" then
        return tostring(ids.battleUid)
    end
    if ids and ids.petUuid and tostring(ids.petUuid) ~= "" then
        return tostring(ids.petUuid)
    end
    return ""
end

local function getMyPetUidInBattle(pos)
    return getFightingPetBattleUid(pos)
end

local function selectHealItem()
    if typeof(CFG.HealItemPriority) == "table" and #CFG.HealItemPriority > 0 then
        return CFG.HealItemPriority[1]
    end
    return 2000001
end

local function isHealInvokeSuccess(result)
    if result == nil then return true end
    if result == true then return true end
    if result == false then return false end
    local t = typeof(result)
    if t == "number" then
        return result == 0 or result == EC_SUCCEEDED
    end
    if t == "table" then
        if typeof(result.result) == "number" then
            return result.result == 0 or result.result == EC_SUCCEEDED
        end
        if typeof(result.code) == "number" then
            return result.code == 0 or result.code == EC_SUCCEEDED
        end
        return true
    end
    if t == "string" then
        local s = string.upper(result)
        if string.find(s, "FAIL", 1, true) or string.find(s, "ERROR", 1, true) then
            return false
        end
        return true
    end
    return true
end

local function tryHealCalls(label, calls)
    local lastErr = "unknown"
    for _, fn in ipairs(calls) do
        local ok, result = pcall(fn)
        if ok then
            if isHealInvokeSuccess(result) then
                print("[AutoHeal]", label, "success:", result)
                return true, result
            else
                lastErr = tostring(result)
            end
        else
            lastErr = tostring(result)
        end
    end
    return false, lastErr
end

-- executeHeal ให้เรียกใช้ ReqOperateBattle ด้วยโครงสร้างอาร์กิวเมนต์ที่ถูกต้อง (actionType = 4) เป็นอันดับแรก
-- เมื่อใช้น้ำยาสำเร็จ 1 ขวดแล้ว จะคืนค่าทันทีโดยไม่วนลูปซ้ำ เพื่อให้ระบบไปเช็คเลือดที่เพิ่มขึ้นก่อน
local function executeHeal()
    local targetPos = CFG.HealTargetPos or 1
    local sourcePos = CFG.HealSourcePos or 1
    local targetUid = getFightingPetBattleUid(targetPos)
    local itemList = (typeof(CFG.HealItemPriority) == "table" and #CFG.HealItemPriority > 0) and CFG.HealItemPriority or {2000001}
    local lastErr = "no method"

    print("[AutoHeal] Executing Heal... targetPos=", targetPos, " targetUid=", targetUid)

    for _, itemId in ipairs(itemList) do
        -- [1] PRIORITY METHOD: ใช้ ReqOperateBattle ด้วยโครงสร้าง args ตรงตามที่กำหนด (actionType = 4)
        if ReqOperateBattle then
            local payload = {
                targetPos = targetPos,
                targetUid = tostring(targetUid),
                sourcePos = sourcePos,
                actionType = 4,
                itemId = tonumber(itemId)
            }
            local ok, result = pcall(function()
                return ReqOperateBattle:InvokeServer(payload)
            end)
            if ok and isHealInvokeSuccess(result) then
                print("[AutoHeal] ReqOperateBattle (actionType=4) SUCCESS with Item ID:", itemId, "result:", result)
                State.lastHealAt = os.clock()
                return true, tonumber(itemId)
            else
                lastErr = tostring(result)
                print("[AutoHeal] ReqOperateBattle failed for Item ID:", itemId, "err:", lastErr)
            end
        end

        -- [2] FALLBACK: ลองใช้ ReqUseBattleItem (กรณีสำรองถ้า ReqOperateBattle ไม่ตอบสนอง)
        if ReqUseBattleItem then
            local ok, result = tryHealCalls("ReqUseBattleItem", {
                function() return ReqUseBattleItem:InvokeServer(itemId, targetPos) end,
                function() return ReqUseBattleItem:InvokeServer(itemId, targetUid) end,
                function()
                    return ReqUseBattleItem:InvokeServer({
                        itemId = itemId,
                        targetPos = targetPos,
                        targetUid = targetUid,
                    })
                end,
                function() ReqUseBattleItem:FireServer(itemId, targetPos); return true end,
            })
            if ok then
                State.lastHealAt = os.clock()
                return true, tonumber(itemId)
            else
                lastErr = tostring(result)
            end
        end

        -- [3] FALLBACK: ลองใช้ ReqUseItemGlobal
        if ReqUseItemGlobal then
            local ok, result = tryHealCalls("ReqUseItemGlobal", {
                function() return ReqUseItemGlobal:InvokeServer(itemId, targetPos) end,
                function() return ReqUseItemGlobal:InvokeServer(itemId, targetUid) end,
                function() ReqUseItemGlobal:FireServer(itemId, targetPos); return true end,
            })
            if ok then
                State.lastHealAt = os.clock()
                return true, tonumber(itemId)
            else
                lastErr = tostring(result)
            end
        end
    end

    warn("[AutoHeal] All heal methods failed | targetUid=", targetUid, " targetPos=", targetPos, " lastErr=", lastErr)
    State.lastHealAt = os.clock()
    return false, nil
end

local function scanHealRemotes()
    print("═══════ [AutoHeal] REMOTE SCAN ═══════")
    if RemoteBattle then
        print("Remote/Battle children:")
        for _, child in ipairs(RemoteBattle:GetChildren()) do
            print(string.format("  %s [%s]", child.Name, child.ClassName))
        end
    else
        print("RemoteBattle: NOT FOUND")
    end
    if RemoteItem then
        print("Remote/Item children:")
        for _, child in ipairs(RemoteItem:GetChildren()) do
            print(string.format("  %s [%s]", child.Name, child.ClassName))
        end
    else
        print("Remote/Item: NOT FOUND")
    end
    if BindableBattle then
        print("Bindable/Battle children:")
        for _, child in ipairs(BindableBattle:GetChildren()) do
            print(string.format("  %s [%s]", child.Name, child.ClassName))
        end
    end
    print("Heal Remote Candidates:", #HealRemoteCandidates)
    print("═══════ END REMOTE SCAN ═══════")
end
task.spawn(scanHealRemotes)

-- ────────────────────────────────────────────────────────────────────
-- SECTION 14C : AUTO TASK HELPERS
-- ────────────────────────────────────────────────────────────────────
local AUTO_TASK_IDS = {
    7001030,
    7001031,
    7001040,
    7001041,
    7001070,
    7001080,
    7001100,
    7001120,
    7001130,
    7001150,
}
local _taskReceiveCache = {}
local _taskClaimCache = {}
local TASK_RESULT = {
    [0] = "SUCCEEDED",
    [1] = "FAILED",
    [2] = "NOT_FOUND",
    [3] = "ALREADY_ACCEPTED",
    [4] = "NOT_COMPLETED",
}

local function taskResultStr(code)
    if typeof(code) == "number" then
        return TASK_RESULT[code] or ("UNKNOWN_" .. code)
    end
    return tostring(code)
end

local function scanExtraTaskIds()
    local extraIds = {}
    if ConfigDataManager then
        pcall(function()
            for id = 7001001, 7001200 do
                if not table.find(AUTO_TASK_IDS, id) then
                    local cfg = nil
                    local ok = pcall(function()
                        cfg = ConfigDataManager.getConfig("Task", id) or ConfigDataManager.getConfig("TASK", id)
                    end)
                    if ok and cfg then
                        table.insert(extraIds, id)
                    end
                end
            end
        end)
    end
    return extraIds
end

local function receiveOneTask(taskId)
    if not ReqReceiveTask then return false, "Remote not found" end
    if _taskReceiveCache[taskId] then return true, "ALREADY_CACHED" end
    local ok, result = pcall(function()
        return ReqReceiveTask:InvokeServer(taskId)
    end)
    if not ok then return false, tostring(result) end
    local code = typeof(result) == "number" and result or -1
    if code == 0 or code == 3 then
        _taskReceiveCache[taskId] = true
        return true, taskResultStr(code)
    end
    return false, taskResultStr(code)
end

local function claimOneTask(taskId)
    if not ReqCompleteTask then return false, "Remote not found" end
    if _taskClaimCache[taskId] then return true, "ALREADY_CACHED" end
    local ok, result = pcall(function()
        return ReqCompleteTask:InvokeServer(taskId)
    end)
    if not ok then return false, tostring(result) end
    local code = typeof(result) == "number" and result or -1
    if code == 0 then
        _taskClaimCache[taskId] = true
        return true, taskResultStr(code)
    end
    if code == 4 then
        return false, "NOT_COMPLETED"
    end
    return false, taskResultStr(code)
end

local function executeAutoTasks()
    local allTaskIds = {}
    for _, id in ipairs(AUTO_TASK_IDS) do
        table.insert(allTaskIds, id)
    end
    local extras = scanExtraTaskIds()
    for _, id in ipairs(extras) do
        if not table.find(allTaskIds, id) then
            table.insert(allTaskIds, id)
        end
    end
    local receivedCount = 0
    local claimedCount = 0
    local totalCount = #allTaskIds
    if CFG.TaskAutoReceive then
        State.taskStatus = string.format("Receiving tasks (0/%d)...", totalCount)
        for i, taskId in ipairs(allTaskIds) do
            if not CFG.AutoTask then break end
            local success, msg = receiveOneTask(taskId)
            if success then receivedCount += 1 end
            State.taskStatus = string.format("Receiving %d/%d (ok:%d) — %d: %s", i, totalCount, receivedCount, taskId, msg)
            task.wait(CFG.TaskReceiveDelay)
        end
    end
    if CFG.TaskAutoClaim then
        State.taskStatus = string.format("Claiming tasks (0/%d)...", totalCount)
        for i, taskId in ipairs(allTaskIds) do
            if not CFG.AutoTask then break end
            local success, msg = claimOneTask(taskId)
            if success then claimedCount += 1 end
            State.taskStatus = string.format("Claiming %d/%d (ok:%d) — %d: %s", i, totalCount, claimedCount, taskId, msg)
            task.wait(CFG.TaskClaimDelay)
        end
    end
    State.taskReceived = receivedCount
    State.taskClaimed = claimedCount
    State.taskLastRun = os.clock()
    State.taskStatus = string.format("Done — Received: %d, Claimed: %d / %d tasks", receivedCount, claimedCount, totalCount)
    return receivedCount, claimedCount
end

local function resetTaskCache()
    _taskReceiveCache = {}
    _taskClaimCache = {}
end

-- ────────────────────────────────────────────────────────────────────
-- SECTION 15 : PRE-CHECK WRAPPERS
-- ────────────────────────────────────────────────────────────────────
local function preCheckAndExecute(checkFn, actionFn)
    if not checkFn() then return false end
    task.wait(CFG.PreCheckDelay)
    if not checkFn() then return false end
    local ok, err = pcall(actionFn)
    if not ok then warn("[PreCheck]", err) end
    return ok
end

local function catchEscapePreCheck(checkFn, actionFn)
    if not checkFn() then return false end
    local windowOpen = waitForCatchWindowEnabled(CFG.WindowCheckDelay)
    if not windowOpen then return false end
    if not checkFn() then return false end
    task.wait(CFG.PreCheckDelay)
    if not checkFn() then return false end
    local ok, err = pcall(actionFn)
    if not ok then warn("[CatchEscapePreCheck]", err) end
    return ok
end

-- ────────────────────────────────────────────────────────────────────
-- SECTION 16 : TELEPORT SYSTEM
-- ────────────────────────────────────────────────────────────────────
local AreaCache, CacheLocked = {}, false
local function tpLog(...)
    if CFG.TPDebug then
        print("[AutoTP]", ...)
    end
end

local function getPlayerLevel()
    local ok, result = pcall(function()
        local LvService = require(
            ReplicatedStorage:WaitForChild("Script")
                :WaitForChild("Lv")
                :WaitForChild("LvService")
        )
        local _, lvData = LvService.getLvInfo()
        if type(lvData) == "table" and lvData.lv then
            return lvData.lv
        end
        return nil
    end)
    return ok and result or nil
end

local function getAreaIdFromLevel(level)
    if not level then return 1001 end
    local targetLevel, targetAreaId = 0, 1001
    for lvl, areaId in pairs(LevelToAreaMap) do
        if level >= lvl and lvl >= targetLevel then
            targetLevel = lvl
            targetAreaId = areaId
        end
    end
    return targetAreaId
end

local function scanForAreas()
    if CacheLocked then return false end
    CacheLocked = true
    local foundCount = 0
    local mapFolder = Workspace:FindFirstChild("Map") or Workspace:FindFirstChild("Areas") or Workspace
    for _, desc in ipairs(mapFolder:GetDescendants()) do
        if not desc:IsA("BasePart") and not desc:IsA("Model") then continue end
        local areaName, areaId, targetCFrame
        local attrId = desc:GetAttribute("AreaId")
        if attrId then
            local numId = tonumber(attrId)
            if numId and AreaConfigs[numId] then
                areaName = AreaConfigs[numId]
                areaId = numId
            end
        end
        if not areaName then
            local tileName = desc:GetAttribute("AreaTileName")
            if tileName then
                for id, name in pairs(AreaConfigs) do
                    if tileName == name then
                        areaName = name
                        areaId = id
                        break
                    end
                end
            end
        end
        if not areaName then
            for id, name in pairs(AreaConfigs) do
                if desc.Name == name then
                    areaName = name
                    areaId = id
                    break
                end
            end
        end
        if areaName then
            if desc:IsA("BasePart") then
                targetCFrame = desc.CFrame
            elseif desc:IsA("Model") then
                if desc.PrimaryPart then
                    targetCFrame = desc.PrimaryPart.CFrame
                else
                    local fp = desc:FindFirstChildWhichIsA("BasePart")
                    if fp then targetCFrame = fp.CFrame end
                end
            end
            if targetCFrame and not AreaCache[areaName] then
                AreaCache[areaName] = {name = areaName, id = areaId, cframe = targetCFrame}
                foundCount += 1
            end
        end
    end
    tpLog("Found", foundCount, "areas")
    CacheLocked = false
    return foundCount > 0
end

local function teleportToArea(areaId, retryCount)
    retryCount = retryCount or 0
    local areaName = AreaConfigs[areaId]
    if not areaName then return false end
    if not AreaCache[areaName] then
        scanForAreas()
        task.wait(1)
    end
    local data = AreaCache[areaName]
    if not data then
        if retryCount < CFG.TPMaxRetries then
            task.wait(2)
            return teleportToArea(areaId, retryCount + 1)
        end
        return false
    end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local targetCF = data.cframe * CFrame.new(0, CFG.TPHeight, 0)
    State.tpStatus = "TELEPORTING..."
    local ok = pcall(function()
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
        hrp.CFrame = targetCF
        task.wait(0.5)
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.CanCollide = true
            end
        end
    end)
    if ok then
        task.wait(0.5)
        local dist = (hrp.Position - targetCF.Position).Magnitude
        if dist > 50 and retryCount < CFG.TPMaxRetries then
            task.wait(1)
            return teleportToArea(areaId, retryCount + 1)
        end
        State.tpStatus = "OK: " .. areaName
        return true
    end
    State.tpStatus = "FAILED"
    return false
end

local function manualTeleport(areaName)
    local areaId = AreaNameToId[areaName]
    if areaId then return teleportToArea(areaId) end
    return false
end

-- ────────────────────────────────────────────────────────────────────
-- SECTION 17 : ANTI-AFK SYSTEM
-- ────────────────────────────────────────────────────────────────────
local _afkConnection = nil
local function setupAntiAFK()
    if _afkConnection then return end
    _afkConnection = LocalPlayer.Idled:Connect(function()
        if not CFG.AntiAFK then return end
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
        State.afkStatus = "Kicked Idle @ " .. os.date("%X")
    end)
end
local function teardownAntiAFK()
    if _afkConnection then
        _afkConnection:Disconnect()
        _afkConnection = nil
    end
    State.afkStatus = "OFF"
end

-- ────────────────────────────────────────────────────────────────────
-- SECTION 18 : WATCHDOG
-- ────────────────────────────────────────────────────────────────────
task.spawn(function()
    while true do
        task.wait(1)
        if State.enterCooldown and not State.isFighting then
            if (os.clock() - State.lastEnterAt) > State.enterTimeout then
                State.enterCooldown = false
            end
        end
        if State.isFighting and BattleService then
            local ok, cur = pcall(BattleService.getCurrentBattle)
            if ok and not cur then onBattleEnd() end
        end
        if not CFG.AutoCatch then State.catchBusy = false end
        if not CFG.AutoEscape then State.escapeBusy = false end
        if not CFG.AutoChest then State.chestBusy = false end
        if not CFG.AutoEnterBattle then State.enterCooldown = false end
        if not CFG.AutoNPC then State.inNpcBattle = false end
        if not CFG.AutoBoss and not CFG.AutoFastBoss then State.inBossBattle = false end
        if not CFG.AutoTower then State.inTowerBattle = false end
        if not CFG.AutoHeal then State.healBusy = false end
        if not CFG.AutoTask then State.taskBusy = false end
        if not CFG.ElemAdvEnabled then State.elemAdvBusy = false end
    end
end)

-- ────────────────────────────────────────────────────────────────────
-- SECTION 19 : FEATURE LOOPS (MODIFIED WITH ULTRA FAST 0.1s HEAL & INSTANT BATTLE PAUSE)
-- ────────────────────────────────────────────────────────────────────
task.spawn(function()
    local prevState = nil
    while true do
        task.wait(0.5)
        if CFG.AutoBattle ~= prevState then
            prevState = CFG.AutoBattle
            if not State.isHealing then
                forceSetAutoBattle(CFG.AutoBattle)
            end
        end
        if CFG.AutoBattle and isInBattle() and not State.isHealing then
            local now = os.clock()
            if (now - State.lastAutoBattleSent) > CFG.AutoBattleResync then
                forceSetAutoBattle(true)
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(math.max(0, CFG.ScanDelay))
        if State.isHealing or not CFG.AutoEnterBattle or not ReqEnterPetBattle then continue end
        local targets = getTargetUids()
        if not targets[1] then continue end
        local uid = targets[1]
        preCheckAndExecute(
            function()
                return not State.isHealing and CFG.AutoEnterBattle and canEnterBattle()
            end,
            function()
                State.enterCooldown = true
                State.lastEnterAt = os.clock()
                ReqEnterPetBattle:FireServer(uid)
            end
        )
    end
end)

task.spawn(function()
    while true do
        task.wait(CFG.ChestScanDelay)
        if not CFG.AutoChest or State.chestBusy or not ChestFolder or not ReqClaimChest then continue end
        State.chestBusy = true
        pcall(function()
            for _, chest in ipairs(ChestFolder:GetChildren()) do
                if not CFG.AutoChest then break end
                local id = chest.Name
                if id and #id > 5 then
                    preCheckAndExecute(
                        function()
                            return CFG.AutoChest and chest.Parent ~= nil
                        end,
                        function()
                            ReqClaimChest:InvokeServer(id)
                        end
                    )
                    task.wait(CFG.ChestClaimDelay)
                end
            end
        end)
        State.chestBusy = false
    end
end)

task.spawn(function()
    while true do
        task.wait(CFG.CatchDelay)
        if State.isHealing or not CFG.AutoCatch or State.catchBusy or not ReqOperateBattle then continue end
        local didAct = catchEscapePreCheck(
            function()
                return not State.isHealing and CFG.AutoCatch and not State.catchBusy and isInBattle() and isCatchWindowOpen()
            end,
            function()
                State.catchBusy = true
                ReqOperateBattle:InvokeServer({
                    sourcePos = 1,
                    targetPos = 1,
                    actionType = 5,
                    itemId = CFG.BallItemId,
                })
            end
        )
        if didAct then
            task.delay(CFG.CatchDelay, function()
                State.catchBusy = false
            end)
        else
            State.catchBusy = false
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(CFG.EscapeDelay)
        if State.isHealing or not CFG.AutoEscape or State.escapeBusy or not ReqOperateBattle then continue end
        local didAct = catchEscapePreCheck(
            function()
                return not State.isHealing and CFG.AutoEscape and not State.escapeBusy and isInBattle() and isCatchWindowOpen()
            end,
            function()
                State.escapeBusy = true
                ReqOperateBattle:InvokeServer({actionType = 8})
            end
        )
        if didAct then
            task.delay(CFG.EscapeDelay, function()
                State.escapeBusy = false
            end)
        else
            State.escapeBusy = false
        end
    end
end)

-- Auto Heal Loop (ความถี่เร็วสุด 0.1 วินาที + หยุด Auto Battle ชั่วคราวเพื่อ Heal ทันทีทันใด + เช็คเลือดเพิ่มจริง)
task.spawn(function()
    task.wait(1.5)
    while true do
        task.wait(CFG.HealDelay or 0.1)
        if not CFG.AutoHeal then
            State.healBusy = false
            State.isHealing = false
            State.healStatus = "OFF"
            continue
        end
        if State.healBusy or State.isHealing then continue end
        if not isInBattle() then
            State.isHealing = false
            State.healStatus = "Waiting for battle..."
            continue
        end
        
        local hpPct = getPetHpPercent(CFG.HealTargetPos)
        local uiCur, uiMax, _ = getUIBattlePetHp()
        local hpDisplay = (uiCur and uiMax) and string.format("%d/%d (%d%%)", uiCur, uiMax, hpPct) or string.format("%d%%", hpPct)
        
        if hpPct == -1 then
            if CFG.HealForceMode then
                State.isHealing = true
                State.healBusy = true
                State.healStatus = "HP Unknown -> STOPPING BATTLE TO FORCE HEAL..."
                
                -- หยุด AutoBattle ทันทีเพื่อเปิดโอกาสให้ใช้น้ำยาได้อย่างแม่นยำ
                if CFG.AutoBattle or isInBattle() then
                    forceSetAutoBattle(false)
                end
                
                local okCall, usedItem = pcall(executeHeal)
                if okCall and usedItem then
                    State.healStatus = "Force Healed (Item: " .. tostring(usedItem) .. ") @ " .. os.date("%X")
                else
                    State.healStatus = "Force Heal FAILED @ " .. os.date("%X")
                end
                
                task.wait(0.3)
                State.isHealing = false
                State.healBusy = false
                if CFG.AutoBattle and isInBattle() then
                    forceSetAutoBattle(true)
                end
            else
                State.healStatus = "HP: Unknown (Monitoring 0.1s...)"
            end
            continue
        end
        
        State.healStatus = string.format("HP: %s (threshold: %d%%)", hpDisplay, CFG.HealThreshold)
        if hpPct > CFG.HealThreshold then continue end
        
        -- ตรวจสอบซ้ำแบบรวดเร็ว (0.05 วินาที) ก่อนตัดสินใจกดใช้ยา
        task.wait(0.05)
        if not CFG.AutoHeal or not isInBattle() then continue end
        
        local hpPct2 = getPetHpPercent(CFG.HealTargetPos)
        local uiCur2, uiMax2, _ = getUIBattlePetHp()
        if hpPct2 ~= -1 and hpPct2 > CFG.HealThreshold then
            State.healStatus = string.format("HP: %s (OK)", (uiCur2 and uiMax2) and string.format("%d/%d (%d%%)", uiCur2, uiMax2, hpPct2) or string.format("%d%%", hpPct2))
            continue
        end
        
        -- [PRIORITY HEAL ROUTINE (ULTRA FAST 0.1s)] เลือดถึงหรือต่ำกว่าเกณฑ์ -> หยุด Battle ชั่วคราวเพื่อใช้ยา Heal ทันที!
        State.isHealing = true
        State.healBusy = true
        local beforeHpVal = uiCur2 or (hpPct2 ~= -1 and hpPct2 or 0)
        
        State.healStatus = string.format("HEALING! HP %s <= %d%% -> STOPPED BATTLE & USING POTION!", hpDisplay, CFG.HealThreshold)
        print("[AutoHeal] HP low (" .. tostring(hpPct2) .. "% <= " .. tostring(CFG.HealThreshold) .. "%) -> Stopping Battle to Heal immediately!")
        
        -- 1. หยุด Auto Battle ทันทีทันใด (Instant Stop Battle) เพื่อไม่ให้การโจมตีขัดจังหวะการใช้น้ำยา
        if CFG.AutoBattle or isInBattle() then
            forceSetAutoBattle(false)
        end
        
        -- 2. กดใช้น้ำยา Heal 1 ครั้งในเสี้ยววินาทีเดียวกัน!
        local okCall, usedItem = pcall(executeHeal)
        
        -- 3. [CHECK POTION USAGE BY HP INCREASE] รอเช็คเลือดเพิ่มขึ้นอย่างรวดเร็วทุก 0.05 วินาที (สูงสุด 1.0 วินาที)
        if okCall and usedItem then
            State.healStatus = string.format("Potion used! Waiting for HP increase...", usedItem)
            local hpIncreased = false
            local waitElapsed = 0
            
            while waitElapsed < 1.0 do
                task.wait(0.05)
                waitElapsed = waitElapsed + 0.05
                if not isInBattle() then break end
                
                -- ย้ำคำสั่งหยุด AutoBattle ระหว่างรอเลือดขึ้น เพื่อไม่ให้ตัวละครตีโต้ตอบ
                if CFG.AutoBattle then
                    forceSetAutoBattle(false)
                end
                
                local curCheck, maxCheck, _ = getUIBattlePetHp()
                local pctCheck = getPetHpPercent(CFG.HealTargetPos)
                
                -- เช็คว่าเลือดเพิ่มขึ้นจากเดิมแล้วหรือยัง (HP increased!)
                if (curCheck and beforeHpVal and curCheck > beforeHpVal) or (pctCheck ~= -1 and pctCheck > hpPct2) then
                    hpIncreased = true
                    local afterDisplay = (curCheck and maxCheck) and string.format("%d/%d (%d%%)", curCheck, maxCheck, pctCheck) or string.format("%d%%", pctCheck)
                    State.healStatus = string.format("✔ HP Increased! (%s -> %s) @ %s", hpDisplay, afterDisplay, os.date("%X"))
                    print("[AutoHeal] ✔ Verified HP increased in " .. string.format("%.2f", waitElapsed) .. "s! Potion saved.")
                    break
                end
            end
            
            if not hpIncreased then
                State.healStatus = string.format("⚠ Potion sent (Item %s) but HP delayed @ %s", tostring(usedItem), os.date("%X"))
                print("[AutoHeal] ⚠ Potion sent but HP unchanged within 1.0s.")
            end
        else
            State.healStatus = string.format("✖ Heal FAILED (HP %s) @ %s", hpDisplay, os.date("%X"))
            warn("[AutoHeal] executeHeal failed:", usedItem)
        end
        
        -- 4. เมื่อฮีลเสร็จสิ้น ปลดล็อคและเปิด Auto Battle คืนทันที
        task.wait(0.1)
        State.isHealing = false
        State.healBusy = false
        if CFG.AutoBattle and isInBattle() then
            print("[AutoHeal] Resuming combat -> Re-enabling AutoBattle!")
            forceSetAutoBattle(true)
        end
    end
end)

task.spawn(function()
    scanForAreas()
    local loopCount = 0
    while true do
        task.wait(CFG.TPCheckInterval)
        if not CFG.AutoTP then
            State.tpStatus = "OFF"
            continue
        end
        loopCount += 1
        if loopCount % 20 == 0 then scanForAreas() end
        local lvl = getPlayerLevel()
        State.currentLevel = lvl
        if lvl then
            local targetId = getAreaIdFromLevel(lvl)
            local targetName = AreaConfigs[targetId] or "???"
            if State.lastTPLevel ~= lvl then State.lastTPLevel = lvl end
            if State.lastTPAreaId ~= targetId then
                State.tpStatus = "TP -> " .. targetName
                if teleportToArea(targetId) then State.lastTPAreaId = targetId end
            else
                State.tpStatus = "OK: " .. targetName
            end
        else
            State.tpStatus = "No Level Data"
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.25)
        if not CFG.AutoNPC then
            State.npcStatus = "OFF"
            State.inNpcBattle = false
            task.wait(0.5)
            continue
        end
        if selectedNPC then
            State.npcStatus = "Running: " .. selectedNPC.name
            State.inNpcBattle = true
            executeNPCBattle(selectedNPC)
            State.inNpcBattle = false
        end
        local elapsed = 0
        while elapsed < CFG.NPCLoopDelay do
            if not CFG.AutoNPC then break end
            task.wait(0.25)
            elapsed += 0.25
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.25)
        if not CFG.AutoBoss then
            State.bossStatus = "OFF"
            if not CFG.AutoFastBoss then State.inBossBattle = false end
            task.wait(0.5)
            continue
        end
        if selectedBoss and selectedBoss.hasBattle then
            State.bossStatus = "Running: " .. selectedBoss.displayName
            State.inBossBattle = true
            local ok = enterBoss(selectedBoss)
            if ok and CFG.AutoBossAutoBattle and not State.isHealing then
                task.wait(0.5)
                if not State.isHealing then forceSetAutoBattle(true) end
            end
            State.inBossBattle = false
        else
            State.bossStatus = "Invalid Boss"
        end
        local elapsed = 0
        while elapsed < CFG.AutoBossDelay do
            if not CFG.AutoBoss then break end
            task.wait(0.25)
            elapsed += 0.25
        end
    end
end)

-- Auto Fast Boss Loop — เข้าสู้ Fast Boss โดยใช้ NPC 10000 คงที่ และปรับโลกตาม Target World (900000X)
task.spawn(function()
    while true do
        task.wait(0.25)
        if not CFG.AutoFastBoss or State.isHealing then
            if not CFG.AutoFastBoss then
                State.fastBossStatus = "OFF"
                if not CFG.AutoBoss then State.inBossBattle = false end
            end
            task.wait(0.5)
            continue
        end
        
        if not isInBattle() then
            local targetWorld = tonumber(CFG.FastBossTargetWorld) or 1
            
            State.fastBossStatus = string.format("Entering World %d (ID: %d)...", targetWorld, 9000000 + targetWorld)
            State.inBossBattle = true
            
            local ok, msg = enterFastBoss(targetWorld)
            if ok then
                State.fastBossStatus = string.format("Entered World %d @ %s", targetWorld, os.date("%X"))
                if CFG.AutoFastBossAutoBattle and not State.isHealing then
                    task.wait(0.5)
                    if not State.isHealing then forceSetAutoBattle(true) end
                end
                
                -- ถ้าเปิดแบบ Sequential และเข้าสู้สำเร็จ ให้เตรียมขยับไปโลกถัดไปหลังการต่อสู้เสร็จสิ้น
                if string.find(tostring(CFG.FastBossMode), "Sequential") then
                    task.delay(1.5, function()
                        if not State.isFighting and not isInBattle() and CFG.AutoFastBoss then
                            local nextW = (CFG.FastBossTargetWorld or 1) + 1
                            if nextW > 20 then nextW = 1 end
                            CFG.FastBossTargetWorld = nextW
                            pcall(function()
                                if _G.FastBossSliderRef then _G.FastBossSliderRef:SetValue(nextW) end
                            end)
                        end
                    end)
                end
            else
                State.fastBossStatus = "Failed: " .. tostring(msg)
                State.inBossBattle = false
            end
        else
            local targetWorld = tonumber(CFG.FastBossTargetWorld) or 1
            if State.isHealing then
                State.fastBossStatus = string.format("World %d — PAUSING FOR HEAL...", targetWorld)
            else
                State.fastBossStatus = string.format("Fighting World %d — waiting...", targetWorld)
            end
        end
        
        local elapsed = 0
        while elapsed < CFG.AutoFastBossDelay do
            if not CFG.AutoFastBoss then break end
            task.wait(0.25)
            elapsed += 0.25
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.25)
        if not CFG.AutoTower then
            State.towerStatus = "OFF"
            State.inTowerBattle = false
            task.wait(0.5)
            continue
        end
        if not ReqEnterTowerDungeonBattle then
            State.towerStatus = "Remote NOT FOUND"
            task.wait(2)
            continue
        end
        if not isInBattle() then
            State.towerStatus = "Entering tower..."
            State.inTowerBattle = true
            local ok, res = enterTowerBattle()
            if ok then
                State.towerStatus = "Entered tower @ " .. os.date("%X")
                if CFG.AutoTowerAutoBattle and not State.isHealing then
                    task.wait(0.5)
                    if not State.isHealing then forceSetAutoBattle(true) end
                end
            else
                State.towerStatus = "Enter failed: " .. tostring(res)
                State.inTowerBattle = false
            end
        else
            State.towerStatus = "In battle — waiting..."
        end
        local elapsed = 0
        while elapsed < CFG.AutoTowerDelay do
            if not CFG.AutoTower then break end
            task.wait(0.25)
            elapsed += 0.25
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(1)
        if not CFG.AutoTask then
            State.taskBusy = false
            State.taskStatus = "OFF"
            task.wait(2)
            continue
        end
        if State.taskBusy then
            task.wait(1)
            continue
        end
        local elapsed = os.clock() - State.taskLastRun
        if elapsed < CFG.TaskLoopInterval and State.taskLastRun > 0 then
            local remaining = math.ceil(CFG.TaskLoopInterval - elapsed)
            State.taskStatus = string.format("Next run in %ds (Last: R:%d C:%d)", remaining, State.taskReceived, State.taskClaimed)
            task.wait(1)
            continue
        end
        State.taskBusy = true
        resetTaskCache()
        local ok, err = pcall(function()
            executeAutoTasks()
        end)
        if not ok then
            warn("[AutoTask] Error:", err)
            State.taskStatus = "Error: " .. tostring(err)
        end
        State.taskBusy = false
    end
end)

task.spawn(function()
    State.petMgrRunning = false
    State.petMgrStop = false
    while true do
        task.wait(0.5)
        if not CFG.PetMgrEnabled then
            State.petMgrStatus = "OFF"
            State.petMgrRunning = false
            State.petMgrStop = true
            task.wait(1)
            continue
        end
        State.petMgrStop = false
        State.petMgrRunning = true
        local now = os.clock()
        local elapsed = now - State.petMgrLastScan
        if elapsed < CFG.PetMgrScanInterval then
            local remain = math.ceil(CFG.PetMgrScanInterval - elapsed)
            State.petMgrStatus = string.format("Next scan in %ds (Cycle %d)", remain, State.petMgrCycle)
            task.wait(0.5)
            continue
        end
        local ok, err = pcall(petMgrScanOnce)
        if not ok then
            State.petMgrStatus = "Error: " .. tostring(err)
            warn("[PetMgr]", err)
        end
    end
end)

task.spawn(function()
    task.wait(2)
    while true do
        task.wait(CFG.ElemAdvScanDelay or 0.75)
        repeat
            if not CFG.ElemAdvEnabled then
                State.elemAdvStatus = "OFF"
                State.elemAdvBusy = false
                State.elemAdvEnemyName = "—"
                State.elemAdvEnemyElements = ""
                State.elemAdvBestPet = "—"
                State.elemAdvBestRate = 0
                State.elemAdvCandidates = 0
                State.elemAdvLockedUid = nil
                State.elemAdvLockedName = "—"
                break
            end
            if not isInBattle() then
                State.elemAdvStatus = "Waiting for battle..."
                State.elemAdvEnemyName = "—"
                State.elemAdvBestPet = "—"
                State.elemAdvBestRate = 0
                State.elemAdvCandidates = 0
                State.elemAdvLockedUid = nil
                State.elemAdvLockedName = "—"
                break
            end
            if State.isHealing then
                State.elemAdvStatus = "Pausing for Auto Heal..."
                break
            end
            local scanOk, battleData, enemyPet, enemyName, enemyElements, rows = pcall(buildElemCandidates)
            if not scanOk then
                State.elemAdvStatus = "Scan error"
                break
            end
            if typeof(rows) ~= "table" then
                State.elemAdvStatus = "No data"
                break
            end
            State.elemAdvEnemyName = enemyName or "—"
            State.elemAdvEnemyElements = elementListToText(enemyElements)
            State.elemAdvCandidates = #rows
            if #rows > 0 then
                State.elemAdvBestPet = rows[1].name or "?"
                State.elemAdvBestRate = rows[1].advantageRate or 0
                State.elemAdvStatus = string.format("Best: %s [%.2fx] | %d found", rows[1].name or "?", rows[1].advantageRate or 0, #rows)
            else
                State.elemAdvBestPet = "None"
                State.elemAdvBestRate = 0
                State.elemAdvStatus = "No advantage >= " .. tostring(CFG.ElemAdvMinRate) .. "x"
            end
            if CFG.ElemAdvAutoSwitch and not State.elemAdvBusy and not State.isHealing and #rows > 0 then
                local activePet = getActiveTeamPet(battleData)
                local activeUid = getElemPetBattleUid(activePet)
                local activeDead = isElemPetDead(activePet)
                local aliveTeamRows = getAliveTeamAdvRows(rows)
                local bestOverall = aliveTeamRows[1]
                local bestBench = nil
                for _, p in ipairs(aliveTeamRows) do
                    if not p.isInField then
                        bestBench = p
                        break
                    end
                end
                local lockedUid = State.elemAdvLockedUid
                local lockedIsCurrentActive =
                    typeof(lockedUid) == "string" and lockedUid ~= ""
                    and activeUid ~= ""
                    and lockedUid == activeUid
                    and activePet ~= nil
                    and not activeDead
                if lockedIsCurrentActive then
                    State.elemAdvLockedName = activePet.name or "?"
                    State.elemAdvStatus = string.format(
                        "LOCKED: %s (HP %s%%) — play till dead | %d adv found",
                        activePet.name or "?",
                        (typeof(activePet.hpPercent) == "number" and activePet.hpPercent >= 0) and tostring(activePet.hpPercent) or "?",
                        #rows
                    )
                else
                    if lockedUid ~= nil then
                        State.elemAdvLockedUid = nil
                        State.elemAdvLockedName = "—"
                    end
                    if not bestOverall then
                        if activePet then
                            State.elemAdvStatus = string.format(
                                "No switchable advantage | Active: %s (HP %s%%)",
                                activePet.name or "?",
                                (typeof(activePet.hpPercent) == "number" and activePet.hpPercent >= 0) and tostring(activePet.hpPercent) or "?"
                            )
                        else
                            State.elemAdvStatus = "No switchable advantage"
                        end
                    else
                        local bestOverallUid = getElemPetBattleUid(bestOverall)
                        if activePet and not activeDead and activeUid ~= "" and activeUid == bestOverallUid then
                            State.elemAdvLockedUid = activeUid
                            State.elemAdvLockedName = activePet.name or "?"
                            State.elemAdvStatus = string.format(
                                "LOCK CURRENT BEST: %s [%.2fx] (play till dead)",
                                activePet.name or "?",
                                bestOverall.advantageRate or 0
                            )
                        else
                            local switchTarget = bestBench
                            if switchTarget and not switchTarget.isInField then
                                State.elemAdvBusy = true
                                State.elemAdvStatus = "Switching to " .. (switchTarget.name or "?") .. "..."
                                local switchOk, switchResult = elemSwitchPet(switchTarget)
                                if switchOk then
                                    State.elemAdvLockedUid = getElemPetBattleUid(switchTarget)
                                    State.elemAdvLockedName = switchTarget.name or "?"
                                    State.elemAdvStatus = string.format(
                                        "Switched → LOCK: %s [%.2fx] (play till dead)",
                                        switchTarget.name or "?",
                                        switchTarget.advantageRate or 0
                                    )
                                else
                                    State.elemAdvStatus = "Switch failed: " .. tostring(switchResult)
                                end
                                task.delay(3, function()
                                    State.elemAdvBusy = false
                                end)
                            else
                                if activePet then
                                    local activeRow = findElemRowByUid(rows, activeUid)
                                    State.elemAdvLockedUid = (activeUid ~= "" and activeUid) or nil
                                    State.elemAdvLockedName = activePet.name or "?"
                                    State.elemAdvStatus = string.format(
                                        "LOCK ACTIVE: %s%s",
                                        activePet.name or "?",
                                        activeRow and string.format(" [%.2fx] (play till dead)", activeRow.advantageRate or 0) or " (play till dead)"
                                    )
                                end
                            end
                        end
                    end
                end
            end
        until true
    end
end)

print("[Delta X — Evomon v3.6] Building GUI...")

-- ────────────────────────────────────────────────────────────────────
-- SECTION 20 : FLUENT UI
-- ────────────────────────────────────────────────────────────────────
local function addCfgToggle(tab, key, title, desc, stateReset, onChangeFn)
    tab:AddToggle(key, {
        Title = title,
        Description = desc,
        Default = false,
    }):OnChanged(function()
        CFG[key] = Fluent.Options[key].Value
        if stateReset and not CFG[key] then
            State[stateReset] = false
        end
        if onChangeFn then onChangeFn(CFG[key]) end
    end)
end

local function addCfgSlider(tab, key, title, desc, default, min, max, multiplier)
    multiplier = multiplier or 1
    tab:AddSlider(key, {
        Title = title,
        Description = desc,
        Default = default,
        Min = min,
        Max = max,
        Rounding = 0,
        Callback = function(v)
            CFG[key] = v * multiplier
        end,
    })
end

local function addSliderGroup(tab, defs)
    for _, d in ipairs(defs) do
        addCfgSlider(tab, d[1], d[2], d[3], d[4], d[5], d[6], d[7])
    end
end

local LevelMapString = (function()
    local lines, sorted = {}, {}
    for lvl in pairs(LevelToAreaMap) do sorted[#sorted + 1] = lvl end
    table.sort(sorted)
    for _, lvl in ipairs(sorted) do
        lines[#lines + 1] = string.format("Lv.%d+  ->  %s", lvl, AreaConfigs[LevelToAreaMap[lvl]] or "???")
    end
    return table.concat(lines, "\n")
end)()

local Window = Fluent:CreateWindow({
    Title = "Delta X — Evomon v3.6",
    SubTitle = "Auto Farm Suite (Merged Fix)",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 480),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl,
})

local Tabs = {
    Farm     = Window:AddTab({ Title = "Farm", Icon = "swords" }),
    Teleport = Window:AddTab({ Title = "Teleport", Icon = "map-pin" }),
    Pet      = Window:AddTab({ Title = "Pet Team", Icon = "star" }),
    Combat   = Window:AddTab({ Title = "Combat", Icon = "zap" }),
    Misc     = Window:AddTab({ Title = "Misc", Icon = "shield" }),
    PetMgr   = Window:AddTab({ Title = "Pet Mgr", Icon = "shield-check" }),
    Element  = Window:AddTab({ Title = "Pet Element", Icon = "flame" }),
    Timing   = Window:AddTab({ Title = "Timing", Icon = "sliders-horizontal" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" }),
}

-- Tab Farm
do
    local T = Tabs.Farm
    local PStatus = T:AddParagraph({ Title = "Status", Content = "Loading..." })
    task.spawn(function()
        while true do
            task.wait(0.8)
            local lvl = State.currentLevel or getPlayerLevel()
            local areaId = lvl and getAreaIdFromLevel(lvl) or nil
            local areaName = areaId and AreaConfigs[areaId] or "—"
            local battleMode
            if State.inBossBattle and CFG.AutoFastBoss then
                battleMode = "FAST BOSS BATTLE"
            elseif State.inBossBattle and CFG.AutoBoss then
                battleMode = "BOSS BATTLE"
            elseif State.inNpcBattle and CFG.AutoNPC then
                battleMode = "NPC BATTLE"
            elseif State.isFighting then
                battleMode = "FIGHTING"
            elseif CFG.AutoBattle and BattleService then
                local ok, cur = pcall(BattleService.getCurrentBattle)
                battleMode = (ok and cur) and "AUTO BATTLE" or "IDLE"
            elseif State.enterCooldown then
                battleMode = "ENTERING..."
            else
                battleMode = "IDLE"
            end
            local catchWinOpen = isCatchWindowOpen()
            local tgts = getTargetUids()
            local tgtStr = tgts[1] and (tgts[1] .. " (" .. #tgts .. " nearby)") or "None"
            local active = {}
            if CFG.AutoBattle then active[#active + 1] = "Battle" end
            if CFG.AutoEnterBattle then active[#active + 1] = "Enter" end
            if CFG.AutoCatch then active[#active + 1] = "Catch" end
            if CFG.AutoEscape then active[#active + 1] = "Escape" end
            if CFG.AutoHeal then active[#active + 1] = "Heal" end
            if CFG.AutoChest then active[#active + 1] = "Chest" end
            if CFG.AutoTP then active[#active + 1] = "TP" end
            if CFG.AutoFastBoss then active[#active + 1] = "FastBoss" end
            if CFG.AutoBoss then active[#active + 1] = "Boss" end
            if CFG.AutoNPC then active[#active + 1] = "NPC" end
            if CFG.AutoTower then active[#active + 1] = "Tower" end
            if CFG.AntiAFK then active[#active + 1] = "AFK" end
            if CFG.AutoTask then active[#active + 1] = "Task" end
            if CFG.ElemAdvEnabled then active[#active + 1] = "Element" end
            
            local bossDisplayStr = "—"
            if CFG.AutoFastBoss then
                bossDisplayStr = "Fast (W" .. tostring(CFG.FastBossTargetWorld or 1) .. ")"
            elseif State.bossStatus and State.bossStatus ~= "OFF" then
                bossDisplayStr = State.bossStatus
            end

            PStatus:SetDesc(
                "Lv." .. (lvl or "?") .. "  |  Area: " .. areaName ..
                "\nBattle Mode: " .. battleMode ..
                "\nCatch Window: " .. (catchWinOpen and "Open" or "Closed") ..
                "  |  Target: " .. tgtStr ..
                "\nTP: " .. (State.tpStatus or "—") ..
                "  |  Boss: " .. bossDisplayStr ..
                "  |  NPC: " .. (State.npcStatus or "—") ..
                "\nAFK: " .. (State.afkStatus or "OFF") ..
                "  |  Heal: " .. (State.healStatus or "OFF") ..
                "\nTask: " .. (State.taskStatus or "OFF") ..
                "\nElement: " .. (State.elemAdvStatus or "OFF") ..
                "\nActive: " .. (#active > 0 and table.concat(active, ", ") or "None")
            )
        end
    end)
    addCfgToggle(T, "AutoBattle", "Auto Battle", "BattleService auto-fight (auto-resync every 2s)", nil, function(on)
        forceSetAutoBattle(on)
    end)
    addCfgToggle(T, "AutoEnterBattle", "Auto Enter Battle", "Engage nearest monster", "enterCooldown")
    addCfgToggle(T, "AutoCatch", "Auto Catch", "Throw ball — requires CatchWindow open + in battle", "catchBusy")
    T:AddInput("BallItemId", {
        Title = "Ball Item ID",
        Default = tostring(CFG.BallItemId),
        Placeholder = "2000015",
        Numeric = true,
        Finished = true,
        Callback = function(v)
            local n = tonumber(v)
            if n then CFG.BallItemId = n end
        end,
    })
    T:AddParagraph({
        Title = "─── Auto Heal ───",
        Content = "ใช้ยารักษาอัตโนมัติเมื่อ HP ต่ำกว่า threshold",
    })
    addCfgToggle(T, "AutoHeal", "Auto Heal", "ใช้ไอเทม HP อัตโนมัติเมื่ออยู่ใน battle (หยุด AutoBattle ขณะ Heal + เช็คเลือดเพิ่มจริง)", "healBusy")
    T:AddToggle("HealForceMode", {
        Title = "Force Heal (Blind Mode)",
        Description = "Heal ทุก cycle แม้ดึงค่า HP ไม่ได้",
        Default = false,
    }):OnChanged(function()
        CFG.HealForceMode = Fluent.Options["HealForceMode"].Value
    end)
    T:AddSlider("HealThreshold", {
        Title = "Heal Threshold (%)",
        Description = "รักษาเมื่อ HP ต่ำกว่าค่านี้",
        Default = 50,
        Min = 10,
        Max = 90,
        Rounding = 0,
        Callback = function(v)
            CFG.HealThreshold = v
        end,
    })
    T:AddDropdown("HealItemSelect", {
        Title = "Heal Item Priority",
        Description = "ไอเทมที่ใช้รักษาก่อน (ลำดับแรก)",
        Values = {
            "2000001 (Small HP)",
            "2000002 (Medium HP)",
            "2000003 (Large HP)",
        },
        Default = 1,
        Multi = false,
        Callback = function(v)
            local idMap = {
                ["2000001 (Small HP)"] = {2000001, 2000002, 2000003},
                ["2000002 (Medium HP)"] = {2000002, 2000001, 2000003},
                ["2000003 (Large HP)"] = {2000003, 2000002, 2000001},
            }
            CFG.HealItemPriority = idMap[v] or {2000001, 2000002, 2000003}
        end,
    })
    T:AddSlider("HealTargetPos", {
        Title = "Heal Target Slot",
        Description = "ตำแหน่ง pet ใน team ที่จะรักษา (1-5)",
        Default = 1,
        Min = 1,
        Max = 5,
        Rounding = 0,
        Callback = function(v)
            CFG.HealTargetPos = v
            CFG.HealSourcePos = v
        end,
    })
    T:AddButton({
        Title = "Test Heal Now",
        Description = "ทดสอบ heal 1 ครั้ง (ต้องอยู่ใน battle)",
        Callback = function()
            task.spawn(function()
                if not isInBattle() then
                    Fluent:Notify({ Title = "Auto Heal", Content = "ต้องอยู่ใน battle ก่อน!", Duration = 3 })
                    return
                end
                local hpBefore = getPetHpPercent(CFG.HealTargetPos)
                local uiCur, uiMax, _ = getUIBattlePetHp()
                local hpBeforeStr = (uiCur and uiMax) and string.format("%d/%d (%d%%)", uiCur, uiMax, hpBefore) or (hpBefore == -1 and "??" or string.format("%d%%", hpBefore))
                local activeUid = getFightingPetBattleUid(CFG.HealTargetPos)
                Fluent:Notify({
                    Title = "Testing Heal",
                    Content = string.format("HP: %s | UID: %s | Item: %d", hpBeforeStr, activeUid ~= "" and activeUid or "none", selectHealItem()),
                    Duration = 3,
                })
                local ok = executeHeal()
                task.wait(1)
                local hpAfter = getPetHpPercent(CFG.HealTargetPos)
                local afterCur, afterMax, _ = getUIBattlePetHp()
                local hpAfterStr = (afterCur and afterMax) and string.format("%d/%d (%d%%)", afterCur, afterMax, hpAfter) or (hpAfter == -1 and "??" or string.format("%d%%", hpAfter))
                Fluent:Notify({
                    Title = ok and "Heal Sent!" or "Heal Failed",
                    Content = string.format(
                        "UID: %s | Item: %d\nBefore: %s -> After: %s",
                        activeUid ~= "" and activeUid or "none",
                        selectHealItem(),
                        hpBeforeStr,
                        hpAfterStr
                    ),
                    Duration = 5,
                })
            end)
        end,
    })
    T:AddButton({
        Title = "Scan Heal Remotes",
        Description = "แสดง Remote และ Battle UID ของ Pet ใน Output",
        Callback = function()
            task.spawn(function()
                scanHealRemotes()
                local hpPct = getPetHpPercent(CFG.HealTargetPos)
                local uiCur, uiMax, _ = getUIBattlePetHp()
                local hpStr = (uiCur and uiMax) and string.format("%d/%d (%d%%)", uiCur, uiMax, hpPct) or (hpPct == -1 and "Unknown" or string.format("%d%%", hpPct))
                local activeUid = getFightingPetBattleUid(CFG.HealTargetPos)
                local info = string.format(
                    "Remotes: %d candidates\nHP: %s\nFighting Pet UID: %s\nSee Output (F9) for full details",
                    #HealRemoteCandidates,
                    hpStr,
                    activeUid ~= "" and activeUid or "nil"
                )
                Fluent:Notify({ Title = "Heal Remote Scan", Content = info, Duration = 6 })
                print("[AutoHeal] Current Fighting Pet Battle UID:", activeUid)
            end)
        end,
    })
    addCfgToggle(T, "AutoEscape", "Auto Escape", "Flee — requires CatchWindow open + in battle", "escapeBusy")
    addCfgToggle(T, "AutoChest", "Auto Collect Chest", "Claim chests automatically", "chestBusy")
end

-- Tab Teleport
do
    local T = Tabs.Teleport
    addCfgToggle(T, "AutoTP", "Auto TP by Level", "Teleport to level-appropriate area")
    local selectedArea = AreaNameList[1] or ""
    T:AddDropdown("ManualTPArea", {
        Title = "Manual TP Area",
        Values = AreaNameList,
        Default = 1,
        Multi = false,
        Callback = function(v)
            selectedArea = v
        end,
    })
    T:AddButton({
        Title = "Teleport Now",
        Callback = function()
            if not selectedArea or selectedArea == "" then return end
            Fluent:Notify({ Title = "Teleporting", Content = selectedArea, Duration = 2 })
            task.spawn(function()
                local ok = manualTeleport(selectedArea)
                Fluent:Notify({ Title = ok and "TP Success" or "TP Failed", Content = selectedArea, Duration = 3 })
            end)
        end,
    })
    T:AddParagraph({ Title = "─── Auto Task ───", Content = "รับและเคลม Task อัตโนมัติ" })
    addCfgToggle(T, "AutoTask", "Auto Task", "วน Receive + Claim task อัตโนมัติ ทุก X วินาที", "taskBusy")
    T:AddToggle("TaskAutoReceive", {
        Title = "Auto Receive",
        Description = "รับ task ใหม่อัตโนมัติ",
        Default = true,
    }):OnChanged(function()
        CFG.TaskAutoReceive = Fluent.Options["TaskAutoReceive"].Value
    end)
    T:AddToggle("TaskAutoClaim", {
        Title = "Auto Claim",
        Description = "เคลม task ที่เสร็จแล้วอัตโนมัติ",
        Default = true,
    }):OnChanged(function()
        CFG.TaskAutoClaim = Fluent.Options["TaskAutoClaim"].Value
    end)
    T:AddButton({
        Title = "Run Tasks Now",
        Description = "Receive + Claim ทันที (ไม่ต้องรอ timer)",
        Callback = function()
            task.spawn(function()
                if State.taskBusy then
                    Fluent:Notify({ Title = "Task System", Content = "กำลังทำงานอยู่ รอสักครู่", Duration = 2 })
                    return
                end
                State.taskBusy = true
                resetTaskCache()
                Fluent:Notify({ Title = "Auto Task", Content = "กำลัง Receive + Claim...", Duration = 2 })
                local ok, err = pcall(function()
                    executeAutoTasks()
                end)
                State.taskBusy = false
                if ok then
                    Fluent:Notify({
                        Title = "Auto Task Complete",
                        Content = string.format("Received: %d, Claimed: %d", State.taskReceived, State.taskClaimed),
                        Duration = 4,
                    })
                else
                    Fluent:Notify({ Title = "Auto Task Error", Content = tostring(err), Duration = 4 })
                end
            end)
        end,
    })
    T:AddButton({
        Title = "View Task IDs",
        Description = "แสดงรายการ Task ID ที่จะรับ/เคลม",
        Callback = function()
            local lines = {"=== Auto Task ID List ==="}
            for i, id in ipairs(AUTO_TASK_IDS) do
                local recvStatus = _taskReceiveCache[id] and "✓ Received" or "— Pending"
                local claimStatus = _taskClaimCache[id] and "✓ Claimed" or "— Pending"
                table.insert(lines, string.format("#%d  ID:%d  [%s] [%s]", i, id, recvStatus, claimStatus))
            end
            local extras = scanExtraTaskIds()
            if #extras > 0 then
                table.insert(lines, "\n=== Extra Tasks Found ===")
                for _, id in ipairs(extras) do
                    table.insert(lines, string.format("  Extra ID: %d", id))
                end
            end
            Fluent:Notify({ Title = "Task IDs", Content = table.concat(lines, "\n"), Duration = 8 })
            for _, line in ipairs(lines) do print("[AutoTask]", line) end
        end,
    })
    T:AddButton({
        Title = "Rescan Map",
        Callback = function()
            task.spawn(function()
                scanForAreas()
                local count = 0
                for _ in pairs(AreaCache) do count += 1 end
                Fluent:Notify({ Title = "Scan Complete", Content = count .. " areas found", Duration = 3 })
            end)
        end,
    })
    T:AddParagraph({ Title = "Level -> Area Map", Content = LevelMapString })
end

-- Tab Pet
do
    local T = Tabs.Pet
    local PResultPot = T:AddParagraph({ Title = "Top 5 Potential", Content = "Press Scan to view" })
    local PResultPow = T:AddParagraph({ Title = "Top 5 Power", Content = "Press Scan to view" })
    T:AddButton({
        Title = "Scan Pets",
        Callback = function()
            task.spawn(function()
                Fluent:Notify({ Title = "Scanning", Content = "Analyzing pets...", Duration = 2 })
                local potPets, potErr = scanAndRankPets("potential")
                PResultPot:SetDesc(potPets and table.concat(formatPetLines(potPets, "potential"), "\n") or ("Error: " .. (potErr or "unknown")))
                local powPets, powErr = scanAndRankPets("power")
                PResultPow:SetDesc(powPets and table.concat(formatPetLines(powPets, "power"), "\n") or ("Error: " .. (powErr or "unknown")))
                Fluent:Notify({ Title = "Scan Complete", Content = (potPets and #potPets or 0) .. " pets analyzed", Duration = 3 })
            end)
        end,
    })
    local function addSetTeamButton(tab, mode, label)
        tab:AddButton({
            Title = "Set Team: " .. label,
            Callback = function()
                task.spawn(function()
                    local allPets, err = scanAndRankPets(mode)
                    if not allPets then
                        Fluent:Notify({ Title = "Error", Content = err or "Scan failed", Duration = 4 })
                        return
                    end
                    local top5 = {}
                    for i = 1, math.min(5, #allPets) do top5[i] = allPets[i].uuid end
                    local ok, result = setTeam(top5)
                    local target = mode == "potential" and PResultPot or PResultPow
                    target:SetDesc(table.concat(formatPetLines(allPets, mode), "\n"))
                    local names = {}
                    for i = 1, math.min(5, #allPets) do names[i] = allPets[i].name end
                    Fluent:Notify({ Title = ok and "Team Set!" or "Failed", Content = ok and table.concat(names, ", ") or result, Duration = 4 })
                end)
            end,
        })
    end
    addSetTeamButton(T, "potential", "Top 5 Potential")
    addSetTeamButton(T, "power", "Top 5 Power")
end

-- Tab Combat (MODIFIED WITH TARGET WORLD ONLY & INSTANT AUTO-SCANNED BOSS DROPDOWN)
do
    local T = Tabs.Combat
    
    -- Auto Fast Boss Section (ยึด Target World เป็นหลักตัวเดียว ลบ Start / Max ออก)
    T:AddParagraph({ Title = "─── Auto Fast Boss ───", Content = "ตีบอสแบบรวดเร็วโดยส่ง NPC 10000 คงที่ เลื่อนซ้าย-ขวาเลือกโลกได้อิสระ (900000X)" })
    
    local PFastBossStatus = T:AddParagraph({ Title = "Fast Boss Status", Content = "Waiting..." })
    task.spawn(function()
        while true do
            task.wait(0.8)
            pcall(function()
                local curW = tonumber(CFG.FastBossTargetWorld) or 1
                PFastBossStatus:SetDesc(
                    "Status: " .. tostring(State.fastBossStatus or "OFF") ..
                    "\nMode: " .. tostring(CFG.FastBossMode) ..
                    "\nCurrent Target: World " .. curW .. " (Battle ID: " .. (9000000 + curW) .. ")"
                )
            end)
        end
    end)

    addCfgToggle(T, "AutoFastBoss", "Auto Fast Boss Loop", "วนเข้าสู้ Fast Boss อัตโนมัติ (NPC = 10000 คงที่)")
    addCfgToggle(T, "AutoFastBossAutoBattle", "Server Auto Battle (Fast Boss)", "เปิด Auto Battle ของเซิร์ฟเวอร์เมื่อเข้า Fast Boss")

    T:AddDropdown("FastBossModeSelect", {
        Title = "Fast Boss Mode",
        Description = "เลือกลักษณะการตีบอส",
        Values = {
            "Manual / Single World (สไลด์เลือกโลกอิสระ)",
            "Sequential Loop (วนลูปขึ้นทีละโลกจาก Target World)",
        },
        Default = 1,
        Multi = false,
        Callback = function(v)
            CFG.FastBossMode = v
        end,
    })

    -- ตัวเลื่อนเลือกโลกเป้าหมายหลักตัวเดียว ยึดตามคำสั่งผู้เล่น (Target World)
    local FastBossSlider = T:AddSlider("FastBossTargetWorld", {
        Title = "🎯 Target World (เลื่อนซ้าย-ขวาเลือกโลกได้อิสระ)",
        Description = "เลื่อนไปซ้าย-ขวาเพื่อเปลี่ยนโลก Fast Boss ทันที (World 1 - 20)",
        Default = 1,
        Min = 1,
        Max = 20,
        Rounding = 0,
        Callback = function(v)
            CFG.FastBossTargetWorld = v
        end,
    })
    _G.FastBossSliderRef = FastBossSlider

    -- ปุ่มเลื่อนซ้าย-ขวาเพื่อเปลี่ยนโลกทีละ 1 สเต็ปทันที
    T:AddButton({
        Title = "◀ เลื่อนโลกไปทางซ้าย (Previous World -1)",
        Description = "ลดระดับโลกบอสลง 1 ลำดับทันที",
        Callback = function()
            local cur = (tonumber(CFG.FastBossTargetWorld) or 1) - 1
            if cur < 1 then cur = 20 end
            CFG.FastBossTargetWorld = cur
            pcall(function() FastBossSlider:SetValue(cur) end)
            Fluent:Notify({ Title = "Fast Boss", Content = "เลื่อนไปซ้าย ➔ World " .. cur .. " (ID: " .. (9000000 + cur) .. ")", Duration = 2 })
        end,
    })

    T:AddButton({
        Title = "เลื่อนโลกไปทางขวา (Next World +1) ▶",
        Description = "เพิ่มระดับโลกบอสขึ้น 1 ลำดับทันที",
        Callback = function()
            local cur = (tonumber(CFG.FastBossTargetWorld) or 1) + 1
            if cur > 20 then cur = 1 end
            CFG.FastBossTargetWorld = cur
            pcall(function() FastBossSlider:SetValue(cur) end)
            Fluent:Notify({ Title = "Fast Boss", Content = "เลื่อนไปขวา ➔ World " .. cur .. " (ID: " .. (9000000 + cur) .. ")", Duration = 2 })
        end,
    })

    T:AddSlider("AutoFastBossDelay", {
        Title = "Fast Boss Loop Delay (sec)",
        Description = "หน่วงเวลาระหว่างการเข้าตี Fast Boss Each ครั้ง",
        Default = 5,
        Min = 1,
        Max = 30,
        Rounding = 0,
        Callback = function(v)
            CFG.AutoFastBossDelay = v
        end,
    })

    T:AddButton({
        Title = "🚀 Enter Fast Boss Now",
        Description = "กดเข้าสู้ Fast Boss โลกเป้าหมายปัจจุบันทันที 1 ครั้ง",
        Callback = function()
            task.spawn(function()
                local targetWorld = tonumber(CFG.FastBossTargetWorld) or 1
                Fluent:Notify({ Title = "Fast Boss", Content = string.format("Entering World %d (ID: %d)...", targetWorld, 9000000 + targetWorld), Duration = 2 })
                local ok, msg = enterFastBoss(targetWorld)
                if ok and CFG.AutoFastBossAutoBattle and not State.isHealing then
                    task.wait(0.5)
                    if not State.isHealing then forceSetAutoBattle(true) end
                end
                Fluent:Notify({ Title = ok and "Fast Boss Entered" or "Failed", Content = tostring(msg), Duration = 4 })
            end)
        end,
    })

    T:AddParagraph({ Title = "─── Standard Auto Boss & NPC ───", Content = "ระบบตีบอสและ NPC ปกติตามตาราง (สแกนอัตโนมัติแล้ว)" })

    local PBossInfo = T:AddParagraph({ Title = "Boss Info", Content = string.format("Total Bosses Found: %d", #BOSS_LIST) })
    local BossDropdown = T:AddDropdown("BossSelect", {
        Title = "Select Boss (สแกนทันทีเรียบร้อย)",
        Values = BOSS_NAMES,
        Default = 1,
        Multi = false,
        Callback = function(v)
            for _, b in ipairs(BOSS_LIST) do
                if b.name == v then
                    selectedBoss = b
                    PBossInfo:SetDesc(string.format(
                        "Total: %d | Selected: %s\nNPC ID: %d | Battle ID: %d (%s) | Status: %s",
                        #BOSS_LIST, b.displayName, b.npcId, b.battleId, b.battleSource, b.status
                    ))
                    break
                end
            end
        end,
    })
    _G.BossDropdownRef = BossDropdown

    addCfgToggle(T, "AutoBoss", "Auto Boss Loop", "Repeatedly enter boss battle (sets inBossBattle flag for Catch/Escape)")
    addCfgToggle(T, "AutoBossAutoBattle", "Server Auto Battle (Boss)", "Enable server-side auto battle during boss")
    T:AddButton({
        Title = "Enter Boss Now",
        Callback = function()
            task.spawn(function()
                if not selectedBoss or not selectedBoss.hasBattle then
                    Fluent:Notify({ Title = "Cannot Enter", Content = "Selected boss has no valid battleId", Duration = 4 })
                    return
                end
                Fluent:Notify({ Title = "Entering Boss", Content = string.format("%s (battle %d)", selectedBoss.displayName, selectedBoss.battleId), Duration = 2 })
                enterBoss(selectedBoss)
            end)
        end,
    })
    T:AddDropdown("NPCSelect", {
        Title = "Select NPC",
        Values = NPC_NAMES,
        Default = 1,
        Multi = false,
        Callback = function(v)
            for _, n in ipairs(NPC_LIST) do
                if n.name == v then
                    selectedNPC = n
                    break
                end
            end
        end,
    })
    addCfgToggle(T, "AutoNPC", "Auto NPC Loop", "Repeatedly battle NPC (sets inNpcBattle flag for Catch/Escape)")
    T:AddButton({
        Title = "Battle NPC Now",
        Callback = function()
            task.spawn(function()
                if not selectedNPC then return end
                Fluent:Notify({ Title = "Battling NPC", Content = selectedNPC.name, Duration = 2 })
                executeNPCBattle(selectedNPC)
            end)
        end,
    })
    T:AddParagraph({ Title = "─── Auto Tower ───", Content = "เข้า Tower Dungeon Battle อัตโนมัติ (วนซ้ำ)" })
    local PTowerInfo = T:AddParagraph({ Title = "Tower Status", Content = ReqEnterTowerDungeonBattle and "Remote: OK" or "Remote: NOT FOUND" })
    task.spawn(function()
        while true do
            task.wait(1)
            pcall(function()
                PTowerInfo:SetDesc(
                    "Remote: " .. (ReqEnterTowerDungeonBattle and "OK" or "NOT FOUND") ..
                    "\nStatus: " .. (State.towerStatus or "OFF")
                )
            end)
        end
    end)
    addCfgToggle(T, "AutoTower", "Auto Tower Loop", "วนเข้า Tower Dungeon Battle อัตโนมัติทุก X วินาที")
    addCfgToggle(T, "AutoTowerAutoBattle", "Server Auto Battle (Tower)", "เปิด server auto-battle ตอนเข้า tower")
    T:AddSlider("AutoTowerDelay", {
        Title = "Tower Loop Delay (sec)",
        Description = "หน่วงระหว่างการ enter tower Each ครั้ง",
        Default = 5,
        Min = 1,
        Max = 30,
        Rounding = 0,
        Callback = function(v)
            CFG.AutoTowerDelay = v
        end,
    })
    T:AddButton({
        Title = "Enter Tower Now",
        Callback = function()
            task.spawn(function()
                if not ReqEnterTowerDungeonBattle then
                    Fluent:Notify({ Title = "Auto Tower", Content = "Remote ReqEnterTowerDungeonBattle ไม่พบ", Duration = 4 })
                    return
                end
                Fluent:Notify({ Title = "Auto Tower", Content = "Entering tower...", Duration = 2 })
                local ok, res = enterTowerBattle()
                if ok and CFG.AutoTowerAutoBattle then
                    task.wait(0.5)
                    forceSetAutoBattle(true)
                end
                Fluent:Notify({ Title = ok and "Tower Entered" or "Tower Failed", Content = tostring(res), Duration = 4 })
            end)
        end,
    })
end

-- Tab Misc
do
    local T = Tabs.Misc
    T:AddParagraph({
        Title = "Anti-AFK System",
        Content = "Prevent Roblox from kicking you due to inactivity.\nWhen enabled, the script auto-clicks the screen when idle detection triggers.",
    })
    addCfgToggle(T, "AntiAFK", "Anti-AFK Enabled", "Bypass 20-minute idle kick", nil, function(on)
        if on then
            setupAntiAFK()
            State.afkStatus = "ACTIVE"
            Fluent:Notify({ Title = "Anti-AFK Enabled", Content = "You won't be kicked for idle", Duration = 3 })
        else
            teardownAntiAFK()
            Fluent:Notify({ Title = "Anti-AFK Disabled", Content = "Standard idle kick active", Duration = 3 })
        end
    end)
end

-- Tab PetMgr
do
    local T = Tabs.PetMgr
    local PMStatus = T:AddParagraph({ Title = "Pet Manager Status", Content = "Waiting..." })
    task.spawn(function()
        while true do
            task.wait(1)
            local modStatus = ""
            if not PetServiceModule then modStatus = " ⚠ PetService: NOT LOADED" end
            if not PetGroupStorageMod then modStatus = modStatus .. " ⚠ PetGroupStorage: NOT LOADED" end
            PMStatus:SetDesc(
                "Status: " .. (State.petMgrStatus or "OFF") ..
                "\nCycle: " .. State.petMgrCycle ..
                " | Scanned: " .. State.petMgrScanned ..
                " | Kept: " .. State.petMgrKept ..
                "\nLocked: " .. State.petMgrLocked ..
                " | Deleted: " .. State.petMgrDeleted ..
                (modStatus ~= "" and ("\n" .. modStatus) or "") ..
                "\nKeep Tiers: " .. table.concat(CFG.PetMgrKeepTiers, ", ") ..
                " | Shiny: " .. tostring(CFG.PetMgrKeepShiny) ..
                " | Colorful: " .. tostring(CFG.PetMgrKeepColorful)
            )
        end
    end)
    T:AddToggle("PetMgrEnabled", {
        Title = "Enable Auto Pet Manager",
        Description = "เปิด/ปิด ระบบจัดการ pet อัตโนมัติ (Lock + Delete)",
        Default = false,
    }):OnChanged(function()
        CFG.PetMgrEnabled = Fluent.Options["PetMgrEnabled"].Value
        if CFG.PetMgrEnabled then
            State.petMgrStop = false
            State.petMgrCycle = 0
            State.petMgrLastScan = 0
            Fluent:Notify({ Title = "Pet Manager", Content = "เปิดใช้งานแล้ว", Duration = 2 })
        else
            State.petMgrStop = true
            State.petMgrStatus = "OFF"
            Fluent:Notify({ Title = "Pet Manager", Content = "ปิดใช้งานแล้ว", Duration = 2 })
        end
    end)
    T:AddToggle("PetMgrAutoLock", {
        Title = "Auto Lock Valuable Pets",
        Description = "ล็อค pet ที่ตรงเงื่อนไขอัตโนมัติ",
        Default = true,
    }):OnChanged(function()
        CFG.PetMgrAutoLock = Fluent.Options["PetMgrAutoLock"].Value
    end)
    T:AddToggle("PetMgrAutoDelete", {
        Title = "Auto Delete Unwanted Pets",
        Description = "⚠ ลบ pet ที่ไม่ตรงเงื่อนไข (ปิดค่าเริ่มต้นเพื่อความปลอดภัย)",
        Default = false,
    }):OnChanged(function()
        CFG.PetMgrAutoDelete = Fluent.Options["PetMgrAutoDelete"].Value
        if CFG.PetMgrAutoDelete then
            Fluent:Notify({ Title = "⚠ Auto Delete ON", Content = "Pet ที่ไม่อยู่ในเงื่อนไขจะถูกลบถาวร!", Duration = 5 })
        end
    end)
    T:AddToggle("PetMgrKeepShiny", {
        Title = "Keep Shiny Pets",
        Description = "เก็บ pet ที่เป็น Shiny (shinyTypeId == 2) ไว้เสมอ",
        Default = true,
    }):OnChanged(function()
        CFG.PetMgrKeepShiny = Fluent.Options["PetMgrKeepShiny"].Value
    end)
    T:AddToggle("PetMgrKeepColorful", {
        Title = "Keep Colorful/Prismatic Pets",
        Description = "เก็บ pet ที่มี colorful attribute ไว้เสมอ",
        Default = true,
    }):OnChanged(function()
        CFG.PetMgrKeepColorful = Fluent.Options["PetMgrKeepColorful"].Value
    end)
    local TIER_LABEL_TO_ID = {
        ["C (1)"] = 1,
        ["B (2)"] = 2,
        ["A (3)"] = 3,
        ["S (4)"] = 4,
        ["SSS (5)"] = 5,
        ["D (6)"] = 6,
    }
    local TIER_ID_TO_LABEL = {}
    for label, id in pairs(TIER_LABEL_TO_ID) do TIER_ID_TO_LABEL[id] = label end
    local defaultTierLabels = {}
    for _, id in ipairs(CFG.PetMgrKeepTiers) do
        if TIER_ID_TO_LABEL[id] then defaultTierLabels[#defaultTierLabels + 1] = TIER_ID_TO_LABEL[id] end
    end
    T:AddDropdown("PetMgrKeepTiers", {
        Title = "Keep Tier (Talent Grade)",
        Description = "เลือก Tier ที่ต้องการเก็บ (Multi-select)",
        Values = {"C (1)", "B (2)", "A (3)", "S (4)", "SSS (5)", "D (6)"},
        Default = defaultTierLabels,
        Multi = true,
        Callback = function(selectedTable)
            local newTiers = {}
            for label, isSelected in pairs(selectedTable) do
                if isSelected and TIER_LABEL_TO_ID[label] then
                    newTiers[#newTiers + 1] = TIER_LABEL_TO_ID[label]
                end
            end
            table.sort(newTiers)
            CFG.PetMgrKeepTiers = newTiers
            rebuildTierSet()
        end,
    })
    T:AddSlider("PetMgrScanInterval", {
        Title = "Scan Interval (x0.5s)",
        Description = "ความถี่ในการ scan pet",
        Default = 2,
        Min = 1,
        Max = 20,
        Rounding = 0,
        Callback = function(v) CFG.PetMgrScanInterval = v * 0.5 end,
    })
    T:AddSlider("PetMgrRequestDelay", {
        Title = "Request Delay (x10ms)",
        Description = "หน่วงระหว่าง request แต่ละครั้ง",
        Default = 5,
        Min = 0,
        Max = 50,
        Rounding = 0,
        Callback = function(v) CFG.PetMgrRequestDelay = v * 0.01 end,
    })
    T:AddSlider("PetMgrBatchSize", {
        Title = "Delete Batch Size",
        Description = "จำนวน pet ที่ลบต่อ 1 คำสั่ง",
        Default = 25,
        Min = 1,
        Max = 50,
        Rounding = 0,
        Callback = function(v) CFG.PetMgrBatchSize = v end,
    })
    T:AddButton({
        Title = "Scan Now",
        Description = "สแกนและจัดการ pet ทันที (1 รอบ)",
        Callback = function()
            task.spawn(function()
                if not PetServiceModule then
                    Fluent:Notify({ Title = "Pet Manager", Content = "⚠ PetService module ไม่ถูกโหลด", Duration = 4 })
                    return
                end
                Fluent:Notify({ Title = "Pet Manager", Content = "กำลังสแกน...", Duration = 2 })
                local ok, err = pcall(petMgrScanOnce)
                if ok then
                    Fluent:Notify({ Title = "Scan Complete", Content = State.petMgrStatus, Duration = 4 })
                else
                    Fluent:Notify({ Title = "Scan Error", Content = tostring(err), Duration = 4 })
                end
            end)
        end,
    })
    T:AddButton({
        Title = "Lock All Valuable Now",
        Description = "ล็อค pet ที่ตรงเงื่อนไขทั้งหมดทันที (ไม่ลบ)",
        Callback = function()
            task.spawn(function()
                local prevLock = CFG.PetMgrAutoLock
                local prevDelete = CFG.PetMgrAutoDelete
                CFG.PetMgrAutoLock = true
                CFG.PetMgrAutoDelete = false
                Fluent:Notify({ Title = "Pet Manager", Content = "กำลังล็อค pet ที่มีค่า...", Duration = 2 })
                local ok, err = pcall(petMgrScanOnce)
                CFG.PetMgrAutoLock = prevLock
                CFG.PetMgrAutoDelete = prevDelete
                if ok then
                    Fluent:Notify({ Title = "Lock Complete", Content = string.format("ล็อคแล้ว: %d ตัว", State.petMgrLocked), Duration = 4 })
                else
                    Fluent:Notify({ Title = "Lock Error", Content = tostring(err), Duration = 4 })
                end
            end)
        end,
    })
    T:AddButton({
        Title = "View Module Status",
        Description = "ตรวจสอบว่า Module โหลดสำเร็จหรือไม่",
        Callback = function()
            local lines = {
                "=== Pet Manager Module Status ===",
                "PetService:      " .. (PetServiceModule and "✓ Loaded" or "✗ NOT LOADED"),
                "PetGroupStorage: " .. (PetGroupStorageMod and "✓ Loaded" or "✗ NOT LOADED"),
                "ErrorCode:       " .. (ErrorCode and "✓ Loaded" or "✗ NOT LOADED (using fallback 0)"),
                "PetStorage(old): " .. (PetStorage and "✓ Loaded" or "✗ NOT LOADED"),
                "",
                "EC_SUCCEEDED = " .. tostring(EC_SUCCEEDED),
                "Keep Tiers: " .. table.concat(CFG.PetMgrKeepTiers, ", "),
            }
            if PetServiceModule then
                local methods = {"getPlayerPetData", "reqSetPetLocked", "reqRemovePets", "removePets", "reqDeletePet", "setLocked"}
                lines[#lines + 1] = "\nPetService Methods:"
                for _, m in ipairs(methods) do
                    lines[#lines + 1] = string.format("  %-22s %s", m, PetServiceModule[m] and "✓" or "✗")
                end
            end
            local content = table.concat(lines, "\n")
            Fluent:Notify({ Title = "Module Status", Content = content, Duration = 8 })
            print(content)
        end,
    })
end

-- Tab Element
do
    local T = Tabs.Element
    T:AddParagraph({
        Title = "Module Status",
        Content = string.format(
            "ElementModule: %s | BattleDataGet: %s | Controller: %s | HeadDisplay: %s",
            ElementModule ~= nil and "OK" or "MISSING",
            BattleDataGetModule ~= nil and "OK" or "MISSING",
            MainBattleWindowController ~= nil and "OK" or "MISSING",
            BattlePetHeadModule ~= nil and "OK" or "MISSING"
        ),
    })
    local ElemStatus = T:AddParagraph({ Title = "Element Advantage Status", Content = "Waiting..." })
    task.spawn(function()
        while true do
            task.wait(1)
            pcall(function()
                ElemStatus:SetDesc(
                    "Status: " .. tostring(State.elemAdvStatus or "OFF") ..
                    "\nEnemy: " .. tostring(State.elemAdvEnemyName or "—") ..
                    " | Elements: " .. tostring(State.elemAdvEnemyElements or "—") ..
                    "\nBest: " .. tostring(State.elemAdvBestPet or "—") ..
                    string.format(" [%.2fx]", State.elemAdvBestRate or 0) ..
                    " | Found: " .. tostring(State.elemAdvCandidates or 0) ..
                    "\nLocked: " .. tostring(State.elemAdvLockedName or "—")
                )
            end)
        end
    end)
    local ElemCandidates = T:AddParagraph({ Title = "Top Candidates", Content = "Enable scanner to see results" })
    task.spawn(function()
        while true do
            task.wait(1.5)
            if not CFG.ElemAdvEnabled or not isInBattle() then
                pcall(function()
                    ElemCandidates:SetDesc("Enable scanner + enter battle")
                end)
            else
                pcall(function()
                    local scanOk, r1, r2, r3, r4, r5 = pcall(buildElemCandidates)
                    if not scanOk or typeof(r5) ~= "table" then
                        ElemCandidates:SetDesc("Scan error")
                        return
                    end
                    local rows = r5
                    local lines = {}
                    local showCount = math.min(10, #rows)
                    if showCount == 0 then
                        lines[1] = "No pet >= " .. tostring(CFG.ElemAdvMinRate) .. "x"
                    else
                        for i = 1, showCount do
                            local p = rows[i]
                            local atkName = "?"
                            if p.bestAtkElement then
                                atkName = getElementName(p.bestAtkElement)
                            end
                            local src = p.source == "BattleTeam" and ("[TEAM " .. tostring(p.slotText) .. "]") or "[BAG]"
                            lines[#lines + 1] = string.format("#%d %s [%.2fx] %s", i, p.name or "?", p.advantageRate or 0, src)
                            lines[#lines + 1] = string.format("   Atk: %s | Elem: %s", atkName, elementListToText(p.elements))
                        end
                    end
                    lines[#lines + 1] = string.format("\nTotal: %d", #rows)
                    ElemCandidates:SetDesc(table.concat(lines, "\n"))
                end)
            end
        end
    end)
    T:AddToggle("ElemAdvEnabled", {
        Title = "Enable Element Scanner",
        Description = "สแกน element advantage ต่อ enemy",
        Default = false,
    }):OnChanged(function()
        CFG.ElemAdvEnabled = Fluent.Options["ElemAdvEnabled"].Value
    end)
    T:AddToggle("ElemAdvAutoSwitch", {
        Title = "Auto Switch + Play Till Dead",
        Description = "สลับไปตัวที่ธาตุชนะทางดีที่สุด แล้วเล่นตัวนั้นจนตาย จากนั้นค่อยหาตัวใหม่อัตโนมัติ",
        Default = false,
    }):OnChanged(function()
        CFG.ElemAdvAutoSwitch = Fluent.Options["ElemAdvAutoSwitch"].Value
        CFG.ElemAdvSwitchOnlyWhenDead = CFG.ElemAdvAutoSwitch
        State.elemAdvLockedUid = nil
        State.elemAdvLockedName = "—"
    end)
    T:AddDropdown("ElemAdvMinRate", {
        Title = "Minimum Advantage Rate",
        Description = "แสดงเฉพาะ pet >= ค่านี้",
        Values = {"1.50x", "2.00x", "2.50x", "3.00x", "4.00x"},
        Default = 2,
        Multi = false,
        Callback = function(v)
            local map = {
                ["1.50x"] = 1.5,
                ["2.00x"] = 2.0,
                ["2.50x"] = 2.5,
                ["3.00x"] = 3.0,
                ["4.00x"] = 4.0,
            }
            CFG.ElemAdvMinRate = map[v] or 2.0
        end,
    })
    T:AddDropdown("ElemAdvActionType", {
        Title = "Switch Action Type",
        Description = "actionType สำหรับสลับ pet (ปกติ = 3)",
        Values = {"3 (Switch)", "4 (Item)", "5 (Catch)", "6 (Other)"},
        Default = 1,
        Multi = false,
        Callback = function(v)
            local map = {
                ["3 (Switch)"] = 3,
                ["4 (Item)"] = 4,
                ["5 (Catch)"] = 5,
                ["6 (Other)"] = 6,
            }
            CFG.ElemAdvActionType = map[v] or 3
        end,
    })
    T:AddSlider("ElemAdvScanDelay", {
        Title = "Scan Interval (x0.25s)",
        Description = "ความถี่ scan",
        Default = 3,
        Min = 1,
        Max = 20,
        Rounding = 0,
        Callback = function(v)
            CFG.ElemAdvScanDelay = v * 0.25
        end,
    })
    T:AddButton({
        Title = "Scan Now",
        Description = "สแกนทันที",
        Callback = function()
            task.spawn(function()
                if not isInBattle() then
                    Fluent:Notify({ Title = "Element", Content = "ต้องอยู่ใน battle!", Duration = 3 })
                    return
                end
                local scanOk, r1, r2, r3, r4, r5 = pcall(buildElemCandidates)
                if not scanOk then
                    Fluent:Notify({ Title = "Error", Content = tostring(r1), Duration = 4 })
                    return
                end
                local enemyName = r3
                local enemyElements = r4
                local rows = r5 or {}
                local topLines = {}
                for i = 1, math.min(5, #rows) do
                    topLines[#topLines + 1] = string.format("#%d %s [%.2fx]", i, rows[i].name or "?", rows[i].advantageRate or 0)
                end
                Fluent:Notify({
                    Title = "Scan Complete",
                    Content = string.format(
                        "Enemy: %s [%s]\n%d candidates\n%s",
                        tostring(enemyName),
                        elementListToText(enemyElements),
                        #rows,
                        #topLines > 0 and table.concat(topLines, "\n") or "None"
                    ),
                    Duration = 6,
                })
            end)
        end,
    })
    T:AddButton({
        Title = "Switch Best Now",
        Description = "สลับเป็น pet ที่ดีที่สุดทันที",
        Callback = function()
            task.spawn(function()
                if not isInBattle() then
                    Fluent:Notify({ Title = "Element", Content = "ต้องอยู่ใน battle!", Duration = 3 })
                    return
                end
                local scanOk, r1, r2, r3, r4, r5 = pcall(buildElemCandidates)
                if not scanOk or typeof(r5) ~= "table" or #r5 == 0 then
                    Fluent:Notify({ Title = "No Candidate", Content = "ไม่พบ pet ที่มี advantage", Duration = 3 })
                    return
                end
                local bestPet = findBestTeamSwitch(r5)
                if not bestPet then
                    Fluent:Notify({ Title = "No Team Pet", Content = "Best pet อยู่ใน Bag — ไม่สามารถสลับ", Duration = 4 })
                    return
                end
                local switchOk, switchResult = elemSwitchPet(bestPet)
                Fluent:Notify({
                    Title = switchOk and "Switched!" or "Failed",
                    Content = string.format("%s [%.2fx] — %s", bestPet.name or "?", bestPet.advantageRate or 0, tostring(switchResult)),
                    Duration = 4,
                })
            end)
        end,
    })
end

-- Tab Timing
do
    local T = Tabs.Timing
    addSliderGroup(T, {
        {"WindowCheckDelay", "Window Check Delay (x0.1s)",  "Max wait for CatchWindow to open",   5,  1, 20, 0.1},
        {"PreCheckDelay",    "Pre-Check Delay (x0.1s)",     "Double-check pause before action",   3,  1, 20, 0.1},
        {"ScanDelay",        "Enter Scan Interval (x0.1s)", "Target scan frequency (0=fastest)", 0,  0, 20, 0.1},
        {"CatchDelay",       "Catch Interval (x0.5s)",      "Ball throw frequency",              2,  1, 10, 0.5},
        {"EscapeDelay",      "Escape Interval (x0.5s)",     "Escape attempt frequency",          2,  1, 10, 0.5},
        {"ChestClaimDelay",  "Chest Claim Gap (x0.1s)",     "Delay between chest claims",        3,  1, 10, 0.1},
        {"ChestScanDelay",   "Chest Scan Interval (x0.5s)", "Chest rescan frequency",            4,  1, 20, 0.5},
        {"TPCheckInterval",  "TP Check Interval (sec)",     "Level check frequency",            10,  3, 60, 1},
        {"TPHeight",         "TP Height (studs)",           "Height above spawn point",         10,  0, 50, 1},
        {"AutoBossDelay",    "Boss Loop Delay (sec)",       "Delay between boss attempts",       6,  1, 30, 1},
        {"NPCLoopDelay",     "NPC Loop Delay (x0.5s)",      "Delay between NPC attempts",        5,  1, 20, 0.5},
        {"AutoBattleResync", "AutoBattle Resync (x0.5s)",   "Resync auto-battle signal",         4,  1, 20, 0.5},
        {"HealDelay",        "Heal Check Interval (x0.1s)", "ความถี่ตรวจ HP ใน battle (1 = 0.1s เร็วสุด)", 1,  1, 20, 0.1},
        {"TaskReceiveDelay", "Task Receive Gap (x0.1s)",    "Delay ระหว่างรับแต่ละ task",        5,  1, 30, 0.1},
        {"TaskClaimDelay",   "Task Claim Gap (x0.1s)",      "Delay ระหว่าง claim Each task",    5,  1, 30, 0.1},
        {"TaskLoopInterval", "Task Loop Interval (sec)",    "ความถี่วน loop receive+claim ใหม่",30, 10, 300, 1},
        {"ElemAdvScanDelay", "Element Scan (x0.25s)",       "ความถี่ scan element advantage",    3,  1, 20, 0.25},
    })
end

-- Tab Settings
do
    SaveManager:SetLibrary(Fluent)
    InterfaceManager:SetLibrary(Fluent)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes({})
    InterfaceManager:SetFolder("FluentScriptHub")
    SaveManager:SetFolder("FluentScriptHub/evomon-farm")
    InterfaceManager:BuildInterfaceSection(Tabs.Settings)
    SaveManager:BuildConfigSection(Tabs.Settings)
end

-- ────────────────────────────────────────────────────────────────────
-- SECTION 21 : INIT (INSTANT GUI & SILENT BACKGROUND BOSS RESCAN)
-- ────────────────────────────────────────────────────────────────────
Window:SelectTab(1)
print("[Delta X — Evomon v3.6] GUI Created instantly! All systems active.")

Fluent:Notify({
    Title = "Delta X — Evomon v3.6",
    Content = string.format("GUI Loaded Instantly! %d Bosses ready.", #BOSS_LIST),
    Duration = 3,
})

-- สแกนบอสเบื้องหลังเงียบๆ ทุก 10 วินาที เพื่ออัปเดตสถานะและการเกิดของบอสใน Dropdown อัตโนมัติ
task.spawn(function()
    while true do
        task.wait(10)
        pcall(function()
            local newList = scanAllBosses()
            if #newList > 0 and #newList ~= #BOSS_LIST then
                BOSS_LIST = newList
                BOSS_NAMES = buildNameList(BOSS_LIST)
                if _G.BossDropdownRef then
                    _G.BossDropdownRef:SetValues(BOSS_NAMES)
                end
                print(string.format("[Delta X — Evomon v3.6] Silent Boss Rescan updated: %d bosses", #BOSS_LIST))
            end
        end)
    end
end)

SaveManager:LoadAutoloadConfig()
print("[Delta X — Evomon v3.6] Ready!")
