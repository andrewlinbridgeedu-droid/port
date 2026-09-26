# 联封深井按钮暗色与缩小 · 2026-09-25

## 本轮要求与实现

用户认可暗紫灰底、旧铜金细边、淡古金字的配色预览，并要求按钮再缩小约七分之一，减少对塔景主焦点的争夺。

- 四个正式资源 `ButtonArtChurchTower{Entry,Return,Next,Back}` 都已改为暗色同款，只替换“进入封印 / 重返封线 / 准备下一层 / 返回深井”文字。保留右端小型封印纹、切角、细双框和透明外部。每张仍为 1400 × 327 RGBA，位于 `mistport-ios/Mistport/Assets.xcassets/` 各自的 `.imageset/art.png`。
- `ChapterOneTestView.swift` 的共用 `ChurchTowerArtButton` 宽度上限由 350 改为 300，正好是原宽度的 6/7（缩小 14.29%）；点击动作、可用状态和无障碍名称未动。原 350pt 图像约高 82pt，新 300pt 图像约高 70pt。
- 生成母图、裁切后的正式图与 300px 实际大小的四张预览位于 `output/church-tower-buttons-20260925/dark-compact/`。旧浅色资源及原 Swift 文件备份在 `backups/church-tower-dark-button-20260925/prechange/`。
- 工程版本号从 77 提至 78，以便标识本轮设备包。

## 图片生成方式与提示词

使用内置 imagegen。先以原“重返封线”图片为编辑目标、真机塔页截图为配色参考生成暗色母版。母版提示词及真机配色预览提示词逐字保存在 `output/church-tower-buttons-20260925/color-preview/README.md`，母版生成源为 `/Users/andrewlin/.codex/generated_images/01a0c79c-3f4d-78e0-93c6-601df50a3999/exec-798240bf-8e78-406a-a31d-8f998f8aaa4f.png`。

后三图使用内置 imagegen 的 `text-localization`，以暗色母版作为编辑目标、原浅色对应按钮仅作文字参考。每张分别指定精确文字 `进入封印`、`准备下一层`、`返回深井`，其余约束相同：保持烟熏炭紫纸面、旧铜金双细框、右端封印纹与细线、透明外部及图像比例；文字用克制的古金色宋/明体；不恢复奶白色，不加羽笔、发光、背景或新符号。五字的“准备下一层”仅在中央文案区稍收字距与大小。生成源：

- Entry: `exec-873ade00-d574-4f29-ab74-540c3208e2d9.png`
- Next: `exec-8fafaee4-dd44-4f9d-aa65-10dd05211a6b.png`
- Back: `exec-20da8c75-9ca3-496f-928f-5a9cda2e69ef.png`

以上三图均在同一个 `/Users/andrewlin/.codex/generated_images/01a0c79c-3f4d-78e0-93c6-601df50a3999/` 目录；正式裁切图已另存至游戏工作区，并非仅存在生成目录。按生成图的 alpha 实际边界等比缩至 1400px，再裁至原 327px 画布，逐张检查了四处文字及 300px 缩图。

## 检查与界限

- iPhoneOS Debug 签名 Build 78 构建成功。`Assets.car` 查到四个新资源，四张 PNG 尺寸和 alpha 均核对通过。Unity 旧代码有弃用警告，但无构建错误。
- 已显式覆盖安装并启动连接的 iPhone 13。设备应用列表显示 `0.1.0 (78)`，进程列表显示游戏正在运行。
- 安装前与安装后 `Library/Preferences` 逐文件一致。启动后仅 `mistport.player-test-01-15.plist` 中 `mistport.campaign-relics.v1` 两个既有 ID 的数组顺序互换，内容未增减，其余偏好数据一致。三个阶段副本保存在 `backups/church-tower-dark-button-20260925/device-{before,after-install,after-launch}/`。
- 已在真机镜像中实际进入联封深井，分别选第 9 层看“进入封印”、第 1 层看“重返封线”；暗色和缩小后的比例显示正常。第 9 层和第 1 层均未进入战斗；“准备下一层 / 返回深井”的正式通关弹窗尚未实看，只检查了资源与 300px 预览。最终主观美感仍由用户判断。
