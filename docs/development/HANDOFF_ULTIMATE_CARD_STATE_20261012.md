# 交接：无名宣告卡牌状态 · 2026-10-12

用户反馈主线第 30 关部分卡牌无法使用，并指定“无名不行”。当前手机旧版为 169.81，本轮从最新真实 Preferences 取快照，用隔离预览实际测试。

## 169.81 复现与结论

- 第 30 关开打前，无名宣告不能选入普通自动序列；开打后需要点击手动释放，每场一次。这是当前规则。
- 实际点击成功触发 `AI_HERO_CAST skill=fool_skill_10`；`debug.ultimate-contacts` 确認 Boss 获得 4 层误认及归结准备，`canUseAgain=false`。因此本次未复现“战中从未用过却无法释放”。无名是铺垫技能，直接伤害为 0。
- 已确认显示故障：旧卡面使用普通 20 秒 CD 扇形，结束后卡图恢复，却不提示本场次数已用尽；再次点击仍被每场一次规则拒绝。战前禁用也仅有小字“终极”，原因不清楚。
- 普通牌的整套出手／封印恢复未完成真机确认，不能用本次无名测试宣称全部正常。首轮预览选过四张普通牌，开场后记录仅普攻与一次无名；普通序列在该预览的转场保留情况还需另查。

旧版证据在 `Mistport-169.81-9cab331-hero-motion-20261012-codex-01a12f14/q30-card-audit-20261012-codex-01a12f14/`：截图、`q30-console.log`、`telemetry-after-ultimate.plist`、`q30-ultimate-before-fix.json`。全量 Preferences 前后 266 文件仅隔离遥测变化，真实档和盲玩档逐字节一致。

## 修改

仅 `mistport-ios/Mistport/ChapterOneTestView.swift`：无名卡标明“每场一次”，卡面随实际状态显示“战中手动／点击释放／等待释放／释放中／本场已用／主角倒地／暂被封住”。终极不再播放普通卡 CD 扇形；用完持续暗化并显示本场已用，下一场由新 session 恢复。按钮及实际请求都拒绝倒地主角发起终极；可访问状态与画面一致。每场一次、命中时刻、误认和归结效果均沿用原规则。

## 构建及核验

实时 `devicectl device info apps` 确认 `bundleVersion=169.81`，选择 169.82。新归档 `/Volumes/andrew's SSD/Mistport-archives/releases/Mistport-169.82-9cab331-ultimate-state-20261012-codex-01a12f14`，包含会话后缀。沿用 `scripts/build_hero_v4.sh device 169.82` 的 Unity 导出 → 新鲜度核对 → 宿主流程，DerivedData 与日志全部在外置 SSD；上一归档保持独立。

169.82 构建、导出新鲜度和深层签名验证通过，35 项相关既有规则测试（终战队伍／连续排程／愚者战斗）通过。已安装；安装前后 266 个 Preferences 文件逐项 SHA 一致，实时 `bundleVersion` 确认为 169.82。

新版隔离 Q30 实测：战前显示“战中手动”，开打后显示“点击释放”，点击后先显示等待，最终实际命中一次；规则记录 Boss 获得 4 层误认与归结准备，`canUseAgain=false`。卡面持续暗化并显示“本场已用”，重新挑战后恢复“战中手动”。战中重新加入伪证烙印／双重追猎／荒谬归结／反客为主，四张均有实际出手及接触记录；首轮旧预览转场丢失普通序列的问题仍单独保留，不据此宣称已修全部入口。

归档含 `q30-ultimate-actual-contact.json`、`q30-player-contacts.json`、`q30-console.log` 与 `device-evidence/` 的各状态截图；97 帧约 24 秒的 `q30-ultimate-sampled-mirror.mp4` 为镜像采样记录。安装、演练、恢复真实档后均逐文件核对 Preferences：266 文件无新增／删除；安装阶段完全一致，演练及最终启动阶段仅隔离 `mistport.p1-ui-verification.plist` 改变。真实 `mistport.player-test-01-15.plist` 和盲玩 audit plist 全程逐字节相同，未恢复旧备份、未发正式奖励。已用 `-MistportCityMute YES --developer-tools --player-test` 回到真实档标题。

盲玩仍按用户要求暂停，不能写作第一章已通关。测试不恢复旧备份覆盖玩家亲测进度。
