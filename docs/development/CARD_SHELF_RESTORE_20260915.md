# Build20卡牌消失回退修复

用户在真机反馈开战后卡牌不见。直接原因是本批新增combatIsActive条件过滤持有手牌，已撤回；下方收藏手牌始终可见，是否编排不再决定存在性。

另发现重建视图时已处于battle阶段不会触发battleIsActive.onChange，@State chosenLoopSkills原本固定[]。初始化改为：仅已处于battle且非holdpreview的视图从本次initialSession.loadout.normalSkillIDs读取；setup仍空，重试仍空，不自动装备/继承上一关。

保留Build20原生Button点击区域、战前详情入口、战中不抢手势、移除提示字和第四关55%两连火球。Build21，原生构建与安装结果待补。未把构建当作真机触摸验收。

Build21原生构建成功，已安装并启动iPhone13；日志在backups/card-shelf-restore-20260915。本次不重置存档、不自动选牌。手机实际卡牌显示/点击仍待用户复核。
