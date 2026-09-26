using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

/// <summary>Presentation only. Positions are live world-space mouth/chest and victim impact anchors.
/// Source should return mouth for Hound, cabinet for Archivist, working hand for Matriarch.
/// The combat owner supplies damage through onContact. No gameplay state is changed here.</summary>
public sealed partial class EnemySignatureSpellVFX : MonoBehaviour
{
    public enum Kind { Hound, Archivist, Matriarch }
    public const float ChargeDuration = 1.4f;
    public const float TravelDuration = .65f;
    public const float ResidualDuration = .8f;
    public bool IsPlaying { get; private set; }

    int generation;
    GameObject root;
    IronVaultArmProjectile launchArm;
    SpellSceneLighting surfaceLighting;
    EnemyArcaneProjection arcaneProjection;
    Layer glow, ink, flames, smoke, bloom, parchment, archiveShield;
    Vector3 right, up, forward, view, cameraRight, cameraUp;
    float airWidth = 3f, airHeight = 2.5f;
    readonly Vector3[] curve = new Vector3[49];
    static readonly Color Gold = new Color(1f, .57f, .12f, .9f);
    static readonly Color Violet = new Color(.62f, .13f, 1f, .85f);
    static readonly Color White = new Color(1f, .85f, .54f, .95f);
    static readonly Color CrimsonRose = new Color(1f,.055f,.18f,.8f);
    static readonly Color CrimsonGold = new Color(1f,.43f,.27f,.85f);
    static readonly Color CrimsonPearl = new Color(1f,.72f,.65f,.85f);
    static readonly Color Ember = new Color(1f, .17f, .035f, .85f);

    // Six batched dynamic meshes; authored flame/smoke sprites, soft bloom, substantive pages.
    // No per-particle objects/materials or scene lights.
    sealed class Layer
    {
        public readonly Mesh mesh;
        public readonly Material material;
        readonly List<Vector3> positions = new List<Vector3>(12000);
        readonly List<Color> colors = new List<Color>(12000);
        readonly List<Vector2> uvs = new List<Vector2>(12000);
        readonly List<int> indices = new List<int>(18000);
        public Layer(Transform parent, Shader shader, string name, bool additive)
        {
            var go = new GameObject(name);
            go.transform.SetParent(parent, false);
            mesh = new Mesh { name = name + " runtime mesh" };
            mesh.MarkDynamic();
            material = new Material(shader) { name = name + " runtime material" };
            material.renderQueue = additive ? 3015 : 3014;
            material.SetFloat("_DstBlend", additive ? (float)BlendMode.One : (float)BlendMode.OneMinusSrcAlpha);
            go.AddComponent<MeshFilter>().sharedMesh = mesh;
            var renderer = go.AddComponent<MeshRenderer>();
            renderer.sharedMaterial = material;
            renderer.shadowCastingMode = ShadowCastingMode.Off;
            renderer.receiveShadows = false;
            renderer.lightProbeUsage = LightProbeUsage.Off;
            renderer.reflectionProbeUsage = ReflectionProbeUsage.Off;
        }
        public void Clear() { positions.Clear(); colors.Clear(); uvs.Clear(); indices.Clear(); }
        public void Quad(Vector3 a, Vector3 b, Vector3 c, Vector3 d, Color color, int atlasTile = -1)
        {
            int n = positions.Count;
            positions.Add(a); positions.Add(b); positions.Add(c); positions.Add(d);
            for (int i = 0; i < 4; i++) colors.Add(color);
            float x = atlasTile < 0 ? 0 : (atlasTile % 2) * .5f;
            float y = atlasTile < 0 ? 0 : (atlasTile / 2) * .5f;
            float size = atlasTile < 0 ? 1 : .5f;
            uvs.Add(new Vector2(x, y)); uvs.Add(new Vector2(x+size, y));
            uvs.Add(new Vector2(x+size, y+size)); uvs.Add(new Vector2(x, y+size));
            indices.Add(n); indices.Add(n+1); indices.Add(n+2);
            indices.Add(n); indices.Add(n+2); indices.Add(n+3);
        }
        public void Upload()
        {
            mesh.Clear(); mesh.SetVertices(positions); mesh.SetColors(colors);
            mesh.SetUVs(0, uvs); mesh.SetTriangles(indices, 0); mesh.RecalculateBounds();
        }
        public void Dispose() { UnityEngine.Object.Destroy(mesh); UnityEngine.Object.Destroy(material); }
    }

    public IEnumerator Play(Kind kind, Func<Vector3> source, Func<Vector3> target,
        Action onRelease, Action onContact, int variant = 0)
    {
        CancelAll();
        int id = generation;
        if (!isActiveAndEnabled || source == null || target == null) yield break;
        Shader shader = Resources.Load<Shader>("EnemySignature/SignatureFilament");
        if (shader == null) { Debug.LogError("Enemy signature shader is missing."); yield break; }
        root = new GameObject("Enemy signature • " + kind);
        // World-space vertices; keep root independent of scaled/animated enemy transforms.
        glow = new Layer(root.transform, shader, "Luminous filaments", true);
        ink = new Layer(root.transform, shader, "Shadow and parchment", false);
        Shader sprite = Resources.Load<Shader>("EnemySignature/SignatureSprite");
        if (sprite == null) { CancelAll(); Debug.LogError("Enemy signature sprite shader is missing."); yield break; }
        flames = SpriteLayer(sprite, "Authored fire", false, "Fire_Single", 3, 3015);
        smoke = SpriteLayer(sprite, "Violet smoke volume", false, "Smoke", 0, 3012);
        bloom = SpriteLayer(sprite, "Soft magical radiance", true, null, 1, 3013);
        parchment = SpriteLayer(sprite, "Illuminated parchment", false, null, 2, 3014);
        if (kind == Kind.Archivist && variant % 2 == 0) launchArm = IronVaultArmProjectile.Find(transform);
        IsPlaying = true;
        try
        {
            float t = 0;
            while (t < ChargeDuration && id == generation)
            {
                Draw(kind, variant, 0, t / ChargeDuration, source(), target());
                yield return null;
                t += Time.deltaTime;
            }
            if (id != generation) yield break;
            onRelease?.Invoke();
            if (id != generation) yield break;
            if (launchArm != null && !launchArm.Release(target()))
            { launchArm.Dispose(); launchArm = null; }
            t = 0;
            while (t < TravelDuration && id == generation)
            {
                Draw(kind, variant, 1, t / TravelDuration, source(), target());
                yield return null;
                t += Time.deltaTime;
            }
            if (id != generation) yield break;
            // Upload the impact frame before notifying the combat owner.
            Draw(kind, variant, 2, 0, source(), target());
            onContact?.Invoke();
            if (id != generation) yield break;
            t = 0;
            while (t < ResidualDuration && id == generation)
            {
                Draw(kind, variant, 2, t / ResidualDuration, source(), target());
                yield return null;
                t += Time.deltaTime;
            }
        }
        finally { if (id == generation) CancelAll(); }
    }

    public void CancelAll()
    {
        // Also invalidates iterators being driven by another component's StartCoroutine.
        generation++;
        ClearApprovedFireball();
        surfaceLighting?.Clear();
        IsPlaying = false;
        launchArm?.Dispose(); launchArm = null;
        if (root != null) { root.SetActive(false); Destroy(root); }
        root = null;
        arcaneProjection = null;
        archiveShield?.Dispose(); archiveShield=null; glow?.Dispose(); ink?.Dispose(); flames?.Dispose(); smoke?.Dispose(); bloom?.Dispose(); parchment?.Dispose();
        glow = null; ink = null; flames = null; smoke = null; bloom = null; parchment = null;
    }
    void OnDisable() { CancelAll(); }
    void OnDestroy() { CancelAll(); }

    static Color Fade(Color color, float alpha) { color.a *= Mathf.Clamp01(alpha); return color; }
    static float Noise(float n) { return Mathf.Repeat(Mathf.Sin(n * 127.1f) * 43758.5453f, 1); }
    Vector3 Radial(float angle) { return right * Mathf.Cos(angle) + up * Mathf.Sin(angle); }
    void Draw(Kind kind, int variant, int phase, float p, Vector3 source, Vector3 target)
    {
        float rawPhaseProgress=p;
        if (phase == 2) p = EnemyImpactEnvelope20260921.Sample(p);
        archiveShield?.Clear(); glow.Clear(); ink.Clear(); flames.Clear(); smoke.Clear(); bloom.Clear(); parchment.Clear();
        forward = (target - source).sqrMagnitude > .001f ? (target - source).normalized : Vector3.forward;
        right = Vector3.Cross(Vector3.up, forward).normalized;
        if (right.sqrMagnitude < .1f) right = Vector3.right;
        up = Vector3.Cross(forward, right).normalized;
        var camera = Camera.main;
        view = camera != null ? camera.transform.forward : -forward;
        cameraRight = camera != null ? camera.transform.right : right;
        cameraUp = camera != null ? camera.transform.up : up;
        if(camera != null)
        {
            // Occupy ~70% viewport width at the middle of the combat corridor, including native portrait.
            float depth=Mathf.Max(1f,Vector3.Dot(Vector3.Lerp(source,target,.5f)-camera.transform.position,view));
            float height=camera.orthographic?camera.orthographicSize*2f:2f*depth*Mathf.Tan(camera.fieldOfView*Mathf.Deg2Rad*.5f);
            airWidth=Mathf.Clamp(height*camera.aspect*.35f,2.5f,5.2f);
            airHeight=Mathf.Clamp(height*.20f,2f,3.5f);
        }
        if (kind == Kind.Hound) OrganicHound(variant,phase,p,source,target);
        else if (kind == Kind.Archivist) {
            if(launchArm != null) launchArm.Update(phase,p,target);
            OrganicMachine(variant,phase,p,source,target,launchArm != null ? launchArm.Position : source);

        }
        else CrimsonSpectacle(variant,phase,p,source,target,rawPhaseProgress);
        if (!surfaceLighting) surfaceLighting = gameObject.AddComponent<SpellSceneLighting>();
        Color castColor = kind == Kind.Hound ? new Color(1f,.29f,.055f)
            : kind == Kind.Archivist ? ((variant&1)==0 ? new Color(.15f,.6f,1f) : new Color(1f,.5f,.12f))
            : new Color(1f,.055f,.19f);
        Vector3 lightPosition = phase == 0 ? source : phase == 2 ? target
            : kind == Kind.Hound && (variant&1)==0 ? target : Vector3.Lerp(source,target,p);
        float lightPower = phase == 0 ? p*p*1.9f : phase == 1 ? 2.9f
            : 5.6f*Mathf.Pow(1-p,2);
        surfaceLighting.Draw(lightPosition+Vector3.up*.35f,castColor,lightPower,6f);
        archiveShield?.Upload(); ink.Upload(); glow.Upload(); flames.Upload(); smoke.Upload(); bloom.Upload(); parchment.Upload();
    }
    void IronVaultArm(int phase, float p, Vector3 arm, Vector3 target)
    {
        Color blue = new Color(.16f, .64f, 1f, .9f);
        Color white = new Color(.82f, .96f, 1f, .95f);
        float energy = phase == 0 ? .25f + .75f * p : 1f;
        float radius = phase == 0 ? .18f + .08f * p : .20f;
        for (int ring = 0; ring < 3; ring++)
        {
            Vector3 center = arm + forward * ((ring - 1) * .12f);
            for (int j = 0; j <= 32; j++)
            {
                float a = j / 32f * Mathf.PI * 2 + p * 7 + ring;
                curve[j] = center + Radial(a) * radius;
            }
            Stroke(glow, 33, ring == 1 ? .023f : .012f, Fade(ring == 1 ? white : blue, energy));
        }
        Radiance(arm, .65f, blue, energy * .35f);
        if (phase == 1 || phase == 2)
        {
            Vector3 trail = phase == 1 ? -forward : forward;
            for (int k = 0; k < 7; k++)
            {
                Vector3 offset = Radial(k * 2.39996f) * .10f;
                Line(glow, arm + offset, arm + offset + trail * (.25f + Noise(k) * .4f),
                    .012f, Fade(blue, .65f));
            }
        }
        if (phase == 2 && p < .42f)
        {
            Burst(target, p / .42f, white, 22, .65f);
            Radiance(target, .95f, blue, (1 - p / .42f) * .65f);
        }
    }

    Vector3 AirPath(Vector3 s,Vector3 t,float u,float lane,float twist=0)
    {
        float arch=Mathf.Sin(Mathf.PI*u);
        return Vector3.Lerp(s,t,u)+cameraRight*lane*airWidth*arch
            +Vector3.up*(airHeight*arch*(.55f+.4f*Mathf.Abs(lane)))
            +cameraUp*Mathf.Sin(u*Mathf.PI*2+twist)*arch*.25f;
    }
    void AerialTheatre(Kind kind,bool second,int phase,float p,Vector3 s,Vector3 t)
    {
        float fade=phase==2?Mathf.Pow(1-p,1.3f):1;
        if(kind==Kind.Hound)
        {
            if(phase==0)
            {
                // Broad embers rise alongside the full-body blaze, without burying its silhouette.
                for(int i=0;i<26;i++)
                {
                    float side=i%2==0?-1:1;
                    float u=Mathf.Repeat(Noise(i)+p*.8f,1);
                    Vector3 c=s+cameraRight*side*(.45f+p*airWidth*.38f)*Mathf.Sin(u*Mathf.PI)
                        +Vector3.up*(u*airHeight*.7f-.45f)-forward*.25f;
                    Billboard(flames,c,.35f,.7f,(Noise(i+9)-.5f),Fade(i%3==0?Gold:Ember,p*.38f));
                    Spark(c,Vector3.up,.055f,Fade(Gold,p));
                }
                return;
            }
            int lanes=second?4:6;
            for(int k=0;k<lanes;k++)
            {
                float lane=(k/(float)(lanes-1)*2-1);
                float lead=phase==1?Mathf.Clamp01(p*1.23f-Noise(k)*.1f):1;
                // Full trailing flight paths remain in the central empty air after contact, then burn out.
                for(int j=0;j<49;j++)
                {
                    float u=j/48f*lead;
                    curve[j]=AirPath(s,t,u,lane,k)+cameraRight*Mathf.Sin(u*23+k)*.055f;
                }
                Stroke(glow,49,second?.045f:.033f,Fade(k%2==0?Gold:Ember,fade*.8f),true);
                for(int j=0;j<24;j++)
                {
                    float u=(j+.5f)/24f*lead;
                    Vector3 c=AirPath(s,t,u,lane,k);
                    float alpha=Mathf.Sin(u*Mathf.PI)*fade;
                    if(second)
                    {
                        Vector3 tangent=(AirPath(s,t,Mathf.Min(1,u+.01f),lane,k)-c).normalized;
                        Vector3 cross=j%2==0?cameraRight:cameraUp;
                        for(int v=0;v<=10;v++)
                        {float a=v/10f*Mathf.PI*2;curve[v]=c+tangent*Mathf.Cos(a)*.13f+cross*Mathf.Sin(a)*.075f;}
                        Stroke(glow,11,.032f,Fade(Gold,alpha));
                        if(j%2==0) Billboard(flames,c,.5f,.8f,lane*.7f,Fade(Ember,alpha*.48f));
                    }
                    else
                    {
                        Billboard(flames,c,.5f+.15f*Noise(j+k),.8f+.3f*Noise(j+k+5),lane*.8f,Fade(k%2==0?Ember:Gold,alpha*.45f));
                        if(j%3==0) Billboard(smoke,c,.95f,1.1f,j*.8f,new Color(.09f,.015f,.17f,alpha*.16f),(j+k)%4);
                    }
                    if(j%3==0) Radiance(c,1.2f,Ember,alpha*.20f);
                }
                if(phase==1)
                {
                    Vector3 head=AirPath(s,t,lead,lane,k);
                    Radiance(head,.85f,Gold,.65f);
                    Billboard(flames,head,.7f,1.1f,lane,Fade(White,.65f));
                }
            }
            if(phase==2)
                for(int i=0;i<28;i++)
                {
                    Vector3 c=Vector3.Lerp(s,t,.75f)+cameraRight*(Noise(i)-.5f)*airWidth*1.8f
                        +Vector3.up*(Noise(i+7)*airHeight*(.5f+p)) + forward*p*.5f;
                    Billboard(flames,c,.45f,.85f,i*.3f,Fade(Ember,fade*.45f));
                    Spark(c,cameraUp,.055f,Fade(Gold,fade));
                }
            return;
        }
        if(kind==Kind.Archivist)
        {
            int count=phase==0?40:second?96:64;
            for(int i=0;i<count;i++)
            {
                float side=i%2==0?-1:1;
                float n=Noise(i+10);
                float u=phase==0?.04f:phase==1?Mathf.Clamp01(p*1.25f-n*.6f):.25f+n*.7f;
                float lane=side*(.45f+.6f*Noise(i+19));
                Vector3 c=phase==0?s+cameraRight*lane*airWidth*.62f*p
                    +Vector3.up*(Noise(i+24)-.25f)*airHeight*.8f
                    :AirPath(s,t,u,lane)+cameraUp*Mathf.Sin(i*2.4f+p*7)*.25f;
                if(phase==2)c+=cameraRight*side*p*.45f+Vector3.up*p*(n-.5f);
                Page(c,.105f+Noise(i+41)*.055f,side*.3f+Mathf.Sin(i+p*4)*.4f,phase==0?p*.85f:fade*.88f,i);
                if(i%3==0) Radiance(c,.6f,Gold,fade*.23f);
            }
            if(phase>0)
            {
                for(int k=0;k<6;k++)
                {
                    float lane=(k/5f*2-1);
                    for(int j=0;j<49;j++)
                    {float u=j/48f*(phase==1?Mathf.Min(1,p*1.2f):1);curve[j]=AirPath(s,t,u,lane)+cameraRight*Mathf.Sin(u*15+k)*.12f;}
                    Stroke(glow,49,.027f,Fade(k%2==0?Gold:White,fade*.58f),true);
                }
                if(!second)
                {
                    Vector3 c=Vector3.Lerp(s,t,phase==1?Mathf.SmoothStep(0,1,p):1);
                    float radius=phase==1?Mathf.Lerp(1.25f,1.75f,p):1.75f+p*.3f;
                    Seal(c,radius,(phase==1?1-p:0)*.35f,fade*.8f);
                    Radiance(c,radius*2.4f,Gold,fade*.22f);
                }
            }
            return;
        }
        // Matriarch's thread canopy deliberately spans the empty air between both fighters.
        Vector3 middle=Vector3.Lerp(s,t,.48f)+Vector3.up*airHeight*.68f;
        float grow=phase==0?p*.65f:1;
        if(!second)
        {
            for(int layer=0;layer<3;layer++)
            {
                Vector3 center=middle+forward*(layer-1)*.7f;
                float radius=airWidth*(.78f-layer*.13f)*grow;
                for(int j=0;j<49;j++)
                {
                    float a=j/48f*Mathf.PI*2;
                    float petal=.73f+.26f*Mathf.Cos(a*6+layer*Mathf.PI);
                    curve[j]=center+cameraRight*Mathf.Cos(a)*radius*petal
                        +cameraUp*Mathf.Sin(a)*radius*.68f*petal;
                }
                Stroke(glow,49,layer==0?.052f:.031f,Fade(layer==0?CrimsonGold:CrimsonRose,fade*.8f));
                for(int k=0;k<12;k++)
                {
                    float a=k*Mathf.PI/6;
                    Vector3 outer=center+cameraRight*Mathf.Cos(a)*radius+cameraUp*Mathf.Sin(a)*radius*.68f;
                    Vector3 next=center+cameraRight*Mathf.Cos(a+2.094f)*radius+cameraUp*Mathf.Sin(a+2.094f)*radius*.68f;
                    Line(glow,outer,next,.021f,Fade(CrimsonRose,fade*.6f));
                    Radiance(outer,.55f,k%3==0?CrimsonGold:CrimsonRose,fade*.45f);
                    if(k%2==0) Billboard(bloom,Vector3.Lerp(center,outer,.55f),.7f,radius,-a,Fade(CrimsonRose,fade*.20f));
                }
            }
            if(phase>0)
                for(int k=0;k<12;k++)
                {
                    float lane=k/11f*2-1;
                    for(int j=0;j<49;j++)
                    {float u=j/48f;curve[j]=AirPath(s,t,u,lane)+cameraUp*Mathf.Sin(u*12+k+p*6)*.12f;}
                    Stroke(glow,49,k%3==0?.033f:.016f,Fade(k%3==0?CrimsonGold:CrimsonRose,fade*.65f));
                }
        }
        else
        {
            int columns=12,rows=4;
            for(int row=0;row<rows;row++) for(int col=0;col<columns;col++)
            {
                int i=row*columns+col;
                float x=(col/(float)(columns-1)*2-1)*airWidth*grow;
                Vector3 top=middle+cameraRight*x+cameraUp*(.2f+row*.4f)+forward*(row-1.5f)*.7f;
                if(phase==0 || (phase==1&&p<.6f))
                {
                    Spark(top,cameraUp,.09f,Fade(i%3==0?CrimsonGold:CrimsonRose,phase==0?p:.8f));
                    Radiance(top,.5f,CrimsonRose,.40f);
                    if(col>0) Line(glow,top-cameraRight*(airWidth*2/(columns-1)*grow),top,.018f,Fade(CrimsonRose,.6f));
                    if(row>0) Line(glow,top-cameraUp*.4f-forward*.7f,top,.012f,Fade(CrimsonGold,.42f));
                }
                if(phase>0)
                {
                    float fall=phase==1?Mathf.Clamp01((p-.15f-Noise(i)*.12f)/(.85f-Noise(i)*.12f)):1;
                    Vector3 landing=t+cameraRight*x*.4f+forward*(Noise(i+6)-.5f)*1.5f;
                    Vector3 c=Vector3.Lerp(top,landing,fall);
                    Vector3 d=(landing-top).normalized;
                    if(phase==2)c+=cameraRight*(Noise(i)-.5f)*p+cameraUp*p*Noise(i+3);
                    Line(glow,c-d*.7f,c,.043f,Fade(i%3==0?CrimsonGold:CrimsonRose,fade*.85f));
                    Radiance(c,.48f,i%3==0?CrimsonGold:CrimsonRose,fade*.55f);
                    Spark(c,d,.065f,Fade(CrimsonPearl,fade));
                }
            }
        }
        for(int i=0;i<16;i++)
        {
            Vector3 c=middle+cameraRight*(Noise(i)-.5f)*airWidth*1.8f+cameraUp*(Noise(i+20)-.5f)*airHeight;
            Billboard(smoke,c,1.5f,1.4f,i,new Color(.13f,.02f,.23f,fade*(phase==0?p:1)*.10f),i%4);
            Radiance(c,1.2f,CrimsonRose,fade*.10f);
        }
    }
    Layer SpriteLayer(Shader shader, string name, bool additive, string texture, int shape, int queue)
    {
        var layer = new Layer(root.transform, shader, name, additive);
        layer.material.renderQueue = queue;
        layer.material.SetFloat("_Shape", shape);
        if (texture != null)
            layer.material.mainTexture = Resources.Load<Texture2D>("Effects/HellHound/Texture/" + texture);
        return layer;
    }
    void Billboard(Layer layer, Vector3 c, float width, float height, float angle, Color color, int tile = -1)
    {
        Vector3 x=(cameraRight*Mathf.Cos(angle)+cameraUp*Mathf.Sin(angle))*width*.5f;
        Vector3 y=(-cameraRight*Mathf.Sin(angle)+cameraUp*Mathf.Cos(angle))*height*.5f;
        layer.Quad(c-x-y,c+x-y,c+x+y,c-x+y,color,tile);
    }
    void Radiance(Vector3 c, float size, Color color, float alpha)
    {
        Billboard(bloom,c,size,size,0,Fade(color,alpha));
    }
    void Volume(Kind kind, int variant, int phase, float p, Vector3 s, Vector3 t)
    {
        bool second=variant%2!=0;
        float fade=phase==2?Mathf.Pow(1-p,1.4f):1;
        if(kind==Kind.Hound)
        {
            if(phase==0)
            {
                Vector3 horizontal = Vector3.ProjectOnPlane(forward, Vector3.up).normalized;
                Vector3 body=s-horizontal*.38f-Vector3.up*.75f;
                Radiance(body,2.6f,Ember,.28f*p);
                for(int i=0;i<16;i++)
                {
                    float u=Mathf.Repeat(p*1.8f+Noise(i),1);
                    Vector3 c=body+right*(Noise(i+25)-.5f)*.9f+forward*(Noise(i+35)-.5f)*.8f
                        +Vector3.up*(u*.9f-.3f);
                    float a=(.16f+.35f*p)*Mathf.Sin(u*Mathf.PI);
                    Billboard(smoke,c,.52f,.6f,Noise(i)*6,new Color(.10f,.015f,.19f,a*.7f),i%4);
                    Billboard(flames,c,.34f+.2f*p,.68f+.48f*p,(Noise(i+6)-.5f)*.5f,
                        Fade(i%3==0?Gold:Ember,a));
                }
                Radiance(s,.65f,Gold,p*.55f);
            }
            else if(phase==1 && !second)
            {
                Vector3 head=Vector3.Lerp(s,t,p);
                Radiance(head,1.8f,Ember,.7f);
                Radiance(head,.58f,White,.85f);
                for(int i=0;i<18;i++)
                {
                    float u=i/17f;
                    Vector3 c=head-forward*u*Mathf.Min(1.65f,Vector3.Distance(s,head)+.1f)
                        +right*Mathf.Sin(i*2.4f+p*16)*.08f;
                    Billboard(smoke,c,.65f+u*.45f,.65f+u*.4f,i*.73f,new Color(.10f,.01f,.18f,(1-u)*.28f),i%4);
                    Billboard(flames,c,.40f+u*.2f,.65f+u*.2f,i*.45f+p*3,
                        Fade(i%4==0?Gold:Ember,(1-u)*.65f));
                }
            }
            else if(phase==1)
            {
                for(int k=0;k<2;k++) for(int i=0;i<12;i++)
                {
                    float u=(i+.5f)/12f*p;
                    float side=k==0?-1:1;
                    Vector3 c=Vector3.Lerp(s,t,u)+right*side*Mathf.Sin(u*Mathf.PI)*.7f;
                    Billboard(flames,c,.27f,.46f,side*u*2,Fade(Gold,.48f));
                    Radiance(c,.65f,Ember,.22f);
                }
                Radiance(t,1.6f,Gold,p*.27f);
            }
            else
            {
                Radiance(t,2.4f,Ember,fade*.65f);
                Radiance(t,.75f+p*.4f,White,fade*.6f);
                for(int i=0;i<16;i++)
                {
                    Vector3 d=Radial(i*2.39996f);
                    Vector3 c=t+d*(.1f+p*.9f)+Vector3.up*p*.3f;
                    Billboard(smoke,c,.7f+p*.7f,.75f+p*.6f,i*.6f,new Color(.12f,.018f,.20f,fade*.23f),i%4);
                    Billboard(flames,c,.42f,.75f,i*.37f+p*2,Fade(i%3==0?Gold:Ember,fade*.48f));
                }
            }
        }
        else if(kind==Kind.Archivist)
        {
            Vector3 c=phase==0?s:phase==1?Vector3.Lerp(s,t,Mathf.SmoothStep(0,1,p)):t;
            Radiance(c,phase==0?1.7f:2f,Gold,(phase==0?p*.24f:.30f)*fade);
            if(!second && phase>0)
            {
                float radius=phase==1?.47f+.35f*p:.82f+p*.25f;
                // Offset dark-gold backing and parallel edges make the stamp a thick object.
                for(int k=0;k<4;k++)
                {
                    Vector3 a=c+Radial(k*Mathf.PI*.5f)*radius;
                    Vector3 b=c+Radial((k+1)*Mathf.PI*.5f)*radius;
                    Vector3 z=forward*.10f;
                    parchment.Quad(a,b,b+z,a+z,new Color(.62f,.27f,.045f,.8f*fade));
                    Line(glow,a+z,b+z,.035f,Fade(Gold,fade*.8f));
                }
            }
            for(int i=0;i<20;i++)
            {
                float a=i*2.39996f+p*2;
                float r=phase==2?.15f+p*1.1f:.3f+Noise(i)*.5f;
                Vector3 particle=c+Radial(a)*r+forward*(Noise(i+50)-.5f)*.5f;
                Radiance(particle,.12f+.10f*Noise(i+15),Gold,(phase==0?p:.7f)*fade);
            }
        }
        else
        {
            if(phase==0)
            {
                Radiance(s,1.7f,CrimsonRose,p*.28f);
                for(int k=0;k<3;k++)
                {
                    Vector3 spool=s+Radial(Mathf.PI*.5f+k*Mathf.PI*2/3)*.48f;
                    Radiance(spool,.6f,CrimsonGold,p*.6f);
                }
            }
            Vector3 c=phase==0?s:phase==1?Vector3.Lerp(s,t,Mathf.Clamp01(p*1.6f)):t;
            if(second && phase<2) c=Vector3.Lerp(s,t,phase==0?0:Mathf.Clamp01(p*2.7f))+Vector3.up*1.5f;
            float aFade=phase==0?p*.25f:fade*.35f;
            for(int i=0;i<7;i++)
            {
                Vector3 cloud=c+Radial(i*2.39996f+p*1.5f)*(.25f+.12f*Noise(i));
                Billboard(smoke,cloud,1.15f,1.15f,i*.6f,new Color(.14f,.025f,.27f,aFade*.55f),i%4);
                Radiance(cloud,1.35f,i%3==0?CrimsonGold:CrimsonRose,aFade*.35f);
            }
            if(!second && phase>0)
            {
                float radius=phase==1?Mathf.Lerp(.88f,.3f,p):.3f+p*.7f;
                for(int i=0;i<6;i++)
                {
                    float a=i*Mathf.PI/3;
                    Billboard(bloom,c+Radial(a)*radius*.45f,.28f,radius*1.7f,-a+Mathf.PI*.5f,
                        Fade(i%2==0?CrimsonGold:CrimsonRose,fade*.55f));
                }
            }
            if(second && phase==1)
            {
                for(int i=0;i<18;i++)
                {
                    Vector3 top=StarPoint(Vector3.Lerp(s,t,Mathf.Clamp01(p*2.7f)),i);
                    float fall=Mathf.SmoothStep(0,1,Mathf.Clamp01((p-.32f-Noise(i)*.12f)/(.68f-Noise(i)*.12f)));
                    Vector3 point=Vector3.Lerp(top,t+right*(Noise(i+120)-.5f)*.45f,fall);
                    Radiance(point,.32f,i%3==0?CrimsonGold:CrimsonRose,.65f);
                }
            }
            if(phase==2) Radiance(t,2.1f,CrimsonRose,fade*.55f);
        }
    }
    void Line(Layer layer, Vector3 a, Vector3 b, float width, Color color)
    {
        Vector3 side = Vector3.Cross(b-a, view).normalized * width * .5f;
        if (side.sqrMagnitude < 1e-9f) side = right * width * .5f;
        layer.Quad(a-side, b-side, b+side, a+side, color);
    }
    void Stroke(Layer layer, int count, float width, Color color, bool taper = false)
    {
        for (int i = 1; i < count; i++)
            Line(layer, curve[i-1], curve[i], width * (taper ? Mathf.Sin(Mathf.PI * (i-.5f)/(count-1)) : 1), color);
    }
    void Spark(Vector3 c, Vector3 direction, float length, Color color)
    {
        Line(glow, c-direction*length, c+direction*length, .022f, color);
        Line(glow, c-right*length*.32f, c+right*length*.32f, .016f, color);
    }
    void Burst(Vector3 c, float p, Color color, int count, float reach)
    {
        float fade = Mathf.Pow(1-p, 1.6f);
        for (int i = 0; i < count; i++)
        {
            float a = i * 2.39996f;
            Vector3 d = (Radial(a) + forward * (Noise(i+3)-.5f)*.8f).normalized;
            float r = .12f + Mathf.Sqrt(p) * reach * (.5f + Noise(i+12)*.5f);
            Spark(c+d*r, d, (.04f+.12f*(1-p)), Fade(color, fade));
        }
    }

    void Hound(int phase, float p, Vector3 s, Vector3 t)
    {
        if (phase == 0)
        {
            // Irregular tongues run from the flank to the muzzle, leaving the face readable.
            for (int k = 0; k < 15; k++)
            {
                float a = k*2.39996f;
                for (int j = 0; j < 25; j++)
                {
                    float u = j/24f;
                    float r = (.17f + .30f*Mathf.Sin(u*Mathf.PI))*(.5f+.5f*p);
                    curve[j] = s-forward*(1-u)*1.15f + Radial(a+u*3+p*8)*r
                        + Vector3.up*Mathf.Sin(u*8+p*12+k)*.06f;
                }
                Stroke(ink, 25, .13f, new Color(.09f,.012f,.15f,.48f), true);
                Stroke(glow, 25, .032f, Fade(k%3==0 ? Gold : Ember, .25f+.7f*p), true);
            }
        }
        else if (phase == 1)
        {
            Vector3 head = Vector3.Lerp(s,t,p);
            for (int k = 0; k < 11; k++)
            {
                for (int j = 0; j < 25; j++)
                {
                    float u=j/24f;
                    float r = Mathf.Sin(u*Mathf.PI)*(.12f+.12f*Noise(k));
                    curve[j]=head-forward*(1-u)*Mathf.Min(1.4f,Vector3.Distance(s,head)+.12f)
                        + Radial(k*2.39996f+u*7-p*15)*r;
                }
                Stroke(ink,25,.18f,new Color(.035f,.008f,.065f,.8f),true);
                Stroke(glow,25,.048f,k%3==0?Gold:Ember,true);
            }
            Burst(head,.07f,Gold,14,.35f);
        }
        else
        {
            Burst(t,p,Ember,42,1.15f);
            for(int k=0;k<9;k++)
            {
                for(int j=0;j<17;j++)
                {
                    float u=j/16f;
                    curve[j]=t+Radial(k*2.39996f+Mathf.Sin(u*9+k)*.13f)*u*(.5f+p*.8f)
                        + forward*Mathf.Sin(u*5)*.1f;
                }
                Stroke(ink,17,.13f,Fade(new Color(.06f,0,.08f,.7f),1-p),true);
                Stroke(glow,17,.055f,Fade(Gold,1-p),true);
            }
        }
    }

    void Page(Vector3 c, float size, float angle, float alpha, int seed)
    {
        size *= 1.25f;
        Vector3 x=Radial(angle)*size, y=Radial(angle+Mathf.PI*.5f)*size*1.45f;
        // Raised curled leaf face plus a narrow gold edge gives a tangible page silhouette.
        parchment.Quad(c-x-y,c+x-y,c+x+y-view*size*.18f,c-x+y-view*size*.18f,
            new Color(1f,.69f,.28f,.93f*alpha));
        bloom.Quad(c-x*2-y*1.6f,c+x*2-y*1.6f,c+x*2+y*1.6f,c-x*2+y*1.6f,
            new Color(1f,.42f,.06f,.20f*alpha));
        Line(glow,c-x-y,c+x-y,.018f,Fade(Gold,alpha));
        Line(glow,c-x+y,c+x+y,.018f,Fade(Gold,alpha));
        for(int i=0;i<5;i++)
        {
            Vector3 row=c+y*(.65f-i*.3f);
            // Broken typeset lines read as a page without inventing pseudo-Chinese characters.
            Line(glow,row-x*.7f,row+x*(.25f+.4f*Noise(seed+i)),.012f,Fade(White,alpha*.8f));
        }
    }
    void Seal(Vector3 c, float radius, float rotation, float alpha)
    {
        for(int tier=0;tier<3;tier++)
        {
            int sides=tier==0?4:8;
            for(int j=0;j<=sides;j++) curve[j]=c+Radial(rotation+j*Mathf.PI*2/sides)*radius*(1-tier*.17f);
            Stroke(glow,sides+1,tier==0?.035f:.016f,Fade(Gold,alpha));
        }
        // A visible central archive-lock motif with crossbars, not an empty circle.
        for(int j=-1;j<=1;j++)
            Line(glow,c-right*radius*.32f+up*radius*j*.25f,c+right*radius*.32f+up*radius*j*.25f,.045f,Fade(White,alpha));
        for(int j=-1;j<=1;j+=2)
            Line(glow,c+right*radius*j*.26f-up*radius*.45f,c+right*radius*j*.26f+up*radius*.45f,.04f,Fade(Gold,alpha));
    }
    void Archivist(int phase,float p,Vector3 s,Vector3 t)
    {
        if(phase==0)
        {
            for(int i=0;i<18;i++)
            {
                float a=i*2.39996f+p*5;
                Vector3 c=s+Radial(a)*(.47f+.15f*Mathf.Sin(i+p*5))+forward*Mathf.Sin(a)*.2f;
                Page(c,.075f,a*.25f,.25f+.7f*p,i);
            }
            Seal(s-forward*.08f,.25f+p*.24f,-p*1.4f,p*.8f);
        }
        else if(phase==1)
        {
            Vector3 c=Vector3.Lerp(s,t,Mathf.SmoothStep(0,1,p));
            Seal(c,.47f+.35f*p,(1-p)*2,.95f);
            for(int i=0;i<10;i++)
            {
                float u=Mathf.Clamp01(p-i*.045f);
                Vector3 page=Vector3.Lerp(s,t,u)+Radial(i*2.39996f+p*4)*Mathf.Sin(p*Mathf.PI)*.35f;
                Page(page,.065f,i+p*7,.7f,i);
            }
            for(int k=0;k<4;k++)
            {
                for(int j=0;j<25;j++)
                { float u=j/24f*p; curve[j]=Vector3.Lerp(s,t,u)+Radial(k*Mathf.PI*.5f+u*9)*Mathf.Sin(u*Mathf.PI)*.18f; }
                Stroke(glow,25,.018f,Fade(Gold,.7f));
            }
        }
        else
        {
            Seal(t,.82f+p*.25f,0,Mathf.Pow(1-p,2));
            Burst(t,p,White,32,1.25f);
            for(int i=0;i<16;i++)
            { float a=i*2.39996f; Page(t+Radial(a)*(.2f+p*(.6f+Noise(i)))-Vector3.up*p*p*.3f,.065f,a+p*6,1-p,i); }
        }
    }

    void Matriarch(int phase,float p,Vector3 s,Vector3 t)
    {
        if(phase==0)
        {
            for(int k=0;k<3;k++)
            {
                Vector3 spool=s+Radial(Mathf.PI*.5f+k*Mathf.PI*2/3)*.48f;
                for(int strand=0;strand<3;strand++)
                {
                    for(int j=0;j<33;j++)
                    { float u=j/32f; curve[j]=Vector3.Lerp(spool,s,u)+Radial(u*12+p*8+strand*2.1f)*Mathf.Sin(u*Mathf.PI)*(.13f+.2f*p); }
                    Stroke(glow,33,strand==0?.025f:.012f,Fade(strand==0?CrimsonGold:CrimsonRose,.3f+p*.7f));
                }
                Spark(spool,up,.09f+.04f*Mathf.Sin(p*15),CrimsonGold);
            }
        }
        else if(phase==1)
        {
            for(int k=0;k<9;k++)
            {
                Vector3 spool=s+Radial(Mathf.PI*.5f+(k%3)*Mathf.PI*2/3)*.48f;
                for(int j=0;j<49;j++)
                {
                    float u=j/48f;
                    Vector3 end=Vector3.Lerp(s,t,Mathf.Clamp01(p*1.6f));
                    float envelope=Mathf.Sin(u*Mathf.PI)*(.12f+.22f*(1-p));
                    curve[j]=Vector3.Lerp(spool,end,u)+Radial(k*2.39996f+u*13-p*9)*envelope;
                }
                Stroke(glow,49,k%3==0?.023f:.01f,k%3==0?CrimsonGold:CrimsonRose);
            }
            if(p>.25f) Weave(t,(p-.25f)/.75f,1);
        }
        else
        {
            Weave(t,1,.85f*Mathf.Pow(1-p,2));
            Burst(t,p,CrimsonRose,42,1.3f);
            // Fine broken threads fly out with gold knots at the ends.
            for(int k=0;k<18;k++)
            {
                Vector3 d=Radial(k*2.39996f);
                Vector3 c=t+d*(.25f+p*1.1f);
                Line(glow,c-d*.08f+up*Mathf.Sin(k+p*9)*.06f,c+d*.10f,.013f,Fade(CrimsonGold,1-p));
                Spark(c,d,.025f,Fade(CrimsonPearl,1-p));
            }
        }
    }
    void Chain(Vector3 a,Vector3 b,float p,float alpha)
    {
        const int links=18;
        for(int k=0;k<links;k++)
        {
            float u=(k+.5f)/links;
            Vector3 c=Vector3.Lerp(a,b,u)+Vector3.up*Mathf.Sin(u*Mathf.PI)*(.3f+.3f*p);
            Vector3 axis=(b-a).normalized;
            Vector3 cross=k%2==0?up:right;
            for(int j=0;j<=12;j++)
            {
                float angle=j/12f*Mathf.PI*2;
                curve[j]=c+axis*Mathf.Cos(angle)*.07f+cross*Mathf.Sin(angle)*.035f;
            }
            Stroke(ink,13,.05f,Fade(new Color(.04f,.015f,.055f,.8f),alpha));
            Stroke(glow,13,.018f,Fade(k%3==0?Ember:Gold,alpha));
        }
    }
    void ChainFire(int phase,float p,Vector3 s,Vector3 t)
    {
        Vector3 collar=s-forward*.35f;
        if(phase==0)
        {
            for(int k=0;k<2;k++)
            {
                float side=k==0?-1:1;
                Chain(collar,collar+right*side*(.35f+.35f*p)+Vector3.up*.3f,p,p);
            }
            for(int i=0;i<18;i++)
                Spark(collar+Radial(i*2.39996f+p*6)*(.22f+.1f*p),up,.035f,Fade(Ember,p));
        }
        else if(phase==1)
        {
            for(int k=0;k<2;k++)
            {
                float side=k==0?-1:1;
                Vector3 end=Vector3.Lerp(collar,t,p)+right*side*Mathf.Sin(p*Mathf.PI)*.75f;
                Chain(collar,end,p,1);
            }
            // Upright segmented collar at the live victim anchor closes from two sides.
            for(int k=0;k<2;k++)
            {
                for(int j=0;j<25;j++)
                {
                    float a=(k*Mathf.PI)+(j/24f)*Mathf.PI*p;
                    curve[j]=t+Radial(a)*Mathf.Lerp(.85f,.35f,p);
                }
                Stroke(glow,25,.05f,Gold);
            }
        }
        else
        {
            Burst(t,p,Gold,34,1.1f);
            for(int i=0;i<12;i++)
            {
                float a=i*Mathf.PI/6;
                Vector3 c=t+Radial(a)*(.35f+p*.65f);
                for(int j=0;j<=8;j++)
                { float b=j/8f*Mathf.PI*2; curve[j]=c+Radial(a+b)*.07f+up*p*p*.1f; }
                Stroke(glow,9,.027f,Fade(Ember,1-p));
            }
        }
    }
    void PagePursuit(int phase,float p,Vector3 s,Vector3 t)
    {
        if(phase==0)
        {
            // Two opening fans rather than the first spell's orbiting seal.
            for(int i=0;i<20;i++)
            {
                float side=i<10?-1:1;
                float u=(i%10)/9f;
                Vector3 c=s+right*side*(.15f+u*(.35f+.25f*p))+up*(.4f-u*.7f);
                Page(c,.09f,side*(.1f+u*.8f)*p,.3f+.7f*p,i);
            }
        }
        else if(phase==1)
        {
            for(int i=0;i<28;i++)
            {
                float u=Mathf.Clamp01(p*1.4f-i*.025f);
                float a=i*2.39996f+p*10;
                Vector3 c=Vector3.Lerp(s,t,u)+Radial(a)*Mathf.Sin(u*Mathf.PI)*(.25f+.14f*Noise(i));
                Page(c,.06f+.025f*Noise(i+5),a,.85f,i);
            }
            for(int k=0;k<3;k++)
            {
                for(int j=0;j<49;j++)
                {
                    float u=j/48f*p;
                    curve[j]=Vector3.Lerp(s,t,u)+Radial(k*2.094f+u*12)*Mathf.Sin(u*Mathf.PI)*.3f;
                }
                Stroke(glow,49,.015f,Fade(White,.5f));
            }
        }
        else
        {
            Burst(t,p,Gold,30,1f);
            for(int i=0;i<25;i++)
            {
                float a=i*2.39996f;
                Vector3 c=t+Radial(a)*(.1f+p*(.6f+Noise(i)*.5f))+forward*p*.15f;
                Page(c,.065f*(1-p*.5f),a+p*(Noise(i)*8-4),1-p,i);
            }
        }
    }
    Vector3 StarPoint(Vector3 c,int i)
    {
        return c+right*(Noise(i+55)-.5f)*1.4f+forward*(Noise(i+75)-.5f)*.65f
            +Vector3.up*(1.35f+Noise(i+95)*.55f);
    }
    void StarRain(int phase,float p,Vector3 s,Vector3 t)
    {
        if(phase==0)
        {
            // The constellation forms above the caster; source-to-constellation threads
            // explain the origin before the canopy moves across to the victim.
            for(int i=0;i<12;i++)
            {
                Vector3 c=StarPoint(s,i);
                Spark(c,up,.04f+.025f*p,Fade(i%3==0?CrimsonGold:CrimsonRose,p));
                if(i>0) Line(glow,StarPoint(s,i-1),c,.012f,Fade(CrimsonRose,p*.65f));
                if(i%4==0) Line(glow,s+right*((i/4)-1)*.3f,c,.012f,Fade(CrimsonGold,p*.6f));
            }
        }
        else if(phase==1)
        {
            float move=Mathf.Clamp01(p*2.7f);
            Vector3 canopy=Vector3.Lerp(s,t,Mathf.SmoothStep(0,1,move));
            for(int i=0;i<18;i++)
            {
                Vector3 top=StarPoint(canopy,i);
                float fall=Mathf.SmoothStep(0,1,Mathf.Clamp01((p-.32f-Noise(i)*.12f)/(.68f-Noise(i)*.12f)));
                Vector3 landing=t+right*(Noise(i+120)-.5f)*.45f+forward*(Noise(i+140)-.5f)*.25f;
                Vector3 c=Vector3.Lerp(top,landing,fall);
                Vector3 d=(landing-top).normalized;
                Line(glow,c-d*(.16f+.25f*fall),c,.027f,i%3==0?CrimsonGold:CrimsonRose);
                Spark(c,d,.035f,CrimsonPearl);
                if(p<.45f&&i>0) Line(glow,StarPoint(canopy,i-1),top,.012f,Fade(CrimsonRose,1-p/.45f));
            }
        }
        else
        {
            Burst(t,p,CrimsonPearl,46,1.15f);
            for(int k=0;k<8;k++)
            {
                float a=k*Mathf.PI*.25f;
                Vector3 d=Radial(a);
                Line(glow,t+d*(.1f+p*.5f),t+d*(.4f+p*.7f),.023f,Fade(k%2==0?CrimsonGold:CrimsonRose,(1-p)*(1-p)));
            }
        }
    }
    void Weave(Vector3 c,float p,float alpha)
    {
        float radius=Mathf.Lerp(.92f,.24f,p*p);
        for(int tier=0;tier<3;tier++)
        {
            for(int j=0;j<49;j++)
            {
                float a=j/48f*Mathf.PI*2;
                float r=radius*(.66f+.28f*Mathf.Cos(a*6+tier*Mathf.PI))*(1-tier*.14f);
                curve[j]=c+Radial(a+tier*.25f)*r+forward*tier*.05f;
            }
            Stroke(glow,49,tier==0?.025f:.012f,Fade(tier==0?Gold:Violet,alpha));
        }
        for(int i=0;i<12;i++)
        {
            float a=i*Mathf.PI/6;
            Line(glow,c+Radial(a)*radius*.82f,c+Radial(a+Mathf.PI*.66f)*radius*.82f,.012f,Fade(Violet,alpha*.65f));
        }
    }
}
