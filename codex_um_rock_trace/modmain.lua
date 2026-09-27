local ROCK_AVOCADO_PREFAB = "rock_avocado_bush"
local TRACE_PREFIX = "[CODEX_UM_ROCK_TRACE]"
local SUMMARY_PREFIX = "[CODEX_UM_ROCK_SUMMARY]"

local function ReturnResults(results)
    return results[1], results[2], results[3], results[4], results[5], results[6]
end

local function IsRockAvocado(inst)
    return inst ~= nil and inst.prefab == ROCK_AVOCADO_PREFAB
end

local function SafeGetTime()
    return GLOBAL.GetTime ~= nil and GLOBAL.GetTime() or -1
end

local function BoolString(value)
    if value == nil then
        return "nil"
    end
    return tostring(value)
end

local function FormatPos(inst)
    if inst ~= nil and inst.Transform ~= nil then
        local x, y, z = inst.Transform:GetWorldPosition()
        return string.format("(%.2f,%.2f,%.2f)", x or 0, y or 0, z or 0)
    end
    return "(nil,nil,nil)"
end

local function FormatReasons(reasons)
    if reasons == nil then
        return "nil"
    end

    local out = {}
    for reason, value in pairs(reasons) do
        table.insert(out, tostring(reason) .. "=" .. tostring(value))
    end
    table.sort(out)
    return #out > 0 and table.concat(out, ",") or "empty"
end

local function FormatTask(task)
    if task == nil then
        return "nil"
    end
    return tostring(task)
end

local function ShouldLogCount(count)
    return count <= 10 or count % 100 == 0
end

local function GetCounter(comp, label)
    comp._codex_um_rock_trace_counts = comp._codex_um_rock_trace_counts or {}
    local counts = comp._codex_um_rock_trace_counts
    counts[label] = (counts[label] or 0) + 1
    return counts[label]
end

local function LogState(label, inst, extra)
    if not IsRockAvocado(inst) then
        return
    end

    local world = GLOBAL.TheWorld
    local state = world ~= nil and world.state or nil
    local growable = inst.components ~= nil and inst.components.growable or nil
    local pickable = inst.components ~= nil and inst.components.pickable or nil

    print(string.format(
        "%s label=%s guid=%s prefab=%s pos=%s season=%s iswinter=%s cycles=%s phase=%s time=%s " ..
        "g_stage=%s g_targettime=%s g_sleeptime=%s g_pausedremaining=%s g_remaining=%s g_task=%s g_is_growing=%s g_reasons=%s " ..
        "p_canbepicked=%s p_paused=%s p_targettime=%s p_task=%s p_cycles_left=%s p_numtoharvest=%s %s",
        TRACE_PREFIX,
        tostring(label),
        tostring(inst.GUID),
        tostring(inst.prefab),
        FormatPos(inst),
        tostring(state ~= nil and state.season or nil),
        BoolString(state ~= nil and state.iswinter or nil),
        tostring(state ~= nil and state.cycles or nil),
        tostring(state ~= nil and state.phase or nil),
        tostring(SafeGetTime()),
        tostring(growable ~= nil and growable.stage or nil),
        tostring(growable ~= nil and growable.targettime or nil),
        tostring(growable ~= nil and growable.sleeptime or nil),
        tostring(growable ~= nil and growable.pausedremaining or nil),
        tostring(growable ~= nil and growable.remaining or nil),
        FormatTask(growable ~= nil and growable.task or nil),
        BoolString(growable ~= nil and growable.is_growing or nil),
        FormatReasons(growable ~= nil and growable.pausereasons or nil),
        BoolString(pickable ~= nil and pickable.canbepicked or nil),
        BoolString(pickable ~= nil and pickable.paused or nil),
        tostring(pickable ~= nil and pickable.targettime or nil),
        FormatTask(pickable ~= nil and pickable.task or nil),
        tostring(pickable ~= nil and pickable.cycles_left or nil),
        tostring(pickable ~= nil and pickable.numtoharvest or nil),
        extra or ""
    ))
end

local function WrapMethod(component_name, method_name, before_after)
    AddComponentPostInit(component_name, function(self)
        local old = self[method_name]
        if old == nil then
            return
        end

        self[method_name] = function(comp, ...)
            local inst = comp.inst
            local count = IsRockAvocado(inst) and GetCounter(comp, component_name .. "." .. method_name) or 0
            local should_log = IsRockAvocado(inst) and (before_after or ShouldLogCount(count))

            if should_log then
                LogState(component_name .. "." .. method_name .. " before", inst, "count=" .. tostring(count))
            end

            local results = { old(comp, ...) }

            if should_log then
                LogState(component_name .. "." .. method_name .. " after", inst, "count=" .. tostring(count))
            end

            return ReturnResults(results)
        end
    end)
end

local function WrapLongUpdate()
    AddComponentPostInit("growable", function(self)
        local old = self.LongUpdate
        if old == nil then
            return
        end

        self.LongUpdate = function(comp, dt, ...)
            local inst = comp.inst
            local count = IsRockAvocado(inst) and GetCounter(comp, "growable.LongUpdate") or 0
            local should_log = IsRockAvocado(inst) and (count <= 20 or count % 100 == 0)

            if should_log then
                local timeleft = comp.targettime ~= nil and (comp.targettime - SafeGetTime()) or nil
                LogState("growable.LongUpdate before", inst, "count=" .. tostring(count) .. " dt=" .. tostring(dt) .. " timeleft=" .. tostring(timeleft))
            end

            local results = { old(comp, dt, ...) }

            if should_log then
                local timeleft = comp.targettime ~= nil and (comp.targettime - SafeGetTime()) or nil
                LogState("growable.LongUpdate after", inst, "count=" .. tostring(count) .. " dt=" .. tostring(dt) .. " timeleft=" .. tostring(timeleft))
            end

            return ReturnResults(results)
        end
    end)
end

local function WatchRock(inst)
    if not GLOBAL.TheWorld.ismastersim then
        return
    end

    inst:ListenForEvent("entitywake", function()
        LogState("event.entitywake", inst)
    end)
    inst:ListenForEvent("entitysleep", function()
        LogState("event.entitysleep", inst)
    end)

    inst:DoTaskInTime(0, function()
        LogState("prefab_t0", inst)
    end)
    inst:DoTaskInTime(1, function()
        LogState("prefab_t1", inst)
    end)
end

local function WorldSummary()
    if not GLOBAL.TheWorld.ismastersim then
        return
    end

    GLOBAL.TheWorld:DoPeriodicTask(60, function()
        local count = 0
        for _, inst in pairs(GLOBAL.Ents) do
            if IsRockAvocado(inst) then
                count = count + 1
                LogState("world_periodic_60", inst)
            end
        end
        local state = GLOBAL.TheWorld.state
        print(string.format(
            "%s total=%s season=%s iswinter=%s cycles=%s phase=%s time=%s",
            SUMMARY_PREFIX,
            tostring(count),
            tostring(state ~= nil and state.season or nil),
            BoolString(state ~= nil and state.iswinter or nil),
            tostring(state ~= nil and state.cycles or nil),
            tostring(state ~= nil and state.phase or nil),
            tostring(SafeGetTime())
        ))
    end)
end

WrapMethod("growable", "OnLoad", true)
WrapMethod("growable", "OnSave", true)
WrapMethod("growable", "OnEntityWake", true)
WrapMethod("growable", "OnEntitySleep", true)
WrapLongUpdate()
WrapMethod("growable", "DoGrowth", false)
WrapMethod("growable", "SetStage", false)
WrapMethod("growable", "StartGrowing", false)
WrapMethod("growable", "StartGrowingTask", false)
WrapMethod("growable", "StopGrowing", false)
WrapMethod("growable", "Pause", false)
WrapMethod("growable", "Resume", false)

WrapMethod("pickable", "OnLoad", true)
WrapMethod("pickable", "OnSave", true)
WrapMethod("pickable", "Regen", false)
WrapMethod("pickable", "Pause", false)
WrapMethod("pickable", "Resume", false)
WrapMethod("pickable", "MakeEmpty", false)
WrapMethod("pickable", "MakeBarren", false)

AddPrefabPostInit(ROCK_AVOCADO_PREFAB, WatchRock)
AddSimPostInit(WorldSummary)
