# 2026 诺贝尔奖 · 四部科学与文学短片（渲染工程）

四部约 3 分钟的中文解说短片，聚焦获奖成果本身：

| 片名 | 奖项 | 主题 | 渲染命令 |
|---|---|---|---|
| 《以冰为眼》 | 物理学奖 | 冰立方与高能天体中微子 | `npm run render:physics` |
| 《积微成著》 | 化学奖 | 手性、非线性效应与不对称自催化 | `npm run render:chemistry` |
| 《以光为钥》 | 生理学或医学奖 | 通道视紫红质与光遗传学 | `npm run render:medicine` |
| 《与火为邻》 | 文学奖 | 安妮·卡森：残篇、爱欲与新的形式 | `npm run render:literature` |

成片输出到 `output/`（1920×1080，30 fps，H.264 + AAC，响度 −16 LUFS）。资料笔记与出处见 `research/`。

## 一、准备（macOS，一次即可）

```bash
brew install node ffmpeg          # 已装可跳过
cd nobel-2026-videos
npm install                       # 安装 Playwright
npx playwright install chromium   # 下载无头 Chromium；装不上也行，会自动改用本机 Google Chrome
```

字体放在 `fonts/`：若随包附带的 `nobel-2026-fonts.zip` 已解压到此处即可；否则运行 `bash scripts/setup.sh` 自动下载（全部为开源字体：思源宋体、霞鹜文楷、马善政楷书、志莽行书、Cormorant Garamond、GFS Didot）。

> 国内网络若下载慢：`npm config set registry https://registry.npmmirror.com`，
> 以及 `PLAYWRIGHT_DOWNLOAD_HOST=https://npmmirror.com/mirrors/playwright npx playwright install chromium`。

## 二、渲染

```bash
npm run render:physics            # 渲染画面并合成配乐，得到 output/01_物理学奖_以冰为眼.mp4
npm run render:all                # 依次渲染四部
```

- 并行进程数默认取 CPU 核数的一半，可手动指定：`node engine/render.js physics --workers 8`，再 `bash engine/finish.sh physics 01_物理学奖_以冰为眼`。
- 只看某一秒的静帧：`node engine/render.js physics --still 30,60,90`（输出到 `build/physics/still_*.jpg`）。
- 只渲染一段：`node engine/render.js physics --from 40 --to 70`。
- 带声音的实时预览（可拖动时间轴）：`npm run preview`，或 `node engine/preview.js chemistry`。
- 字幕已烧录在画面中；另附外挂字幕 `assets/<片>/subtitles.srt`。

每一帧都是时间的纯函数，帧可以乱序、多进程并行渲染，结果完全一致。参考耗时：4 核云主机约 3–5 帧/秒；Apple Silicon 一般更快。

## 三、目录

```
films/<片>.js            各场景画面（Canvas 2D + WebGL2 着色器）
films/<片>.script.json   解说词：text 为字幕，say 为朗读文本（含多音字修正）
assets/<片>/timeline.json   配音时间轴（画面按句同步）
assets/<片>/soundtrack.ogg  成品音轨：解说 + 配乐 + 音效，已做响度标准化
assets/<片>/subtitles.srt   外挂字幕
engine/core.js kit.js gl.js 渲染内核、通用部件、着色器库
engine/player.html/.js      逐帧播放器；preview.html 为带声音的预览页
engine/render.js            无头浏览器逐帧渲染、并行编码
engine/finish.sh            画面 + 音轨封装成片
engine/build_tts.py         （可选）重新合成配音并生成时间轴
engine/score.py             （可选）重新生成配乐、音效与混音
engine/check_tts.py         （可选）用语音识别回听配音，排查读错的字
research/                   四个奖项的资料笔记、数字与易错点、出处
```

## 四、（可选）修改解说词后重做声音

需要 Python 3 与离线模型（约 900 MB）：

```bash
WITH_TTS=1 bash scripts/setup.sh          # 下载 Kokoro 中文语音、SenseVoice 识别模型，安装 sherpa-onnx 等
python3 engine/build_tts.py physics        # 重新配音，更新 assets/physics/timeline.json
python3 engine/check_tts.py physics        # 可选：回听核对
python3 engine/score.py physics            # 重新配乐与混音（build/physics/mix.wav）
npm run render:physics                     # finish.sh 会自动改用新的混音
```

配音音色：科学三片为 Kokoro v1.1 中文男声（sid 68，语速 1.05），文学片为女声（sid 18）。注意 Kokoro 词典把单字“为”默认读 wèi，表示 wéi 时在 `say` 里写作“维”（片中“以冰为眼”“与火为邻”即如此处理）。
