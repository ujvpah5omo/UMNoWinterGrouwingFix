# UM Rock Avocado Winter Fix - Extracted Investigation Notes

Source task: `UM永不妥协汉化` (`019f7040-85e5-75f2-a906-9d101b37f6a6`)

This document extracts the rock avocado winter-growth investigation from the unrelated UM Chinese localization task, so this patch mod has its own standalone context.

## Problem

Old Uncompromising Mode release `workshop-2039181790`, with `no_winter_growing_ = true`, can make `rock_avocado_bush` enter a growable catch-up loop in winter.

The observed bad state was:

```text
prefab=rock_avocado_bush
season=winter
targettime < current GetTime()
pickable paused
growable not safely paused
growable task nil
pause reasons empty
```

The loop repeatedly ran:

```text
growable.LongUpdate
growable.DoGrowth
growable.SetStage
pickable.Regen
```

Because old UM blocks `growable:StartGrowing()` for rock avocado bushes in winter, normal growable logic cannot refresh the stale `targettime` to a future value. `LongUpdate()` keeps seeing the expired `targettime`, and the shard CPU can stick at 100%.

## Why It Can Happen Naturally

The important condition is not "stone fruit was created in winter"; it is:

```text
current GetTime() > growable.targettime
```

A realistic path is:

```text
1. In autumn or another non-winter season, a player visits moon island or another stone fruit area.
2. Rock avocado bushes wake and schedule future growable targettime values.
3. The player leaves or logs off, and the bushes leave the active loading range.
4. Other players keep the shard running, so GetTime() continues moving forward.
5. Winter arrives while those bushes are unloaded or sleeping.
6. GetTime() passes the saved targettime.
7. A player returns in winter and wakes the bushes.
8. Old UM winter no-growth logic blocks the normal growable recovery path.
```

This explains why the bug is intermittent:

```text
Always-loaded bushes usually advance normally.
Unloaded bushes can keep old targettime values while shard time continues.
Returning in winter is the dangerous wake-up path.
```

## Reproduction Notes

Useful natural reproduction flow:

```text
1. Enable old UM workshop-2039181790.
2. Enable no_winter_growing_.
3. Enable the trace mod only for testing.
4. Start a fresh world in autumn.
5. Visit moon island and load rock_avocado_bush entities once.
6. Leave the stone fruit loading range before their targettime is reached.
7. Keep the shard running until winter and until GetTime() exceeds the targettime.
8. Return to the stone fruit area in winter.
```

One confirmed bad state on Master:

```text
guid=106631
prefab=rock_avocado_bush
pos=(603.73, 0, -463.15)
season=winter
time=4371.80
targettime=2675.06
p_paused=true
g_reasons=empty
g_task=nil
DoGrowth count≈258400
SetStage count≈258400
pickable.Regen count≈64600
```

Another confirmed bad state after restart:

```text
guid=102117
prefab=rock_avocado_bush
pos=(572.53, 0, -407.16)
season=winter
time=95.000004954636
g_targettime=90
g_task=nil
g_reasons=empty
p_paused=true
growable.DoGrowth count=418300+
growable.SetStage count=418300+
pickable.Regen count=104500+
```

This restart test showed that rebooting does not necessarily clear the bad state. The stale targettime can be preserved in the save, and once shard time passes it again, the loop can reappear.

One confirmed bad state on Caves:

```text
guid=102409
prefab=rock_avocado_bush
pos=(-299.76, 0, 158.41)
season=winter
time=2904.53
targettime=2306.75
DoGrowth count=3075500
SetStage count=3075500
pickable.Regen count=768800
```

## Timing Findings

`growable.targettime` is an absolute shard `GetTime()` timestamp, not a day number.

Example:

```text
spawn/wake time=287.90
targettime=2945.52
difference=2657.62 seconds
2657.62 / 480 ≈ 5.54 DST days
```

UM also increases stone fruit growth duration:

```lua
STONE_FRUIT_GROWTH_INCREASE = 3
```

So a large future targettime is not itself suspicious. The dangerous case is when:

```text
targettime < current GetTime()
```

## Patch Behavior

The patch mod fixes the unsafe winter state by doing all of the following for `rock_avocado_bush`:

```text
1. In winter, pause the growable component using its own pause reason.
2. Clear stale growable targettime/sleeptime catch-up data before unsafe LongUpdate paths.
3. Guard OnEntityWake, LongUpdate, DoGrowth, StartGrowing, Resume, and related entry points.
4. Outside winter, clear only the patch's own pause reason and restore normal StartGrowingTask-based growth.
```

The intended behavior is still UM's winter no-growth behavior. The patch does not make stone fruit grow in winter; it makes the no-growth state safe.

## Validation Result

After enabling the patch with old UM, the same kind of test stopped freezing.

Recommended live-server mod set:

```text
workshop-2039181790  old UM release
workshop-3770333015  永不妥协-冬季不生长补丁
```

Do not enable the trace mod on the live server. It is only for diagnostics and produces heavy logs.

Observed safe patched state:

```text
g_targettime=nil
g_task=nil
g_reasons=um_rock_avocado_winter=true
p_paused=true
```

Previously problematic stone fruit after patch:

```text
guid=102117
pos=(572.53, 0, -407.16)
g_targettime=nil
g_pausedremaining=2735
g_reasons=um_rock_avocado_winter=true
```

This confirmed the core goal: in winter, the patch removes dangerous stale targettime catch-up data and keeps growable in a safe paused state, preventing the `LongUpdate -> DoGrowth -> SetStage -> pickable.Regen` CPU loop.

## After Winter

A later check in spring showed the patch was not still blocking growth:

```text
season=spring
g_reasons=empty
um_rock_avocado_winter pause reason removed
```

Some bushes were already pickable, while others still had future targettime values. That was normal growth timing, not a stuck patch state.
