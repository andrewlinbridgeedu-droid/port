using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

// A small batched world-space sculpted ribbon mesh, owned by a presentation root.
// Irregular width, raised centre and open Bezier paths define the actual silhouette.
public sealed class MainlineSpellMeshRound2 : MonoBehaviour
{
    Mesh mesh;Material material;Vector3 spatialCenter;float spatialScale=1;
    readonly List<Vector3> vertices=new List<Vector3>(8192);
    readonly List<Color> colors=new List<Color>(8192);
    readonly List<Vector2> uv=new List<Vector2>(8192);
    readonly List<int> triangles=new List<int>(12288);
    void Awake(){
        mesh=new Mesh{name="Mainline sculpted open spell ribbons"};mesh.MarkDynamic();
        material=new Material(Resources.Load<Shader>("EnemySignature/MainlineInlaidVolumeRound2"));
        material.SetTexture("_GoldBodyArt",Resources.Load<Texture2D>("SpellImpact20260925/GoldContractInk"));
        material.SetTexture("_GoldArt",Resources.Load<Texture2D>("ChurchSpellArt/BindingAuthored/GoldFiligree"));
        material.SetTexture("_FlowArt",Resources.Load<Texture2D>("Effects/Fool/CurtainRift"));
        material.SetTexture("_PaperArt",Resources.Load<Texture2D>("Effects/Fool/HeavyTarotFace"));
        material.SetTexture("_MemoryArt",Resources.Load<Texture2D>("SpellImpact20260925/MemoryFolio"));
        material.SetTexture("_VenomArt",Resources.Load<Texture2D>("ChurchSpellArt/venom"));
        gameObject.AddComponent<MeshFilter>().sharedMesh=mesh;
        var r=gameObject.AddComponent<MeshRenderer>();r.sharedMaterial=material;
        r.shadowCastingMode=ShadowCastingMode.Off;r.receiveShadows=false;
    }
    public void SetSpatialScale(Vector3 center,float scale){spatialCenter=center;spatialScale=scale;}
    Vector3 Local(Vector3 point)=>transform.InverseTransformPoint(spatialCenter+(point-spatialCenter)*spatialScale);
    public void Begin(float age,float impact=0,float motif=0){spatialScale=1;vertices.Clear();colors.Clear();uv.Clear();triangles.Clear();material.SetFloat("_Age",age);material.SetFloat("_Impact",impact);material.SetFloat("_Motif",motif);}
    static Vector3 Bezier(Vector3 a,Vector3 b,Vector3 c,Vector3 d,float u){float q=1-u;return a*q*q*q+b*3*q*q*u+c*3*q*u*u+d*u*u*u;}
    // 2026-10-03, user on the phone: 你很多都设置成这样弯弯的，都改掉吧. Every ribbon keeps
    // only 30% of its authored bend (its control points are pulled toward the chord), and its
    // width no longer ripples, so the curls of the mainline spells read as straight streaks.
    const float KeptBend=.3f;
    static void Straighten(Vector3 a,ref Vector3 b,ref Vector3 c,Vector3 d){
        b=Vector3.Lerp(Vector3.Lerp(a,d,1f/3f),b,KeptBend);c=Vector3.Lerp(Vector3.Lerp(a,d,2f/3f),c,KeptBend);
    }
    static float Width(float u,float seed){return Mathf.Pow(Mathf.Max(0,Mathf.Sin(u*Mathf.PI)),.7f)*.86f;}
    void Quad(Vector3 a,Vector3 b,Vector3 c,Vector3 d,Color tint,float x0,float x1,float u0,float u1){
        int n=vertices.Count;vertices.Add(Local(a));vertices.Add(Local(b));vertices.Add(Local(c));vertices.Add(Local(d));
        for(int k=0;k<4;k++)colors.Add(tint);uv.Add(new Vector2(x0,u0));uv.Add(new Vector2(x0,u1));uv.Add(new Vector2(x1,u1));uv.Add(new Vector2(x1,u0));
        triangles.Add(n);triangles.Add(n+1);triangles.Add(n+2);triangles.Add(n);triangles.Add(n+2);triangles.Add(n+3);
    }
    public void Ribbon(Vector3 a,Vector3 b,Vector3 c,Vector3 d,Vector3 across,float width,Color tint,float seed=0){
        Straighten(a,ref b,ref c,d);across.Normalize();const int steps=24;
        for(int j=0;j<steps;j++){
            float u0=j/(float)steps,u1=(j+1f)/steps;
            Vector3 p0=Bezier(a,b,c,d,u0),p1=Bezier(a,b,c,d,u1);
            Vector3 tangent=(p1-p0).normalized;
            Vector3 lateral=Vector3.ProjectOnPlane(across,tangent).normalized;
            if(lateral.sqrMagnitude<.1f)lateral=Vector3.Cross(tangent,Camera.main?Camera.main.transform.forward:Vector3.forward).normalized;
            Vector3 normal=Vector3.Cross(tangent,lateral).normalized;
            float w0=width*Width(u0,seed),w1=width*Width(u1,seed);
            Vector3 crest0=p0+normal*w0*.5f,crest1=p1+normal*w1*.5f;
            Quad(p0-lateral*w0,p1-lateral*w1,crest1,crest0,tint,0,.5f,u0,u1);
            var shade=tint;shade.r*=.82f;shade.g*=.87f;shade.b*=.92f;
            Quad(crest0,crest1,p1+lateral*w1*.74f,p0+lateral*w0*.74f,shade,.5f,1,u0,u1);
        }
    }
    // Opt-in for M20's two ink membranes. Each path point owns one cross-section;
    // neighbouring quads reuse it instead of opening a wedge at every segment.
    // The default Ribbon path above is deliberately unchanged for other spells.
    public void RibbonContinuous(Vector3 a,Vector3 b,Vector3 c,Vector3 d,Vector3 across,float width,Color tint,float seed=0){
        Straighten(a,ref b,ref c,d);across.Normalize();const int steps=48;
        Vector3 previousLeft=Vector3.zero,previousRight=Vector3.zero,previousCrest=Vector3.zero,previousLateral=Vector3.zero;
        var shade=tint;shade.r*=.82f;shade.g*=.87f;shade.b*=.92f;
        for(int j=0;j<=steps;j++){
            float u=j/(float)steps,q=1-u;
            Vector3 point=Bezier(a,b,c,d,u);
            Vector3 tangent=3*q*q*(b-a)+6*q*u*(c-b)+3*u*u*(d-c);
            if(tangent.sqrMagnitude<.000001f)tangent=d-a;
            if(tangent.sqrMagnitude<.000001f)tangent=Vector3.forward;
            tangent.Normalize();
            Vector3 lateral=Vector3.ProjectOnPlane(across,tangent);
            if(lateral.sqrMagnitude<.0001f)lateral=Vector3.ProjectOnPlane(previousLateral,tangent);
            if(lateral.sqrMagnitude<.0001f)lateral=Vector3.Cross(tangent,Mathf.Abs(tangent.y)<.9f?Vector3.up:Vector3.right);
            lateral.Normalize();
            if(j>0&&Vector3.Dot(lateral,previousLateral)<0)lateral=-lateral;
            Vector3 normal=Vector3.Cross(tangent,lateral).normalized;
            float w=width*Mathf.Pow(Mathf.Max(0,Mathf.Sin(u*Mathf.PI)),.7f)*.86f;
            Vector3 left=point-lateral*w,right=point+lateral*w*.74f,crest=point+normal*w*.5f;
            if(j>0){
                float previousU=(j-1f)/steps;
                Quad(previousLeft,left,crest,previousCrest,tint,0,.5f,previousU,u);
                Quad(previousCrest,crest,right,previousRight,shade,.5f,1,previousU,u);
            }
            previousLeft=left;previousRight=right;previousCrest=crest;previousLateral=lateral;
        }
    }
    // Opt-in physical patches for the September 25 identity pass. Existing
    // users retain their material, shape and lifetime.
    public void AuthoredRibbon(Vector3 a,Vector3 b,Vector3 c,Vector3 d,Vector3 across,float width,Color tint,int seed){
        Straighten(a,ref b,ref c,d);across.Normalize();
        Patch((u,v)=>{
            float q=1-u;Vector3 point=Bezier(a,b,c,d,u);
            Vector3 tangent=3*q*q*(b-a)+6*q*u*(c-b)+3*u*u*(d-c);
            if(tangent.sqrMagnitude<.000001f)tangent=d-a;
            if(tangent.sqrMagnitude<.000001f)tangent=Vector3.forward;
            tangent.Normalize();Vector3 lateral=Vector3.ProjectOnPlane(across,tangent);
            if(lateral.sqrMagnitude<.0001f)lateral=Vector3.Cross(tangent,Mathf.Abs(tangent.y)<.9f?Vector3.up:Vector3.right);
            lateral.Normalize();Vector3 normal=Vector3.Cross(tangent,lateral).normalized;
            // Smooth along its length: no rippling width, rolling twist or travelling wave.
            float pressure=Mathf.Pow(Mathf.Max(0,Mathf.Sin(u*Mathf.PI)),.63f)*.86f;
            float x=(v-.5f)*2;
            return point+lateral*(x*width*pressure)+normal*width*pressure*(.29f*Mathf.Sin(v*Mathf.PI));
        },tint,seed);
    }
    public void Triangle(Vector3 a,Vector3 b,Vector3 c,Color tint){
        int n=vertices.Count;vertices.Add(Local(a));vertices.Add(Local(b));vertices.Add(Local(c));
        colors.Add(tint);colors.Add(tint);colors.Add(tint);uv.Add(new Vector2(.5f,.05f));uv.Add(new Vector2(.02f,.94f));uv.Add(new Vector2(.97f,.81f));
        triangles.Add(n);triangles.Add(n+1);triangles.Add(n+2);
    }
    public void Patch(System.Func<float,float,Vector3> point,Color tint,int seed){
        const int rows=32,cols=10;
        for(int j=0;j<rows;j++)for(int k=0;k<cols;k++){
            float u=j/(float)rows,w=k/(float)cols;
            Quad(point(u,w),point(u+1f/rows,w),point(u+1f/rows,w+1f/cols),point(u,w+1f/cols),tint,w,w+1f/cols,u,u+1f/rows);
        }
    }
    public void End(){
#if UNITY_EDITOR
        foreach(var p in vertices)if(float.IsNaN(p.x)||float.IsInfinity(p.x)||float.IsNaN(p.y)||float.IsInfinity(p.y)||float.IsNaN(p.z)||float.IsInfinity(p.z))
            throw new System.InvalidOperationException("Non-finite authored spell mesh vertex");
#endif
        mesh.Clear();mesh.SetVertices(vertices);mesh.SetColors(colors);mesh.SetUVs(0,uv);mesh.SetTriangles(triangles,0);mesh.RecalculateBounds();}
    void OnDestroy(){if(mesh)Destroy(mesh);if(material)Destroy(material);}
}
