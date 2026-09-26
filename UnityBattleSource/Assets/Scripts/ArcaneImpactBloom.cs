using UnityEngine;
using UnityEngine.Rendering;

/// <summary>Sampled contact explosion. No timer or gameplay callback.</summary>
public sealed class ArcaneImpactBloom : MonoBehaviour
{
    GameObject root;
    Layer body, core;
    Camera cameraRef;
    bool warned;
    bool Ensure()
    {
        if(root)return true;
        var shader=Resources.Load<Shader>("EnemySignature/ArcaneImpactBloom");
        var fire=Resources.Load<Texture2D>("Effects/HellHound/Texture/Fire_Single");
        var smoke=Resources.Load<Texture2D>("Effects/HellHound/Texture/Smoke");
        if(!shader||!fire||!smoke){if(!warned)Debug.LogError("ArcaneImpactBloom: missing authored fire/smoke or shader.");warned=true;return false;}
        root=new GameObject("Arcane impact bloom runtime");
        body=new Layer(root.transform,shader,fire,smoke,40,false);
        core=new Layer(root.transform,shader,fire,smoke,4,true);
        cameraRef=Camera.main; return true;
    }
    public void Draw(Vector3 center,float secondsSinceContact,float duration,Color palette,int variant=0)
    {
        if(secondsSinceContact<0||duration<=0||secondsSinceContact>=duration){Clear();return;}
        if(!Ensure())return;
        if(!cameraRef)cameraRef=Camera.main;
        var cam=cameraRef;
        Vector3 right=cam?cam.transform.right:Vector3.right,up=cam?cam.transform.up:Vector3.up,forward=cam?cam.transform.forward:Vector3.forward;
        float t=secondsSinceContact*.65f/Mathf.Max(.01f,duration);
        float life=Mathf.Clamp01(secondsSinceContact/duration);
        float depth=cam?Mathf.Max(1,Vector3.Dot(center-cam.transform.position,forward)):8;
        float height=cam?(cam.orthographic?cam.orthographicSize*2:2*depth*Mathf.Tan(cam.fieldOfView*Mathf.Deg2Rad*.5f)):8;
        float span=Mathf.Clamp(height*(cam?cam.aspect:.7f)*.64f,4.2f,5.5f);
        body.Reset();core.Reset();
        // Unequal lobes launch at distinct speeds/depths. There is no radial
        // ring boundary: the blast is a compact broken volume with open gaps.
        for(int i=0;i<40;i++)
        {
            bool isSmoke=i>=25;
            float seed=N(i+variant*53+1),delay=isSmoke?.035f+seed*.028f:.018f+seed*.026f;
            float local=Mathf.Max(0,t-delay);
            float open=1-Mathf.Exp(-local*15);
            float tail=Mathf.Clamp01((t-.26f)/.39f);
            float alpha=Mathf.Clamp01(local/.035f)*(1-Mathf.SmoothStep(0,1,life));
            if(!isSmoke)alpha*=1-tail*.88f;
            float x=N(i*3+7+variant*11)*2-1;
            float y=N(i*5+19+variant*7)*1.3f-.37f;
            float z=N(i*7+13)*2-1;
            Vector3 axis=right*x+up*y+forward*z*.32f;
            Vector3 c=center+axis*span*.38f*open+up*tail*(isSmoke?.34f:.13f);
            c+=right*Mathf.Sin(local*9+i)*.075f*open;
            float size=(isSmoke?.51f:.34f)+seed*(isSmoke?.34f:.33f);
            size*=span*(.21f+open*.33f);
            // Low-center placement makes the white nucleus brief and small;
            // outer lobes leave the upper face silhouette readable.
            c-=up*.10f;
            float angle=Mathf.Atan2(-x,y)+seed*.75f;
            Color tint=isSmoke?Color.Lerp(new Color(.045f,.025f,.035f,1),palette,.28f):palette;
            tint.a=alpha*(isSmoke?.55f:1.0f);
            body.Quad(c,right,up,size*(isSmoke?1.2f:.8f),size*(isSmoke?1.0f:1.65f),angle,tint,
                new Vector4(seed,isSmoke?1:0,local,i%4));
        }
        float flash=Mathf.Clamp01(1-t/.085f);
        for(int i=0;i<4;i++)
        {
            Vector3 c=center+right*(N(i+81)-.5f)*.20f+up*(N(i+91)-.5f)*.18f;
            Color ivory=Color.Lerp(palette,new Color(1,.92f,.74f,1),.82f);ivory.a=flash*.9f;
            core.Quad(c,right,up,.48f+flash*.38f,.53f+flash*.42f,i*1.7f,ivory,new Vector4(N(i+2),0,t,0));
        }
        body.Upload(center,span*3);core.Upload(center,span*3);
    }
    static float N(int n){return Mathf.Repeat(Mathf.Sin(n*127.1f)*43758.5453f,1);}
    public void Clear()
    {
        if(root){root.SetActive(false);Destroy(root);root=null;}
        if(body!=null){body.Dispose();body=null;}if(core!=null){core.Dispose();core=null;}
    }
    void OnDisable(){Clear();}void OnDestroy(){Clear();}
    sealed class Layer
    {
        readonly Mesh mesh;readonly Material material;
        readonly Vector3[] vertices;readonly Color[] colors;readonly Vector2[] uv;readonly Vector4[] data;
        int count;
        public Layer(Transform parent,Shader shader,Texture fire,Texture smoke,int quads,bool additive)
        {
            var go=new GameObject(additive?"Impact tiny hot core":"Impact textured lobes");go.transform.SetParent(parent,false);
            mesh=new Mesh{name=additive?"Arcane impact bloom core":"Arcane impact bloom mesh"};mesh.MarkDynamic();
            material=new Material(shader){name=go.name,renderQueue=additive?3023:3022};
            material.SetTexture("_Fire",fire);material.SetTexture("_Smoke",smoke);
            material.SetFloat("_DstBlend",additive?(float)BlendMode.One:(float)BlendMode.OneMinusSrcAlpha);
            go.AddComponent<MeshFilter>().sharedMesh=mesh;var renderer=go.AddComponent<MeshRenderer>();renderer.sharedMaterial=material;
            renderer.shadowCastingMode=ShadowCastingMode.Off;renderer.receiveShadows=false;
            vertices=new Vector3[quads*4];colors=new Color[quads*4];uv=new Vector2[quads*4];data=new Vector4[quads*4];
            var indices=new int[quads*6];
            for(int i=0;i<quads;i++){int n=i*4,k=i*6;uv[n]=new Vector2(0,0);uv[n+1]=new Vector2(1,0);uv[n+2]=new Vector2(1,1);uv[n+3]=new Vector2(0,1);indices[k]=n;indices[k+1]=n+1;indices[k+2]=n+2;indices[k+3]=n;indices[k+4]=n+2;indices[k+5]=n+3;}
            mesh.vertices=vertices;mesh.uv=uv;mesh.triangles=indices;
        }
        public void Reset(){count=0;}
        public void Quad(Vector3 c,Vector3 right,Vector3 up,float width,float height,float angle,Color color,Vector4 payload)
        {
            Vector3 x=(right*Mathf.Cos(angle)+up*Mathf.Sin(angle))*width*.5f,y=(-right*Mathf.Sin(angle)+up*Mathf.Cos(angle))*height*.5f;
            int n=count++*4;vertices[n]=c-x-y;vertices[n+1]=c+x-y;vertices[n+2]=c+x+y;vertices[n+3]=c-x+y;
            for(int j=0;j<4;j++){colors[n+j]=color;data[n+j]=payload;}
        }
        public void Upload(Vector3 center,float size){mesh.SetVertices(vertices);mesh.SetColors(colors);mesh.SetUVs(1,data);mesh.bounds=new Bounds(center,Vector3.one*size);}
        public void Dispose(){Object.Destroy(mesh);Object.Destroy(material);}
    }
}
