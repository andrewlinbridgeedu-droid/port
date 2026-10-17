# 雾港法术命中：猎犬爪痕 + 错步穿行卡牌碎裂 · 交接文档（2026-10-08 下午）

接续 `HANDOFF_20261008.md`（凌晨那份）。覆盖 10-08 03:00–11:10：复看 170.17 → 程序生成"手绘逐帧"被否 → 改用 Effekseer 官方 CC0 样例 → 猎犬扑咬定为"用户手绘爪痕" → 错步穿行改为"塔罗牌击中、碎裂、消散"。逐条过程在同目录 `log.md` 第十二轮。构建、装机、存档的通用做法见 `HANDOFF_20261007.md` §5，这里只写变化。

---

## 1. 现在的状态

| 项 | 状态 |
|---|---|
| 代码 | 全部**未提交**，只在 worktree `/Volumes/andrew's SSD/Mistport-worktrees/hero-v4-device`（分支 `claude/ai-hero-integration-20261003`，HEAD `4ed6d5a`）。上一份交接列的未提交改动仍都在，本段又加了 §4 的文件。 |
| 模拟器 | iPhone 17 Pro Max（`E64100C9-43DA-4B8C-996A-2D953A13219C`），装 **170.23**。测试存档已恢复 Q14 备份，两份 plist 逐字节一致；App 关闭。 |
| 真机 | 没出设备包、没装机。 |
| 用户已认可 | **猎犬扑咬 = 用户手绘爪痕（橙色发光），不要火团**（170.22/170.23）。 |
| 用户未表态 | **错步穿行 = 塔罗牌砸中 → 紫粉裂纹 → 碎片炸开消散**（170.23，最后一条视频刚发，用户还没回复就换 agent）。 |
| 用户否决 | 程序画的"手绘逐帧"图（"太粗糙了，完全不像法术，是平面图"）；主角技能的蓝色三角晶片（"好像纸片"）；Effekseer Claw1 当爪痕（细爪痕被自身红光淹没，"看不到抓痕"）；猎犬的火团。 |
| 用户说"这些都不错" | Effekseer 样例 8 个候选（§3 表），可以留给其它敌人/招式用。 |

---

## 2. 用户这段的原话（按时间）

1. 看 170.17 录屏后："做"（先做猎犬扑咬的手绘逐帧试验）。
2. "记得这些东西要清除，我硬盘不大，或者你放SSD" → 工作文件一律放 SSD，内置盘只留临时、随手删。
3. 看程序生成逐帧图（170.18）："太粗糙了，完全不像法术，是平面图"；指着主角身上卷曲橙红条："这些是什么东西"。
4. "缩小后出对比图给我看" → 看了 8 个 Effekseer 候选："这些都不错"。
5. 看 170.20："看不到抓痕，另外，这些碎片好像纸片"。
6. 看 170.22："抓痕可以了，纸片重新设计，强调卡牌击中，从卡牌形状开始炸裂，消散"；"去掉火团。可以调成紫粉"。
7. "你写handoff吧，我要换agent了"。

---

## 3. 现在的实现（`UnityBattleSource/Assets/Scripts/SpellSpectacle20260926.cs`）

命中分流（`Burst` 和 `FormImpact` 里）：
- 敌方命中：`ClawHit` → `EffekseerHit` → `HandDrawnHit` → 原有实物层（`SpawnBodies`）。
- 主角命中：`CardHit` → `EffekseerHit` → 原有落点/爆刺。

| 身份 | 现在走哪条 | 说明 |
|---|---|---|
| `early-hound`（Q3/Q4 早期地狱犬的敌方命中） | `ClawHit` → `PaintedClaw` | 用户手绘 `PClaw` 格（`SpectaclePaint.png` 图集里），着橙色 (1,.58,.22)，按猎犬在屏幕哪侧镜像，尺寸 = 命中深度可视半高 × 0.5，0.46 秒（0.055 秒长出、峰值后淡出）。无火团。 |
| `sidestep`（主角 fool_skill_01 错步穿行） | `CardHit` → `CardShatter` | 见下。 |
| 其它所有身份 | 原样（实物层 / 旧落点） | `EffekseerLayers` 现在一个身份都没配（返回 null）；`HandDrawnSheet` 也返回 null。两条路都保留，给后续用。 |

**CardShatter（错步穿行）**，着色器 `Resources/SpellSpectacle20260926/SpectacleCardShard.shader`：
- 卡面：`Resources/Effects/Fool/HeavyTarotFace.png`（假面与匕首，972×1619，项目原有）。
- 尺寸：卡高 = 命中深度可视半高 × 0.34（群体次目标 0.26），放在目标点稍靠镜头处。
- 节奏：0–0.07 秒从主角一侧飞来、缩放 1.25→1、白粉闪光；0.10–0.15 秒牌面亮起紫粉裂纹（19 块 Voronoi 碎片，裂纹只在内部缝上，**牌外框不发光**，避免直边框）；0.15 秒炸开（碎片按离心方向飞、旋转、翻转、缩小，带紫粉自发光，紫粉大闪光，24 颗火花）；碎片 0.12–0.26 秒后开始被噪声侵蚀，0.78 秒全部结束。
- 可调参数都在 `CardShatter` 顶部常量（`Slam/CrackFrom/BurstAt/End`）、`Cut()`（碎片数、速度、翻转）、`Draw()`（`lit` 自发光强度、闪光颜色）、`SparkColors`，以及着色器 `_Rim/_Hot`。

**Effekseer 播放层**（`EffekseerLayers` + `EffekseerBurst`）：按身份配若干层"特效名、起始秒、开始淡出、结束、尺寸（可视半高比例）"，挂 root、计入 `LiveEffects`、销毁时停句柄。现在没有身份在用。资源目录 `Resources/SpellSpectacle20260926/Effekseer/`（Claw1、Fire5、Blow5 + `Parts/` 贴图，约 650KB）。

**用户说"都不错"的 8 个候选**（tktk 官方 CC0 样例，暂存 `Assets/HandRef20261008/`，对比图 `output/handdrawn-vfx-20261008/onhero2/effekseer-candidates-small.jpg`）：A 红色爪击 tktk02 Claw1、B 火焰斩 tktk01 Fire8、C 火焰爆 tktk02 Fire5、D 火焰绽开 tktk02 Fire6、E 星芒冲击 tktk02 Blow5、F 火花迸射 tktk02 Blow2、G 地面火爆 tktk01 Fire7、H 火柱转紫 tktk02 Fire8。经验：在战斗里尺寸要按"可视半高 × 0.03–0.05"起步，大了会整屏发白/发红；带一层泛红的（Claw1、Fire5）会把主角整个染色。

---

## 4. 本段新增/改动的文件（worktree 内）

| 文件 | 状态 | 说明 |
|---|---|---|
| `Scripts/SpellSpectacle20260926.cs` | 改 | `ClawHit`/`PaintedClaw`、`CardHit`/`CardShatter`、`EffekseerLayers`/`EffekseerHit`/`EffekseerBurst`、`HandDrawnSheet`/`FlipbookPlayer`（播放器保留、未映射）。改前原件 `backups/handdrawn-20261008/original/` |
| `Resources/SpellSpectacle20260926/SpectacleCardShard.shader` | 新 | 卡牌碎片/火花/闪光 |
| `Resources/SpellSpectacle20260926/SpectacleFlipbook.shader` | 新 | 逐帧图播放（现在没用） |
| `Resources/SpellSpectacle20260926/Effekseer/` | 新 | Claw1/Fire5/Blow5 + Parts（现在没用，但在 Resources 里会打进包） |
| `Resources/SpellSpectacle20260926/HandDrawn/HoundPounce.png` | 新 | 被否的程序逐帧图（2048²，在 Resources 里会打进包）——**应删除** |
| `Assets/HandRef20261008/` | 新 | 26 个 Effekseer 候选暂存（16MB，不在 Resources，不打包）——选完后删除 |
| `Editor/CardHitPreview20261008.cs` | 新·临时 | 编辑器里在 Q3 猎犬上放错步穿行 + 扑咬，30fps 截战斗相机：`Unity -batchmode -projectPath UnityBattleSource -executeMethod CardHitPreview20261008.Begin -cardOutput <目录> -logFile <log>`（不加 -nographics） |
| `Editor/EffekseerOnHero20261008.cs` | 新·临时 | 把 `HandRef20261008` 里的特效逐个打到主角胸口截图，参数 `-heroRefOutput <目录> -heroRefScale 0.2` |
| `Editor/ShieldRigPreview20261006.cs` | 旧·临时 | 光盾复看脚本 |
| `tools/vfx-handdrawn-20261008/` | 新 | `hound_pounce.py`（被否的 PIL 逐帧生成器）、`preview.py`、`encode.swift`（AVFoundation 把 PNG 编成 mp4，免 ffmpeg） |

工作产物都在 SSD：`output/handdrawn-vfx-20261008/`（2.1G：各版本模拟器录屏 `sim-170.18…23/`、预览 `card1/card2/onhero1/onhero2/`、安全检查 `safety1–5/`、构建日志、`bin/extract_range` 与 `bin/encode` 编好的工具）。用户看过的视频：`sim-170.22/q3-170.22-claw-and-sidestep.mp4`、`sim-170.23/q3-170.23-card-and-claw.mp4`。

---

## 5. 验证（证据分级）

| 层级 | 结果 |
|---|---|
| 编译 | 无 `error CS` |
| 录制器安全检查 | 最新 `safety5/`：M05/M06/M07/H01 共 69 项全过，日志里卡牌命中触发 2 次。**录像模式没跑**（需要 ffmpeg，原 `/tmp/mistport-vfx-encode` 已被清空；重装要下载约 30MB，先问用户）。98 组全量也没重跑 |
| 完整构建 | 170.18–170.23 都通过 Unity 导出新鲜度检查 |
| 模拟器 | 170.23 Q3 实拍：卡牌砸中/裂纹/炸开/消散正常；猎犬只有爪痕 |
| 真机 | 无 |
| 用户认可 | 爪痕是；卡牌碎裂未表态 |

---

## 6. 模拟器操作要点（本段新增）

- `xcrun simctl io … recordVideo` 用 `run_in_background` + `exec` 启动，停用 `pkill -INT -f "recordVideo … <文件名>"`；写到 `/private/tmp/claude-501/` 再拷 SSD（`mv` 跨盘会报 owner 错，用 `cp` 再 `rm`）。
- 抽帧用 `output/handdrawn-vfx-20261008/bin/extract_range <视频> <目录> <起秒> <止秒> <fps> <x> <y> <w> <h> <起始编号>`（源码 `tools/vfx-spectacle-20260926/review-20261007/extract_range.swift`）；编码用 `bin/encode <帧目录> <fps> <out.mp4> [宽]`。
- 坐标（设备点 440×956）：标题页"测试"(313,88)；关卡列表**等完全展开后**第 3 关 (204,337)、第 4 关 (204,435 附近)——列表还在展开时点会进错关；Q3 对白里"跳过对白"(82,272)；"开始战斗"(219,440)。
- 打赢后下次启动会先出"已恢复战后奖励"页挡住"测试"按钮：点"继续"(220,731) 后重启 App。
- 每次看完：`xcrun simctl terminate` → 拷 `output/playtest-save-backups/q14-cleared-20261005/*.plist` 到容器 `Library/Preferences/` → `cmp` 逐字节核对。
- 已知 P2 仍在：Q3 点"开始战斗"后经常要 13–18 秒才开打。

---

## 7. 内置盘

我这个会话的临时文件都已删除。`/private/tmp/claude-501/-Volumes-andrew-s-SSD/2e4c29e3-…/scratchpad/` 有约 1.4G（`png.bin` 1.1G 等），是**另一个会话** 10-08 11:06 写的，可能仍在使用，没动；用户要清理时再处理。

---

## 8. 建议的下一步

1. 等用户对错步穿行卡牌碎裂表态；按意见调 `CardShatter`（大小、速度、碎片数、颜色）。
2. 用户认可后，把"卡牌击中→碎裂"推到主角其它牌（每张牌用自己的牌面和颜色），把用户说"都不错"的 Effekseer 候选按身份配给其它敌人（例：钟卫用星芒冲击、重击用地面火爆），每个先在模拟器实拍给用户看。
3. 清理：删 `HandDrawn/HoundPounce.png`、`Assets/HandRef20261008/`（选定后）、未用的 Effekseer 资源、三个临时编辑器脚本；`FlipbookPlayer`/`HandDrawnHit` 若确定不用也可删。改了 Unity 就重跑安全检查 + 完整构建。
4. 补文档：`docs/development/SPELL_SPECTACLE_20261007.md` 补"手绘图接入、命中手感、爪痕、卡牌碎裂"一节，写清验证层级与未做的录像模式。
5. 上一份交接里未完成的仍有效：命中手感（摇晃/压暗）模拟器逐帧确认、震动等用户说装机再验；请用户补第二批手绘图；最后问用户是否提交合入 main（含 `edf41cb` 要不要）。

---

## 9. 用户的长期要求（接手必须遵守）

- 全程中文；直接给推荐并执行，不要列一串问题。海外发行：新文字用普通字体。
- 视觉问题自己在模拟器看；只有用户说"装机"才上真机；模拟器和真机都静音启动（`-MistportCityMute YES --developer-tools`）。
- 内置盘小：工作文件放 SSD，临时文件用完即删。
- 不覆盖玩家真实存档；模拟器测试存档每次看完恢复 Q14 备份并逐字节核对。
- 改了 Unity 运行资源必须重新导出、通过新鲜度检查再构建宿主。
- 录像、测试通过、构建成功都不等于用户视觉认可。
- 法术工作走 `mistport-spell-spectacle` 技能；禁用直边框、规则光板、完整等距圆环、平行光条。用户已否决：条带主体、整片椭圆光膜、PIL 平面剪贴画/程序画的平面逐帧图、Blender 粗模、Meshy 3D 凤凰、静态贴图感、纸片似的扁平晶片。用户喜欢：很亮的霓虹辉光、手绘质感、2D 手绘卡通特效、Effekseer 那类真实粒子特效、紫粉/紫金配色。
- 下载文件、提交、推送、合入 main、永久删除前都先问用户。不要删除/重建/覆盖 SSD 符号链接。
