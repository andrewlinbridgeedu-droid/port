# 169.28 装机与直接查看

实际查询安装前为 169.27；通过开发连接安装后为 169.28。设备为同一台 iPhone 13。构建与签名归档均在 SSD，Unity 导出逐项新鲜度核对通过，旧构建和符号链接未覆盖。

- 安装前备份、安装后备份完成后的比较、主角样板复看后的比较：264 份 Preferences 全部字节一致，真实玩家与 audit 均不豁免。备份实体只在 SSD，没有反写或恢复任何文件。
- 保留原有 ×1 偏好，启动 `--tempo-device-review=hero --tempo-speed=1 --tempo-preview-only`，没有 ReplayKit 录制或额外 UIKit 战斗抓图。
- 原生隔离样板复看完成：169.28、hero、×1、`preview-victory`，22.334 秒，8 回合、861/1000 HP、1 个 Unity 锚点，前台可见；没有向真实玩家发奖。777.53 MiB 只是结束时足迹，未测峰值或帧率。`completed:false` 是旧录制标记，直接查看由 `previewCompleted:true` 确認。
- iPhone 镜像实际抽看新人物、飞牌、假面与大型命中效果，保存 `mirroring-cast-01.png`（大型命中效果）与 `mirroring-cast-02.png`（收招后站姿）。这两张是镜像窗口截图，Mac 的逐招 PNG 另外放在 `../unity-mac/`。
- 抽看手动假面时曾出现浅褐色三角轮廓，尚未逐帧定位其来源，不能记为整个视觉完全合格。镜像随后窗口不可用，未完成三场、三套衣装及 ×2 的真机逐招复验；留在主角样板菜单供用户继续看。用户尚未认可本版，PR #41 保持草稿。

比较脚本曾在安装后备份仍传输时过早读取目录，当时仅收到 223 份并报告失败。此未完成快照的报告保留在 SSD `preferences-after-install.json`；等 `devicectl copy` 明确完成后重跑严格比较，264/264 全部一致，见 `preferences-after-install-complete.json`。没有放宽断言、没有覆盖失败记录。启动命令早于复制完成，本轮并非完全严格的“复制结束后再启动”时序；后续对装机前基线的最终严格比较同样全部一致。

原始备份、命令收据和签名包路径：`/Volumes/andrew's SSD/Mistport-archives/releases/Build169.28-ai-hero-spells/`。用户请求的视觉复看不以构建、回执或截图成功代替。
