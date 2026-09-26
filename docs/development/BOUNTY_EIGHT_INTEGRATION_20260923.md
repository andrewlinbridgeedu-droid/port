# 第一章赏金八体接入（2026-09-23）

**后续视觉修正：** B01 剑刃权重与八体战场体型已按用户反馈重做，当前录像及 iPhone 构建为 build 61；本页下方的 build 60 装机记录是此前版本的历史事实。见 `docs/development/BOUNTY_WEAPON_SCALE_20260923.md` 和 `output/bounty-weapon-scale-20260923/index.html`。

本批按第一章三十关与教会塔开放表接入用户已提供的八个高模。B04、B06 的 Rodin 角色暂置，保留现有案件和战斗实现；不把那两个试作误称为正式模型。塔仍是已确认的 100 层分段开放：起始 1–10，Q10 后 11–30，Q13 后 31–50，Q16 后 51–70，Q20 后 71–100。本批未改塔的层数、怪物与奖励。

| 案号 | 正式战斗模型 | 解锁 | 作恶与战斗身份 |
| --- | --- | ---: | --- |
| B01 | Iron Inquisitor | Q7 | 非法执行两人；缺齿剑斩 |
| B02 | Clockwork Butcher | Q14 | 外锁背架掳走活人；束带伤害 |
| B03 | Azure Anchorlord | Q23 | 逆钟劫船；残影护航、水刃与重浪 |
| B05 | Crimson Seamstress | Q27 | 借量衣单诱捕活人；赤丝剪击与勒束 |
| B07 | Azure Belltoad | Q5 | 复制求救声骗开门；三叩冲击与有限毒沫 |
| B08 | Masquerade Duelist | Q11 | 盗脸签收赃物；可击散伪影与真身短刺 |
| B09 | Copperback Guardian 彩绘版 | Q17 | 吞毁清偿凭据；可击破铜甲与撕裂 |
| B10 | Crimson Moon Empress | Q26 | 伪造疗契转嫁寿数；绯帷伤害与囊体转息 |

高模原件与 SHA 保留在 `ArtSource/BountyIntake20260922`，B09 彩绘原版保留在 `ArtSource/CopperbackBounty20260922/textured-v1`。`ArtSource/BountyCombat20260923` 存放可编辑 Blender、FBX、贴图和构建脚本；八体分别降到约 5 万三角面，创建区域权重骨架和八段基础动作。B10 囊体是独立辅助模型与纹理，不冒充第九个用户提供的资产。Unity 的 `Resources/Enemies/Signature/BountyBXX` 下有独立 Prefab、PBR 材质、动画控制器与 VisualProfile，正式战斗按稳定敌人 ID 路由，B04/B06 沿用旧模型路由。

十案都保留五个独立调查节点、辨误选项、核验后战斗和一次性结案。新增四案的战斗规则与外形互相对应：B07 的毒沫是有限跳伤且施术者死亡即清理，青绿毒状态与 B02 金色束缚分流；B08 两个伪影能单独击散，真身不会因此结案；B09 铜甲是普通可击破护盾；B10 收寿囊体最多三次转息，可先击破，相关遗落物可按已有契约截流。十案合计 1060 铜币、222 功勋；旧六案的稳定 ID 与旧奖励维持原值。教会大厅的悬赏卷宗可滚动查看十案，未达对应主线节点仍锁定。

运行证据：`output/bounty-eight-20260923/index.html` 中 15 组、30 段真实 Unity 全景/近景 MP4；`record-all-passed.txt` 的 63 项录制检查与 `safety-all-passed.txt` 的 212 项取消、死亡退场、跨波与重试检查通过。B10 囊体的第一版过大且过于简单，逐帧复看后改成分瓣、铜箍、转息管和五区贴图，重新录制 `record-b10-final` 与转息确认 `record-b10-heal-final`；旧第一版不作当前视觉依据。B02 原金纹主带形成近乎完整圆圈，按已确认的形状禁令改成左右两条不闭合的错层纹带，另录 `record-b02-open-final2`。Swift 十案卷宗三项测试和赏金战斗八项测试通过，十案均有无手动假面胜利路径。

这些证据证明资源导入、代码路径、命中时序和清理，不代表用户已认可视觉。B01/B02 原件仍偏脏暗、B09 细封签和侧甲仍需视觉精修；骨架权重是区域近似，细节变形需要真机近景再评审。iPhone 实际帧率与连续通关须另测，不能由 Unity 编辑器录像推断。

## iPhone 构建与安装

最终 B02 开口金纹版本已随 Unity 自动导出进入 iOS 工程，Xcode `Debug-iphoneos` 签名构建成功（`output/bounty-eight-20260923/xcodebuild-device-final.log`）。本地 `codesign --verify --deep --strict` 通过；安装包为 `com.yourcompany.mistport`，构建号 60。2026-09-23 已用 `devicectl` 覆盖安装到配对的 iPhone 13，设备应用列表也确认版本 `0.1.0 (60)`，记录在 `device-install.log`、`device-install.json`、`device-app-info.json`。

首次启动被 iOS 以 `Security` 拒绝（`device-launch.log`）；同一个安装包稍后重试启动成功（`device-launch-retry.log`），设备进程列表确认 `Mistport.app/Mistport` 仍在运行，PID 18320（`device-process.json`）。未更换签名或重新安装；不能由首次拒绝断言具体原因。设备开发者模式已开启，描述文件有效至 2026-09-30 且含本机 UDID，包的本地签名验证通过。真机上已确认安装、启动及进程保持；手机帧率、画面与十案连续通关尚未逐项实测。保留现有应用数据；未卸载或清除存档。
