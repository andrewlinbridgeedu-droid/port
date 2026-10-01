# 镜像时首页环境音异常

## 169.13：PR #38 已合入，完整复验尚未完成

2026-09-30 晚，将 PR #38 合入 `codex/housing-h3-verification-20260930`（`5ba38b4`），用外置 SSD 构建签名 Debug 169.13 并通过 USB 安装到同一台 iPhone 13、iOS 26.6。新包住处 22 项及原有 11 组自检通过。下面的诊断不等于用户听感确认或完整稳定性通过。

- 使用隔离住房账户和 `--housing-audio-review`，**没有**传入 `-MistportCityMute`；诊断确认 `environmentMuted:false`，扬声器路由、总线音量 0.6、输出时钟推进与有音量的循环节点。只读诊断写入独立 Documents JSON，不改音频启动逻辑、偏好或真实存档。
- 镜像实际打开并关闭过角色页，但该页覆盖首页，未触发首页音频停止；这些操作不计入“十次首页进出”。正确复验应从首页任务标题进入主线地图，再返回港城。
- 手机随后多次被其他操作切到设置、快捷指令和主屏幕。核查雾港进程仍为同一 PID，系统没有本轮时段的新 Mistport 崩溃文件；不能将这种切换记为崩溃，也不能将其当作受控的切换 App 测试。
- 用户最终表示先完成其他手机操作，镜像测试已停止；没有擅自继续切页。用户没有耳机，**耳机连接／断开未测**。
- [中途只读诊断](audio-interim-169.13.json)保留实测事件及“不满十次、耳机未测”标记。它仅证明上述短时输出状态，不能证明声音可听恢复、十次复验通过或所有路由稳定。

待继续：独占镜像下至少十次主线地图往返、一次受控的其他 App 往返、人工听感或录音确认声音恢复。耳机路由、电话中断、AirPlay、媒体服务重置及长时间压力目前均无新真机证据。PR #35 仍为草稿。完成剩余镜像与灯罩测试后，还须再次逐文件核对 Preferences。

## 169.12 历史异常与当时的临时静音

2026-09-30，在已安装修订版 169.12 的 iPhone 13（iOS 26.6）上用 iPhone 镜像操作时，首页出现一次未捕获的 Core Audio 异常。系统崩溃报告 `Mistport-2026-09-30-115130.ips` 的主线程栈为：

```text
com.apple.coreaudio.avfaudio: player did not see an IO cycle.
AVAudioPlayerNodeImpl::StartImpl
AVAudioPlayerNode.play
CityAmbience.play(_:volume:pan:rate:priority:)
CityAmbience.tick
CityAmbience.resumeTimer
```

原始系统报告包含设备与进程信息，只留本机私有目录，不提交。没有因此改动生产音频代码。后续住房手动流程使用项目已有的 DEBUG 参数 `-MistportCityMute YES`，仅本次启动的参数域生效，不保存静音偏好；首页音乐仍由原控制器运行。手动检查全部从隔离账户首页点击进入，未自动切页。阶段截图也采用相同环境音参数。

因此，本轮证据可以支持住房交互与页面复看，不能证明镜像条件下开启环境音稳定。后续需单独修复音频启动／路由变化处理，在相同真机与镜像条件下复验。Apple 对 [AVAudioEngine 配置变化通知](https://developer.apple.com/documentation/foundation/nsnotification/name-swift.struct/avaudioengineconfigurationchange) 的说明可作调查入口；本记录没有把该说明当作已经证实的根因。
