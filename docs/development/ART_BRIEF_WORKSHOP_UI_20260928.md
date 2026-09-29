# 美术需求：百工坊与盐港页面的按钮、步骤插图 · 2026-09-28

用户要求：新做的页面都要有画出来的图，按钮要跟游戏现有的统一扁平风格一致。现在百工坊、角色页的序列 8 仪式、黑盐岸码头、转运站、检修单、事件预览这几页用的是 iOS 系统按钮，要换掉。交给 Codex 用内置 imagegen 出图；接入代码由 Claude 这边做，Codex 不改代码。图未经用户认可不算合格，不入包。

**状态：** Codex 已交付 10 张（`ArtSource/WorkshopUI20260928/`，每张生成 1 轮）。用户 2026-09-28 看过后认可；已告知的两处小偏差为取材插图右侧多画了工作台、检修架插图带一个发光箭头。已登记为 `ButtonArt*`、`WorkshopStep*` 素材，由 `PlateButton` 组件接入 Build 158，待真机截图确认。按钮两侧的金点装饰贴着文字区，没有落在两端，所以底板只能整体等比缩放，不能拉伸中段。

韧皮、维修绑带、检修组具三个图标和两派徽记，已经在 [ART_BRIEF_SALTPORT_20260928.md](ART_BRIEF_SALTPORT_20260928.md) 第二批里，这里不重复。

---

## 给 Codex 的要求（整段复制）

在 mindstone-game 仓库里画 10 张图：7 张按钮底板、3 张步骤插图。**只出图并存档，不改任何 Swift 代码、Xcode 工程或 Asset 目录。**

### 一、按钮底板（7 张）

**先看现有按钮，照这个风格画：**
- 浅色款：`mistport-ios/Mistport/Assets.xcassets/ButtonArtChurchLoanContract.imageset`、`ButtonArtChurchGearEquip.imageset`、`ButtonArt25MainAction.imageset`
- 深色款：`ButtonArtChurchTowerEntry.imageset`、`ButtonArt29ChurchAction.imageset`、`ButtonArtBountyAccept.imageset`

共同特征：扁平，不做 3D 凸起或高光；四角切角；细金色双线边框；文字区两侧各一组小金点加短横线；右端一个小徽记。浅色款是米色羊皮纸底，深色款是深紫灰带细纹理的底，边框金色。

**规格（7 张都一样）：**
- 866×192 像素，PNG，透明背景（按钮外面透明）。
- **按钮上不写任何字**，文字由代码叠加，因为价格和数量会变。
- 中间约 60% 的宽度必须是均匀的纸面或纹理，没有装饰，代码要横向拉伸它。左端装饰限制在左边 100 像素以内，右端徽记限制在右边 200 像素以内。
- 不要文字、字母、数字、水印。

| 文件名 | 底色 | 右端徽记 | 用在 |
|---|---|---|---|
| `button-workshop-primary.png` | 浅色羊皮纸 | 交叉的小锤和锥子 | 学习图纸、制作一批、交货、安装（百工坊和转运站工作台） |
| `button-workshop-secondary.png` | 深色 | 一座小钟楼剪影 | 前往教会塔取材、返回、取消 |
| `button-saltport-route.png` | 深色 | 船锚叠一枚盐晶 | 前往外港转运站、返回黑盐岸码头、转运站检修单 |
| `button-saltport-news.png` | 浅色羊皮纸 | 卷起的公报纸卷 | 看最新公报、比较两份计划、查看项目账、看结果 |
| `button-ritual-sequence8.png` | 深色，边框里多一圈细金线 | 八角星形印记 | 举行序列 8 仪式（角色页和黑盐岸码头） |
| `button-public-battle.png` | 深色，边框用暗红和金色 | 两把交叉的短刃 | 进入战斗（公共行动） |
| `button-side-choice.png` | 浅色羊皮纸 | **不画徽记**，右端留出 200 像素空白圆位 | 选择泵站联合会或灰帆联营，代码把两派徽记叠在圆位上 |

七张放在一起看要像同一套：边框粗细、切角大小、金点装饰都一致。

### 二、百工坊步骤插图（3 张）

**风格参考：** `mistport-ios/Mistport/Assets.xcassets/GameNavWorkshopAnime.imageset/art.png`（百工坊图标）：明亮的金蓝配色、细线描边、干净的动画插画感。

**规格：** 900×360，PNG。背景四周渐隐到 #26272B（与卡片底色一致），主体居中偏右，左侧 40% 较暗、留给文字。不要文字、字母、数字。

| 文件名 | 内容 | 放在 |
|---|---|---|
| `step-gather.png` | 教会塔第一层：石拱门后一只盾颚魔的暗影（厚重的石质颚甲），门前地上一块卷起、用麻绳捆着的韧皮 | “01 · 取材”卡片 |
| `step-craft.png` | 皮革工作台特写：切好的皮条、锥子、针线、黄铜扣环，三条刚做好的深棕绑带 | “02 · 皮革制作”卡片 |
| `step-install.png` | 工坊检修架：铸铁与木头的支架，两条开裂的旧绑带被拆下挂在一边，两条新绑带已扣在支架上 | “03 · 工坊检修架”卡片 |

### 交付

- 存到 `ArtSource/WorkshopUI20260928/`，文件名如上；每张另存一份 1/3 尺寸预览 `*-preview.png`。
- 在同目录写 `README.md`：每张图的最终提示词、生成原图路径（`~/.codex/generated_images/...`）、编辑过几轮。
- 另外拼一张 `contact-sheet.png`：7 个按钮底板上用临时文字试排（比如“制作一批 · 13铜”“前往教会塔取材”“进入战斗”），方便用户一眼看效果。这张只用来审看，不入包。
- 不删除、不覆盖任何已有图片；不动 `output/`、`artifacts/releases/`、`UnityBattleSource/Library` 等符号链接。

---

## 接入计划（出图并经用户认可后）

- 新增一个通用按钮组件：底板用 `resizable(capInsets:)` 横向拉伸，左 100、右 200 像素不拉伸；文字用现有的金色或深色宋体，禁用时降到 45% 不透明（沿用 `ChurchActionButton` 的做法）。
- 替换以下页面里的系统按钮：`LocalWorkshopView`（百工坊）、`CharacterProfileView` 的序列 8 仪式行、`WorldViews` 里的码头、转运站、检修单、事件预览、公共战页面。
- 三张步骤插图放进百工坊三张卡片的顶部；百工坊顶部的铜币图标改用现有的 `RewardCoin`。
- 入包前压缩；真机截图给用户确认后才算接入。
