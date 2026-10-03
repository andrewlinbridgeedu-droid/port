# 169.27 装机与直接查看 · 2026-10-02

用户明确要求“装机我看看”。同一台 iPhone 13 经无线开发连接，从 169.26 更新到 169.27；安装回执和安装后应用列表确认了版本。未卸载 App，未恢复或反写任何存档。原始 Preferences 和设备命令回执仅留在 SSD 的 `Build169.27-ai-hero` 归档目录。

- 安装前后：264 份 Preferences 全部逐字节相同，见 `preferences-after-install.json`。
- 主角样板结束后：264 份仍全部逐字节相同，真实玩家和 audit 无豁免，见 `preferences-after-preview.json`。
- 启动参数：`--tempo-device-review=hero --tempo-speed=1 --tempo-preview-only`；没有录制参数。使用独立 DEBUG suite，不结算真实玩家奖励。
- 原生报告 `tempo-after-hero-x1.json`：169.27、主角展示 ×1、23.55 秒后 `preview-victory`，剩余 HP 861/1000、规则 round 8，Unity 锚点 1、前台状态。ReplayKit 未启动，`previewCompleted:true`；`completed:false` 是该旧字段记录录像完成，不能据此声称录制成功。
- 报告末端进程占用约 744.55 MiB。这只是单次终点值，没有持续采样，不能算峰值或性能合格证据。

手机处于使用中，iPhone 镜像提示需锁屏连接，未取得本轮镜像图。因此本轮证明安装、隔离预览和存档保护；不宣称作者逐帧观察了 iPhone 新动作，也不代表用户视觉认可。尚未做 ×2、三套服装逐一真机展示、三场完整复验、帧率或长期稳定性验证。PR #41 保持草稿。用户可用左下“换样板”重看本场或进入 Q4、D01、B01。
