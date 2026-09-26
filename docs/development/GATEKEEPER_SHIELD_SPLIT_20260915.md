# 门卫防御盾与螺旋分离

用户明确确认：用生成的圆盾替换截图红框里的蓝色线框，攻击螺旋单独重做。

ArchiveEncounterPresentation的guard阶段改用ArchiveAegisV2原画，半透明0.65、尺寸3.35，独立悬浮于门卫前方1.25世界单位并轻微摆动。破绽与退出时清理。删除攻击过程对该原画的绘制/加载。

攻击飞行阶段改为3股宽尾尖头螺旋（外蓝光、蓝色主体、白色亮芯），沿真实飞臂位置推进，轴心附一道能量矛。没有修改伤害、时序或真实接触回调。

Unity独立运行passed.txt及截图位于output/gatekeeper-split-vfx-20260915。guard与impact截图已检查：防御盾正确可见，命中不显示盾。三个攻击回调与取消/失活检查通过，非真机连续通关。备份backups/gatekeeper-split-vfx-20260915。

用户追加明确盾不可贴身，改为沿门卫至相机的地面方向前移1.25世界单位；最终运行证据在output/gatekeeper-split-vfx-20260915/forward，重测通过。

Build33构建成功、安装启动iPhone13，安装前后Preferences一致。手机观感待用户复核。
