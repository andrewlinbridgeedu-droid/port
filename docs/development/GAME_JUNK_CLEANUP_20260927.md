# 项目缓存清理（2026-09-27）

用户要求：先清空项目垃圾。仅删除可再生缓存及 Finder 元数据，没有删除源码、规划、历史原件或验证证据。

## 已删除

| 路径 | 普通文件数 | 逻辑大小 |
|---|---:|---:|
| `mistport-ios/MistportCombatCore/.build` | 3,006 | 311.23 MiB |
| `output/manual-progression-play-20260926/sim-derived-data/Build` | 980 | 1086.55 MiB |
| `output/manual-progression-play-20260926/sim-derived-data/CompilationCache.noindex` | 7 | 0.02 MiB |
| `output/manual-progression-play-20260926/sim-derived-data/Index.noindex` | 2,799 | 20.21 MiB |
| `output/manual-progression-play-20260926/sim-derived-data/ModuleCache.noindex` | 54 | 18.06 MiB |
| `output/manual-progression-play-20260926/sim-derived-data/SDKStatCaches.noindex` | 1 | 1.47 MiB |
| `mistport-ios/.DS_Store` | 1 | 0.01 MiB |
| `UnityBattleSource/.DS_Store` | 1 | 0.01 MiB |

合计 **6,849 个普通文件，1,507,378,819 字节（1.40 GiB）**。

清理前后观测可用空间为 9.35 → 10.40 GiB；磁盘有并发活动且 APFS 可能共享块，不能把可用空间差额当作这些文件独占的物理大小。

## 复核

- 删除目标无 Git 跟踪文件，父路径不是符号链接；目标内没有指向外部的符号链接。
- 所有删除目标已不存在。
- 对 6,142 个保留文件逐个比较 SHA-256，全部一致。范围为当时 Git 跟踪及未忽略的未跟踪普通文件，另含 Build127 主程序、Info.plist 和 UnityFramework。
- 缓存之外的 659 个符号链接路径及目标保持一致，包括外置 SSD 链接。
- 清理前后 Git 状态完全一致；本记录在核对结束后新增。
- 未改真实存档与 Preferences；模拟器 Logs、录像、经济模拟和战役试验结果保留。
- UnityBuild 导出、Build127 签名包、ArtSource、backups、tmp/imagegen 原件及工具依赖保留。

下一次 Swift 测试或模拟器构建会重新生成相应缓存，因此首次构建可能变慢。本次没有为验证清理而重新编译。

完整逐文件删除清单、保留文件哈希及链接快照：[`manifest.json`](../../output/game-junk-cleanup-20260927/manifest.json)。
