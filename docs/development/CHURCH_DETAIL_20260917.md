# 法术繁复细节 · Build55

用户纠正：需要内部繁复细节与层次，不是反复增大增亮外圈。

保留六张认可原画，新增ChurchLivingSurface内部流动脉络：由原纹理/透明度约束的细脉与能量波，随时间运动。新增ChurchSpellFragments批处理84片材质碎片，每招额外单一网格/材质；四批错开55ms，独立尺寸、转速、退场。材质取自本物种法术原画：盾颚喷出下坠、毒囊重力滴落、剪肢/骨爪细长翻转、蛇冠/辅助法术旋绕。边缘由shader剪成不规则尖片/液滴，避免方形贴片。第一轮大方片已拒绝并改小细化后重录。

原外侧宽弧/卷焰透明度降低，让内部细节可见；伤害回调/冷却不改。不是新增84个GameObject/DrawCall。所有网格材质随施法对象销毁。

证据：14组Unity实录重新生成，逐帧查看盾颚/剪肢/毒囊爆发后细节；持续效果停止清理通过，编译/运行无异常。没有声称所有主观视觉标准已验收；尚未手机测试。预览output/church-grotesque-20260917/index.html。

备份backups/church-detail-20260917。新增源码：ChurchSpellFragments20260917.cs、ChurchLivingSurface.shader、ChurchFragments.shader。

Build55原生构建及签名验证通过，归档artifacts/releases/Build55/Mistport.app，未安装手机。
