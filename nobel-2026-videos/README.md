# 2026 诺贝尔奖 · 四部科学与文学短片

四部约 3 分钟的中文解说短片，聚焦获奖成果本身（而非人物）：

| 片名 | 奖项 | 主题 | 成片 |
|---|---|---|---|
| 《以冰为眼》 | 物理学奖 | 冰立方与高能天体中微子 | `output/01_物理学奖_以冰为眼.mp4` |
| 《积微成著》 | 化学奖 | 手性、非线性效应与不对称自催化 | `output/02_化学奖_积微成著.mp4` |
| 《以光为钥》 | 生理学或医学奖 | 通道视紫红质与光遗传学 | `output/03_生理学或医学奖_以光为钥.mp4` |
| 《与火为邻》 | 文学奖 | 安妮·卡森：残篇、爱欲与新的形式 | `output/04_文学奖_与火为邻.mp4` |

资料笔记（含出处与易错点）见 `research/`。

## 制作方式

全部画面由代码逐帧生成：Canvas 2D + WebGL2 着色器（星云、极光、黑洞、星系、冰体光、水波焦散、宣纸、墨迹），在无头 Chromium 中按时间确定性渲染，多进程并行编码；配音为离线神经网络语音合成（sherpa-onnx · Kokoro 中文音色），配乐与音效由 Python 程序化合成并对解说做侧链闪避，最后统一响度到 −16 LUFS。

```
films/<片>.script.json   解说词（字幕文本 text 与朗读文本 say）
films/<片>.js            各场景画面
engine/build_tts.py      合成配音、生成时间轴 build/<片>/timeline.json
engine/render.js         逐帧渲染（--still 秒,秒 输出静帧；--workers N 并行）
engine/score.py          配乐、音效与混音
engine/finish.sh         响度标准化并封装成片
```

重建一部片子：

```bash
python3 engine/build_tts.py physics      # 需要 sherpa-onnx 与 Kokoro 模型（TTS_MODELS 指向模型目录）
node engine/render.js physics --workers 4
python3 engine/score.py physics
engine/finish.sh physics 01_物理学奖_以冰为眼
```

字体（思源宋体、霞鹜文楷、马善政楷书、志莽行书、Cormorant Garamond）放在 `fonts/`，未纳入仓库；均为开源字体，可从 Google Fonts 与 LXGW WenKai 的 GitHub 发布页获取。
