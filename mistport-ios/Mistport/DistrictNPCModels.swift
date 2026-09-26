import CoreGraphics
import UIKit

struct DistrictNPCDefinition: Identifiable {
    let id: String
    let name: String
    let title: String
    let areaID: String
    let position: CGPoint
    let tint: UIColor
    let sigil: String
    let artName: String
    let portraitArtName: String
    let dialogue: String
}

extension GameContent {
    static let oldClockNPCs: [DistrictNPCDefinition] = [
        DistrictNPCDefinition(
            id: "mara-grey",
            name: "玛拉·格雷",
            title: "守钟人 · 主线引导",
            areaID: "clock-square",
            position: CGPoint(x: 12_640, y: 12_600),
            tint: .systemPurple,
            sigil: "M",
            artName: "NPCMaraGrey",
            portraitArtName: "PortraitMaraGrey",
            dialogue: "归一档案今晚已经校正过十二次。\n听见第十三次校正以后，不要相信任何声称记得你的人——\n包括我。"
        ),
        DistrictNPCDefinition(
            id: "odelle-finn",
            name: "奥黛尔·芬",
            title: "记忆医生 · 恢复与抗侵蚀",
            areaID: "clock-square",
            position: CGPoint(x: 13_120, y: 12_600),
            tint: .systemTeal,
            sigil: "O",
            artName: "NPCOdelleFinn",
            portraitArtName: "PortraitOdelleFinn",
            dialogue: "记忆会缺失，人仍可以继续选择。我要保护的是下一段人生，不是一份完美档案。"
        ),
        DistrictNPCDefinition(
            id: "number-thirteen",
            name: "十三号",
            title: "受损机械犬 · 搜寻助手",
            areaID: "clock-square",
            position: CGPoint(x: 12_480, y: 12_880),
            tint: .systemCyan,
            sigil: "13",
            artName: "NPCNumberThirteen",
            portraitArtName: "PortraitNumberThirteen",
            dialogue: "咔……识别：友方。嗅迹记录指向镜潮宅邸，但最后三分钟被人为封锁。"
        ),
        DistrictNPCDefinition(
            id: "norn-kade",
            name: "诺恩·凯德",
            title: "雾灯巡官 · 悬赏与公共事件",
            areaID: "foglamp-street",
            position: CGPoint(x: 7_520, y: 12_800),
            tint: .systemIndigo,
            sigil: "N",
            artName: "NPCNornKade",
            portraitArtName: "PortraitNornKade",
            dialogue: "雾灯一盏接一盏熄灭。恢复巡线，我就能把你送到任何已点亮的街口。"
        ),
        DistrictNPCDefinition(
            id: "eli-white-sparrow",
            name: "伊莱“白雀”",
            title: "街区信使 · 隐藏路线",
            areaID: "foglamp-street",
            position: CGPoint(x: 8_640, y: 14_336),
            tint: .systemYellow,
            sigil: "E",
            artName: "NPCEliWhiteSparrow",
            portraitArtName: "PortraitEliWhiteSparrow",
            dialogue: "正路给巡警和怪物走，屋顶才属于聪明人。先说好，我的情报从来不免费。"
        ),
        DistrictNPCDefinition(
            id: "vera-copperbranch",
            name: "维拉·铜枝",
            title: "机械医生 · 武装改造",
            areaID: "gear-works",
            position: CGPoint(x: 19_840, y: 12_800),
            tint: .systemOrange,
            sigil: "V",
            artName: "NPCVeraCopperbranch",
            portraitArtName: "PortraitVeraCopperbranch",
            dialogue: "猎犬不是生来吃人的。我造它们去废墟里找活人——现在我要亲手修正这个错误。"
        ),
        DistrictNPCDefinition(
            id: "seravian-lo",
            name: "瑟维安·洛",
            title: "镜潮宅邸主人 · 区域首领",
            areaID: "mirror-manor",
            position: CGPoint(x: 20_800, y: 22_016),
            tint: .systemPink,
            sigil: "S",
            artName: "NPCSeravianLo",
            portraitArtName: "PortraitSeravianLo",
            dialogue: "肉体会腐烂，记忆却可以校准、复制、永远运转。你真愿意让整座城消失吗？"
        )
    ]
}
