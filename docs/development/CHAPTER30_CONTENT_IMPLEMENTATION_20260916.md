# 第一章30关内容与首通合同接入

本批将v3.1/Pro表落实到静态内容与核心首通账本，不代表30关已开放。用户最新优先序列9遗落物，序列0不纳入本批。

## 已接

- 30个稳定mission/encounter定义；Q1–15编号/卡牌时点保持，Q16–30替换旧20关稿。原生任务种子同步30条，旧后四区内容未删除，仍非本章新规划。
- 44项绑定调查物证，既有11项沿用存档ID，新项chapter30_eNN；另P04/05/06晋阶凭据与U01/02许可。固定物品不重复计算数值奖励。
- 主线首通铜币2280、功勋100、天赋30、技能尘60；主线经验0，新档180铜币。重打不重复发放。功勋累计资格与可用余额分开。
- 旧档已完成节点补物证且统一双完成ID；不返铜币、药品、尘、功勋或天赋，不追回旧物品。
- 旧犬H03、洛克R-01、维娅WVR-01、押运卫V21、Boss BOSS01连续性；P17/P29等独立实例。
- Q13/15/21/22/25非致命演出映射，Q10/20/28/29撤离演出映射。撤离的目标是否完成由新目标契约决定，不把零血动画当逃跑实现。
- Q28五完整行动循环后存活；Q29额外清手下；Q30真击杀后仍存活。Q20截救与Q25自愿断契有独立目标谓词。

## 验证

`swift test --package-path mistport-ios/MistportCombatCore --filter ChapterOneThirtyMissionContractTests`：5项通过。覆盖30编队对演员ID、物证约束、经济汇总、双重领取/旧档迁移、五循环与非击殺目标。
报告：`output/chapter30-content-20260916/static-contract-tests.log`。

## 真实边界

- 正式开放门禁仍15；supportsUnity同步限定15。后15静态存在不等于可玩。
- 新目标谓词仍须接实际事件进度和Unity。Q20不得靠HP归零冒充截救；Q28/29不得把多段命中算多个完整循环。
- 新enemy_codex_executor是独立正式资产ID；enemy_archive_adjudicator、enemy_archive_convoy和boss_chronarch_sovereign需专用模型接入。初始数值仅待校验预算，不是通关验证。
- 新@adjudicator/@convoy/@chronarch/@early-hell-hound描述需Unity路由按真实模型支持后再开放；不回退普通守卫当完成。
- 新旧前后15的连贯对白/关卡特殊机械、模型演出、完整连续通关与手机验收由主制作批继续完成。

内容修改前备份：`backups/chapter30-content-20260916`。引擎奖励前半与主agent协作局部更新，session引擎由主agent负责。
