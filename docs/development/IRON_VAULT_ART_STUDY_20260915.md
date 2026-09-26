# 档案守卫离线精修样例状态

用户要求以现有角色 GLB 继续向更高美术品质制作。目前最新样例为 `output/iron-vault-art-study-v4/`，属于独立 Blender 制作，没有替换游戏和手机资产。

- 第一轮：原模型材质、灯光和展示细节，`output/iron-vault-art-study/`。
- 第二轮：独立胸柜、锁具、铭牌、纸签，`output/iron-vault-art-study-v2/`。
- 第三轮：原身体表面与材质收敛、贴合掌心的机械件，`output/iron-vault-art-study-v3/`。
- 第四轮：三片头盔、完整独立前臂、上举手掌与十五段关节、肘部接口；实际七秒转头、逐指蓄力、飞臂和回装。制作及验证见第四轮 `README.md` 与 `motion-validation.json`。

第四轮试验中发现原前臂外壳跨过预设切面，飞出时残留半截。已在本样例中移除该融合表面并重建封闭前臂；不能再用早期错误姿态图作为交付证据。静帧和动作视频以第四轮 `*-final.png`、`mechanical-performance.mp4` 为准。

原始 `ArtSource/IronVaultSentinelRig/Source.glb`、正式战斗模型、手机安装和存档保留。第四轮使用分层机械变换，不是正式战斗骨骼包；没有命中回调、跨关清理或真机性能测试。本轮不能记为用户视觉验收通过，也不能宣称达到《魔兽世界》的完整角色成品水准。

## 第五轮增量（2026-09-15）

最新局部精修场景：`output/iron-vault-art-study-v5/IronVault_Cohesive.blend`。提高旧身体漆面覆盖、减弱法线噪声、统一新部件反光，头盔增加实体钥匙徽记与眉缘。两幅 Cycles 同机位图已渲染并查看，见该目录 README。属于小幅材质与标识进展，旧身体几何依然粗糙，未达目标；下一轮应优先重做旧几何而非再微调着色。第四轮动作保留但本轮未重新验证，无新视频，无手机集成。
