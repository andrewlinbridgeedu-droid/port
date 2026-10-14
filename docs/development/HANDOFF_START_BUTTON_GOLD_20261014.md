# 开始战斗恢复金色渐变 · 2026-10-14

用户截图要求将白色“开始战斗”恢复为以前的金色渐变。基线eaece4f，分支codex/playtest-ui-20261012。

从历史提交5fbc35c取回原色：顶部(1.00,0.96,0.72)，中段(0.96,0.72,0.22)，底部(0.72,0.38,0.08)。在ChapterOneTestView.swift的BattleStartButtonChrome统一设置渐变，去除独立预览及正常主线setup入口的局部白色覆盖；“请选择N张技能”也继承相同样式。当前金紫羽化背景、布局、按钮行为、选牌和经济规则未修改。

仅完成源码修改及Swift语法检查，不启动Unity／Xcode构建，不操作手机，不宣称171.6已包含本次变化。机构会话可将本次提交合入当前Swift宿主；保留其银行、付费晋阶、住宿、会客和隔离存档改动。

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
