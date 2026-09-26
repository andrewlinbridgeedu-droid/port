using System;
using System.Collections.Generic;
using UnityEngine;
// Review adapter: target selection belongs to the caller; one disposable effect per stable identity.
public sealed class TargetSpellTrial:MonoBehaviour {
 public enum Style { Phoenix, Rift, Thunder }
 sealed class Entry {public string id;public Transform target;public Vector3 initial,baseRoot;public GameObject root;public Action<float> sample;}
 readonly List<Entry> entries=new List<Entry>();
 public int LiveCount {get {int n=0;foreach(var e in entries)if(e.root)n++;return n;}}
 public void Build(Style style,Vector3 origin,IList<Transform> targets,IList<string> ids,Texture2D art,Mesh wing=null){
  if(targets.Count!=ids.Count)throw new ArgumentException("Target identity count mismatch");
  Clear();
  var seen=new HashSet<string>();
  for(int i=0;i<targets.Count;i++){
   var target=targets[i];if(!target||!target.gameObject.activeInHierarchy||!seen.Add(ids[i]))continue;
   Vector3 end=target.position;end.y=.04f;
   var root=new GameObject(style+" target "+ids[i]);root.transform.SetParent(transform,false);
   Action<float> sample;
   if(style==Style.Phoenix){var fx=root.AddComponent<PhoenixWingTrial>();fx.WidthFactor=.34f;fx.Build(origin,end,art,wing);var hit=root.AddComponent<SpellContactTrial>();hit.Build(new[]{end});sample=t=>{fx.Sample(t);hit.Sample(t);};}
   else if(style==Style.Rift){var fx=root.AddComponent<GoldenRiftTrial>();fx.WidthFactor=.34f;fx.SurfaceArt=art;fx.Build(origin,end);var hit=root.AddComponent<RiftImpactTrial>();hit.Build(new[]{end});sample=t=>{fx.Sample(t);hit.Sample(t);};}
   else{var fx=root.AddComponent<IceThunderTrial>();fx.GroundArt=art;fx.StableTargetId=ids[i];fx.Build(new[]{end});var hit=root.AddComponent<SpellContactTrial>();hit.Ice=true;hit.Build(new[]{end});sample=t=>{fx.Sample(t);hit.Sample(t);};}
   entries.Add(new Entry{id=ids[i],target=target,initial=target.position,baseRoot=root.transform.position,root=root,sample=sample});
  }
 }
 public void Sample(float t){foreach(var e in entries){if(!e.root)continue;if(!e.target||!e.target.gameObject.activeInHierarchy){e.root.SetActive(false);Destroy(e.root);e.root=null;continue;}e.root.transform.position=e.baseRoot;e.sample(t); // Curves are authored in initial world space; the independent root follows this recipient only.
  e.root.transform.position=e.baseRoot+e.target.position-e.initial;
 }}
 void Clear(){foreach(var e in entries)if(e.root){e.root.SetActive(false);Destroy(e.root);e.root=null;}entries.Clear();}
 void OnDisable(){Clear();}
 void OnDestroy(){Clear();}
}
