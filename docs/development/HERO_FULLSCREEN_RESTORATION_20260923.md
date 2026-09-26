# 主角全屏命中层恢复 · 2026-09-23

用户在 `output/all-spell-reference-20260923/index.html` 指出旧版全屏效果被取消：截图中仅剩敌人附近一小段紫色斜光。此前全法术批的录制与安全检查通过，不能证明视觉达标；将它当成可交付版本是错误判断。

## 根因与修复

- 对照 `output/whole-spell-round2-20260922/before/hero-independent/hero-basic.jpg` 和原全屏 shader 备份，发现 `TarotNova.shader` 被改成局部细线，移除了紫金飞牌、卷曲雾焰、碎光与全屏余韵。这与 `BASIC_COMPACT_20260922.md` 中“只修改普攻身体表现，不缩小飞牌/接触特效”的承诺相反。
- `HeroSpellVolume.shader` 同批还缩小了 H04/H05/H06/H07/H08/H10 的屏幕空间主体，H07 原有跨画面金色斜裂尤其明显地消失。
- H00 将 `TarotNova.shader` 恢复到 `backups/whole-spell-round2-20260922/hero` 的原版，保留现行短促身体动作、离手及 contact 时刻。H04/H05/H06/H07/H08/H10 恢复原全屏分支；H04–H08 加分招强度控制，以免白闪完全遮挡瓷脸、牌面与人物。现行 `HeroSpellVolume.cs` 的锚点和状态照明修正保留。
- 修改前 shader 和原缩小版 H00 片段留在 `backups/h00-fullscreen-restoration-20260923`；对照页 `output/h00-fullscreen-repair-20260923/index.html` 保留缩小版与恢复版。未改伤害、治疗、冷却、首现条件、存档或塔开放层数。

## 复核

- H00 单次/连发/接 H07 定向 Unity 实录 6 段，28 项录制检查和 24 项安全检查通过；0.58 秒 contact 及快速身体收势保留。实际查看 0.5–1.3 秒连续帧，恢复版在 0.83–1.3 秒能见跨战场紫金飞牌、雾焰、碎光。
- H04/H05/H06/H07/H08/H10 定向实录并查看同帧前后拼图，H07 恢复横贯画面的金色斜裂；H04 瓷脸、H05 烙印、H06 蓝白行动、H08 幕布等仍各有主体，调低恢复后过曝的白芯。拼图位于 `output/h00-fullscreen-repair-20260923/hero-screen-toned.jpg`。
- 正式总览 81 组／162 段和通缉犯 15 组／45 段均已用最终 shader 全量重录，两份 `record-all-source-sha256.txt` 完全相同，分别 382、63 条录制检查通过。主角恢复对象 H00/H04/H05/H06/H07/H08/H10 再经 96 条最终安全检查，源码校验与正式总览相同。总览 96 组／207 段的 `review-manifest.json` 已重新生成并逐片记 SHA256，14 张全法术与 9 张通缉犯时序拼图已从新录像重新生成；页面 277 个本地链接全部存在。
- Unity iOS Device 导出通过，`unity-export64.log` 显示成功退出。导出清单含 H00 `TarotNova.shader` SHA256 `4613d052556dedaeb209e1011b2ab0214b9c222289a204afbe39a938106afabd`、主角屏幕层 `HeroSpellVolume.shader` SHA256 `40e7a1f13b3c02a92e1b78904c71981007cbc6efc088cad610ea7d9863f4756e`，与正式录制时源码相同。
- Xcode 签名 Debug-iphoneos **Build 64** 构建通过（`output/h00-fullscreen-repair-20260923/xcodebuild-device64.log`），`codesign --verify --deep --strict` 通过。Build 64 已覆盖安装在配对 iPhone 13，设备列表确认 `0.1.0 (64)`；启动后进程列表可见 `Mistport.app/Mistport` PID 25490。安装前、安装后、启动后导出的偏好存档 SHA256 均为 `275b190cffe1554446f611447eee5dad00a504ab4c058dc919f09a5acb57e05a`，没有卸载或清空存档。这证明更新、启动和存档未变，不证明逐招真机画质或帧率。

Unity 录像和检查不等于用户已认可视觉，也不证明手机上逐招画质或帧率。
