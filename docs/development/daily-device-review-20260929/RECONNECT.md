# 重新连接后的剩余检查

工作树：`/Volumes/andrew's SSD/Mistport-worktrees/daily-work`。设备UUID `2A835FEC-7B6D-513B-AF8F-B5A84B673035`，bundle `com.yourcompany.mistport`。Build169已安装；不得使用170+号段覆盖另一会话工作。

1. 先备份完整 `Library/Preferences`，和本轮 `output/daily-device-review-20260929/preferences-path-installed` 比较。仅允许明确命名的独立测试suite改变；真实玩家不能豁免，不能回灌旧档。
2. 从设备 `Documents/` 导出 `daily-review-map-street-loaded.png`、`daily-review-map-talk-postman.png`，实际查看。它们是在路径修复后生成，但断线前未成功取回。
3. 启动 `--daily-pacing-device-walk --daily-map-walk --daily-map-recipient`。这只在独立suite预置“已听邮差口信”，角色仍须实际寻路到west-lane。检查 `DAILY_MAP_NEIGHBOR_ARRIVAL` 距离≤2.5、`DAILY_MAP_RELAY: completed=true`，取回 `daily-review-map-talk-west-lane.png` 与 `daily-review-map-relay-complete.png`。当前尚未运行这一轮。
4. 最终Build169再运行三个 `--daily-street-kind=event|pest|remnant` 独立夹具，并确认最终包与截图对应。既有三个胜利和清晰帧来自较早同号候选；后续没有Unity修改，不冒称其为最后包截图。
5. 使用 `--player-test-audit` 跑11组：`--verify-newspaper --verify-remnants --verify-neighbors --verify-city-events --verify-daily-workshop --verify-daily-work --verify-daily-pacing --verify-church-tower --verify-bounty-daily-risk --verify-player-growth --verify-p0`。不得在真实suite运行。
6. 再备份Preferences逐文件比较，只允许 `mistport.daily-pacing-device-walk.v1.plist`、`mistport.player-test-01-15.audit.plist` 这两个现有测试文件变化；新增UUID测试suite单列。结束后以正常启动参数回到玩家入口，再次复核真实存档。
7. 将新日志、实际看过的截图和比较报告通过后续PR更新状态；仍不能替代用户视觉/手感认可、任务2正常游玩计时。

示例命令（输出目录须取新名字，保留旧证据）：

```sh
xcrun devicectl device copy from --device 2A835FEC-7B6D-513B-AF8F-B5A84B673035 --source Library/Preferences --destination <新备份目录> --domain-type appDataContainer --domain-identifier com.yourcompany.mistport
xcrun devicectl device process launch --device 2A835FEC-7B6D-513B-AF8F-B5A84B673035 --terminate-existing --console com.yourcompany.mistport -- -MistportCityMute YES --daily-pacing-device-walk --daily-map-walk --daily-map-recipient
```
