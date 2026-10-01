# 战斗节奏样板：Q4、D01、B01

本批只改三场节奏与样板表现；另按用户要求替换 Q3 猎犬扑咬身体动作。×1／×2 按钮、飘字和受击边缘反馈放在共用战斗页。用户视觉认可仍待完成，未推广其余战斗的节奏和 Blender 动作。

## 实现

- App 开战采用 `MPCCombatTempo.profile`，轻击排程／结算采用 `MPCLightAttackClock`，普攻间隔与恢复取规则库。×2 用墙钟累积，规则仍以 50 毫秒一格推进，Unity 时间同步；选择仅写新键 `mistport.combat.presentation-speed.v1`。
- 飘字显示真实伤害、误认／错位加成、招架、护盾、净化。会心的金色样式已预留，但当前规则没有会心事件，未伪造会心命中或声称验证过会心。
- Blender 原创关键帧产出四个模型动作库，保留既有资产。猎犬拆分下颚权重；石颚修脚骨层级；主角保留原有脸部、衣摆、材质，由新骨架驱动原有皮肤。原衣摆的表现仍保留原组件；新增 FBX 的衣摆弹簧不应被当作所有原服装均已换权重。
- Unity 样板使用根运动、脚 IK、目标注视、尾／耳弹簧、受击叠加；取消、死亡与换波清理归原战斗生命周期。Q4 探口、蓄力、双焰和破绽分别播身体动作，攻击期间停止走路。两发命中仍由原双焰合同通知 Swift。
- 小批特效为三种轻击材质、灰白招架、不同重击地面预告、面具、双影和道具雨；不修改伤害／防御次数，不把视觉代码当作结算。
- DEBUG 录制账户使用独立 suite，不进入真实奖励结算。自动录制只在显式 `--tempo-record-auto` 时启用，系统录屏授权仍由 ReplayKit 处理。

## 已有证据

- 规则库：564 项、100 个 suite 通过，见 [摘要](core-test-summary.txt)。
- Unity：11 段新样板探针及 Q3 扑咬探针，命中回执符合预期；另做生命周期检查，见 [记录](probes/record-all-passed.txt)、[安全检查](probes/safety-all-passed.txt)。
- [12 组完整／特写并排](probes/manifest.json)均保留源片，标明 Unity probe；这是独立表现夹具，不是真机完整战斗。旧版没有轻击视觉命令，对应旧片没有轻击。
- [Q4 七帧](probes/q4-two-flame/)来自实际 Mac Unity Player 的原检查：探口和两发各一次、0.65 秒间隔、取消后无迟到命中。它们不代替手机视觉认可。
- 新 Unity iOS 导出已核对完整资源清单，见 [源清单](unity-export-manifest.txt)。DerivedData、临时工程和签名包在 SSD；原工作区与指向 SSD 的链接未改。
- 每次安装前后独立备份 Preferences，逐文件核对。真实玩家和 audit 无豁免、不反写；原始 plist 仅留 SSD，仓库只存哈希和核对结果。

## 真机录制尚未完成

169.15／169.17 改前对照已装 iPhone 13／iOS 26.6，首次 DEBUG 直入场景曾因 Unity 键盘初始化顺序崩溃，后续改为原生窗口激活后预加载。最终启动进程存活，但169.17 复验仍收到 ReplayKit `-5833`（音频／视频捕捉失败，无法开始），没有有效 MP4。镜像捕获工具同时出现 ScreenCaptureKit `-3811/-3812`、窄条裁切和超时，不能据此完成点击或录像。

签名 Debug 169.17（旧数值／旧动作对照）、169.18（本次修改）均在 SSD 构建通过，具体可执行文件与 UnityFramework 哈希见 [构建记录](builds.json)。

169.18 已装；战斗、非 Unity 的首页原生录屏都返回同一 `-5833`，不是只有战斗场景失败。169.19 只补正隔离首页夹具：先选愚者途径、跳过隔离引导，再进入港城，避免将初始玛拉画面误当雨云。两场失败报告保留在 `device/`。

正在补录：三场 ×1／×2 各一段改前／改后完整战斗、主角普攻／受击／招架特写、首页雨云。**未完成的真机证据不能用 Unity probe、模拟器或构建成功替代。**

改前对照采用同一 DEBUG 宿主、相同合法队伍／卡组，关闭 tempo，配修改前 Unity 资源。×2 和录制工具为本轮补加，飘字／HUD 共用，因此这是“旧数值／旧动作对照”，不是历史发行包全界面的原样录像。Q4 通过真实手动假面入口输入；D01／B01 在规则时间 22 秒后按可用状态激活真实遗落物；两边使用同一输入策略。单独主角展示夹具使用已解锁的双影／归结，不用于三场难度校准。

服务器测试本机未到执行阶段：Hummingbird `RequestBody.swift` 缺少 `DequeModule` 导入，触发 Swift 模块可见性错误。没有改其源码或项目锁文件，也没有把 PR #40 的云端 22 项结果算作本轮 Mac 复验。

## 复跑

1. Blender：`Blender -b --python tools/animation/build_tempo_samples.py -- <仓库绝对路径>`；来源与授权见 [SOURCES](../../../tools/animation/SOURCES.md)。
2. 用 `tools/combat/build_tempo_capture_plan.py` 生成探针；已有 Unity `WholeSpellRound2Review20260922.Begin` 执行 `--round2-output=<目录>`，加 `--round2-safety` 执行安全检查。打包脚本验证源哈希后才生成并排。
3. iOS 导出必须显式设置 `MISTPORT_UNITY_IOS_OUTPUT` 到本分支工作区，再跑 `scripts/check_unity_export_freshness.sh`；宿主构建用 SSD DerivedData、`CURRENT_PROJECT_VERSION=169.x`。
4. 装机前后复制整个 `Library/Preferences`，用 `tools/combat/verify_device_preferences.py` 核对。完整测试只允许隔离 suite 和新速度键；安装本身要求所有文件逐字节一致。
5. 已安装正确构建、手机解锁后，用 `tools/combat/capture_device_tempo.py --device <设备> --build <构建> --preferences-backup <备份> --destination <交付目录> --sample q4 --speed 1`，改前另加 `--baseline`。该工具不安装、不替用户授权，只有新鲜 `completed:true` 报告和原生 MP4 才导出完成证据。
