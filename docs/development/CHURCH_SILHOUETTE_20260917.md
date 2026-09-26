# 六恶魔法术主体 · Build 51

用户批准参考图2：清晰主体、暗轮廓/饱和色/亮芯、绚丽且保留空隙。

## 实现

`UnityBattleSource/Assets/Scripts/ChurchFinalVfx20260917.cs` 接入六张真正透明的原画，真实时间驱动旋转、推进、交剪、缩放消散。原有细流光、地裂与命中碎光作为辅层。伤害和回调时间未改。

| 恶魔 | 主体 | 运动 |
|---|---|---|
| 盾颚 | 黑曜熔金地裂冠 | 地面倾斜展开、旋转消散 |
| 盐囊 | 腐绿细脉毒枪 | 沿施法者到目标的方向推进 |
| 背囊 | 寄生翅膜 | 转移至受疗目标、旋转收束 |
| 剪肢 | 暗甲酸绿镰刃 | 两侧反向交剪 |
| 蛇冠 | 深红异形冠 | 旋转推进与扩散 |
| 骨爪 | 三道紫色撕裂 | 分离裂痕、斜劈与横扫 |

## 素材与提示词集

使用内置 image_gen；六张原始 RGBA 原画位于 `UnityBattleSource/Assets/Resources/ChurchSpellArt/{earth,venom,mend,sickle,corona,claw}.png`。1254×1254，真实 alpha。没有用 Python 绘制或编辑图像。

共同提示：Production dark fantasy RPG VFX sprite, one centered isolated asset on genuine transparent alpha background. Premium meticulously hand painted game spell, layered dark edge / saturated body / bright thin core. Transparent margins and gaps. No scene, ground, character, words, UI, watermark, large bloom or fog cloud. Intended for actual game-engine animation.

- earth: Top down demonic earth rupture crown, interlocking jagged obsidian shale blades, molten amber gold fissures, narrow ivory inner edges. Central 55 percent diameter empty transparent, chipped contours and stone striations.
- venom: Three twisted translucent bile-green streams bound by dark olive organic membranes, needle point at top, split curling tails, ivory acid veins, narrow diamond silhouette, transparent gaps.
- mend: Three overlapping translucent jade insect membranes, hooked dark bronze ribs, amber-green seed, finely veined pearlescent surfaces, sinister organic regeneration, no circle.
- sickle: Curved insect sickle crescent, serrated chitin outer rim, translucent chartreuse membrane, hot ivory edge, tapering luminous filaments, empty center.
- corona: Asymmetric hooked crimson organic flame blades around empty center, burgundy outline, ruby membranes, golden-white inner edges, open broken spiral.
- claw: Three separated parallel diagonal demonic tears, dark indigo broken borders, violet inner energy, thin ivory cores, jagged edges and filament tails, no bones or circle.

提示词集为制作参数记录；生成原始结果保留在 Codex generated_images 本次任务目录。Build50源码备份在 `backups/church-silhouette-20260917`。

## 证据与边界

14组真实 Unity 演出：`output/church-grotesque-20260917/index.html`，720×1280、30fps、可暂停和半速。已逐种查看命中帧；不是合成游戏截图。视觉最终认可仍待用户，不宣称魔兽级。

Unity 验证：11个伤害动作各一次实际命中；施法者死亡取消后无迟到命中，重试恢复；D03/D05受疗/强化目标死亡取消通过。最后调整辅助法术前移0.85与尺寸后，重新录制14组并复查背囊受疗帧，持续效果停止清理通过。该位置调整不涉及回调逻辑。

## 原生交付

Build51 Xcode构建成功、签名校验通过，归档 `artifacts/releases/Build51/Mistport.app`。2026-09-17安装并启动配对iPhone13成功；安装前后 `mistport.player-test-01-15.plist` 字节一致，备份见本批device目录。没有声称完成手机逐招视觉验收。
