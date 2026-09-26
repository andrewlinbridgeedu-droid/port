# D02 盐囊恶魔 · Rodin / Effekseer 样板

用户批准先做一只，选择D02。仅D02表现修改，原角色、伤害、冷却、毒预算、站位和存档未改，D04方向保留。

## 制作

Rodin网页（computer use，无API）任务 https://hyper3d.ai/workspace/rodin/6ab5a1ba-2539-4b92-9958-7fb530810ae3 。首张双头长矛参考弃用，改无握柄矿物獠刺。确认几何与材质，网页下载41.7MB ZIP；原始PBR/Shaded GLB及SHA回执在 ArtSource/SaltmawSpell20260919。用户批准现有44.5 credits内，不充值；按钮分别显示几何确认0.5、材质0.5费用提示，余额未刷新核对，不能把提示当实际扣费回执。

Blender源50万三角→4999三角；主轴校正、尖端朝向、材质和可编辑blend/FBX保留。近景preview.png检查通过，但矿物细节仍偏骨牙，不称最终美术通过。

Unity独立SaltmawSpell20260919控制胸/颈/头/双臂及盐囊缩放：聚能、前倾吐息、释放盐晶刺与回弹。原0.65秒接触及1.25秒生命周期保持。Effekseer三工程Gather/CorrosiveMist/CrystalImpact从既有工程结构派生，纹理出处SHA见资源目录PROVENANCE.json。不是简单声称使用Effekseer：已生成实际.asset并由EffekseerSystem播放/停止。

## 迭代与验证

- 第一轮白烟过大遮挡，拒绝；第二轮发现飞行缩放覆盖FBX单位比例导致实体过小，修复为外层飞行节点。
- 最终Unity两招单次contact；胸颈活动约21.24/18.60度，根位置无漂移。
- 两个取消时刻无晚回调；隐藏/死亡取消、重试再次单次命中、所有Saltmaw组件停止清理通过。
- Effekseer句柄由实例拥有，Restore/OnDisable立即Stop；不依赖粒子自然消散跨战残留。
- 首次UPM连接失败，noUpm尝试缺UI程序集，恢复普通UPM后编译/导入及最终运行成功；不是修改战斗源码去规避依赖。
- 最终日志 /tmp/saltmaw-review-final-20260919.log；回执output/saltmaw-sample-20260919/passed.txt。
- 720×1280/30fps两段实际Unity渲染，分别2.8秒含0.8秒起手及释放/收势。非真机录像，未原生构建或安装，视觉与真机性能待用户复核。

备份 backups/saltmaw-sample-20260919。完整原资产保留，前两轮拒绝画面在输出目录下保留。

## 用户否定首版后的动作/光彩修订

用户指出动作单调、武器发白无光彩。保留Rodin源，新增SaltmawRadiance20260919：12股青绿/青蓝/暖金光带、随飞行旋转的实体和局部动态光、接触后展开消散；Effekseer腐雾与碎晶继续保留。骨骼新增骨盆与前臂，胸腰拧转/双臂开合/颈头前送、两招左右侧身幅度区分；原伤害时钟不改。首轮绿光过曝已降低实体自发光与动态灯，实体改细长比例避免白色大片。参考项目已保存VFXQualityReference20260913/user-reference-4.jpg，不声称确认为用户本次所指的唯一图片。原版备份backups/saltmaw-radiance-20260919。

第二版最终Unity回调/取消/死亡/重试/清理复测通过，日志/tmp/saltmaw-radiance-final.log。视频poison-v2.mp4、salt-spike-v2.mp4；未原生构建或安装，视觉仍待用户判断。

## 第三版：用户要求再绚丽20倍

按强烈增强的艺术方向实施，不把“20倍”虚报为客观量化结果。新增72条碎晶光迹、24条有尖端和疏密变化的青蓝/绿/金流光、扩大命中外扩及延长余辉。首轮48条密环遮挡实体，实拍后改为较少但更宽的主带与细辅带、短曲率和渐细端点，保留盐刺可见性。原骨骼动作、伤害、0.65秒接触、1.25秒生命周期不变。

已查看Unity聚能、飞行及两招命中帧；单次命中、取消无迟到伤害、死亡中断、重试与清理全部通过，日志 /tmp/saltmaw-spectacle-final.log。输出 output/saltmaw-spectacle-20260919/index.html，两段30fps实际运行视频。备份 backups/saltmaw-spectacle-20260919，前版视频保留。未原生构建/安装，不能称为用户视觉验收或手机性能通过；本轮未消耗Rodin积分。

## 第四版：不规则炸裂
用户认可略有提升但否定规则圆环，要求炸裂开。去掉光带的三角函数绕圈轨迹，改为确定性散布方向、不等长渐细破碎光焰、错峰外抛碎晶；飞行阶段收束成尾焰，命中按不同速度与延迟向三维方向散射。保留三色、规模及原实体/骨骼/战斗时序。已检查起手/飞行/命中Unity帧，日志/tmp/saltmaw-burst-review.log中单次接触/取消/死亡/重试/清理均通过。输出output/saltmaw-burst-20260919/index.html，旧版与源码备份保留于backups/saltmaw-burst-20260919。视觉待用户复核，未安装手机，无Rodin消耗。

## 第五版：扩大、闪亮、裂开
用户认可第四版方向，要求面积更大、更闪、更裂。扩大不规则光焰长度与外抛速度、提高亮芯，碎晶72→108条；新增48条组成24组分叉裂光，命中按三个时差向外撕开。原规则、伤害和动作时序不变。已查看起手与两招命中渲染帧，爆发覆盖两侧，主角仍可见；不把内部截图检查当作用户视觉验收。Unity单次接触/取消/死亡/重试/清理通过，日志/tmp/saltmaw-fracture-review.log。动态输出output/saltmaw-fracture-20260919/index.html；备份backups/saltmaw-fracture-20260919。未原生构建或安装，手机性能未测，本轮无Rodin消耗。

## 第六版：少而大片
用户要求不要那么多、那么散，少一点大片一点。主体光焰24→9片，宽度改0.32/0.58；碎晶108→24，分叉裂光48→8，并降低外抛速度与裂光跨度。保留亮度、不规则炸裂及原战斗时序。已检查起手/命中Unity帧，单次接触/取消/死亡/重试/清理通过（/tmp/saltmaw-broad-review.log）。输出output/saltmaw-broad-20260919/index.html，备份backups/saltmaw-broad-20260919。视觉待用户复核，未安装手机。
