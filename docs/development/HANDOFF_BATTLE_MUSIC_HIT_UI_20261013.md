# 战斗音乐与伤害数字交接 · 2026-10-13

169.88 已安装；源码基线3753d5d，分支 codex/playtest-ui-20261012。用户确认问题为前几关播主城／选角曲、第三关缺伤害数字，要求检查全部。沿用 commit、push、handoff 授权。**最终音频报告、战斗画面和最终隔离检查后存档核对仍待设备重连，不能称完整真机验收。**

## 改动

战斗音乐由视图UUID持有，旧页面的延迟退出不能停止新页面，包括同关重试；active标志、session outcome、新session采纳均重新同步。原来终局只停止、inProgress没有可靠恢复的问题已修。曲名相同但播放器已停也重播；资源加载失败清除旧track，记录具体错误。四首曲及映射未改：Q1–5 Petals、Q6–15 Gears、Q16–27 Harbor、Q28–30 Brass；塔／十通缉／维护沿用正式路由。

敌方伤害移到血条上方36点，额外伤害金色，增加暗底。原来40ms后很快淡到25%，现在全亮停留120ms后上浮32点，约1.32s后移除；四个稳定槽与状态文字分组。冻结命中锚点，切波前消费已结算多段命中并用旧编队，补齐队友伤害、备用普攻与假面致命命中。实际伤害、CD、奖励和平衡未改。

DEBUG --verify-battle-music 使用隔离shell，实际AVAudioPlayer固定音量0，不写音量／开关。独立检查143入口（30主线、100塔、十通缉、三档维护）及旧退出、重试、回城，写 Documents/battle-music-route-review.json；页面真实切曲和数字写 battle-music-live-review.json、battle-hit-ui-review.json。最终检查加每次切曲120ms间隔及error字段。没有自动代玩。

## 已完成证据

归档、DerivedData、日志：/Volumes/andrew's SSD/Mistport-archives/releases/Mistport-169.88-battle-music-hit-ui-20261013-codex-01a12f14
原始源码备份：worktree/backups/battle-music-hit-ui-20261013/original。

- apps先查询169.87，递增169.88。标准 scripts/build_hero_v4.sh device 169.88 完成Unity导出→新鲜度→宿主编译，pipeline.log、export-169.88.log、build-169.88.log留档。Swift补入后再次检查新鲜度和增量编译，最终 build-audio-diagnostic-final-169.88.log 为 BUILD SUCCEEDED；codesign-final.log 深层严格签名通过。全部新归档在SSD，旧包／符号链接保留。
- music-hit-regression.log：135 tests /18 suites通过，覆盖主线曲目、塔边界、十通缉、维护、三个音乐生命周期回归，以及既有编排、假面、反击等规则。不称全库通过或真人全章通关。
- apps-after-install.json记录169.88；install-final.json为同版最终补编译包成功安装。
- 安装前结束旧进程，重新备份最新Preferences。preferences-install-comparison.json及最终补编译安装的 preferences-install-final-comparison.json均为275→275逐文件SHA全一致，无变化／新增／删除。首次隔离启动后 preferences-first-qa-comparison.json仍275文件全一致。没有恢复旧档、重置进度或代发奖励。
- 最终包四首Battle*.m4a逐字节匹配源码 Mistport/Audio 中各自加工资源；排除漏包／错包，没有试听或更换歌曲。
- 静音隔离启动成功：-MistportCityMute YES --developer-tools --verify-battle-music --preview-chapter-one-q3；启动JSON/log留档。

## 未完成及失败记录

首次快速同步143次切曲：前6次播放器成功、后137次未播，三个生命周期音频检查false；无具体错误，不能断言原因。保留 battle-music-route-review-initial-failed.json。随后把测试改为异步留间隔并记录错误，重新构建和安装。

第二次读取仍是旧报告（无error字段），不算最终检查。控制台重试有Unity启动输出，随后CoreDevice中断，返回 device disconnected / peer no longer reachable，未取回最终报告。launch-q3-console.log、copy-route-console.log、copy-route-reconnect.log留档。

镜像提示“iPhone使用中／已超时”，一次SCStreamErrorDomain -3811捕获失败；重连及重建捕获未恢复，本版尚未操作战斗画面。169.87截图不能冒充169.88证据。

待手机可达并连接镜像后：读取带error字段的新报告；Q3开打／失败重试确认Petals，截图伤害数字；抽查塔多敌切波、通缉、Q30队友数字；停止隔离进程并重新逐文件核对Preferences，特别确认真实档／盲玩档。用户已被通知连接问题。

用户真实进度不再重置；盲玩agent仍暂停，第一章真人通关仍未完成。30份旧AIHero png.meta格式改动不属于本次提交。
