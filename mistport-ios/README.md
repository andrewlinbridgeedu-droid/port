# 秘仪：雾港升序 iOS

当前第一章为单主角实时战斗，Swift 负责规则与结算、Unity 负责战斗表现。主线 Q1–30、教会塔一百层（正式 D01–D11）和 B01–B10 通缉的设计及实施边界见[当前总规划](docs/game-design/chapter-one-30/README.md)。[四项审查](docs/game-design/chapter-one-30/CHAPTER1_REVIEW_AND_PLAN_20260925.md)列出尚未完成的真机、成长与经济验收。旧 v0.5 三人回合制材料在[`docs/legacy/game-design-v0.5/`](docs/legacy/game-design-v0.5/README.md)，不再作为当前规则。

## 构建与验证

用 Xcode 打开 `Mistport.xcodeproj`，选择 `Mistport` scheme 和已配置签名的 iPhone。命令行无签名设备编译：

```bash
xcodebuild -project Mistport.xcodeproj -scheme Mistport -sdk iphoneos -configuration Debug CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

战斗核心测试在 `MistportCombatCore/` 执行 `swift test`。改动 `UnityBattleSource/` 的运行资源后，先运行仓库根目录 `scripts/check_unity_export_freshness.sh`，再构建宿主；生成的 `UnityBuild/` 不手改。安装或启动成功不代表逐关或法术视觉通过，需按交付记录逐项核对。真机测试必须隔离夹具并核查玩家 Preferences。

工程导航见[项目结构](../PROJECT_STRUCTURE.md)、[文档权威](../DOCUMENTATION_GUIDE.md)、[美术规则](../ART_ASSET_GUIDE.md)与[3D 敌人接入](ENEMY_3D_PIPELINE.md)。
