const screen = document.querySelector('#screen')
const navButtons = [...document.querySelectorAll('[data-screen]')]

const assets = {
  fool: '../Mistport/Assets.xcassets/PathFool.imageset/path-fool.png',
  priestess: '../Mistport/Assets.xcassets/PathPriestess.imageset/path-priestess.png',
  chariot: '../Mistport/Assets.xcassets/PathChariot.imageset/path-chariot.png',
  magician: '../Mistport/Assets.xcassets/PathMagician.imageset/path-magician.png',
  justice: '../Mistport/Assets.xcassets/PathJustice.imageset/path-justice.png',
  star: '../Mistport/Assets.xcassets/PathStar.imageset/path-star.png',
  city: '../Mistport/Assets.xcassets/MistportCityHub.imageset/mistport-city-hub.png',
  world: '../Mistport/Assets.xcassets/MistportWorldMap.imageset/mistport-world-map.png',
  clock: '../Mistport/Assets.xcassets/SceneClockDistrict.imageset/scene-clock-district.png',
  tea: '../Mistport/Assets.xcassets/SceneLaurelTeaHouse.imageset/scene-laurel-teahouse.png',
  theater: '../Mistport/Assets.xcassets/SceneMirrorTheater.imageset/scene-mirror-theater.png',
  ritual: '../Mistport/Assets.xcassets/SceneSaltRitual.imageset/scene-salt-ritual.png'
}

const regions = [
  ['9', '雾岬自由联邦', '雾岬港', '秘密、潮汐与初次选择', '开放'],
  ['8', '盐镜联邦', '镜湾城', '身份、倒影与替代者', '预览'],
  ['7', '铜冠联邦', '铸雨城', '工业、秩序与被制造的神迹', '锁定'],
  ['6', '翡翠群岛联邦', '树潮城', '生命、共生与过度生长', '锁定'],
  ['5', '灰烬边疆联邦', '余火城', '战争、记忆与未熄的命令', '锁定'],
  ['4', '眠海联邦', '梦港城', '梦境、死亡与温柔遗忘', '锁定'],
  ['3', '风碑联邦', '誓风城', '历史、誓言与胜者叙事', '锁定'],
  ['2', '星桥联邦', '远星城', '空间、知识与不可抵达之物', '锁定'],
  ['1', '黎明环联邦', '晨钟城', '时间、权柄与最后的人性', '锁定'],
  ['0', '无冕天域', '逆潮之源', '六路共同终局与个人成神选择', '终局']
]

const party = [
  ['☽', '愚者·假面', '控场与欺敌'],
  ['◐', '女祭司·潮听', '控场与治疗'],
  ['◆', '战车·远征', '前锋与守护'],
  ['✣', '魔术师·炼成', '制造与范围输出'],
  ['⚖', '正义·誓衡', '护盾与净化'],
  ['✦', '星星·星渡', '远程与位移']
]

function renderTitle () {
  screen.innerHTML = `<section class="app-screen"><div class="title-art"></div><div class="title-content">
    <div class="seal">✦</div><p class="game-kicker">原创塔罗仪式 RPG · 免费序章</p>
    <h2>秘仪：<br>雾港升序</h2>
    <p class="tagline">从序列 9 开始，以扮演驾驭力量。<br>在潮水倒流的雾港，完成第一次晋升仪式。</p>
    <button class="primary" data-go="paths">进入免费序章　→</button>
    <div class="title-links"><button data-go="world">九联邦路线</button><button data-go="expedition">临时远征</button></div>
    <button class="text-action">解锁完整雾港篇</button>
    <div class="facts"><span><b>6</b>成神路径</span><span><b>9</b>主题联邦</span><span><b>9 → 0</b>完整升序</span></div>
  </div></section>`
}

function pathCard ({ id, arcana, name, sequence, description, principle, tint }) {
  return `<button class="path-card" data-path="${id}" style="--tint:${tint};--image:url('${assets[id]}')"><span class="path-image"></span><span class="path-meta">
    <h3>${arcana} · ${name}</h3><small>序列 9 · ${sequence}</small><p>${description}</p><span class="principle">扮演原则：${principle}</span>
  </span></button>`
}

function renderPaths () {
  screen.innerHTML = `<section class="app-screen"><header class="screen-header"><button class="back" data-go="title">‹ 返回</button><h2>第一张牌决定<br>最初的道路</h2><p>每条路径都有不同的力量、扮演原则和失控代价。</p></header><div class="path-list">
    ${pathCard({ id: 'fool', arcana: '0', name: '愚者·假面', sequence: '街头戏法师', description: '伪装身份、操纵误判，在常理裂缝中脱身。', principle: '让人相信一个可控的错误', tint: '#c78af1' })}
    ${pathCard({ id: 'priestess', arcana: 'II', name: '女祭司·潮听', sequence: '灵视者', description: '读取梦境、记忆与被遮蔽的灵性残响。', principle: '从沉默与细节中听见真相', tint: '#76c1ff' })}
    ${pathCard({ id: 'chariot', arcana: 'VII', name: '战车·远征', sequence: '夜巡者', description: '追猎、护送并成为危险中的可靠前锋。', principle: '在恐惧中仍向目标前进', tint: '#f8b54f' })}
    ${pathCard({ id: 'magician', arcana: 'I', name: '魔术师·炼成', sequence: '盐晶学徒', description: '拆解材料、改造机关并临时重塑战场。', principle: '每一次创造都必须付出等价之物', tint: '#56e0b7' })}
    ${pathCard({ id: 'justice', arcana: 'XI', name: '正义·誓衡', sequence: '誓约见证人', description: '识别契约、分配代价并约束异常。', principle: '只许下自己愿意承担代价的誓言', tint: '#f47a6b' })}
    ${pathCard({ id: 'star', arcana: 'XVII', name: '星星·星渡', sequence: '星图测绘师', description: '观测可能性、折叠短距并寻找绝境航路。', principle: '先为迷路的人指出仍可抵达的方向', tint: '#719fff' })}
  </div></section>`
}

function renderAdventure () {
  screen.innerHTML = `<section class="app-screen scene-screen" style="--scene:url('${assets.clock}')"><div class="scene-shade"></div><div class="fog fog-a"></div><div class="rain"></div>
    <header class="scene-hud combat-hud"><button data-go="city">‹</button><span><b>旧钟区</b><small>异常清剿</small></span><div class="enemy-counter">✹ <b id="enemyCount">3</b></div></header>
    <div class="web-monster monster-purple" style="left:54%;top:43%"><i>◈</i><span></span></div>
    <div class="web-monster monster-cyan" style="left:36%;top:61%"><i>◇</i><span></span></div>
    <div class="web-monster monster-red" style="left:72%;top:72%"><i>⚙</i><span></span></div>
    <div class="web-player" style="left:27%;top:75%"><i></i><b>0</b></div>
    <article class="web-combat-dock"><div class="web-health"><i>♥</i><span></span><b>100</b></div><div class="web-combat-actions">
      <button class="web-skill" id="combatSkill">☽<small>路径</small></button><em id="combatStatus">点击怪物锁定</em><button class="web-attack" id="combatAttack">✹</button>
    </div></article>
  </section>`
}

function renderCity () {
  screen.innerHTML = `<section class="app-screen city-screen" style="--city:url('${assets.city}')"><div class="scene-shade"></div><div class="fog fog-a"></div><div class="fog fog-b"></div><div class="rain"></div>
    <header class="city-hud"><span class="mini-seal">☽</span><span><b>愚者·假面</b><small>序列 9 · 雾岬港</small></span><em>≋ 夜潮 41%</em></header>
    <button class="hotspot primary-hotspot" data-go="adventure" style="left:5%;top:34%"><i>◷</i><span><b>旧钟区</b><small>主线</small></span></button>
    <button class="hotspot" data-go="adventure" style="left:25%;top:51%;--spot:#f1a34c"><i>◉</i><span><b>月桂街</b><small>茶馆</small></span></button>
    <button class="hotspot" data-go="expedition" style="right:4%;top:27%;--spot:#5edbea"><i>⌖</i><span><b>远征灯塔</b><small>组队</small></span></button>
    <button class="hotspot" data-go="adventure" style="right:2%;top:57%;--spot:#d763e8"><i>◐</i><span><b>潮汐剧院</b><small>异常</small></span></button>
    <button class="hotspot" data-go="world" style="left:38%;top:69%;--spot:#f4d343"><i>▰</i><span><b>潮汐环</b><small>航路</small></span></button>
    <button class="mission-strip" data-go="adventure"><span><b>主线 · 失踪的钟表匠</b><small>前往旧钟区</small></span><i>›</i></button>
    <nav class="city-bar"><button data-go="adventure">▰<small>任务</small></button><button data-go="world">◆<small>航路</small></button><button data-go="expedition">♟<small>远征</small></button></nav>
  </section>`
}

function renderWorld () {
  const positions = [[42,85],[64,75],[34,65],[63,56],[35,47],[64,39],[36,31],[65,24],[42,16],[65,9]]
  screen.innerHTML = `<section class="app-screen visual-world" style="--world:url('${assets.world}')"><div class="scene-shade"></div><div class="fog fog-a"></div><header class="map-hud"><span><b>九联邦航路</b><small>序列 9 → 0</small></span><button data-go="city">×</button></header>
    ${regions.map(([sequence, name], index) => `<button class="map-node ${index === 0 ? 'current' : ''} ${index === 9 ? 'final' : ''}" style="left:${positions[index][0]}%;top:${positions[index][1]}%"><i>${sequence}</i><span>${index < 2 || index === 9 ? name : `序列 ${sequence}`}</span></button>`).join('')}
    <div class="current-region">⌖ 当前 · 雾岬自由联邦</div>
  </section>`
}

function renderExpedition () {
  screen.innerHTML = `<section class="app-screen expedition-scene" style="--theater:url('${assets.theater}')"><div class="scene-shade"></div><div class="fog fog-a"></div><header class="map-hud"><span><b>雾岬远征站</b><small>⚒ 联机演示</small></span><button data-go="city">×</button></header>
    <article class="party-token-bar" id="partyCount">${party.map(([symbol], index) => `<i class="${index ? 'empty' : ''}">${symbol}</i>`).join('')}<span>1 / 6</span></article>
    <article class="expedition-dock"><small>雾岬港 · 约 12 分钟</small><h3>镜剧院 · 潮汐回声</h3><p>破坏三面锚镜，涨潮前救出观众。</p><button class="primary" id="matchButton">随到随组 · 开始匹配</button><em>无公会 · 无打卡 · AI 随时补位</em></article>
  </section>`
}

function show (name) {
  navButtons.forEach(button => button.classList.toggle('active', button.dataset.screen === name))
  if (name === 'paths') renderPaths()
  else if (name === 'city') renderCity()
  else if (name === 'adventure') renderAdventure()
  else if (name === 'world') renderWorld()
  else if (name === 'expedition') renderExpedition()
  else renderTitle()
}

document.addEventListener('click', event => {
  const target = event.target.closest('[data-screen], [data-go], [data-path]')
  if (target) show(target.dataset.screen || target.dataset.go || (target.dataset.path ? 'city' : 'adventure'))

  if (event.target.closest('#matchButton')) {
    const button = document.querySelector('#matchButton')
    button.textContent = '正在寻找同行者…'
    button.disabled = true
    setTimeout(() => {
      button.textContent = '队伍已就绪'
      document.querySelector('#partyCount span').textContent = '6 / 6'
      document.querySelectorAll('.party-token-bar i.empty').forEach(token => token.classList.remove('empty'))
    }, 700)
  }

  if (event.target.closest('#combatAttack, #combatSkill')) {
    const monster = document.querySelector('.web-monster:not(.defeated)')
    if (monster) {
      monster.classList.add('defeated')
      const remaining = document.querySelectorAll('.web-monster:not(.defeated)').length
      document.querySelector('#enemyCount').textContent = remaining
      document.querySelector('#combatStatus').textContent = remaining ? `击破 · 剩余 ${remaining}` : '区域净化'
    }
    if (event.target.closest('#combatSkill')) event.target.closest('#combatSkill').disabled = true
  }
})

show('title')
