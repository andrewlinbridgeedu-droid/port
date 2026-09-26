# D01 盾颚魔首期运行资产

用户授权开通教会塔；本批仅 D01 新母版与 D00 旧犬支持前期，不将其余五只高模声称接入。

- 母版：ArtSource/ChurchDemons20260916/Meshy_AI_Stonehide_Colossus_0917020850_texture.glb，原文件保留。
- Blender 实际减面：1,605,428 → 54,998 三角；16 骨蒙皮，源 UV / PBR 保留，2K 色彩、法线、金属光滑度。
- Idle / Charge / Cast / Hit / Death / Charge2 / Cast2 / Retreat 共 8 段；待机胸颈观察、长臂交替小幅承重，双臂蓄力及重砸，脚不前扑。没有武器或人形守卫替代。
- 可编辑文件 ArtSource/StonehideRig20260917/Stonehide_Combat.blend；配套 prepare.py / rig.py 可重建。
- Unity 接口：@stonehide；Resources/Enemies/Signature/Stonehide/VisualProfile。正式 BattlePrototype 模板/攻击/取消已注册，使用 clock-guard-* 稳定实例 ID。
- 独立 Unity PlayMode 已通过：16 骨实际蒙皮、8 段每段 170 曲线、两种攻击各一次命中、取消无命中、死亡后重试恢复。fit 测量高度 2.65、脚底 0。
- Blender 与 Unity 实拍见 output/stonehide-delivery-20260917；这不是整塔连续通关、完整淡出或手机性能验收。由主集成继续验证。

## 实际塔编队追加验证

- D00+D01 与双D01均以正式 ConfigureWaveInstances 运行；两物种前排分开，未替换成普通守卫。
- D01 guard / charge / recover 显示缩甲、双臂蓄力、恢复待机，不发送伤害回调；archive_slam 实际命中一次。
- D00 tower_flame_first / tower_flame_second 使用每实例早犬火球呈现，不进入新犬火柱。两次各命中一次。
- 正式 NativeCombat=false 取消后无回调；两敌 hidden 经1秒淡出，visible重试恢复通过。
- 真正编队证据 output/stonehide-delivery-20260917/tower/passed.txt、roster-0.png、roster-1.png、tower_flame_first.png。尚非手机验收。

## 独立教会封堵场景

用户追加塔背景独立。实际检查改用 church-tower: 原生桥命令，入塔为 ChurchSealingWell 地下封堵场景，人物脚下有足够地面。BattleRain.SetWeatherVisible 在塔内停止雨丝/水滴/涟漪及更新；主线形成命令恢复 ClockPlaza 与雨。正式两编队全部检查重跑通过，断言入塔贴图区别及退塔恢复同一原贴图、雨开关状态。截图 tower/roster-0.png（无室内雨）和 tower/mainline-restored.png（广场雨恢复）。
