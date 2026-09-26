# 第五关翠焰亡灵接入

用户提供：`/Users/andrewlin/Downloads/Meshy_AI_The_Emerald_Revenant_biped.zip`。
内容为 Walking 与 Running GLB，带模型和纹理。没有待机、施法、受击或死亡动画。

本批范围：第五关铃铛独立试演替换临时猎犬，正式第五关剧情/奖励重设计不因换模型自动完成。第四关保留猎犬。

转换：Blender GLB→FBX，提取basecolor、normal、metallic/roughness。Standard材质使用basecolor和normal；glTF金属粗糙度通道不直接误接Standard光滑度，当前使用标量。第一次FBX遗漏动画烘焙，已用包含Walking动画栈的版本替换，Unity已生成controller。当前定格步态中段，不声称原创待机/施法动画齐全。

运行时：`EmeraldRevenantPresentation`在现有战斗身份上替换可见模型，保留伤害回调；施法锚点使用新模型中心，身体绿色蓄力及透明铃沿用。退出试演恢复原模型。原始源文件和本轮脚本备份在 `docs/development/backups/emerald-revenant`。

构建/实测：待实际结果追加。第一轮Xcode因缓存数据库I/O及缺失协议提取文件失败，非编译源错误；已重试。

实测结果：/tmp/emerald-ready-export.log 和 /tmp/emerald-ready-build.log 成功，已安装。运行日志确认最初模型请求 handle=False，重试后 handle=True，已替换。实际战斗录像 `output/encore-bell/emerald-revenant-battle.mov`，第13秒帧 `emerald-battle-frames/frame-13.png` 显示新亡灵、绿色全身蓄力和透明铃同屏。身体发光从早期饱和绿降低为保留贴图细节的强度。
仍需后续调整：旧猎犬血条高度遮住人形头部，应抬高；当前姿势为定格步态且施法仅程序轻倾，专门动作仍缺；不能据此宣称第五关正式剧情/奖励/完整通关已完成。

## 动作与血条修订
按用户要求：试演血条相对旧位置上移40pt；身体绿色染色比例降低，自发光降低20%。运行时缓存导入姿势骨骼旋转，关闭冻结Animator的覆盖，在LateUpdate叠加待机呼吸/头部摆动、0.65秒双臂蓄力抬起、保持及0.8秒前伸回落。动作不改变战斗伤害或蓄力时钟，非新增Meshy动画片段。保留已验证的模型替换、缩放、朝向和旧猎犬隐藏逻辑。
Unity导出通过 `/tmp/emerald-motion-export.log`，iOS构建及实战截图待追加。
动作修订已构建安装实测：`/tmp/emerald-motion-export.log`、`/tmp/emerald-motion-hud-build.log`成功。模拟器確認敵血條位於帽頂上方，主角血條維持原位；雙臂蓄力姿勢與回落可見，綠色降低。最終實戰錄像 `output/encore-bell/emerald-motion-final.mov`。這是程序骨骼演出初版，不稱為Meshy專用動畫素材。

## 亡灵独立法术与测试列表
用户否定亡灵复用火球。新增 EmeraldRevenantSpell，引用本地 Effekseer 官方 Ribbon/effect1-2 和 DarkRift/Dark2。0.24秒聚光、0.78秒弧线幽能丝带、0.20秒裂隙命中；只替换亡灵分支，移除该分支FireBall和burst-infernal-impact-v1调用，第四关不变。伤害接触回调保持原时点。
测试列表Q4说明改为远处喷吐；Q5标示“不肯落幕·翠焰亡灵试演”及铃负面代价，去掉技术tag/0名AI。通过显式参数启用试演，已从非encore启动参数的列表实际点击进入并看到亡灵与铃，非仅改文案。
第一版实录 emerald-spectral-spell.mov 确认伤害-198和裂隙命中，但绿色丝带命中层像实心色片，随后移除该层、降低飞行丝带alpha。最终构建/实测待追加。
修正版 `/tmp/spectral-polish-export.log`、`/tmp/spectral-polish-build.log`成功并安装。实际录像 `output/encore-bell/emerald-spectral-final.mov`，逐帧可见半透明幽能丝带（spectral-final-frames/frame-148.png），命中不再出现绿色实心片或橙色爆炸。新法术为第一版演出，仍可提高辨识度；不声称达到参考动图最终质量。

## Blender 动作与宽幅灵带（2026-09-12，新一轮）
用户否定上版细丝与程序摆手。已用 Blender 5.2 在提供的骨架上制作单时间线，使用双臂 IK 后进行 visual_keying 烘焙、移除约束再导出。可复现脚本 `tools/art/emerald/bake_cast.py`；交付源 `output/encore-bell/emerald-cast.blend`。先前候选有目标 action 共享和未正确烘焙的问题，废弃，不能作为动画证据。

最终候选 FBX 重新导入 Blender 后，96帧双手收拢、150帧前伸均已检查，截图为 `emerald-charge-fbx.png` / `emerald-cast-fbx.png`，只属离线资产验证。Unity importer 已确认三段：Idle 1–48、Charge 49–120、Cast 121–198，24fps。运行时移除旧程序摆手，Cast加速3.8倍以匹配出手时刻。

法术增加三条宽幅螺旋灵带：深青色主体、浅翡翠边缘、流动纹理和扩散命中环，保留 Effekseer 次级层。当前此轮游戏构建与实战验证尚待完成；离线截图不代替实战验收。

本轮首版 Unity 导出 `/tmp/emerald-baked-export.log`、iOS `/tmp/emerald-baked-build.log` 均成功。真实模拟器 `emerald-baked-cycle.mov` 确认双手聚拢蓄力和摇铃延长保持；`emerald-cycle-frames/frame-180.png` 确认三条宽带飞行可见，但过于实体化，不视为最终视觉验收。现进一步减薄并增加破碎透明纹理、细亮边。此次测试为跳关试演；未操作假面导致失败，不是新档通关证据。

最终对比度修订：第一版宽带过实，第二版细纹透明过淡，第三版保留0.22宽度和细纹，将主体alpha基值调为0.42。`/tmp/emerald-balanced-export.log` 与 `/tmp/emerald-balanced-build.log`成功，安装并录制 `output/encore-bell/emerald-balanced-combat.mov`。保持第四关分支与伤害回调不变。本次为法术/动作视觉试演，不宣称达到参考动图全部层次，也不计作正式第五关通关。
