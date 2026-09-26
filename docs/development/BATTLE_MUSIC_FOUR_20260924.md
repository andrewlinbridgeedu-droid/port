# 第一章四首战斗音乐接入（2026-09-24）

用户提供的四个 MP3 是本批唯一战斗配乐来源。原始文件逐字节保存在 `output/battle-music-four-20260924/originals`；`tools/audio/prepare_battle_music_four.py` 仅为游戏版本剪去淡出尾段、做首尾 2.8 秒交叠，并压成 44.1 kHz 立体声 AAC。剪辑边界、音量测量和文件大小见同目录 `music-prep-report.json`。旧 Lyria 战斗曲保留在源码中，但不再进入 iOS 安装包。

| 曲目 | 正式战斗场景 |
| --- | --- |
| `Petals_on_the_River` | 主线 Q1–5 雨夜旧城区；通缉 B07 铃蛙、B08 假面决斗者 |
| `Gears_Against_the_Fog` | 主线 Q6–15 档案与齿轮调查；教会塔 F1–30；通缉 B01、B04、B09；早期巡检 |
| `The_Harbor’s_Iron_Toll` | 主线 Q16–27 签发、押运与港口营救；教会塔 F31–70；通缉 B02、B03、B06 |
| `March_of_the_Brass_Tide` | 主线 Q28–30 瑟维安三战；教会塔 F71–100；通缉 B05、B10 |

按 `encounter.id` 路由，不改战斗数值、奖励、存档或故事。战斗中同一场景不重新启曲；新战斗即便仍处于战斗视图也会按新 ID 换曲。战斗结算、离开视图、关闭音乐和音量滑块沿用原控制路径。陌生战斗 ID 回退到 Gears；塔维护委托按其实际塔层决定。

已做：五项路由测试覆盖 30 关、塔层边界、十案及维护层；Xcode 工程 plist 检查通过；四份 AAC 文件生成、复解码并检查首尾采样衔接。签名 iOS Build 66 构建及 `codesign --verify --deep --strict` 通过，包内有四首新曲、无旧统一曲；已安装并启动 iPhone 13，设备列表确认 `0.1.0 (66)`。安装前、安装后、启动后的 `Library/Preferences` 逐文件一致，备份在 `backups/battle-music-four-20260924/device-*`。真机逐场切曲、音质、战斗音效与配乐混音感受仍须以设备听感复核，不以构建通过替代。

接入文件：`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/BattleMusicRoute.swift`、`mistport-ios/Mistport/HomeMusicController.swift`、`mistport-ios/Mistport/ChapterOneTestView.swift`、`mistport-ios/Mistport.xcodeproj/project.pbxproj`。
