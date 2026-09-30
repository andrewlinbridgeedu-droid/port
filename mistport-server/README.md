# 雾港共享服 · M0 技术小样

规划书 M0 要求的“服务端技术小样”：一笔共享交易和一场关键战的服务端校验能跑通。这是一个权威服务加一个 SQLite 事务库，战斗由服务器用规则库复算。**这是技术验证，不是上线服务**：没有正式登录、TLS、限流、备份演练和压测，经济数值全是候选。记录与局限见 [`docs/development/shared-server-m0-20260929/`](../docs/development/shared-server-m0-20260929/README.md)。

## 运行

```sh
swift build
swift test                     # 账本 14 项 + HTTP 端到端 2 项
MISTPORT_DB=./dev.sqlite MISTPORT_PORT=8080 MISTPORT_ADMIN_TOKEN=<至少16位> swift run mistport-server
```

- Swift 6.0 可编译（Linux 已验证）；Hummingbird 固定在 2.17，这是最后一个 Swift 6.0 能编译的版本。
- Linux 需要 `libsqlite3-dev`，macOS 用系统自带的 SQLite。
- 依赖本仓库的 `mistport-ios/MistportCombatCore`，战斗规则和 App 是同一份代码。
- 选型（2026-09-30 定）：M2 小服用这套 Swift＋SQLite 单权威服务。
  - 部署在一台 Linux 服务器上，前面用 Caddy 做 TLS。
  - 用 Litestream 把 SQLite 持续备份到对象存储。
  - 扩到 2,000 注册前做 200 人同时在线压测；不过线再换 PostgreSQL。

## 组成

| 目标 | 内容 |
|---|---|
| `MistportLedger` | 账本：账户、铜的发行/转账/销毁、物品批次与来源、挂单托管与成交、操作回执、战斗票据、本地财富带入、审计 |
| `MistportServer` | HTTP 接口（Hummingbird），只把请求交给账本 |
| `mistport-server` | 可执行文件，读环境变量 `MISTPORT_DB`、`MISTPORT_HOST`、`MISTPORT_PORT`、`MISTPORT_ADMIN_TOKEN` |

## 账本规则

- **铜**：每次变动记一行账。`issue` 按来源发行（`genesis:city-budget`、`local-import`），`burn` 销毁（可配置交易费销毁），其余都是 `transfer`。货币总量恒等于发行减销毁，审计按账重算每个账户。
- **物品**：每件东西属于一个批次，记录来源（`tower-drop` 带票据号、`test-grant`）。交易只移动数量，批次和来源跟着走。
- **操作回执**：每个写请求带客户端生成的 `op`。同一个 `op`、同样内容，返回存下的结果，失败也一样；同一个 `op`、不同内容，拒绝（`operationConflict`）。一次请求是一个 `BEGIN IMMEDIATE` 事务，多个进程共用一个库时也由 SQLite 串行。
- **市场**：挂单时货进托管；买入时，买方的铜、卖方的铜、交易费和货在同一事务里交换，交易费从卖方所得里扣。多人抢最后一件时只有一笔成功（测试：8 个连接、40 个买家）。
- **战斗**：
  - 开票：先检查资格（塔层不能越级；亮灯公共目标每个账号一次），再从城市预算预留奖励，并把带进战斗的药放进票据托管。预算不够就不开战，不会打赢后才发现付不出。
  - 结算：服务器用自己保存的角色配装和 `MPCChurchBattleDriver` 复算客户端提交的操作记录。确认打赢，才付奖励（塔层还会掉材料）；打输或记录非法，奖励退回城市预算。用掉的药销毁，没用的退回。每张票只结算一次。
  - 过期：票据超过 30 分钟未结算自动关闭，奖励和药退回。
- **本地财富带入**（用户 2026-09-29 定带入，2026-09-30 定折算）：
  - 最多计 12,000 本地铜，按 15% 折成共享铜（最多 1,800），和共享服每日玩法按单机 15% 付的比例一致。
  - 每个账号一次；同一份存档指纹只能带一次。
  - 存档指纹由客户端提供，服务器无法验证真伪，这个风险用户已接受。

## HTTP 接口（v0）

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/health` | 服务与战斗规则版本 |
| POST | `/v0/accounts` | 建账号，返回 `accountID` 和 `token`（只给一次） |
| GET | `/v0/me` | 自己的铜、物品和角色 |
| POST | `/v0/import` | `{op, fingerprint, copper}` 本地财富带入，回执含计入的本地铜和发出的共享铜 |
| GET | `/v0/market?item=` | 公开挂单 |
| POST | `/v0/market/listings` | `{op, item, quantity, unitPrice}` 挂单 |
| POST | `/v0/market/listings/:id/buy` | `{op, quantity}` 买入 |
| POST | `/v0/market/listings/:id/cancel` | `{op}` 撤单 |
| POST | `/v0/battles` | `{op, battle: {kind: "tower"/"lights-public", floor, side, consumables}}` 开票 |
| POST | `/v0/battles/:id/settle` | `{op, log}` 提交操作记录结算 |
| GET | `/v0/events/lights` | 亮灯事件两派公共贡献 |
| GET | `/v0/admin/audit` | 审计（需 `X-Admin-Token`） |
| POST | `/v0/admin/characters/:account` | 设服务器角色层数（测试／运维工具，不是玩家操作） |
| POST | `/v0/admin/grants` | 发测试物品，来源记为 `test-grant` |

玩家请求带 `Authorization: Bearer <token>`。错误返回 `{"error": "<代码>"}`：未登录 401，找不到 404，请求不对 400，业务冲突（余额不足、已售完、已尝试等）409。
