// Check the player-painted road graph and every generated citywide itinerary.
// The inherited walkable-area mask mislabels water/roofs, so the reviewed
// painted centerline and its exact graph edges are the movement authority.
import fs from 'node:fs';

const root = new URL('../../mistport-ios/Mistport/', import.meta.url);
const catalog = JSON.parse(fs.readFileSync(new URL('WisteriaMap/harbor-pedestrians.json', root), 'utf8'));
const roads = JSON.parse(fs.readFileSync(new URL('WisteriaMap/navigation.json', root), 'utf8'));
const swift = fs.readFileSync(new URL('BountyCityInvestigationView.swift', root), 'utf8');
const assets = new URL('Assets.xcassets/', root);
const failures = [];
const hash = point => point.join(',');
const edge = (a, b) => [hash(a), hash(b)].sort().join('|');
const approved = new Set(roads.edges.map(([a, b]) => edge(roads.nodes[a], roads.nodes[b])));
const distance = (a, b) => Math.hypot(a[0] - b[0], a[1] - b[1]);

if (roads.nodes.length < 100 || roads.edges.length < 100)
  failures.push('The corrected citywide road network is missing');
if (!Array.isArray(roads.source) ||
    !roads.source.includes('ArtSource/HarborCityRoutes20260925/user-road-markup.png') ||
    !roads.source.includes('ArtSource/HarborCityRoutes20260925/user-blue-alley-markup.png'))
  failures.push('The road network has lost the player-markup provenance');
const towerFacadeCrossings = roads.edges.filter(([a, b]) => {
  const x = (roads.nodes[a][0] + roads.nodes[b][0]) / 2;
  const y = (roads.nodes[a][1] + roads.nodes[b][1]) / 2;
  return x >= 1180 && x <= 1420 && y >= 715 && y <= 755;
});
if (towerFacadeCrossings.length) failures.push('A road still crosses the clock-tower facade');
const blueNodes = roads.nodes.filter(([x, y]) => x < 940 && y >= 410 && y <= 870);
if (!blueNodes.some(([x, y]) => x < 80 && y < 650) ||
    !blueNodes.some(([x, y]) => x > 900 && y < 720) ||
    !blueNodes.some(([x, y]) => x > 550 && y > 840))
  failures.push('The three player-painted narrow alleys have not been joined to the city');
if (!swift.includes('HarborAlleyVisibility.isHidden(pose.point)'))
  failures.push('Pedestrians can still appear on the foreground alley roofs');
if (roads.spawn !== 0 || distance(roads.nodes[0], [325, 1005]) > 75)
  failures.push('The 3D map preview has lost its original home spawn');
if (!Number.isInteger(roads.tourNode) || roads.tourNode < 0 || roads.tourNode >= roads.nodes.length)
  failures.push('The 3D map preview tour destination was not remapped');
for (const npc of roads.npcs) {
  if (!Number.isInteger(npc.node) || npc.node < 0 || npc.node >= roads.nodes.length)
    failures.push(`${npc.name}: 3D preview node is invalid`);
}
if (!swift.includes('HarborRoadNetwork.current.nodes') || !swift.includes('HarborRoadNetwork.current.edges'))
  failures.push('Bounty investigation still uses the rejected fountain-crossing road graph');
if (!swift.includes('HarborPedestrianCatalog.current.citizens'))
  failures.push('Harbor city is not rendering the full roaming citizen roster');
if (swift.split('struct HarborCityExplorationView: View {')[1]
    ?.split('private enum HarborPlace:')[0].includes('private var actorMarker: some View'))
  failures.push('Harbor city still renders the protagonist');

const seen = new Set();
for (const citizen of catalog.citizens) {
  if (seen.has(citizen.id)) failures.push(`${citizen.id}: duplicate ID`);
  seen.add(citizen.id);
  const file = new URL(`${citizen.atlasName}.imageset/art.png`, assets);
  if (!fs.existsSync(file)) failures.push(`${citizen.id}: missing walk atlas ${citizen.atlasName}`);
  if (!citizen.name || !citizen.dialogue) failures.push(`${citizen.id}: role or dialogue missing`);
  if (citizen.routes.length !== 3) failures.push(`${citizen.id}: expected three seeded itineraries`);
  for (const [variant, route] of citizen.routes.entries()) {
    if (route.length < 40) failures.push(`${citizen.id}/${variant}: route too short`);
    if (hash(route[0]) !== hash(route.at(-1))) failures.push(`${citizen.id}/${variant}: route does not close`);
    for (let i = 1; i < route.length; i++) {
      if (!approved.has(edge(route[i - 1], route[i])))
        failures.push(`${citizen.id}/${variant}: off-road segment ${i - 1}-${i}`);
    }
    const xs = route.map(p => p[0]);
    if (Math.min(...xs) > 600 || Math.max(...xs) < 1500 ||
        !route.some(p => p[0] > 850 && p[0] < 1350))
      failures.push(`${citizen.id}/${variant}: fails to visit west, center and east city`);
  }
}
if (catalog.citizens.length !== 23 || seen.size !== 23)
  failures.push(`Expected 23 named citizens, got ${catalog.citizens.length}`);

if (failures.length) {
  console.error(failures.join('\n'));
  process.exitCode = 1;
} else {
  console.log(`Roads: ${roads.nodes.length} nodes, ${roads.edges.length} painted edges; ` +
              `${seen.size} citizens, 69 closed west/center/east itineraries and art assets valid`);
}
