# 交接：战斗中的主角动作轮换 · 2026-10-12

接在 [169.80 出招节奏交接](HANDOFF_PLAYER_CADENCE_20261012.md) 之后。用户要求将已有多个视频动作实际展示在每次战斗中；随后明确“不需要技能对应动作”，只要忙碌、被打时一律展示被打并让出招停滞一下。以这一最新要求为准。

## 实现

当前装机主角使用 `AIHeroAnimatedBody` 的五套视频动作图集：斜切、指令弹指、过肩抛投、按印、侧手施法。此前普攻和错步都固定选择斜切，少量卡牌的战斗会反复播放同一套动作。

现在每个主角身体持有一个独立 `MotionSequence`，所有普攻和技能直接轮换五套动作，不按技能分动作池；连续两次不重复。五次真实出手会用到五套，实际短战展示的数量取决于出手次数。

选择器不读写规则、冷却、随机数或 Preferences。每个视频片段仍以自身 releaseFrame 对齐该卡原有命中时间。每次有效受击都会触发明显的摇晃、下沉和短促压缩，同时把出招画面停住约 0.1 秒，然后恢复。动作时间仍跟随规则时钟，暂停期间保持可见帧；技能命中与 CD 继续由规则控制。自然收招现使用 `FinishAction`，不会再把刚发生的挨打反应清掉；离场／倒地仍由既有清理和倒地表现接管。

## 验证与导出检查修复

- `HeroMotionVariationVerification.Verify` 在实际 Unity 环境检查三套服装共 15 个动作的图集、待机图及命中帧信息。
- 12 种普攻／开局卡／双卡／各技能与普攻序列调用真实 `AIHeroAnimatedBody.PlaySkill`，覆盖五套动作且相邻不重复。还实例化真实身体验证受击时帧保持、停顿后恢复、末帧挨打不被收招清掉及离场清理。最终通过日志为 169.81 归档 `hero-motion-final-body-verification.log`。
- 新增 C# 类型后 IL2CPP 将必需的 `BattlePrototype_UseDualClockGuardModel` 移到 `Assembly-CSharp__1.cpp`。旧新鲜度脚本只查 `Assembly-CSharp.cpp`，产生误报。脚本现在搜索全部 `Assembly-CSharp*.cpp`，仍要求元数据、导出版本和完整 1191 项源码／资源哈希精确一致。首轮与修复后的导出日志均保留。
- 169.80 相关规则测试 31 项已通过。169.81 只改 Unity 表现和导出校验脚本，继承主角 1.1 秒技能回复／0.8 秒普攻回复。

## 构建与设备

工作树 `/Volumes/andrew's SSD/Mistport-worktrees/main-9cab331-codex-01a12f14`，分支 `codex/playtest-ui-20261012`。本轮表现及导出校验提交 `06d5463da290619b586f813f359b909a984d2aa4` 已 push。

实时手机版本 169.80；选择下一版 169.81。归档 `/Volumes/andrew's SSD/Mistport-archives/releases/Mistport-169.81-9cab331-hero-motion-20261012-codex-01a12f14`。用 `scripts/build_hero_v4.sh device 169.81`：Unity 导出 → 新鲜度检查 → 宿主构建。最新用户简化规则后的最终管线为 `pipeline-final.log`；此前中间包未安装。DerivedData 和日志全部在 SSD，上一包保持独立。

最终 `pipeline-final.log` 确认新鲜度及宿主构建成功，169.81 深层签名检查通过。用户锁屏后重新取得最新 Preferences，169.81 已安装；实时 `devicectl device info apps` 的 `bundleVersion` 为 169.81（`version` 是营销版本 0.1.0）。安装前后 266 文件逐项 SHA 核对完全一致。最后一条初次设备查询因 StreamingAction 连接中断失败，恢复镜像后复查成功，证据为 `apps-after-install-retry.json` 和 `installed-version-verification.json`。

## 169.81 真机演练

静音参数为 `-MistportCityMute YES --developer-tools`。隔离预览追加 `--player-test-audit --verify-p1-ui`，从合法解锁状态创建内存战斗，不修改玩家或盲玩进度。

- Q5 单卡试演：错步与普攻实际轮换五套动作；完整运行日志有 25 次出手、1 次非致死受击，发生于指令弹指期间。
- Q9 双卡试演：Q1–Q8 奖励在预览内存中解锁两张牌，选择错步与张冠李戴。完整日志有 19 次出手、五套动作均出现，相邻不重复；4 次非致死伤害均对应 `AI_HERO_HIT`，其中 3 次在出招中触发。最终致死伤害走原有倒地表现。双卡连续出手和原有技能命中已补真机记录，未领取正式奖励。
- `device-evidence/q5-motion-sampled-mirror.mp4` 为 137 帧约 14 秒镜像采样；`q9-two-card-sampled-mirror.mp4` 为 112 帧约 22 秒镜像采样。帧文件与时间 JSON 保留。复看截图可见不同手势、侧身、受击及血量变化；录像采样间隔不能用来精确量出 0.1 秒，停帧时长由实际身体自动验证及真机触发日志支持，尚未取得用户视觉认可。
- 对应 `q5-motion-runtime-verification.json`、`q9-motion-runtime-verification.json` 和 Q9 敌我接触记录均在归档。真机第九关证明已解锁双卡能连续播放；新档第五关仍只有一张普通卡，不宣称第五关天然已有两张。

演练结束后已用 `--player-test` 静音恢复真实档至标题，截图为 `device-evidence/real-player-title-after-resume.png`。

## 测试范围和存档

169.80 已安装，安装前后 266 个 Preferences 完全相同。第五关的隔离演练采用新档当时合法的一张错步卡和自动普攻；接触日志确认出招衔接已缩短。该演练后的 266 文件中仅隔离遥测 plist 有变化，真实档和盲玩档未变。双卡的 Q3／Q4／Q5 同节奏结论来自明确配置双卡的规则夹具，不能写成新档第五关自然已解锁第二张卡。

169.81 安装与隔离演练期间，真实档和盲玩档均保持逐字节一致；演练后 266 文件仅 `mistport.p1-ui-verification.plist` 变化，见 `motion-test-preferences-verification.json`。恢复真实档后，正常前台启动触发新一天日账：新增 739902 的码头铺位／汤棚付款 12 铜，余额 330→318，并刷新满体力的结算时间；已有付款保留。遗落物数组顺序和 JSON 序列化顺序有变化，语义无增删。`real-resume-semantic-verification.json` 严格确认除此之外无变化，主线／物品／战斗权益不变，盲玩档仍逐字节一致。没有用备份恢复或覆盖真实档。所有三阶段快照及 SHA 差异报告保留，不能把最终启动后写成所有文件完全相同。

盲玩仍按用户要求暂停：主线 Q12、B01 三证据、塔 14 已过。演练不操作真实进度，也不推进盲玩档。每轮安装前重新获取手机最新 Preferences，不能恢复旧档覆盖玩家亲测进度。

后续无名宣告卡面状态修复与终战实测见 [169.82 无名交接](HANDOFF_ULTIMATE_CARD_STATE_20261012.md)。
