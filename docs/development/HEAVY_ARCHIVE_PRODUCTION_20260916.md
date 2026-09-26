# 裁决重卫与押运重卫制作

按 chapter-one-30/MODEL_BUDGET 的 M13/M14 对应关系制作，未用旧普通守卫改名充数。

| 项目 | M13 裁决重卫 | M14 押运重卫 |
|---|---|---|
| 用户母版 | Iron_Star_Sentinel_0916094930 | Iron_Vanguard_0916102127 |
| 使用 | Q18/J19、Q23/J25 不同实例 | Q20/V21 活着撤运、Q26/V21 真正摧毁 |
| 原三角面 | 1,933,436 | 1,195,936 |
| 制作三角面 | 65,000 | 65,000 |
| 骨架 | 18骨/最多4权重 | 18骨/最多4权重 |
| 归档 | ArtSource/ArchiveAdjudicator20260916 | ArtSource/ArchiveConvoy20260916 |
| Unity Resources | Enemies/Signature/ArchiveAdjudicator/VisualProfile | Enemies/Signature/ArchiveConvoy/VisualProfile |
| 路由约定 | @adjudicator / adjudicator-template | @convoy / convoy-template |

原 Downloads 两文件已被移到废纸篓。本批在 `.Trash` 找到原件，分别核对与之前 intake manifest SHA256 完全相等后复制到上述 ArtSource；未移动/清空废纸篓。原高模保留。

## 绑定与动作

每只独立关节坐标与骨骼。单根刚性武器骨保留完整锤头/握柄，双手握持骨随武器，前臂使用两骨 IK 追踪握持点，再将实际求解结果烘焙到动画，避免两手漂离锤柄或弯曲长柄。热权重与局部刚性武器权重结合，限制4权重并归一化。

八段动作：Idle/Charge/Cast/Hit/Death/Charge2/Cast2/Retreat。第一招调整横锤判令，第二招抬高双手锤压迫；押运重卫抬升更高、回压方向不同，待机保持双手承重而非放开武器摆臂。固定脚位，尚无行走循环；Retreat 为非死亡收势，由导演随后作退场。

保存可编辑 `.blend`、FBX/GLB、2K PBR三图、生成与验证脚本。Blender连续边界检查采用1e-5四元数分量容差，因为实际IK烘焙存在最大约9e-6浮点残差，未放宽到可见姿态差。脚底最低点固定，实际蒙皮在多帧发生变化。

## Unity接口与验收边界

handle 添加 `HeavyArchivePresentation20260916`；M14 设置 `isConvoy=true`；调用 `FitRestPose()`。`Strike(handle,target,contact,valid)` 只在一次接触回调中交给规则层计算；取消/隐藏/重试调用 `Cancel()`。Q20非致命撤离用 `BeginRetreat()`，不播Death。Q26由死亡导演播Death并渐隐。

`ImportHeavyArchives20260916.Import` 只生成独立资源，不编辑共享场景。单体PlayMode验证真实蒙皮、两种出招各一次接触、取消无接触、Retreat、Death→Idle恢复；整章组合测试由 `ChapterThirtyRosterPreview20260916` 负责。输出在 `output/archiveadjudicator-delivery-20260916/` 与 `output/archiveconvoy-delivery-20260916/`。

本批只是模型/动画与基础冲击演出。精细法术视觉尚待用户整关复核；未宣称手机视觉验收、数学通关或全部关卡已安装。
