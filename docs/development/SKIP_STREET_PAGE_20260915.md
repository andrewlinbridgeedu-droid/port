# 删除街道中转页
用户截图指定空白街道页面（章节顶栏、全区地图、底部再次进入）。主线入口直接准备并进入下一未完成关卡；全通关后重访最后可用关卡。旧districtMap状态改为立即路由，不再渲染DistrictLocationMapView。对应mapEntry引导在主动进入时完成，不显示已不存在的按钮教学。城市测试入口仍保留。

备份 backups/skip-street-page-20260915。Build12，不重置存档。原地图源文件保留；真机交互尚需复核。

Build12构建通过，已安装并启动iPhone13；安装前后存档一致：True，测试入口：True。
