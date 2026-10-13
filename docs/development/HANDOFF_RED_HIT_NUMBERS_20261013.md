# 红色无背景伤害数字与最终核验 · 2026-10-13

最终版本 **169.90** 已安装、静音隔离复看完成、测试进程已关闭。基线67ded10，分支 codex/playtest-ui-20261012。用户在169.88截图中明确要求“数字飘红，不需要背景色”；沿用 commit、push、handoff 授权。真实档未重置，盲玩仍暂停。

## 最终显示

普通、技能、暴击、额外伤害和主角受伤统一红色，移除整个飘字背景；治疗保持绿色、状态文字保持各自颜色。沿用血条上方位置、冻结命中锚点、约1.32秒可见时间和上浮动作，不修改伤害、CD、奖励、日进度或技能顺序规则。

169.89真机终章发现同时命中的80／65等值可能挤成一个大数字。169.90改为两列两行：横向相隔92点、上下76点，覆盖原32点上浮轨迹。冻结基点时不加槽位偏移，显示时仅加一次；玩家受伤亦冻结基点。最多四个同时值、稳定槽位及状态分组保留。

## 设备证据与版本边界

169.89归档：/Volumes/andrew's SSD/Mistport-archives/releases/Mistport-169.89-red-hit-numbers-20261013-codex-01a12f14
169.90归档：/Volumes/andrew's SSD/Mistport-archives/releases/Mistport-169.90-red-hit-spacing-20261013-codex-01a12f14
DerivedData、Unity导出和宿主日志均在相应SSD会话目录。旧包和符号链接保留。

- 两版均执行 scripts/build_hero_v4.sh device 版本号：Unity导出→新鲜度核对→宿主构建，pipeline.log及build日志成功，codesign.log深层严格验证通过。安装前手机169.88→169.89→169.90，apps-after-install.json与install.json留档。
- 169.89：独立 --verify-battle-music 入口全143实际播放器路由通过（30主线、100塔、十通缉、三档维护）。全部 expected==actual、playing=true、volume=0、error=none；旧同关退出忽略、回城、重试三项true。音乐控制器与路由源码在169.90未修改，四份Battle音频包逐字节相同，music-resources-vs-16989.json确认；169.90实际Q30报告为BattleBrassTide、playing=true、error=none、volume=0。全路由结果不等于143场真人游玩或听感认可。
- 169.89 Q3：工具选牌、首次开打、无假面失败、重新挑战、重新选牌开打。两次真实页面音乐均为BattlePetalsRiver，日志无错误。device-evidence/mistport-16989-q3-hit-2.png、q3-hit-4.png及q3-retry-3.png确认红色、无底的18／136等值；没有代打真实第三关。
- 169.89 塔F2：四牌开打，采样13秒并继续记录到第三波。battle-hit-ui-tower2.json共31事件、wave索引0／1／2、5个敌方目标，全部锚点有效；截图同时有左右目标60及后续33／19等红字，杀死目标后数字仍显示。只声明三波命中与切波显示检查，未声明首通／胜利。
- 169.89 B08：三敌开打，截图有59／63／63及连弹35等红字；实际播放Petals。终章预览含队友数字、多段29、主角受击，所有事件锚点有效；旧间距重叠据此修正。没有结案真实通缉或通过真实终章。
- 169.90 Q30：第一轮重新连接窗口时已开始战斗，含外部协助；后续另开干净进程，由工具选择四牌、开始、跳过出场，立即采样。device-evidence/mistport-16990-q30-clean-1.png清楚区分同帧的80与65；clean-6.png显示不同排的52与16。最终battle-hit-ui-q30-final.json共89事件、缺失锚点0，首两项均battleTime=0.05且分别lane0／lane1，与图一致。较早倒地期间无新数字的采样未当成间距通过证据。截图自查不代替用户对法术、美工或整章体验的认可。

## 数据与交付

169.88恢复连接后的历史检查见[音乐与数字交接](HANDOFF_BATTLE_MUSIC_HIT_UI_20261013.md)。其后仅既有隔离shell一次变化，真实档、盲玩档与用户音乐开关SHA未变。

169.89安装前后275文件全一致，演练前后亦275全一致；169.90再次重新备份，preferences-install-comparison.json及preferences-qa-comparison.json均275→275，全部哈希一致，无变化、添加或删除。没有恢复旧存档、代发奖励或修改真实进度。

QA参数包含 -MistportCityMute YES --developer-tools --verify-battle-music；直接战场另用 -mistport.music.enabled YES，仅参数域覆盖，使播放器能以零音量被检查。用户持久音乐开关原为false，始终保留；独立诊断器不写开关／音量。

最终隔离进程76581已终止（terminate-qa.json/log）。保留游戏关闭，用户从手机图标冷启动回正常真实档，避免继承隔离参数。135项相关核心回归在音乐生命周期修复版通过；本次颜色和间距为显示修改，验证为两次标准编译及设备截图，没有增加镜像实现的样式测试。30份旧AIHero png.meta无关格式变动仍不提交。第一章完整盲玩通关仍未完成，不自动恢复代理。
