# 终战三人组队设计（第 28–30 关）· 2026-10-10

**状态：用户已定方向（见下节），规则和数值实现中；具体数字待模拟验证。**

## 用户决定（10-10 傍晚）

- 第二位队友：**诺恩·凯德**。
- **第 28、29、30 关都三人组队**（主角 + 奥黛尔 + 诺恩，两人都是 AI）。
- 玛拉不出场。**教会的天使出现，带走更强的那个 Boss**，留下的瑟维安由我们三人打。（“更强的 Boss”指谁待用户确认；暂按“瑟维安背后更早的外部追索者”理解，只影响剧情文字。）
- 第 30 关血量约 18000–20000，分三阶段：可以。
- **要选到好的遗落物才能打得过**：数值按“普通遗落物组合打不过、好的组合能过”来调。

## 用户方向（10-10）

- 最终 Boss 瑟维安至少 4 个技能，血要超厚。
- 最终战 3 人组队，其中 2 个是 AI 队友。
- 奥黛尔可以入队。
- 玛拉的真实身份是黑夜教会女神的分身，不能当普通队友。世界观约束（`WORLD_CONTINUITY.md`）里也已写明不给她新增人形战斗母版。

## 现状（源码）

- 第一章 30 关目前全是单人：遭遇的 `companionSlots` 都是 0。
- 规则引擎本来就有 AI 同伴：`MPCChapterOneCatalog.companions` 有护卫、治疗、构装三种角色。`companionCandidates` 让同伴自己挑目标出手：护卫替主角挡已知伤害，治疗给主角回血，构装给主角上盾。早期的“不存在的灾难”就是瑟维安（统一时钟形态）带 2 个同伴的 Boss 战。
- 瑟维安在第 30 关：血量 `q30SovereignHP = 6500`，出招循环 `strike / thirteenth_charge / slam / recover`。低于狂暴线后，伤害按 `q30EnragePercent` 放大，并按玩家血量比例结算。

## 提议

### 范围

第 28–30 关都组队。第 28 关仍是撑过五轮（瑟维安打不死），第 29 关仍要清掉手下，第 30 关真正击杀。三关开场剧情交代两位队友在场；第 30 关开场天使出现、带走更强的 Boss。

### 队伍

| 位置 | 角色 | 控制方式 | 定位 |
|---|---|---|---|
| 主角 | 无名者 | 玩家操作 | 输出、控场（现有技能牌） |
| 队友一 | 奥黛尔·芬（诊所医生、炼药师） | AI | 治疗：给血量最低的人回血，解除“夺名代签”的封印；普攻掷药瓶，伤害小 |
| 队友二 | **推荐诺恩·凯德**（巡官，提灯） | AI | 护卫：替队友挡下一次已知重击（第十三响、镇钟重砸），用提灯普攻 |
| 备选 | 维拉·铜枝（机械臂工匠） | AI | 输出：铜枝构装射击、给主角上盾 |

队友沿用引擎现有的同伴 AI（护卫、治疗两种角色），需要补“解封印”和“挡群攻里的一份”两条行为。队友倒下后不能复活；全员倒下才算失败。

### 瑟维安四招（针对三人）

| 招式 | 动作视频 | 打谁 | 效果 |
|---|---|---|---|
| 铜手按印（普攻） | 全身横扫（已认可） | 主角 | 现有普攻伤害，巨型铜手拍下（已认可） |
| 第十三响（蓄力） | 举拳过头斜砸（待生成） | 单体，优先主角 | 蓄力后重击，诺恩可替挡；落剑钟鸣（已有） |
| 镇钟重砸 | 共用砸地视频，不蓄力 | 三人群攻 | 每人吃一份；手绘碎岩染铜色 |
| 夺名代签（新） | 签名视频（已抠图） | 一名队友或主角 | 封住目标一张技能（AI 队友封其技能，主角封一张牌）6 秒；奥黛尔可解 |

### 血量与阶段

血量约 18000–20000（三人输出比单人高）。按阶段放招：

| 阶段 | 血量 | 出招 |
|---|---|---|
| 一 | 100–60% | 铜手按印、第十三响 |
| 二 | 60–30% | 加入镇钟重砸、夺名代签 |
| 三 | 30% 以下狂暴 | 全部招式加快，沿用现有狂暴墙 |

具体数字要用推进模拟器跑过：确认按天放开（每天 1–2 小时、第 30 天）的玩家带两位队友能打过，单靠堆时间赢不了。

### 玛拉

不出场（用户 10-10）。

## 已实现的规则与数值（10-10 晚，规则库 600 项测试全过）

- **队友**：诺恩 1600 血；奥黛尔·芬（新加，治疗）1200 血。第 28–30 关各带 2 个同伴位。每场开始时队友满血，共享复活 1 次；打完不写回存档，不影响塔和通缉战。
- **队友行动**：按战斗时间每 1 秒检查一次，每人最多 2.5 秒行动一次（主角倒下时也照常行动）。奥黛尔有封印时先解封，否则治疗（180 血，冷却 5 秒），再否则掷药瓶。诺恩在第十三响来之前布好拦截：替主角吃 60%，主角不掉血，每轮循环一次，倒下或被封时不能拦。
- **队友伤害**：走和主角一样的保护规则，所以第 28、29 关仍然打不死瑟维安本体，但能打护卫。
- **瑟维安（第 30 关）**：
  - 20000 血，伤害按主角基础血量的比例结算：铜手按印 32%、第十三响 52%、镇钟重砸 42%（队友各吃自身血量的 18%，狂暴时 30%）、夺名代签 12%。
  - 低于 30% 狂暴：没有绯月寿账签时伤害 ×125%，且每击（夺名代签除外）至少扣 70% 基础血。
  - 镇钟重砸保留“塔 90 层装备”的墙。
  - 出招循环随血线切换：60% 以上 `铜手按印 / 铜手按印 / 第十三响 / 回气`；60–30% `夺名代签 / 铜手按印 / 镇钟重砸 / 第十三响 / 回气`；30% 以下 `镇钟重砸 / 夺名代签 / 第十三响 / 铜手按印`（不回气）。
- **夺名代签**：按主角 → 诺恩 → 奥黛尔轮流点名（跳过倒下的）。点中主角时，封住自动出招下一张要出的牌 6 秒；点中队友时，让他 6 秒内只能普攻。后手改写也能解主角的封印。
- **失败条件（用户 10-10 定）**：三人全倒才输。主角倒下时不能出牌和普攻，打向他的攻击转给还站着的队友（诺恩优先）；奥黛尔站着且没被封时，用 3 秒把主角救起（共享复活 1 次，恢复 30% 血），被封或被打倒会打断。队友在主角倒下时打倒瑟维安也算赢。第 30 关输了不给遗落物提示。
- **第 28、29 关**：固定伤害（铜手按印 700 / 第十三响 1130 / 镇钟重砸 920），没有按遗落物设墙，带普通遗落物也能过。
- **模拟验证（塔 90 层装备 + 绯月寿账签，每种遗落物 8 种打法）**：

  | 第 30 关 | 高 | 中 | 低 |
  |---|---|---|---|
  | 返礼银扣 | 6/8 | 6/8 | 2/8 |
  | 迟签印章 / 缄卷镇纸 | 2/8 | 1/8 | 0 |
  | 盐封呼吸囊 / 奥瑞斯之镜 / 逆潮铜锚 / 归属断线针 | 0 | 0 | 0 |

  没有绯月寿账签全输；只有塔 80 层装备全输；塔 100 层装备和 90 层差不多（高水平玩家用盐封呼吸囊能险胜一次）。赢的战斗 66–127 秒。第 28、29 关塔 70 层装备任何遗落物都能过。

## 工作量

- **规则**：第 30 关 `companionSlots = 2` 并指定这两位队友；补队友的“解封印”和“挡群攻”行为；瑟维安的阶段、新招 `name_seal`、群攻 `slam`；新血量；用推进模拟器验证。
- **画面**：
  - 战场摆三个人（竖屏站位）；
  - 队友的视频身体（同主角做法）；
  - 队友血条和技能提示；
  - 队友法术（手绘道具图）；
  - 瑟维安四招的视频身体，以及夺名代签的金色签名锁链。
- **用户生成**：两张全身原画；每位队友 4 条视频；瑟维安待机、蓄力、受击 3 条。

## 待用户确认

1. 天使带走的“更强的 Boss”是谁（剧情文字）。

---

## 附：原画与视频提示词

### 1. 全身原画（以现有半身立绘为参考图，图生图）

现有立绘：`design/concept-art/odelle-finn-final-v1.png`、`design/concept-art/norn-kade-final-v1.png`。都是半身，背景是场景，要改成全身、正面、中灰底，才能做视频起始帧。

**奥黛尔·芬**
```
Full-body front view of this exact character from the reference image: a young female physician-alchemist with short blue hair and a teal hair clip, a cream scarf, a blue robe with silver embroidery over a white dress, leather belts hung with small glass vials, holding a glass flask of blue liquid in one hand. She stands facing the viewer in a relaxed neutral pose, arms slightly away from the body, both feet flat on the ground, head to boots fully in frame with clear room above the head. Same face, hair, costume and colors as the reference. Detailed hand-painted dark-fantasy game illustration. Flat uniform medium-gray background (#8E8A85), no floor, no shadow, no scenery, no text, no frame. 9:16, 1080x1920.
```

**诺恩·凯德**
```
Full-body front view of this exact character from the reference image: a rugged male city patrol officer with dark tousled hair and light stubble, a long dark navy greatcoat with brass buckles and leather belts, black gloves, holding an old brass oil lantern in his right hand. He stands facing the viewer in a steady neutral pose, arms slightly away from the body, both feet flat on the ground, head to boots fully in frame with clear room above the head. Same face, hair, costume and colors as the reference. Detailed hand-painted dark-fantasy game illustration. Flat uniform medium-gray background (#8E8A85), no floor, no shadow, no scenery, no text, no frame. 9:16, 1080x1920.
```

### 2. 队友视频（起始帧用上面生成的全身原画，9:16，8 秒，24 fps）

每条 = 前缀 + 动作 + 服装锁定 + 后缀。

**奥黛尔前缀**
```
[Static shot] Animate this exact full-body front-view hand-painted fantasy game character: a young female physician-alchemist with short blue hair and a teal hair clip, a cream scarf, a blue robe with silver embroidery over a white dress, belts with small glass vials, a glass flask of blue liquid in her hand. Preserve her identity, face, proportions, hairstyle, every costume panel and colors from the supplied image. High-quality detailed painted illustration animation, never glossy CGI or plastic 3D. Locked front camera, constant framing and scale, head to boots fully in frame at all times with room above the head. The flat medium-gray background stays completely still and uniform. Her whole body takes part in the movement: hips, waist, shoulders, knees and feet all move, never only the arm.
```

**诺恩前缀**
```
[Static shot] Animate this exact full-body front-view hand-painted fantasy game character: a rugged male city patrol officer with dark tousled hair and stubble, a long dark navy greatcoat with brass buckles and leather belts, black gloves, an old brass oil lantern in his right hand. Preserve his identity, face, proportions, hairstyle, every costume panel and colors from the supplied image. High-quality detailed painted illustration animation, never glossy CGI or plastic 3D. Locked front camera, constant framing and scale, head to boots fully in frame at all times with room above the head. The flat medium-gray background stays completely still and uniform. His whole body takes part in the movement: hips, waist, shoulders, knees and feet all move, never only the arm.
```

**通用后缀**（`[服装]` 换成各自的服装锁定句）
```
[服装] Shoulder, elbow and wrist move as a coordinated anatomical chain: no backward joints, no rubber bending, no extra fingers or extra limbs. Clothing, belts and hair follow with light delayed secondary motion and settle. No camera motion, no cuts, no zoom, no new objects, no text, no particles, no glow, no magic effects, no other characters. Back in the exact starting pose before the end.
```

- 奥黛尔服装锁定：`Her scarf, robe, white dress and belts stay exactly as in the image for the whole video; no costume changes. The glass flask keeps its exact shape.`
- 诺恩服装锁定：`His greatcoat, belts and gloves stay exactly as in the image for the whole video; no costume changes. The brass lantern keeps its exact shape.`

**奥黛尔动作**

- 待机 idle：
  ```
  A calm living idle loop: she breathes, shifts her weight from one leg to the other, turns the glass flask slowly in her hand and checks it against the light, glances to the side and back to the camera with a gentle determined look; scarf and robe sway with the weight shift. The last frame matches the first frame for a seamless loop.
  ```
- 普攻·掷药瓶 throw：
  ```
  One overhand throw with the whole body: she steps back with one foot, turns her waist and draws a small glass vial from her belt, winds her arm back high, then steps forward and hurls the vial toward the camera with her whole body, robe and scarf flaring; she follows through, then recovers and steps back to the exact starting stance.
  ```
- 技能·疗愈 heal：
  ```
  One healing rite with the whole body: she sinks onto one knee, raises the flask high with both hands, rises in a half turn as she lifts it over her head, then sweeps it forward in a wide arc as if sprinkling medicine over allies in front of her, scarf and robe swirling with the turn; then she settles back into the exact starting stance.
  ```
- 受击 hit：
  ```
  One hit reaction with the whole body: a blow strikes her shoulder; she twists back and staggers one step, clutching the flask to her chest, hair and scarf whipping; she steadies herself, straightens up and steps back to the exact starting stance.
  ```

**诺恩动作**

- 待机 idle：
  ```
  A steady living idle loop: he breathes deeply, shifts his weight, lets the heavy lantern swing gently from his hand and lifts it a little to look ahead, rolls his shoulders, coat tails swaying. The last frame matches the first frame for a seamless loop.
  ```
- 普攻·提灯重击 strike：
  ```
  One heavy lantern strike with the whole body: he steps back and turns his waist, swinging the brass lantern back on its handle, then lunges a full step forward and swings it in a wide overhead arc down in front of him, crouching with the impact, greatcoat flaring; then he rises and steps back to the exact starting stance.
  ```
- 技能·拦截 guard：
  ```
  One protective guard with the whole body: he steps forward wide and plants his feet, sweeps his greatcoat open with his free arm and raises the lantern in front of his chest like a shield, braces as if a heavy blow hits him, is pushed back half a step with knees bending, holds firm, then straightens and steps back to the exact starting stance.
  ```
- 受击 hit：
  ```
  One hit reaction with the whole body: a heavy blow strikes his chest; he rocks back a step, the lantern swinging wide, coat whipping; he plants his feet, shakes it off and returns to the exact starting stance.
  ```

## 附 3：分层部件图提示词（10-10，不用视频，骨骼动画）

全身原画已交（`ArtSource/FinalBossParty20261010/odelle_full.png`、`norn_full.png`、`elaia_full.png`、`shadow_pursuer.png`）。队友改用 2D 骨骼动画（Spine 式部件拼装），需要每人一张部件拆分图：以全身原画为参考图，图生图。交回命名 `odelle_parts.png`、`norn_parts.png`、`elaia_parts.png`。提示词见对话（与下方一致）。

### 奥黛尔 odelle_parts.png
```
Using the supplied full-body image as the exact reference, create a 2D cutout-animation PART SHEET of this same character (a young female physician-alchemist: short blue hair with a teal hair clip, cream scarf, blue robe with silver embroidery over a white dress, leather belts with glass vials, brown boots). Same face, colors, costume details, line quality and painted style as the reference, and the same scale as the full-body image. Draw each body part as a separate, complete piece, laid out in a neat grid with wide empty gaps between pieces; no piece touches or overlaps another. Every piece faces front, upright and straight (limbs hanging straight down), lit from the upper left.
Pieces:
1. Head with hair and hair clip, with a short neck stub.
2. Torso from neck to hips: white dress bodice, robe shoulders, cream scarf, cross belt, vial belt and pouch, drawn complete with NO arms attached (the shoulders where the arms join are fully painted).
3. The hanging fringed end of the scarf, separate.
4. Left upper arm in the wide blue sleeve.
5. Left forearm with the wide sleeve cuff and the open relaxed hand.
6. Right upper arm in the wide blue sleeve.
7. Right forearm with the sleeve cuff and the hand holding the glass flask of blue liquid.
8. The glass flask of blue liquid alone.
9. White dress skirt from hips to knees, complete.
10. Left blue robe tail panel hanging from the hip, complete.
11. Right blue robe tail panel, complete.
12. Left lower leg with brown boot.
13. Right lower leg with brown boot.
Arm and leg pieces extend a little past each joint with a rounded painted end so they can rotate without gaps. Areas normally hidden behind other parts are painted in full. Flat uniform medium-gray background (#8E8A85), no shadows, no floor, no labels, no numbers, no text, no frame. Square, 2048x2048.
```

### 诺恩 norn_parts.png
```
Using the supplied full-body image as the exact reference, create a 2D cutout-animation PART SHEET of this same character (a rugged male city patrol officer: dark tousled hair and stubble, a long dark navy greatcoat with a shoulder capelet, brass buckles, cross leather belts and a badge, black gloves, a brass oil lantern, black strapped boots). Same face, colors, costume details, line quality and painted style as the reference, and the same scale as the full-body image. Draw each body part as a separate, complete piece, laid out in a neat grid with wide empty gaps between pieces; no piece touches or overlaps another. Every piece faces front, upright and straight (limbs hanging straight down), lit from the upper left.
Pieces:
1. Head with hair, with a short neck stub.
2. Torso from neck to hips: coat chest with collar, shoulder capelet, buttons, cross belts, badge and waist belt with pouches, drawn complete with NO arms attached (the shoulders where the arms join are fully painted).
3. Left upper arm in the coat sleeve.
4. Left forearm with the strapped cuff and the open gloved hand.
5. Right upper arm in the coat sleeve.
6. Right forearm with the strapped cuff and the gloved hand closed in an empty grip.
7. The brass oil lantern alone, glowing, with its handle.
8. Left greatcoat skirt panel from the waist to the shins, complete.
9. Right greatcoat skirt panel, complete.
10. Left leg: trouser thigh and shin with the black strapped boot.
11. Right leg: trouser thigh and shin with the black strapped boot.
Arm and leg pieces extend a little past each joint with a rounded painted end so they can rotate without gaps. Areas normally hidden behind other parts are painted in full. Flat uniform medium-gray background (#8E8A85), no shadows, no floor, no labels, no numbers, no text, no frame. Square, 2048x2048.
```

### 伊莱娅 elaia_parts.png（出场演出用：翅膀扇动、灯杖、衣摆飘）
```
Using the supplied full-body image as the exact reference, create a 2D cutout-animation PART SHEET of this same angel (silver-white hair, white and pale-gold robe with lantern motifs, a long brass lantern staff, two large white-and-gold feathered wings, bare feet). Same face, colors, costume details and painted style as the reference, and the same scale as the full-body image. Draw each part as a separate, complete piece, laid out with wide empty gaps; no piece touches or overlaps another. Lit from the upper left.
Pieces:
1. Body from head to feet in the robe, arms at the sides, WITHOUT the wings and WITHOUT the staff (the back and shoulders where the wings attach fully painted, the hands empty).
2. Left wing, fully spread, complete with its root.
3. Right wing, fully spread, complete with its root.
4. The long brass lantern staff alone, upright, its flame glowing.
5. Her right hand closed in a grip (to hold the staff), separate.
6. Two long trailing pieces of her sleeve and robe hem cloth, separate.
Areas normally hidden behind other parts are painted in full. Flat uniform medium-gray background (#8E8A85), no shadows, no floor, no labels, no numbers, no text, no frame. Square, 2048x2048.
```

## 附 4：背面版（10-10 晚）

战场镜头在主角身后（主角视频是背面），队友站在主角两侧也应是背面；现有正面部件图用于开场演出和界面。伊莱娅面向镜头（站在 Boss 那边面对队伍），用正面即可。背面版先出全身背面图，再以它为参考出背面部件图（提示词见对话）。交回命名 `odelle_back_full.png`、`odelle_back_parts.png`、`norn_back_full.png`、`norn_back_parts.png`。

## 离场祝福（彩蛋，10-10）

用户 10-10：「2人离开时分别会随机给予主角和小boss一个祝福，这在一定程度上会影响战斗。设计个小彩蛋而已。」开场伊莱娅把外部追索者拖进裂隙时，伊莱娅给主角一个祝福，追索者给瑟维安一个赠礼，各从三个里随机抽一个。只在第 30 关生效，第 28、29 关和其他战斗不变；只管这一场，不写回队伍和存档。数值在 `MPCProgressionWalls.q30*`，规则在 `MPCFarewellBlessings` 和 `applyFarewellBlessings`。

**伊莱娅的祝福（主角）**

| 祝福 | 效果 |
|---|---|
| 灯芯长明 | 主角自己对瑟维安的伤害 +8%（队友的伤害不加） |
| 羽翼庇护 | 共享复活多 1 次：奥黛尔照常引导 3 秒，第二次唤回只回 10% 血（第一次仍是 30%） |
| 照名之光 | 夺名代签只封 3 秒（原 6 秒），主角和队友都算 |

**追索者的赠礼（瑟维安）**

| 赠礼 | 效果 |
|---|---|
| 黑盐外壳 | 瑟维安受到的所有伤害 −15% |
| 冷钟 | 第十三响 +32%（在按血量比例算完之后再加，诺恩替挡时吃其中的 60%） |
| 雾中续命 | 进入第二、第三阶段时各回 5% 最大生命，不超过上限；回血后不退回上一阶段，第三阶段照样算狂暴 |

初稿（灯芯 10%、复活回 30%、外壳 10%、冷钟 20%）模拟不过：多组里普通遗落物赢了。原因是没有好遗落物时，最接近的几局瑟维安只剩 255–900 血（共 20000），主角拿到任何增益都可能翻盘；冷钟低于约 28% 时又几乎都被诺恩挡掉。现在这组数是从网格里挑出来的，但余量很薄：灯芯 9%、外壳 14% 或续命 4% 都会让某一组重新不过。

**App**：每次点“开始战斗”进入第 30 关时，用系统随机数各抽一个（`ChapterOneMissionBridgeView.beginConfiguredBattle`）。开战时借终结技提示条依次显示两条：标题“伊莱娅的祝福 / 追索者的赠礼”，下面是名字和一行效果，各显示约 2.5 秒。撤退后再开战会重新抽。

**模拟**（塔 90 层装备 + 绯月寿账签，每档 8 局；格内是返礼银扣在高 / 中 / 低三档的胜场）

| 主角 \ 瑟维安 | 黑盐外壳 | 冷钟 | 雾中续命 |
|---|---|---|---|
| 灯芯长明 | 6/3/0 | 4/4/0 | 5/5/0 |
| 羽翼庇护 | 6/4/0 | 5/4/0 | 6/6/0 |
| 照名之光 | 6/5/0 | 5/3/0 | 7/4/0 |

不抽祝福时仍是 6/6/2，和原表一样。四件普通遗落物（盐封呼吸囊、奥瑞斯之镜、逆潮铜锚、归属断线针）在 9 组、三档里全是 0；没有绯月寿账签，或者只有塔 80 层装备，9 组全输。第 28、29 关有没有祝福，输出逐字相同。代价：低水平玩家带银扣原本 2/8，现在 9 组都是 0/8。工具：`BLESSINGS=<主角>,<瑟维安> ProgressionSim fight …`。

## 2026-10-15：第 30 关两道墙在真实循环里复核

用户要求“必须带遗落物”重新成立。按正式审计的 168 种编排实测：不带绯月寿账签（F100 装备）有 37 种能赢，只穿 F80 装备有 10 种能赢（原“0/16”是旧手牌）。只改“不满足墙”时才生效的数：狂暴每击至少 70%→300% 基础生命，狂暴猛砸对队友 30%→100%；没有 F90 以上装备时，塔层检定猛砸 140%→300%，并对两名队友也按 300% 结算。改后两种情况都是 0/168（三套装扮）；带寿账签＋F90 的战斗完全不受影响，所以离场祝福那张表不变。详见[主线硬墙第 10 节](PROGRESSION_WALLS_AND_BOUNTY_RELICS_20260928.md)。

**同日复核（未改，需用户定）：** 在真实循环里按 168 种编排打 F90＋寿账签，四件普通遗落物（盐封呼吸囊、奥瑞斯之镜、逆潮铜锚、归属断线针）在 9 组祝福里各赢 30–38 种编排（不抽祝福 36–37），返礼银扣 44–55。上面“普通遗落物 9 组全是 0”是旧模拟器那两套手牌的结果，换成正式审计的编排后不成立。这套战斗（带寿账签＋F90）本轮没有改动；要不要让第 30 关只认银扣，需要用户决定（`OrderedChapterBalanceAuditTests.q30BlessingAudit`，`MISTPORT_Q30_AUDIT=1`）。

