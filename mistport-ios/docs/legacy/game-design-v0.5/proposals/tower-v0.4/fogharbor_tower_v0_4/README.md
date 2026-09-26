# 教会百层长阶补充包 v0.4

先读 TOWER_SYSTEM_SPEC.md。三座各100层，共300条**候选配置**，不是300个已完成Unity关卡。

## 复现

需要Python 3.10及以上，仅标准库：

```sh
python audit_tower.py
```

会重新生成tower_config.json、floors_300.csv与审计输出，不修改v0.3或游戏工程。当前49项检查包括静态预算、配置引用和纯内存首通/校准参考变换。

## 文件

TOWER_SYSTEM_SPEC.md是规则及数值说明；FIRST_20_AND_EXAMPLES.md是首20层与关键卡点清单；tower_config.json是冻结数据；floors_300.csv是其平面导出；build_tower.py是确定性生成器；reference_rules.py是测试使用的内存规则；audit_tower.py及audit_results.json/audit_tests.txt保存实际验证结果。

## 严格限制

没有实现战斗、动画事件、敌人AI、十八天赋、真实存档事务、网络并发或手机UI。测试中的胜利是注入输入，不是任何构筑真的战胜300层。正式结算必须由可信战斗结果驱动，不能把测试函数直接当作发奖API。

全部楼层release_enabled=false，仍需真实时序和机制覆盖验收。新增五级校准是待战斗验证的候选改变；假面重设计未批准。原调查线、技能、天赋里程碑、晋阶条件和六次定向获取路径保留。

名义经验预算不等于可入账经验：仍受序列9累计2340经验上限约束。校准退款用原始支出，不用热更价格。档案与称号不加属性。
