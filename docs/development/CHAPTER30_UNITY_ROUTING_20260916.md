# 第一章16–30关：正式模型路由与退场整合

## 本批落地

- `BattlePrototype.ConfigureChapterThirtyMission` 与桥接命令 `chapter-thirty:16`…`chapter-thirty:30`，沿用原生权威伤害/目标与胜负。
- Q16旧犬；Q17 Codex执行者；Q18/23独立M13裁定锤卫；Q19翠焰亡灵；Q20/26独立M14押运锤卫；Q21洛克+核心；Q22/25维娅；Q24铠甲犬+真实幽灵；Q27白门卫+铠甲犬；Q28/30 Chronarch；Q29 Chronarch+新Codex+空壳守卫。
- 专用模板按资源加载；没有资源就明确失败，禁止拿普通守卫冒充新敌人。通用编队支持真实幽灵/赤红子体描述。
- Q29 Boss居中后排、略大，两护卫左右前方并轻微前后错位。
- Chronarch与两锤卫接入各自Strike和Cancel；跨关/退场清理法术。保留编队前的战斗启停状态。
- 修复旧撤离曾先播放Death的问题。非致命演员取消攻击后维持可见自然待机；Q28/29播Retreat，Q30显式进入Death状态再渐隐。无Death trigger的泛型Animator同样能正确播放Death片段。
- 调试蓝盘/灰蓝底座只在Editor或Standalone且显式传`--show-debug-arena-rings`时创建；iOS预处理从不创建。默认编辑器画面亦不再出现。

## 实际验证

`ChapterThirtyRosterPreview20260916.Begin`在Unity Editor Play Mode实际运行：

- Q16–30全部15编队，人数和稳定ID正确；每个演员攻击回调恰一次，取消后没有迟到回调。
- Q21/22/25非致命演员保持可见、能够恢复；Q20/28/29撤离、Q30真死亡渐隐及复显通过。Q30断言Animator正在Death，非仅计时器。
- 额外复测Q3/4/10撤离不播Death，以及Q13/15非致命与重显。
- 已人工查看Q16旧犬、Q18/Q20两独立锤卫、Q28单Boss、Q29三敌站位实际截图。
- 独立短视觉重拍关闭调试几何，保留上面的行为回执；未因纯背景变化重复全部动作验证。

证据：`output/chapter30-rosters-20260916/index.html`、`checks.txt`、`passed.txt`。日志复制到同目录。源文件修改前备份：`backups/chapter30-unity-routing-20260916/`。

## 边界

这些是实际Unity模型/动画/联系回调检查，不是原生连续通关、平衡或真机验收。Q28/29五完整循环、Q20截救、Q25断契、Q26供能条由核心引擎实现。Q24幽灵死亡分裂后的动态编队必须由原生子体事件同步，不能再发静态整关入口复活母体。未执行iOS导出或安装。
