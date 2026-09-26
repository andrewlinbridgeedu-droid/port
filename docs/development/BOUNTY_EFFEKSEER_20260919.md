# 红绸与断链 Effekseer 命中改版

## 最新修正：恢复认可的起手

用户截图否定新增的锯齿红片。此前“图2达标”应保留红环与银剪起手，上一轮误改；现撤销 TornSilk 网格及其位姿，恢复原起手。Effekseer 命中部分保持，不表示用户已认可爆裂。交付视频另存 silk-restored.mp4，避免浏览器缓存旧红片。

用户否定平行红光和规则直角断链，要求使用 Effekseer。新增 SilkRupture / AnchorRupture 两个可编辑 efkproj，由项目自带 Effekseer importer 编译；生成脚本 tools/vfx/build_bounty_effekseer.py，纹理复用本地已存在素材，原文件未改。

BountyContactBurst 的 B05/B06 实际命中路径播放独立效果，跳过旧三条纵向光带/矩形链节。两套使用不同层级尺寸、数量、寿命和速度：红色宽裂光与细断口，蓝白斜冲击与高速碎光。组件禁用/销毁停止 Effekseer handle，不拥有伤害逻辑。B05 起手圆弧改不对称带破边的绸片，剪刃保留。其它物种和已认可 D04/B01 未改。

首轮实拍发现 aurora 纹理矩形边缘和圆粒，否决后改软边裂光纹理及 Z 轴随机旋转 billboard。第二轮查看起手、命中与尾段真实 Unity 帧，输出 output/bounty-effekseer-20260919/index.html 两段 30fps 视频。此版仍是候选，不代替用户视觉验收。

日志 bounty-effekseer-v2.log：两招无运行异常，各一次接触。bounty-effekseer-safety.log：两招取消零迟到接触、组件根清理、重试一次接触通过。日志复制在交付目录；未原生构建或安装手机。备份 backups/bounty-effekseer-20260919，存档/数值/源模型未改。
