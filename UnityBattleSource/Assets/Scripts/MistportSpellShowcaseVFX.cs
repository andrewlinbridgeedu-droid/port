using System;
using System.Collections;
using System.Collections.Generic;
using Effekseer;
using UnityEngine;

/// <summary>
/// Final-cut showcase choreography for the three Mistport spell families.
/// Effekseer owns the authored energy vocabulary; the small runtime ribbons
/// make the silhouette and motion legible on the portrait battlefield.
/// </summary>
public sealed class MistportSpellShowcaseVFX : MonoBehaviour
{
    const string FireballResource = "Effects/HellHound/FireBall";
    const string FireOnlyResource = "Effects/HellHound/FireOnly";
    const string MaskResource = "Effects/Fool/Effekseer/MaskExplosion/FoolMaskExplosion";
    const string CurtainExplosionResource = "Effects/Fool/Effekseer/CurtainExplosion/FoolCurtainExplosion";
    const string DarkRiftResource = "Effects/Fool/Effekseer/TktkDarkRift/Dark2";
    const string OfficialSlashResource = "Effects/Mistport/Official/Slashing/effect";
    const string OfficialSwordRibbonResource = "Effects/Mistport/Official/Ribbon/effect2";
    const string OfficialSpiralResource = "Effects/Mistport/Official/Ribbon/effect1-2";
    const string OfficialSwordTextureResource = "Effects/Mistport/Official/Ribbon/Sword1";
    const string AuroraTextureResource = "Effects/Fool/Effekseer/MaskExplosion/Texture/aurora01";
    const string FireBurstTextureResource = "Effects/Fool/Effekseer/MaskExplosion/Texture/fire_tex";
    const string BrokenShockwaveTextureResource = "Effects/Fool/Effekseer/MaskExplosion/Texture/Shock_wave004";
    const string SlashTextureResource = "Effects/HellHound/Texture/Line1";
    const string WindTextureResource = "Effects/HellHound/Texture/Wind";
    const string ShockwaveTextureResource = "Effects/HellHound/Texture/Shockwave";
    const string FireBlurTextureResource = "Effects/HellHound/Texture/Fire_Blur";
    const string FireSingleTextureResource = "Effects/HellHound/Texture/Fire_Single";
    const string FlowNoiseTextureResource = "Effects/HellHound/Texture/FractalNoise_2";
    const string CloudNoiseTextureResource = "Effects/HellHound/Texture/FractalNoise_4";
    const string SmokeTextureResource = "Effects/HellHound/Texture/Smoke";
    const string FlameTextureResource = "Effects/HellHound/Texture/Fire";
    const string SplashTextureResource = "Effects/HellHound/Texture/Splash";
    const string FeatherTextureResource = "Effects/HellHound/Texture/Feather";
    const string ParticleSoftTextureResource = "Effects/HellHound/Texture/Particle_Soft";
    const string SpectralCheetahTextureResource = "Effects/HellHound/Texture/Generated/SpectralCheetah_Leap";
    const string SpectralCheetahClosedTextureResource = "Effects/HellHound/Texture/Generated/SpectralCheetah_Leap_Closed";
    const string SwordQiSlashTextureResource = "Effects/HellHound/Texture/Generated/SwordQi_Slash";
    const string WildWardenWindColumnResource = "Effects/Mistport/Generated/WildWarden_WindColumn_v2";

    readonly List<EffekseerHandle> activeHandles = new();
    readonly List<GameObject> activeRoots = new();
    readonly List<Material> activeMaterials = new();
    readonly List<Sprite> activeSprites = new();
    readonly List<Texture2D> activeTextures = new();
    readonly List<Mesh> activeMeshes = new();

    EffekseerEffectAsset fireball;
    EffekseerEffectAsset fireOnly;
    EffekseerEffectAsset mask;
    EffekseerEffectAsset curtainExplosion;
    EffekseerEffectAsset darkRift;
    EffekseerEffectAsset officialSlash;
    EffekseerEffectAsset officialSwordRibbon;
    EffekseerEffectAsset officialSpiral;
    Texture2D slashTexture;
    Texture2D windTexture;
    Texture2D shockwaveTexture;
    Texture2D fireBlurTexture;
    Texture2D smokeTexture;
    Texture2D flameTexture;
    Texture2D splashTexture;
    Texture2D featherTexture;
    Texture2D particleSoftTexture;
    Texture2D spectralHoundTexture;
    Texture2D spectralHoundClosedTexture;
    Texture2D swordQiSlashTexture;
    Texture2D wildWardenWindColumnTexture;
    Texture2D officialSwordTexture;
    Texture2D auroraTexture;
    Texture2D fireBurstTexture;
    Texture2D brokenShockwaveTexture;
    Texture2D fireSingleTexture;
    Texture2D flowNoiseTexture;
    Texture2D cloudNoiseTexture;
    Texture2D impactCoverTexture;
    Texture2D wildWardenBodyTexture;
    Texture2D solarFireballTexture;
    Texture2D houndParticleDotTexture;
    int playbackID;
    bool playing;

    sealed class HoundParticleField
    {
        public ParticleSystem system;
        public ParticleSystem.Particle[] particles;
        public Vector2[] samples;
        public float[] phases;
        public float[] depths;
        public float[] sizes;
        public Color[] colors;
    }

    sealed class NativeFireballSegment
    {
        public EffekseerHandle handle;
        public float age;
        public bool rootStopped;
    }

    public bool IsPlaying => playing;

    // Showcase-only callers can enlarge the authored native FireBall for an
    // isolated hero shot without changing the approved gameplay presentation.
    // The default remains exactly one authored FireBall scale.
    public float NativeFireballScale { get; set; } = 1f;

    void Awake()
    {
        fireball = Resources.Load<EffekseerEffectAsset>(FireballResource);
        fireOnly = Resources.Load<EffekseerEffectAsset>(FireOnlyResource);
        mask = Resources.Load<EffekseerEffectAsset>(MaskResource);
        curtainExplosion = Resources.Load<EffekseerEffectAsset>(CurtainExplosionResource);
        darkRift = Resources.Load<EffekseerEffectAsset>(DarkRiftResource);
        officialSlash = Resources.Load<EffekseerEffectAsset>(OfficialSlashResource);
        officialSwordRibbon = Resources.Load<EffekseerEffectAsset>(OfficialSwordRibbonResource);
        officialSpiral = Resources.Load<EffekseerEffectAsset>(OfficialSpiralResource);
        slashTexture = Resources.Load<Texture2D>(SlashTextureResource);
        windTexture = Resources.Load<Texture2D>(WindTextureResource);
        shockwaveTexture = Resources.Load<Texture2D>(ShockwaveTextureResource);
        fireBlurTexture = Resources.Load<Texture2D>(FireBlurTextureResource);
        smokeTexture = Resources.Load<Texture2D>(SmokeTextureResource);
        flameTexture = Resources.Load<Texture2D>(FlameTextureResource);
        splashTexture = Resources.Load<Texture2D>(SplashTextureResource);
        featherTexture = Resources.Load<Texture2D>(FeatherTextureResource);
        particleSoftTexture = Resources.Load<Texture2D>(ParticleSoftTextureResource);
        spectralHoundTexture = Resources.Load<Texture2D>(SpectralCheetahTextureResource);
        spectralHoundClosedTexture = Resources.Load<Texture2D>(SpectralCheetahClosedTextureResource);
        swordQiSlashTexture = Resources.Load<Texture2D>(SwordQiSlashTextureResource);
        wildWardenWindColumnTexture = Resources.Load<Texture2D>(WildWardenWindColumnResource);
        officialSwordTexture = Resources.Load<Texture2D>(OfficialSwordTextureResource);
        auroraTexture = Resources.Load<Texture2D>(AuroraTextureResource);
        fireBurstTexture = Resources.Load<Texture2D>(FireBurstTextureResource);
        brokenShockwaveTexture = Resources.Load<Texture2D>(BrokenShockwaveTextureResource);
        fireSingleTexture = Resources.Load<Texture2D>(FireSingleTextureResource);
        flowNoiseTexture = Resources.Load<Texture2D>(FlowNoiseTextureResource);
        cloudNoiseTexture = Resources.Load<Texture2D>(CloudNoiseTextureResource);
    }

    public IEnumerator PlaySwordSlash(Func<Vector3> source, Func<Vector3> target)
    {
        var id = ++playbackID;
        StopActiveEffects();
        playing = true;

        var camera = Camera.main;
        var cameraRight = camera != null ? camera.transform.right : Vector3.right;
        var cameraUp = camera != null ? camera.transform.up : Vector3.up;
        var cameraForward = camera != null ? camera.transform.forward : Vector3.forward;
        var root = CreateRoot("VFX · 剑气 · 逆时斩");
        var slashColors = new[]
        {
            new Color(0.16f, 0.74f, 1f),
            new Color(0.68f, 0.34f, 1f),
            new Color(0.42f, 0.92f, 1f)
        };
        var glowRibbons = new List<LineRenderer>();
        var coreRibbons = new List<LineRenderer>();
        for (var i = 0; i < slashColors.Length; i++)
        {
            glowRibbons.Add(CreateRibbon(root.transform, 0.18f - i * 0.025f, slashColors[i], 24, 3180 + i));
            coreRibbons.Add(CreateRibbon(root.transform, 0.045f - i * 0.005f, Color.white, 24, 3210 + i));
        }
        var frontShroud = new List<LineRenderer>();
        for (var i = 0; i < 18; i++)
            frontShroud.Add(CreateFrontRibbon(root.transform, 0.22f - (i % 3) * 0.022f, 8, 4050 + i));
        var organicFront = new List<MeshRenderer>();
        for (var i = 0; i < 42; i++)
            organicFront.Add(CreateFrontOrganicSprite(
                root.transform,
                $"VFX sword front energy {i + 1}",
                slashTexture,
                4100 + i));
        for (var i = 0; i < 30; i++)
            organicFront.Add(CreateFrontOrganicSprite(
                root.transform,
                $"VFX sword front energy splash {i + 1}",
                smokeTexture,
                4150 + i,
                i % 4));
        var cloudVeil = new List<MeshRenderer>();
        for (var i = 0; i < 9; i++)
            cloudVeil.Add(CreateFrontCloud(root.transform, $"VFX sword cloud veil {i + 1}", 4200 + i));
        var frontParticleClouds = new List<ParticleSystem>();
        frontParticleClouds.Add(CreateFrontParticleCloud(
            root.transform,
            "VFX sword front mist cyan",
            ResolveTarget(target) + cameraForward * -1.10f,
            new Color(0.12f, 0.58f, 1f, 0.48f),
            150,
            0.46f,
            4210));
        frontParticleClouds.Add(CreateFrontParticleCloud(
            root.transform,
            "VFX sword front mist violet",
            ResolveTarget(target) + cameraRight * 0.16f + cameraForward * -1.14f,
            new Color(0.42f, 0.16f, 0.92f, 0.46f),
            130,
            0.42f,
            4211));
        frontParticleClouds.Add(CreateFrontParticleCloud(
            root.transform,
            "VFX sword front mist white",
            ResolveTarget(target) + cameraUp * 0.20f + cameraForward * -1.17f,
            new Color(0.70f, 0.90f, 1f, 0.34f),
            100,
            0.38f,
            4212));
        ConfigureFrontParticleVolumes(frontParticleClouds, ParticleSystemShapeType.Sphere, new Vector3(0.78f, 0f, 0f));

        var impactSlash = CreateBillboardSprite(
            root.transform,
            "VFX sword slash main",
            slashTexture,
            target(),
            new Color(0.20f, 0.78f, 1f, 0f),
            3280,
            256);
        var impactEcho = CreateBillboardSprite(
            root.transform,
            "VFX sword slash echo",
            slashTexture,
            target(),
            new Color(0.64f, 0.26f, 1f, 0f),
            3278,
            256);
        var impactCore = CreateBillboardSprite(
            root.transform,
            "VFX sword slash core",
            slashTexture,
            target(),
            new Color(0.92f, 0.98f, 1f, 0f),
            3282,
            256);
        var impactFlash = CreateBillboardSprite(
            root.transform,
            "VFX sword contact flash",
            fireBlurTexture,
            target(),
            new Color(0.22f, 0.70f, 1f, 0f),
            3270,
            512);
        var impactEnergy = CreateBillboardSprite(
            root.transform,
            "VFX sword dense energy mass",
            fireBlurTexture,
            target(),
            new Color(0.04f, 0.24f, 1f, 0f),
            3289,
            256);
        var impactEnergyCore = CreateBillboardSprite(
            root.transform,
            "VFX sword white-hot energy core",
            fireBlurTexture,
            target(),
            new Color(0.52f, 0.92f, 1f, 0f),
            3291,
            320);
        var impactEnergyEcho = CreateBillboardSprite(
            root.transform,
            "VFX sword violet energy echo",
            fireBlurTexture,
            target(),
            new Color(0.28f, 0.06f, 0.94f, 0f),
            3288,
            288);
        var impactCover = CreateCoverSprite(
            root.transform,
            "VFX sword impact cover",
            CreateImpactCoverTexture(),
            target(),
            new Color(0.22f, 0.58f, 1f, 0f),
            3295,
            128);
        var impactCoverCore = CreateCoverSprite(
            root.transform,
            "VFX sword impact cover core",
            CreateImpactCoverTexture(),
            target(),
            new Color(0.86f, 0.94f, 1f, 0f),
            3297,
            128);
        var impactArcs = new List<LineRenderer>
        {
            CreateSlashArc(root.transform, 0.115f, new Color(0.22f, 0.78f, 1f), 4250),
            CreateSlashArc(root.transform, 0.080f, new Color(0.72f, 0.28f, 1f), 4251),
            CreateSlashArc(root.transform, 0.042f, new Color(0.92f, 0.98f, 1f), 4252)
        };
        var impactRays = new List<LineRenderer>();
        var impactRayDirections = new List<Vector3>();
        var frontCutGlows = new List<LineRenderer>();
        var frontCutCores = new List<LineRenderer>();
        for (var i = 0; i < 2; i++)
        {
            frontCutGlows.Add(CreateFrontRibbon(root.transform, 0.12f - i * 0.010f, 9, 4300 + i));
            frontCutCores.Add(CreateFrontRibbon(root.transform, 0.034f - i * 0.002f, 9, 4330 + i));
        }
        var frontSlashCards = new List<MeshRenderer>();
        for (var i = 0; i < 6; i++)
            frontSlashCards.Add(CreateFrontOrganicSprite(
                root.transform,
                $"VFX sword front impact splash {i + 1}",
                splashTexture,
                4360 + i,
                i % 4));
        var frontSlashSmoke = new List<MeshRenderer>();
        for (var i = 0; i < 3; i++)
            frontSlashSmoke.Add(CreateFrontOrganicSprite(
                root.transform,
                $"VFX sword front impact haze {i + 1}",
                smokeTexture,
                4370 + i,
                i % 4));
        var frontSwordCore = new List<MeshRenderer>();
        for (var i = 0; i < 2; i++)
            frontSwordCore.Add(CreateFrontOrganicSprite(
                root.transform,
                $"VFX sword front white-hot core {i + 1}",
                flameTexture,
                4380 + i,
                i == 0 ? 0 : 3));
        var frontSwordBurstFlames = new List<MeshRenderer>();
        for (var i = 0; i < 14; i++)
            frontSwordBurstFlames.Add(CreateFrontOrganicSprite(
                root.transform,
                $"VFX sword dense impact flame {i + 1}",
                flameTexture,
                4400 + i,
                i % 4));
        var frontSwordBurstSmoke = new List<MeshRenderer>();
        for (var i = 0; i < 6; i++)
            frontSwordBurstSmoke.Add(CreateFrontOrganicSprite(
                root.transform,
                $"VFX sword dense impact smoke {i + 1}",
                smokeTexture,
                4420 + i,
                i % 4));
        EffekseerHandle authoredImpact = default;
        EffekseerHandle authoredEcho = default;
        var charge = Play(
            darkRift ?? mask,
            source() + cameraForward * -0.16f + cameraUp * 0.10f,
            Vector3.one * 0.025f,
            new Color(0.20f, 0.58f, 1f),
            1.35f);

        var elapsed = 0f;
        var impactPlayed = false;
        while (elapsed < 1.10f && id == playbackID)
        {
            elapsed += Time.deltaTime;
            var progress = Mathf.Clamp01(elapsed / 1.10f);
            var launch = source();
            var destination = ResolveTarget(target);
            var travel = Mathf.SmoothStep(0f, 1f, Mathf.Clamp01((progress - 0.12f) / 0.60f));
            var fade = 1f - Mathf.SmoothStep(0f, 1f, Mathf.Clamp01((progress - 0.76f) / 0.28f));

            for (var i = 0; i < glowRibbons.Count; i++)
            {
                var head = Mathf.Clamp01(travel * 1.15f - i * 0.075f);
                var tail = Mathf.Clamp01(head - 0.33f - i * 0.035f);
                var arcOffset = (i - 1) * 0.15f;
                UpdateRibbonPair(
                    glowRibbons[i],
                    coreRibbons[i],
                    launch + cameraRight * arcOffset,
                    destination + cameraRight * arcOffset * 0.32f,
                    tail,
                    head,
                    cameraRight,
                    cameraUp,
                    cameraForward,
                    elapsed,
                    i,
                    slashColors[i],
                    fade);
            }

            var slashReveal = Mathf.Clamp01((progress - 0.42f) / 0.48f);
            var slashFade = 1f - Mathf.SmoothStep(0f, 1f, Mathf.Clamp01((progress - 0.79f) / 0.20f));
            UpdateSlashSprite(
                impactSlash,
                destination + cameraRight * 0.02f + cameraForward * -0.08f,
                camera,
                Mathf.Lerp(0.06f, 1.06f, EaseOutBack(Mathf.Clamp01(slashReveal * 1.08f))),
                Mathf.Lerp(-66f, -38f, slashReveal),
                0f,
                new Vector3(0.82f, 1.12f, 1f));
            UpdateSlashSprite(
                impactEcho,
                destination + cameraRight * -0.10f + cameraUp * 0.03f + cameraForward * -0.11f,
                camera,
                Mathf.Lerp(0.03f, 0.86f, EaseOutBack(Mathf.Clamp01(slashReveal * 1.18f))),
                Mathf.Lerp(48f, 22f, slashReveal),
                0f,
                new Vector3(0.74f, 0.92f, 1f));
            UpdateSlashSprite(
                impactCore,
                destination + cameraRight * 0.02f + cameraUp * -0.01f + cameraForward * -0.15f,
                camera,
                Mathf.Lerp(0.04f, 0.90f, EaseOutBack(Mathf.Clamp01(slashReveal * 1.10f))),
                Mathf.Lerp(-58f, -32f, slashReveal),
                0f,
                new Vector3(0.30f, 1.08f, 1f));
            UpdateSlashSprite(
                impactFlash,
                destination + cameraForward * -0.19f,
                camera,
                Mathf.Lerp(0.10f, 0.78f, EaseOutCubic(slashReveal)),
                0f,
                0f,
                Vector3.one);

            var energyReveal = EaseOutCubic(Mathf.Clamp01((progress - 0.48f) / 0.14f));
            var energyFade = 1f - Mathf.SmoothStep(0f, 1f,
                Mathf.Clamp01((progress - 0.98f) / 0.20f));
            UpdateWindSprite(
                impactEnergy,
                destination + cameraForward * -0.24f + cameraUp * 0.08f,
                camera,
                -elapsed * 22f,
                new Vector3(1.62f * energyReveal, 2.54f * energyReveal, 1f),
                energyFade * 0.76f * energyReveal,
                new Color(0.04f, 0.24f, 1f));
            UpdateWindSprite(
                impactEnergyCore,
                destination + cameraForward * -0.30f + cameraUp * 0.04f,
                camera,
                elapsed * 28f,
                new Vector3(1.04f * energyReveal, 1.92f * energyReveal, 1f),
                energyFade * 0.72f * energyReveal,
                new Color(0.52f, 0.92f, 1f));
            UpdateWindSprite(
                impactEnergyEcho,
                destination + cameraForward * -0.40f + cameraRight * 0.18f + cameraUp * -0.08f,
                camera,
                -elapsed * 36f,
                new Vector3(1.28f * energyReveal, 2.10f * energyReveal, 1f),
                energyFade * 0.54f * energyReveal,
                new Color(0.28f, 0.06f, 0.94f));

            var coverReveal = EaseOutCubic(Mathf.Clamp01((progress - 0.46f) / 0.12f));
            var coverFade = 1f - Mathf.SmoothStep(0f, 1f, Mathf.Clamp01((progress - 0.68f) / 0.28f));
            UpdateWindSprite(
                impactCover,
                destination + cameraForward * -0.35f,
                camera,
                -progress * 38f,
                new Vector3(0.46f * coverReveal, 0.70f * coverReveal, 1f),
                0f,
                new Color(0.22f, 0.58f, 1f));
            UpdateWindSprite(
                impactCoverCore,
                destination + cameraForward * -0.47f,
                camera,
                progress * 30f,
                new Vector3(0.28f * coverReveal, 0.48f * coverReveal, 1f),
                0f,
                new Color(0.86f, 0.94f, 1f));
            UpdateFrontShroud(
                frontShroud,
                destination,
                cameraRight,
                cameraUp,
                cameraForward,
                elapsed,
                EaseOutCubic(Mathf.Clamp01((progress - 0.30f) / 0.20f)),
                0f,
                0,
                new[]
                {
                    new Color(0.04f, 0.30f, 1f),
                    new Color(0.34f, 0.08f, 0.92f),
                    new Color(0.12f, 0.78f, 1f),
                    new Color(0.72f, 0.90f, 1f),
                new Color(0.58f, 0.14f, 1f)
                });
            UpdateFrontOrganicSprites(
                organicFront,
                destination,
                cameraRight,
                cameraUp,
                cameraForward,
                elapsed,
                EaseOutCubic(Mathf.Clamp01((progress - 0.34f) / 0.16f)),
                0f,
                0,
                new[]
                {
                    new Color(0.04f, 0.42f, 1f),
                    new Color(0.30f, 0.12f, 0.92f),
                    new Color(0.24f, 0.86f, 1f),
                    new Color(0.84f, 0.96f, 1f),
                    new Color(0.64f, 0.18f, 1f)
                });
            UpdateFrontClouds(
                cloudVeil,
                destination,
                cameraRight,
                cameraUp,
                cameraForward,
                elapsed,
                EaseOutCubic(Mathf.Clamp01((progress - 0.34f) / 0.16f)),
                0f,
                0,
                0.56f,
                new[]
                {
                    new Color(0.06f, 0.30f, 0.95f),
                    new Color(0.24f, 0.08f, 0.78f),
                    new Color(0.14f, 0.58f, 1f)
                });
            UpdateFrontParticleClouds(
                frontParticleClouds,
                destination,
                cameraRight,
                cameraUp,
                cameraForward,
                elapsed,
                0f);
            var frontCutReveal = EaseOutCubic(Mathf.Clamp01((progress - 0.40f) / 0.16f));
            var frontCutFade = 1f - Mathf.SmoothStep(0f, 1f, Mathf.Clamp01((progress - 0.94f) / 0.18f));
            UpdateSwordFrontCuts(
                frontCutGlows,
                frontCutCores,
                destination,
                cameraRight,
                cameraUp,
                cameraForward,
                elapsed,
                frontCutReveal,
                frontCutFade);
            UpdateSwordFrontCards(
                frontSlashCards,
                destination,
                cameraRight,
                cameraUp,
                cameraForward,
                elapsed,
                frontCutReveal,
                frontCutFade * 0.94f,
                new[]
                {
                    new Color(0.08f, 0.46f, 1f),
                    new Color(0.30f, 0.16f, 0.95f),
                    new Color(0.12f, 0.82f, 1f),
                    new Color(0.66f, 0.30f, 1f),
                    new Color(0.82f, 0.98f, 1f),
                    new Color(0.44f, 0.24f, 1f)
                });
            UpdateSwordImpactHaze(
                frontSlashSmoke,
                destination,
                cameraRight,
                cameraUp,
                cameraForward,
                elapsed,
                frontCutReveal,
                0f);
            UpdateSwordCoreBurst(
                frontSwordCore,
                destination,
                cameraRight,
                cameraUp,
                cameraForward,
                elapsed,
                frontCutReveal,
                frontCutFade * 0.76f);
            var denseBurstReveal = EaseOutCubic(Mathf.Clamp01((progress - 0.50f) / 0.12f));
            var denseBurstFade = 1f - Mathf.SmoothStep(0f, 1f,
                Mathf.Clamp01((progress - 0.98f) / 0.20f));
            UpdateColoredBurstCards(
                frontSwordBurstFlames,
                frontSwordBurstSmoke,
                destination,
                cameraRight,
                cameraUp,
                cameraForward,
                elapsed,
                denseBurstReveal,
                denseBurstFade,
                new[]
                {
                    new Color(0.03f, 0.24f, 0.98f),
                    new Color(0.12f, 0.52f, 1f),
                    new Color(0.34f, 0.18f, 0.96f),
                    new Color(0.46f, 0.78f, 1f),
                    new Color(0.84f, 0.98f, 1f)
                },
                new Color(0.08f, 0.14f, 0.58f),
                1.18f,
                3);
            var arcReveal = EaseOutCubic(Mathf.Clamp01((progress - 0.40f) / 0.22f));
            var arcFade = 1f - Mathf.SmoothStep(0f, 1f, Mathf.Clamp01((progress - 0.70f) / 0.28f));
            UpdateSlashArc(
                impactArcs[0], destination, cameraRight, cameraUp, cameraForward,
                -132f, -38f, 0.92f, arcReveal, arcFade * 0.92f, elapsed, 0);
            UpdateSlashArc(
                impactArcs[1], destination, cameraRight, cameraUp, cameraForward,
                -150f, -68f, 0.78f, arcReveal, arcFade * 0.74f, elapsed, 1);
            UpdateSlashArc(
                impactArcs[2], destination, cameraRight, cameraUp, cameraForward,
                -120f, -46f, 0.68f, arcReveal, arcFade * 0.96f, elapsed, 2);

            if (impactPlayed)
            {
                var impactAge = Mathf.Clamp01((progress - 0.54f) / 0.34f);
                UpdateImpactRays(
                    impactRays,
                    impactRayDirections,
                    destination,
                    impactAge,
                    new Color(0.04f, 0.34f, 1f),
                    new Color(0.84f, 0.98f, 1f));
            }

            if (progress >= 0.28f)
                charge.StopRoot();

            if (!impactPlayed && progress >= 0.54f)
            {
                impactPlayed = true;
                authoredImpact = default;
                authoredEcho = default;
                CreateImpactRays(
                    root.transform,
                    destination,
                    cameraRight,
                    cameraUp,
                    cameraForward,
                    impactRays,
                    impactRayDirections,
                    new Color(0.04f, 0.34f, 1f),
                    new Color(0.84f, 0.98f, 1f),
                    4440,
                    "sword energy");
                CreateSparkBurst(root.transform, destination, new Color(0.22f, 0.72f, 1f), 104, 2.2f, 6.8f, 0.062f);
                CreateSparkBurst(root.transform, destination, new Color(0.72f, 0.30f, 1f), 58, 1.2f, 3.6f, 0.045f);
            }

            yield return null;
        }

        StopRoot(charge);
        StopRoot(authoredImpact);
        StopRoot(authoredEcho);
        yield return WaitFor(id, 0.20f);
        FinishPresentation(root, id);
    }

    IEnumerator PlayOfficialSwordSlash(int id, Func<Vector3> source, Func<Vector3> target)
    {
        var camera = Camera.main;
        var cameraRight = camera != null ? camera.transform.right : Vector3.right;
        var cameraUp = camera != null ? camera.transform.up : Vector3.up;
        var cameraForward = camera != null ? camera.transform.forward : Vector3.forward;
        var root = CreateRoot("VFX · Effekseer 官方斩击样例");
        var travel = Play(
            officialSwordRibbon ?? officialSlash,
            source(),
            Vector3.one * 0.055f,
            new Color(0.26f, 0.72f, 1f),
            1.25f);
        EffekseerHandle impact = default;
        EffekseerHandle echo = default;
        var elapsed = 0f;
        var impactPlayed = false;
        while (elapsed < 0.92f && id == playbackID)
        {
            elapsed += Time.deltaTime;
            var progress = Mathf.Clamp01(elapsed / 0.92f);
            var start = source();
            var destination = ResolveTarget(target);
            var flight = Mathf.SmoothStep(0f, 1f, Mathf.Clamp01((progress - 0.08f) / 0.58f));
            var location = Vector3.Lerp(start, destination, flight)
                + cameraUp * Mathf.Sin(flight * Mathf.PI) * 0.20f;
            var direction = destination - location;
            if (direction.sqrMagnitude < 0.0001f)
                direction = Vector3.back;
            SetLocation(travel, location);
            SetRotation(travel, Quaternion.FromToRotation(Vector3.up, direction.normalized));
            SetScale(travel, Vector3.one * Mathf.Lerp(0.045f, 0.075f, flight));

            if (!impactPlayed && progress >= 0.50f)
            {
                impactPlayed = true;
                StopRoot(travel);
                impact = Play(
                    officialSlash ?? officialSwordRibbon,
                    destination + cameraForward * -0.14f,
                    Vector3.one * 0.095f,
                    new Color(0.34f, 0.78f, 1f),
                    1.35f);
                echo = Play(
                    officialSlash ?? officialSwordRibbon,
                    destination + cameraRight * 0.10f + cameraForward * -0.16f,
                    Vector3.one * 0.070f,
                    new Color(0.72f, 0.30f, 1f),
                    1.10f);
            }
            yield return null;
        }

        StopRoot(travel);
        StopRoot(impact);
        StopRoot(echo);
        yield return WaitFor(id, 0.18f);
        FinishPresentation(root, id);
    }

    public IEnumerator PlayFireball(Func<Vector3> source, Func<Vector3> target)
    {
        // This preview is intentionally limited to the authored Effekseer
        // FireBall. The older layered showcase remains below for reference,
        // but is bypassed so the review build shows only one small-to-large
        // native fireball travelling from the Hell Hound to the player.
        yield return PlayNativeFireballOnly(source, target);
        yield break;

#if false
        var id = ++playbackID;
        StopActiveEffects();
        playing = true;

        var camera = Camera.main;
        var cameraRight = camera != null ? camera.transform.right : Vector3.right;
        var cameraUp = camera != null ? camera.transform.up : Vector3.up;
        var cameraForward = camera != null ? camera.transform.forward : Vector3.forward;
        var root = CreateRoot("VFX · 火球 · 冥焰爆燃");
        var launch = source();
        var initialDestination = ResolveTarget(target);
        var trailGlow = CreateRibbon(root.transform, 0.12f, new Color(1f, 0.22f, 0.035f), 16, 3180);
        var trailCore = CreateRibbon(root.transform, 0.026f, new Color(1f, 0.86f, 0.50f), 16, 3210);
        var frontShroud = new List<LineRenderer>();
        for (var i = 0; i < 22; i++)
            frontShroud.Add(CreateFrontRibbon(root.transform, 0.25f - (i % 4) * 0.022f, 8, 4050 + i));
        var organicFront = new List<MeshRenderer>();
        for (var i = 0; i < 52; i++)
            organicFront.Add(CreateFrontOrganicSprite(
                root.transform,
                $"VFX fireball front flame {i + 1}",
                flameTexture,
                4100 + i,
                i % 4));
        for (var i = 0; i < 34; i++)
            organicFront.Add(CreateFrontOrganicSprite(
                root.transform,
                $"VFX fireball front smoke {i + 1}",
                smokeTexture,
                4160 + i,
                i % 4));
        var cloudVeil = new List<MeshRenderer>();
        for (var i = 0; i < 10; i++)
            cloudVeil.Add(CreateFrontCloud(root.transform, $"VFX fireball cloud veil {i + 1}", 4200 + i));
        var frontParticleClouds = new List<ParticleSystem>();
        frontParticleClouds.Add(CreateFrontParticleCloud(
            root.transform,
            "VFX fireball front smoke red",
            initialDestination + cameraForward * -1.10f,
            new Color(0.92f, 0.055f, 0.006f, 0.56f),
            190,
            0.48f,
            4210));
        frontParticleClouds.Add(CreateFrontParticleCloud(
            root.transform,
            "VFX fireball front smoke orange",
            initialDestination + cameraRight * 0.14f + cameraForward * -1.14f,
            new Color(1f, 0.26f, 0.02f, 0.52f),
            165,
            0.44f,
            4211));
        frontParticleClouds.Add(CreateFrontParticleCloud(
            root.transform,
            "VFX fireball front heat",
            initialDestination + cameraUp * 0.18f + cameraForward * -1.17f,
            new Color(1f, 0.72f, 0.10f, 0.42f),
            125,
            0.38f,
            4212));
        frontParticleClouds.Add(CreateFrontParticleCloud(
            root.transform,
            "VFX fireball front ember haze",
            initialDestination + cameraRight * -0.18f + cameraUp * -0.22f + cameraForward * -1.15f,
            new Color(0.80f, 0.015f, 0.002f, 0.48f),
            140,
            0.40f,
            4213));
        ConfigureFrontParticleVolumes(frontParticleClouds, ParticleSystemShapeType.Sphere, new Vector3(0.84f, 0f, 0f));
        var travelFlame = CreateBillboardSprite(
            root.transform,
            "VFX fireball travel flame",
            fireBlurTexture,
            launch,
            new Color(1f, 0.24f, 0.025f, 0f),
            3278,
            256);
        var travelFlameCore = CreateBillboardSprite(
            root.transform,
            "VFX fireball travel flame core",
            fireBlurTexture,
            launch,
            new Color(1f, 0.84f, 0.28f, 0f),
            3280,
            320);
        // Use the project's authored FireBall as the projectile itself. It
        // already contains the cohesive warm body, fire layers, noise and
        // ember vocabulary. Moving a FireOnly layer and adding loose cards
        // here was the source of the scattered-line look.
        var impactAsset = fireball ?? fireOnly;
        var launchEffectPosition = launch + cameraForward * -0.22f;
        var authoredTravelScale = fireball != null
            ? Mathf.Clamp((initialDestination - launchEffectPosition).magnitude / 6.4f * 0.30f, 0.20f, 0.34f)
            : 0.075f;
        var authoredTravelSpeed = fireball != null ? 2.55f : 1.85f;
        var travelAuthored = Play(
            impactAsset,
            launchEffectPosition,
            Vector3.one * authoredTravelScale,
            Color.white,
            authoredTravelSpeed);
        if (fireball != null)
        {
            var direction = initialDestination - launchEffectPosition;
            if (direction.sqrMagnitude < 0.0001f)
                direction = Vector3.forward;
            var rotation = Quaternion.FromToRotation(Vector3.up, direction.normalized);
            travelAuthored.SetRotation(rotation);
        }
        var solarFireballTexture = CreateSolarFireballTexture();
        // The imported FireBall is authored as a charge/impact asset. Keep
        // its native charge at the mouth for the first beat, then carry one
        // connected solar body made from the same warm texture vocabulary so
        // the released projectile is visible as a ball between anchors.
        var travelSolarBody = CreateFrontOrganicSprite(
            root.transform,
            "VFX fireball single solar carrier",
            solarFireballTexture,
            4390,
            -1);
        var travelCloud = CreateFrontCloud(
            root.transform,
            "VFX fireball moving organic body",
            4391);
        var travelCloudCore = CreateFrontCloud(
            root.transform,
            "VFX fireball moving hot core",
            4392);
        // The imported FireBall is a strong charge/impact asset, but its
        // authored root is not a reliable source-to-target projectile. Use a
        // single dense front-facing carrier for the flight so the player sees
        // one solar mass rather than loose streaks.
        var travelCarrier = CreateCoverSprite(
            root.transform,
            "VFX fireball moving dense solar body",
            CreateImpactCoverTexture(),
            launchEffectPosition,
            new Color(0.92f, 0.025f, 0.002f, 0f),
            4393,
            128f);
        var travelCarrierCore = CreateCoverSprite(
            root.transform,
            "VFX fireball moving dense solar core",
            CreateImpactCoverTexture(),
            launchEffectPosition,
            new Color(1f, 0.62f, 0.045f, 0f),
            4394,
            128f);
        EffekseerHandle impact = default;
        EffekseerHandle impactFire = default;
        var impactRays = new List<LineRenderer>();
        var impactRayDirections = new List<Vector3>();
        var frontFireCards = new List<MeshRenderer>();
        for (var i = 0; i < 10; i++)
            frontFireCards.Add(CreateFrontOrganicSprite(
                root.transform,
                $"VFX fireball front flame silhouette {i + 1}",
                flameTexture,
                4300 + i,
                i % 4));
        var frontFireSmoke = new List<MeshRenderer>();
        for (var i = 0; i < 4; i++)
            frontFireSmoke.Add(CreateFrontOrganicSprite(
                root.transform,
                $"VFX fireball front smoke silhouette {i + 1}",
                smokeTexture,
                4320 + i,
                i % 4));
        var impactCoreFlames = new List<MeshRenderer>();
        for (var i = 0; i < 8; i++)
            impactCoreFlames.Add(CreateFrontOrganicSprite(
                root.transform,
                $"VFX fireball impact core flame {i + 1}",
                flameTexture,
                4340 + i,
                (i + 1) % 4));
        var impactCoreOffsets = new[]
        {
            new Vector2(-0.12f, 0.04f),
            new Vector2(0.10f, 0.08f),
            new Vector2(-0.05f, -0.11f),
            new Vector2(0.14f, -0.08f),
            new Vector2(-0.18f, -0.07f),
            new Vector2(0.02f, 0.18f),
            new Vector2(-0.16f, 0.15f),
            new Vector2(0.18f, 0.16f)
        };
        var impactSolarBody = CreateFrontOrganicSprite(
            root.transform,
            "VFX fireball impact solar core",
            solarFireballTexture,
            4398,
            -1);
        var impactCover = CreateCoverSprite(
            root.transform,
            "VFX fireball impact dense cover",
            CreateImpactCoverTexture(),
            initialDestination + cameraForward * -1.86f,
            new Color(0.82f, 0.018f, 0.002f, 0f),
            4396,
            128f);
        var impactCoverCore = CreateCoverSprite(
            root.transform,
            "VFX fireball impact dense hot core",
            CreateImpactCoverTexture(),
            initialDestination + cameraForward * -1.98f,
            new Color(1f, 0.52f, 0.035f, 0f),
            4397,
            128f);
        var impactPlayed = false;
        // The authored FireBall is reserved for the terminal hit. During
        // flight the previously accepted dense solar carrier is the only
        // readable projectile body; leaving the authored charge layer alive
        // makes the projectile read as rings and streaks instead of one solid
        // fireball.
        var travelAuthoredStopped = true;
        travelAuthored.Stop();
        var elapsed = 0f;
        const float duration = 1.52f;
        while (elapsed < duration && id == playbackID)
        {
            elapsed += Time.deltaTime;
            var progress = Mathf.Clamp01(elapsed / duration);
            var destination = ResolveTarget(target);
            var travel = Mathf.SmoothStep(0f, 1f, Mathf.Clamp01((progress - 0.06f) / 0.62f));
            var projectilePosition = Vector3.Lerp(launch, destination, travel);
            if (!impactPlayed)
            {
                var travelFade = 1f;
                UpdateWindSprite(
                    travelFlame,
                    projectilePosition + cameraForward * -0.12f,
                    camera,
                    -elapsed * 44f,
                    new Vector3(Mathf.Lerp(0.28f, 0.42f, travel),
                        Mathf.Lerp(0.44f, 0.70f, travel),
                        1f),
                    travelFade * 0.08f,
                    new Color(1f, 0.24f, 0.025f));
                UpdateWindSprite(
                    travelFlameCore,
                    projectilePosition + cameraForward * -0.16f,
                    camera,
                    elapsed * 36f,
                    new Vector3(Mathf.Lerp(0.18f, 0.28f, travel),
                        Mathf.Lerp(0.28f, 0.48f, travel),
                        1f),
                    travelFade * 0.06f,
                    new Color(1f, 0.84f, 0.28f));
                var orbReveal = EaseOutCubic(Mathf.Clamp01((progress - 0.04f) / 0.10f));
                var orbPulse = 0.98f + Mathf.Sin(elapsed * 15f) * 0.025f;
                var orbScale = Mathf.Lerp(0.34f, 1.46f, travel) * orbReveal * orbPulse;
                UpdateWindSprite(
                    travelSolarBody,
                    projectilePosition + cameraForward * -1.70f,
                    camera,
                    elapsed * 11f,
                    new Vector3(orbScale * 1.06f, orbScale * 0.98f, 1f),
                    travelFade * 0.98f,
                    Color.white);
                UpdateWindSprite(
                    travelCloud,
                    projectilePosition + cameraForward * -1.62f,
                    camera,
                    -elapsed * 16f,
                    new Vector3(orbScale * 1.20f, orbScale * 1.12f, 1f),
                    travelFade * 0.14f,
                    new Color(1f, 0.035f, 0.004f));
                // The authored FireBall is intentionally not moved during
                // flight. The moving solar orb owns the complete silhouette.
                if (!travelAuthoredStopped)
                {
                    if (fireball != null)
                    {
                        SetLocation(
                            travelAuthored,
                            projectilePosition + cameraForward * -0.28f + cameraUp * 0.02f);
                        SetScale(
                            travelAuthored,
                            Vector3.one * authoredTravelScale
                                * Mathf.Lerp(0.92f, 1.52f, travel));
                    }
                    else
                    {
                        var projectileReveal = EaseOutCubic(Mathf.Clamp01((progress - 0.04f) / 0.10f));
                        SetLocation(
                            travelAuthored,
                            projectilePosition + cameraForward * -0.28f + cameraUp * 0.02f);
                        SetScale(
                            travelAuthored,
                            Vector3.one * Mathf.Lerp(0.070f, 0.115f, travel) * projectileReveal);
                    }
                }

                var trailHead = Mathf.Clamp01(travel);
                var trailTail = Mathf.Clamp01(trailHead - 0.24f);
                UpdateRibbonPair(
                    trailGlow,
                    trailCore,
                    Vector3.Lerp(launch, destination, trailTail),
                    projectilePosition,
                    0f,
                    1f,
                    cameraRight,
                    cameraUp,
                    cameraForward,
                    elapsed,
                    0,
                    new Color(1f, 0.25f, 0.035f),
                    (1f - Mathf.SmoothStep(0f, 1f,
                        Mathf.Clamp01((travel - 0.76f) / 0.20f))) * 0.14f);
            }
            else
            {
                trailGlow.enabled = false;
                trailCore.enabled = false;
                if (travelSolarBody != null)
                    travelSolarBody.enabled = false;
                if (travelCloud != null)
                    travelCloud.enabled = false;
                if (travelCloudCore != null)
                    travelCloudCore.enabled = false;
                if (travelCarrier != null)
                    travelCarrier.enabled = false;
                if (travelCarrierCore != null)
                    travelCarrierCore.enabled = false;
                travelAuthored.Stop();
            }

            // The authored Effekseer fire stays on top of the target-local
            // organic layers. The protagonist remains in the scene, but the
            // flame cards and smoke are dense enough to wash over the body.
            var coverReveal = EaseOutCubic(Mathf.Clamp01((progress - 0.66f) / 0.18f));
            var coverFade = 1f - Mathf.SmoothStep(0f, 1f,
                Mathf.Clamp01((progress - 0.94f) / 0.20f));
            var roundImpactBlend = EaseOutCubic(Mathf.Clamp01((progress - 0.60f) / 0.30f));
            UpdateFrontShroud(
                frontShroud,
                destination,
                cameraRight,
                cameraUp,
                cameraForward,
                elapsed,
                EaseOutCubic(Mathf.Clamp01((progress - 0.70f) / 0.12f)),
                coverFade * 0.04f,
                1,
                new[]
                {
                    new Color(0.68f, 0.025f, 0.008f),
                    new Color(1f, 0.12f, 0.012f),
                    new Color(1f, 0.34f, 0.025f),
                    new Color(1f, 0.72f, 0.12f),
                    new Color(1f, 0.96f, 0.58f),
                    new Color(0.92f, 0.06f, 0.008f)
                });
            UpdateFrontOrganicSprites(
                organicFront,
                destination,
                cameraRight,
                cameraUp,
                cameraForward,
                elapsed,
                EaseOutCubic(Mathf.Clamp01((progress - 0.74f) / 0.12f)),
                coverFade * Mathf.Lerp(0.025f, 0.52f, roundImpactBlend),
                1,
                new[]
                {
                    new Color(0.66f, 0.018f, 0.004f),
                    new Color(1f, 0.08f, 0.006f),
                    new Color(1f, 0.24f, 0.012f),
                    new Color(1f, 0.58f, 0.045f),
                    new Color(1f, 0.94f, 0.48f),
                    new Color(0.92f, 0.035f, 0.004f)
                });
            UpdateFrontClouds(
                cloudVeil,
                destination,
                cameraRight,
                cameraUp,
                cameraForward,
                elapsed,
                EaseOutCubic(Mathf.Clamp01((progress - 0.66f) / 0.16f)),
                coverFade * 0.70f,
                1,
                0.60f,
                new[]
                {
                    new Color(0.66f, 0.018f, 0.004f),
                    new Color(0.94f, 0.08f, 0.006f),
                    new Color(1f, 0.28f, 0.015f),
                    new Color(0.86f, 0.10f, 0.004f)
                });
            UpdateFrontParticleClouds(
                frontParticleClouds,
                destination,
                cameraRight,
                cameraUp,
                cameraForward,
                elapsed,
                coverFade * coverReveal);
            var frontFireReveal = EaseOutCubic(Mathf.Clamp01((progress - 0.76f) / 0.16f));
            var frontFireFade = 1f - Mathf.SmoothStep(0f, 1f, Mathf.Clamp01((progress - 1.00f) / 0.18f));
            var sharpFlameSuppression = Mathf.Lerp(0.38f, 0.78f, roundImpactBlend);
            UpdateFireBurstCards(
                frontFireCards,
                frontFireSmoke,
                destination,
                cameraRight,
                cameraUp,
                cameraForward,
                elapsed,
                frontFireReveal,
                frontFireFade * Mathf.Lerp(0.12f, 0.42f, roundImpactBlend) * sharpFlameSuppression);
            var impactCoreReveal = EaseOutCubic(Mathf.Clamp01((progress - 0.76f) / 0.16f));
            var impactCoreFade = frontFireFade * impactCoreReveal * 0.62f;
            var impactCorePalette = new[]
            {
                new Color(0.78f, 0.018f, 0.003f),
                new Color(1f, 0.08f, 0.004f),
                new Color(1f, 0.27f, 0.008f),
                new Color(1f, 0.62f, 0.035f),
                new Color(1f, 0.92f, 0.34f)
            };
            for (var i = 0; i < impactCoreFlames.Count; i++)
            {
                var renderer = impactCoreFlames[i];
                if (renderer == null)
                    continue;
                var offset = impactCoreOffsets[i % impactCoreOffsets.Length];
                var pulse = 0.92f + Mathf.Sin(elapsed * (11f + i * 0.80f) + i * 1.4f) * 0.08f;
                var alpha = impactCoreFade * (i == 3 ? 0.94f : 0.70f + (i % 3) * 0.08f) * pulse;
                renderer.enabled = alpha > 0.004f;
                if (!renderer.enabled)
                    continue;
                var coreTightness = Mathf.Lerp(0.28f, 0.62f, roundImpactBlend);
                renderer.transform.position = destination
                    + cameraRight * offset.x * coreTightness
                    + cameraUp * offset.y * coreTightness
                    + cameraForward * (-1.50f - i * 0.015f);
                renderer.transform.rotation = FrontBillboardRotation(
                    cameraForward,
                    cameraUp,
                    (i * 43f) + Mathf.Sin(elapsed * 9f + i) * 12f);
                var coreScale = Mathf.Lerp(0.12f, 0.72f, roundImpactBlend) * pulse;
                renderer.transform.localScale = new Vector3(coreScale * 0.86f, coreScale * 1.18f, 1f);
                var material = renderer.material;
                if (material != null && material.HasProperty("_Color"))
                {
                    var color = impactCorePalette[i % impactCorePalette.Length];
                    material.SetColor("_Color", new Color(color.r, color.g, color.b, alpha));
                }
            }

            // A soft, solid inner mass starts before the sharp flame cards.
            // It is the layer that makes the hit feel like a real detonation:
            // the actor remains underneath, but the fire owns the pixels.
            UpdateWindSprite(
                impactCover,
                destination + cameraForward * -1.86f,
                camera,
                -elapsed * 18f,
                new Vector3(
                    Mathf.Lerp(0.30f, 1.30f, coverReveal),
                    Mathf.Lerp(0.34f, 1.12f, coverReveal),
                    1f),
                0f,
                new Color(0.82f, 0.018f, 0.002f));
            UpdateWindSprite(
                impactCoverCore,
                destination + cameraForward * -1.99f,
                camera,
                elapsed * 24f,
                new Vector3(
                    Mathf.Lerp(0.16f, 0.72f, coverReveal),
                    Mathf.Lerp(0.18f, 0.68f, coverReveal),
                    1f),
                0f,
                new Color(1f, 0.54f, 0.035f));
            if (impactCover != null && impactCover.material != null
                && impactCover.material.HasProperty("_Phase"))
                impactCover.material.SetFloat("_Phase", elapsed * 17f);
            if (impactCoverCore != null && impactCoverCore.material != null
                && impactCoverCore.material.HasProperty("_Phase"))
                impactCoverCore.material.SetFloat("_Phase", -elapsed * 23f);

            var impactSolarReveal = EaseOutCubic(Mathf.Clamp01((progress - 0.78f) / 0.14f));
            var impactSolarScale = Mathf.Lerp(0.12f, 0.88f, roundImpactBlend);
            UpdateWindSprite(
                impactSolarBody,
                destination + cameraForward * -1.66f,
                camera,
                -elapsed * 18f,
                new Vector3(impactSolarScale * 1.08f, impactSolarScale * 0.94f, 1f),
                frontFireFade * impactSolarReveal * 0.94f,
                Color.white);

            if (!impactPlayed && progress >= 0.72f)
            {
                impactPlayed = true;
                travelAuthoredStopped = true;
                travelAuthored.Stop();
                // Restore the authored terminal pair used in the reference:
                // a hot solar core plus the broad layered organic blast. The
                // native pair supplies the white/yellow heat bloom while the
                // cards and clouds supply the irregular red/orange silhouette.
                impact = Play(
                    impactAsset,
                    destination + cameraForward * -0.18f,
                    Vector3.one * 0.28f,
                    new Color(1f, 0.38f, 0.045f, 1f),
                    1.20f);
                impactFire = Play(
                    fireOnly ?? impactAsset,
                    destination + cameraForward * -0.30f,
                    Vector3.one * 0.34f,
                    new Color(1f, 0.68f, 0.14f, 1f),
                    1.75f);
                CreateSparkBurst(root.transform, destination, new Color(1f, 0.34f, 0.045f), 104, 2.2f, 6.8f, 0.062f);
                CreateSparkBurst(root.transform, destination, new Color(1f, 0.82f, 0.30f), 58, 1.2f, 3.6f, 0.045f);
            }

            yield return null;
        }

        StopRoot(impact);
        StopRoot(impactFire);
        yield return WaitFor(id, 0.20f);
        FinishPresentation(root, id);
#endif
    }

    IEnumerator PlayNativeFireballOnly(Func<Vector3> source, Func<Vector3> target)
    {
        var id = ++playbackID;
        StopActiveEffects();
        playing = true;

        var camera = Camera.main;
        var cameraRight = camera != null ? camera.transform.right : Vector3.right;
        var cameraUp = camera != null ? camera.transform.up : Vector3.up;
        var cameraForward = camera != null ? camera.transform.forward : Vector3.forward;
        var launch = source() + cameraForward * -0.24f;
        var destination = ResolveTarget(target) + cameraForward * -0.24f;
        var direction = destination - launch;
        if (direction.sqrMagnitude < 0.0001f)
            direction = Vector3.forward;

        var root = CreateRoot("VFX · 原生太阳火球 · 直线命中");
        if (fireball == null)
        {
            FinishPresentation(root, id);
            yield break;
        }

        var segments = new List<NativeFireballSegment>(4);
        var rotation = Quaternion.FromToRotation(Vector3.up, direction.normalized);

        // FireBall contains an authored location curve, so one handle cannot
        // be dragged smoothly with SetLocation. Keep the same authored asset
        // alive through a very short crossfade instead of hard-stopping and
        // respawning it at large intervals. Visually this reads as one ball;
        // technically it is two or three overlapping instances of the same
        // native effect, with no Unity replacement layer.
        void SpawnSegment(Vector3 position, float scale)
        {
            var segment = new NativeFireballSegment
            {
                handle = Play(
                    fireball,
                    position,
                    Vector3.one * scale * Mathf.Max(0.01f, NativeFireballScale),
                    Color.white,
                    1.20f),
                age = 0f,
                rootStopped = false
            };
            segment.handle.SetRotation(rotation);
            segment.handle.SetAllColor(new Color(1f, 1f, 1f, 0f));
            segments.Add(segment);
        }

        const float refreshInterval = 0.085f;
        const float fadeInDuration = 0.045f;
        const float fadeOutStart = 0.15f;
        const float segmentLifetime = 0.25f;

        SpawnSegment(launch, 0.075f);
        var elapsed = 0f;
        // Keep the fifth review frame on the travelling fireball.  `flightEnd`
        // is a normalized point inside `duration`, so the old 0.82 value made
        // the ball arrive before the fifth capture and turned that frame into
        // the impact flash.
        const float duration = 1.48f;
        const float flightEnd = 0.90f;
        var refreshElapsed = 0f;
        while (elapsed < duration && id == playbackID)
        {
            var deltaTime = Mathf.Max(Time.deltaTime, 1f / 120f);
            elapsed += deltaTime;
            var progress = Mathf.Clamp01(elapsed / duration);
            var travel = Mathf.SmoothStep(
                0f,
                1f,
                Mathf.Clamp01(progress / flightEnd));
            var position = Vector3.Lerp(launch, destination, travel);
            var scale = Mathf.Lerp(0.075f, 0.34f, travel);
            refreshElapsed += deltaTime;
            if (refreshElapsed >= refreshInterval)
            {
                do
                {
                    refreshElapsed -= refreshInterval;
                }
                while (refreshElapsed >= refreshInterval);
                SpawnSegment(position, scale);
            }

            for (var i = segments.Count - 1; i >= 0; i--)
            {
                var segment = segments[i];
                segment.age += deltaTime;
                var fadeIn = Mathf.SmoothStep(
                    0f,
                    1f,
                    Mathf.Clamp01(segment.age / fadeInDuration));
                var fadeOut = 1f - Mathf.SmoothStep(
                    0f,
                    1f,
                    Mathf.InverseLerp(fadeOutStart, segmentLifetime, segment.age));
                segment.handle.SetAllColor(new Color(1f, 1f, 1f, fadeIn * fadeOut));

                if (!segment.rootStopped && segment.age >= fadeOutStart)
                {
                    segment.handle.StopRoot();
                    segment.rootStopped = true;
                }

                if (segment.age >= segmentLifetime)
                {
                    segment.handle.Stop();
                    segments.RemoveAt(i);
                }
            }
            yield return null;
        }

        for (var i = 0; i < segments.Count; i++)
            segments[i].handle.Stop();

        // Final review presentation: the five confirmed FireBall flight
        // frames are the complete effect. Do not append an alternate impact
        // composition after the approved fifth frame.
        yield return WaitFor(id, 0.16f);
        FinishPresentation(root, id);
        yield break;

#if false
        // Historical implementation kept below for comparison only. It is
        // never entered and must not be used for the showcase preview.
        var impactFrontShroud = new List<LineRenderer>();
        for (var i = 0; i < 22; i++)
            impactFrontShroud.Add(CreateFrontRibbon(
                root.transform,
                0.25f - (i % 4) * 0.022f,
                8,
                4050 + i));
        var impactOrganicFront = new List<MeshRenderer>();
        for (var i = 0; i < 52; i++)
            impactOrganicFront.Add(CreateFrontOrganicSprite(
                root.transform,
                $"VFX fireball impact flame {i + 1}",
                flameTexture,
                4100 + i,
                i % 4));
        for (var i = 0; i < 34; i++)
            impactOrganicFront.Add(CreateFrontOrganicSprite(
                root.transform,
                $"VFX fireball impact smoke {i + 1}",
                smokeTexture,
                4160 + i,
                i % 4));
        var impactCloudVeil = new List<MeshRenderer>();
        for (var i = 0; i < 10; i++)
            impactCloudVeil.Add(CreateFrontCloud(
                root.transform,
                $"VFX fireball impact cloud {i + 1}",
                4200 + i));
        var impactParticleClouds = new List<ParticleSystem>();
        impactParticleClouds.Add(CreateFrontParticleCloud(
            root.transform,
            "VFX fireball impact red smoke",
            impactCenter + cameraForward * -1.10f,
            new Color(0.92f, 0.055f, 0.006f, 0.56f),
            190,
            0.48f,
            4210));
        impactParticleClouds.Add(CreateFrontParticleCloud(
            root.transform,
            "VFX fireball impact orange smoke",
            impactCenter + cameraRight * 0.14f + cameraForward * -1.14f,
            new Color(1f, 0.26f, 0.02f, 0.52f),
            165,
            0.44f,
            4211));
        impactParticleClouds.Add(CreateFrontParticleCloud(
            root.transform,
            "VFX fireball impact heat",
            impactCenter + cameraUp * 0.18f + cameraForward * -1.17f,
            new Color(1f, 0.72f, 0.10f, 0.42f),
            125,
            0.38f,
            4212));
        impactParticleClouds.Add(CreateFrontParticleCloud(
            root.transform,
            "VFX fireball impact ember haze",
            impactCenter + cameraRight * -0.18f + cameraUp * -0.22f + cameraForward * -1.15f,
            new Color(0.80f, 0.015f, 0.002f, 0.48f),
            140,
            0.40f,
            4213));
        ConfigureFrontParticleVolumes(
            impactParticleClouds,
            ParticleSystemShapeType.Sphere,
            new Vector3(0.84f, 0f, 0f));
        var impactFireCards = new List<MeshRenderer>();
        for (var i = 0; i < 10; i++)
            impactFireCards.Add(CreateFrontOrganicSprite(
                root.transform,
                $"VFX fireball impact flame silhouette {i + 1}",
                flameTexture,
                4300 + i,
                i % 4));
        var impactFireSmoke = new List<MeshRenderer>();
        for (var i = 0; i < 4; i++)
            impactFireSmoke.Add(CreateFrontOrganicSprite(
                root.transform,
                $"VFX fireball impact smoke silhouette {i + 1}",
                smokeTexture,
                4320 + i,
                i % 4));
        var impactCoreFlames = new List<MeshRenderer>();
        for (var i = 0; i < 8; i++)
            impactCoreFlames.Add(CreateFrontOrganicSprite(
                root.transform,
                $"VFX fireball impact core flame {i + 1}",
                flameTexture,
                4340 + i,
                (i + 1) % 4));
        var impactCoreOffsets = new[]
        {
            new Vector2(-0.12f, 0.04f),
            new Vector2(0.10f, 0.08f),
            new Vector2(-0.05f, -0.11f),
            new Vector2(0.14f, -0.08f),
            new Vector2(-0.18f, -0.07f),
            new Vector2(0.02f, 0.18f),
            new Vector2(-0.16f, 0.15f),
            new Vector2(0.18f, 0.16f)
        };
        var impactSolarBody = CreateFrontOrganicSprite(
            root.transform,
            "VFX fireball impact solar core",
            CreateSolarFireballTexture(),
            4398,
            -1);
        var impactCover = CreateCoverSprite(
            root.transform,
            "VFX fireball impact dense cover",
            CreateImpactCoverTexture(),
            impactCenter + cameraForward * -1.86f,
            new Color(0.82f, 0.018f, 0.002f, 0f),
            4396,
            128f);
        var impactCoverCore = CreateCoverSprite(
            root.transform,
            "VFX fireball impact dense hot core",
            CreateImpactCoverTexture(),
            impactCenter + cameraForward * -1.98f,
            new Color(1f, 0.52f, 0.035f, 0f),
            4397,
            128f);
        var impact = Play(
            fireball ?? fireOnly,
            impactCenter + cameraForward * -0.18f,
            Vector3.one * 0.28f,
            new Color(1f, 0.38f, 0.045f, 1f),
            1.20f);
        var impactFire = Play(
            fireOnly ?? fireball,
            impactCenter + cameraForward * -0.30f,
            Vector3.one * 0.34f,
            new Color(1f, 0.68f, 0.14f, 1f),
            1.75f);
        CreateSparkBurst(root.transform, impactCenter, new Color(1f, 0.34f, 0.045f), 104, 2.2f, 6.8f, 0.062f);
        CreateSparkBurst(root.transform, impactCenter, new Color(1f, 0.82f, 0.30f), 58, 1.2f, 3.6f, 0.045f);

        // The old block above is kept as the source record of the original
        // composition, but its four free particle clouds are what turn the
        // screenshot into a vertical ball in the current runtime. Drive the
        // same flame/smoke materials with the target-local splash layout
        // below, and leave the original update loop unreachable.
        for (var i = 0; i < impactFrontShroud.Count; i++)
            if (impactFrontShroud[i] != null)
                impactFrontShroud[i].enabled = false;
        for (var i = 0; i < impactOrganicFront.Count; i++)
            if (impactOrganicFront[i] != null)
                impactOrganicFront[i].enabled = false;
        for (var i = 0; i < impactCloudVeil.Count; i++)
            if (impactCloudVeil[i] != null)
                impactCloudVeil[i].enabled = false;
        for (var i = 0; i < impactParticleClouds.Count; i++)
            if (impactParticleClouds[i] != null)
                impactParticleClouds[i].Stop(true, ParticleSystemStopBehavior.StopEmittingAndClear);
        StopRoot(impact);
        StopRoot(impactFire);

        var referenceFlames = impactOrganicFront.GetRange(0, 24);
        var referenceSmoke = impactOrganicFront.GetRange(52, 12);
        var impactHeatGlow = CreateBillboardSprite(
            root.transform,
            "VFX fireball reference yellow-white heat",
            fireBlurTexture,
            impactCenter + cameraForward * -1.92f,
            new Color(1f, 0.72f, 0.08f, 0f),
            4399,
            256f);
        {
            var referenceImpactElapsed = 0f;
            const float referenceImpactDuration = 1.10f;
            while (referenceImpactElapsed < referenceImpactDuration && id == playbackID)
            {
                referenceImpactElapsed += Mathf.Max(Time.deltaTime, 1f / 120f);
                var impactProgress = Mathf.Clamp01(referenceImpactElapsed / referenceImpactDuration);
                var splashReveal = EaseOutCubic(Mathf.Clamp01(impactProgress / 0.60f));
                var splashFade = 1f - Mathf.SmoothStep(
                    0f,
                    1f,
                    Mathf.Clamp01((impactProgress - 0.92f) / 0.18f)) * 0.10f;

                UpdateReferenceFireballSplash(
                    referenceFlames,
                    referenceSmoke,
                    impactCoreFlames,
                    impactSolarBody,
                    impactCenter,
                    cameraRight,
                    cameraUp,
                    cameraForward,
                    referenceImpactElapsed,
                    splashReveal,
                    splashFade);
                var veilReveal = EaseOutCubic(Mathf.Clamp01(impactProgress / 0.66f));
                UpdateWindSprite(
                    impactCover,
                    impactCenter + cameraForward * -1.80f,
                    camera,
                    -referenceImpactElapsed * 8f,
                    new Vector3(
                        Mathf.Lerp(0.18f, 1.52f, veilReveal),
                        Mathf.Lerp(0.16f, 1.06f, veilReveal),
                        1f),
                    splashFade * veilReveal * 0.26f,
                    new Color(0.76f, 0.018f, 0.002f));
                UpdateWindSprite(
                    impactCoverCore,
                    impactCenter + cameraForward * -1.96f,
                    camera,
                    referenceImpactElapsed * 14f,
                    new Vector3(
                        Mathf.Lerp(0.12f, 0.82f, veilReveal),
                        Mathf.Lerp(0.12f, 0.66f, veilReveal),
                        1f),
                    splashFade * veilReveal * 0.28f,
                    new Color(1f, 0.48f, 0.025f));
                UpdateWindSprite(
                    impactHeatGlow,
                    impactCenter
                        + cameraRight * -0.32f
                        + cameraUp * -0.34f
                        + cameraForward * -2.02f,
                    camera,
                    -referenceImpactElapsed * 11f,
                    new Vector3(
                        Mathf.Lerp(0.12f, 1.10f, veilReveal),
                        Mathf.Lerp(0.10f, 0.82f, veilReveal),
                        1f),
                    splashFade * veilReveal * 0.38f,
                    new Color(1f, 0.68f, 0.08f));
                yield return null;
            }

            yield return WaitFor(id, 0.20f);
            FinishPresentation(root, id);
        }
        yield break;

        var legacyImpactElapsed = 0f;
        const float legacyImpactDuration = 0.64f;
        while (legacyImpactElapsed < legacyImpactDuration && id == playbackID)
        {
            legacyImpactElapsed += Mathf.Max(Time.deltaTime, 1f / 120f);
            var impactProgress = Mathf.Clamp01(legacyImpactElapsed / legacyImpactDuration);
            // The original choreography enters its terminal section at
            // progress 0.72 and reaches the reference peak at 1.00.
            var progress = Mathf.Lerp(0.72f, 1f, impactProgress);
            var coverReveal = EaseOutCubic(Mathf.Clamp01((progress - 0.66f) / 0.18f));
            var coverFade = 1f - Mathf.SmoothStep(
                0f,
                1f,
                Mathf.Clamp01((progress - 0.94f) / 0.20f));
            var roundImpactBlend = EaseOutCubic(Mathf.Clamp01((progress - 0.60f) / 0.30f));

            UpdateFrontShroud(
                impactFrontShroud,
                impactCenter,
                cameraRight,
                cameraUp,
                cameraForward,
                legacyImpactElapsed,
                EaseOutCubic(Mathf.Clamp01((progress - 0.70f) / 0.12f)),
                coverFade * 0.04f,
                1,
                new[]
                {
                    new Color(0.68f, 0.025f, 0.008f),
                    new Color(1f, 0.12f, 0.012f),
                    new Color(1f, 0.34f, 0.025f),
                    new Color(1f, 0.72f, 0.12f),
                    new Color(1f, 0.96f, 0.58f),
                    new Color(0.92f, 0.06f, 0.008f)
                });
            UpdateFrontOrganicSprites(
                impactOrganicFront,
                impactCenter,
                cameraRight,
                cameraUp,
                cameraForward,
                legacyImpactElapsed,
                EaseOutCubic(Mathf.Clamp01((progress - 0.74f) / 0.12f)),
                coverFade * Mathf.Lerp(0.025f, 0.52f, roundImpactBlend),
                1,
                new[]
                {
                    new Color(0.66f, 0.018f, 0.004f),
                    new Color(1f, 0.08f, 0.006f),
                    new Color(1f, 0.24f, 0.012f),
                    new Color(1f, 0.58f, 0.045f),
                    new Color(1f, 0.94f, 0.48f),
                    new Color(0.92f, 0.035f, 0.004f)
                });
            UpdateFrontClouds(
                impactCloudVeil,
                impactCenter,
                cameraRight,
                cameraUp,
                cameraForward,
                legacyImpactElapsed,
                EaseOutCubic(Mathf.Clamp01((progress - 0.66f) / 0.16f)),
                coverFade * 0.70f,
                1,
                0.60f,
                new[]
                {
                    new Color(0.66f, 0.018f, 0.004f),
                    new Color(0.94f, 0.08f, 0.006f),
                    new Color(1f, 0.28f, 0.015f),
                    new Color(0.86f, 0.10f, 0.004f)
                });
            UpdateFrontParticleClouds(
                impactParticleClouds,
                impactCenter,
                cameraRight,
                cameraUp,
                cameraForward,
                legacyImpactElapsed,
                coverFade * coverReveal);

            var frontFireReveal = EaseOutCubic(Mathf.Clamp01((progress - 0.76f) / 0.16f));
            var frontFireFade = 1f - Mathf.SmoothStep(
                0f,
                1f,
                Mathf.Clamp01((progress - 1.00f) / 0.18f));
            var sharpFlameSuppression = Mathf.Lerp(0.38f, 0.78f, roundImpactBlend);
            UpdateFireBurstCards(
                impactFireCards,
                impactFireSmoke,
                impactCenter,
                cameraRight,
                cameraUp,
                cameraForward,
                legacyImpactElapsed,
                frontFireReveal,
                frontFireFade * Mathf.Lerp(0.12f, 0.42f, roundImpactBlend) * sharpFlameSuppression);

            var impactCoreReveal = EaseOutCubic(Mathf.Clamp01((progress - 0.76f) / 0.16f));
            var impactCoreFade = frontFireFade * impactCoreReveal * 0.62f;
            var impactCorePalette = new[]
            {
                new Color(0.78f, 0.018f, 0.003f),
                new Color(1f, 0.08f, 0.004f),
                new Color(1f, 0.27f, 0.008f),
                new Color(1f, 0.62f, 0.035f),
                new Color(1f, 0.92f, 0.34f)
            };
            for (var i = 0; i < impactCoreFlames.Count; i++)
            {
                var renderer = impactCoreFlames[i];
                if (renderer == null)
                    continue;
                var offset = impactCoreOffsets[i % impactCoreOffsets.Length];
                var pulse = 0.92f + Mathf.Sin(legacyImpactElapsed * (11f + i * 0.80f) + i * 1.4f) * 0.08f;
                var alpha = impactCoreFade * (i == 3 ? 0.94f : 0.70f + (i % 3) * 0.08f) * pulse;
                renderer.enabled = alpha > 0.004f;
                if (!renderer.enabled)
                    continue;
                var coreTightness = Mathf.Lerp(0.28f, 0.62f, roundImpactBlend);
                renderer.transform.position = impactCenter
                    + cameraRight * offset.x * coreTightness
                    + cameraUp * offset.y * coreTightness
                    + cameraForward * (-1.50f - i * 0.015f);
                renderer.transform.rotation = FrontBillboardRotation(
                    cameraForward,
                    cameraUp,
                    (i * 43f) + Mathf.Sin(legacyImpactElapsed * 9f + i) * 12f);
                var coreScale = Mathf.Lerp(0.12f, 0.72f, roundImpactBlend) * pulse;
                renderer.transform.localScale = new Vector3(coreScale * 0.86f, coreScale * 1.18f, 1f);
                var material = renderer.material;
                if (material != null && material.HasProperty("_Color"))
                {
                    var color = impactCorePalette[i % impactCorePalette.Length];
                    material.SetColor("_Color", new Color(color.r, color.g, color.b, alpha));
                }
            }

            UpdateWindSprite(
                impactCover,
                impactCenter + cameraForward * -1.86f,
                camera,
                -legacyImpactElapsed * 18f,
                new Vector3(
                    Mathf.Lerp(0.30f, 1.30f, coverReveal),
                    Mathf.Lerp(0.34f, 1.12f, coverReveal),
                    1f),
                0f,
                new Color(0.82f, 0.018f, 0.002f));
            UpdateWindSprite(
                impactCoverCore,
                impactCenter + cameraForward * -1.99f,
                camera,
                legacyImpactElapsed * 24f,
                new Vector3(
                    Mathf.Lerp(0.16f, 0.72f, coverReveal),
                    Mathf.Lerp(0.18f, 0.68f, coverReveal),
                    1f),
                0f,
                new Color(1f, 0.54f, 0.035f));
            if (impactCover != null && impactCover.material != null
                && impactCover.material.HasProperty("_Phase"))
                impactCover.material.SetFloat("_Phase", legacyImpactElapsed * 17f);
            if (impactCoverCore != null && impactCoverCore.material != null
                && impactCoverCore.material.HasProperty("_Phase"))
                impactCoverCore.material.SetFloat("_Phase", -legacyImpactElapsed * 23f);

            var impactSolarReveal = EaseOutCubic(Mathf.Clamp01((progress - 0.78f) / 0.14f));
            var impactSolarScale = Mathf.Lerp(0.12f, 0.88f, roundImpactBlend);
            UpdateWindSprite(
                impactSolarBody,
                impactCenter + cameraForward * -1.66f,
                camera,
                -legacyImpactElapsed * 18f,
                new Vector3(impactSolarScale * 1.08f, impactSolarScale * 0.94f, 1f),
                frontFireFade * impactSolarReveal * 0.94f,
                Color.white);

            yield return null;
        }

        StopRoot(impact);
        StopRoot(impactFire);
        yield return WaitFor(id, 0.20f);
        FinishPresentation(root, id);
#endif
    }

    /// <summary>
    /// A short front-facing detonation veil for authored effects whose native
    /// layers are additive. It is target-local and opaque at the contact
    /// core: the actor remains present underneath the burst while the spell
    /// owns the contact silhouette.
    /// </summary>
    IEnumerator PlayReferenceFireballImpact(
        GameObject root,
        int id,
        Camera camera,
        Vector3 center,
        Vector3 cameraRight,
        Vector3 cameraUp,
        Vector3 cameraForward)
    {
        // This is the recovered target composition: overlapping irregular
        // flame/smoke cards spread sideways across the actor, with a hot
        // yellow-white lower flare. It intentionally contains no free
        // particle sphere, no vertical cloud and no native impact orb.
        var flames = new List<MeshRenderer>();
        for (var index = 0; index < 24; index++)
            flames.Add(CreateFrontOrganicSprite(
                root.transform,
                $"VFX reference fireball splash flame {index + 1}",
                flameTexture,
                4100 + index,
                index % 4));

        var smoke = new List<MeshRenderer>();
        for (var index = 0; index < 12; index++)
            smoke.Add(CreateFrontOrganicSprite(
                root.transform,
                $"VFX reference fireball splash smoke {index + 1}",
                smokeTexture,
                4160 + index,
                index % 4));

        var coreFlames = new List<MeshRenderer>();
        for (var index = 0; index < 8; index++)
            coreFlames.Add(CreateFrontOrganicSprite(
                root.transform,
                $"VFX reference fireball splash hot layer {index + 1}",
                flameTexture,
                4340 + index,
                (index + 1) % 4));

        var solarBody = CreateFrontOrganicSprite(
            root.transform,
            "VFX reference fireball splash hot core",
            CreateSolarFireballTexture(),
            4398,
            -1);
        var cover = CreateCoverSprite(
            root.transform,
            "VFX reference fireball splash red occlusion",
            CreateImpactCoverTexture(),
            center + cameraForward * -1.80f,
            new Color(0.76f, 0.018f, 0.002f, 0f),
            4396,
            128f);
        var coverCore = CreateCoverSprite(
            root.transform,
            "VFX reference fireball splash orange occlusion",
            CreateImpactCoverTexture(),
            center + cameraForward * -1.96f,
            new Color(1f, 0.48f, 0.025f, 0f),
            4397,
            128f);
        var lowerHeat = CreateBillboardSprite(
            root.transform,
            "VFX reference fireball splash lower heat",
            fireBlurTexture,
            center + cameraRight * -0.32f + cameraUp * -0.34f + cameraForward * -2.02f,
            new Color(1f, 0.68f, 0.08f, 0f),
            4399,
            256f);

        CreateSparkBurst(
            root.transform,
            center,
            new Color(1f, 0.34f, 0.045f),
            104,
            2.2f,
            6.8f,
            0.062f);
        CreateSparkBurst(
            root.transform,
            center,
            new Color(1f, 0.82f, 0.30f),
            58,
            1.2f,
            3.6f,
            0.045f);

        var elapsed = 0f;
        const float duration = 1.10f;
        while (elapsed < duration && id == playbackID)
        {
            elapsed += Mathf.Max(Time.deltaTime, 1f / 120f);
            var progress = Mathf.Clamp01(elapsed / duration);
            var reveal = EaseOutCubic(Mathf.Clamp01(progress / 0.60f));
            var fade = 1f - Mathf.SmoothStep(
                0f,
                1f,
                Mathf.Clamp01((progress - 0.92f) / 0.18f)) * 0.10f;

            UpdateReferenceFireballSplash(
                flames,
                smoke,
                coreFlames,
                solarBody,
                center,
                cameraRight,
                cameraUp,
                cameraForward,
                elapsed,
                reveal,
                fade);
            var veilReveal = EaseOutCubic(Mathf.Clamp01(progress / 0.66f));
            UpdateWindSprite(
                cover,
                center + cameraForward * -1.80f,
                camera,
                -elapsed * 8f,
                new Vector3(
                    Mathf.Lerp(0.18f, 1.52f, veilReveal),
                    Mathf.Lerp(0.16f, 1.06f, veilReveal),
                    1f),
                fade * veilReveal * 0.26f,
                new Color(0.76f, 0.018f, 0.002f));
            UpdateWindSprite(
                coverCore,
                center + cameraForward * -1.96f,
                camera,
                elapsed * 14f,
                new Vector3(
                    Mathf.Lerp(0.12f, 0.82f, veilReveal),
                    Mathf.Lerp(0.12f, 0.66f, veilReveal),
                    1f),
                fade * veilReveal * 0.28f,
                new Color(1f, 0.48f, 0.025f));
            UpdateWindSprite(
                lowerHeat,
                center
                    + cameraRight * -0.32f
                    + cameraUp * -0.34f
                    + cameraForward * -2.02f,
                camera,
                -elapsed * 11f,
                new Vector3(
                    Mathf.Lerp(0.12f, 1.10f, veilReveal),
                    Mathf.Lerp(0.10f, 0.82f, veilReveal),
                    1f),
                fade * veilReveal * 0.38f,
                new Color(1f, 0.68f, 0.08f));
            yield return null;
        }

        yield return WaitFor(id, 0.20f);
        FinishPresentation(root, id);
    }

    public IEnumerator PlayImpactCover(Func<Vector3> target, Color color, float scale)
    {
        var id = ++playbackID;
        StopActiveEffects();
        playing = true;

        var camera = Camera.main;
        var cameraForward = camera != null ? camera.transform.forward : Vector3.forward;
        var cameraRight = camera != null ? camera.transform.right : Vector3.right;
        var root = CreateRoot("VFX · 命中遮蔽爆发");
        var cover = CreateCoverSprite(
            root.transform,
            "VFX impact cover body",
            CreateImpactCoverTexture(),
            ResolveTarget(target) + cameraForward * -0.34f,
            new Color(color.r, color.g, color.b, 0f),
            3300,
            128);
        var coverCore = CreateCoverSprite(
            root.transform,
            "VFX impact cover core",
            CreateImpactCoverTexture(),
            ResolveTarget(target) + cameraForward * -0.46f,
            new Color(1f, 0.96f, 0.82f, 0f),
            3302,
            128);
        var coverEcho = CreateCoverSprite(
            root.transform,
            "VFX impact cover echo",
            CreateImpactCoverTexture(),
            ResolveTarget(target) + cameraForward * -0.56f,
            new Color(color.r, Mathf.Min(1f, color.g * 0.72f), color.b, 0f),
            3301,
            128);

        var elapsed = 0f;
        const float duration = 0.72f;
        while (elapsed < duration && id == playbackID)
        {
            elapsed += Time.deltaTime;
            var progress = Mathf.Clamp01(elapsed / duration);
            var reveal = EaseOutCubic(Mathf.Clamp01(progress / 0.22f));
            var fade = 1f - Mathf.SmoothStep(0f, 1f, Mathf.Clamp01((progress - 0.56f) / 0.44f));
            var center = ResolveTarget(target);
            UpdateWindSprite(
                cover,
                center + cameraForward * -0.34f,
                camera,
                -progress * 42f,
                new Vector3(scale * Mathf.Lerp(0.42f, 1.12f, reveal),
                    scale * Mathf.Lerp(0.42f, 1.58f, reveal),
                    1f),
                fade * Mathf.Lerp(0.30f, 0.96f, reveal),
                color);
            UpdateWindSprite(
                coverCore,
                center + cameraForward * -0.46f,
                camera,
                progress * 28f,
                new Vector3(scale * Mathf.Lerp(0.18f, 0.76f, reveal),
                    scale * Mathf.Lerp(0.20f, 1.10f, reveal),
                    1f),
                fade * Mathf.Lerp(0.24f, 1.00f, reveal),
                new Color(1f, 0.96f, 0.82f));
            UpdateWindSprite(
                coverEcho,
                center + cameraForward * -0.56f + cameraRight * 0.05f,
                camera,
                -progress * 66f,
                new Vector3(scale * Mathf.Lerp(0.26f, 0.92f, reveal),
                    scale * Mathf.Lerp(0.30f, 1.28f, reveal),
                    1f),
                fade * Mathf.Lerp(0.16f, 0.84f, reveal),
                new Color(color.r, Mathf.Min(1f, color.g * 0.72f), color.b));
            yield return null;
        }

        FinishPresentation(root, id);
    }

    IEnumerator PlayOfficialTornado(int id, Func<Vector3> target)
    {
        var camera = Camera.main;
        var cameraForward = camera != null ? camera.transform.forward : Vector3.forward;
        var center = ResolveTarget(target) - Vector3.up * 0.42f;
        var root = CreateRoot("VFX · Effekseer 官方螺旋样例");
        var spiral = Play(
            officialSpiral,
            center,
            Vector3.one * 0.13f,
            new Color(0.34f, 0.58f, 1f),
            1.05f);
        var echo = Play(
            officialSpiral,
            center + Vector3.up * 0.10f + cameraForward * -0.08f,
            Vector3.one * 0.095f,
            new Color(0.78f, 0.28f, 1f),
            0.82f);

        var elapsed = 0f;
        while (elapsed < 1.08f && id == playbackID)
        {
            elapsed += Time.deltaTime;
            var progress = Mathf.Clamp01(elapsed / 1.08f);
            center = ResolveTarget(target) - Vector3.up * 0.42f;
            SetLocation(spiral, center);
            SetLocation(echo, center + Vector3.up * 0.10f + cameraForward * -0.08f);
            SetRotation(spiral, Quaternion.AngleAxis(progress * 110f, Vector3.up));
            SetRotation(echo, Quaternion.AngleAxis(-progress * 145f, Vector3.up));
            if (progress >= 0.72f)
            {
                StopRoot(spiral);
                StopRoot(echo);
            }
            yield return null;
        }

        StopRoot(spiral);
        StopRoot(echo);
        yield return WaitFor(id, 0.20f);
        FinishPresentation(root, id);
    }

    public IEnumerator PlayTornado(Func<Vector3> target)
    {
        yield return PlayTornadoCore(target, false);
    }

    /// <summary>
    /// Wild Warden reference variant. This is intentionally separate from the
    /// blue tornado baseline: the reference language is a living wind column,
    /// leaf/feather motes, broken rings, and a warm green-gold core.
    /// </summary>
    public IEnumerator PlayWildWarden(Func<Vector3> target)
    {
        yield return PlayWildWardenReference(target);
    }

    IEnumerator PlayTornadoCore(Func<Vector3> target, bool wildWardenPalette)
    {
        var id = ++playbackID;
        StopActiveEffects();
        playing = true;

        var camera = Camera.main;
        var cameraForward = camera != null ? camera.transform.forward : Vector3.forward;
        var cameraRight = camera != null ? camera.transform.right : Vector3.right;
        var groundForward = Vector3.ProjectOnPlane(cameraForward, Vector3.up).normalized;
        if (groundForward.sqrMagnitude < 0.0001f)
            groundForward = Vector3.forward;
        var groundRight = Vector3.Cross(Vector3.up, groundForward).normalized;
        var cameraUp = camera != null ? camera.transform.up : Vector3.up;
        var root = CreateRoot("VFX · 旋风 · 失序回流");
        // The storm owns the protagonist's body space, not the floor in front
        // of him. This keeps the silhouette readable when the live anchor
        // moves with the actor or the camera framing changes.
        var center = ResolveTarget(target) + Vector3.up * 0.02f;

        var colors = new[]
        {
            new Color(0.24f, 0.66f, 1f),
            new Color(0.40f, 0.24f, 0.98f),
            new Color(0.18f, 0.90f, 0.82f),
            new Color(0.58f, 0.34f, 1f)
        };
        var windRibbons = new List<LineRenderer>();
        for (var i = 0; i < 8; i++)
            windRibbons.Add(CreateRibbon(root.transform, 0.10f - i * 0.010f, colors[i % colors.Length], 34, 4250 + i));
        var frontWindGlows = new List<LineRenderer>();
        var frontWindCores = new List<LineRenderer>();
        var frontWindBandCount = wildWardenPalette ? 5 : 2;
        for (var i = 0; i < frontWindBandCount; i++)
        {
            frontWindGlows.Add(CreateFrontRibbon(
                root.transform,
                0.19f - i * 0.018f,
                29,
                4300 + i));
            frontWindCores.Add(CreateFrontRibbon(
                root.transform,
                0.046f - i * 0.003f,
                29,
                4330 + i));
        }
        var frontWindMist = new List<MeshRenderer>();
        for (var i = 0; i < 5; i++)
            frontWindMist.Add(CreateFrontOrganicSprite(
                root.transform,
                $"VFX tornado front mist card {i + 1}",
                smokeTexture,
                4360 + i,
                i % 4));
        var frontAuroraCards = new List<MeshRenderer>();
        for (var i = 0; i < 4; i++)
            frontAuroraCards.Add(CreateFrontOrganicSprite(
                root.transform,
                $"VFX tornado supplied aurora card {i + 1}",
                auroraTexture,
                4380 + i));
        var frontWindSplashes = new List<MeshRenderer>();
        for (var i = 0; i < 6; i++)
            frontWindSplashes.Add(CreateFrontOrganicSprite(
                root.transform,
                $"VFX tornado supplied splash fragment {i + 1}",
                splashTexture,
                4390 + i,
                i % 4));
        var frontShroud = new List<LineRenderer>();
        for (var i = 0; i < 20; i++)
            frontShroud.Add(CreateFrontRibbon(root.transform, 0.21f - (i % 4) * 0.018f, 9, 4050 + i));
        var organicFront = new List<MeshRenderer>();
        for (var i = 0; i < 44; i++)
            organicFront.Add(CreateFrontOrganicSprite(
                root.transform,
                $"VFX tornado front wind {i + 1}",
                windTexture,
                4100 + i));
        for (var i = 0; i < 28; i++)
            organicFront.Add(CreateFrontOrganicSprite(
                root.transform,
                $"VFX tornado front mist {i + 1}",
                smokeTexture,
                4150 + i,
                i % 4));
        var cloudVeil = new List<MeshRenderer>();
        for (var i = 0; i < 10; i++)
            cloudVeil.Add(CreateFrontCloud(root.transform, $"VFX tornado cloud veil {i + 1}", 4200 + i));
        var frontParticleClouds = new List<ParticleSystem>();
        if (!wildWardenPalette)
        {
            frontParticleClouds.Add(CreateFrontParticleCloud(
                root.transform,
                "VFX tornado front cyan mist",
                center + cameraForward * -1.12f,
                new Color(0.12f, 0.66f, 1f, 0.44f),
                180,
                0.44f,
                4210));
            frontParticleClouds.Add(CreateFrontParticleCloud(
                root.transform,
                "VFX tornado front violet mist",
                center + cameraRight * 0.16f + cameraForward * -1.15f,
                new Color(0.50f, 0.18f, 0.92f, 0.42f),
                155,
                0.42f,
                4211));
            frontParticleClouds.Add(CreateFrontParticleCloud(
                root.transform,
                "VFX tornado front turquoise mist",
                center + cameraRight * -0.14f + cameraUp * 0.20f + cameraForward * -1.16f,
                new Color(0.10f, 0.88f, 0.80f, 0.38f),
                145,
                0.39f,
                4212));
            frontParticleClouds.Add(CreateFrontParticleCloud(
                root.transform,
                "VFX tornado front pink mist",
                center + cameraUp * -0.24f + cameraForward * -1.14f,
                new Color(1f, 0.16f, 0.70f, 0.34f),
                125,
                0.36f,
                4213));
            ConfigureFrontParticleVolume(frontParticleClouds[0], ParticleSystemShapeType.Box, new Vector3(0.62f, 1.55f, 0.30f));
            ConfigureFrontParticleVolume(frontParticleClouds[1], ParticleSystemShapeType.Box, new Vector3(0.84f, 1.28f, 0.30f));
            ConfigureFrontParticleVolume(frontParticleClouds[2], ParticleSystemShapeType.Box, new Vector3(0.52f, 1.82f, 0.30f));
            ConfigureFrontParticleVolume(frontParticleClouds[3], ParticleSystemShapeType.Box, new Vector3(0.42f, 1.18f, 0.30f));
        }
        var windLayers = new List<SpriteRenderer>();
        for (var i = 0; i < 5; i++)
        {
            var color = colors[i % colors.Length];
            var layer = CreateBillboardSprite(
                root.transform,
                $"VFX wind vortex layer {i + 1}",
                windTexture,
                center,
                new Color(color.r, color.g, color.b, 0f),
                4260 + i,
                128);
            windLayers.Add(layer);
        }
        var stormCore = CreateBillboardSprite(
            root.transform,
            "VFX storm core",
            fireBlurTexture,
            center + cameraUp * 0.66f,
            new Color(0.34f, 0.70f, 1f, 0f),
            3258,
            512);
        var stormEnergy = CreateBillboardSprite(
            root.transform,
            "VFX storm dense energy mass",
            fireBlurTexture,
            center,
            new Color(0.04f, 0.36f, 1f, 0f),
            3289,
            256);
        var stormEnergyCore = CreateBillboardSprite(
            root.transform,
            "VFX storm white-hot core",
            fireBlurTexture,
            center,
            new Color(0.52f, 0.96f, 1f, 0f),
            3291,
            320);
        var stormEnergyEcho = CreateBillboardSprite(
            root.transform,
            "VFX storm violet energy echo",
            fireBlurTexture,
            center,
            new Color(0.30f, 0.08f, 0.96f, 0f),
            3288,
            288);
        var floorShock = CreateBillboardSprite(
            root.transform,
            "VFX storm ground shockwave",
            shockwaveTexture,
            center + Vector3.up * 0.03f,
            new Color(0.22f, 0.66f, 1f, 0f),
            3255,
            256);
        var stormCover = CreateCoverSprite(
            root.transform,
            "VFX storm impact cover",
            CreateImpactCoverTexture(),
            center + Vector3.up * 0.08f,
            new Color(0.24f, 0.62f, 1f, 0f),
            3295,
            128);
        var stormCoverEcho = CreateCoverSprite(
            root.transform,
            "VFX storm impact cover echo",
            CreateImpactCoverTexture(),
            center + Vector3.up * 0.10f + cameraForward * -0.10f,
            new Color(0.60f, 0.28f, 1f, 0f),
            3296,
            128);
        var impactRays = new List<LineRenderer>();
        var impactRayDirections = new List<Vector3>();
        var frontStormBurstFlames = new List<MeshRenderer>();
        for (var i = 0; i < 14; i++)
            frontStormBurstFlames.Add(CreateFrontOrganicSprite(
                root.transform,
                $"VFX storm dense impact flame {i + 1}",
                flameTexture,
                4400 + i,
                i % 4));
        var frontStormBurstSmoke = new List<MeshRenderer>();
        for (var i = 0; i < 6; i++)
            frontStormBurstSmoke.Add(CreateFrontOrganicSprite(
                root.transform,
                $"VFX storm dense impact smoke {i + 1}",
                smokeTexture,
                4420 + i,
                i % 4));
        var rift = wildWardenPalette
            ? default(EffekseerHandle)
            : Play(
                darkRift ?? mask,
                center + Vector3.up * 0.07f,
                Vector3.one * 0.022f,
                new Color(0.22f, 0.64f, 1f),
                1.10f);
        EffekseerHandle stormBurst = default;
        var stormBurstPlayed = false;
        CreateWindParticles(root.transform, center, new Color(0.45f, 0.72f, 1f), 36);

        var elapsed = 0f;
        while (elapsed < 1.08f && id == playbackID)
        {
            elapsed += Time.deltaTime;
            var progress = Mathf.Clamp01(elapsed / 1.08f);
            var reveal = Mathf.SmoothStep(0f, 1f, Mathf.Clamp01(progress / 0.25f));
            var fade = 1f - Mathf.SmoothStep(0f, 1f, Mathf.Clamp01((progress - 0.82f) / 0.18f));
            center = ResolveTarget(target) + Vector3.up * 0.02f;

            for (var i = 0; i < windRibbons.Count; i++)
            {
                // The authored ground-plane helix projects as a polygonal
                // cage in the portrait camera. The front-facing bands below
                // carry the readable tornado silhouette instead.
                windRibbons[i].enabled = false;
            }

            if (!wildWardenPalette)
            {
                for (var i = 0; i < windLayers.Count; i++)
                {
                    var heightT = i / (float)Mathf.Max(1, windLayers.Count - 1);
                    var layerReveal = Mathf.Clamp01(reveal * (1.10f - heightT * 0.16f));
                    var layerHeight = Mathf.Lerp(0.04f, 1.42f, heightT) * layerReveal;
                    var width = Mathf.Lerp(0.68f, 1.62f, heightT)
                        * (0.92f + Mathf.Sin(elapsed * 8.5f + i * 1.3f) * 0.08f);
                    var bandHeight = Mathf.Lerp(0.42f, 0.30f, heightT);
                    var spin = elapsed * (i % 2 == 0 ? 142f : -118f) + i * 37f;
                    var layerColor = colors[i % colors.Length];
                    UpdateWindSprite(
                        windLayers[i],
                        center + Vector3.up * layerHeight + cameraForward * (-0.05f - i * 0.012f),
                        camera,
                        spin,
                        new Vector3(width * layerReveal, bandHeight * layerReveal, 1f),
                        0f,
                        layerColor);
                }
            }

            if (!wildWardenPalette)
            {
                UpdateWindSprite(
                    stormCore,
                    center + Vector3.up * Mathf.Lerp(0.24f, 0.58f, reveal) + cameraForward * -0.17f,
                    camera,
                    elapsed * 86f,
                    new Vector3(0.92f, 1.42f, 1f) * reveal,
                    fade * 0.62f * reveal,
                    new Color(0.30f, 0.68f, 1f));
                var stormEnergyReveal = EaseOutCubic(Mathf.Clamp01((progress - 0.24f) / 0.16f));
                var stormEnergyFade = 1f - Mathf.SmoothStep(0f, 1f,
                    Mathf.Clamp01((progress - 0.98f) / 0.20f));
                UpdateWindSprite(
                    stormEnergy,
                    center + Vector3.up * 0.18f + cameraForward * -0.24f,
                    camera,
                    -elapsed * 24f,
                    new Vector3(1.64f * stormEnergyReveal, 2.62f * stormEnergyReveal, 1f),
                    stormEnergyFade * 0.74f * stormEnergyReveal,
                    new Color(0.04f, 0.34f, 1f));
                UpdateWindSprite(
                    stormEnergyCore,
                    center + Vector3.up * 0.14f + cameraForward * -0.30f,
                    camera,
                    elapsed * 30f,
                    new Vector3(1.06f * stormEnergyReveal, 2.00f * stormEnergyReveal, 1f),
                    stormEnergyFade * 0.70f * stormEnergyReveal,
                    new Color(0.52f, 0.96f, 1f));
                UpdateWindSprite(
                    stormEnergyEcho,
                    center + Vector3.up * 0.10f + cameraRight * 0.16f + cameraForward * -0.40f,
                    camera,
                    -elapsed * 38f,
                    new Vector3(1.28f * stormEnergyReveal, 2.18f * stormEnergyReveal, 1f),
                    stormEnergyFade * 0.52f * stormEnergyReveal,
                    new Color(0.30f, 0.08f, 0.96f));
                UpdateWindSprite(
                    floorShock,
                    center + Vector3.up * 0.025f + cameraForward * -0.09f,
                    camera,
                    elapsed * -58f,
                    new Vector3(
                        Mathf.Lerp(0.12f, 1.34f, EaseOutCubic(Mathf.Clamp01(progress / 0.70f))),
                        Mathf.Lerp(0.12f, 0.84f, EaseOutCubic(Mathf.Clamp01(progress / 0.70f))),
                        1f),
                    fade * Mathf.Sin(Mathf.Clamp01(progress / 0.82f) * Mathf.PI) * 0.30f,
                    new Color(0.22f, 0.62f, 1f));
                var stormCoverReveal = EaseOutCubic(Mathf.Clamp01((progress - 0.20f) / 0.20f));
                UpdateWindSprite(
                    stormCover,
                    center + Vector3.up * 0.08f + cameraForward * -0.34f,
                    camera,
                    elapsed * -32f,
                    new Vector3(0.54f * stormCoverReveal, 0.82f * stormCoverReveal, 1f),
                    0f,
                    new Color(0.24f, 0.62f, 1f));
                UpdateWindSprite(
                    stormCoverEcho,
                    center + Vector3.up * 0.12f + cameraForward * -0.46f,
                    camera,
                    elapsed * 52f,
                    new Vector3(0.40f * stormCoverReveal, 0.62f * stormCoverReveal, 1f),
                    0f,
                    new Color(0.60f, 0.28f, 1f));
            }
            UpdateFrontShroud(
                frontShroud,
                center,
                cameraRight,
                cameraUp,
                cameraForward,
                elapsed,
                EaseOutCubic(Mathf.Clamp01((progress - 0.10f) / 0.18f)),
                wildWardenPalette ? 0.82f : 0f,
                2,
                colors);
            if (!wildWardenPalette)
            {
                UpdateFrontOrganicSprites(
                    organicFront,
                    center,
                    cameraRight,
                    cameraUp,
                    cameraForward,
                    elapsed,
                    EaseOutCubic(Mathf.Clamp01((progress - 0.12f) / 0.16f)),
                    0f,
                    2,
                    colors);
                UpdateFrontClouds(
                    cloudVeil,
                    center,
                    cameraRight,
                    cameraUp,
                    cameraForward,
                    elapsed,
                    EaseOutCubic(Mathf.Clamp01((progress - 0.12f) / 0.16f)),
                    0f,
                    2,
                    0.58f,
                    colors);
            }
            UpdateFrontParticleClouds(
                frontParticleClouds,
                center,
                cameraRight,
                cameraUp,
                cameraForward,
                elapsed,
                0f);
            var frontWindReveal = EaseOutCubic(Mathf.Clamp01((progress - 0.08f) / 0.22f));
            var frontWindFade = 1f - Mathf.SmoothStep(0f, 1f, Mathf.Clamp01((progress - 0.96f) / 0.18f));
            UpdateTornadoFrontBands(
                frontWindGlows,
                frontWindCores,
                center,
                cameraRight,
                cameraUp,
                cameraForward,
                elapsed,
                frontWindReveal,
                frontWindFade,
                colors);
            if (!wildWardenPalette)
            {
                UpdateTornadoFrontMist(
                    frontWindMist,
                    center,
                    cameraRight,
                    cameraUp,
                    cameraForward,
                    elapsed,
                    frontWindReveal,
                    frontWindFade);
                UpdateTornadoAuroraCards(
                    frontAuroraCards,
                    center,
                    cameraRight,
                    cameraUp,
                    cameraForward,
                    elapsed,
                    frontWindReveal,
                    frontWindFade);
                UpdateTornadoSplashCards(
                    frontWindSplashes,
                    center,
                    cameraRight,
                    cameraUp,
                    cameraForward,
                    elapsed,
                    frontWindReveal,
                    frontWindFade);
                var denseBurstReveal = EaseOutCubic(Mathf.Clamp01((progress - 0.24f) / 0.14f));
                var denseBurstFade = 1f - Mathf.SmoothStep(0f, 1f,
                    Mathf.Clamp01((progress - 0.98f) / 0.20f));
                UpdateColoredBurstCards(
                    frontStormBurstFlames,
                    frontStormBurstSmoke,
                    center,
                    cameraRight,
                    cameraUp,
                    cameraForward,
                    elapsed,
                    denseBurstReveal,
                    denseBurstFade,
                    new[]
                    {
                        new Color(0.02f, 0.30f, 0.96f),
                        new Color(0.08f, 0.68f, 1f),
                        new Color(0.12f, 0.92f, 0.84f),
                        new Color(0.38f, 0.18f, 0.98f),
                        new Color(0.82f, 0.98f, 1f)
                    },
                    new Color(0.06f, 0.18f, 0.62f),
                    1.28f,
                    3);
            }

            if (stormBurstPlayed)
            {
                var impactAge = Mathf.Clamp01((progress - 0.28f) / 0.38f);
                UpdateImpactRays(
                    impactRays,
                    impactRayDirections,
                    center,
                    impactAge,
                    new Color(0.04f, 0.44f, 1f),
                    new Color(0.84f, 0.99f, 1f));
            }

            if (progress >= 0.48f)
                rift.StopRoot();

            if (!stormBurstPlayed && progress >= 0.28f)
            {
                stormBurstPlayed = true;
                if (!wildWardenPalette)
                {
                    stormBurst = Play(
                        curtainExplosion ?? mask ?? darkRift,
                        center + Vector3.up * 0.42f + cameraForward * -0.20f,
                        Vector3.one * 0.10f,
                        new Color(0.34f, 0.78f, 1f),
                        1.20f);
                }
                CreateImpactRays(
                    root.transform,
                    center,
                    cameraRight,
                    cameraUp,
                    cameraForward,
                    impactRays,
                    impactRayDirections,
                    new Color(0.04f, 0.44f, 1f),
                    new Color(0.84f, 0.99f, 1f),
                    4440,
                    "storm energy");
                CreateSparkBurst(root.transform, center, new Color(0.18f, 0.78f, 1f), 104, 2.0f, 6.2f, 0.060f);
                CreateSparkBurst(root.transform, center, new Color(0.66f, 0.30f, 1f), 58, 1.1f, 3.4f, 0.044f);
            }
            if (progress >= 0.68f)
                stormBurst.StopRoot();

            if (wildWardenPalette)
                TintRootMaterials(root);

            yield return null;
        }

        StopRoot(rift);
        StopRoot(stormBurst);
        yield return WaitFor(id, 0.20f);
        FinishPresentation(root, id);
    }

    IEnumerator PlayWildWardenReference(Func<Vector3> target)
    {
        var id = ++playbackID;
        StopActiveEffects();
        playing = true;

        var camera = Camera.main;
        var cameraForward = camera != null ? camera.transform.forward : Vector3.forward;
        var cameraRight = camera != null ? camera.transform.right : Vector3.right;
        var cameraUp = camera != null ? camera.transform.up : Vector3.up;
        var root = CreateRoot("VFX · Wild Warden · 原野风暴");
        var center = ResolveTarget(target) + Vector3.up * 0.02f;
        var palette = new[]
        {
            new Color(0.46f, 0.96f, 0.62f),
            new Color(1.00f, 0.82f, 0.24f),
            new Color(0.92f, 1.00f, 0.88f),
            new Color(0.035f, 0.34f, 0.13f),
            new Color(0.68f, 1.00f, 0.34f),
            new Color(1.00f, 0.96f, 0.72f)
        };

        // The reference silhouette is one connected, translucent wind mass.
        // A hand-painted authored body owns the readable silhouette. The
        // procedural volumes stay behind it only as animated depth, avoiding
        // both a static card and the rigid crossed-line cage from the old setup.
        var outerVolume = CreateProceduralVolumeSprite(
            root.transform,
            "VFX Wild Warden outer wind veil",
            cloudNoiseTexture != null ? cloudNoiseTexture : flowNoiseTexture,
            4250,
            "Mindstone/Mistport Wind Volume");
        var bodyVolume = CreateProceduralVolumeSprite(
            root.transform,
            "VFX Wild Warden connected body",
            flowNoiseTexture != null ? flowNoiseTexture : cloudNoiseTexture,
            4260,
            "Mindstone/Mistport Wind Volume");
        var innerVolume = CreateProceduralVolumeSprite(
            root.transform,
            "VFX Wild Warden luminous inner current",
            cloudNoiseTexture != null ? cloudNoiseTexture : flowNoiseTexture,
            4270,
            "Mindstone/Mistport Wind Volume");
        var authoredOuter = CreateReferenceFlowSprite(
            root.transform,
            "VFX Wild Warden authored outer curtain",
            wildWardenWindColumnTexture,
            flowNoiseTexture != null ? flowNoiseTexture : cloudNoiseTexture,
            4290,
            0.10f,
            0f,
            0.92f);
        var authoredBody = CreateReferenceFlowSprite(
            root.transform,
            "VFX Wild Warden authored wind canopy",
            wildWardenWindColumnTexture,
            flowNoiseTexture != null ? flowNoiseTexture : cloudNoiseTexture,
            4310,
            0.24f,
            0f,
            0.78f);
        var authoredInner = CreateReferenceFlowSprite(
            root.transform,
            "VFX Wild Warden authored inner spiral",
            wildWardenWindColumnTexture,
            flowNoiseTexture != null ? flowNoiseTexture : cloudNoiseTexture,
            4330,
            0.72f,
            0f,
            0.86f);

        var brokenRings = new List<MeshRenderer>();
        for (var index = 0; index < 2; index++)
            brokenRings.Add(CreateReferenceFlowSprite(
                root.transform,
                $"VFX Wild Warden broken orbit {index + 1}",
                brokenShockwaveTexture != null ? brokenShockwaveTexture : shockwaveTexture,
                flowNoiseTexture,
                4380 + index,
                1f,
                0f));

        var motes = new List<MeshRenderer>();
        for (var index = 0; index < 16; index++)
            motes.Add(CreateFrontOrganicSprite(
                root.transform,
                $"VFX Wild Warden leaf mote {index + 1}",
                featherTexture,
                4450 + index,
                index % 16));

        var core = CreateBillboardSprite(
            root.transform,
            "VFX Wild Warden living core glow",
            fireBlurTexture,
            center,
            Color.clear,
            4490,
            256);
        var coreSpark = CreateBillboardSprite(
            root.transform,
            "VFX Wild Warden living core spark",
            fireBlurTexture,
            center,
            Color.clear,
            4500,
            256);

        var elapsed = 0f;
        const float duration = 2.16f;
        while (elapsed < duration && id == playbackID)
        {
            elapsed += Time.deltaTime;
            var progress = Mathf.Clamp01(elapsed / duration);
            center = ResolveTarget(target) + Vector3.up * 0.02f;
            // A slower base-up reveal makes the wind column readable as an
            // animated spell instead of presenting the completed illustration
            // on the first frame.
            var reveal = Mathf.SmoothStep(0f, 1f, Mathf.Clamp01(progress / 0.32f));
            var fade = 1f - Mathf.SmoothStep(0f, 1f, Mathf.Clamp01((progress - 0.80f) / 0.20f));
            var impactReveal = EaseOutCubic(Mathf.Clamp01((progress - 0.08f) / 0.27f));
            var impactFade = 1f - Mathf.SmoothStep(0f, 1f, Mathf.Clamp01((progress - 0.86f) / 0.14f));
            var verticalReveal = Mathf.Lerp(0.16f, 1f, reveal);
            var widthReveal = Mathf.Lerp(0.70f, 1f, reveal);
            var basePosition = center + cameraUp * -0.86f;
            var breathe = 1f + Mathf.Sin(elapsed * 5.4f) * 0.052f;
            // The authored v2 layers now provide all visible depth. Keep the
            // procedural volumes only as a texture-missing fallback; their
            // dark torn edge polluted the pale reference palette.
            var supportOpacity = authoredBody != null ? 0f : 1f;

            UpdateProceduralVolumeSprite(
                outerVolume,
                basePosition + cameraUp * (1.38f * verticalReveal) + cameraForward * -0.88f,
                camera,
                Mathf.Sin(elapsed * 1.25f) * 3.0f,
                new Vector3(2.36f * widthReveal, 2.90f * verticalReveal, 1f),
                fade * reveal * 0.40f * supportOpacity,
                new Color(0.94f, 1.00f, 0.95f),
                elapsed * 4.1f,
                0.88f,
                0.16f,
                0.085f);
            UpdateProceduralVolumeSprite(
                bodyVolume,
                basePosition + cameraUp * (1.24f * verticalReveal) + cameraForward * -0.94f,
                camera,
                -Mathf.Sin(elapsed * 1.08f) * 2.0f,
                new Vector3(1.94f * widthReveal * breathe, 2.62f * verticalReveal, 1f),
                fade * reveal * 0.54f * supportOpacity,
                new Color(0.88f, 1.00f, 0.92f),
                elapsed * 5.3f + 1.7f,
                1.02f,
                0.46f,
                0.075f);
            UpdateProceduralVolumeSprite(
                innerVolume,
                basePosition + cameraUp * (1.02f * verticalReveal) + cameraForward * -1.02f,
                camera,
                Mathf.Sin(elapsed * 1.7f) * 1.4f,
                new Vector3(1.28f * widthReveal, 2.10f * verticalReveal, 1f),
                impactFade * impactReveal * 0.68f * supportOpacity,
                new Color(1.00f, 0.98f, 0.76f),
                elapsed * 6.4f + 3.1f,
                1.18f,
                1.00f,
                0.060f);

            UpdateReferenceFlowSprite(
                authoredOuter,
                basePosition + cameraUp * (1.52f * verticalReveal) + cameraForward * -1.04f,
                camera,
                -Mathf.Sin(elapsed * 1.22f + 0.7f) * 4.2f,
                new Vector3(
                    2.50f * widthReveal * (2f - breathe),
                    3.04f * verticalReveal,
                    1f),
                fade * reveal * 0.42f,
                new Color(0.94f, 1.00f, 0.92f),
                -elapsed * 5.8f + 2.4f,
                0.064f,
                0.24f);
            UpdateReferenceFlowSprite(
                authoredBody,
                basePosition + cameraUp * (1.47f * verticalReveal) + cameraForward * -1.10f,
                camera,
                Mathf.Sin(elapsed * 1.45f) * 2.6f,
                new Vector3(
                    2.34f * widthReveal * breathe,
                    2.94f * verticalReveal,
                    1f),
                fade * reveal * 0.82f,
                Color.white,
                elapsed * 4.8f,
                0.036f,
                0.12f);
            UpdateReferenceFlowSprite(
                authoredInner,
                basePosition + cameraUp * (1.40f * verticalReveal) + cameraForward * -1.18f,
                camera,
                -Mathf.Sin(elapsed * 1.72f + 1.2f) * 3.4f,
                new Vector3(
                    2.06f * widthReveal * (0.98f + Mathf.Sin(elapsed * 6.2f) * 0.035f),
                    2.80f * verticalReveal,
                    1f),
                impactFade * impactReveal * 0.36f,
                new Color(1.00f, 0.98f, 0.72f),
                -elapsed * 7.2f + 4.1f,
                0.052f,
                0.18f);

            UpdateWildWardenReferenceRings(
                brokenRings,
                center,
                cameraForward,
                cameraUp,
                elapsed,
                impactReveal,
                impactFade,
                palette);

            UpdateWildWardenReferenceLeaves(
                motes,
                center,
                cameraRight,
                cameraUp,
                cameraForward,
                elapsed,
                impactReveal,
                impactFade,
                palette);

            var corePulse = 0.92f + Mathf.Sin(elapsed * 18f) * 0.08f;
            UpdateWindSprite(
                core,
                center + cameraUp * -0.58f + cameraForward * -1.10f,
                camera,
                elapsed * 38f,
                new Vector3(0.72f, 0.46f, 1f) * impactReveal * corePulse,
                impactFade * 0.52f * impactReveal,
                new Color(1.00f, 0.82f, 0.22f));
            UpdateWindSprite(
                coreSpark,
                center + cameraUp * -0.56f + cameraForward * -1.16f,
                camera,
                -elapsed * 62f,
                new Vector3(0.34f, 0.28f, 1f) * impactReveal * corePulse,
                impactFade * 0.90f * impactReveal,
                new Color(1f, 0.92f, 0.34f));

            yield return null;
        }

        yield return WaitFor(id, 0.12f);
        FinishPresentation(root, id);
    }

    /// <summary>
    /// A direct, readable sword-qi projectile. The old animal silhouette and
    /// this effect share the same enemy-to-player timing, but the travelling
    /// object is now a layered sword shape with a clear tip, guard, handle,
    /// motion trails, and a front-loaded impact burst. It intentionally uses
    /// meshes, ribbons, and front occlusion cards instead of a particle cloud
    /// so the blade remains legible until the instant it covers the player.
    /// </summary>
    public IEnumerator PlaySwordQi(Func<Vector3> source, Func<Vector3> target)
    {
        yield return PlaySwordQiCore(source, target, false);
    }

    /// <summary>
    /// Fire Elementalist variant: reuse the approved continuous travel and
    /// impact timing, but carry the approved native FireBall as one short
    /// crossfaded projectile chain, add a lifted aerial arc, and reinforce
    /// contact with the authored fire layer. The approved sword-qi
    /// presentation remains unchanged.
    /// </summary>
    public IEnumerator PlayFireElementalist(Func<Vector3> source, Func<Vector3> target)
    {
        yield return PlayFireElementalistReference(source, target);
    }

    IEnumerator PlayFireElementalistReference(
        Func<Vector3> source,
        Func<Vector3> target)
    {
        var id = ++playbackID;
        StopActiveEffects();
        playing = true;

        var camera = Camera.main;
        var cameraForward = camera != null ? camera.transform.forward : Vector3.forward;
        var cameraRight = camera != null ? camera.transform.right : Vector3.right;
        var cameraUp = camera != null ? camera.transform.up : Vector3.up;
        var root = CreateRoot("VFX · Fire Elementalist · 火焰风暴");
        var destination = ResolveTarget(target);
        var sourcePosition = source != null
            ? source()
            : destination + cameraUp * 1.80f;
        sourcePosition += cameraForward * -0.34f;
        var palette = new[]
        {
            new Color(0.52f, 0.006f, 0.002f),
            new Color(0.92f, 0.025f, 0.004f),
            new Color(1.00f, 0.20f, 0.008f),
            new Color(1.00f, 0.62f, 0.06f),
            new Color(1.00f, 0.94f, 0.46f)
        };

        var travelGlows = new List<LineRenderer>();
        var travelCores = new List<LineRenderer>();
        for (var index = 0; index < 4; index++)
        {
            travelGlows.Add(CreateFrontRibbon(root.transform, 0.14f - index * 0.018f, 30, 4420 + index));
            travelCores.Add(CreateFrontRibbon(root.transform, 0.032f - index * 0.003f, 30, 4460 + index));
        }
        var travelFlames = new List<MeshRenderer>();
        for (var index = 0; index < 1; index++)
            travelFlames.Add(CreateReferenceFlowSprite(
                root.transform,
                $"VFX Fire Elementalist travel tongue {index + 1}",
                fireSingleTexture != null ? fireSingleTexture : flameTexture,
                flowNoiseTexture,
                4480 + index,
                1f));
        var travelCore = CreateReferenceFlowSprite(
            root.transform,
            "VFX Fire Elementalist traveling hot mass",
            fireBlurTexture,
            flowNoiseTexture,
            4520,
            1f);

        var impactFlames = new List<MeshRenderer>();
        for (var index = 0; index < 1; index++)
            impactFlames.Add(CreateReferenceFlowSprite(
                root.transform,
                $"VFX Fire Elementalist impact flame {index + 1}",
                fireSingleTexture != null ? fireSingleTexture : flameTexture,
                flowNoiseTexture,
                4540 + index,
                1f));
        var impactSmoke = new List<MeshRenderer>();
        // FractalNoise_4 is useful as a mask, but as a full-screen quad it
        // reads as a rectangle. The procedural volume below already owns
        // the smoke veil, so keep this auxiliary list empty.
        var impactArcs = new List<LineRenderer>();
        for (var index = 0; index < 2; index++)
            impactArcs.Add(CreateFrontRibbon(root.transform, 0.20f - index * 0.018f, 32, 4590 + index));
        // Do not use Shock_wave004 as a visible oval here. The reference
        // reads as a broad fire mass with curved tongues, not a magic ring.
        MeshRenderer groundRing = null;
        var impactCore = CreateProceduralVolumeSprite(
            root.transform,
            "VFX Fire Elementalist white hot center",
            flowNoiseTexture,
            4630,
            "Mindstone/Mistport Fire Volume",
            fireBurstTexture);
        var impactHot = CreateProceduralVolumeSprite(
            root.transform,
            "VFX Fire Elementalist white hot spark",
            flowNoiseTexture,
            4640,
            "Mindstone/Mistport Fire Volume",
            fireBurstTexture);
        var impactMass = CreateProceduralVolumeSprite(
            root.transform,
            "VFX Fire Elementalist continuous impact mass",
            flowNoiseTexture,
            4525,
            "Mindstone/Mistport Fire Volume",
            fireBurstTexture);
        var impactMassCore = CreateProceduralVolumeSprite(
            root.transform,
            "VFX Fire Elementalist continuous impact core mass",
            flowNoiseTexture,
            4535,
            "Mindstone/Mistport Fire Volume",
            fireBurstTexture);

        CreateWindParticles(root.transform, destination, new Color(1f, 0.24f, 0.02f), 22);

        var elapsed = 0f;
        // The impact must have a readable hold. The old 1.92s timeline
        // started fading while the projectile was still visually arriving,
        // which is why the board looked empty in its later review frames.
        const float duration = 2.30f;
        while (elapsed < duration && id == playbackID)
        {
            elapsed += Time.deltaTime;
            var progress = Mathf.Clamp01(elapsed / duration);
            destination = ResolveTarget(target);
            var currentSource = source != null ? source() : sourcePosition;
            currentSource += cameraForward * -0.34f;
            var flight = Mathf.SmoothStep(0f, 1f, Mathf.Clamp01((progress - 0.04f) / 0.50f));
            var travelReveal = EaseOutCubic(Mathf.Clamp01((progress - 0.03f) / 0.16f));
            var travelFade = 1f - Mathf.SmoothStep(0f, 1f, Mathf.Clamp01((progress - 0.43f) / 0.15f));
            var impactReveal = EaseOutCubic(Mathf.Clamp01((progress - 0.40f) / 0.18f));
            var impactFade = 1f - Mathf.SmoothStep(0f, 1f, Mathf.Clamp01((progress - 0.84f) / 0.44f));

            UpdateFireElementalistReferenceTravel(
                travelGlows,
                travelCores,
                travelFlames,
                travelCore,
                currentSource,
                destination,
                camera,
                cameraRight,
                cameraUp,
                cameraForward,
                elapsed,
                flight,
                travelReveal,
                travelFade,
                palette);
            UpdateFireElementalistReferenceImpact(
                impactFlames,
                impactSmoke,
                impactArcs,
                groundRing,
                impactCore,
                impactHot,
                impactMass,
                impactMassCore,
                destination,
                camera,
                cameraRight,
                cameraUp,
                cameraForward,
                elapsed,
                impactReveal,
                impactFade,
                palette);

            yield return null;
        }

        yield return WaitFor(id, 0.14f);
        FinishPresentation(root, id);
    }

    IEnumerator PlaySwordQiCore(
        Func<Vector3> source,
        Func<Vector3> target,
        bool fireElementalist)
    {
        var id = ++playbackID;
        StopActiveEffects();
        playing = true;

        var camera = Camera.main;
        var cameraForward = camera != null ? camera.transform.forward : Vector3.forward;
        var cameraRight = camera != null ? camera.transform.right : Vector3.right;
        var cameraUp = camera != null ? camera.transform.up : Vector3.up;
        var root = CreateRoot(fireElementalist
            ? "VFX · 火元素师 · 空袭爆炎"
            : "VFX · 剑气 · 破空斩");
        var destination = ResolveTarget(target);
        var sourcePosition = source != null
            ? source()
            : destination + cameraUp * 1.80f;
        sourcePosition += cameraForward * -0.34f
            + (fireElementalist ? cameraUp * 0.16f : Vector3.zero);

        var travelAxis = Vector3.ProjectOnPlane(destination - sourcePosition, cameraForward);
        if (travelAxis.sqrMagnitude < 0.0001f)
            travelAxis = -cameraUp;
        travelAxis.Normalize();
        var screenRoll = Vector3.SignedAngle(cameraUp, travelAxis, cameraForward);

        var palette = fireElementalist
            ? new[]
            {
                new Color(0.62f, 0.008f, 0.002f),
                new Color(0.98f, 0.045f, 0.004f),
                new Color(1.00f, 0.30f, 0.012f),
                new Color(1.00f, 0.90f, 0.38f)
            }
            : new[]
            {
                new Color(0.96f, 0.025f, 0.055f),
                new Color(1.00f, 0.16f, 0.025f),
                new Color(1.00f, 0.56f, 0.075f),
                new Color(1.00f, 0.88f, 0.44f)
            };

        var swordQiTexture = swordQiSlashTexture != null ? swordQiSlashTexture : slashTexture;
        var projectileTexture = fireElementalist && fireBlurTexture != null
            ? fireBlurTexture
            : swordQiTexture;
        var swordGlow = CreateFrontOrganicSprite(
            root.transform,
            "VFX sword qi generated ember halo",
            projectileTexture,
            4458);
        var swordBody = CreateFrontOrganicSprite(
            root.transform,
            "VFX sword qi generated torn blade",
            projectileTexture,
            4468);
        var swordCore = CreateFrontOrganicSprite(
            root.transform,
            "VFX sword qi generated hot edge",
            projectileTexture,
            4476);
        var travelSlash = CreateBillboardSprite(
            root.transform,
            "VFX sword qi torn travel mark",
            slashTexture,
            sourcePosition,
            new Color(1f, 0.08f, 0.02f, 0f),
            4448,
            256);
        var travelSlashEcho = CreateBillboardSprite(
            root.transform,
            "VFX sword qi red travel echo",
            slashTexture,
            sourcePosition,
            new Color(0.88f, 0.015f, 0.12f, 0f),
            4446,
            256);

        var trailGlows = new List<LineRenderer>();
        var trailCores = new List<LineRenderer>();
        for (var i = 0; i < palette.Length - 1; i++)
        {
            trailGlows.Add(CreateRibbon(
                root.transform,
                fireElementalist
                    ? 0.235f - i * 0.030f
                    : 0.17f - i * 0.025f,
                palette[i],
                28,
                4420 + i));
            trailCores.Add(CreateRibbon(
                root.transform,
                fireElementalist
                    ? 0.052f - i * 0.006f
                    : 0.038f - i * 0.005f,
                palette[3],
                28,
                4430 + i));
        }

        var chargeGlow = CreateBillboardSprite(
            root.transform,
            "VFX sword qi enemy charge glow",
            fireBlurTexture,
            sourcePosition,
            new Color(1f, 0.08f, 0.02f, 0f),
            4408,
            320);
        var chargeCore = CreateBillboardSprite(
            root.transform,
            "VFX sword qi enemy charge core",
            fireBlurTexture,
            sourcePosition,
            new Color(1f, 0.76f, 0.22f, 0f),
            4410,
            384);

        var impactSlash = CreateBillboardSprite(
            root.transform,
            "VFX sword qi impact slash",
            slashTexture,
            destination,
            new Color(1f, 0.08f, 0.02f, 0f),
            4480,
            256);
        var impactSlashEcho = CreateBillboardSprite(
            root.transform,
            "VFX sword qi impact slash echo",
            slashTexture,
            destination,
            new Color(0.88f, 0.02f, 0.16f, 0f),
            4479,
            256);
        var impactSlashCore = CreateBillboardSprite(
            root.transform,
            "VFX sword qi impact white cut",
            slashTexture,
            destination,
            new Color(1f, 0.86f, 0.36f, 0f),
            4482,
            256);
        var impactEnergy = CreateBillboardSprite(
            root.transform,
            "VFX sword qi impact ember mass",
            fireBlurTexture,
            destination + cameraForward * -0.36f,
            new Color(1f, 0.045f, 0.015f, 0f),
            4490,
            256);
        var impactEnergyCore = CreateBillboardSprite(
            root.transform,
            "VFX sword qi impact gold core",
            fireBlurTexture,
            destination + cameraForward * -0.44f,
            new Color(1f, 0.72f, 0.18f, 0f),
            4492,
            320);
        var impactEnergyEcho = CreateBillboardSprite(
            root.transform,
            "VFX sword qi impact crimson echo",
            fireBlurTexture,
            destination + cameraRight * 0.12f + cameraForward * -0.54f,
            new Color(0.84f, 0.015f, 0.18f, 0f),
            4489,
            288);
        var floorShock = CreateBillboardSprite(
            root.transform,
            "VFX sword qi impact floor shock",
            shockwaveTexture,
            destination + Vector3.up * 0.02f + cameraForward * -0.18f,
            new Color(1f, 0.20f, 0.025f, 0f),
            4486,
            256);
        var impactCover = CreateCoverSprite(
            root.transform,
            "VFX sword qi impact red cover",
            CreateImpactCoverTexture(),
            destination + Vector3.up * 0.08f + cameraForward * -0.60f,
            new Color(0.92f, 0.03f, 0.08f, 0f),
            4495,
            128);
        var impactCoverCore = CreateCoverSprite(
            root.transform,
            "VFX sword qi impact gold cover",
            CreateImpactCoverTexture(),
            destination + Vector3.up * 0.08f + cameraForward * -0.70f,
            new Color(1f, 0.52f, 0.08f, 0f),
            4497,
            128);

        var impactArcs = new List<LineRenderer>
        {
            CreateSlashArc(root.transform, 0.15f, new Color(1f, 0.08f, 0.02f), 4500),
            CreateSlashArc(root.transform, 0.10f, new Color(0.94f, 0.02f, 0.18f), 4501),
            CreateSlashArc(root.transform, 0.055f, new Color(1f, 0.82f, 0.28f), 4502)
        };

        var frontSlashCards = new List<MeshRenderer>();
        for (var i = 0; i < 10; i++)
            frontSlashCards.Add(CreateFrontOrganicSprite(
                root.transform,
                $"VFX sword qi front slash fragment {i + 1}",
                i % 3 == 0 ? flameTexture : splashTexture,
                4510 + i,
                i % 4));
        var burstFlames = new List<MeshRenderer>();
        for (var i = 0; i < 18; i++)
            burstFlames.Add(CreateFrontOrganicSprite(
                root.transform,
                $"VFX sword qi impact flame {i + 1}",
                flameTexture,
                4530 + i,
                i % 4));
        var burstSmoke = new List<MeshRenderer>();
        for (var i = 0; i < 8; i++)
            burstSmoke.Add(CreateFrontOrganicSprite(
                root.transform,
                $"VFX sword qi impact smoke {i + 1}",
                smokeTexture,
                4550 + i,
                i % 4));

        var fireFrontGlows = new List<LineRenderer>();
        var fireFrontCores = new List<LineRenderer>();
        if (fireElementalist)
        {
            for (var i = 0; i < 7; i++)
            {
                fireFrontGlows.Add(CreateFrontRibbon(
                    root.transform,
                    0.20f - i * 0.018f,
                    36,
                    4570 + i));
                fireFrontCores.Add(CreateFrontRibbon(
                    root.transform,
                    0.046f - i * 0.004f,
                    36,
                    4580 + i));
            }
        }

        var impactRays = new List<LineRenderer>();
        var impactRayDirections = new List<Vector3>();
        var impactPlayed = false;
        // Keep the flight visually self-contained. The imported FireOnly
        // layer is intentionally not spawned as a charge because it is the
        // source of the detached pale strips in the early review frame.
        var elementalCharge = default(EffekseerHandle);
        var elementalImpact = default(EffekseerHandle);
        var fireTravelSegments = new List<NativeFireballSegment>(4);
        var fireTravelRefreshElapsed = 0f;
        void SpawnFireTravelSegment(Vector3 position, Vector3 direction, float scale)
        {
            if (!fireElementalist || fireball == null)
                return;

            var segment = new NativeFireballSegment
            {
                handle = Play(
                    fireball,
                    position,
                    Vector3.one * scale,
                    Color.white,
                    1.20f),
                age = 0f,
                rootStopped = false
            };
            if (direction.sqrMagnitude > 0.0001f)
                segment.handle.SetRotation(Quaternion.FromToRotation(Vector3.up, direction.normalized));
            segment.handle.SetAllColor(new Color(1f, 1f, 1f, 0f));
            fireTravelSegments.Add(segment);
        }
        void StopFireTravelSegments()
        {
            for (var index = 0; index < fireTravelSegments.Count; index++)
                fireTravelSegments[index].handle.Stop();
            fireTravelSegments.Clear();
        }
        if (fireElementalist)
            SpawnFireTravelSegment(sourcePosition, destination - sourcePosition, 0.080f);
        var elapsed = 0f;
        var duration = fireElementalist ? 2.18f : 1.92f;
        var styleScale = fireElementalist ? 1.18f : 1f;

        while (elapsed < duration && id == playbackID)
        {
            elapsed += Time.deltaTime;
            var progress = Mathf.Clamp01(elapsed / duration);
            destination = ResolveTarget(target);

            var currentSource = source != null ? source() : sourcePosition;
            currentSource += cameraForward * -0.34f;
            var liveAxis = Vector3.ProjectOnPlane(destination - currentSource, cameraForward);
            if (liveAxis.sqrMagnitude > 0.0001f)
                liveAxis.Normalize();
            else
                liveAxis = travelAxis;
            var liveRoll = Vector3.SignedAngle(cameraUp, liveAxis, cameraForward);

            var flight = Mathf.SmoothStep(
                0f,
                1f,
                Mathf.Clamp01((progress - 0.07f) / 0.49f));
            var bladePosition = Vector3.Lerp(currentSource, destination, flight)
                + cameraUp * Mathf.Sin(flight * Mathf.PI)
                * (fireElementalist ? 0.34f : 0.12f);
            var bladeReveal = Mathf.Clamp01(
                EaseOutBack(Mathf.Clamp01((progress - 0.04f) / 0.18f)));
            var bladeFade = 1f - Mathf.SmoothStep(
                0f,
                1f,
                Mathf.Clamp01((progress - 0.49f) / 0.15f));
            var swordAlpha = bladeReveal * bladeFade;
            var slashPulse = 0.94f + Mathf.Sin(elapsed * 17f) * 0.06f;
            var swordRoll = Mathf.Lerp(-26f, 24f, flight)
                + Mathf.Sin(elapsed * 15f) * 5.0f
                + Mathf.Sin(elapsed * 6.5f) * 3.0f;
            if (fireElementalist)
                swordRoll += Mathf.Sin(elapsed * 8.5f) * 12f;

            if (fireElementalist)
            {
                var fireBallPosition = bladePosition + cameraForward * -0.22f;
                var fireBallScale = Mathf.Lerp(0.080f, 0.30f, flight) * styleScale;
                var fireTravelDelta = Mathf.Max(Time.deltaTime, 1f / 120f);
                fireTravelRefreshElapsed += fireTravelDelta;
                if (fireTravelRefreshElapsed >= 0.085f)
                {
                    do
                    {
                        fireTravelRefreshElapsed -= 0.085f;
                    }
                    while (fireTravelRefreshElapsed >= 0.085f);
                    SpawnFireTravelSegment(
                        fireBallPosition,
                        destination - currentSource,
                        fireBallScale);
                }

                for (var segmentIndex = fireTravelSegments.Count - 1;
                     segmentIndex >= 0;
                     segmentIndex--)
                {
                    var segment = fireTravelSegments[segmentIndex];
                    segment.age += fireTravelDelta;
                    var fadeIn = Mathf.SmoothStep(
                        0f,
                        1f,
                        Mathf.Clamp01(segment.age / 0.045f));
                    var fadeOut = 1f - Mathf.SmoothStep(
                        0f,
                        1f,
                        Mathf.InverseLerp(0.15f, 0.25f, segment.age));
                    segment.handle.SetAllColor(new Color(1f, 1f, 1f, fadeIn * fadeOut));
                    if (!segment.rootStopped && segment.age >= 0.15f)
                    {
                        segment.handle.StopRoot();
                        segment.rootStopped = true;
                    }
                    if (segment.age >= 0.25f)
                    {
                        segment.handle.Stop();
                        fireTravelSegments.RemoveAt(segmentIndex);
                    }
                }
            }

            if (!fireElementalist)
            {
                UpdateWindSprite(
                    swordGlow,
                    bladePosition + cameraForward * -1.20f,
                    camera,
                    liveRoll + 180f + swordRoll,
                    new Vector3(1.38f, 3.06f, 1f) * slashPulse * styleScale,
                    swordAlpha * 0.46f,
                    new Color(1f, 0.035f, 0.012f));
                UpdateWindSprite(
                    swordBody,
                    bladePosition + cameraForward * -1.23f,
                    camera,
                    liveRoll + 180f + swordRoll,
                    new Vector3(1.24f, 2.84f, 1f) * slashPulse * styleScale,
                    swordAlpha * 0.84f,
                    Color.white);
                UpdateWindSprite(
                    swordCore,
                    bladePosition + cameraForward * -1.26f,
                    camera,
                    liveRoll + 180f + swordRoll + 1.5f,
                    new Vector3(1.18f, 2.76f, 1f) * slashPulse * styleScale,
                    swordAlpha * 0.60f,
                    new Color(1f, 0.70f, 0.24f));

                UpdateWindSprite(
                    travelSlash,
                    bladePosition + cameraForward * 0.02f,
                    camera,
                    liveRoll + swordRoll,
                    new Vector3(1.22f, 2.42f, 1f) * bladeReveal,
                    swordAlpha * 0.22f,
                    new Color(1f, 0.06f, 0.015f));
                UpdateWindSprite(
                    travelSlashEcho,
                    bladePosition + cameraRight * 0.08f + cameraForward * 0.04f,
                    camera,
                    liveRoll + swordRoll + 7f,
                    new Vector3(1.08f, 2.15f, 1f) * bladeReveal,
                    swordAlpha * 0.30f,
                    new Color(0.86f, 0.015f, 0.15f));
            }

            for (var i = 0; i < trailGlows.Count; i++)
            {
                var head = Mathf.Clamp01(flight - i * 0.06f);
                var tail = Mathf.Clamp01(head - 0.39f - i * 0.035f);
                UpdateWarmRibbonPair(
                    trailGlows[i],
                    trailCores[i],
                    currentSource,
                    destination,
                    tail,
                    head,
                    cameraRight,
                    cameraUp,
                    cameraForward,
                    elapsed,
                    i,
                    palette[i],
                    swordAlpha * 0.86f);
            }

            var chargeReveal = 1f - Mathf.SmoothStep(
                0f,
                1f,
                Mathf.Clamp01((progress - 0.02f) / 0.18f));
            UpdateWindSprite(
                chargeGlow,
                currentSource + cameraForward * -0.08f,
                camera,
                elapsed * -28f,
                new Vector3(0.38f, 0.46f, 1f) * (0.68f + chargeReveal * 0.32f),
                chargeReveal * 0.38f,
                new Color(1f, 0.08f, 0.02f));
            UpdateWindSprite(
                chargeCore,
                currentSource + cameraForward * -0.12f,
                camera,
                elapsed * 34f,
                new Vector3(0.22f, 0.32f, 1f),
                chargeReveal * 0.52f,
                new Color(1f, 0.76f, 0.20f));
            var impactReveal = EaseOutCubic(Mathf.Clamp01((progress - 0.50f) / 0.12f));
            var impactFade = 1f - Mathf.SmoothStep(
                0f,
                1f,
                Mathf.Clamp01((progress - 0.72f) / 0.30f));
            if (!fireElementalist)
            {
                UpdateWindSprite(
                    impactSlash,
                    destination + cameraForward * -0.76f,
                    camera,
                    liveRoll - 46f - elapsed * 10f,
                    new Vector3(1.16f, 2.00f, 1f) * impactReveal,
                    impactFade * 0.84f * impactReveal,
                    new Color(1f, 0.05f, 0.015f));
                UpdateWindSprite(
                    impactSlashEcho,
                    destination + cameraRight * -0.12f + cameraForward * -0.82f,
                    camera,
                    liveRoll + 34f + elapsed * 14f,
                    new Vector3(0.98f, 1.78f, 1f) * impactReveal,
                    impactFade * 0.62f * impactReveal,
                    new Color(0.88f, 0.015f, 0.14f));
                UpdateWindSprite(
                    impactSlashCore,
                    destination + cameraForward * -0.90f,
                    camera,
                    liveRoll - 39f,
                    new Vector3(0.38f, 1.82f, 1f) * impactReveal,
                    impactFade * 0.90f * impactReveal,
                    new Color(1f, 0.86f, 0.38f));
            }
            UpdateWindSprite(
                impactEnergy,
                destination + cameraForward * -0.48f + cameraUp * 0.08f,
                camera,
                -elapsed * 30f,
                new Vector3(1.92f, 2.62f, 1f) * impactReveal * styleScale,
                impactFade * 0.76f * impactReveal,
                new Color(1f, 0.045f, 0.012f));
            UpdateWindSprite(
                impactEnergyCore,
                destination + cameraForward * -0.56f + cameraUp * 0.04f,
                camera,
                elapsed * 36f,
                new Vector3(1.30f, 1.92f, 1f) * impactReveal * styleScale,
                impactFade * 0.82f * impactReveal,
                new Color(1f, 0.72f, 0.16f));
            UpdateWindSprite(
                impactEnergyEcho,
                destination + cameraRight * 0.12f + cameraForward * -0.66f,
                camera,
                -elapsed * 42f,
                new Vector3(1.54f, 2.22f, 1f) * impactReveal * styleScale,
                impactFade * 0.48f * impactReveal,
                new Color(0.84f, 0.01f, 0.18f));
            UpdateWindSprite(
                floorShock,
                destination + Vector3.up * 0.02f + cameraForward * -0.25f,
                camera,
                elapsed * -54f,
                new Vector3(
                    Mathf.Lerp(0.12f, 1.62f, EaseOutCubic(Mathf.Clamp01((progress - 0.44f) / 0.56f))),
                    Mathf.Lerp(0.10f, 0.88f, EaseOutCubic(Mathf.Clamp01((progress - 0.44f) / 0.56f))),
                    1f),
                impactFade * 0.38f * impactReveal,
                new Color(1f, 0.22f, 0.025f));
            UpdateWindSprite(
                impactCover,
                destination + Vector3.up * 0.08f + cameraForward * -0.72f,
                camera,
                -elapsed * 36f,
                new Vector3(1.26f, 1.48f, 1f) * impactReveal,
                impactFade * 0.60f * impactReveal,
                new Color(0.92f, 0.025f, 0.07f));
            UpdateWindSprite(
                impactCoverCore,
                destination + Vector3.up * 0.08f + cameraForward * -0.84f,
                camera,
                elapsed * 30f,
                new Vector3(0.92f, 1.12f, 1f) * impactReveal,
                impactFade * 0.48f * impactReveal,
                new Color(1f, 0.52f, 0.08f));

            var frontCutReveal = EaseOutCubic(Mathf.Clamp01((progress - 0.48f) / 0.16f));
            var frontCutFade = 1f - Mathf.SmoothStep(
                0f,
                1f,
                Mathf.Clamp01((progress - 0.76f) / 0.26f));
            if (!fireElementalist)
            {
                UpdateSwordFrontCards(
                    frontSlashCards,
                    destination,
                    cameraRight,
                    cameraUp,
                    cameraForward,
                    elapsed,
                    frontCutReveal,
                    frontCutFade * 0.94f,
                    palette);
                UpdateColoredBurstCards(
                    burstFlames,
                    burstSmoke,
                    destination,
                    cameraRight,
                    cameraUp,
                    cameraForward,
                    elapsed,
                    impactReveal,
                    impactFade,
                    new[]
                    {
                        new Color(0.96f, 0.018f, 0.025f),
                        new Color(1f, 0.10f, 0.012f),
                        new Color(1f, 0.34f, 0.025f),
                        new Color(1f, 0.72f, 0.12f),
                        new Color(1f, 0.92f, 0.52f)
                    },
                    new Color(0.34f, 0.008f, 0.055f),
                    1.26f,
                    2);
            }
            else
            {
                var fireRibbonReveal = EaseOutCubic(Mathf.Clamp01((progress - 0.30f) / 0.18f));
                var fireRibbonFade = 1f - Mathf.SmoothStep(
                    0f,
                    1f,
                    Mathf.Clamp01((progress - 0.82f) / 0.20f));
                var firePalette = new[]
                {
                    new Color(0.80f, 0.012f, 0.002f),
                    new Color(1.00f, 0.08f, 0.004f),
                    new Color(1.00f, 0.34f, 0.012f),
                    new Color(1.00f, 0.82f, 0.18f),
                    new Color(1.00f, 0.98f, 0.68f)
                };
                UpdateTornadoFrontBands(
                    fireFrontGlows,
                    fireFrontCores,
                    destination,
                    cameraRight,
                    cameraUp,
                    cameraForward,
                    elapsed,
                    fireRibbonReveal,
                    fireRibbonFade,
                    firePalette);
            }

            var arcReveal = EaseOutCubic(Mathf.Clamp01((progress - 0.48f) / 0.20f));
            var arcFade = 1f - Mathf.SmoothStep(
                0f,
                1f,
                Mathf.Clamp01((progress - 0.74f) / 0.26f));
            UpdateSlashArc(
                impactArcs[0], destination, cameraRight, cameraUp, cameraForward,
                -144f, -30f, 1.10f, arcReveal, arcFade * 0.94f, elapsed, 0);
            UpdateSlashArc(
                impactArcs[1], destination, cameraRight, cameraUp, cameraForward,
                -132f, -54f, 0.88f, arcReveal, arcFade * 0.78f, elapsed, 1);
            UpdateSlashArc(
                impactArcs[2], destination, cameraRight, cameraUp, cameraForward,
                -156f, -40f, 0.72f, arcReveal, arcFade * 0.96f, elapsed, 2);

            if (impactPlayed)
                UpdateImpactRays(
                    impactRays,
                    impactRayDirections,
                    destination,
                    Mathf.Clamp01((progress - 0.50f) / 0.44f),
                    new Color(1f, 0.10f, 0.015f),
                    new Color(1f, 0.86f, 0.34f));

            if (!impactPlayed && progress >= 0.50f)
            {
                impactPlayed = true;
                StopFireTravelSegments();
                if (fireElementalist)
                {
                    elementalImpact = Play(
                        fireball ?? fireOnly,
                        destination + cameraForward * -0.20f,
                        Vector3.one * 0.12f,
                        new Color(1f, 0.34f, 0.025f),
                        1.18f);
                }
                CreateImpactRays(
                    root.transform,
                    destination,
                    cameraRight,
                    cameraUp,
                    cameraForward,
                    impactRays,
                    impactRayDirections,
                    new Color(1f, 0.10f, 0.015f),
                    new Color(1f, 0.86f, 0.34f),
                    4560,
                    "sword qi impact");
            }

            yield return null;
        }

        StopFireTravelSegments();
        StopRoot(elementalCharge);
        StopRoot(elementalImpact);
        yield return WaitFor(id, 0.20f);
        FinishPresentation(root, id);
    }

    /// <summary>
    /// A readable animal-shaped variant built from particles sampled from the
    /// generated spectral cheetah silhouette. The mask is never rendered as a
    /// card: two independently disturbed particle fields form the hound at
    /// the enemy, travel along the enemy-to-player path, and burst apart on
    /// contact before the dense impact layers take over.
    /// </summary>
    public IEnumerator PlaySpectralHound(Func<Vector3> source, Func<Vector3> target)
    {
        var id = ++playbackID;
        StopActiveEffects();
        playing = true;

        var camera = Camera.main;
        var cameraForward = camera != null ? camera.transform.forward : Vector3.forward;
        var cameraRight = camera != null ? camera.transform.right : Vector3.right;
        var cameraUp = camera != null ? camera.transform.up : Vector3.up;
        var root = CreateRoot("VFX · 幽冥猎犬 · 扑击爆发");
        var destination = ResolveTarget(target);
        var sourcePosition = source != null
            ? source()
            : destination + cameraUp * 1.80f;
        sourcePosition += cameraForward * -0.32f;

        // The generated mask is deliberately vertical: its muzzle and paws
        // sit at local -Y while the tail trails at local +Y. Rotate that
        // silhouette so the head always points along the actual enemy-to-
        // player screen direction, even when the anchors are diagonal.
        var screenTravel = Vector3.ProjectOnPlane(destination - sourcePosition, cameraForward);
        if (screenTravel.sqrMagnitude < 0.0001f)
            screenTravel = -cameraUp;
        screenTravel.Normalize();
        var houndShapeUp = -screenTravel;
        var houndShapeRight = Vector3.Cross(houndShapeUp, cameraForward);
        if (houndShapeRight.sqrMagnitude < 0.0001f)
            houndShapeRight = cameraRight;
        else
            houndShapeRight.Normalize();

        var palette = new[]
        {
            new Color(1f, 0.08f, 0.02f),
            new Color(0.84f, 0.02f, 0.24f),
            new Color(1f, 0.28f, 0.035f),
            new Color(1f, 0.62f, 0.08f)
        };
        var cheetahSprite = CreateCheetahSprite(
            root.transform,
            "VFX spectral cheetah leap",
            4460);

        // Keep the readable action free of the broad ribbon strips that can
        // make a silhouette look like a translucent wall. The impact beat
        // has its own rays and organic front cards instead.
        var frontShroud = new List<LineRenderer>();

        // The generated hound already carries its own torn flame edge and
        // detached shards. Keep the action beat clean; extra cards only
        // compete with the animal read and can look like floating blocks.
        var bodyCards = new List<MeshRenderer>();

        var impactEnergy = CreateBillboardSprite(
            root.transform,
            "VFX spectral hound impact energy",
            fireBlurTexture,
            destination + cameraForward * -0.30f,
            new Color(1f, 0.08f, 0.02f, 0f),
            4490,
            256);
        var impactCore = CreateBillboardSprite(
            root.transform,
            "VFX spectral hound impact core",
            fireBlurTexture,
            destination + cameraForward * -0.38f,
            new Color(1f, 0.72f, 0.16f, 0f),
            4492,
            320);
        var impactEcho = CreateBillboardSprite(
            root.transform,
            "VFX spectral hound impact violet echo",
            fireBlurTexture,
            destination + cameraRight * 0.08f + cameraForward * -0.48f,
            new Color(0.86f, 0.02f, 0.28f, 0f),
            4489,
            288);
        var floorShock = CreateBillboardSprite(
            root.transform,
            "VFX spectral hound floor shock",
            shockwaveTexture,
            destination + Vector3.up * 0.03f + cameraForward * -0.12f,
            new Color(1f, 0.22f, 0.03f, 0f),
            4486,
            256);
        var impactCover = CreateCoverSprite(
            root.transform,
            "VFX spectral hound impact cover",
            CreateImpactCoverTexture(),
            destination + Vector3.up * 0.08f + cameraForward * -0.52f,
            new Color(0.92f, 0.06f, 0.10f, 0f),
            4495,
            128);
        var impactCoverCore = CreateCoverSprite(
            root.transform,
            "VFX spectral hound impact cover core",
            CreateImpactCoverTexture(),
            destination + Vector3.up * 0.08f + cameraForward * -0.62f,
            new Color(1f, 0.54f, 0.12f, 0f),
            4497,
            128);

        var burstFlames = new List<MeshRenderer>();
        for (var i = 0; i < 16; i++)
            burstFlames.Add(CreateFrontOrganicSprite(
                root.transform,
                $"VFX spectral hound impact flame {i + 1}",
                flameTexture,
                4510 + i,
                i % 4));
        var burstSmoke = new List<MeshRenderer>();
        for (var i = 0; i < 8; i++)
            burstSmoke.Add(CreateFrontOrganicSprite(
                root.transform,
                $"VFX spectral hound impact smoke {i + 1}",
                smokeTexture,
                4530 + i,
                i % 4));
        var impactRays = new List<LineRenderer>();
        var impactRayDirections = new List<Vector3>();
        var impactPlayed = false;

        var elapsed = 0f;
        // Keep the full silhouette on screen long enough for the player to
        // read the forepaw motion and the impact cover as separate beats.
        const float duration = 1.92f;
        while (elapsed < duration && id == playbackID)
        {
            elapsed += Time.deltaTime;
            var progress = Mathf.Clamp01(elapsed / duration);
            destination = ResolveTarget(target);

            // Give the cheetah enough travel time to read as one complete
            // animal between the anchors before the contact burst.
            var lunge = Mathf.SmoothStep(
                0f,
                1f,
                Mathf.Clamp01((progress - 0.10f) / 0.50f));
            var cheetahPosition = Vector3.Lerp(sourcePosition, destination, lunge);
            cheetahPosition += cameraUp * Mathf.Sin(lunge * Mathf.PI) * 0.18f;
            var cheetahReveal = Mathf.Lerp(
                0.24f,
                1f,
                EaseOutCubic(Mathf.Clamp01(progress / 0.24f)));
            var cheetahFade = 1f - Mathf.SmoothStep(0f, 1f, Mathf.Clamp01((progress - 0.48f) / 0.16f));
            var cheetahPhase = elapsed * 9.5f;
            UpdateCheetahSprite(
                cheetahSprite,
                cheetahPosition,
                cameraForward,
                houndShapeUp,
                elapsed,
                cheetahReveal,
                cheetahFade,
                1.55f + Mathf.Sin(elapsed * 8f) * 0.05f,
                2.30f + Mathf.Sin(elapsed * 6.5f + 0.7f) * 0.08f,
                Mathf.Sin(elapsed * 7.2f) * 3.5f,
                cheetahPhase,
                Mathf.Clamp01((progress - 0.42f) / 0.16f),
                Mathf.SmoothStep(0f, 1f, Mathf.Clamp01((progress - 0.12f) / 0.24f)));

            var actionReveal = EaseOutCubic(Mathf.Clamp01((progress - 0.04f) / 0.24f));
            var actionFade = 1f - Mathf.SmoothStep(0f, 1f, Mathf.Clamp01((progress - 0.40f) / 0.25f));
            UpdateFrontShroud(
                frontShroud,
                cheetahPosition,
                cameraRight,
                cameraUp,
                cameraForward,
                elapsed,
                actionReveal,
                actionFade * 0.42f,
                0,
                palette);
            UpdateFrontOrganicSprites(
                bodyCards,
                cheetahPosition,
                cameraRight,
                cameraUp,
                cameraForward,
                elapsed,
                actionReveal,
                actionFade * 0.50f,
                1,
                palette);

            var impactReveal = EaseOutCubic(Mathf.Clamp01((progress - 0.50f) / 0.12f));
            var impactFade = 1f - Mathf.SmoothStep(0f, 1f, Mathf.Clamp01((progress - 0.70f) / 0.30f));
            UpdateWindSprite(
                impactEnergy,
                destination + cameraForward * -0.30f,
                camera,
                -elapsed * 30f,
                new Vector3(1.82f, 2.54f, 1f) * impactReveal,
                impactFade * 0.72f * impactReveal,
                new Color(1f, 0.08f, 0.02f));
            UpdateWindSprite(
                impactCore,
                destination + cameraForward * -0.40f,
                camera,
                elapsed * 34f,
                new Vector3(1.22f, 1.84f, 1f) * impactReveal,
                impactFade * 0.80f * impactReveal,
                new Color(1f, 0.72f, 0.16f));
            UpdateWindSprite(
                impactEcho,
                destination + cameraRight * 0.08f + cameraForward * -0.48f,
                camera,
                -elapsed * 42f,
                new Vector3(1.44f, 2.10f, 1f) * impactReveal,
                impactFade * 0.48f * impactReveal,
                new Color(0.86f, 0.02f, 0.28f));
            UpdateWindSprite(
                floorShock,
                destination + Vector3.up * 0.03f + cameraForward * -0.12f,
                camera,
                elapsed * -56f,
                new Vector3(
                    Mathf.Lerp(0.12f, 1.50f, EaseOutCubic(Mathf.Clamp01((progress - 0.42f) / 0.58f))),
                    Mathf.Lerp(0.10f, 0.86f, EaseOutCubic(Mathf.Clamp01((progress - 0.42f) / 0.58f))),
                    1f),
                impactFade * 0.34f * impactReveal,
                new Color(1f, 0.22f, 0.03f));
            UpdateWindSprite(
                impactCover,
                destination + Vector3.up * 0.08f + cameraForward * -0.52f,
                camera,
                -elapsed * 34f,
                new Vector3(1.12f, 1.36f, 1f) * impactReveal,
                impactFade * 0.56f * impactReveal,
                new Color(0.92f, 0.06f, 0.10f));
            UpdateWindSprite(
                impactCoverCore,
                destination + Vector3.up * 0.08f + cameraForward * -0.64f,
                camera,
                elapsed * 28f,
                new Vector3(0.82f, 1.04f, 1f) * impactReveal,
                impactFade * 0.46f * impactReveal,
                new Color(1f, 0.54f, 0.12f));
            UpdateFrontOrganicSprites(
                burstFlames,
                destination,
                cameraRight,
                cameraUp,
                cameraForward,
                elapsed,
                impactReveal,
                impactFade * 0.84f,
                1,
                palette);
            UpdateFrontOrganicSprites(
                burstSmoke,
                destination,
                cameraRight,
                cameraUp,
                cameraForward,
                elapsed * 0.82f,
                impactReveal,
                impactFade * 0.54f,
                1,
                new[]
                {
                    new Color(0.42f, 0.015f, 0.08f),
                    new Color(0.28f, 0.01f, 0.18f),
                    new Color(0.68f, 0.08f, 0.12f)
                });
            if (impactPlayed)
                UpdateImpactRays(
                    impactRays,
                    impactRayDirections,
                    destination,
                    Mathf.Clamp01((progress - 0.50f) / 0.42f),
                    new Color(1f, 0.10f, 0.02f),
                    new Color(1f, 0.78f, 0.26f));

            if (!impactPlayed && progress >= 0.50f)
            {
                impactPlayed = true;
                CreateImpactRays(
                    root.transform,
                    destination,
                    cameraRight,
                    cameraUp,
                    cameraForward,
                    impactRays,
                    impactRayDirections,
                    new Color(1f, 0.10f, 0.02f),
                    new Color(1f, 0.78f, 0.26f),
                    4540,
                    "spectral hound");
            }

            yield return null;
        }

        yield return WaitFor(id, 0.20f);
        FinishPresentation(root, id);
    }

    public void Stop()
    {
        playbackID++;
        StopActiveEffects();
        playing = false;
    }

    Vector3 ResolveTarget(Func<Vector3> target)
    {
        var position = target != null ? target() : Vector3.zero;
        // Imported actor roots are grounded at the feet. Lift effect space to
        // the visual center so the detonation covers the protagonist instead
        // of reading like a floor decal.
        return position + Vector3.up * 0.32f + Vector3.back * 1.06f;
    }

    IEnumerator WaitFor(int id, float duration)
    {
        var elapsed = 0f;
        while (elapsed < duration && id == playbackID)
        {
            elapsed += Time.deltaTime;
            yield return null;
        }
    }

    EffekseerHandle Play(
        EffekseerEffectAsset asset,
        Vector3 position,
        Vector3 scale,
        Color color,
        float speed)
    {
        if (asset == null)
            return default;
        var parameters = EffekseerPlayEffectParameters.Create(position);
        parameters.SetScale(scale);
        parameters.Speed = speed;
        var handle = EffekseerSystem.PlayEffect(asset, parameters);
        handle.SetAllColor(color);
        activeHandles.Add(handle);
        return handle;
    }

    void FinishPresentation(GameObject root, int id)
    {
        DestroyRoot(root);
        if (id == playbackID)
        {
            StopActiveEffects();
            playing = false;
        }
    }

    GameObject CreateRoot(string name)
    {
        var root = new GameObject(name);
        activeRoots.Add(root);
        return root;
    }

    void DestroyRoot(GameObject root)
    {
        if (root != null)
            Destroy(root);
        activeRoots.Remove(root);
    }

    void TintRootMaterials(GameObject root)
    {
        if (root == null)
            return;

        var renderers = root.GetComponentsInChildren<Renderer>(true);
        for (var index = 0; index < renderers.Length; index++)
        {
            var renderer = renderers[index];
            if (renderer == null)
                continue;

            if (renderer is LineRenderer line)
            {
                line.startColor = NatureTint(line.startColor);
                line.endColor = NatureTint(line.endColor);
            }
            else if (renderer is SpriteRenderer sprite)
            {
                sprite.color = NatureTint(sprite.color);
            }

            var material = renderer.material;
            if (material == null)
                continue;

            if (material.HasProperty("_Color"))
                material.SetColor("_Color", NatureTint(material.GetColor("_Color")));
            if (material.HasProperty("_BaseColor"))
                material.SetColor("_BaseColor", NatureTint(material.GetColor("_BaseColor")));
            if (material.HasProperty("_EmissionColor"))
            {
                var emission = NatureTint(material.GetColor("_EmissionColor"));
                material.SetColor("_EmissionColor", emission * 1.45f);
            }
        }
    }

    static Color NatureTint(Color source)
    {
        var brightness = Mathf.Clamp01(Mathf.Max(source.r, Mathf.Max(source.g, source.b)));
        var tint = Color.Lerp(
            new Color(0.018f, 0.18f, 0.045f),
            new Color(0.70f, 1f, 0.22f),
            Mathf.Pow(brightness, 0.72f));
        tint.a = source.a;
        return tint;
    }

    LineRenderer CreateRibbon(Transform parent, float width, Color color, int pointCount, int renderQueue)
    {
        var objectRoot = new GameObject("VFX ribbon");
        objectRoot.transform.SetParent(parent, false);
        var line = objectRoot.AddComponent<LineRenderer>();
        line.useWorldSpace = true;
        line.loop = false;
        line.positionCount = pointCount;
        line.alignment = LineAlignment.View;
        line.textureMode = LineTextureMode.Stretch;
        line.numCornerVertices = 8;
        line.numCapVertices = 8;
        line.widthMultiplier = width;
        line.widthCurve = new AnimationCurve(
            new Keyframe(0f, 0.05f),
            new Keyframe(0.16f, 0.62f),
            new Keyframe(0.58f, 1f),
            new Keyframe(0.88f, 0.34f),
            new Keyframe(1f, 0.02f));
        line.material = CreateVFXMaterial(color, renderQueue, slashTexture);
        line.startColor = Color.clear;
        line.endColor = Color.clear;
        return line;
    }

    LineRenderer CreateFrontRibbon(Transform parent, float width, int pointCount, int renderQueue)
    {
        var objectRoot = new GameObject("VFX front shroud ribbon");
        objectRoot.transform.SetParent(parent, false);
        var line = objectRoot.AddComponent<LineRenderer>();
        line.useWorldSpace = true;
        line.loop = false;
        line.positionCount = pointCount;
        line.alignment = LineAlignment.View;
        line.textureMode = LineTextureMode.Stretch;
        line.numCornerVertices = 10;
        line.numCapVertices = 10;
        line.widthMultiplier = width;
        line.widthCurve = new AnimationCurve(
            new Keyframe(0f, 0.04f),
            new Keyframe(0.10f, 0.62f),
            new Keyframe(0.28f, 1.00f),
            new Keyframe(0.60f, 0.86f),
            new Keyframe(0.86f, 0.48f),
            new Keyframe(1f, 0.025f));
        line.material = CreateFrontRibbonMaterial(renderQueue);
        line.startColor = Color.white;
        line.endColor = Color.white;
        line.enabled = false;
        return line;
    }

    LineRenderer CreateWildRibbon(
        Transform parent,
        float width,
        int pointCount,
        int renderQueue,
        Color color,
        Color edgeColor)
    {
        var objectRoot = new GameObject("VFX Wild Warden fluid ribbon");
        objectRoot.transform.SetParent(parent, false);
        var line = objectRoot.AddComponent<LineRenderer>();
        line.useWorldSpace = true;
        line.loop = false;
        line.positionCount = pointCount;
        line.alignment = LineAlignment.View;
        line.textureMode = LineTextureMode.Stretch;
        line.numCornerVertices = 12;
        line.numCapVertices = 12;
        line.widthMultiplier = width;
        line.widthCurve = new AnimationCurve(
            new Keyframe(0f, 0.015f),
            new Keyframe(0.10f, 0.52f),
            new Keyframe(0.28f, 1.00f),
            new Keyframe(0.62f, 0.88f),
            new Keyframe(0.88f, 0.38f),
            new Keyframe(1f, 0.012f));
        line.material = CreateWildRibbonMaterial(renderQueue, color, edgeColor);
        line.startColor = Color.white;
        line.endColor = Color.white;
        line.enabled = false;
        return line;
    }

    MeshRenderer CreateFrontCloud(Transform parent, string name, int renderQueue)
    {
        var objectRoot = GameObject.CreatePrimitive(PrimitiveType.Quad);
        objectRoot.name = name;
        objectRoot.transform.SetParent(parent, true);
        var collider = objectRoot.GetComponent<Collider>();
        if (collider != null)
            Destroy(collider);
        var renderer = objectRoot.GetComponent<MeshRenderer>();
        renderer.material = CreateFrontCloudMaterial(renderQueue);
        renderer.sortingOrder = renderQueue;
        renderer.enabled = false;
        return renderer;
    }

    ParticleSystem CreateFrontParticleCloud(
        Transform parent,
        string name,
        Vector3 position,
        Color color,
        int count,
        float size,
        int renderQueue)
    {
        var objectRoot = new GameObject(name);
        objectRoot.transform.SetParent(parent, true);
        objectRoot.transform.position = position;
        var particles = objectRoot.AddComponent<ParticleSystem>();
        var main = particles.main;
        main.duration = 1.35f;
        main.loop = false;
        main.playOnAwake = false;
        main.startLifetime = new ParticleSystem.MinMaxCurve(0.92f, 1.28f);
        main.startSpeed = new ParticleSystem.MinMaxCurve(0.02f, 0.18f);
        main.startSize = new ParticleSystem.MinMaxCurve(size * 0.44f, size);
        main.startRotation = new ParticleSystem.MinMaxCurve(0f, Mathf.PI * 2f);
        main.startColor = color;
        main.simulationSpace = ParticleSystemSimulationSpace.Local;
        main.gravityModifier = 0f;
        main.maxParticles = count;

        var emission = particles.emission;
        emission.enabled = true;
        emission.rateOverTime = 0f;
        emission.SetBursts(new[] { new ParticleSystem.Burst(0.04f, (short)Mathf.Clamp(count, 1, 300)) });

        var shape = particles.shape;
        shape.enabled = true;
        shape.shapeType = ParticleSystemShapeType.Box;
        shape.scale = new Vector3(0.90f, 1.70f, 0.34f);

        var renderer = particles.GetComponent<ParticleSystemRenderer>();
        renderer.renderMode = ParticleSystemRenderMode.Billboard;
        renderer.alignment = ParticleSystemRenderSpace.View;
        var particleTexture = fireBlurTexture != null ? fireBlurTexture : particleSoftTexture;
        renderer.material = CreateFrontOrganicMaterial(renderQueue, particleTexture, -1);
        renderer.sortingOrder = renderQueue;
        if (renderer.material != null && renderer.material.HasProperty("_Color"))
            renderer.material.SetColor("_Color", color);
        particles.Play();
        return particles;
    }

    static void ConfigureFrontParticleVolumes(
        List<ParticleSystem> particles,
        ParticleSystemShapeType shapeType,
        Vector3 volume)
    {
        if (particles == null)
            return;
        for (var i = 0; i < particles.Count; i++)
            ConfigureFrontParticleVolume(particles[i], shapeType, volume);
    }

    static void ConfigureFrontParticleVolume(
        ParticleSystem particles,
        ParticleSystemShapeType shapeType,
        Vector3 volume)
    {
        if (particles == null)
            return;
        var shape = particles.shape;
        shape.shapeType = shapeType;
        if (shapeType == ParticleSystemShapeType.Sphere)
            shape.radius = Mathf.Max(0.05f, volume.x);
        else
            shape.scale = volume;
    }

    static void UpdateFrontParticleClouds(
        List<ParticleSystem> particles,
        Vector3 center,
        Vector3 cameraRight,
        Vector3 cameraUp,
        Vector3 cameraForward,
        float elapsed,
        float fade)
    {
        if (particles == null)
            return;

        for (var index = 0; index < particles.Count; index++)
        {
            var system = particles[index];
            if (system == null)
                continue;

            var phase = elapsed * (1.4f + index * 0.23f) + index * 2.17f;
            var baseX = index % 2 == 0 ? -0.14f : 0.14f;
            var baseY = index == 0 ? 0.16f : index == 1 ? -0.08f : index == 2 ? 0.24f : -0.20f;
            var position = center
                + cameraRight * (baseX + Mathf.Sin(phase) * 0.08f)
                + cameraUp * (baseY + Mathf.Cos(phase * 1.17f) * 0.08f)
                + cameraForward * (-1.10f - index * 0.025f);
            system.transform.position = position;
            system.transform.rotation = FrontBillboardRotation(cameraForward, cameraUp, 0f);
            if (fade < 0.02f && system.isPlaying)
                system.Stop(true, ParticleSystemStopBehavior.StopEmittingAndClear);
        }
    }

    static void UpdateFrontClouds(
        List<MeshRenderer> clouds,
        Vector3 center,
        Vector3 cameraRight,
        Vector3 cameraUp,
        Vector3 cameraForward,
        float elapsed,
        float reveal,
        float fade,
        int pattern,
        float scale,
        Color[] palette)
    {
        if (clouds == null || clouds.Count == 0 || palette == null || palette.Length == 0)
            return;

        reveal = Mathf.Clamp01(reveal);
        fade = Mathf.Clamp01(fade);
        for (var index = 0; index < clouds.Count; index++)
        {
            var renderer = clouds[index];
            if (renderer == null)
                continue;

            var phase = elapsed * (1.8f + index * 0.28f) + index * 1.37f + pattern * 2.4f;
            var offsetX = Mathf.Sin(index * 2.17f + pattern) * 0.38f;
            var offsetY = Mathf.Cos(index * 1.51f + pattern * 0.7f) * 0.52f;
            if (pattern == 1)
                offsetY += 0.06f + index * 0.035f;
            if (pattern == 2)
                offsetX += Mathf.Sin(phase) * 0.14f;

            var position = center
                + cameraRight * offsetX
                + cameraUp * offsetY
                + cameraForward * (-1.02f - index * 0.028f);
            var width = scale * (0.92f + Mathf.Sin(phase * 1.3f) * 0.08f);
            var height = scale * Mathf.Lerp(1.74f, 2.05f, index / (float)Mathf.Max(1, clouds.Count - 1));
            var roll = Mathf.Sin(phase * 0.72f) * (pattern == 2 ? 24f : 13f) + index * 17f;
            var alpha = fade * reveal * (pattern == 1 ? 0.84f : 0.76f);
            var color = palette[index % palette.Length];

            renderer.enabled = alpha > 0.004f;
            if (!renderer.enabled)
                continue;

            renderer.transform.position = position;
            renderer.transform.rotation = FrontBillboardRotation(cameraForward, cameraUp, roll);
            renderer.transform.localScale = new Vector3(width, height, 1f) * reveal;
            var material = renderer.material;
            if (material != null)
            {
                if (material.HasProperty("_Color"))
                    material.SetColor("_Color", new Color(color.r, color.g, color.b, alpha));
                if (material.HasProperty("_Phase"))
                    material.SetFloat("_Phase", phase);
            }
        }
    }

    MeshRenderer CreateFrontOrganicSprite(
        Transform parent,
        string name,
        Texture2D texture,
        int renderQueue,
        int textureCell = -1)
    {
        if (texture == null)
            return null;

        var objectRoot = GameObject.CreatePrimitive(PrimitiveType.Quad);
        objectRoot.name = name;
        objectRoot.transform.SetParent(parent, true);
        var collider = objectRoot.GetComponent<Collider>();
        if (collider != null)
            Destroy(collider);
        var renderer = objectRoot.GetComponent<MeshRenderer>();
        renderer.material = CreateFrontOrganicMaterial(renderQueue, texture, textureCell);
        renderer.sortingOrder = renderQueue;
        renderer.enabled = false;
        return renderer;
    }

    MeshRenderer CreateReferenceFlowSprite(
        Transform parent,
        string name,
        Texture2D texture,
        Texture2D noise,
        int renderQueue,
        float lumaMask = 1f,
        float envelope = 0f,
        float colorFloor = 0f)
    {
        if (texture == null)
            return null;

        var objectRoot = GameObject.CreatePrimitive(PrimitiveType.Quad);
        objectRoot.name = name;
        objectRoot.transform.SetParent(parent, true);
        var collider = objectRoot.GetComponent<Collider>();
        if (collider != null)
            Destroy(collider);
        var renderer = objectRoot.GetComponent<MeshRenderer>();
        renderer.material = CreateReferenceFlowMaterial(
            renderQueue,
            texture,
            noise,
            lumaMask,
            envelope,
            colorFloor);
        renderer.sortingOrder = renderQueue;
        renderer.enabled = false;
        return renderer;
    }

    MeshRenderer CreateProceduralVolumeSprite(
        Transform parent,
        string name,
        Texture2D noise,
        int renderQueue,
        string shaderName,
        Texture2D detail = null)
    {
        var shader = Shader.Find(shaderName);
        if (shader == null)
            return null;

        var objectRoot = GameObject.CreatePrimitive(PrimitiveType.Quad);
        objectRoot.name = name;
        objectRoot.transform.SetParent(parent, true);
        var collider = objectRoot.GetComponent<Collider>();
        if (collider != null)
            Destroy(collider);
        var renderer = objectRoot.GetComponent<MeshRenderer>();
        var material = new Material(shader)
        {
            renderQueue = Mathf.Max(renderQueue, 4250)
        };
        if (material.HasProperty("_NoiseTex"))
            material.SetTexture("_NoiseTex", noise);
        if (material.HasProperty("_DetailTex"))
            material.SetTexture("_DetailTex", detail != null ? detail : noise);
        if (material.HasProperty("_Color"))
            material.SetColor("_Color", Color.white);
        if (material.HasProperty("_Intensity"))
            material.SetFloat("_Intensity", 1f);
        if (material.HasProperty("_Core"))
            material.SetFloat("_Core", 0f);
        activeMaterials.Add(material);
        renderer.material = material;
        renderer.sortingOrder = renderQueue;
        renderer.enabled = false;
        return renderer;
    }

    MeshRenderer CreateHoundSprite(Transform parent, string name, int renderQueue)
    {
        if (spectralHoundTexture == null)
            return null;

        var objectRoot = GameObject.CreatePrimitive(PrimitiveType.Quad);
        objectRoot.name = name;
        objectRoot.transform.SetParent(parent, true);
        var collider = objectRoot.GetComponent<Collider>();
        if (collider != null)
            Destroy(collider);
        var renderer = objectRoot.GetComponent<MeshRenderer>();
        renderer.material = CreateHoundMaterial(renderQueue, spectralHoundTexture);
        renderer.sortingOrder = renderQueue;
        renderer.enabled = false;
        return renderer;
    }

    MeshRenderer CreateCheetahSprite(Transform parent, string name, int renderQueue)
    {
        if (spectralHoundTexture == null)
            return null;

        var objectRoot = GameObject.CreatePrimitive(PrimitiveType.Quad);
        objectRoot.name = name;
        objectRoot.transform.SetParent(parent, true);
        var collider = objectRoot.GetComponent<Collider>();
        if (collider != null)
            Destroy(collider);
        var meshFilter = objectRoot.GetComponent<MeshFilter>();
        if (meshFilter != null)
        {
            meshFilter.sharedMesh = CreateCheetahGridMesh(28, 42);
        }
        var renderer = objectRoot.GetComponent<MeshRenderer>();
        renderer.material = CreateCheetahMaterial(
            renderQueue,
            spectralHoundTexture,
            spectralHoundClosedTexture);
        renderer.sortingOrder = renderQueue;
        renderer.enabled = false;
        return renderer;
    }

    Mesh CreateCheetahGridMesh(int columns, int rows)
    {
        columns = Mathf.Max(4, columns);
        rows = Mathf.Max(4, rows);
        var vertices = new Vector3[(columns + 1) * (rows + 1)];
        var uv = new Vector2[vertices.Length];
        var triangles = new int[columns * rows * 6];

        for (var y = 0; y <= rows; y++)
        {
            var v = y / (float)rows;
            for (var x = 0; x <= columns; x++)
            {
                var u = x / (float)columns;
                var index = y * (columns + 1) + x;
                vertices[index] = new Vector3(u - 0.5f, v - 0.5f, 0f);
                uv[index] = new Vector2(u, v);
            }
        }

        var triangleIndex = 0;
        for (var y = 0; y < rows; y++)
        {
            for (var x = 0; x < columns; x++)
            {
                var bottomLeft = y * (columns + 1) + x;
                var bottomRight = bottomLeft + 1;
                var topLeft = bottomLeft + columns + 1;
                var topRight = topLeft + 1;
                triangles[triangleIndex++] = bottomLeft;
                triangles[triangleIndex++] = topLeft;
                triangles[triangleIndex++] = topRight;
                triangles[triangleIndex++] = bottomLeft;
                triangles[triangleIndex++] = topRight;
                triangles[triangleIndex++] = bottomRight;
            }
        }

        var mesh = new Mesh
        {
            name = "Mistport spectral cheetah motion grid"
        };
        mesh.MarkDynamic();
        mesh.vertices = vertices;
        mesh.uv = uv;
        mesh.triangles = triangles;
        mesh.RecalculateBounds();
        activeMeshes.Add(mesh);
        return mesh;
    }

    MeshRenderer CreateSwordQiBlade(Transform parent, string name, int renderQueue)
    {
        var objectRoot = new GameObject(name);
        objectRoot.transform.SetParent(parent, true);
        var meshFilter = objectRoot.AddComponent<MeshFilter>();
        meshFilter.sharedMesh = CreateSwordQiMesh();
        var renderer = objectRoot.AddComponent<MeshRenderer>();
        renderer.material = CreateSwordQiMaterial(renderQueue);
        renderer.sortingOrder = renderQueue;
        renderer.enabled = false;
        return renderer;
    }

    Mesh CreateSwordQiMesh()
    {
        // Local +Y is the sword tip. The separate blade, guard, grip, and
        // pommel polygons keep the projectile readable at a glance while
        // the shader turns the same silhouette into layered hot energy.
        var vertices = new[]
        {
            new Vector3(0.00f, 0.60f, 0f),
            new Vector3(-0.13f, 0.16f, 0f),
            new Vector3(0.13f, 0.16f, 0f),
            new Vector3(-0.19f, -0.25f, 0f),
            new Vector3(0.19f, -0.25f, 0f),

            new Vector3(-0.29f, -0.28f, -0.01f),
            new Vector3(0.29f, -0.28f, -0.01f),
            new Vector3(0.23f, -0.36f, -0.01f),
            new Vector3(-0.23f, -0.36f, -0.01f),

            new Vector3(-0.065f, -0.36f, -0.02f),
            new Vector3(0.065f, -0.36f, -0.02f),
            new Vector3(0.065f, -0.66f, -0.02f),
            new Vector3(-0.065f, -0.66f, -0.02f),
            new Vector3(-0.105f, -0.68f, -0.025f),
            new Vector3(0.105f, -0.68f, -0.025f),
            new Vector3(0.00f, -0.78f, -0.025f)
        };
        var uv = new Vector2[vertices.Length];
        var colors = new Color[vertices.Length];
        for (var index = 0; index < vertices.Length; index++)
        {
            uv[index] = new Vector2(
                Mathf.InverseLerp(-0.40f, 0.40f, vertices[index].x),
                Mathf.InverseLerp(-0.80f, 0.62f, vertices[index].y));
            colors[index] = index < 5
                ? new Color(1f, 0.28f, 0.035f, 1f)
                : index < 9
                    ? new Color(0.92f, 0.08f, 0.018f, 0.96f)
                    : new Color(0.72f, 0.018f, 0.035f, 0.92f);
        }

        var mesh = new Mesh
        {
            name = "Mistport sword qi silhouette"
        };
        mesh.vertices = vertices;
        mesh.uv = uv;
        mesh.colors = colors;
        mesh.triangles = new[]
        {
            0, 1, 2,
            1, 3, 4,
            1, 4, 2,
            5, 6, 7,
            5, 7, 8,
            9, 10, 11,
            9, 11, 12,
            13, 14, 15
        };
        mesh.RecalculateBounds();
        activeMeshes.Add(mesh);
        return mesh;
    }

    HoundParticleField CreateHoundParticleField(
        Transform parent,
        string name,
        Texture2D particleTexture,
        int particleCount,
        int renderQueue,
        float particleSize,
        Color[] palette,
        bool edgeOnly)
    {
        if (spectralHoundTexture == null || particleTexture == null)
            return null;

        var maskPixels = spectralHoundTexture.GetPixels32();
        var maskWidth = spectralHoundTexture.width;
        var maskHeight = spectralHoundTexture.height;
        var candidates = new List<Vector2>();
        var candidateColors = new List<Color32>();
        const int sampleStep = 6;
        for (var y = 0; y < maskHeight; y += sampleStep)
        for (var x = 0; x < maskWidth; x += sampleStep)
        {
            var pixel = maskPixels[y * maskWidth + x];
            if (pixel.a < 72)
                continue;

            if (edgeOnly)
            {
                var left = x >= sampleStep ? maskPixels[y * maskWidth + x - sampleStep].a : (byte)0;
                var right = x + sampleStep < maskWidth ? maskPixels[y * maskWidth + x + sampleStep].a : (byte)0;
                var down = y >= sampleStep ? maskPixels[(y - sampleStep) * maskWidth + x].a : (byte)0;
                var up = y + sampleStep < maskHeight ? maskPixels[(y + sampleStep) * maskWidth + x].a : (byte)0;
                if (left >= 72 && right >= 72 && down >= 72 && up >= 72)
                    continue;
            }

            candidates.Add(new Vector2(
                (x / (float)(maskWidth - 1) - 0.5f) * 2f,
                (y / (float)(maskHeight - 1) - 0.5f) * 2f));
            candidateColors.Add(pixel);
        }

        if (candidates.Count == 0)
            return null;

        var objectRoot = new GameObject(name);
        objectRoot.transform.SetParent(parent, false);
        var particles = objectRoot.AddComponent<ParticleSystem>();
        var main = particles.main;
        main.duration = 30f;
        main.loop = false;
        main.playOnAwake = false;
        main.startLifetime = 30f;
        main.startSpeed = 0f;
        main.startSize = particleSize;
        main.startColor = Color.white;
        main.simulationSpace = ParticleSystemSimulationSpace.World;
        main.simulationSpeed = 0f;
        main.maxParticles = particleCount;

        var emission = particles.emission;
        emission.enabled = false;
        var shape = particles.shape;
        shape.enabled = false;

        var particleRenderer = particles.GetComponent<ParticleSystemRenderer>();
        particleRenderer.renderMode = ParticleSystemRenderMode.Billboard;
        particleRenderer.alignment = ParticleSystemRenderSpace.View;
        particleRenderer.material = CreateHoundParticleMaterial(renderQueue, particleTexture);
        particleRenderer.sortingOrder = renderQueue;

        var field = new HoundParticleField
        {
            system = particles,
            particles = new ParticleSystem.Particle[particleCount],
            samples = new Vector2[particleCount],
            phases = new float[particleCount],
            depths = new float[particleCount],
            sizes = new float[particleCount],
            colors = new Color[particleCount]
        };
        var paletteLength = palette != null && palette.Length > 0 ? palette.Length : 1;
        for (var index = 0; index < particleCount; index++)
        {
            // Do not use a step close to the sampled texture row width. A
            // stride such as 97 walks a near-vertical diagonal through the
            // row-major candidate list and turns every animal into a column
            // of particles. This larger deterministic coprime stride keeps
            // the distribution repeatable while covering the full mask.
            var candidateIndex = (int)((index * 7919L + 17L) % candidates.Count);
            field.samples[index] = candidates[candidateIndex];
            field.phases[index] = index * 0.6180339f;
            field.depths[index] = ((index % 13) - 6) * 0.012f;
            field.sizes[index] = particleSize * (0.64f + Mathf.Repeat(index * 0.371f, 1f) * 0.66f);
            var paletteColor = palette != null && palette.Length > 0
                ? palette[index % paletteLength]
                : Color.white;
            var sourceColor = candidateColors[candidateIndex];
            var sourceTint = new Color(
                sourceColor.r / 255f,
                sourceColor.g / 255f,
                sourceColor.b / 255f,
                1f);
            // Preserve the authored mask's bright eyes, teeth, and cyan
            // flame edge while keeping the two fields in the Mistport blue-
            // violet palette. Those high-value facial particles make the
            // leading head readable even while it crosses the enemy model.
            var sourceInfluence = edgeOnly ? 0.62f : 0.38f;
            field.colors[index] = Color.Lerp(paletteColor, sourceTint, sourceInfluence);

            var particle = new ParticleSystem.Particle
            {
                position = Vector3.zero,
                startLifetime = 30f,
                remainingLifetime = 30f,
                startSize = field.sizes[index],
                startColor = field.colors[index],
                randomSeed = (uint)(index + 1)
            };
            field.particles[index] = particle;
        }

        particles.Play();
        particles.SetParticles(field.particles, particleCount);
        return field;
    }

    HoundParticleField CreateHoundFeatureParticleField(
        Transform parent,
        string name,
        Texture2D particleTexture,
        int renderQueue,
        float particleSize)
    {
        if (particleTexture == null)
            return null;

        var samples = new List<Vector2>();
        var colors = new List<Color>();
        AddHoundFeatureCluster(
            samples,
            colors,
            new Vector2(-0.24f, -0.18f),
            new Vector2(0.095f, 0.070f),
            26,
            new Color(0.78f, 1f, 1f),
            0.15f);
        AddHoundFeatureCluster(
            samples,
            colors,
            new Vector2(0.24f, -0.18f),
            new Vector2(0.095f, 0.070f),
            26,
            new Color(0.78f, 1f, 1f),
            1.43f);
        AddHoundFeatureCluster(
            samples,
            colors,
            new Vector2(0f, -0.35f),
            new Vector2(0.22f, 0.14f),
            54,
            new Color(0.38f, 0.92f, 1f),
            0.62f);
        AddHoundFeatureCluster(
            samples,
            colors,
            new Vector2(-0.40f, -0.72f),
            new Vector2(0.18f, 0.27f),
            54,
            new Color(0.20f, 0.78f, 1f),
            2.14f);
        AddHoundFeatureCluster(
            samples,
            colors,
            new Vector2(0.40f, -0.72f),
            new Vector2(0.18f, 0.27f),
            54,
            new Color(0.20f, 0.78f, 1f),
            3.04f);
        AddHoundFeatureCluster(
            samples,
            colors,
            new Vector2(0f, -0.28f),
            new Vector2(0.075f, 0.060f),
            18,
            new Color(0.90f, 1f, 1f),
            0.37f);

        var objectRoot = new GameObject(name);
        objectRoot.transform.SetParent(parent, false);
        var particles = objectRoot.AddComponent<ParticleSystem>();
        var main = particles.main;
        main.duration = 30f;
        main.loop = false;
        main.playOnAwake = false;
        main.startLifetime = 30f;
        main.startSpeed = 0f;
        main.startSize = particleSize;
        main.startColor = Color.white;
        main.simulationSpace = ParticleSystemSimulationSpace.World;
        main.simulationSpeed = 0f;
        main.maxParticles = samples.Count;

        var emission = particles.emission;
        emission.enabled = false;
        var shape = particles.shape;
        shape.enabled = false;

        var particleRenderer = particles.GetComponent<ParticleSystemRenderer>();
        particleRenderer.renderMode = ParticleSystemRenderMode.Billboard;
        particleRenderer.alignment = ParticleSystemRenderSpace.View;
        particleRenderer.material = CreateHoundParticleMaterial(renderQueue, particleTexture);
        particleRenderer.sortingOrder = renderQueue;

        var field = new HoundParticleField
        {
            system = particles,
            particles = new ParticleSystem.Particle[samples.Count],
            samples = samples.ToArray(),
            phases = new float[samples.Count],
            depths = new float[samples.Count],
            sizes = new float[samples.Count],
            colors = colors.ToArray()
        };
        for (var index = 0; index < samples.Count; index++)
        {
            field.phases[index] = index * 0.6180339f;
            field.depths[index] = -0.08f - (index % 7) * 0.012f;
            field.sizes[index] = particleSize
                * (0.78f + Mathf.Repeat(index * 0.431f, 1f) * 0.50f);
            field.particles[index] = new ParticleSystem.Particle
            {
                position = Vector3.zero,
                startLifetime = 30f,
                remainingLifetime = 30f,
                startSize = field.sizes[index],
                startColor = field.colors[index],
                randomSeed = (uint)(index + 1)
            };
        }

        particles.Play();
        particles.SetParticles(field.particles, field.particles.Length);
        return field;
    }

    static void AddHoundFeatureCluster(
        List<Vector2> samples,
        List<Color> colors,
        Vector2 center,
        Vector2 radius,
        int count,
        Color color,
        float phase)
    {
        for (var index = 0; index < count; index++)
        {
            var angle = phase + index * Mathf.PI * 2f / count;
            var ring = 0.30f + Mathf.Repeat(index * 0.6180339f + phase, 1f) * 0.70f;
            samples.Add(center + new Vector2(
                Mathf.Cos(angle) * radius.x * ring,
                Mathf.Sin(angle) * radius.y * ring));
            colors.Add(color);
        }
    }

    Texture2D CreateHoundParticleDotTexture()
    {
        if (houndParticleDotTexture != null)
            return houndParticleDotTexture;

        const int size = 32;
        var texture = new Texture2D(size, size, TextureFormat.RGBA32, false)
        {
            name = "Runtime spectral hound particle dot",
            filterMode = FilterMode.Bilinear,
            wrapMode = TextureWrapMode.Clamp
        };
        var pixels = new Color[size * size];
        var center = (size - 1) * 0.5f;
        for (var y = 0; y < size; y++)
        for (var x = 0; x < size; x++)
        {
            var dx = (x - center) / center;
            var dy = (y - center) / center;
            var radius = Mathf.Sqrt(dx * dx + dy * dy);
            var alpha = 1f - Mathf.SmoothStep(0.25f, 1f, radius);
            alpha *= alpha;
            pixels[y * size + x] = new Color(1f, 1f, 1f, alpha);
        }
        texture.SetPixels(pixels);
        texture.Apply(false, true);
        houndParticleDotTexture = texture;
        activeTextures.Add(texture);
        return texture;
    }

    static void UpdateFrontOrganicSprites(
        List<MeshRenderer> sprites,
        Vector3 center,
        Vector3 cameraRight,
        Vector3 cameraUp,
        Vector3 cameraForward,
        float elapsed,
        float reveal,
        float fade,
        int pattern,
        Color[] palette)
    {
        if (sprites == null || sprites.Count == 0 || palette == null || palette.Length == 0)
            return;

        reveal = Mathf.Clamp01(reveal);
        fade = Mathf.Clamp01(fade);
        for (var index = 0; index < sprites.Count; index++)
        {
            var renderer = sprites[index];
            if (renderer == null)
                continue;

            var seed = index * 0.6180339f + pattern * 0.173f;
            var xT = Mathf.Repeat(seed * 1.37f, 1f);
            var yT = Mathf.Repeat(seed * 2.17f + 0.23f, 1f);
            var inner = index % 5 != 0;
            var xExtent = inner ? 0.72f : 1.06f;
            var yMin = inner ? -0.98f : -1.28f;
            var yMax = inner ? 1.06f : 1.30f;
            var x = Mathf.Lerp(-xExtent, xExtent, xT);
            var y = Mathf.Lerp(yMin, yMax, yT);
            var roll = Mathf.Lerp(-68f, 68f, Mathf.Repeat(seed * 1.91f, 1f));

            if (pattern == 0)
            {
                // Broken sword qi crosses the actor on several diagonals.
                y += Mathf.Sin(elapsed * 8f + seed * 9f) * 0.10f;
                x += y * 0.14f + Mathf.Sin(elapsed * 11f + seed * 5f) * 0.08f;
                roll += Mathf.Sin(elapsed * 7f + seed * 6f) * 12f;
            }
            else if (pattern == 1)
            {
                // Flame cards rise and overlap like tongues and smoke, with
                // a few lower embers keeping the actor covered at contact.
                y += Mathf.Sin(elapsed * 6f + seed * 8f) * 0.11f + 0.12f;
                x += Mathf.Sin(elapsed * 10f + seed * 7f) * 0.09f;
                roll += Mathf.Sin(elapsed * 9f + seed * 5f) * 16f;
            }
            else
            {
                // Wind texture cards orbit through the body volume without
                // ever forming a clean closed circle.
                var orbit = elapsed * (1.5f + Mathf.Repeat(seed * 3f, 1f)) + seed * 8f;
                x += Mathf.Cos(orbit) * (0.16f + Mathf.Abs(y) * 0.18f);
                y += Mathf.Sin(orbit * 1.21f) * 0.10f;
                roll += Mathf.Sin(orbit) * 38f;
            }

            var width = pattern == 1
                ? Mathf.Lerp(0.34f, 0.70f, Mathf.Repeat(seed * 2.31f, 1f))
                : Mathf.Lerp(0.28f, 0.62f, Mathf.Repeat(seed * 2.31f, 1f));
            var height = pattern == 2
                ? Mathf.Lerp(0.30f, 0.66f, Mathf.Repeat(seed * 1.73f, 1f))
                : Mathf.Lerp(0.38f, 0.88f, Mathf.Repeat(seed * 1.73f, 1f));
            width *= 0.74f;
            height *= 0.76f;
            if (inner)
            {
                width *= 1.18f;
                height *= 1.16f;
            }
            else
            {
                width *= 0.82f;
                height *= 0.84f;
            }
            var scaleReveal = Mathf.Lerp(0.22f, 1f, reveal);
            var depth = -0.90f - (index % 9) * 0.012f;
            var position = center
                + cameraRight * x
                + cameraUp * y
                + cameraForward * depth;
            var color = palette[index % palette.Length];
            var shimmer = 0.82f + Mathf.Sin(elapsed * (13f + index * 0.19f) + seed) * 0.18f;
            var alpha = fade * reveal * shimmer
                * (inner ? (pattern == 1 ? 0.62f : 0.52f) : 0.24f);
            if (index % 7 == 0)
                alpha = Mathf.Min(1f, alpha + 0.14f);

            renderer.enabled = alpha > 0.004f;
            if (!renderer.enabled)
                continue;

            renderer.transform.position = position;
            renderer.transform.rotation = FrontBillboardRotation(cameraForward, cameraUp, roll);
            renderer.transform.localScale = new Vector3(width, height, 1f) * scaleReveal;
            var material = renderer.material;
            if (material != null && material.HasProperty("_Color"))
                material.SetColor("_Color", new Color(color.r, color.g, color.b, alpha));
        }
    }

    static void UpdateSwordQiBlade(
        MeshRenderer renderer,
        Vector3 position,
        Vector3 cameraForward,
        Vector3 swordAxis,
        float roll,
        Vector3 scale,
        float alpha,
        Color tint,
        float elapsed,
        float glow)
    {
        if (renderer == null)
            return;

        var visible = alpha > 0.003f && scale.sqrMagnitude > 0.0001f;
        renderer.enabled = visible;
        if (!visible)
            return;

        renderer.transform.position = position + cameraForward * -1.14f;
        renderer.transform.rotation = FrontBillboardRotation(cameraForward, swordAxis, roll);
        renderer.transform.localScale = scale;

        var material = renderer.material;
        if (material == null)
            return;
        if (material.HasProperty("_Color"))
            material.SetColor("_Color", new Color(tint.r, tint.g, tint.b, 1f));
        if (material.HasProperty("_EdgeColor"))
            material.SetColor("_EdgeColor", new Color(1f, 0.84f, 0.30f, 1f));
        if (material.HasProperty("_Phase"))
            material.SetFloat("_Phase", elapsed * 8.5f + roll * 0.02f);
        if (material.HasProperty("_Glow"))
            material.SetFloat("_Glow", glow + Mathf.Sin(elapsed * 15f) * 0.12f);
        if (material.HasProperty("_Alpha"))
            material.SetFloat("_Alpha", Mathf.Clamp01(alpha));
    }

    static void UpdateHoundSprite(
        MeshRenderer renderer,
        Vector3 position,
        Camera camera,
        float roll,
        Vector3 scale,
        float alpha,
        Color tint)
    {
        if (renderer == null)
            return;

        var visible = alpha > 0.003f && scale.sqrMagnitude > 0.0001f;
        renderer.enabled = visible;
        if (!visible)
            return;

        var cameraForward = camera != null ? camera.transform.forward : Vector3.forward;
        var cameraUp = camera != null ? camera.transform.up : Vector3.up;
        renderer.transform.position = position;
        renderer.transform.rotation = FrontBillboardRotation(cameraForward, cameraUp, roll);
        // Unity's Quad winding presents this source mirrored from the
        // camera-facing side. Flip X so the muzzle leads the lunge direction.
        renderer.transform.localScale = new Vector3(-scale.x, scale.y, scale.z);
        var material = renderer.material;
        if (material != null && material.HasProperty("_Color"))
            material.SetColor("_Color", new Color(tint.r, tint.g, tint.b, alpha));
    }

    static void UpdateCheetahSprite(
        MeshRenderer renderer,
        Vector3 position,
        Vector3 cameraForward,
        Vector3 shapeUp,
        float elapsed,
        float reveal,
        float fade,
        float width,
        float height,
        float roll,
        float phase,
        float dissolve,
        float mouthOpen)
    {
        if (renderer == null)
            return;

        reveal = Mathf.Clamp01(reveal);
        fade = Mathf.Clamp01(fade);
        var alpha = reveal * fade;
        renderer.enabled = alpha > 0.003f;
        if (!renderer.enabled)
            return;

        renderer.transform.position = position + cameraForward * -1.02f;
        renderer.transform.rotation = FrontBillboardRotation(cameraForward, shapeUp, roll);
        var scaleReveal = Mathf.Lerp(0.34f, 1f, reveal);
        renderer.transform.localScale = new Vector3(width, height, 1f) * scaleReveal;

        var material = renderer.material;
        if (material == null)
            return;
        if (material.HasProperty("_Color"))
            material.SetColor("_Color", new Color(0.94f, 0.98f, 1f, alpha));
        if (material.HasProperty("_Phase"))
            material.SetFloat("_Phase", phase + elapsed * 1.7f);
        if (material.HasProperty("_ActionPhase"))
            material.SetFloat("_ActionPhase", elapsed);
        if (material.HasProperty("_LimbMotion"))
            material.SetFloat("_LimbMotion", Mathf.Lerp(0.72f, 1.08f, reveal));
        if (material.HasProperty("_Distortion"))
            material.SetFloat("_Distortion", 0.045f + Mathf.Sin(elapsed * 8.3f) * 0.012f);
        if (material.HasProperty("_Dissolve"))
            material.SetFloat("_Dissolve", dissolve * 0.82f);
        if (material.HasProperty("_MouthOpen"))
            material.SetFloat("_MouthOpen", Mathf.Clamp01(mouthOpen));
        if (material.HasProperty("_Glow"))
            material.SetFloat("_Glow", 0.62f + Mathf.Sin(elapsed * 13f) * 0.12f);
    }

    static void UpdateHoundParticleField(
        HoundParticleField field,
        Vector3 center,
        Vector3 cameraRight,
        Vector3 cameraUp,
        Vector3 cameraForward,
        float elapsed,
        float reveal,
        float alpha,
        float breakup,
        float width,
        float height)
    {
        if (field == null || field.system == null || field.particles == null)
            return;

        reveal = Mathf.Clamp01(reveal);
        alpha = Mathf.Clamp01(alpha);
        breakup = Mathf.Clamp01(breakup);
        for (var index = 0; index < field.particles.Length; index++)
        {
            var sample = field.samples[index];
            var phase = field.phases[index];
            var pulse = 0.88f + Mathf.Sin(elapsed * (10f + index * 0.013f) + phase) * 0.12f;
            var turbulence = new Vector2(
                Mathf.Sin(elapsed * 5.8f + phase * 3.1f),
                Mathf.Cos(elapsed * 7.1f + phase * 2.4f)) * 0.045f;
            var burstDirection = sample.sqrMagnitude > 0.02f
                ? sample.normalized
                : new Vector2(Mathf.Sin(phase), Mathf.Cos(phase)).normalized;
            var breakupOffset = burstDirection * breakup * (0.16f + Mathf.Repeat(phase * 1.73f, 1f) * 0.62f);
            var localX = (sample.x * reveal + turbulence.x + breakupOffset.x) * width;
            var localY = (sample.y * reveal + turbulence.y + breakupOffset.y) * height;
            var localDepth = field.depths[index]
                + Mathf.Sin(elapsed * 8.4f + phase) * 0.055f
                + breakup * Mathf.Sin(phase * 4.7f) * 0.20f;
            field.particles[index].position = center
                + cameraRight * localX
                + cameraUp * localY
                + cameraForward * localDepth;
            field.particles[index].startSize = field.sizes[index]
                * pulse
                * Mathf.Lerp(0.74f, 1.22f, reveal)
                * Mathf.Lerp(1f, 1.45f, breakup);
            var particleAlpha = alpha
                * Mathf.Lerp(1f, 0.10f, breakup)
                * (0.76f + Mathf.Sin(elapsed * 12.0f + phase * 1.7f) * 0.24f);
            var color = field.colors[index];
            field.particles[index].startColor = new Color(
                color.r,
                color.g,
                color.b,
                Mathf.Clamp01(particleAlpha));
            field.particles[index].remainingLifetime = 30f;
        }
        field.system.SetParticles(field.particles, field.particles.Length);
    }

    static Quaternion FrontBillboardRotation(Vector3 cameraForward, Vector3 cameraUp, float roll)
    {
        var facing = Quaternion.LookRotation(-cameraForward, cameraUp);
        return Quaternion.AngleAxis(roll, -cameraForward) * facing;
    }

    static void UpdateFrontRibbon(
        LineRenderer line,
        Vector3[] points,
        float width,
        Color color,
        float alpha)
    {
        if (line == null || points == null || points.Length < 2)
            return;

        var visible = alpha > 0.004f && width > 0.001f;
        line.enabled = visible;
        if (!visible)
            return;

        line.positionCount = points.Length;
        line.SetPositions(points);
        line.widthMultiplier = width;
        line.startColor = Color.white;
        line.endColor = Color.white;
        var material = line.material;
        if (material != null && material.HasProperty("_Color"))
            material.SetColor("_Color", new Color(color.r, color.g, color.b, alpha));
    }

    static void UpdateWildRibbon(
        LineRenderer line,
        Vector3[] points,
        float width,
        Color color,
        Color edgeColor,
        float alpha,
        float phase)
    {
        if (line == null || points == null || points.Length < 2)
            return;

        var visible = alpha > 0.003f && width > 0.001f;
        line.enabled = visible;
        if (!visible)
            return;

        line.positionCount = points.Length;
        line.SetPositions(points);
        line.widthMultiplier = width;
        line.startColor = Color.white;
        line.endColor = Color.white;
        var material = line.material;
        if (material == null)
            return;
        if (material.HasProperty("_Color"))
            material.SetColor("_Color", new Color(color.r, color.g, color.b, alpha));
        if (material.HasProperty("_EdgeColor"))
            material.SetColor("_EdgeColor", new Color(edgeColor.r, edgeColor.g, edgeColor.b, alpha));
        if (material.HasProperty("_Phase"))
            material.SetFloat("_Phase", phase);
    }

    static void UpdateWildWardenFluidRibbons(
        List<LineRenderer> sheets,
        List<LineRenderer> cores,
        List<LineRenderer> arcs,
        List<LineRenderer> groundSweeps,
        Vector3 center,
        Vector3 cameraRight,
        Vector3 cameraUp,
        Vector3 cameraForward,
        float elapsed,
        float reveal,
        float fade,
        Color[] palette)
    {
        if (palette == null || palette.Length == 0)
            return;

        reveal = Mathf.Clamp01(reveal);
        fade = Mathf.Clamp01(fade);

        if (sheets != null)
        {
            for (var index = 0; index < sheets.Count; index++)
            {
                var points = BuildWildWardenFlowPath(
                    sheets[index] != null ? sheets[index].positionCount : 48,
                    index,
                    center,
                    cameraRight,
                    cameraUp,
                    cameraForward,
                    elapsed,
                    reveal,
                    0f);
                var color = palette[(index + 1) % palette.Length];
                var edge = index % 2 == 0 ? palette[5] : palette[4];
                var shimmer = 0.90f + Mathf.Sin(elapsed * 8.0f + index * 1.3f) * 0.10f;
                UpdateWildRibbon(
                    sheets[index],
                    points,
                    (0.34f - index * 0.022f) * shimmer,
                    color,
                    edge,
                    fade * reveal * (0.36f + (index % 3) * 0.045f),
                    elapsed * (1.2f + index * 0.17f));
            }
        }

        if (cores != null)
        {
            for (var index = 0; index < cores.Count; index++)
            {
                var points = BuildWildWardenFlowPath(
                    cores[index] != null ? cores[index].positionCount : 48,
                    index,
                    center,
                    cameraRight,
                    cameraUp,
                    cameraForward,
                    elapsed + 0.07f,
                    reveal,
                    -0.035f);
                UpdateWildRibbon(
                    cores[index],
                    points,
                    0.046f - index * 0.0028f,
                    palette[4],
                    palette[5],
                    fade * reveal * (0.58f - index * 0.022f),
                    elapsed * (1.7f + index * 0.14f) + 1.2f);
            }
        }

        if (arcs != null)
        {
            for (var index = 0; index < arcs.Count; index++)
            {
                var points = BuildWildWardenArcPath(
                    arcs[index] != null ? arcs[index].positionCount : 32,
                    index,
                    center,
                    cameraRight,
                    cameraUp,
                    cameraForward,
                    elapsed,
                    reveal,
                    -0.10f - index * 0.025f);
                var color = index % 2 == 0 ? palette[4] : palette[3];
                UpdateWildRibbon(
                    arcs[index],
                    points,
                    0.125f - index * 0.009f,
                    color,
                    palette[5],
                    fade * reveal * (0.42f - index * 0.025f),
                    elapsed * (1.4f + index * 0.16f) + index * 1.8f);
            }
        }

        if (groundSweeps != null)
        {
            for (var index = 0; index < groundSweeps.Count; index++)
            {
                var points = BuildWildWardenGroundSweepPath(
                    groundSweeps[index] != null ? groundSweeps[index].positionCount : 36,
                    index,
                    center,
                    cameraRight,
                    cameraUp,
                    cameraForward,
                    elapsed,
                    reveal,
                    -0.14f - index * 0.025f);
                var color = index == 0 ? palette[3] : palette[4];
                UpdateWildRibbon(
                    groundSweeps[index],
                    points,
                    0.21f - index * 0.024f,
                    color,
                    palette[5],
                    fade * reveal * (0.34f - index * 0.025f),
                    elapsed * (1.1f + index * 0.20f));
            }
        }
    }

    static Vector3[] BuildWildWardenFlowPath(
        int pointCount,
        int style,
        Vector3 center,
        Vector3 cameraRight,
        Vector3 cameraUp,
        Vector3 cameraForward,
        float elapsed,
        float reveal,
        float depthOffset)
    {
        var points = new Vector3[Mathf.Max(2, pointCount)];
        for (var point = 0; point < points.Length; point++)
        {
            var t = point / (float)(points.Length - 1);
            var visibleT = Mathf.Clamp01(t * reveal);
            var y = Mathf.Lerp(-1.72f, 1.78f, visibleT);
            var phase = elapsed * (1.18f + style * 0.11f) + style * 1.24f;
            var wave = Mathf.Sin(visibleT * Mathf.PI * 2.0f + phase) * 0.085f
                + Mathf.Sin(visibleT * Mathf.PI * 4.0f - phase * 0.62f) * 0.035f;
            float x;
            switch (style)
            {
                case 0:
                    x = -1.72f + visibleT * 0.66f + wave;
                    break;
                case 1:
                    x = 1.70f - visibleT * 0.72f - wave * 0.80f;
                    break;
                case 2:
                    x = -1.18f + visibleT * 2.42f + wave * 1.15f;
                    break;
                case 3:
                    x = 1.18f - visibleT * 2.48f - wave * 1.05f;
                    break;
                case 4:
                    x = -0.12f + Mathf.Sin(visibleT * Mathf.PI * 1.35f + phase) * 0.88f + wave;
                    break;
                default:
                    x = 0.18f + Mathf.Sin(visibleT * Mathf.PI * 1.72f - phase) * 0.72f - wave * 0.70f;
                    break;
            }

            y += Mathf.Sin(visibleT * Mathf.PI) * 0.06f
                + Mathf.Sin(phase * 0.8f + visibleT * 9.0f) * 0.018f;
            var depth = -0.78f - style * 0.018f - point * 0.0015f + depthOffset;
            points[point] = center
                + cameraRight * x
                + cameraUp * y
                + cameraForward * depth;
        }
        return points;
    }

    static Vector3[] BuildWildWardenArcPath(
        int pointCount,
        int style,
        Vector3 center,
        Vector3 cameraRight,
        Vector3 cameraUp,
        Vector3 cameraForward,
        float elapsed,
        float reveal,
        float depthOffset)
    {
        var points = new Vector3[Mathf.Max(2, pointCount)];
        var arcStart = style % 2 == 0 ? -1.38f : 0.44f;
        var arcEnd = style % 2 == 0 ? 0.54f : 2.38f;
        var radiusX = 0.92f + (style % 3) * 0.12f;
        var radiusY = 0.48f + (style % 2) * 0.12f;
        var offsetX = style < 2 ? 0f : (style == 2 ? -0.32f : 0.36f);
        var offsetY = -0.18f + (style % 2) * 0.70f;
        for (var point = 0; point < points.Length; point++)
        {
            var t = point / (float)(points.Length - 1);
            var visibleT = Mathf.Clamp01(t * reveal);
            var angle = Mathf.Lerp(arcStart, arcEnd, visibleT)
                + Mathf.Sin(elapsed * 1.2f + t * 5.0f + style) * 0.035f;
            var x = offsetX + Mathf.Cos(angle) * radiusX;
            var y = offsetY + Mathf.Sin(angle) * radiusY;
            points[point] = center
                + cameraRight * x
                + cameraUp * y
                + cameraForward * (-0.92f - style * 0.022f + depthOffset);
        }
        return points;
    }

    static Vector3[] BuildWildWardenGroundSweepPath(
        int pointCount,
        int style,
        Vector3 center,
        Vector3 cameraRight,
        Vector3 cameraUp,
        Vector3 cameraForward,
        float elapsed,
        float reveal,
        float depthOffset)
    {
        var points = new Vector3[Mathf.Max(2, pointCount)];
        for (var point = 0; point < points.Length; point++)
        {
            var t = point / (float)(points.Length - 1);
            var visibleT = Mathf.Clamp01(t * reveal);
            var x = Mathf.Lerp(-2.15f, 2.15f, visibleT);
            var y = -1.46f + Mathf.Sin(visibleT * Mathf.PI + elapsed * (1.1f + style * 0.2f)) * 0.16f
                + Mathf.Sin(visibleT * 8.0f + elapsed * 2.2f + style) * 0.025f;
            points[point] = center
                + cameraRight * x
                + cameraUp * y
                + cameraForward * (-0.95f - style * 0.025f + depthOffset);
        }
        return points;
    }

    static void UpdateWildWardenMotes(
        List<MeshRenderer> motes,
        Vector3 center,
        Vector3 cameraRight,
        Vector3 cameraUp,
        Vector3 cameraForward,
        float elapsed,
        float reveal,
        float fade,
        Color[] palette)
    {
        if (motes == null || palette == null || palette.Length == 0)
            return;

        for (var index = 0; index < motes.Count; index++)
        {
            var renderer = motes[index];
            if (renderer == null)
                continue;
            var phase = elapsed * (1.7f + index * 0.19f) + index * 2.2f;
            var orbit = phase + index * 0.7f;
            var x = Mathf.Cos(orbit) * (0.70f + (index % 3) * 0.14f);
            var y = -0.78f + Mathf.Repeat(index * 0.31f, 1f) * 1.95f
                + Mathf.Sin(phase * 1.3f) * 0.12f;
            var alpha = fade * reveal * (0.08f + (index % 3) * 0.025f);
            renderer.enabled = alpha > 0.003f;
            if (!renderer.enabled)
                continue;
            renderer.transform.position = center
                + cameraRight * x
                + cameraUp * y
                + cameraForward * (-0.66f - index * 0.018f);
            renderer.transform.rotation = FrontBillboardRotation(
                cameraForward,
                cameraUp,
                phase * Mathf.Rad2Deg * 0.75f + index * 23f);
            var size = 0.14f + (index % 3) * 0.035f;
            renderer.transform.localScale = new Vector3(size * 0.78f, size, 1f);
            var material = renderer.material;
            if (material != null && material.HasProperty("_Color"))
            {
                var color = palette[(index + 2) % palette.Length];
                material.SetColor("_Color", new Color(color.r, color.g, color.b, alpha));
            }
        }
    }

    static void UpdateWildWardenReferenceRibbons(
        List<LineRenderer> glows,
        List<LineRenderer> cores,
        Vector3 center,
        Vector3 cameraRight,
        Vector3 cameraUp,
        Vector3 cameraForward,
        float elapsed,
        float reveal,
        float fade,
        Color[] palette)
    {
        if (glows == null || cores == null || palette == null || palette.Length == 0)
            return;

        reveal = Mathf.Clamp01(reveal);
        fade = Mathf.Clamp01(fade);
        for (var index = 0; index < glows.Count && index < cores.Count; index++)
        {
            var glow = glows[index];
            var core = cores[index];
            if (glow == null || core == null)
                continue;

            var points = new Vector3[glow.positionCount];
            for (var point = 0; point < points.Length; point++)
            {
                var t = point / (float)(points.Length - 1);
                var visibleT = Mathf.Clamp01(t * Mathf.Lerp(0.22f, 1.08f, reveal));
                var height = Mathf.Lerp(-0.78f, 1.28f, visibleT);
                var spiral = elapsed * (1.25f + index * 0.18f)
                    + visibleT * (2.85f + index * 0.28f)
                    + index * 1.82f;
                var envelope = Mathf.Sin(visibleT * Mathf.PI);
                var radius = Mathf.Lerp(0.18f, 0.76f, visibleT)
                    * (0.90f - visibleT * 0.16f)
                    * (0.92f + Mathf.Sin(elapsed * 4.2f + index) * 0.08f);
                var x = Mathf.Cos(spiral) * radius
                    + Mathf.Sin(visibleT * 8f + elapsed * 2.8f + index) * 0.045f * envelope;
                var y = height + Mathf.Sin(spiral * 1.17f) * 0.075f * envelope;
                var depth = -0.84f - index * 0.045f + Mathf.Sin(spiral * 0.8f) * 0.045f;
                points[point] = center
                    + cameraRight * x
                    + cameraUp * y
                    + cameraForward * depth;
            }

            var color = palette[index % palette.Length];
            var shimmer = 0.90f + Mathf.Sin(elapsed * 13f + index * 1.8f) * 0.10f;
            UpdateFrontRibbon(
                glow,
                points,
                (0.145f - index * 0.022f) * shimmer,
                color,
                fade * reveal * 0.72f * shimmer);
            var corePoints = new Vector3[points.Length];
            for (var point = 0; point < points.Length; point++)
                corePoints[point] = points[point] + cameraForward * -0.018f;
            UpdateFrontRibbon(
                core,
                corePoints,
                0.022f - index * 0.002f,
                Color.Lerp(new Color(0.88f, 1f, 0.64f), color, 0.28f),
                fade * reveal * 0.78f * shimmer);
        }
    }

    static void UpdateWildWardenReferenceRings(
        List<MeshRenderer> rings,
        Vector3 center,
        Vector3 cameraForward,
        Vector3 cameraUp,
        float elapsed,
        float reveal,
        float fade,
        Color[] palette)
    {
        if (rings == null || palette == null || palette.Length == 0)
            return;

        reveal = Mathf.Clamp01(reveal);
        fade = Mathf.Clamp01(fade);
        for (var index = 0; index < rings.Count; index++)
        {
            var renderer = rings[index];
            if (renderer == null)
                continue;

            var phase = elapsed * (1.35f + index * 0.22f) + index * 1.8f;
            var ringReveal = Mathf.Clamp01(reveal * (0.92f + index * 0.10f));
            var y = -0.72f + index * 0.44f + Mathf.Sin(phase) * 0.055f;
            var width = 0.78f + index * 0.22f;
            var height = 0.30f + index * 0.05f;
            var alpha = fade * ringReveal * (0.18f + index * 0.05f);
            renderer.enabled = alpha > 0.004f;
            if (!renderer.enabled)
                continue;

            renderer.transform.position = center
                + cameraUp * y
                + cameraForward * (-1.20f - index * 0.035f);
            renderer.transform.rotation = FrontBillboardRotation(
                cameraForward,
                cameraUp,
                phase * Mathf.Rad2Deg * (index % 2 == 0 ? 0.42f : -0.34f));
            renderer.transform.localScale = new Vector3(width, height, 1f) * ringReveal;
            var material = renderer.material;
            if (material != null && material.HasProperty("_Color"))
            {
                var color = palette[(index + 1) % palette.Length];
                material.SetColor("_Color", new Color(color.r, color.g, color.b, alpha));
                if (material.HasProperty("_Phase"))
                    material.SetFloat("_Phase", phase * 5.0f);
                if (material.HasProperty("_Distortion"))
                    material.SetFloat("_Distortion", 0.035f);
                if (material.HasProperty("_NoiseBreakup"))
                    material.SetFloat("_NoiseBreakup", 0.54f);
            }
        }
    }

    static void UpdateWildWardenReferenceLeaves(
        List<MeshRenderer> leaves,
        Vector3 center,
        Vector3 cameraRight,
        Vector3 cameraUp,
        Vector3 cameraForward,
        float elapsed,
        float reveal,
        float fade,
        Color[] palette)
    {
        if (leaves == null || palette == null || palette.Length == 0)
            return;

        reveal = Mathf.Clamp01(reveal);
        fade = Mathf.Clamp01(fade);
        for (var index = 0; index < leaves.Count; index++)
        {
            var renderer = leaves[index];
            if (renderer == null)
                continue;

            var seed = index * 0.6180339f;
            var phase = elapsed * (1.8f + (index % 5) * 0.23f) + seed * 8.0f;
            var orbit = phase + seed * 12.4f;
            var radius = Mathf.Lerp(0.22f, 0.94f, Mathf.Repeat(seed * 1.73f, 1f));
            radius *= 0.72f + reveal * 0.28f;
            var height = Mathf.Lerp(-0.58f, 1.24f, Mathf.Repeat(seed * 2.19f + 0.16f, 1f));
            height += Mathf.Sin(phase * 1.13f) * 0.13f;
            var x = Mathf.Cos(orbit) * radius;
            var y = height + Mathf.Sin(orbit * 1.21f) * 0.11f;
            var alpha = fade * reveal * (0.20f + (index % 4) * 0.045f)
                * (0.90f + Mathf.Sin(phase * 1.7f) * 0.10f);
            renderer.enabled = alpha > 0.004f;
            if (!renderer.enabled)
                continue;

            renderer.transform.position = center
                + cameraRight * x
                + cameraUp * y
                + cameraForward * (-1.08f - (index % 7) * 0.022f);
            renderer.transform.rotation = FrontBillboardRotation(
                cameraForward,
                cameraUp,
                phase * Mathf.Rad2Deg * 0.70f + index * 31f);
            var leafScale = 0.10f + (index % 5) * 0.024f;
            renderer.transform.localScale = new Vector3(
                leafScale * (0.74f + Mathf.Sin(phase) * 0.12f),
                leafScale * (0.62f + Mathf.Cos(phase * 1.2f) * 0.10f),
                1f);
            var material = renderer.material;
            if (material != null && material.HasProperty("_Color"))
            {
                var color = palette[index % palette.Length];
                material.SetColor("_Color", new Color(color.r, color.g, color.b, alpha));
            }
        }
    }

    static void UpdateWildWardenReferencePlumes(
        List<MeshRenderer> plumes,
        Vector3 center,
        Vector3 cameraRight,
        Vector3 cameraUp,
        Vector3 cameraForward,
        float elapsed,
        float reveal,
        float fade,
        Color[] palette)
    {
        if (plumes == null || palette == null || palette.Length == 0)
            return;

        var offsets = new[]
        {
            new Vector2(-0.54f, -0.08f),
            new Vector2(0.48f, 0.16f),
            new Vector2(-0.34f, 0.58f),
            new Vector2(0.36f, 0.78f),
            new Vector2(-0.10f, -0.62f),
            new Vector2(0.12f, 1.02f)
        };
        for (var index = 0; index < plumes.Count; index++)
        {
            var renderer = plumes[index];
            if (renderer == null)
                continue;

            var phase = elapsed * (1.2f + index * 0.18f) + index * 1.42f;
            var offset = offsets[index % offsets.Length];
            var alpha = fade * reveal * (0.14f + (index % 3) * 0.032f);
            renderer.enabled = alpha > 0.004f;
            if (!renderer.enabled)
                continue;

            renderer.transform.position = center
                + cameraRight * (offset.x + Mathf.Sin(phase) * 0.08f)
                + cameraUp * (offset.y + Mathf.Cos(phase * 1.13f) * 0.08f)
                + cameraForward * (-1.00f - index * 0.026f);
            renderer.transform.rotation = FrontBillboardRotation(
                cameraForward,
                cameraUp,
                index * 27f + Mathf.Sin(phase) * 18f);
            renderer.transform.localScale = new Vector3(
                0.42f + (index % 2) * 0.12f,
                0.46f + (index % 3) * 0.10f,
                1f) * Mathf.Lerp(0.12f, 1f, reveal);
            var material = renderer.material;
            if (material != null && material.HasProperty("_Color"))
            {
                var color = palette[(index + 1) % palette.Length];
                material.SetColor("_Color", new Color(color.r, color.g, color.b, alpha));
            }
        }
    }

    static void UpdateWildWardenReferenceAurora(
        List<MeshRenderer> cards,
        Vector3 center,
        Vector3 cameraRight,
        Vector3 cameraUp,
        Vector3 cameraForward,
        float elapsed,
        float reveal,
        float fade,
        Color[] palette)
    {
        if (cards == null || palette == null || palette.Length == 0)
            return;

        var offsets = new[] { -0.26f, 0.02f, 0.30f };
        for (var index = 0; index < cards.Count; index++)
        {
            var renderer = cards[index];
            if (renderer == null)
                continue;

            var phase = elapsed * (1.6f + index * 0.18f) + index * 1.7f;
            var alpha = fade * reveal * (0.24f + index * 0.035f);
            renderer.enabled = alpha > 0.004f;
            if (!renderer.enabled)
                continue;

            renderer.transform.position = center
                + cameraRight * (offsets[index % offsets.Length] + Mathf.Sin(phase) * 0.06f)
                + cameraUp * (0.18f + index * 0.14f + Mathf.Cos(phase) * 0.07f)
                + cameraForward * (-1.15f - index * 0.035f);
            renderer.transform.rotation = FrontBillboardRotation(
                cameraForward,
                cameraUp,
                Mathf.Sin(phase * 0.72f) * 14f + index * 9f);
            renderer.transform.localScale = new Vector3(
                0.30f + index * 0.035f,
                1.08f + index * 0.12f,
                1f) * Mathf.Lerp(0.10f, 1f, reveal);
            var material = renderer.material;
            if (material != null && material.HasProperty("_Color"))
            {
                var color = palette[(index + 2) % palette.Length];
                material.SetColor("_Color", new Color(color.r, color.g, color.b, alpha));
                if (material.HasProperty("_Phase"))
                    material.SetFloat("_Phase", phase * 6.0f);
                if (material.HasProperty("_Distortion"))
                    material.SetFloat("_Distortion", 0.085f);
                if (material.HasProperty("_NoiseBreakup"))
                    material.SetFloat("_NoiseBreakup", 0.58f);
            }
        }
    }

    static void UpdateFireElementalistReferenceTravel(
        List<LineRenderer> glows,
        List<LineRenderer> cores,
        List<MeshRenderer> flames,
        MeshRenderer hotMass,
        Vector3 source,
        Vector3 destination,
        Camera camera,
        Vector3 cameraRight,
        Vector3 cameraUp,
        Vector3 cameraForward,
        float elapsed,
        float flight,
        float reveal,
        float fade,
        Color[] palette)
    {
        if (glows == null || cores == null || palette == null || palette.Length == 0)
            return;

        flight = Mathf.Clamp01(flight);
        reveal = Mathf.Clamp01(reveal);
        fade = Mathf.Clamp01(fade);
        var current = Vector3.Lerp(source, destination, flight)
            + cameraUp * Mathf.Sin(flight * Mathf.PI) * 0.22f;
        for (var index = 0; index < glows.Count && index < cores.Count; index++)
        {
            var glow = glows[index];
            var core = cores[index];
            if (glow == null || core == null)
                continue;

            var head = Mathf.Clamp01(flight + 0.035f - index * 0.018f);
            var tail = Mathf.Clamp01(head - (0.30f + index * 0.025f));
            var points = new Vector3[glow.positionCount];
            for (var point = 0; point < points.Length; point++)
            {
                var t = Mathf.Lerp(tail, head, point / (float)(points.Length - 1));
                var basePoint = Vector3.Lerp(source, destination, t)
                    + cameraUp * Mathf.Sin(t * Mathf.PI) * 0.22f;
                var curl = Mathf.Sin(t * 7.0f + elapsed * (5.2f + index * 0.4f) + index) * 0.09f;
                var lift = Mathf.Sin(t * Mathf.PI) * (0.055f + index * 0.012f);
                points[point] = basePoint
                    + cameraRight * curl
                    + cameraUp * lift
                    + cameraForward * (-0.95f - index * 0.035f);
            }
            var color = palette[(index + 1) % palette.Length];
            var shimmer = 0.90f + Mathf.Sin(elapsed * 18f + index * 1.7f) * 0.10f;
            UpdateFrontRibbon(
                glow,
                points,
                (0.145f - index * 0.018f) * shimmer,
                color,
                fade * reveal * 0.72f * shimmer);
            var corePoints = new Vector3[points.Length];
            for (var point = 0; point < points.Length; point++)
                corePoints[point] = points[point] + cameraForward * -0.020f;
            UpdateFrontRibbon(
                core,
                corePoints,
                0.030f - index * 0.003f,
                Color.Lerp(new Color(1f, 0.86f, 0.35f), color, 0.18f),
                fade * reveal * 0.84f * shimmer);
        }

        if (flames != null)
        {
            for (var index = 0; index < flames.Count; index++)
            {
                var renderer = flames[index];
                if (renderer == null)
                    continue;
                var trailT = Mathf.Clamp01(flight - (index + 1) * 0.055f);
                var phase = elapsed * (5.0f + index * 0.24f) + index * 1.7f;
                var position = Vector3.Lerp(source, destination, trailT)
                    + cameraUp * (Mathf.Sin(trailT * Mathf.PI) * 0.22f
                        + Mathf.Sin(phase) * 0.10f)
                    + cameraRight * Mathf.Sin(phase * 0.82f) * 0.14f
                    + cameraForward * (-1.12f - index * 0.025f);
                var alpha = fade * reveal * (0.16f + (index % 3) * 0.035f);
                renderer.enabled = alpha > 0.004f;
                if (!renderer.enabled)
                    continue;
                renderer.transform.position = position;
                renderer.transform.rotation = FrontBillboardRotation(
                    cameraForward,
                    cameraUp,
                    -28f + index * 31f + Mathf.Sin(phase) * 16f);
                renderer.transform.localScale = new Vector3(
                    0.22f + (index % 3) * 0.05f,
                    0.38f + (index % 2) * 0.12f,
                    1f) * Mathf.Lerp(0.20f, 1f, reveal);
                var material = renderer.material;
                if (material != null && material.HasProperty("_Color"))
                {
                    var color = palette[(index + 2) % palette.Length];
                    material.SetColor("_Color", new Color(color.r, color.g, color.b, alpha));
                    if (material.HasProperty("_Phase"))
                        material.SetFloat("_Phase", phase * 5.5f);
                    if (material.HasProperty("_Distortion"))
                        material.SetFloat("_Distortion", 0.070f);
                    if (material.HasProperty("_NoiseBreakup"))
                        material.SetFloat("_NoiseBreakup", 0.40f);
                }
            }
        }

        UpdateReferenceFlowSprite(
            hotMass,
            current + cameraForward * -1.44f,
            camera,
            elapsed * -24f,
            new Vector3(0.24f, 0.34f, 1f) * Mathf.Lerp(0.50f, 1.14f, flight),
            fade * reveal * 0.64f,
            new Color(1f, 0.50f, 0.08f),
            elapsed * -10f,
            0.065f,
            0.36f);
    }

    static void UpdateFireElementalistReferenceImpact(
        List<MeshRenderer> flames,
        List<MeshRenderer> smoke,
        List<LineRenderer> arcs,
        MeshRenderer groundRing,
        MeshRenderer core,
        MeshRenderer hot,
        MeshRenderer impactMass,
        MeshRenderer impactMassCore,
        Vector3 center,
        Camera camera,
        Vector3 cameraRight,
        Vector3 cameraUp,
        Vector3 cameraForward,
        float elapsed,
        float reveal,
        float fade,
        Color[] palette)
    {
        if (palette == null || palette.Length == 0)
            return;

        reveal = Mathf.Clamp01(reveal);
        fade = Mathf.Clamp01(fade);
        if (flames != null)
        {
            var xOffsets = new[] { -0.62f, 0.02f, 0.62f };
            for (var index = 0; index < flames.Count; index++)
            {
                var renderer = flames[index];
                if (renderer == null)
                    continue;
                var column = index % xOffsets.Length;
                var row = index / xOffsets.Length;
                var phase = elapsed * (2.4f + index * 0.11f) + index * 1.4f;
                var x = xOffsets[column] * Mathf.Lerp(0.20f, 1f, reveal)
                    + Mathf.Sin(phase) * 0.07f;
                var y = -0.10f + row * 0.30f + Mathf.Cos(phase * 1.12f) * 0.08f;
                var alpha = fade * reveal * (0.30f + (index % 3) * 0.045f);
                renderer.enabled = alpha > 0.004f;
                if (!renderer.enabled)
                    continue;
                renderer.transform.position = center
                    + cameraRight * x
                    + cameraUp * y
                    + cameraForward * (-1.34f - row * 0.035f);
                renderer.transform.rotation = FrontBillboardRotation(
                    cameraForward,
                    cameraUp,
                    -18f + column * 13f + Mathf.Sin(phase) * 13f);
                renderer.transform.localScale = new Vector3(
                    0.58f + (index % 3) * 0.08f,
                    0.94f + row * 0.13f + (index % 2) * 0.10f,
                    1f) * Mathf.Lerp(0.12f, 1f, reveal);
                var material = renderer.material;
                if (material != null && material.HasProperty("_Color"))
                {
                    var color = palette[(index + 1) % palette.Length];
                    material.SetColor("_Color", new Color(color.r, color.g, color.b, alpha));
                    if (material.HasProperty("_Phase"))
                        material.SetFloat("_Phase", phase * 5.2f);
                    if (material.HasProperty("_Distortion"))
                        material.SetFloat("_Distortion", 0.080f);
                    if (material.HasProperty("_NoiseBreakup"))
                        material.SetFloat("_NoiseBreakup", 0.46f);
                }
            }
        }

        UpdateProceduralVolumeSprite(
            impactMass,
            center + cameraUp * 0.10f + cameraForward * -1.42f,
            camera,
            Mathf.Sin(elapsed * 2.1f) * 2.0f,
            new Vector3(2.78f, 1.68f, 1f) * reveal,
            fade * reveal * 0.88f,
            Color.white,
            -elapsed * 8.5f,
            1.18f,
            0.16f,
            0.095f);
        UpdateProceduralVolumeSprite(
            impactMassCore,
            center + cameraUp * 0.10f + cameraForward * -1.56f,
            camera,
            Mathf.Sin(elapsed * 2.1f + 0.8f) * 1.5f,
            new Vector3(1.74f, 1.26f, 1f) * reveal,
            fade * reveal * 0.72f,
            Color.white,
            elapsed * 12.0f,
            1.10f,
            0.72f,
            0.065f);

        if (smoke != null)
        {
            for (var index = 0; index < smoke.Count; index++)
            {
                var renderer = smoke[index];
                if (renderer == null)
                    continue;
                var phase = elapsed * (1.2f + index * 0.18f) + index * 2.1f;
                var alpha = fade * reveal * (0.10f + index * 0.018f);
                renderer.enabled = alpha > 0.004f;
                if (!renderer.enabled)
                    continue;
                renderer.transform.position = center
                    + cameraRight * (Mathf.Sin(phase) * (0.58f + index * 0.07f))
                    + cameraUp * (0.18f + index * 0.18f + Mathf.Cos(phase) * 0.10f)
                    + cameraForward * (-1.08f - index * 0.028f);
                renderer.transform.rotation = FrontBillboardRotation(
                    cameraForward,
                    cameraUp,
                    phase * Mathf.Rad2Deg * 0.38f + index * 24f);
                renderer.transform.localScale = new Vector3(
                    0.52f + index * 0.06f,
                    0.36f + index * 0.08f,
                    1f) * Mathf.Lerp(0.12f, 1f, reveal);
                var material = renderer.material;
                if (material != null && material.HasProperty("_Color"))
                {
                    material.SetColor("_Color", new Color(0.32f, 0.012f, 0.004f, alpha));
                    if (material.HasProperty("_Phase"))
                        material.SetFloat("_Phase", phase * 4.5f);
                    if (material.HasProperty("_Distortion"))
                        material.SetFloat("_Distortion", 0.095f);
                    if (material.HasProperty("_NoiseBreakup"))
                        material.SetFloat("_NoiseBreakup", 0.64f);
                }
            }
        }

        if (arcs != null)
        {
            for (var index = 0; index < arcs.Count; index++)
            {
                var line = arcs[index];
                if (line == null)
                    continue;
                var points = new Vector3[line.positionCount];
                var side = index == 2 ? 0f : (index % 2 == 0 ? -1f : 1f);
                for (var point = 0; point < points.Length; point++)
                {
                    var t = point / (float)(points.Length - 1);
                    var visibleT = Mathf.Clamp01(t * Mathf.Lerp(0.14f, 1.10f, reveal));
                    var x = side * (0.06f + visibleT * (0.72f + index * 0.045f));
                    if (Mathf.Abs(side) < 0.01f)
                        x = Mathf.Sin(visibleT * Mathf.PI) * 0.12f;
                    x += Mathf.Sin(visibleT * 6.4f + elapsed * (4f + index)) * 0.075f;
                    var y = -0.44f + visibleT * (1.56f + (index % 2) * 0.16f)
                        + Mathf.Sin(visibleT * Mathf.PI) * (0.20f + index * 0.018f);
                    var depth = -1.54f - index * 0.035f
                        + Mathf.Sin(visibleT * 4f + elapsed * 2.2f) * 0.05f;
                    points[point] = center
                        + cameraRight * x
                        + cameraUp * y
                        + cameraForward * depth;
                }
                var color = palette[(index + 2) % palette.Length];
                var shimmer = 0.90f + Mathf.Sin(elapsed * 17f + index) * 0.10f;
                UpdateFrontRibbon(
                    line,
                    points,
                    (0.20f - index * 0.020f) * shimmer,
                    color,
                    fade * reveal * 0.82f * shimmer);
            }
        }

        UpdateProceduralVolumeSprite(
            groundRing,
            center + cameraUp * -0.68f + cameraForward * -1.62f,
            camera,
            elapsed * -22f,
            new Vector3(1.78f, 0.58f, 1f) * reveal,
            0f,
            Color.white,
            elapsed * -9.0f,
            0f,
            0f,
            0f);
        UpdateProceduralVolumeSprite(
            core,
            center + cameraUp * 0.04f + cameraForward * -1.70f,
            camera,
            Mathf.Sin(elapsed * 2.1f + 1.1f) * 1.0f,
            new Vector3(0.86f, 0.86f, 1f) * reveal,
            fade * reveal * 0.68f,
            Color.white,
            elapsed * 16.0f,
            1.02f,
            0.62f,
            0.045f);
        var hotPulse = 0.92f + Mathf.Sin(elapsed * 22f) * 0.08f;
        UpdateProceduralVolumeSprite(
            hot,
            center + cameraUp * 0.05f + cameraForward * -1.80f,
            camera,
            0f,
            new Vector3(0.30f, 0.34f, 1f) * reveal * hotPulse,
            fade * reveal * 0.62f,
            Color.white,
            -elapsed * 19.0f,
            1.12f,
            0.96f,
            0.035f);
    }

    static void UpdateFrontShroud(
        List<LineRenderer> ribbons,
        Vector3 center,
        Vector3 cameraRight,
        Vector3 cameraUp,
        Vector3 cameraForward,
        float elapsed,
        float reveal,
        float fade,
        int pattern,
        Color[] palette)
    {
        if (ribbons == null || ribbons.Count == 0 || palette == null || palette.Length == 0)
            return;

        reveal = Mathf.Clamp01(reveal);
        fade = Mathf.Clamp01(fade);
        for (var index = 0; index < ribbons.Count; index++)
        {
            var line = ribbons[index];
            var laneT = (index + 0.5f) / ribbons.Count;
            var baseX = Mathf.Lerp(-1.02f, 1.02f, laneT);
            var phase = index * 1.71f + pattern * 2.13f;
            var bottom = -1.28f + Mathf.Sin(phase * 1.7f) * 0.12f;
            var top = 1.30f + Mathf.Sin(phase * 2.1f + 0.8f) * 0.16f;
            var pathReveal = Mathf.Clamp01(reveal * (1.04f + Mathf.Sin(elapsed * 9f + phase) * 0.08f));
            var points = new Vector3[line.positionCount];

            for (var point = 0; point < points.Length; point++)
            {
                var t = point / (float)(points.Length - 1);
                var sampleT = Mathf.Clamp01(t * pathReveal);
                var y = Mathf.Lerp(bottom, top, sampleT);
                var x = baseX;

                if (pattern == 0)
                {
                    // Sword qi: diagonal, broken lanes that cross the body.
                    x += y * (0.16f + (index % 3) * 0.035f);
                    x += Mathf.Sin(sampleT * 8.4f + elapsed * 13f + phase) * 0.075f;
                    y += Mathf.Sin(sampleT * 5.8f + elapsed * 10f + phase) * 0.045f;
                }
                else if (pattern == 1)
                {
                    // Fire: tongues pinch, bend, and split as they rise.
                    var flameT = Mathf.Sin(sampleT * Mathf.PI);
                    x += Mathf.Sin(sampleT * 7.2f + elapsed * 15f + phase) * (0.06f + flameT * 0.12f);
                    x += Mathf.Sin(sampleT * 15.5f + phase * 1.9f) * 0.035f;
                    y += Mathf.Sin(sampleT * Mathf.PI * 2f + phase) * 0.035f;
                }
                else
                {
                    // Tornado: front-facing helixes, not a closed ring.
                    var height = Mathf.InverseLerp(-1.35f, 1.35f, y) * 2f - 1f;
                    var curl = 0.16f + Mathf.Abs(height) * 0.28f;
                    x = baseX * 0.62f
                        + Mathf.Sin(y * 2.45f + elapsed * 6.4f + phase) * curl
                        + Mathf.Sin(y * 5.1f - elapsed * 3.2f + phase) * 0.045f;
                }

                var depth = -0.78f - (index % 5) * 0.014f - point * 0.003f;
                points[point] = center
                    + cameraRight * x
                    + cameraUp * y
                    + cameraForward * depth;
            }

            var paletteColor = palette[index % palette.Length];
            var shimmer = 0.86f + Mathf.Sin(elapsed * (17f + index * 0.23f) + phase) * 0.14f;
            var alpha = fade * reveal * shimmer * (pattern == 1 ? 0.94f : 0.90f);
            var width = (0.235f - (index % 4) * 0.018f)
                * (0.90f + Mathf.Sin(elapsed * 8f + phase) * 0.10f);
            UpdateFrontRibbon(line, points, width, paletteColor, alpha);
        }
    }

    static void UpdateSwordFrontCuts(
        List<LineRenderer> glows,
        List<LineRenderer> cores,
        Vector3 center,
        Vector3 cameraRight,
        Vector3 cameraUp,
        Vector3 cameraForward,
        float elapsed,
        float reveal,
        float fade)
    {
        if (glows == null || cores == null)
            return;

        var angles = new[] { -54f, 44f, 58f };
        var offsets = new[] { 0.10f, -0.06f, 0.16f };
        reveal = Mathf.Clamp01(reveal);
        fade = Mathf.Clamp01(fade);
        for (var index = 0; index < glows.Count && index < cores.Count; index++)
        {
            var glow = glows[index];
            var core = cores[index];
            if (glow == null || core == null)
                continue;

            var angle = angles[index % angles.Length] * Mathf.Deg2Rad;
            var direction = cameraRight * Mathf.Cos(angle) + cameraUp * Mathf.Sin(angle);
            var normal = cameraRight * -Mathf.Sin(angle) + cameraUp * Mathf.Cos(angle);
            var auxiliary = index >= 2 ? 0.56f : 1f;
            var length = Mathf.Lerp(0.10f, (1.82f - index * 0.08f) * (index >= 2 ? 0.84f : 1f), reveal);
            var linePoints = new Vector3[glow.positionCount];
            for (var point = 0; point < linePoints.Length; point++)
            {
                var t = point / (float)(linePoints.Length - 1);
                var wobble = Mathf.Sin(t * 8.0f + elapsed * (9.0f + index) + index * 1.7f) * 0.035f;
                var bow = Mathf.Sin(t * Mathf.PI) * (0.07f + index * 0.012f);
                var lane = offsets[index % offsets.Length] * Mathf.Lerp(0.24f, 1f, reveal);
                linePoints[point] = center
                    + direction * ((t - 0.5f) * length)
                    + normal * (lane + bow + wobble)
                    + cameraForward * (-1.28f - index * 0.035f);
            }

            var shimmer = 0.88f + Mathf.Sin(elapsed * 23f + index * 1.9f) * 0.12f;
            UpdateFrontRibbon(
                glow,
                linePoints,
                (0.17f - index * 0.016f) * (0.94f + shimmer * 0.06f),
                index % 2 == 0
                    ? new Color(0.05f, 0.60f, 1f)
                    : new Color(0.52f, 0.18f, 1f),
                fade * reveal * 0.70f * shimmer * auxiliary);

            var corePoints = new Vector3[linePoints.Length];
            for (var point = 0; point < linePoints.Length; point++)
                corePoints[point] = linePoints[point] + cameraForward * -0.018f;
            UpdateFrontRibbon(core, corePoints, 0.042f - index * 0.003f,
                new Color(0.90f, 0.98f, 1f), fade * reveal * 0.84f * shimmer * auxiliary);
        }
    }

    static void UpdateSwordFrontCards(
        List<MeshRenderer> cards,
        Vector3 center,
        Vector3 cameraRight,
        Vector3 cameraUp,
        Vector3 cameraForward,
        float elapsed,
        float reveal,
        float fade,
        Color[] palette)
    {
        if (cards == null || palette == null || palette.Length == 0)
            return;

        var offsets = new[]
        {
            new Vector2(-0.34f, 0.30f),
            new Vector2(0.30f, 0.16f),
            new Vector2(-0.18f, -0.30f),
            new Vector2(0.38f, -0.26f),
            new Vector2(0.02f, 0.02f),
            new Vector2(-0.42f, -0.10f)
        };
        var rolls = new[] { -50f, 36f, -68f, 28f, 8f, -32f };
        reveal = Mathf.Clamp01(reveal);
        fade = Mathf.Clamp01(fade);
        for (var index = 0; index < cards.Count; index++)
        {
            var renderer = cards[index];
            if (renderer == null)
                continue;

            var offset = offsets[index % offsets.Length];
            var jitter = Mathf.Sin(elapsed * (8f + index) + index * 1.8f) * 0.045f;
            var position = center
                + cameraRight * (offset.x + jitter)
                + cameraUp * (offset.y + Mathf.Cos(elapsed * 7f + index) * 0.035f)
                + cameraForward * (-1.36f - index * 0.025f);
            var scaleReveal = Mathf.Lerp(0.08f, 1f, reveal);
            var width = Mathf.Lerp(0.62f, 0.96f, Mathf.Repeat(index * 0.37f, 1f));
            var height = Mathf.Lerp(0.80f, 1.28f, Mathf.Repeat(index * 0.29f + 0.2f, 1f));
            var alpha = fade * reveal * (0.60f + (index % 3) * 0.10f);
            renderer.enabled = alpha > 0.004f;
            if (!renderer.enabled)
                continue;

            renderer.transform.position = position;
            renderer.transform.rotation = FrontBillboardRotation(
                cameraForward,
                cameraUp,
                rolls[index % rolls.Length] + Mathf.Sin(elapsed * 6f + index) * 5f);
            renderer.transform.localScale = new Vector3(width, height, 1f) * scaleReveal;
            var material = renderer.material;
            if (material != null && material.HasProperty("_Color"))
            {
                var color = palette[index % palette.Length];
                material.SetColor("_Color", new Color(color.r, color.g, color.b, alpha));
            }
        }
    }

    static void UpdateSwordImpactHaze(
        List<MeshRenderer> cards,
        Vector3 center,
        Vector3 cameraRight,
        Vector3 cameraUp,
        Vector3 cameraForward,
        float elapsed,
        float reveal,
        float fade)
    {
        if (cards == null)
            return;

        var offsets = new[]
        {
            new Vector2(0.00f, 0.02f),
            new Vector2(-0.20f, -0.12f),
            new Vector2(0.22f, 0.18f)
        };
        var scales = new[]
        {
            new Vector2(0.84f, 0.74f),
            new Vector2(0.68f, 0.62f),
            new Vector2(0.72f, 0.66f)
        };
        reveal = Mathf.Clamp01(reveal);
        fade = Mathf.Clamp01(fade);
        for (var index = 0; index < cards.Count; index++)
        {
            var renderer = cards[index];
            if (renderer == null)
                continue;
            var offset = offsets[index % offsets.Length];
            var scale = scales[index % scales.Length];
            var pulse = 0.92f + Mathf.Sin(elapsed * 13f + index * 1.4f) * 0.08f;
            var alpha = fade * reveal * (index == 0 ? 0.30f : 0.22f) * pulse;
            renderer.enabled = alpha > 0.004f;
            if (!renderer.enabled)
                continue;

            renderer.transform.position = center
                + cameraRight * offset.x
                + cameraUp * offset.y
                + cameraForward * (-1.43f - index * 0.02f);
            renderer.transform.rotation = FrontBillboardRotation(
                cameraForward,
                cameraUp,
                Mathf.Sin(elapsed * 9f + index) * 18f + index * 34f);
            renderer.transform.localScale = new Vector3(scale.x, scale.y, 1f)
                * Mathf.Lerp(0.12f, 1f, reveal);
            var material = renderer.material;
            if (material != null && material.HasProperty("_Color"))
                material.SetColor("_Color", new Color(0.48f, 0.84f, 1f, alpha));
        }
    }

    static void UpdateSwordCoreBurst(
        List<MeshRenderer> cards,
        Vector3 center,
        Vector3 cameraRight,
        Vector3 cameraUp,
        Vector3 cameraForward,
        float elapsed,
        float reveal,
        float fade)
    {
        if (cards == null)
            return;

        var offsets = new[] { new Vector2(0.00f, 0.02f), new Vector2(0.08f, -0.08f) };
        var scales = new[] { new Vector2(0.72f, 1.08f), new Vector2(0.48f, 0.76f) };
        reveal = Mathf.Clamp01(reveal);
        fade = Mathf.Clamp01(fade);
        for (var index = 0; index < cards.Count; index++)
        {
            var renderer = cards[index];
            if (renderer == null)
                continue;
            var pulse = 0.92f + Mathf.Sin(elapsed * 21f + index * 1.7f) * 0.08f;
            var alpha = fade * reveal * (index == 0 ? 0.42f : 0.28f) * pulse;
            renderer.enabled = alpha > 0.004f;
            if (!renderer.enabled)
                continue;

            var offset = offsets[index % offsets.Length];
            var scale = scales[index % scales.Length];
            renderer.transform.position = center
                + cameraRight * offset.x
                + cameraUp * offset.y
                + cameraForward * (-1.50f - index * 0.024f);
            renderer.transform.rotation = FrontBillboardRotation(
                cameraForward,
                cameraUp,
                elapsed * (index == 0 ? -22f : 31f) + index * 24f);
            renderer.transform.localScale = new Vector3(scale.x, scale.y, 1f)
                * Mathf.Lerp(0.10f, 1f, reveal);
            var material = renderer.material;
            if (material != null && material.HasProperty("_Color"))
                material.SetColor("_Color", new Color(0.66f, 0.90f, 1f, alpha));
        }
    }

    static void UpdateFireBurstCards(
        List<MeshRenderer> flames,
        List<MeshRenderer> smoke,
        Vector3 center,
        Vector3 cameraRight,
        Vector3 cameraUp,
        Vector3 cameraForward,
        float elapsed,
        float reveal,
        float fade)
    {
        reveal = Mathf.Clamp01(reveal);
        fade = Mathf.Clamp01(fade);
        var flamePalette = new[]
        {
            new Color(0.78f, 0.025f, 0.004f),
            new Color(1f, 0.10f, 0.006f),
            new Color(1f, 0.34f, 0.018f),
            new Color(1f, 0.78f, 0.14f),
            new Color(1f, 0.96f, 0.55f)
        };
        if (flames != null)
        {
            for (var index = 0; index < flames.Count; index++)
            {
                var renderer = flames[index];
                if (renderer == null)
                    continue;

                var angle = index * Mathf.PI * 2f / Mathf.Max(1, flames.Count)
                    + elapsed * (0.85f + (index % 3) * 0.16f);
                var inner = index < 2;
                var radius = inner
                    ? 0.045f + index * 0.055f
                    : 0.24f + (index % 4) * 0.11f;
                radius *= Mathf.Lerp(0.10f, 1f, reveal);
                var position = center
                    + cameraRight * Mathf.Cos(angle) * radius * 1.04f
                    + cameraUp * Mathf.Sin(angle) * radius * 0.82f
                    + cameraForward * (-1.34f - index * 0.018f);
                var width = inner ? 0.82f : Mathf.Lerp(0.43f, 0.70f, (index % 5) / 4f);
                var height = inner ? 0.92f : Mathf.Lerp(0.58f, 1.02f, (index % 4) / 3f);
                var alpha = fade * reveal * (inner ? 0.92f : 0.66f);
                renderer.enabled = alpha > 0.004f;
                if (!renderer.enabled)
                    continue;

                renderer.transform.position = position;
                renderer.transform.rotation = FrontBillboardRotation(
                    cameraForward,
                    cameraUp,
                    angle * Mathf.Rad2Deg - 90f + Mathf.Sin(elapsed * 8f + index) * 8f);
                renderer.transform.localScale = new Vector3(width, height, 1f)
                    * Mathf.Lerp(0.10f, 1f, reveal);
                var material = renderer.material;
                if (material != null && material.HasProperty("_Color"))
                {
                    var color = flamePalette[index % flamePalette.Length];
                    material.SetColor("_Color", new Color(color.r, color.g, color.b, alpha));
                }
            }
        }

        if (smoke == null)
            return;
        for (var index = 0; index < smoke.Count; index++)
        {
            var renderer = smoke[index];
            if (renderer == null)
                continue;
            var angle = index * Mathf.PI * 0.5f + elapsed * (0.55f + index * 0.12f) + 0.35f;
            var radius = (0.40f + index * 0.075f) * Mathf.Lerp(0.10f, 1f, reveal);
            var alpha = fade * reveal * (0.22f + index * 0.018f);
            renderer.enabled = alpha > 0.004f;
            if (!renderer.enabled)
                continue;

            renderer.transform.position = center
                + cameraRight * Mathf.Cos(angle) * radius
                + cameraUp * (Mathf.Sin(angle) * radius * 0.72f + 0.06f)
                + cameraForward * (-1.38f - index * 0.024f);
            renderer.transform.rotation = FrontBillboardRotation(
                cameraForward,
                cameraUp,
                angle * Mathf.Rad2Deg + 22f);
            renderer.transform.localScale = new Vector3(0.68f, 0.55f, 1f)
                * Mathf.Lerp(0.10f, 1f, reveal);
            var material = renderer.material;
            if (material != null && material.HasProperty("_Color"))
                material.SetColor("_Color", new Color(0.70f, 0.028f, 0.004f, alpha));
        }
    }

    static void UpdateReferenceFireballSplash(
        List<MeshRenderer> flames,
        List<MeshRenderer> smoke,
        List<MeshRenderer> coreFlames,
        MeshRenderer solarBody,
        Vector3 center,
        Vector3 cameraRight,
        Vector3 cameraUp,
        Vector3 cameraForward,
        float elapsed,
        float reveal,
        float fade)
    {
        reveal = Mathf.Clamp01(reveal);
        fade = Mathf.Clamp01(fade);
        var grow = Mathf.Lerp(0.12f, 1.14f, reveal);

        // These offsets are intentionally wide and asymmetric. The reference
        // is a horizontal painted fire splash around the waist, not a sphere
        // and not a vertical column. Large cards overlap to cover the actor,
        // while their separated edges keep the silhouette legible.
        var outerOffsets = new[]
        {
            new Vector2(-1.12f, 0.12f),
            new Vector2(-0.88f, -0.32f),
            new Vector2(-0.68f, 0.46f),
            new Vector2(-0.44f, -0.60f),
            new Vector2(-0.22f, 0.25f),
            new Vector2(0.04f, -0.26f),
            new Vector2(0.28f, 0.48f),
            new Vector2(0.54f, -0.18f),
            new Vector2(0.78f, 0.30f),
            new Vector2(1.05f, -0.20f),
            new Vector2(-0.86f, -0.76f),
            new Vector2(-0.34f, -0.86f),
            new Vector2(0.18f, -0.80f),
            new Vector2(0.72f, -0.70f)
        };
        var outerScales = new[]
        {
            new Vector2(1.08f, 0.58f),
            new Vector2(0.92f, 0.68f),
            new Vector2(0.86f, 0.76f),
            new Vector2(0.82f, 0.58f),
            new Vector2(0.96f, 0.72f),
            new Vector2(1.02f, 0.64f),
            new Vector2(0.92f, 0.76f),
            new Vector2(0.98f, 0.56f),
            new Vector2(1.08f, 0.64f),
            new Vector2(0.94f, 0.66f),
            new Vector2(1.16f, 0.72f),
            new Vector2(1.08f, 0.66f),
            new Vector2(1.00f, 0.62f),
            new Vector2(1.18f, 0.70f)
        };
        var outerPalette = new[]
        {
            new Color(0.72f, 0.018f, 0.003f),
            new Color(0.94f, 0.035f, 0.004f),
            new Color(1f, 0.12f, 0.006f),
            new Color(1f, 0.25f, 0.012f),
            new Color(1f, 0.42f, 0.018f),
            new Color(1f, 0.68f, 0.055f),
            new Color(0.86f, 0.025f, 0.003f)
        };
        if (flames != null)
        {
            for (var index = 0; index < flames.Count; index++)
            {
                var renderer = flames[index];
                if (renderer == null)
                    continue;

                var phase = elapsed * (2.6f + index * 0.17f) + index * 1.91f;
                var offset = outerOffsets[index % outerOffsets.Length];
                var scale = outerScales[index % outerScales.Length];
                var position = center
                    + cameraRight * (offset.x * grow + Mathf.Sin(phase) * 0.035f)
                    + cameraUp * (offset.y * grow + Mathf.Cos(phase * 1.17f) * 0.035f)
                    + cameraForward * (-1.12f - index * 0.012f);
                var pulse = 0.94f + Mathf.Sin(phase * 1.31f) * 0.06f;
                var alpha = fade * reveal * (0.44f + (index % 4) * 0.048f) * pulse;
                renderer.enabled = alpha > 0.004f;
                if (!renderer.enabled)
                    continue;

                renderer.transform.position = position;
                renderer.transform.rotation = FrontBillboardRotation(
                    cameraForward,
                    cameraUp,
                    -38f + index * 27f + Mathf.Sin(phase * 0.91f) * 10f);
                renderer.transform.localScale = new Vector3(
                    scale.x * grow * pulse,
                    scale.y * grow * pulse,
                    1f);
                var material = renderer.material;
                if (material != null && material.HasProperty("_Color"))
                {
                    var color = outerPalette[index % outerPalette.Length];
                    material.SetColor("_Color", new Color(color.r, color.g, color.b, alpha));
                }
            }
        }

        var smokeOffsets = new[]
        {
            new Vector2(-1.04f, 0.42f),
            new Vector2(-0.62f, -0.58f),
            new Vector2(0.12f, 0.62f),
            new Vector2(0.70f, -0.46f),
            new Vector2(1.00f, 0.26f)
        };
        var smokeScales = new[]
        {
            new Vector2(1.12f, 0.52f),
            new Vector2(1.02f, 0.60f),
            new Vector2(0.96f, 0.54f),
            new Vector2(1.08f, 0.58f),
            new Vector2(0.92f, 0.50f)
        };
        if (smoke != null)
        {
            for (var index = 0; index < smoke.Count; index++)
            {
                var renderer = smoke[index];
                if (renderer == null)
                    continue;

                var phase = elapsed * (1.45f + index * 0.15f) + index * 2.32f;
                var offset = smokeOffsets[index % smokeOffsets.Length];
                var scale = smokeScales[index % smokeScales.Length];
                var alpha = fade * reveal * (0.20f + index * 0.020f);
                renderer.enabled = alpha > 0.004f;
                if (!renderer.enabled)
                    continue;

                renderer.transform.position = center
                    + cameraRight * (offset.x * grow + Mathf.Sin(phase) * 0.04f)
                    + cameraUp * (offset.y * grow + Mathf.Cos(phase) * 0.04f)
                    + cameraForward * (-1.00f - index * 0.016f);
                renderer.transform.rotation = FrontBillboardRotation(
                    cameraForward,
                    cameraUp,
                    index * 41f + Mathf.Sin(phase) * 14f);
                renderer.transform.localScale = new Vector3(
                    scale.x * grow,
                    scale.y * grow,
                    1f);
                var material = renderer.material;
                if (material != null && material.HasProperty("_Color"))
                {
                    var color = index % 2 == 0
                        ? new Color(0.68f, 0.018f, 0.003f)
                        : new Color(0.96f, 0.14f, 0.008f);
                    material.SetColor("_Color", new Color(color.r, color.g, color.b, alpha));
                }
            }
        }

        var coreOffsets = new[]
        {
            new Vector2(-0.38f, 0.14f),
            new Vector2(-0.18f, 0.25f),
            new Vector2(0.02f, 0.10f),
            new Vector2(0.20f, 0.23f),
            new Vector2(0.40f, 0.08f),
            new Vector2(-0.22f, -0.18f),
            new Vector2(0.18f, -0.23f)
        };
        var coreScales = new[]
        {
            new Vector2(0.70f, 0.56f),
            new Vector2(0.76f, 0.62f),
            new Vector2(0.84f, 0.68f),
            new Vector2(0.72f, 0.60f),
            new Vector2(0.66f, 0.54f),
            new Vector2(0.82f, 0.62f),
            new Vector2(0.78f, 0.58f)
        };
        var corePalette = new[]
        {
            new Color(0.94f, 0.04f, 0.003f),
            new Color(1f, 0.16f, 0.006f),
            new Color(1f, 0.34f, 0.012f),
            new Color(1f, 0.62f, 0.035f),
            new Color(1f, 0.88f, 0.20f)
        };
        if (coreFlames != null)
        {
            for (var index = 0; index < coreFlames.Count; index++)
            {
                var renderer = coreFlames[index];
                if (renderer == null)
                    continue;

                var phase = elapsed * (4.0f + index * 0.26f) + index * 1.27f;
                var offset = coreOffsets[index % coreOffsets.Length];
                var scale = coreScales[index % coreScales.Length];
                var pulse = 0.95f + Mathf.Sin(phase * 1.8f) * 0.05f;
                var alpha = fade * reveal * (0.45f + (index % 3) * 0.060f) * pulse;
                renderer.enabled = alpha > 0.004f;
                if (!renderer.enabled)
                    continue;

                renderer.transform.position = center
                    + cameraRight * (offset.x * Mathf.Lerp(0.24f, 0.76f, reveal))
                    + cameraUp * (offset.y * Mathf.Lerp(0.24f, 0.76f, reveal))
                    + cameraForward * (-1.48f - index * 0.014f);
                renderer.transform.rotation = FrontBillboardRotation(
                    cameraForward,
                    cameraUp,
                    18f + index * 49f + Mathf.Sin(phase) * 16f);
                renderer.transform.localScale = new Vector3(
                    scale.x * Mathf.Lerp(0.20f, 1f, reveal) * pulse,
                    scale.y * Mathf.Lerp(0.20f, 1f, reveal) * pulse,
                    1f);
                var material = renderer.material;
                if (material != null && material.HasProperty("_Color"))
                {
                    var color = corePalette[index % corePalette.Length];
                    material.SetColor("_Color", new Color(color.r, color.g, color.b, alpha));
                }
            }
        }

        if (solarBody != null)
        {
            var alpha = fade * reveal * 0.14f;
            solarBody.enabled = alpha > 0.004f;
            if (solarBody.enabled)
            {
                solarBody.transform.position = center
                    + cameraRight * -0.06f
                    + cameraUp * 0.06f
                    + cameraForward * -1.66f;
                solarBody.transform.rotation = FrontBillboardRotation(
                    cameraForward,
                    cameraUp,
                    -elapsed * 12f);
                solarBody.transform.localScale = new Vector3(
                    Mathf.Lerp(0.18f, 0.82f, reveal),
                    Mathf.Lerp(0.14f, 0.56f, reveal),
                    1f);
                var material = solarBody.material;
                if (material != null && material.HasProperty("_Color"))
                    material.SetColor("_Color", new Color(1f, 0.42f, 0.025f, alpha));
            }
        }
    }

    static void UpdateColoredBurstCards(
        List<MeshRenderer> flames,
        List<MeshRenderer> smoke,
        Vector3 center,
        Vector3 cameraRight,
        Vector3 cameraUp,
        Vector3 cameraForward,
        float elapsed,
        float reveal,
        float fade,
        Color[] palette,
        Color smokeColor,
        float sizeScale,
        int coreCount)
    {
        if (palette == null || palette.Length == 0)
            return;

        reveal = Mathf.Clamp01(reveal);
        fade = Mathf.Clamp01(fade);
        sizeScale = Mathf.Max(0.01f, sizeScale);
        coreCount = Mathf.Max(1, coreCount);

        if (flames != null)
        {
            for (var index = 0; index < flames.Count; index++)
            {
                var renderer = flames[index];
                if (renderer == null)
                    continue;

                var angle = index * Mathf.PI * 2f / Mathf.Max(1, flames.Count)
                    + elapsed * (0.82f + (index % 3) * 0.14f);
                var inner = index < coreCount;
                var radius = inner
                    ? 0.045f + index * 0.052f
                    : 0.24f + (index % 4) * 0.12f;
                radius *= Mathf.Lerp(0.10f, 1f, reveal);
                var position = center
                    + cameraRight * Mathf.Cos(angle) * radius * 1.06f
                    + cameraUp * Mathf.Sin(angle) * radius * 0.84f
                    + cameraForward * (-1.42f - index * 0.018f);
                var width = inner
                    ? 0.90f
                    : Mathf.Lerp(0.48f, 0.78f, (index % 5) / 4f);
                var height = inner
                    ? 1.02f
                    : Mathf.Lerp(0.64f, 1.12f, (index % 4) / 3f);
                var alpha = fade * reveal * (inner ? 0.98f : 0.76f)
                    * (0.94f + Mathf.Sin(elapsed * 9f + index) * 0.06f);
                renderer.enabled = alpha > 0.004f;
                if (!renderer.enabled)
                    continue;

                renderer.transform.position = position;
                renderer.transform.rotation = FrontBillboardRotation(
                    cameraForward,
                    cameraUp,
                    angle * Mathf.Rad2Deg - 90f + Mathf.Sin(elapsed * 8f + index) * 9f);
                renderer.transform.localScale = new Vector3(width, height, 1f)
                    * sizeScale
                    * Mathf.Lerp(0.10f, 1f, reveal);
                var material = renderer.material;
                if (material != null && material.HasProperty("_Color"))
                {
                    var color = palette[index % palette.Length];
                    material.SetColor("_Color", new Color(color.r, color.g, color.b, alpha));
                }
            }
        }

        if (smoke == null)
            return;
        for (var index = 0; index < smoke.Count; index++)
        {
            var renderer = smoke[index];
            if (renderer == null)
                continue;

            var angle = index * Mathf.PI * 0.5f
                + elapsed * (0.52f + index * 0.11f)
                + 0.35f;
            var radius = (0.42f + index * 0.08f)
                * Mathf.Lerp(0.10f, 1f, reveal);
            var alpha = fade * reveal * (0.28f + index * 0.022f);
            renderer.enabled = alpha > 0.004f;
            if (!renderer.enabled)
                continue;

            renderer.transform.position = center
                + cameraRight * Mathf.Cos(angle) * radius
                + cameraUp * (Mathf.Sin(angle) * radius * 0.74f + 0.06f)
                + cameraForward * (-1.46f - index * 0.024f);
            renderer.transform.rotation = FrontBillboardRotation(
                cameraForward,
                cameraUp,
                angle * Mathf.Rad2Deg + 22f);
            renderer.transform.localScale = new Vector3(0.74f, 0.62f, 1f)
                * sizeScale
                * Mathf.Lerp(0.10f, 1f, reveal);
            var material = renderer.material;
            if (material != null && material.HasProperty("_Color"))
                material.SetColor("_Color", new Color(
                    smokeColor.r,
                    smokeColor.g,
                    smokeColor.b,
                    alpha));
        }
    }

    static void UpdateTornadoFrontBands(
        List<LineRenderer> glows,
        List<LineRenderer> cores,
        Vector3 center,
        Vector3 cameraRight,
        Vector3 cameraUp,
        Vector3 cameraForward,
        float elapsed,
        float reveal,
        float fade,
        Color[] palette)
    {
        if (glows == null || cores == null || palette == null || palette.Length == 0)
            return;

        reveal = Mathf.Clamp01(reveal);
        fade = Mathf.Clamp01(fade);
        for (var index = 0; index < glows.Count && index < cores.Count; index++)
        {
            var glow = glows[index];
            var core = cores[index];
            if (glow == null || core == null)
                continue;

            var points = new Vector3[glow.positionCount];
            for (var point = 0; point < points.Length; point++)
            {
                var rawT = point / (float)(points.Length - 1);
                var heightT = Mathf.Clamp01(rawT * Mathf.Lerp(0.25f, 1.10f, reveal));
                var height = Mathf.Lerp(-0.92f, 1.14f, heightT);
                var upperSpread = Mathf.SmoothStep(0f, 1f, Mathf.Clamp01(heightT / 0.48f));
                var radius = Mathf.Lerp(0.14f, 0.62f, upperSpread)
                    * Mathf.Lerp(1f, 0.68f, heightT);
                var angle = elapsed * (4.6f + index * 0.28f)
                    + heightT * 4.9f
                    + index * 1.03f;
                var depth = -1.24f - index * 0.025f + Mathf.Sin(angle) * 0.09f;
                points[point] = center
                    + cameraRight * Mathf.Cos(angle) * radius
                    + cameraUp * height
                    + cameraForward * depth;
            }

            var shimmer = 0.90f + Mathf.Sin(elapsed * 18f + index * 1.3f) * 0.10f;
            var color = palette[index % palette.Length];
            UpdateFrontRibbon(
                glow,
                points,
                (0.118f - index * 0.009f) * (0.94f + shimmer * 0.06f),
                color,
                fade * reveal * 0.92f * shimmer);

            var corePoints = new Vector3[points.Length];
            for (var point = 0; point < points.Length; point++)
                corePoints[point] = points[point] + cameraForward * -0.018f;
            UpdateFrontRibbon(
                core,
                corePoints,
                0.034f - index * 0.0022f,
                Color.Lerp(Color.white, color, 0.22f),
                fade * reveal * 0.90f * shimmer);
        }
    }

    static void UpdateTornadoFrontMist(
        List<MeshRenderer> cards,
        Vector3 center,
        Vector3 cameraRight,
        Vector3 cameraUp,
        Vector3 cameraForward,
        float elapsed,
        float reveal,
        float fade)
    {
        if (cards == null)
            return;

        var heights = new[] { -0.62f, -0.20f, 0.22f, 0.62f, 0.94f };
        var widths = new[] { 0.46f, 0.58f, 0.64f, 0.54f, 0.40f };
        var colors = new[]
        {
            new Color(0.12f, 0.70f, 1f),
            new Color(0.30f, 0.38f, 1f),
            new Color(0.16f, 0.90f, 0.78f),
            new Color(0.64f, 0.24f, 1f),
            new Color(0.52f, 0.92f, 1f)
        };
        reveal = Mathf.Clamp01(reveal);
        fade = Mathf.Clamp01(fade);
        for (var index = 0; index < cards.Count; index++)
        {
            var renderer = cards[index];
            if (renderer == null)
                continue;
            var phase = elapsed * (3.2f + index * 0.36f) + index * 1.8f;
            var y = heights[index % heights.Length] * reveal;
            var radius = Mathf.Lerp(0.16f, 0.42f, Mathf.Clamp01((y + 0.70f) / 1.7f));
            var x = Mathf.Sin(phase) * radius;
            var alpha = fade * reveal * (0.38f + (index % 2) * 0.10f);
            renderer.enabled = alpha > 0.004f;
            if (!renderer.enabled)
                continue;

            renderer.transform.position = center
                + cameraRight * x
                + cameraUp * y
                + cameraForward * (-1.40f - index * 0.018f);
            renderer.transform.rotation = FrontBillboardRotation(
                cameraForward,
                cameraUp,
                Mathf.Sin(phase) * 22f + index * 27f);
            renderer.transform.localScale = new Vector3(
                widths[index % widths.Length] * 1.08f,
                0.38f + (index % 3) * 0.09f,
                1f) * Mathf.Lerp(0.10f, 1f, reveal);
            var material = renderer.material;
            if (material != null && material.HasProperty("_Color"))
            {
                var color = colors[index % colors.Length];
                material.SetColor("_Color", new Color(color.r, color.g, color.b, alpha));
            }
        }
    }

    static void UpdateTornadoAuroraCards(
        List<MeshRenderer> cards,
        Vector3 center,
        Vector3 cameraRight,
        Vector3 cameraUp,
        Vector3 cameraForward,
        float elapsed,
        float reveal,
        float fade)
    {
        if (cards == null)
            return;

        var offsets = new[]
        {
            new Vector2(-0.12f, -0.10f),
            new Vector2(0.12f, 0.08f),
            new Vector2(0.00f, 0.34f)
        };
        var scales = new[]
        {
            new Vector2(0.78f, 1.12f),
            new Vector2(0.68f, 1.04f),
            new Vector2(0.54f, 0.82f)
        };
        var colors = new[]
        {
            new Color(0.08f, 0.62f, 1f),
            new Color(0.36f, 0.22f, 0.96f),
            new Color(0.22f, 0.90f, 0.82f)
        };
        reveal = Mathf.Clamp01(reveal);
        fade = Mathf.Clamp01(fade);
        for (var index = 0; index < cards.Count; index++)
        {
            var renderer = cards[index];
            if (renderer == null)
                continue;
            var phase = elapsed * (2.8f + index * 0.42f) + index * 2.1f;
            var offset = offsets[index % offsets.Length];
            var scale = scales[index % scales.Length];
            var alpha = fade * reveal * (0.18f + index * 0.022f)
                * (0.92f + Mathf.Sin(phase * 1.7f) * 0.08f);
            renderer.enabled = alpha > 0.004f;
            if (!renderer.enabled)
                continue;

            renderer.transform.position = center
                + cameraRight * (offset.x + Mathf.Sin(phase) * 0.07f)
                + cameraUp * (offset.y + Mathf.Cos(phase * 1.13f) * 0.08f)
                + cameraForward * (-1.48f - index * 0.026f);
            renderer.transform.rotation = FrontBillboardRotation(
                cameraForward,
                cameraUp,
                Mathf.Sin(phase * 0.82f) * 28f + index * 58f);
            renderer.transform.localScale = new Vector3(scale.x, scale.y, 1f)
                * Mathf.Lerp(0.08f, 1f, reveal);
            var material = renderer.material;
            if (material != null && material.HasProperty("_Color"))
            {
                var color = colors[index % colors.Length];
                material.SetColor("_Color", new Color(color.r, color.g, color.b, alpha));
            }
        }
    }

    static void UpdateTornadoSplashCards(
        List<MeshRenderer> cards,
        Vector3 center,
        Vector3 cameraRight,
        Vector3 cameraUp,
        Vector3 cameraForward,
        float elapsed,
        float reveal,
        float fade)
    {
        if (cards == null)
            return;

        var heights = new[] { -0.84f, -0.50f, -0.14f, 0.24f, 0.66f, 1.04f };
        var widths = new[] { 0.72f, 0.62f, 0.84f, 0.68f, 0.58f, 0.46f };
        var colors = new[]
        {
            new Color(0.08f, 0.56f, 1f),
            new Color(0.20f, 0.84f, 0.92f),
            new Color(0.36f, 0.20f, 0.96f),
            new Color(0.16f, 0.70f, 1f),
            new Color(0.58f, 0.28f, 1f),
            new Color(0.42f, 0.92f, 0.86f)
        };
        reveal = Mathf.Clamp01(reveal);
        fade = Mathf.Clamp01(fade);
        for (var index = 0; index < cards.Count; index++)
        {
            var renderer = cards[index];
            if (renderer == null)
                continue;

            var phase = elapsed * (1.55f + index * 0.13f) + index * 1.08f;
            var height = heights[index % heights.Length]
                + Mathf.Sin(phase * 1.17f) * 0.08f;
            var heightT = Mathf.InverseLerp(-0.78f, 0.94f, height);
            var radius = Mathf.Lerp(0.20f, 0.58f, heightT)
                * (0.92f + Mathf.Sin(phase * 0.83f) * 0.08f);
            var position = center
                + cameraRight * Mathf.Cos(phase) * radius
                + cameraUp * height
                + cameraForward * (-1.62f - index * 0.018f);
            var roll = phase * Mathf.Rad2Deg + 74f + index * 19f;
            var width = widths[index % widths.Length]
                * (0.92f + Mathf.Sin(phase * 1.4f) * 0.08f);
            var heightScale = Mathf.Lerp(0.62f, 1.02f, 1f - heightT * 0.24f);
            var alpha = fade * reveal * (0.40f + (index % 3) * 0.055f)
                * (0.94f + Mathf.Sin(phase * 2.1f) * 0.06f);
            renderer.enabled = alpha > 0.004f;
            if (!renderer.enabled)
                continue;

            renderer.transform.position = position;
            renderer.transform.rotation = FrontBillboardRotation(cameraForward, cameraUp, roll);
            renderer.transform.localScale = new Vector3(width, heightScale, 1f)
                * Mathf.Lerp(0.10f, 1f, reveal);
            var material = renderer.material;
            if (material != null && material.HasProperty("_Color"))
            {
                var color = colors[index % colors.Length];
                material.SetColor("_Color", new Color(color.r, color.g, color.b, alpha));
            }
        }
    }

    LineRenderer CreateSlashArc(Transform parent, float width, Color color, int renderQueue)
    {
        var objectRoot = new GameObject("VFX sword impact arc");
        objectRoot.transform.SetParent(parent, false);
        var line = objectRoot.AddComponent<LineRenderer>();
        line.useWorldSpace = true;
        line.loop = false;
        line.positionCount = 32;
        line.alignment = LineAlignment.View;
        line.textureMode = LineTextureMode.Stretch;
        line.numCornerVertices = 8;
        line.numCapVertices = 8;
        line.widthMultiplier = width;
        line.widthCurve = new AnimationCurve(
            new Keyframe(0f, 0.04f),
            new Keyframe(0.18f, 0.72f),
            new Keyframe(0.52f, 1f),
            new Keyframe(0.86f, 0.52f),
            new Keyframe(1f, 0.04f));
        line.material = CreateVFXMaterial(color, renderQueue, slashTexture);
        line.startColor = Color.clear;
        line.endColor = Color.clear;
        return line;
    }

    static void UpdateRibbonPair(
        LineRenderer glow,
        LineRenderer core,
        Vector3 start,
        Vector3 end,
        float tail,
        float head,
        Vector3 cameraRight,
        Vector3 cameraUp,
        Vector3 cameraForward,
        float elapsed,
        int layer,
        Color color,
        float fade)
    {
        var visible = head > tail + 0.012f && fade > 0.006f;
        glow.enabled = visible;
        core.enabled = visible;
        if (!visible)
            return;

        for (var point = 0; point < glow.positionCount; point++)
        {
            var localT = point / (float)(glow.positionCount - 1);
            var pathT = Mathf.Lerp(tail, head, localT);
            var basePoint = Vector3.Lerp(start, end, pathT);
            var arc = Mathf.Sin(pathT * Mathf.PI) * (0.20f + layer * 0.065f);
            var jitter = Mathf.Sin(pathT * 9.5f + elapsed * (10f + layer * 1.8f) + layer * 1.7f) * 0.035f;
            var position = basePoint
                + cameraUp * (arc + jitter)
                + cameraRight * Mathf.Sin(pathT * 5.3f + elapsed * 6f + layer) * 0.025f
                - cameraForward * (0.025f + layer * 0.012f);
            glow.SetPosition(point, position);
            core.SetPosition(point, position + cameraForward * -0.008f);
        }

        var shimmer = 0.90f + Mathf.Sin(elapsed * 24f + layer * 2.1f) * 0.10f;
        var glowAlpha = fade * shimmer * (0.24f + (1f - tail) * 0.24f);
        var coreAlpha = fade * shimmer * 0.90f;
        glow.startColor = new Color(color.r, color.g, color.b, glowAlpha * 0.26f);
        glow.endColor = new Color(color.r, color.g, color.b, glowAlpha);
        core.startColor = new Color(0.82f, 0.94f, 1f, coreAlpha * 0.64f);
        core.endColor = new Color(1f, 1f, 0.96f, coreAlpha);
    }

    static void UpdateWarmRibbonPair(
        LineRenderer glow,
        LineRenderer core,
        Vector3 start,
        Vector3 end,
        float tail,
        float head,
        Vector3 cameraRight,
        Vector3 cameraUp,
        Vector3 cameraForward,
        float elapsed,
        int layer,
        Color color,
        float fade)
    {
        var visible = head > tail + 0.012f && fade > 0.006f;
        if (glow != null) glow.enabled = visible;
        if (core != null) core.enabled = visible;
        if (!visible || glow == null || core == null)
            return;

        for (var point = 0; point < glow.positionCount; point++)
        {
            var localT = point / (float)(glow.positionCount - 1);
            var pathT = Mathf.Lerp(tail, head, localT);
            var basePoint = Vector3.Lerp(start, end, pathT);
            var arc = Mathf.Sin(pathT * Mathf.PI) * (0.16f + layer * 0.055f);
            var jitter = Mathf.Sin(
                pathT * 10.0f + elapsed * (11f + layer * 1.8f) + layer * 1.6f) * 0.032f;
            var position = basePoint
                + cameraUp * (arc + jitter)
                + cameraRight * Mathf.Sin(pathT * 5.6f + elapsed * 7f + layer) * 0.024f
                - cameraForward * (0.045f + layer * 0.014f);
            glow.SetPosition(point, position);
            core.SetPosition(point, position + cameraForward * -0.012f);
        }

        var shimmer = 0.90f + Mathf.Sin(elapsed * 25f + layer * 2.2f) * 0.10f;
        var glowAlpha = fade * shimmer * (0.26f + (1f - tail) * 0.28f);
        var coreAlpha = fade * shimmer * 0.92f;
        glow.startColor = new Color(color.r, color.g, color.b, glowAlpha * 0.28f);
        glow.endColor = new Color(color.r, color.g, color.b, glowAlpha);
        core.startColor = new Color(1f, 0.54f, 0.12f, coreAlpha * 0.62f);
        core.endColor = new Color(1f, 0.96f, 0.68f, coreAlpha);
    }

    static void UpdateSlashArc(
        LineRenderer line,
        Vector3 center,
        Vector3 cameraRight,
        Vector3 cameraUp,
        Vector3 cameraForward,
        float startAngle,
        float endAngle,
        float radius,
        float reveal,
        float fade,
        float elapsed,
        int layer)
    {
        if (line == null)
            return;

        var visible = reveal > 0.004f && fade > 0.004f;
        line.enabled = visible;
        if (!visible)
            return;

        for (var index = 0; index < line.positionCount; index++)
        {
            var t = index / (float)(line.positionCount - 1);
            var arcT = Mathf.Clamp01(t * reveal);
            var angle = Mathf.Lerp(startAngle, endAngle, arcT) * Mathf.Deg2Rad;
            var wobble = Mathf.Sin(t * 11f + elapsed * (7f + layer * 1.2f)) * 0.035f;
            var position = center
                + cameraRight * Mathf.Cos(angle) * radius
                + cameraUp * (Mathf.Sin(angle) * radius * 0.78f + wobble)
                + cameraForward * (-0.68f - layer * 0.025f);
            line.SetPosition(index, position);
        }

        line.startColor = new Color(0.90f, 0.96f, 1f, fade * 0.16f);
        line.endColor = new Color(1f, 1f, 1f, fade * 0.92f);
    }

    static void UpdateWindRibbon(
        LineRenderer line,
        Vector3 center,
        Vector3 groundRight,
        Vector3 groundForward,
        float elapsed,
        float progress,
        float reveal,
        float fade,
        int layer,
        Color color)
    {
        var spin = elapsed * (2.8f + layer * 0.36f) + layer * Mathf.PI * 0.5f;
        for (var point = 0; point < line.positionCount; point++)
        {
            var heightT = point / (float)(line.positionCount - 1);
            var visibleHeight = Mathf.Lerp(0.18f, 1.72f, heightT) * reveal;
            var funnel = Mathf.Lerp(0.76f - layer * 0.035f, 0.12f + layer * 0.018f, heightT);
            var angle = spin + heightT * 7.2f + layer * 0.52f;
            var wobble = 1f + Mathf.Sin(heightT * 11f + elapsed * 7f + layer) * 0.08f;
            var position = center
                + Vector3.up * visibleHeight
                + groundRight * Mathf.Cos(angle) * funnel * wobble
                + groundForward * Mathf.Sin(angle) * funnel * 0.42f * wobble;
            line.SetPosition(point, position);
        }

        var alpha = fade * (0.34f + reveal * 0.76f);
        line.startColor = new Color(color.r, color.g, color.b, alpha * 0.32f);
        line.endColor = new Color(color.r, color.g, color.b, alpha);
        line.widthMultiplier = (0.145f - layer * 0.010f) * (0.88f + Mathf.Sin(elapsed * 9f + layer) * 0.12f);
    }

    void CreateImpactRays(
        Transform parent,
        Vector3 center,
        Vector3 cameraRight,
        Vector3 cameraUp,
        Vector3 cameraForward,
        List<LineRenderer> rays,
        List<Vector3> directions)
    {
        CreateImpactRays(
            parent,
            center,
            cameraRight,
            cameraUp,
            cameraForward,
            rays,
            directions,
            new Color(1f, 0.30f, 0.04f),
            new Color(1f, 0.78f, 0.20f),
            4250,
            "fireburst");
    }

    void CreateImpactRays(
        Transform parent,
        Vector3 center,
        Vector3 cameraRight,
        Vector3 cameraUp,
        Vector3 cameraForward,
        List<LineRenderer> rays,
        List<Vector3> directions,
        Color glowColor,
        Color coreColor,
        int renderQueue,
        string label)
    {
        const int rayCount = 22;
        for (var index = 0; index < rayCount; index++)
        {
            var angle = index * Mathf.PI * 2f / rayCount + (index % 2 == 0 ? 0.08f : -0.05f);
            var depth = ((index % 3) - 1) * 0.14f;
            var direction = (
                cameraRight * Mathf.Cos(angle)
                + cameraUp * Mathf.Sin(angle) * 0.72f
                + cameraForward * depth
            ).normalized;
            var rayObject = new GameObject($"VFX {label} ray");
            rayObject.transform.SetParent(parent, true);
            var ray = rayObject.AddComponent<LineRenderer>();
            ray.useWorldSpace = true;
            ray.loop = false;
            ray.positionCount = 4;
            ray.alignment = LineAlignment.View;
            ray.numCornerVertices = 6;
            ray.numCapVertices = 6;
            ray.widthMultiplier = 0.125f - (index % 3) * 0.016f;
            ray.widthCurve = new AnimationCurve(
                new Keyframe(0f, 0.02f),
                new Keyframe(0.24f, 0.76f),
                new Keyframe(0.72f, 1f),
                new Keyframe(1f, 0.01f));
            ray.material = CreateVFXMaterial(
                index % 3 == 0 ? glowColor : coreColor,
                renderQueue + index);
            ray.startColor = Color.clear;
            ray.endColor = Color.clear;
            rays.Add(ray);
            directions.Add(direction);
            ray.SetPosition(0, center);
            ray.SetPosition(1, center);
            ray.SetPosition(2, center);
            ray.SetPosition(3, center);
        }
    }

    static void UpdateImpactRays(
        List<LineRenderer> rays,
        List<Vector3> directions,
        Vector3 center,
        float age)
    {
        UpdateImpactRays(
            rays,
            directions,
            center,
            age,
            new Color(1f, 0.28f, 0.04f),
            new Color(1f, 0.82f, 0.24f));
    }

    static void UpdateImpactRays(
        List<LineRenderer> rays,
        List<Vector3> directions,
        Vector3 center,
        float age,
        Color glowColor,
        Color coreColor)
    {
        var reveal = EaseOutCubic(age);
        var fade = 1f - Mathf.SmoothStep(0f, 1f, Mathf.Clamp01((age - 0.64f) / 0.36f));
        for (var index = 0; index < rays.Count; index++)
        {
            var ray = rays[index];
            var direction = directions[index];
            var length = Mathf.Lerp(0.08f, 1.22f + (index % 4) * 0.14f, reveal);
            var bend = Vector3.Cross(direction, Vector3.up);
            if (bend.sqrMagnitude < 0.001f)
                bend = Vector3.right;
            bend.Normalize();
            bend *= Mathf.Sin(age * Mathf.PI) * 0.10f * (index % 2 == 0 ? 1f : -1f);
            ray.SetPosition(0, center + direction * 0.04f);
            ray.SetPosition(1, center + direction * length * 0.28f + bend * 0.45f);
            ray.SetPosition(2, center + direction * length * 0.72f + bend);
            ray.SetPosition(3, center + direction * length);
            ray.startColor = new Color(glowColor.r, glowColor.g, glowColor.b, fade * 0.18f);
            ray.endColor = new Color(coreColor.r, coreColor.g, coreColor.b, fade * 0.96f);
            ray.enabled = fade > 0.004f;
        }
    }

    void CreateSparkBurst(
        Transform parent,
        Vector3 position,
        Color color,
        int count,
        float speedMin,
        float speedMax,
        float size)
    {
        var objectRoot = new GameObject("VFX spark burst");
        objectRoot.transform.SetParent(parent, true);
        objectRoot.transform.position = position;
        var particles = objectRoot.AddComponent<ParticleSystem>();
        var main = particles.main;
        main.duration = 0.70f;
        main.loop = false;
        main.playOnAwake = false;
        main.startLifetime = new ParticleSystem.MinMaxCurve(0.24f, 0.62f);
        main.startSpeed = new ParticleSystem.MinMaxCurve(speedMin, speedMax);
        main.startSize = new ParticleSystem.MinMaxCurve(size * 0.55f, size);
        main.startRotation = new ParticleSystem.MinMaxCurve(0f, Mathf.PI * 2f);
        main.startColor = color;
        main.simulationSpace = ParticleSystemSimulationSpace.World;
        main.maxParticles = count;

        var emission = particles.emission;
        emission.enabled = true;
        emission.SetBursts(new[] { new ParticleSystem.Burst(0f, (short)count) });
        var shape = particles.shape;
        shape.enabled = true;
        shape.shapeType = ParticleSystemShapeType.Sphere;
        shape.radius = 0.045f;

        var renderer = particles.GetComponent<ParticleSystemRenderer>();
        renderer.renderMode = ParticleSystemRenderMode.Billboard;
        renderer.material = CreateParticleMaterial(color, 3250);
        particles.Play();
    }

    void CreateWindParticles(Transform parent, Vector3 position, Color color, int maxParticles)
    {
        var objectRoot = new GameObject("VFX floating wind motes");
        objectRoot.transform.SetParent(parent, true);
        objectRoot.transform.position = position + Vector3.up * 0.72f;
        var particles = objectRoot.AddComponent<ParticleSystem>();
        var main = particles.main;
        main.duration = 1.08f;
        main.loop = true;
        main.playOnAwake = false;
        main.startLifetime = new ParticleSystem.MinMaxCurve(0.34f, 0.82f);
        main.startSpeed = new ParticleSystem.MinMaxCurve(0.05f, 0.22f);
        main.startSize = new ParticleSystem.MinMaxCurve(0.018f, 0.065f);
        main.startColor = new Color(color.r, color.g, color.b, 0.72f);
        main.simulationSpace = ParticleSystemSimulationSpace.World;
        main.maxParticles = maxParticles;

        var emission = particles.emission;
        emission.enabled = true;
        emission.rateOverTime = new ParticleSystem.MinMaxCurve(28f);
        var shape = particles.shape;
        shape.enabled = true;
        shape.shapeType = ParticleSystemShapeType.Sphere;
        shape.radius = 0.58f;

        var renderer = particles.GetComponent<ParticleSystemRenderer>();
        renderer.renderMode = ParticleSystemRenderMode.Billboard;
        renderer.material = CreateParticleMaterial(color, 3240);
        particles.Play();
    }

    SpriteRenderer CreateBillboardSprite(
        Transform parent,
        string name,
        Texture2D texture,
        Vector3 position,
        Color color,
        int renderQueue,
        float pixelsPerUnit)
    {
        if (texture == null)
            return null;

        var objectRoot = new GameObject(name);
        objectRoot.transform.SetParent(parent, true);
        objectRoot.transform.position = position;
        objectRoot.transform.rotation = BillboardRotation(Camera.main, 0f);
        var renderer = objectRoot.AddComponent<SpriteRenderer>();
        renderer.sprite = Sprite.Create(
            texture,
            new Rect(0f, 0f, texture.width, texture.height),
            new Vector2(0.5f, 0.5f),
            pixelsPerUnit);
        activeSprites.Add(renderer.sprite);
        renderer.material = CreateVFXMaterial(Color.white, renderQueue, texture);
        renderer.color = color;
        renderer.sortingOrder = renderQueue;
        renderer.enabled = color.a > 0.003f;
        return renderer;
    }

    Texture2D CreateSolarFireballTexture()
    {
        if (solarFireballTexture != null)
            return solarFireballTexture;

        const int size = 192;
        var texture = new Texture2D(size, size, TextureFormat.RGBA32, false)
        {
            name = "Runtime cohesive solar fireball",
            filterMode = FilterMode.Bilinear,
            wrapMode = TextureWrapMode.Clamp
        };
        var pixels = new Color[size * size];
        var center = (size - 1) * 0.5f;
        for (var y = 0; y < size; y++)
        for (var x = 0; x < size; x++)
        {
            var dx = (x - center) / center;
            var dy = (y - center) / center;
            var radius = Mathf.Sqrt(dx * dx + dy * dy);
            var angle = Mathf.Atan2(dy, dx);
            var coarse = Mathf.PerlinNoise((dx + 1.7f) * 2.8f, (dy + 2.3f) * 2.8f);
            var fine = Mathf.PerlinNoise((dx + 4.1f) * 8.0f, (dy + 3.6f) * 8.0f);
            var lobe = Mathf.Sin(angle * 5.0f + coarse * 2.6f) * 0.055f
                + Mathf.Sin(angle * 9.0f - fine * 3.8f) * 0.032f
                + Mathf.Sin(angle * 13.0f + 1.4f) * 0.018f;
            var edge = 0.80f + (coarse - 0.5f) * 0.19f + (fine - 0.5f) * 0.075f + lobe;
            var mask = 1f - Mathf.SmoothStep(edge - 0.12f, edge + 0.025f, radius);
            var surface = Mathf.Clamp01(coarse * 0.58f + fine * 0.42f);
            var core = Mathf.Clamp01(1f - radius / Mathf.Max(0.20f, edge));
            var hot = Mathf.Clamp01(core * 0.86f + surface * 0.36f);
            var turbulent = Mathf.Clamp01(surface * 1.30f + core * 0.24f);
            var darkPocket = Mathf.SmoothStep(0.68f, 0.92f, fine)
                * Mathf.SmoothStep(0.24f, 0.86f, radius)
                * 0.16f;
            var red = Mathf.Lerp(0.38f, 1f, Mathf.Clamp01(0.42f + hot * 0.72f));
            var green = Mathf.Lerp(0.008f, 0.92f, Mathf.Clamp01(hot * 1.12f));
            var blue = Mathf.Lerp(0.002f, 0.075f, hot);
            red *= 1f - darkPocket * 0.36f;
            green *= 1f - darkPocket;
            blue *= 1f - darkPocket;
            var intensity = mask * Mathf.Lerp(0.74f, 1.12f, turbulent);
            pixels[y * size + x] = new Color(
                red * intensity,
                green * intensity,
                blue * intensity,
                mask);
        }
        texture.SetPixels(pixels);
        texture.Apply(false, true);
        solarFireballTexture = texture;
        activeTextures.Add(texture);
        return texture;
    }

    Texture2D CreateWildWardenBodyTexture()
    {
        if (wildWardenBodyTexture != null)
            return wildWardenBodyTexture;

        const int width = 128;
        const int height = 256;
        var texture = new Texture2D(width, height, TextureFormat.RGBA32, false)
        {
            name = "Runtime Wild Warden continuous wind column",
            filterMode = FilterMode.Bilinear,
            wrapMode = TextureWrapMode.Clamp
        };
        var pixels = new Color[width * height];
        for (var y = 0; y < height; y++)
        for (var x = 0; x < width; x++)
        {
            var u = x / (float)(width - 1);
            var v = y / (float)(height - 1);
            var centeredX = u * 2f - 1f;
            var centerOffset = Mathf.Sin(v * 7.2f + 0.45f) * 0.075f
                + Mathf.Sin(v * 17f - 0.80f) * 0.030f;
            var widthProfile = 0.27f
                + Mathf.Sin(v * Mathf.PI) * 0.28f
                + v * 0.10f;
            var edgeNoise = 1f
                + Mathf.Sin(v * 21f + 0.40f) * 0.055f
                + Mathf.Sin(v * 37f - 1.20f) * 0.025f;
            var distance = Mathf.Abs(centeredX - centerOffset)
                / Mathf.Max(0.08f, widthProfile * edgeNoise);
            var edge = 1f - Mathf.SmoothStep(0.72f, 1.04f, distance);
            var vertical = 0.68f + 0.32f * Mathf.Sin(v * Mathf.PI);
            var internalFlow = 0.82f
                + Mathf.Sin(centeredX * 8f + v * 15f) * 0.10f
                + Mathf.Sin(centeredX * 17f - v * 24f) * 0.05f;
            var alpha = Mathf.Clamp01(edge * vertical * internalFlow * 0.90f);
            pixels[y * width + x] = new Color(1f, 1f, 1f, alpha);
        }
        texture.SetPixels(pixels);
        texture.Apply(false, true);
        wildWardenBodyTexture = texture;
        activeTextures.Add(texture);
        return texture;
    }

    Texture2D CreateImpactCoverTexture()
    {
        if (impactCoverTexture != null)
            return impactCoverTexture;

        const int size = 128;
        var texture = new Texture2D(size, size, TextureFormat.RGBA32, false)
        {
            name = "Runtime impact occlusion burst",
            filterMode = FilterMode.Bilinear,
            wrapMode = TextureWrapMode.Clamp
        };
        var pixels = new Color[size * size];
        var center = (size - 1) * 0.5f;
        for (var y = 0; y < size; y++)
        for (var x = 0; x < size; x++)
        {
            var dx = (x - center) / center;
            var dy = (y - center) / center;
            var radius = Mathf.Sqrt(dx * dx + dy * dy);
            var angle = Mathf.Atan2(dy, dx);
            // Break the cover into uneven smoke/flame lobes. The layers also
            // rotate independently, so the contact never reads as a closed
            // UI-like circle.
            var lobe = 1f
                + Mathf.Sin(angle * 5f + 0.65f) * 0.15f
                + Mathf.Sin(angle * 9f - 1.30f) * 0.075f
                + Mathf.Sin(angle * 13f + 2.10f) * 0.04f;
            var distortedRadius = radius * (1f + Mathf.Sin(angle * 3f - 0.4f) * 0.045f);
            var edge = 0.84f * lobe;
            var edgeFade = Mathf.SmoothStep(0.68f, 1f,
                Mathf.Clamp01(distortedRadius / Mathf.Max(0.30f, edge)));
            var alpha = 1.00f * (1f - edgeFade);
            alpha *= 0.92f + Mathf.Sin(angle * 4f + 0.2f) * 0.08f;
            pixels[y * size + x] = new Color(1f, 1f, 1f, alpha);
        }
        texture.SetPixels(pixels);
        texture.Apply(false, true);
        impactCoverTexture = texture;
        activeTextures.Add(texture);
        return texture;
    }

    MeshRenderer CreateCoverSprite(
        Transform parent,
        string name,
        Texture2D texture,
        Vector3 position,
        Color color,
        int renderQueue,
        float pixelsPerUnit)
    {
        if (texture == null)
            return null;

        var objectRoot = GameObject.CreatePrimitive(PrimitiveType.Quad);
        objectRoot.name = name;
        objectRoot.transform.SetParent(parent, true);
        objectRoot.transform.position = position;
        objectRoot.transform.rotation = BillboardRotation(Camera.main, 0f);
        var collider = objectRoot.GetComponent<Collider>();
        if (collider != null)
            Destroy(collider);
        var renderer = objectRoot.GetComponent<MeshRenderer>();
        renderer.material = CreateCoverMaterial(renderQueue, texture);
        renderer.sortingOrder = renderQueue;
        renderer.enabled = color.a > 0.003f;
        return renderer;
    }

    Material CreateCoverMaterial(int renderQueue, Texture2D texture)
    {
        var shader = Shader.Find("Mindstone/Mistport Front Occlusion Sprite")
            ?? Shader.Find("Sprites/Default")
            ?? Shader.Find("Particles/Standard Unlit")
            ?? Shader.Find("Unlit/Transparent");
        var material = new Material(shader)
        {
            // Keep the cover in the final transparent pass. Sprite sorting
            // alone cannot beat a 3D actor's depth buffer; the dedicated
            // shader also uses ZTest Always so this is real visual occlusion,
            // not a renderer toggle or a fake alpha wash behind the actor.
            renderQueue = Mathf.Max(renderQueue, 4000),
            mainTexture = texture
        };
        if (material.HasProperty("_Color"))
            material.SetColor("_Color", Color.white);
        activeMaterials.Add(material);
        return material;
    }

    Material CreateFrontRibbonMaterial(int renderQueue)
    {
        var shader = Shader.Find("Mindstone/Mistport Front Ribbon")
            ?? Shader.Find("Mindstone/Mistport Front Occlusion Sprite")
            ?? Shader.Find("Unlit/Color")
            ?? Shader.Find("Sprites/Default");
        var material = new Material(shader)
        {
            renderQueue = Mathf.Max(renderQueue, 4050)
        };
        if (material.HasProperty("_Color"))
            material.SetColor("_Color", Color.white);
        activeMaterials.Add(material);
        return material;
    }

    Material CreateWildRibbonMaterial(int renderQueue, Color color, Color edgeColor)
    {
        var shader = Shader.Find("Mindstone/Mistport Wild Ribbon")
            ?? Shader.Find("Mindstone/Mistport Front Ribbon")
            ?? Shader.Find("Mindstone/Mistport Front Occlusion Sprite")
            ?? Shader.Find("Unlit/Color")
            ?? Shader.Find("Sprites/Default");
        var material = new Material(shader)
        {
            renderQueue = Mathf.Max(renderQueue, 4250)
        };
        if (material.HasProperty("_Color"))
            material.SetColor("_Color", color);
        if (material.HasProperty("_EdgeColor"))
            material.SetColor("_EdgeColor", edgeColor);
        if (material.HasProperty("_Phase"))
            material.SetFloat("_Phase", 0f);
        if (material.HasProperty("_Glow"))
            material.SetFloat("_Glow", 1.0f);
        activeMaterials.Add(material);
        return material;
    }

    Material CreateFrontOrganicMaterial(int renderQueue, Texture2D texture, int textureCell)
    {
        var shader = Shader.Find("Mindstone/Mistport Front Organic Sprite")
            ?? Shader.Find("Mindstone/Mistport Front Occlusion Sprite")
            ?? Shader.Find("Sprites/Default")
            ?? Shader.Find("Unlit/Transparent");
        var material = new Material(shader)
        {
            renderQueue = Mathf.Max(renderQueue, 4100),
            mainTexture = texture
        };
        if (material.HasProperty("_MainTex"))
            material.SetTexture("_MainTex", texture);
        if (textureCell >= 0 && material.HasProperty("_MainTex"))
        {
            var cell = textureCell % 4;
            material.SetTextureScale("_MainTex", new Vector2(0.5f, 0.5f));
            material.SetTextureOffset("_MainTex", new Vector2((cell % 2) * 0.5f, (cell / 2) * 0.5f));
        }
        if (material.HasProperty("_Color"))
            material.SetColor("_Color", Color.white);
        activeMaterials.Add(material);
        return material;
    }

    Material CreateReferenceFlowMaterial(
        int renderQueue,
        Texture2D texture,
        Texture2D noise,
        float lumaMask,
        float envelope,
        float colorFloor)
    {
        var shader = Shader.Find("Mindstone/Mistport Reference Flow Sprite")
            ?? Shader.Find("Mindstone/Mistport Front Organic Sprite")
            ?? Shader.Find("Mindstone/Mistport Front Occlusion Sprite")
            ?? Shader.Find("Sprites/Default")
            ?? Shader.Find("Unlit/Transparent");
        var material = new Material(shader)
        {
            renderQueue = Mathf.Max(renderQueue, 4250),
            mainTexture = texture
        };
        if (material.HasProperty("_MainTex"))
            material.SetTexture("_MainTex", texture);
        if (material.HasProperty("_NoiseTex"))
            material.SetTexture("_NoiseTex", noise != null ? noise : texture);
        if (material.HasProperty("_LumaMask"))
            material.SetFloat("_LumaMask", lumaMask);
        if (material.HasProperty("_Envelope"))
            material.SetFloat("_Envelope", envelope);
        if (material.HasProperty("_ColorFloor"))
            material.SetFloat("_ColorFloor", colorFloor);
        if (material.HasProperty("_Distortion"))
            material.SetFloat("_Distortion", 0.055f);
        if (material.HasProperty("_NoiseBreakup"))
            material.SetFloat("_NoiseBreakup", 0.32f);
        if (material.HasProperty("_Color"))
            material.SetColor("_Color", Color.white);
        activeMaterials.Add(material);
        return material;
    }

    Material CreateHoundMaterial(int renderQueue, Texture2D texture)
    {
        var shader = Shader.Find("Mindstone/Mistport Front Hound Sprite")
            ?? Shader.Find("Mindstone/Mistport Front Occlusion Sprite")
            ?? Shader.Find("Sprites/Default")
            ?? Shader.Find("Unlit/Transparent");
        var material = new Material(shader)
        {
            renderQueue = Mathf.Max(renderQueue, 4300),
            mainTexture = texture
        };
        if (material.HasProperty("_MainTex"))
            material.SetTexture("_MainTex", texture);
        if (material.HasProperty("_Color"))
            material.SetColor("_Color", Color.white);
        activeMaterials.Add(material);
        return material;
    }

    Material CreateCheetahMaterial(
        int renderQueue,
        Texture2D texture,
        Texture2D closedTexture)
    {
        var shader = Shader.Find("Mindstone/Mistport Front Cheetah Sprite")
            ?? Shader.Find("Mindstone/Mistport Front Hound Sprite")
            ?? Shader.Find("Mindstone/Mistport Front Occlusion Sprite")
            ?? Shader.Find("Sprites/Default")
            ?? Shader.Find("Unlit/Transparent");
        var material = new Material(shader)
        {
            renderQueue = Mathf.Max(renderQueue, 4300),
            mainTexture = texture
        };
        if (material.HasProperty("_MainTex"))
            material.SetTexture("_MainTex", texture);
        if (material.HasProperty("_ClosedTex"))
            material.SetTexture("_ClosedTex", closedTexture != null ? closedTexture : texture);
        if (material.HasProperty("_Color"))
            material.SetColor("_Color", Color.white);
        if (material.HasProperty("_EdgeColor"))
            material.SetColor("_EdgeColor", new Color(1f, 0.26f, 0.06f, 1f));
        if (material.HasProperty("_Phase"))
            material.SetFloat("_Phase", 0f);
        if (material.HasProperty("_MouthOpen"))
            material.SetFloat("_MouthOpen", 0f);
        activeMaterials.Add(material);
        return material;
    }

    Material CreateSwordQiMaterial(int renderQueue)
    {
        var shader = Shader.Find("Mindstone/Mistport Front Sword Qi")
            ?? Shader.Find("Mindstone/Mistport Front Ribbon")
            ?? Shader.Find("Mindstone/Mistport Front Occlusion Sprite")
            ?? Shader.Find("Unlit/Color")
            ?? Shader.Find("Sprites/Default");
        var material = new Material(shader)
        {
            renderQueue = Mathf.Max(renderQueue, 4400)
        };
        if (material.HasProperty("_Color"))
            material.SetColor("_Color", new Color(1f, 0.16f, 0.025f, 1f));
        if (material.HasProperty("_EdgeColor"))
            material.SetColor("_EdgeColor", new Color(1f, 0.84f, 0.30f, 1f));
        if (material.HasProperty("_Phase"))
            material.SetFloat("_Phase", 0f);
        if (material.HasProperty("_Glow"))
            material.SetFloat("_Glow", 1.4f);
        if (material.HasProperty("_Alpha"))
            material.SetFloat("_Alpha", 0f);
        activeMaterials.Add(material);
        return material;
    }

    Material CreateHoundParticleMaterial(int renderQueue, Texture2D texture)
    {
        var shader = Shader.Find("Mindstone/Mistport Front Hound Particle")
            ?? Shader.Find("Mindstone/Mistport Front Organic Sprite")
            ?? Shader.Find("Mindstone/Mistport Front Occlusion Sprite")
            ?? Shader.Find("Sprites/Default")
            ?? Shader.Find("Unlit/Transparent");
        var material = new Material(shader)
        {
            renderQueue = Mathf.Max(renderQueue, 4300),
            mainTexture = texture
        };
        if (material.HasProperty("_MainTex"))
            material.SetTexture("_MainTex", texture);
        if (material.HasProperty("_Color"))
            material.SetColor("_Color", Color.white);
        activeMaterials.Add(material);
        return material;
    }

    Material CreateFrontCloudMaterial(int renderQueue)
    {
        var shader = Shader.Find("Mindstone/Mistport Front Cloud")
            ?? Shader.Find("Mindstone/Mistport Front Occlusion Sprite")
            ?? Shader.Find("Sprites/Default")
            ?? Shader.Find("Unlit/Transparent");
        var material = new Material(shader)
        {
            renderQueue = Mathf.Max(renderQueue, 4200)
        };
        if (material.HasProperty("_Color"))
            material.SetColor("_Color", Color.white);
        if (material.HasProperty("_Phase"))
            material.SetFloat("_Phase", 0f);
        activeMaterials.Add(material);
        return material;
    }

    static Quaternion BillboardRotation(Camera camera, float roll)
    {
        if (camera == null)
            return Quaternion.AngleAxis(roll, Vector3.forward);

        var facing = Quaternion.LookRotation(-camera.transform.forward, camera.transform.up);
        return Quaternion.AngleAxis(roll, -camera.transform.forward) * facing;
    }

    static void UpdateSlashSprite(
        SpriteRenderer renderer,
        Vector3 position,
        Camera camera,
        float reveal,
        float roll,
        float alpha,
        Vector3 scale)
    {
        if (renderer == null)
            return;

        var visible = reveal > 0.004f && alpha > 0.003f;
        renderer.enabled = visible;
        if (!visible)
            return;

        renderer.transform.position = position;
        renderer.transform.rotation = BillboardRotation(camera, roll);
        renderer.transform.localScale = scale * reveal;
        var color = renderer.color;
        renderer.color = new Color(color.r, color.g, color.b, alpha);
    }

    static void UpdateWindSprite(
        SpriteRenderer renderer,
        Vector3 position,
        Camera camera,
        float roll,
        Vector3 scale,
        float alpha,
        Color color)
    {
        if (renderer == null)
            return;

        var visible = scale.sqrMagnitude > 0.0001f && alpha > 0.003f;
        renderer.enabled = visible;
        if (!visible)
            return;

        renderer.transform.position = position;
        renderer.transform.rotation = BillboardRotation(camera, roll);
        renderer.transform.localScale = scale;
        renderer.color = new Color(color.r, color.g, color.b, alpha);
    }

    static void UpdateWindSprite(
        MeshRenderer renderer,
        Vector3 position,
        Camera camera,
        float roll,
        Vector3 scale,
        float alpha,
        Color color)
    {
        if (renderer == null)
            return;

        var visible = scale.sqrMagnitude > 0.0001f && alpha > 0.003f;
        renderer.enabled = visible;
        if (!visible)
            return;

        renderer.transform.position = position;
        renderer.transform.rotation = BillboardRotation(camera, roll);
        renderer.transform.localScale = scale;
        var material = renderer.material;
        if (material != null && material.HasProperty("_Color"))
            material.SetColor("_Color", new Color(color.r, color.g, color.b, alpha));
    }

    static void UpdateReferenceFlowSprite(
        MeshRenderer renderer,
        Vector3 position,
        Camera camera,
        float roll,
        Vector3 scale,
        float alpha,
        Color color,
        float phase,
        float distortion = 0.055f,
        float breakup = 0.32f)
    {
        if (renderer == null)
            return;

        var visible = scale.sqrMagnitude > 0.0001f && alpha > 0.003f;
        renderer.enabled = visible;
        if (!visible)
            return;

        renderer.transform.position = position;
        renderer.transform.rotation = BillboardRotation(camera, roll);
        renderer.transform.localScale = scale;
        var material = renderer.material;
        if (material == null)
            return;
        if (material.HasProperty("_Color"))
            material.SetColor("_Color", new Color(color.r, color.g, color.b, alpha));
        if (material.HasProperty("_Phase"))
            material.SetFloat("_Phase", phase);
        if (material.HasProperty("_Distortion"))
            material.SetFloat("_Distortion", distortion);
        if (material.HasProperty("_NoiseBreakup"))
            material.SetFloat("_NoiseBreakup", breakup);
    }

    static void UpdateProceduralVolumeSprite(
        MeshRenderer renderer,
        Vector3 position,
        Camera camera,
        float roll,
        Vector3 scale,
        float alpha,
        Color color,
        float phase,
        float intensity,
        float core,
        float distortion)
    {
        if (renderer == null)
            return;

        var visible = scale.sqrMagnitude > 0.0001f && alpha > 0.003f;
        renderer.enabled = visible;
        if (!visible)
            return;

        renderer.transform.position = position;
        renderer.transform.rotation = BillboardRotation(camera, roll);
        renderer.transform.localScale = scale;
        var material = renderer.material;
        if (material == null)
            return;
        if (material.HasProperty("_Color"))
            material.SetColor("_Color", new Color(color.r, color.g, color.b, alpha));
        if (material.HasProperty("_Phase"))
            material.SetFloat("_Phase", phase);
        if (material.HasProperty("_Intensity"))
            material.SetFloat("_Intensity", intensity);
        if (material.HasProperty("_Core"))
            material.SetFloat("_Core", core);
        if (material.HasProperty("_Distortion"))
            material.SetFloat("_Distortion", distortion);
    }

    Material CreateVFXMaterial(Color color, int renderQueue, Texture2D texture = null)
    {
        var shader = Shader.Find("Mindstone/Fool Additive Sprite")
            ?? Shader.Find("Legacy Shaders/Particles/Additive")
            ?? Shader.Find("Particles/Standard Unlit")
            ?? Shader.Find("Sprites/Default")
            ?? Shader.Find("Unlit/Color");
        var material = new Material(shader);
        material.color = color;
        material.renderQueue = renderQueue;
        if (texture != null)
            material.mainTexture = texture;
        if (material.HasProperty("_Color"))
            material.SetColor("_Color", color);
        if (material.HasProperty("_BaseColor"))
            material.SetColor("_BaseColor", color);
        if (material.HasProperty("_EmissionColor"))
        {
            material.EnableKeyword("_EMISSION");
            material.SetColor("_EmissionColor", color * 2.6f);
        }
        activeMaterials.Add(material);
        return material;
    }

    Material CreateParticleMaterial(Color color, int renderQueue)
    {
        var material = CreateVFXMaterial(color, renderQueue);
        var texture = Resources.Load<Texture2D>("Effects/HellHound/Texture/Fire_Blur")
            ?? Resources.Load<Texture2D>("Effects/Fool/Effekseer/MaskExplosion/Texture/glow");
        if (texture != null)
            material.mainTexture = texture;
        return material;
    }

    static float EaseOutCubic(float value)
    {
        var inverse = 1f - Mathf.Clamp01(value);
        return 1f - inverse * inverse * inverse;
    }

    static float EaseOutBack(float value)
    {
        var t = Mathf.Clamp01(value);
        const float c1 = 1.70158f;
        const float c3 = c1 + 1f;
        return 1f + c3 * Mathf.Pow(t - 1f, 3f) + c1 * Mathf.Pow(t - 1f, 2f);
    }

    static void SetLocation(EffekseerHandle handle, Vector3 position) => handle.SetLocation(position);

    static void SetRotation(EffekseerHandle handle, Quaternion rotation) => handle.SetRotation(rotation);

    static void SetScale(EffekseerHandle handle, Vector3 scale) => handle.SetScale(scale);

    static void StopRoot(EffekseerHandle handle)
    {
        handle.StopRoot();
    }

    void StopActiveEffects()
    {
        for (var i = 0; i < activeHandles.Count; i++)
        {
            activeHandles[i].Stop();
        }
        activeHandles.Clear();

        for (var i = 0; i < activeRoots.Count; i++)
        {
            if (activeRoots[i] != null)
                Destroy(activeRoots[i]);
        }
        activeRoots.Clear();

        for (var i = 0; i < activeMaterials.Count; i++)
        {
            if (activeMaterials[i] != null)
                Destroy(activeMaterials[i]);
        }
        activeMaterials.Clear();

        for (var i = 0; i < activeSprites.Count; i++)
        {
            if (activeSprites[i] != null)
                Destroy(activeSprites[i]);
        }
        activeSprites.Clear();

        for (var i = 0; i < activeTextures.Count; i++)
        {
            if (activeTextures[i] != null)
                Destroy(activeTextures[i]);
        }
        activeTextures.Clear();

        for (var i = 0; i < activeMeshes.Count; i++)
        {
            if (activeMeshes[i] != null)
                Destroy(activeMeshes[i]);
        }
        activeMeshes.Clear();
        impactCoverTexture = null;
        houndParticleDotTexture = null;
    }

    void OnDisable() => Stop();

    void OnDestroy() => Stop();
}
