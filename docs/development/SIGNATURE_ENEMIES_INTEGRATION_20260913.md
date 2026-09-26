# 三模型、六法术接入记录

用户批准接入猎犬、档案守卫、织幕女主，并将每只专属法术增至两招；最新视觉要求为约三分之一战场画面的法术飞舞，不能只在嘴边或目标处出现小团特效。

## 当前接入

|模型|关卡/槽位|专属法术|
|---|---|---|
|Hellhound Sentinel|替换现有猎犬美术，3/4/6追猎线继续；4关远程不改为扑近|冥焰吐息、锁名焰环|
|Archivist Sentinel|10关原抄录傀儡展示槽位，保留同场猎犬|终卷封存、千页追缉|
|Clockwork Veil Matriarch|15关原空壳守卫展示槽位，保留两颗寄忆核心|万缕夜幕、断线星雨|

这是模型、动作与法术表现接入；两招按有效攻击交替，未新增控制/多段伤害/减益/阶段规则，也未重做关卡数值、奖励和遗落物。内容ID和稳定战斗ID不变，仅 q10/q15 指定展示槽位使用新模型和显示名。第五关翠焰亡灵与铃的独立试演仍走原试演路径；本次不能据此宣布第五关剧情/遗落物迁移完成。完整步行以及1–20关全量模型替换不在本次完成范围。

三个源GLB、基础绑定blend保持原样。Combat目录新增FBX、动作源工程和贴图。导出30fps：Idle1–61，Charge62–104，Cast105–135，Hit136–147，Death148–178，Charge2 179–221，Cast2 222–252。Unity按实际take首帧偏移切片，21片段均检查到有效动画曲线和正确长度。

主要接入文件：ImportSignatureEnemies.cs、SignatureEnemyPresentation.cs、EnemySignatureSpellVFX.cs、两个Resources/EnemySignature shader，以及BattlePrototype/UnityBattleBridge签名敌人分支。Swift visualDescriptor仅在展示描述上添加@archivist/@matriarch，ConfigureWaveInstances剥离该标记后继续使用原稳定目标/接触ID。

## 校准与取消

FBX导入动画包围盒导致人形模型初版过大。最终按骨骼矩阵与bindpose逐顶点计算实际蒙皮边界，避免BakeMesh后再次TransformPoint导致双重缩放。尺寸相对阵型基准2.88：猎犬0.82、守卫1.10、女主1.16；重复校准结果保持2.362/3.168/3.341。正面朝玩家，脚底归到阵型平面。单猎犬场景继续使用现有单敌放大系数；多敌场景清除其遗留缩放。

每个敌人单独拥有施法组件和取消代次。死亡开始即取消，再播放Death和原有退场淡出。被取消的外层协程不会报告旧的完成或清场；守卫准备动作同样检查代次，防止0.65秒后发出死者接触事件。

## 已验证的证据

- 核心规则：177项既有Swift测试通过（/tmp/signature-core-tests.log）。这不是新档连续通关。
- Unity导入：三个模型、每个7片段，资源/材质/控制器创建成功（/tmp/import-signature-enemies.log、/tmp/signature-recalibration.log）。
- Mac真实运行：output/signature-spells-runtime-v3/ 内六招各52帧。六招各一次接触；中途停止零延迟接触；两敌同时施法、其中一敌死亡后，另一敌仍产生一次接触和一次完成；准备动作中死亡零接触/零完成。日志/tmp/signature-runtime-v3.log。
- 逐张查看六招飞行/爆发和q10/q15阵型截图。最终版扩大为左右火浪/链焰、两翼卷页、上空花形丝阵/针雨，主角轮廓可辨认。该检查不等于用户美术验收。
- 截图工具SignatureSpellCapture仅在编辑器/桌面运行参数下启用，调用实际战斗施法与桥接回调路径，未修改玩家或敌人血量。固定捕获帧率用于取图，不能据此声称真机60fps。

## iOS交付

Unity模拟器导出成功（/tmp/export-signature-ios.log），原生xcodebuild成功（/tmp/signature-ios-build.log，BUILD SUCCEEDED）。产物：/tmp/mindstone-current-simulator-build/Build/Products/Debug-iphonesimulator/Mistport.app。

安装/运行验证受测试模拟器故障阻塞：旧应用结束后，仅重启本项目的iPhone 16 Pro Max（F93741F2-6102-48FE-999B-EC2436F76CBF）；该设备SpringBoard黑屏，安装与bootstatus未完成。采样显示SpringBoard启动停在CFPREFERENCES_IS_WAITING_FOR_USER_CFPREFSD（/tmp/mistport-springboard-stall.txt），不是已启动新游戏后的崩溃。已尝试结束该设备内cfprefsd使其重启。q4/q10/q15的iOS界面实测仍未通过，不能把Mac预览当作iOS战斗验收。

可交付视觉证据：output/signature-spells-runtime-v3/six-spells-review.mp4（由实际运行逐帧图组成的六招并排视频），six-spells.png（各招峰值截图）。

原始待修改文件备份：backups/signature-enemies-20260913/。可复现的独立Unity预览应用：/tmp/mistport-signature-preview.app。
