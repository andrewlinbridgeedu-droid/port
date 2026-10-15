using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

/// <summary>Authored hero silhouettes, solid tarot pages and folded curtains.
/// Contact timing belongs to the skill contract; this component adds no damage.</summary>
[DefaultExecutionOrder(950)]
public sealed class HeroArcanaTheatreVFX : MonoBehaviour
{
    int generation;
    GameObject root;
    HeroSpellVolume volume;
    Batch pages, fabric, smoke;
    readonly List<Mesh> snapshots = new List<Mesh>();
    readonly List<Material> materials = new List<Material>();
    readonly List<Color> materialColors = new List<Color>();
    readonly Transform[] ghosts = new Transform[2];
    sealed class EchoSkin { public SkinnedMeshRenderer source; public readonly Mesh[] meshes=new Mesh[2]; }
    readonly List<EchoSkin> echoSkins=new List<EchoSkin>();
    readonly bool[] echoCaptured=new bool[2];
    readonly AIHeroAnimatedBody.VisualEcho[] illustratedEchoes=new AIHeroAnimatedBody.VisualEcho[2];
    Func<Vector3> echoOrigin;
    float echoPoseAge;
    Transform heavyCard;
    HeroTarotRuptureRound2 heavyRupture;
    Material heavyFace,heavyEdge;
    // Seven separately staged folios, not twelve equal-spaced accordion ribs.
    static readonly Vector3[] RewriteOffset={new Vector3(-.55f,.08f,.35f),new Vector3(.42f,.82f,-.32f),
        new Vector3(1.52f,.12f,.70f),new Vector3(1.03f,-.37f,-.55f),new Vector3(-.88f,.62f,-.10f),
        new Vector3(.08f,-.50f,.24f),new Vector3(1.72f,1.10f,.06f)};
    static readonly float[] RewriteTurn={-.72f,.52f,-.21f,1.07f,-1.32f,.18f,.81f};
    static readonly float[] RewriteDelay={0,.14f,.055f,.25f,.09f,.21f,.31f};
    Vector3 right, up, forward;
    bool ghostsOnly, dash;
    /// <param name="ghostsOnly">Only the two hero-shaped hunting shadows (2026-10-03 spell
    /// forms): no screen-wide volume and no smoke trail, so the shadows read as aimed bodies.</param>
    /// <param name="contactOverride">Contact time reported by the caller, when known.</param>
    /// <param name="dash">错步穿行's afterimage (2026-10-03): one shadow leaves at once on a
    /// nearly straight lane with a small sidestep, cuts past the target on the contact and
    /// runs on beyond it. Implies ghostsOnly.</param>
    public IEnumerator Play(string id, Transform actor, Func<Vector3> caster, Func<Vector3> target, Action onContact, bool ghostsOnly = false, float contactOverride = -1f, bool dash = false)
    {
        Clear();
        int run = generation;
        int skill = Parse(id);
        if (skill < 6 || skill > 9 || caster == null || target == null) yield break;
        this.dash = dash && skill == 6;
        this.ghostsOnly = (ghostsOnly || this.dash) && skill == 6;
        float contactTime = contactOverride > 0 ? contactOverride : skill == 7 ? .885f : skill == 8 ? .63f : .705f;
        Shader sprite = Shader.Find("Sprites/Default");
        Shader mistShader = Resources.Load<Shader>("EnemySignature/SignatureSprite");
        Texture2D atlas = Resources.Load<Texture2D>("Effects/Fool/FoolTarotVFXAtlas");
        if (!sprite || !mistShader || !atlas) { Debug.LogError("HeroArcanaTheatreVFX: missing tarot atlas or shaders."); yield return new WaitForSeconds(contactTime); if (run == generation) onContact?.Invoke(); yield break; }
        root = new GameObject("Hero arcana theatre " + skill);
        if (!this.ghostsOnly) volume=new HeroSpellVolume(root.transform,skill,contactTime);
        pages = new Batch(root.transform, sprite, atlas, false, "Tarot original art");
        fabric = new Batch(root.transform, sprite, Texture2D.whiteTexture, false, "Folded stage fabric");
        smoke = new Batch(root.transform, mistShader, Resources.Load<Texture2D>("Effects/HellHound/Texture/Smoke"), true, "Organic aftermath");
        Vector3 origin = caster();
        if (skill == 6 && actor != null){CaptureGhosts(actor, origin);echoOrigin=caster;echoPoseAge=0;}
        if(skill==7)
        {
            heavyCard=new GameObject("H07 hand-raised torn great tarot").transform;heavyCard.SetParent(root.transform,false);
            var mesh=HeroPaperRound2.Create(new Rect(0,0,1,1),.60f,.020f,.085f,7);snapshots.Add(mesh);
            heavyFace=new Material(sprite){mainTexture=Resources.Load<Texture2D>("Effects/Fool/HeavyTarotFace"),renderQueue=3018};
            heavyEdge=new Material(sprite){renderQueue=3018};materials.Add(heavyFace);materials.Add(heavyEdge);
            heavyCard.gameObject.AddComponent<MeshFilter>().sharedMesh=mesh;
            heavyCard.gameObject.AddComponent<MeshRenderer>().sharedMaterials=new[]{heavyFace,heavyEdge};
            heavyRupture=new HeroTarotRuptureRound2(root.transform,heavyFace.mainTexture);
        }
        float time = 0;
        bool contacted = false;
        try
        {
            while (time < 1.9f && generation == run)
            {
                if(skill==6)echoPoseAge=time;
                float visualTime = skill == 9 ? time : HeroVisualBeat.Sample(time, contactTime, skill == 7 ? .14f : .10f);
                Draw(skill, visualTime, contactTime, caster(), target());
                volume?.Sample(visualTime,caster(),target());
                if (!contacted && time >= contactTime)
                {
                    contacted = true; onContact?.Invoke();
                    if (generation != run) yield break;
                }
                yield return null;
                time += Time.deltaTime;
            }
            if (!contacted && generation == run) { contacted = true; onContact?.Invoke(); }
        }
        finally { if (generation == run) Clear(); }
    }
    static int Parse(string id)
    {
        if (string.IsNullOrEmpty(id)) return -1;
        for (int i = 6; i <= 9; i++)
            if (id == i.ToString() || id.EndsWith("0" + i, StringComparison.Ordinal)) return i;
        return -1;
    }
    void CaptureGhosts(Transform actor, Vector3 origin)
    {
        for (int i = 0; i < (dash ? 1 : 2); i++)
        {
            var go = new GameObject("True hero hunting shadow " + i);
            go.transform.SetParent(root.transform, false); go.transform.position = origin;
            ghosts[i] = go.transform;
        }
        var illustrated=actor.GetComponentInChildren<AIHeroAnimatedBody>();
        if(illustrated) {
            for(int i=0;i<(dash?1:2);i++) illustratedEchoes[i]=illustrated.CreateEcho(ghosts[i],origin,
                i==0?new Color(.44f,.16f,.67f):new Color(.14f,.64f,.70f));
            return;
        }
        foreach (var renderer in actor.GetComponentsInChildren<SkinnedMeshRenderer>())
        {
            if (!renderer.enabled || !renderer.sharedMesh) continue;
            // Procedural blendshape accessories are not the body snapshot.
            if (renderer.name.StartsWith("FoolRibbon", StringComparison.Ordinal)) continue;
            try
            {
                Mesh original = renderer.sharedMesh;
                // GPU-only imported meshes cannot expose their source arrays.
                // BakeMesh creates a readable, posed snapshot in renderer space.
                bool baked = !original.isReadable || original.blendShapeCount > 0;
                if (baked)
                {
                    original = new Mesh();
                    snapshots.Add(original);
                    renderer.BakeMesh(original, false);
                }
                Vector3[] vertices = original.vertices, normals = original.normals;
                BoneWeight[] weights = baked ? Array.Empty<BoneWeight>() : original.boneWeights;
                Matrix4x4[] binds = baked ? Array.Empty<Matrix4x4>() : original.bindposes;
                Transform[] bones = renderer.bones;
                // Some imported body renderers include extra unused bones; only
                // bindpose indices are meaningful. Rigid meshes have no weights.
                bool skinned = weights.Length == vertices.Length && binds.Length > 0;
                if (skinned && binds.Length > bones.Length)
                    throw new InvalidOperationException($"Missing bound bones: {renderer.name} binds={binds.Length} bones={bones.Length}");
                Matrix4x4[] matrices = new Matrix4x4[binds.Length], normalMatrices = new Matrix4x4[binds.Length];
                for (int b = 0; b < binds.Length; b++)
                {
                    matrices[b] = bones[b] ? bones[b].localToWorldMatrix * binds[b] : renderer.localToWorldMatrix;
                    normalMatrices[b] = matrices[b].inverse.transpose;
                }
                Matrix4x4 rigid = renderer.localToWorldMatrix, rigidNormal = rigid.inverse.transpose;
                for (int v = 0; v < vertices.Length; v++)
                {
                    vertices[v] = (skinned ? Skin(matrices, weights[v], vertices[v], true) : rigid.MultiplyPoint3x4(vertices[v])) - origin;
                    if (normals.Length == vertices.Length)
                        normals[v] = (skinned ? Skin(normalMatrices, weights[v], normals[v], false) : rigidNormal.MultiplyVector(normals[v])).normalized;
                }
                Mesh mesh = baked ? original : Instantiate(original); mesh.name = "Hero world skin snapshot";
                mesh.vertices = vertices;
                if (normals.Length == vertices.Length) mesh.normals = normals; else mesh.RecalculateNormals();
                mesh.RecalculateBounds(); mesh.RecalculateTangents();
                if (!baked) snapshots.Add(mesh);
                var capture=new EchoSkin{source=renderer};
                for (int i = 0; i < (dash ? 1 : 2); i++)
                {
                    var go = new GameObject(renderer.name + " echo"); go.transform.SetParent(ghosts[i], false);
                    var echoMesh=Instantiate(mesh);snapshots.Add(echoMesh);capture.meshes[i]=echoMesh;
                    go.AddComponent<MeshFilter>().sharedMesh = echoMesh;
                    var echo = go.AddComponent<MeshRenderer>(); echo.shadowCastingMode = ShadowCastingMode.Off;
                    var copies = renderer.sharedMaterials;
                    for (int m = 0; m < copies.Length; m++)
                    {
                        if (!copies[m]) continue;
                        var copy = HeroHuntingEchoMaterial.Create(copies[m], i);
                        if (!copy) continue;
                        Color tint = copy.GetColor("_Color");
                        materials.Add(copy); materialColors.Add(tint); copies[m] = copy;
                    }
                    echo.sharedMaterials = copies;
                }
                echoSkins.Add(capture);
            }
            catch (Exception e) { Debug.LogError("HeroArcanaTheatreVFX: hero snapshot failed: " + e.Message); }
        }
        if (snapshots.Count == 0) Debug.LogError("HeroArcanaTheatreVFX: no actual hero skin available for hunting shadows.");
    }
    void CaptureHuntingPose(int copy,Vector3 origin)
    {
        echoCaptured[copy]=true;
        illustratedEchoes[copy]?.Capture(origin);
        foreach(var skin in echoSkins)
        {
            if(!skin.source||!skin.meshes[copy])continue;
            var mesh=skin.meshes[copy];skin.source.BakeMesh(mesh,false);
            var vertices=mesh.vertices;var normals=mesh.normals;
            var matrix=skin.source.localToWorldMatrix;var normalMatrix=matrix.inverse.transpose;
            for(int i=0;i<vertices.Length;i++)
            {
                vertices[i]=matrix.MultiplyPoint3x4(vertices[i])-origin;
                if(normals.Length==vertices.Length)normals[i]=normalMatrix.MultiplyVector(normals[i]).normalized;
            }
            mesh.vertices=vertices;if(normals.Length==vertices.Length)mesh.normals=normals;
            mesh.RecalculateBounds();mesh.RecalculateTangents();
        }
    }
    void LateUpdate()
    {
        // Snapshot only after the actual additive body action has been applied.
        if(echoOrigin==null||!root)return;
        for(int copy=0;copy<2;copy++)if(!echoCaptured[copy]&&echoPoseAge>=.14f+copy*.14f)
            CaptureHuntingPose(copy,echoOrigin());
    }
    static Vector3 Skin(Matrix4x4[] matrices, BoneWeight w, Vector3 v, bool point)
    {
        return TransformWeighted(matrices, w.boneIndex0, w.weight0, v, point)
            + TransformWeighted(matrices, w.boneIndex1, w.weight1, v, point)
            + TransformWeighted(matrices, w.boneIndex2, w.weight2, v, point)
            + TransformWeighted(matrices, w.boneIndex3, w.weight3, v, point);
    }
    static Vector3 TransformWeighted(Matrix4x4[] matrices, int index, float weight, Vector3 v, bool point)
    {
        if (weight <= 0) return Vector3.zero;
        return (point ? matrices[index].MultiplyPoint3x4(v) : matrices[index].MultiplyVector(v)) * weight;
    }
    void Draw(int skill, float time, float contact, Vector3 s, Vector3 t)
    {
        Camera camera = Camera.main;
        right = camera ? camera.transform.right : Vector3.right;
        up = camera ? camera.transform.up : Vector3.up;
        forward = camera ? camera.transform.forward : Vector3.forward;
        float attack = Mathf.Clamp01(time / contact);
        float tail = Mathf.Clamp01((time - contact) / (1.3f - contact));
        float release = Mathf.Max(0, time - contact);
        float impactScale = HeroVisualBeat.Burst(time, contact, skill == 7 ? 1.65f : .95f);
        float alpha = Mathf.Clamp01(time / .14f) * (1 - tail);
        pages.Reset(); fabric.Reset(); smoke.Reset();
        if (skill == 6)
        {
            for (int i = 0; i < 2; i++)
            {
                // The dash leaves at once and cuts straight in; the twin hunt swings wide and accelerates.
                float depart = dash ? .05f : .14f + i * .10f;
                float p = Mathf.Clamp01((time - depart) / (contact - depart));
                if (ghosts[i])
                {
                    ghosts[i].position = Vector3.Lerp(s, t, Mathf.Pow(p, dash ? 1.5f : 2.4f))
                        + right * (dash ? -.22f : i == 0 ? -.64f : .53f) * Mathf.Sin(p * Mathf.PI)
                        + up * Mathf.Sin(p * Mathf.PI) * (i==0?.07f:.24f)
                        + (t-s).normalized*(1-Mathf.Exp(-release*13f))*(i==0?1.7f:1.35f)
                        + right*(i==0?-.24f:.24f)*Mathf.Clamp01((time-contact)*4);
                    ghosts[i].rotation = Quaternion.AngleAxis(Mathf.Sin(p * Mathf.PI) * (i == 0 ? -8 : 11), Vector3.up);
                }
                for (int j = 0; j < (ghostsOnly ? 0 : 12); j++)
                {
                    float u = Mathf.Clamp01(p - j * .025f);
                    Vector3 c = Vector3.Lerp(s, t, u) - up * .43f
                        + right * (i == 0 ? -.46f : .46f) * Mathf.Sin(u * Mathf.PI);
                    Puff(c, .39f + N(j) * .27f, new Color(.12f, .075f, .24f, alpha * .11f), j, time);
                }
            }
            foreach(var echo in illustratedEchoes) echo?.SetOpacity(alpha*.78f*Mathf.SmoothStep(0,1,Mathf.Clamp01((time-.10f)/.09f)));
            for (int i = 0; i < materials.Count; i++)
            { Color color = materialColors[i]; color.a = alpha * .78f * Mathf.SmoothStep(0,1,Mathf.Clamp01((time-.10f)/.09f)); if (materials[i].HasProperty("_Color")) materials[i].color = color; }
        }
        else if (skill == 7)
        {
            // One heavy, face-on original-art blade dominates, then breaks into
            // individual textured pieces only after the actual contact moment.
            if (time < contact+.17f)
            {
                float lift=Mathf.SmoothStep(0,1,Mathf.Clamp01(attack/.58f));
                float plunge = Mathf.Pow(Mathf.Clamp01((attack - .50f) / .50f),2.6f);
                Vector3 raised=Vector3.Lerp(s+up*.45f,t+up*2.6f,lift)+right*(.24f*(1-lift));
                Vector3 c=Vector3.Lerp(raised,t+up*.12f,plunge);
                if(heavyCard)
                {
                    heavyCard.gameObject.SetActive(true);heavyCard.position=c;
                    heavyCard.rotation=(camera?camera.transform.rotation:Quaternion.identity)*Quaternion.Euler(-17+plunge*32,17+Mathf.Sin(attack*3)*13,Mathf.Lerp(-32,38,plunge));
                    heavyCard.localScale=Vector3.one*Mathf.Lerp(.75f,3.48f,lift);
                    float holdFade=1-Mathf.SmoothStep(0,1,Mathf.Clamp01((time-contact-.045f)/.125f));
                    heavyFace.color=heavyEdge.color=new Color(1,1,1,alpha*holdFade);
                }
            }
            else if(heavyCard)heavyCard.gameObject.SetActive(false);
            // Preserve the impact span with large, patterned, curled pieces of
            // this very tarot. Do not replace its face with screen-space clouds.
            heavyRupture?.Sample(time,contact,t,right,up,forward);
        }
        else if (skill == 8)
        {
            // Broad folded stage skins peel away in opposite directions. Open
            // central gap shows the enemy as the outer role is overturned.
            for (int i = 0; i < 2; i++)
            {
                float side = i % 2 == 0 ? -1 : 1;
                float peel = Mathf.SmoothStep(0, 1, attack);
                Vector3 top = t + right * side * (.78f + peel * 1.13f + tail * .37f) + up * (i==0?1.40f:1.13f) + forward * (i==0?.12f:.48f);
                Vector3 bottom = t + right * side * (.61f + peel * 1.05f + tail * .43f) - up * (i==0?1.06f:1.22f);
                Drape(top, bottom, i==0?.93f:.72f, time, i, alpha*.97f);
            }
            for (int i = 0; i < 18; i++)
                Puff(t + right * (N(i) > .5f ? 1 : -1) * (.42f + attack * .56f)
                    + up * (N(i + 40) - .5f) * 1.6f, .47f,
                    new Color(.24f, .045f, .13f, alpha * .13f), i, time);
        }
        else
        {
            // Each folio has its own height/depth, diagonal and arrival. Their
            // discontinuous grouping cannot form one parallel accordion edge.
            for (int i = 0; i < RewriteOffset.Length; i++)
            {
                float delay=RewriteDelay[i];
                float appearPage=Mathf.SmoothStep(0,1,Mathf.Clamp01((time-.035f-delay)/.12f));
                float rewind=Mathf.SmoothStep(0,1,Mathf.Clamp01((time-.25f-delay*.55f)/(.48f+delay*.40f)));
                Vector3 offset=RewriteOffset[i];
                Vector3 start=s+right*offset.x+up*(.30f+offset.y)+forward*offset.z;
                Vector3 c=Vector3.Lerp(start,s+right*.10f+up*.12f,rewind)
                    +up*Mathf.Sin(rewind*Mathf.PI)*(.18f+N(i+6)*.22f)
                    -forward*Mathf.Sin(rewind*Mathf.PI)*(.24f+N(i+13)*.23f);
                float angle=RewriteTurn[i]+rewind*(i%2==0?1.18f:-.86f);
                float pageFade=alpha*appearPage*(1-Mathf.SmoothStep(0,1,Mathf.Clamp01((rewind-.76f)/.24f)));
                float size=(.82f+N(i+14)*.29f)*(1-rewind*.65f);
                Card(c,.58f*size,.92f*size,angle,pageFade,1.35f+i*1.17f+rewind*2.4f);
            }
            for (int i = 0; i < 22; i++)
            {
                float u = Mathf.Repeat(N(i) + attack * .65f, 1);
                Vector3 c = s + right * (.64f + (1 - u) * .70f) + up * ((N(i + 8) - .5f) * .7f) + forward * .15f;
                    Puff(c, .23f + N(i + 12) * .18f, new Color(.065f, .14f, .26f, alpha * .055f), i, time);
            }
        }
        pages.Upload(); fabric.Upload(); smoke.Upload();
    }
    void Card(Vector3 c, float width, float height, float angle, float alpha, float curl)
    {
        Vector3 x = (right * Mathf.Cos(angle) + up * Mathf.Sin(angle)) * width;
        Vector3 y = (-right * Mathf.Sin(angle) + up * Mathf.Cos(angle)) * height;
        // Crop only the actual upright tarot in tile 1; the atlas has no alpha,
        // so using an entire tile would render a large black square.
        for (int strip = 0; strip < 12; strip++)
        {
            float a = strip / 12f, b = (strip + 1) / 12f;
            Vector3 ca = c + x * (a - .5f) - forward * Mathf.Sin(a * Mathf.PI) * Mathf.Sin(curl) * width * .27f;
            Vector3 cb = c + x * (b - .5f) - forward * Mathf.Sin(b * Mathf.PI) * Mathf.Sin(curl) * width * .27f;
            float topA=.44f+Mathf.Sin(a*13+curl)*.052f,topB=.44f+Mathf.Sin(b*13+curl)*.052f;
            float baseA=.44f+Mathf.Sin(a*19+curl+2)*.045f,baseB=.44f+Mathf.Sin(b*19+curl+2)*.045f;
            pages.Quad(ca - y * baseA, cb - y * baseB, cb + y * topB, ca + y * topA, new Color(.95f, .89f, .81f, alpha),
                new Rect(Mathf.Lerp(.344f, .396f, a), .814f, (.396f - .344f) / 12f, .111f));
        }
    }
    void Drape(Vector3 top, Vector3 bottom, float width, float time, int seed, float alpha)
    {
        // Broad velvet panels have nine continuous shaded folds across their
        // width, with depth and moving sheen instead of two flat cutout colors.
        for (int row = 0; row < 24; row++)
        for (int band = 0; band < 12; band++)
        {
            float a = row / 24f, b = (row + 1) / 24f;
            float x0 = band / 12f, x1 = (band + 1) / 12f;
            float x=(band+.5f)/12f;
            float light = .5f + .5f * Mathf.Cos(x * 8.4f + a * 3.7f - time * 2.2f + seed);
            float sheen = Mathf.Pow(light, 2.3f);
            float seam=x-.5f-.17f*Mathf.Sin(a*7.3f+seed*2.1f)-.055f*Mathf.Sin(a*15.8f-time*.4f+seed);
            float gilt=Mathf.Exp(-Mathf.Pow(seam/.068f,2))*Mathf.Sin(a*Mathf.PI);
            float branch=Mathf.Exp(-Mathf.Pow((x-.30f-.11f*Mathf.Sin(a*9.2f+seed))/.065f,2))
                *Mathf.Exp(-Mathf.Pow((a-.67f)/.20f,2));
            float hem=(band==0||band==11)?.30f:0;
            // The curtain itself carries the vivid center and winding gilt;
            // the overlay remains secondary to these world-space velvet folds.
            var tint = new Color(.30f + sheen * .45f + gilt*.49f + branch*.28f + hem*.48f,
                .025f + sheen * .11f + gilt*.34f + branch*.15f + hem*.18f,
                .12f + sheen * .27f + gilt*.13f + branch*.11f, alpha * .96f);
            fabric.Quad(DrapePoint(top,bottom,width,a,x0,time,seed),DrapePoint(top,bottom,width,b,x0,time,seed),
                DrapePoint(top,bottom,width,b,x1,time,seed),DrapePoint(top,bottom,width,a,x1,time,seed), tint, new Rect(0,0,1,1));
        }
    }
    Vector3 DrapePoint(Vector3 top,Vector3 bottom,float width,float v,float u,float time,int seed)
    {
        float fold = Mathf.Sin(u * 8.4f + v * 3.7f - time * 2.2f + seed);
        float taper=.13f+.87f*Mathf.Pow(Mathf.Max(0,Mathf.Sin(v*Mathf.PI)),.55f);
        float torn=.10f*Mathf.Sin(v*19+seed)+.043f*Mathf.Sin(v*41+1.7f);
        float turn=Mathf.Clamp01((time-.34f)/.74f);
        float across=(u-.5f)*width*2*taper;
        return Vector3.Lerp(top,bottom,v) + right * (across*Mathf.Cos(turn*1.8f)+torn+Mathf.Sin(v*5+time*2+seed)*.13f)
            - forward * (fold*.23f+across*Mathf.Sin(turn*1.8f)) + up * Mathf.Sin(u*6+v*2+time)*.055f;
    }
    void Puff(Vector3 c, float size, Color tint, int seed, float time)
    {
        tint.a = Mathf.Min(.58f, tint.a * 3f);
        float angle = seed * 2.39f + time * .3f;
        Vector3 x = (right * Mathf.Cos(angle) + up * Mathf.Sin(angle)) * size * .5f;
        Vector3 y = (-right * Mathf.Sin(angle) + up * Mathf.Cos(angle)) * size * .6f;
        smoke.Quad(c - x - y, c + x - y, c + x + y, c - x + y, tint, new Rect(seed % 2 * .5f, seed % 4 / 2 * .5f, .5f, .5f));
    }
    static float N(float seed) { return Mathf.Repeat(Mathf.Sin(seed * 127.1f) * 43758.5453f, 1); }
    public void Clear()
    {
        generation++;
        if(volume!=null){volume.Dispose();volume=null;}
        if(heavyRupture!=null){heavyRupture.Dispose();heavyRupture=null;}
        if (root) { root.SetActive(false); Destroy(root); root = null; }
        if (pages != null) { pages.Dispose(); pages = null; }
        if (fabric != null) { fabric.Dispose(); fabric = null; }
        if (smoke != null) { smoke.Dispose(); smoke = null; }
        foreach (var mesh in snapshots) if (mesh) Destroy(mesh);
        foreach (var material in materials) if (material) Destroy(material);
        snapshots.Clear(); materials.Clear(); materialColors.Clear();
        for(int i=0;i<illustratedEchoes.Length;i++) {illustratedEchoes[i]?.Dispose();illustratedEchoes[i]=null;}
        echoSkins.Clear();echoCaptured[0]=echoCaptured[1]=false;echoOrigin=null;heavyCard=null;heavyFace=heavyEdge=null;
        ghosts[0] = null; ghosts[1] = null;
    }
    void OnDisable() { Clear(); }
    void OnDestroy() { Clear(); }
    sealed class Batch
    {
        readonly Mesh mesh;
        readonly Material material;
        readonly List<Vector3> vertices = new List<Vector3>(1800);
        readonly List<Color> colors = new List<Color>(1800);
        readonly List<Vector2> uv = new List<Vector2>(1800);
        readonly List<int> triangles = new List<int>(2700);
        public Batch(Transform parent, Shader shader, Texture texture, bool mist, string name)
        {
            var go = new GameObject(name); go.transform.SetParent(parent, false);
            mesh = new Mesh { name = name }; mesh.MarkDynamic();
            material = new Material(shader) { name = name, mainTexture = texture, renderQueue = mist ? 3011 : 3015 };
            if (mist) { material.SetFloat("_DstBlend", (float)BlendMode.OneMinusSrcAlpha); material.SetFloat("_Shape", 0); }
            go.AddComponent<MeshFilter>().sharedMesh = mesh;
            var renderer = go.AddComponent<MeshRenderer>(); renderer.sharedMaterial = material;
            renderer.shadowCastingMode = ShadowCastingMode.Off; renderer.receiveShadows = false;
        }
        public void Reset() { vertices.Clear(); colors.Clear(); uv.Clear(); triangles.Clear(); }
        public void Quad(Vector3 a, Vector3 b, Vector3 c, Vector3 d, Color color, Rect rect)
        {
            int n = vertices.Count; vertices.Add(a); vertices.Add(b); vertices.Add(c); vertices.Add(d);
            for (int i = 0; i < 4; i++) colors.Add(color);
            uv.Add(new Vector2(rect.xMin, rect.yMin)); uv.Add(new Vector2(rect.xMax, rect.yMin)); uv.Add(new Vector2(rect.xMax, rect.yMax)); uv.Add(new Vector2(rect.xMin, rect.yMax));
            triangles.Add(n); triangles.Add(n + 1); triangles.Add(n + 2); triangles.Add(n); triangles.Add(n + 2); triangles.Add(n + 3);
        }
        public void Upload() { mesh.Clear(); mesh.SetVertices(vertices); mesh.SetColors(colors); mesh.SetUVs(0, uv); mesh.SetTriangles(triangles, 0); mesh.RecalculateBounds(); }
        public void Dispose() { UnityEngine.Object.Destroy(mesh); UnityEngine.Object.Destroy(material); }
    }
}
