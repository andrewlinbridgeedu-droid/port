import Foundation

/// Street fights of the daily loop (city events, nameless remnant cases, neighbour
/// errands). Like the lights public target they reuse authored tower bodies under
/// `church_maintenance_` encounter IDs and `~maintenance-` enemy IDs, so Unity
/// presentation, music and identity follow the shipped church path. No scaling:
/// each fight names the tower band its bodies come from.
public enum MPCStreetEncounters {
    public typealias Species = MPCChurchTowerCatalog.Species

    static func validTicket(_ id: String) -> Bool { MPCChurchMaintenanceCatalog.validJobID(id) }

    private static let authoredBodies: [(floor: Int, species: Species, id: String)] = MPCChurchTowerCatalog.floors.flatMap { floor in
        floor.waves.indices.flatMap { w in floor.waves[w].indices.map { (floor.number, floor.waves[w][$0].species, floor.enemyID(wave: w, slot: $0)) } }
    }

    /// The last authored body of this species at or below `floor`, so the fight weighs
    /// like that band of the tower; the species' first body if it appears only later.
    static func body(_ species: Species, atOrBelow floor: Int) -> String {
        authoredBodies.last { $0.floor <= floor && $0.species == species }?.id
            ?? authoredBodies.first { $0.species == species }!.id
    }

    static func content(id: String, name: String, tag: String, waves: [[Species]], floor: Int) -> MPCEncounterContent {
        .init(id: id, name: name, investigationID: "church_maintenance",
              waves: waves.enumerated().map { w, species in
                  MPCEncounterWave(enemyIDs: species.enumerated().map { p, s in body(s, atOrBelow: floor) + "~maintenance-\(tag)-w\(w)-p\(p)" })
              },
              companionSlots: 0, fixedRewardItemIDs: [], firstClearRelicID: nil, recommendedTags: ["church_maintenance", "street_" + tag])
    }

    /// `prefix + key + "_" + ticket`; keys never contain underscores.
    static func parse(_ id: String, prefix: String) -> (key: String, ticket: String)? {
        guard id.hasPrefix(prefix) else { return nil }
        let rest = id.dropFirst(prefix.count).split(separator: "_", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
        guard rest.count == 2, !rest[0].isEmpty, validTicket(rest[1]) else { return nil }
        return (rest[0], rest[1])
    }

    public static func encounter(id: String) -> MPCEncounterContent? {
        MPCCityEventCatalog.encounter(id: id) ?? MPCRemnantCatalog.encounter(id: id) ?? MPCNeighborCatalog.encounter(id: id)
            ?? MPCStreetTaskCatalog.streetEncounter(id: id)
    }
}
