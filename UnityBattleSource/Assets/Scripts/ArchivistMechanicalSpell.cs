using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

/// Ordered enamel-and-steel assemblies driven solely by the existing spell timeline.
/// The separately rendered original forearm and gameplay callbacks remain untouched.
public sealed class ArchivistMechanicalSpell : MonoBehaviour
{
    Mesh mesh; Material material;MainlineSpellMeshRound2 pressure;
    readonly List<Vector3> vertices=new List<Vector3>(6000);
    readonly List<Vector3> normals=new List<Vector3>(6000);
    readonly List<Color> colors=new List<Color>(6000);
    readonly List<Vector2> uvs=new List<Vector2>(6000);
    readonly List<int> triangles=new List<int>(9000);
    void Awake()
    {
        var shader=Resources.Load<Shader>("EnemySignature/ArchivistMechanicalSpell");
        if(!shader){Debug.LogError("Archivist mechanical shader missing");return;}
        mesh=new Mesh{name="Ordered beveled archive mechanisms"};mesh.MarkDynamic();
        material=new Material(shader){name="Polished ivory indigo steel",renderQueue=3005};
        var go=new GameObject("Precision archive spell assembly");go.transform.SetParent(transform,false);
        go.AddComponent<MeshFilter>().sharedMesh=mesh;
        var renderer=go.AddComponent<MeshRenderer>();renderer.sharedMaterial=material;
        renderer.shadowCastingMode=ShadowCastingMode.Off;renderer.receiveShadows=false;
        var folds=new GameObject("Engraved blue pressure faces");folds.transform.SetParent(transform,false);pressure=folds.AddComponent<MainlineSpellMeshRound2>();
    }
    void Quad(Vector3 c,Quaternion r,Vector3 a,Vector3 b,Vector3 d,Vector3 e,Color color)
    {
        int n=vertices.Count;Vector3 normal=transform.InverseTransformDirection(r*Vector3.Cross(b-a,d-a).normalized);
        vertices.Add(transform.InverseTransformPoint(c+r*a));vertices.Add(transform.InverseTransformPoint(c+r*b));
        vertices.Add(transform.InverseTransformPoint(c+r*d));vertices.Add(transform.InverseTransformPoint(c+r*e));
        for(int i=0;i<4;i++){normals.Add(normal);colors.Add(color);}
        uvs.Add(new Vector2(0,0));uvs.Add(new Vector2(0,1));uvs.Add(new Vector2(1,1));uvs.Add(new Vector2(1,0));
        triangles.Add(n);triangles.Add(n+1);triangles.Add(n+2);triangles.Add(n);triangles.Add(n+2);triangles.Add(n+3);
    }
    // Six-sided machined lance with a real bevel surrounding a recessed enamel face.
    void Lance(Vector3 c,Quaternion r,float width,float length,float alpha,bool ivory)
    {
        float x=width*.65f,y=length*.59f,z=width*.20f;
        Vector3[] rim={new Vector3(-x*.55f,-y,0),new Vector3(-x,-y*.55f,0),new Vector3(-x,y*.48f,0),new Vector3(0,y,0),new Vector3(x,y*.48f,0),new Vector3(x*.55f,-y,0)};
        Color enamel=ivory?new Color(.83f,.86f,.82f,alpha):new Color(.055f,.10f,.22f,alpha);
        Color steel=new Color(.48f,.60f,.69f,alpha),side=new Color(.17f,.23f,.30f,alpha);
        for(int sign=-1;sign<=1;sign+=2)
        {
            Vector3 center=new Vector3(0,0,z*sign);
            for(int j=0;j<rim.Length;j++)
            {
                int k=(j+1)%rim.Length;
                Vector3 a=rim[j]*.78f+center,b=rim[k]*.78f+center;
                if(sign>0){Quad(c,r,center,a,b,b,enamel);Quad(c,r,a,rim[j],rim[k],b,steel);}
                else {Quad(c,r,center,b,a,a,enamel);Quad(c,r,b,rim[k],rim[j],a,steel);}
                // A thin dark collar makes the physical edge legible at phone size.
                if(sign>0)Quad(c,r,rim[j],rim[j]-Vector3.forward*z*.35f,rim[k]-Vector3.forward*z*.35f,rim[k],side);
            }
            // Continuous narrow cyan inlay, not procedural screen-space markings.
            float iz=z*sign*1.02f;
            Quad(c,r,new Vector3(-x*.075f,-y*.60f,iz),new Vector3(-x*.075f,y*.42f,iz),new Vector3(x*.075f,y*.42f,iz),new Vector3(x*.075f,-y*.60f,iz),new Color(2,1,1,alpha*.8f));
        }
    }
    public void Draw(int variant,int phase,float p,Vector3 source,Vector3 target,Vector3 arm)
    {
        if(!mesh)return;
        vertices.Clear();normals.Clear();colors.Clear();uvs.Clear();triangles.Clear();
        p=Mathf.Clamp01(p);bool fist=(variant&1)==0;
        Vector3 forward=target-source;forward=forward.sqrMagnitude>.01f?forward.normalized:Vector3.forward;
        Vector3 side=Vector3.Cross(Vector3.up,forward).normalized;
        Vector3 up=Vector3.Cross(forward,side).normalized;
        float fade=phase==0?Mathf.SmoothStep(0,1,p*2.5f):phase==2?Mathf.Pow(1-p,1.6f):1;
        if(fist) {
            // Three unequal stabilisers follow the real arm, leaving its fist
            // and ivory fingers visible. No surrounding cage or ring skeleton.
            for(int i=0;i<3;i++){
                float x=i==0?-.38f:i==1?.47f:.11f,y=i==2?.35f:-.16f;
                Vector3 radial=side*x+up*y;
                Vector3 axis=(forward+radial*(phase==2?p*.7f:.12f)).normalized;
                Vector3 center=(phase==0?source:arm)+radial-forward*(.27f+i*.18f);
                Quaternion rotation=Quaternion.LookRotation(Vector3.Cross(side,axis).normalized,axis);
                Lance(center,rotation,.22f+i*.035f,.70f+i*.17f,fade,i!=1);
            }
        }else{
            // A slanted sheaf of seven independent enamel blades: unequal
            // depth, offset and launch delay, all reaching the original contact.
            for(int i=0;i<7;i++){
                float h=Mathf.Repeat(i*.618034f+.13f,1),k=Mathf.Repeat(i*.414214f+.2f,1);
                Vector3 offset=side*(h-.48f)*2.35f+up*(k-.35f)*1.3f-forward*(.15f+k*.48f);
                float launch=phase==0?0:phase==1?Mathf.Pow(Mathf.Clamp01((p-h*.16f)/(1-h*.16f)),1.3f):1;
                Vector3 origin=source+offset*Mathf.SmoothStep(0,1,phase==0?p:1);
                Vector3 landing=target+side*(h-.5f)*.65f+up*(k-.5f)*.5f;
                Vector3 center=Vector3.Lerp(origin,landing,launch)+up*Mathf.Sin(launch*Mathf.PI)*(.2f+h*.35f);
                Vector3 axis=(landing-origin).normalized;
                if(phase==2){center+=side*(h-.45f)*Mathf.Sqrt(p)*2.5f+up*(k-.25f)*p*1.5f-forward*p*.3f;axis=(axis+side*(h-.5f)*p*3).normalized;}
                var rotation=Quaternion.LookRotation(Vector3.Cross(side,axis).normalized,axis);
                Lance(center,rotation,.28f+h*.12f,.89f+k*.49f,fade,i%3!=1);
            }
        }
        mesh.Clear();mesh.SetVertices(vertices);mesh.SetNormals(normals);mesh.SetColors(colors);mesh.SetUVs(0,uvs);mesh.SetTriangles(triangles,0);mesh.RecalculateBounds();
        material.SetColor("_EdgeGlow",new Color(.24f,.82f,1.25f));
        if(pressure){
            pressure.Begin(phase+p,phase==2?Mathf.Exp(-p*8):0);
            Vector3 core=phase==0?source:phase==1?(fist?arm:Vector3.Lerp(source,target,p)):target;
            if(fist){
                if(phase==2){
                    // A single punched enamel fault, offset from the real fist.
                    // The departing arm, its fingers and the return route stay legible.
                    float spread=.30f+Mathf.Sqrt(p)*1.15f;
                    pressure.RibbonContinuous(core-side*.34f-up*.52f*spread,
                        core-side*.57f+up*.24f*spread,core+side*.18f+up*.69f*spread,
                        core+side*.68f+up*.19f*spread,side+up*.25f,.39f,
                        new Color(.12f,.42f,.89f,fade*.94f),1.9f);
                    pressure.RibbonContinuous(core-side*.08f-up*.43f*spread,
                        core+side*.22f-up*.23f*spread,core+side*.54f+up*.18f*spread,
                        core+side*.19f+up*.55f*spread,up,.13f,
                        new Color(.72f,.89f,1,fade*.95f),4.7f);
                }else{
                    pressure.RibbonContinuous(core-forward*.77f-side*.19f,
                        core-forward*.46f+up*.24f,core+forward*.14f+side*.13f,
                        core+forward*.34f,side+up*.28f,.18f,
                        new Color(.16f,.53f,.91f,fade*.65f),2.1f);
                }
            }else if(phase==2){
                // The seven physical blades converge into three unequal, curled
                // cuts rather than borrowing the fist's punch crater.
                float spread=.35f+Mathf.Sqrt(p)*1.28f;
                for(int i=0;i<3;i++){
                    float length=i==0?1.10f:i==1?.78f:1.30f;
                    float height=i==0?.46f:i==1?-.30f:.08f;
                    Vector3 a=core-side*spread*length+up*(height+.36f)+forward*(i==1?.18f:-.09f);
                    Vector3 d=core+side*spread*(i==1?.67f:1.03f)+up*(height-.42f)+forward*(i==2?.21f:0);
                    pressure.RibbonContinuous(a,a+side*.54f+up*.31f,
                        d-side*.41f-up*.20f,d,up+forward*.24f,
                        i==0?.32f:i==1?.17f:.24f,
                        i==1?new Color(.72f,.87f,1,fade*.91f):new Color(.16f,.48f,.86f,fade*.86f),i*2.4f+.5f);
                }
            }else{
                for(int i=0;i<2;i++){
                    float sign=i==0?-1:1;
                    Vector3 a=core-forward*.65f+side*sign*.37f;
                    Vector3 d=core+forward*.32f+side*sign*(.50f+i*.18f)+up*(i==0?.32f:-.16f);
                    pressure.RibbonContinuous(a,a+forward*.33f+up*.17f,
                        d-forward*.23f+up*.11f,d,side+up*.42f,.23f+i*.05f,
                        new Color(.10f,.42f,.83f,fade*.64f),i*2.7f);
                }
            }
            pressure.End();
        }
    }
    void OnDestroy(){if(mesh)Destroy(mesh);if(material)Destroy(material);}
}
