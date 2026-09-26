# 港城入口与地图标记（2026-09-25）

首页剧情继续由蜡封「档案街入口」进入；底部原「征战」改为「进入港城」，打开可拖动、100%–260% 缩放的港城街景。港城里可沿路步行至建筑，再进入教会、酒馆通缉板或已开放的咖啡馆；顶部有明确的「返回主页」。港城本身不直接开主线战斗。

用户要求的原简线门图已从 `ButtonArt16MapRunesEnter` 换成新绘制的港城门图，并作为首页 `GameNavHarborAnime` 使用。旧卷轴剑图 `GameNavConquestAnime` 保留原件，SHA256 仍为 `af1ee9a448fd891d9aa4b0da8595a103cbd299c53c4705a9d768199a6a31cc18`，首页港城按钮已不再使用它。旧简线门图备份在 `backups/harbor-entry-20260925`。

建筑标记改为屋顶文字，酒馆只显示「酒馆」两字；进门落点仍在路面。早期 Build 78 曾暂用 `AmbientFemaleWalkAtlas`、`AmbientMaleWalkAtlas`、`AmbientElderWalkAtlas`；后续已改用侧面重渲染的 Blender/GLTF 行人，补齐轻点对话、悬停停步和路线修正。港城背景仍是二维街景，人物的可编辑三维模型另存于 `ArtSource/HarborCitizens20260925`，不应称整座城市为实时三维场景。现状见 `HARBOR_MAP_DAYNIGHT_NPC_20260925.md`。

早期签名 iOS Build 78 已通过 `xcodebuild` 与 `codesign --verify --deep --strict`；此记录仅说明当时批次，不代表现行手机版本。新图由内置 imagegen 生成，提示词要求港城石拱门、暖光与青蓝雾气、透明背景、小尺寸可辨；源图保留在 Codex generated_images，正式位图在项目 Assets.xcassets。
