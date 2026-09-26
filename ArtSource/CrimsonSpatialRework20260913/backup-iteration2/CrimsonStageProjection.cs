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
    readonly List<int> triangles = new List<int>(36000);
    readonly Vector3[] path = new Vector3[41];
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
        vertices.Clear();normals.Clear();colors.Clear();triangles.Clear();
        if((variant&1)==0)Weave(phase,p,source,target);else NeedleRain(phase,p,source,target);
        mesh.Clear();mesh.SetVertices(vertices);mesh.SetNormals(normals);mesh.SetColors(colors);
        mesh.SetTriangles(triangles,0);mesh.RecalculateBounds();
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
            // Opposing helical silk ropes enclose real depth. Their open gaps
            // preserve the enemy silhouette while showing the spinning volume.
            for(int strand=0;strand<12;strand++)
            {
                float handed=strand<6?1:-1;
                float start=(strand%6)/6f*Mathf.PI*2+handed*time*5.2f;
                for(int j=0;j<=40;j++)
                {
                    float u=j/40f*reveal;
                    float a=start+u*Mathf.PI*3.1f*handed;
                    float r=radius*(.7f+.3f*Mathf.Sin(u*Mathf.PI))+.04f*Mathf.Sin(u*19+strand+time*5);
                    path[j]=center+right*Mathf.Cos(a)*r+depth*Mathf.Sin(a)*r+Vector3.up*((u-.5f)*height);
                }
                Tube(path,41,.027f+(strand%3)*.004f,WithAlpha(Silk,reveal), false);
                // Thin pearl filaments embedded into selected physical cords.
                if(strand%3==0)
                {
                    for(int j=0;j<=40;j++)path[j]+=Vector3.up*.025f;
                    Tube(path,41,.009f,WithAlpha(new Color(1,.22f,.29f),reveal),true);
                }
            }
            // Six loose ends whip above/below rather than closing into rings.
            for(int i=0;i<6;i++)
            {
                float a=i*Mathf.PI/3+time*5;
                for(int j=0;j<19;j++)
                {
                    float u=j/18f;
                    float r=radius+u*.65f;
                    path[j]=center+right*Mathf.Cos(a+u*2)*r+depth*Mathf.Sin(a+u*2)*r
                        +Vector3.up*((i%2==0?-1:1)*height*.38f+Mathf.Sin(u*5+time*5+i)*u*.45f);
                }
                Tube(path,19,.022f,WithAlpha(Silk,reveal),false);
            }
        }
        else
        {
            // The compressed knot ruptures into curved, tumbling severed silk;
            // depth and gravity make the impact fundamentally unlike a card cloud.
            for(int i=0;i<48;i++)
            {
                float a=i*2.39996f;
                Vector3 d=right*Mathf.Cos(a)+depth*Mathf.Sin(a)*.85f+Vector3.up*(Hash(i+8)*1.3f-.45f);
                Vector3 c=center+d*(.25f+Mathf.Sqrt(p)*2.7f)-Vector3.up*p*p*.9f;
                for(int j=0;j<9;j++)
                {
                    float u=j/8f-.5f;
                    path[j]=c+d*u*(.3f+Hash(i)*.55f)+right*Mathf.Sin(u*7+i+p*11)*.12f
                        +Vector3.up*Mathf.Cos(u*8+i+p*13)*.13f;
                }
                Tube(path,9,.018f,WithAlpha(i%4==0?new Color(1,.23f,.28f):Silk,1-p),false);
            }
        }
    }
    void NeedleRain(int phase,float p,Vector3 source,Vector3 target)
    {
        float reveal=phase==0?Mathf.SmoothStep(0,1,p):1;
        // Three high, staggered ranks of fifteen steel needles form an arsenal.
        // Every delayed trajectory converges at the existing contact boundary.
        for(int row=0;row<3;row++)for(int col=0;col<15;col++)
        {
            int id=row*15+col;
            float lane=(col-7)/7f;
            Vector3 formation=source+right*lane*(2.5f-row*.22f)
                +Vector3.up*(1.05f+row*.48f+.28f*(1-lane*lane))+depth*(row-.8f)*.46f;
            Vector3 origin=Vector3.Lerp(source,formation,reveal);
            Vector3 landing=target-Vector3.up*.88f+right*lane*(.85f+row*.2f)+depth*(row-1)*.42f;
            float delay=row*.15f+Hash(id)*.09f;
            float dive=phase==0?0:phase==1?Mathf.Pow(Mathf.Clamp01((p-delay)/(1-delay)),2.25f):1;
            Vector3 position=Vector3.Lerp(origin,landing,dive);
            Vector3 direction=(landing-formation).normalized;
            float fade=phase<2?reveal:1-Mathf.SmoothStep(.5f,1,p);
            Needle(position,direction,.83f+Hash(id+6)*.3f,fade);
            // Each needle carries a real trailing thread, curved in space.
            if(phase<2)
            {
                Vector3 tail=position-direction*(.9f+Hash(id)*.25f);
                for(int j=0;j<9;j++)
                {
                    float u=j/8f;
                    path[j]=tail-direction*u*(.32f+dive*.4f)
                        +right*Mathf.Sin(u*5+id+p*9)*.055f*u+Vector3.up*Mathf.Sin(u*6+id)*.09f*u;
                }
                Tube(path,9,.009f,WithAlpha(Silk,fade),false);
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
                Tube(path,13,.012f,WithAlpha(Silk,1-p),false);
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
            float r0=section==0?0:section==1?.027f:.032f;
            float r1=section==0?.027f:section==1?.032f:.019f;
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
    void Quad(Vector3 a,Vector3 b,Vector3 c,Vector3 d,Vector3 normal,Color color)
    {
        int n=vertices.Count;vertices.Add(a);vertices.Add(b);vertices.Add(c);vertices.Add(d);
        for(int i=0;i<4;i++){normals.Add(normal);colors.Add(color);}
        triangles.Add(n);triangles.Add(n+1);triangles.Add(n+2);triangles.Add(n);triangles.Add(n+2);triangles.Add(n+3);
    }
    static float Hash(int i){float x=Mathf.Sin(i*127.1f+31.7f)*43758.5453f;return x-Mathf.Floor(x);}
    static Color WithAlpha(Color c,float a){c.a=Mathf.Clamp01(a);return c;}
    void Release(){var r=GetComponent<MeshRenderer>();if(r)r.enabled=false;if(mesh)Destroy(mesh);mesh=null;if(material)Destroy(material);material=null;}
    void OnDisable(){Release();}
    void OnDestroy(){Release();}
}
