# 雾港城市 Blender 试作

这是按通缉调查地图布局制作的**可编辑 3D 场景试作**，不是现行游戏地图。当前游戏仍使用 `mistport-ios/Mistport/Assets.xcassets/BountyCityPanorama.imageset/city.png`，保持原画的细节和色彩。

## 文件

- `BountyHarborCity.blend`：可编辑源工程，房屋、钟楼、教会、桥、树、运河等为独立几何体。
- `BountyHarborCity.glb`：完整场景预览，约 2,987 个网格、241,017 个三角面、24 种材质及 4 张内嵌纹理。
- `BountyHarborCity-mobile.glb`：按材质合并到 24 个网格，保留相同三角面、材质与 8 个 `DOOR_` 定位点；只是低绘制调用预览，尚未在 iPhone 上做性能测试。
- `render-overview.png`、`render-clock-square.png`、`render-west-street.png`：Blender Cycles 实际渲染。
- `textures/`：场景材质原图；原始生成素材另存于项目的 `.codex/generated_images/`。

## 复现

使用 Blender 5.2：先运行 `build_city.py`，再打开生成的 `.blend` 运行 `polish_city.py`。从润色后的 `.blend` 运行 `render_closeups.py` 生成两个近景，并运行 `export_mobile.py` 生成合并网格的 GLB。完整场景不因移动预览导出而被合并。

## 现状

已经是真正可转角度查看的几何场景，但建筑造型、立面装饰、植被、水道边缘和整体密度都比用户提供的精细城市原画简单很多。当前仅供空间结构与门点位置验证，**不应替换正式插画地图，也不能称为最终美术资产**。尚缺手机端性能、碰撞、导航和室内外衔接验收。
