name = "永不妥协-冬季不生长补丁"
description = [[永不妥协 UM 旧版正式分支（workshop-2039181790）的服务端兼容补丁，用于修复开启 no_winter_growing_ 后，冬季石果灌木 rock_avocado_bush 的 growable 状态可能进入 LongUpdate 死循环并导致服务器 CPU 100% 卡死的问题。

Server-side compatibility patch for the official Uncompromising Mode release (workshop-2039181790).

This patch only fixes the CPU-freeze risk caused by incomplete winter growth-state handling for rock avocado bushes. It does not change normal rock avocado growth outside winter.

In workshop-2039181790, rock avocado bushes have both pickable and growable components. UM's No Winter Growing logic handles the pickable side first, but does not fully clear or synchronize the growable side. UM also blocks growable:StartGrowing() for rock avocado bushes in winter, which prevents the original StartGrowing() logic from clearing the old targettime and scheduling a new future targettime.

If a bush wakes up with an expired targettime, Growable:LongUpdate() can calculate a negative timeleft. That makes dt increase instead of being consumed. Each loop then tries to run DoGrowth -> SetStage -> pickable.Regen, but StartGrowing() is blocked again by UM, so the stale targettime remains. In that state, a single shard can hit 100% CPU.

This patch keeps UM's No Winter Growing behavior for rock avocado bushes, but makes the growable and pickable states consistent:
- In winter, rock avocado growable state is moved into a safe paused state and stale targettime/sleeptime catch-up data is cleared.
- Winter OnEntityWake, LongUpdate, DoGrowth, StartGrowing, and Resume entry points are guarded against unsafe catch-up.
- Outside winter, the patch clears its own pause reason and restores normal StartGrowingTask-based growth.

Compared with the Uncompromising Mode testing branch (workshop-3193922031), which avoids the issue by excluding rock avocado bushes from the problematic winter-growth handling, this patch fixes the old release more narrowly while preserving the intended winter no-growth behavior.]]
author = "Codex"
version = "1.1.1"
forumthread = ""
api_version = 10
dst_compatible = true
all_clients_require_mod = false
client_only_mod = false
server_only_mod = true
icon_atlas = ""
icon = ""
configuration_options = {}
