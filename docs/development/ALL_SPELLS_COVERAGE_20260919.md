# 全法术覆盖审计 · 2026-09-19

本记录是源码只读路由审计，不是运行或视觉验收。依据当前 AGENTS.md 末尾（D02 少而大片方向）、UnityBattleBridge、BattlePrototype、实际专属演出与原生按钮。没有运行 Unity、没有改战斗代码。增强目标为细节、炸裂、绚丽、光彩、面积，同时避免细碎均匀放射、规则圆环和全屏白光。

## 真实入口与主角

`UnityBattleBridge.ApplyCommand` 将 `skill:*`、`enemy:*` 分别传入 `BattlePrototype.PresentPlayerSkill/PresentEnemyAttack`。九张现役技能 ID 为01、02、04–10；03纸人只留旧兼容，不应复活为正式技能。

| ID | 技能 | 实际演出 |
|---|---|---|
|01|错步穿行|FoolEffekseerSkillVFX → FoolTarotStrikeVFX（单双目标独立）|
|02|假面谕令|HeroIdentityTheatreVFX；正式手动遗物另走 masquerade，不等于此卡预览|
|04/05|身份错置/伪证烙印|HeroIdentityTheatreVFX|
|06/07/08/09|错影追猎/荒谬归结/反客为主/后手改写|HeroArcanaTheatreVFX|
|10|无名宣告|NamelessDeclarationVFX，另有 ArcaneDustFlow|

`SpellBridge.CanPlay` 注册表优先分支存在，但实际 Registry 没有上述 fool_skill_* 项；不能只改 VFXV1 JSON 就声称九招覆盖。普攻走 `PresentPlayerBasic`，与九招不同，是武器基础攻击；应分列伴随反馈，不计新增法术。主角受击/回血飘字也不是新法术。

## 主线敌方演出全集

| 群组 | 真实路径及必须包含的表现 |
|---|---|
|Q1/Q2与复用幽灵|PresentFogGhostCast → SpellBridge：projectile-fog-chime-v1 / projectile-ghost-wisp-v1；Q2分裂赤幽灵也需看实际编队|
|早期犬 Q3/Q4/Q16|旧犬独立路径；Q4HoundPresentation小火球/双大火球、蓄力；不能用新犬熔火替换|
|铠甲犬|SignatureEnemyPresentation → EnemySignatureSpellVFX.Hound 两variant；脚下火旋缩，禁止恢复火球|
|翠焰亡灵 Q5/Q19|EmeraldRevenantPresentation / EmeraldRevenantSpell：开场持续毒雾及蓄力重击；另有 EncoreBellPresentation 历史路径|
|档案门卫/档案机械守卫|Signature → EnemySignatureSpellVFX.Archivist + ArchivistMechanicalSpell / IronVaultArmProjectile；两variant；ArchiveEncounterPresentation防御盾为独立状态，前方悬浮/旋转免伤盾不发射|
|织幕女主|Signature → EnemySignatureSpellVFX.Matriarch（独立partial）：绸带/针阵两variant|
|记忆蛭|MemoryLeechPresentation.Cast；ArchiveEncounterPresentation.SetLeech蓄力|
|寄忆核心|RotateClockCoreCast；repair_guard → ArchiveEncounterPresentation.Repair，enemy-heal → HealConfirmed；回血只本体绿，不恢复已否定的绿连线绿圈|
|书记员/救援者/执行者|StoryEnemyPresentation20260916，isScribe/isExecutor分别区分；不能只改Signature三族|
|裁决者/护送重卫|HeavyArchivePresentation20260916，isConvoy区分|
|总签官|ChronarchPresentation20260916.Strike；Q28/29活退、Q30死亡边界保留|
|基础空壳守卫|PresentClockGuardStrike内部武器轨迹/冲击；无专属组件的回退仍可见，不可漏Q29第三个守卫|

后半30关实际配置：16旧犬；17执行者；18/23裁决者；19亡灵；20/26护送重卫；21救援者+核心；22/25女主；24犬+幽灵；27档案机械守卫+犬；28/30总签官；29总签官+执行者+基础守卫。故“30关”不等于30套独立法术，要查所有复用与多实例。

## 塔六恶魔与通缉

|物种|动作|演出|
|---|---|---|
|D01 stonehide|guard/charge/recover、archive_slam|StonehidePresentation20260917及ChurchSpellVisual|
|D02 saltmaw|tower_sac_charge、tower_poison、tower_salt_spike|SaltmawSpell20260919 + SaltmawRadiance20260919 + Effekseer；最新少而大片基线|
|D03 shellback|tower_mend_charge、tower_mend、tower_short_pounce|ChurchDemonPresentation → ChurchSpellVisual|
|D04 ironclaw|tower_blade_charge/tower_raised_blade、tower_cut_first/second/heavy_cut|IronclawSpell20260918及光影/漫天层；保留已认可方向|
|D05 frilled-naga|tower_crown_charge、tower_empower、tower_sound_arrow|ChurchDemonPresentation → ChurchSpellVisual|
|D06 boneclaw|tower_claw_charge、tower_piercing_claw/tail_sweep/heavy_claw|ChurchDemonPresentation → ChurchSpellVisual|

共11伤害动作+2辅助动作，连D01盾共14组常用预览；起手蓄力另计，不能用命中增强替代。D03/D05有真实受益者，受益者死亡也要取消。

六通缉 **全部** 被 BattlePrototype 前置 bounty 分支截获，进入 `BountyIdentityPresentation20260917.Strike → ChurchSpellVisual20260917`；其母版模型即便挂Signature也不代表走Signature特效。OwnsStrike属性没有参与这个分支。六组包括b01 ambush、b02 bind、b03 heavy_strike（含护航身份变体）、b04 overwrite、b05 silk_bind、b06 guard/heavy_strike；准备还包括 bounty_bind_charge/bounty_copy_charge。必须单列覆盖，不能以主线母版升级推断覆盖。

`ChurchStatusPresentation20260917` 另处理 poison/empowered/bindings/escorted 持续状态，跨关停战清理必须保留。旧TowerHoundPresentation仍有兼容路由，已非正式塔六怪，不重新当塔内容交付。

## 遗落物及辅助表现边界

- 正式手动假面：原生发送masquerade:N / masquerade-hit:N → BattlePrototype.SetMasquerade → Mindstone.VFXV1.MasqueradePhantom及summon-masquerade-v1。九卡录制不能覆盖此正式入口。
- 僭命勋章：原生ChapterOneTestView按钮调用核心并syncVisualHealth；目前视觉是原生UsurpedMedalCrownEffect卡片层，未发专属Unity法术。不可把仅Unity增强说成勋章已重做。
- 空栏名片：原生按钮调用activateBlankNameCard，当前未发专属Unity演出。盐封呼吸囊及普通被动遗物主要状态/数值/UI，不自动等于存在独立Unity法术。
- guardian-ward-break / paper-double-* / encore-* 是保留兼容/试演入口，不能未经本次指令恢复被否定纸人或旧铃机制。
- enemy-heal、enemy-impact、药品绿字属于反馈，增强不能伪造实际恢复/伤害。

## 可用验证入口（未在本审计运行）

|入口|覆盖及局限|
|---|---|
|HeroCompactCheck20260918.Begin / HeroSpellCapture|九招接触、取消、死亡清理、重试；HeroSpellCapture standalone参数 --preview-hero-spells --hero-capture=目录。不覆盖手动假面遗物|
|SignatureSpellCapture|--preview-signatures，可用--signature-kinds=Hound,Archivist,Matriarch,Emerald；不是所有主线敌人|
|ChapterThirtyRosterPreview20260916.Begin|Q16–30真实编队/接触等；不是九招或全前15关|
|CodexExecutorPreview、ChronarchPreview、ArchiveAdjudicatorPreview、ArchiveConvoyPreview（均20260916.Begin）|各角色独立，不能替代真实编队|
|ChurchDemonAllSpellsCheck20260917.Begin|六怪11伤害正常一次/死亡取消/重试；D03/D05正常辅助和受益者死亡取消|
|ChurchGrotesquePreview20260917.Begin / ChurchVisualFinalPreview20260917.Begin|塔批量动态/静态预览；检查当前输出目录，避免覆盖认可基线|
|SaltmawReview20260919.Begin / IronclawReview20260918.Begin|独立样板动作、命中、取消、死亡、重试、清理；会PrepareBlade导入资产|
|ChurchSpellsPreview20260917.Begin|六塔+六通缉、持续状态，但仅关键帧，不足动态视觉验收；旧行表缺D04第二剪|
|TowerSixFullPresentation20260917 / TowerRosterPreview20260917|实际塔编队/正式卡回调；不能作为特效审美通过证据|

交付至少要分清：源码触达、运行回调/取消、动态画面检查、用户视觉认可、原生构建、真机安装/视觉。此记录仅第一项。新法术共享层易影响多个家族；需在真实路由截取起手、飞行、命中、尾效，尤其多敌人和盾/治疗非伤害行为。

## 批量录制行表注意

实际母版使用 `wave-instances:clock-guard-primary@皮肤`；archivist/matriarch/scribe/rescue/executor/adjudicator/convoy/chronarch同一实例连续两次`enemy:clock-guard-primary`得到轮换variant，不要每次重装重置计数。通缉以各intent发送。

幽灵必须用`@fog-ghost`/`@crimson-ghost`；`@ghost`会额外挂通缉B03护航身份，实际转入通缉演出，不能代表主线幽灵。新犬使用`wave-instances:hell-hound-primary`；旧犬加`@early-hell-hound`。Q4在旧犬上依次`q4-hound:charge`、`q4-hound:first`/`second`再发敌攻击；仅first/second为大火球，其余非clear为试探小球。

亡灵可用`chapter-thirty:19`再`combat-start`，`emerald-spell:poison`/`burst`选择，`enemy:hell-hound-primary`实际攻击；`emerald-poison:1`等控制持续层，`encore-charge`/`encore-release`控制蓄力。防御盾`archive-state:guard`，清理`archive-state:clear`；蛭蓄力`leech-charge:charge`/`off`。治疗`enemy:clock-core-primary:repair_guard:clock-guard-primary`，正恢复显示`enemy-heal:clock-guard-primary`。手动假面`masquerade:2`、`masquerade-hit:1`、`masquerade-hit:0`。上述非伤害状态不能断言有敌伤回调。
