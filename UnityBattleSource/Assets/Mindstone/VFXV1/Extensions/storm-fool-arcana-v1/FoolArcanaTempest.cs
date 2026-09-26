using System.Collections.Generic;
using UnityEngine;
namespace Mindstone.VFXV1 {
public sealed class FoolArcanaTempest : MonoBehaviour, ISpellExtension {
 GameObject body; Material wind,gold,stone,arc; readonly List<Transform> debris=new(); readonly List<LineRenderer> bolts=new(); readonly List<LineRenderer> threads=new(); bool released;
 public void Initialize(SpellSpec spec,SpellLayerSpec layer,int seed){
 body=Instantiate(Resources.Load<GameObject>("Mindstone/VFXV1/Spells/storm-fool-arcana-v1/ArcanaTornado"),transform);body.name="Blender authored Arcana tornado";
 wind=new Material(Resources.Load<Shader>("Mindstone/VFXV1/Spells/storm-fool-arcana-v1/ArcanaWind"));wind.SetColor("_Tint",new Color(.46f,.24f,.92f));
 foreach(var r in body.GetComponentsInChildren<Renderer>())r.sharedMaterial=wind;
 gold=new Material(Resources.Load<Shader>("Mindstone/VFXV1/Spells/storm-fool-arcana-v1/ArcanaCard"));gold.color=new Color(.18f,.09f,.025f);gold.EnableKeyword("_EMISSION");gold.SetColor("_EmissionColor",new Color(1.6f,.75f,.18f));gold.SetFloat("_Metallic",.8f);
 stone=new Material(Shader.Find("Standard"));stone.color=new Color(.13f,.15f,.19f);stone.SetFloat("_Metallic",.55f);
 arc=new Material(Shader.Find("Sprites/Default"));arc.color=new Color(.72f,.6f,1f);
 for(int i=0;i<72;i++){var g=GameObject.CreatePrimitive(i%3==0?PrimitiveType.Cube:PrimitiveType.Cube);g.name=i%3==0?"Arcana golden fragment":"Vortex debris";g.transform.SetParent(transform);DestroyOwned(g.GetComponent<Collider>());g.GetComponent<Renderer>().sharedMaterial=i%3==0?gold:stone;g.transform.localScale=i%3==0?new Vector3(.1f,.16f,.018f):Vector3.one*(.04f+(i%5)*.018f);debris.Add(g.transform);}
 for(int i=0;i<5;i++){var g=new GameObject("Branch lightning");g.transform.SetParent(transform);var l=g.AddComponent<LineRenderer>();l.sharedMaterial=arc;l.positionCount=24;l.widthMultiplier=.018f;l.useWorldSpace=false;bolts.Add(l);}
 }
 void BuildThreads(){for(int i=0;i<7;i++){var g=new GameObject("Fine rotating wind filament");g.transform.SetParent(transform);var l=g.AddComponent<LineRenderer>();l.sharedMaterial=arc;l.useWorldSpace=false;l.positionCount=80;l.widthMultiplier=.009f;threads.Add(l);}}
 public void Sample(in SpellSample s){SampleAt(s.AbsoluteTime,s.Target);}
 public void SampleAt(float t,Vector3 anchor){if(released||body==null)return;transform.position=anchor;var vis=Mathf.SmoothStep(0,1,t/.8f)*(1-Mathf.SmoothStep(0,1,(t-4.8f)/1.2f));body.transform.localScale=Vector3.one*(.15f+.85f*vis);body.transform.localRotation=Quaternion.Euler(0,-t*150,0);wind.SetFloat("_Phase",t);wind.SetFloat("_Visibility",vis);if(threads.Count==0)BuildThreads();for(int i=0;i<threads.Count;i++){var l=threads[i];l.startColor=l.endColor=new Color(.63f,.48f,1,.48f*vis);for(int k=0;k<80;k++){float h=.08f+k/79f*.86f,a=h*14+i*.91f-t*2.7f,r=.25f+2.2f*Mathf.Pow(h,.8f);l.SetPosition(k,new Vector3(Mathf.Cos(a)*r,h*5.8f,Mathf.Sin(a)*r));}}
 for(int i=0;i<debris.Count;i++){float h=Mathf.Repeat(i*.071f+t*.23f,1),a=i*2.4f+t*(2.8f+i%4*.18f),r=.5f+2.5f*h;debris[i].localPosition=new Vector3(Mathf.Cos(a)*r,h*5.3f,Mathf.Sin(a)*r);debris[i].localRotation=Quaternion.Euler(t*100+i*37,t*180+i*23,i*17);debris[i].gameObject.SetActive(vis>.05f);}
 for(int i=0;i<bolts.Count;i++){float pulse=Mathf.Pow(Mathf.Max(0,Mathf.Sin(t*7+i*1.7f)),12)*vis;bolts[i].enabled=pulse>.025f;bolts[i].startColor=bolts[i].endColor=new Color(.65f,.6f,1,pulse);for(int k=0;k<24;k++){float h=k/23f,a=i*1.256f+h*3+t*.5f,r=.45f+2.1f*h;bolts[i].SetPosition(k,new Vector3(Mathf.Cos(a)*r+Mathf.Sin(k*17+i)*.13f,h*5.5f,Mathf.Sin(a)*r));}}
 }
 public void Interrupt()=>Cleanup();public void Cleanup(){if(released)return;released=true;if(body)DestroyOwned(body);foreach(var d in debris)if(d)DestroyOwned(d.gameObject);foreach(var b in bolts)if(b)DestroyOwned(b.gameObject);foreach(var l in threads)if(l)DestroyOwned(l.gameObject);DestroyOwned(wind);DestroyOwned(gold);DestroyOwned(stone);DestroyOwned(arc);}
 static void DestroyOwned(Object o){if(!o)return;if(Application.isPlaying)Destroy(o);else DestroyImmediate(o);}
}
}
