# Build127 安装确认 · 2026-09-26

恢复任务后，CoreDevice 已报告手机安装版本 0.1.0 (127)。此前安装命令被取消后，手机端实际仍完成安装；本次没有重复覆盖。无参数 terminate-existing 后正常启动回执成功。此为安装/启动证据，不是法术视觉验收。

原安装前58份Preferences与恢复任务后的58份逐字节相同。正常启动后仅 `mistport.player-test-01-15.plist` 改变；逐键复核仅 `mistport.campaign-relics.v1` 中原有假面/僭命勋章两项数组次序互换，集合及其他字段不变。未恢复覆盖玩家数据。回执位于 `output/build127-device-20260926/normal-launch-resume.json`，比较见 `resume-save-comparison.json`。M12、M15、H10及高塔/十案的此版真机视觉检查仍待完成。
