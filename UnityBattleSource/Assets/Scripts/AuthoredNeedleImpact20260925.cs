using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

// A presentation child of the existing silk cast. Time, contact and cancellation
// remain owned by EnemySignatureSpellVFX. Art is sampled onto folded world meshes.
public sealed class AuthoredNeedleImpact20260925 : MonoBehaviour
{
    Mesh mesh;Material material;readonly List<Vector3> v=new();readonly List<Vector2> uv=new();readonly List<Color> colors=new();readonly List<int> indices=new();
    Vector3 R,U,F;float age,fade,burst;
    void Awake(){
        mesh=new Mesh{name="Needle silk authored ruptures",indexFormat=IndexFormat.UInt32};mesh.MarkDynamic();
        material=new Material(Resources.Load<Shader>("SpellImpact20260925/AuthoredNeedle"));
        material.SetTexture("_Art",Resources.Load<Texture2D>("SpellImpact20260925/SilverNeedleSilk"));
        gameObject.AddComponent<MeshFilter>().sharedMesh=mesh;var renderer=gameObject.AddComponent<MeshRenderer>();renderer.sharedMaterial=material;renderer.shadowCastingMode=ShadowCastingMode.Off;
    }
    static float H(int n)=>Mathf.Repeat(Mathf.Sin(n*39.137f+7.9f)*4793.18f,1);
    static Vector3 B(Vector3 a,Vector3 b,Vector3 c,Vector3 d,float t){float q=1-t;return a*q*q*q+b*3*q*q*t+c*3*q*t*t+d*t*t*t;}
    void Quad(Vector3 a,Vector3 b,Vector3 c,Vector3 d,Vector2 t0,Vector2 t1,Vector2 t2,Vector2 t3,Color color){
        int n=v.Count;v.Add(transform.InverseTransformPoint(a));v.Add(transform.InverseTransformPoint(b));v.Add(transform.InverseTransformPoint(c));v.Add(transform.InverseTransformPoint(d));uv.Add(t0);uv.Add(t1);uv.Add(t2);uv.Add(t3);for(int k=0;k<4;k++)colors.Add(color);
        indices.Add(n);indices.Add(n+1);indices.Add(n+2);indices.Add(n);indices.Add(n+2);indices.Add(n+3);
    }
    Vector3 FoldPoint(Vector3 a,Vector3 b,Vector3 c,Vector3 d,float width,float x,float y,int seed){
        Vector3 center=B(a,b,c,d,y);Vector3 tangent=B(a,b,c,d,Mathf.Min(1,y+.01f))-B(a,b,c,d,Mathf.Max(0,y-.01f));
        Vector3 side=Vector3.Cross(tangent,F).normalized;if(side.sqrMagnitude<.1f)side=R;
        Vector3 normal=Vector3.Cross(tangent,side).normalized;
        float taper=Mathf.Pow(Mathf.Max(0,Mathf.Sin(y*Mathf.PI)),.48f);
        float pressure=.80f+.17f*Mathf.Sin(y*8.4f+seed)+.11f*Mathf.Sin(y*19.2f-seed*.7f);
        float curl=(Mathf.Sin(x*2.5f+y*7+seed+age*10)*.27f+x*x*.29f)*width*taper;
        return center+side*x*width*taper*pressure+normal*curl;
    }
    void Fold(Vector3 a,Vector3 b,Vector3 c,Vector3 d,float width,int seed,Color tint){
        const int rows=48,cols=12;float section=seed%3;
        // Each curved sheet uses a different continuous patch of the painted
        // textile. No complete sprite is hung in front of the camera.
        Vector2 Tex(float x,float y)=>new Vector2(.12f+y*.74f+(x-.5f)*(.42f-section*.035f),.10f+y*.78f-(x-.5f)*(.48f+section*.015f));
        for(int j=0;j<rows;j++)for(int k=0;k<cols;k++){
            float y=j/(float)rows,z=(j+1f)/rows,x=k/(float)cols,w=(k+1f)/cols;
            Quad(FoldPoint(a,b,c,d,width,x*2-1,y,seed),FoldPoint(a,b,c,d,width,x*2-1,z,seed),FoldPoint(a,b,c,d,width,w*2-1,z,seed),FoldPoint(a,b,c,d,width,w*2-1,y,seed),Tex(x,y),Tex(x,z),Tex(w,z),Tex(w,y),tint);
        }
    }
    public void Sample(int phase,float p,Vector3 source,Vector3 target){
        if(!mesh)return;v.Clear();uv.Clear();colors.Clear();indices.Clear();
        var cam=Camera.main;R=cam?cam.transform.right:Vector3.right;U=cam?cam.transform.up:Vector3.up;F=cam?cam.transform.forward:Vector3.forward;
        age=phase==2?p*.8f:0;fade=phase==2?Mathf.Pow(Mathf.Clamp01(1-age/.57f),1.15f):phase==1?1:.45f*p;
        burst=phase==2?(1-Mathf.Exp(-age*80))*Mathf.Exp(-age*4.9f):0;
        material.SetFloat("_Age",age);material.SetFloat("_Flash",phase==2?Mathf.Exp(-age*18):0);
        if(phase==2){
            float reach=.36f+burst*5.2f;
            for(int i=0;i<4;i++){
                Vector3 direction=(R*(i==0?-.95f:i==1?.85f:i==2?.28f:-.45f)+U*(i==0?.56f:i==1?.38f:i==2?-.9f:-.62f)).normalized;
                Vector3 side=Vector3.Cross(F,direction).normalized;
                Vector3 c=target+F*(i-.9f)*.34f;
                Vector3 a=c+direction*.12f,b=c+direction*reach*.26f+side*(i%2==0?.64f:-.49f),d=c+direction*reach*(i==0?1.05f:i==1?.93f:i==2?.78f:.62f);
                Color tint=i==3?new Color(1.18f,.36f,.40f,fade*.86f):new Color(1.12f,1.18f,1.24f,fade*.95f);
                Fold(a,b,c+direction*reach*.73f-side*(.30f+burst*.48f),d,.16f+burst*(i<2?1.1f:.81f),i+2,tint);
            }
            // Silver splinters have separate fast ballistic paths and tiny
            // pointed silhouettes. They follow the puncture, not a round halo.
            for(int i=0;i<66;i++){
                float h=H(i+4),angle=H(i+17)*6.283f;Vector3 dir=(R*Mathf.Cos(angle)+U*Mathf.Sin(angle)*(.55f+H(i+31)) +F*(H(i+9)-.5f)*.8f).normalized;
                Vector3 c=target+dir*(.08f+age*(6+h*13))-U*age*age*2;
                float length=(.10f+H(i+28)*.28f)*(1-age);Vector3 side=Vector3.Cross(dir,F).normalized*(.014f+h*.015f);
                Color tint=i%7==0?new Color(1.6f,.31f,.52f,fade):new Color(1.55f,1.75f,1.90f,fade);
                Quad(c-dir*length,c+side,c+dir*length*.27f,c-side,new Vector2(-1,0),new Vector2(-1,1),new Vector2(-1,1),new Vector2(-1,0),tint);
            }
        }else if(phase==1){
            float rush=Mathf.Pow(p,1.6f);Vector3 head=Vector3.Lerp(source,target,rush);
            for(int i=0;i<2;i++){
                Vector3 q=head+R*(i==0?-.33f:.29f)+F*i*.23f;
                Fold(q-F*.88f-U*.26f,q-F*.48f+R*(i==0?-.38f:.4f),q-F*.24f-U*.17f,q,.15f+p*.15f,i+1,new Color(.91f,1.02f,1.12f,.65f));
            }
        }
#if UNITY_EDITOR
        foreach(var point in v)if(float.IsNaN(point.x)||float.IsNaN(point.y)||float.IsNaN(point.z)||float.IsInfinity(point.x)||float.IsInfinity(point.y)||float.IsInfinity(point.z))throw new System.InvalidOperationException("Non-finite authored needle vertex");
#endif
        mesh.Clear();mesh.SetVertices(v);mesh.SetUVs(0,uv);mesh.SetColors(colors);mesh.SetTriangles(indices,0);mesh.RecalculateBounds();
    }
    void OnDestroy(){if(mesh)Destroy(mesh);if(material)Destroy(material);}
}
