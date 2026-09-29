# 每日玩法任务 0：Mac 编译与设备验证 · 2026-09-29

从 `main` 的 `10d0500` 开始。规则库 **516 个测试全过**；原始 main 编译成功，无需类型错误修复。Build 160、161 均已签名并装到配对的 iPhone 13。当前交付为 **Build 161**。

## 改动

- 深井地图层号的颜色和 VoiceOver 状态也遵守按天额度；此前进入按钮已禁用，但 F5 层号仍宣称“可进入”。点击层号仍可查看锁定原因。
- `--verify-daily-pacing` 增加真实开战入口检查：第 1 天封完四层后 F5 被拒绝，已封堵 F4 可以重打。
- 新增显式 DEBUG 走查入口 `--daily-pacing-device-walk`，仅重置 `mistport.daily-pacing-device-walk.v1` 独立 suite；播种已过 Q3、已封四层、第 1 天。不会使用玩家真实 suite。
- 走查加 `--preview-city` 显示“第 4 关明天开放”，加 `--daily-pacing-tower` 显示 F5 锁定，加 `--daily-pacing-gear` 展示封线装备。页面四秒后保存实际设备窗口截图到 Documents。

## 已验证

- `swift test --package-path mistport-ios/MistportCombatCore --scratch-path "/Volumes/andrew's SSD/Mistport-build-cache/daily-loop-core"`：516 个测试、92 个 suite，通过。
- `xcodebuild -project mistport-ios/Mistport.xcodeproj -scheme Mistport -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath "/Volumes/andrew's SSD/Mistport-build-cache/bridge-dd" -jobs 2 CURRENT_PROJECT_VERSION=161 build`：成功。Unity 导出新鲜度检查通过，未修改 Unity。
- Build 161 真机五组 DEBUG 自检全部通过，见 [日志摘录](debug-checks-161.txt)。包括 daily-pacing、player-growth、church-tower、bounty-daily-risk、p0；自检使用独立 suite。
- [城市截图](city.png)：Q3 已过，显示“第 4 关明天开放”。[深井截图](tower.png)：F1–4 已封、F5 层号灰色、进入按钮禁用且原因可读。[封线装备截图](gear.png)：隔离新档中的通缉栏布局，**不是已领取遗落物的展示**。
- Build 160 安装后 72/72 个 Preferences 文件逐字节一致；首次启动只改变玩家主 plist，其他 71 个文件一致。真实玩家为已过八关、八层的旧档；按天记录 `origin=migrated`，对应第 7 天，规则额度覆盖下一关 Q9 和下一层 F9。再次打开后玩家主 plist 逐字节一致。
- Build 161 安装后 79/79 个 Preferences 文件逐字节一致；自检和截图后所有原有文件仍逐字节一致，仅新增隔离走查 suite 和自检清空后的 plist。见 [Build 160 迁移报告](verification-160.json)、[Build 161 报告](verification-161.json)。

## 任务单“只新增按天键”的实际差异

手机原为 Build 159，还没有通缉遗落物迁移。因此首次打开新版除了新增 `mistport.daily-pacing.start.v1`，还更新了 `mistport.church.services.v1`：B07 旧护甲转为 B07 遗落物，护甲位替换为玩家已有的 F8 甲；写入迁移回执及新增账本默认值。通缉进度和随身遗落物状态的差异仅为 Set 编码顺序，语义一致。铜币、功勋、主线、背包等所有其他玩家键未变，没有重复发奖。第二次启动没有再次迁移。**不能将本次记录写成“真实旧档只新增一个键”。**

## 证据与待验收

- 本机完整日志和 Preferences 备份：`output/daily-loop-task0-20260929/`。真实存档备份不入 Git。
- 签名包：`/Volumes/andrew's SSD/Mistport-archives/releases/Build161/Mistport.app`。
- 已请用户看通缉栏、案卷遗落物说明、墙关失败提示和通缉战败说明；**尚未获得用户视觉/手感认可**。截图和自检不能代替认可。
- 尚未通过真人在真机上逐项手动走查；F4 重打验证为真实入口自检，不是手动打完一场。
- 任务 1、2 尚未完成；本文不代表每日玩法接入、真机计时或经济验收通过。
