# 秘仪：雾港升序

单主角实时战斗 RPG。Swift 负责规则与结算，Unity 负责战斗表现。

- [第一章当前规划](mistport-ios/docs/game-design/chapter-one-30/README.md)
- [工程运行与构建](mistport-ios/README.md)
- [文档阅读顺序](DOCUMENTATION_GUIDE.md)
- [项目结构](PROJECT_STRUCTURE.md)

## 获取资源

本仓库用 Git LFS 管理模型、贴图、音频等大文件。克隆前安装 Git LFS，克隆后运行 `git lfs pull`。Unity 工程位于 `UnityBattleSource/`；iOS 工程位于 `mistport-ios/`，Unity iOS 导出需在本机重新生成。

提交范围包含当前源码、规划、生产脚本和本机可用素材。玩家存档、密钥、签名包、构建缓存、临时输出、回滚备份和外置 SSD 的机器专用符号链接不入库。历史文档中指向 `output/`、`backups/` 或未入库源素材的链接只用于原开发机溯源，不保证克隆后可用。当前运行资产以 Unity Assets 和 iOS Asset Catalog 为准。

构建/安装证据不等于完整真机视觉验收；最新实施边界见当前规划及开发记录。
