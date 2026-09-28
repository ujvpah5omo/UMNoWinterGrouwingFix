local is_chinese = locale == "zh" or locale == "zhr" or locale == "zht" or locale == "chs" or locale == "cht"

local WORKSHOP_URL = "https://steamcommunity.com/sharedfiles/filedetails/?id=3770333015"
local UM_WORKSHOP_ID = "workshop-2039181790"

local function T(zh, en)
    return is_chinese and zh or en
end

name = T(
    "永不妥协-冬季不生长补丁",
    "UM No Winter Growing Fix"
)

description = T([[
旧版永不妥协 UM（workshop-2039181790）的服务端外挂补丁。

本补丁只修复 2039181790 版 UM 对石果灌木 rock_avocado_bush 冬季生长状态处理不完整导致的 LongUpdate 死循环风险，不改变石果在非冬季的正常生长逻辑。

问题核心：
- 石果灌木同时拥有 pickable 和 growable。
- UM 的“冬季不生长”逻辑暂停了 pickable，但没有完整同步 growable。
- UM 又在冬季拦截 growable:StartGrowing() / Resume()。
- 当旧 targettime 落在当前时间之前时，LongUpdate -> DoGrowth -> SetStage -> pickable.Regen 可能反复补算，导致单分片 CPU 100%。

本补丁会在冬季且 UM 开启 no_winter_growing_ 时，将 rock_avocado_bush 的 growable 压到安全暂停状态，清理过期 targettime/sleeptime/remaining 等补算入口，并在非冬季恢复正常 StartGrowingTask 生长。

和测试版 UM workshop-3193922031 的区别：
3193922031 更像是绕开石果的冬季限制；本补丁保留旧版 UM“石果冬季不生长”的语义，但修正 growable / pickable 状态不一致的问题。

正式服只需要启用：
- workshop-2039181790 永不妥协 UM 旧版正式分支
- workshop-3770333015 永不妥协-冬季不生长补丁

不需要启用跟踪 / trace / debug mod。

Steam: https://steamcommunity.com/sharedfiles/filedetails/?id=3770333015
]], [[
Server-side compatibility patch for the old Uncompromising Mode release (workshop-2039181790).

This patch only fixes the LongUpdate dead-loop risk caused by incomplete winter growth-state handling for rock_avocado_bush in UM 2039181790. It does not change normal rock avocado growth outside winter.

Core issue:
- Rock avocado bushes have both pickable and growable components.
- UM's No Winter Growing logic pauses the pickable side, but does not fully synchronize the growable side.
- UM also blocks growable:StartGrowing() / Resume() in winter.
- If an old targettime is already earlier than the current shard time, LongUpdate -> DoGrowth -> SetStage -> pickable.Regen can repeatedly catch up and push one shard to 100% CPU.

When it is winter and UM's no_winter_growing_ option is enabled, this patch moves rock_avocado_bush growable into a safe paused state, clears stale targettime/sleeptime/remaining catch-up data, and restores normal StartGrowingTask growth outside winter.

Difference from UM testing branch workshop-3193922031:
3193922031 appears to avoid the rock avocado winter restriction path. This patch keeps old UM's "rock avocado does not grow in winter" meaning, but fixes the inconsistent growable / pickable state.

For live servers, enable only:
- workshop-2039181790 old Uncompromising Mode release
- workshop-3770333015 UM No Winter Growing Fix

Do not enable any trace / debug mod on a live server.

Steam: https://steamcommunity.com/sharedfiles/filedetails/?id=3770333015
]])

author = "Codex"
version = "1.2.1"
forumthread = WORKSHOP_URL

api_version = 10
priority = 0

dst_compatible = true
dont_starve_compatible = false
reign_of_giants_compatible = false
shipwrecked_compatible = false
hamlet_compatible = false
forge_compatible = false
gorge_compatible = false

all_clients_require_mod = false
client_only_mod = false
server_only_mod = true

icon_atlas = "modicon.xml"
icon = "modicon.tex"

mod_dependencies = {
    { workshop = UM_WORKSHOP_ID },
}

server_filter_tags = {
    "UM",
    "Uncompromising Mode",
    "No Winter Growing",
    "rock avocado",
    "server fix",
}

configuration_options = {
    {
        name = "patch_enabled",
        label = T("启用补丁", "Enable Patch"),
        hover = T(
            "默认启用。关闭后，本补丁不会介入石果灌木的冬季 growable 状态。",
            "Enabled by default. When disabled, this patch will not touch rock avocado winter growable state."
        ),
        options = {
            {
                description = T("启用", "Enabled"),
                hover = T(
                    "在 UM 开启“冬季不生长”且当前为冬季时，保护 rock_avocado_bush 的 growable 状态。",
                    "Protect rock_avocado_bush growable state when UM No Winter Growing is enabled and the world is in winter."
                ),
                data = true,
            },
            {
                description = T("禁用", "Disabled"),
                hover = T(
                    "完全关闭本补丁逻辑。仅建议排查兼容问题时临时使用。",
                    "Disable this patch completely. Only recommended temporarily for compatibility testing."
                ),
                data = false,
            },
        },
        default = true,
    },
}
