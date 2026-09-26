# 新版法术 Build126 与装机验证

截至 2026-09-26 00:00，修正后的 Unity iOS 导出、签名设备整包编译链接及签名深验证通过，**Build126 已覆盖安装并普通无参数启动**。Q6 的 M12 蓝盾在真机实看；Q7 的 M15 与 H10 尚无有效真机片。安装和普通启动未改变原57份 Preferences；Q6/Q7 审计后只新增独立 `mistport.p1-ui-verification.plist`，正常玩家与旧审计玩家 plist 逐字节未变。镜像在Q7中断，当前最后一次游戏进程可能带审计参数，尚未恢复最终普通启动。

2026-09-26续：针对该Q6片的平淡感，M12另做[深蓝护片与快速展开](M12_DEPLOY_GRADE_20260926.md)，签名Build127已完成但未装机。本页以下手机证据仍只属于Build126；不能拿它验收Build127的峰值。

[补修影片入口](../../output/spell-impact-device-20260925/index.html) · [构建回执](../../output/spell-impact-device-20260925/final-build126.json) · [前一批82段](SPELL_IMPACT_GRADE_20260925.md)

## 本次纠正

- M12 封存装甲：移除可读为四角框的主体，改成三片角度、宽度不同的弯曲护片；中央留出脸与身体。纹理只采原图内部局部，不让原纹理边界形成闭合盾框。仍是蓝银防护，不增加伤害爆炸。
- M15 记忆攻击：使用新绘纸纤维与墨迹 RGBA，映射在五片不规则薄纸曲面。去尖硬冰晶轮廓与金属亮脊，增加深靛笔迹和断续紫边以抵消浅灰广场背景。新原画 SHA256 为 `9028953cbfabebd0e5acb414cc279e7192c3f16b0ed10d64f7aff08e121c0479`，运行 PNG 与母版逐字节一致。

两项修改保留原伤害、CD、目标与 contact；H00 动作与恢复版大范围未改。M12 从上一轮未改对照转为本轮修改对象，因此累计为 **16个独立身份、19个主批修改表现组、8个未改对照**。这不是重新录制了全章或重新录齐82段。

## 实录与安全

补修首轮4组8段，录制26项、安全62项；最终纸墨对比微调2组4段，录制18项、安全36项。检查有重叠，不能相加作独立总数。页面选择8段：M12/M16来自补修首轮，M15与M15受体来自最终纸墨版；最初4段M15留作过程证据。

已实际看M12全景/近景全时长各24帧与24帧连续状态窗；最终M15全景、施法者近景、受体近景全时长各24帧，以及全景/受体接触窗各24连续帧。M16未改对照全景/近景全时长各24帧已看；治疗受益者仅全景可见。额外M15受体全景留原片，未额外计独立复看。没有实时播放全片、没有看遍原始每帧、无音轨。

M12现在是左右开口蓝色护片，四角框消失。M15的纸纤维、墨字与紫边已能读为破页，峰值约1.067–1.167秒展开，约1.5秒收去；峰值仍会遮身体。主任务也实际看过最终连续窗并要求以该版本入包；这不等于用户已认可参考图力度。

## 构建与同源边界

- 修正后 Unity iOS 导出退出0，导出 freshness 检查通过。
- Xcode Debug arm64 Build126 完整编译、IL2CPP/原生链接及开发签名成功，`codesign --verify --deep --strict` 退出0。包括正式 player-impact 桥接，以及主任务新增的 audit-only 塔层/通缉直达入口；这些 Swift 代码已参与完整编译。
- 原生二进制 SHA256：`9e384a9e831b8feae14642f569c261a563dca0c0d2ae2119934d1d5bd130d8d8`。
- UnityFramework SHA256：`e86adb2e8cfea50cde44eebd0a00975bb8a751459ebda1ec604b879f86fc153d`。
- 最终纸墨版的400项 `.cs/.shader` 清单 SHA256：`f9a028f37c61a2268825f8fa8c65852aff5dda4e7d045453e4e4c5a34c420ed5`；打包后逐项核当前源码全部相同。
- [导出运行文件清单](../../output/spell-impact-device-20260925/final-export-manifest.txt) 和 [14项关键源码/资源快照](../../output/spell-impact-device-20260925/final-source-snapshot.json) 另含资源与协作 Swift 源码。快照在 `backups/spell-impact-device-20260925/final-build126`。

之前82段的清单 SHA 是 `30d756229bbb6c1426f9577344bed2f5ce3973a9b45fb1b75de44049d78b0b19`；该批录制与安全仍对应当时版本，**不能称全部82段与当前补修后的源码同源**。早先未补修的基线也用Build126构建，但从未安装；以本页二进制SHA与 `xcode-final126.log` 辨别最终包。

## 手机与存档

23:32只读复制了当前手机57份 Preferences 到 `output/spell-impact-device-20260925/device-before/Preferences`，逐文件SHA在同级 `preferences-manifest.json`；安装前设备为Build125。23:45以覆盖方式成功安装Build126，随后无参数正常启动，真机首页可见；[安装回执](../../output/spell-impact-device-20260925/install126.json)与[正常启动回执](../../output/spell-impact-device-20260925/normal-launch126.json)均为成功。安装确认与正常启动后57份 Preferences 对初始基线**逐文件完全相同**，见[首轮存档比较](../../output/spell-impact-device-20260925/initial-save-comparison.json)。未卸载、未覆盖旧备份，塔F1–10原审计进度保留。

随后以隔离审计参数进入Q6。初次黑屏来自镜像画面停滞：返回主屏也不更新；重开镜像后**相同参数**可显示战前Unity 3D、HUD和战斗，因此没有改游戏或重装。Q6实景的封存装甲由左右不等蓝色护片构成，四角框已消失，参考[真机接触时序](../../output/spell-impact-device-20260925/phone/q6-contact-sheet.jpg)。在手机常规观看尺寸下蓝面仍偏平，色彩层次与图1力度未达用户验收。盾招按防御身份不强加伤害爆炸。Q6原生会话[接触记录](../../output/spell-impact-device-20260925/native-enemy-contacts.json)里 `guard` 为0伤害，三次`archive_slam`各400，HP实际1000→600→200→0；该记录证明规则结算，不单凭它声称Unity受击动画已获完整验收。

Q7虽曾显示战前画面，但连拍85帧全部是系统“iPhone使用中”断开提示，不能当M15或主角受击片。只读复核：Q6/Q7审计后原有57个Preferences文件无变动，只新增隔离`mistport.p1-ui-verification.plist`；正常玩家`mistport.player-test-01-15.plist`与审计玩家`mistport.player-test-01-15.audit.plist`对本次测试前均逐字节相同。镜像重连复发后停止手机操作，未碰用户当时的其他界面，也未强拉游戏回前台。当前需在设备能连续空闲时重做Q7/H10、塔/通缉直达，并以无参数正常启动和最终存档对比收尾。

## 仍存边界

M26/M29部分暖棕背面平涂、M31峰前与爆峰反差、部分大面遮身和H10四目标局部偏白保留；本次没有借装机构建无止境重做。Q6虽已真机实看，但**M12仍偏平**；Q7/M15、H10、声音混音、帧率/性能、新桥接受击动画的完整真实战斗核验、全章逐招与用户视觉认可未完成。R02–R10原生被动附效的逐项触发录像也未在此补齐。
