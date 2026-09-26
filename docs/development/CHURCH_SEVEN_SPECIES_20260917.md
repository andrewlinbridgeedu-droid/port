# 教会七物种制作与接入

D00 旧犬与 D01 盾颚沿用已验收运行资产；本批将已收到五个 GLB 制作为独立移动模型，不替换主线任何角色。原 GLB 保留 ArtSource/ChurchDemons20260916。

| 新运行母版 | skin | 三角面 | 骨骼 |
|---|---|---|---|
| Saltmaw | @saltmaw | 800,070 → 50,000 | 19 |
| Shellback | @shellback | 1,276,636 → 50,000 | 18 |
| Ironclaw | @ironclaw | 1,135,080 → 50,000 | 16 |
| FrilledNaga | @frilled-naga | 1,344,992 → 50,000 | 17 |
| Boneclaw | @boneclaw | 1,227,688 → 50,000 | 19 |

每体 8 段真实骨骼动画：Idle、Charge、Cast、Hit、Death、Charge2、Cast2、Retreat，2K 原 UV 色彩/法线/金属光滑度。D02 双囊、D03 双背囊、D04 反折镰臂、D05 独立蛇尾链与双冠膜、D06 尾与长爪分别绑定；没有把五体套一个人类骨架。

可编辑工程与生成脚本 ArtSource/ChurchDemonsCombat20260917，Unity Resources/Enemies/Signature/<母版>/VisualProfile。D01继续 @stonehide，D00 @early-hell-hound。编队最多4体，第三第四体后排左右，不能同点重叠。

## 权威回调

准备动作（tower_sac_charge、tower_mend_charge、tower_blade_charge、tower_raised_blade、tower_crown_charge、tower_claw_charge、recover）没有命中回调。其它每动作恰好一次，不将双镰一次动作发两次回调。

D03 tower_mend:<recipient>、D05 tower_empower:<recipient> 固定目标。目标死亡即时取消，独立 combat-contact payload=enemy-cancel:<actor>，不是 enemy:<actor> 命中；发起者死亡取消所有未命中表现且不再回调普通命中，由原生死亡事件清除 committed。目标消失不转移。D03不画绿线或绿圈，实际受疗者绿光/+HP仍由原生真实恢复发送。

D00后期 tower_pounce_charge、tower_hound_pounce 为每实例短扑，单次接触后返回原位，取消也还原。前10双火球不改；不会进入新铠甲犬地火。

## 通缉身体区分

@bounty-b01…@bounty-b06 使用已存在母版的独立实例材料和识别饰物，主线源材质不改。B01强制普通空壳不是幽灵；B03强制蓝色亡灵。B02通过面饰区别身份，B05保留清晰面部并用小银剪胸针；B03不用帽子方块，改贴胸船锚。B01小铭牌按蒙皮表面定位并随骨骼。这些是覆层处理而非新脸重雕。真实头像输出 output/church-bounty-portraits，不复用主线头像。

## 验证范围

实际 Unity PlayMode 两批检查已通过：

- `output/church-demons-combat-20260917/unity/passed.txt`：五独立蒙皮、真实待机骨骼变化、所有动作准备零/攻击一次 contact、战斗取消、冻结目标死亡、渐隐重试、四体坐标、六通缉身份与透明淡出。
- `output/church-demons-combat-20260917/unity/cancellation-passed.txt`：七恶魔加六通缉全部正常攻击一次回调；发起者在途死亡后零回调、重试恢复；D03/D05目标死恰好一个 enemy-cancel，零普通命中。
- 五段 2.4 秒 Unity GIF 与关键图在同目录；raw RGB 临时捕获已转码后删除，未保留逐帧 PNG。

四体前内后外交错位置另补实际截图，避免旧前后站位透视遮挡。手机性能、100层连玩与经济验证由主集成报告，不用模型检查冒充。通缉面饰是首期几何覆层，不是新面部雕刻或美术最终验收。
