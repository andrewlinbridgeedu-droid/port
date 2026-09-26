# 世界事件与工艺经济独立核对

这里不是游戏运行代码，也不是Pro完整市场模型的副本。

- `check_progression.py`：逐次计算候选熟练度增长及假设材料/现金成本。
- `check_event_contract.py`：内存参考结算，核对重复请求、变更载荷、最后一件采购、资金不足和钱物守恒。
- `*-review.json`：本次实际运行结果。

运行：`python3 tools/world-economy-design/check_progression.py`；`python3 tools/world-economy-design/check_event_contract.py`。

真实SQLite原子性、多用户并发、崩溃恢复、付费权益验证与全服市场价格并未被这些脚本验证。当前规划入口是 `mistport-ios/docs/game-design/chapter-one-30/WORLD_EVENTS_AND_ECONOMY_20260926.md`。
