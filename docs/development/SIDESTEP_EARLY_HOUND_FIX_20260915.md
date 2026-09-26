# 错步与早期地狱犬修复 · 2026-09-15

用户确认两项修复：错步不能与普攻同样演出；第三关「循名而来的猎犬」应使用旧地狱犬，新狗属于后期。

## 原因与处理

错步 `FoolTarotStrikeVFX` 原来加载与普攻相同的 `TarotNova`。本轮改用独立 `FoolSidestepRift` shader：错位双轨迹、交叉裂隙命中、短反向尾效与消散。普攻文件与原资源未变。保留 .6192 秒接触、一次回调、原时长和取消清理。角色自身施法动作依然共用，区别在独立技能特效；本轮不宣称重做主角骨骼动作。

新猎犬导入覆盖了全局 `hell-hound-primary` 展示。第3、4、6关现在发送 `early-hell-hound`，资源 `Enemies/EarlyHellHound/VisualProfile` 引用原 `Generated/HellHoundModel.prefab`（Emberwolf）、控制器与材质。早期狗不挂 `SignatureEnemyPresentation`，保留原远处火球；后期波次显式选择新铠甲犬，保留其独立法术。

缓存中的两种犬在非使用时分别拥有模板身份，只有当前选中那只持有 `hell-hound-primary`。这避免退场后可见性命令误选另一隐藏模型。第五关仍走翠焰亡灵替换路径；未改战斗数值、剧情、保存或奖励。

## 实际证据

`output/sidestep-hound-fix-20260915/` 含实际运行截图、最终日志与对比页。

定向 Unity macOS 独立运行验证（不是iOS模拟器）：
- 旧犬→新犬→旧犬身份与对应组件正确。
- 旧犬隐藏退场后重新显示，身份仍正确。
- 旧犬火球、普攻、错步均恰好一次接触。
- 错步一次完成；命中前取消无接触/完成与残留特效根对象。
- 已查看原犬、新犬及两种主角攻击的实际渲染；首轮特效过大，收紧后重跑通过。

不等于新档连续通关或用户视觉验收。真机构建/安装结果另行在下方记录。

源码备份：`backups/sidestep-hound-fix-20260915/`。

## 真机交付

Unity iPhone 导出、导出新鲜度校验、Xcode Debug iphoneos 构建通过。首次安装出现系统增量清单错误，构建编号由1升至2后重新签名构建并安装成功；没有卸载应用。iPhone 13 正常启动，安装及启动结果见 device-install-version2.json / device-launch.json。手机偏好存档在更新前已备份到 backups/sidestep-hound-fix-20260915/。实际手机内逐关战斗与视觉效果仍需用户复核，不能把启动成功当成完整战斗验收。
