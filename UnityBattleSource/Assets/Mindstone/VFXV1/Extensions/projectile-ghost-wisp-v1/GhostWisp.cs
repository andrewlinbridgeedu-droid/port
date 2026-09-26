using UnityEngine;
namespace Mindstone.VFXV1 {
public sealed class GhostWisp : MonoBehaviour, ISpellExtension {
 GameObject[] glow; Material[] glowMats; LineRenderer[] lines; Material mat; string role; const bool violet=true;
 public void Initialize(SpellSpec spell, SpellLayerSpec layer,int seed) {
  role=layer.role; mat=new Material(Resources.Load<Shader>("Mindstone/VFXV1/ArcanaFilament"));
  if(role!="direction") {glow=new GameObject[role=="core"?(violet?3:1):3];glowMats=new Material[glow.Length];for(int i=0;i<glow.Length;i++){var g=GameObject.CreatePrimitive(PrimitiveType.Quad);Destroy(g.GetComponent<Collider>());g.transform.SetParent(transform,false);var m=new Material(Resources.Load<Shader>("Mindstone/VFXV1/ArcanaBurst"));g.GetComponent<Renderer>().sharedMaterial=m;glow[i]=g;glowMats[i]=m;}}
  lines=new LineRenderer[role=="core"?6:role=="direction"?6:9];
  for(int i=0;i<lines.Length;i++){var go=new GameObject("Spectral mist filament");go.transform.SetParent(transform,false);var l=go.AddComponent<LineRenderer>();lines[i]=l;l.sharedMaterial=mat;l.useWorldSpace=true;l.positionCount=40;l.numCapVertices=4;l.shadowCastingMode=UnityEngine.Rendering.ShadowCastingMode.Off;}
 }
 Vector3 Path(in SpellSample s,float t,int n,Vector3 r,Vector3 u){float a=t*5+n*2.094f;return Vector3.Lerp(s.Source,s.Target,t)+(r*Mathf.Sin(a)*(violet?.65f:.12f)+u*(violet?Mathf.Cos(a)*.32f:.35f))*Mathf.Sin(t*Mathf.PI);}
 public void Sample(in SpellSample s){float p=s.NormalizedTime;var cam=Camera.main;var r=cam?cam.transform.right:Vector3.right;var u=cam?cam.transform.up:Vector3.up;var f=cam?cam.transform.forward:Vector3.forward;
  if(glow!=null)for(int i=0;i<glow.Length;i++){float t=Mathf.Clamp01((p-.1f-i*.055f)/.49f);float h=EnemyImpactEnvelope20260921.Sample(Mathf.Clamp01((p-.59f)/.41f));bool core=role=="core";float a=core?Mathf.Sin(t*Mathf.PI):Mathf.Sin(h*Mathf.PI)*(1-h);float ang=i*2.399963f;glow[i].transform.position=core?Path(s,t,i,r,u):s.Target+(r*Mathf.Cos(ang)+u*Mathf.Sin(ang))*h*(i==0?0:1.2f)-f*.12f;glow[i].transform.rotation=cam?cam.transform.rotation:Quaternion.identity;glow[i].transform.localScale=Vector3.one*(core?1.35f:(1.8f+h*3.25f)*(1+.65f*EnemyImpactEnvelope20260921.Burst(h)));Color c=violet?new Color(.58f,.16f,1f,a*.83f):new Color(.12f,.72f,1f,a*.83f);glowMats[i].SetColor("_Color",c);}
  for(int i=0;i<lines.Length;i++){var l=lines[i];int n=violet?i%3:0;float t=Mathf.Clamp01((p-.1f-n*.055f)/.49f);float alpha=0;
   if(role=="core"){alpha=Mathf.Sin(t*Mathf.PI)*.85f;float radius=.10f+(i/3)*.055f;for(int j=0;j<40;j++){float a=j/39f*Mathf.PI*2;var orbit=r*Mathf.Cos(a)+u*Mathf.Sin(a);l.SetPosition(j,Path(s,t,n,r,u)+orbit*radius+f*Mathf.Sin(a*2+p*12)*radius*.45f);}l.widthMultiplier=i<3?.32f:.12f;}
   else if(role=="direction"){alpha=Mathf.Sin(t*Mathf.PI)*.65f;for(int j=0;j<40;j++){float q=j/39f;float v=Mathf.Clamp01(t-q*.3f);l.SetPosition(j,Path(s,v,n,r,u)+(r*Mathf.Cos(q*8+i)+u*Mathf.Sin(q*8+i))*.055f*Mathf.Sin(q*Mathf.PI));}l.widthMultiplier=.32f;l.widthCurve=AnimationCurve.Linear(0,1,1,0);}
   else {float h=EnemyImpactEnvelope20260921.Sample(Mathf.Clamp01((p-.59f)/.41f));alpha=Mathf.Sin(h*Mathf.PI)*(1-h);float angle=i*2.399963f+h*1.5f;for(int j=0;j<40;j++){float q=j/39f;Vector3 pos;if(i<1){float a=q*Mathf.PI*1.45f+i*2.1f;float radius=(.2f+Mathf.Sqrt(h)*2.45f)*(1-i*.14f);pos=s.Target+(r*Mathf.Cos(a)+u*Mathf.Sin(a))*radius+f*Mathf.Sin(a*3+h*9)*.10f;}else {var axis=r*Mathf.Cos(angle)+u*Mathf.Sin(angle);pos=s.Target+axis*(.15f+(1-Mathf.Exp(-h*7))*(1.5f+i*.1f)+q*.65f)+(u*Mathf.Sin(q*5+i+h*8))*.24f+f*Mathf.Sin(q*4+i)*.35f;}l.SetPosition(j,pos);}l.widthMultiplier=i<2?.42f:.32f;}
   Color c=violet?new Color(.62f,.22f,1f,alpha):new Color(.18f,.8f,1f,alpha);l.startColor=Color.Lerp(c,new Color(.8f,.95f,1,alpha),i%3==0?.55f:0);l.endColor=new Color(c.r,c.g,c.b,alpha*.25f);
  }
 }
 public void Interrupt()=>Cleanup();
 public void Cleanup(){if(glow!=null)foreach(var g in glow)if(g)Destroy(g);glow=null;if(glowMats!=null)foreach(var m in glowMats)if(m)Destroy(m);glowMats=null;if(lines!=null)foreach(var l in lines)if(l)Destroy(l.gameObject);lines=null;if(mat)Destroy(mat);mat=null;}
 void OnDestroy(){if(mat)Destroy(mat);}
}}
