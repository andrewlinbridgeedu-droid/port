# 开始战斗恢复金色渐变 · 2026-10-14

**171.7 已构建并安装到 iPhone 的“雾港·机构试玩”**（local.mistport.institutions）。设备安装前查询为171.6，本次加一；安装后devicectl实际查询为171.7。保留当前机构经济、银行、付费晋阶、住宿、会客与底部卡牌／右侧遗落物整合。

金色源码提交为788446e，基线eaece4f；已push到codex/playtest-ui-20261012。只恢复开始文字颜色，不改战斗规则。历史提交5fbc35c的顶部(1.00,0.96,0.72)、中段(0.96,0.72,0.22)、底部(0.72,0.38,0.08)统一放在BattleStartButtonChrome；去除独立预览和正常主线setup的局部白色覆盖。“请选择N张技能”同样继承渐变，现有金紫羽化背景保留。

## 本次构建与真机核验

用户随后要求“建”，本次仅将ChapterOneTestView.swift的金色补丁应用到根工程；没有重置或提交机构会话的其他本地改动。根工程HEAD为493918c，含尚未提交的机构整合，不能把整包描述为788446e的干净构建。

归档、DerivedData和日志均在外置SSD会话目录：
`/Volumes/andrew's SSD/Mistport-archives/releases/Mistport-171.7-start-gold-20261014-codex-01a12f14`。

顺序：Swift语法检查 → scripts/check_institutions_art_baseline.py → scripts/export_current_unity_art.sh物理副本导出 → 独立Unity新鲜度检查 → Xcode宿主Debug/iphoneos build → 系统环境codesign深度严格检查 → devicectl安装。机构构建使用其独立bundle及显示名、CURRENT_PROJECT_VERSION=171.7、jobs=3、allowProvisioningUpdates；未使用会改回原App标识的旧工作树构建入口。现有build_institutions_playtest.sh仍默认171.6，后续构建须显式更新版本及使用新的归档路径。

静音启动参数为`-MistportCityMute YES --developer-tools`。附加`-institution.profile gold1717-20261014-codex-01a12f14`使用全新隔离suite；实际新增plist已读回确认，未切换玩家进度profile。正常主线Q1的金色开场文字已通过iPhone镜像实看，见本会话工具截图。另查看隔离Q1/Q2场景及Q5预览；独立保存的q1-isolated-combat-1717.png是后续战斗帧，不能冒充金色按钮的独立截图。本次不宣称完整关卡通关、逐招法术视觉认可或机构全库测试重跑。

## Preferences逐文件核对

- 安装前备份当前机构容器全部10文件；安装后10／10 SHA256一致，无新增／缺失／修改。
- 隔离启动后原10文件一致，仅新增本次金色测试profile。
- 测试结束后玩家进度profile仍未改；标准设置local.mistport.institutions.plist新增institution.profile=fresh、mistport.combat.presentation-speed.v1=1。差异已逐键分析并留证。
- 仅把此标准设置文件恢复为安装前刚备份的原件，没有恢复或写入任何玩家进度profile。再次读回：原10文件全部SHA256一致，无修改／缺失；唯一新增为本次隔离测试profile。
- 测试进程已结束，下次正常图标启动继续原有试玩档。未重复发放真实首通或经济权益。

证据均在归档evidence/：apps-before查询、apps-after-install.json、install.json、source-manifest.json、preferences-install-comparison.json、preferences-standard-semantic-comparison.json、restore-standard-settings.json、preferences-closure-comparison.json和各次launch/terminate记录；logs/保留Unity、freshness、Xcode、签名、设备命令日志。真实Preferences原件只留SSD，不能提交到Git。

## 同轮只读普攻来源核对

供“完善机构与银行功能方案 (2)”合并后咨询使用。本工作树的普攻源码没有未提交新版；当前根工程FoolBasicTarotVFX、SpellSpectacle20260926、AIHeroAnimatedBody物理SHA与eaece4f相同。可见另两个工作树是更早来源，未发现遗漏的已交付新版普攻。用户新交三段队友视频未接入，不涉及普攻。

正常主线路由：ChapterOneTestView.tickContinuousCombat -> basic:<目标ID> -> UnityBattleBridge -> BattlePrototype.PresentPlayerBasic／PresentPlayerAction(Basic)。AI身体通过CombatTempoPresentation.HeroCast("basic") -> AIHeroAnimatedBody.PlaySkill轮换五套动作，06d5463已在eaece4f中。

FoolBasicTarotVFX保留物理塔罗牌，0.16秒离手、0.58秒报命中，命中后0.16秒淡出；FullScreenOverlay=false。SpellSpectacle的basic -> paper／Form.Flick额外负责飞行和命中。当前SolidAll=true，飞行优先使用SpectacleFlipbook.shader + TarotFlight.png的原画翻页飞牌，并保留沿途光点／闪星；LaunchShots中旧几何宽带及双亮带在solid分支不绘制，不能仅凭旧注释把它们当成现行全部画面。

命中优先InkHit：InkStrokes=true、paper -> burst、尺寸half*0.24。Ink2D.Burst为紫粉／浅粉芯的手绘炸裂光团，快速展开、单个短暂冲击环、卷曲光丝外散及光点／碎屑；主体在寿命60%前退出，末尾散尽。基础寿命0.62秒，命中层HitPace=0.7，约0.89秒游戏时长（×2等时间缩放另计）。此分支replaces=true，跳过较早的Form.Flick斜划／旋开牌片命中回退。不是早期169.52–59大团弯丝方案的现行重播。

可能看起来像旧版的源码分支：
- 缺少Resources/SpellSpectacle20260926/SpectacleInk20261008.shader导致inkMaterial为空，InkHit返回false，回退到Form.Flick旧命中流程；此shader缺失不一定触发通用MISSING_RESOURCE警告。
- 缺少SpectacleFlipbook.shader或TarotFlight.png，tarotMaterial为空，SolidShot回退到旋转的TarotFront／TarotBack牌片。
- SpellSpectacle.Suppressed、Load失败或没有注册／消费Contact，可能只见FoolBasicTarotVFX的老物理牌。
- tempo.HasHero／hero.ai未成立时走PrepareCompactPlayerBasic或旧body动作；Swift未使用Unity时走DungeonScene.presentFoolBasicAttack。

这些是静态分支核对，不是171.6运行时复现或诊断结论。文件及Unity Data一致不能单独证明实际分支、材质加载、目标绑定或命中cue消费正确；此咨询没有构建、安装或设备操作。
