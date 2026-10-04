using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

// Unequal hand-cast silk folds and staggered short silver needles.
public sealed class MainlineSilkRound2 : MonoBehaviour
{
    Mesh mesh;AuthoredNeedleImpact20260925 needleImpact;
    Material material;
    readonly List<Vector3> vertices = new List<Vector3>(24000);
    readonly List<Vector3> normals = new List<Vector3>(24000);
    readonly List<Color> colors = new List<Color>(24000);
    readonly List<Vector3> textureCoords = new List<Vector3>(24000);
    readonly List<int> triangles = new List<int>(36000);
    readonly Vector3[] path = new Vector3[81];
    readonly Vector3[] silkLeft = new Vector3[81], silkRight = new Vector3[81];
    readonly Vector3[] silkCrest = new Vector3[81], silkNormals = new Vector3[81];
    Vector3 right, depth;
    static readonly Color Silk = new Color(.91f,.065f,.16f,1);
    static readonly Color Silver = new Color(.87f,.94f,1f,1);
    bool Ensure()
    {
        if (material) return true;
        var shader = Resources.Load<Shader>("EnemySignature/MainlineSilkRound2");
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
    public void Sample(int variant,int phase,float progress,Vector3 source,Vector3 target,float rawProgress=-1)
    {
        if(!Ensure())return;
        float p=Mathf.Clamp01(progress);material.SetFloat("_NeedlePass",variant&1);
        var cam=Camera.main;
        right=cam?cam.transform.right:Vector3.right;right.y=0;right.Normalize();
        depth=Vector3.Cross(right,Vector3.up).normalized;
        vertices.Clear();normals.Clear();colors.Clear();textureCoords.Clear();triangles.Clear();
        if((variant&1)==0)Weave(phase,p,source,target);else {
            float raw=rawProgress<0?p:Mathf.Clamp01(rawProgress);
            NeedleRain(phase,phase==2?raw:p,source,target);
            if(!needleImpact){var go=new GameObject("Authored silver needle rupture layers");go.transform.SetParent(transform,false);needleImpact=go.AddComponent<AuthoredNeedleImpact20260925>();}
            needleImpact.Sample(phase,raw,source,target);
        }
        mesh.Clear();mesh.SetVertices(vertices);mesh.SetNormals(normals);mesh.SetColors(colors);
        mesh.SetUVs(0,textureCoords);mesh.SetTriangles(triangles,0);mesh.RecalculateBounds();
    }
    void Weave(int phase,float p,Vector3 source,Vector3 target)
    {
        float time=phase==0?p*1.4f:phase==1?1.4f+p*.65f:2.05f+p*.8f;
        float reveal=phase==0?Mathf.SmoothStep(0,1,p):1;
        Vector3 center=phase==0?source:phase==1?Vector3.Lerp(source,target,Mathf.SmoothStep(0,1,p)):target;
        if(phase<2){
            // Three unequal S-folds cast from the working hand. Each has its own
            // hem, twist and depth, never three equal helices around one axis.
            for(int strip=0;strip<3;strip++){
                float sign=strip==1?-1:1,length=strip==0?3.35f:strip==1?2.62f:2.08f;
                float gather=phase==1?1-p*.48f:reveal;
                for(int j=0;j<=80;j++){
                    float u=j/80f*reveal,belly=Mathf.Sin(u*Mathf.PI);
                    float sweep=Mathf.Sin(u*(strip==0?4.8f:3.9f)+strip*.72f+time*.65f);
                    path[j]=center+right*(sign*sweep*(.54f+belly*.70f)*gather+(u-.5f)*.42f+(strip==1?-.43f:strip==2?.48f:0)*gather)
                        +Vector3.up*((u-(strip==1?.57f:.42f))*length*gather)
                        +depth*(Mathf.Sin(u*5.3f+strip*1.3f+time*.48f)*.56f*belly+strip*.32f);
                }
                Ribbon(path,81,strip==0?.74f:strip==1?.55f:.41f,WithAlpha(Silk,reveal*.96f),strip*1.6f+time*.48f);
                // Uneven fine running seam follows the fold; no additional loop.
                for(int j=0;j<=80;j++)path[j]+=Vector3.up*(.017f+Mathf.Sin(j*.23f+strip)*.012f);
                Tube(path,81,.011f,WithAlpha(new Color(1f,.73f,.39f),reveal*.80f),false);
            }
        }else{
            for(int i=0;i<9;i++){
                float a=Hash(i+3)*6.283f;
                Vector3 d=right*Mathf.Cos(a)+depth*Mathf.Sin(a)*.7f+Vector3.up*(Hash(i+8)*1.5f-.35f);
                Vector3 c=center+d*(.18f+Mathf.Sqrt(p)*(2.1f+Hash(i+14)*1.3f))-Vector3.up*p*p*.9f;
                for(int j=0;j<25;j++){
                    float u=j/24f-.5f;
                    path[j]=c+d*u*(.75f+Hash(i)*.8f)+right*Mathf.Sin(u*5.3f+i+p*8)*.24f
                        +Vector3.up*Mathf.Cos(u*6.1f+i+p*9)*.20f+depth*Mathf.Sin(u*4+i)*.16f;
                }
                Ribbon(path,25,i<4?.47f+Hash(i+17)*.20f:.23f+Hash(i+17)*.15f,
                    WithAlpha(Silk,Mathf.Pow(1-p,1.3f)),i+p*2);
            }
        }
    }
    void NeedleRain(int phase,float p,Vector3 source,Vector3 target)
    {
        float reveal=phase==0?Mathf.SmoothStep(0,1,p):1;
        // Unequal flanking needle clusters unfold from the hands, not an equal
        // rank above the head. All trajectories end at the same real contact.
        for(int id=0;id<24;id++){
            float h=Hash(id+4),k=Hash(id+19),side=id%2==0?-1:1;
            Vector3 formation=source+right*side*(.35f+h*1.2f)+Vector3.up*(.12f+k*1.3f)+depth*(Hash(id+31)-.5f)*1.05f;
            Vector3 origin=Vector3.Lerp(source,formation,reveal);
            Vector3 landing=target+right*(h-.5f)*.82f+Vector3.up*(k-.56f)*.65f+depth*(Hash(id+2)-.5f)*.48f;
            float delay=Hash(id+8)*.42f;
            float dive=phase==0?0:phase==1?Mathf.Pow(Mathf.Clamp01((p-delay)/(1-delay)),2.05f):1;
            Vector3 control=(origin+landing)*.5f+Vector3.up*(.22f+h*.25f)+right*side*.18f;
            Vector3 position=(1-dive)*(1-dive)*origin+2*(1-dive)*dive*control+dive*dive*landing;
            Vector3 direction=Vector3.Lerp(control-origin,landing-control,dive).normalized;
            float fade=phase<2?reveal:Mathf.Pow(1-p,1.8f);
            bool lead=id==0||id==5||id==13||id==20;
            float size=lead?1.84f+Hash(id+6)*.47f:1.08f+Hash(id+6)*.42f;
            if(phase==2){
                Vector3 deflect=(right*(h-.45f)+Vector3.up*(k+.15f)-depth*.3f).normalized;
                float swell=(1-Mathf.Exp(-p*.8f*80))*Mathf.Exp(-p*.8f*4.9f);
                position+=deflect*(Mathf.Sqrt(p)*(.65f+h)+swell*(lead?1.2f:.6f))-Vector3.up*p*p*.55f;
                direction=Vector3.Slerp(direction,deflect,Mathf.Clamp01(p*.8f+swell*(.22f+h*.50f)));size*=(1-p*.35f)*(1+swell*(lead?.74f:.3f));
            }
            Needle(position,direction,size,lead?.028f:.013f+h*.007f,fade);
            if(phase<2){
                Vector3 tail=position-direction*size;
                for(int j=0;j<17;j++){
                    float u=j/16f;
                    path[j]=tail-direction*u*(.28f+dive*.63f)+right*Mathf.Sin(u*4.5f+id+p*7)*.12f*u+Vector3.up*Mathf.Sin(u*5+id)*.11f*u;
                }
                Ribbon(path,17,lead?.048f+dive*.019f:.018f+dive*.013f,
                    WithAlpha(new Color(.96f,.10f,.22f),fade*.55f),id+p*2);
                if(lead){
                    // Four embroidered silk leaders carry the metal bouquet
                    // through space. Unequal bends and depths keep the silver
                    // tips dominant without turning the rain into bare rays.
                    for(int j=0;j<25;j++){
                        float u=j/24f,curve=Mathf.Sin(u*Mathf.PI);
                        path[j]=Vector3.Lerp(source+right*side*.22f,position-direction*size*.64f,u)
                            +right*side*curve*(.28f+h*.33f)
                            +depth*curve*Mathf.Sin(u*5.2f+id*.7f)*(.18f+k*.21f)
                            +Vector3.up*curve*(.23f+k*.21f);
                    }
                    Ribbon(path,25,.045f+h*.016f,WithAlpha(new Color(.86f,.055f,.16f),fade*.48f),id*.43f+p);
                }
            }else if(id%3==0){
                // One short torn scar per cluster; no floor wire nest/round loop.
                Vector3 d=(right*(h-.4f)+Vector3.up*(k-.3f)).normalized;
                for(int j=0;j<17;j++){
                    float u=j/16f;
                    path[j]=landing+d*u*(.42f+Mathf.Sqrt(p)*1.56f)+depth*Mathf.Sin(u*4+id)*.18f;
                }
                Ribbon(path,17,.06f+h*.025f,WithAlpha(new Color(.80f,1.18f,1.5f),fade),id);
            }
        }
    }
    void Needle(Vector3 tip,Vector3 direction,float size,float radius,float alpha)
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
            float r0=section==0?0:section==1?radius*.89f:radius;
            float r1=section==0?radius*.89f:section==1?radius:radius*.47f;
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
        points=StraightLines20261003.Flattened(points,count);
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
        points=StraightLines20261003.Flattened(points,count);
        // One frame per path vertex, shared by both adjacent faces. Computing a
        // new frame per segment left 80 little wedge gaps: the comb-like hem.
        Vector3 previousAcross=Vector3.zero;
        for(int j=0;j<count;j++)
        {
            float u=j/(float)(count-1);
            Vector3 tangent=(points[Mathf.Min(j+1,count-1)]-points[Mathf.Max(0,j-1)]).normalized;
            if(tangent.sqrMagnitude<.01f)tangent=Vector3.up;
            Vector3 across=Vector3.Cross(tangent,depth).normalized;
            if(across.sqrMagnitude<.1f)across=Vector3.ProjectOnPlane(j>0?previousAcross:right,tangent).normalized;
            if(across.sqrMagnitude<.1f)across=Vector3.Cross(tangent,Vector3.up).normalized;
            across=Quaternion.AngleAxis(Mathf.Sin(u*5+motion)*32,tangent)*across;
            if(j>0&&Vector3.Dot(across,previousAcross)<0)across=-across;
            previousAcross=across;
            Vector3 normal=Vector3.Cross(tangent,across).normalized;
            float w=width*SilkWidth(u,motion);
            silkLeft[j]=points[j]-across*w;
            silkRight[j]=points[j]+across*w*(.91f+.06f*Mathf.Sin(u*5.3f+motion));
            silkCrest[j]=points[j]+normal*w*.22f;silkNormals[j]=normal;
        }
        for(int j=1;j<count;j++)
        {
            float u0=(j-1f)/(count-1),u1=j/(float)(count-1);
            Vector3 normal=(silkNormals[j-1]+silkNormals[j]).normalized;
            Quad(silkLeft[j-1],silkLeft[j],silkCrest[j],silkCrest[j-1],normal,color);
            RibbonUV(u0,u1,0,.5f);
            Quad(silkCrest[j-1],silkCrest[j],silkRight[j],silkRight[j-1],normal,color);
            RibbonUV(u0,u1,.5f,1);
        }
    }
    static float SilkWidth(float u,float motion){
        if(u<=0||u>=1)return 0;
        return Mathf.Pow(Mathf.Max(0,Mathf.Sin(u*Mathf.PI)),.6f)*(.88f+.11f*Mathf.Sin(u*6.8f+motion)+.04f*Mathf.Sin(u*11.3f-motion));
    }
    void RibbonUV(float u0,float u1,float x0,float x1){
        int n=textureCoords.Count-4;textureCoords[n]=new Vector3(u0,x0,1);textureCoords[n+1]=new Vector3(u1,x0,1);textureCoords[n+2]=new Vector3(u1,x1,1);textureCoords[n+3]=new Vector3(u0,x1,1);
    }
    void Quad(Vector3 a,Vector3 b,Vector3 c,Vector3 d,Vector3 normal,Color color)
    {
        int n=vertices.Count;vertices.Add(transform.InverseTransformPoint(a));vertices.Add(transform.InverseTransformPoint(b));vertices.Add(transform.InverseTransformPoint(c));vertices.Add(transform.InverseTransformPoint(d));
        for(int i=0;i<4;i++){normals.Add(transform.InverseTransformDirection(normal));colors.Add(color);textureCoords.Add(Vector3.zero);}
        triangles.Add(n);triangles.Add(n+1);triangles.Add(n+2);triangles.Add(n);triangles.Add(n+2);triangles.Add(n+3);
    }
    static float Hash(int i){float x=Mathf.Sin(i*127.1f+31.7f)*43758.5453f;return x-Mathf.Floor(x);}
    static Color WithAlpha(Color c,float a){c.a=Mathf.Clamp01(a);return c;}
    void Release(){var r=GetComponent<MeshRenderer>();if(r)r.enabled=false;if(mesh)Destroy(mesh);mesh=null;if(material)Destroy(material);material=null;}
    void OnDisable(){Release();}
    void OnDestroy(){Release();}
}
