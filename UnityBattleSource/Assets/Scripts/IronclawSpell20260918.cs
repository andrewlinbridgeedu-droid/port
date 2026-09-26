using System;
using System.Collections.Generic;
using UnityEngine;
// D04 choreography and VFX share one clock. Gameplay contact stays with the caller.
[DefaultExecutionOrder(1800)]
public sealed class IronclawSpell20260918:MonoBehaviour {
 sealed class Bone { public Transform t; public Quaternion rest; }
 sealed class Strip { public Mesh mesh; public Material mat; public Transform t; public Vector3[] vertices=new Vector3[82]; public Vector2[] uv=new Vector2[82]; public int[] triangles=new int[240]; }
 readonly Dictionary<string,Bone> bones=new Dictionary<string,Bone>();
 readonly List<Strip> strips=new List<Strip>();
 readonly List<Transform> motes=new List<Transform>();
 readonly List<Material> materials=new List<Material>();
 readonly List<Mesh> meshes=new List<Mesh>();
 readonly List<Transform> tempestClouds=new List<Transform>(); readonly List<Transform> clouds=new List<Transform>(); Light castLight,hitLight,offhandLight; readonly List<Transform> glints=new List<Transform>(); Transform sigil,sigil2;
 TowerRigRound2 rig; TowerSurfaceRound2 cutSkin;
 EnemyHandle actor; Func<Vector3> target; string intent; float age,contact; bool heavy,second,held;
 Vector3 launch,launch2; bool launched; Transform blade,blade2; Material bladeMat;
 static readonly Color Acid=new Color(.45f,1,.15f),Ice=new Color(.28f,.86f,.94f),Ivory=new Color(1,.91f,.62f);
 Quaternion Face=>Camera.main?Quaternion.LookRotation(Camera.main.transform.forward):Quaternion.identity;
 public static IronclawSpell20260918 Create(EnemyHandle actor,string intent,Func<Vector3> target,float contact,Transform owner) {
  var go=new GameObject("D04 articulated spell");go.transform.SetParent(owner,false);var v=go.AddComponent<IronclawSpell20260918>();v.actor=actor;v.intent=intent;v.target=target;v.contact=contact;v.heavy=intent=="tower_heavy_cut"||intent=="tower_raised_blade";v.second=intent=="tower_cut_second";v.held=intent.Contains("charge")||intent=="tower_raised_blade";
  foreach(var t in actor.VisualRoot.GetComponentsInChildren<Transform>(true))if(t.name=="Chest"||t.name=="Head"||t.name.StartsWith("UpperArm.")||t.name.StartsWith("Forearm.")||t.name.StartsWith("Hand."))v.bones[t.name]=new Bone{t=t,rest=t.localRotation};
  v.rig=new TowerRigRound2(actor.VisualRoot,v.gameObject);v.cutSkin=new TowerSurfaceRound2(go.transform,12,"ChurchSpellArt/sickle");
  for(int i=0;i<44;i++)v.strips.Add(v.MakeStrip());
  for(int i=0;i<160;i++)v.motes.Add(v.MakeMote(i));
  for(int i=0;i<6;i++){var cloud=v.MakeMote(100+i);cloud.name="Organic blade flare "+i;var mat=cloud.GetComponent<Renderer>().sharedMaterial;mat.shader=Resources.Load<Shader>("Shaders/ChurchDetonation");mat.SetFloat("_Gather",i<2?1:0);v.clouds.Add(cloud);}
  for(int i=0;i<12;i++){var w=v.MakeMote(400+i);w.name="Airborne torn energy "+i;var m=w.GetComponent<Renderer>().sharedMaterial;m.shader=Resources.Load<Shader>("Shaders/ChurchDetonation");m.SetFloat("_Gather",1);v.tempestClouds.Add(w);}
  v.sigil=v.MakeMote(200);v.sigil2=v.MakeMote(201);
  foreach(var shape in new[]{v.sigil,v.sigil2}){var m=shape.GetComponent<Renderer>().sharedMaterial;m.mainTexture=Resources.Load<Texture2D>("ChurchSpellArt/sickle");m.SetFloat("_Luma",0);m.SetFloat("_Dst",10);}
  for(int i=0;i<5;i++){var glint=v.MakeMote(300+i);glint.name="Blade spectral glint "+i;glint.GetComponent<Renderer>().sharedMaterial.shader=Resources.Load<Shader>("Shaders/IronclawRadiance");v.glints.Add(glint);}
  v.offhandLight=v.MakeLight("Offhand blade light");v.offhandLight.color=Ice;
  v.castLight=v.MakeLight("Blade casting light");v.hitLight=v.MakeLight("Cut impact light");
  var asset=Resources.Load<GameObject>("ChurchSpellArt/IronclawBlade");
  if(asset){v.blade=new GameObject("Primary physical blade").transform;v.blade.SetParent(go.transform,false);Instantiate(asset,v.blade,false);v.blade2=new GameObject("Secondary physical blade").transform;v.blade2.SetParent(go.transform,false);Instantiate(asset,v.blade2,false);} 
  v.bladeMat=new Material(Shader.Find("Standard"));v.bladeMat.color=new Color(.16f,.24f,.055f);v.bladeMat.SetFloat("_Metallic",.7f);v.bladeMat.SetFloat("_Glossiness",.65f);v.bladeMat.EnableKeyword("_EMISSION");v.bladeMat.SetColor("_EmissionColor",new Color(.10f,.32f,.015f));v.materials.Add(v.bladeMat);
  if(v.blade)foreach(var r in v.blade.GetComponentsInChildren<Renderer>()){var m=new Material(r.sharedMaterial);m.EnableKeyword("_EMISSION");m.SetColor("_EmissionColor",new Color(.05f,.15f,.01f));r.sharedMaterial=m;v.materials.Add(m);}
  if(v.blade2)foreach(var r in v.blade2.GetComponentsInChildren<Renderer>()){var m=new Material(r.sharedMaterial);m.EnableKeyword("_EMISSION");m.SetColor("_EmissionColor",new Color(.05f,.15f,.01f));r.sharedMaterial=m;v.materials.Add(m);}
  return v;
 }
 Light MakeLight(string name){var g=new GameObject(name);g.transform.SetParent(transform,false);var l=g.AddComponent<Light>();l.type=LightType.Point;l.color=Acid;l.range=3.6f;l.shadows=LightShadows.None;l.intensity=0;return l;}
 Material Mat(string tex){var m=new Material(Resources.Load<Shader>("Shaders/ChurchFilament"));m.mainTexture=Resources.Load<Texture2D>(tex);m.SetFloat("_Luma",1);m.SetFloat("_Dst",1);m.SetColor("_Color",Color.clear);materials.Add(m);return m;}
 Strip MakeStrip(){var go=new GameObject("Torn flowing edge");go.transform.SetParent(transform,false);var mesh=new Mesh();mesh.MarkDynamic();meshes.Add(mesh);var m=Mat("Effects/Mistport/Official/Slashing/Line01");m.SetFloat("_Ribbon",1);go.AddComponent<MeshFilter>().sharedMesh=mesh;go.AddComponent<MeshRenderer>().sharedMaterial=m;return new Strip{mesh=mesh,mat=m,t=go.transform};}
 Transform MakeMote(int i){var go=GameObject.CreatePrimitive(PrimitiveType.Quad);Destroy(go.GetComponent<Collider>());go.name="Corrosive shard "+i;go.transform.SetParent(transform,false);go.GetComponent<Renderer>().sharedMaterial=Mat("Effects/Mistport/Official/Slashing/Particle02");return go.transform;}
 void Pose(string name,Vector3 angle){rig.Rotate(name,angle);}
 Vector3 Hand(string side){return bones.TryGetValue("Hand."+side,out var b)&&b.t?b.t.position:actor.EffectAnchor.position;}
 public void Tick(float time){age=held?Mathf.Max(0,time):TowerImpactTiming20260921.Sample(Mathf.Max(0,time),contact,heavy?.110f:second?.075f:.060f);}
 // Contact-only overshoot: fast expansion followed by a short settling tail.
 float ImpactScale(float post){return post<0?1:1+(heavy?4.4f:second?3.7f:3.3f)*Mathf.SmoothStep(0,1,post/.042f)*(1-Mathf.SmoothStep(0,1,(post-.12f)/.26f));}
 void Update(){if(!restored)rig?.Reset();}
 void LateUpdate(){if(restored||!actor||!actor.gameObject.activeInHierarchy)return;if(held)age+=Time.deltaTime;rig.Capture();Animate();Draw();}
 void Animate(){
  float release=heavy?.46f:.22f;
  float load=held?Mathf.SmoothStep(0,1,age/.3f):Mathf.SmoothStep(0,1,age/release);
  float swing=held?0:Mathf.SmoothStep(0,1,(age-release)/Mathf.Max(.05f,contact-release));
  float settle=held?1:1-Mathf.SmoothStep(0,1,(age-contact-.10f)/.38f);
  float turn=heavy?-5*load+9*swing:second?-20*load+43*swing:15*load-32*swing;
  float crouch=load*(1-.67f*swing);
  Pose("Pelvis",new Vector3(6*crouch-5*swing,turn,second?-4*load+8*swing:3*load-6*swing)*settle);
  Pose("Thigh.L",new Vector3(-21*crouch+8*swing,-turn*.19f,-3*load)*settle);
  Pose("Thigh.R",new Vector3(-29*crouch+13*swing,-turn*.23f,4*load)*settle);
  Pose("Shin.L",new Vector3(28*crouch-8*swing,0,0)*settle);
  Pose("Shin.R",new Vector3(37*crouch-13*swing,0,0)*settle);
  Pose("Foot.L",new Vector3(-7*crouch,0,0)*settle);Pose("Foot.R",new Vector3(-9*crouch,0,0)*settle);
  float rise=heavy&&!held?TowerRigRound2.Ease((age-.19f)/.18f)*(1-TowerRigRound2.Ease((age-.44f)/Mathf.Max(.05f,contact-.44f))):0;
  float land=heavy&&!held?TowerRigRound2.Ease((age-contact)/.045f)*(1-TowerRigRound2.Ease((age-contact-.10f)/.18f)):0;
  rig.ShiftWorld("Pelvis",Vector3.up*((-.045f*crouch+.14f*rise-.075f*land)*settle));
  if(heavy){
   Pose("Chest",new Vector3(-22*load+56*swing,0,0)*settle);
   Pose("Head",new Vector3(-15*load+30*swing,0,0)*settle);
   foreach(string side in new[]{"R","L"}){float sign=side=="R"?1:-1;
    Pose("UpperArm."+side,new Vector3(-125*load+155*swing,0,sign*(25*load-43*swing))*settle);
    Pose("Forearm."+side,new Vector3(-18*load+48*swing,0,sign*12*swing)*settle);
    Pose("Hand."+side,new Vector3(23*load-48*swing,sign*12*swing,sign*9*swing)*settle);
   }
  }else if(second){
   Pose("Chest",new Vector3(8*load,-48*load+100*swing,-10*load+20*swing)*settle);
   Pose("Head",new Vector3(0,22*load-40*swing,0)*settle);
   Pose("UpperArm.L",new Vector3(-32*load,65*load-135*swing,-78*load+38*swing)*settle);
   Pose("Forearm.L",new Vector3(18*load,-30*load+70*swing,0)*settle);
   Pose("UpperArm.R",new Vector3(20*load,-25*load,35*load)*settle);
   Pose("Forearm.R",new Vector3(45*load,0,0)*settle);
   Pose("Hand.L",new Vector3(12*load-28*swing,26*load-48*swing,-12*load+24*swing)*settle);
  }else{
   Pose("Chest",new Vector3(-8*load+32*swing,30*load-62*swing,10*load-20*swing)*settle);
   Pose("Head",new Vector3(-10*load+20*swing,-12*load,0)*settle);
   Pose("UpperArm.R",new Vector3(-110*load+158*swing,22*load-45*swing,32*load-48*swing)*settle);
   Pose("Forearm.R",new Vector3(-15*load+50*swing,0,0)*settle);
   Pose("UpperArm.L",new Vector3(15*load,0,-20*load)*settle);
   Pose("Forearm.L",new Vector3(38*load,0,0)*settle);
   Pose("Hand.R",new Vector3(18*load-32*swing,-12*load+24*swing,8*load-17*swing)*settle);
  }
 }

 void Ribbon(int i,Func<float,Vector3> path,float width,Color c,float alpha){var l=strips[i];const int n=40;var vs=l.vertices;var uv=l.uv;var ts=l.triangles;var forward=Camera.main?Camera.main.transform.forward:Vector3.forward;
  for(int j=0;j<=n;j++){float q=j/(float)n;var p=path(q);var tangent=path(Mathf.Min(1,q+.015f))-path(Mathf.Max(0,q-.015f));var normal=Vector3.Cross(tangent,forward).normalized;float w=width*1.18f*Mathf.Pow(Mathf.Max(0,Mathf.Sin(q*Mathf.PI)),.7f)*(1+.18f*Mathf.Sin(q*31+age*17+i));vs[j*2]=p-normal*w;vs[j*2+1]=p+normal*w;uv[j*2]=new Vector2(0,q);uv[j*2+1]=new Vector2(1,q);if(j<n){int k=j*6,a=j*2;ts[k]=a;ts[k+1]=a+2;ts[k+2]=a+1;ts[k+3]=a+1;ts[k+4]=a+2;ts[k+5]=a+3;}}
  l.mesh.Clear();l.mesh.vertices=vs;l.mesh.uv=uv;l.mesh.triangles=ts;l.mesh.RecalculateBounds();c.a=Mathf.Clamp01(alpha);l.mat.SetColor("_Color",c);
 }
 Vector3 Flight(Vector3 start,Vector3 end,float q,int side){return Vector3.Lerp(start,end,q)+Face*new Vector3(Mathf.Sin(q*Mathf.PI)*(heavy?side*.85f:second?-2.0f:0),Mathf.Sin(q*Mathf.PI)*(heavy?.25f:second?.05f:.12f),0);}
 void Draw(){cutSkin.Hide();foreach(var s in strips)s.mat.SetColor("_Color",Color.clear);foreach(var t in motes)t.GetComponent<Renderer>().sharedMaterial.SetColor("_Color",Color.clear);
  float release=heavy?.46f:.22f;float wind=held?1:Mathf.Clamp01(age/.10f)*(1-Mathf.Clamp01((age-release)/.15f));
  var right=Hand(second?"L":"R");var left=Hand(second?"R":"L");var end=target();
  if(!launched&&!held&&age>=release){launched=true;launch=right;launch2=left;}
  for(int h=0;h<(heavy?2:1);h++){var hand=h==0?right:left;
   for(int k=0;k<3;k++){int j=k;Ribbon(h*3+k,q=>hand+new Vector3(Mathf.Cos(q*2.6f+age*5+j*2.1f)*(.08f+q*.32f),Mathf.Sin(q*3.1f+age*5+j*1.8f)*(.09f+q*.35f),q*.18f),k==0?.065f:.023f,k==0?Acid:Ice,wind*(k==0?.9f:.55f));}
  }
  float f=Mathf.Clamp01((age-release)/Mathf.Max(.05f,contact-release));float post=held?-1:age-contact;
  float travel=launched&&post<.07f?1:0;
  for(int c=0;c<6;c++){var cloud=clouds[c];bool cast=c<2;float tail=Mathf.Max(0,post-(c-2)*.025f);float alpha=cast?wind*(c==1&&!heavy?.2f:1):post>=0?Mathf.Exp(-tail*(c==2?16:5))*1.3f:0;cloud.position=cast?(c==0?right:left):end+Face*new Vector3(Mathf.Sin(c*6.1f)*tail*.7f,Mathf.Cos(c*4.2f)*tail*.7f,-.04f*c);cloud.rotation=Face*Quaternion.Euler(0,0,c*97+age*31);float size=cast?1.1f+wind*.5f:c==2?.4f+tail*9:1.1f+tail*4;cloud.localScale=new Vector3(size*(cast?1:heavy?1:second?1.65f:.18f),size*(cast?1:heavy?1:second?.16f:1.35f),1)*(cast?1:ImpactScale(post));if(!cast&&!heavy)cloud.rotation=Face*Quaternion.Euler(0,0,second?0:-44);var m=cloud.GetComponent<Renderer>().sharedMaterial;var color=c==2?Ivory:c==4?Ice:Acid;color.a=alpha*(cast?1:c==2?.54f:.40f);m.SetColor("_Color",color);m.SetFloat("_Age",cast?age:tail);}
  castLight.transform.position=right;castLight.intensity=wind*(3.2f+.65f*Mathf.Sin(age*17));offhandLight.transform.position=left;offhandLight.intensity=heavy?wind*2.8f:0;hitLight.transform.position=end;hitLight.intensity=post>=0?Mathf.Exp(-post*21)*(heavy?6.8f:5.6f):0;hitLight.color=Color.Lerp(Ivory,Ice,Mathf.Clamp01(post*5));// Compact layered radiance: hand cores, release snap, and a brief impact bloom.
  // Follow live hands before launch; avoid a persistent sheet across the battlefield.
  for(int g=0;g<5;g++){var glow=glints[g];float strength,scale;
   if(g<2){glow.position=g==0?right:left;strength=wind*(g==1&&!heavy?0:1)*(.72f+.18f*Mathf.Sin(age*23+g));scale=.72f+wind*.35f;}
   else if(g==2){float snap=age-release;glow.position=launched?launch:right;strength=!held&&snap>=0?Mathf.Exp(-snap*24):0;scale=1.2f+Mathf.Max(0,snap)*3;}
   else{glow.position=end-Face*Vector3.forward*(.04f*g);strength=!held&&post>=0?Mathf.Exp(-post*(g==3?17:6))*(heavy?1.1f:.85f):0;scale=g==3?2.25f+Mathf.Max(0,post)*6:2.8f+Mathf.Max(0,post)*3;}
   glow.rotation=Face*Quaternion.Euler(0,0,g*73+age*(g<2?27:9));glow.localScale=new Vector3(scale*1.13f,scale*1.13f,1)*(g<3?1:1+(ImpactScale(post)-1)*.55f);var gm=glow.GetComponent<Renderer>().sharedMaterial;var tint=g==4?Ice:Ivory;tint.a=strength*(g<3?1:heavy?.38f:.24f);gm.SetColor("_Color",tint);gm.SetFloat("_Age",age+g*1.7f);
  }
  float fade=1-Mathf.Clamp01(Mathf.Max(0,post)/.52f);
  float impactScale=ImpactScale(post);
  for(int b=0;b<(heavy?2:1);b++){int bi=b;Vector3 from=b==0?launch:launch2;Vector3 pos=Flight(from,end,f,b==0?1:-1);var card=b==0?sigil:sigil2;card.position=pos-Face*Vector3.forward*.025f;card.rotation=Face*Quaternion.Euler(0,0,(second?-90:-44)+(heavy?b*95:0)+f*(heavy?170:second?280:0));card.localScale=new Vector3(1.15f,1.15f,1)*(heavy?1.12f:1);card.GetComponent<Renderer>().sharedMaterial.SetColor("_Color",new Color(.8f,1,.75f,travel*.38f));var model=b==0?blade:blade2;if(model){model.gameObject.SetActive(travel>0);model.position=pos;model.rotation=Face*Quaternion.Euler(0,0,(second?-90:-44)+(heavy?b*95:0)+f*(heavy?170:second?280:0));model.localScale=Vector3.one*(heavy?.65f:.53f);}
   // T43's opposing half-orbits joined into a closed-looking ring. Leave these
   // auxiliaries hidden; retain the painted jaws, physical blades and open wakes.
   if(intent!="tower_heavy_cut")for(int k=0;k<4;k++){int strand=k;float tilt=(second?-1:1)*(heavy?(b==0?-.8f:.8f):.3f);
    Ribbon(6+b*4+k,q=>{float a=Mathf.Lerp(-1.8f,1.25f,q)+tilt;float r=.62f+strand*.055f+.035f*Mathf.Sin(q*18+age*12+strand);return pos+Face*(heavy?new Vector3(Mathf.Cos(a)*r,Mathf.Sin(a)*r,0):second?new Vector3(Mathf.Cos(a)*r*2.1f,Mathf.Sin(a)*r*.65f,0):new Vector3((q-.5f)*1.35f,(q-.5f)*1.65f+strand*.045f,0))+Vector3.forward*strand*.015f;},k==0?.14f:.028f,k==0?Acid:k==1?Ivory:Ice,travel*(k<2?1:.6f));
   }
   if(launched)Ribbon(14+b,q=>Flight(from,end,Mathf.Lerp(Mathf.Max(0,f-.43f),f,q),bi==0?1:-1),.065f,Ice,travel*.6f);
  }
  if(!heavy)sigil2.gameObject.SetActive(false);
  if(blade2&&!heavy)blade2.gameObject.SetActive(false);
  if(post>=0&&!held){ChurchImpactLens20260917.Request(this,post,heavy?.95f:.5f);
   for(int k=0;k<(heavy?2:1);k++){int j=k;float tilt=second?0:heavy?(j==0?-.78f:.78f):.95f;
    Ribbon(16+k,q=>{float x=(q-.47f)*(1.3f+post*2.8f)*impactScale;float bend=Mathf.Sin(q*5.7f+j*.8f)*.11f*impactScale;return end+Face*new Vector3(x,(second?Mathf.Sin(q*2.7f+.15f)*.60f*impactScale:bend)+x*tilt,Mathf.Sin(q*Mathf.PI)*.10f*impactScale);},.052f*impactScale,Ivory,fade*.78f);
   }
  }

  Tempest((right+left)*.5f,end,post,wind);
  for(int i=0;i<64;i++){var m=motes[i];float seed=i*2.39996f;Vector3 p;float a,size;
   if(i<20){float q=Mathf.Repeat(age*2+i*.137f,1);var hand=heavy&&i%2==0?left:right;p=hand+new Vector3(Mathf.Cos(seed+age*3),Mathf.Sin(seed+age*4),Mathf.Sin(seed*2)*.4f)*(.12f+(1-q)*.6f);a=wind*q;size=.025f+q*.05f;}
   else {float t=Mathf.Max(0,post-(i%5)*.008f);var dir=Face*(heavy?new Vector3(Mathf.Cos(seed),Mathf.Sin(seed)*.7f,Mathf.Sin(seed*1.7f)*.3f):second?new Vector3(Mathf.Cos(seed)*1.8f,Mathf.Sin(seed)*.18f,0):new Vector3(Mathf.Cos(seed)*.8f,Mathf.Cos(seed)*1.2f,Mathf.Sin(seed)*.1f));p=end+dir*t*(2.3f+(i%7)*.39f)+Vector3.down*t*t*2;a=post>=0?fade:0;size=i%9==0?.24f:.035f+(i%4)*.017f;}
   m.position=p;m.rotation=Face*Quaternion.Euler(0,0,seed*57.3f+age*110);m.localScale=new Vector3(size,size*(i%3==0?4:1),1);var c=i%4==0?Ivory:i%3==0?Ice:Acid;c.a=a*.85f;m.GetComponent<Renderer>().sharedMaterial.SetColor("_Color",c);
  }
 }
 // Painted cutting lips retain diagonal / return arc / closing shear identity.
 // Their topology and short branching details replace the old parallel rail rack.
 void Tempest(Vector3 caster,Vector3 end,float post,float wind){
  foreach(var cloud in tempestClouds)cloud.gameObject.SetActive(false);
  float release=heavy?.46f:.22f;if(held||age<release)return;
  float travel=Mathf.Clamp01((age-release)/Mathf.Max(.05f,contact-release));
  float presence=1-Mathf.SmoothStep(0,1,(post-.10f)/.45f);
  Vector3 center=Vector3.Lerp(caster,end,travel);
  float burst=ImpactScale(post);
  int jaws=heavy?2:1;
  for(int jaw=0;jaw<jaws;jaw++){
   float sign=jaw==0?-1:1;
   float tilt=heavy?sign*43:second?-84:-42;
   for(int part=0;part<3;part++){
    int index=jaw*3+part;
    float fraction=part==0?1:part==1?.63f:.43f;
    float offset=part==0?0:part==1?-.29f:.37f;
    Quaternion frame=Face*Quaternion.Euler(0,sign*(part*8+Mathf.Max(0,post)*65),tilt+part*3.4f);
    Vector3 position=center+frame*new Vector3(sign*Mathf.Max(0,post)*1.5f,(offset+.04f*Mathf.Sin(part*7.1f))*burst,part*.08f);
    cutSkin.Leaf(index,position,frame,new Vector2((part==0?.79f:.44f)*burst,(heavy?3.1f:second?3.3f:2.8f)*fraction*burst),
     part==0?new Color(.38f,.92f,.19f):part==1?new Color(.21f,.73f,.57f):new Color(.70f,.94f,.27f),
     presence*(part==0?.94f:.72f),age,second?.42f:.30f,null,Mathf.Max(0,post-.10f)*1.8f);
    // A narrow white-cyan incision stays embedded in the sickle material.
    // The first diagonal, horizontal return and two-jaw shear keep their
    // existing paths; this is not a shared screen-wide burst overlay.
    cutSkin.Leaf(6+index,position+Face*new Vector3(0,0,-.035f),frame,
     new Vector2((part==0?.22f:.13f)*burst,(heavy?2.88f:second?3.03f:2.54f)*fraction*burst),
     part==1?new Color(.72f,1,.94f):new Color(1,1,.78f),
     presence*(part==0?.82f:.56f),age,second?.30f:.24f,null,Mathf.Max(0,post-.10f)*2.1f);
   }
  }
  for(int k=0;k<6;k++){
   int branch=k;float sign=heavy?(k%2==0?-1:1):second?1:-1;
   float t=Mathf.Max(0,post),alpha=post>=0?presence*(1-TowerRigRound2.Ease((t-.16f)/.26f)):0;
   float from=.05f+.10f*(k%3),span=.28f+.14f*Mathf.Abs(Mathf.Sin(k*3.7f));
   Ribbon(20+k,q=>{
    float v=from+q*span;float x=(v-.45f)*(heavy?3.1f:3.3f)*burst;
    float y=second?Mathf.Sin(v*2.7f+.13f)*.68f*burst:x*(heavy?sign*.76f:.95f);
    y+=Mathf.Sin(q*6.5f+branch*1.8f)*(.075f+.022f*branch)*burst+sign*q*q*t*2.3f;
    return end+Face*new Vector3(x,y,.055f*branch+Mathf.Sin(q*Mathf.PI)*.17f*burst);
   },.024f*burst,k%3==0?Ivory:Ice,alpha*.82f);
  }
  for(int i=64;i<112;i++){
   int j=i-64;float sign=j%2==0?1:-1;float t=Mathf.Max(0,post-(j%3)*.018f);
   float along=Mathf.Sin(j*12.73f)*1.4f;
   float slope=heavy?sign*.76f:second?0:.95f;
   var particle=motes[i];
   Vector3 velocity=new Vector3(sign*(1.4f+Mathf.Abs(Mathf.Sin(j*4.7f))*2.3f),sign*(3.8f+(j%4)*.62f),Mathf.Sin(j*1.9f)*1.2f);
   if(second)velocity=new Vector3(sign*(6.1f+(j%5)*.63f),Mathf.Sin(j*3.7f)*1.5f,velocity.z);
   particle.position=end+Face*(new Vector3(along,along*slope,0)+velocity*t+Vector3.down*t*t*2.2f);
   particle.rotation=Face*Quaternion.Euler(j*9,t*(j%2==0?130:-95),sign*55+slope*30);
   float size=j%4==0?.16f:.065f;particle.localScale=new Vector3(size,size*(2.1f+t*2),1);
   var c=j%3==0?Ivory:Acid;c.a=post>=0?presence*(1-Mathf.Clamp01(t/.48f)):0;
   particle.GetComponent<Renderer>().sharedMaterial.SetColor("_Color",c);
  }
 }

 bool restored;
 public void Restore(){if(restored)return;restored=true;rig?.Reset();cutSkin?.Hide();}
 void OnDisable(){Restore();}
 void OnDestroy(){Restore();cutSkin?.Dispose();foreach(var m in materials)if(m)Destroy(m);foreach(var m in meshes)if(m)Destroy(m);}
}
