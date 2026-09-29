# 历史工艺设计v1核验（未接入游戏）

用户最新方向已取消工资，改为生活补给＋商品销售＋等级/熟练度门槛。此目录仅保留旧版可重放证据，订单/工资/400铜结论不可作为当前实现配置。当前规划见`CRAFTING_MARKET_AND_PROFICIENCY_20260926.md`。

`catalog.json`是8张配方与12张订单的材料槽、三维效果、标签及验收配置；`economy.json`保存同一订单表、商店卷价/库存、基础料供给。实现取值以这两份为准；总规则见游戏规划的`CRAFTING_INTEGRATION_SPEC_20260926.md`。

运行（仓库根目录）：

```sh
python3 tools/crafting-design/check_catalog.py tools/crafting-design/catalog.json
python3 tools/crafting-design/check_access.py
python3 tools/crafting-design/check_economy.py
```

- 配方/订单穷举：数量参与运算，原始和最后clamp到0…9，合并/移除标签，验证阈值/禁忌及每条至少两解。referenceCost未定价时为0，不代表真实成本或最省钱组合。
- 可达性：读取现有ChurchTower.swift前十层敌种，验证素材池可覆盖两条路线；不证明掉率、耗时或玩家战斗能力。
- 有限资金：订单至多400铜；商店初始0，四种卷买入再卖出都亏钱。只核算该本地模块，不证明全游戏不通胀。

`*-verification.json`和`verification.json`为上述命令结果。不是Swift运行测试、事务崩溃测试、2000人模拟或真机验收。未写玩家存档。
