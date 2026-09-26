using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

/// Historical component name retained for compatibility. This now draws actual
/// world-space silk cords and silver needles, never a camera-facing projection.
/// References: local HolySandstorm spiral staging and CurtainExplosion delayed
/// burst staging. Authored geometry provides this enemy's distinctive subject.
public sealed class CrimsonStageProjection : MonoBehaviour
{
    Mesh mesh;
    Material material;
    readonly List<Vector3> vertices = new List<Vector3>(24000);
    readonly List<Vector3> normals = new List<Vector3>(24000);
    readonly List<Color> colors = new List<Color>(24000);
    readonly List<Vector3> textureCoords = new List<Vector3>(24000);
    readonly List<int> triangles = new List<int>(36000);
    readonly Vector3[] path = new Vector3[81];
    Vector3 right, depth;
    static readonly Color Silk = new Color(.62f,.016f,.07f,1);
    static readonly Color Silver = new Color(.73f,.83f,.9f,1);
    bool Ensure()
    {
        if (material) return true;
        var shader = Resources.Load<Shader>("EnemySignature/CrimsonStageProjection");
        if (!shader) return false;
        mesh = new Mesh { name="Crimson world silk and steel", indexFormat=IndexFormat.UInt32 };
        mesh.MarkDynamic();
        material = new Material(shader) { name="Crimson physical silk and steel" };
        var filter=GetComponent<MeshFilter>();if(!filter)filter=gameObject.AddComponent<MeshFilter>();
        filter.sharedMesh=mesh;
        var renderer=GetComponent<MeshRenderer>();if(!renderer)renderer=gameObject.AddComponent<MeshRenderer>();
        renderer.sharedMaterial=material;renderer.shadowCastingMode=ShadowCastingMode.Off;
        return true;
    }
    public void Sample(int variant,int phase,float progress,Vector3 source,Vector3 target)
    {
        if(!Ensure())return;
        float p=Mathf.Clamp01(progress);
        var cam=Camera.main;
        right=cam?cam.transform.right:Vector3.right;right.y=0;right.Normalize();
        depth=Vector3.Cross(right,Vector3.up).normalized;
        vertices.Clear();normals.Clear();colors.Clear();textureCoords.Clear();triangles.Clear();
        if((variant&1)==0)Weave(phase,p,source,target);else NeedleRain(phase,p,source,target);
        mesh.Clear();mesh.SetVertices(vertices);mesh.SetNormals(normals);mesh.SetColors(colors);
        mesh.SetUVs(0,textureCoords);mesh.SetTriangles(triangles,0);mesh.RecalculateBounds();
    }
    void Weave(int phase,float p,Vector3 source,Vector3 target)
    {
        float time=phase==0?p*1.4f:phase==1?1.4f+p*.65f:2.05f+p*.8f;
        float reveal=phase==0?Mathf.SmoothStep(0,1,p):1;
        Vector3 center=phase==0?source:phase==1?Vector3.Lerp(source,target,Mathf.SmoothStep(0,1,p)):target;
        if(phase<2)
        {
            float radius=phase==0?Mathf.Lerp(.4f,1.38f,reveal):Mathf.Lerp(1.38f,.52f,Mathf.Pow(p,3));
            float height=phase==0?Mathf.Lerp(.5f,2.85f,reveal):2.85f;
            // Three continuous lengths of satin turn through an open, tilted volume.
            // A single broad fold carries each silhouette; restrained threads follow it.
            for(int strip=0;strip<3;strip++)
            {
                for(int j=0;j<=80;j++)
                {
                    float u=j/80f*reveal;
                    float angle=strip*Mathf.PI*2/3+u*5.1f+time*3.2f;
                    float r=radius*(.68f+.26f*Mathf.Sin(u*Mathf.PI));
                    path[j]=center+right*Mathf.Cos(angle)*r+depth*Mathf.Sin(angle)*r
                        +Vector3.up*((u-.5f)*height)+right*(u-.5f)*.4f;
                }
                Ribbon(path,81,.23f+strip*.027f,WithAlpha(new Color(.70f,.035f,.09f),reveal),strip+time);
                // One fine running stitch at the outer fold, not another spiral rope.
                for(int j=0;j<=80;j++)path[j]+=Vector3.up*.028f;
                Tube(path,81,.006f,WithAlpha(new Color(.79f,.18f,.22f),reveal*.7f),false);
            }

        }
        else
        {
            // The compressed knot ruptures into curved, tumbling severed silk;
            // depth and gravity make the impact fundamentally unlike a card cloud.
            for(int i=0;i<7;i++)
            {
                float a=i*2.39996f;
                Vector3 d=right*Mathf.Cos(a)+depth*Mathf.Sin(a)*.85f+Vector3.up*(Hash(i+8)*1.3f-.45f);
                Vector3 c=center+d*(.25f+Mathf.Sqrt(p)*3.65f)-Vector3.up*p*p*.9f;
                for(int j=0;j<9;j++)
                {
                    float u=j/8f-.5f;
                    path[j]=c+d*u*(.65f+Hash(i)*.70f)+right*Mathf.Sin(u*7+i+p*11)*.12f
                        +Vector3.up*Mathf.Cos(u*8+i+p*13)*.13f;
                }
                Ribbon(path,9,.22f,WithAlpha(Silk,1-p),i+p*3);
            }
        }
    }
    void NeedleRain(int phase,float p,Vector3 source,Vector3 target)
    {
        float reveal=phase==0?Mathf.SmoothStep(0,1,p):1;
        // Three staggered ranks of eight short steel needles form an arsenal.
        // Every delayed trajectory converges at the existing contact boundary.
        for(int row=0;row<3;row++)for(int col=0;col<8;col++)
        {
            int id=row*8+col;
            float lane=(col-3.5f)/3.5f;
            Vector3 formation=source+right*lane*(1.65f-row*.15f)
                +Vector3.up*(.66f+row*.30f+.38f*(1-lane*lane))+depth*(row-.8f)*.46f;
            Vector3 origin=Vector3.Lerp(source,formation,reveal);
            Vector3 landing=target-Vector3.up*.88f+right*lane*(.85f+row*.2f)+depth*(row-1)*.42f;
            float delay=row*.23f+Hash(id)*.055f;
            float dive=phase==0?0:phase==1?Mathf.Pow(Mathf.Clamp01((p-delay)/(1-delay)),2.25f):1;
            Vector3 control=(origin+landing)*.5f+Vector3.up*.48f+right*lane*.2f;
            Vector3 position=(1-dive)*(1-dive)*origin+2*(1-dive)*dive*control+dive*dive*landing;
            Vector3 aimed=Vector3.Lerp(control-origin,landing-control,dive).normalized;
            Vector3 spread=(right*lane*.35f-Vector3.up*.55f+depth*.8f).normalized;
            Vector3 direction=Vector3.Slerp(spread,aimed,Mathf.Clamp01(dive*1.8f));
            float fade=phase<2?reveal:1-Mathf.SmoothStep(.5f,1,p);
            float needleSize=.62f+Hash(id+6)*.20f;
            Needle(position,direction,needleSize,fade);
            // Each needle carries a real trailing thread, curved in space.
            if(phase<2)
            {
                Vector3 tail=position-direction*needleSize;
                for(int j=0;j<9;j++)
                {
                    float u=j/8f;
                    path[j]=tail-direction*u*(.23f+dive*.65f)
                        +right*Mathf.Sin(u*5+id+p*9)*.055f*u+Vector3.up*Mathf.Sin(u*6+id)*.09f*u;
                }
                Ribbon(path,9,.016f+dive*.017f,WithAlpha(new Color(1,.18f,.29f),fade),id+p*3);
                Tube(path,9,.004f,WithAlpha(new Color(1,.68f,.66f),fade),true);
            }
            else if(id%2==0)
            {
                // Small wire nests unravel and burst at individual insertion sites.
                for(int j=0;j<13;j++)
                {
                    float u=j/12f;
                    float a=u*Mathf.PI*3+id+p*8;
                    path[j]=landing+right*Mathf.Cos(a)*(.1f+p*.5f)+depth*Mathf.Sin(a)*(.12f+p*.35f)
                        +Vector3.up*(Mathf.Sin(u*Mathf.PI)*(.16f+p*.5f)-p*p*.3f);
                }
                Tube(path,13,.042f,WithAlpha(Silk,1-p),false);
                Vector3 launch=(right*(Hash(id)-.5f)+depth*(Hash(id+2)-.5f)+Vector3.up*.7f).normalized;
                Needle(landing+launch*(p*1.2f)-Vector3.up*p*p*.7f,launch,.14f,1-p);
            }
        }
    }
    void Needle(Vector3 tip,Vector3 direction,float size,float alpha)
    {
        // Faceted silver shaft with a tapered point; bright/dark normals create
        // identifiable metal rather than a glowing diamond or billboard streak.
        Vector3 x=Vector3.Cross(direction,depth).normalized;
        if(x.sqrMagnitude<.1f)x=right;
        Vector3 y=Vector3.Cross(direction,x).normalized;
        for(int section=0;section<3;section++)
        {
            float u0=section==0?0:section==1?.22f:.86f;
            float u1=section==0?.22f:section==1?.86f:1;
            float r0=section==0?0:section==1?.017f:.019f;
            float r1=section==0?.017f:section==1?.019f:.009f;
            for(int k=0;k<8;k++)
            {
                float a=k*Mathf.PI*.25f,b=(k+1)*Mathf.PI*.25f;
                Vector3 n0=x*Mathf.Cos(a)+y*Mathf.Sin(a),n1=x*Mathf.Cos(b)+y*Mathf.Sin(b);
                Quad(tip-direction*size*u0+n0*r0,tip-direction*size*u1+n0*r1,
                    tip-direction*size*u1+n1*r1,tip-direction*size*u0+n1*r0,
                    (n0+n1).normalized,WithAlpha(Silver,alpha));
            }
        }
    }
    void Tube(Vector3[] points,int count,float radius,Color color,bool bright)
    {
        // Eight-sided tubes, shared frame buffer; no GameObjects per filament.
        const int sides=6;
        for(int j=1;j<count;j++)
        {
            Vector3 tangent=(points[j]-points[j-1]).normalized;
            if(tangent.sqrMagnitude<.01f)continue;
            Vector3 x=Vector3.Cross(tangent,Vector3.up).normalized;
            if(x.sqrMagnitude<.01f)x=right;
            Vector3 y=Vector3.Cross(tangent,x).normalized;
            float taper=Mathf.Min(1,Mathf.Min(j,count-j)*.6f);
            for(int k=0;k<sides;k++)
            {
                float a=k*Mathf.PI*2/sides,b=(k+1)*Mathf.PI*2/sides;
                Vector3 n0=x*Mathf.Cos(a)+y*Mathf.Sin(a),n1=x*Mathf.Cos(b)+y*Mathf.Sin(b);
                Color shade=color;if(bright){shade.r*=1.25f;shade.g*=1.25f;}
                Quad(points[j-1]+n0*radius*taper,points[j]+n0*radius*taper,
                    points[j]+n1*radius*taper,points[j-1]+n1*radius*taper,(n0+n1).normalized,shade);
            }
        }
    }
    void Ribbon(Vector3[] points,int count,float width,Color color,float motion)
    {
        for(int j=1;j<count;j++)
        {
            float u=(j-.5f)/(count-1);
            Vector3 tangent=(points[j]-points[j-1]).normalized;
            Vector3 across=(Vector3.up*.8f+right*Mathf.Sin(u*5+motion)*.3f+depth*Mathf.Cos(u*5+motion)*.3f).normalized;
            Vector3 normal=Vector3.Cross(tangent,across).normalized;
            float w=width*Mathf.Pow(Mathf.Sin(u*Mathf.PI),.6f)*(1+.08f*Mathf.Sin(u*12+motion));
            Quad(points[j-1]-across*w,points[j]-across*w,points[j]+across*w,points[j-1]+across*w,normal,color);
            int n=textureCoords.Count-4;
            textureCoords[n]=new Vector3((j-1f)/(count-1),0,1);
            textureCoords[n+1]=new Vector3(j/(float)(count-1),0,1);
            textureCoords[n+2]=new Vector3(j/(float)(count-1),1,1);
            textureCoords[n+3]=new Vector3((j-1f)/(count-1),1,1);
        }
    }
    void Quad(Vector3 a,Vector3 b,Vector3 c,Vector3 d,Vector3 normal,Color color)
    {
        int n=vertices.Count;vertices.Add(a);vertices.Add(b);vertices.Add(c);vertices.Add(d);
        for(int i=0;i<4;i++){normals.Add(normal);colors.Add(color);textureCoords.Add(Vector3.zero);}
        triangles.Add(n);triangles.Add(n+1);triangles.Add(n+2);triangles.Add(n);triangles.Add(n+2);triangles.Add(n+3);
    }
    static float Hash(int i){float x=Mathf.Sin(i*127.1f+31.7f)*43758.5453f;return x-Mathf.Floor(x);}
    static Color WithAlpha(Color c,float a){c.a=Mathf.Clamp01(a);return c;}
    void Release(){var r=GetComponent<MeshRenderer>();if(r)r.enabled=false;if(mesh)Destroy(mesh);mesh=null;if(material)Destroy(material);material=null;}
    void OnDisable(){Release();}
    void OnDestroy(){Release();}
}
