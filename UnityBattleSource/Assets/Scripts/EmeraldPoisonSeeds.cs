using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

/// Solid toxic pods and directional shell fragments. No gameplay state or damage.
public sealed class EmeraldPoisonSeeds : MonoBehaviour
{
    Mesh mesh;Material material; readonly Vector3[] q=new Vector3[4];
    readonly List<Vector3> v=new List<Vector3>(6000),n=new List<Vector3>(6000);
    readonly List<Color> c=new List<Color>(6000);readonly List<int> t=new List<int>(9000);
    static float N(int i)=>Mathf.Repeat(Mathf.Sin(i*127.1f+33.1f)*43758.5453f,1);
    void Awake(){var shader=Resources.Load<Shader>("EnemySignature/EmeraldPoisonSeeds");if(!shader)return;
        mesh=new Mesh{name="Owned toxic pod shells"};mesh.MarkDynamic();material=new Material(shader){name="Owned black jade poison",renderQueue=2480};
        var go=new GameObject("Sculpted toxic seeds");go.transform.SetParent(transform,false);go.AddComponent<MeshFilter>().sharedMesh=mesh;
        var renderer=go.AddComponent<MeshRenderer>();renderer.sharedMaterial=material;renderer.shadowCastingMode=ShadowCastingMode.Off;renderer.receiveShadows=false;}
    void Triangle(Vector3 a,Vector3 b,Vector3 d,float fade,int seed){int k=v.Count;Vector3 normal=Vector3.Cross(b-a,d-a).normalized;
        v.Add(a);v.Add(b);v.Add(d);for(int i=0;i<3;i++){n.Add(normal);c.Add(new Color(.18f,.36f+N(seed)*.12f,.22f,fade));}t.Add(k);t.Add(k+1);t.Add(k+2);}
    void Pod(Vector3 center,Quaternion rotation,Vector3 scale,float fade,int seed,bool spikes){
        const int sides=14,rings=9;
        for(int y=0;y<rings;y++)for(int x=0;x<sides;x++){
            for(int j=0;j<4;j++){int px=x+((j==1||j==2)?1:0),py=y+(j>=2?1:0);float a=px*Mathf.PI*2/sides,b=py*Mathf.PI/rings;
                float r=spikes&&py>0&&py<rings&&((px% sides+py+seed)%3==0)?1.65f:1;
                Vector3 point=new Vector3(Mathf.Cos(a)*Mathf.Sin(b),Mathf.Cos(b),Mathf.Sin(a)*Mathf.Sin(b))*r;
                q[j]=center+rotation*Vector3.Scale(point,scale);}
            Triangle(q[0],q[2],q[1],fade,seed+x+y);Triangle(q[0],q[3],q[2],fade,seed+x+y);
        }}
    public void Draw(int variant,int phase,float p,Vector3 source,Vector3 target){if(!mesh)return;v.Clear();n.Clear();c.Clear();t.Clear();
        bool burst=variant==1;Vector3 axis=(target-source).normalized;if(axis.sqrMagnitude<.01f)axis=Vector3.forward;Vector3 right=Vector3.Cross(Vector3.up,axis).normalized;if(right.sqrMagnitude<.01f)right=Vector3.right;
        int count=phase==2?(burst?38:22):(burst?9:5);
        for(int i=0;i<count;i++){
            float theta=i*2.39996f+(phase+p)*7;Vector3 pos;float size;float fade=phase==2?Mathf.Pow(1-p,.6f):phase==0?Mathf.Clamp01(p*4):1;
            if(phase==2){float distance=Mathf.Sqrt(p)*(burst?3.8f:2.4f);Vector3 direction=(right*(N(i+3)-.5f)*(burst?1.9f:2.8f)+Vector3.up*(N(i+7)-.3f)*1.8f+axis*(burst?(.5f+N(i+9)):(N(i+9)-.5f))).normalized;
                pos=target+direction*distance*(.4f+N(i)) - Vector3.up*p*p*.7f;size=.08f+N(i+17)*.12f;
            }else{float along=phase==0?0:Mathf.Clamp01(p-(burst?0:N(i)*.12f));Vector3 center=Vector3.Lerp(source,target,along);
                float radius=burst?(phase==0?Mathf.Lerp(1.05f,.7f,p):Mathf.Lerp(.7f,.11f,Mathf.SmoothStep(0,1,Mathf.Clamp01((p-.65f)/.35f)))):.30f;
                pos=center+right*Mathf.Cos(theta)*radius+Vector3.up*Mathf.Sin(theta)*radius+axis*(N(i+22)-.5f)*.4f;
                size=burst?.17f+N(i+12)*.09f:.24f+N(i+12)*.14f;
            }
            Pod(pos,Quaternion.Euler(i*31+p*180,i*27+p*130,i*17),new Vector3(size,size*(burst?1.15f:1.45f),size)*.38f,fade,i,burst);
        }
        mesh.Clear();mesh.SetVertices(v);mesh.SetNormals(n);mesh.SetColors(c);mesh.SetTriangles(t,0);mesh.RecalculateBounds();
    }
    void OnDestroy(){if(mesh)Destroy(mesh);if(material)Destroy(material);}
}
