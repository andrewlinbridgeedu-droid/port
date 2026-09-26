# 暮钟酒馆横幅与 4K 原画

2026-09-25。用户要求保留 ImageGen 风格与原酒馆老板娘，让灰筹·莫尔坐在一张牌桌旁，以宽幅画面左右拖动看纵深；后续明确要求使用所给 EC2 主机上的环境 API key 生成一张 4K 图。本批没有使用 Blender。

## 美术与交互

- 原酒馆图 `BountyTavernInterior.imageset/art.png` 与独立莫尔立绘 `BountyNPCMor.imageset/art.png` 均保留。先以它们为人物参考绘制宽幅构图，老板娘在左侧吧台，莫尔在右侧牌桌，中央留有海港窗景与前后错开的家具。
- 使用用户指定 EC2 的环境密钥，经 `gpt-image-2` image edit 将宽幅稿重绘为 **3840 × 2160** PNG；密钥只由远端进程从 `/home/ubuntu/mysite/.env` 读取，没有复制到本机或日志。母版为 `ArtSource/TavernDepth20260925/panorama-4k.png`，提示词为同目录 `prompt-4k.txt`。经视觉检查，人物、构图及双手无明显错误；这是评审结论，不等于用户已认可。
- 游戏用高质量 4K JPEG 为 `Mistport/Assets.xcassets/BountyTavernPanorama4K.imageset/art.jpg`，约 5.4 MB；保留无损 PNG 母版，避免游戏包里直接加载约 14 MB 的 PNG。`BountyPokerRound.swift` 的酒馆室内用这张宽幅画作左右平移和轻微视角倾斜，左侧吧台、右侧莫尔牌桌可点击定位，莫尔头顶姓名可点击交谈；拖离牌桌时对白收起。仅酒馆画面替换，扑克牌规则与奖励未改。
- 这是 **2.5D 绘画横向取景**：可查看画面左右并感到空间纵深，不能像真实 3D 场景那样绕到家具背面。独立交互评审页 `output/tavern-depth-panorama-20260925/index.html` 可拖动、切换左／中／右并查看手机实拍；本轮浏览器工具因本地 `file:` URL 安全策略拒绝自动打开该页，文件本身与六项相对资源引用已核验。

## 验证边界

- 4K PNG 与游戏 JPEG 均经 `sips` 核实为 3840 × 2160；`assetutil` 确认新资源进入 `Assets.car`。
- 签名 iPhoneOS **Build 121** 完整构建成功，`codesign --verify --deep --strict` 通过，已覆盖安装并正常启动 iPhone 13。先前 Build 120 的设备原生 UIWindow 左／中／右及莫尔对话截图分别为 `backups/tavern-depth-panorama-20260925/{left,center,right,mor-dialogue}-4k.png`；Build 121 的绘画布局相同，只补拖离牌桌后对白收起。
- iPhone 镜像里实测了从莫尔牌桌拖至中景、从中景回吧台、吧台／牌桌按钮定位、点击莫尔姓名进入对白、拖离牌桌收起对白。预览使用独立 fixture，未动真实玩家赌注。
- 安装 Build 121 并第一次正常启动后，`Library/Preferences` 54 个文件与安装前逐字节相同。随后设备预览又新增两个独立 fixture plist；恢复普通启动后真实玩家 `mistport.player-test-01-15.plist` 仅旧有两件遗落物数组顺序互换，集合与其他键不变。安装前与最终快照位于 `backups/tavern-depth-panorama-20260925/device-{before121,after121-normal}/Preferences`。

仍需用户判断画风、构图和人物大小是否达到最终审美要求；本批没有做完整牌局的再次实玩。
