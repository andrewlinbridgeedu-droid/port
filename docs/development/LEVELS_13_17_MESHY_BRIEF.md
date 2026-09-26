# 第13、17关正式模型制作规格

总清单以 `LEVELS_01_20_MODEL_REQUEST.md` 的5个模型为准。本文件仅细化其中第13关追令精英守卫和第17关裁忆者，不额外增加模型数量。

状态：依据当前关卡身份提出的美术制作规格，尚无对应已交付3D资产。不可把以下描述当作已生成模型或已实现法术。用户负责Meshy生成；骨骼动作与游戏接入由开发侧完成。

## 第13关：精英空壳守卫

关卡「救援命令」：只认命令、不认求救者的旧城区执行者。现有普通持斧守卫不足以表达精英身份，需独立剪影，保留同一组织材质语言。

- 人形双足，约主角身高1.25倍；空洞头盔、宽肩、窄腰，胸前破损救援徽记。
- 老旧铁甲、黑铜关节、残破象牙白救援披肩；非未来机甲，不使用荧光绿亡灵配色。
- 一只手持短柄仪式重锤，另一手保持空手，用于指令/蓄力。避免巨大武器永久遮脸。
- 原地承重待机，双脚落地；佯攻短抬手、真实下击、长蓄力举锤、受击、跪倒退场。不要模型自带火球。
- 提供人形骨架；手掌、武器头、胸口为后续法术挂点。贴图不烘焙动态光效。
- Meshy提示：Dark gothic fantasy hollow rescue enforcer, full body biped, weathered iron armor and black bronze joints, broken rescue insignia on chest, tattered ivory shoulder mantle, empty helmet with narrow eye slits, ceremonial short handled hammer in one hand, other hand empty, grounded balanced silhouette, realistic PBR, isolated character, no scenery, no baked magic effects.

## 第17关：精英记忆蛭

关卡「被删掉的人」：从记录中剪除身份的异常生物；与普通寄忆蛭有亲缘关系，但通过分叉头冠与剪切口器区分，不只是放大或染色。

- 非人形，贴地蠕动；直立最高点约主角身高0.8倍，身体宽约1.2倍。
- 深紫灰肉质、苍白硬质口器、背部多层薄片像被撕掉的名册；左右轮廓不完全对称。
- 口器为主要施法挂点，背冠为归档动作发光区域。保留清楚头尾方向，无巨型地面脓水网格。
- 动作由开发侧处理：低伏待机、抬首剪切、抽取增益、收拢背片归档、受击蜷缩、死亡塌落。
- 网格与骨架保持一致尺度；液体和死亡溶解由游戏特效实现，避免极大动画包围盒再次影响布阵尺寸。
- Meshy提示：Dark gothic fantasy elite memory leech, low crawling non humanoid creature, dark violet grey organic body, pale chitin shearing mandibles, forked crown, layered dorsal plates resembling torn archival pages, asymmetrical but readable silhouette, realistic PBR, isolated creature, no environment, no puddle mesh, no baked glow or spell effects.

## 交付与接入检查

优先GLB或FBX，附独立base color、normal、metallic/roughness纹理；保留原始可编辑文件。先检查轮廓、朝向和尺度，再做骨骼动作；不要求用户制作动画。进入战场后检查模型大小、落地、血条避脸、发射挂点、命中、取消和退场，再认定资产完成。
