using UnityEngine;
// One batched mesh: textured pieces sampled from the approved spell artwork.
public sealed class ChurchSpellFragments20260917:MonoBehaviour {
 const int Count=36;Mesh mesh;Material mat;Vector3[] vertices=new Vector3[Count*4];Vector2[] uv=new Vector2[Count*4];Vector2[] local=new Vector2[Count*4];Color[] colors=new Color[Count*4];int[] indices=new int[Count*6];string kind;bool support;Color fragmentTint=Color.white;
 public void Configure(string species,Texture texture,bool aid,string action=null){
  kind=species;support=aid;mesh=new Mesh();mesh.MarkDynamic();mat=new Material(Resources.Load<Shader>("Shaders/ChurchFilament"));mat.mainTexture=texture;mat.SetFloat("_Dst",10);mat.SetFloat("_Luma",0);mat.SetColor("_Color",Color.white);
  // This material uses vertex tint, including independent per-fragment opacity.
  mat.shader=Resources.Load<Shader>("Shaders/ChurchFragments");mat.SetFloat("_Organic",kind=="saltmaw"||kind=="shellback"?1:0);
  if(kind=="boneclaw"){fragmentTint=action=="tower_tail_sweep"?new Color(.25f,.95f,.59f):action=="tower_piercing_claw"?new Color(.39f,.77f,1):new Color(.88f,.56f,1);mat.SetFloat("_Recolor",1);}
  gameObject.AddComponent<MeshFilter>().sharedMesh=mesh;gameObject.AddComponent<MeshRenderer>().sharedMaterial=mat;
  for(int j=0;j<Count;j++){int v=j*4,k=j*6;local[v]=Vector2.zero;local[v+1]=Vector2.right;local[v+2]=Vector2.one;local[v+3]=Vector2.up;indices[k]=v;indices[k+1]=v+1;indices[k+2]=v+2;indices[k+3]=v;indices[k+4]=v+2;indices[k+5]=v+3;}
 }
 static float Rand(int n){return Mathf.Repeat(Mathf.Sin(n*127.1f+31.7f)*43758.54f,1);}
 public void Step(float age,Vector3 center,float strength){
  var cam=Camera.main;if(!cam)return;Vector3 right=cam.transform.right,up=cam.transform.up;
  for(int j=0;j<Count;j++){
   float t=age-(j%4)*.027f;float seed=Rand(j+1),angle=j*2.39996f;
   float life=t<0?0:Mathf.Clamp01(1-t/(.45f+seed*.20f));
   float speed=support?.9f:3.2f+seed*4.4f;
   float r=.22f+Mathf.Max(0,t)*speed;
   float twist=kind=="frilled-naga"||support?t*3:0;
   float x=Mathf.Cos(angle+twist)*r,y=Mathf.Sin(angle+twist)*r*.65f;
   if(support){x=Mathf.Cos(angle+t*2)*(.38f-Mathf.Min(.25f,Mathf.Max(0,t)*.5f));y=-.4f+Mathf.Max(0,t)*1.8f+seed*.3f;}
   if(kind=="saltmaw")y-=t*t*3; // viscous droplets sag
   if(kind=="stonehide")y=Mathf.Abs(y)*.7f-t*t*2; // erupts from the floor
   if(kind=="boneclaw")x*=.65f; // narrow, tearing spray
   Vector3 p=center+right*x+up*y-cam.transform.forward*(.18f+seed*.15f+Mathf.Max(0,t)*Mathf.Sin(angle*1.7f)*.9f);
   float size=(j%3==0?.14f:.07f)+seed*.055f;size*=Mathf.Sqrt(life);
   float turn=angle+t*(j%2==0?8:-11);Vector3 a=right*Mathf.Cos(turn)+up*Mathf.Sin(turn),b=Vector3.Cross(cam.transform.forward,a);
   float elong=kind=="ironclaw"||kind=="boneclaw"?2.5f:1;
   int v=j*4;vertices[v]=p-a*size-b*size*elong;vertices[v+1]=p+a*size-b*size*elong;vertices[v+2]=p+a*size+b*size*elong;vertices[v+3]=p-a*size+b*size*elong;
   float sampleAngle=j*2.39996f;Vector2 c=new Vector2(.5f+Mathf.Cos(sampleAngle)*.29f,.5f+Mathf.Sin(sampleAngle)*.29f);float patch=.055f+seed*.05f;
   uv[v]=c-new Vector2(patch,patch);uv[v+1]=c+new Vector2(patch,-patch);uv[v+2]=c+new Vector2(patch,patch);uv[v+3]=c+new Vector2(-patch,patch);
   Color tint=fragmentTint;tint.a=life*strength*(support?.55f:.9f);for(int n=0;n<4;n++)colors[v+n]=tint;
  }
  mesh.Clear();mesh.vertices=vertices;mesh.uv=uv;mesh.uv2=local;mesh.colors=colors;mesh.triangles=indices;mesh.RecalculateBounds();
 }
 void OnDestroy(){if(mesh)Destroy(mesh);if(mat)Destroy(mat);}
}
