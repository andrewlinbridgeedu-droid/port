using System;
using UnityEngine;
using UnityEngine.Rendering;

/// H07 only: five unequal pieces of the great tarot peel into broad, curled foil.
/// The existing owner supplies its held visual age and the real target anchor.
/// This object has no clock, contact callback, camera shake or gameplay authority.
public sealed class HeroTarotRuptureRound2 : IDisposable
{
    const int Pieces=5,Across=12,Along=28;
    static readonly float[] Reach={-3.35f,-1.78f,.34f,2.05f,3.12f};
    static readonly float[] Rise={1.10f,2.65f,3.18f,2.30f,.82f};
    static readonly float[] Width={1.58f,1.92f,1.74f,1.68f,1.35f};
    static readonly Rect[] Art={new Rect(.04f,.08f,.32f,.83f),new Rect(.61f,.11f,.31f,.79f),
        new Rect(.26f,.25f,.45f,.56f),new Rect(.10f,.54f,.38f,.39f),new Rect(.57f,.04f,.34f,.55f)};
    GameObject root;
    Mesh mesh;
    Material material;
    readonly Vector3[] vertices=new Vector3[Pieces*(Across+1)*(Along+1)];

    public HeroTarotRuptureRound2(Transform parent,Texture art)
    {
        var shader=Resources.Load<Shader>("Effects/Fool/HeroTarotRuptureRound2");
        if(!shader||!art){Debug.LogError("H07 patterned rupture requires its owned shader and original tarot art.");return;}
        root=new GameObject("H07 curled gilt tarot rupture");root.transform.SetParent(parent,false);
        mesh=new Mesh{name="Five unequal torn tarot foil surfaces"};mesh.MarkDynamic();
        var uv=new Vector2[vertices.Length];var surface=new Vector2[vertices.Length];
        var indices=new int[Pieces*Across*Along*6];int cursor=0;
        for(int part=0;part<Pieces;part++)
        for(int row=0;row<=Along;row++)
        for(int col=0;col<=Across;col++)
        {
            int index=part*(Across+1)*(Along+1)+row*(Across+1)+col;
            float u=col/(float)Across,v=row/(float)Along;
            uv[index]=new Vector2(Mathf.Lerp(Art[part].xMin,Art[part].xMax,u),Mathf.Lerp(Art[part].yMin,Art[part].yMax,v));
            surface[index]=new Vector2(u,v);
            if(row==Along||col==Across)continue;
            int a=index,b=index+1,c=index+Across+2,d=index+Across+1;
            indices[cursor++]=a;indices[cursor++]=b;indices[cursor++]=c;
            indices[cursor++]=a;indices[cursor++]=c;indices[cursor++]=d;
        }
        mesh.vertices=vertices;mesh.uv=uv;mesh.uv2=surface;mesh.triangles=indices;
        root.AddComponent<MeshFilter>().sharedMesh=mesh;
        material=new Material(shader){name="H07 preserved tarot filigree on purple foil",mainTexture=art,renderQueue=3024};
        var renderer=root.AddComponent<MeshRenderer>();renderer.sharedMaterial=material;
        renderer.shadowCastingMode=ShadowCastingMode.Off;renderer.receiveShadows=false;
        root.SetActive(false);
    }

    public void Sample(float visualTime,float contact,Vector3 center,Vector3 right,Vector3 up,Vector3 forward)
    {
        if(!root)return;
        float age=visualTime-contact-.010f;
        if(age<=0||age>=.56f){root.SetActive(false);return;}
        root.SetActive(true);
        float open=Mathf.SmoothStep(0,1,Mathf.Clamp01(age/.045f));
        float burst=open*(1+.14f*Mathf.Exp(-Mathf.Max(0,age-.045f)*16));
        float fade=1-Mathf.SmoothStep(0,1,Mathf.Clamp01((age-.19f)/.37f));
        material.SetFloat("_Clock",age);material.SetFloat("_Fade",fade);
        material.SetFloat("_Flash",Mathf.Exp(-Mathf.Max(0,age-.045f)*19)*open);
        Vector3 tangent=(right*.81f+up*.59f).normalized;
        Vector3 normal=(-right*.59f+up*.81f).normalized;
        for(int part=0;part<Pieces;part++)
        for(int row=0;row<=Along;row++)
        for(int col=0;col<=Across;col++)
        {
            float u=col/(float)Across,v=row/(float)Along,lateral=u*2-1;
            float taper=Mathf.Pow(Mathf.Max(0,Mathf.Sin(v*Mathf.PI)),.58f);
            // Geometry owns the broken brush edge; the shader never hides a
            // rectangular plate. Unequal low-frequency folds keep soft normals.
            float tear=1+.15f*Mathf.Sin(v*17.3f+part*1.9f)+.075f*Mathf.Sin(v*39.7f+part*.7f);
            float breadth=Width[part]*taper*tear*(.45f+.10f*v);
            float travel=Mathf.Pow(v,.86f);
            float curl=Mathf.Sin(v*4.4f+part*.79f-age*4.2f);
            float x=Reach[part]*travel+lateral*breadth
                +Mathf.Sin(v*3.8f+part)*.36f*v;
            float y=Rise[part]*travel+Mathf.Sin(v*Mathf.PI)*(.35f+part*.09f)
                +lateral*breadth*.24f*Mathf.Sin(v*5+part);
            float z=(part-2)*.16f*v+curl*.64f*v
                +lateral*lateral*.42f*taper+Mathf.Sin(u*Mathf.PI)*.19f;
            Vector3 peel=(tangent*x+normal*y+forward*z)*(.09f+.91f*burst);
            // After the fast opening, sheets roll and fall; their reach is not
            // traded for a large cloudy envelope or a uniform radial explosion.
            peel+=normal*(age*.55f*travel)-up*(age*age*.95f*travel);
            int index=part*(Across+1)*(Along+1)+row*(Across+1)+col;
            vertices[index]=center+peel-forward*.16f;
        }
        mesh.vertices=vertices;mesh.RecalculateNormals();mesh.RecalculateBounds();
    }

    public void Dispose()
    {
        if(root){root.SetActive(false);UnityEngine.Object.Destroy(root);}root=null;
        if(mesh)UnityEngine.Object.Destroy(mesh);mesh=null;
        if(material)UnityEngine.Object.Destroy(material);material=null;
    }
}
