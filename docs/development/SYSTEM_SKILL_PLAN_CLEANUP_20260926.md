# 系统文件、skill 与规划入口清理

日期：2026-09-26。目标是让当前工作只从一个第一章设计入口出发，避免旧三人回合制、旧法术审批流程和过期构建状态继续被误读成现行要求。本次不改游戏源码、Unity 资产、设备安装包或玩家存档。

## 当前入口

- 协作边界：项目根 [`AGENTS.md`](../../AGENTS.md)。原 387 行按日期追加的全文保存在清理备份，不再作为活跃指令累计。
- 设计权威：[`DOCUMENTATION_GUIDE.md`](../../DOCUMENTATION_GUIDE.md) → [`chapter-one-30/README.md`](../../mistport-ios/docs/game-design/chapter-one-30/README.md) → 对应专题和 [`CHAPTER1_REVIEW_AND_PLAN_20260925.md`](../../mistport-ios/docs/game-design/chapter-one-30/CHAPTER1_REVIEW_AND_PLAN_20260925.md)。
- 工程导航：[`PROJECT_STRUCTURE.md`](../../PROJECT_STRUCTURE.md) 和 [`mistport-ios/README.md`](../../mistport-ios/README.md)。`CURRENT_PLAN_20260916.md` 与 `docs/game-design/PRODUCTION_ROADMAP.md` 只留跳转，不再维护第二套历史状态。

## 从活跃目录撤下

- v0.5 三人回合制规格、旧关卡/成长、旧世界故事圣经、旧提案、程序员交接副本及文档侧 JSON/测试向量共移入 [`docs/legacy/game-design-v0.5/`](../../mistport-ios/docs/legacy/game-design-v0.5/README.md)。现行 `MistportCombatCore` 打包的运行资源未移动。旧工程审计所写的原路径和行号是历史快照，查阅时按新归档位置定位，不把审计当当前规则。
- `mindstone-battle-vfx` 与 `mindstone-create-spell-vfx` 的旧 skill 指令移入 [`archive/legacy-skills/`](../../archive/legacy-skills/README.md)，`SKILL.md` 重命名为 `SKILL.archived.md`，避免继续作为活跃技能发现。VFX V1 生成脚本、schema、预设与参考迁至 [`tools/vfx-v1-authoring/`](../../tools/vfx-v1-authoring/README.md)，历史 authoring manifest 的 owner 标识保持不变。
- 删除过期 `.codex-work/ACTIVE_VFX_CHECKPOINT.md` 和无人引用、会按 9 月 20 日固定名单删除构建/输出的 `tools/cleanup/cleanup_generated_20260920.py`；原件在备份中。`mistport-ios/DESIGN_AUTHORITY_V1.md` 也移入 v0.5 归档。
- `archive/README.md` 的“目前未移动任何文件”错误描述已更正。

## 验证与边界

清理前逐文件备份 137 个原件、1,946,391 字节；[原件哈希清单](../../backups/system-skill-plan-cleanup-20260926/original-manifest.json)和[去向清单](../../backups/system-skill-plan-cleanup-20260926/disposition-manifest.json)可用于逐文件恢复。其去向为：125 个从活跃路径移走（其中 5 个只修了归档后的相对链接），2 个从活跃路径删除，10 个活跃入口／专题引用改写。设计目录顶层现在仅有 `README.md` 与 `CURRENT_PLAN_20260916.md` 两个跳转/索引文件，当前正文集中在 `chapter-one-30/`。

迁移后的 53 个受影响 Markdown 文件已做本地相对链接检查；`python3 tools/vfx-v1-authoring/scripts/spell_vfx.py inspect --repo .` 成功识别 Unity、VFX V1 运行时及 14 个已注册法术。未执行游戏构建或真机战斗复测，因为运行源码与打包资源未改变。旧审计里的原路径是历史事实，其文本未重写；`output/`、外置 SSD 符号链接、备份高模与玩家 Preferences 均未清理。
