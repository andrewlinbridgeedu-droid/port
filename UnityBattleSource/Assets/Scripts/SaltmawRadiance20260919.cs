using System.Collections.Generic;
using UnityEngine;
// Finite, owned light ribbons. Effekseer remains responsible for mist and impact particles.
public sealed class SaltmawRadiance20260919:MonoBehaviour {
 readonly List<LineRenderer> ribbons=new List<LineRenderer>();readonly List<Material> materials=new List<Material>();readonly List<LineRenderer> cracks=new List<LineRenderer>();Light glow; readonly List<LineRenderer> sparks=new List<LineRenderer>();
 public void Build(){for(int i=0;i<9;i++){var g=new GameObject("Salt spectral filament");g.transform.SetParent(transform,false);var l=g.AddComponent<LineRenderer>();l.positionCount=48;l.widthCurve=new AnimationCurve(new Keyframe(0,0),new Keyframe(.22f,1),new Keyframe(.7f,.45f),new Keyframe(1,0));l.useWorldSpace=true;l.numCapVertices=4;l.numCornerVertices=3;var m=new Material(Resources.Load<Shader>("Shaders/SaltmawLuminousSheet"));m.renderQueue=3000;l.sharedMaterial=m;materials.Add(m);ribbons.Add(l);}for(int i=0;i<24;i++){var g=new GameObject("Salt crystal streak");g.transform.SetParent(transform,false);var l=g.AddComponent<LineRenderer>();l.positionCount=2;l.useWorldSpace=true;l.sharedMaterial=materials[i%materials.Count];l.widthMultiplier=.018f+(i%3)*.009f;sparks.Add(l);}for(int i=0;i<8;i++){var g=new GameObject("Salt branching rupture");g.transform.SetParent(transform,false);var l=g.AddComponent<LineRenderer>();l.positionCount=9;l.useWorldSpace=true;l.sharedMaterial=materials[i%materials.Count];l.widthCurve=new AnimationCurve(new Keyframe(0,.6f),new Keyframe(.2f,1),new Keyframe(1,0));cracks.Add(l);}glow=new GameObject("Salt dynamic radiance").AddComponent<Light>();glow.transform.SetParent(transform,false);glow.type=LightType.Point;glow.range=6;glow.color=new Color(.25f,1,.65f);}
 public void Draw(Vector3 mouth,Vector3 tip,Vector3 target,float age,float contact,bool held,bool poison){if(!held)age=TowerImpactTiming20260921.Sample(age,contact,poison?.055f:.095f);if(poison&&!held){DrawPoison(mouth,tip,target,age,contact);return;}float post=age-contact;float fade=held?1:post<0?1:Mathf.Exp(-post*5);var axis=(target-mouth).normalized;var side=Vector3.Cross(axis,Vector3.up).normalized;var up=Vector3.Cross(side,axis).normalized;var center=held?mouth:post<0?tip:target;glow.transform.position=center;glow.intensity=fade*(post>=0?4.5f:1.25f);
 for(int i=0;i<ribbons.Count;i++){
 var l=ribbons[i];float seed=Hash(i+3), phase=Hash(i+91);float a=seed*Mathf.PI*2;
 var dir=(side*Mathf.Cos(a)+up*Mathf.Sin(a)+axis*(Hash(i+35)-.5f)*1.4f).normalized;
 var bend=Vector3.Cross(dir,axis).normalized;
 float t=held?Mathf.Repeat(age*(1.3f+seed)+phase,1):post<0?Mathf.Repeat(age*2+phase,1):Mathf.Max(0,post-phase*.09f);
 float life=held?Mathf.Sin(t*Mathf.PI):post<0?1:Mathf.Exp(-t*(3+seed*3));
 var color=i%3==0?new Color(.3f,1,.48f):i%3==1?new Color(.2f,.75f,1):new Color(1,.72f,.2f);
 color*=1.78f;color.a=life*(i%4==0?.95f:.6f);l.startColor=l.endColor=color;l.widthMultiplier=(i%3==0?.65f:.36f)*(!held&&post>=0?1.35f:1);
 float length=1.32f+Hash(i+63)*1.87f;
 for(int j=0;j<48;j++){
 float q=j/47f;float jag=(Mathf.PerlinNoise(q*5+seed*31,Mathf.Floor(age*14)*.2f)-.5f)*.3f*Mathf.Sin(q*Mathf.PI);
 Vector3 p;
 if(post>=0&&!held){float distance=(1-Mathf.Exp(-t*23))*(1.45f+seed*1.1f);p=center+dir*(distance+q*length*.8f)+bend*(jag+q*q*(phase-.5f)*.6f)+Vector3.down*t*t*2;}
 else if(held){p=mouth+dir*(.08f+t*.45f+q*length)+bend*jag+Vector3.up*q*q*.3f;}
 else {p=center-axis*q*(1.2f+length)+dir*q*(.15f+seed*.7f)+bend*jag;}
 l.SetPosition(j,p);
 }}
 for(int i=0;i<sparks.Count;i++){
 float seed=Hash(i+201),phase=Hash(i+411),a=seed*Mathf.PI*2;
 var dir=(side*Mathf.Cos(a)+up*Mathf.Sin(a)+axis*(Hash(i+531)-.5f)*1.7f).normalized;
 float t=held?Mathf.Repeat(age*(1+seed*2)+phase,1):post<0?Mathf.Repeat(age*2.5f+phase,1):Mathf.Max(0,post-phase*.12f);
 float radius=held?t*(1.1f+seed*2):post<0?t*(.5f+seed*1.3f):t*(7+seed*12);
 var pos=center+dir*radius;if(!held&&post<0)pos-=axis*t*2;
 if(!held&&post>=0)pos+=Vector3.down*t*t*3;
 var c=i%3==0?new Color(1,.75f,.24f):i%3==1?new Color(.2f,.9f,1):new Color(.45f,1,.6f);
 c*=1.7f;c.a=(held?1-t:post<0?1:Mathf.Exp(-t*4))*.9f;
 sparks[i].startColor=c;c.a=0;sparks[i].endColor=c;
 sparks[i].SetPosition(0,pos);sparks[i].SetPosition(1,pos-dir*(.1f+Hash(i+711)*.4f));
 }
 // Two irregular rupture fronts with forked tips. Owned by the same cancellable visual.
 for(int i=0;i<cracks.Count;i++){
 int branch=i/2;float seed=Hash(branch+803);float a=seed*Mathf.PI*2;
 var dir=(side*Mathf.Cos(a)+up*Mathf.Sin(a)+axis*(Hash(branch+902)-.5f)*.55f).normalized;
 var bend=Vector3.Cross(dir,axis).normalized;
 bool impact=!held&&post>=0;float local=impact?post-(branch%3)*.045f:Mathf.Repeat(age*1.8f+Hash(branch+993),1);
 float flash=impact?(local<0?0:Mathf.Exp(-local*6)):(.35f+.65f*Mathf.Pow(Mathf.Max(0,Mathf.Sin(local*Mathf.PI)),3));
 float span=(1.1f+Hash(branch+723)*1.9f)*(impact?1.15f:held?.8f:.6f);
 float advance=impact?Mathf.Max(0,local)*3:0;
 var l=cracks[i];l.widthMultiplier=i%2==0?.12f:.06f;
 var col=Color.Lerp(new Color(.65f,1,.9f),new Color(1,.94f,.65f),seed)*2.3f;col.a=flash*.9f;l.startColor=col;col.a=0;l.endColor=col;
 for(int j=0;j<9;j++){
 float q=j/8f;float start=i%2==0?0:.5f;float v=start+q*(1-start);
 float zig=(Hash(branch*17+j+1261)-.5f)*.4f*Mathf.Sin(v*Mathf.PI);
 float fork=i%2==0?0:q*(Hash(branch+477)>.5f?1:-1)*span*.45f;
 l.SetPosition(j,center+dir*(advance+v*span)+bend*(zig+fork));
 }
 }

 }
 void DrawPoison(Vector3 mouth,Vector3 tip,Vector3 target,float age,float contact){
  float post=age-contact,life=post<0?Mathf.Clamp01(age/.15f):Mathf.Exp(-post*3.8f);
  var axis=(target-mouth).normalized;var side=Vector3.Cross(axis,Vector3.up).normalized;
  float impact=post<0?0:Mathf.SmoothStep(0,1,post/.045f);
  glow.transform.position=post<0?tip:target;glow.color=new Color(.48f,.9f,.13f);glow.intensity=life*(1.5f+impact*3);
  for(int i=0;i<9;i++){
   var l=ribbons[i];float seed=Hash(i+15);l.widthMultiplier=i<3?.75f:.18f;
   Color c=i<3?new Color(.48f,.82f,.12f):new Color(.76f,1,.31f);c.a=life*(i<3?.6f:.4f);l.startColor=l.endColor=c;
   for(int j=0;j<48;j++){
    float q=j/47f;Vector3 p;
    if(post<0){p=Vector3.Lerp(mouth,tip,q)+side*Mathf.Sin(q*7-age*5+i*2)*q*(.15f+seed*.35f)+Vector3.up*Mathf.Sin(q*5+i)*q*.17f;}
    else{float a=i*2.399f+q*2.2f;float r=(.2f+impact*1.9f+q*.7f)*(i<3?1:1.1f);p=target+new Vector3(Mathf.Cos(a)*r,Mathf.Sin(q*Mathf.PI)*.65f-post*.8f,Mathf.Sin(a)*r*.65f);}
    l.SetPosition(j,p);
   }
  }
  for(int i=0;i<24;i++){
   float t=Mathf.Max(0,post),a=i*2.399f;var d=new Vector3(Mathf.Cos(a),.6f+Hash(i),Mathf.Sin(a));
   var p=target+d*t*(3.2f+i%4*1.3f)-Vector3.up*t*t*4;
   var c=new Color(.76f,1,.24f,post>=0?life:.0f);sparks[i].widthMultiplier=.045f+(i%3)*.025f;sparks[i].startColor=c;c.a=0;sparks[i].endColor=c;
   sparks[i].SetPosition(0,p);sparks[i].SetPosition(1,p+Vector3.up*.12f);
  }
  foreach(var l in cracks){l.startColor=l.endColor=Color.clear;}
 }
 static float Hash(int n){return Mathf.Repeat(Mathf.Sin(n*127.1f+31.7f)*43758.5453f,1);}
 void OnDestroy(){foreach(var m in materials)if(m)Destroy(m);}
}
