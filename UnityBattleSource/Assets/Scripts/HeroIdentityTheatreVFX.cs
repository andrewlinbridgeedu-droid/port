using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

/// Authored identity theatre. No gameplay state; timed contact survives missing art.
public sealed class HeroIdentityTheatreVFX : MonoBehaviour
{
    const string MaskPath="Effects/Fool/NamelessDeclaration/MaskActor";
    readonly List<UnityEngine.Object> owned=new List<UnityEngine.Object>();
    readonly List<HeroPorcelainRound2> porcelain=new List<HeroPorcelainRound2>();
    GameObject root; int generation; HeroSpellVolume volume;
    sealed class Ribbon
{
    public Mesh mesh; public Transform node;
    public Vector3[] v = new Vector3[17 * 5];
    public Color[] c = new Color[17 * 5];
}

    readonly List<Ribbon> ribbons=new List<Ribbon>();
    public void Clear() { ++generation; foreach(var mask in porcelain)mask.Dispose();porcelain.Clear(); if(volume!=null){volume.Dispose();volume=null;} if(root) { root.SetActive(false); Destroy(root); } root=null; foreach(var o in owned) if(o) Destroy(o); owned.Clear(); ribbons.Clear(); }
    void OnDisable(){Clear();}
    void OnDestroy(){Clear();}
    public IEnumerator Play(string id,Func<Vector3> caster,Func<Vector3> target,Action onContact,Transform hero=null)
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
        if(!blade){end=Mathf.Max(end,contact+.95f);volume=new HeroSpellVolume(root.transform,summon?2:swap?4:5,contact);}
        Transform[] actors=new Transform[swap?2:1]; Vector3[] sizes=new Vector3[actors.Length];
        for(int i=0;i<actors.Length;i++) {
            actors[i]=(blade||stamp)?Card(stamp?11:2,stamp?2.40f:1.05f,stamp):Mask(summon?1.82f:i==0?2.18f:1.96f);
            if(swap&&i<porcelain.Count)
                porcelain[i].TintPortraitSurface(i==0?new Color(.46f,.75f,.96f):new Color(1,.61f,.39f),.64f);
            if(actors[i]) sizes[i]=actors[i].localScale;
        }
        var smoke=Smoke(blade?new Color(.25f,.065f,.43f,.75f):summon?new Color(.21f,.09f,.34f,.18f):swap?new Color(.14f,.075f,.29f,.15f):new Color(.30f,.18f,.13f,.22f));
        for(int i=0;i<(blade?2:swap?2:stamp?3:0);i++)
            MakeRibbon(blade?(i==0?new Color(.29f,.06f,.38f,.85f):new Color(.65f,.29f,.43f,.7f))
                :swap?(i==0?new Color(.08f,.47f,.77f,.90f):new Color(.95f,.47f,.17f,.88f))
                :i==0?new Color(.48f,.12f,.78f,.91f):i==1?new Color(.92f,.18f,.55f,.86f):new Color(1,.68f,.25f,.78f));
        Transform[] shards=new Transform[stamp?11:0]; Vector3[] shardScale=new Vector3[shards.Length];
        for(int i=0;i<shards.Length;i++){shards[i]=Card(i%16,.15f+(i%3)*.07f);if(shards[i]){shardScale[i]=shards[i].localScale;shards[i].gameObject.SetActive(false);}}
        float time=0; bool called=false;
        var acting=hero?hero.GetComponent<FoolSkillChoreography>():null;
        while(token==generation&&root&&time<end)
        {
            time+=Time.deltaTime;
            // Refresh the existing target delegate without changing its identity.
            from=caster!=null?caster():from; to=target!=null?target():to;
            Vector3 hand=acting?acting.CastingHandPosition:from;
            float visualTime=stamp?HeroVisualBeat.Sample(time,contact,.085f):time;
            if(volume!=null)volume.Sample(visualTime,from,to);
            float fade=1-Mathf.SmoothStep(0,1,Mathf.InverseLerp(end-.3f,end,time));
            Vector3 focus=to;
            for(int i=0;i<actors.Length;i++) if(actors[i])
            {
                float p=Mathf.Clamp01(visualTime/contact); Vector3 pos=to; Quaternion rotation=face; float scale=1;
                if(blade){float travel=Mathf.SmoothStep(0,1,p);pos=Vector3.Lerp(from,to,travel)+up*(Mathf.Sin(travel*Mathf.PI)*.48f); rotation=face*Quaternion.Euler(0,Mathf.Sin(p*Mathf.PI)*40,p*540);scale=time>contact?Mathf.Lerp(1,.05f,Mathf.InverseLerp(contact,end,time)):1;}
                else if(summon)
                {
                    pos=Vector3.Lerp(hand+up*.10f,from+up*1.08f,Mathf.SmoothStep(0,1,p))
                        -face*Vector3.forward*.36f+up*(Mathf.Max(0,time-contact)*.16f);
                    rotation=PortraitFacing(cam,pos,up,face)*Quaternion.Euler(-4,Mathf.Lerp(-32,4,Mathf.SmoothStep(0,1,p)),Mathf.Sin(time*4)*5);
                    scale=Mathf.SmoothStep(.08f,1,Mathf.Pow(p,1.4f));
                }
                else if(swap)
                {
                    float sign=i==0?-1:1,cross=Mathf.SmoothStep(0,1,Mathf.Pow(p,2.2f));
                    // The faces exchange depth and height, not 72-degree edge-on
                    // silhouettes. Both eyes/nose remain readable through the swap.
                    pos=to+right*sign*Mathf.Lerp(1.42f,-1.10f,cross)
                        +up*(.58f+sign*Mathf.Sin(cross*Mathf.PI)*.70f)
                        +face*Vector3.forward*(-1.02f+sign*Mathf.Sin(cross*Mathf.PI)*.23f);
                    rotation=PortraitFacing(cam,pos,up,face)*Quaternion.Euler(sign*5,sign*Mathf.Sin(cross*Mathf.PI)*16,sign*(8-3*cross));
                    scale=Mathf.SmoothStep(.15f,1,Mathf.Clamp01(time/.15f));
                }
                else {float drop=Mathf.Pow(p,3f);Vector3 raised=Vector3.Lerp(hand+up*.32f,to+up*1.9f,Mathf.SmoothStep(0,1,Mathf.Clamp01(p/.62f)));pos=Vector3.Lerp(raised,to,drop);rotation=face*Quaternion.Euler(Mathf.Lerp(-42,12,drop),Mathf.Lerp(-23,9,drop),Mathf.Lerp(-21,4,drop));scale=Mathf.SmoothStep(.12f,1,Mathf.Clamp01(time/.17f))*(visualTime<contact?1:HeroVisualBeat.Burst(visualTime,contact,.58f)*Mathf.Lerp(1,.82f,Mathf.Clamp01((visualTime-contact)*5)));}
                actors[i].position=pos;actors[i].rotation=rotation;actors[i].localScale=sizes[i]*scale*fade;focus=pos;
            }
            foreach(var mask in porcelain)mask.Sample(time,fade,Mathf.SmoothStep(0,1,Mathf.InverseLerp(end-.46f,end,time)),swap&&time>=contact?Mathf.Exp(-(time-contact)*10):0);
            if(smoke){smoke.transform.position=focus+face*Vector3.forward*.65f;var emission=smoke.emission;emission.rateOverTime=blade?(time<contact?18:8):(time<contact?6:3);}
            for(int i=0;i<ribbons.Count;i++)
            {
                float sign=i%2==0?-1:1;
                Vector3 start,finish;float ribbonFade=fade,width=.48f;
                if(blade){start=Vector3.Lerp(from,focus,.25f);finish=focus;width=.32f;}
                else if(swap){
                    // Two unequal identity seams cross behind, not over, the porcelain eyes.
                    Vector3 maskPoint=actors[i] ? actors[i].position : to+right*sign;
                    start=maskPoint+face*Vector3.forward*.39f+up*.36f;
                    finish=to+right*sign*.20f+up*(i==0?-.41f:.09f)+face*Vector3.forward*.42f;
                    width=i==0?.46f:.36f;
                    ribbonFade*=Mathf.SmoothStep(0,1,Mathf.Clamp01((time-.19f)/.17f));
                }
                else {
                    // The stamp peels purple wax and broken gilt into open curls on contact.
                    start=to+right*sign*.20f+up*(i==2?.32f:-.04f)+face*Vector3.forward*.23f;
                    finish=to+right*sign*(i==2?1.18f:1.62f)+up*(i==0?.58f:i==1?-.44f:.82f)
                        +face*Vector3.forward*(i==2?.55f:.38f);
                    width=i==2?.22f:.54f;
                    float open=Mathf.SmoothStep(0,1,Mathf.Clamp01((visualTime-contact+.07f)/.11f));
                    ribbonFade*=open*(1-Mathf.SmoothStep(0,1,Mathf.Clamp01((visualTime-contact)/.51f)));
                }
                UpdateRibbon(ribbons[i],start,finish,up,face,time,i,ribbonFade,width);
            }
            if(stamp&&visualTime>=contact) for(int i=0;i<shards.Length;i++) if(shards[i])
            {shards[i].gameObject.SetActive(true);float a=i*2.399963f,d=visualTime-contact;shards[i].position=to+right*(Mathf.Cos(a)*(1-Mathf.Exp(-d*12))*(.65f+i%3*.24f))+up*(Mathf.Sin(a)*(1-Mathf.Exp(-d*10))*.55f+d*.8f-d*d*2);shards[i].rotation=face*Quaternion.Euler(d*240+i*13,d*90,i*51+d*150);shards[i].localScale=shardScale[i]*fade;}
            if(!called&&time>=contact){called=true;onContact?.Invoke();if(token!=generation)yield break;}
            yield return null;
        }
        if(token==generation)Clear();
    }
    static float EvidenceContact(){float lo=0,hi=1;for(int i=0;i<24;i++){float m=(lo+hi)*.5f;if(m*m*(3-2*m)<.86f)lo=m;else hi=m;}return .95f*(.38f+.25f*(lo+hi)*.5f);}
    static Quaternion PortraitFacing(Camera camera,Vector3 point,Vector3 up,Quaternion fallback)
        =>camera?Quaternion.LookRotation(camera.transform.position-point,up):fallback*Quaternion.Euler(0,180,0);
    Material Mat(Color color,Texture texture=null)
    {var shader=Shader.Find("Sprites/Default")??Shader.Find("Unlit/Transparent")??Shader.Find("Standard");if(!shader)return null;var m=new Material(shader);m.color=color;if(texture)m.mainTexture=texture;owned.Add(m);return m;}
    Transform Card(int tile,float height,bool seal=false)
    {
        var atlas=Resources.Load<Texture2D>("Effects/Fool/FoolTarotVFXAtlas");if(!atlas)return null;
        var go=new GameObject("Solid illustrated tarot");go.transform.SetParent(root.transform,false);
        // Two illustrated faces plus a narrow physical paper edge; no additive washout.
        // Verified authored card interior; atlas tiles include opaque black margins.
        // All paper uses this real illustration rather than the full black-backed cell.
        var mesh=HeroPaperRound2.Create(new Rect(.344f,.814f,.052f,.111f),seal?.76f:.58f,seal?.006f:.016f,seal?.095f:.085f,tile,seal);owned.Add(mesh);
        var foil=Mat(seal?new Color(.92f,.84f,.64f):new Color(1,.78f,.37f),seal?atlas:null);
        if(seal)
        {
            // Sprite shaders need authored UVs, not a texture scale/offset that
            // some variants ignore. Sample the original fine gilt at the edge.
            var edgeUV=mesh.uv;var edgeColor=mesh.colors;
            foreach(int vertex in new HashSet<int>(mesh.GetIndices(1)))
            {
                Vector2 original=edgeUV[vertex];
                edgeUV[vertex]=new Vector2(.344f+original.x*.052f,.814f+original.y*.012f);
                float sheen=.67f+.21f*Mathf.Sin(mesh.vertices[vertex].y*19.3f+mesh.vertices[vertex].x*8.7f);
                edgeColor[vertex]=new Color(sheen,sheen*.91f,sheen*.70f,1);
            }
            mesh.uv=edgeUV;mesh.colors=edgeColor;
        }
        go.AddComponent<MeshFilter>().sharedMesh=mesh;go.AddComponent<MeshRenderer>().sharedMaterials=new[]{Mat(Color.white,atlas),foil};go.transform.localScale=Vector3.one*height;return go.transform;
    }
    Transform Mask(float height)
    {
        var mask=new HeroPorcelainRound2(root.transform,height,porcelain.Count%2==0?new Color(.30f,.70f,1):new Color(1,.61f,.25f));mask.EnablePortraitReadability();porcelain.Add(mask);return mask.Root;
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
