# 主角／主线法术参考强度第二轮 · 源码交接

依据 `output/all-spell-reference-20260923/whole/after` 新录制的 H04/H05/H10/H10-four、M01/M02/M10/M13/M14/M15/M16-recipient/M19/M20/M22 原 MP4 抽取全时序帧复看；不以旧 `whole-spell-round2` 片代替新片。新片中的 H04 双脸、H10 四组浅白脸墙、M10 等高绿雾、M13/14 近似蓝压力片、M15 核心与命中脱节、M22 与普通红斩缺少力度级差，均为本轮直接可见的缺口。参考图只规定主体面积、亮芯和层次的强度，防御/校准/治疗保持非伤害语义。

| 入口 | 此轮实际源码改动 |
| --- | --- |
| H04 身份错置 | 两张原瓷脸分别染冷蓝／暖铜（只改此招的实例材质），交换时背后两片不等厚卷缝沿脸移动；眼鼻仍在前景，不做伤害云。 |
| H05 伪证烙印 | 保留原紫色印面/腕压；命中增加深紫蜡、玫红、碎金三片错向短卷裂，随原接触包络快速退去。 |
| H10 无名宣告 | 中央瓷脸保留焦点，两个辅脸缩小、拉开深度，各组宽度收窄以减轻四目标白脸墙；三脸分别偏玫灰、深紫、暖金，绯帷加深并沿折边显金纹。原四实际目标实例、`.96s` contact 与 validity/generation 逻辑不动。 |
| M01 普通赤弧斩 | 原一片红弧命中由薄刃改为有色厚裂面、短金热芯和深色下折；只发生在原 contact。 |
| M02 守势／M19 强化／M20 校准 | 防御与强化改从真实双腕收向胸前的错层暖金护片，校准从真实笔腕展开较宽的连续紫墨卷面与笔芯；都不增加伤害爆炸、弹体或 ack。最新旧版 M20 已无等距梳齿，此轮继续使用连续曲面。 |
| M10 翠毒持续场 | 大盒雾减淡，仅作纵深；42 个不同宽、高、深度与色层的缓慢翻卷毒云成为可见边界，低位暗穴和浅黄绿毒脉不遮人物上身。原强度梯度、native tick 与结束清理不动。 |
| M13 飞臂／M14 刃群 | 真实飞臂/七金属刃及回装权不动；飞臂以单点蓝珐琅拳印和短压缩尾流收束，刃群以三道长短不同、错深度的卷曲切口收束，去掉两招共用的蓝压力褶主体。七装饰刃仍只对应原有一次伤害接触。 |
| M15 核心记忆 | 核心翻面后半段有蓝白折页沿核心→玩家世界路线飞行，在原 contact 前抵达；原三片错层记忆命中保留，不添加回调或伤害。取消时页片随实例清除。 |
| M16 已确认治疗 | 实际受疗者整体绿染减半，局部甲缝改为五道不等长的绿金连续闭合纹；只在正回血确认路径展示，原受疗对象/空修复契约不动。 |
| M22 精英重击 | 蓄势热量从肩收向持剑腕与剑脊；重击传递 elite 标志，仅在原精英接触画独立金赤厚压力楔、短金芯与暗色下折，普通 M01 不跟随放大。蓄力时钟、contact、数值不变。 |

改动文件：`HeroIdentityTheatreVFX.cs`、`HeroNamelessRound2.cs`、`HeroPorcelainRound2.cs`、`EmeraldPoisonField.cs`、`ArchivistMechanicalSpell.cs`、`MainlineContactRound2.cs`、`MainlineStateRound2.cs`、`ArchiveEncounterPresentation.cs`、`BattlePrototype.cs`。旧文件逐一备份于 `backups/reference-intensity-round2-20260923/hero-mainline/UnityBattleSource/Assets/Scripts`；当前 SHA256 在 `output/reference-intensity-20260923/hero-mainline-round2/source-sha256.txt`。H00/H01、翠焰亡灵已认可的贴身蓄力、Bounty/Church/Tower、录制器、共享 shader、规则、存档未改。

用项目当前 111 旧源及 54 新源生成隔离 Roslyn response file，完整 C# 静态编译 exit 0；输出 `/tmp/mindstone-complete-static-check-20260923.dll`。初次只编译九个文件并引用旧 `Assembly-CSharp.dll` 因重复 `BattlePrototype` 身份产生外部程序集型别冲突，不能作为最终结果；已以完整源码编译通过替代。没有启动 Unity/iOS。主控须定向复录全景/近景并实际检查 H04/H10 的颜色与四组不粘连、M10 是否由平带变卷云、M13 飞臂手指/回装、M15 折页到命中的因果、M22 与 M01 力度级差、M02/M19/M20 状态可读、取消/死亡/跨波清理。源码与静态编译通过不等于视觉认可。
