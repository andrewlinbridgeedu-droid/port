import Foundation
import MistportCombatCore

enum HousingPower {
    struct Row: Codable {
        let mission:Int, profile:String, floor:Int, restPercent:Int, extraHP:Int
        let won:Bool, hpPercent:Int, medicines:Int, seconds:Double
    }
    static func run(_ url:URL) throws {
        var rows:[Row]=[]
        for (q,floor) in [(18,50),(22,70),(26,70),(30,90)] {
            var gear=MPCChurchGearLedger()
            for f in 1...floor { if let item=MPCChurchGearCatalog.towerDrop(floor:f) { gear.grant(item.id) } }
            let bounty=MPCProgressionWalls.wall(mission:q)?.caseID.flatMap { MPCBountyRelicCatalog.relic(forCase:$0)?.id }
            for profile in Profile.all {
                for percent in [0,3,5] {
                    var l=loadout(mission:q,gear:gear.stats,passive:"relic_salt_sealed_breathing_bag",sequence:cards(forMission:q)[0],bountyRelic:bounty)
                    let hp=(1000+l.churchGear.maxHP)*percent/100;l.churchGear.maxHP+=hp
                    let r=try ChapterDriver.run(q:q,sequence:cards(forMission:q)[0],mask:true,consumables:["consumable_pain_salve":1],priorityCore:profile.priorityCore,ultimate:true,loadout:l,medalOffset:6,precise:true,actionDelay:profile.actionDelay)
                    rows.append(.init(mission:q,profile:profile.name,floor:floor,restPercent:percent,extraHP:hp,won:r.session.outcome == .victory,hpPercent:r.session.playerHP*100/max(1,r.session.playerMaxHP),medicines:r.medicinesUsed,seconds:r.seconds))
                }
            }
        }
        let e=JSONEncoder();e.outputFormatting=[.prettyPrinted,.sortedKeys];try e.encode(rows).write(to:url)
        print("Housing fixed-loadout probes: \(rows.count)")
    }
}
