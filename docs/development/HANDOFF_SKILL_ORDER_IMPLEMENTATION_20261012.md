# 十张技能与四格编排接入交接

最终设备版本：**169.86**（已安装、静音隔离核验完成）。

日期：2026-10-12；分支 `codex/playtest-ui-20261012`；开发基线 `7c572ae`。用户授权实装技能重做与区分鲜明的卡牌，并沿用完成后 commit、push、handoff 的要求。

## 实装范围

第一章十张普通技能选四张，严格左到右循环；下一位未冷却则等待并普攻，封牌临时跳过。所有普通技能CD7秒，拖换位置后受影响卡重置完整CD。新11抢拍提高施法/收招速度；新12固定1.8秒引导，常速3发、全加速6发；新13按2.6秒内实际技能命中累积爆炸。伪证、转换、双影、归结围绕4秒标记窗口；后手延时兼净化护盾；反客驱散增益创造错位。详细数值在 `mistport-ios/MistportCombatCore/Sources/MistportCombatCore/OrderedSkillRules.swift` 与目录说明中。

规则、观看和即时结算共用原生命中时钟，Unity收到首/末次命中时间做演出；额外命中不会抢掉正在释放的其他法术。多段伤害沿用遗落物与装备入口。旧技能ID与等级保留；新技能按关卡资格解锁，不重复发首通或货币。Q3/4假面和双喷保留；按天开放未改；Q28/29仍是五次完整行动。

十张1024×1536卡面已分别接入`FoolOrderedCard{01,04,05,06,07,08,09,11,12,13}20261012.imageset`。旧素材保留，生成提示记录在`tools/skill-order-lab/card-art-prompts-20261012.json`。

多数正式伤害关加入可见追逼压力，开始时间按关卡配置在`pressureStart`；每4秒逐层翻倍，上限8层。Q1–4、Q20、Q28–30保持自身教学/目标/狂暴。这个机制针对无限续航，不能解释成检测错误牌序后直接判败。

输入记录版本升级：`story-battle-v3`、`church-battle-v4`。后端如运行旧CombatCore，需同步编译部署；本任务未擅自部署远端服务。

## 验证与交付记录

- 最终相关回归：119 项 / 16 suites 全通过，日志 `Mistport-build-cache/ordered-regression-final.log`；Q1–13 最终源码补跑通过，日志 `ordered-audit-early-final.log`。
- 正式 Q1–30：7 类配牌族的去重排列，共 4,109 次；24 关存在同一组四张牌换序后的胜负分化、30 关都找到胜序。每次使用合法阶段装备、天赋、遗落物，不用药；Q3/4仍手动防御重击。不是 5,040×30 的全枚举，也不是真人通关。精简结果与胜负例子已入库 `tools/skill-order-lab/production-audit-20261012.json`，完整结果在 SSD `ordered-chapter-audit-v3-early.json` / `ordered-chapter-audit-v2.json`。
- 差异仍有边界：抽样中有12个顺序能在固定成长夹具下通吃Q12–30；本轮不能宣称“每关必须换一套牌”，也未完成塔100层全量再校准。
- 同样四张牌的真实 Q12 回归：`抢拍→连弹→错步→伪证` 通关剩24HP；只交换前两张，倒下时敌人剩617HP。测试 `swappingHasteAndBarrageChangesARealMissionOutcome`。
- 回归包含连弹3/6发、加速中途到期、四秒状态、拖动0.05秒重置7秒、跨波取消余下命中、整招保留伤害加成、旧档幂等迁移、终极技不重置普通牌游标、普通观看/即时结算重放、封牌清除与Q3/4假面。
- `scripts/build_hero_v4.sh device 169.84` 成功。Unity先导出、Freshness通过、宿主编译通过；最后Swift修正后再次检查新鲜度并增量构建，`build-final-169.84.log` 成功，codesign深度校验通过。没有在导出后修改Unity脚本。
- `devicectl`查询旧版169.83，安装169.84成功。安装前后267个Preferences文件SHA-256完全一致；报告 `preferences-install-comparison.json`。iOS锁定拒绝启动后，用户解锁，静音隔离预览启动成功；后续镜像实测记录见下。
- 卡面联系表 `artifacts/skill-order-20261012/card-art-contact-sheet.png` 已自查十个主体/主色；自查和构建成功不代表用户认可。

本机全库测试在变更前的独立`7c572ae`源码副本也因旧测试夹具的nil/数组越界中断（`ChurchCancelledContactTests.swift:85`及塔测试）；需区分历史测试负债与本次新增回归。完整日志保留于SSD `Mistport-build-cache/ordered-baseline-*.log`，不会把不完整全库测试写成全绿。

## 玩家数据边界

实时设备查询确认169.83，选择169.84。归档、DerivedData、日志在 `/Volumes/andrew's SSD/Mistport-archives/releases/Mistport-169.84-ordered-skills-20261012-codex-01a12f14`。安装前后须逐文件比较Preferences；视觉演练使用隔离预览，不推进真实或盲玩档。盲玩仍暂停在之前记录的Q12，不能称第一章已盲玩通关。用户面包任务已经刷新过，本轮不得重复刷新。

## 真机发现与修正版

169.84 隔离 Q12 预览已看到两页共10张独立卡面，四张能加入上排，第五张被拒绝。随后发现 App 把 systemUptime 当作战斗时间，“追逼”在战前即显示8层，导致过早失败；Swift stepper 从0起步，原规则测试无法覆盖宿主这一差异。169.84不得作为最终交付包。

修正：App逻辑战斗时钟初始/接收新局/重试均归0，仅用systemUptime计算帧增量；重试还重置轻击时钟。独立预览也补齐“请选择4张技能”的开打门槛。版本由设备实查169.84加一至169.85，重新通过标准脚本导出、核对新鲜度并构建。正式规则未改变，上述规则审计仍适用。169.85真机确认战前16秒保持不动，开打后递减；重试恢复16秒。

169.84隔离演练结束，267个既有Preferences文件全部不变，仅增加2个daily-pacing隔离验证文件（269总数）；真实档与盲玩档未变。证据 `preferences-after-qa-comparison.json`。修正版新备份位于 `Mistport-169.85-ordered-clock-20261012-codex-01a12f14/preferences-before`。


## 同轮战场空间调整（2026-10-12 22:15 用户截图）

- 状态格从23pt改17pt、间隔3pt改2pt；仍置于对应血条下，保留层数。
- 遗落物和补给移到64pt纵向侧栏，默认右侧；顶部箭头一键换边，位置偏好保存。数量多时纵向滚动；假面、勋章、铃和药品仍保留原操作与冷却/次数反馈。战前选择与战中发动分开呈现。
- 底部普通牌库面板最小高度154pt改98pt，卡面70pt不缩小；底部留白缩到4pt。已编排四张牌仍在牌库上方，可以拖换次序。
- Unity `EnemyPresenter.BattleScale=0.8`、`BattleRetreat=(0,0,0.9)`；Present和Reposition均使用绝对值，四敌阵、塔怪和猎犬的专用尺寸入口同步乘系数，换波/重试不累计缩小。近战走近主角的接敌规则保持。
- 22:13启动的169.85宿主构建因新需求中止，22:29再次运行完整标准构建，包含上述Unity与SwiftUI修改。169.85完整构建成功并安装；下述设备截图只是开发者自查，不代表用户视觉认可。

补充验证：执行现有 `EnemyPipelineSelfTest.RunBatch`，确定性归一化/重复装配/换位检查未报错，但整套检查因两个资料共用 `hell-hound` ID 失败（Generated/HellHoundVisualProfile 与 Signature/HellhoundSentinel/VisualProfile）。两份重复ID在基线7c572ae中已存在，本轮不修改旧资产身份；完整日志 `enemy-pipeline-self-test.log`。不能将此检查记为通过。


## 169.85 设备自查（22:38–22:43）

- 安装前后269个Preferences文件完全一致，报告 `preferences-layout-install-comparison.json`。
- 静音隔离启动成功：`-MistportCityMute YES --developer-tools --verify-daily-pacing --preview-chapter-one-mission=12`。未使用真实档或盲玩档参战。
- Q12两敌：右侧栏→左侧栏→右侧栏均可点击切换；四张技能可选择、战前与战中拖动可换序。卡牌棚下移后不再占据原遗落物整行。
- Q12战中：血条下可见紧凑状态格及1/2/4层数字；右侧假面点击后出现幻影、两枚承伤点及主角状态数字。此轮药品点击发生在倒下边界，剩余仍1，不能记为用药成功。
- Q12跳过：点击后进入“正在结算战斗”，随后出现失败统计。并非硬改胜负；这份隔离预览未套用规则审计中的阶段装备，因此不能把规则审计的胜序剩24HP直接当作本次设备结果。
- Q3猎犬：与旧版截图对照，身体明显缩小、脚位后移。此轮只检验布局/尺寸，操作未赶上教学假面时机而失败，不作为双喷或第一章通关的新证据。
- 截图目录：`Mistport-169.85-ordered-clock-20261012-codex-01a12f14/device-qa`。关键文件 `16985-q12-left-rail-four-cards.png`、`16985-q12-live-status-drag-mask.png`、`16985-q12-retry-clock-reset.png`、`16985-hound-after-layout.png`、`16985-q12-settled-result.png`。
- 测试结束逐文件核对：269→271，仅新添2个daily-pacing临时验证文件，隔离壳plist只有`mistport.combatItemsOnLeft`变化；真实档与盲玩档的SHA-256均不变。报告 `preferences-layout-qa-comparison.json`。

## 最终修订 169.86

复看169.85重试截图发现上一局受击红边仍在：逻辑时钟归0后，`playerHitFlashUntil`仍是上一局的时间。新局/重试同步清除此截止时间、拖动暂态；重试还清除`didSkipBattle`/`isFastForwardingBattle`，避免前次跳过标记外溢。规则数值与169.85的Unity资源不变。

设备再次实查169.85，加一为169.86。归档 `Mistport-169.86-ordered-layout-20261012-codex-01a12f14`；Derived在SSD做APFS写时复制，保留169.85构建目录，继续完整标准脚本导出→新鲜度→宿主。标准构建与codesign深度校验通过，169.86安装成功；安装前后271个Preferences文件逐文件SHA-256完全一致（`preferences-install-comparison.json`）。最终隔离重试核验首次启动被iOS拒绝，返回Locked；用户解锁后于22:56成功静音启动，再锁屏恢复镜像。22:58实机完成四牌开打→跳过结算→重试；红边消失、血条回满、倒计时归16秒且停在战前。证据 `device-qa/16986-q12-skip-settlement.png` 与 `device-qa/16986-q12-clean-retry-settled.png`。

测试结束已终止隔离进程。271个既有Preferences文件全部不变，仅新添2个daily-pacing临时验证文件（273总数），真实档与盲玩档SHA-256都不变，报告 `preferences-qa-comparison.json`。代码提交 `b9015a4` 已推送到 `origin/codex/playtest-ui-20261012`；本次补充交接提交只记录最终设备证据，不改构建源码。
