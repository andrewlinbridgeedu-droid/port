# 第一章经济任务角色建模清单

第一章按20个经济任务角色设计：3名银行与交易人员、5名生产人员、5名航运人员、3名公共服务人员、4名海盗与地下关系人。角色与名字为本轮设计；现有人物若承担同一岗位，沿用其身份和外观，不另造替身。新增3D素材尚未制作。

先生成经理、工程师、仓库主管、船长、货主及三名登船敌人共8个关键角色，再补其他12人。经理已有新的接待室插画，可作为其服装、脸型和配色参考：BankManagerOffice20261014。其他角色需单独区分剪影，不用同一模型只换颜色充人数。

## 共用生成要求

每个角色单独生成。英文提示词先使用下列共用段，再接各角色描述：

> One full-body adult human character for a stylized realistic Victorian dark-fantasy harbour RPG. Natural readable anatomy, detailed but clean clothing, believable worn fabric and brass details, grounded human proportions. Neutral A-pose, arms separated from the torso, empty hands, fingers separated, both feet fully visible, no pedestal. One character only, plain neutral background, no text, logos, floating effects, environment, extra limbs or fused props. The character must be recognisable by silhouette, not only colour.

项目目标：普通人物身高约1.6–1.9米，重装海盗可略壮；优先共用人形骨架。衣物和护具不能把胳膊与身体粘成一块。书、箱子、锤、剑、枪钩和座椅单独做道具，后续挂在手或骨骼上，不让生成器把手和道具熔在一起。

移动端目标预算为普通人物约8千至1.8万三角面，头目约1.5万至2.5万；普通人物先用1K贴图，主要近景人物再按效果决定2K。这是项目目标，不是Meshy产品限制。保存可编辑模型、材质贴图和干净中立姿势版本，先做一个关键角色验证导入与动作，再批量生成。

## 银行和交易

| 编号 | 角色 | 游戏职责 | 主要出场 |
|---|---|---|---|
| 01 | 阿尔登 投资经理 | 报价、声望审核、追加说明与合同协商 | Q1起展示项目，Q13与Q20主持产业签约 |
| 02 | 伊芙 存款柜员 | 存单、到账通知、提前取回与预算提醒 | Q1起；岗位优先复用现有柜员 |
| 03 | 塞拉 贸易经纪人 | 比价、询价、寻找替代买家，不担保消息绝对正确 | Q5起 |

**01 阿尔登**

> A courteous male bank investment manager in his late forties, wavy dark brown hair with grey temples, short neat salt-and-pepper beard, broad calm face. Dark forest-green Victorian frock coat, charcoal patterned waistcoat, ivory shirt and black cravat, modest brass watch chain, polished brown boots. Broad shoulders and a welcoming dignified presence. Match the manager in the supplied Mistport office reference; do not include the desk or office.

动作：站立与坐姿待机、迎客、指订单、解释、拒绝、结束会面。椅子单独导入。

**02 伊芙**

> A young adult female savings teller, short loosely waved chestnut hair, thoughtful friendly face. Ivory puff-sleeved linen blouse, fitted deep-green waistcoat with restrained brass embroidery, brown tailored trousers, simple practical shoes. Slender upright silhouette, professional rather than aristocratic. A small belt pouch, no paper or ledger in the hands.

动作：柜台待机、核对、记账、交付存单；可复用现有柜员立绘特征。

**03 塞拉**

> A sharp-eyed adult female harbour trade broker, black hair in a compact low bun, narrow angular face. Long navy travelling coat over a muted burgundy waistcoat, high-collared ivory shirt, fitted trousers, weathered leather ankle boots, two flat document pouches on the belt. A mobile, businesslike silhouette, not a royal uniform.

动作：站立、行走、指报价、对话、摇头。

## 自行车和工坊

| 编号 | 角色 | 游戏职责 | 主要出场 |
|---|---|---|---|
| 04 | 赫伯特 车厂负责人 | 接受订单，公布采购、产量与停工原因 | Q13起 |
| 05 | 黛娜 工程师 | 查缺件、诊断装配，提出可核查的修复方案 | Q13起 |
| 06 | 乔里 试车员 | 演示故障、完成试车，指出赶工代价 | Q13起 |
| 07 | 帕维 仓库主管 | 领料、库存、箱签、实际出货 | Q5起；优先复用现有货场人物 |
| 08 | 米拉 买家代表 | 下订单、确认扩单、验车、拒收或付款 | Q13起 |

**04 赫伯特**

> A stocky middle-aged male bicycle workshop owner, receding auburn hair, thick moustache, square kindly face. Rolled ivory sleeves, dark olive work waistcoat, heavy brown leather apron reaching the knees, sturdy striped trousers and worn work boots. Broad chest, practical modest wealth, subtle oil stains, no tools in the hands.

动作：待机、交谈、查看车架、着急、认可。

**05 黛娜**

她是自行车厂工程师，与Q16的机械医生维拉·铜枝分工不同，不接管其主线身份。

> An adult female mechanical engineer with copper-red braided hair tied behind her head and a focused angular face. Slate-blue work jacket, rolled sleeves, fitted tan trousers, short dark leather utility apron, brass-rimmed goggles resting on her forehead, narrow tool belt and sturdy boots. Athletic practical build, precise professional appearance, not a glamorous costume.

动作：行走、检查、蹲下维修、解释、试验失败反应。

**06 乔里**

> A lean young adult male bicycle test rider, sandy blond cropped hair and a cheerful freckled face. Short burnt-orange cycling jacket, cream shirt, dark breeches, knee socks, leather lace-up shoes, close-fitting soft riding cap. Slim agile silhouette with light protective leather elbow pads. No bicycle included.

动作：站立、跑动、蹬车姿势、刹车、摔倒与起身；自行车另做道具。

**07 帕维**

> A broad, tall adult male warehouse foreman with a shaved head, short dark beard and heavy brows. Faded russet work shirt, broad suspenders, thick charcoal trousers, short canvas apron, reinforced leather boots and a key ring hanging from the belt. Thick hands and a strong practical silhouette, no crate or ledger included.

动作：行走、指货架、清点、抬箱、交货。已有货场人员可承担该角色。

**08 米拉**

> An elegant but practical adult female retailer and purchasing representative, dark brown shoulder-length hair pinned back, composed face. Plum-coloured fitted Victorian jacket over a pale blouse, ankle-length charcoal walking skirt, practical leather boots, a small brass clasp and structured waist pouch. Crisp narrow silhouette, sensible merchant clothing rather than a ball gown.

动作：核对、验收、签字、拒收、满意；文件另挂。

## 航运

| 编号 | 角色 | 游戏职责 | 主要出场 |
|---|---|---|---|
| 09 | 罗温 商船船长 | 航线、船况、出航窗口与航行决定 | Q20起 |
| 10 | 艾丝 大副 | 装货、船员分工、遇袭时保货 | Q20起 |
| 11 | 巴斯 货主 | 真实买卖需求、托管、追加与赔付谈判 | Q20起 |
| 12 | 芬恩 修船匠 | 勘查破损，提供修理或备用船报价 | Q20起 |
| 13 | 伊莎 港口信号员 | 提供带时间和来源的航路情报 | Q20起 |

**09 罗温**

> A weathered male merchant captain in his fifties, grey beard, sun-lined face and solid upright build. Long deep-navy sea coat with worn brass buttons, off-white knitted sailor shirt, brown belt, dark trousers, tall battered sea boots and a simple captain's cap. Restrained practical authority, no fantasy crown, no ship included.

动作：待机、指航线、登船、指挥、受击与倒地。

**10 艾丝**

> A fit adult female merchant-ship first mate, dark hair in a tight braid, alert strong face. Short teal wool sea jacket, cream sailor shirt, dark fitted trousers, wide leather belt with rope loops, knee-high working boots. Compact athletic silhouette, weathered clothing, sleeves ready for work, empty hands.

动作：行走、装货、示警、格挡、攻击、受击、倒地。

**11 巴斯**

> A prosperous middle-aged male cloth cargo merchant with a round thoughtful face, neatly combed black hair and a small moustache. Sand-coloured long coat, warm burgundy brocade waistcoat, ivory shirt, modest gold watch chain, dark trousers and clean leather boots. Slightly heavy dignified build, recognisably distinct from the green bank manager.

动作：看清单、议价、签字、忧虑、付款。

**12 芬恩**

> A sturdy older male shipwright with short silver hair, rough friendly face and thick forearms. Faded blue linen shirt with rolled sleeves, broad tan canvas apron with simple patch repairs, heavy brown trousers, thick leather boots and a leather utility belt. Rugged working-class silhouette, no hammer or saw in the hands.

动作：检查船板、蹲下、维修、解释、收工；工具另挂。

**13 伊莎**

> A slender adult female harbour signal keeper with short black hair, sharp attentive eyes. Moss-green short weather cape over a cream high-neck shirt, navy waistcoat, straight dark trousers, practical ankle boots and a compact soft cap. A distinct cape silhouette and small brass signal insignia without letters; no telescope included.

动作：观察、打信号、奔跑、报信；灯和望远镜另做。

## 公共服务

| 编号 | 角色 | 游戏职责 | 主要出场 |
|---|---|---|---|
| 14 | 达瑞 验印员 | 核对封印、箱数、原始签收记录 | Q5起；复用公证柜台人物 |
| 15 | 芮恩 理赔调查员 | 判断损失证据与责任，不自动承诺全额赔偿 | Q20起 |
| 16 | 奥黛尔·芬 记忆医生 | 船员和工人救治，产生实际费用与人物后续 | Q4起；复用现有诊所人物 |

**14 达瑞**

> A precise adult male municipal cargo inspector with a narrow clean-shaven face, short tidy brown hair and small round spectacles. Charcoal-blue civil-service coat, olive waistcoat, pale linen shirt, plain trousers, polished working shoes and a simple brass badge with no text. Upright restrained silhouette, no stamp or paperwork in the hands.

动作：核对、盖印、指错误、拒绝、交还单据。

**15 芮恩**

> An adult female maritime claims investigator in her forties, ash-brown hair in a neat bun, calm sceptical face. Long taupe travelling coat, muted blue waistcoat, white high-collared shirt, dark ankle-length skirt and weatherproof boots. Small leather evidence pouches at the belt, practical middle-class silhouette, no magnifying glass included.

动作：查看证据、记账、询问、拒赔、认可。

**16 奥黛尔·芬**

> An adult female harbour clinic memory doctor, Odelle Finn, composed compassionate face and practical appearance, matching the existing Mistport Odelle Finn character reference. Ivory physician's coat over a muted grey-green waistcoat, dark trousers, simple clean shoes and a small medical belt pouch. No modern surgical mask, electronics or glowing magic. Empty hands, readable professional silhouette.

动作：待机、检查伤者、包扎、解释、急救。沿用《WORLD_CONTINUITY》中的奥黛尔·芬；以现有参考确定脸型和服装，有可用模型就直接复用，不重新生成替身。

## 海盗和地下关系人

| 编号 | 角色 | 游戏职责 | 战斗身份 |
|---|---|---|---|
| 17 | 赤潮维克 海盗头目 | 决定劫货目标，可逃走、投降或死亡 | 指挥登船、重击、撤退；一章不重复复活领奖 |
| 18 | 米克 快刀登船者 | 攀船夺箱，逼玩家保护货物 | 快速近战、移动、打断 |
| 19 | 铜拳戈恩 重装登船者 | 破坏船门与挡住撤运 | 慢重击、护货争夺、明确蓄力 |
| 20 | 夜鸥薇 走私接头人 | 提供可疑航路消息、残货回收和赎货谈判 | 可谈判人物；必要时防御撤退 |

**17 赤潮维克**

> A formidable adult male pirate captain, lean tall build, weathered angular face, swept-back dark red hair and a trimmed beard. Long dark oxblood sea coat with asymmetrical worn lapels, black leather waistcoat, faded ivory shirt, wide belt, fitted dark trousers and high sea boots. A jagged shoulder silhouette and restrained tarnished brass details. Sword and boarding pistol are separate props; empty hands, no skull crown.

动作：待机、行走、跑动、指挥、普通攻击、重击蓄力与释放、受击、格挡、倒地、投降、撤退。

**18 米克**

> A wiry adult male pirate boarding raider, cropped black hair, narrow mischievous face and agile build. Short faded charcoal sea jacket, striped cream shirt, compact leather harness with rope loops, fitted grey trousers and soft brown boots. An agile narrow silhouette with a single rust-red neck scarf. No dagger or rope held in the hands.

动作：攀登、冲刺、夺箱、快速攻击、后撤、受击、倒地。

**19 铜拳戈恩**

> A very broad adult male pirate boarding bruiser, bald head, thick neck, scarred square face. Heavy dark leather vest over a dirty pale sailor shirt, an asymmetrical hammered-brass shoulder guard, large forearm bracers, reinforced navy trousers and heavy sea boots. Clearly heavier and slower silhouette than the raider; grounded human anatomy, not a robot. Empty hands, boarding hammer separate.

动作：慢走、重击蓄力、砸门、格挡、受击、倒地。大型锤另挂，武器命中要对应动作接触。

**20 夜鸥薇**

> An adult female harbour smuggling contact, short ash-black hair, alert intelligent face, slim balanced build. Dark petrol-blue short hooded cape with the hood down, fitted brown leather waistcoat, pale grey shirt, dark trousers, quiet ankle boots and several discreet belt pouches. A recognisable cape-and-pouch silhouette, subtle wear, no glowing runes, no held weapon.

动作：待机、低声交谈、指路、行走、快跑、防御撤退。她可以撒谎但有可查证的消息来源，不只是随机扣钱按钮。

## 交付和接入

建议文件按编号与角色短名保存，每人一个文件夹，附中立姿势模型、贴图、角色正侧背参考和动作清单。非战斗人物先做好待机、行走和对话；海盗头目和两名登船者补战斗、投降和撤退；走私接头人只补谈判、防御和撤退所需动作。不要为每个柜员生成全套攻击动画。

模型接入后逐人检查比例、面朝方向、脚底、材质、手持物挂点、受击与死亡动作。站姿通过后再进真实任务；生成成功、导入成功都不等于人物和战斗表现已经认可。
