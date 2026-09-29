# 每日玩法任务 1.2：工坊接入 · Build 164 · 2026-09-29

## 实现

- `mistport.daily-workshop.v1` 保存制作、订单、塔材料战斗凭据和修理回执，带 `migratedAt`。旧档迁移为空账本且只写一次；旧检修单记录和已领取奖励保留。
- 所有新塔战登记材料凭据，胜利调用 `MPCTowerMaterials.drops(floor:)`，首通和重打都按每个恶魔身体掉料。重复回调不重领，败退凭据作废；旧版进行中的 F1 凭据继续按旧规则结清。
- 四个基础配方、十件装备调用 `MPCCraftingLedger.craft`，按主线/熟练度开放，每天前五次成功制作计熟练度；转运站绑带制作也改走同一账本，避免旁路。制作、库存、铜币、装备和账本在同一教会写前回执里提交。
- NPC 订单调用 `MPCWorkshopOrderBoard`，每日预算、最多积累三天和防重复交货由规则库执行。现有一次性检修架的交付/安装继续保留，不重发旧奖励。
- 新制作与订单传入事件 `surcharge`/`bonus`，通过 `mistport.city-events.v1` 的账本读取效果；任务 1.4 尚未创建事件账本时不施加不可参与事件的惩罚，事件板完成后接通。
- 工坊装备按已过塔层穿戴，按规则磨损并计入塔层检定；在工坊、角色装备页、封线装备页显示档位/耐久及修理按钮。修理有回执，重复调用只扣一次材料。
- 工坊四类手艺页显示材料库存/需求、底料价、配方门槛、每日熟练上限和订单剩余预算；沿用既有插画和按钮资源。

## 验证

- Mac `Crafting|Workshop|ChurchGear` 相关 24 个测试、5 个 suite 全过。
- Build 164 完整 `xcodebuild` 成功，Unity 导出新鲜度检查通过；未修改 Unity 运行资源。
- 真机 `--verify-daily-workshop` 通过：一次迁移、Q5/第3天开放、每日五次熟练、重复制作/交货、有限订单、塔首通/重打材料、退场凭据、全部14配方、穿戴门槛、塔层检定、磨损/修理各一次、重启。
- 原六组自检仍全部通过；旧 `--verify-local-workshop` 17 项检查通过（检修单一次性支付、库存/余额/制作记录恢复等）。见 [自检日志](debug-checks.txt)。
- 装机前后 **103/103** 个 Preferences 文件逐字节一致。真实玩家仅新增 `mistport.daily-workshop.v1`，所有旧键未变。自检后仅三个显式隔离 suite 有预期变化，其他原文件不变。见 [迁移](migration.json)、[最终比对](verification.json)。
- [Build 164 真机窗口截图](workshop.png) 来自 `--daily-pacing-device-walk --daily-workshop-preview`：独立第3天存档、当天做过6批绑带，实际熟练为5，未使用真实玩家存档。

完整日志/Preferences 备份：独立工作树 `output/daily-workshop-20260929/`。
签名包：`/Volumes/andrew's SSD/Mistport-archives/releases/Build164/Mistport.app`。
工作树：`/Volumes/andrew's SSD/Mistport-worktrees/daily-work`；DerivedData：`/Volumes/andrew's SSD/Mistport-build-cache/daily-work-dd`。

## 未验证

用户尚未认可界面/手感；没有进行真人制作、卖货与塔战计时。截图仅证明对应页面实际渲染，不能代替14个配方逐一手工操作或装备视觉验收。事件、街坊、残余案及日刊后续任务仍待做。
