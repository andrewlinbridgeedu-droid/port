# 早期主线战斗配曲调整 · 2026-10-13

最终版本169.91已安装，基线0695215，分支codex/playtest-ui-20261012。用户报告前三关仍不像战斗音乐；本轮重新查询手机确认已安装169.90，随后用户澄清“已经换曲，但不像战斗曲”。因此这次是配曲选择调整，不把听感问题误记成新的切曲失败。

## 改动

主线Q1–5由BattlePetalsRiver（Petals on the River）改为已有用户曲BattleGearsFog（Gears Against the Fog），与Q6–15使用同一战斗曲。其余主线、塔、通缉和维护路由保持原配置。没有生成、替换或重新编码音频文件；伤害、技能、CD、奖励与每日进度规则未修改。设备听感是否符合用户预期仍由用户试听确认。

增加DEBUG核验参数--mainline-music-review=1／2／3，优先使用专用suite mistport.mainline-music-review.20261013。仅将测试人物准备到对应关卡，在正常ContentView主城显示，再由工具点击主线入口，经GameStore.beginMission与ChapterOneMissionBridgeView开始战斗；不走ChapterOneTestView独立预览。图标冷启动仍使用玩家真实suite。本轮不会重置玩家或盲玩档，不代发真实奖励。

实际播放器事件报告补充build、启动参数、phase和时间，排除旧预览报告被误用。审查器的Q3重试判断改从现行路由取曲目，不再写死Petals。

## 构建与验证

归档：/Volumes/andrew's SSD/Mistport-archives/releases/Mistport-169.91-early-battle-theme-20261013-codex-01a12f14
按scripts/build_hero_v4.sh device 169.91：Unity设备导出→新鲜度核对→签名宿主；DerivedData与所有日志均在外置SSD会话目录。保留旧签名包和符号链接。

八项音乐路由与归属测试通过，见music-regression.log。设备核验与最终Preferences逐文件核对已完成，记录如下。

设备核验：apps-after-install.json／log确认169.91；codesign.log深层严格检查通过。music-all-routes.json共143路由，全部expected==actual、playing=true、volume=0、error=none；回城、重试和旧同关视图退出三项true。八项单元测试与四份包内音乐SHA核对通过。

normal-entry-music-summary.json及music-normal-q1／q2／q3.json确认：三个独立启动均build169.91、phase=dungeon，实际BattleGearsFog、playing=true、volume=0、error=none，每关两条匹配事件。启动参数含mainline-music-review对应编号，无preview-chapter-one。工具依次在主城点击主线横条，第二／三关跳过已知对话、选两张牌并点击开始；第一关无牌开打，出现玛拉干预后停止该隔离进程。截图在device-evidence，第一关后续图为干预画面，不冒充整关胜利。第三关截图接口SCStreamErrorDomain -3812中断一次，经重新绑定App和窗口居中恢复。

这是静音实际播放器与入口核验，未录制或宣称听感认可，也未宣称前三关或第一章真人通关。用户可从手机图标启动原档试听。

Preferences核对：安装前后275→275，每个文件SHA完全一致，无变化、新增、删除。隔离测试后275→276，原275份全部一致，仅新增mistport.mainline-music-review.20261013.plist。用户音乐开关在本轮开始前已为true，始终保留；未恢复旧备份、未重置真实进度、未重复发放真实奖励。详见preferences-install-comparison.json／preferences-qa-comparison.json。

交付：隔离进程77084已终止，保留App关闭，正常图标启动使用真实存档与原有音乐设置，不继承静音测试参数。继续沿用用户commit、push授权，将本轮源码与交接提交到codex/playtest-ui-20261012；30份旧AIHero png.meta格式变化留在工作区、不提交。盲玩代理仍暂停。
