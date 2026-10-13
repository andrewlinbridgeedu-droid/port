# 四张牌编排数值原型

2026-10-12 候选规则，**没有接入 iOS / Unity / 玩家存档**。对应设计入口：
[`SKILL_ORDER_COMBAT_REDESIGN_20261012.md`](../../mistport-ios/docs/game-design/chapter-one-30/SKILL_ORDER_COMBAT_REDESIGN_20261012.md)。

需要 Node.js 22+，无依赖：

```sh
node --test tools/skill-order-lab/model.test.mjs
node tools/skill-order-lab/audit.mjs
node tools/skill-order-lab/build-visual.mjs /absolute/task-owned/skill-order-lab.html
```

- `model.mjs`：10 张普通牌、4 个位置、真实时间窗口、六类压力敌人。整数毫秒；施法速度只改变前摇/后摇和引导频率，不改变全局时间、敌人频率、CD 或效果持续时间。纯函数，不读取和写入存档。
- `audit.mjs`：每类敌人枚举 5,040 个顺序，共 30,240 个基础对局；另对可行配牌做攻击降低 10% 的检查。结果写入 `audit-results.json`。自动门槛：每类至少三组可行配牌、可行配牌中的错误排序失败占比至少 70%、十张牌都有可赢用途、没有一个顺序包办六类敌人。
- `model.test.mjs`：时序、失效窗口、加速与 CD 区别、同牌换序的结果、输入验证、记录不干扰结算。
- `visual-template.html` / `build-visual.mjs`：将同一个模型嵌入对话预览，禁止另写一套近似数值；模板里的占位符须先生成后才能运行。

`cleared` 只表示六个固定压力夹具被清空且主角活着。45 秒上限是原型评估上限，**不是准备给所有主线加的超时失败条件**。它不表示通过真实 Q1–30；没有模拟假面、无名、装备、天赋、遗落物、队友、每日门槛、剧情胜利目标、多波刷新和存档迁移。不能把此报告当成真机战斗认可或生产战斗平衡测试。

先固定夹具生命/护甲/攻击参数，再枚举。审计只统计，不会按排序排名给胜负，也不会按百分位动态调低某个顺序的敌人生命。敌方攻击与法术命中同刻时，敌方优先；所有状态使用 `[开始,结束)`；伤害同时清空双方时不判胜。技能冷却从施法开始计时，严格按四格循环，等待 CD 时普攻；不存在“错误牌序直接判负”的分支。
