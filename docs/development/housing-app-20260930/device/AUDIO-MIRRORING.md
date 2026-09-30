# 镜像时首页环境音异常

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
