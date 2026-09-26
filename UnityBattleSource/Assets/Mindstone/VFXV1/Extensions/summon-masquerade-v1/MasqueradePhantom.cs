using System.Collections.Generic;
using UnityEngine;
namespace Mindstone.VFXV1 {
/// Presentation only. Swift owns the two charges and sends authoritative hit updates.
public sealed class MasqueradePhantom : MonoBehaviour {
 sealed class Part { public SkinnedMeshRenderer source; public Transform original, copy; public Mesh baked; }
 GameObject[] shards; Material shardMaterial; Vector3 breakOrigin;
 readonly List<Part> parts=new List<Part>();
 float expiresAt = float.PositiveInfinity;
 public void SetLifetime(float seconds) { expiresAt = Time.time + seconds; }
 Transform actor; GameObject silhouette; Material material; float born,hitAt=-100,fadeAt=-100; bool fading;
 public bool IsActive => silhouette;
 public Vector3 Impact => actor ? actor.position+Offset+Vector3.up*.85f : transform.position;
 Vector3 Offset => (Camera.main?Camera.main.transform.right:Vector3.right)*-.72f+Vector3.forward*.65f;
 public void Deploy(Transform source) {
  Clear(); expiresAt=float.PositiveInfinity; actor=source;born=Time.time;fading=false;hitAt=-100;
  silhouette=new GameObject("Masquerade · living echo");silhouette.transform.SetParent(transform,false);
  material=new Material(Resources.Load<Shader>("Mindstone/VFXV1/MasqueradeGhost"));
  foreach(var renderer in source.GetComponentsInChildren<SkinnedMeshRenderer>()) {
   if(!renderer.enabled || !renderer.sharedMesh || renderer.name.StartsWith("FoolRibbon"))continue;
   var go=new GameObject("Echo · "+renderer.name);go.transform.SetParent(silhouette.transform,false);
   var mesh=new Mesh();mesh.MarkDynamic();go.AddComponent<MeshFilter>().sharedMesh=mesh;
   var mr=go.AddComponent<MeshRenderer>();var mats=new Material[renderer.sharedMesh.subMeshCount];for(int i=0;i<mats.Length;i++)mats[i]=material;mr.sharedMaterials=mats;
   mr.shadowCastingMode=UnityEngine.Rendering.ShadowCastingMode.Off;mr.receiveShadows=false;
   parts.Add(new Part{source=renderer,original=renderer.transform,copy=go.transform,baked=mesh});
  }
 }
 public void Hit(int remaining) { if(!silhouette)return;hitAt=Time.time;if(remaining<=0){fading=true;fadeAt=Time.time;breakOrigin=Impact;
   shardMaterial=new Material(Resources.Load<Shader>("Mindstone/VFXV1/MasqueradeGhost"));shards=new GameObject[17];
   for(int i=0;i<shards.Length;i++){var g=GameObject.CreatePrimitive(PrimitiveType.Quad);Destroy(g.GetComponent<Collider>());g.name="Shattered false identity";g.transform.SetParent(transform,false);g.GetComponent<Renderer>().sharedMaterial=shardMaterial;g.transform.localScale=new Vector3(.065f+(i%4)*.030f,.13f+(i%3)*.09f,1);shards[i]=g;}} }
 void LateUpdate(){if(!silhouette||!actor)return;
  float fade=fading?Mathf.Clamp01(1-(Time.time-fadeAt)/.55f):Mathf.Clamp01((Time.time-born)/.3f);
  if(!fading) fade *= Mathf.Clamp01((expiresAt-Time.time)/.8f);
  float hitAge=Mathf.Max(0,Time.time-hitAt);
  float hit=Mathf.Exp(-hitAge*11);
  float recoil=Mathf.Sin(Mathf.Clamp01(hitAge/.22f)*Mathf.PI)*.13f;
  material.SetColor("_Color",Color.Lerp(new Color(.5f,.24f,1,.65f*fade),new Color(1.18f,.88f,.43f,fade),hit));
  foreach(var part in parts){if(!part.source||!part.copy)continue;part.source.BakeMesh(part.baked);part.copy.SetPositionAndRotation(part.original.position+Offset+Vector3.up*Mathf.Sin(Time.time*2.2f)*.025f-Vector3.forward*recoil,part.original.rotation);part.copy.localScale=part.original.lossyScale;}
  if(shards!=null){float t=Time.time-fadeAt;for(int i=0;i<shards.Length;i++){float a=i*2.399963f;var v=new Vector3(Mathf.Cos(a),Mathf.Sin(a),Mathf.Sin(a*3));shards[i].transform.position=breakOrigin+v*(.12f+(1-Mathf.Exp(-t*13))*(.72f+(i%5)*.14f))+Vector3.down*t*t*1.5f;shards[i].transform.rotation=Quaternion.Euler(i*37+t*260,i*73+t*190,i*19);}
   shardMaterial.SetColor("_Color",new Color(.8f,.44f,1,fade));}
  if(fading && fade<=0)Clear();
 }
 public void Clear(){if(shards!=null)foreach(var g in shards)if(g)Destroy(g);shards=null;if(shardMaterial)Destroy(shardMaterial);shardMaterial=null;foreach(var p in parts)if(p.baked)Destroy(p.baked);parts.Clear();if(silhouette)Destroy(silhouette);silhouette=null;if(material)Destroy(material);material=null;}
 void OnDisable()=>Clear();
 void OnDestroy()=>Clear();
}
}
