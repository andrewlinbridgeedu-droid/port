# D04 剪肢恶魔完整演出

用户明确要求先做完一只怪的整个法术效果。本轮只重做 D04，其他恶魔不声称已改善。前版 Build58 的跨场彩色曲面被用户否定为雷同、像额外贴块，D04 不再调用该演出。

## 素材

通过用户登录的 Chrome Hyper3D 网页生成并下载，不使用 API。任务 https://hyper3d.ai/workspace/rodin/136d91b0-0666-4a5f-b6de-8b31edc765dc 。原始PBR/Shaded GLB 保存在 ArtSource/IronclawSpell20260918。网站生成物实际为弯刃形态，并非新怪物。Blender处理1,000,000→6,500三角面，保存可编辑blend、FBX及源贴图，Unity独立材质与prefab。

## 三个动作

- tower_cut_first：右侧刃臂预备，横向挥切后释放弧形镰刃。
- tower_cut_second：换左臂反手，反向弧线，斜切命中。
- tower_heavy_cut：双臂架起、胸身蓄势，两刃分路汇聚，交叉切裂。

使用实际Hand.L/R骨骼位置，LateUpdate先更新关节再算光源与发射位置；飞行起点在离手时锁定。保留刃缘原画纹理细节与实体刃、青绿/象牙色辅光，不再铺满整条路的彩色曲面。命中有短促光团、交剪切口、定向碎光与投影短震。持续蓄力跟随手部而非静态场景点。

所有演出由既有动作时钟驱动，伤害、冷却及单次命中仍归原规则：快剪0.35秒，重剪0.65秒。1.25秒演出生命周期。动作取消立即恢复骨骼、销毁视觉实例；原始模型及其他怪物未覆盖。

备份：backups/ironclaw-complete-20260918。
验证结果与原生构建状态在完成后追加；不能以Unity录制替代手机视觉验收。

## 运行交付

最终 Unity PlayMode：三动作各一次 contact；双臂绑定存在，最大旋转变化分别约68.5°、68.3°、64.2°；怪物根节点不漂移。两种中断时刻、死亡前取消、重试再命中、停止清理全部通过。验收器 IronclawReview20260918，日志 /tmp/ironclaw-delivery.log，回执 output/ironclaw-complete-20260918/passed.txt。

最终3段720×1280、30fps视频，每段2.8秒，包括0.8秒测试蓄力及出手/收势；连续视频8.4秒。逐帧检查实体刃可见、双臂聚能、飞行与命中。视频为Unity独立运行，不是手机实录，不代表用户已认可美术。

## 原生构建

Build60 原生 iOS Debug 构建成功（/tmp/ironclaw-build60.log），已归档 artifacts/releases/Build60/Mistport.app。codesign --verify --deep --strict 通过，CFBundleVersion=60。包含本次 D04 三招与此前主角紧凑动作；未安装手机，不代表真机或用户视觉验收。

- 2026-09-18 用户认可 D04 方向，要求仅增加光影和爆发感。本轮保留三招骨骼动作、飞刃与伤害时机；新增独立 IronclawRadiance 柔光/不规则细芒、双手动态灯光、出手短闪及冷暖命中辉光。Unity 三招、取消/死亡/重试检查通过；新视频 output/ironclaw-light-polish-20260918/index.html。此轮未重新构建原生或安装，Build60 不包含这次光影微调。备份 backups/ironclaw-light-polish-20260918。

- 2026-09-18 用户要求 D04 漫天法术：新增24条分层空中流光、96枚空中碎光和12簇噪声焰团，覆盖双方上方及侧翼，保留主飞刃与动作/命中时机；起手集聚、出手扩散、尾段消退，全部随原实例清理。最终 Unity 三招/取消/死亡/重试通过，视频 output/ironclaw-tempest-20260918/index.html。未原生构建/安装，视觉与手机性能待复核；备份 backups/ironclaw-tempest-20260918。
