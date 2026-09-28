GLOBAL.setmetatable(env, { __index = function(_, key) return GLOBAL.rawget(GLOBAL, key) end })

local ROCK_AVOCADO_PREFAB = "rock_avocado_bush"
local WINTER_PAUSE_SOURCE = "um_rock_avocado_winter"
local PATCH_ENABLED = GetModConfigData("patch_enabled") ~= false

if not PATCH_ENABLED then
    return
end

local UM_MOD_NAMES = {
    "workshop-2039181790",
    "workshop-3193922031",
}

local function Pack(...)
    return { n = GLOBAL.select("#", ...), ... }
end

local function Unpack(values)
    return GLOBAL.unpack(values, 1, values.n)
end

local function GetWorld()
    return GLOBAL.TheWorld
end

local function GetNoWinterGrowingConfig()
    local getter = GLOBAL.GetModConfigData
    if getter == nil then
        return false
    end

    for _, modname in ipairs(UM_MOD_NAMES) do
        local value = getter("no_winter_growing_", modname)
        if value ~= nil then
            return value == true
        end
    end

    return false
end

local function GetSeason()
    local world = GetWorld()
    if world == nil then
        return nil, false
    end

    local state = world.state
    local season = state ~= nil and state.season or nil
    local iswinter = state ~= nil and state.iswinter == true or season == "winter"

    local seasons = world.components ~= nil and world.components.seasons or nil
    if seasons ~= nil and seasons.GetSeason ~= nil then
        local component_season = seasons:GetSeason()
        season = season or component_season
        iswinter = iswinter or component_season == "winter"
    end

    return season, iswinter
end

local function ShouldBlockStoneFruitGrowth()
    if not GetNoWinterGrowingConfig() then
        return false
    end

    local season, iswinter = GetSeason()
    return iswinter or season == nil
end

local function PauseGrowable(growable)
    if growable == nil then
        return
    end

    -- Growable:Pause catches up sleeptime via LongUpdate first; that catch-up is
    -- the freeze path, so clear it before adding our pause reason.
    growable.sleeptime = nil
    if growable.Pause ~= nil then
        growable:Pause(WINTER_PAUSE_SOURCE)
    end
    if growable.pausereasons ~= nil then
        growable.pausereasons[WINTER_PAUSE_SOURCE] = true
    end
    if growable.pausedremaining ~= nil and growable.pausedremaining < 0 then
        growable.pausedremaining = 0
    end
end

local function HasPauseReasons(growable)
    if growable == nil or growable.pausereasons == nil then
        return false
    end

    return next(growable.pausereasons) ~= nil
end

local function ClearWinterPauseReason(growable)
    if growable == nil or growable.pausereasons == nil then
        return
    end

    growable.pausereasons[WINTER_PAUSE_SOURCE] = nil
    for reason, _ in pairs(growable.pausereasons) do
        if tostring(reason) == WINTER_PAUSE_SOURCE then
            growable.pausereasons[reason] = nil
        end
    end
end

local function ResumeGrowable(growable)
    if growable == nil then
        return
    end

    -- Older UM wraps Resume without forwarding the pause reason argument. Clear
    -- our reason directly so spring recovery cannot be blocked by that wrapper.
    ClearWinterPauseReason(growable)

    if not HasPauseReasons(growable) and growable.pausedremaining ~= nil then
        local remaining = growable.pausedremaining
        growable.pausedremaining = nil

        if growable.StartGrowingTask ~= nil then
            growable:StartGrowingTask(remaining)
        end

        ClearWinterPauseReason(growable)
        return true
    end
end

local function IsRockAvocadoGrowable(growable)
    return growable ~= nil
        and growable.inst ~= nil
        and growable.inst.prefab == ROCK_AVOCADO_PREFAB
end

local function ApplyStoneFruitWinterGrowth(inst)
    if inst == nil or inst.components == nil then
        return
    end

    local growable = inst.components.growable
    if growable == nil then
        return
    end

    if ShouldBlockStoneFruitGrowth() then
        PauseGrowable(growable)
    else
        ResumeGrowable(growable)
    end
end

AddComponentPostInit("growable", function(self)
    local old_on_load = self.OnLoad
    function self:OnLoad(...)
        local result = old_on_load ~= nil and Pack(old_on_load(self, ...)) or Pack()
        if IsRockAvocadoGrowable(self) then
            if ShouldBlockStoneFruitGrowth() then
                PauseGrowable(self)
            else
                ClearWinterPauseReason(self)
            end
        end
        return Unpack(result)
    end

    local old_on_entity_wake = self.OnEntityWake
    function self:OnEntityWake(...)
        if IsRockAvocadoGrowable(self) then
            if ShouldBlockStoneFruitGrowth() then
                PauseGrowable(self)
                return
            end
            ClearWinterPauseReason(self)
        end

        local result = old_on_entity_wake ~= nil and Pack(old_on_entity_wake(self, ...)) or Pack()
        if IsRockAvocadoGrowable(self) and not ShouldBlockStoneFruitGrowth() then
            ClearWinterPauseReason(self)
        end
        return Unpack(result)
    end

    local old_long_update = self.LongUpdate
    function self:LongUpdate(dt, ...)
        if IsRockAvocadoGrowable(self) then
            if ShouldBlockStoneFruitGrowth() then
                PauseGrowable(self)
                return
            end
            ClearWinterPauseReason(self)
        end

        local result = old_long_update ~= nil and Pack(old_long_update(self, dt, ...)) or Pack()
        if IsRockAvocadoGrowable(self) and not ShouldBlockStoneFruitGrowth() then
            ClearWinterPauseReason(self)
        end
        return Unpack(result)
    end

    local old_do_growth = self.DoGrowth
    function self:DoGrowth(...)
        if IsRockAvocadoGrowable(self) then
            if ShouldBlockStoneFruitGrowth() then
                PauseGrowable(self)
                return false
            end
            ClearWinterPauseReason(self)
        end

        local result = old_do_growth ~= nil and Pack(old_do_growth(self, ...)) or Pack()
        if IsRockAvocadoGrowable(self) and not ShouldBlockStoneFruitGrowth() then
            ClearWinterPauseReason(self)
        end
        return Unpack(result)
    end

    local old_start_growing = self.StartGrowing
    function self:StartGrowing(...)
        if IsRockAvocadoGrowable(self) then
            if ShouldBlockStoneFruitGrowth() then
                PauseGrowable(self)
                return false
            end
            ClearWinterPauseReason(self)
        end

        local result = old_start_growing ~= nil and Pack(old_start_growing(self, ...)) or Pack()
        if IsRockAvocadoGrowable(self) and not ShouldBlockStoneFruitGrowth() then
            ClearWinterPauseReason(self)
        end
        return Unpack(result)
    end

    local old_start_growing_task = self.StartGrowingTask
    function self:StartGrowingTask(...)
        if IsRockAvocadoGrowable(self) and not ShouldBlockStoneFruitGrowth() then
            ClearWinterPauseReason(self)
        end

        local result = old_start_growing_task ~= nil and Pack(old_start_growing_task(self, ...)) or Pack()
        if IsRockAvocadoGrowable(self) and not ShouldBlockStoneFruitGrowth() then
            ClearWinterPauseReason(self)
        end
        return Unpack(result)
    end

    local old_resume = self.Resume
    function self:Resume(...)
        if IsRockAvocadoGrowable(self) then
            if ShouldBlockStoneFruitGrowth() then
                PauseGrowable(self)
                return false
            end

            ResumeGrowable(self)
        end

        local result = old_resume ~= nil and Pack(old_resume(self, ...)) or Pack()
        if IsRockAvocadoGrowable(self) and not ShouldBlockStoneFruitGrowth() then
            ClearWinterPauseReason(self)
        end
        return Unpack(result)
    end

    local old_on_save = self.OnSave
    function self:OnSave(...)
        if IsRockAvocadoGrowable(self) and not ShouldBlockStoneFruitGrowth() then
            ClearWinterPauseReason(self)
        end

        if old_on_save ~= nil then
            return old_on_save(self, ...)
        end
    end
end)

local ROCK_AVOCADOS = {}

local function ApplyAllStoneFruit()
    for inst, _ in pairs(ROCK_AVOCADOS) do
        if inst ~= nil and inst:IsValid() then
            ApplyStoneFruitWinterGrowth(inst)
        else
            ROCK_AVOCADOS[inst] = nil
        end
    end
end

AddPrefabPostInit(ROCK_AVOCADO_PREFAB, function(inst)
    local world = GetWorld()
    if world == nil or world.ismastersim ~= true then
        return
    end

    ROCK_AVOCADOS[inst] = true
    inst:ListenForEvent("onremove", function()
        ROCK_AVOCADOS[inst] = nil
    end)

    inst:DoTaskInTime(0, ApplyStoneFruitWinterGrowth)
    inst:DoTaskInTime(1, ApplyStoneFruitWinterGrowth)
end)

AddPrefabPostInit("world", function(world)
    if world == nil or world.ismastersim ~= true then
        return
    end

    world:WatchWorldState("iswinter", ApplyAllStoneFruit)
    world:WatchWorldState("season", ApplyAllStoneFruit)
    world:DoTaskInTime(5, ApplyAllStoneFruit)
    world:DoTaskInTime(15, ApplyAllStoneFruit)
    world:DoTaskInTime(30, ApplyAllStoneFruit)
end)
