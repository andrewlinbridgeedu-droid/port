using UnityEngine;
using System.Collections.Generic;

// Authored openwork on independently curling surfaces. The owner retains all combat timing.
public sealed class BindingRibbon20260921 : MonoBehaviour {
 const int Segments=144, CrossSections=4;
 Mesh mesh;
 Material material;
 BindingEffekseerAccent20260921 accents;
 BindingImpact20260921 impact;
 readonly List<Vector3> vertices=new List<Vector3>();
 readonly List<Vector2> coordinates=new List<Vector2>();
 readonly List<Color> colors=new List<Color>();
 readonly List<int> triangles=new List<int>();
 float birth;
 void Awake(){
  birth=Time.time;
  mesh=new Mesh {name="Gold filigree binding surfaces"};mesh.MarkDynamic();
  material=new Material(Resources.Load<Shader>("Shaders/BindingRibbon20260921"));
  material.SetTexture("_MainTex",Resources.Load<Texture2D>("ChurchSpellArt/BindingAuthored/GoldFiligree"));
  gameObject.AddComponent<MeshFilter>().sharedMesh=mesh;
  var renderer=gameObject.AddComponent<MeshRenderer>();renderer.sharedMaterial=material;
  renderer.shadowCastingMode=UnityEngine.Rendering.ShadowCastingMode.Off;renderer.receiveShadows=false;
  accents=gameObject.AddComponent<BindingEffekseerAccent20260921>();
  impact=gameObject.AddComponent<BindingImpact20260921>();
 }
 public void Draw(Vector3 source,Vector3 target,float age,float contact,bool held){
  if(age<0){mesh.Clear();accents.StopAll();impact.Draw(target,-1,true);return;}
  vertices.Clear();coordinates.Clear();colors.Clear();triangles.Clear();
  float elapsed=Mathf.Max(0,Time.time-birth),clock=held?elapsed:BindingImpact20260921.Motion(age,contact);
  float progress=Mathf.Clamp01(age/Mathf.Max(.01f,contact));
  float post=age-contact;
  float formation=held?Mathf.SmoothStep(0,1,elapsed/.18f):Mathf.SmoothStep(0,1,(progress-.70f)/.30f);
  // The brief hold belongs only to the drawing; contact and gameplay clocks never pause.
  float close=held?1:Mathf.SmoothStep(0,1,(progress-.84f)/.16f);
  float expansion=held?0:BindingImpact20260921.Expansion(post);
  float fade=held?1:1-Mathf.SmoothStep(0,1,(post-.38f)/.30f);
  float pulse=held?0:post>=0?Mathf.Exp(-post*13)+expansion*1.8f:0;
  Vector3 flightSource=source+Vector3.up*.36f;
  Vector3 right=Camera.main?Camera.main.transform.right:Vector3.right;
  Vector3 depth=Camera.main?Camera.main.transform.forward:Vector3.forward;
  for(int strand=0;strand<8;strand++){
   bool cross=strand>=2&&strand<4;
   bool detail=strand>=4;
   float echo=detail&&!held?BindingImpact20260921.Expansion(post-(strand-2)*.012f):0;
   if(detail&&(held||echo<.008f))continue;
   int start=vertices.Count;
   for(int j=0;j<=Segments;j++){
    float q=j/(float)Segments;
    // Open, opposed restraints leave the face and torso visible. The former
    // combined curls read as a nearly complete luminous ring in the battle view.
    float sign=strand%2==0?-1:1;
    float offset=detail ? .31f+echo*(.43f+strand*.05f)
     : held ? .23f : Mathf.Lerp(.48f,.21f,close)+expansion*.56f;
    float height=detail?(q-.5f)*(.68f+echo*.48f)+(strand-3.5f)*.21f
     :(q-.5f)*(strand==0?1.40f:1.29f)+.13f*Mathf.Sin(q*5.1f+strand*2+clock*1.3f);
    Vector3 wrapped=cross
     ?target+right*((q-.5f)*(strand==2 ? .66f : -.72f)+Mathf.Sin(q*4.8f+strand)*.055f)
      +Vector3.up*(.15f+(q-.5f)*(strand==2 ? .71f : .64f)+(strand-2.5f)*.11f)
      -depth*(.24f+Mathf.Sin(q*5.2f+clock*.5f+strand)*.05f)
     :target+right*(sign*(offset+q*.10f+
      Mathf.Sin(q*5.4f+strand*1.8f+clock*.85f)*(held ? .16f : .055f+expansion*.045f)))
      +Vector3.up*(.15f+height*(1+expansion*.18f))
      +depth*(Mathf.Sin(q*4.3f+strand*2.2f)*(.17f+expansion*.09f)+strand*.025f);
    float run=Mathf.Clamp01(progress*1.25f-(1-q)*.52f);
    Vector3 flying=Vector3.Lerp(flightSource,target,run)+right*(Mathf.Sin(q*5.2f+clock*3+strand*2.6f)*.26f)+Vector3.up*(Mathf.Sin(run*Mathf.PI)*.34f+Mathf.Sin(q*5+strand*2)*.20f);
    Vector3 center=Vector3.Lerp(flying,wrapped,formation);
    Vector3 normal=(right*sign+depth*.24f).normalized;
    Vector3 side=(Vector3.up+normal*(.22f*Mathf.Sin(q*7+clock*1.3f+strand))).normalized;
    side=Vector3.Slerp(right,side,formation).normalized;
    float tip=Mathf.SmoothStep(0,1,q/.065f)*Mathf.SmoothStep(0,1,(1-q)/.09f);
    float width=(detail ? .22f : cross ? .17f : Mathf.Lerp(.25f,.36f,formation))
     *(1+(detail?echo*.42f:expansion*.45f))*tip*(.88f+.12f*Mathf.Sin(q*8+strand));
    for(int c=0;c<=CrossSections;c++){
     float t=c/(float)CrossSections;
     // Shallow transverse camber gives the luminous openwork a softly rolled profile.
     Vector3 p=center+side*((t-.5f)*width*2)+normal*(Mathf.Sin(t*Mathf.PI)*width*.10f*formation);
     vertices.Add(transform.InverseTransformPoint(p));coordinates.Add(new Vector2(q,t));
     colors.Add(detail?new Color(1,.73f,.32f,echo*.60f):Color.white);
     if(j<Segments&&c<CrossSections){int n=start+j*(CrossSections+1)+c;triangles.Add(n);triangles.Add(n+CrossSections+1);triangles.Add(n+1);triangles.Add(n+1);triangles.Add(n+CrossSections+1);triangles.Add(n+CrossSections+2);}
    }
   }
  }
  mesh.Clear();mesh.SetVertices(vertices);mesh.SetUVs(0,coordinates);mesh.SetColors(colors);mesh.SetTriangles(triangles,0);mesh.RecalculateNormals();mesh.RecalculateBounds();
  material.SetFloat("_Age",clock);material.SetFloat("_Fade",fade);material.SetFloat("_Pulse",pulse);
  accents.Draw(target+Vector3.up*.15f,fade*(held?formation:progress>=1?1:0),held,held?0:post>=0?Mathf.Exp(-post*13):0);
  if(!held)accents.Release(target+Vector3.up*.15f,post-BindingImpact20260921.Hold,fade);
  impact.Draw(target,post,held);
 }
 void OnDestroy(){if(mesh)Destroy(mesh);if(material)Destroy(material);}
}
