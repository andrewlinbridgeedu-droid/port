using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

/// Authored identity theatre. No gameplay state; timed contact survives missing art.
public sealed class HeroIdentityTheatreVFX : MonoBehaviour
{
    const string MaskPath="Effects/Fool/NamelessDeclaration/MaskActor";
    readonly List<UnityEngine.Object> owned=new List<UnityEngine.Object>();
    GameObject root; int generation;
    sealed class Ribbon
{
    public Mesh mesh; public Transform node;
    public Vector3[] v = new Vector3[17 * 5];
    public Color[] c = new Color[17 * 5];
}

    readonly List<Ribbon> ribbons=new List<Ribbon>();
    public void Clear() { ++generation; if(root) { root.SetActive(false); Destroy(root); } root=null; foreach(var o in owned) if(o) Destroy(o); owned.Clear(); ribbons.Clear(); }
    void OnDisable(){Clear();}
    void OnDestroy(){Clear();}
    public IEnumerator Play(string id,Func<Vector3> caster,Func<Vector3> target,Action onContact)
    {
        Clear(); int token=generation;
        bool blade=id=="fool_skill_01", summon=id=="fool_skill_02", swap=id=="fool_skill_04", stamp=id=="fool_skill_05";
        if(!blade&&!summon&&!swap&&!stamp) yield break;
        // 02 = authored windup .12 + travel .26. 05 preserves smoothstep drop>=.86.
        float contact=blade ? .6192f : summon ? .38f : swap ? .441f : EvidenceContact();
        float end=blade?1.05f:summon?1.45f:swap?1.25f:1.30f;
        Vector3 from=caster!=null?caster():transform.position, to=target!=null?target():from;
        Camera cam=Camera.main; Vector3 right=cam?cam.transform.right:Vector3.right, up=cam?cam.transform.up:Vector3.up;
        Quaternion face=cam?cam.transform.rotation:Quaternion.identity;
        root=new GameObject("Hero Identity Theatre "+id);
        Transform[] actors=new Transform[swap?2:1]; Vector3[] sizes=new Vector3[actors.Length];
        for(int i=0;i<actors.Length;i++) { actors[i]=(blade||stamp)?Card(stamp?11:2,stamp?2.4f:1.05f):Mask(summon?1.65f:1.35f); if(actors[i]) sizes[i]=actors[i].localScale; }
        var smoke=Smoke(blade?new Color(.25f,.065f,.43f,.75f):summon?new Color(.29f,.15f,.39f,.78f):swap?new Color(.22f,.11f,.38f,.72f):new Color(.42f,.27f,.25f,.75f));
        for(int i=0;i<(swap?4:2);i++) MakeRibbon(i%2==0?new Color(.29f,.06f,.38f,.85f):new Color(.65f,.29f,.43f,.7f));
        Transform[] shards=new Transform[stamp?14:0]; Vector3[] shardScale=new Vector3[shards.Length];
        for(int i=0;i<shards.Length;i++){shards[i]=Card(i%16,.15f+(i%3)*.07f);if(shards[i]){shardScale[i]=shards[i].localScale;shards[i].gameObject.SetActive(false);}}
        float time=0; bool called=false;
        while(token==generation&&root&&time<end)
        {
            time+=Time.deltaTime;
            float fade=1-Mathf.SmoothStep(0,1,Mathf.InverseLerp(end-.3f,end,time));
            Vector3 focus=to;
            for(int i=0;i<actors.Length;i++) if(actors[i])
            {
                float p=Mathf.Clamp01(time/contact); Vector3 pos=to; Quaternion rotation=face; float scale=1;
                if(blade){float travel=Mathf.SmoothStep(0,1,p);pos=Vector3.Lerp(from,to,travel)+up*(Mathf.Sin(travel*Mathf.PI)*.48f); rotation=face*Quaternion.Euler(0,Mathf.Sin(p*Mathf.PI)*40,p*540);scale=time>contact?Mathf.Lerp(1,.05f,Mathf.InverseLerp(contact,end,time)):1;}
                else if(summon){pos=from+up*(.3f+Mathf.SmoothStep(0,1,p)*.95f);rotation=face*Quaternion.Euler(0,Mathf.Lerp(-75,0,Mathf.SmoothStep(0,1,p)),Mathf.Sin(time*3)*8);scale=Mathf.SmoothStep(.08f,1,p);}
                else if(swap){float sign=i==0?-1:1;float cross=Mathf.SmoothStep(0,1,p);pos=to+right*sign*Mathf.Lerp(1.1f,-1.1f,cross)+up*(.35f+sign*Mathf.Sin(cross*Mathf.PI)*.45f);rotation=face*Quaternion.Euler(0,sign*Mathf.Sin(cross*Mathf.PI)*65,sign*12);scale=Mathf.SmoothStep(.15f,1,Mathf.Clamp01(time/.15f));}
                else {float drop=Mathf.SmoothStep(0,1,p);pos=to+up*(2.5f*(1-drop));rotation=face*Quaternion.Euler(Mathf.Lerp(-32,0,drop),0,Mathf.Lerp(-18,0,drop));scale=time<contact?1:Mathf.Lerp(1,.88f,Mathf.Clamp01((time-contact)*4));}
                actors[i].position=pos;actors[i].rotation=(summon||swap)?rotation*Quaternion.Euler(0,180,0):rotation;actors[i].localScale=sizes[i]*scale*fade;focus=pos;
            }
            if(smoke){smoke.transform.position=focus;var emission=smoke.emission;emission.rateOverTime=time<contact?42:18;}
            for(int i=0;i<ribbons.Count;i++)
            {
                Vector3 start=blade?Vector3.Lerp(from,focus,.25f):focus+right*((i%2==0?-1:1)*.25f);
                Vector3 finish=blade?focus:focus+right*((i%2==0?-1:1)*(summon?1.25f:1.8f))-up*.8f;
                UpdateRibbon(ribbons[i],start,finish,up,face,time,i,fade,blade ? .32f : .48f);
            }
            if(stamp&&time>=contact) for(int i=0;i<shards.Length;i++) if(shards[i])
            {shards[i].gameObject.SetActive(true);float a=i*2.399963f,d=time-contact;shards[i].position=to+right*(Mathf.Cos(a)*d*(1.5f+i%3))+up*(Mathf.Sin(a)*d*2+d*.8f-d*d*2);shards[i].rotation=face*Quaternion.Euler(d*240+i*13,d*90,i*51+d*150);shards[i].localScale=shardScale[i]*fade;}
            if(!called&&time>=contact){called=true;onContact?.Invoke();if(token!=generation)yield break;}
            yield return null;
        }
        if(token==generation)Clear();
    }
    static float EvidenceContact(){float lo=0,hi=1;for(int i=0;i<24;i++){float m=(lo+hi)*.5f;if(m*m*(3-2*m)<.86f)lo=m;else hi=m;}return .95f*(.38f+.25f*(lo+hi)*.5f);}
    Material Mat(Color color,Texture texture=null)
    {var shader=Shader.Find("Sprites/Default")??Shader.Find("Unlit/Transparent")??Shader.Find("Standard");if(!shader)return null;var m=new Material(shader);m.color=color;if(texture)m.mainTexture=texture;owned.Add(m);return m;}
    Transform Card(int tile,float height)
    {
        var atlas=Resources.Load<Texture2D>("Effects/Fool/FoolTarotVFXAtlas");if(!atlas)return null;
        var go=new GameObject("Solid illustrated tarot");go.transform.SetParent(root.transform,false);
        // Two illustrated faces plus a narrow physical paper edge; no additive washout.
        var mesh=new Mesh();owned.Add(mesh);float w=.58f,h=1,d=.012f;
        mesh.vertices=new[]{new Vector3(-w/2,-h/2,-d),new Vector3(w/2,-h/2,-d),new Vector3(w/2,h/2,-d),new Vector3(-w/2,h/2,-d),new Vector3(-w/2,-h/2,d),new Vector3(w/2,-h/2,d),new Vector3(w/2,h/2,d),new Vector3(-w/2,h/2,d)};
        mesh.triangles=new[]{0,2,1,0,3,2,4,5,6,4,6,7,0,1,5,0,5,4,1,2,6,1,6,5,2,3,7,2,7,6,3,0,4,3,4,7};
        // Verified authored card interior; atlas tiles include opaque black margins.
        // All paper uses this real illustration rather than the full black-backed cell.
        float x=.344f,y=.814f,cw=.052f,ch=.111f;var a=new Vector2(x,y);var b=new Vector2(x+cw,y);var c=new Vector2(x+cw,y+ch);var e=new Vector2(x,y+ch);mesh.uv=new[]{a,b,c,e,a,b,c,e};mesh.RecalculateNormals();mesh.RecalculateBounds();go.AddComponent<MeshFilter>().sharedMesh=mesh;go.AddComponent<MeshRenderer>().sharedMaterial=Mat(Color.white,atlas);go.transform.localScale=Vector3.one*height;return go.transform;
    }
    Transform Mask(float height)
    {
        var prefab=Resources.Load<GameObject>(MaskPath);if(!prefab)return null;
        var holder=new GameObject("Porcelain identity actor");holder.transform.SetParent(root.transform,false);var model=Instantiate(prefab,holder.transform);var rs=model.GetComponentsInChildren<Renderer>();if(rs.Length==0)return holder.transform;
        Bounds b=rs[0].bounds;foreach(var r in rs)b.Encapsulate(r.bounds);model.transform.position-=b.center;holder.transform.localScale=Vector3.one*(height/Mathf.Max(.01f,b.size.y));return holder.transform;
    }
    ParticleSystem Smoke(Color tint)
    {
        var texture=Resources.Load<Texture2D>("Effects/HellHound/Texture/Smoke");if(!texture)return null;
        var go=new GameObject("Dense rolling organic smoke");go.transform.SetParent(root.transform,false);var ps=go.AddComponent<ParticleSystem>();ps.Stop(true,ParticleSystemStopBehavior.StopEmittingAndClear);var main=ps.main;main.loop=false;main.duration=1.5f;main.startLifetime=.65f;main.startSpeed=.42f;main.startSize=new ParticleSystem.MinMaxCurve(.55f,1.1f);main.startColor=tint;main.maxParticles=64;main.simulationSpace=ParticleSystemSimulationSpace.World;var shape=ps.shape;shape.shapeType=ParticleSystemShapeType.Sphere;shape.radius=.35f;var emission=ps.emission;emission.rateOverTime=40;var color=ps.colorOverLifetime;color.enabled=true;var gradient=new Gradient();gradient.SetKeys(new[]{new GradientColorKey(Color.white,0),new GradientColorKey(Color.white,1)},new[]{new GradientAlphaKey(0,0),new GradientAlphaKey(1,.2f),new GradientAlphaKey(0,1)});color.color=gradient;var sheet=ps.textureSheetAnimation;sheet.enabled=true;sheet.numTilesX=2;sheet.numTilesY=2;sheet.animation=ParticleSystemAnimationType.WholeSheet;sheet.startFrame=new ParticleSystem.MinMaxCurve(0f,1f);sheet.frameOverTime=new ParticleSystem.MinMaxCurve(1f, AnimationCurve.Linear(0,0,1,1));sheet.cycleCount=1;
        var smokeShader=Resources.Load<Shader>("EnemySignature/SignatureSprite")??Shader.Find("Mindstone/EnemySignature/Sprite");
        if(!smokeShader){Destroy(go);return null;}
        var smokeMat=new Material(smokeShader);owned.Add(smokeMat);smokeMat.mainTexture=texture;smokeMat.SetFloat("_Shape",0);smokeMat.SetFloat("_DstBlend",(float)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);go.GetComponent<ParticleSystemRenderer>().sharedMaterial=smokeMat;ps.Play();return ps;
    }
void MakeRibbon(Color color)
{
    var go = new GameObject("Folded broad silk");
    go.transform.SetParent(root.transform, false);
    var r = new Ribbon { node = go.transform, mesh = new Mesh() };
    owned.Add(r.mesh); r.mesh.MarkDynamic();
    var uv = new Vector2[85]; var triangles = new int[16 * 4 * 6];
    for (int i = 0; i < 17; i++) for (int j = 0; j < 5; j++)
    {
        int n = i * 5 + j; uv[n] = new Vector2(i / 16f, j / 4f);
        r.c[n] = Color.white;
        if (i < 16 && j < 4)
        {
            int k = (i * 4 + j) * 6;
            triangles[k] = n; triangles[k + 1] = n + 5; triangles[k + 2] = n + 1;
            triangles[k + 3] = n + 1; triangles[k + 4] = n + 5; triangles[k + 5] = n + 6;
        }
    }
    r.mesh.vertices = r.v; r.mesh.uv = uv; r.mesh.colors = r.c; r.mesh.triangles = triangles;
    go.AddComponent<MeshFilter>().sharedMesh = r.mesh;
    go.AddComponent<MeshRenderer>().sharedMaterial = Mat(color);
    ribbons.Add(r);
}
static void UpdateRibbon(Ribbon r, Vector3 a, Vector3 b, Vector3 up,
    Quaternion face, float time, int seed, float fade, float width)
{
    Vector3 cameraUp = face * Vector3.up, depth = face * Vector3.forward;
    // Cloth has broad rolling bends and one broad crosswise fold, not thin stripes.
    Vector3 light = (cameraUp * .6f - depth).normalized;
    for (int i = 0; i < 17; i++)
    {
        float t = i / 16f, envelope = Mathf.Sin(t * Mathf.PI);
        float wave = t * 6.2f - time * 3.4f + seed * 1.7f;
        Vector3 center = Vector3.Lerp(a, b, t)
            + up * (Mathf.Sin(wave) * .17f * envelope)
            + depth * (Mathf.Sin(wave * .72f + .8f) * width * .38f * envelope);
        float twist = Mathf.Sin(wave * .85f) * .65f;
        Vector3 across = cameraUp * Mathf.Cos(twist) + depth * Mathf.Sin(twist);
        Vector3 normal = -depth * Mathf.Cos(twist) + cameraUp * Mathf.Sin(twist);
        float half = width * (.24f + .76f * envelope) * .5f;
        for (int j = 0; j < 5; j++)
        {
            float s = j / 4f * 2 - 1;
            float foldPhase = s * Mathf.PI + wave * .45f;
            float fold = Mathf.Cos(foldPhase) * width * .13f * envelope;
            int n = i * 5 + j;
            r.v[n] = center + across * (s * half) + normal * fold;
            float slope = -Mathf.Sin(foldPhase) * .13f * Mathf.PI * envelope
                / Mathf.Max(.12f, half / width);
            Vector3 foldNormal = (normal - across * slope).normalized;
            float shade = .43f + .69f * Mathf.Max(0, Vector3.Dot(foldNormal, light));
            // Transparent tail dissolves instead of shrinking the strip into a line.
            float alpha = fade * Mathf.SmoothStep(0, 1, (1 - t) * 7)
                * (j == 0 || j == 4 ? .88f : 1);
            r.c[n] = new Color(shade, shade, shade, alpha);
        }
    }
    r.mesh.vertices = r.v; r.mesh.colors = r.c; r.mesh.RecalculateBounds();
}

}
