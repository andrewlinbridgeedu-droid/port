# Mistport 参考级战斗特效方法

## 目标

参考图不是“很多粒子叠在一起”，而是一个由主形体控制观感的三拍效果：

1. **主形体**：一张有明确轮廓的连续素材，负责第一眼识别。
2. **流场**：噪声只扭曲主形体边缘和局部亮度，不把主体切成碎片。
3. **冲击层**：命中瞬间扩大主形体，并用少量弧线、火舌或叶片强调方向。
4. **前景遮挡**：冲击峰值使用 `ZTest Always`，主角仍然渲染，但被法术淹没。

细节层永远不能承担主轮廓。缩小到 showcase 缩略图时，先看到的是一整团火/风，再看到细节。

## 素材映射

| 效果 | 主形体 | 流场噪声 | 辅助层 |
| --- | --- | --- |
| Fire Elementalist | `MistportFireVolume.shader` 连续火幕/火舌 | `Effects/HellHound/Texture/FractalNoise_2.png` | `fire_tex.png` 只做低强度火焰细节、`Fire_Single.png` 做一根前景火舌 |
| Wild Warden | `MistportWindVolume.shader` 连续风柱/双螺旋流带 | `Effects/HellHound/Texture/FractalNoise_2.png` | `Feather.png` 少量叶片、单条宽流带 |

`Fire.png` 四格贴图和大量独立 Quad 不得再作为爆炸主形体；它们只适合少量辅助火舌/残片。规则圆环也不能作为爆炸主体。

## 运行时实现

- `MistportReferenceFlowSprite.shader` 采样主形体和噪声，通过 `_Phase` 连续滚动，通过 `_Distortion` 只扰动外缘。
- Fire/Wild 的主爆发使用 `MistportFireVolume.shader` / `MistportWindVolume.shader`：轮廓由连续密度函数生成，现成贴图只进入细节和流场采样，避免把 `fire_tex` 的对称翅形或 `aurora01` 的方形边界直接带进游戏。
- 主体材质使用 `ZTest Always`、透明混合和高 render queue，确保角色不会“透过技能看见”。
- 每个效果的 C# 协程只负责时间轴、锚点、缩放和层级；素材不在截图上手工摆放。
- 统一按 `travel → contact → impact hold → fade` 四段时间轴制作。飞行结束后必须保留完整的命中和爆发停留，不能在命中前开始淡出。

## 审查标准

每个新效果必须通过以下检查才进入游戏：

- 8 个时间节点中，飞行、命中、爆发、残留均可辨认。
- 爆发峰值覆盖主角轮廓，但没有关闭主角 Renderer。
- 缩略图不呈现规则圆、方形卡片、编织线或九宫格贴图。
- 只改变新效果的 recipe，不修改已经确认的 Fireball 五帧和 Sword Qi。
- 停止、重播、切换下一张卡后没有残留 GameObject、材质或 Effekseer handle。
