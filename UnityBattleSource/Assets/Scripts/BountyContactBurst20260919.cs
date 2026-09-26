using UnityEngine;
using System.Collections.Generic;
using Effekseer;
// Contact-aged cosmetic breakup; parent attack owns cancellation and lifetime.
public sealed class BountyContactBurst20260919:MonoBehaviour {
 EffekseerHandle rupture;bool released;BountySurfaceRound2 jade,azure;
 Mesh mesh;Material mat;readonly List<Vector3> vertices=new List<Vector3>();readonly List<Vector2> uv=new List<Vector2>();readonly List<Color> colors=new List<Color>();readonly List<int> tris=new List<int>();GameObject bloom;Material bloomMat;string kind;
 public void Configure(string species){kind=species;if(kind=="b04"||kind=="b06"){var g=new GameObject(kind=="b04"?"Torn copper-jade ink contact":"Azure anchor-break contact");g.transform.SetParent(transform,false);var surface=g.AddComponent<BountySurfaceRound2>();surface.Configure(kind);if(kind=="b04")jade=surface;else azure=surface;return;}mesh=new Mesh();mesh.MarkDynamic();mat=new Material(Resources.Load<Shader>("EnemySignature/AuthoredBurstTier"));gameObject.AddComponent<MeshFilter>().sharedMesh=mesh;gameObject.AddComponent<MeshRenderer>().sharedMaterial=mat;bloom=GameObject.CreatePrimitive(PrimitiveType.Quad);Destroy(bloom.GetComponent<Collider>());bloom.transform.SetParent(transform,false);bloomMat=new Material(Resources.Load<Shader>("Shaders/ContactFractureBloom"));bloom.GetComponent<Renderer>().sharedMaterial=bloomMat;bloom.SetActive(false);}
 public void Draw(float post,Vector3 center){if(jade){DrawJade(post,center);return;}if(azure){DrawAzure(post,center);return;}if(post<0){mesh.Clear();bloom.SetActive(false);return;}var cam=Camera.main;if(!cam)return;var right=cam.transform.right;var up=cam.transform.up;var forward=cam.transform.forward;float fade=1-Mathf.Clamp01(post/.62f);Color tint=kind=="b05"?new Color(1,.12f,.32f):kind.StartsWith("b03")?new Color(.16f,.7f,1):kind=="b04"?new Color(.15f,1,.62f):kind=="b02"?new Color(1,.55f,.18f):new Color(.38f,.87f,1);
 bloom.SetActive(kind=="b01");bloom.transform.position=center-forward*.25f;bloom.transform.rotation=Quaternion.LookRotation(forward);bloom.transform.localScale=Vector3.one*(4.3f+post*2);bloomMat.SetColor("_Color",tint);bloomMat.SetFloat("_Age",post);
 vertices.Clear();uv.Clear();colors.Clear();tris.Clear();
 if(kind=="b05"||kind=="b06"){
 if(!released){released=true;var asset=Resources.Load<EffekseerEffectAsset>("ChurchSpellArt/BountyEffekseer/"+(kind=="b05"?"SilkRupture":"AnchorRupture"));if(!asset)Debug.LogError("Missing bounty rupture "+kind);else{var p=EffekseerPlayEffectParameters.Create(center);p.SetScale(Vector3.one*(kind=="b05"?.53f:1.65f));p.Speed=1.5f;rupture=EffekseerSystem.PlayEffect(asset,p);}}
 mesh.Clear();return;
 }
 if(kind!="b01"){
 float open=1-Mathf.Exp(-Mathf.Max(0,post-.025f)*24);Color c=tint*2.4f;c.a=fade;
 if(kind=="b02"){
 // Broken leather restraints recoil sideways; squared ends and stitched seams.
 for(int k=0;k<4;k++){float sign=k%2==0?-1:1;Strip(q=>center+right*sign*(.18f+open*1.5f+q*.8f)+up*((k/2-.5f)*.9f+Mathf.Sin(q*5+post*12)*.22f),up,.16f,c);}
 }else if(kind.StartsWith("b03")){
 // Two broad rising water walls, cresting upward rather than orbiting the target.
 for(int k=0;k<2;k++){int lane=k;Strip(q=>center+right*((q-.5f)*4.4f)+up*(-.85f+lane*.42f+open*(.6f+Mathf.Sin(q*Mathf.PI)*1.7f))+forward*(lane*.3f),up,.34f,c);}
 for(int k=0;k<7;k++){float x=(k-3)*.55f;Tile(center+right*x+up*(open*(1.3f+Mathf.Sin(k*2)*.5f)-.4f),right*.06f,up*.18f,c);}
 }else if(kind=="b05"){
 // Three torn curtains peel vertically; broad hems stay visibly cloth-like.
 for(int k=0;k<3;k++){int lane=k;Strip(q=>center+right*((lane-1)*(.5f+open*1.2f)+Mathf.Sin(q*8+post*13+lane)*.18f)+up*((q-.5f)*3.2f+open*.3f),right,.34f,c);}
 }else{
 // Four broken chain links tumble outward around a falling anchor crosspiece.
 for(int k=0;k<4;k++){float a=k*1.57f+.3f;Vector3 p=center+right*Mathf.Cos(a)*open*2+up*(Mathf.Sin(a)*open*1.4f-post*post*2);Vector3 u=right*Mathf.Cos(post*8+k)+up*Mathf.Sin(post*8+k),v=Vector3.Cross(forward,u);Tile(p-v*.3f,u*.24f,v*.065f,c);Tile(p+v*.3f,u*.24f,v*.065f,c);Tile(p-u*.24f,u*.065f,v*.3f,c);}
 Tile(center-up*open*.9f,right*.1f,up*.7f,c);Tile(center-up*(.5f+open*.9f),right*.65f,up*.12f,c);
 }
 }else{
 for(int k=0;k<6;k++){float delay=(k%3)*.018f,t=Mathf.Max(0,post-delay),angle=k*2.39996f+.3f;float flight=(1-Mathf.Exp(-t*12))*(1.4f+(k%3)*.28f);float extent=.85f+(k%2)*.55f;
 for(int j=0;j<=16;j++){float q=j/16f;float a=angle+q*.85f;float r=.12f+flight+q*extent;var p=center+(right*Mathf.Cos(a)+up*Mathf.Sin(a)*.85f)*r-forward*.2f;float width=Mathf.Sin(q*Mathf.PI)*(.25f+(k%3)*.09f)*fade;var side=(right*Mathf.Cos(a+1.5708f)+up*Mathf.Sin(a+1.5708f)).normalized;
 for(int s=0;s<2;s++){vertices.Add(transform.InverseTransformPoint(p+side*width*(s==0?-1:1)));uv.Add(new Vector2(s,q));var c=Color.Lerp(tint,new Color(1,.86f,.4f),k%3==0?.65f:.0f)*2;c.a=fade;colors.Add(c);}if(j<16){int i=k*34+j*2;tris.Add(i);tris.Add(i+2);tris.Add(i+1);tris.Add(i+1);tris.Add(i+2);tris.Add(i+3);}}
 }
 }
 // Brief contact compression, fast release, then recover authored proportions.
 float release=Mathf.Clamp01((post-.025f)/.055f);
 float peak=1+1.25f*Mathf.Sin(release*Mathf.PI*.5f)*Mathf.Exp(-Mathf.Max(0,post-.08f)*9);
 for(int i=0;i<vertices.Count;i++){
  Vector3 world=transform.TransformPoint(vertices[i]);Vector3 offset=world-center;
  // Preserve each species silhouette; add depth to the existing strips/plates.
  float depth=Mathf.Sin(i*.71f+post*14)*.13f*fade;
  vertices[i]=transform.InverseTransformPoint(center+offset*peak+forward*depth);
 }
 mesh.Clear();mesh.SetVertices(vertices);mesh.SetUVs(0,uv);mesh.SetColors(colors);mesh.SetTriangles(tris,0);mesh.RecalculateBounds();mat.SetFloat("_Age",post*2);
 }
 void DrawJade(float post,Vector3 center){
  if(post<0){jade.Clear();return;}var camera=Camera.main;
  Vector3 right=camera?camera.transform.right:Vector3.right,up=camera?camera.transform.up:Vector3.up,depth=camera?camera.transform.forward:Vector3.forward;
  float release=Mathf.Max(0,post-.066f),open=Mathf.SmoothStep(0,1,release/.045f)*Mathf.Exp(-Mathf.Max(0,release-.045f)*8);
  float fade=1-Mathf.SmoothStep(0,1,post/.52f);jade.Begin(release*1.45f);
  for(int k=0;k<4;k++){
   float lane=k,sign=k==1||k==3?-1:1;float span=.64f+open*(2.30f-lane*.21f);
   Color c=k==2?new Color(.97f,.64f,.22f,fade):new Color(.18f+k*.08f,1,.63f+k*.035f,fade);
   int stroke=k;
   jade.Ribbon(q=>BountyEffekseerTravel20260921.BrushPoint(center,right,up,depth,
    BountyEffekseerTravel20260921.InkStroke(stroke,q,release*1.45f),span)
    +right*sign*release*.7f-up*release*.35f,
    up,(.29f+open*.34f)*(1-lane*.10f),1.15f,c,1.9f+lane*2.71f,1.1f,
    silhouette:BountySurfaceRound2.Silhouette.Veil);
  }
  jade.Spray(center,right,up,depth,release,5.1f,18,new Color(.85f,1,.65f,.91f),3.2f);jade.End(1,1.75f);
 }
 void DrawAzure(float post,Vector3 center){
  if(post<0){azure.Clear();return;}
  if(!released){
   released=true;
   var asset=Resources.Load<EffekseerEffectAsset>("ChurchSpellArt/BountyEffekseer/AnchorRupture");
   if(asset){var p=EffekseerPlayEffectParameters.Create(center);p.SetScale(Vector3.one*1.28f);p.Speed=1.5f;rupture=EffekseerSystem.PlayEffect(asset,p);}
  }
  var camera=Camera.main;
  Vector3 right=camera?camera.transform.right:Vector3.right;
  Vector3 up=camera?camera.transform.up:Vector3.up;
  Vector3 depth=camera?camera.transform.forward:Vector3.forward;
  float release=Mathf.Max(0,post-.035f);
  float open=Mathf.SmoothStep(0,1,release/.048f)*Mathf.Exp(-Mathf.Max(0,release-.048f)*8.5f);
  float fade=1-Mathf.SmoothStep(0,1,post/.47f);
  azure.Begin(post);
  // The keel drops through the impact; two unequal, curled flukes tear away
  // in depth. This remains a forged anchor, not a generic radial blue cloud.
  azure.Ribbon(q=>center+up*((.52f-q)*(1.65f+open*1.60f))
      +right*Mathf.Sin(q*5.4f+post*4)*(.13f+open*.12f)
      +depth*Mathf.Sin(q*4.1f)*.19f,
      right,(.28f+open*.27f)*fade,1.08f,new Color(.22f,.61f,1,fade),2.3f,.82f,
      silhouette:BountySurfaceRound2.Silhouette.Blade);
  for(int k=0;k<2;k++){
   float sign=k==0?-1:1,lane=k;
   azure.Ribbon(q=>center+right*(sign*(.10f+q*(.89f+open*.94f)))
       +up*(-.32f+Mathf.Sin(q*2.6f)*( .46f+open*.34f)-q*q*.32f)
       +depth*(lane*.29f+Mathf.Sin(q*5.2f+lane)*.18f),
       up,(.38f+open*.30f)*fade,1.19f,
       k==0?new Color(.09f,.45f,.97f,fade):new Color(.36f,.82f,1,fade),
       5.1f+lane*3.4f,.96f,silhouette:BountySurfaceRound2.Silhouette.Water);
  }
  azure.Ribbon(q=>center+up*((.52f-q)*(1.50f+open*1.47f))
      +right*Mathf.Sin(q*5.4f+post*4)*(.13f+open*.12f)
      +depth*(Mathf.Sin(q*4.1f)*.19f+.04f),
      right,(.068f+open*.12f)*fade,.42f,new Color(.95f,.99f,1,fade),8.9f,.47f,
      silhouette:BountySurfaceRound2.Silhouette.Blade);
  azure.Spray(center,right,up,depth,post,4.9f,18,new Color(.74f,.96f,1,fade),4.2f);
  azure.End(1,1.75f);
 }
 void Tile(Vector3 p,Vector3 x,Vector3 y,Color c){int n=vertices.Count;foreach(var v in new[]{p-x-y,p+x-y,p+x+y,p-x+y}){vertices.Add(transform.InverseTransformPoint(v));colors.Add(c);}uv.Add(Vector2.zero);uv.Add(Vector2.right);uv.Add(Vector2.one);uv.Add(Vector2.up);tris.AddRange(new[]{n,n+1,n+2,n,n+2,n+3});}
 void Strip(System.Func<float,Vector3> path,Vector3 side,float width,Color c){for(int j=0;j<24;j++){float q=j/24f,r=(j+1)/24f;Vector3 a=path(q),b=path(r);int n=vertices.Count;foreach(var p in new[]{a-side*width,a+side*width,b+side*width,b-side*width}){vertices.Add(transform.InverseTransformPoint(p));colors.Add(c);}uv.Add(new Vector2(0,q));uv.Add(new Vector2(1,q));uv.Add(new Vector2(1,r));uv.Add(new Vector2(0,r));tris.AddRange(new[]{n,n+1,n+2,n,n+2,n+3});}}
 void OnDisable(){if(released)rupture.Stop();}
 void OnDestroy(){if(released)rupture.Stop();if(mesh)Destroy(mesh);if(mat)Destroy(mat);if(bloomMat)Destroy(bloomMat);}
}
