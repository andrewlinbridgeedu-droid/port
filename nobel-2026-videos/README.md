# 2026 诺贝尔奖 · 四集科学与文学解说短片

四个奖项各一集，1080p / 30fps，中文配音 + 中文字幕 + 原创配乐。重点讲获奖的科学与文学本身，人物只在片头出现一次。

| 集 | 奖项 | 片名 | 时长 | 讲什么 |
|---|---|---|---|---|
| 一 | 物理学奖 | 冰中捕光 | 6:10 | 中微子为何是“幽灵粒子”与宇宙信使；冰立方如何用南极一立方千米的冰捕捉切伦科夫蓝光；如何在大气 μ 子的暴雨里挑出宇宙中微子；2013 年 PeV 中微子、2017 年耀变体 TXS 0506+056、2022 年 NGC 1068、2023 年银河系中微子图像 |
| 二 | 化学奖 | 镜中之谜 | 4:52 | 手性与镜像分子；生命的同手性之谜；非线性效应（不太纯的催化剂造出更纯的产物，“结对退场”机制）；不对称自催化（三轮反应把约 0.00005% 的偏向放大到 >99.5%）；同手性的起源与制药应用 |
| 三 | 生理学或医学奖 | 以光为令 | 4:29 | 神经元与离子通道；莱茵衣藻的眼点与光电流；通道视紫红质：视黄醛受蓝光改变形状、通道开启；2005 年神经元毫秒级光控；按细胞类型装开关；2007 年活体小鼠；蓝光开、黄光关；从相关到因果；2021 年光遗传学部分恢复视觉 |
| 四 | 文学奖 | 在残缺处写作 | 4:28 | 萨福残篇与方括号（对照中国画的留白）；“甜苦”与爱欲的三角；《红的自传》让被斩杀的怪物发声；文体边界的消融；《夜》的折页与翻译即哀悼；与古典“游戏式对话”（对照鲁迅《故事新编》） |

完整旁白见 [`NARRATION.md`](NARRATION.md)。

## 制作流程

1. **文稿** `scripts/<id>.json`：每段旁白分句；`t` 为字幕文字，`s` 为配音读法（数字写成汉字、多音字用同音字替换）。
2. **配音** `tools/tts.py`：离线中文语音合成（sherpa-onnx · Matcha 标贝女声）。每句生成多个版本，用 SenseVoice 语音识别回听，按拼音比对挑出最准确的一版，并生成时间轴 `build/<id>/timeline.json`。
3. **画面** `engine/`：每集一个场景脚本（Canvas 2D，全部为时间的纯函数），`render.mjs` 用无头 Chromium 逐帧截图并编码。字幕、章节卡、片头片尾由 `engine/core.js` 统一处理。
4. **配乐** `tools/audio.py`：程序合成的氛围音乐（和弦铺底、钟音、低频、转场音效），在旁白处自动压低，整体响度 −16 LUFS。
5. **合成** `tools/make.sh <id>`（H.264 母版）与 `tools/deliver.sh <id>`（≤28 MiB 的 HEVC 分享版）。

```bash
tools/setup.sh ~/.cache/nobel-2026        # 下载模型与字体，按提示 export TTS_DIR / ASR_DIR
python3 tools/tts.py physics --check       # 配音 + 读音回测
node render.mjs physics --stills 30,120    # 先看静帧
tools/make.sh physics 2 && tools/deliver.sh physics
```

## 资料来源

- 诺贝尔奖官网各奖项新闻稿与科普材料（nobelprize.org，2026 年 10 月 5–8 日）
- 新华社、中国日报、人民网对四项奖的中文报道（获奖者译名据新华社）
- 物理：NSF、NASA、Scientific American 对冰立方与哈尔岑获奖的报道；冰立方合作组 Science 2013 / 2018 / 2022 / 2023 论文
- 化学：Chemistry World、C&EN、RSC 报道；Kagan 等 JACS 1986；Soai 等 Nature 1995 及后续综述（0.00005% → >99.5%，三轮）
- 医学：Nature、STAT、Scientific American 报道；Nagel、Hegemann 等 Science 2002 / PNAS 2003；Boyden、Deisseroth 等 Nature Neuroscience 2005；Sahel 等 Nature Medicine 2021
- 文学：瑞典学院新闻稿、CNN、半岛电视台、Publishers Weekly、CBC 报道。萨福残篇 130 与卡图卢斯第 101 首按希腊文、拉丁文原文意译；书名为意译，并附原名

片中的曲线、能谱、分子与器官形态均为示意图，用于说明原理，不是实验数据。
