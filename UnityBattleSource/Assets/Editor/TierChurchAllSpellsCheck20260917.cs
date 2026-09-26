using System;using System.Collections;using System.IO;using System.Linq;using UnityEditor;using UnityEditor.SceneManagement;using UnityEngine;
public static class TierChurchAllSpellsCheck20260917{
 const string Key="TierChurchAllSpellsCheck";public static void Begin(){SessionState.SetBool(Key,true);EditorSceneManager.OpenScene("Assets/Scenes/BattlePrototype.unity");EditorApplication.isPlaying=true;}
 [InitializeOnLoadMethod]static void Restore(){EditorApplication.playModeStateChanged+=s=>{if(!SessionState.GetBool(Key,false))return;if(s==PlayModeStateChange.EnteredPlayMode)new GameObject("Church cancellation check").AddComponent<TierChurchAllSpellsRunner20260917>();if(s==PlayModeStateChange.EnteredEditMode){SessionState.SetBool(Key,false);EditorApplication.Exit(0);}};}
}
public sealed class TierChurchAllSpellsRunner20260917:MonoBehaviour{
 int hits,cancels;BattlePrototype battle;UnityBattleBridge bridge;
 void Log(string s,string trace,LogType type){if(!s.Contains("combat-contact"))return;if(s.Contains("enemy:clock-guard-primary"))hits++;if(s.Contains("enemy-cancel:clock-guard-primary"))cancels++;}
 void Check(bool ok,string why){if(!ok){Debug.LogError("CHURCH_CANCEL_FAILED "+why);EditorApplication.Exit(3);throw new Exception(why);}Debug.Log("CHURCH_CANCEL_OK "+why);}
 IEnumerator Start(){Time.timeScale=4;Application.logMessageReceived+=Log;yield return new WaitForSeconds(3);battle=FindFirstObjectByType<BattlePrototype>();bridge=FindFirstObjectByType<UnityBattleBridge>();
 string[] skins={"stonehide","saltmaw","saltmaw","shellback","ironclaw","ironclaw","ironclaw","frilled-naga","boneclaw","boneclaw","boneclaw"};
 string[] actions={"archive_slam","tower_poison","tower_salt_spike","tower_short_pounce","tower_cut_first","tower_cut_second","tower_heavy_cut","tower_sound_arrow","tower_piercing_claw","tower_tail_sweep","tower_heavy_claw"};
 for(int i=0;i<skins.Length;i++){
 bridge.ApplyCommand("{\"action\":\""+"church-tower:"+"clock-guard-primary@"+skins[i]+"\"}");yield return new WaitForSeconds(.6f);battle.SetNativeCombatEnabled(true);
 var a=FindObjectsByType<EnemyHandle>(FindObjectsSortMode.None).Single(h=>battle.BelongsToCurrentEncounter(h));int before=hits;battle.PresentEnemyAttack(a.BattleEnemyId+":"+actions[i]);yield return new WaitForSeconds(2.8f);Check(hits==before+1,"normal once "+skins[i]);
 before=hits;battle.PresentEnemyAttack(a.BattleEnemyId+":"+actions[i]);yield return new WaitForSeconds(.1f);bridge.SetEnemyVisibility(a.BattleEnemyId+"=hidden");yield return new WaitForSeconds(2.1f);Check(hits==before,"actor death cancels unlanded "+skins[i]);bridge.SetEnemyVisibility(a.BattleEnemyId+"=visible");yield return new WaitForSeconds(.2f);Check(a.gameObject.activeInHierarchy,"retry "+skins[i]);battle.SetNativeCombatEnabled(false);
 }
 foreach(string skin in new[]{"shellback","frilled-naga"}){
 bridge.ApplyCommand("{\"action\":\"church-tower:clock-guard-primary@"+skin+",clock-guard-secondary@stonehide\"}");yield return new WaitForSeconds(.6f);battle.SetNativeCombatEnabled(true);int supportBefore=hits;battle.PresentEnemyAttack("clock-guard-primary:"+(skin=="shellback"?"tower_mend":"tower_empower")+":clock-guard-secondary");yield return new WaitForSeconds(1.6f);Check(hits==supportBefore+1,"support normal once "+skin);int before=hits,oldCancel=cancels;battle.PresentEnemyAttack("clock-guard-primary:"+(skin=="shellback"?"tower_mend":"tower_empower")+":clock-guard-secondary");yield return new WaitForSeconds(.1f);bridge.SetEnemyVisibility("clock-guard-secondary=hidden");yield return new WaitForSeconds(1.1f);Check(hits==before&&cancels==oldCancel+1,"recipient one cancel zero hit "+skin);battle.SetNativeCombatEnabled(false);
 }
 File.WriteAllText(Path.GetFullPath("../output/all-spells-tier-20260919/church-death-cancellation-passed.txt"),"All 11 damaging actions across six tower species: one normal contact; actor death cancels before contact, zero late contact; retry restored. D03/D05 recipient death one cancel zero hit. Actual Unity PlayMode, not phone gameplay.");EditorApplication.isPlaying=false;
 }
 void OnDestroy(){Application.logMessageReceived-=Log;}
}
