# B02 束缚命中爆发加强

用户反馈金纹束缚仍不够炸裂，并再次指定虹翼 extreme 的白金爆闪图作为冲击参考。本次按 game-spell-impact 的压缩、停顿、极速扩张、快速衰减重新制作 B02 命中段，保留上一版原画镂空纹路和持续旋转闪光。

- 真实 contact 仍为原战斗回调。视觉到接触点先收紧，局部动画停顿 166.667 ms，然后 45 ms 撑开；不暂停全局战斗时间。
- 金纹主体半径在释放瞬间由约0.52增至约1.87，束带宽度亦短促展开；回收后恢复普通束缚体积。网格仍为独立三维曲面，保留花纹与前后遮挡。
- 单目标白金亮芯与长短不一的金橙星芒爆开。新增实际 Effekseer BindingReleaseBurst：22条运动轨迹，每条亮碎片和短尾，45ms发射完成、寿命200～383ms、速度约7.2～14.76 world units/s、带重力。
- 持续状态不重复播放命中爆发；只保留旋转金纹与持续碎星。伤害、目标数、冷却、正式contact时序不变。

## 实录和验证

入口 `output/all-spells-polish-20260921/binding-impact.html`：新旧同步播放、近景/全景、半速及命中慢放。旧版视频由 `backups/binding-impact-20260921/` 提供，最新全览和 binding-authored 页同步指向加强版。

Unity实际网格采样 `binding-impact-timing.csv`：第19～23帧视觉时钟均0.65，共5帧；压缩宽度1.204531、释放峰值3.888513，约3.23倍宽。截图可能相对采样晚一个LateUpdate，因此保留第20～28帧连续画面用于对照。逐帧检查压缩、释放、飞散、回收，外圈纹理仍可辨认。

8项录制检查、17项定向安全检查通过。新增验证释放只触发一次、爆开期间取消清理碎光和亮芯、持续状态不伪命中；取消/重试真实回调与Effekseer句柄清零继续通过。参见 binding-impact-recording-passed.txt / binding-impact-safety-passed.txt。

两个MP4完整解码成功，清理可再生中间帧并保留命中连续关键帧。视觉待用户复核；未原生构建或安装手机。本次只修改B02，不据此宣称其它法术已验收。

## 文件

- Assets/Scripts/BindingRibbon20260921.cs：压缩/停顿/展开/回收。
- Assets/Scripts/BindingImpact20260921.cs、Resources/Shaders/BindingImpact20260921.shader：局部白金亮芯和不等长星芒。
- Assets/Scripts/BindingEffekseerAccent20260921.cs：释放锁存与取消清理。
- tools/vfx/build_binding_effekseer.py：三个有限时长 Effekseer 工程生成器。

以上 Assets 路径基于 UnityBattleSource。原源码、旧视频及回看页在 backups/binding-impact-20260921/。
