# 敌方法术一档增强（2026-09-19）

## 范围与状态

本批按用户“增加细节、炸裂、绚丽、光彩、面积；少而大片”方向修改表现源码。伤害、目标、联系回调、动画时钟、站位、生命周期未改。原文件位于 `backups/all-spells-tier-20260919/enemy`。本记录写入时尚未运行 Unity；后续统一验证由主 agent 记录，不能把本记录当视觉通过或手机验收。

## 真实路由与变化

| 路由 | 本批变化 |
|---|---|
| 早犬 → HellHoundEffekseerFireball | 保留真实 authored 飞行轨迹；提高色彩/透明度与终端爆发尺度，不改变 .24/.78/.20 秒时序 |
| Q4 → Q4HoundPresentation | 两颗独立预警火核、追索火核、热尾与落点爆发扩大约一档，提高亮芯；两颗接触逻辑不变 |
| 新犬 → EnemySignatureSpellVFX → HoundVolumetricInferno | 脚下火柱宽 1.18、高 1.16，体积火密度增强；不恢复火球、不改变旋转缩小路线 |
| 门卫 → EnemySignatureSpellVFX → ArchivistMechanicalSpell | 保留实际飞臂；外螺旋 5→3 股加宽；白芯/钴蓝层变宽；命中碎块 18→8、单块加大；精密刃片加宽增厚，嵌光加强 |
| 门卫 guard / open → ArchiveEncounterPresentation | 正前方旋转盾 3.35→3.70、透明度 .65→.76；原前置 1.25 与旋转24度不变 |
| 女主 → CrimsonStageProjection | 三条红绸更宽更亮；命中15段碎绸→7片大绸，保持裁缝丝绸身份；银针长度适量增强、随针丝光加宽 |
| 亡灵两招 → EmeraldRevenantSpell | 有毒体积横向/纵深扩大；雾叶数量减少、每叶变大；亮芯与场景映光加强；不改施毒规则 |
| Q5持续毒雾 → EmeraldPoisonField | 地表范围8.2×6.4→9.2×7.1；42细雾→28片较大雾叶，冷暖翠色层次增强；密度递增、持续到战斗结束和原高度保持 |
| Q7实际正恢复 → ArchiveEncounterPresentation.HealConfirmed | 仅本体 _HealPulse×1.2；不恢复已否定绿线/绿圈，不改+HP/恢复回调 |
| 记忆蛭 → MemoryLeechPresentation + ArchiveEncounterPresentation | 吞名牵引加宽，绿黏液核.24→.34、湿亮发光和3片短尾；接触时点不变 |
| 书记员/救援者/执行者 → StoryEnemyPresentation20260916 | 原细线之外加入各自紫色卷页、掌风大瓣、真实笔端金色交叉书写；命中后短裂开0.5秒（原contact仍1秒） |
| 重锤卫 → HeavyArchivePresentation20260916 | 原细环之外加入三块宽金铜压力裂面，押运为贴地、裁决为上扬；1秒接触保持 |
| 总签官 → ChronarchPresentation20260916 | 同体三阶段保持；加入5段断开铜金钟片与内刻度、接触向外张开；原两式交替不变 |
| 幽灵 → VFXV1 GhostWisp / FogChime | 专属扩展减少线数量6/6/9、3片爆发光团，加宽主体与尾迹；命中闭环改断开弧，保持紫/青身份与原时间轴 |
| 通缉b01–b06 → BountyIdentityPresentation → ChurchSpellVisual | 全部通缉先于母版路由截获，不按母版冒充覆盖。刀弧、皮索、海浪、覆写笔、剪刀、锚链实体放大1.22、弧厚1.28、内发光加强；飞散小件减半且单件放大。教会六种直接return finalVfx，不受此改动 |

新增 `EnemyAuthoredBurstTier20260919` 仅作为故事演员/Boss/锤卫/记忆蛭表现根的子组件，渲染有主体身份的有色面和亮脉；不自建伤害计时，原根取消时一并清理Mesh与Material。

## 需统一运行的验证入口

- SignatureSpellCapture：主线四类八招、旧路径取消检查。
- Q4TwoFlameCapture：预警、两次追索、假面目标变更与取消。
- EmeraldEscalationCapture：毒雾递增、实际场景遮挡。
- Q678RedesignCapture：盾/蛭/恢复实际路由。
- StoryModelCapture20260916、ChronarchPreview20260916.Begin：故事演员与Boss实际动画/接触。
- 通缉应经 BattlePrototype.PresentEnemyAttack 的真实Bounty截获路径逐个触发，不调用母版Showcase替代。

用户需要的最终验收是实录逐招看主体/面积/亮芯/命中层次、取消/退场/重试清理与不遮人物；不是生成或编译成功。

## 第一轮实拍后的局部精修

已只读检查 `output/all-spells-tier-20260919/enemy-sheet.jpg`，发现故事演员宽面呈纯色硬纸片，Boss/锤卫原三重圆环压过新主体。此问题不算通过。

本次精修仅修改新helper、专属 `EnemySignature/AuthoredBurstTier.shader` 与Boss/重锤表现文件：移除旧三重圆环渲染；原数量不增加，宽面细分为连续弯曲面，透明柔边、内部流动密度、细热脊取代均匀白色。书记员仍3页，新增实体弯折和材质文字/边纹。5段钟片轻微错位，保留刻度身份。第一轮源码备份在 `enemy/first-review`。未更动接触或伤害逻辑；须重新运行与看图确认精修效果。
