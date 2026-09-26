# 战斗震动实施记录

对应策划：`docs/design/COMBAT_HAPTICS_PLAN_20260915.md`。本批为原生 Build 26，复用现有 Unity 包，不改战斗伤害、冷却或动画。

## 实现

- 正式主线连续战斗以已消费的 Unity 接触事件及实际结算为输入；玩家一次施法汇总伤害，仅播放一次反馈。零伤害攻击静默，成功防御技能与假面发动使用独立轻反馈。
- 普攻、错步、身份错置、烙印、追猎双拍、巨牌重击、反客、后手与无名宣告使用独立强度/触感。Core Haptics 播放短图样，失败或硬件不支持时降级为一次系统 impact。
- 敌人实际 HP/盾损失与假面次数减少分流；HP 损失按最大 HP 的 10%/30% 分档。持续毒伤不触发普通承伤震动，战败状态统一反馈一次，替代致命直接承伤。
- 设置保留既有开关与持久化值，新增主动「体验震动：轻击 · 重击 · 格挡」。关闭、退后台、退出/重置战斗会取消待播与当前图样。
- 16ms 内聚合最高优先级反馈，正式连续战斗使用攻击时间及敌人 ID 去重。160ms 节流，滚动一秒最多三个图样，战败允许覆盖。事件不延后排队补播。
- 移除主线旧统一中等反馈和选敌/出手提前震动。旧回合演示的玩家伤害共用新入口；未把独立 Dungeon 原型及暂停铃试演当作正式主线验收范围。

## 文件

- `Mistport/CombatHaptics.swift`：原生调度、取消、图样与降级。
- `Mistport/ChapterOneTestView.swift`：实际事件接入。
- `Mistport/GameSettingsView.swift`：开关取消与试听。
- `MistportCombatCore/CombatHapticsPolicy.swift`：可独立验证的事件策略与频率限制。
- `CombatHapticsPolicyTests.swift`：6 项策略测试。

路径均相对于 `mistport-ios`，Core 源码及测试分别位于其 `Sources/MistportCombatCore` 与 `Tests/MistportCombatCoreTests`。

## 验证与边界

6 项策略测试通过：正伤害/功能技能例外、HP/盾/假面分流与毒伤、群体重复事件、优先级抢占、滚动预算、第四关相隔 0.65 秒的两次拦截及重置。日志 `/tmp/mistport-haptic-policy-tests.log`。

Build 26 已安装到已配对 iPhone 13，并成功启动。安装前后 Preferences plist 内容一致，存档及设置保留。安装/启动回执与存档备份在 `backups/combat-haptics-20260915`。

最终 iPhoneOS 构建通过：`/tmp/mistport-haptics-build26-final.log`。源文件与原工程备份在 `backups/combat-haptics-20260915`。

策略测试和构建不能证明手机触感。第四关连续三轮挡击、第五关毒伤静默的实际手感、开关和后台取消，以及十分钟舒适度仍需真机操作复核。未宣称触觉验收通过。
