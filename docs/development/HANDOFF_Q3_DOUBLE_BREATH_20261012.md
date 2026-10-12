# 交接：Q3 猎犬双喷、连续咬击与比例修复 · 2026-10-12

> 主角在非样本关卡的出招回复间隔后续统一，见 [169.80 节奏交接](HANDOFF_PLAYER_CADENCE_20261012.md)。

接在 [169.77 试玩交接](HANDOFF_PLAYTEST_UI_20261012.md) 之后，以本记录覆盖其中 Q3 可不使用假面的旧结论。用户要求猎犬一定连续喷两次，节奏符合假面 CD；采用正常伤害和攻击时钟，没有额外的假面使用次数结算门槛。

## 最终行为

- Q3 首轮第 2 秒、3.4 秒起手，第 3.1 秒、4.5 秒命中；每 20 秒重复。一枚假面维持 4 秒、挡两次，18 秒 CD，下一轮仍有反应余量。
- 双喷之间第 6、9、12、15、18 秒起手咬击，接触后正常扣血。相邻起手最大间隔 4 秒，解决只喷两次后长时间不攻击的问题。
- 喷吐每次造成基础生命 90% 的伤害；新档连吃两次会败，药膏和最大初始护盾也不能代替假面。猎犬生命 1200，正常开局卡序不能赶在双喷前击杀。
- 观看与跳过共用 App 战斗推进与规则；跳过不会自动代按假面。Q4 继续使用自身三轮双火规则。
- 猎犬忽大忽小的确定根因在动画资产：Walking 的 Hips 缩放约 0.7953795，新生成的攻击动作原为 1，切换时会放大约 25.7%。生成器现在保留导入 Walking 的基准骨骼缩放，并在每段新动作写入一致缩放。仅重生成 Hound，不重制其他角色。

## 主要源码和素材

- `Mistport/ChapterOneTestView.swift`：按 Q3 实际攻击序号排时钟，重试／重新配置清零；假面教学提示。
- `MistportCombatCore/BattleContactTiming.swift`：`MPCQ3HoundTiming` 共用双喷及咬击时刻。
- `MistportCombatCore/BountyRelics.swift`、`ChapterOneEncounterRuntime.swift`：Q3 生命、伤害与七次攻击循环。
- `Mistport/ChapterOneOnboarding.swift`：双喷和中间咬击的教学文案。
- `tools/animation/build_tempo_samples.py`：基准缩放和 `--kind Hound` 的定向重生成；对应 Hound.fbx 与可编辑 Hound.blend 已更新。

## 验证与交付

工作树 `/Volumes/andrew's SSD/Mistport-worktrees/main-9cab331-codex-01a12f14`，分支 `codex/playtest-ui-20261012`，前一提交 `9c113e9`。

169.78 已安装，266 个 Preferences 安装前后逐文件 SHA256 相同。该版仅双喷，用户发现的攻击间歇和比例问题在随后 169.79 修复。

169.79 归档 `/Volumes/andrew's SSD/Mistport-archives/releases/Mistport-169.79-9cab331-q3-attacks-20261012-codex-01a12f14`：

- 手机实时查询为 169.78，下一版 169.79；新归档含会话后缀，DerivedData、日志均在 SSD。
- `scripts/build_hero_v4.sh device 169.79`：重生成 Hound 后重新 Unity 导出 → 新鲜度核对 → 宿主构建。归档中的 `pipeline-model-fixed.log` 为最终管线，较早 `pipeline.log` 不含模型比例修复，未安装。
- 规则测试：Q3、假面和 Q4 相邻回归共 13 项，通过；覆盖一次假面挡双喷、下一轮 CD、咬击扣血、最大护盾加治疗仍失败、正常自动出牌有无假面对照。
- `verify_hound_scale.py` 独立解析最终二进制 FBX；`verify-hound-scale.json` 确认十段动作 XYZ 缩放完整且一致，所有 key 相对 Walking 基准最大误差 3.58e-7，小于 1e-5。
- 最终构建、深层签名检查和安装均成功，手机实时查询确认 169.79。`install-preferences-verification.json` 确认安装前后 266 文件完全相同。
- 受控真机 1× 对照：同一卡序（错步穿行＋自动普攻），不操作假面时生命 1000 → 100 → 0，两个命中相隔 1.4 秒，截图为战斗失败；重试手动按两次假面，四次喷吐均为 0 伤害，期间六次咬击各扣 88，余 472 生命演练通关。没有使用跳过按钮。证据在 `device-evidence/` 与 `q3-device-contact-evidence.json`。
- 已复看走路、喷吐、扑咬与受击截图：切换动作没有再出现原来的约 26% 骨骼放大；扑咬保留向主角跳跃的动作。资源数据修复和本次截图核验不代替用户视觉认可。
- `test-preferences-verification.json` 确认测试后仍 266 文件，仅隔离遥测 `mistport.p1-ui-verification.plist` 有变化，其余 265 文件（含真实档、盲玩审计档）完全相同。
- 最后以 `-MistportCityMute YES --developer-tools --player-test` 重新启动正常玩家入口，停在“进入雾港”标题页，未代玩真实进度。

## 存档与后续

用户已明确授权真实进度重置，169.77 归档 `user-reset-to-start-1510` 保留重置前旧档。之后每次安装都重新获取手机最新 Preferences，不能恢复早期初始档覆盖用户游玩。169.79 安装前仍有 266 个文件，真实档与 169.78 安装后一致。

盲玩代理暂停在隔离审计档：Q11 已过、Q12 待重试、塔 14 已过；第一章通关和 Q28–Q30 真机盲玩仍未完成。当前检查使用隔离 Q3 演练，不操作真实进度。169.78 的一次镜像操作被工具报告外部操作并中断，随后看到演练完成，不能作为受控双喷或假面通过证据。
