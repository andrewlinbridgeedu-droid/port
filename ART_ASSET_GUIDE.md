# 美术资源指南

本工作区的美术按生命周期分为四类：规范、源素材、处理中间件、运行时资源。目录名中的 `generated` 或 `output` 不代表资源已经获准进入 App。

## 唯一运行时边界

| 产品 | 运行时资源位置 | 说明 |
|---|---|---|
| Mistport iOS | `mistport-ios/Mistport/Assets.xcassets/`、`mistport-ios/Mistport/Art/` | Xcode 构建实际打包的正式资源；移动或改名必须同步工程和代码引用 |

其他目录默认都不是运行时真相。

## Mistport 生产资料

| 位置 | 当前角色 | 处理建议 |
|---|---|---|
| `mistport-ios/ArtSource/` | iOS 主工程的大型生成源图、地图和候选稿 | 保留原分辨率；新内容按资产族分目录 |
| `mistport-ios/art-source/` | 若干战斗精灵源条 | 视为待合并的旧命名入口；不要继续扩散新资产 |
| `mistport-ios/ArtArchive/` | 已撤换地图、导航图标等 | 只用于追溯，不重新导入而不做评审 |
| `design/concept-art/` | 第一章角色、场景和地图概念终稿/候选稿 | 作为概念和评审依据，不等于运行时导出 |
| `design/sprites/` | 精灵源表、透明化结果与拆帧 | 生产源和处理中间件，按动作批次管理 |
| `art-source/`、根 `ArtSource/` | 较早的 UI、角色和敌人源素材 | 遗留入口；迁移前先核对脚本与 Asset Catalog |
| `art-pipeline/` | 特定敌人动作的处理工作区 | 可重复生产的工作目录，保留参数和脚本关联 |
| `output/imagegen/`、`output/sprites/` | 生成与规范化输出 | 候选产物；经检查后才能导入运行时目录 |

目前这些目录存在历史重叠。为降低引用风险，本轮不物理合并；新资产应优先使用 `mistport-ios/ArtSource/<AssetFamily>/` 作为源文件入口，并把最终导出放入 Asset Catalog。`Mistport/Art/` 目前虽随工程存在，但不应继续作为新的精灵导入入口。

## 美术指导文件

按下列顺序使用：

1. `mistport-ios/ART_DIRECTION.md`：当前整体视觉、商业交付和版权边界；
2. `design/ART_BIBLE_BRIGHT_DREAM_JRPG.md`：更具体的明亮幻想 JRPG 视觉语言，若与当前方向冲突需先裁决；
3. `docs/first-chapter-enemy-art-bible.md`：第一章敌人设计；
4. `docs/combat-animation-asset-standard.md`：战斗动画资产通用规格；
5. `mistport-ios/FOOL_ANIMATION_CONTRACT.md`：愚者动作的程序接口契约；
6. `mistport-ios/ANIMATION_WORKBENCH.md`：动画工作台操作；
7. `mistport-ios/ENEMY_3D_PIPELINE.md`：Unity 3D 敌人的导入、规范化、校准、阵型和验收；
8. `mistport-ios/ART_PROMPTS.md` 与 `design/prompts/`：生成记录，不是高于美术圣经的设计规范；
9. `mistport-ios/ART_DIRECTION_V1.md`、`CHARACTER_FACE_AUDIT_V1.md`、`mistport-ios/docs/legacy/game-design-v0.5/DESIGN_AUTHORITY_V1.md`：带版本的历史或审计材料，使用前检查其状态说明。

## 推荐资产结构

新生产批次使用稳定的资产族和动作名，不再按工具名散落：

```text
mistport-ios/ArtSource/
  Characters/<Character>/<Action>/<Version>/
  Enemies/<Enemy>/<Action>/<Version>/
  Environments/<District>/<Scene>/<Version>/
  UI/<Feature>/<Version>/
  Maps/<District>/<Version>/
```

每个批次至少保留：

- `source.*`：原始可编辑文件或最高质量源图；
- `preview.png`：供人评审的静态预览；
- `manifest.json` 或 README：资产 ID、版本、尺寸、帧顺序、来源、生成参数和授权状态；
- `frames/`：只有程序实际需要逐帧输入时才保留；
- 最终运行时文件导入 `Assets.xcassets/<AssetID>.*set/`，不要从 `output/` 直接运行。

## 命名与版本

- 代码资产 ID 使用稳定英文 PascalCase，例如 `FoolSouthAttack`。
- 文件和生产目录使用可读英文，不依赖 `final-final`；版本统一为 `v1`、`v2`。
- 动作方向固定使用 `north`、`south`、`east`、`west`，帧号补零，例如 `frame-01.png`。
- `source`、`alpha`、`normalized`、`preview`、`runtime` 明确标注阶段。
- 被替换批次移入 `ArtArchive/<AssetFamily>/<YYYY-MM-DD>/`，并记录替代资产 ID。

## 导入检查单

1. 确认资产符合 `ART_DIRECTION.md`，并记录原创来源和商用授权状态。
2. 校验画布尺寸、透明通道、颜色空间、方向、锚点和帧顺序。
3. 使用现有脚本完成去背、拆帧或规范化；不要手工覆盖唯一源文件。
4. 将发布导出导入 Asset Catalog，并使用稳定资产 ID。
5. 搜索旧 ID 和路径引用，更新 Swift、Xcode、Shell、Python 和文档。
6. 在目标 iPhone 尺寸检查裁切、清晰度、内存、动画和深浅背景表现。
7. 验收后才把旧运行时资源移入 `ArtArchive/`。

## 移动前检查

资源重排至少执行以下只读搜索：

```bash
rg -n "<asset-id-or-path>" mistport-ios scripts design docs
```

特别保护以下边界：Xcode `project.pbxproj`、所有 `Contents.json`、Swift 中的 `Image(...)`/`SKTexture(...)`，以及 Shell/Python 脚本中的相对目录。未经这些检查，不应批量重命名或移动资源。
