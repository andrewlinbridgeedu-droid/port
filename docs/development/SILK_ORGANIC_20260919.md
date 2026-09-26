# B05 红绸撕流

## 增亮与快速炸开（最新）

本版单次命中、无运行异常、取消零迟到命中、组件清理及重试单次接触通过；日志随交付保存。最终MP4已独立解码检查。

用户要求更亮、炸开，保留当前纹理方向。增加同绸面的两层加色光照，维持原两股起手/三股爆裂数量；命中片从较紧尺寸快速外扩，初速从0.065提高到0.155并加入减速，尺寸先快速撑开再缓降，另有8帧不规则接触闪光。旧纹理和规则保持。查看起手/接触/展开实际Unity帧后输出独立 output/silk-radiance-20260919/index.html，备份 backups/silk-radiance-20260919。视觉仍由用户复核，未装机。

最新反馈明确否定红环与银剪的规则几何。因此覆盖此前“图2达标所以恢复”的误判，本轮彻底移除 B05 Build 的弧环/白色晶锥；没有保留同路径的隐藏几何。

使用内置 imagegen 制作独立 CrimsonSilk.png 原画，归档 ArtSource/BountySilk20260919。可编辑 Effekseer 工程 SilkTravel / SilkRupture 分别负责接近与命中：两条不同尺度角度的绸流跟随真实 source→target，真实 contact 到达时停止飞行效果，三个不同方向的绸片短促扩散后渐隐。生成脚本 tools/vfx/build_silk_organic.py；旧 build_bounty_effekseer.py 不再覆盖 SilkRupture。

取消后零迟到命中、效果根节点清理、重试恰好一次接触通过。日志 silk-organic.log 与 silk-organic-safety.log 已复制到交付目录；从最终 MP4 独立解码 verified-start.png 核对实际交付内容。

已查看实际 Unity 起手、命中、尾段：无环、尖锥、平行硬片；主体可见细纤维与褶皱，留有间隙。输出 output/silk-organic-20260919/index.html，以全新页面和视频文件避免旧页残留。单次命中及运行无异常通过；最终用户视觉验收仍未获得，不以录制或构建替代。未原生构建/安装手机，其它敌方效果及规则不改。
