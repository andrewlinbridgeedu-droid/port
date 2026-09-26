# D02 盐晶刺编辑器精修

用户选定D02盐囊·盐晶刺，沿用少而大片、不规则炸裂、有光彩方向。本轮修改已接入Unity资源，未构建或安装手机，视觉待用户复核。

- Blender实时专用连接打开原模型，焊接重合点、添加细倒角及加权法线，保留UV。最终11653三角面；不能声称性能提升。原始工程保留，新工程在ArtSource/SaltmawEditorPolish20260920/SaltSpike-Polish.blend及同名FBX。
- 晶体材质改为偏青盐晶，飞行渐进旋转并增加中段切面亮度变化。没有改变命中时刻、伤害或技能规则。
- CrystalImpact.efkproj从22碎片改为三簇各3片，不对称散开并调整尺寸、寿命；可重现脚本refine_impact.py保留。九道宽光带、蓄力及毒雾工程保持。
- 原生Blender/Effekseer界面可读取，但点击/快捷键未产生有效操作。实际采用Blender专用连接，以及Effekseer可编辑XML加Unity官方插件导入编译；不是已验证的纯鼠标工作流。未调用Jev。

备份：backups/d02-editor-polish-20260920。真实运行前后逐帧、MP4、对比GIF与页面：output/d02-editor-polish-20260920/index.html。

SaltmawReview20260919新增--d02-output参数，分别录制前后版本。两轮均通过：两招各一次命中、胸颈动作可见、根节点无漂移、两个时点取消后无延迟伤害、死亡取消、重试一次命中及最终清理。证据为before.log/after.log及各自passed.txt。接触帧前后对照已检查，主光效保持，碎晶分布与实体旋转改变；没有将运行测试等同用户视觉验收。
