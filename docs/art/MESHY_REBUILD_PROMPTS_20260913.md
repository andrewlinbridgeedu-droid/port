# Meshy 三敌重做 Prompt · 2026-09-13

用户要求：猎犬采用新 Infernal Warhound GLB；另三个模型重新给出 Prompt，突出动作与重心，颜色不要一样。这里对应翠焰亡灵、档案守卫、织幕女主，保留其剧情身份。以下是新模型制作方向，不代表另三份新资产已经生成或替换。

建模 Prompt 描述一个明确的动态定格姿态；连续呼吸、蓄力、释放等动作应在绑定后制作。不要把数个动作写进同一个静态模型生成请求。已有参考图可作为身份参照，但新姿态和配色以本段文字为准。

## 1. 翠焰亡灵 / Emerald Encore Revenant

主色：深松绿、旧象牙白、氧化铜；翠绿发光仅集中在胸腔和眼睛。姿态：失去平衡般的前倾，肩胯反向扭转，一手发出邀请，另一手把力量攥回胸前。

```text
Create one full-body 3D game enemy: the Emerald Encore Revenant, an undead Victorian stage performer who refuses to leave the stage. A gaunt ivory skull beneath a battered, tilted top hat; a narrow exposed rib cage enclosing a luminous emerald core; a weathered deep pine-green tailcoat with oxidized copper clasps and a faded cream waistcoat. Distinct green-and-ivory palette, with restrained copper accents. No purple costume, no gold armor.

Capture a poised, unsettling instant before a spell: his weight rests on the rear leg, the front foot is half a step forward with its toe turned slightly outward, both knees softly bent. His narrow torso leans forward and twists against the hips. One shoulder is raised; his head tilts toward the opponent as if listening for applause. One arm reaches diagonally forward, elbow bent, palm partly open in a beckoning gesture; the other hand curls close to the glowing chest, gathering power. Keep both hands clearly separated from the torso and every finger readable. The coat tails sweep gently backward and to one side, suggesting a recent turn, without hiding the legs. Sinister theatrical energy, controlled imbalance, an expressive silhouette rather than a straight symmetrical stance.

Anatomically coherent body, exactly two arms and two legs, clean joint separation, complete visible feet, compact silhouette suitable for a portrait-oriented battle screen. Detailed PBR materials: cracked bone, worn velvet, tarnished copper, subtle emerald emissive details. The face, fingers, elbows and knees must remain suitable for later rigging. Character only, no floor or pedestal, no environment, no floating props, no particle clouds, no fire geometry, no motion blur, no text. Spell flames will be added separately in the game.
```

## 2. 档案守卫 / Archivist Sentinel

主色：象牙白搪瓷、靛蓝、黑铁；琥珀小灯为点缀。姿态：像沉重机构正在转身挡路，前后错步，柜体与骨盆逆向扭转，两臂一高一低。

```text
Create one full-body 3D game enemy: the Archivist Sentinel, a menacing mechanical keeper of forbidden identity records. Its torso is a compact antique filing cabinet integrated into a humanoid automaton, with layered drawer fronts, index-card slots, heavy locks and a small watchful head. Ivory enamel panels with chipped edges, deep indigo-blue steel framing, charcoal iron joints, and a few tiny warm amber indicator lights. The dominant impression is pale ivory and dark blue, not bronze, green, purple or glowing gold.

Pose it at the tense moment of turning to bar someone's passage. One heavy foot is planted forward and slightly outward, the other is firmly braced behind. Both knees are flexed under the cabinet's weight. The pelvis remains angled while the cabinet torso twists toward the opponent. The head turns a little farther than the chest, giving an alert, accusatory focus. One broad forearm is raised diagonally across the upper body with the elbow held away from the cabinet, preparing to press an invisible seal; the opposite arm hangs forward and lower, its open mechanical hand ready to grasp a document. Keep the raised hand clear of the face. Uneven shoulder heights and visibly loaded joints should communicate weight and impending movement. Avoid a square frontal pose with parallel feet and identical arms.

Use clear articulated shoulder, elbow, hip, knee and ankle joints. Rigid cabinet panels and drawer fronts should not bend like flesh. Exactly two arms and two legs, separated mechanical fingers, complete visible feet. A few firmly attached paper tabs may protrude from closed drawers, but no floating pages and no large open doors. Strong readable silhouette, complete standalone game mesh, detailed PBR enamel, painted steel and aged paper. Character only, no scenery, no base, no magic effects, no light beams, no text or readable labels, no motion blur.
```

## 3. 织幕女主 / Clockwork Veil Matriarch

主色：深酒红、冷银、灰白薄纱；暗玫瑰小宝石点缀。姿态：转身织线的半拍，侧身错步，腰肩反向，一手高提一手低牵，衣摆随动作单侧展开。

```text
Create one full-body 3D game enemy: the Clockwork Veil Matriarch, an eerie aristocratic weaver who stitches stolen identities into ceremonial veils. A tall, slender woman with a composed, severe face partly framed by an ash-white veil. She wears a layered deep oxblood-red gown, a structured dark burgundy bodice, cold silver filigree and discreet smoked-rose gemstones. Three compact antique thread spools are mounted on an articulated silver frame behind her shoulders. Dominant wine-red fabric, cool silver metal and pale gray-white veil; no green glow, no purple-and-gold palette.

Capture her in a restrained weaving turn rather than a formal portrait. Her supporting leg carries the weight; the other foot steps slightly back and to the side, with both feet visibly grounded. Hips turn one way while the shoulders turn back toward the opponent. One elbow rises outward and the hand is held above shoulder level as if lifting a strand; the opposite hand extends lower and forward as if drawing that strand taut. Both elbows stay softly bent, wrists expressive, fingers curved but clearly separated. Her head inclines toward the lower hand while her eyes watch the opponent. The gown and veil follow the turn in one gentle diagonal sweep, leaving space around the forearms and revealing the position of the feet. Elegant menace, poised tension, an active asymmetric silhouette.

The three spools remain physically attached to their rear frame and separated enough to rotate later. Suggest thread through engraved spool grooves and the gesture; do not create hair-thin strands connecting hands to the head, clothing or frame. Exactly two arms and two legs, believable joints and clean hand anatomy. Separate veil layers, sleeves and skirt panels suitable for later bone animation; no cloth fused to the hands or feet. Detailed PBR velvet, silk, aged silver and translucent-looking but structurally solid veil fabric. Character only, complete body, no environment, no pedestal, no floating objects, no particle effects, no magic ribbons, no motion blur, no text.
```

## 后续绑定动作意图（不混入单次静态建模 Prompt）

- 翠焰亡灵：胸口起伏与轻微重心摇摆；蓄力时肩胯收紧、手势向胸腔回收；释放时身体展开、前掌推出，尾摆滞后跟随；脚部不滑行。
- 档案守卫：沉重微幅重心调整、头部巡查；蓄力先沉肩屈肘，释放再推出前臂；柜体保持刚性，末端有短暂机械回弹，双脚承重稳定。
- 织幕女主：呼吸、手腕与纱摆有错开的细小运动；蓄力双手牵引，释放手臂拉开并轻转腰肩；线轴、袖摆与披风分时跟随，避免全身同时摆动。

配色对照：新猎犬为炭黑/熔红/古金，亡灵为深绿/象牙白/氧化铜，守卫为象牙白/靛蓝/黑铁，女主为酒红/冷银/灰白。各角色使用集中、少量发光区域，避免整身统一发光掩盖材质。
