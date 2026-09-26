using System.Collections.Generic;
using System.Linq;
using UnityEngine;
// Authoritative persistent state. No timers infer poison or grant empowerment.
public sealed class ChurchStatusPresentation20260917:MonoBehaviour {
 BattlePrototype battle;bool poison;TowerStatusRound2 poisonArt;readonly Dictionary<string,ChurchSpellVisual20260917> bindings=new Dictionary<string,ChurchSpellVisual20260917>();ChurchSpellVisual20260917 escort;
 EnemyHandle escortActor;string escortActorID;UnityBattleBridge escortBridge;Vector3 escortLastPosition;
 readonly Dictionary<string,TowerStatusRound2> crowns=new Dictionary<string,TowerStatusRound2>();
 public static ChurchStatusPresentation20260917 Get(BattlePrototype b){var c=b.GetComponent<ChurchStatusPresentation20260917>();if(!c)c=b.gameObject.AddComponent<ChurchStatusPresentation20260917>();c.battle=b;return c;}
 public void Apply(string payload){
  if(payload.StartsWith("escorted:")){
   ClearEscort();string id=payload.Substring(9);if(string.IsNullOrWhiteSpace(id)||!battle)return;
   escortActor=FindActor(id);escortActorID=id;escortBridge=FindFirstObjectByType<UnityBattleBridge>();
   if(!EscortActorValid()){ClearEscort();return;}
   escortLastPosition=escortActor.EffectAnchor.position;
   escort=ChurchSpellVisual20260917.Create("b03","escorted",escortLastPosition,EscortPosition,1);escort.ambient=true;
   // One enveloping water rise when protection begins; no contact, no damage burst.
   var guarded=escortActor;SpellSpectacle20260926.PlayState(battle,"escort-ward",()=>SpellSpectacle20260926.AnchorOf(guarded),SpellSpectacle20260926.StableHash(id));return;
  }
  if(payload.StartsWith("bindings:")){
   var ids=new HashSet<string>(payload.Substring(9).Split(',').Where(x=>x.Length>0));
   foreach(var id in bindings.Keys.ToArray())if(!ids.Contains(id)){if(bindings[id])Destroy(bindings[id].gameObject);bindings.Remove(id);}
   foreach(var id in ids){if(bindings.ContainsKey(id))continue;var actor=FindActor(id);var b=actor?actor.GetComponent<BountyIdentityPresentation20260917>():null;if(!b)continue;var p=battle.PlayerFireBreathImpactAnchor;var art=ChurchSpellVisual20260917.Create(b.bountyID,"binding",p,()=>battle.PlayerFireBreathImpactAnchor,1);art.intensity=.7f;bindings[id]=art;}return;
  }

  if(payload.StartsWith("poison:")){poison=payload.EndsWith(":1");if(!poison&&poisonArt){Destroy(poisonArt.gameObject);poisonArt=null;}return;}
  if(payload.StartsWith("empowered:")){
   var ids=new HashSet<string>(payload.Substring(10).Split(',').Where(x=>x.Length>0));
   foreach(var id in crowns.Keys.ToArray())if(!ids.Contains(id)){if(crowns[id])Destroy(crowns[id].gameObject);crowns.Remove(id);}
   foreach(var id in ids){if(crowns.ContainsKey(id))continue;var actor=FindActor(id);if(!actor)continue;var crown=TowerStatusRound2.Create(false,()=>actor&&actor.EffectAnchor?actor.EffectAnchor.position:Vector3.zero,()=>actor&&actor.gameObject.activeInHierarchy&&battle&&battle.BelongsToCurrentEncounter(actor));crowns[id]=crown;}
  }
 }
 EnemyHandle FindActor(string id)=>FindObjectsByType<EnemyHandle>(FindObjectsSortMode.None).FirstOrDefault(h=>h.BattleEnemyId==id&&battle.BelongsToCurrentEncounter(h));
 // Retain the original instance and identity. A later clone with the same ID
 // must not inherit this presentation when the original actor leaves.
 bool EscortActorValid(){
  if(!battle||!battle.NativeCombatEnabled||!escortActor||escortActor.BattleEnemyId!=escortActorID
   ||!escortActor.gameObject.activeInHierarchy||!escortActor.EnemyRoot||!escortActor.EnemyRoot.gameObject.activeInHierarchy
   ||!escortActor.EffectAnchor||!escortActor.EffectAnchor.gameObject.activeInHierarchy
   ||!battle.BelongsToCurrentEncounter(escortActor))return false;
  if(!escortBridge)escortBridge=FindFirstObjectByType<UnityBattleBridge>();
  return !escortBridge||!escortBridge.IsEnemyExiting(escortActor);
 }
 Vector3 EscortPosition(){if(EscortActorValid())escortLastPosition=escortActor.EffectAnchor.position;return escortLastPosition;}
 void ClearEscort(){
  // Stop ambient drawing immediately; Destroy alone is deferred until frame end.
  if(escort){escort.gameObject.SetActive(false);Destroy(escort.gameObject);}escort=null;
  escortActor=null;escortActorID=null;escortBridge=null;escortLastPosition=Vector3.zero;
 }
 void Update(){
  if(!battle||!battle.NativeCombatEnabled){Clear();return;}
  if(escortActorID!=null&&(!escort||!EscortActorValid()))ClearEscort();
  if(poison){if(!poisonArt)poisonArt=TowerStatusRound2.Create(true,()=>battle.PlayerFireBreathImpactAnchor,()=>battle&&battle.NativeCombatEnabled);poisonArt.intensity=.80f;}
  foreach(var kv in bindings.ToArray()){var actor=FindActor(kv.Key);if(!actor||!actor.gameObject.activeInHierarchy){if(kv.Value)Destroy(kv.Value.gameObject);bindings.Remove(kv.Key);}else if(kv.Value)kv.Value.Tick(.93f+.025f*Mathf.Sin(Time.time*2));}
  foreach(var kv in crowns.ToArray()){var actor=FindActor(kv.Key);if(!actor||!actor.gameObject.activeInHierarchy){if(kv.Value)Destroy(kv.Value.gameObject);crowns.Remove(kv.Key);}}
 }
 public void Clear(){ClearEscort();foreach(var v in bindings.Values)if(v)Destroy(v.gameObject);bindings.Clear();poison=false;if(poisonArt)Destroy(poisonArt.gameObject);poisonArt=null;foreach(var v in crowns.Values)if(v)Destroy(v.gameObject);crowns.Clear();}
 void OnDisable(){Clear();}
}
