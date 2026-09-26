# 大招级命中演出 · Build54

用户要求在Build53上再炸裂100倍，按演出方向处理，不宣称字面量化100倍。

新增ChurchDetonation shader：两层错峰展开的锯齿火焰波前、破碎空隙、内侧流动亮脉、白热亮芯。5.3/4.2单位主体，第二层延迟75ms，盾颚贴地。已降低第一轮实拍过白部分，恢复各恶魔色彩。既有精细原画保留，命中前130ms收紧到70%，命中后撑开。

新增ChurchImpactLens20260917：仅渲染时投影矩阵短促偏移与1.8%推近，每次渲染后恢复；不改Camera Transform/战斗时间/伤害/实际站位。多个请求同帧取较强者，所有者销毁/停止请求后失效，禁用恢复。

14组实际Unity录制重新生成，命中帧逐步检查与持续效果停止清理通过，无编译/运行异常。未进行真机性能或主观视觉验收。追加仅两个shader面片，继承现有材质网格销毁。预览output/church-grotesque-20260917/index.html。

备份backups/church-cataclysm-20260917，未安装手机（上次可用设备版本Build52）。

Build54原生构建通过，签名验证通过，归档artifacts/releases/Build54/Mistport.app。未安装。
