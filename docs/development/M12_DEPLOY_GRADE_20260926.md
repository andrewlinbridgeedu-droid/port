> 2026-09-26续：已确认手机为Build127并正常启动，存档权益保持；见[装机记录](BUILD127_INSTALL_20260926.md)。下文未装机描述为构建完成时的历史状态，真机视觉仍未验收。

# M12 封存装甲展开补修 · 2026-09-26

Build126 的 Q6 真机片确认 M12 已不再是四角盾框，但蓝面近乎恒定、层次偏弱，不能称满足用户给的绚丽和冲击力参考。此批仅补 M12 的**防御展开**，不把它改成伤害爆炸，也不改原生减伤、contact、冷却、敌人编队或存档。

[新旧正式 Unity 录制对照](../../output/spell-impact-m12-deploy-20260926/index.html) · [Build126 真机报告](SPELL_IMPACT_DEVICE_20260925.md)

正式三片不规则弯曲护片保留，着色改深钴蓝实体、银青内部刻纹与短促暖金点色。展开从 2.32 倍在约0.17秒张至5.10倍，再在约0.25秒内回收到3.70倍防护姿态；Build126此前固定约3.70倍。这是呈现尺寸和亮度脉冲，不改变防护持续或游戏规则。复看早帧时发现生成首帧曾在场景原点、主角脚边闪一下；已在对象创建当刻按敌人位置和镜头方向初始化，正式复录的0.20秒帧已位于敌人身侧，0.40秒达大峰值，没有错位闪现。修改前两个源码有独立备份 `backups/m12-deploy-grade-20260926`。

正式 `WholeSpellRound2Review20260922` 的 M12 全景/敌人近景各一段 MP4 重录；实看全景0.20、0.30、0.40、0.53、1.00秒等细帧，并与Build126旧片对比。录制检查核对当前守卫身份、预期0伤害、投影还原、无运行时错误和战斗时钟不变；安全检查核对停战无迟到接触、针体/小怪/通缉/塔/主角/主线临时对象清理。两次检查的完整源码SHA清单逐字节一致。回执位于[录制](../../output/spell-impact-m12-deploy-20260926/record-all-passed.txt)和[安全](../../output/spell-impact-m12-deploy-20260926/safety-all-passed.txt)。防御招预期0伤害，不能从这两段推断全章攻击命中合格。

Unity iOS设备导出已完成，导出manifest的951项当前来源文件逐一SHA256相同，见[导出核对](../../output/spell-impact-m12-deploy-20260926/export-source-check127.json)。录制400项源文件与当前一致，其中263项被设备导出包含且SHA一致，另137项为只供编辑器录制的脚本，见[同源核对](../../output/spell-impact-m12-deploy-20260926/capture-export-check127.json)。核心源码 SHA256：`ArchiveEncounterPresentation.cs` 为 `3d4005fed68f5392da04465a3e561c447ad4d06462f9a6cedda4e7fe0a455b4a3f52`，`ArchiveAegis.shader` 为 `4598c62cdde51e0e04c29dbe9cd5271eaac30154e9dd8a4cc89c523c3f1895a3`。

Xcode设备版完整编译及开发签名通过，`codesign --verify --deep --strict`退出0；[Build127回执](../../output/spell-impact-m12-deploy-20260926/final-build127.json)记录包版本、UnityFramework和原生二进制SHA。签名包已用APFS克隆保存在 `artifacts/releases/Build127/Mistport.app`，克隆后再次核签名和两项SHA，避免仅把可装包放在系统临时目录。**Build127未装手机，手机仍为Build126。** 新片无音轨，尚未真机看此轮峰值、帧率或获用户视觉认可。Q7/M15、H10、高塔和十案真机样本仍待设备可连续空闲时完成。
