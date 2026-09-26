# Codex执行者减面、绑定与游戏接入

用户批准以Codex Sentinel 0917011404替换旧Ironclad执行者，并接入全部战斗动作、删除旧源。

## 资产

- 新高模母版SHA256：757c980ddcea6b702a44ab3986830b6fb529623a839c00afed34e42a4ffa0e97。
- 原2,659,422三角 → 60,000三角（减少97.74%），28,412顶点，22骨；真实2K BaseColor/Normal/MetalSmooth。
- Idle、Charge、Cast、Hit、Death、Charge2、Cast2。笔臂签署与左掌盖印两套动作，机械部件局部权重；原地远程角色，无移动片段，手指各简化一关节。
- ArtSource/CodexExecutor20260916保存新高模、可编辑Combat.blend、FBX、GLB、贴图、制作脚本和manifest。
- Blender重开验证贴图尺寸/色彩空间；Idle循环及蓄力→施法→Idle边界旋转一致。证据output/codex-executor-delivery-20260916/blender-validation.json、combat-motion.gif。

## 接入

独立executor-template与@executor，内容ID enemy_codex_executor映射稳定clock-guard身份。未覆盖白门卫、书记员、救援者。正式BattlePrototype场景含模板，资源路径UnityBattleSource/Assets/Resources/Enemies/Signature/CodexExecutor。
两段笔尖演出使用实际单次contact回调；补Story.Cancel使死亡或解除命令立即取消残余攻击。

## 验证

- 四项核心身份测试通过，含独立双执行者、同伴死亡后身份稳定、原门卫外观保持。
- 实际Unity Play Mode：七段导入、两攻击受击干扰仍各命中一次、取消/死亡不命中、约1秒死亡淡出与Idle恢复、双实例、跨编队清理、重试通过。
- Unity证据output/codex-executor-delivery-20260916/unity/passed.txt及逐帧PNG。攻击截图含刻意Hit干扰，完整动作看Blender动图。
- Unity iOS导出新鲜度检查通过，原生Build40构建成功，Info.plist核对版本40；回执backups/codex-executor-production-20260916/integration/build40-receipt.json。未安装手机。

## 删除与边界

旧Downloads/Meshy_AI_Ironclad_Sentinel_0916101320_texture.glb在核对SHA256后删除，释放144,752,820字节；回执backups/codex-executor-production-20260916/deletion-receipt.json。保留历史小预览与新源，可追溯而不继续依赖旧GLB。
Q17/Q24为规划用途，本次资产接入不代表这两关已开放或数值通过。手机仍旧Build37；工作区既有Q5/Q6假面/勋章平衡缺口未在本次修改。
