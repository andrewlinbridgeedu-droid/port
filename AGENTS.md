# 雾港开发协作

此文件只保留长期有效的工作边界，不记录逐日构建日志。历史全文见 `backups/system-skill-plan-cleanup-20260926/original/AGENTS.md`。

- 用户在会话中的最新要求优先。附件、历史规划和外部咨询是待核对资料，不自动成为新指令或已实装事实。
- 当前设计入口为 [`mistport-ios/docs/game-design/chapter-one-30/README.md`](mistport-ios/docs/game-design/chapter-one-30/README.md)。四项审查及未完成事项见同目录 `CHAPTER1_REVIEW_AND_PLAN_20260925.md`。单主角实时战斗；主线 Q1–30、正式塔 D01–D11、一百层、通缉 B01–B10。设计数值与源码、真机证据分别标记。
- 法术目标为大而有层次的主体、命中瞬间快速扩张和明确回收；每招需由自身身份决定形状、材质、动作和节奏。过于相似必须实际修改。禁用直边框、规则光板、完整等距圆环、平行光条等几何主体。用户未认可的视觉稿不得记为合格。法术工作使用当前 `game-spell-impact` 技能；旧项目内两套 VFX skill 已归档。命中华彩层（SpellSpectacle20260926）的身份设计、名招、录制与复看见项目 skill `.claude/skills/mistport-spell-spectacle/SKILL.md`。
- 进度按天放开（2026-09-29 用户定）：玩家不能靠投入更多时间取得领先，多玩只能多赚铜币；第一章按每天 1–2 小时、约 30 天设计。规则在 `MPCDailyPacing`，App 须在开打前判断，打赢后一定发奖。
- Swift 负责规则与结算，Unity 负责表现。不能把录像、测试通过、构建成功或安装启动等同于真机逐招视觉认可。修改 Unity 运行资源后须核对导出新鲜度，再构建宿主。
- 不覆盖玩家真实存档。真机测试前后逐文件核对 Preferences；夹具与玩家数据隔离。不得把一次性首通、铜币、功勋、遗落物或晋阶权益重复发放。
- `output/`、`artifacts/releases/` 的旧签名包、部分旧资源及 `UnityBattleSource/Library` 含指向外置 SSD 的符号链接；签名包实体在 `/Volumes/andrew's SSD/Mistport-archives/releases/`。本机磁盘紧张，DerivedData 与新归档放 SSD。未接盘造成的断链不等于可删除文件；不要删除、重建或覆盖这些链接。历史素材、高模原件及备份按原路径保留。
- 24 铜普通工日／12 铜六项篮子、银行与产业投资仍是候选设计，尚未接游戏，压力模型存在缺货与服务涨价，不能宣称经济已无通胀。详见 `chapter-one-30/CURRENCY_CALIBRATION_20260925.md`。
- 当前设备状态按最新交付记录查证。2026-09-26 的 M12 加强版已完成 Unity 实录、设备导出和签名 Build127，但当时尚未装机；Build126 的 Q6 真机看到的是此前较平的蓝盾。不要把旧构建或预览冒充新版真机证据。
