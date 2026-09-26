# 全敌人待机运行验收

当前状态：11 类编队/模型案例已完成独立 Unity player 运行验证；发现问题后定向修复重测通过。尚未将本验证视为真机逐关手势验收或用户美术确认。

入口：`EnemyIdleCapture.cs`。独立 macOS Unity player 以 `--verify-enemy-idle` 启动；设置环境变量 `MISTPORT_IDLE_CAPTURE` 为证据目录。必须用此次最新代码构建，不能使用旧 preview。

覆盖：空壳守卫、普通幽灵、四只赤红分裂幽灵、早期地狱犬、后期铠甲犬、翠焰亡灵、寄忆核心、记忆蛭、档案守卫、织幕女主，以及档案守卫/织幕女主/记忆蛭的三人混编克隆。

验证调用正式 BattlePrototype 模型与编队路由，不由脚本主动安装待机组件。每个可见 EnemyHandle 必须自动得到已配置且指向实际可见演员的组件。分别测量战前、开战后等待出招、敌方攻击回到待机、主角普攻受击回到待机、死亡中途取消、完整退场后重显六个阶段。

每阶段记录约两秒内局部 Transform 旋转或位移变化，至少两个节点实际变化；固定编队 EnemyRoot 不能漂移超过 0.025 世界单位。该数值检测用于发现静态/停摆/站位回归，不能替代美术观察。战前和战斗空档每种编队分别保存六帧截图；另保存攻击、受击及死亡取消帧。

运行成功生成 `passed.txt`，失败生成 `failed.txt`，逐模型结果保留 `progress.txt`。截图证明实际 Unity 运行，不等同真机验收或新档连续通关。

## 运行结果与修复记录

- `output/all-enemy-idle-20260915/final/progress.txt`：铠甲犬、记忆蛭完整六阶段通过；早犬也通过状态测试，但后续皮肤贴地修复以 grounded 证据覆盖。
- `output/all-enemy-idle-20260915/final-rest/passed.txt`：织幕女主、三体混编、翠焰亡灵、寄忆核心、空壳守卫、普通幽灵、四只赤红幽灵全部通过；亡灵切回早/晚猎犬分类与待机恢复通过。
- `output/all-enemy-idle-20260915/grounded/passed.txt`：早期犬、档案守卫、织幕女主、三体克隆编队修复后六阶段重测通过，两种回切通过。

运行发现并修复：亡灵 `(Clone)` 名导致绑定到隐藏犬的共同父节点；早犬原 Idle 复用 Walking 导致四肢踏步，Hit 恢复过慢；单网格核心没有局部变化；死亡中途重显没有恢复 Animator/legacy Idle；档案守卫使用与旧守卫相同 identity 时，退场后重显错误选中隐藏模板；早犬站姿皮肤距地 0.64292 世界单位。没有通过放宽断言掩盖这些问题。

最终早犬皮肤最低点（骨矩阵与 bind pose 逐顶点计算）校正后为地面 y=0；前脚末端骨约 y=.08、后脚约 y=.12，EnemyRoot 和 MotionRoot 保持 y=0。正常站立四脚稳定，胸、头、耳、尾有独立运动。核心实际网格顶点每测量窗口有约 .00018 局部单位变化，未用整体根旋转代替。

## 动态证据

截图原始帧以 `--idle-dense` 采集，每两帧一张。CSV 实测相邻帧时间 .066667 秒，即 15 fps；每段 30 张图覆盖 1.933 秒。GIF 按时间戳拼接实际截图，未生成或插值游戏画面。

- `output/all-enemy-idle-20260915/grounded/early-hound-combat-idle.gif`
- `output/all-enemy-idle-20260915/final-rest/emerald-combat-idle.gif`
- `output/all-enemy-idle-20260915/final-rest/matriarch-combat-idle.gif`

人工检查了正常守卫、两种猎犬、翠焰亡灵、女主、四赤红幽灵、核心、记忆蛭、档案守卫及三体混编实际帧；grounded 早犬已消除原浮地间距。模型显示与既有站位保持一致，未重新设计外观。所有其它案例保留完整战前/战斗空档帧序列供复核。仍应在 iPhone 安装后观察全尺寸观感与战斗交互，不能以本运行结果宣称用户已验收美术。
