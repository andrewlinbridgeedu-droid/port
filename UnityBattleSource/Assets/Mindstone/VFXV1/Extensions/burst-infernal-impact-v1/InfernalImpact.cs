using UnityEngine;
namespace Mindstone.VFXV1 {
public sealed class InfernalImpact:MonoBehaviour,ISpellExtension {
 GameObject[] clouds;Material[] mats;LineRenderer[] sparks;Material lineMat;string role;
 public void Initialize(SpellSpec spell,SpellLayerSpec layer,int seed){role=layer.role;
 if(role=="core"){clouds=new GameObject[15];mats=new Material[15];for(int i=0;i<15;i++){var g=GameObject.CreatePrimitive(PrimitiveType.Quad);Destroy(g.GetComponent<Collider>());g.transform.SetParent(transform,false);var m=new Material(Resources.Load<Shader>("Mindstone/VFXV1/ArcanaBurst"));g.GetComponent<Renderer>().sharedMaterial=m;clouds[i]=g;mats[i]=m;}}
 else {lineMat=new Material(Resources.Load<Shader>("Mindstone/VFXV1/ArcanaFilament"));sparks=new LineRenderer[role=="direction"?3:32];for(int i=0;i<sparks.Length;i++){var g=new GameObject("Infernal heat / ember");g.transform.SetParent(transform,false);var l=g.AddComponent<LineRenderer>();l.sharedMaterial=lineMat;l.positionCount=32;l.useWorldSpace=true;l.numCapVertices=3;l.shadowCastingMode=UnityEngine.Rendering.ShadowCastingMode.Off;sparks[i]=l;}}
 }
 public void Sample(in SpellSample s){float p=s.NormalizedTime;var cam=Camera.main;var r=cam?cam.transform.right:Vector3.right;var u=cam?cam.transform.up:Vector3.up;var f=cam?cam.transform.forward:Vector3.forward;float fade=Mathf.Pow(1-p,1.5f);float growth=1-Mathf.Pow(1-p,4);
 if(clouds!=null)for(int i=0;i<clouds.Length;i++){float a=i*2.399963f;float radius=i==0?0:Mathf.Sqrt(i/14f)*growth*1.05f;clouds[i].transform.position=s.Target+(r*Mathf.Cos(a)+u*Mathf.Sin(a))*radius+u*p*.45f+f*Mathf.Sin(a*2)*.32f;clouds[i].transform.rotation=(cam?cam.transform.rotation:Quaternion.identity)*Quaternion.Euler(0,0,i*37+p*30);clouds[i].transform.localScale=Vector3.one*(.6f+growth*(i==0?2.1f:1.0f));mats[i].SetColor("_Color",Color.Lerp(new Color(1,.48f,.05f,fade*.75f),new Color(.75f,.055f,.005f,fade*.5f),p));}
 if(sparks!=null)for(int i=0;i<sparks.Length;i++){var l=sparks[i];float angle=i*2.399963f;for(int j=0;j<32;j++){float q=j/31f;Vector3 pos;if(role=="direction"){float a=q*Mathf.PI*2;float radius=(.25f+growth*1.9f)*(1-i*.12f);pos=s.Target+(r*Mathf.Cos(a)+u*Mathf.Sin(a))*radius+f*Mathf.Sin(a*5+p*9)*.12f;}else {var v=(r*Mathf.Cos(angle)+u*Mathf.Sin(angle)+f*Mathf.Sin(angle*3)*.6f).normalized;pos=s.Target+v*(growth*(1.1f+(i%5)*.24f)+q*.22f)-u*p*p*.8f;}l.SetPosition(j,pos);}l.widthMultiplier=role=="direction"?.075f:.045f;l.startColor=new Color(1,.65f,.13f,fade);l.endColor=new Color(1,.12f,.015f,fade*.2f);}
 }
 public void Interrupt()=>Cleanup();public void Cleanup(){if(clouds!=null)foreach(var g in clouds)if(g)Destroy(g);clouds=null;if(mats!=null)foreach(var m in mats)if(m)Destroy(m);mats=null;if(sparks!=null)foreach(var l in sparks)if(l)Destroy(l.gameObject);sparks=null;if(lineMat)Destroy(lineMat);lineMat=null;}void OnDestroy()=>Cleanup();
}
}
