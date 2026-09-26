using System;
using System.Collections.Generic;
using UnityEngine;
// Textured, time-driven visual layers; no game state or contact ownership.
public sealed class ChurchFinalVfx20260917:MonoBehaviour {
 sealed class Layer{public Transform t;public Mesh mesh;public Material material;public bool ribbon;public Vector3[] vertices;public Vector2[] uvs;public int[] triangles;}
 readonly List<Layer> layers=new List<Layer>();
 TowerSurfaceRound2 stoneLips,stoneCore;
 TowerMarrowRound2 marrowFolds;
 string species,intent;Vector3 source;Func<Vector3> target;float contact; public float intensity=1;
 int auraStart;int castStart;ChurchSpellFragments20260917 fragments;float visualPost;Color hue;bool support,held;const string Root="Effects/Mistport/Official/Slashing/";
 static Quaternion Face=>Camera.main?Quaternion.LookRotation(Camera.main.transform.forward):Quaternion.identity;
 public void Configure(string s,string action,Vector3 start,Func<Vector3> finish,float time){
  species=s;intent=action;source=start;target=finish;contact=time;
  if(s=="stonehide"){
   stoneLips=new TowerSurfaceRound2(transform,6,"ChurchSpellArt/earth");
   stoneCore=new TowerSurfaceRound2(transform,6,"Effects/Mistport/Official/Slashing/Line01",true);
  }
  if(s=="boneclaw")marrowFolds=new TowerMarrowRound2(transform);

  hue=s=="stonehide"?new Color(1,.66f,.29f):s=="saltmaw"?new Color(.48f,.85f,.16f):s=="shellback"?new Color(.32f,.95f,.60f):s=="ironclaw"?new Color(.74f,1,.34f):s=="frilled-naga"?new Color(1,.18f,.46f):new Color(.64f,.34f,1);
  if(s=="boneclaw")hue=action=="tower_piercing_claw"?new Color(.16f,.62f,1):action=="tower_tail_sweep"?new Color(.10f,1,.48f):new Color(.62f,.22f,1);
  support=action=="tower_mend"||action=="tower_empower";held=action=="guard"||action=="escorted"||action.Contains("charge")||action=="tower_raised_blade";
  // 0-3 fine casting light; 4-15 impact streaks; 16-23 textured dust;
  // 24-27 grounded scars; 28-33 dual edge ribbons; 34-45 motes.
  for(int i=0;i<46;i++){
   bool ribbon=i>=28&&i<34;string path=i>=24&&i<28?(i==27?"EnemySignature/HoundCraterDecal":"EnemySignature/HoundFaultDecal"):i>=16&&i<24?"Effects/Fool/Effekseer/CurtainExplosion/Texture/smoke_tex":i>=4&&i<16||ribbon?Root+"Line01":Root+"Particle02";
   Add(path,ribbon,i>=16&&i<28);
  }
  string art=s=="stonehide"?"earth":s=="saltmaw"?"venom":s=="shellback"?"mend":s=="ironclaw"?"sickle":s=="frilled-naga"?"corona":"claw";
  Add("ChurchSpellArt/"+art,false,true);Add("ChurchSpellArt/"+art,false,true);Add("ChurchSpellArt/"+art,false,false);
  for(int i=46;i<49;i++)layers[i].material.SetFloat("_Luma",i==48?1:0);
  layers[48].material.shader=Resources.Load<Shader>("Shaders/ChurchLivingSurface");
  if(!held){var shardRoot=new GameObject("Textured spell fragmentation");shardRoot.transform.SetParent(transform,false);fragments=shardRoot.AddComponent<ChurchSpellFragments20260917>();fragments.Configure(s,layers[46].material.mainTexture,support,action);}
  if(!support&&!held){
   for(int i=0;i<12;i++)Add(Root+"Line01",true,false);
   for(int i=0;i<24;i++)Add(Root+"Line01",false,false);
   for(int i=0;i<2;i++){
    Add(Root+"Particle02",false,false);
    layers[85+i].material.shader=Resources.Load<Shader>("Shaders/ChurchDetonation");
   }
  }
  castStart=layers.Count;
  Add("ChurchSpellArt/"+art,false,true);
  Add("ChurchSpellArt/"+art,false,false);
  layers[castStart].material.SetFloat("_Luma",0);
  layers[castStart+1].material.shader=Resources.Load<Shader>("Shaders/ChurchLivingSurface");
  for(int i=0;i<6;i++)Add(Root+"Line01",true,false);
  for(int i=0;i<16;i++)Add(Root+"Particle02",false,false);
  auraStart=layers.Count;
  for(int i=0;i<2;i++){Add(Root+"Particle02",false,false);layers[auraStart+i].material.shader=Resources.Load<Shader>("Shaders/ChurchDetonation");layers[auraStart+i].material.SetFloat("_Gather",1);}
  if(species=="boneclaw")foreach(int index in new[]{46,47,48,castStart,castStart+1}){layers[index].material.shader=Resources.Load<Shader>("Shaders/BonePattern20260920");layers[index].material.SetFloat("_Pattern",intent=="tower_piercing_claw"?0:intent=="tower_tail_sweep"?1:2);}
 }
 void Add(string path,bool ribbon,bool alpha){
  var go=new GameObject("VFX "+layers.Count);go.transform.SetParent(transform,false);
  var mesh=new Mesh();mesh.MarkDynamic();
  if(!ribbon){mesh.vertices=new[]{new Vector3(-.5f,-.5f,0),new Vector3(.5f,-.5f,0),new Vector3(.5f,.5f,0),new Vector3(-.5f,.5f,0)};mesh.uv=new[]{Vector2.zero,Vector2.right,Vector2.one,Vector2.up};mesh.triangles=new[]{0,1,2,0,2,3};}
  if(!ribbon&&species=="boneclaw"&&path.StartsWith("ChurchSpellArt/")){
   const int cols=24,rows=40;var vertices=new Vector3[(cols+1)*(rows+1)];var uv=new Vector2[vertices.Length];var indices=new int[cols*rows*6];
   for(int y=0;y<=rows;y++)for(int x=0;x<=cols;x++){
    int n=y*(cols+1)+x;float u=x/(float)cols,v=y/(float)rows;
    float taper=Mathf.Pow(Mathf.Max(0,Mathf.Sin(v*Mathf.PI)),.38f);
    vertices[n]=new Vector3((u-.5f)*(.76f+.24f*taper)+Mathf.Sin(v*5.3f)*taper*.075f,v-.5f,Mathf.Sin(u*Mathf.PI)*taper*.07f);uv[n]=new Vector2(u,v);
    if(x<cols&&y<rows){int k=(y*cols+x)*6;indices[k]=n;indices[k+1]=n+1;indices[k+2]=n+cols+2;indices[k+3]=n;indices[k+4]=n+cols+2;indices[k+5]=n+cols+1;}
   }
   mesh.Clear();mesh.vertices=vertices;mesh.uv=uv;mesh.triangles=indices;mesh.RecalculateBounds();
  }
  var material=new Material(Resources.Load<Shader>("Shaders/ChurchFilament"));material.mainTexture=Resources.Load<Texture2D>(path);material.SetFloat("_Ribbon",ribbon?1:0);material.SetFloat("_Dst",alpha?10:1);material.SetFloat("_Luma",path.StartsWith("EnemySignature")?0:1);material.SetColor("_Color",Color.clear);
  go.AddComponent<MeshFilter>().sharedMesh=mesh;var r=go.AddComponent<MeshRenderer>();r.sharedMaterial=material;r.shadowCastingMode=UnityEngine.Rendering.ShadowCastingMode.Off;r.receiveShadows=false;
  layers.Add(new Layer{t=go.transform,mesh=mesh,material=material,ribbon=ribbon,vertices=ribbon?new Vector3[66]:null,uvs=ribbon?new Vector2[66]:null,triangles=ribbon?new int[192]:null});
 }
 void Sprite(int i,Vector3 pos,Vector2 size,Quaternion rotation,Color color,float opacity,float dissolve=0){var l=layers[i];l.t.position=pos;l.t.rotation=rotation;if(species=="boneclaw"){color=Color.Lerp(hue,Color.white,.18f);}
  if(i>=46&&i<=48)size*=species=="boneclaw"?1.22f:species=="stonehide"?1.16f:1.18f;
  l.t.localScale=new Vector3(size.x,size.y,1);if(i>=46&&i<=48&&!support&&!held){
   float t=visualPost;
   if(t<0&&t>-.13f)l.t.localScale*=Mathf.Lerp(1,.70f,1+t/.13f);
   if(t>=0){float kick=species=="boneclaw"?BoneBurst(t):1+.34f*(1-Mathf.Exp(-t*22));l.t.localScale*=kick;dissolve=Mathf.Max(dissolve,Mathf.Clamp01((t-.12f)/.48f));}
  }
  color.a=Mathf.Clamp01(opacity)*intensity;l.material.SetColor("_Color",color);l.material.SetFloat("_Dissolve",dissolve);}
 void Ribbon(int i,Func<float,Vector3> curve,float width,Color color,float opacity){
  const int n=32;var l=layers[i];var v=l.vertices;var uv=l.uvs;var tr=l.triangles;
  for(int j=0;j<=n;j++){float q=j/(float)n;Vector3 p=curve(q),tangent=curve(Mathf.Min(1,q+.01f))-curve(Mathf.Max(0,q-.01f));Vector3 normal=Vector3.Cross(tangent,Camera.main?Camera.main.transform.forward:Vector3.forward).normalized;float w=width*Mathf.Pow(Mathf.Max(0,Mathf.Sin(q*Mathf.PI)),.6f);v[j*2]=p-normal*w;v[j*2+1]=p+normal*w;uv[j*2]=new Vector2(0,q);uv[j*2+1]=new Vector2(1,q);if(j<n){int k=j*6,a=j*2;tr[k]=a;tr[k+1]=a+2;tr[k+2]=a+1;tr[k+3]=a+1;tr[k+4]=a+2;tr[k+5]=a+3;}}
  l.mesh.Clear();l.mesh.vertices=v;l.mesh.uv=uv;l.mesh.triangles=tr;l.mesh.RecalculateBounds();l.t.SetPositionAndRotation(Vector3.zero,Quaternion.identity);l.t.localScale=Vector3.one;color.a=opacity*intensity;l.material.SetColor("_Color",color);
 }
 public void Step(float age){
  age=Mathf.Max(0,age);stoneLips?.Hide();stoneCore?.Hide();marrowFolds?.Hide();
  if(!support&&!held)age=TowerImpactTiming20260921.Sample(age,contact,species=="stonehide"?.115f:species=="boneclaw"?.105f:.080f);
  if(target==null)return;foreach(var l in layers)l.material.SetColor("_Color",Color.clear);
  Vector3 end=target(),floor=end;floor.y=.025f;float f=Mathf.Clamp01(age/Mathf.Max(.01f,contact)),post=age-contact,fade=1-Mathf.Clamp01(Mathf.Max(0,post)/.55f);Vector3 center=Vector3.Lerp(source,end,f);
  visualPost=post;float clock=held?Time.time:age;
  for(int side=0;side<2;side++){
   if(species=="stonehide"||species=="boneclaw")continue;
   if(support)continue; // Healing/crown state is not a damage-style detonation aura.
   float life=side==0?(post<0?Mathf.Clamp01(age/.16f):Mathf.Clamp01(1-post/.25f)):(post<-.12f?0:Mathf.Clamp01(1-Mathf.Max(0,post)/.6f));
   Vector3 spot=(side==0?source:end)-Face*Vector3.forward*.6f;
   float pulse=1+.08f*Mathf.Sin(age*13+side*3)+.04f*Mathf.Sin(age*23);
   Sprite(auraStart+side,spot,new Vector2(2.5f,2.8f)*pulse,Face*Quaternion.Euler(0,0,side*71+age*12),hue,life*.85f);
   layers[auraStart+side].material.SetFloat("_Age",age+side*2.13f);
  }
  if(species=="stonehide"&&held)return;
  Cast(age,f,post);
  Art(age,end,f,post,fade);
  layers[48].material.SetFloat("_Age",age);
  if(species=="boneclaw")foreach(int index in new[]{46,47,48,castStart,castStart+1})layers[index].material.SetFloat("_Age",age);
  if(fragments){Vector3 debrisOrigin=end;if(species=="stonehide")debrisOrigin.y=.25f;fragments.Step(post,debrisOrigin,intensity);}

  // Cast gathers inward. Four tiny motes converge, without covering the body.
  if(post<0||held)for(int j=0;j<4;j++){float a=j*1.57f+clock*3,r=held?.32f:Mathf.Lerp(.7f,.08f,f);Sprite(j,source+new Vector3(Mathf.Cos(a)*r,Mathf.Sin(a)*r*.7f,0),Vector2.one*.13f,Face,hue,.75f);}
  if(held){
   for(int j=0;j<2;j++){int k=j;Ribbon(28+j,q=>source+Face*new Vector3((k==0?-1:1)*(.45f+.16f*Mathf.Sin(q*Mathf.PI)),(q-.5f)*1.2f,0),.07f,hue,.65f);}
   return;
  }
  if(support){
   Vector3 spot=post<0?source:end;
   for(int j=0;j<12;j++){float a=j*2.399f+age*.7f,t=Mathf.Repeat(age*1.1f+j*.071f,1);float radius=intent=="tower_mend"?Mathf.Lerp(.55f,.19f,t):.38f+.10f*Mathf.Sin(t*Mathf.PI);Vector3 p=spot+new Vector3(Mathf.Cos(a)*radius,(t-.5f)*1.5f,Mathf.Sin(a)*radius*.75f);Sprite(34+j,p,new Vector2(.12f,.24f),Face,hue,Mathf.Sin(t*Mathf.PI)*fade);}
   if(intent=="tower_empower")for(int j=0;j<3;j++){int k=j;Ribbon(28+j,q=>spot+Vector3.up*.48f+Face*new Vector3((q-.5f)*.65f,.17f*Mathf.Sin(q*Mathf.PI)+k*.08f,0),.035f,hue,fade);}
   else {
    Sprite(0,spot,Vector2.one*(.45f+.2f*Mathf.Sin(f*Mathf.PI)),Face,hue,.55f*fade);
    if(post>=0)for(int j=0;j<2;j++){int k=j;Ribbon(28+j,q=>spot+new Vector3(Mathf.Sin(q*5+age*3+k*Mathf.PI)*.35f,(q-.5f)*1.4f,Mathf.Cos(q*5+k*Mathf.PI)*.20f),.075f,hue,fade*.6f);}
   }
   return;
  }
  if(species=="stonehide"){
   Vector3 groundStart=source;groundStart.y=.025f;Vector3 direction=(floor-groundStart).normalized;
   for(int j=0;j<3;j++){float q=(j+1)/3f,t=age-(contact*q-.16f),life=t<0?0:1-Mathf.Clamp01((t-.12f)/.45f);Vector3 p=Vector3.Lerp(groundStart,floor,q);Sprite(24+j,p,new Vector2(.9f,1.8f),Quaternion.LookRotation(Vector3.up,direction),new Color(.7f,.6f,.5f),life);
    if(t>=0&&t<.4f){Sprite(16+j,p+Vector3.up*(.15f+t*.5f),new Vector2(.8f+t,.45f+t*.8f),Face,new Color(.45f,.36f,.26f),life*.35f,t);}
   }
   // D01's centre stays open; the six separated stone lips replace a crater disc.
  }else if(species=="ironclaw"){
   int count=species=="ironclaw"?2:3;
   for(int j=0;j<count;j++){int k=j;float local=age-contact+.20f-j*.035f;float life=local<0?0:1-Mathf.Clamp01((local-.10f)/.45f);float sweep=Mathf.Clamp01(local/.18f);
    float tilt=species=="ironclaw"?(j==0?-.65f:.65f):intent=="tower_tail_sweep"?1.4f:-.22f;
    Func<float,Vector3> curve=q=>end+Face*(Quaternion.Euler(0,0,tilt*Mathf.Rad2Deg)*new Vector3((q-.5f)*2.2f,(k-(count-1)*.5f)*.25f+Mathf.Sin(q*Mathf.PI)*.26f,-.04f)) + Vector3.up*(1-sweep)*.35f;
    Ribbon(28+j*2,curve,.32f,hue*1.4f,life*.16f);Ribbon(29+j*2,curve,.065f,new Color(1,.94f,.83f),life*.16f);
   }
  }else if(species=="saltmaw"){
   if(intent=="tower_poison"){
    for(int j=0;j<3;j++){int k=j;Ribbon(28+j,q=>Vector3.Lerp(source,end,Mathf.Clamp01(f-q*.35f))+new Vector3(Mathf.Sin(q*12+age*9+k*2)*.10f,Mathf.Cos(q*9+age*7+k)*.08f,0),.16f,hue,fade*.7f);}
    for(int j=0;j<8;j++){float q=Mathf.Clamp01(f-j*.055f);Sprite(16+j,Vector3.Lerp(source,end,q),Vector2.one*(.24f+q*.24f),Face*Quaternion.Euler(0,0,j*47+age*45),hue,.16f*fade);}
   }else for(int j=0;j<3;j++){int k=j;Ribbon(28+j,q=>center+new Vector3((k-1)*.13f,0,0)+(end-source).normalized*(q-.5f)*.85f,.045f,new Color(.86f,1,.57f),fade);}
  }else if(species=="frilled-naga"){
   for(int j=0;j<3;j++){int k=j;Vector3 p=Vector3.Lerp(source,end,Mathf.Clamp01(f-j*.13f));float r=.22f+j*.09f;
    Ribbon(28+j,q=>p+Face*new Vector3(Mathf.Cos(q*5.2f+age*4+k)*r,Mathf.Sin(q*5.2f+age*4+k)*r*1.4f,0),.14f,hue,fade*.8f);
   }
  }
  if(post>=0&&species=="stonehide"){StoneHeave(post,floor,fade);return;}
  if(post>=0&&species=="boneclaw"){BoneRupture(post,end,fade);return;}
  if(post>=0){
   ChurchImpactLens20260917.Request(this,post,intensity);
   // Distinct jagged fire fronts unfold after the single contact flash.
   for(int wave=0;wave<2;wave++){
    float t=post-wave*.075f;if(t<0)continue;
    Vector3 loc=end-Face*Vector3.forward*.35f;
    Quaternion rot=Face*Quaternion.Euler(0,0,wave*43);
    if(species=="stonehide"){loc.y=.15f+wave*.15f;rot=Quaternion.Euler(70,wave*47,0);}
    Sprite(85+wave,loc,Vector2.one*(wave==0?6.4f:5.2f),rot,hue,1);
    layers[85+wave].material.SetFloat("_Age",t);
   }
   // Fast expansion, narrow brilliant core, separated ballistic fragments.
   float burst=Mathf.Clamp01(post/.38f),fadeOut=1-burst;
   Vector3 impact=end-Face*Vector3.forward*.22f;
   if(species=="stonehide")impact.y=.22f;
   float flash=Mathf.Exp(-post*12);
   Sprite(0,impact,Vector2.one*(2.4f+post*8),Face,new Color(1,.96f,.82f),flash);
   Sprite(1,impact,new Vector2(6.5f+post*8,.32f+post*.4f),Face,hue*3.0f,flash);
   float radius=.18f+3.5f*(1-Mathf.Exp(-post*12));
   for(int j=0;j<4;j++){
    int k=j;float offset=j*1.5708f;
    Ribbon(49+j,q=>{
     float angle=offset+q*1.12f+post*.8f;
     Vector3 local=new Vector3(Mathf.Cos(angle)*radius,Mathf.Sin(angle)*radius*.70f,0);
     return species=="stonehide"?impact+new Vector3(local.x,.035f,local.y):impact+Face*local;
    },.12f+.34f*fadeOut,hue*1.7f,fadeOut*fadeOut*.40f);
   }
   for(int j=0;j<12;j++){
    float a=j*2.399f,r=.12f+(3.6f+j%4)*post;
    Vector3 p=impact+Face*new Vector3(Mathf.Cos(a)*r,Mathf.Sin(a)*r*.85f-post*post*2,0);
    if(species=="stonehide")p.y=Mathf.Max(.08f,p.y);
    Sprite(4+j,p,new Vector2(.07f+j%3*.025f,(.85f+j%4*.18f)*(1-post)),Face*Quaternion.Euler(0,0,a*Mathf.Rad2Deg-90),Color.Lerp(hue,Color.white,.4f),fade*fade*.35f);
   }
   for(int j=0;j<12;j++){
    float a=j*2.399f+.5f,r=post*(2.3f+j%5*.5f);
    Vector3 p=impact+Face*new Vector3(Mathf.Cos(a)*r,Mathf.Sin(a)*r*.8f-post*post*2.5f,0);
    float twinkle=.65f+.35f*Mathf.Sin(post*45+j*7);
    Sprite(34+j,p,new Vector2(.09f,.14f+j%3*.04f),Face*Quaternion.Euler(0,0,j*71+post*380),Color.Lerp(hue,Color.white,.25f),fade*twinkle);
   }
   // Delayed second detonation: torn, rolling energy petals, not a filled cloud.
   for(int j=0;j<8;j++){
    int k=j;float t=post-(j%2)*.06f;
    if(t<0)continue;
    float envelope=Mathf.Pow(1-Mathf.Clamp01(t/.50f),1.4f);
    float theta=j*Mathf.PI*.25f;
    Ribbon(53+j,q=>{
     float r=.22f+(1-Mathf.Exp(-t*10))*3.0f+q*.65f;
     float a=theta+q*.65f+t*(k%2==0?2:-2);
     float lift=Mathf.Sin(q*Mathf.PI)*(.35f+t);
     Vector3 local=new Vector3(Mathf.Cos(a)*r,Mathf.Sin(a)*r*.78f+lift,0);
     return species=="stonehide"?impact+new Vector3(local.x,lift+.08f,local.y):impact+Face*local;
    },.12f+envelope*.20f,hue*1.8f,envelope*.13f);
   }
   for(int j=0;j<24;j++){
    float t=post-(j%3)*.026f;if(t<0)continue;
    float a=j*2.399f,r=.25f+t*(4.8f+j%5*.75f);
    Vector3 pos=impact+Face*new Vector3(Mathf.Cos(a)*r,Mathf.Sin(a)*r*.85f-t*t*3,0);
    if(species=="stonehide")pos.y=Mathf.Max(.06f,pos.y);
    Sprite(61+j,pos,new Vector2(.035f+j%3*.02f,.5f+(j%4)*.22f),Face*Quaternion.Euler(0,0,a*Mathf.Rad2Deg-90),Color.Lerp(hue,Color.white,.65f)*2,Mathf.Pow(1-Mathf.Clamp01(t/.55f),1.3f)*.35f);
   }
   // Sparse dust only on the outer edge; never a filled central cloud.
   for(int j=0;j<4;j++){
    float a=j*1.57f+.4f;Vector3 p=impact+Face*new Vector3(Mathf.Cos(a)*radius,Mathf.Sin(a)*radius*.7f,0);
    Sprite(20+j,p,Vector2.one*(.25f+post*.8f),Face*Quaternion.Euler(0,0,j*73+post*40),hue,fade*.12f,post);
   }
  }
 }

 void StoneHeave(float t,Vector3 floor,float fade){
  ChurchImpactLens20260917.Request(this,t,intensity);
  float peak=1+3.7f*Mathf.SmoothStep(0,1,t/.045f)*(1-Mathf.SmoothStep(0,1,(t-.14f)/.30f));
  // Fault seams surge out from the planted impact, then heave upward as stone teeth.
  for(int j=0;j<12;j++){
   int k=j;float angle=j*2.39996f+.12f*Mathf.Sin(j*7.1f);
   Ribbon(49+j,q=>{
    float r=.16f+q*(.65f+peak*(.47f+.17f*Mathf.Sin(k*4.7f)));
    float a=angle+Mathf.Sin(q*18+k)*.045f;
    float lift=Mathf.Sin(q*Mathf.PI)*Mathf.Sin(Mathf.Clamp01(t/.45f)*Mathf.PI)*(.35f+(k%3)*.18f);
    return floor+new Vector3(Mathf.Cos(a)*r,lift+.03f,Mathf.Sin(a)*r);
   },j%3==0?.10f:.035f,j%3==0?new Color(1,.9f,.60f):hue,fade);
  }
  for(int j=0;j<24;j++){
   float local=t-(j%3)*.018f;if(local<0)continue;
   float a=j*2.399f,r=.35f+local*(2+j%4);
   Vector3 p=floor+new Vector3(Mathf.Cos(a)*r,.12f+local*(2.5f+j%3)-local*local*7,Mathf.Sin(a)*r);
   Sprite(61+j,p,new Vector2(.10f,.25f+(j%4)*.09f),Face*Quaternion.Euler(0,0,a*57+local*190),new Color(1,.78f,.4f),fade*fade);
  }
  // Visible incandescent sparks: rapid radial ejection, ballistic fall and one bounce.
  for(int j=0;j<48;j++){
   float age=t-(j%3)*.012f;if(age<0)continue;
   float angle=j*2.39996f,speed=8.5f+(j%7)*1.05f,up=2.7f+(j%5)*.65f;
   float bounce=2*up/18f;
   float y=age<bounce?up*age-9*age*age:(age-bounce)*up*.42f-9*(age-bounce)*(age-bounce);
   y=Mathf.Max(.025f,y);
   Vector3 radial=new Vector3(Mathf.Cos(angle),0,Mathf.Sin(angle));
   Vector3 pos=floor+radial*(age*speed)+Vector3.up*(.08f+y);
   Vector3 velocity=radial*speed+Vector3.up*(age<bounce?up-18*age:up*.42f-18*(age-bounce));
   Vector3 screen=Quaternion.Inverse(Face)*velocity;
   float rotation=Mathf.Atan2(-screen.x,screen.y)*Mathf.Rad2Deg;
   int slot=j<24?61+j:j<36?4+j-24:34+j-36;
   float alpha=1-Mathf.SmoothStep(0,1,(age-.18f)/.36f);
   Color fire=j%3==0?new Color(1,.97f,.78f):new Color(1,.61f,.17f);
   Sprite(slot,pos,new Vector2(j%4==0?.075f:.045f,.35f+(j%5)*.16f),Face*Quaternion.Euler(0,0,rotation),fire*2.2f,alpha);
  }
  Sprite(0,floor+Vector3.up*.1f,new Vector2(2.1f,1.15f)*peak,Quaternion.Euler(70,0,0),new Color(1,.85f,.5f),Mathf.Exp(-t*13));
 }
 static float BoneBurst(float t){return 1+5.1f*Mathf.SmoothStep(0,1,t/.042f)*(1-Mathf.SmoothStep(0,1,(t-.14f)/.36f));}
 void BoneRupture(float t,Vector3 end,float fade){
  ChurchImpactLens20260917.Request(this,t,intensity);
  bool tail=intent=="tower_tail_sweep",heavy=intent=="tower_heavy_claw";
  Quaternion frame=Face*Quaternion.Euler(0,0,tail?0:heavy?-8:24);
  float burst=BoneBurst(t),life=fade*fade;
  Color marrow=tail?new Color(.30f,1,.64f):heavy?new Color(.85f,.56f,1):new Color(.40f,.80f,1),ivory=tail?new Color(.76f,1,.56f):heavy?new Color(1,.84f,.48f):new Color(.85f,.97f,1);
  // Three torn channels, each with separate lips. Open across the cut, not in a ring.
  for(int k=0;k<6;k++){
   if(!heavy&&!tail&&k>=2)continue;
   int digit=k/2;float side=k%2==0?-1:1;
   Func<float,Vector3> path=q=>{
    if(heavy){float angle=k*2.39996f+.21f*Mathf.Sin(k*7.3f);float radius=q*(1.04f+.24f*Mathf.Sin(k*4.7f))*burst;float bend=Mathf.Sin(q*11.3f+k)*.055f*q*burst;return end+frame*new Vector3(Mathf.Cos(angle)*radius+bend,Mathf.Sin(angle)*radius*.65f,Mathf.Sin(q*Mathf.PI)*.16f*burst);}
    if(tail){float span=.49f+.34f*Mathf.Abs(Mathf.Sin(k*3.73f+.4f));float tx=(q-.5f)*span-.48f+Mathf.Repeat(k*.381966f,1)*.96f;float ty=.18f*tx*tx+.16f*Mathf.Sin(k*5.3f)+Mathf.Sin(q*8.1f+k*2.7f)*(.022f+.013f*k);return end+frame*new Vector3(tx*burst,ty*burst,Mathf.Sin(q*Mathf.PI)*(.08f+.035f*k)*burst-.02f*k);}

    float y=(q-.5f)*2.0f*burst;float x=(side*(.065f+t*.24f)*Mathf.Sin(q*Mathf.PI)+Mathf.Sin(q*5.7f)*.062f+Mathf.Sin(q*19.1f)*.008f)*burst;
    return end+frame*new Vector3(x,y,0);
   };
   float matterWidth=(tail?.26f:heavy?.31f:.21f)*(1+.12f*Mathf.Sin(k*3.7f+1))*burst;
   Color body=tail?new Color(.17f,.72f,.45f):heavy?new Color(.53f,.22f,.84f):new Color(.24f,.56f,.91f);
   marrowFolds.Draw(k,path,matterWidth,(tail?.12f:heavy?.19f:.10f)*burst,body,ivory,life*.96f,t);
   Ribbon(28+k,path,(.046f+.011f*Mathf.Sin(k*3.7f+1))*burst,hue,life*.64f);
   Ribbon(49+k,path,.028f*burst,ivory,life);
   int channel=k;
   Ribbon(55+k,q=>path(.10f+channel*.055f+q*(.42f+.055f*(channel%3)))+frame*new Vector3(side*q*q*.10f*burst,Mathf.Sin(q*(heavy?15:tail?9:23)+channel)* (heavy?.075f:tail?.055f:.025f),.035f*q*burst),.012f*burst,marrow,life*.8f);
  }
  // Paired bone splinters peel from the wound at staggered heights.
  for(int j=0;j<24;j++){
   float delay=(j%4)*.018f,age=t-delay;if(age<0)continue;
   float side=j%2==0?-1:1;
   Vector3 local=new Vector3(side*(.22f+age*(3.5f+j%3)),((j/2)%6-2.5f)*.26f-age*age*(heavy?4:1),0);
   if(tail)local=new Vector3(((j/2)%6-2.5f)*.38f+side*age*6.2f,Mathf.Sin(j)*.14f-age*age*2,0);
   Vector3 p=end+frame*local;
   Sprite(61+j,p,new Vector2(.065f,.22f+(j%3)*.11f),frame*Quaternion.Euler(0,0,side*(25+age*180)),ivory,life);
  }
  float snap=Mathf.Exp(-t*17);
  Sprite(0,end,new Vector2(.7f,1.1f)*burst,frame,marrow,snap*.75f);
  // Keep the bright center finite so the three wound silhouettes remain visible.
 }

 void Cast(float age,float f,float post){
  if(species=="stonehide"||species=="boneclaw")return; // New body component owns bone-attached charge light.
  if(held||post>.18f)return;
  float strength=post<0?Mathf.SmoothStep(0,1,Mathf.Clamp01(age/.12f)):1-Mathf.Clamp01(post/.18f);
  float wind=Mathf.Clamp01(f/.75f),release=Mathf.Clamp01((f-.72f)/.28f);
  Vector3 pivot=source-Face*Vector3.forward*.40f;
  bool ground=species=="stonehide";
  Vector3 origin=pivot;if(ground)origin.y=.12f;
  float scale=ground?3.3f:species=="saltmaw"?2.1f:2.5f;
  scale*=1.14f*(.70f+.30f*wind+.20f*release);
  Quaternion rotation=ground?Quaternion.Euler(72,age*85,0):Face*Quaternion.Euler(0,0,age*(species=="boneclaw"?-32:80));
  Sprite(castStart,origin,Vector2.one*scale,rotation,Color.white,strength*.85f);
  Sprite(castStart+1,origin,Vector2.one*scale,rotation,hue,strength*.70f);
  layers[castStart+1].material.SetFloat("_Age",age*1.5f);
  for(int j=0;j<6;j++){
   int k=j;float angle=j*Mathf.PI/3+age*(j%2==0?1.3f:-1.3f);
   Ribbon(castStart+2+j,q=>{
    float r=(1-q)*(1.0f+.18f*Mathf.Sin(age*7+k))+.12f;
    float a=angle+q*(species=="ironclaw"?.9f:2.1f)+Mathf.Sin(q*11+age*5+k)*.24f;
    Vector3 v=new Vector3(Mathf.Cos(a)*r,Mathf.Sin(a)*r*.68f,0);
    if(ground)return origin+new Vector3(v.x,q*.8f,v.y);
    if(species=="saltmaw")v.y+=Mathf.Sin(q*8+age*11)*.10f;
    return pivot+Face*v;
   },.024f+.028f*wind,Color.Lerp(hue,Color.white,.25f)*1.5f,strength*.8f);
  }
  for(int j=0;j<16;j++){
   float q=Mathf.Repeat(age*(.8f+j%3*.2f)+j*.061f,1),a=j*2.399f+age*.6f;
   float r=(1-q)*1.25f+.1f;
   Vector3 v=new Vector3(Mathf.Cos(a)*r,Mathf.Sin(a)*r*.8f,0);
   Vector3 pos=ground?origin+new Vector3(v.x,q*.65f,v.y):pivot+Face*v;
   Sprite(castStart+8+j,pos,new Vector2(.055f,.12f+j%3*.035f),Face*Quaternion.Euler(0,0,a*57.3f),Color.Lerp(hue,Color.white,.35f),strength*Mathf.Sin(q*Mathf.PI));
  }
 }

 void Art(float age,Vector3 end,float f,float post,float fade){
  float attack=Mathf.SmoothStep(0,1,Mathf.Clamp01((age-contact+.22f)/.18f));
  float life=attack*fade;Vector3 center=Vector3.Lerp(source,end,Mathf.SmoothStep(0,1,f));
  Quaternion rotation=Face;Vector2 size=Vector2.one;Vector3 p=center;
  if(held){
   if(species=="stonehide"||species=="boneclaw")return;
   p=source+Vector3.back*.32f;size=Vector2.one*(species=="stonehide"?1.5f:1.0f);rotation=Face*Quaternion.Euler(0,0,Time.time*18);
   Sprite(46,p,size,rotation,Color.white,.75f);return;
  }
  if(support){
   p=(post<0?source:end)-Face*Vector3.forward*.85f;size=Vector2.one*(post<0?1.35f+f*.25f:1.8f+.14f*Mathf.Sin(age*4));rotation=Face*Quaternion.Euler(intent=="tower_mend"?12:-9,Mathf.Sin(age*2)*9,age*(intent=="tower_mend"?12:-8));
   if(intent=="tower_empower")p+=Vector3.up*.42f;
   Sprite(46,p,size,rotation,Color.white,fade*.8f);
   Sprite(48,p,size*1.015f,rotation,Color.white,fade*.30f);return;
  }
  if(species=="stonehide"){
   if(post<0)return;
   float open=Mathf.SmoothStep(0,1,post/.045f),recoil=1-Mathf.SmoothStep(0,1,(post-.14f)/.30f);
   float kick=1+1.25f*open*recoil;Vector3 ground=end;ground.y=.065f;
   for(int j=0;j<6;j++){
    float a=j*2.39996f+.19f*Mathf.Sin(j*5.3f),radius=.22f+open*(.45f+.15f*Mathf.Sin(j*3.1f));
    Vector3 pos=ground+new Vector3(Mathf.Cos(a)*radius,.04f+Mathf.Sin(post*7+j)*.025f,Mathf.Sin(a)*radius*.76f);
    stoneLips.Leaf(j,pos,Quaternion.Euler(70-j%3*8,a*Mathf.Rad2Deg+12*Mathf.Sin(j*4.7f),j%2==0?-13:9),
     new Vector2((1.18f+.24f*Mathf.Sin(j*4.3f))*kick,(1.75f+.33f*Mathf.Sin(j*2.6f))*kick),
     j%3==0?new Color(1,.91f,.72f):Color.white,fade,age,.23f+.035f*j,new Rect(.07f+j%3*.18f,.16f,.34f,.68f),Mathf.Max(0,post-.10f)*1.8f);
    // The white-gold fault is narrower than its lifted earth lip and follows
    // the same unequal ground path. The open gaps stay visible at peak.
    stoneCore.Leaf(j,pos+Vector3.up*.032f,Quaternion.Euler(69-j%3*8,a*Mathf.Rad2Deg+12*Mathf.Sin(j*4.7f),j%2==0?-13:9),
     new Vector2((.29f+.07f*Mathf.Sin(j*4.3f))*kick,(1.49f+.27f*Mathf.Sin(j*2.6f))*kick),
     j%3==0?new Color(1,1,.80f):new Color(1,.87f,.52f),fade*.79f,age,.12f+.02f*j,
     new Rect(.13f+j%3*.16f,.17f,.27f,.63f),Mathf.Max(0,post-.09f)*2.2f);
   }
   return;
  }
  if(species=="ironclaw"){
   float progress=Mathf.Clamp01((age-contact+.22f)/.32f),flip=intent=="tower_cut_second"?-1:1;
   for(int j=0;j<2;j++){
    float sign=j==0?-1:1;Vector3 pos=end+Face*new Vector3(sign*Mathf.Lerp(.85f,.18f,progress),0,-.06f);
    Quaternion rot=Face*Quaternion.Euler(0,0,sign*flip*Mathf.Lerp(-65,65,progress)+(j==1?180:0));
    Sprite(46+j,pos,Vector2.one*(intent=="tower_heavy_cut"?2.35f:1.95f),rot,Color.white,life*.9f);
   }
   return;
  }
  if(species=="boneclaw"){
   // Contact uses filled rolled cuts, not the dark flat patterned disc or
   // the old detached tail patch. Keep existing narrow pre-contact artwork.
   if(post>=0)return;
   p=end+Vector3.up*(1-attack)*.5f;size=new Vector2(2.45f,2.25f);rotation=Face*Quaternion.Euler(0,0,intent=="tower_tail_sweep"?0:intent=="tower_heavy_claw"?0:22);
   Sprite(46,p,size,rotation,Color.white,life);Sprite(48,p,size*1.015f,rotation,Color.white,life*.32f);return;
  }
  if(species=="saltmaw"){
   Vector3 projected=Quaternion.Inverse(Face)*(end-source);float angle=Mathf.Atan2(-projected.x,projected.y)*Mathf.Rad2Deg;
   p=center;size=new Vector2(intent=="tower_poison"?2.05f:1.65f,1.65f+f*.35f);rotation=Face*Quaternion.Euler(0,0,angle+Mathf.Sin(age*12)*4);
   Sprite(46,p,size,rotation,Color.white,fade*Mathf.SmoothStep(0,1,f*4));
   Sprite(48,p,size*1.04f,rotation,Color.white,fade*.15f);return;
  }
  // Sonic crown travels as a single recognisable rotating body, then opens.
  p=center;size=Vector2.one*(.65f+f*1.30f+Mathf.Max(0,post)*1.2f);rotation=Face*Quaternion.Euler(0,0,age*210);
  Sprite(46,p,size,rotation,Color.white,fade);Sprite(48,p,size*1.03f,rotation,Color.white,fade*.32f);
 }
 void OnDestroy(){stoneLips?.Dispose();stoneCore?.Dispose();marrowFolds?.Dispose();foreach(var l in layers){if(l.material)Destroy(l.material);if(l.mesh)Destroy(l.mesh);}}
}
