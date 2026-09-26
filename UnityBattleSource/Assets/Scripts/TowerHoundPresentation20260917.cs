using System;
using System.Collections;
using UnityEngine;
// Independent per-instance reuse of the authored early fireball, never late-hound fire pillars.
public sealed class TowerHoundPresentation20260917:MonoBehaviour {
 Q4HoundPresentation flames;
 int epoch;Transform movingRoot,head;Vector3 home;bool charging,headAdjusted;float chargeAge;Quaternion delta=Quaternion.identity,applied;
 public IEnumerator Shot(EnemyHandle actor,Func<Vector3> target,bool second,Action contact) {
  Cancel(); if(!flames)flames=gameObject.AddComponent<Q4HoundPresentation>();
  flames.Configure(actor.EnemyRoot,()=>actor.EffectAnchor?actor.EffectAnchor.position:actor.EnemyRoot.position+Vector3.up,target);
  flames.SetPhase(second?"second":"first");
  yield return flames.Shot(contact,()=>UnityBattleBridge.ReportPresentationComplete("enemy"));
 }
 public void PreparePounce(EnemyHandle actor){Cancel();charging=true;chargeAge=0;foreach(var t in actor.EnemyRoot.GetComponentsInChildren<Transform>())if(t.name.ToLowerInvariant().Contains("head")){head=t;break;}}
 void LateUpdate(){UndoHead();if(charging&&head){chargeAge+=Time.deltaTime;delta=Quaternion.Euler(Mathf.SmoothStep(0,10,Mathf.Clamp01(chargeAge/1.5f)),0,0);head.localRotation*=delta;applied=head.localRotation;headAdjusted=true;}}
 void UndoHead(){if(headAdjusted&&head&&Quaternion.Angle(head.localRotation,applied)<.01f)head.localRotation*=Quaternion.Inverse(delta);headAdjusted=false;}
 public IEnumerator Pounce(EnemyHandle actor,Func<Vector3> target,Action contact){
  Cancel();int token=epoch;movingRoot=actor.EnemyRoot;home=movingRoot.position;var direction=target()-home;direction.y=0;var end=home+direction.normalized*Mathf.Min(1.4f,direction.magnitude*.4f);var animator=actor.GetComponentInChildren<Animator>();animator?.SetTrigger("Attack");bool hit=false;
  try{for(float t=0;t<1.05f;t+=Time.deltaTime){if(token!=epoch||!actor||!actor.gameObject.activeInHierarchy)yield break;float u=t<.45f?Mathf.Clamp01(t/.45f):Mathf.Clamp01(1-(t-.45f)/.60f);movingRoot.position=Vector3.Lerp(home,end,u)+Vector3.up*Mathf.Sin(u*Mathf.PI)*.16f;if(!hit&&t>=.45f){hit=true;contact?.Invoke();}yield return null;}}
  finally{if(token==epoch&&movingRoot){movingRoot.position=home;movingRoot=null;}if(token==epoch)UnityBattleBridge.ReportPresentationComplete("enemy");}
 }
 public void Cancel(){epoch++;charging=false;UndoHead();if(movingRoot){movingRoot.position=home;movingRoot=null;}if(flames)flames.Clear();}
 void OnDisable(){Cancel();}
}
