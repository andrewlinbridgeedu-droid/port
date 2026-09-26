using System.Collections;
using UnityEngine;

/// Presentation-only encore fire and bell beat; never changes combat timing or actor roots.
public sealed class EncoreBellPresentation : MonoBehaviour
{
    const float ChargeSeconds = 3f;
    const float BellSeconds = .72f;
    readonly Color fire = new Color(.22f,1f,.06f,1f);
    readonly Color gold = new Color(1f,.68f,.12f,1f);
    GameObject flameRoot, bellRoot;
    ParticleSystem flames;
    Material flameMaterial;
    Material bellMaterial;
    readonly System.Collections.Generic.List<ParticleSystem> flameLayers = new System.Collections.Generic.List<ParticleSystem>();
    readonly System.Collections.Generic.List<Material> flameMaterials = new System.Collections.Generic.List<Material>();
    Coroutine flameRoutine, bellRoutine;
    AudioSource audioSource;
    AudioClip bellClip;
    bool slowed;
    readonly System.Collections.Generic.List<Renderer> bodyRenderers = new System.Collections.Generic.List<Renderer>();
    readonly System.Collections.Generic.List<Material[]> bodyOriginals = new System.Collections.Generic.List<Material[]>();
    readonly System.Collections.Generic.List<Material[]> bodyCopies = new System.Collections.Generic.List<Material[]>();

    void PrepareBody(Transform visual)
    {
        foreach (var renderer in visual.GetComponentsInChildren<Renderer>(true))
        {
            if (!renderer.enabled || !renderer.gameObject.activeInHierarchy || (!(renderer is SkinnedMeshRenderer) && !(renderer is MeshRenderer))) continue;
            var originals = renderer.sharedMaterials;
            var copies = new Material[originals.Length];
            for (var i = 0; i < originals.Length; i++)
            {
                if (originals[i] == null) continue;
                copies[i] = new Material(originals[i]);
                copies[i].EnableKeyword("_EMISSION");
            }
            bodyRenderers.Add(renderer); bodyOriginals.Add(originals); bodyCopies.Add(copies);
            renderer.sharedMaterials = copies;
        }
    }

    void RestoreBody()
    {
        for (var i = 0; i < bodyRenderers.Count; i++)
        {
            if (bodyRenderers[i] != null) bodyRenderers[i].sharedMaterials = bodyOriginals[i];
            foreach (var material in bodyCopies[i]) if (material != null) Destroy(material);
        }
        bodyRenderers.Clear(); bodyOriginals.Clear(); bodyCopies.Clear();
    }

    void TintBody(float intensity)
    {
        foreach (var copies in bodyCopies)
            foreach (var material in copies)
            {
                if (material == null) continue;
                var tint = Color.Lerp(Color.white, new Color(.18f, 1f, .08f), .55f + intensity * .26f);
                if (material.HasProperty("_Color")) material.SetColor("_Color", tint);
                if (material.HasProperty("_BaseColor")) material.SetColor("_BaseColor", tint);
                if (material.HasProperty("_EmissionColor"))
                    material.SetColor("_EmissionColor", new Color(.005f, .048f, .002f) * (.5f + intensity));
            }
    }

    public void Charge(EnemyHandle handle)
    {
        ClearCharge(); ClearBell(); slowed = false;
        if (handle == null || handle.VisualRoot == null) return;
        PrepareBody(handle.VisualRoot);
        flameRoot = CreateFlames(handle.VisualRoot);
        flameRoutine = StartCoroutine(RampFlames());
    }

    public void Bell(EnemyHandle handle)
    {
        slowed = true; SetFlameIntensity(.58f); ClearBell();
        if (handle == null || handle.VisualRoot == null) return;
        bellRoot = CreateRipple(handle.VisualRoot);
        bellRoutine = StartCoroutine(PlayRipple());
        EnsureAudio().PlayOneShot(GetBellClip());
    }

    public void Release() { Clear(); }

    public void Clear()
    {
        if (flameRoutine != null) StopCoroutine(flameRoutine);
        if (bellRoutine != null) StopCoroutine(bellRoutine);
        flameRoutine = null; bellRoutine = null; slowed = false;
        if (audioSource != null) audioSource.Stop();
        DestroyEffect(ref flameRoot, ref flameMaterial);
        DestroyEffect(ref bellRoot, ref bellMaterial);
        RestoreBody();
        flames = null;
        flameLayers.Clear();
        flameMaterials.Clear();
    }

    void ClearCharge() { RestoreBody(); if (flameRoutine != null) StopCoroutine(flameRoutine); flameRoutine = null; DestroyEffect(ref flameRoot, ref flameMaterial); flames = null; flameLayers.Clear(); flameMaterials.Clear(); }
    void ClearBell() { if (bellRoutine != null) StopCoroutine(bellRoutine); bellRoutine = null; DestroyEffect(ref bellRoot, ref bellMaterial); }

    IEnumerator RampFlames()
    {
        var elapsed = 0f;
        while (flameRoot != null && flames != null && elapsed < ChargeSeconds)
        {
            elapsed += Time.unscaledDeltaTime;
            var t = Mathf.Clamp01(elapsed / ChargeSeconds);
            SetFlameIntensity(Mathf.Lerp(.65f, slowed ? .68f : 1f, t));
            yield return null;
        }
        // Keep the held fire visible until the native combat clock releases it.
        flameRoutine = null;
    }

    void SetFlameIntensity(float intensity)
    {
        if (flames == null) return;
        TintBody(intensity);
        for (var i = 0; i < flameLayers.Count; i++)
        {
            var layerEmission = flameLayers[i].emission;
            layerEmission.rateOverTime = Mathf.Lerp(20f, 65f, intensity) * (i == 0 ? 1.35f : i == 1 ? .82f : .28f);
        }
        for (var i = 0; i < flameMaterials.Count; i++)
            if (flameMaterials[i] != null && flameMaterials[i].HasProperty("_Color"))
            {
                var c = Color.white;
                c.a = Mathf.Lerp(.12f, .82f, intensity) * (i == 2 ? .72f : 1f);
                flameMaterials[i].color = c;
            }
    }

    GameObject CreateFlames(Transform parent)
    {
        var revenant=GetComponent<EmeraldRevenantPresentation>();
        var bounds = revenant != null && revenant.IsInstalled ? revenant.VisibleWorldBounds : VisualBounds(parent);
        var root = new GameObject("Encore Full Body Fire"); root.transform.SetParent(parent,true); root.transform.position=bounds.center; root.transform.rotation=Quaternion.identity;
        var s=parent.lossyScale; root.transform.localScale=new Vector3(bounds.size.x*1.1f/Mathf.Max(.001f,Mathf.Abs(s.x)),bounds.size.y*1.05f/Mathf.Max(.001f,Mathf.Abs(s.y)),Mathf.Max(bounds.size.z,bounds.size.x*.6f)/Mathf.Max(.001f,Mathf.Abs(s.z)));
        flames = CreateLayer(root.transform, "Body Fire", new Vector3(.52f, .88f, .42f), .35f, .65f, .10f, .24f, .22f, .42f, 1.35f);
        CreateLayer(root.transform, "Rising Tongues", new Vector3(.5f, .82f, .4f), .38f, .75f, .32f, .72f, .16f, .34f, .82f);
        CreateLayer(root.transform, "Floating Embers", new Vector3(.86f, .72f, .62f), .6f, 1.35f, .55f, 1.25f, .045f, .12f, .28f);
        return root;
    }

    ParticleSystem CreateLayer(Transform parent, string name, Vector3 shapeSize,
        float lifetimeMin, float lifetimeMax, float speedMin, float speedMax,
        float sizeMin, float sizeMax, float emissionScale)
    {
        var node = new GameObject(name);
        node.transform.SetParent(parent, false);
        var system = node.AddComponent<ParticleSystem>();
        var main = system.main;
        main.loop = true; main.playOnAwake = true;
        main.startLifetime = new ParticleSystem.MinMaxCurve(lifetimeMin, lifetimeMax);
        main.startSpeed = new ParticleSystem.MinMaxCurve(speedMin, speedMax);
        main.startSize = new ParticleSystem.MinMaxCurve(sizeMin, sizeMax);
        main.startRotation = new ParticleSystem.MinMaxCurve(-.12f, .12f);
        main.simulationSpace = ParticleSystemSimulationSpace.Local;
        main.scalingMode = ParticleSystemScalingMode.Hierarchy;
        main.startColor = new ParticleSystem.MinMaxGradient(fire, new Color(.65f, 1f, .18f));
        var lifetime = system.colorOverLifetime;
        lifetime.enabled = true;
        var fade = new Gradient();
        fade.SetKeys(new[] { new GradientColorKey(Color.white, 0), new GradientColorKey(Color.white, 1) },
            new[] { new GradientAlphaKey(0, 0), new GradientAlphaKey(1, .15f), new GradientAlphaKey(0, 1) });
        lifetime.color = fade;
        var emission = system.emission;
        emission.rateOverTime = 8f * emissionScale;
        var shape = system.shape;
        shape.shapeType = ParticleSystemShapeType.Box;
        shape.scale = shapeSize;
        var velocity = system.velocityOverLifetime;
        velocity.enabled = true; velocity.space = ParticleSystemSimulationSpace.Local;
        velocity.x = new ParticleSystem.MinMaxCurve(-.08f, .08f);
        velocity.y = new ParticleSystem.MinMaxCurve(speedMin * .5f, speedMax);
        velocity.z = new ParticleSystem.MinMaxCurve(-.08f, .08f);
        var renderer = system.GetComponent<ParticleSystemRenderer>();
        renderer.renderMode = ParticleSystemRenderMode.Billboard;
        var material = MakeFlameMaterial();
        renderer.material = material;
        if (flameMaterial == null) flameMaterial = material;
        flameLayers.Add(system); flameMaterials.Add(material);
        system.Play();
        return system;
    }

    Bounds VisualBounds(Transform visual)
    {
        var rs=visual.GetComponentsInChildren<Renderer>(true); var b=new Bounds(visual.position,Vector3.one); var found=false;
        for(var i=0;i<rs.Length;i++){if(rs[i]==null||rs[i] is ParticleSystemRenderer||!rs[i].enabled)continue;if(!found){b=rs[i].bounds;found=true;}else b.Encapsulate(rs[i].bounds);} return b;
    }
    Material MakeFlameMaterial()
    {
        var shader = Shader.Find("Mindstone/Encore Flame")
            ?? Shader.Find("Particles/Standard Unlit")
            ?? Shader.Find("Standard");
        var material = new Material(shader);
        var texture = Resources.Load<Texture2D>("Effects/HellHound/Texture/Fire_Single");
        if (texture != null && material.HasProperty("_MainTex"))
            material.mainTexture = texture;
        material.color = Color.white;
        return material;
    }

    GameObject CreateRipple(Transform parent)
    {
        var root = new GameObject("Encore Bell Sound Ripple");
        root.transform.SetParent(parent, false);
        root.transform.localPosition = Vector3.up * .55f;
        var rippleObject = new GameObject("Vertical Ripple");
        rippleObject.transform.SetParent(root.transform, false);
        var line = rippleObject.AddComponent<LineRenderer>();
        line.useWorldSpace = false;
        line.loop = true;
        line.positionCount = 40;
        line.widthMultiplier = .025f;
        bellMaterial = new Material(Shader.Find("Sprites/Default")
            ?? Shader.Find("Unlit/Color") ?? Shader.Find("Standard"));
        line.material = bellMaterial;
        line.startColor = gold;
        line.endColor = gold;
        for (var i = 0; i < line.positionCount; i++)
        {
            var angle = i * Mathf.PI * 2f / line.positionCount;
            line.SetPosition(i, new Vector3(Mathf.Cos(angle) * .72f,
                Mathf.Sin(angle) * .72f, 0f));
        }
        for(int layer=1;layer<3;layer++) {
            var echo=Instantiate(rippleObject,root.transform);echo.name="Delayed bell echo "+layer;
            echo.transform.localRotation=Quaternion.Euler(layer*13,layer*19,layer*7);
        }
        return root;
    }
    IEnumerator PlayRipple()
    {
        var elapsed = 0f;
        while (bellRoot != null && elapsed < BellSeconds)
        {
            elapsed += Time.unscaledDeltaTime;
            var progress = Mathf.Clamp01(elapsed / BellSeconds);
            var lines=bellRoot.GetComponentsInChildren<LineRenderer>();
            for(int i=0;i<lines.Length;i++) {
                float phase=Mathf.Clamp01((elapsed-i*.085f)/(.72f-i*.085f));
                float opening=1-Mathf.Pow(1-phase,3);
                lines[i].transform.localScale=Vector3.one*Mathf.Lerp(.35f,1.8f+i*.24f,opening);
                var color=Color.Lerp(gold,new Color(1,.95f,.65f),i*.2f);
                color.a=Mathf.Sin(Mathf.PI*phase)*(.75f-i*.17f);
                lines[i].startColor=color;lines[i].endColor=color;
                lines[i].widthMultiplier=.015f+.035f*(1-phase);
            }
            yield return null;
        }
        bellRoutine = null;
        DestroyEffect(ref bellRoot, ref bellMaterial);
    }
    AudioSource EnsureAudio(){if(audioSource!=null)return audioSource;var o=new GameObject("Encore Bell Audio");o.transform.SetParent(transform,false);audioSource=o.AddComponent<AudioSource>();audioSource.playOnAwake=false;audioSource.spatialBlend=0f;audioSource.volume=.42f;return audioSource;}
    AudioClip GetBellClip(){if(bellClip!=null)return bellClip;const int rate=44100;var a=new float[Mathf.CeilToInt(rate*.65f)];for(var i=0;i<a.Length;i++){var t=i/(float)rate;var e=Mathf.Exp(-4.5f*t);a[i]=e*(.52f*Mathf.Sin(2f*Mathf.PI*880f*t)+.25f*Mathf.Sin(2f*Mathf.PI*1320f*t)+.13f*Mathf.Sin(2f*Mathf.PI*1760f*t));}bellClip=AudioClip.Create("Encore Bell",a.Length,1,rate,false);bellClip.SetData(a,0);return bellClip;}
    static void DestroyEffect(ref GameObject root, ref Material owned)
    {
        if (root == null) return;
        root.SetActive(false);
        var renderers = root.GetComponentsInChildren<Renderer>(true);
        for (var i = 0; i < renderers.Length; i++)
            foreach (var material in renderers[i].sharedMaterials)
                if (material != null) Object.Destroy(material);
        Object.Destroy(root);
        root = null;
        owned = null;
    }
    void OnDisable(){Clear();} void OnDestroy(){Clear();if(bellClip!=null)Object.Destroy(bellClip);}
}
