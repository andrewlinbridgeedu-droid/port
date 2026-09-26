# 世界事件与工艺经济独立核对

这里不是游戏运行代码。Pro原始完整模型保留在 `docs/development/crafting-world-events-v2-pro-source/`；本目录提供本地复现与独立核对入口。

- `check_progression.py`：逐次计算候选熟练度增长及假设材料/现金成本。
- `check_event_contract.py`：内存参考结算，核对重复请求、变更载荷、最后一件采购、资金不足和钱物守恒。
- `*-review.json`：本次实际运行结果。

运行：`python3 tools/world-economy-design/check_progression.py`；`python3 tools/world-economy-design/check_event_contract.py`。

真实SQLite原子性、多用户并发、崩溃恢复、付费权益验证与全服市场价格并未被这些脚本验证。当前规划入口是 `mistport-ios/docs/game-design/chapter-one-30/WORLD_EVENTS_AND_ECONOMY_20260926.md`。

## Pro v2完整复现

运行 `python3 tools/world-economy-design/review_pro_v2.py`。仅将原模型输出路径改为临时目录，运行18×3×365模型和随包验证器，比较下载CSV，并独立核算19,710日行货币等式。输出 `pro-v2-review.json` 包含源码哈希和差异。临时CSV自动清理，下载原件不修改。

8份CSV字节一致；事件窗口摘要有格式差异及1处0.0001舍入差异。另3份衍生表没有生成脚本，未宣称复现。原模型的聚合钱包、成交额重新估价和模拟报价指数局限见 `docs/development/CRAFTING_WORLD_EVENTS_V2_REVIEW_20260926.md`。会计通过不等于市场平衡通过。
