import Foundation

struct WorldRegion: Identifiable, Hashable {
    enum Kind: String, Hashable {
        case federation = "主题联邦"
        case divineRealm = "终局天域"
    }

    enum Access: Hashable {
        case current
        case preview
        case locked
        case final
    }

    let id: String
    let sequence: Int
    let name: String
    let capital: String
    let theme: String
    let conflict: String
    let kind: Kind
    let access: Access
}

enum TaskStage: String, CaseIterable, Identifiable {
    case soloLeadIn
    case expedition
    case soloAftermath

    var id: Self { self }

    var title: String {
        switch self {
        case .soloLeadIn: "个人引子"
        case .expedition: "临时远征"
        case .soloAftermath: "个人余波"
        }
    }

    var detail: String {
        switch self {
        case .soloLeadIn: "按你的路径获取入口与私密动机"
        case .expedition: "同城玩家随到随组，空位由潮汐化身补齐"
        case .soloAftermath: "回到个人时间线，承担只属于你的后果"
        }
    }

    var symbol: String {
        switch self {
        case .soloLeadIn: "person.fill"
        case .expedition: "person.3.fill"
        case .soloAftermath: "arrow.triangle.branch"
        }
    }
}

struct ExpeditionDefinition: Identifiable, Hashable {
    let id: String
    let title: String
    let city: String
    let estimatedMinutes: Int
    let objective: String
    let storyReason: String
}

struct ExpeditionMember: Identifiable, Hashable {
    let id: Pathway.ID
    let name: String
    let role: String
    let symbol: String
    let isLocalPlayer: Bool
}

extension GameContent {
    static let worldRoute: [WorldRegion] = [
        WorldRegion(
            id: "mistcape",
            sequence: 9,
            name: "雾岬自由联邦",
            capital: "雾岬港",
            theme: "秘密、潮汐与初次选择",
            conflict: "倒流的潮水正在交换居民的记忆。",
            kind: .federation,
            access: .current
        ),
        WorldRegion(
            id: "saltmirror",
            sequence: 8,
            name: "盐镜联邦",
            capital: "镜湾城",
            theme: "身份、倒影与替代者",
            conflict: "每个人都可能在镜中拥有一位更可信的自己。",
            kind: .federation,
            access: .preview
        ),
        WorldRegion(
            id: "coppercrown",
            sequence: 7,
            name: "铜冠联邦",
            capital: "铸雨城",
            theme: "工业、秩序与被制造的神迹",
            conflict: "永不停机的工厂开始生产无人订购的圣物。",
            kind: .federation,
            access: .locked
        ),
        WorldRegion(
            id: "emerald-isles",
            sequence: 6,
            name: "翡翠群岛联邦",
            capital: "树潮城",
            theme: "生命、共生与过度生长",
            conflict: "城市与森林正在争夺同一副呼吸器官。",
            kind: .federation,
            access: .locked
        ),
        WorldRegion(
            id: "ash-frontier",
            sequence: 5,
            name: "灰烬边疆联邦",
            capital: "余火城",
            theme: "战争、记忆与未熄的命令",
            conflict: "一场已经结束的战争每天黎明都会重新开始。",
            kind: .federation,
            access: .locked
        ),
        WorldRegion(
            id: "sleeping-sea",
            sequence: 4,
            name: "眠海联邦",
            capital: "梦港城",
            theme: "梦境、死亡与温柔遗忘",
            conflict: "死者的梦正在替活人决定醒来的时间。",
            kind: .federation,
            access: .locked
        ),
        WorldRegion(
            id: "wind-steles",
            sequence: 3,
            name: "风碑联邦",
            capital: "誓风城",
            theme: "历史、誓言与胜者叙事",
            conflict: "石碑每晚改写过去，白天则要求所有人宣誓相信。",
            kind: .federation,
            access: .locked
        ),
        WorldRegion(
            id: "starbridge",
            sequence: 2,
            name: "星桥联邦",
            capital: "远星城",
            theme: "空间、知识与不可抵达之物",
            conflict: "星桥带回了知识，也带回了观察知识的目光。",
            kind: .federation,
            access: .locked
        ),
        WorldRegion(
            id: "dawn-ring",
            sequence: 1,
            name: "黎明环联邦",
            capital: "晨钟城",
            theme: "时间、权柄与最后的人性",
            conflict: "每一次钟响都删去一个从未成神的未来。",
            kind: .federation,
            access: .locked
        ),
        WorldRegion(
            id: "uncrowned",
            sequence: 0,
            name: "无冕天域",
            capital: "逆潮之源",
            theme: "权柄、人性与选择",
            conflict: "六条道路必须共同封闭源头，再各自决定是否接受神座。",
            kind: .divineRealm,
            access: .final
        )
    ]

    static func expeditionMembers(for selectedPath: Pathway?) -> [ExpeditionMember] {
        let localID = selectedPath?.id ?? .fool
        let localPath = pathways.first { $0.id == localID }
        let ordered = [localPath].compactMap { $0 } + pathways.filter { $0.id != localID }

        return ordered.map { path in
            ExpeditionMember(
                id: path.id,
                name: path.name,
                role: path.teamRole,
                symbol: path.symbol,
                isLocalPlayer: path.id == localID
            )
        }
    }
}
