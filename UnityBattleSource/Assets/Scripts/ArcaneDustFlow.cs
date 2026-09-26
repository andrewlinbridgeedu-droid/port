using UnityEngine;
using UnityEngine.Rendering;

/// <summary>Dense camera-sized grains carried by irregular volumetric streams.
/// Pure presentation: Draw is sampled by the owner; Clear owns every resource.</summary>
public sealed class ArcaneDustFlow : MonoBehaviour
{
    public bool SuppressImpactBloom { get; set; }
    const int Count = 11000;
    struct Grain { public float u, x, y, z, size, light, phase; public int lane; }
    Grain[] grains;
    Vector3[] vertices;
    Color[] colors;
    Mesh mesh;
    Material material;
    ArcaneImpactBloom impact;
    GameObject root;
    Camera cachedCamera;
    bool missingShaderReported;

    bool Ensure()
    {
        if (mesh) return true;
        Shader shader = Resources.Load<Shader>("EnemySignature/ArcaneDust");
        if (!shader)
        {
            if (!missingShaderReported) Debug.LogError("ArcaneDustFlow: EnemySignature/ArcaneDust shader missing.");
            missingShaderReported = true; return false;
        }
        if (grains == null)
        {
            grains = new Grain[Count]; vertices = new Vector3[Count * 4]; colors = new Color[Count * 4];
            for (int i = 0; i < Count; i++) grains[i] = new Grain {
                u=Hash(i*7+1), x=Hash(i*7+2)*2-1, y=Hash(i*7+3)*2-1,
                z=Hash(i*7+4)*2-1, size=Hash(i*7+5), light=Hash(i*7+6), phase=Hash(i*7+7)*6.283185f, lane=i%11 };
        }
        root = new GameObject("Arcane dust flow runtime");
        // Geometry is world-space; never inherit an actor's FBX scale.
        mesh = new Mesh { name="Arcane dust 11000 grains" }; mesh.MarkDynamic();
        material = new Material(shader) { name="Arcane dust owned", renderQueue=3018 };
        root.AddComponent<MeshFilter>().sharedMesh=mesh;
        var renderer=root.AddComponent<MeshRenderer>(); renderer.sharedMaterial=material;
        renderer.shadowCastingMode=ShadowCastingMode.Off; renderer.receiveShadows=false;
        renderer.lightProbeUsage=LightProbeUsage.Off; renderer.reflectionProbeUsage=ReflectionProbeUsage.Off;
        var uv=new Vector2[Count*4]; var indices=new int[Count*6];
        for(int i=0;i<Count;i++)
        {
            int n=i*4,k=i*6;
            uv[n]=new Vector2(-1,-1); uv[n+1]=new Vector2(1,-1); uv[n+2]=new Vector2(1,1); uv[n+3]=new Vector2(-1,1);
            indices[k]=n;indices[k+1]=n+1;indices[k+2]=n+2;indices[k+3]=n;indices[k+4]=n+2;indices[k+5]=n+3;
        }
        mesh.vertices=vertices; mesh.colors=colors; mesh.uv=uv; mesh.triangles=indices;
        cachedCamera=Camera.main;
        return true;
    }
    public void Draw(Vector3 source,Vector3 target,float age,float contactTime,float endTime,Color warm,Color shadow,int variant=0)
    {
        if(age<0 || endTime<=0 || age>=endTime) { Clear(); return; }
        if(!Ensure())return;
        if(!cachedCamera)cachedCamera=Camera.main;
        var camera=cachedCamera;
        Vector3 cr=camera?camera.transform.right:Vector3.right;
        Vector3 cu=camera?camera.transform.up:Vector3.up;
        Vector3 cv=camera?camera.transform.forward:Vector3.forward;
        Vector3 middle=Vector3.Lerp(source,target,.5f);
        float depth=camera?Mathf.Max(1,Vector3.Dot(middle-camera.transform.position,cv)):8;
        float visibleHeight=camera?(camera.orthographic?camera.orthographicSize*2:2*depth*Mathf.Tan(camera.fieldOfView*Mathf.Deg2Rad*.5f)):8;
        float span=Mathf.Clamp(visibleHeight*(camera?camera.aspect:.7f)*.32f,1.5f,4.5f);
        float pixelWorld=visibleHeight/Mathf.Max(1,camera?camera.pixelHeight:1024);
        float contact=Mathf.Max(.05f,contactTime);
        if(!impact) impact=gameObject.AddComponent<ArcaneImpactBloom>();
        if(!SuppressImpactBloom)impact.Draw(target,age-contact,Mathf.Max(.12f,endTime-contact),warm,variant);
        else impact.Clear();
        float build=Mathf.Clamp01(age/contact);
        float charge=Mathf.SmoothStep(0,1,Mathf.Clamp01(build/.34f));
        float head=Mathf.SmoothStep(0,1,Mathf.Clamp01((build-.21f)/.79f));
        float dispersal=Mathf.Clamp01((age-contact)/Mathf.Max(.05f,endTime-contact));
        float fade=Mathf.Clamp01(age/.10f)*Mathf.Pow(1-dispersal,1.15f);
        float clock=age*1.8f+variant*1.731f;
        Vector3 travel=target-source;
        bool selfCast=travel.sqrMagnitude<1f;
        if(selfCast) { travel=cu*1.35f+cv*.75f; span=Mathf.Clamp(span,1.6f,2.3f); }
        for(int i=0;i<Count;i++)
        {
            Grain g=grains[i];
            float lane=g.lane/10f*2-1;
            float drift=Mathf.Repeat(g.u+age*(.12f+.035f*g.z),1);
            // Bias grains into substantial moving packets, separated by dark
            // gaps. Each packet has its own broad, nonperiodic turbulent path.
            float u=head*(.20f+.80f*drift);
            float envelope=Mathf.Sin(Mathf.Clamp01(u)*Mathf.PI);
            float group=g.lane*1.47f+variant*.69f;
            float wave=Mathf.Sin(u*5.2f+group+clock*.62f);
            float wave2=Mathf.Sin(u*8.7f-group*.73f-clock*.43f);
            float curlX=Mathf.Sin(g.y*3.6f+g.z*2.1f+clock+group);
            float curlY=Mathf.Sin(g.z*4.1f-g.x*2.8f-clock*.87f+group*.6f);
            float curlZ=Mathf.Sin(g.x*3.8f+g.y*2.5f+clock*.71f);
            float packet=.13f+.19f*(.5f+.5f*Mathf.Sin(drift*10+group));
            Vector3 c=source+travel*u;
            c+=cr*(lane*span*(.32f*charge+.68f*envelope)+wave*span*.23f*envelope);
            c+=cu*(.18f+wave2*.48f+envelope*.32f);
            c+=cr*(g.x+curlX*.42f)*packet*span;
            c+=cu*(g.y+curlY*.42f)*packet*1.3f;
            c+=cv*(g.z+curlZ*.45f)*packet*2.4f;
            if(dispersal>0)
            {
                // All fine grains participate in the actual impact burst: a
                // dense bright centre fans into irregular high-speed ejecta.
                float seconds=age-contact;
                Vector3 velocity=cr*g.x+cu*(g.y*.82f+.20f)+cv*g.z*.75f;
                float speed=(1.7f+g.u*5.8f)*(g.light>.94f?1.4f:1f);
                c=target+velocity*speed*Mathf.Pow(seconds,.62f)
                    +cr*Mathf.Sin(g.phase+seconds*9)*seconds*.3f
                    -cu*seconds*seconds*1.5f;
            }
            float grainPixels=(g.size>.985f?2.8f:Mathf.Lerp(1.05f,2.20f,g.size*g.size))*(dispersal>0?1.25f:1f);
            float localDepth=camera&&!camera.orthographic?Mathf.Max(.5f,Vector3.Dot(c-camera.transform.position,cv))/depth:1;
            float diameter=Mathf.Clamp(pixelWorld*grainPixels*localDepth,.007f,.028f);
            if(g.light<.085f)diameter*=1.7f; // ~300 darker dust grains, still tiny, not smoke cards.
            float angle=g.phase+clock*.1f;
            Vector3 x=(cr*Mathf.Cos(angle)+cu*Mathf.Sin(angle))*diameter*.5f;
            Vector3 y=(-cr*Mathf.Sin(angle)+cu*Mathf.Cos(angle))*diameter*(g.light>.9f?.80f:.5f);
            Color tint;
            if(g.light<.085f) tint=Color.Lerp(shadow,warm,.08f);
            else if(g.light>.94f) tint=Color.Lerp(warm,new Color(1f,.91f,.72f,1),.74f);
            else tint=Color.Lerp(shadow,warm,.48f+g.light*.52f);
            float twinkle=.74f+.26f*Mathf.Sin(clock*2+g.phase);
            tint.a=fade*(g.light<.085f?.44f:.70f+.25f*g.light)*twinkle;
            int n=i*4;vertices[n]=c-x-y;vertices[n+1]=c+x-y;vertices[n+2]=c+x+y;vertices[n+3]=c-x+y;
            colors[n]=tint;colors[n+1]=tint;colors[n+2]=tint;colors[n+3]=tint;
        }
        mesh.SetVertices(vertices);mesh.SetColors(colors);
        mesh.bounds=new Bounds(middle, new Vector3(Mathf.Abs(travel.x),Mathf.Abs(travel.y),Mathf.Abs(travel.z))+Vector3.one*(span*4+6));
    }
    static float Hash(int seed)
    {
        uint h=unchecked((uint)seed*747796405u+2891336453u);
        h=((h>>((int)(h>>28)+4))^h)*277803737u;h=(h>>22)^h;
        return (h&0x00ffffffu)/16777216f;
    }
    public void Clear()
    {
        if(impact)impact.Clear();
        if(root){root.SetActive(false);Destroy(root);root=null;}
        if(mesh){Destroy(mesh);mesh=null;}
        if(material){Destroy(material);material=null;}
    }
    void OnDisable(){Clear();}
    void OnDestroy(){Clear();}
}
