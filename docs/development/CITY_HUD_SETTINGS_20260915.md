# 主城顶栏与设置
- 顶栏两行：名字/路径序列地点 + 测试/设置；第二行铜币、材料、线索、演证、声望。移除主城外层悬浮测试按钮避免重叠。数字单行缩放，无原39pt定宽。
- 底部蓝色背景全屏宽，内部图标22pt边距，背景延伸到底部安全区。任务条/顶栏各自保留边距。
- GameSettingsView：名字12字符持久保存；音乐开关和音量实际接AVAudioPlayer；界面音效0静音/音量/试听，主城按钮接合成提示音；减少界面动态与系统辅助设置取OR，影响既有入场/卡牌动画；战斗振动控制sensoryFeedback。
- 不宣称战斗音效总线或3D画质选项已实现。减少界面动态不削弱技能信息或改战斗时序。
- 所有设置显式UserDefaults.standard，与当前游戏存档suite独立，修复旧音乐开关读写存储不一致。进度不重置，城市功能锁保留。
- 新文件GameSettingsView.swift加入Xcode Sources。Build15，备份backups/city-hud-settings-20260915；音乐备份backups/home-settings-20260915。
- 构建/安装以实际后续结果为准；无手机新UI截图验收。

Build15构建成功并安装启动iPhone13。安装前后存档一致：True；测试入口：True。设置UI和声音尚需用户在手机复核。
