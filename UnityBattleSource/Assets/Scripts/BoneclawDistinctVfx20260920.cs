using System;
using System.Collections.Generic;
using UnityEngine;
// Three separate material actions: lance, segmented lash, ground impalement.
public sealed class BoneclawDistinctVfx20260920:MonoBehaviour {
 string intent;Vector3 source;Func<Vector3> target;float contact;bool held;
 readonly List<Transform> bones=new List<Transform>();readonly List<LineRenderer> trails=new List<LineRenderer>();Material ivory,light;Mesh mesh;
 Quaternion Face=>Camera.main?Camera.main.transform.rotation:Quaternion.identity;
 public void Configure(string action,Vector3 start,Func<Vector3> end,float hit){intent=action;source=start;target=end;contact=hit;held=action.Contains("charge");
  ivory=new Material(Shader.Find("Standard"));ivory.color=new Color(.85f,.78f,.60f);ivory.SetFloat("_Metallic",.35f);ivory.SetFloat("_Glossiness",.7f);ivory.EnableKeyword("_EMISSION");ivory.SetColor("_EmissionColor",new Color(.45f,.36f,.22f));
  light=new Material(Resources.Load<Shader>("Shaders/BonePressure20260920"));
  mesh=new Mesh();var vertices=new List<Vector3>();var triangles=new List<int>();for(int j=0;j<5;j++)for(int i=0;i<7;i++){float a=i*Mathf.PI*2/7;float r=j==0?.10f:j==1?.19f:j==2?.11f:j==3?.08f:0;vertices.Add(new Vector3(Mathf.Cos(a)*r,j/4f,Mathf.Sin(a)*r));}for(int j=0;j<4;j++)for(int i=0;i<7;i++){int a=j*7+i,b=j*7+(i+1)%7;triangles.AddRange(new[]{a,b,a+7,b,b+7,a+7});}mesh.SetVertices(vertices);mesh.SetTriangles(triangles,0);mesh.RecalculateNormals();
  for(int i=0;i<24;i++){var g=new GameObject("Articulated marrow shard");g.transform.SetParent(transform,false);g.AddComponent<MeshFilter>().sharedMesh=mesh;g.AddComponent<MeshRenderer>().sharedMaterial=ivory;bones.Add(g.transform);}
  for(int i=0;i<16;i++){var g=new GameObject("Bone pressure trail");g.transform.SetParent(transform,false);var l=g.AddComponent<LineRenderer>();l.sharedMaterial=light;l.textureMode=LineTextureMode.Stretch;l.positionCount=32;l.useWorldSpace=true;l.widthCurve=new AnimationCurve(new Keyframe(0,0),new Keyframe(.2f,1),new Keyframe(.8f,1),new Keyframe(1,0));trails.Add(l);}
 }
 void Bone(int i,Vector3 p,Vector3 direction,float length,float width){var b=bones[i];b.gameObject.SetActive(length>.005f);b.position=p;b.rotation=Quaternion.FromToRotation(Vector3.up,direction.normalized);b.localScale=new Vector3(width,length,width);}
 void Line(int i,Func<float,Vector3> curve,float width,float alpha){var l=trails[i];l.enabled=alpha>.01f;l.widthMultiplier=width*.38f;Color c=i%3==0?new Color(1,.91f,.77f,alpha):new Color(.65f,.20f,1,alpha*.7f);l.startColor=l.endColor=c;for(int j=0;j<32;j++)l.SetPosition(j,curve(j/31f));}
 public void Step(float age){if(target==null)return;foreach(var b in bones)b.gameObject.SetActive(false);foreach(var l in trails)l.enabled=false;
  Vector3 end=target()+Vector3.up*.85f;float t=age-contact,f=Mathf.Clamp01(age/contact),fade=1-Mathf.Clamp01(Mathf.Max(0,t)/.65f);float burst=1+3*Mathf.SmoothStep(0,1,Mathf.Max(0,t)/.075f)*(1-Mathf.SmoothStep(0,1,(t-.16f)/.4f));
  if(held){for(int i=0;i<5;i++){Vector3 p=source+Face*new Vector3((i-2)*.12f,.1f+i*.07f,0);Bone(i,p,Face*Vector3.up,.38f+.08f*Mathf.Sin(age*5+i),.35f);}return;}
  bool tail=intent=="tower_tail_sweep",heavy=intent=="tower_heavy_claw";
  if(heavy){
   if(t<0){for(int j=0;j<2;j++){Vector3 p=source+Face*new Vector3((j==0?-1:1)*.55f,1.1f*f,0);for(int k=0;k<3;k++)Bone(j*3+k,p+Face*Vector3.right*(k-1)*.16f,Vector3.down,.65f+f*.45f,.55f);}}
   else {Vector3 floor=target();floor.y=.04f;float rise=Mathf.Sin(Mathf.Clamp01(t/.58f)*Mathf.PI);for(int j=0;j<12;j++){float a=j*2.399f;Vector3 p=floor+new Vector3(Mathf.Cos(a),0,Mathf.Sin(a))*(.5f+j*.10f);Bone(j,p,new Vector3(Mathf.Cos(a)*.3f,1,Mathf.Sin(a)*.3f),rise*(1.5f+j%3*.7f),.7f);int k=j;Line(j,q=>Vector3.Lerp(floor,p,q)+Vector3.up*.04f+Vector3.right*Mathf.Sin(q*21+k)*.06f,.075f*burst,fade);}ChurchImpactLens20260917.Request(this,t,1);}
  }else if(tail){
   float sweep=Mathf.SmoothStep(0,1,Mathf.Clamp01((age-contact+.28f)/.65f));Vector3 center=t<-.25f?source:Vector3.Lerp(source,target()+Vector3.up*.25f,Mathf.Clamp01((age-contact+.3f)/.3f));
   Func<float,Vector3> whip=q=>center+Face*new Vector3(Mathf.Lerp(-2.4f,2.4f,q),Mathf.Sin(q*Mathf.PI)*.35f-.3f,Mathf.Sin(q*Mathf.PI+sweep*4)*.3f);
   for(int j=0;j<18;j++){float q=j/17f;Vector3 p=whip(q);Bone(j,p,whip(Mathf.Min(1,q+.025f))-whip(Mathf.Max(0,q-.025f)),(.32f+j*.008f)*fade,.85f);}
   for(int j=0;j<6;j++){int k=j;Line(j,q=>whip(q)+Face*Vector3.up*(k*.065f+Mathf.Max(0,t)*k*.24f),.09f*burst,fade);}
   if(t>=0)for(int j=18;j<24;j++){float a=j*2.4f;Bone(j,target()+new Vector3((j-21)*.45f,t*(2+j%2)-t*t*4,.2f),new Vector3(Mathf.Cos(a),1,0),.3f*fade,.45f);}
  }else{
   Vector3 axis=(end-source).normalized;Vector3 tip=Vector3.Lerp(source,end,Mathf.SmoothStep(0,1,f));
   if(t<0){for(int j=0;j<5;j++)Bone(j,tip-axis*(.8f+j*.15f)+Face*Vector3.right*(j-2)*.08f,axis,1.1f+f*.5f,.6f);for(int j=0;j<4;j++){int k=j;Line(j,q=>Vector3.Lerp(source,tip,q)+Face*Vector3.right*(k-1.5f)*.07f,.08f,f);}}
   else {for(int j=0;j<18;j++){float a=j*2.399f;Vector3 radial=Face*new Vector3(Mathf.Cos(a),Mathf.Sin(a),0);Bone(j,end+radial*(.15f+t*(2+j%3))+axis*t*4,axis+radial*.65f,(.4f+j%3*.3f)*fade,.5f);}
    for(int j=0;j<5;j++){int k=j;Line(j,q=>end+axis*(q-.4f)*3.5f*burst+Face*Vector3.right*(k-2)*.06f,.10f*burst,fade);}ChurchImpactLens20260917.Request(this,t,.6f);}
  }
 }
 void OnDestroy(){if(ivory)Destroy(ivory);if(light)Destroy(light);if(mesh)Destroy(mesh);}
}
