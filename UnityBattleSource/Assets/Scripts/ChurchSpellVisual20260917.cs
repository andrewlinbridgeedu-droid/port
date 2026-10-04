using System;
using System.Collections.Generic;
using UnityEngine;
using Effekseer;
// Church-only geometry, one owner and lifetime. Never reports contact or owns gameplay state.
public sealed class ChurchSpellVisual20260917:MonoBehaviour {
 sealed class Piece {public Transform t;public Material m;public Color color;public Vector3 scale;public bool loose;}
 BountySpellRound2 bountyRound2; ChurchFinalVfx20260917 finalVfx;float impactBodyFade=1;
 int organStart; int spectacleStart; bool spectacle;
 EffekseerHandle silkTravel;bool silkStarted,silkStopped;
 readonly List<Piece> pieces=new List<Piece>();readonly List<Mesh> meshes=new List<Mesh>();
 public bool ambient;public float intensity=1;
 void Update(){if(ambient)Tick(.55f+.10f*Mathf.Sin(Time.time*2));}
 string species,intent;Vector3 source;Func<Vector3> target;float contact;
 static readonly Color Salt=new Color(.68f,.88f,.69f),Ivory=new Color(.95f,.90f,.69f),Gold=new Color(1,.67f,.25f),Blue=new Color(.23f,.72f,1),Violet=new Color(.68f,.47f,1),Red=new Color(.78f,.07f,.16f);
 public static ChurchSpellVisual20260917 Create(string species,string intent,Vector3 source,Func<Vector3> target,float contact){
  var go=new GameObject("ChurchSpell_"+species+"_"+intent);var v=go.AddComponent<ChurchSpellVisual20260917>();v.species=species;v.intent=intent;v.source=source;v.target=target;v.contact=contact;
  if(species.StartsWith("b0")){v.bountyRound2=go.AddComponent<BountySpellRound2>();v.bountyRound2.Configure(species,intent,source,target,contact);return v;}
  if(species=="stonehide"||species=="saltmaw"||species=="shellback"||species=="ironclaw"||species=="frilled-naga"||species=="boneclaw"){v.finalVfx=go.AddComponent<ChurchFinalVfx20260917>();v.finalVfx.Configure(species,intent,source,target,contact);return v;}
  v.Build();v.BuildOrgans();v.BuildSpectacle();return v;
 }
 Piece Add(string name,Mesh mesh,Color color,bool soft=false){var go=new GameObject(name);go.transform.SetParent(transform,false);go.AddComponent<MeshFilter>().sharedMesh=mesh;var r=go.AddComponent<MeshRenderer>();r.shadowCastingMode=UnityEngine.Rendering.ShadowCastingMode.Off;r.receiveShadows=false;var m=new Material(Resources.Load<Shader>("Shaders/ChurchArcane"));m.SetColor("_Color",color);if(species.StartsWith("b"))m.SetFloat("_BountyDetail",1);m.SetFloat("_Soft",soft?1:0);m.SetFloat("_Glow",name.Contains("crescent")||name.Contains("chevron")||name.Contains("orbit")||name.Contains("perimeter")||name.Contains("wave")||name.Contains("talon")?1.2f:.18f);r.sharedMaterial=m;var p=new Piece{t=go.transform,m=m,color=color,scale=Vector3.one,loose=name.Contains("spray")||name.Contains("fragments")||name.Contains("rivet")||name.Contains("cancellation")};if(species.StartsWith("b"))m.SetFloat("_Glow",soft?.20f:name.Contains("chain")?.38f:1.45f);pieces.Add(p);return p;}
 Mesh Mesh(Vector3[] v,int[] tris){var m=new Mesh();m.vertices=v;m.triangles=tris;var uv=new Vector2[v.Length];for(int i=0;i<v.Length;i++)uv[i]=new Vector2(v[i].x+.5f,v[i].y+.5f);m.uv=uv;m.RecalculateNormals();meshes.Add(m);return m;}
 Mesh Quad(){return Mesh(new[]{new Vector3(-.5f,-.5f,0),new Vector3(.5f,-.5f,0),new Vector3(.5f,.5f,0),new Vector3(-.5f,.5f,0)},new[]{0,1,2,0,2,3});}
 Mesh Crystal(){return Mesh(new[]{new Vector3(0,1,0),new Vector3(-.16f,0,0),new Vector3(0,0,.13f),new Vector3(.16f,0,0),new Vector3(0,0,-.13f),new Vector3(0,-.35f,0)},new[]{0,1,2,0,2,3,0,3,4,0,4,1,5,2,1,5,3,2,5,4,3,5,1,4});}
 // 2026-10-03, the user on the phone: 你很多都设置成这样弯弯的，都改掉吧. Every arc of this
 // script (cutting crescents, rings, chevrons, bands) is drawn as a gently bowed slash: its
 // span is held to at most 120 degrees round its middle, so no ring or near-ring is left, and
 // the curve keeps only 30% of its bow from the chord between its ends.
 Mesh Arc(float from,float to,float thickness,int steps=40){if(species.StartsWith("b"))thickness*=1.28f;
  float mid=(from+to)*.5f,half=Mathf.Min(Mathf.Abs(to-from)*.5f,60f);from=mid-half;to=mid+half;
  Vector3 A=new Vector3(Mathf.Cos(from*Mathf.Deg2Rad),Mathf.Sin(from*Mathf.Deg2Rad),0),B=new Vector3(Mathf.Cos(to*Mathf.Deg2Rad),Mathf.Sin(to*Mathf.Deg2Rad),0);
  var v=new Vector3[(steps+1)*2];var triangles=new int[steps*6];for(int i=0;i<=steps;i++){float u=(float)i/steps,a=Mathf.Lerp(from,to,u)*Mathf.Deg2Rad;float taper=Mathf.Sin(u*Mathf.PI);
   Vector3 radial=new Vector3(Mathf.Cos(a),Mathf.Sin(a),0),chord=Vector3.Lerp(A,B,u),p=chord+(radial-chord)*.3f;
   v[2*i]=p;v[2*i+1]=p-radial*thickness*taper;if(i<steps){int j=i*6,k=i*2;triangles[j]=k;triangles[j+1]=k+2;triangles[j+2]=k+1;triangles[j+3]=k+1;triangles[j+4]=k+2;triangles[j+5]=k+3;}}return Mesh(v,triangles);}
 Mesh Ring(){return Arc(0,360,.07f,64);}
 void Build(){
  if(intent=="guard"||intent=="escorted"){for(int i=0;i<7;i++)Add("Protective interlocked facet",Crystal(),intent=="escorted"?new Color(.24f,.65f,.88f,.52f):new Color(.48f,.62f,.73f,.72f));for(int i=0;i<2;i++)Add("Shield perimeter",Ring(),new Color(.69f,.87f,1,.85f));return;}
  if(intent.Contains("charge")||intent=="tower_raised_blade"){for(int i=0;i<9;i++)Add("Organ charged filament",Crystal(),species=="saltmaw"?Salt:species=="frilled-naga"?Violet:Gold);return;}

  if(intent=="tower_mend"){for(int i=0;i<14;i++)Add("Back sac golden secretion",Crystal(),new Color(.85f,.79f,.42f,.8f));return;}
  if(intent=="tower_poison"){for(int i=0;i<22;i++)Add("Finite poison breath lobe",Quad(),new Color(.40f,.57f,.20f,.58f),true);for(int i=0;i<7;i++)Add("Salt droplets",Crystal(),Ivory);return;}
  if(intent=="tower_salt_spike"){for(int i=0;i<7;i++)Add("Faceted salt lance",Crystal(),i%2==0?Ivory:Salt);for(int i=0;i<10;i++)Add("Salt shard impact",Crystal(),Ivory);return;}
  if(intent=="tower_empower"){for(int i=0;i<7;i++)Add("Crown articulated ray",Crystal(),Violet);for(int i=0;i<3;i++)Add("Crown orbit",Ring(),new Color(.78f,.60f,1,.75f));return;}
  if(intent=="tower_sound_arrow"){for(int i=0;i<5;i++)Add("Compressed sound chevron",Arc(25,155,.16f),i==0?Ivory:Violet);for(int i=0;i<4;i++)Add("Resonance wake",Ring(),new Color(.58f,.39f,1,.55f));return;}
  if(species=="stonehide"){for(int i=0;i<15;i++)Add("Stone pressure ridge",Crystal(),new Color(.48f,.51f,.59f));for(int i=0;i<3;i++)Add("Stone concentric impact",Ring(),new Color(.74f,.69f,.49f,.7f));return;}
  if(species=="b02"){for(int i=0;i<5;i++)Add("Abductor leather restraint",Arc(-150,145,.11f),new Color(.34f,.18f,.095f,.95f));for(int i=0;i<6;i++)Add("Brass restraint rivet",Crystal(),Gold);return;}
  if(species=="b04"){Add("Mechanical copper nib",Crystal(),new Color(.53f,.78f,.63f));for(int i=0;i<5;i++)Add("Overwritten broken seal",Arc(i*72,i*72+56,.13f),new Color(.27f,.65f,.47f,.9f));for(int i=0;i<9;i++)Add("Ink cancellation stroke",Quad(),new Color(.045f,.09f,.075f,.95f));return;}
  if(species=="b05")return;
  if(species=="b06"){for(int i=0;i<14;i++)Add("Pressed iron chain link",Ring(),new Color(.48f,.55f,.60f));for(int i=0;i<3;i++)Add("Anchor barbed head",Crystal(),new Color(.61f,.69f,.74f));return;}
  if(species.StartsWith("b03")){for(int i=0;i<4;i++)Add("Drowned crescent wave",Arc(-100,100,.23f),i==0?new Color(.66f,.90f,1,.9f):new Color(.12f,.48f,.79f,.6f));for(int i=0;i<9;i++)Add("Sea spray",Quad(),new Color(.4f,.79f,1,.6f),true);return;}
  if(intent=="tower_piercing_claw"||intent=="tower_heavy_claw"){for(int i=0;i<4;i++)Add("Deep marrow rupture",Arc(-80,80,.18f),new Color(.34f,.12f,.53f,.85f));for(int i=0;i<4;i++)Add("Bruised claw fracture",Arc(-75,75,.09f),new Color(.62f,.32f,.73f,.8f));return;}
  int count=intent=="tower_tail_sweep"?2:intent=="tower_heavy_cut"?2:3;
  for(int i=0;i<count;i++)Add("Solid edged cutting crescent",Arc(-125,100,i==0?.24f:.07f),species=="ironclaw"?new Color(.67f,.78f,.24f,i==0?.75f:.55f):i==0?new Color(.8f,.91f,1,.85f):Gold);
  for(int i=0;i<8;i++)Add("Directed steel fragments",Crystal(),Ivory);
 }
 void Pose(int i,Vector3 position,Vector3 scale,Quaternion rotation,float alpha=1){var p=pieces[i];if(species.StartsWith("b")){scale*=p.loose?1.45f:1.22f;if(p.loose&&i%2!=0)alpha=0;}p.t.position=position;p.t.localScale=scale;p.t.rotation=rotation;var c=p.color;c.a*=Mathf.Clamp01(alpha)*intensity*impactBodyFade;p.m.SetColor("_Color",c);}
 static Quaternion Face=>Camera.main?Quaternion.LookRotation(Camera.main.transform.forward):Quaternion.identity;
 public void Tick(float age){
  if(bountyRound2){bountyRound2.Draw(age,ambient,intensity);return;}
  if(finalVfx){finalVfx.intensity=intensity;finalVfx.Step(age);return;}
  if(spectacle){if(species=="stonehide"&&(intent=="archive_slam"||intent=="slam"))TickStoneJaw(age);else TickReadable(age);return;}
  TickOrgans(age);TickSpectacle(age);
  if(!this||target==null)return;Vector3 end=target();float f=Mathf.Clamp01(age/contact),after=Mathf.Max(0,age-contact),fade=age<contact?1:Mathf.Clamp01(1-after/.62f);var center=Vector3.Lerp(source,end,f);var flight=Quaternion.FromToRotation(Vector3.up,(end-source).normalized);bool landed=age>=contact;

  if(intent=="guard"||intent=="escorted"){
   var p=source+Vector3.back*.65f;for(int i=0;i<7;i++){float a=i*Mathf.PI*2/7;Pose(i,p+new Vector3(Mathf.Cos(a)*.50f,Mathf.Sin(a)*.66f,0),new Vector3(1.6f,.75f,1),Face*Quaternion.Euler(0,0,a*Mathf.Rad2Deg-90),1);}
   for(int i=7;i<9;i++)Pose(i,p,new Vector3(.78f+(i-7)*.08f,1.02f+(i-7)*.08f,1),Face,1);return;
  }
  if(intent.Contains("charge")||intent=="tower_raised_blade"){
   for(int i=0;i<9;i++){float a=i*2.399f+Time.time;Pose(i,source+new Vector3(Mathf.Cos(a)*.45f,Mathf.Sin(a)*.33f,Mathf.Sin(a)*.13f),new Vector3(.10f,.19f,.1f),Quaternion.Euler(0,0,-a*Mathf.Rad2Deg),.7f);}return;
  }
  if(intent=="tower_mend") {for(int i=0;i<organStart;i++){float a=i*2.399f+age;var p=source+new Vector3(Mathf.Cos(a)*.48f,.15f+Mathf.Sin(a)*.25f+f*.3f,Mathf.Sin(a)*.2f);Pose(i,p,Vector3.one*(.09f+Mathf.Sin(age*6+i)*.025f),Quaternion.Euler(0,i*36,age*70),fade);}return;}
  if(intent=="tower_poison"){
   for(int i=0;i<22;i++){float q=Mathf.Clamp01(f-i*.018f),a=i*2.399f+age*.8f;float radius=.16f+q*.65f;var p=Vector3.Lerp(source,end,q)+new Vector3(Mathf.Cos(a)*radius,Mathf.Sin(a)*radius*.55f,.03f*i);float size=.5f+q*.9f;Pose(i,p,new Vector3(size,size,1),Face,fade*.85f);}
   for(int i=22;i<organStart;i++){float a=i*2.39f;Pose(i,center+new Vector3(Mathf.Cos(a)*.35f,Mathf.Sin(a)*.25f,0),Vector3.one*.08f,flight,fade);}return;
  }
  if(intent=="tower_salt_spike"){
   for(int i=0;i<7;i++){float a=i*2.399f;var offset=new Vector3(Mathf.Cos(a)*.22f,Mathf.Sin(a)*.22f,0);Pose(i,center+offset,new Vector3(.32f,1.65f,.32f),flight,landed?fade*.25f:1);}
   for(int i=7;i<organStart;i++){float a=i*2.399f;Pose(i,end+new Vector3(Mathf.Cos(a),Mathf.Sin(a),.2f)*after*2.4f,Vector3.one*.18f,Quaternion.Euler(i*31,age*320,i*13),landed?fade:0);}return;
  }
  if(intent=="tower_empower"){
   Vector3 crown=landed?end+Vector3.up*.45f:source;
   for(int i=0;i<7;i++){float a=i*Mathf.PI*2/7;Pose(i,crown+new Vector3(Mathf.Cos(a)*.42f,Mathf.Sin(a)*.23f,.05f),new Vector3(.35f,.40f+.20f*Mathf.Abs(Mathf.Cos(a)),.35f),Quaternion.Euler(0,0,-a*Mathf.Rad2Deg+90),fade);}
   for(int i=7;i<10;i++)Pose(i,crown,new Vector3(.43f+(i-7)*.12f,.26f+(i-7)*.10f,1),Face*Quaternion.Euler(0,0,age*(i%2==0?75:-75)),fade*.75f);return;
  }
  if(intent=="tower_sound_arrow"){
   for(int i=0;i<5;i++){var p=Vector3.Lerp(source,end,Mathf.Clamp01(f-i*.07f));float size=.46f-i*.045f;Pose(i,p,new Vector3(size,size,1),Face*Quaternion.Euler(0,0,180),fade);}
   for(int i=5;i<9;i++){float q=Mathf.Repeat(age*1.4f+(i-5)*.23f,1);Pose(i,Vector3.Lerp(source,end,q),Vector3.one*(.20f+q*.55f+(landed?after:0)),Face,fade*.7f);}return;
  }
  if(species=="stonehide"){
   for(int i=0;i<15;i++){float q=i/14f;var p=Vector3.Lerp(source,end,q);p.y=.06f;float onset=Mathf.Clamp01((f-q)*8);float peak=onset*Mathf.Clamp01(1-after*2);Pose(i,p+new Vector3(Mathf.Sin(i*2.3f)*.26f,0,0),new Vector3(.9f,.16f+peak*.72f,.9f),Quaternion.Euler(0,i*51,18),peak);}
   for(int i=15;i<18;i++){var p=end;p.y=.05f;float r=(.45f+(i-15)*.25f)+after*2;Pose(i,p,new Vector3(r,r,1),Quaternion.Euler(90,0,0),landed?fade:0);}return;
  }
  if(species=="b02"){
   for(int i=0;i<5;i++){float r=.75f-f*.34f;Pose(i,center+Vector3.up*(i-2)*.19f,new Vector3(r,r*.53f,1),Quaternion.Euler(58,age*130+i*46,i*21),fade);}
   for(int i=5;i<11;i++){float a=i*1.04f+age*3;Pose(i,center+new Vector3(Mathf.Cos(a)*.43f,Mathf.Sin(a)*.4f,0),Vector3.one*.08f,Quaternion.Euler(0,0,i*60),fade);}return;
  }
  if(species=="b04"){
   Pose(0,center,new Vector3(.7f,.85f,.7f),flight,landed?0:1);
   for(int i=1;i<6;i++)Pose(i,end,new Vector3(.65f,.65f,1),Face*Quaternion.Euler(0,0,landed?after*45:0),landed?fade:0);
   for(int i=6;i<15;i++){float q=(i-6)/8f;Pose(i,end+new Vector3((q-.5f)*.9f,Mathf.Sin(i*8)*.32f,0),new Vector3(.12f,.32f,1),Face*Quaternion.Euler(0,0,-28),landed?fade:0);}return;
  }
  if(species=="b05"){
   if(!silkStarted&&!landed){silkStarted=true;var asset=Resources.Load<EffekseerEffectAsset>("ChurchSpellArt/BountyEffekseer/SilkTravel");if(!asset)Debug.LogError("Missing SilkTravel");else{var p=EffekseerPlayEffectParameters.Create(center);p.SetScale(Vector3.one);silkTravel=EffekseerSystem.PlayEffect(asset,p);}}
   if(silkStarted&&!silkStopped){silkTravel.SetLocation(center);if(landed){silkTravel.Stop();silkStopped=true;}}return;
  }
  if(species=="b06"){
   for(int i=0;i<14;i++){float q=(i+.5f)/14;var p=Vector3.Lerp(source,center,q)+Vector3.down*Mathf.Sin(q*Mathf.PI)*.3f;Pose(i,p,new Vector3(.095f,.15f,.09f),Quaternion.Euler(i%2==0?0:70,0,0),fade);}
   for(int i=14;i<17;i++)Pose(i,center+Vector3.right*(i-15)*.22f,new Vector3(.65f,i==15?.8f:.50f,.65f),flight*Quaternion.Euler(0,0,(i-15)*60),fade);return;
  }
  if(species.StartsWith("b03")){
   bool heavy=intent=="heavy_strike";for(int i=0;i<4;i++){float size=(heavy?1.15f:.7f)-i*.11f;Pose(i,Vector3.Lerp(source,end,Mathf.Clamp01(f-i*.06f)),new Vector3(size,size*.65f,1),Face*Quaternion.Euler(0,0,age*75),fade);}
   for(int i=4;i<13;i++){float a=i*2.399f;Pose(i,center+new Vector3(Mathf.Cos(a)*after*2,Mathf.Sin(a)*after*1.4f,0),Vector3.one*(.25f+after*.4f),Face,landed?fade*.7f:0);}return;
  }
  if(intent=="tower_piercing_claw"||intent=="tower_heavy_claw"){
   bool heavy=intent=="tower_heavy_claw";for(int i=0;i<4;i++){var off=new Vector3((i-1.5f)*.28f,0,0);Pose(i,end+off,new Vector3(.25f+after*.35f,1.05f+after*.3f,1),Face*Quaternion.Euler(0,0,heavy?-16:35),landed?fade:0);}
   for(int i=4;i<8;i++)Pose(i,end+Vector3.right*(i-5.5f)*.2f,new Vector3(.16f,.75f,1),Face*Quaternion.Euler(0,0,22),landed?fade:0);return;
  }
  int blades=intent=="tower_tail_sweep"?2:intent=="tower_heavy_cut"?2:3;bool tail=intent=="tower_tail_sweep";float flip=intent=="tower_cut_second"?-1:1;
  for(int i=0;i<blades;i++){float size=intent=="tower_heavy_cut"?1.15f:tail?1.25f:.7f;var rotation=tail?Quaternion.Euler(80,age*150,0):Face*Quaternion.Euler(0,0,flip*(age*200+25));Pose(i,center+Vector3.forward*i*.035f,new Vector3(size-i*.08f,size-i*.08f,1),rotation,fade);}
  for(int i=blades;i<organStart;i++){float angle=i*2.399f;Pose(i,end+new Vector3(Mathf.Cos(angle),Mathf.Sin(angle),0)*after*2,new Vector3(.09f,.22f,.09f),Quaternion.Euler(0,0,angle*Mathf.Rad2Deg),landed?fade:0);}
 }

 // Curved, volumetric horn and membrane meshes give the demons silhouettes
 // distinct from the hero's tarot effects. No collision/damage is owned here.
 Mesh Horn(){
  const int rings=13,sides=6;var v=new Vector3[rings*sides];var tr=new int[(rings-1)*sides*6];
  for(int j=0;j<rings;j++){float u=j/(float)(rings-1),r=.13f*Mathf.Pow(1-u,.7f)+.003f;
   for(int k=0;k<sides;k++){float a=k*Mathf.PI*2/sides;v[j*sides+k]=new Vector3(u*u*.48f+Mathf.Cos(a)*r,u,Mathf.Sin(a)*r);}
   if(j<rings-1)for(int k=0;k<sides;k++){int a=j*sides+k,b=j*sides+(k+1)%sides,c=a+sides,d=b+sides,o=(j*sides+k)*6;tr[o]=a;tr[o+1]=c;tr[o+2]=b;tr[o+3]=b;tr[o+4]=c;tr[o+5]=d;}}
  return Mesh(v,tr);
 }
 Mesh Sac(){
  const int lat=10,lon=14;var v=new Vector3[(lat+1)*(lon+1)];var tr=new int[lat*lon*6];
  for(int j=0;j<=lat;j++)for(int k=0;k<=lon;k++){float a=j*Mathf.PI/lat,b=k*Mathf.PI*2/lon;float r=.5f*(1+.07f*Mathf.Sin(b*3+a*5));v[j*(lon+1)+k]=new Vector3(Mathf.Sin(a)*Mathf.Cos(b)*r,Mathf.Cos(a)*.58f,Mathf.Sin(a)*Mathf.Sin(b)*r);if(j<lat&&k<lon){int x=j*(lon+1)+k,o=(j*lon+k)*6;tr[o]=x;tr[o+1]=x+1;tr[o+2]=x+lon+1;tr[o+3]=x+1;tr[o+4]=x+lon+2;tr[o+5]=x+lon+1;}}
  return Mesh(v,tr);
 }

 Mesh BoneLink(){
  const int rings=13,sides=8;var v=new Vector3[rings*sides];var tr=new int[(rings-1)*sides*6];
  for(int j=0;j<rings;j++){float u=j/(float)(rings-1),r=.10f+.09f*Mathf.Pow(Mathf.Abs(u-.5f)*2,3);
   for(int k=0;k<sides;k++){float a=k*Mathf.PI*2/sides;v[j*sides+k]=new Vector3(Mathf.Sin(u*Mathf.PI)*.10f+Mathf.Cos(a)*r,u,Mathf.Sin(a)*r*.80f);}
   if(j<rings-1)for(int k=0;k<sides;k++){int a=j*sides+k,b=j*sides+(k+1)%sides,c=a+sides,d=b+sides,o=(j*sides+k)*6;tr[o]=a;tr[o+1]=c;tr[o+2]=b;tr[o+3]=b;tr[o+4]=c;tr[o+5]=d;}}
  return Mesh(v,tr);
 }
 void BuildOrgans(){
  organStart=pieces.Count;
  if(species!="stonehide"&&species!="saltmaw"&&species!="shellback"&&species!="ironclaw"&&species!="frilled-naga"&&species!="boneclaw")return;
  var bone=new Color(.66f,.64f,.69f,.96f);var flesh=new Color(.42f,.065f,.19f,.82f);
  for(int i=0;i<18;i++){
   bool bulb=species=="saltmaw"||species=="shellback";
   Color c=species=="saltmaw"?new Color(.52f,.65f,.12f,.65f):species=="shellback"?new Color(.75f,.40f,.12f,.88f):species=="frilled-naga"?flesh:bone;
   Mesh shape=bulb&&species!="saltmaw"?Sac():Horn();
   if(species=="boneclaw")shape=i%2==1?Sac():(i%6==4?Horn():BoneLink());
   if(species=="ironclaw")shape=i%9<3?BoneLink():Horn();
   if(species=="boneclaw"||species=="ironclaw")c=i%2==1?new Color(.40f,.32f,.43f,.95f):bone;
   var piece=Add("Demonic organ "+i,shape,species=="saltmaw"?new Color(.43f,.52f,.12f,.50f):(species=="boneclaw"||species=="ironclaw")?c:i%7==0?flesh:c);piece.m.SetFloat("_Glow",i%4==0?.42f:.12f);piece.m.SetFloat("_Organic",species=="boneclaw"||species=="ironclaw"?0:1);if(species=="boneclaw"||species=="ironclaw"||species=="stonehide"){piece.m.SetFloat("_Cull",2);piece.m.SetFloat("_Depth",1);}
  }
 }
 void TickOrgans(float age){
  if(!spectacle||target==null)return;
  bool charge=intent.Contains("charge")||intent=="tower_raised_blade",guard=intent=="guard";
  float f=Mathf.Clamp01(age/Mathf.Max(.01f,contact)),post=Mathf.Max(0,age-contact),fade=charge||guard?1:1-Mathf.Clamp01(post/.60f);
  Vector3 end=target(),center=Vector3.Lerp(source,end,f);float clock=ambient?Time.time:age;
  for(int j=0;j<18;j++){
   float a=j*2.39996f,beat=1+.09f*Mathf.Sin(clock*9+j*.8f);Vector3 p=center,scale=Vector3.one;Quaternion rot=Face;float alpha=fade;
   if(charge){
    // The organs gather around the actual casting body, contracting in waves.
    p=source+new Vector3(Mathf.Cos(a)*.52f,Mathf.Sin(a)*.37f,Mathf.Sin(a*2)*.20f);
    scale=new Vector3(.20f,.27f,.20f)*beat;rot=Face*Quaternion.Euler(0,0,a*Mathf.Rad2Deg+clock*12);
   }else if(species=="stonehide"){
    // A shield is a clenched double jaw; the slam erupts as paired fossil teeth.
    if(guard){float side=j%2==0?1:-1;float q=(j/2)/8f;p=source+Vector3.back*.72f+new Vector3((q-.5f)*1.45f,side*(.38f+.10f*Mathf.Sin(clock*2)),0);scale=new Vector3(.48f,.60f,.5f);rot=Face*Quaternion.Euler(0,0,side>0?180:0);}
    else {float q=(j/2)/8f,on=Mathf.Clamp01((f-q)*7);p=Vector3.Lerp(source,end,q);p.y=.05f;p.x+=(j%2==0?-1:1)*.30f;scale=new Vector3(.68f,on*(.8f+q*.4f),.65f);rot=Quaternion.Euler(0,j*31,j%2==0?-20:20);alpha*=on;}
   }else if(species=="saltmaw"){
    // Sticky pustules stretch with the breath, then burst away from its head.
    float q=Mathf.Clamp01(f-j*.027f),r=.08f+q*(.14f+.36f*Mathf.Abs(Mathf.Sin(j*5.7f)));
    p=Vector3.Lerp(source,end,q)+new Vector3(Mathf.Cos(a+clock*.5f)*r,Mathf.Sin(a+clock*.3f)*r*.65f,Mathf.Sin(a)*.28f);
    if(post>0)p+=new Vector3(Mathf.Cos(a),Mathf.Sin(a)-.4f,0)*post*1.8f;
    scale=new Vector3(.13f+.07f*Mathf.Sin(j*3.7f),.48f+(.5f+.5f*Mathf.Sin(j*7.3f))*.85f,.12f)*beat;rot=Quaternion.FromToRotation(Vector3.up,end-source);
   }else if(species=="shellback"){
    // Its dorsal organ carries a cluster of translucent eggs, no healing beam.
    p=source+new Vector3(Mathf.Cos(a)*(.23f+j*.012f),Mathf.Sin(a)*.27f+.1f,Mathf.Sin(a*2)*.23f);
    scale=Vector3.one*(.20f+.09f*Mathf.Sin(j*1.7f))*beat;rot=Quaternion.Euler(j*21,clock*22,j*43);
   }else if(species=="ironclaw"){
    // Two thick articulated sickles. Six short barbs grow from each shell,
    // never a cloud of parallel metallic needles.
    int part=j%9;float side=j<9?1:-1,close=Mathf.Sin(f*Mathf.PI*.5f);
    if(part<3){float q=part/2f,theta=(q-.5f)*2.0f;p=center+new Vector3(Mathf.Sin(theta)*.85f,side*(.72f*Mathf.Cos(theta)-close*.22f),0);scale=new Vector3(.85f,.68f,.72f);rot=Face*Quaternion.Euler(0,0,side*(90-theta*Mathf.Rad2Deg));}
    else {float q=(part-3)/5f,theta=(q-.5f)*2.0f;p=center+new Vector3(Mathf.Sin(theta)*.83f,side*(.68f*Mathf.Cos(theta)-close*.22f),-.02f);scale=new Vector3(.45f,.27f,.45f);rot=Face*Quaternion.Euler(0,0,side>0?180+Mathf.Sin(theta)*45:-Mathf.Sin(theta)*45);}
   }else if(species=="frilled-naga"){
    // An asymmetric ribbed throat opens and projects its parasitic crown.
    float radius=.45f+.2f*Mathf.Sin(f*Mathf.PI);p=(intent=="tower_empower"&&f>=1?end+Vector3.up*.35f:center)+new Vector3(Mathf.Cos(a)*radius,Mathf.Sin(a)*radius*.65f,Mathf.Sin(a*2)*.10f);
    scale=new Vector3(.22f,.55f*beat,.22f);rot=Face*Quaternion.Euler(0,0,a*Mathf.Rad2Deg-90+Mathf.Sin(clock*4+j)*12);
   }else {
    // Three fingers, each with three separate phalanges and knuckles.
    // The distal joints curl further, producing a readable closing hand.
    int digit=j/6,segment=(j%6)/2;bool joint=j%2==1;
    float curl=Mathf.Lerp(12,68,Mathf.SmoothStep(0,1,f)),spread=(digit-1)*24;
    Vector3 local=new Vector3((digit-1)*.44f,.64f+(digit==1?.12f:0),0);
    for(int k=0;k<segment;k++){float aa=(180+spread+k*curl)*Mathf.Deg2Rad;local+=new Vector3(-Mathf.Sin(aa),Mathf.Cos(aa),0)*(k==0?.49f:.40f);}
    float angle=180+spread+segment*curl;float length=segment==0?.49f:segment==1?.40f:.42f;
    p=center+Face*local;
    if(intent=="tower_heavy_claw")p+=Vector3.up*(1-f)*.6f;
    scale=joint?Vector3.one*.15f:new Vector3(.75f,length,.70f);
    rot=Face*Quaternion.Euler(0,0,angle);

   }
   p = (charge||guard?source:center) + (p-(charge||guard?source:center))*1.28f;
   Pose(organStart+j,p,scale*1.45f,rot,alpha);
  }
 }

 // Species-specific rupture, casting mantle and lingering matter. Visual only.
 void BuildSpectacle(){
  spectacleStart=pieces.Count;
  spectacle=species=="stonehide"||species=="saltmaw"||species=="shellback"||species=="ironclaw"||species=="frilled-naga"||species=="boneclaw";
  if(!spectacle)return;
  Color c=species=="stonehide"?new Color(.66f,.61f,1):species=="saltmaw"?new Color(.62f,.83f,.08f):species=="shellback"?new Color(1,.56f,.12f):species=="ironclaw"?new Color(.77f,1,.20f):species=="frilled-naga"?new Color(.95f,.10f,.48f):new Color(.62f,.24f,1);
  for(int j=0;j<38;j++){
   bool cloud=j<8;Mesh mesh=cloud?Quad():j<14?Arc(-100,115,.11f,48):j<30?(species=="shellback"||species=="saltmaw"?Sac():Horn()):Arc(-105,110,.12f,32);
   var v=Add("Demon rupture "+j,mesh,new Color(c.r,c.g,c.b,cloud?.65f:.90f),cloud);
   v.m.SetFloat("_Glow",cloud?0:j<14?1.8f:1.05f);
   if(j>=14&&j<30){v.m.SetFloat("_Organic",1);v.m.SetFloat("_Glow",.15f);v.m.SetFloat("_Cull",2);v.m.SetFloat("_Depth",1);}
  }
 }
 void TickSpectacle(float age){
  if(!spectacle||target==null)return;
  bool held=ambient||intent=="guard"||intent.Contains("charge")||intent=="tower_raised_blade";
  bool support=intent=="tower_mend"||intent=="tower_empower";
  float f=Mathf.Clamp01(age/Mathf.Max(.01f,contact)),post=Mathf.Max(0,age-contact),fade=1-Mathf.Clamp01(post/.62f);
  float clock=ambient?Time.time:age;Vector3 end=target(),center=Vector3.Lerp(source,end,f);
  if(held)center=source;
  if(support)center=f<1?source:end;
  for(int j=0;j<38;j++){
   float a=j*2.39996f;Vector3 p=center,sc=Vector3.one;Quaternion rot=Face;float alpha=fade;
   if(j<8){
    float radius=held?.55f:.35f+f*.35f+post*2.5f;
    p+=new Vector3(Mathf.Cos(a+clock)*radius,Mathf.Sin(a+clock)*radius*.75f,.18f);
    float size=held?1.0f:1.15f+post*2.2f;sc=new Vector3(size,size,1);alpha*=held?.38f:.75f;
    if(species=="stonehide"){p.y=.15f+j*.06f;sc*=1.2f;}
   }else if(j<14){
    int k=j-8;float size=held?.8f+k*.055f:.45f+k*.08f+post*(1.8f+k*.1f);
    sc=new Vector3(size,size*(species=="ironclaw"?.52f:1),1);
    rot=Face*Quaternion.Euler(0,0,k*57+clock*(k%2==0?150:-130));
    alpha*=held?.35f:post>0?Mathf.Exp(-post*5.5f)*.75f:.35f;
    if(k>2)alpha=0;
    if(species=="stonehide"||species=="shellback"){p.y=.1f+k*.025f;rot=Quaternion.Euler(90,clock*95+k*50,0);}
    if(species=="frilled-naga"){sc.y*=1.35f;p+=Vector3.up*.2f;}
   }else if(j<30){
    float burst=held?.55f:post>0?.5f+post*4.5f:.40f+f*.3f;
    p+=new Vector3(Mathf.Cos(a)*burst,Mathf.Sin(a)*burst*.8f-post*post*2,Mathf.Sin(a*1.7f)*burst*.45f);
    sc=species=="saltmaw"||species=="shellback"?new Vector3(.13f,.32f+.18f*Mathf.Abs(Mathf.Sin(a)),.10f):new Vector3(.28f,.38f+.24f*Mathf.Abs(Mathf.Sin(a)),.28f);
    rot=Face*Quaternion.Euler(j*19,clock*180,a*Mathf.Rad2Deg-90);
    alpha*=held?.6f:post>0?1:.45f;
    if(species=="stonehide"){p.y=Mathf.Max(.08f,p.y);sc*=1.35f;}
   }else{
    int k=j-30;float size=.55f+k*.06f+post*1.2f;
    sc=new Vector3(size,species=="boneclaw"?size*1.65f:size*.55f,1);
    p+=Vector3.right*(k-3.5f)*.13f;
    rot=Face*Quaternion.Euler(0,0,species=="ironclaw"?(intent=="tower_cut_second"?-35:35):species=="boneclaw"?-25:k*45+clock*70);
    alpha*=held?0:post>0?fade*.7f:.12f;
    if(k>2)alpha=0;
   }
   Pose(spectacleStart+j,p,sc,rot,alpha);
  }
 }


 void TickReadable(float age){
  if(target==null)return;
  for(int i=0;i<pieces.Count;i++)Pose(i,Vector3.zero,Vector3.zero,Quaternion.identity,0);
  Vector3 end=target(),center=Vector3.Lerp(source,end,Mathf.Clamp01(age/Mathf.Max(.01f,contact)));
  float f=Mathf.Clamp01(age/Mathf.Max(.01f,contact)),post=Mathf.Max(0,age-contact),fade=1-Mathf.Clamp01(post/.5f);
  bool held=ambient||intent=="guard"||intent.Contains("charge")||intent=="tower_raised_blade";
  if(held){
   // Sparse plates at the sides leave the face and torso visible.
   if(species=="stonehide"&&intent=="guard"){
    for(int j=0;j<6;j++){
     float sign=j<3?-1:1;Vector3 pos=source+new Vector3(sign*.62f,(j%3-1)*.35f,-.4f);
     Pose(organStart+j,pos,new Vector3(.28f,.45f,.28f),Face*Quaternion.Euler(0,0,sign*65),.85f);
    }
   }else for(int j=0;j<3;j++){
    float a=Time.time*1.2f+j*2.09f;
    Pose(spectacleStart+8+j,source,new Vector3(.55f,.32f,1),Face*Quaternion.Euler(0,0,a*Mathf.Rad2Deg),.38f);
   }
   return;
  }
  if(species=="saltmaw"){
   if(intent=="tower_poison"){
    // A travelling narrow stream, not a filled billboard in front of the hero.
    for(int j=0;j<16;j++){
     float q=Mathf.Clamp01(f-j*.04f),a=j*2.4f+age*4;
     Vector3 pos=Vector3.Lerp(source,end,q)+new Vector3(Mathf.Sin(a)*.13f,Mathf.Cos(a)*.10f,0);
     float width=.28f+q*.20f;
     Pose(j,pos,new Vector3(width,width*.70f,1),Face,fade*.32f);
    }
    for(int j=0;j<6;j++){
     float a=j*2.4f;Vector3 pos=center+new Vector3(Mathf.Cos(a),Mathf.Sin(a),0)*(.1f+post*1.9f);
     Pose(organStart+j,pos,new Vector3(.05f,.25f,.05f),Quaternion.FromToRotation(Vector3.up,end-source),fade*.65f);
    }
   }else{
    for(int j=0;j<3;j++)Pose(j,center+Vector3.right*(j-1)*.12f,new Vector3(.12f,.95f,.12f),Quaternion.FromToRotation(Vector3.up,end-source),post>0?0:1);
    ImpactStrokes(end,post,fade,3);
   }
   return;
  }
  if(species=="shellback"){
   if(intent=="tower_mend"){
    // Small dorsal pulses then sparse rising motes on the recipient.
    for(int j=0;j<4;j++){
     float a=j*2.4f;Vector3 pos=source+new Vector3(Mathf.Cos(a)*.18f,Mathf.Sin(a)*.17f,0);
     Pose(organStart+j,pos,Vector3.one*(.10f+.025f*Mathf.Sin(age*12+j)),Face,fade*.65f);
    }
    if(post>0)for(int j=0;j<8;j++){
     float a=j*2.4f;Vector3 pos=end+new Vector3(Mathf.Cos(a)*.38f,-.45f+post*1.8f+j*.08f,Mathf.Sin(a)*.20f);
     Pose(spectacleStart+14+j,pos,new Vector3(.025f,.13f,.025f),Quaternion.identity,fade);
     pieces[spectacleStart+14+j].m.SetColor("_Color",new Color(.3f,.9f,.52f,fade));
    }
   }else{ImpactStrokes(end,post,fade,3);}
   return;
  }
  if(species=="ironclaw"){
   // Two travelling sickle streaks cross, then separate; no detached chunky jaws.
   float sign=intent=="tower_cut_second"?-1:1;
   for(int j=0;j<2;j++){
    float side=j==0?-1:1;float size=intent=="tower_heavy_cut"?1.2f:.9f;
    Vector3 pos=center+Vector3.right*side*(.65f*(1-f)+post*1.3f);
    Pose(spectacleStart+8+j,pos,new Vector3(size,size*.4f,1),Face*Quaternion.Euler(0,0,side*sign*(55-f*35)),fade*.9f);
   }
   ImpactStrokes(end,post,fade,4);return;
  }
  if(species=="frilled-naga"){
   if(intent=="tower_empower"){
    Vector3 pos=f<1?source:end+Vector3.up*.55f;
    for(int j=0;j<5;j++){
     float a=(j/4f*150+15)*Mathf.Deg2Rad;
     Pose(organStart+j,pos+new Vector3(Mathf.Cos(a)*.30f,Mathf.Sin(a)*.18f,0),new Vector3(.075f,.22f,.075f),Face*Quaternion.Euler(0,0,a*Mathf.Rad2Deg-90),fade*.8f);
    }
   }else{
    for(int j=0;j<3;j++){
     float q=Mathf.Clamp01(f-j*.12f);Vector3 pos=Vector3.Lerp(source,end,q);
     Pose(spectacleStart+8+j,pos,new Vector3(.42f+j*.10f,.58f+j*.10f,1),Face*Quaternion.Euler(0,0,age*120+j*110),fade*.75f);
    }
    ImpactStrokes(end,post,fade,5);
   }
   return;
  }
  // Three long, separated scratches with a brief stagger; no floating bone fist.
  for(int j=0;j<3;j++){
   float local=age-contact+.12f-j*.035f;
   if(local<0)continue;float visible=1-Mathf.Clamp01(local/.48f);
   float angle=intent=="tower_tail_sweep"?75:intent=="tower_heavy_claw"?-15:32;
   Pose(spectacleStart+8+j,end+Vector3.right*(j-1)*.22f,new Vector3(.24f,1.05f,1),Face*Quaternion.Euler(0,0,angle),visible);
  }
  ImpactStrokes(end,post,fade,3);
 }
 void ImpactStrokes(Vector3 end,float post,float fade,int count){
  if(post<=0)return;
  float burst=1-Mathf.Exp(-post*14);
  for(int j=0;j<count;j++){
   float a;
   if(species=="ironclaw") a=(j%2==0?-.72f:.72f)+(j/2)*.22f;
   else if(species=="frilled-naga") a=(j-1)*.92f;
   else if(species=="boneclaw") a=(j-1)*.48f+.18f*Mathf.Sin(post*18+j);
   else a=j*2.4f+.4f;
   Vector3 dir=new Vector3(Mathf.Cos(a),Mathf.Sin(a),0);
   Vector3 pos=end+dir*(.18f+burst*(species=="ironclaw"?1.6f:1.15f));
   float w=species=="ironclaw"?.30f:species=="boneclaw"?.22f:.18f;
   float h=species=="frilled-naga"?1.0f:species=="boneclaw"?.82f:.62f;
   Pose(spectacleStart+30+j,pos,new Vector3(w,h,1),Face*Quaternion.Euler(0,0,a*Mathf.Rad2Deg),fade*.92f);
   pieces[spectacleStart+30+j].m.SetColor("_Color",species=="ironclaw"?new Color(.18f,.9f,.35f,fade):species=="boneclaw"?new Color(.62f,.18f,1,fade):species=="frilled-naga"?new Color(1,.18f,.45f,fade):new Color(.72f,1,.82f,fade));
  }
 }
 void TickStoneJaw(float age){
  if(target==null)return;
  Vector3 end=target();end.y=.04f;Vector3 begin=source;begin.y=.04f;
  Vector3 direction=(end-begin).normalized,side=Vector3.Cross(Vector3.up,direction).normalized;
  // Three discrete jaw strikes. Each retracts before the next one peaks.
  for(int i=0;i<pieces.Count;i++)Pose(i,Vector3.zero,Vector3.zero,Quaternion.identity,0);
  for(int g=0;g<3;g++){
   float q=g==0?.28f:g==1?.62f:1f;
   float local=age-(contact*q-.16f),u=Mathf.Clamp01(local/.22f);
   float fade=local<0?0:1-Mathf.Clamp01((local-.23f)/.22f);
   float height=Mathf.Sin(u*Mathf.PI*.5f)*fade;
   Vector3 center=Vector3.Lerp(begin,end,q);
   for(int k=0;k<6;k++){
    float sign=k<3?-1:1,along=(k%3-1)*.30f;
    Vector3 pos=center+side*sign*Mathf.Lerp(.82f,.32f,u)+direction*along;
    var rotation=Quaternion.LookRotation(direction)*Quaternion.Euler(0,sign<0?180:0,sign*36*u);
    Pose(organStart+g*6+k,pos,new Vector3(.56f,(k%3==1?1.35f:.95f)*height,.56f),rotation,fade);
    pieces[organStart+g*6+k].m.SetFloat("_Organic",0);
    pieces[organStart+g*6+k].m.SetFloat("_Glow",.03f);
    pieces[organStart+g*6+k].m.SetColor("_Color",new Color(.67f,.60f,.48f,fade));
   }
   // A single thin ground fracture at each jaw; no stacked rings or fog.
   for(int k=0;k<5;k++){
    Vector3 pos=center+direction*(k-2)*.22f;
    Pose(g*5+k,pos,new Vector3(.14f,.025f,.42f),Quaternion.LookRotation(direction)*Quaternion.Euler(90,k%2==0?18:-18,0),fade);
    pieces[g*5+k].m.SetColor("_Color",new Color(.14f,.08f,.04f,fade));
   }
  }
  float post=age-contact;
  if(post>=0){
   // Six short debris chips thrown outward from the final contact point.
   for(int j=0;j<6;j++){
    float a=j*Mathf.PI/3+.2f,r=.35f+post*2.8f;
    Vector3 pos=end+new Vector3(Mathf.Cos(a)*r,.12f+post*2.8f-post*post*6,Mathf.Sin(a)*r*.65f);
    int n=spectacleStart+14+j;
    Pose(n,pos,new Vector3(.24f,.25f,.21f),Quaternion.Euler(j*31,post*260,j*47),1-Mathf.Clamp01(post/.5f));
    pieces[n].m.SetColor("_Color",new Color(.43f,.35f,.25f,1-Mathf.Clamp01(post/.5f)));
   }
  }
 }
 void OnDisable(){if(silkStarted)silkTravel.Stop();}
 void OnDestroy(){if(silkStarted)silkTravel.Stop();foreach(var p in pieces)if(p.m)Destroy(p.m);foreach(var mesh in meshes)if(mesh)Destroy(mesh);}
}
