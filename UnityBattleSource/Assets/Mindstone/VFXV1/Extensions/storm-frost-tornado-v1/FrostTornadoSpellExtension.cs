using System.Collections.Generic;
using Effekseer;
using UnityEngine;
using UnityEngine.Rendering;

namespace Mindstone.VFXV1
{
    /// <summary>
    /// Spell-owned dynamic frost tornado. The core and both impact surfaces
    /// are rebuilt from continuous equations every render sample. Effekseer
    /// contributes short-lived particle ribbons; no complete tornado image is
    /// translated or deformed.
    /// </summary>
    public sealed class FrostTornadoSpellExtension : MonoBehaviour, ISpellExtension
    {
        const string ShaderResource = "Mindstone/VFXV1/Spells/storm-frost-tornado-v1/FrostTornado";
        const string MistShaderResource = "Mindstone/VFXV1/Spells/storm-frost-tornado-v1/FrostMist";
        const string BurstShaderResource = "Mindstone/VFXV1/Spells/storm-frost-tornado-v1/FrostBurst";
        const string PlumeShaderResource = "Mindstone/VFXV1/Spells/storm-frost-tornado-v1/FrostPlume";
        const string CrystalShaderResource = "Mindstone/VFXV1/Spells/storm-frost-tornado-v1/FrostCrystal";
        const string AssetSpriteShaderResource = "Mindstone/VFXV1/Spells/storm-frost-tornado-v1/FrostAssetSprite";
        const string ImpactSmokeTextureResource = "Mindstone/VFXV1/Spells/storm-frost-tornado-v1/Effekseer/FrostStormImpact/Texture/Smoke";
        const string BlueFireTextureResource = "Mindstone/VFXV1/Spells/storm-frost-tornado-v1/Effekseer/SnowstormOfficial/Texture/blue_fire";
        // This mature single-flame silhouette has broken organic contours and
        // no atlas seams, so recoloured accents do not read as painted strips.
        const string AuroraFlameTextureResource = "Mindstone/VFXV1/Spells/storm-frost-tornado-v1/Effekseer/FrostStormImpact/Texture/Fire_Single";
        const string WindTextureResource = "Mindstone/VFXV1/Spells/storm-frost-tornado-v1/Effekseer/FrostStormImpact/Texture/Wind";
        // The frost impact uses the authored white-hot Burst01_2 core.  The
        // old red mask was a different spell family and made the hit read as
        // a flat sticker when it overlapped the cold volume.
        const string BurstTextureResource = "Mindstone/VFXV1/Spells/storm-frost-tornado-v1/Effekseer/SnowstormOfficial/Texture/Burst01_2";
        const string SnowCrystalTextureResource = "Mindstone/VFXV1/Spells/storm-frost-tornado-v1/Effekseer/MagicCold/Texture/SnowCrystals_M";
        const string TravelEffectResource = "Mindstone/VFXV1/Spells/storm-frost-tornado-v1/Effekseer/SnowstormOfficial/snowstorm11";
        const string ImpactStormEffectResource = "Mindstone/VFXV1/Spells/storm-frost-tornado-v1/Effekseer/FrostStormImpact/FrostStormImpact";
        const string ImpactColdEffectResource = "Mindstone/VFXV1/Spells/storm-frost-tornado-v1/Effekseer/FrostStormImpact/FrostStormImpact";
        const string FinalBurstEffectResource = "Effects/HellHound/FrostTornadoFinalBurst";

        // Exact 60-Hz review beats agreed for the showcase.
        const float FormationEnd = 14f / 60f;
        const float ContactTime = 47f / 60f;
        const float AxisTurnEnd = 54f / 60f;
        const float ExpansionEnd = 74f / 60f;
        const float PeakEnd = 84f / 60f;
        const float SpellEnd = 104f / 60f;
        const float ActorHeight = 1.55f;
        const float GroundDrop = 0.95f;

        // The value hierarchy is intentionally dark-jade first. White is a
        // short-lived ridge, not the storm volume, and warm gold is limited to
        // a few sub-pixel glints. This prevents the impact from becoming a
        // white/pink teleport cloud on both the dark board and the game scene.
        static readonly Color DeepIce = new(0.025f, 0.210f, 0.390f, 1f);
        static readonly Color Glacier = new(0.035f, 0.720f, 0.610f, 1f);
        static readonly Color Frost = new(0.250f, 0.890f, 1.000f, 1f);
        static readonly Color IceWhite = new(0.900f, 1.000f, 0.970f, 1f);
        static readonly Color IceBlue = new(0.080f, 0.600f, 0.910f, 1f);
        static readonly Color PaleGold = new(1.000f, 0.760f, 0.210f, 1f);
        static readonly Color MoonCyan = new(0.260f, 0.960f, 1.000f, 1f);
        static readonly Color ArcaneIndigo = new(0.260f, 0.230f, 0.840f, 1f);
        static readonly Color AuroraViolet = new(0.700f, 0.320f, 1.000f, 1f);
        static readonly Color AuroraRose = new(0.950f, 0.300f, 0.740f, 1f);
        static readonly Color MysticJade = new(0.050f, 0.920f, 0.580f, 1f);
        static readonly Color JadeWhite = new(0.820f, 1.000f, 0.930f, 1f);
        static readonly Color WarmWhite = new(1.000f, 0.950f, 0.700f, 1f);

        // Pro review palette for this spell only.  The legacy colors above
        // remain available to the older layers, but the new asset stack uses
        // one cold ink-to-jade-to-cyan ramp so the tornado reads as one
        // authored volume instead of a collage of colored cards.
        static readonly Color InkJade = new(0.043f, 0.188f, 0.208f, 1f);
        static readonly Color Emerald = new(0.110f, 0.467f, 0.447f, 1f);
        static readonly Color IceCyan = new(0.380f, 0.792f, 0.839f, 1f);
        static readonly Color JadeWhitePro = new(0.863f, 0.937f, 0.910f, 1f);

        SpellLayerSpec layer;
        int seed;
        Color layerTint;
        Texture2D flowTexture;
        Material coreMaterial;
        Material mistMaterial;
        Material glowMistMaterial;
        Material travelPlumeMaterial;
        Material groundMaterial;
        Material frontMaterial;
        Material frontMistMaterial;
        Material frontGlowMistMaterial;
        Material impactCoreMistMaterial;
        Material impactBurstMaterial;
        Material crystalMaterial;
        Material blueFireAssetMaterial;
        Material iceFlameAssetMaterial;
        Material windAssetMaterial;
        Material burstAssetMaterial;
        DynamicMeshBatch coreBatch;
        DynamicMeshBatch groundBatch;
        DynamicMeshBatch frontBatch;
        AssetQuadBatch blueFireAssetBatch;
        AssetQuadBatch iceFlameAssetBatch;
        AssetQuadBatch windAssetBatch;
        AssetQuadBatch burstAssetBatch;
        ProceduralMistField mistField;
        ProceduralMistField glowMistField;
        TravelPlumeField travelPlumeField;
        ProceduralMistField frontMistField;
        ProceduralMistField frontGlowMistField;
        ProceduralMistField impactCoreMistField;
        ImpactBurstField impactBurstField;
        CrystalParticleField crystalField;
        EffekseerEffectAsset effectAsset;
        EffekseerHandle effectHandle = new(-1);
        bool effectStarted;
        bool effectRootStopped;
        bool released;

        public void Initialize(SpellSpec spellSpec, SpellLayerSpec layerSpec, int deterministicSeed)
        {
            layer = layerSpec;
            seed = deterministicSeed;
            layerTint = ReadColor(layerSpec.color, Color.white);

            var shader = Resources.Load<Shader>(ShaderResource)
                ?? Shader.Find("Mindstone/VFXV1/Frost Tornado Dynamic Flow")
                ?? Shader.Find("Sprites/Default");
            if (shader == null)
            {
                Debug.LogError("[VFX V1] Frost tornado dynamic-flow shader is unavailable.");
                return;
            }

            switch (layer.role)
            {
                case "core":
                    flowTexture = CreateDirectionlessNoise(seed + 7919);
                    coreMaterial = CreateMaterial(
                        shader,
                        flowTexture,
                        layer.renderQueue > 0 ? layer.renderQueue : 3510,
                        CompareFunction.LessEqual,
                        Color.Lerp(Glacier, MoonCyan, 0.46f));
                    mistMaterial = CreateMaterial(
                        Resources.Load<Shader>(MistShaderResource) ?? shader,
                        flowTexture,
                        layer.renderQueue > 0 ? layer.renderQueue - 30 : 3480,
                        CompareFunction.LessEqual,
                        Color.Lerp(Glacier, Frost, 0.42f));
                    mistMaterial.SetFloat("_Opacity", 0.14f);
                    mistMaterial.SetFloat("_AlphaCap", 0.085f);
                    mistMaterial.SetFloat("_Coverage", 0.015f);
                    mistMaterial.SetFloat("_Occlusion", 0f);
                    mistMaterial.SetFloat("_Intensity", 0.92f);
                    mistMaterial.SetColor("_HotColor", JadeWhite);
                    glowMistMaterial = CreateMaterial(
                        Resources.Load<Shader>(MistShaderResource) ?? shader,
                        flowTexture,
                        layer.renderQueue > 0 ? layer.renderQueue - 18 : 3492,
                        CompareFunction.LessEqual,
                        Color.Lerp(Frost, JadeWhite, 0.28f));
                    glowMistMaterial.SetFloat("_Opacity", 0.11f);
                    glowMistMaterial.SetFloat("_AlphaCap", 0.070f);
                    glowMistMaterial.SetFloat("_Coverage", 0.01f);
                    glowMistMaterial.SetFloat("_Occlusion", 0f);
                    glowMistMaterial.SetFloat("_Intensity", 1.02f);
                    glowMistMaterial.SetColor("_HotColor", JadeWhite);
                    var travelPlumeShader = Resources.Load<Shader>(PlumeShaderResource)
                        ?? Resources.Load<Shader>(MistShaderResource)
                        ?? shader;
                    var travelSmokeTexture = Resources.Load<Texture2D>(ImpactSmokeTextureResource)
                        ?? flowTexture;
                    travelPlumeMaterial = CreateMaterial(
                        travelPlumeShader,
                        travelSmokeTexture,
                        4988,
                        CompareFunction.Always,
                        Color.Lerp(MysticJade, MoonCyan, 0.46f));
                    travelPlumeMaterial.SetColor("_HotColor", Color.Lerp(IceWhite, JadeWhite, 0.36f));
                    travelPlumeMaterial.SetFloat("_Opacity", 0.18f);
                    travelPlumeMaterial.SetFloat("_AlphaCap", 0.14f);
                    travelPlumeMaterial.SetFloat("_Coverage", 0.012f);
                    travelPlumeMaterial.SetFloat("_Occlusion", 0f);
                    travelPlumeMaterial.SetFloat("_Intensity", 0.92f);
                    travelPlumeMaterial.SetFloat("_Accent", 0.10f);
                    coreMaterial.SetFloat("_AlphaCap", 0.34f);
                    coreMaterial.SetColor("_HotColor", JadeWhite);
                    coreBatch = new DynamicMeshBatch(transform, "Frost core helix", coreMaterial, layer.sortingOrder);
                    mistField = new ProceduralMistField(
                        transform,
                        mistMaterial,
                        layer.sortingOrder - 1,
                        unchecked((uint)(seed + 28411)),
                        28,
                        true);
                    glowMistField = new ProceduralMistField(
                        transform,
                        glowMistMaterial,
                        layer.sortingOrder,
                        unchecked((uint)(seed + 35171)),
                        16,
                        true);
                    travelPlumeField = new TravelPlumeField(
                        transform,
                        travelPlumeMaterial,
                        4988,
                        unchecked((uint)(seed + 42391)));
                    InitializeMatureAssetComposition(false);
                    effectAsset = Resources.Load<EffekseerEffectAsset>(TravelEffectResource);
                    break;

                case "impact-back":
                    effectAsset = Resources.Load<EffekseerEffectAsset>(
                        layer.name == "effekseer-violet-pressure-shell"
                            ? ImpactColdEffectResource
                            : ImpactStormEffectResource);
                    break;

                case "impact-front":
                    flowTexture = CreateDirectionlessNoise(seed + 1543);
                    var mistShader = Resources.Load<Shader>(MistShaderResource)
                        ?? shader;
                    var burstShader = Resources.Load<Shader>(BurstShaderResource)
                        ?? Resources.Load<Shader>(PlumeShaderResource)
                        ?? mistShader;
                    var smokeTexture = Resources.Load<Texture2D>(ImpactSmokeTextureResource)
                        ?? flowTexture;
                    groundMaterial = CreateMaterial(
                        shader,
                        flowTexture,
                        3280,
                        CompareFunction.LessEqual,
                        Color.Lerp(IceBlue, Frost, 0.42f));
                    frontMaterial = CreateMaterial(
                        shader,
                        flowTexture,
                        4990,
                        CompareFunction.Always,
                        Color.Lerp(MysticJade, Frost, 0.46f));
                    frontMistMaterial = CreateMaterial(
                        mistShader,
                        flowTexture,
                        4970,
                        CompareFunction.Always,
                        Color.Lerp(Glacier, Frost, 0.38f));
                    var crystalShader = Resources.Load<Shader>(AssetSpriteShaderResource)
                        ?? Resources.Load<Shader>(CrystalShaderResource)
                        ?? shader;
                    var crystalTexture = Resources.Load<Texture2D>(SnowCrystalTextureResource)
                        ?? flowTexture;
                    crystalMaterial = CreateMaterial(
                        crystalShader,
                        crystalTexture,
                        4998,
                        CompareFunction.Always,
                        IceBlue);
                    crystalMaterial.SetColor("_HotColor", Color.Lerp(IceWhite, PaleGold, 0.08f));
                    crystalMaterial.SetColor("_DeepColor", DeepIce);
                    crystalMaterial.SetColor("_WarmColor", PaleGold);
                    crystalMaterial.SetFloat("_Opacity", 0.92f);
                    crystalMaterial.SetFloat("_AlphaCap", 0.82f);
                    crystalMaterial.SetFloat("_Intensity", 1.90f);
                    crystalMaterial.SetFloat("_Distortion", 0.008f);
                    crystalMaterial.SetFloat("_CutLow", 0.02f);
                    crystalMaterial.SetFloat("_CutHigh", 0.18f);
                    crystalMaterial.SetFloat("_ArcSpan", 1f);
                    crystalMaterial.SetFloat("_WarmAmount", 0.012f);
                    crystalMaterial.SetFloat("_SourceMix", 0f);
                    crystalMaterial.SetFloat("_VertexMix", 0.92f);
                    crystalMaterial.SetFloat("_UseSourceAlpha", 1f);
                    groundMaterial.SetFloat("_AlphaCap", 0.14f);
                    frontMaterial.SetFloat("_AlphaCap", 0.34f);
                    frontMaterial.SetColor("_HotColor", JadeWhite);
                    frontMistMaterial.SetColor("_HotColor", JadeWhite);
                    // Mist is edge depth only. The faceted brush geometry is
                    // responsible for the premium silhouette and engulfment.
                    frontMistMaterial.SetFloat("_Opacity", 0.18f);
                    frontMistMaterial.SetFloat("_AlphaCap", 0.16f);
                    frontMistMaterial.SetFloat("_Coverage", 0.03f);
                    frontMistMaterial.SetFloat("_Occlusion", 0f);
                    frontMistMaterial.SetFloat("_Intensity", 1.02f);
                    frontGlowMistMaterial = CreateMaterial(
                        mistShader,
                        flowTexture,
                        4986,
                        CompareFunction.Always,
                        Color.Lerp(Frost, JadeWhite, 0.24f));
                    frontGlowMistMaterial.SetColor("_HotColor", JadeWhite);
                    frontGlowMistMaterial.SetFloat("_Opacity", 0.16f);
                    frontGlowMistMaterial.SetFloat("_AlphaCap", 0.14f);
                    frontGlowMistMaterial.SetFloat("_Coverage", 0.02f);
                    frontGlowMistMaterial.SetFloat("_Occlusion", 0f);
                    frontGlowMistMaterial.SetFloat("_Intensity", 1.12f);
                    impactCoreMistMaterial = CreateMaterial(
                        mistShader,
                        flowTexture,
                        4998,
                        CompareFunction.Always,
                        Color.Lerp(MoonCyan, JadeWhite, 0.30f));
                    impactCoreMistMaterial.SetColor("_HotColor", JadeWhite);
                    impactCoreMistMaterial.SetFloat("_Opacity", 0.24f);
                    impactCoreMistMaterial.SetFloat("_AlphaCap", 0.22f);
                    impactCoreMistMaterial.SetFloat("_Coverage", 0.06f);
                    impactCoreMistMaterial.SetFloat("_Occlusion", 0f);
                    impactCoreMistMaterial.SetFloat("_Intensity", 1.08f);
                    impactBurstMaterial = CreateMaterial(
                        burstShader,
                        flowTexture,
                        4999,
                        CompareFunction.Always,
                        Color.Lerp(DeepIce, Glacier, 0.50f));
                    impactBurstMaterial.SetColor("_HotColor", IceWhite);
                    impactBurstMaterial.SetFloat("_Opacity", 0f);
                    impactBurstMaterial.SetFloat("_AlphaCap", 0.40f);
                    impactBurstMaterial.SetFloat("_Coverage", 0.18f);
                    impactBurstMaterial.SetFloat("_Occlusion", 0.14f);
                    impactBurstMaterial.SetFloat("_Intensity", 1.42f);
                    groundBatch = new DynamicMeshBatch(transform, "Broken frost ground skirt", groundMaterial, layer.sortingOrder - 1);
                    // The established showcase effects use their late render
                    // queue as the sorting order for true actor-overdraw.
                    // A small order such as 19 lets the skinned actor render
                    // back over an Always-tested transparent mesh.
                    frontBatch = new DynamicMeshBatch(
                        transform,
                        "Short frost front veil",
                        frontMaterial,
                        Mathf.Max(layer.sortingOrder + 1, 4990));
                    frontMistField = new ProceduralMistField(
                        transform,
                        frontMistMaterial,
                        Mathf.Max(layer.sortingOrder, 4970),
                        unchecked((uint)(seed + 61717)),
                        40,
                        true);
                    frontGlowMistField = new ProceduralMistField(
                        transform,
                        frontGlowMistMaterial,
                        4986,
                        unchecked((uint)(seed + 65521)),
                        12,
                        true);
                    impactCoreMistField = new ProceduralMistField(
                        transform,
                        impactCoreMistMaterial,
                        4998,
                        unchecked((uint)(seed + 67531)),
                        10,
                        true);
                    impactBurstField = new ImpactBurstField(
                        transform,
                        impactBurstMaterial,
                        4999,
                        unchecked((uint)(seed + 73973)));
                    InitializeMatureAssetComposition(true);
                    crystalField = new CrystalParticleField(
                        transform,
                        crystalMaterial,
                        Mathf.Max(layer.sortingOrder + 2, 4998),
                        unchecked((uint)(seed + 77317)));
                    break;

                case "accent":
                    // Spell-private copy of the approved FireBall Finish
                    // branch: charge/travel were removed and its multi-
                    // emitter volume was recolored without touching the
                    // locked source effect.
                    effectAsset = Resources.Load<EffekseerEffectAsset>(FinalBurstEffectResource);
                    break;
            }

        }

        public void Sample(in SpellSample sample)
        {
            if (released)
                return;

            // The host places extension roots on spell anchors. Geometry here
            // is authored in world space, so inherited projectile rotation and
            // scale must not tilt the post-impact column.
            transform.rotation = Quaternion.identity;
            transform.localScale = Vector3.one;

            var frame = Frame.From(sample);
            var phase = ContinuousPhase(sample.AbsoluteTime) + Seed01(seed) * Mathf.PI * 2f;

            switch (layer.role)
            {
                case "core":
                    SampleCore(in sample, in frame, phase);
                    break;
                case "impact-back":
                    if (layer.name == "effekseer-violet-pressure-shell")
                        SampleImpactCold(in sample, phase);
                    else
                        SampleImpactStorm(in sample, phase);
                    break;
                case "impact-front":
                    SampleVolumetricImpact(in sample, in frame, phase);
                    break;
                case "accent":
                    SampleFinalBurst(in sample, in frame, phase);
                    break;
            }
        }

        /// <summary>
        /// Builds the commercial asset stack from mature Effekseer sample
        /// textures.  The textures provide the micro-detail and organic
        /// silhouette; Unity only recolors, crops, bends and times them.
        /// Every role owns its own materials so travel and actor-engulfing
        /// impact can use different depth and sorting policies safely.
        /// </summary>
        void InitializeMatureAssetComposition(bool impact)
        {
            var assetShader = Resources.Load<Shader>(AssetSpriteShaderResource)
                ?? Shader.Find("Mindstone/VFXV1/Frost Recolored Asset Sprite")
                ?? Shader.Find("Sprites/Default");
            var blueFire = Resources.Load<Texture2D>(BlueFireTextureResource);
            var auroraFlame = Resources.Load<Texture2D>(AuroraFlameTextureResource);
            var wind = Resources.Load<Texture2D>(WindTextureResource);
            var burst = Resources.Load<Texture2D>(BurstTextureResource);
            if (assetShader == null || blueFire == null || auroraFlame == null || wind == null)
            {
                Debug.LogError("[VFX V1] Frost tornado mature Effekseer texture stack is incomplete.");
                return;
            }

            var zTest = impact ? CompareFunction.Always : CompareFunction.Always;
            var blueQueue = impact ? 4994 : 4962;
            var windQueue = impact ? 4992 : 4958;
            var flameQueue = impact ? 4996 : 4966;
            blueFireAssetMaterial = CreateAssetMaterial(
                assetShader,
                blueFire,
                blueQueue,
                zTest,
                InkJade,
                Emerald,
                IceCyan,
                JadeWhitePro,
                impact ? 0.66f : 0.58f,
                impact ? 1.28f : 1.18f,
                0.060f,
                1f,
                false);
            // Source hue is intentionally disabled.  We keep the source
            // alpha/silhouette/detail, but never reintroduce the atlas's
            // indigo or rose islands into the approved frost palette.
            blueFireAssetMaterial.SetFloat("_SourceMix", 0f);
            blueFireAssetMaterial.SetFloat("_VertexMix", impact ? 0.20f : 0.16f);
            blueFireAssetMaterial.SetFloat("_WarmAmount", 0.006f);
            iceFlameAssetMaterial = CreateAssetMaterial(
                assetShader,
                auroraFlame,
                flameQueue,
                zTest,
                InkJade,
                Emerald,
                IceCyan,
                JadeWhitePro,
                impact ? 0.25f : 0.21f,
                impact ? 1.22f : 1.16f,
                0.035f,
                1f,
                false);
            iceFlameAssetMaterial.SetFloat("_SourceMix", 0f);
            iceFlameAssetMaterial.SetFloat("_VertexMix", 0.18f);
            iceFlameAssetMaterial.SetFloat("_WarmAmount", 0.004f);
            windAssetMaterial = CreateAssetMaterial(
                assetShader,
                wind,
                windQueue,
                zTest,
                InkJade,
                Emerald,
                IceCyan,
                JadeWhitePro,
                impact ? 0.38f : 0.34f,
                impact ? 1.18f : 1.12f,
                0.025f,
                impact ? 0.46f : 0.40f,
                true);
            windAssetMaterial.SetFloat("_SourceMix", 0f);
            windAssetMaterial.SetFloat("_VertexMix", 0.15f);
            windAssetMaterial.SetFloat("_WarmAmount", 0.003f);

            blueFireAssetBatch = new AssetQuadBatch(
                transform,
                impact ? "Mature blue-fire impact body" : "Mature blue-fire travel body",
                blueFireAssetMaterial,
                blueQueue);
            windAssetBatch = new AssetQuadBatch(
                transform,
                impact ? "Broken mature wind impact arcs" : "Broken mature wind travel arc",
                windAssetMaterial,
                windQueue);
            iceFlameAssetBatch = new AssetQuadBatch(
                transform,
                impact ? "Mature aurora-flame impact tongues" : "Mature aurora-flame travel tongues",
                iceFlameAssetMaterial,
                flameQueue);

            if (impact && burst != null)
            {
                burstAssetMaterial = CreateAssetMaterial(
                    assetShader,
                    burst,
                    5000,
                    CompareFunction.Always,
                    InkJade,
                    Emerald,
                    JadeWhitePro,
                    JadeWhitePro,
                    1f,
                    2.18f,
                    0.012f,
                    1f,
                    true);
                burstAssetBatch = new AssetQuadBatch(
                    transform,
                    "Short white-hot mature burst core",
                    burstAssetMaterial,
                    5000);
                burstAssetMaterial.SetFloat("_SourceMix", 0f);
                burstAssetMaterial.SetFloat("_VertexMix", 0.12f);
                burstAssetMaterial.SetFloat("_WarmAmount", 0.003f);
            }
        }

        public void Interrupt() => Release();
        public void Cleanup() => Release();
        void OnDestroy() => Release();

        void SampleCore(in SpellSample sample, in Frame frame, float phase)
        {
            var time = sample.AbsoluteTime;
            var visibility = Ease(0.025f, 0.17f, time) * (1f - Ease(1.50f, SpellEnd, time));
            var travelVisibility = visibility * (1f - Ease(ContactTime, 0.90f, time));
            var impactVisibility = Ease(ContactTime, 0.817f, time)
                * (1f - Ease(1.40f, 1.56f, time));
            var motionCenter = ResolveContinuousMotionCenter(in sample, time);
            var formation = Ease(0.025f, FormationEnd, time);
            var travelGrowth = Ease(FormationEnd, ContactTime, time);
            var travelLength = ActorHeight * Mathf.Lerp(
                Mathf.Lerp(0.26f, 0.34f, formation),
                0.62f,
                travelGrowth);
            var travelRadius = ActorHeight * Mathf.Lerp(
                Mathf.Lerp(0.09f, 0.12f, formation),
                0.23f,
                travelGrowth);
            var travelShape = new Shape(travelLength, travelRadius, 2.35f, 1f);
            var basePosition = motionCenter
                - frame.CameraUp * (travelLength * 0.52f)
                - frame.CameraForward * (ActorHeight * 0.035f);
            var upright = Quaternion.FromToRotation(Vector3.up, frame.CameraUp);
            var ground = sample.Target - Vector3.up * GroundDrop;
            var impactProfile = ResolveCommercialImpactProfile(time);
            var impactBase = ground
                + frame.CameraUp * (ActorHeight * (0.035f + impactProfile.LiftH))
                - frame.CameraForward * (ActorHeight * 0.035f);
            var accent = ResolveAccentStrength(time)
                * (1f - Ease(1.42f, 1.50f, time));

            if (coreMaterial != null)
            {
                coreMaterial.SetFloat("_Phase", phase / (Mathf.PI * 2f));
                coreMaterial.SetFloat("_Opacity", Mathf.Max(
                    travelVisibility * 0.74f,
                    impactVisibility * 0.58f));
                coreMaterial.SetFloat("_AlphaCap", 0.48f);
                coreMaterial.SetFloat("_Accent", Mathf.Max(travelVisibility * 0.70f, accent * 0.78f));
            }
            if (mistMaterial != null)
            {
                mistMaterial.SetFloat("_Phase", phase / (Mathf.PI * 2f) * 0.63f);
                mistMaterial.SetFloat("_Opacity", 0.46f);
                mistMaterial.SetFloat("_AlphaCap", 0.24f);
                mistMaterial.SetFloat("_Coverage", travelVisibility * 0.11f);
                mistMaterial.SetFloat("_Occlusion", travelVisibility * 0.055f);
                mistMaterial.SetFloat("_Intensity", 1.34f);
                mistMaterial.SetFloat("_Accent", Mathf.Max(travelVisibility * 0.24f, accent * 0.24f));
            }
            if (glowMistMaterial != null)
            {
                glowMistMaterial.SetFloat("_Phase", phase / (Mathf.PI * 2f) * 0.81f + 0.17f);
                glowMistMaterial.SetFloat("_Opacity", 0.42f);
                glowMistMaterial.SetFloat("_AlphaCap", 0.22f);
                glowMistMaterial.SetFloat("_Coverage", travelVisibility * 0.085f);
                glowMistMaterial.SetFloat("_Occlusion", travelVisibility * 0.028f);
                glowMistMaterial.SetFloat("_Intensity", 1.58f);
                glowMistMaterial.SetFloat("_Accent", Mathf.Max(travelVisibility * 0.38f, accent * 0.40f));
            }

            coreBatch?.Begin();
            // No mesh sheet is allowed in travel. The continuous silhouette
            // comes from overlapping deterministic particle volumes; this
            // removes the large negative-space bands a partial cone exposes.
            coreBatch?.Commit();

            SampleTravelAssetComposition(
                basePosition,
                in frame,
                travelLength,
                travelRadius,
                phase,
                time,
                travelVisibility);

            if (travelPlumeMaterial != null)
            {
                travelPlumeMaterial.SetFloat("_Phase", phase / (Mathf.PI * 2f) * 0.84f);
                travelPlumeMaterial.SetFloat("_Opacity", Mathf.Lerp(0.15f, 0.21f, travelGrowth));
                travelPlumeMaterial.SetFloat("_AlphaCap", Mathf.Lerp(0.11f, 0.16f, travelGrowth));
                travelPlumeMaterial.SetFloat("_Coverage", 0.012f);
                travelPlumeMaterial.SetFloat("_Occlusion", 0f);
                travelPlumeMaterial.SetFloat("_Intensity", Mathf.Lerp(0.88f, 1.00f, travelGrowth));
                travelPlumeMaterial.SetFloat("_Accent", 0.10f);
            }
            // The legacy plume is a pair of straight billboard lanes.  It is
            // intentionally silenced while the mature asset surface owns the
            // travel silhouette; keeping it alive is exactly what produced
            // the thin cyan lines in the review capture.
            travelPlumeField?.Sample(
                basePosition,
                frame.CameraRight,
                frame.CameraUp,
                frame.CameraForward,
                travelLength,
                travelRadius,
                phase,
                time,
                0f);

            if (impactVisibility >= travelVisibility)
            {
                var impactShape = new Shape(
                    ActorHeight * impactProfile.HeightH,
                    ActorHeight * impactProfile.CrownRadiusH * 0.94f,
                    impactProfile.Turns,
                    1f);
                mistField?.Sample(
                    impactBase,
                    upright,
                    impactShape,
                    phase + 0.11f,
                    0f,
                    frame.CameraForward,
                    time);
                var impactGlowShape = new Shape(
                    impactShape.Length * 0.82f,
                    impactShape.Radius * 0.54f,
                    impactShape.Turns + 0.28f,
                    1f);
                glowMistField?.Sample(
                    impactBase + frame.CameraUp * (ActorHeight * 0.07f),
                    upright,
                    impactGlowShape,
                    phase + 0.47f,
                    impactVisibility * 0.07f,
                    frame.CameraForward,
                    time + 0.137f);
            }
            else
            {
                mistField?.Sample(
                    basePosition,
                    upright,
                    travelShape,
                    phase,
                    0f,
                    frame.CameraForward,
                    time);
                var glowShape = new Shape(
                    travelLength * 0.88f,
                    travelRadius * 0.54f,
                    2.20f,
                    0.18f);
                glowMistField?.Sample(
                    basePosition + frame.CameraUp * (travelLength * 0.035f),
                    upright,
                    glowShape,
                    phase + 1.47f,
                    0f,
                    frame.CameraForward,
                    time + 0.137f);
            }
            // Do not mix the old Snowstorm11 line emitter into the rebuilt
            // asset-driven projectile.  It remains available to the authored
            // Effekseer library, but this spell preview must show one source
            // of truth for the silhouette.
            var effectVisibility = 0f;
            var effectScale = Mathf.Lerp(0.18f, 0.34f, Ease(FormationEnd, ContactTime, time));
            UpdateEffekseer(
                in sample,
                basePosition,
                upright * Quaternion.AngleAxis(phase * Mathf.Rad2Deg, Vector3.up),
                Vector3.one * effectScale,
                ApplyAlpha(Color.Lerp(Color.white, MoonCyan, 0.16f), effectVisibility * 0.52f),
                time >= 0.90f);
        }

        void SampleTravelAssetComposition(
            Vector3 basePosition,
            in Frame frame,
            float length,
            float radius,
            float phase,
            float time,
            float visibility)
        {
            blueFireAssetBatch?.Begin();
            iceFlameAssetBatch?.Begin();
            windAssetBatch?.Begin();
            if (visibility <= 0.002f)
            {
                blueFireAssetBatch?.Commit();
                iceFlameAssetBatch?.Commit();
                windAssetBatch?.Commit();
                return;
            }

            // Pro pass: three cropped surfaces share one axis and one cold
            // palette.  They are open cone sectors, not whole vertical
            // sprites, so the projectile reads as a compressed frost vortex
            // that grows toward impact rather than a stack of cards.
            var growth = Ease(0.04f, ContactTime, time);
            if (blueFireAssetMaterial != null)
            {
                blueFireAssetMaterial.SetFloat("_Phase", phase / (Mathf.PI * 2f) * 0.42f);
                blueFireAssetMaterial.SetFloat("_Opacity", Mathf.Lerp(0.62f, 0.78f, growth));
                blueFireAssetMaterial.SetFloat("_AlphaCap", Mathf.Lerp(0.42f, 0.56f, growth));
                blueFireAssetMaterial.SetFloat("_Intensity", Mathf.Lerp(1.04f, 1.18f, growth));
                blueFireAssetMaterial.SetFloat("_Distortion", Mathf.Lerp(0.038f, 0.060f, growth));
                blueFireAssetMaterial.SetFloat("_EdgeErode", Mathf.Lerp(0.34f, 0.48f, growth));
                blueFireAssetMaterial.SetFloat("_SourceMix", 0f);
                blueFireAssetMaterial.SetFloat("_VertexMix", 0.14f);
            }
            if (iceFlameAssetMaterial != null)
            {
                iceFlameAssetMaterial.SetFloat("_Phase", -phase / (Mathf.PI * 2f) * 0.34f + 0.18f);
                iceFlameAssetMaterial.SetFloat("_Opacity", 0.32f);
                iceFlameAssetMaterial.SetFloat("_AlphaCap", 0.28f);
                iceFlameAssetMaterial.SetFloat("_Intensity", 1.14f);
                iceFlameAssetMaterial.SetFloat("_SourceMix", 0f);
                iceFlameAssetMaterial.SetFloat("_VertexMix", 0.16f);
            }
            var axisHeight = Mathf.Max(length, ActorHeight * 0.22f);
            var baseRadius = Mathf.Max(ActorHeight * 0.018f, radius * 0.18f);
            var waistRadius = Mathf.Max(ActorHeight * 0.035f, radius * 0.50f);
            var crownRadius = Mathf.Max(ActorHeight * 0.055f, radius * 0.88f);
            var travelRoot = InkJade;
            travelRoot.a = visibility * 0.22f;
            var travelMid = Emerald;
            travelMid.a = visibility * 0.28f;
            var travelTip = IceCyan;
            travelTip.a = visibility * 0.24f;
            blueFireAssetBatch?.AddOpenFunnelSurface(
                basePosition,
                frame.CameraRight,
                frame.CameraUp,
                frame.CameraForward,
                axisHeight,
                baseRadius,
                waistRadius,
                crownRadius,
                0.48f,
                0.72f,
                105f * Mathf.Deg2Rad,
                phase + 0.12f,
                9,
                18,
                new Rect(0.12f, 0.12f, 0.58f, 0.66f),
                0.00f,
                travelRoot,
                travelMid,
                travelTip,
                time,
                Seed01(seed + 1101));
            var travelRootB = Color.Lerp(InkJade, Emerald, 0.24f);
            travelRootB.a = visibility * 0.19f;
            var travelMidB = Color.Lerp(Emerald, IceCyan, 0.62f);
            travelMidB.a = visibility * 0.25f;
            var travelTipB = JadeWhitePro;
            travelTipB.a = visibility * 0.18f;
            blueFireAssetBatch?.AddOpenFunnelSurface(
                basePosition + frame.CameraRight * (radius * 0.055f),
                frame.CameraRight,
                frame.CameraUp,
                frame.CameraForward,
                axisHeight * 0.94f,
                baseRadius * 1.10f,
                waistRadius * 0.92f,
                crownRadius * 0.86f,
                0.52f,
                0.68f,
                130f * Mathf.Deg2Rad,
                phase + 2.18f,
                9,
                18,
                new Rect(0.18f, 0.08f, 0.66f, 0.70f),
                0.23f,
                travelRootB,
                travelMidB,
                travelTipB,
                time + 0.08f,
                Seed01(seed + 1107));
            var travelRootC = Color.Lerp(InkJade, Emerald, 0.42f);
            travelRootC.a = visibility * 0.15f;
            var travelMidC = Color.Lerp(Emerald, IceCyan, 0.48f);
            travelMidC.a = visibility * 0.21f;
            var travelTipC = IceCyan;
            travelTipC.a = visibility * 0.16f;
            blueFireAssetBatch?.AddOpenFunnelSurface(
                basePosition - frame.CameraRight * (radius * 0.045f),
                frame.CameraRight,
                frame.CameraUp,
                frame.CameraForward,
                axisHeight * 0.88f,
                baseRadius * 0.92f,
                waistRadius * 0.82f,
                crownRadius * 0.74f,
                0.45f,
                0.76f,
                90f * Mathf.Deg2Rad,
                phase + 4.63f,
                8,
                16,
                new Rect(0.22f, 0.18f, 0.52f, 0.62f),
                0.47f,
                travelRootC,
                travelMidC,
                travelTipC,
                time - 0.06f,
                Seed01(seed + 1113));

            // Fire_Single is only used as three short internal wind cuts. It
            // never forms a full outline or a second axis.
            var cutAlpha = visibility * Mathf.Lerp(0.12f, 0.18f, growth);
            var cutColors = new[]
            {
                Color.Lerp(Emerald, IceCyan, 0.56f),
                Color.Lerp(IceCyan, JadeWhitePro, 0.24f),
                Color.Lerp(Emerald, IceCyan, 0.78f)
            };
            var cutAngles = new[] { -29f, 17f, 111f };
            var cutLengths = new[] { 0.58f, 0.46f, 0.34f };
            var cutWidths = new[] { 0.095f, 0.080f, 0.062f };
            for (var index = 0; index < 3; index++)
            {
                var cut = cutColors[index];
                cut.a = cutAlpha * (index == 1 ? 0.88f : 0.72f);
                var normalized = (index + 0.45f) / 3f;
                iceFlameAssetBatch?.AddQuad(
                    basePosition
                        + frame.CameraUp * (axisHeight * Mathf.Lerp(0.30f, 0.76f, normalized))
                        + frame.CameraRight * (Mathf.Sin(phase + index * 2.1f) * radius * 0.16f)
                        - frame.CameraForward * (ActorHeight * (0.058f + index * 0.006f)),
                    frame.CameraRight,
                    frame.CameraUp,
                    ActorHeight * cutWidths[index],
                    axisHeight * cutLengths[index],
                    cutAngles[index] + Mathf.Sin(time * 2.2f + index) * 8f,
                    cut,
                    FireAtlasCrop(index),
                    (index & 1) != 0,
                    index == 2);
            }

            blueFireAssetBatch?.Commit();
            iceFlameAssetBatch?.Commit();
            windAssetBatch?.Commit();
            return;

            var legacyGrowth = Ease(0.04f, ContactTime, time);
            if (blueFireAssetMaterial != null)
            {
                blueFireAssetMaterial.SetFloat("_Phase", phase / (Mathf.PI * 2f) * 0.82f);
                blueFireAssetMaterial.SetFloat("_Opacity", Mathf.Lerp(0.70f, 0.84f, growth));
                blueFireAssetMaterial.SetFloat("_AlphaCap", Mathf.Lerp(0.46f, 0.61f, growth));
                blueFireAssetMaterial.SetFloat("_Intensity", Mathf.Lerp(1.10f, 1.28f, growth));
                blueFireAssetMaterial.SetFloat("_Distortion", Mathf.Lerp(0.048f, 0.074f, growth));
                blueFireAssetMaterial.SetFloat("_EdgeErode", Mathf.Lerp(0.18f, 0.26f, growth));
            }
            if (iceFlameAssetMaterial != null)
            {
                iceFlameAssetMaterial.SetFloat("_Phase", -phase / (Mathf.PI * 2f) * 0.73f + 0.27f);
                iceFlameAssetMaterial.SetFloat("_Opacity", Mathf.Lerp(0.38f, 0.58f, growth));
                iceFlameAssetMaterial.SetFloat("_Intensity", Mathf.Lerp(1.28f, 1.52f, growth));
                iceFlameAssetMaterial.SetFloat("_ArcSpan", 1f);
                iceFlameAssetMaterial.SetFloat("_EdgeErode", 0.18f);
            }
            if (windAssetMaterial != null)
            {
                windAssetMaterial.SetFloat("_Phase", phase / (Mathf.PI * 2f) * 0.54f + 0.61f);
                windAssetMaterial.SetFloat("_Opacity", Mathf.Lerp(0.16f, 0.28f, growth));
                windAssetMaterial.SetFloat("_Intensity", Mathf.Lerp(1.08f, 1.22f, growth));
                windAssetMaterial.SetFloat("_ArcSpan", Mathf.Lerp(0.30f, 0.44f, growth));
            }

            // Two counter-rotating lanes follow an S-curved centreline.  The
            // toe stays narrow while the crown opens strongly, giving a clear
            // tornado silhouette instead of a uniformly bright rectangular
            // column.  Large overlaps retain volume without exposing cards.
            var levelCount = time < 0.26f ? 5 : time < 0.58f ? 6 : 7;
            var blueCount = levelCount * 2;
            for (var index = 0; index < blueCount; index++)
            {
                var level = index / 2;
                var lane = index & 1;
                var normalized = Mathf.Clamp01((level + 0.34f + lane * 0.15f) / levelCount);
                var angle = phase * Mathf.Lerp(0.42f, 0.72f, normalized)
                    + lane * Mathf.PI + level * 1.31f;
                var profile = Mathf.Lerp(0.10f, 1.0f, Mathf.Pow(normalized, 0.76f));
                var centreSwing = Mathf.Sin(
                    phase * 0.34f + normalized * Mathf.PI * 2.35f)
                    * radius * Mathf.Lerp(0.12f, 0.46f, normalized);
                var point = basePosition
                    + frame.CameraUp * (length * Mathf.Lerp(0.045f, 0.93f, normalized))
                    + frame.CameraRight * (centreSwing
                        + Mathf.Sin(angle) * radius * profile * 0.36f)
                    - frame.CameraForward * (ActorHeight * (0.045f + lane * 0.008f));
                var width = radius * Mathf.Lerp(0.34f, 1.72f, Mathf.Pow(normalized, 0.72f))
                    * (lane == 0 ? 1.08f : 0.94f)
                    * Mathf.Lerp(0.94f, 1.08f, Mathf.Sin(time * 6.1f + index) * 0.5f + 0.5f);
                var height = length * Mathf.Lerp(0.22f, 0.34f, normalized)
                    * (lane == 0 ? 1.06f : 0.92f);
                var color = lane == 0
                    ? Color.Lerp(MysticJade, MoonCyan, 0.52f)
                    : Color.Lerp(AuroraViolet, Frost, 0.42f);
                if (level == levelCount - 2 && lane == 1)
                    color = Color.Lerp(PaleGold, JadeWhite, 0.48f);
                color.a = visibility * (lane == 0
                    ? Mathf.Lerp(0.46f, 0.60f, normalized)
                    : Mathf.Lerp(0.40f, 0.54f, normalized));
                blueFireAssetBatch?.AddQuad(
                    point,
                    frame.CameraRight,
                    frame.CameraUp,
                    width,
                    height,
                    TravelAssetRotation(index, phase, time),
                    color,
                    lane == 0 && (level & 1) == 0
                        ? BlueFireCrop(level)
                        : BlueFireFragmentCrop(index + level),
                    (index & 1) != 0,
                    index == 2);
            }

            // No wind-ring card is drawn in travel. Even a broken ring reads
            // as a coarse line once the camera is close; rotation is carried
            // by the changing overlap and UV flow of the ice-flame surfaces.

            // Counter-rotating cropped flame tongues from the mature Holy
            // Sandstorm atlas add violet/jade/gold motion without drawing a
            // second geometric coil over the funnel.
            var accentCount = time < 0.32f ? 3 : 5;
            for (var index = 0; index < accentCount; index++)
            {
                var normalized = (index + 0.58f) / accentCount;
                var orbit = -phase * (0.24f + normalized * 0.12f) + index * 1.91f;
                var accent = index == accentCount - 1
                    ? Color.Lerp(PaleGold, JadeWhite, 0.36f)
                    : Color.Lerp(ArcaneIndigo, AuroraViolet, 0.58f);
                accent.a = visibility * Mathf.Lerp(0.15f, 0.27f, growth);
                iceFlameAssetBatch?.AddQuad(
                    basePosition
                        + frame.CameraUp * (length * Mathf.Lerp(0.20f, 0.84f, normalized))
                        + frame.CameraRight * (Mathf.Cos(orbit) * radius * 0.32f)
                        - frame.CameraForward * (ActorHeight * (0.092f + index * 0.004f)),
                    frame.CameraRight,
                    frame.CameraUp,
                    radius * Mathf.Lerp(0.50f, 0.98f, normalized),
                    length * Mathf.Lerp(0.16f, 0.28f, normalized),
                    Mathf.Sin(orbit) * 14f + (index % 2 == 0 ? 16f : -18f),
                    accent,
                    FireAtlasCrop(index),
                    (index & 1) != 0,
                    false);
            }

            blueFireAssetBatch?.Commit();
            iceFlameAssetBatch?.Commit();
            windAssetBatch?.Commit();
        }

        static Rect BlueFireCrop(int index)
        {
            switch (index & 3)
            {
                case 0: return new Rect(0.00f, 0.00f, 1.00f, 1.00f);
                case 1: return new Rect(0.10f, 0.02f, 0.84f, 0.88f);
                case 2: return new Rect(0.02f, 0.12f, 0.90f, 0.82f);
                default: return new Rect(0.08f, 0.08f, 0.86f, 0.86f);
            }
        }

        static Rect BlueFireFragmentCrop(int index)
        {
            switch (index % 5)
            {
                case 0: return new Rect(0.02f, 0.04f, 0.50f, 0.48f);
                case 1: return new Rect(0.48f, 0.03f, 0.49f, 0.46f);
                case 2: return new Rect(0.04f, 0.49f, 0.47f, 0.48f);
                case 3: return new Rect(0.50f, 0.49f, 0.47f, 0.48f);
                default: return new Rect(0.20f, 0.16f, 0.60f, 0.66f);
            }
        }

        static Rect FireAtlasCrop(int index)
        {
            switch (index & 3)
            {
                case 0: return new Rect(0.00f, 0.50f, 0.50f, 0.50f);
                case 1: return new Rect(0.50f, 0.50f, 0.50f, 0.50f);
                case 2: return new Rect(0.00f, 0.00f, 0.50f, 0.50f);
                default: return new Rect(0.50f, 0.00f, 0.50f, 0.50f);
            }
        }

        static float TravelAssetRotation(int index, float phase, float time)
        {
            switch (index & 3)
            {
                case 0: return -12f + Mathf.Sin(time * 2.3f) * 6f;
                case 1: return 16f + phase * Mathf.Rad2Deg * 0.018f;
                case 2: return -18f - phase * Mathf.Rad2Deg * 0.016f;
                default: return 9f + Mathf.Sin(time * 3.1f) * 7f;
            }
        }

        void SampleImpactStorm(in SpellSample sample, float phase)
        {
            const float EffekseerStart = 0.765f;
            var time = sample.AbsoluteTime;
            if (time < EffekseerStart)
                return;

            // FrostStormImpact contains the legacy vertical ribbon pair.  It
            // is not part of the Pro-approved funnel vocabulary and visually
            // overwhelms the new connected surface, so leave this extension
            // layer empty until a proper cropped back-smoke asset is authored.
            return;

            var frame = Frame.From(sample);
            var pressure = Ease(EffekseerStart, 0.875f, time);
            var release = Ease(1.040f, 1.360f, time);
            var visibility = pressure * (1f - Ease(1.380f, 1.540f, time));
            var impactScale = Mathf.Lerp(0.046f, 0.072f, pressure)
                * Mathf.Lerp(1f, 1.18f, release);
            var impactPosition = sample.Target
                - frame.CameraUp * (ActorHeight * 0.12f)
                - frame.CameraForward * (ActorHeight * 0.105f);
            var impactColor = Color.Lerp(MysticJade, MoonCyan, 0.56f);
            impactColor = Color.Lerp(impactColor, IceWhite, 0.10f + 0.03f * Mathf.Sin(phase));

            UpdateEffekseer(
                in sample,
                impactPosition,
                Quaternion.identity,
                Vector3.one * impactScale,
                ApplyAlpha(impactColor, visibility),
                time >= 1.115f,
                2.40f);
        }

        void SampleImpactCold(in SpellSample sample, float phase)
        {
            const float EffekseerStart = 0.835f;
            var time = sample.AbsoluteTime;
            if (time < EffekseerStart)
                return;

            // Same isolation rule as SampleImpactStorm: the old impact asset
            // is a line/ring language, not the rebuilt cold funnel.
            return;

            var frame = Frame.From(sample);
            var pressure = Ease(EffekseerStart, 0.950f, time);
            var release = Ease(1.120f, 1.440f, time);
            var visibility = pressure * (1f - Ease(1.420f, 1.560f, time));
            var impactPosition = sample.Target
                + frame.CameraRight * (ActorHeight * 0.035f)
                - frame.CameraUp * (ActorHeight * 0.08f)
                - frame.CameraForward * (ActorHeight * 0.125f);
            var impactScale = Mathf.Lerp(0.038f, 0.061f, pressure)
                * Mathf.Lerp(1f, 1.24f, release);
            var coldColor = Color.Lerp(Emerald, IceCyan, 0.48f);
            coldColor = Color.Lerp(coldColor, JadeWhitePro, 0.08f + 0.025f * Mathf.Cos(phase));

            UpdateEffekseer(
                in sample,
                impactPosition,
                Quaternion.identity,
                Vector3.one * impactScale,
                ApplyAlpha(coldColor, visibility),
                time >= 1.205f,
                2.05f);
        }

        void SampleFinalBurst(in SpellSample sample, in Frame frame, float phase)
        {
            // The accent layer used a separate legacy Effekseer burst which
            // reintroduced the same ribbon silhouettes during decay.  The
            // impact-front layer now owns the deterministic residue and core.
            return;
            var time = sample.LayerTime;
            var echo = layer.name.Contains("echo");
            // Keep the first deterministic tick barely alive. A true zero on
            // a late layer is indistinguishable from a terminal fade to the
            // shared Effekseer cleanup guard and would retire the handle before
            // its first authored child emitters are sampled.
            var onset = Mathf.Lerp(
                0.08f,
                1f,
                Ease(0f, echo ? 0.055f : 0.035f, time));
            var fade = 1f - Ease(echo ? 0.105f : 0.145f, echo ? 0.165f : 0.225f, time);
            var visibility = onset * fade;
            var expansion = Ease(0f, echo ? 0.175f : 0.155f, time);
            var pulse = 1f + Mathf.Sin(phase * (echo ? 0.31f : 0.27f)) * 0.025f;
            var scale = echo
                ? Mathf.Lerp(0.10f, 0.28f, expansion)
                : Mathf.Lerp(0.14f, 0.36f, expansion);

            var color = echo
                ? ApplyAlpha(Color.Lerp(Emerald, IceCyan, 0.28f), visibility * 0.72f)
                : ApplyAlpha(Color.Lerp(IceCyan, InkJade, 0.18f), visibility * 0.80f);

            var position = sample.Target
                + frame.CameraUp * (ActorHeight * (echo ? 0.18f : 0.24f))
                + frame.CameraRight * (ActorHeight * (echo ? 0.035f : -0.018f))
                - frame.CameraForward * (ActorHeight * (echo ? 0.155f : 0.135f));
            var rotation = Quaternion.AngleAxis(
                echo ? -17f : 11f,
                frame.CameraForward.sqrMagnitude > 0.001f ? frame.CameraForward : Vector3.forward);

            UpdateEffekseer(
                in sample,
                position,
                rotation,
                Vector3.one * (scale * pulse),
                color,
                time >= (echo ? 0.100f : 0.140f),
                echo ? 1.32f : 1.52f);
        }

        /// <summary>
        /// Five-beat impact authored as genuinely different states: a tight
        /// contact knot, delayed pressure release, opaque aurora detonation,
        /// radial frost-flame breakup, then separated ice debris.  The actor
        /// renderer is never disabled; the front-sorted layers physically
        /// engulf it during the detonation beat.
        /// </summary>
        void SampleVolumetricImpact(in SpellSample sample, in Frame frame, float phase)
        {
            var time = sample.AbsoluteTime;
            var ground = sample.Target - Vector3.up * GroundDrop;
            var contact = Ease(ContactTime, 0.833f, time);
            var detonation = Ease(0.950f, 1.180f, time);
            // The contact funnel must be gone before the review's peak frame.
            // Keeping it alive under the burst was what made stages three and
            // four read as the same growing cotton cloud.
            var columnVisibility = contact * (1f - Ease(1.030f, 1.230f, time));
            // A separate peak envelope provides real foreground coverage.
            // It starts after the compact contact knot and dies before the
            // authored breakup, so the five review beats remain distinct.
            var engulfVisibility = Ease(ContactTime, 0.870f, time)
                * (1f - Ease(1.405f, 1.505f, time));
            var accent = ResolveAccentStrength(time);
            var columnPosition = ground
                + frame.CameraUp * (ActorHeight * Mathf.Lerp(0.17f, 0.025f, detonation))
                - frame.CameraForward * (ActorHeight * 0.070f);
            var engulfPosition = ground
                + frame.CameraUp * (ActorHeight * 0.035f)
                - frame.CameraForward * (ActorHeight * 0.182f);
            var basePosition = Vector3.Lerp(
                columnPosition,
                engulfPosition,
                Mathf.Clamp01(engulfVisibility));

            if (frontMistMaterial != null)
            {
                frontMistMaterial.SetFloat("_Phase", phase / (Mathf.PI * 2f) * 0.57f + 0.17f);
                frontMistMaterial.SetColor(
                    "_Tint",
                    Color.Lerp(DeepIce, MysticJade, 0.52f));
                frontMistMaterial.SetColor(
                    "_HotColor",
                    Color.Lerp(MoonCyan, JadeWhite, 0.22f));
                frontMistMaterial.SetFloat("_Opacity", Mathf.Lerp(0.10f, 0.24f, engulfVisibility));
                frontMistMaterial.SetFloat("_AlphaCap", Mathf.Lerp(0.08f, 0.18f, engulfVisibility));
                frontMistMaterial.SetFloat("_Coverage", Mathf.Lerp(0.02f, 0.10f, engulfVisibility));
                frontMistMaterial.SetFloat("_Occlusion", engulfVisibility * 0.12f);
                frontMistMaterial.SetFloat("_Intensity", Mathf.Lerp(0.94f, 1.08f, engulfVisibility));
                frontMistMaterial.SetFloat("_Accent", accent * Mathf.Lerp(0.12f, 0.28f, engulfVisibility));
            }
            if (frontGlowMistMaterial != null)
            {
                frontGlowMistMaterial.SetFloat("_Phase", phase / (Mathf.PI * 2f) * 0.79f + 0.51f);
                frontGlowMistMaterial.SetColor(
                    "_Tint",
                    Color.Lerp(Emerald, IceCyan, 0.48f));
                frontGlowMistMaterial.SetColor("_HotColor", JadeWhite);
                frontGlowMistMaterial.SetFloat("_Opacity", Mathf.Lerp(0.08f, 0.18f, engulfVisibility));
                frontGlowMistMaterial.SetFloat("_AlphaCap", Mathf.Lerp(0.06f, 0.13f, engulfVisibility));
                frontGlowMistMaterial.SetFloat("_Coverage", Mathf.Lerp(0.008f, 0.07f, engulfVisibility));
                frontGlowMistMaterial.SetFloat("_Occlusion", 0f);
                frontGlowMistMaterial.SetFloat("_Intensity", Mathf.Lerp(1.06f, 1.18f, engulfVisibility));
                frontGlowMistMaterial.SetFloat("_Accent", accent * Mathf.Lerp(0.16f, 0.46f, engulfVisibility));
            }

            var height = ActorHeight * Mathf.Lerp(
                Mathf.Lerp(0.66f, 0.92f, detonation),
                1.36f,
                engulfVisibility);
            var radius = ActorHeight * Mathf.Lerp(
                Mathf.Lerp(0.17f, 0.30f, detonation),
                0.62f,
                engulfVisibility);
            var outerShape = new Shape(
                height,
                radius,
                Mathf.Lerp(Mathf.Lerp(1.18f, 2.34f, detonation), 1.86f, engulfVisibility),
                1f);
            frontMistField?.Sample(
                basePosition,
                Quaternion.identity,
                outerShape,
                phase + 0.63f,
                0f,
                frame.CameraForward,
                time);

            var innerShape = new Shape(
                height * 0.82f,
                radius * 0.60f,
                outerShape.Turns + 0.41f,
                1f);
            frontGlowMistField?.Sample(
                basePosition + frame.CameraUp * (ActorHeight * 0.065f),
                Quaternion.identity,
                innerShape,
                -phase * 0.73f + 2.21f,
                0f,
                frame.CameraForward,
                time + 0.091f);

            // The first hit is deliberately compact.  The large burst is
            // delayed, so the contact frame cannot look like the later peak.
            var pressureVisibility = contact * (1f - Ease(0.900f, 1.020f, time));
            var pressureScale = ResolveImpactBurstScale(time);
            if (impactCoreMistMaterial != null)
            {
                impactCoreMistMaterial.SetFloat("_Phase", phase / (Mathf.PI * 2f) * 0.91f + 0.38f);
                impactCoreMistMaterial.SetFloat("_Opacity", pressureVisibility * 0.12f);
                impactCoreMistMaterial.SetFloat("_AlphaCap", 0.10f);
                impactCoreMistMaterial.SetFloat("_Coverage", 0.015f);
                impactCoreMistMaterial.SetFloat("_Occlusion", 0f);
                impactCoreMistMaterial.SetFloat("_Intensity", 0.98f);
                impactCoreMistMaterial.SetFloat("_Accent", pressureVisibility * 0.14f);
            }
            var pressureShape = new Shape(
                ActorHeight * 0.54f * pressureScale.y,
                ActorHeight * 0.44f * pressureScale.x,
                1.08f,
                1f);
            impactCoreMistField?.Sample(
                ground + frame.CameraUp * (ActorHeight * 0.34f)
                    - frame.CameraForward * (ActorHeight * 0.085f),
                Quaternion.identity,
                pressureShape,
                phase - 0.77f,
                pressureVisibility * 0.12f,
                frame.CameraForward,
                time + 0.037f);

            // The old front mesh assembled the hit from six hand-authored
            // lobes. In motion their borders exposed the exact polygons and
            // created the repeated "paper片" silhouette. Clear that batch on
            // every sample; the dense foreground is now entirely atlas-based
            // organic plume particles.
            frontBatch?.Begin();
            frontBatch?.Commit();

            // The pressure field belongs to the detonation beat only.  Shut
            // the renderer off before the final review beat; otherwise its
            // many overlapping billboard plumes keep rebuilding a central
            // mass after the authored atlas fragments have already separated.
            var particleBurstVisibility = Ease(0.785f, 0.817f, time)
                * (1f - Ease(0.840f, 0.925f, time)) * 0.18f;
            if (impactBurstMaterial != null)
            {
                impactBurstMaterial.SetFloat("_Phase", phase / (Mathf.PI * 2f) * 0.76f + 0.31f);
                impactBurstMaterial.SetFloat("_Opacity", 0.22f);
                impactBurstMaterial.SetFloat("_AlphaCap", 0.16f);
                impactBurstMaterial.SetFloat("_Coverage", 0.08f);
                impactBurstMaterial.SetFloat("_Occlusion", 0.04f);
                impactBurstMaterial.SetFloat("_Intensity", 1.12f);
                impactBurstMaterial.SetFloat("_Accent", Mathf.Lerp(0.14f, 0.22f, detonation));
            }
            impactBurstField?.Sample(
                ground + frame.CameraUp * (ActorHeight * 0.50f)
                    - frame.CameraForward * (ActorHeight * 0.158f),
                frame.CameraRight,
                frame.CameraUp,
                frame.CameraForward,
                time,
                ActorHeight,
                particleBurstVisibility);

            SampleImpactAssetComposition(ground, in frame, phase, time);
            crystalField?.Sample(
                ground + Vector3.up * (ActorHeight * 0.18f),
                frame.CameraRight,
                frame.CameraUp,
                frame.CameraForward,
                time,
                ActorHeight);
        }

        void SampleImpactAssetComposition(
            Vector3 ground,
            in Frame frame,
            float phase,
            float time)
        {
            blueFireAssetBatch?.Begin();
            iceFlameAssetBatch?.Begin();
            windAssetBatch?.Begin();
            burstAssetBatch?.Begin();

            // Pro pass: one continuous impact vocabulary.  The hit starts as
            // a horizontal compressed shell, turns into a three-surface
            // funnel, then leaves only an upper residue.  No radial billboard
            // cloud, full source rectangle or independent colored card is
            // allowed into the review frames.
            var proContact = Ease(0.770f, 0.817f, time)
                * (1f - Ease(0.858f, 0.935f, time));
            var proShell = Ease(0.785f, 0.817f, time)
                * (1f - Ease(0.900f, 1.045f, time));
            var proFunnel = Ease(0.900f, 1.267f, time)
                * (1f - Ease(1.400f, 1.520f, time));
            var proResidue = 1f - Ease(1.420f, SpellEnd, time);
            var proCuts = Ease(0.805f, 0.830f, time)
                * (1f - Ease(1.300f, 1.420f, time));

            if (blueFireAssetMaterial != null)
            {
                blueFireAssetMaterial.SetFloat("_Phase", phase / (Mathf.PI * 2f) * 0.33f + 0.06f);
                blueFireAssetMaterial.SetFloat("_Opacity", 0.76f);
                blueFireAssetMaterial.SetFloat("_AlphaCap", Mathf.Lerp(0.48f, 0.62f, proFunnel));
                blueFireAssetMaterial.SetFloat("_Intensity", Mathf.Lerp(1.04f, 1.22f, proFunnel));
                blueFireAssetMaterial.SetFloat("_Distortion", Mathf.Lerp(0.052f, 0.078f, proFunnel));
                blueFireAssetMaterial.SetFloat("_EdgeErode", Mathf.Lerp(0.30f, 0.58f, proFunnel));
                blueFireAssetMaterial.SetFloat("_SourceMix", 0f);
                blueFireAssetMaterial.SetFloat("_VertexMix", 0.18f);
            }
            if (iceFlameAssetMaterial != null)
            {
                iceFlameAssetMaterial.SetFloat("_Phase", -phase / (Mathf.PI * 2f) * 0.42f + 0.19f);
                iceFlameAssetMaterial.SetFloat("_Opacity", 0.36f);
                iceFlameAssetMaterial.SetFloat("_AlphaCap", 0.24f);
                iceFlameAssetMaterial.SetFloat("_Intensity", 1.22f);
                iceFlameAssetMaterial.SetFloat("_SourceMix", 0f);
                iceFlameAssetMaterial.SetFloat("_VertexMix", 0.16f);
            }
            if (windAssetMaterial != null)
                windAssetMaterial.SetFloat("_Opacity", 0f);
            if (burstAssetMaterial != null)
            {
                burstAssetMaterial.SetFloat("_SourceMix", 0f);
                burstAssetMaterial.SetFloat("_VertexMix", 0.08f);
                burstAssetMaterial.SetFloat("_WarmAmount", 0.002f);
            }

            if (proShell > 0.002f)
            {
                var shellRoot = Color.Lerp(InkJade, Emerald, 0.18f);
                shellRoot.a = proShell * 0.30f;
                var shellMid = Color.Lerp(Emerald, IceCyan, 0.44f);
                shellMid.a = proShell * 0.34f;
                var shellTip = JadeWhitePro;
                shellTip.a = proShell * 0.23f;
                var shellCenter = ground
                    + frame.CameraUp * (ActorHeight * 0.49f)
                    - frame.CameraForward * (ActorHeight * 0.14f);
                blueFireAssetBatch?.AddOpenFunnelSurface(
                    shellCenter - frame.CameraRight * (ActorHeight * 0.40f),
                    frame.CameraUp,
                    frame.CameraRight,
                    frame.CameraForward,
                    ActorHeight * 0.80f,
                    ActorHeight * 0.22f,
                    ActorHeight * 0.42f,
                    ActorHeight * 0.33f,
                    0.49f,
                    0.86f,
                    250f * Mathf.Deg2Rad,
                    phase + 0.12f,
                    9,
                    18,
                    new Rect(0.12f, 0.10f, 0.58f, 0.70f),
                    0.12f,
                    shellRoot,
                    shellMid,
                    shellTip,
                    time,
                    Seed01(seed + 1201));
                var shellNear = Color.Lerp(InkJade, Emerald, 0.30f);
                shellNear.a = proShell * 0.23f;
                var shellNearMid = Color.Lerp(Emerald, IceCyan, 0.62f);
                shellNearMid.a = proShell * 0.27f;
                var shellNearTip = Color.Lerp(IceCyan, JadeWhitePro, 0.45f);
                shellNearTip.a = proShell * 0.18f;
                blueFireAssetBatch?.AddOpenFunnelSurface(
                    shellCenter - frame.CameraRight * (ActorHeight * 0.33f)
                        - frame.CameraForward * (ActorHeight * 0.05f),
                    frame.CameraUp,
                    frame.CameraRight,
                    frame.CameraForward,
                    ActorHeight * 0.70f,
                    ActorHeight * 0.18f,
                    ActorHeight * 0.34f,
                    ActorHeight * 0.30f,
                    0.52f,
                    0.96f,
                    210f * Mathf.Deg2Rad,
                    phase + 2.31f,
                    8,
                    16,
                    new Rect(0.23f, 0.08f, 0.54f, 0.72f),
                    0.46f,
                    shellNear,
                    shellNearMid,
                    shellNearTip,
                    time + 0.06f,
                    Seed01(seed + 1207));
            }

            if (proFunnel > 0.002f)
            {
                var funnelOrigin = ground
                    + frame.CameraUp * (ActorHeight * 0.025f)
                    - frame.CameraForward * (ActorHeight * 0.18f);
                var funnelRoot = InkJade;
                funnelRoot.a = proFunnel * 0.24f;
                var funnelMid = Emerald;
                funnelMid.a = proFunnel * 0.33f;
                var funnelTip = IceCyan;
                funnelTip.a = proFunnel * 0.28f;
                blueFireAssetBatch?.AddOpenFunnelSurface(
                    funnelOrigin,
                    frame.CameraRight,
                    frame.CameraUp,
                    frame.CameraForward,
                    ActorHeight * 1.46f,
                    ActorHeight * 0.105f,
                    ActorHeight * 0.255f,
                    ActorHeight * 0.48f,
                    0.44f,
                    0.72f,
                    225f * Mathf.Deg2Rad,
                    phase + 0.81f,
                    13,
                    20,
                    new Rect(0.10f, 0.16f, 0.52f, 0.64f),
                    0.18f,
                    funnelRoot,
                    funnelMid,
                    funnelTip,
                    time,
                    Seed01(seed + 1213));
                var funnelLeft = Color.Lerp(InkJade, Emerald, 0.34f);
                funnelLeft.a = proFunnel * 0.19f;
                var funnelLeftMid = Color.Lerp(Emerald, IceCyan, 0.52f);
                funnelLeftMid.a = proFunnel * 0.25f;
                var funnelLeftTip = JadeWhitePro;
                funnelLeftTip.a = proFunnel * 0.18f;
                blueFireAssetBatch?.AddOpenFunnelSurface(
                    funnelOrigin + frame.CameraRight * (ActorHeight * 0.025f),
                    frame.CameraRight,
                    frame.CameraUp,
                    frame.CameraForward,
                    ActorHeight * 1.38f,
                    ActorHeight * 0.092f,
                    ActorHeight * 0.225f,
                    ActorHeight * 0.43f,
                    0.47f,
                    0.66f,
                    205f * Mathf.Deg2Rad,
                    phase + 2.24f,
                    12,
                    18,
                    new Rect(0.22f, 0.08f, 0.64f, 0.66f),
                    0.42f,
                    funnelLeft,
                    funnelLeftMid,
                    funnelLeftTip,
                    time + 0.07f,
                    Seed01(seed + 1219));
                var funnelNear = Color.Lerp(Emerald, IceCyan, 0.48f);
                funnelNear.a = proFunnel * 0.16f;
                var funnelNearMid = Color.Lerp(IceCyan, JadeWhitePro, 0.34f);
                funnelNearMid.a = proFunnel * 0.21f;
                var funnelNearTip = IceCyan;
                funnelNearTip.a = proFunnel * 0.14f;
                blueFireAssetBatch?.AddOpenFunnelSurface(
                    funnelOrigin - frame.CameraForward * (ActorHeight * 0.065f),
                    frame.CameraRight,
                    frame.CameraUp,
                    frame.CameraForward,
                    ActorHeight * 1.30f,
                    ActorHeight * 0.082f,
                    ActorHeight * 0.20f,
                    ActorHeight * 0.37f,
                    0.41f,
                    0.92f,
                    245f * Mathf.Deg2Rad,
                    phase + 4.42f,
                    11,
                    18,
                    new Rect(0.18f, 0.20f, 0.56f, 0.58f),
                    0.77f,
                    funnelNear,
                    funnelNearMid,
                    funnelNearTip,
                    time - 0.05f,
                    Seed01(seed + 1225));
            }

            if (proCuts > 0.002f)
            {
                var cutAngles = new[] { -29f, 17f, 111f };
                var cutLengths = new[] { 0.58f, 0.46f, 0.34f };
                var cutWidths = new[] { 0.095f, 0.080f, 0.062f };
                for (var index = 0; index < 3; index++)
                {
                    var cut = Color.Lerp(Emerald, IceCyan, 0.45f + index * 0.12f);
                    if (index == 1)
                        cut = Color.Lerp(IceCyan, JadeWhitePro, 0.26f);
                    cut.a = proCuts * (index == 1 ? 0.18f : 0.14f);
                    iceFlameAssetBatch?.AddQuad(
                        ground
                            + frame.CameraUp * (ActorHeight * (0.34f + index * 0.24f))
                            + frame.CameraRight * (Mathf.Sin(phase + index * 1.7f) * ActorHeight * 0.10f)
                            - frame.CameraForward * (ActorHeight * (0.19f + index * 0.006f)),
                        frame.CameraRight,
                        frame.CameraUp,
                        ActorHeight * cutWidths[index],
                        ActorHeight * cutLengths[index],
                        cutAngles[index] + Mathf.Sin(time * 3.0f + index) * 10f,
                        cut,
                        FireAtlasCrop(index),
                        (index & 1) != 0,
                        index == 2);
                }
            }

            var proBurst = Ease(0.785f, 0.817f, time)
                * (1f - Ease(0.840f, 0.925f, time));
            if (proBurst > 0.002f && burstAssetBatch != null)
            {
                var burstColor = JadeWhitePro;
                burstColor.a = proBurst * 0.48f;
                burstAssetBatch?.AddQuad(
                    ground
                        + frame.CameraUp * (ActorHeight * 0.47f)
                        - frame.CameraForward * (ActorHeight * 0.235f),
                    frame.CameraRight,
                    frame.CameraUp,
                    ActorHeight * 0.18f,
                    ActorHeight * 0.23f,
                    phase * Mathf.Rad2Deg * 0.04f,
                    burstColor,
                    new Rect(0.08f, 0.08f, 0.84f, 0.84f),
                    false,
                    false);
            }

            if (proResidue > 0.002f)
            {
                var residueAlpha = Mathf.Lerp(0.13f, 0.025f, Ease(1.42f, SpellEnd, time))
                    * proResidue;
                var residueOrigin = ground
                    + frame.CameraUp * (ActorHeight * 0.82f)
                    - frame.CameraForward * (ActorHeight * 0.12f);
                var residueRoot = Emerald;
                residueRoot.a = residueAlpha;
                var residueMid = IceCyan;
                residueMid.a = residueAlpha * 1.18f;
                var residueTip = JadeWhitePro;
                residueTip.a = residueAlpha * 0.82f;
                blueFireAssetBatch?.AddOpenFunnelSurface(
                    residueOrigin,
                    frame.CameraRight,
                    frame.CameraUp,
                    frame.CameraForward,
                    ActorHeight * 0.46f,
                    ActorHeight * 0.035f,
                    ActorHeight * 0.14f,
                    ActorHeight * 0.28f,
                    0.42f,
                    0.74f,
                    165f * Mathf.Deg2Rad,
                    phase + 1.04f,
                    7,
                    14,
                    new Rect(0.26f, 0.22f, 0.48f, 0.54f),
                    0.28f,
                    residueRoot,
                    residueMid,
                    residueTip,
                    time,
                    Seed01(seed + 1231));
                var residueCut = Color.Lerp(IceCyan, JadeWhitePro, 0.34f);
                residueCut.a = residueAlpha * 0.92f;
                iceFlameAssetBatch?.AddQuad(
                    residueOrigin + frame.CameraUp * (ActorHeight * 0.09f)
                        - frame.CameraForward * (ActorHeight * 0.025f),
                    frame.CameraRight,
                    frame.CameraUp,
                    ActorHeight * 0.055f,
                    ActorHeight * 0.32f,
                    -24f + phase * Mathf.Rad2Deg * 0.03f,
                    residueCut,
                    new Rect(0.14f, 0.16f, 0.62f, 0.64f),
                    true,
                    false);
            }

            windAssetBatch?.Commit();
            blueFireAssetBatch?.Commit();
            iceFlameAssetBatch?.Commit();
            burstAssetBatch?.Commit();
            return;

            var contact = Ease(ContactTime, 0.825f, time)
                * (1f - Ease(0.915f, 1.035f, time));
            var release = Ease(0.805f, 1.050f, time)
                * (1f - Ease(1.560f, SpellEnd, time));
            var expansion = Ease(0.820f, 1.180f, time);
            var peakBody = release * (1f - Ease(1.420f, 1.520f, time));
            var scatter = Ease(1.360f, 1.540f, time);

            if (blueFireAssetMaterial != null)
            {
                blueFireAssetMaterial.SetFloat("_Phase", phase / (Mathf.PI * 2f) * 0.94f + 0.13f);
                // High alpha supplies true actor occlusion; restrained light
                // intensity preserves coloured midtones instead of bleaching
                // the entire impact into one white additive mass.
                blueFireAssetMaterial.SetFloat("_Opacity", Mathf.Lerp(0.84f, 0.98f, expansion));
                blueFireAssetMaterial.SetFloat("_AlphaCap", Mathf.Lerp(0.64f, 0.78f, expansion));
                blueFireAssetMaterial.SetFloat("_Intensity", Mathf.Lerp(1.02f, 1.20f, expansion));
                blueFireAssetMaterial.SetFloat("_Distortion", Mathf.Lerp(0.052f, 0.088f, scatter));
                blueFireAssetMaterial.SetFloat("_EdgeErode", Mathf.Lerp(0.16f, 0.82f, scatter));
                // During contact and peak, retain the dark coloured body of
                // the mature texture instead of keeping only its bright
                // holes.  Breakup restores the higher threshold so detached
                // fragments remain crisp and do not turn into square cards.
                blueFireAssetMaterial.SetFloat("_CutLow", Mathf.Lerp(0.006f, 0.030f, scatter));
                blueFireAssetMaterial.SetFloat("_CutHigh", Mathf.Lerp(0.105f, 0.235f, scatter));
                blueFireAssetMaterial.SetFloat("_AlphaCap", Mathf.Lerp(0.98f, 0.72f, scatter));
            }
            if (iceFlameAssetMaterial != null)
            {
                iceFlameAssetMaterial.SetFloat("_Phase", -phase / (Mathf.PI * 2f) * 0.82f + 0.47f);
                iceFlameAssetMaterial.SetFloat("_Opacity", Mathf.Lerp(0.52f, 0.74f, expansion));
                iceFlameAssetMaterial.SetFloat("_Intensity", Mathf.Lerp(1.42f, 1.78f, expansion));
                iceFlameAssetMaterial.SetFloat("_ArcSpan", 1f);
                iceFlameAssetMaterial.SetFloat("_EdgeErode", Mathf.Lerp(0.14f, 0.74f, scatter));
            }
            if (windAssetMaterial != null)
            {
                windAssetMaterial.SetFloat("_Phase", phase / (Mathf.PI * 2f) * 0.68f + 0.79f);
                // Impact uses plume tongues and snow crystals instead of
                // horizontally squashed wind rings.  Keeping this material
                // at zero also prevents stale line cards during replay.
                windAssetMaterial.SetFloat("_Opacity", 0f);
            }

            // Beat 1: a compact knot physically enters the target.  Three
            // blue-fire masses provide opacity and three cropped flame-atlas
            // tongues give it an irregular, colourful edge.  No ring card is
            // allowed in the impact foreground.
            if (contact > 0.002f)
            {
                for (var index = 0; index < 3; index++)
                {
                    var angle = phase * (0.26f + index * 0.026f) + index * 2.11f;
                    var point = ground
                        + frame.CameraUp * (ActorHeight * (0.25f + 0.22f * index))
                        + frame.CameraRight * (Mathf.Sin(angle) * ActorHeight * 0.10f)
                        - frame.CameraForward * (ActorHeight * (0.082f + index * 0.007f));
                    var color = ImpactAssetColor(index);
                    color.a = contact * Mathf.Lerp(0.50f, 0.66f, index / 2f);
                    blueFireAssetBatch?.AddQuad(
                        point,
                        frame.CameraRight,
                        frame.CameraUp,
                        ActorHeight * Mathf.Lerp(0.44f, 0.68f, index / 2f),
                        ActorHeight * Mathf.Lerp(0.32f, 0.52f, index / 2f),
                        TravelAssetRotation(index, phase, time) * 0.52f,
                        color,
                        BlueFireCrop(index),
                        (index & 1) != 0,
                        index == 2);
                }

                // Two front-sorted, overlapping flame bodies make the
                // instant of contact physically pass in front of the target.
                // They are source-shaped and rotated differently, so this is
                // an engulfing volume rather than hiding the actor renderer
                // or drawing a geometric mask.
                for (var index = 0; index < 2; index++)
                {
                    var cover = index == 0
                        ? Color.Lerp(DeepIce, MysticJade, 0.64f)
                        : Color.Lerp(ArcaneIndigo, MoonCyan, 0.46f);
                    cover.a = contact * 0.96f;
                    blueFireAssetBatch?.AddQuad(
                        ground
                            + frame.CameraRight * (ActorHeight * (index == 0 ? -0.045f : 0.055f))
                            + frame.CameraUp * (ActorHeight * (index == 0 ? 0.33f : 0.78f))
                            - frame.CameraForward * (ActorHeight * (0.205f + index * 0.008f)),
                        frame.CameraRight,
                        frame.CameraUp,
                        ActorHeight * (index == 0 ? 0.76f : 0.70f),
                        ActorHeight * (index == 0 ? 0.60f : 0.58f),
                        index == 0 ? -13f : 17f,
                        cover,
                        BlueFireCrop(index + 1),
                        index == 1,
                        false);
                }

                for (var index = 0; index < 3; index++)
                {
                    var accent = index == 0
                        ? Color.Lerp(ArcaneIndigo, AuroraViolet, 0.72f)
                        : index == 1
                            ? Color.Lerp(MysticJade, MoonCyan, 0.52f)
                            : Color.Lerp(PaleGold, JadeWhite, 0.34f);
                    accent.a = contact * (index == 2 ? 0.16f : 0.24f);
                    iceFlameAssetBatch?.AddQuad(
                        ground
                            + frame.CameraRight * (ActorHeight * (index - 1f) * 0.13f)
                            + frame.CameraUp * (ActorHeight * (0.28f + index * 0.24f))
                            - frame.CameraForward * (ActorHeight * (0.132f + index * 0.005f)),
                        frame.CameraRight,
                        frame.CameraUp,
                        ActorHeight * (0.32f + index * 0.06f),
                        ActorHeight * (0.40f + index * 0.08f),
                        index == 0 ? -24f : index == 1 ? 17f : 31f,
                        accent,
                        FireAtlasCrop(index),
                        index == 1,
                        index == 2);
                }
            }

            // Beat 2: the compressed knot springs into a broad commercial
            // impact. Six organic blue-fire masses hide the actor while three
            // compact chromatic knots tear the perimeter.  They deliberately
            // reuse the irregular flame volume instead of a ribbon atlas, so
            // no long brush strip can appear at the review peak.
            if (peakBody > 0.002f)
            {
                const int peakMasses = 6;
                for (var index = 0; index < peakMasses; index++)
                {
                    var normalized = (index + 0.40f) / peakMasses;
                    var orbit = phase * Mathf.Lerp(0.28f, 0.52f, normalized) + index * 2.03f;
                    var radial = ActorHeight * Mathf.Lerp(0.08f, 0.36f, normalized) * expansion;
                    var point = ground
                        + frame.CameraRight * (Mathf.Sin(orbit) * radial)
                        + frame.CameraUp * (ActorHeight * Mathf.Lerp(0.18f, 1.18f, normalized))
                        - frame.CameraForward * (ActorHeight * (0.086f + index * 0.008f));
                    var color = ImpactAssetColor(index);
                    color.a = peakBody * Mathf.Lerp(0.56f, 0.72f, normalized);
                    blueFireAssetBatch?.AddQuad(
                        point,
                        frame.CameraRight,
                        frame.CameraUp,
                        ActorHeight * Mathf.Lerp(0.50f, 0.92f, normalized) * Mathf.Lerp(0.76f, 1f, expansion),
                        ActorHeight * Mathf.Lerp(0.34f, 0.58f, normalized),
                        Mathf.Sin(orbit) * 16f,
                        color,
                        BlueFireCrop(index),
                        (index & 1) != 0,
                        index == 3);
                }

                // Dense front knots bridge the organic holes in the source
                // texture exactly during the hit peak. The actor remains in
                // the scene, but the storm truly engulfs it rather than
                // reading as a transparent overlay.
                for (var index = 0; index < 4; index++)
                {
                    Color occlusionColor;
                    switch (index)
                    {
                        case 0: occlusionColor = Color.Lerp(DeepIce, MysticJade, 0.62f); break;
                        case 1: occlusionColor = Color.Lerp(ArcaneIndigo, MoonCyan, 0.40f); break;
                        case 2: occlusionColor = Color.Lerp(MysticJade, Frost, 0.38f); break;
                        default: occlusionColor = Color.Lerp(AuroraViolet, IceBlue, 0.56f); break;
                    }
                    occlusionColor.a = peakBody * 0.98f;
                    blueFireAssetBatch?.AddQuad(
                        ground
                            + frame.CameraRight * (ActorHeight * new[] { -0.10f, 0.08f, -0.06f, 0.10f }[index])
                            + frame.CameraUp * (ActorHeight * new[] { 0.22f, 0.52f, 0.82f, 1.08f }[index])
                            - frame.CameraForward * (ActorHeight * (0.218f + index * 0.007f)),
                        frame.CameraRight,
                        frame.CameraUp,
                        ActorHeight * new[] { 1.02f, 1.06f, 0.98f, 0.82f }[index],
                        ActorHeight * new[] { 0.68f, 0.72f, 0.70f, 0.60f }[index],
                        new[] { -14f, 17f, -21f, 12f }[index],
                        occlusionColor,
                        BlueFireCrop(index + 1),
                        (index & 1) != 0,
                        (index & 2) != 0);
                }

                const int chromaticKnots = 3;
                for (var index = 0; index < chromaticKnots; index++)
                {
                    var normalized = (index + 0.46f) / chromaticKnots;
                    var side = index % 2 == 0 ? -1f : 1f;
                    var orbit = -phase * Mathf.Lerp(0.22f, 0.46f, normalized) + index * 1.41f;
                    Color accent;
                    switch (index)
                    {
                        case 0: accent = Color.Lerp(ArcaneIndigo, AuroraViolet, 0.82f); break;
                        case 1: accent = Color.Lerp(AuroraRose, MoonCyan, 0.26f); break;
                        default: accent = Color.Lerp(PaleGold, JadeWhite, 0.32f); break;
                    }
                    accent.a = peakBody * (index == 2
                        ? Mathf.Lerp(0.18f, 0.25f, expansion)
                        : Mathf.Lerp(0.24f, 0.34f, expansion));
                    blueFireAssetBatch?.AddQuad(
                        ground
                            + frame.CameraRight * (ActorHeight * side
                                * Mathf.Lerp(0.12f, 0.40f, normalized)
                                * Mathf.Lerp(0.80f, 1f, expansion))
                            + frame.CameraUp * (ActorHeight * Mathf.Lerp(0.12f, 1.26f, normalized))
                            - frame.CameraForward * (ActorHeight * (0.148f + index * 0.004f)),
                        frame.CameraRight,
                        frame.CameraUp,
                        ActorHeight * Mathf.Lerp(0.34f, 0.48f, normalized),
                        ActorHeight * Mathf.Lerp(0.28f, 0.42f, normalized),
                        side * Mathf.Lerp(18f, 42f, normalized) + Mathf.Sin(orbit) * 8f,
                        accent,
                        BlueFireFragmentCrop(index + 31),
                        (index & 1) != 0,
                        (index & 2) != 0);
                }
            }

            // Beat 3: the peak does not simply dissolve.  It compresses for
            // two ticks, flashes white-hot, then the mature atlas material is
            // torn into independent radial lobes.  Each lobe has its own crop,
            // palette, spin and lifetime, so this reads as a volume bursting
            // apart instead of a circular card or a uniformly scaled sprite.
            var finalCompression = Ease(1.320f, 1.365f, time)
                * (1f - Ease(1.382f, 1.415f, time));
            var finalFlash = Ease(1.355f, 1.392f, time)
                * (1f - Ease(1.500f, 1.585f, time));
            var finalBreak = Ease(1.372f, 1.475f, time)
                * (1f - Ease(1.600f, SpellEnd, time));
            var finalExpansion = Ease(1.372f, 1.555f, time);
            var breakCenter = ground
                + frame.CameraUp * (ActorHeight * Mathf.Lerp(0.54f, 0.48f, finalExpansion))
                - frame.CameraForward * (ActorHeight * 0.166f);

            if (finalBreak > 0.002f)
            {
                const int volumeLobes = 7;
                for (var index = 0; index < volumeLobes; index++)
                {
                    var angle = index / (float)volumeLobes * Mathf.PI * 2f
                        + phase * (0.028f + (index % 3) * 0.006f)
                        + Mathf.Sin(index * 4.73f) * 0.13f;
                    var direction = (frame.CameraRight * Mathf.Cos(angle)
                        + frame.CameraUp * Mathf.Sin(angle)).normalized;
                    var tangent = (-frame.CameraRight * Mathf.Sin(angle)
                        + frame.CameraUp * Mathf.Cos(angle)).normalized;
                    var stagger = Mathf.Clamp01(finalExpansion * 1.22f - (index % 3) * 0.085f);
                    var radius = ActorHeight * Mathf.Lerp(0.055f, 1.10f, stagger)
                        * Mathf.Lerp(0.82f, 1.08f, Seed01(index + 1901));
                    var point = breakCenter
                        + direction * radius
                        + tangent * (Mathf.Sin(phase * 0.34f + index * 1.71f)
                            * ActorHeight * 0.045f * finalExpansion)
                        - frame.CameraForward * (ActorHeight * (0.010f * (index % 4)));
                    var color = ImpactAssetColor(index + 2);
                    if (index == 1 || index == 6)
                        color = Color.Lerp(AuroraViolet, AuroraRose, 0.28f);
                    else if (index == 4)
                        color = Color.Lerp(PaleGold, JadeWhite, 0.32f);
                    color.a = finalBreak * Mathf.Lerp(0.38f, 0.56f, Seed01(index + 2017));
                    blueFireAssetBatch?.AddQuad(
                        point,
                        frame.CameraRight,
                        frame.CameraUp,
                        ActorHeight * Mathf.Lerp(0.34f, 0.54f, Seed01(index + 2089)),
                        ActorHeight * Mathf.Lerp(0.34f, 0.56f, Seed01(index + 2143)),
                        angle * Mathf.Rad2Deg - 90f
                            + Mathf.Sin(phase * 0.22f + index) * 13f,
                        color,
                        BlueFireCrop(index + 5),
                        (index & 1) != 0,
                        (index & 2) != 0);
                }

                const int shearLobes = 5;
                for (var index = 0; index < shearLobes; index++)
                {
                    var angle = (index + 0.35f) / shearLobes * Mathf.PI * 2f
                        - phase * (0.020f + (index % 2) * 0.008f);
                    var direction = (frame.CameraRight * Mathf.Cos(angle)
                        + frame.CameraUp * Mathf.Sin(angle)).normalized;
                    var radius = ActorHeight * Mathf.Lerp(0.10f, 1.32f, finalExpansion)
                        * Mathf.Lerp(0.86f, 1.10f, Seed01(index + 2237));
                    Color shearColor;
                    switch (index % 4)
                    {
                        case 0: shearColor = Color.Lerp(ArcaneIndigo, AuroraViolet, 0.70f); break;
                        case 1: shearColor = Color.Lerp(MysticJade, MoonCyan, 0.44f); break;
                        case 2: shearColor = Color.Lerp(AuroraRose, Frost, 0.30f); break;
                        default: shearColor = Color.Lerp(PaleGold, WarmWhite, 0.24f); break;
                    }
                    shearColor.a = finalBreak * Mathf.Lerp(0.14f, 0.24f, Seed01(index + 2293));
                    blueFireAssetBatch?.AddQuad(
                        breakCenter
                            + direction * radius
                            - frame.CameraForward * (ActorHeight * (0.020f + index * 0.004f)),
                        frame.CameraRight,
                        frame.CameraUp,
                        ActorHeight * Mathf.Lerp(0.25f, 0.40f, Seed01(index + 2339)),
                        ActorHeight * Mathf.Lerp(0.23f, 0.38f, Seed01(index + 2381)),
                        angle * Mathf.Rad2Deg - 90f
                            + Mathf.Sin(index * 2.17f) * 11f,
                        shearColor,
                        BlueFireFragmentCrop(index + 19),
                        (index & 1) != 0,
                        (index & 2) != 0);
                }
            }

            var contactFlash = Ease(ContactTime, 0.806f, time)
                * (1f - Ease(0.865f, 0.930f, time));
            var peakFlash = Ease(0.980f, 1.120f, time)
                * (1f - Ease(1.280f, 1.410f, time));
            // Keep the radial burst texture as a brief contact glint only.
            // It must never become the late, coarse star that dominates the
            // breakup; the organic blue-fire lobes carry the final explosion.
            var flash = Mathf.Max(contactFlash * 0.32f, peakFlash * 0.34f);
            if (burstAssetMaterial != null)
            {
                burstAssetMaterial.SetFloat("_Phase", phase / (Mathf.PI * 2f) * 0.18f);
                burstAssetMaterial.SetFloat("_Opacity", flash);
                burstAssetMaterial.SetFloat("_Intensity", Mathf.Lerp(2.12f, 2.86f, flash));
            }
            if (flash > 0.002f)
            {
                for (var index = 0; index < 3; index++)
                {
                    var side = index - 1f;
                    var flashColor = index == 0
                        ? Color.Lerp(AuroraViolet, IceWhite, 0.40f)
                        : index == 1
                            ? Color.Lerp(JadeWhite, PaleGold, peakFlash * 0.24f)
                            : Color.Lerp(MoonCyan, JadeWhite, 0.34f);
                    flashColor.a = flash * (index == 1
                        ? Mathf.Lerp(0.42f, 0.32f, peakFlash)
                        : Mathf.Lerp(0.26f, 0.18f, peakFlash));
                    burstAssetBatch?.AddQuad(
                        ground
                            + frame.CameraRight * (ActorHeight * side * 0.20f * peakFlash)
                            + frame.CameraUp * (ActorHeight * (0.50f + index * 0.07f))
                            - frame.CameraForward * (ActorHeight * (0.150f + index * 0.004f)),
                        frame.CameraRight,
                        frame.CameraUp,
                        ActorHeight * Mathf.Lerp(0.62f, index == 1 ? 1.24f : 0.88f, peakFlash),
                        ActorHeight * Mathf.Lerp(0.58f, index == 1 ? 1.10f : 0.82f, peakFlash),
                        side * 38f + phase * Mathf.Rad2Deg * 0.018f,
                        flashColor,
                        new Rect(0f, 0f, 1f, 1f),
                        index == 2,
                        false);
                }

            }

            // The rebound begins as a dense white-hot frost-flame knot, then
            // the seven coloured lobes visibly detach from this shared core.
            // This creates the requested "bounce then burst" beat without a
            // regular geometric shockwave or star card.
            if (finalFlash > 0.002f)
            {
                for (var index = 0; index < 2; index++)
                {
                    var compressedScale = Mathf.Lerp(0.42f, 0.26f, finalCompression);
                    var breakScale = Mathf.Lerp(compressedScale, 0.72f + index * 0.12f, finalExpansion);
                    var hotColor = index == 0
                        ? Color.Lerp(IceWhite, WarmWhite, 0.10f)
                        : Color.Lerp(MoonCyan, AuroraViolet, 0.28f);
                    hotColor.a = finalFlash * (index == 0 ? 0.68f : 0.46f);
                    blueFireAssetBatch?.AddQuad(
                        breakCenter
                            + frame.CameraRight * (ActorHeight * (index == 0 ? -0.035f : 0.045f))
                            - frame.CameraForward * (ActorHeight * (0.018f + index * 0.006f)),
                        frame.CameraRight,
                        frame.CameraUp,
                        ActorHeight * breakScale,
                        ActorHeight * breakScale * (index == 0 ? 0.92f : 0.82f),
                        (index == 0 ? -11f : 17f) + phase * Mathf.Rad2Deg * 0.008f,
                        hotColor,
                        BlueFireFragmentCrop(index + 13),
                        index == 1,
                        false);
                }
            }

            windAssetBatch?.Commit();
            blueFireAssetBatch?.Commit();
            iceFlameAssetBatch?.Commit();
            burstAssetBatch?.Commit();
        }

        static Color ImpactAssetColor(int index)
        {
            switch (index % 5)
            {
                case 0: return Color.Lerp(DeepIce, ArcaneIndigo, 0.46f);
                case 1: return Color.Lerp(IceBlue, MoonCyan, 0.48f);
                case 2: return Color.Lerp(MysticJade, MoonCyan, 0.54f);
                case 3: return Color.Lerp(AuroraViolet, Frost, 0.38f);
                default: return Color.Lerp(JadeWhite, PaleGold, 0.18f);
            }
        }

        static float ContactShearAngle(int index)
        {
            switch (index & 3)
            {
                case 0: return -78f;
                case 1: return 74f;
                case 2: return -105f;
                default: return 103f;
            }
        }

        static void ResolveImpactAssetLobe(
            int index,
            out float offsetX,
            out float offsetY,
            out float widthH,
            out float heightH,
            out float rotation)
        {
            switch (index)
            {
                case 0:
                    offsetX = 0f; offsetY = 0.30f; widthH = 0.82f; heightH = 0.50f; rotation = 0f;
                    break;
                case 1:
                    offsetX = -0.12f; offsetY = 0.58f; widthH = 0.72f; heightH = 0.65f; rotation = 18f;
                    break;
                case 2:
                    offsetX = 0.13f; offsetY = 0.68f; widthH = 0.70f; heightH = 0.68f; rotation = -20f;
                    break;
                case 3:
                    offsetX = -0.18f; offsetY = 0.96f; widthH = 0.58f; heightH = 0.72f; rotation = 34f;
                    break;
                default:
                    offsetX = 0.17f; offsetY = 0.86f; widthH = 0.78f; heightH = 0.88f; rotation = -36f;
                    break;
            }
        }

        /// <summary>
        /// Commercial impact construction: one shared axis, two wide rotating
        /// sheets, a short-lived pressure shell and one near-side C-shaped
        /// wrap. Mist only supplies depth. The actor renderer remains enabled;
        /// engulfment is the union of phase-offset porous surfaces.
        /// </summary>
        void SampleImpactSurfacesV2(in SpellSample sample, in Frame frame, float phase)
        {
            var time = sample.AbsoluteTime;
            var ground = sample.Target - Vector3.up * GroundDrop;
            var profile = ResolveCommercialImpactProfile(time);
            var reveal = Ease(ContactTime, 0.817f, time);
            var fade = 1f - Ease(1.56f, SpellEnd, time);
            var visibility = reveal * fade;
            var frontVisibility = Ease(0.800f, 0.883f, time) * fade;
            var shellVisibility = Ease(ContactTime, 0.817f, time)
                * (1f - Ease(0.950f, 1.100f, time));
            var accent = ResolveAccentStrength(time)
                * (1f - Ease(1.42f, 1.50f, time));
            var vortexBase = ground
                + frame.CameraUp * (ActorHeight * (0.035f + profile.LiftH))
                - frame.CameraForward * (ActorHeight * 0.060f);

            if (groundMaterial != null)
            {
                groundMaterial.SetFloat("_Phase", phase / (Mathf.PI * 2f) * 0.31f);
                groundMaterial.SetFloat("_Opacity", visibility * 0.14f);
                groundMaterial.SetFloat("_AlphaCap", 0.14f);
                groundMaterial.SetFloat("_Accent", accent * 0.18f);
            }
            groundBatch?.Begin();
            if (groundBatch != null && visibility > 0.002f)
            {
                var groundFade = 1f - Ease(1.42f, 1.62f, time);
                var radius = ActorHeight * Mathf.Lerp(0.42f, 0.25f,
                    Ease(0.90f, 1.42f, time));
                var groundColor = ApplyLayerTint(Glacier, 0.01f);
                groundColor.a = visibility * groundFade * 0.12f;
                groundBatch.AddBrokenGroundArc(
                    ground + Vector3.up * (ActorHeight * 0.010f),
                    frame.CameraRight,
                    frame.GroundForward,
                    radius,
                    ActorHeight * 0.045f,
                    17,
                    78f * Mathf.Deg2Rad,
                    22f * Mathf.Deg2Rad + phase * 0.010f,
                    groundColor,
                    time,
                    Seed01(seed + 1801));
                var secondaryGround = ApplyLayerTint(ArcaneIndigo, 0.01f);
                secondaryGround.a = visibility * groundFade * 0.09f;
                groundBatch.AddBrokenGroundArc(
                    ground + Vector3.up * (ActorHeight * 0.013f),
                    frame.CameraRight,
                    frame.GroundForward,
                    radius * 0.82f,
                    ActorHeight * 0.032f,
                    15,
                    64f * Mathf.Deg2Rad,
                    181f * Mathf.Deg2Rad - phase * 0.008f,
                    secondaryGround,
                    time,
                    Seed01(seed + 1867));
                groundBatch.AddIceCracks(
                    ground + Vector3.up * (ActorHeight * 0.011f),
                    frame.CameraRight,
                    frame.GroundForward,
                    ActorHeight,
                    time,
                    phase,
                    ApplyLayerTint(IceBlue, 0.01f));
            }
            groundBatch?.Commit();

            if (frontMaterial != null)
            {
                frontMaterial.SetFloat("_Phase", phase / (Mathf.PI * 2f) * 0.71f + 0.83f);
                frontMaterial.SetFloat("_Opacity", Mathf.Max(
                    shellVisibility * 0.58f,
                    frontVisibility * 0.52f));
                frontMaterial.SetFloat("_AlphaCap", 0.34f);
                frontMaterial.SetFloat("_Accent", accent * 0.72f);
            }
            if (frontMistMaterial != null)
            {
                frontMistMaterial.SetFloat("_Phase", phase / (Mathf.PI * 2f) * 0.53f + 0.23f);
                frontMistMaterial.SetFloat("_Opacity", frontVisibility * 0.62f);
                frontMistMaterial.SetFloat("_AlphaCap", 0.24f);
                frontMistMaterial.SetFloat("_Accent", accent * 0.30f);
            }
            if (frontGlowMistMaterial != null)
            {
                frontGlowMistMaterial.SetFloat("_Phase", phase / (Mathf.PI * 2f) * 0.67f + 0.61f);
                frontGlowMistMaterial.SetFloat("_Opacity", frontVisibility * 0.34f);
                frontGlowMistMaterial.SetFloat("_AlphaCap", 0.16f);
                frontGlowMistMaterial.SetFloat("_Accent", accent * 0.44f);
            }
            if (impactCoreMistMaterial != null)
            {
                impactCoreMistMaterial.SetFloat("_Phase", phase / (Mathf.PI * 2f) * 0.82f + 0.47f);
                impactCoreMistMaterial.SetFloat("_Opacity", shellVisibility * 0.54f);
                impactCoreMistMaterial.SetFloat("_AlphaCap", 0.26f);
                impactCoreMistMaterial.SetFloat("_Accent", accent * 0.52f);
            }
            frontBatch?.Begin();
            if (frontBatch != null && shellVisibility > 0.002f)
            {
                var burstScale = ResolveImpactBurstScale(time);
                var shellRoot = ApplyLayerTint(DeepIce, 0.01f);
                var shellTip = ApplyLayerTint(MoonCyan, 0.01f);
                shellRoot.a = shellVisibility * 0.18f;
                shellTip.a = shellVisibility * 0.22f;
                frontBatch.AddImpactShell(
                    ground + frame.CameraUp * (ActorHeight * 0.43f)
                        - frame.CameraForward * (ActorHeight * 0.070f),
                    frame.CameraRight,
                    frame.CameraUp,
                    frame.CameraForward,
                    ActorHeight * 0.40f * burstScale.x,
                    ActorHeight * 0.31f * burstScale.y,
                    ActorHeight * 0.34f * burstScale.x,
                    250f * Mathf.Deg2Rad,
                    phase * 0.08f + 0.64f,
                    12,
                    10,
                    shellRoot,
                    shellTip,
                    time,
                    Seed01(seed + 2111));

                var innerShellRoot = ApplyLayerTint(AuroraViolet, 0.01f);
                var innerShellTip = ApplyLayerTint(Color.Lerp(Frost, PaleGold, 0.18f), 0.01f);
                innerShellRoot.a = shellVisibility * 0.14f;
                innerShellTip.a = shellVisibility * 0.18f;
                frontBatch.AddImpactShell(
                    ground + frame.CameraUp * (ActorHeight * 0.46f)
                        - frame.CameraForward * (ActorHeight * 0.082f),
                    frame.CameraRight,
                    frame.CameraUp,
                    frame.CameraForward,
                    ActorHeight * 0.31f * burstScale.x,
                    ActorHeight * 0.38f * burstScale.y,
                    ActorHeight * 0.29f * burstScale.x,
                    224f * Mathf.Deg2Rad,
                    phase * -0.06f + 3.02f,
                    11,
                    9,
                    innerShellRoot,
                    innerShellTip,
                    time,
                    Seed01(seed + 2147));
            }
            if (frontBatch != null && frontVisibility > 0.002f)
            {
                // The old near-side VortexSheet was still a narrow helix and
                // visually reintroduced the thick regular stripe after the
                // core had been rebuilt.  A broad incomplete mantle now puts
                // irregular storm mass in front of the actor without drawing
                // a cable around it.
                var frontHeight = ActorHeight * profile.HeightH * 0.90f;
                var frontRoot = ApplyLayerTint(AuroraViolet, 0.01f);
                var frontTip = ApplyLayerTint(Color.Lerp(Frost, PaleGold, 0.10f), 0.01f);
                frontRoot.a = frontVisibility * 0.24f;
                frontTip.a = frontVisibility * 0.30f;
                frontBatch.AddFunnelMantle(
                    vortexBase + frame.CameraUp * (frontHeight * 0.48f),
                    frame.CameraRight,
                    frame.CameraUp,
                    frame.CameraForward,
                    frontHeight,
                    ActorHeight * profile.CrownRadiusH * 0.92f,
                    4.74f,
                    -phase * 0.34f + 1.12f,
                    27,
                    17,
                    0.84f,
                    frontRoot,
                    frontTip,
                    time,
                    Seed01(seed + 2179));

                var iceCoreVisibility = Ease(ContactTime, 0.817f, time)
                    * (1f - Ease(0.883f, 0.920f, time));
                if (iceCoreVisibility > 0.002f)
                {
                    var iceCore = ApplyLayerTint(JadeWhite, 0.005f);
                    iceCore.a = iceCoreVisibility * 0.24f;
                    frontBatch.AddColdCoreLobe(
                        ground + frame.CameraUp * (ActorHeight * 0.48f)
                            - frame.CameraForward * (ActorHeight * 0.095f),
                        frame.CameraRight,
                        frame.CameraUp,
                        ActorHeight * 0.16f,
                        ActorHeight * 0.22f,
                        iceCore,
                        time,
                        Seed01(seed + 2237),
                        true,
                        -12f * Mathf.Deg2Rad);
                }
            }
            frontBatch?.Commit();

            if (frontVisibility > 0.002f)
            {
                var mistShape = new Shape(
                    ActorHeight * profile.HeightH * 0.92f,
                    ActorHeight * profile.CrownRadiusH * 0.88f,
                    profile.Turns,
                    1f);
                frontMistField?.Sample(
                    vortexBase,
                    Quaternion.identity,
                    mistShape,
                    phase + 0.83f,
                    frontVisibility * 0.72f,
                    frame.CameraForward,
                    time);
                var glowShape = new Shape(
                    mistShape.Length * 0.82f,
                    mistShape.Radius * 0.66f,
                    mistShape.Turns + 0.22f,
                    1f);
                frontGlowMistField?.Sample(
                    vortexBase + frame.CameraUp * (ActorHeight * 0.08f),
                    Quaternion.identity,
                    glowShape,
                    phase + 2.31f,
                    frontVisibility * 0.34f,
                    frame.CameraForward,
                    time + 0.093f);
            }
            if (shellVisibility > 0.002f)
            {
                var pressureShape = new Shape(
                    ActorHeight * 0.70f,
                    ActorHeight * 0.42f,
                    1.30f,
                    1f);
                impactCoreMistField?.Sample(
                    ground + frame.CameraUp * (ActorHeight * 0.10f),
                    Quaternion.identity,
                    pressureShape,
                    phase - 0.52f,
                    shellVisibility * 0.54f,
                    frame.CameraForward,
                    time + 0.047f);
            }

            // Contact ejects a separate, short-lived particle mass. It does
            // not replace the funnel; it supplies the requested outward pop
            // and late breakup around the still-readable shared axis.
            var particleBurstVisibility = Ease(ContactTime, 0.817f, time)
                * (1f - Ease(1.48f, 1.68f, time));
            impactBurstField?.Sample(
                ground + frame.CameraUp * (ActorHeight * 0.52f),
                frame.CameraRight,
                frame.CameraUp,
                frame.CameraForward,
                time,
                ActorHeight,
                particleBurstVisibility);

            crystalField?.Sample(
                ground + frame.CameraUp * (ActorHeight * 0.12f),
                frame.CameraRight,
                frame.CameraUp,
                frame.CameraForward,
                time,
                ActorHeight);
        }

        void SampleImpactSurfaces(in SpellSample sample, in Frame frame, float phase)
        {
            var time = sample.AbsoluteTime;
            var ground = sample.Target - Vector3.up * GroundDrop;
            var reveal = Ease(ContactTime, 0.818f, time);
            var fade = 1f - Ease(1.58f, SpellEnd, time);
            var visibility = reveal * fade;
            var accent = ResolveAccentStrength(time);

            // The contact response is built from broad, broken pressure
            // leaves. There are no circles, runes, concentric arcs or lines.
            var groundBurst = Ease(ContactTime, ContactTime + 0.045f, time)
                * (1f - Ease(1.16f, 1.46f, time));
            var groundOpen = Mathf.Lerp(0.12f, 1f,
                Ease(ContactTime, ContactTime + 0.085f, time));
            groundBatch?.Begin();
            if (groundBatch != null && groundBurst > 0.002f)
            {
                var groundAngles = new[] { 14f, 68f, 139f, 208f, 276f, 329f };
                var groundLengths = new[] { 0.92f, 0.58f, 0.76f, 0.64f, 0.86f, 0.70f };
                var groundWidths = new[] { 0.28f, 0.22f, 0.30f, 0.20f, 0.27f, 0.23f };
                for (var index = 0; index < groundAngles.Length; index++)
                {
                    var angle = groundAngles[index] * Mathf.Deg2Rad;
                    var direction = (frame.CameraRight * Mathf.Cos(angle)
                        + frame.GroundForward * Mathf.Sin(angle)).normalized;
                    var across = (-frame.CameraRight * Mathf.Sin(angle)
                        + frame.GroundForward * Mathf.Cos(angle)).normalized;
                    var root = ApplyLayerTint(
                        index % 3 == 0
                            ? Color.Lerp(MysticJade, Frost, 0.38f)
                            : index % 3 == 1
                                ? Color.Lerp(Glacier, IceWhite, 0.34f)
                                : Color.Lerp(AuroraViolet, IceBlue, 0.64f),
                        0.02f);
                    var tip = ApplyLayerTint(
                        index == 0 || index == 4
                            ? Color.Lerp(PaleGold, IceWhite, 0.42f)
                            : Color.Lerp(Frost, MoonCyan, 0.22f),
                        0.01f);
                    root.a = groundBurst * 0.62f;
                    tip.a = groundBurst * 0.48f;
                    groundBatch.AddOrganicBurstPetal(
                        ground + Vector3.up * (ActorHeight * (0.010f + index * 0.002f)),
                        direction,
                        across,
                        ActorHeight * groundLengths[index] * groundOpen,
                        ActorHeight * groundWidths[index] * groundOpen,
                        ActorHeight * new[] { 0.08f, -0.05f, 0.06f, -0.07f, 0.09f, -0.04f }[index],
                        18,
                        root,
                        tip,
                        time,
                        Seed01(seed + 2401 + index * 47));
                }
            }
            groundBatch?.Commit();

            if (frontMaterial != null)
            {
                frontMaterial.SetFloat("_Phase", phase / (Mathf.PI * 2f) * 0.73f);
                frontMaterial.SetFloat("_Opacity", Mathf.Min(0.995f,
                    visibility * Mathf.Lerp(0.94f, 1f, accent)));
                frontMaterial.SetFloat("_Accent", accent * 0.78f);
            }
            if (frontMistMaterial != null)
            {
                frontMistMaterial.SetFloat("_Phase", phase / (Mathf.PI * 2f) * 0.51f);
                frontMistMaterial.SetFloat("_Opacity", visibility * 0.68f);
                frontMistMaterial.SetFloat("_Accent", accent * 0.42f);
            }

            // Three review frames after contact, the pressure jumps past its
            // resting size and settles. This is the requested visible "pop",
            // not a smooth UI scale tween.
            var stand = Ease(0.835f, 1.055f, time);
            var popOpen = Ease(ContactTime, ContactTime + 0.050f, time);
            var popSettle = Ease(ContactTime + 0.050f, ContactTime + 0.205f, time);
            var popScale = Mathf.Lerp(0.16f, 1.52f, popOpen);
            popScale = Mathf.Lerp(popScale, 1f, popSettle);
            var height = ActorHeight * Mathf.Lerp(0.90f, 1.62f, stand);
            var topRadius = ActorHeight * Mathf.Lerp(0.88f, 0.62f, stand);
            var vortexBase = ground + frame.CameraUp * (ActorHeight * 0.035f)
                - frame.CameraForward * (ActorHeight * 0.070f);

            var mistShape = new Shape(
                height,
                topRadius * 1.08f,
                2.04f,
                1f);
            frontMistField?.Sample(
                vortexBase,
                Quaternion.identity,
                mistShape,
                phase + 0.91f,
                visibility * 0.94f,
                frame.CameraForward,
                time);

            frontBatch?.Begin();
            if (frontBatch != null && visibility > 0.002f)
            {
                var columnVisibility = visibility * Ease(0.845f, 1.02f, time);
                var burstVisibility = visibility
                    * Ease(ContactTime, ContactTime + 0.032f, time)
                    * (1f - Ease(0.96f, 1.12f, time));

                // Eight independently eroded frost-plasma lobes overlap into
                // one coherent turbulent body. No single quad can reveal its
                // rectangular bounds, and the union is dense enough to engulf
                // the target without disabling the actor renderer.
                var bodyCenters = new[]
                {
                    new Vector2(-0.12f, 0.29f),
                    new Vector2(0.11f, 0.38f),
                    new Vector2(-0.23f, 0.62f),
                    new Vector2(0.24f, 0.72f),
                    new Vector2(-0.34f, 0.99f),
                    new Vector2(0.33f, 1.08f),
                    new Vector2(-0.10f, 1.30f),
                    new Vector2(0.15f, 1.43f)
                };
                var bodyWidths = new[] { 0.48f, 0.43f, 0.62f, 0.58f, 0.72f, 0.68f, 0.62f, 0.52f };
                var bodyHeights = new[] { 0.58f, 0.50f, 0.72f, 0.66f, 0.76f, 0.70f, 0.64f, 0.52f };
                var bodyTilts = new[] { -20f, 24f, -31f, 29f, -38f, 36f, -18f, 21f };
                var bodyPalette = new[]
                {
                    Color.Lerp(DeepIce, MysticJade, 0.62f),
                    Color.Lerp(ArcaneIndigo, Glacier, 0.58f),
                    Color.Lerp(MysticJade, Frost, 0.42f),
                    Color.Lerp(Glacier, MoonCyan, 0.54f),
                    Color.Lerp(AuroraViolet, IceBlue, 0.68f),
                    Color.Lerp(MysticJade, IceWhite, 0.38f),
                    Color.Lerp(Glacier, Frost, 0.58f),
                    Color.Lerp(AuroraViolet, MoonCyan, 0.72f)
                };
                for (var index = 0; index < bodyCenters.Length; index++)
                {
                    var spread = Mathf.Lerp(popScale, 1f, stand);
                    var centerX = bodyCenters[index].x * Mathf.Lerp(1.20f, 1f, stand) * spread;
                    var centerY = Mathf.Lerp(
                        0.54f + bodyCenters[index].x * 0.18f,
                        bodyCenters[index].y,
                        stand);
                    var bodyColor = ApplyLayerTint(bodyPalette[index], 0.015f);
                    bodyColor.a = columnVisibility * new[]
                        { 0.88f, 0.84f, 0.82f, 0.86f, 0.78f, 0.82f, 0.74f, 0.70f }[index];
                    frontBatch.AddColdCoreLobe(
                        vortexBase
                            + frame.CameraRight * (ActorHeight * centerX)
                            + frame.CameraUp * (ActorHeight * centerY)
                            - frame.CameraForward * (ActorHeight * (0.030f + index * 0.006f)),
                        frame.CameraRight,
                        frame.CameraUp,
                        ActorHeight * bodyWidths[index] * Mathf.Lerp(popScale, 1f, stand),
                        ActorHeight * bodyHeights[index] * Mathf.Lerp(popScale, 1f, stand),
                        bodyColor,
                        time,
                        Seed01(seed + 2603 + index * 61),
                        false,
                        bodyTilts[index] * Mathf.Deg2Rad,
                        index == 0 || index == 1);
                }

                // Four broad curved surfaces bind the cloud masses into a
                // rotating funnel silhouette. They are deliberately wide,
                // torn and phase-offset; none can read as a tube or wire.
                var sweepAngles = new[] { 24f, 154f, 48f, 132f };
                var sweepRootsX = new[] { -0.42f, 0.38f, -0.31f, 0.29f };
                var sweepRootsY = new[] { 0.14f, 0.26f, 0.52f, 0.70f };
                var sweepLengths = new[] { 1.42f, 1.30f, 1.18f, 1.08f };
                var sweepWidths = new[] { 0.48f, 0.44f, 0.40f, 0.36f };
                for (var index = 0; index < sweepAngles.Length; index++)
                {
                    var angle = (sweepAngles[index]
                        + Mathf.Sin(phase * 0.35f + index * 1.7f) * 7f) * Mathf.Deg2Rad;
                    var direction = (frame.CameraRight * Mathf.Cos(angle)
                        + frame.CameraUp * Mathf.Sin(angle)).normalized;
                    var across = (-frame.CameraRight * Mathf.Sin(angle)
                        + frame.CameraUp * Mathf.Cos(angle)).normalized;
                    var root = ApplyLayerTint(
                        index == 0
                            ? Color.Lerp(DeepIce, MysticJade, 0.66f)
                            : index == 1
                                ? Color.Lerp(AuroraViolet, IceBlue, 0.64f)
                                : index == 2
                                    ? Color.Lerp(Glacier, Frost, 0.46f)
                                    : Color.Lerp(MysticJade, MoonCyan, 0.54f),
                        0.01f);
                    var tip = ApplyLayerTint(
                        index == 1
                            ? Color.Lerp(AuroraViolet, Frost, 0.38f)
                            : index == 2
                                ? Color.Lerp(PaleGold, IceWhite, 0.60f)
                                : Color.Lerp(Frost, IceWhite, 0.52f),
                        0.005f);
                    root.a = columnVisibility * new[] { 0.88f, 0.78f, 0.84f, 0.76f }[index];
                    tip.a = root.a * 0.88f;
                    frontBatch.AddOrganicBurstPetal(
                        vortexBase
                            + frame.CameraRight * (ActorHeight * sweepRootsX[index])
                            + frame.CameraUp * (ActorHeight * sweepRootsY[index])
                            - frame.CameraForward * (ActorHeight * (0.070f + index * 0.008f)),
                        direction,
                        across,
                        ActorHeight * sweepLengths[index] * Mathf.Lerp(popScale, 1f, stand),
                        ActorHeight * sweepWidths[index] * Mathf.Lerp(popScale, 1f, stand),
                        ActorHeight * new[] { 0.32f, -0.28f, 0.25f, -0.22f }[index],
                        28,
                        root,
                        tip,
                        time,
                        Seed01(seed + 3119 + index * 71),
                        false,
                        false,
                        true);
                }

                // The contact beat throws large asymmetric color masses out
                // from the actor before they curl upward. Wide silhouettes,
                // unequal timing and displaced roots create an explosion,
                // never a regular starburst.
                if (burstVisibility > 0.002f)
                {
                    var burstAngles = new[] { -22f, 18f, 61f, 112f, 158f, 214f, 286f };
                    var burstLengths = new[] { 1.12f, 0.86f, 0.74f, 0.92f, 1.04f, 0.78f, 0.96f };
                    var burstWidths = new[] { 0.46f, 0.38f, 0.34f, 0.41f, 0.48f, 0.36f, 0.40f };
                    var burstPalette = new[]
                    {
                        Color.Lerp(MysticJade, Frost, 0.45f),
                        Color.Lerp(PaleGold, IceWhite, 0.48f),
                        Color.Lerp(AuroraViolet, IceBlue, 0.56f),
                        Color.Lerp(Glacier, IceWhite, 0.54f),
                        Color.Lerp(AuroraViolet, Frost, 0.42f),
                        Color.Lerp(MysticJade, MoonCyan, 0.62f),
                        Color.Lerp(PaleGold, Frost, 0.36f)
                    };
                    for (var index = 0; index < burstAngles.Length; index++)
                    {
                        var angle = burstAngles[index] * Mathf.Deg2Rad;
                        var direction = (frame.CameraRight * Mathf.Cos(angle)
                            + frame.CameraUp * Mathf.Sin(angle)).normalized;
                        var across = (-frame.CameraRight * Mathf.Sin(angle)
                            + frame.CameraUp * Mathf.Cos(angle)).normalized;
                        var root = ApplyLayerTint(bodyPalette[index], 0.01f);
                        var tip = ApplyLayerTint(burstPalette[index], 0.005f);
                        root.a = burstVisibility * 0.86f;
                        tip.a = burstVisibility * 0.92f;
                        frontBatch.AddOrganicBurstPetal(
                            vortexBase
                                + frame.CameraRight * (ActorHeight * new[]
                                    { -0.31f, -0.18f, 0.04f, 0.16f, 0.28f, -0.06f, -0.24f }[index])
                                + frame.CameraUp * (ActorHeight * new[]
                                    { 0.48f, 0.28f, 0.34f, 0.46f, 0.62f, 0.68f, 0.82f }[index])
                                - frame.CameraForward * (ActorHeight * (0.090f + index * 0.006f)),
                            direction,
                            across,
                            ActorHeight * burstLengths[index] * popScale,
                            ActorHeight * burstWidths[index] * popScale,
                            ActorHeight * new[] { 0.18f, -0.13f, 0.12f, -0.16f, 0.19f, -0.10f, 0.14f }[index],
                            24,
                            root,
                            tip,
                            time,
                            Seed01(seed + 3613 + index * 53),
                            index == 1 || index == 3,
                            false,
                            index != 1 && index != 3);
                    }
                }

                // Compact off-centre value focus. It is intentionally short
                // and irregular, so it cannot become the rejected vertical
                // line, portal or geometric ring.
                var corePulse = 0.94f + Mathf.Sin(time * 17.0f + seed * 0.013f) * 0.06f;
                var coreColor = ApplyLayerTint(Color.Lerp(MoonCyan, IceWhite, 0.78f), 0.005f);
                coreColor.a = visibility * 0.98f;
                frontBatch.AddColdCoreLobe(
                    vortexBase
                        - frame.CameraRight * (ActorHeight * 0.055f)
                        + frame.CameraUp * (ActorHeight * 0.64f)
                        - frame.CameraForward * (ActorHeight * 0.045f),
                    frame.CameraRight,
                    frame.CameraUp,
                    ActorHeight * Mathf.Lerp(0.46f, 0.31f, stand) * corePulse,
                    ActorHeight * Mathf.Lerp(0.42f, 0.36f, stand) * corePulse,
                    coreColor,
                    time,
                    Seed01(seed + 2711),
                    false,
                    -17f * Mathf.Deg2Rad);

                var hotColor = ApplyLayerTint(Color.Lerp(IceWhite, WarmWhite, 0.30f), 0.002f);
                hotColor.a = visibility * Mathf.Lerp(0.98f, 0.78f, stand);
                frontBatch.AddColdCoreLobe(
                    vortexBase
                        + frame.CameraRight * (ActorHeight * 0.025f)
                        + frame.CameraUp * (ActorHeight * 0.66f)
                        - frame.CameraForward * (ActorHeight * 0.058f),
                    frame.CameraRight,
                    frame.CameraUp,
                    ActorHeight * Mathf.Lerp(0.24f, 0.16f, stand) * corePulse,
                    ActorHeight * Mathf.Lerp(0.25f, 0.20f, stand) * corePulse,
                    hotColor,
                    time,
                    Seed01(seed + 2729),
                    true,
                    21f * Mathf.Deg2Rad);
            }
            frontBatch?.Commit();

            // The mesh body supplies the readable tornado silhouette; this
            // independent deterministic particle wave supplies the contact
            // snap and the visibly travelling breakup after the hit.
            var particleBurstVisibility = Ease(ContactTime, 0.817f, time)
                * (1f - Ease(1.48f, 1.68f, time));
            impactBurstField?.Sample(
                ground + frame.CameraUp * (ActorHeight * 0.52f),
                frame.CameraRight,
                frame.CameraUp,
                frame.CameraForward,
                time,
                ActorHeight,
                particleBurstVisibility);

            crystalField?.Sample(
                ground + Vector3.up * (ActorHeight * 0.18f),
                frame.CameraRight,
                frame.CameraUp,
                frame.CameraForward,
                time,
                ActorHeight);
        }

        // Kept temporarily as an internal comparison specimen while the new
        // commercial sheet construction is being tuned. It is never sampled.
        void SampleLegacyImpactSurfaces(in SpellSample sample, in Frame frame, float phase)
        {
            var time = sample.AbsoluteTime;
            var ground = sample.Target - Vector3.up * GroundDrop;
            var groundReveal = Ease(ContactTime, 0.835f, time);
            var groundFade = 1f - Ease(1.48f, SpellEnd, time);
            var groundVisibility = groundReveal * groundFade;

            if (groundMaterial != null)
            {
                groundMaterial.SetFloat("_Phase", phase / (Mathf.PI * 2f) * 0.42f);
                groundMaterial.SetFloat("_Opacity", groundVisibility);
                groundMaterial.SetFloat("_Accent", ResolveAccentStrength(time) * 0.56f);
            }
            groundBatch?.Begin();
            if (groundBatch != null && groundVisibility > 0.002f)
            {
                var inwardPull = Ease(0.835f, 1.02f, time);
                var pullRadius = Mathf.Lerp(0.56f, 0.27f, inwardPull) * ActorHeight;
                var pullWidth = Mathf.Lerp(0.062f, 0.108f, Ease(0.835f, 1.02f, time)) * ActorHeight;
                var groundColor = ApplyLayerTint(Color.Lerp(IceBlue, IceWhite, 0.48f), 0.12f);
                groundColor.a = 0.58f;
                groundBatch.AddBrokenGroundArc(
                    ground + Vector3.up * (ActorHeight * 0.009f),
                    frame.CameraRight,
                    frame.GroundForward,
                    pullRadius,
                    pullWidth,
                    18,
                    82f * Mathf.Deg2Rad,
                    21f * Mathf.Deg2Rad + phase * 0.018f,
                    groundColor,
                    time,
                    Seed01(seed + 83));
                var secondaryGround = ApplyLayerTint(Color.Lerp(Glacier, Frost, 0.42f), 0.10f);
                secondaryGround.a = 0.46f;
                groundBatch.AddBrokenGroundArc(
                    ground + Vector3.up * (ActorHeight * 0.013f),
                    frame.CameraRight,
                    frame.GroundForward,
                    pullRadius * 0.86f,
                    pullWidth * 0.78f,
                    16,
                    67f * Mathf.Deg2Rad,
                    143f * Mathf.Deg2Rad - phase * 0.014f,
                    secondaryGround,
                    time,
                    Seed01(seed + 149));
                var tertiaryGround = ApplyLayerTint(Color.Lerp(DeepIce, IceBlue, 0.78f), 0.08f);
                tertiaryGround.a = 0.36f;
                groundBatch.AddBrokenGroundArc(
                    ground + Vector3.up * (ActorHeight * 0.016f),
                    frame.CameraRight,
                    frame.GroundForward,
                    pullRadius * 1.08f,
                    pullWidth * 0.62f,
                    19,
                    94f * Mathf.Deg2Rad,
                    267f * Mathf.Deg2Rad + phase * 0.011f,
                    tertiaryGround,
                    time,
                    Seed01(seed + 197));

                // Five low, non-symmetric pressure petals make the hit feel
                // planted. They remain open shapes; no circular shock ring is
                // introduced.
                var groundBurstVisibility = Ease(0.805f, 0.855f, time)
                    * (1f - Ease(1.24f, 1.46f, time));
                var groundBurstOpen = Ease(0.805f, 0.92f, time);
                var groundAngles = new[] { 18f, 112f, 171f, 252f, 311f };
                var groundLengths = new[] { 0.56f, 0.39f, 0.48f, 0.34f, 0.51f };
                var groundWidths = new[] { 0.16f, 0.10f, 0.13f, 0.09f, 0.12f };
                for (var index = 0; index < groundAngles.Length; index++)
                {
                    var angle = groundAngles[index] * Mathf.Deg2Rad;
                    var direction = (frame.CameraRight * Mathf.Cos(angle)
                        + frame.GroundForward * Mathf.Sin(angle)).normalized;
                    var across = (-frame.CameraRight * Mathf.Sin(angle)
                        + frame.GroundForward * Mathf.Cos(angle)).normalized;
                    var rootColor = ApplyLayerTint(Color.Lerp(Frost, IceWhite, 0.34f), 0.06f);
                    var tipColor = ApplyLayerTint(Color.Lerp(Glacier, IceBlue, 0.52f), 0.08f);
                    rootColor.a = groundBurstVisibility * Mathf.Lerp(0.48f, 0.31f, index / 4f);
                    tipColor.a = rootColor.a * 0.78f;
                    groundBatch.AddOrganicBurstPetal(
                        ground + Vector3.up * (ActorHeight * (0.014f + index * 0.003f)),
                        direction,
                        across,
                        ActorHeight * groundLengths[index] * groundBurstOpen,
                        ActorHeight * groundWidths[index] * groundBurstOpen,
                        ActorHeight * Mathf.Lerp(-0.030f, 0.045f, Seed01(seed + index * 37)),
                        11,
                        rootColor,
                        tipColor,
                        time,
                        Seed01(seed + 401 + index * 53));
                }
                groundBatch.AddIceCracks(
                    ground + Vector3.up * (ActorHeight * 0.011f),
                    frame.CameraRight,
                    frame.GroundForward,
                    ActorHeight,
                    time,
                    phase,
                    ApplyLayerTint(IceBlue, 0.10f));
            }
            groundBatch?.Commit();

            // This is the only Always pass. It exists for less than half a
            // second and never changes the target actor renderer or sorting.
            // The engulfing veil must arrive with contact. A delayed veil made
            // the first impact read as an isolated star before the tornado.
            var frontVisibility = Ease(ContactTime, 0.82f, time)
                * (1f - Ease(1.68f, SpellEnd, time));
            var coldCoreVisibility = time <= 0.818f
                ? Ease(ContactTime, 0.818f, time)
                : 1f - Ease(0.818f, 0.905f, time);
            var burstVisibility = Ease(ContactTime, 0.805f, time)
                * (1f - Ease(0.98f, 1.10f, time));
            // A brief scale overshoot creates a readable "pop": pressure is
            // compressed at contact, jumps past its final size in three
            // frames, then settles into the sustained tornado volume.
            var popExpand = Ease(ContactTime, ContactTime + 0.050f, time);
            var popSettle = Ease(ContactTime + 0.050f, ContactTime + 0.180f, time);
            var popOvershoot = Mathf.Lerp(0.16f, 1.46f, popExpand);
            popOvershoot = Mathf.Lerp(popOvershoot, 1f, popSettle);
            var burstOpen = Ease(ContactTime, ContactTime + 0.050f, time) * popOvershoot;
            var burstExpansion = Mathf.Lerp(0.74f, 1f, burstOpen);
            var burstCurl = Ease(0.90f, 1.08f, time);
            var impactPopVisibility = Ease(ContactTime, ContactTime + 0.018f, time)
                * (1f - Ease(ContactTime + 0.095f, ContactTime + 0.180f, time));
            var glintVisibility = ResolveAccentStrength(time);
            if (frontMaterial != null)
            {
                frontMaterial.SetFloat("_Phase", phase / (Mathf.PI * 2f) * 0.76f);
                frontMaterial.SetFloat("_Opacity", Mathf.Min(0.995f, Mathf.Max(
                    Mathf.Max(frontVisibility * 0.96f, coldCoreVisibility),
                    Mathf.Max(burstVisibility * 0.98f, glintVisibility * 0.96f))));
                frontMaterial.SetFloat("_Accent", glintVisibility * 0.88f);
            }
            if (frontMistMaterial != null)
            {
                frontMistMaterial.SetFloat("_Phase", phase / (Mathf.PI * 2f) * 0.58f);
                frontMistMaterial.SetFloat("_Opacity", Mathf.Min(0.42f, frontVisibility * 0.44f));
                frontMistMaterial.SetFloat("_Accent", glintVisibility * 0.72f);
            }

            var impactShape = new Shape(
                ActorHeight * Mathf.Lerp(0.82f, 1.62f, Ease(ContactTime, 1.18f, time)),
                ActorHeight * Mathf.Lerp(0.24f, 0.66f, Ease(ContactTime, 1.20f, time)),
                2.10f,
                1f);
            frontMistField?.Sample(
                ground + Vector3.up * (ActorHeight * 0.04f),
                Quaternion.identity,
                impactShape,
                phase + 1.23f,
                frontVisibility * 0.40f,
                frame.CameraForward,
                time);
            frontBatch?.Begin();
            if (frontBatch != null && frontVisibility > 0.002f)
            {
                var funnelBase = ground + Vector3.up * (ActorHeight * 0.045f)
                    - frame.CameraForward * 0.082f;
                var funnelFade = 1f - Ease(1.66f, SpellEnd, time);
                var cinematicOpen = Ease(0.88f, 1.18f, time);
                var cinematicWidth = Mathf.Lerp(1f, 1.46f, cinematicOpen);
                var cinematicHeight = Mathf.Lerp(1f, 1.14f, cinematicOpen);
                // Contact is a single, readable ice detonation. The large
                // calligraphic tornado rises a beat later instead of tangling
                // with the impact silhouette in the same frame.
                var funnelVisibility = frontVisibility
                    * Ease(0.88f, 1.04f, time)
                    * funnelFade;

                // A narrow deep-cyan bone gives the saturated storm depth.
                // It remains subordinate to the glacier shell and hot core.
                var funnelBody = ApplyLayerTint(
                    Color.Lerp(DeepIce, Glacier, 0.45f), 0.03f);
                funnelBody.a = funnelVisibility * 0.48f;
                frontBatch.AddEngulfVolume(
                    funnelBase + frame.CameraUp * (ActorHeight * 0.66f),
                    frame.CameraRight,
                    frame.CameraUp,
                    ActorHeight * 0.16f * cinematicWidth,
                    ActorHeight * 1.18f * cinematicHeight,
                    -2f * Mathf.Deg2Rad,
                    0.58f,
                    0.82f,
                    funnelBody,
                    time,
                    Seed01(seed + 1597));

                // Three offset dark-pressure lobes provide the opaque mass of
                // the storm without exposing a rectangular card. Their SDF
                // edges and independent rotations leave different holes, so
                // the union submerges the actor while every layer stays fluid.
                var volumeCenters = new[]
                {
                    new Vector2(-0.10f, 0.67f),
                    new Vector2(0.15f, 0.72f),
                    new Vector2(-0.02f, 0.43f)
                };
                var volumeWidths = new[] { 0.42f, 0.34f, 0.38f };
                var volumeHeights = new[] { 1.08f, 0.92f, 0.72f };
                var volumeTilts = new[] { -12f, 17f, -27f };
                for (var index = 0; index < volumeCenters.Length; index++)
                {
                    var volumeColor = ApplyLayerTint(
                        Color.Lerp(DeepIce, IceBlue,
                            new[] { 0.52f, 0.68f, 0.44f }[index]), 0.03f);
                    volumeColor.a = funnelVisibility * new[] { 0.62f, 0.56f, 0.50f }[index];
                    frontBatch.AddColdCoreLobe(
                        funnelBase
                            + frame.CameraRight * (ActorHeight * volumeCenters[index].x * cinematicWidth)
                            + frame.CameraUp * (ActorHeight * volumeCenters[index].y * cinematicHeight),
                        frame.CameraRight,
                        frame.CameraUp,
                        ActorHeight * volumeWidths[index] * cinematicWidth,
                        ActorHeight * volumeHeights[index] * cinematicHeight,
                        volumeColor,
                        time,
                        Seed01(seed + 1609 + index * 47),
                        false,
                        volumeTilts[index] * Mathf.Deg2Rad,
                        true);
                }

                // A compact upper-front pressure body closes the last gap
                // around the target's head and shoulders. It stays turbulent
                // and asymmetrical, so engulfment comes from storm volume
                // rather than hiding the renderer behind a flat overlay.
                var upperStormMass = ApplyLayerTint(
                    Color.Lerp(DeepIce, IceBlue, 0.66f), 0.025f);
                upperStormMass.a = funnelVisibility * 0.82f;
                frontBatch.AddColdCoreLobe(
                    funnelBase
                        - frame.CameraRight * (ActorHeight * 0.14f * cinematicWidth)
                        + frame.CameraUp * (ActorHeight * 0.94f * cinematicHeight)
                        - frame.CameraForward * (ActorHeight * 0.032f),
                    frame.CameraRight,
                    frame.CameraUp,
                    ActorHeight * 0.38f * cinematicWidth,
                    ActorHeight * 0.62f * cinematicHeight,
                    upperStormMass,
                    time,
                    Seed01(seed + 1613),
                    false,
                    -11f * Mathf.Deg2Rad,
                    true);

                // The former FunnelMantle surfaces carried two bright edge
                // ridges that read as thick blue wires. Replace them with
                // overlapping turbulent volumes: the silhouette stays large
                // and rotating, but there is no authored centreline or rim.
                var plumeColors = new[]
                {
                    Color.Lerp(DeepIce, Glacier, 0.72f),
                    Color.Lerp(AuroraViolet, AuroraRose, 0.34f),
                    Color.Lerp(MysticJade, Frost, 0.44f)
                };
                var plumeCenters = new[]
                {
                    new Vector2(-0.28f, 0.73f),
                    new Vector2(0.31f, 0.78f),
                    new Vector2(-0.04f, 1.08f)
                };
                var plumeWidths = new[] { 0.58f, 0.52f, 0.44f };
                var plumeHeights = new[] { 1.14f, 1.02f, 0.66f };
                var plumeTilts = new[] { -31f, 36f, 8f };
                for (var index = 0; index < plumeCenters.Length; index++)
                {
                    var plumeColor = ApplyLayerTint(plumeColors[index], 0.02f);
                    plumeColor.a = funnelVisibility * new[] { 0.58f, 0.48f, 0.52f }[index];
                    frontBatch.AddColdCoreLobe(
                        funnelBase
                            + frame.CameraRight * (ActorHeight * plumeCenters[index].x * cinematicWidth)
                            + frame.CameraUp * (ActorHeight * plumeCenters[index].y * cinematicHeight)
                            - frame.CameraForward * (ActorHeight * (0.025f + index * 0.009f)),
                        frame.CameraRight,
                        frame.CameraUp,
                        ActorHeight * plumeWidths[index] * cinematicWidth,
                        ActorHeight * plumeHeights[index] * cinematicHeight,
                        plumeColor,
                        time,
                        Seed01(seed + 1621 + index * 37),
                        false,
                        plumeTilts[index] * Mathf.Deg2Rad,
                        true);
                }
                // The former funnel strokes created a conspicuous S-shaped
                // line. Keep the rotating read entirely in turbulent mantles,
                // particles and broken burst surfaces; no axial line layer is
                // authored at impact or peak.

                // The references use one unmistakable white-hot construction
                // inside every large effect. This compact off-centre ice heart
                // is the tornado's focal read; it is not a full-height portal.
                var heartVisibility = funnelVisibility * Ease(0.98f, 1.12f, time);
                var heartPulse = 0.94f
                    + Mathf.Sin(time * 15.6f + Seed01(seed + 1949) * 7.2f) * 0.06f;
                var heartGlow = ApplyLayerTint(Color.Lerp(MoonCyan, IceWhite, 0.72f), 0.01f);
                heartGlow.a = heartVisibility * 0.94f;
                frontBatch.AddColdCoreLobe(
                    funnelBase
                        + frame.CameraRight * (ActorHeight * 0.045f)
                        + frame.CameraUp * (ActorHeight * 0.58f)
                        - frame.CameraForward * (ActorHeight * 0.025f),
                    frame.CameraRight,
                    frame.CameraUp,
                    ActorHeight * 0.285f * heartPulse,
                    ActorHeight * 0.46f * heartPulse,
                    heartGlow,
                    time,
                    Seed01(seed + 1961),
                    false,
                    -9f * Mathf.Deg2Rad);
                var heartHot = ApplyLayerTint(Color.Lerp(IceWhite, PaleGold, 0.10f), 0.01f);
                heartHot.a = heartVisibility * 0.72f;
                frontBatch.AddColdCoreLobe(
                    funnelBase
                        + frame.CameraRight * (ActorHeight * 0.025f)
                        + frame.CameraUp * (ActorHeight * 0.60f)
                        - frame.CameraForward * (ActorHeight * 0.035f),
                    frame.CameraRight,
                    frame.CameraUp,
                    ActorHeight * 0.105f * heartPulse,
                    ActorHeight * 0.23f * heartPulse,
                    heartHot,
                    time,
                    Seed01(seed + 1973),
                    true,
                    13f * Mathf.Deg2Rad);

                // Two offset plasma lobes carry the peak beyond a narrow
                // centre crack. Their turbulence, unequal scale and opposite
                // lean read as a pressure detonation inside the tornado, not
                // as a regular halo or a pair of billboard circles.
                var coronaVisibility = funnelVisibility
                    * Ease(0.96f, 1.12f, time)
                    * (1f - Ease(1.58f, 1.70f, time));
                var coronaLeft = ApplyLayerTint(
                    Color.Lerp(MysticJade, Frost, 0.50f), 0.015f);
                coronaLeft.a = coronaVisibility * 0.72f;
                frontBatch.AddColdCoreLobe(
                    funnelBase
                        - frame.CameraRight * (ActorHeight * 0.38f * cinematicWidth)
                        + frame.CameraUp * (ActorHeight * 0.64f * cinematicHeight)
                        - frame.CameraForward * (ActorHeight * 0.030f),
                    frame.CameraRight,
                    frame.CameraUp,
                    ActorHeight * 0.52f * cinematicWidth,
                    ActorHeight * 0.54f * cinematicHeight,
                    coronaLeft,
                    time,
                    Seed01(seed + 1979),
                    false,
                    -39f * Mathf.Deg2Rad);
                var coronaRight = ApplyLayerTint(
                    Color.Lerp(AuroraViolet, AuroraRose, 0.34f), 0.015f);
                coronaRight.a = coronaVisibility * 0.72f;
                frontBatch.AddColdCoreLobe(
                    funnelBase
                        + frame.CameraRight * (ActorHeight * 0.35f * cinematicWidth)
                        + frame.CameraUp * (ActorHeight * 0.79f * cinematicHeight)
                        - frame.CameraForward * (ActorHeight * 0.042f),
                    frame.CameraRight,
                    frame.CameraUp,
                    ActorHeight * 0.44f * cinematicWidth,
                    ActorHeight * 0.48f * cinematicHeight,
                    coronaRight,
                    time,
                    Seed01(seed + 1981),
                    false,
                    47f * Mathf.Deg2Rad);
                var coronaCrown = ApplyLayerTint(
                    Color.Lerp(PaleGold, IceWhite, 0.58f), 0.01f);
                coronaCrown.a = coronaVisibility * 0.66f;
                frontBatch.AddColdCoreLobe(
                    funnelBase
                        + frame.CameraRight * (ActorHeight * 0.07f)
                        + frame.CameraUp * (ActorHeight * 1.12f * cinematicHeight)
                        - frame.CameraForward * (ActorHeight * 0.038f),
                    frame.CameraRight,
                    frame.CameraUp,
                    ActorHeight * 0.34f * cinematicWidth,
                    ActorHeight * 0.47f * cinematicHeight,
                    coronaCrown,
                    time,
                    Seed01(seed + 1983),
                    false,
                    18f * Mathf.Deg2Rad);

                var divineSpark = ApplyLayerTint(
                    Color.Lerp(WarmWhite, PaleGold, 0.42f), 0.005f);
                divineSpark.a = coronaVisibility * 0.86f;
                frontBatch.AddColdCoreLobe(
                    funnelBase
                        - frame.CameraRight * (ActorHeight * 0.035f)
                        + frame.CameraUp * (ActorHeight * 0.63f)
                        - frame.CameraForward * (ActorHeight * 0.055f),
                    frame.CameraRight,
                    frame.CameraUp,
                    ActorHeight * 0.115f,
                    ActorHeight * 0.16f,
                    divineSpark,
                    time,
                    Seed01(seed + 1985),
                    false,
                    -17f * Mathf.Deg2Rad);

                // Unequal ice teeth lock the vortex to the ground. Their
                // lengths and lean differ so the base is explosive, not a
                // symmetric crown or a regular geometric ring.
                // Sustained blade strips are disabled. Even when broken into
                // pieces they read as thick wires once the blast settles.
                var baseShardVisibility = 0f;
                var baseShardAngles = new[] { 56f, 82f, 108f, 137f };
                var baseShardX = new[] { -0.34f, -0.15f, 0.11f, 0.29f };
                var baseShardLengths = new[] { 0.29f, 0.43f, 0.34f, 0.25f };
                var baseShardWidths = new[] { 0.060f, 0.082f, 0.068f, 0.052f };
                for (var index = 0; index < baseShardAngles.Length; index++)
                {
                    var angle = baseShardAngles[index] * Mathf.Deg2Rad;
                    var direction = (frame.CameraRight * Mathf.Cos(angle)
                        + frame.CameraUp * Mathf.Sin(angle)).normalized;
                    var across = (-frame.CameraRight * Mathf.Sin(angle)
                        + frame.CameraUp * Mathf.Cos(angle)).normalized;
                    var shardRoot = ApplyLayerTint(
                        index == 1
                            ? Color.Lerp(PaleGold, IceWhite, 0.24f)
                            : index == 2
                                ? Color.Lerp(AuroraViolet, Frost, 0.30f)
                                : index == 3
                                    ? Color.Lerp(AuroraRose, IceBlue, 0.42f)
                                    : Color.Lerp(Glacier, Frost, 0.34f),
                        0.02f);
                    var shardTip = ApplyLayerTint(
                        index == 2
                            ? Color.Lerp(AuroraRose, IceWhite, 0.54f)
                            : Color.Lerp(Frost, IceWhite, 0.62f),
                        0.01f);
                    shardRoot.a = baseShardVisibility * new[] { 0.76f, 0.94f, 0.86f, 0.70f }[index];
                    shardTip.a = shardRoot.a * 0.90f;
                    frontBatch.AddOrganicBurstPetal(
                        funnelBase
                            + frame.CameraRight * (ActorHeight * baseShardX[index])
                            + frame.CameraUp * (ActorHeight * 0.035f)
                            - frame.CameraForward * (ActorHeight * 0.018f),
                        direction,
                        across,
                        ActorHeight * baseShardLengths[index],
                        ActorHeight * baseShardWidths[index],
                        ActorHeight * new[] { -0.035f, 0.028f, -0.025f, 0.030f }[index],
                        18,
                        shardRoot,
                        shardTip,
                        time,
                        Seed01(seed + 1987 + index * 31),
                        true,
                        index == 1 || index == 2);
                }

                // An unequal fan of animated ice-qi blades gives the peak a
                // broad explosive silhouette. Each blade originates at a
                // different height and precesses independently, avoiding the
                // regular starburst or single continuous spiral called out in
                // review. Two warm-white fragments act as rare value accents.
                var stormBurstVisibility = 0f;
                var stormBurstOpen = Mathf.Lerp(0.58f, 1f, Ease(0.96f, 1.20f, time));
                var stormBurstAngles = new[] { 12f, 39f, 70f, 108f, 143f, 176f, 218f, 326f };
                var stormBurstX = new[] { 0.08f, 0.03f, 0.05f, -0.05f, -0.03f, -0.09f, -0.02f, 0.07f };
                var stormBurstY = new[] { 0.40f, 0.58f, 0.80f, 0.88f, 0.66f, 0.43f, 0.19f, 0.23f };
                var stormBurstLengths = new[] { 0.68f, 0.43f, 0.62f, 0.57f, 0.66f, 0.44f, 0.39f, 0.43f };
                var stormBurstWidths = new[] { 0.160f, 0.056f, 0.074f, 0.126f, 0.082f, 0.048f, 0.108f, 0.054f };
                for (var index = 0; index < stormBurstAngles.Length; index++)
                {
                    var angle = stormBurstAngles[index] * Mathf.Deg2Rad
                        + Mathf.Sin(phase * 0.16f + index * 2.07f) * 0.10f;
                    var direction = (frame.CameraRight * Mathf.Cos(angle)
                        + frame.CameraUp * Mathf.Sin(angle)).normalized;
                    var across = (-frame.CameraRight * Mathf.Sin(angle)
                        + frame.CameraUp * Mathf.Cos(angle)).normalized;
                    var warmShard = index == 1 || index == 5;
                    var auroraShard = index == 3 || index == 6;
                    var shardRoot = ApplyLayerTint(
                        warmShard
                            ? Color.Lerp(JadeWhite, WarmWhite, 0.44f)
                            : auroraShard
                                ? Color.Lerp(AuroraViolet, AuroraRose, index == 3 ? 0.26f : 0.56f)
                                : index == 7
                                    ? Color.Lerp(MysticJade, Frost, 0.30f)
                                : Color.Lerp(Glacier, IceBlue, index % 2 == 0 ? 0.62f : 0.42f),
                        0.02f);
                    var shardTip = ApplyLayerTint(
                        warmShard
                            ? Color.Lerp(IceWhite, PaleGold, 0.32f)
                            : auroraShard
                                ? Color.Lerp(AuroraRose, IceWhite, 0.68f)
                            : Color.Lerp(Frost, IceWhite, 0.72f),
                        0.01f);
                    shardRoot.a = stormBurstVisibility
                        * new[] { 0.88f, 0.94f, 0.82f, 0.76f, 0.90f, 0.86f, 0.70f, 0.78f }[index];
                    shardTip.a = shardRoot.a * 0.92f;
                    frontBatch.AddOrganicBurstPetal(
                        funnelBase
                            + frame.CameraRight * (ActorHeight * stormBurstX[index])
                            + frame.CameraUp * (ActorHeight * stormBurstY[index])
                            - frame.CameraForward * (ActorHeight * (0.025f + index % 3 * 0.008f)),
                        direction,
                        across,
                        ActorHeight * stormBurstLengths[index] * stormBurstOpen * cinematicWidth,
                        ActorHeight * stormBurstWidths[index] * stormBurstOpen * Mathf.Lerp(1f, 1.20f, cinematicOpen),
                        ActorHeight * new[] { 0.055f, -0.040f, 0.070f, -0.052f, 0.062f, -0.046f, 0.034f, -0.038f }[index],
                        20,
                        shardRoot,
                        shardTip,
                        time,
                        Seed01(seed + 2027 + index * 43),
                        index % 3 != 0,
                        warmShard);
                }

                // Two torn crown strokes break the top outline and keep the
                // funnel from reading as a stack of clean geometric rings.
                var crownVisibility = 0f;
                var crownAngles = new[] { 132f, 26f };
                for (var index = 0; index < crownAngles.Length; index++)
                {
                    var angle = crownAngles[index] * Mathf.Deg2Rad;
                    var direction = (frame.CameraRight * Mathf.Cos(angle)
                        + frame.CameraUp * Mathf.Sin(angle)).normalized;
                    var across = (-frame.CameraRight * Mathf.Sin(angle)
                        + frame.CameraUp * Mathf.Cos(angle)).normalized;
                    var rootColor = ApplyLayerTint(
                        index == 0
                            ? Color.Lerp(JadeWhite, WarmWhite, 0.22f)
                            : Color.Lerp(MoonCyan, JadeWhite, index == 1 ? 0.46f : 0.30f),
                        0.03f);
                    var tipColor = ApplyLayerTint(
                        index == 0
                            ? Color.Lerp(WarmWhite, PaleGold, 0.32f)
                            : Color.Lerp(MysticJade, JadeWhite, 0.38f),
                        0.03f);
                    rootColor.a = crownVisibility * new[] { 0.76f, 0.64f }[index];
                    tipColor.a = rootColor.a * 0.76f;
                    frontBatch.AddOrganicBurstPetal(
                        funnelBase
                            + frame.CameraUp * (ActorHeight * new[] { 1.05f, 0.98f }[index])
                            + frame.CameraRight * (ActorHeight * new[] { -0.08f, 0.05f }[index]),
                        direction,
                        across,
                        ActorHeight * new[] { 0.34f, 0.26f }[index],
                        ActorHeight * new[] { 0.082f, 0.058f }[index],
                        ActorHeight * new[] { -0.07f, 0.05f }[index],
                        22,
                        rootColor,
                        tipColor,
                        time,
                        Seed01(seed + 2017 + index * 97),
                        true,
                        index == 0);
                }

                // A short pale return edge locks the lower vortex to the
                // ground and supplies one rare warm, xianxia-style turn point.
                var returnAngle = 158f * Mathf.Deg2Rad;
                var returnDirection = (frame.CameraRight * Mathf.Cos(returnAngle)
                    + frame.CameraUp * Mathf.Sin(returnAngle)).normalized;
                var returnAcross = (-frame.CameraRight * Mathf.Sin(returnAngle)
                    + frame.CameraUp * Mathf.Cos(returnAngle)).normalized;
                var returnRoot = ApplyLayerTint(Color.Lerp(JadeWhite, WarmWhite, 0.28f), 0.02f);
                var returnTip = ApplyLayerTint(Color.Lerp(WarmWhite, PaleGold, 0.34f), 0.02f);
                returnRoot.a = 0f;
                returnTip.a = 0f;
                frontBatch.AddOrganicBurstPetal(
                    funnelBase
                        + frame.CameraRight * (ActorHeight * 0.28f)
                        + frame.CameraUp * (ActorHeight * 0.16f)
                        - frame.CameraForward * (ActorHeight * 0.025f),
                    returnDirection,
                    returnAcross,
                    ActorHeight * 0.46f,
                    ActorHeight * 0.038f,
                    ActorHeight * 0.045f,
                    20,
                    returnRoot,
                    returnTip,
                    time,
                    Seed01(seed + 2111),
                    true,
                    true);

                // Line-free foreground pressure. The former C-shaped veil was
                // partly hidden by the body and reappeared as two thick blue
                // wires. Two displaced turbulent lobes now submerge the actor
                // without any strip centreline, rim or geometric outline.
                var engulfVisibility = Ease(0.94f, 1.08f, time)
                    * (1f - Ease(1.62f, SpellEnd, time));
                var engulfCenters = new[]
                {
                    new Vector2(-0.15f, 0.56f),
                    new Vector2(0.17f, 0.67f)
                };
                for (var index = 0; index < engulfCenters.Length; index++)
                {
                    var engulfColor = ApplyLayerTint(
                        index == 0
                            ? Color.Lerp(DeepIce, IceBlue, 0.70f)
                            : Color.Lerp(AuroraViolet, MysticJade, 0.38f),
                        0.025f);
                    engulfColor.a = engulfVisibility * new[] { 0.84f, 0.68f }[index];
                    frontBatch.AddColdCoreLobe(
                        funnelBase
                            + frame.CameraRight * (ActorHeight * engulfCenters[index].x * cinematicWidth)
                            + frame.CameraUp * (ActorHeight * engulfCenters[index].y * cinematicHeight)
                            - frame.CameraForward * (ActorHeight * (0.070f + index * 0.012f)),
                        frame.CameraRight,
                        frame.CameraUp,
                        ActorHeight * new[] { 0.50f, 0.42f }[index] * cinematicWidth,
                        ActorHeight * new[] { 0.86f, 0.72f }[index] * cinematicHeight,
                        engulfColor,
                        time,
                        Seed01(seed + 2129 + index * 41),
                        false,
                        new[] { -21f, 27f }[index] * Mathf.Deg2Rad,
                        true);
                }

                // Draw the final hot fissure after the foreground pressure
                // face so the focal value cannot be buried by the blue body.
                var finalHeart = ApplyLayerTint(Color.Lerp(IceWhite, PaleGold, 0.08f), 0.01f);
                finalHeart.a = heartVisibility * 0.78f;
                frontBatch.AddColdCoreLobe(
                    funnelBase
                        + frame.CameraRight * (ActorHeight * 0.035f)
                        + frame.CameraUp * (ActorHeight * 0.59f)
                        - frame.CameraForward * (ActorHeight * 0.060f),
                    frame.CameraRight,
                    frame.CameraUp,
                    ActorHeight * 0.120f * heartPulse,
                    ActorHeight * 0.27f * heartPulse,
                    finalHeart,
                    time,
                    Seed01(seed + 2161),
                    true,
                    8f * Mathf.Deg2Rad);

                // Ground response is supplied by the world-space broken arcs
                // and mist field; no camera-facing halo strip is rendered.
            }
            if (frontBatch != null && coldCoreVisibility > 0.002f)
            {
                // The former full-height core made every capture read as a
                // portal. The core is now only a short, compressed detonation
                // at the chest; the crossing brush blades provide engulfment.
                var coreBase = ground
                    + frame.CameraUp * (ActorHeight * 0.56f)
                    - frame.CameraForward * 0.112f;
                var pressureCore = ApplyLayerTint(
                    Color.Lerp(DeepIce, MoonCyan, 0.28f), 0.04f);
                pressureCore.a = coldCoreVisibility * 0.78f;
                frontBatch.AddColdCoreLobe(
                    coreBase,
                    frame.CameraRight,
                    frame.CameraUp,
                    ActorHeight * 0.18f,
                    ActorHeight * 0.22f,
                    pressureCore,
                    time,
                    Seed01(seed + 947));
                var cyanPlasma = ApplyLayerTint(
                    Color.Lerp(IceBlue, MoonCyan, 0.58f), 0.03f);
                cyanPlasma.a = coldCoreVisibility * 0.74f;
                frontBatch.AddColdCoreLobe(
                    coreBase + frame.CameraRight * (ActorHeight * 0.012f),
                    frame.CameraRight,
                    frame.CameraUp,
                    ActorHeight * 0.11f,
                    ActorHeight * 0.17f,
                    cyanPlasma,
                    time,
                    Seed01(seed + 991));
                var hotFlash = Color.Lerp(ApplyLayerTint(IceWhite, 0.02f), PaleGold, 0.12f);
                hotFlash.a = coldCoreVisibility * 0.66f;
                frontBatch.AddColdCoreLobe(
                    coreBase - frame.CameraRight * (ActorHeight * 0.006f),
                    frame.CameraRight,
                    frame.CameraUp,
                    ActorHeight * 0.090f,
                    ActorHeight * 0.115f,
                    hotFlash,
                    time,
                    Seed01(seed + 1013));
            }
            if (frontBatch != null && burstVisibility > 0.002f)
            {
                var burstOrigin = ground - frame.CameraForward * 0.118f;
                // Offset pressure masses are the dense body of the detonation;
                // the later blades are only its calligraphic tearing edge.
                var impactVolumeCenters = new[]
                {
                    new Vector2(-0.12f, 0.53f),
                    new Vector2(0.14f, 0.58f),
                    new Vector2(0.02f, 0.27f)
                };
                var impactVolumeWidths = new[] { 0.50f, 0.38f, 0.44f };
                var impactVolumeHeights = new[] { 0.68f, 0.76f, 0.42f };
                var impactVolumeTilts = new[] { -24f, 18f, -8f };
                for (var index = 0; index < impactVolumeCenters.Length; index++)
                {
                    var impactVolumeColor = ApplyLayerTint(
                        index == 1
                            ? Color.Lerp(DeepIce, AuroraViolet, 0.66f)
                            : index == 2
                                ? Color.Lerp(DeepIce, MysticJade, 0.58f)
                                : Color.Lerp(DeepIce, IceBlue, 0.58f),
                        0.03f);
                    impactVolumeColor.a = burstVisibility * new[] { 0.74f, 0.68f, 0.62f }[index];
                    frontBatch.AddColdCoreLobe(
                        burstOrigin
                            + frame.CameraRight * (ActorHeight * impactVolumeCenters[index].x)
                            + frame.CameraUp * (ActorHeight * impactVolumeCenters[index].y),
                        frame.CameraRight,
                        frame.CameraUp,
                        ActorHeight * impactVolumeWidths[index] * burstOpen,
                        ActorHeight * impactVolumeHeights[index] * burstOpen,
                        impactVolumeColor,
                        time,
                        Seed01(seed + 1009 + index * 61),
                        false,
                        impactVolumeTilts[index] * Mathf.Deg2Rad,
                        true);
                }

                // Contact needs a dense crown as well as the broad lateral
                // tear. This offset, animated lobe swallows the head/shoulder
                // silhouette while preserving the irregular explosive edge.
                var upperImpactMass = ApplyLayerTint(
                    Color.Lerp(DeepIce, IceBlue, 0.68f), 0.02f);
                upperImpactMass.a = burstVisibility * 0.88f;
                frontBatch.AddColdCoreLobe(
                    burstOrigin
                        - frame.CameraRight * (ActorHeight * 0.20f)
                        + frame.CameraUp * (ActorHeight * 1.04f)
                        - frame.CameraForward * (ActorHeight * 0.035f),
                    frame.CameraRight,
                    frame.CameraUp,
                    ActorHeight * 0.46f * burstOpen,
                    ActorHeight * 0.70f * burstOpen,
                    upperImpactMass,
                    time,
                    Seed01(seed + 1171),
                    false,
                    -8f * Mathf.Deg2Rad,
                    true);

                var impactOcclusion = ApplyLayerTint(
                    Color.Lerp(DeepIce, IceBlue, 0.62f), 0.02f);
                impactOcclusion.a = 0f;
                var impactOcclusionAccent = ApplyLayerTint(
                    Color.Lerp(Glacier, Frost, 0.40f), 0.02f);
                impactOcclusionAccent.a = 0f;
                var occlusionAngles = new[] { -18f, 28f, 104f, 78f };
                var occlusionOriginsX = new[] { -0.46f, -0.42f, 0.18f, -0.20f };
                var occlusionOriginsY = new[] { 0.94f, 0.08f, 0.02f, 0.05f };
                var occlusionLengths = new[] { 1.04f, 0.92f, 0.82f, 1.38f };
                var occlusionWidths = new[] { 0.35f, 0.30f, 0.25f, 0.32f };
                for (var index = 0; index < occlusionAngles.Length; index++)
                {
                    var occlusionAngle = occlusionAngles[index] * Mathf.Deg2Rad;
                    var occlusionDirection = (frame.CameraRight * Mathf.Cos(occlusionAngle)
                        + frame.CameraUp * Mathf.Sin(occlusionAngle)).normalized;
                    var occlusionAcross = (-frame.CameraRight * Mathf.Sin(occlusionAngle)
                        + frame.CameraUp * Mathf.Cos(occlusionAngle)).normalized;
                    var rootColor = index == 0 ? impactOcclusion : impactOcclusionAccent;
                    var tipColor = ApplyLayerTint(
                        index == 0
                            ? Color.Lerp(Glacier, IceBlue, 0.48f)
                            : index == 1
                                ? Color.Lerp(AuroraViolet, AuroraRose, 0.34f)
                                : index == 2
                                    ? Color.Lerp(MysticJade, IceBlue, 0.62f)
                                    : Color.Lerp(PaleGold, IceWhite, 0.46f),
                        0.02f);
                    tipColor.a = rootColor.a * 0.84f;
                    frontBatch.AddOrganicBurstPetal(
                        burstOrigin
                            + frame.CameraRight * (ActorHeight * occlusionOriginsX[index])
                            + frame.CameraUp * (ActorHeight * occlusionOriginsY[index]),
                        occlusionDirection,
                        occlusionAcross,
                        ActorHeight * occlusionLengths[index] * burstOpen,
                        ActorHeight * occlusionWidths[index] * burstOpen,
                        ActorHeight * new[] { 0.11f, -0.08f, 0.10f, -0.09f }[index],
                        30,
                        rootColor,
                        tipColor,
                        time,
                        Seed01(seed + 1193 + index * 47),
                        true,
                        false,
                        true);
                }
                // No full-body pressure card is permitted here. The three
                // tapered faceted blades below complete the near-solid union.
                // Contact is deliberately wider than it is tall: three broad
                // strokes tear across the actor before their tips curl upward
                // into the later funnel. This is the opposite of a vertical
                // portal silhouette.
                var mainAngles = new[] { -31f, 16f, 126f };
                var mainLengths = new[] { 0.92f, 0.78f, 0.57f };
                var mainWidths = new[] { 0.148f, 0.118f, 0.086f };
                var mainOriginX = new[] { -0.48f, -0.43f, 0.25f };
                var mainOriginY = new[] { 0.86f, 0.29f, 0.10f };
                for (var index = 0; index < mainAngles.Length; index++)
                {
                    var targetAngle = index == 0 ? 64f : index == 1 ? 104f : 76f;
                    var degrees = Mathf.Lerp(mainAngles[index], targetAngle, burstCurl * 0.34f);
                    var angle = degrees * Mathf.Deg2Rad;
                    var direction = (frame.CameraRight * Mathf.Cos(angle) + frame.CameraUp * Mathf.Sin(angle)).normalized;
                    var across = (-frame.CameraRight * Mathf.Sin(angle) + frame.CameraUp * Mathf.Cos(angle)).normalized;
                    var rootColor = ApplyLayerTint(
                        Color.Lerp(DeepIce, IceBlue,
                            index == 0 ? 0.64f : index == 1 ? 0.56f : 0.48f), 0.03f);
                    var tipColor = ApplyLayerTint(
                        index == 0
                            ? Color.Lerp(Glacier, Frost, 0.54f)
                            : Color.Lerp(Glacier, IceWhite, index == 1 ? 0.48f : 0.34f),
                        0.03f);
                    rootColor.a = 0f;
                    tipColor.a = rootColor.a * 0.84f;
                    var localOrigin = burstOrigin
                        + frame.CameraRight * (ActorHeight * mainOriginX[index])
                        + frame.CameraUp * (ActorHeight * (mainOriginY[index]
                            + burstCurl * new[] { 0.05f, 0.10f, 0.14f }[index]));
                    var bladeLength = ActorHeight * mainLengths[index] * burstOpen * burstExpansion;
                    var bladeWidth = ActorHeight * mainWidths[index] * burstOpen;
                    frontBatch.AddOrganicBurstPetal(
                        localOrigin,
                        direction,
                        across,
                        bladeLength,
                        bladeWidth,
                        ActorHeight * new[] { 0.10f, -0.08f, 0.07f }[index],
                        index == 2 ? 22 : 24,
                        rootColor,
                        tipColor,
                        time,
                        Seed01(seed + 1401 + index * 31),
                        true);

                    // The explosive blade carries a thin jade-white fracture
                    // inside its darker brush body. It is deliberately offset
                    // and tapered, so it reads as frozen qi rather than a
                    // geometric ray or a flat starburst.
                    var fractureRoot = index == 0
                        ? Color.Lerp(JadeWhite, PaleGold, 0.16f)
                        : Color.Lerp(JadeWhite, MoonCyan, index == 1 ? 0.08f : 0.24f);
                    var fractureTip = index == 0
                        ? Color.Lerp(WarmWhite, PaleGold, 0.26f)
                        : Color.Lerp(IceWhite, Frost, 0.20f);
                    fractureRoot = ApplyLayerTint(fractureRoot, 0.02f);
                    fractureTip = ApplyLayerTint(fractureTip, 0.02f);
                    if (index < 2)
                    {
                        fractureRoot.a = 0f;
                        fractureTip.a = fractureRoot.a * 0.86f;
                        frontBatch.AddOrganicBurstPetal(
                            localOrigin + across * (bladeWidth * 0.05f)
                                - frame.CameraForward * (ActorHeight * 0.018f),
                            direction,
                            across,
                            bladeLength * 1.02f,
                            ActorHeight * new[] { 0.032f, 0.026f }[index] * burstOpen,
                            ActorHeight * new[] { 0.10f, -0.08f }[index] * 1.04f,
                            24,
                            fractureRoot,
                            fractureTip,
                            time,
                            Seed01(seed + 1483 + index * 47),
                            true,
                            true);
                    }
                }

                // One foreground cutting face traverses the upper body. It is
                // an asymmetric blade, not a soft full-screen veil, and its
                // broken interior lets the other impact depths remain visible.
                var cutAngle = -22f * Mathf.Deg2Rad;
                var cutDirection = (frame.CameraRight * Mathf.Cos(cutAngle)
                    + frame.CameraUp * Mathf.Sin(cutAngle)).normalized;
                var cutAcross = (-frame.CameraRight * Mathf.Sin(cutAngle)
                    + frame.CameraUp * Mathf.Cos(cutAngle)).normalized;
                var cutRoot = ApplyLayerTint(
                    Color.Lerp(DeepIce, IceBlue, 0.72f), 0.03f);
                var cutTip = ApplyLayerTint(
                    Color.Lerp(Glacier, IceWhite, 0.52f), 0.02f);
                cutRoot.a = 0f;
                cutTip.a = 0f;
                frontBatch.AddOrganicBurstPetal(
                    burstOrigin
                        - frame.CameraRight * (ActorHeight * 0.43f)
                        + frame.CameraUp * (ActorHeight * 0.72f)
                        - frame.CameraForward * (ActorHeight * 0.025f),
                    cutDirection,
                    cutAcross,
                    ActorHeight * 0.84f * burstOpen,
                    ActorHeight * 0.082f * burstOpen,
                    ActorHeight * 0.045f,
                    28,
                    cutRoot,
                    cutTip,
                    time,
                    Seed01(seed + 1553),
                    true);

                // Short embedded ice facets supply a sharp commercial read.
                // They remain broken brush surfaces inside the impact mass,
                // not independent geometric rays or a symmetric starburst.
                var facetAngles = new[] { -28f, 20f };
                var facetLengths = new[] { 0.26f, 0.22f };
                var facetWidths = new[] { 0.030f, 0.024f };
                var facetOriginX = new[] { -0.11f, -0.02f };
                var facetOriginY = new[] { 0.52f, 0.58f };
                for (var index = 0; index < facetAngles.Length; index++)
                {
                    var angle = facetAngles[index] * Mathf.Deg2Rad;
                    var direction = (frame.CameraRight * Mathf.Cos(angle)
                        + frame.CameraUp * Mathf.Sin(angle)).normalized;
                    var across = (-frame.CameraRight * Mathf.Sin(angle)
                        + frame.CameraUp * Mathf.Cos(angle)).normalized;
                    var facetRoot = ApplyLayerTint(
                        Color.Lerp(JadeWhite, WarmWhite, index == 1 ? 0.22f : 0.10f), 0.02f);
                    var facetTip = ApplyLayerTint(Color.Lerp(Frost, MoonCyan, 0.18f), 0.02f);
                    facetRoot.a = 0f;
                    facetTip.a = facetRoot.a * 0.45f;
                    frontBatch.AddOrganicBurstPetal(
                        burstOrigin
                            + frame.CameraRight * (ActorHeight * facetOriginX[index])
                            + frame.CameraUp * (ActorHeight * facetOriginY[index]),
                        direction,
                        across,
                        ActorHeight * facetLengths[index] * burstOpen,
                        ActorHeight * facetWidths[index] * burstOpen,
                        ActorHeight * new[] { 0.025f, -0.018f, 0.020f }[index],
                        14,
                        facetRoot,
                        facetTip,
                        time,
                        Seed01(seed + 1669 + index * 29),
                        true,
                        true);
                }

                // A compact hot fracture sits above the dark brush bodies for
                // the one-frame detonation read. It disappears before the
                // funnel reaches its peak; regular radial wedges are avoided.
                var impactHot = ApplyLayerTint(Color.Lerp(IceWhite, PaleGold, 0.12f), 0.01f);
                impactHot.a = burstVisibility * 0.98f;
                var impactGlow = ApplyLayerTint(Color.Lerp(MoonCyan, IceWhite, 0.68f), 0.01f);
                impactGlow.a = burstVisibility * 0.995f;
                frontBatch.AddColdCoreLobe(
                    burstOrigin + frame.CameraUp * (ActorHeight * 0.55f),
                    frame.CameraRight,
                    frame.CameraUp,
                    ActorHeight * 0.300f,
                    ActorHeight * 0.255f,
                    impactGlow,
                    time,
                    Seed01(seed + 1711));
                frontBatch.AddColdCoreLobe(
                    burstOrigin + frame.CameraUp * (ActorHeight * 0.56f),
                    frame.CameraRight,
                    frame.CameraUp,
                    ActorHeight * 0.175f,
                    ActorHeight * 0.185f,
                    impactHot,
                    time,
                    Seed01(seed + 1733),
                    true,
                    -28f * Mathf.Deg2Rad);

                // Three-frame prismatic overburst. Unequal directions and
                // displaced roots make the impact jump outward instead of
                // growing like a smooth UI tween or a regular star icon.
                if (impactPopVisibility > 0.002f)
                {
                    var popCloudCenters = new[]
                    {
                        new Vector2(-0.54f, 0.52f),
                        new Vector2(0.49f, 0.61f),
                        new Vector2(-0.27f, 1.00f),
                        new Vector2(0.23f, 1.07f),
                        new Vector2(-0.40f, 0.15f),
                        new Vector2(0.37f, 0.22f),
                        new Vector2(0.02f, 0.72f)
                    };
                    var popCloudWidths = new[] { 0.58f, 0.51f, 0.46f, 0.43f, 0.52f, 0.46f, 0.40f };
                    var popCloudHeights = new[] { 0.46f, 0.43f, 0.52f, 0.47f, 0.36f, 0.34f, 0.58f };
                    var popCloudTilts = new[] { -32f, 29f, -16f, 22f, 41f, -38f, 7f };
                    var popPalette = new[]
                    {
                        Color.Lerp(Glacier, IceWhite, 0.18f),
                        Color.Lerp(AuroraRose, AuroraViolet, 0.22f),
                        Color.Lerp(PaleGold, IceWhite, 0.20f),
                        Color.Lerp(AuroraViolet, Frost, 0.16f),
                        Color.Lerp(MysticJade, IceWhite, 0.22f),
                        Color.Lerp(AuroraRose, IceBlue, 0.24f),
                        Color.Lerp(IceBlue, PaleGold, 0.12f)
                    };
                    for (var index = 0; index < popCloudCenters.Length; index++)
                    {
                        var cloudColor = ApplyLayerTint(popPalette[index], 0.01f);
                        cloudColor.a = impactPopVisibility * new[]
                            { 0.84f, 0.78f, 0.90f, 0.80f, 0.82f, 0.76f, 0.86f }[index];
                        frontBatch.AddColdCoreLobe(
                            burstOrigin
                                + frame.CameraRight * (ActorHeight * popCloudCenters[index].x * popOvershoot)
                                + frame.CameraUp * (ActorHeight * popCloudCenters[index].y)
                                - frame.CameraForward * (ActorHeight * (0.052f + index * 0.006f)),
                            frame.CameraRight,
                            frame.CameraUp,
                            ActorHeight * popCloudWidths[index] * popOvershoot,
                            ActorHeight * popCloudHeights[index] * popOvershoot,
                            cloudColor,
                            time,
                            Seed01(seed + 1811 + index * 53),
                            false,
                            popCloudTilts[index] * Mathf.Deg2Rad,
                            index != 2 && index != 6);
                    }

                    var popFlash = ApplyLayerTint(Color.Lerp(IceWhite, PaleGold, 0.10f), 0.005f);
                    popFlash.a = impactPopVisibility * 0.995f;
                    frontBatch.AddColdCoreLobe(
                        burstOrigin
                            + frame.CameraRight * (ActorHeight * 0.025f)
                            + frame.CameraUp * (ActorHeight * 0.54f)
                            - frame.CameraForward * (ActorHeight * 0.072f),
                        frame.CameraRight,
                        frame.CameraUp,
                        ActorHeight * 0.58f * popOvershoot,
                        ActorHeight * 0.62f * popOvershoot,
                        popFlash,
                        time,
                        Seed01(seed + 2203),
                        false,
                        -13f * Mathf.Deg2Rad);
                }
            }
            // No post-impact centre lobe: after 0.905 s the visual mass is
            // carried entirely by the rotating funnel and its foreground
            // brush. Keeping any full-height centre element makes a portal.
            if (time >= 1.02f)
            {
                frontBatch?.AddSpiralGlints(
                    ground + frame.CameraUp * (ActorHeight * 0.12f)
                        - frame.CameraForward * 0.095f,
                    frame.CameraRight,
                    frame.CameraUp,
                    frame.CameraForward,
                    ActorHeight,
                    time,
                    phase,
                    glintVisibility * 0.78f,
                    ApplyLayerTint(JadeWhite, 0.06f),
                    PaleGold);
            }
            frontBatch?.Commit();

            crystalField?.Sample(
                ground + Vector3.up * (ActorHeight * 0.18f),
                frame.CameraRight,
                frame.CameraUp,
                frame.CameraForward,
                time,
                ActorHeight);
        }

        static float ResolveAccentStrength(float time)
        {
            if (time <= ContactTime)
                return Mathf.Lerp(0.12f, 0.34f, Ease(0.10f, ContactTime, time));
            if (time <= 0.833f)
                return Mathf.Lerp(0.34f, 0.98f, Ease(ContactTime, 0.833f, time));
            if (time <= 1.00f)
                return Mathf.Lerp(0.98f, 0.68f, Ease(0.833f, 1.00f, time));
            if (time <= 1.267f)
                return Mathf.Lerp(0.68f, 0.88f, Ease(1.00f, 1.267f, time));
            if (time <= 1.40f)
                return Mathf.Lerp(0.88f, 0.38f, Ease(1.267f, 1.40f, time));
            if (time <= 1.60f)
                return Mathf.Lerp(0.38f, 0.12f, Ease(1.40f, 1.60f, time));
            return Mathf.Lerp(0.12f, 0f, Ease(1.60f, SpellEnd, time));
        }

        void UpdateEffekseer(
            in SpellSample sample,
            Vector3 position,
            Quaternion rotation,
            Vector3 scale,
            Color color,
            bool stopRoot,
            float simulationFrames = 1f)
        {
            if (!effectStarted && sample.AdvanceSimulation && effectAsset != null)
            {
                effectStarted = true;
                var parameters = EffekseerPlayEffectParameters.Create(position);
                parameters.SetRotation(Vector3.up, 0f);
                parameters.SetScale(scale);
                effectHandle = EffekseerSystem.PlayEffect(effectAsset, parameters);
                if (effectHandle.enabled)
                    effectHandle.paused = true;
            }
            if (!effectHandle.enabled || !effectHandle.exists)
                return;

            effectHandle.SetLocation(position);
            effectHandle.SetRotation(rotation);
            effectHandle.SetAllColor(color);
            var visible = color.a > 0.002f;
            effectHandle.shown = visible;
            // Effekseer's shown flag does not reliably cull every already
            // spawned child renderer in the Unity capture backend.  Collapse
            // the handle as well, and retire it once the authored layer has
            // entered its terminal fade, so travel/pressure particles cannot
            // leak into the final breakup frame.
            effectHandle.SetScale(visible ? scale : Vector3.zero);
            if (!visible && sample.AbsoluteTime >= 1.02f)
            {
                effectHandle.Stop();
                effectHandle = new EffekseerHandle(-1);
                return;
            }
            if (stopRoot && !effectRootStopped)
            {
                effectRootStopped = true;
                effectHandle.StopRoot();
            }
            if (sample.AdvanceSimulation)
                effectHandle.UpdateHandle(Mathf.Max(0.01f, simulationFrames));
        }

        static Shape ResolveShape(float time)
        {
            float lengthH;
            float radiusH;
            float turns;
            float impact;

            if (time <= FormationEnd)
            {
                var u = Ease(0f, FormationEnd, time);
                lengthH = Mathf.Lerp(0.46f, 0.66f, u);
                radiusH = Mathf.Lerp(0.15f, 0.21f, u);
                turns = Mathf.Lerp(1.02f, 1.15f, u);
                impact = 0f;
            }
            else if (time <= ContactTime)
            {
                var u = Ease(FormationEnd, ContactTime, time);
                lengthH = Mathf.Lerp(0.66f, 0.84f, Ease(FormationEnd, FormationEnd + 0.14f, time));
                radiusH = Mathf.Lerp(0.21f, 0.255f, u);
                turns = Mathf.Lerp(1.15f, 1.08f, u);
                impact = 0f;
            }
            else if (time <= AxisTurnEnd)
            {
                var u = Ease(ContactTime, AxisTurnEnd, time);
                lengthH = Mathf.Lerp(0.66f, 0.92f, u);
                radiusH = Mathf.Lerp(0.19f, 0.27f, u);
                turns = Mathf.Lerp(1.08f, 1.62f, u);
                impact = u;
            }
            else if (time <= ExpansionEnd)
            {
                var u = Ease(AxisTurnEnd, ExpansionEnd, time);
                lengthH = Mathf.Lerp(0.92f, 1.42f, u);
                radiusH = Mathf.Lerp(0.27f, 0.43f, u);
                turns = Mathf.Lerp(1.62f, 2.18f, u);
                impact = 1f;
            }
            else if (time <= PeakEnd)
            {
                var u = Ease(ExpansionEnd, PeakEnd, time);
                lengthH = Mathf.Lerp(1.42f, 1.48f, u);
                radiusH = Mathf.Lerp(0.43f, 0.46f, u);
                turns = Mathf.Lerp(2.18f, 2.28f, u);
                impact = 1f;
            }
            else
            {
                var u = Ease(PeakEnd, SpellEnd, time);
                lengthH = Mathf.Lerp(1.48f, 0.72f, u);
                radiusH = Mathf.Lerp(0.46f, 0.18f, u);
                turns = Mathf.Lerp(2.28f, 1.12f, u);
                impact = 1f;
            }

            return new Shape(lengthH * ActorHeight, radiusH * ActorHeight, turns, impact);
        }

        static ImpactProfile ResolveCommercialImpactProfile(float time)
        {
            var contact = new ImpactProfile(0.72f, 0.070f, 0.30f, 1.15f, 0f);
            var compressed = new ImpactProfile(0.68f, 0.060f, 0.29f, 1.10f, 0f);
            var released = new ImpactProfile(0.78f, 0.070f, 0.44f, 1.25f, 0f);
            var burst = new ImpactProfile(0.84f, 0.080f, 0.52f, 1.36f, 0f);
            var shear = new ImpactProfile(1.05f, 0.090f, 0.49f, 1.50f, 0f);
            var rising = new ImpactProfile(1.30f, 0.100f, 0.46f, 1.65f, 0f);
            var peak = new ImpactProfile(1.46f, 0.100f, 0.48f, 1.85f, 0f);
            var crown = new ImpactProfile(1.48f, 0.100f, 0.46f, 1.90f, 0.02f);
            var liftedTail = new ImpactProfile(0.82f, 0.050f, 0.25f, 1.45f, 0.20f);
            var finalTail = new ImpactProfile(0.46f, 0.020f, 0.10f, 1.10f, 0.34f);

            if (time <= 0.800f)
                return ImpactProfile.Lerp(contact, compressed, Ease(ContactTime, 0.800f, time));
            if (time <= 0.817f)
                return ImpactProfile.Lerp(compressed, released, Ease(0.800f, 0.817f, time));
            if (time <= 0.833f)
                return ImpactProfile.Lerp(released, burst, Ease(0.817f, 0.833f, time));
            if (time <= 0.883f)
                return ImpactProfile.Lerp(burst, shear, Ease(0.833f, 0.883f, time));
            if (time <= 0.950f)
                return ImpactProfile.Lerp(shear, rising, Ease(0.883f, 0.950f, time));
            if (time <= 1.267f)
                return ImpactProfile.Lerp(rising, peak, Ease(0.950f, 1.267f, time));
            if (time <= 1.420f)
                return ImpactProfile.Lerp(peak, crown, Ease(1.267f, 1.420f, time));
            if (time <= 1.600f)
                return ImpactProfile.Lerp(crown, liftedTail, Ease(1.420f, 1.600f, time));
            return ImpactProfile.Lerp(liftedTail, finalTail, Ease(1.600f, SpellEnd, time));
        }

        static Vector2 ResolveImpactBurstScale(float time)
        {
            var contact = new Vector2(0.72f, 0.84f);
            var compressed = new Vector2(0.58f, 0.72f);
            var released = new Vector2(1.08f, 0.82f);
            var burst = new Vector2(1.34f, 0.94f);
            var shear = new Vector2(1.18f, 1.10f);
            var rising = new Vector2(1.00f, 1.30f);

            if (time <= 0.800f)
                return Vector2.Lerp(contact, compressed, Ease(ContactTime, 0.800f, time));
            if (time <= 0.817f)
                return Vector2.Lerp(compressed, released, Ease(0.800f, 0.817f, time));
            if (time <= 0.833f)
                return Vector2.Lerp(released, burst, Ease(0.817f, 0.833f, time));
            if (time <= 0.883f)
                return Vector2.Lerp(burst, shear, Ease(0.833f, 0.883f, time));
            return Vector2.Lerp(shear, rising, Ease(0.883f, 0.950f, time));
        }

        static float ResolveGroundRadius(float time)
        {
            if (time <= ExpansionEnd)
                return Mathf.Lerp(0.16f, 0.44f, Ease(0.80f, ExpansionEnd, time)) * ActorHeight;
            return Mathf.Lerp(0.44f, 0.25f, Ease(ExpansionEnd, SpellEnd, time)) * ActorHeight;
        }

        static Vector3 ResolveContinuousMotionCenter(in SpellSample sample, float time)
        {
            var movementStart = FormationEnd - 0.05f;
            var progress = Mathf.Clamp01((time - movementStart) / Mathf.Max(0.01f, ContactTime - movementStart));
            var center = Vector3.LerpUnclamped(sample.Source, sample.Target, progress);
            center += Vector3.up * (4f * progress * (1f - progress) * 0.18f);
            return center;
        }

        static float ContinuousPhase(float time)
        {
            // Integral of the piecewise angular velocity. There is no phase
            // reset at formation, contact, peak, slow motion, or replay.
            var degrees = 0f;
            var t = Mathf.Max(0f, time);
            var segment = Mathf.Min(t, FormationEnd);
            degrees += segment * 900f;
            if (t <= FormationEnd)
                return degrees * Mathf.Deg2Rad;

            segment = Mathf.Min(t, ContactTime) - FormationEnd;
            degrees += segment * 720f;
            if (t <= ContactTime)
                return degrees * Mathf.Deg2Rad;

            segment = Mathf.Min(t, AxisTurnEnd) - ContactTime;
            var turnDuration = AxisTurnEnd - ContactTime;
            degrees += 720f * segment + 0.5f * (360f / turnDuration) * segment * segment;
            if (t <= AxisTurnEnd)
                return degrees * Mathf.Deg2Rad;

            segment = Mathf.Min(t, PeakEnd) - AxisTurnEnd;
            degrees += segment * 1080f;
            if (t <= PeakEnd)
                return degrees * Mathf.Deg2Rad;

            segment = Mathf.Min(t, SpellEnd) - PeakEnd;
            var decayDuration = SpellEnd - PeakEnd;
            degrees += 1080f * segment - 0.5f * (540f / decayDuration) * segment * segment;
            return degrees * Mathf.Deg2Rad;
        }

        Material CreateMaterial(
            Shader shader,
            Texture2D texture,
            int renderQueue,
            CompareFunction zTest,
            Color tint)
        {
            var material = new Material(shader)
            {
                name = $"Runtime {layer.name} dynamic flow",
                hideFlags = HideFlags.DontSave,
                mainTexture = texture,
                renderQueue = renderQueue
            };
            material.SetColor("_Tint", tint);
            material.SetColor("_HotColor", IceWhite);
            material.SetFloat("_Opacity", 1f);
            material.SetFloat("_ErodeLow", 0.36f);
            material.SetFloat("_ErodeHigh", 0.66f);
            if (material.HasProperty("_AlphaCap"))
                material.SetFloat("_AlphaCap", 0.56f);
            if (material.HasProperty("_Coverage"))
                material.SetFloat("_Coverage", 0f);
            if (material.HasProperty("_Occlusion"))
                material.SetFloat("_Occlusion", 0f);
            material.SetInt("_ZTest", (int)zTest);
            return material;
        }

        Material CreateAssetMaterial(
            Shader shader,
            Texture2D texture,
            int renderQueue,
            CompareFunction zTest,
            Color deepColor,
            Color tint,
            Color hotColor,
            Color warmColor,
            float alphaCap,
            float intensity,
            float distortion,
            float arcSpan,
            bool additive)
        {
            var material = CreateMaterial(shader, texture, renderQueue, zTest, tint);
            material.name = $"Runtime {layer.name} mature asset {texture.name}";
            material.SetColor("_DeepColor", deepColor);
            material.SetColor("_Tint", tint);
            material.SetColor("_HotColor", hotColor);
            material.SetColor("_WarmColor", warmColor);
            material.SetFloat("_Opacity", 1f);
            material.SetFloat("_AlphaCap", alphaCap);
            material.SetFloat("_Intensity", intensity);
            material.SetFloat("_Distortion", distortion);
            material.SetFloat("_CutLow", 0.030f);
            material.SetFloat("_CutHigh", texture.name == "blue_fire"
                ? 0.235f
                : texture.name == "Fire_Single"
                    ? 0.285f
                    : 0.220f);
            material.SetFloat("_ArcSpan", arcSpan);
            material.SetFloat("_WarmAmount", additive ? 0.022f : 0.010f);
            material.SetFloat("_UseSourceAlpha", texture.name == "Fire_Single" ? 1f : 0f);
            material.SetInt("_SrcBlend", (int)BlendMode.One);
            material.SetInt("_DstBlend", (int)(additive
                ? BlendMode.One
                : BlendMode.OneMinusSrcAlpha));
            material.SetInt("_ZTest", (int)zTest);
            return material;
        }

        static Texture2D CreateDirectionlessNoise(int textureSeed)
        {
            const int size = 128;
            var texture = new Texture2D(size, size, TextureFormat.RGBA32, false)
            {
                name = "Runtime frost directionless flow noise",
                hideFlags = HideFlags.DontSave,
                filterMode = FilterMode.Bilinear,
                wrapMode = TextureWrapMode.Repeat
            };
            var pixels = new Color32[size * size];
            for (var y = 0; y < size; y++)
            for (var x = 0; x < size; x++)
            {
                var u = x / (float)size;
                var v = y / (float)size;

                // Periodic domain-warped FBM: no visible seam, no diagonal
                // sine lattice, and enough scale separation for broad ink
                // bodies plus fine frost breakup from the same two channels.
                var warpX = (TileableValueNoise(u, v, 3, textureSeed + 17) - 0.5f)
                    + (TileableValueNoise(u, v, 7, textureSeed + 113) - 0.5f) * 0.42f;
                var warpY = (TileableValueNoise(u, v, 4, textureSeed + 229) - 0.5f)
                    + (TileableValueNoise(u, v, 8, textureSeed + 347) - 0.5f) * 0.38f;
                var warpedU = u + warpX * 0.19f;
                var warpedV = v + warpY * 0.17f;

                var a = TileableValueNoise(warpedU, warpedV, 4, textureSeed + 431) * 0.48f
                    + TileableValueNoise(warpedU, warpedV, 9, textureSeed + 557) * 0.27f
                    + TileableValueNoise(warpedU, warpedV, 18, textureSeed + 683) * 0.16f
                    + TileableValueNoise(warpedU, warpedV, 37, textureSeed + 809) * 0.09f;
                var b = TileableValueNoise(warpedU + 0.31f, warpedV - 0.23f, 5, textureSeed + 947) * 0.46f
                    + TileableValueNoise(warpedU - 0.17f, warpedV + 0.29f, 11, textureSeed + 1061) * 0.28f
                    + TileableValueNoise(warpedU + 0.08f, warpedV + 0.14f, 23, textureSeed + 1187) * 0.17f
                    + TileableValueNoise(warpedU, warpedV, 41, textureSeed + 1301) * 0.09f;
                a = Mathf.SmoothStep(0.08f, 0.92f, a);
                b = Mathf.SmoothStep(0.10f, 0.90f, b);
                var red = (byte)Mathf.RoundToInt(Mathf.Clamp01(a) * 255f);
                var green = (byte)Mathf.RoundToInt(Mathf.Clamp01(b) * 255f);
                var detail = (byte)Mathf.RoundToInt(TileableValueNoise(
                    u, v, 47, textureSeed + 1423) * 255f);
                pixels[y * size + x] = new Color32(red, green, detail, 255);
            }
            texture.SetPixels32(pixels);
            texture.Apply(false, true);
            return texture;
        }

        static float TileableValueNoise(float u, float v, int cells, int noiseSeed)
        {
            var x = Mathf.Repeat(u, 1f) * cells;
            var y = Mathf.Repeat(v, 1f) * cells;
            var floorX = Mathf.FloorToInt(x);
            var floorY = Mathf.FloorToInt(y);
            var x0 = PositiveModulo(floorX, cells);
            var y0 = PositiveModulo(floorY, cells);
            var x1 = (x0 + 1) % cells;
            var y1 = (y0 + 1) % cells;
            var tx = x - floorX;
            var ty = y - floorY;
            tx = tx * tx * (3f - 2f * tx);
            ty = ty * ty * (3f - 2f * ty);
            var bottom = Mathf.Lerp(LatticeNoise(x0, y0, noiseSeed),
                LatticeNoise(x1, y0, noiseSeed), tx);
            var top = Mathf.Lerp(LatticeNoise(x0, y1, noiseSeed),
                LatticeNoise(x1, y1, noiseSeed), tx);
            return Mathf.Lerp(bottom, top, ty);
        }

        static int PositiveModulo(int value, int modulus)
        {
            var result = value % modulus;
            return result < 0 ? result + modulus : result;
        }

        static float LatticeNoise(int x, int y, int noiseSeed)
        {
            unchecked
            {
                uint hash = (uint)(x * 374761393 + y * 668265263 + noiseSeed * 69069);
                hash = (hash ^ (hash >> 13)) * 1274126177u;
                hash ^= hash >> 16;
                return (hash & 0x00ffffffu) / 16777215f;
            }
        }

        Color ApplyLayerTint(Color color, float amount)
        {
            color.r *= Mathf.Lerp(1f, layerTint.r * 1.12f, amount);
            color.g *= Mathf.Lerp(1f, layerTint.g * 1.08f, amount);
            color.b *= Mathf.Lerp(1f, layerTint.b * 1.10f, amount);
            return color;
        }

        static Color ApplyAlpha(Color color, float alpha)
        {
            color.a = Mathf.Clamp01(alpha);
            return color;
        }

        static Color ReadColor(float[] values, Color fallback)
        {
            return values != null && values.Length >= 4
                ? new Color(values[0], values[1], values[2], values[3])
                : fallback;
        }

        static float Ease(float start, float end, float time)
        {
            if (end <= start + 0.0001f)
                return time >= end ? 1f : 0f;
            return Mathf.SmoothStep(0f, 1f, Mathf.Clamp01((time - start) / (end - start)));
        }

        static float Seed01(int value)
        {
            unchecked
            {
                uint hash = (uint)value;
                hash ^= hash >> 16;
                hash *= 0x7feb352du;
                hash ^= hash >> 15;
                hash *= 0x846ca68bu;
                hash ^= hash >> 16;
                return (hash & 0x00ffffffu) / 16777215f;
            }
        }

        void Release()
        {
            if (released)
                return;
            released = true;
            if (effectHandle.enabled && effectHandle.exists)
                effectHandle.Stop();
            effectHandle = new EffekseerHandle(-1);
            coreBatch?.Dispose();
            groundBatch?.Dispose();
            frontBatch?.Dispose();
            blueFireAssetBatch?.Dispose();
            iceFlameAssetBatch?.Dispose();
            windAssetBatch?.Dispose();
            burstAssetBatch?.Dispose();
            mistField?.Dispose();
            glowMistField?.Dispose();
            travelPlumeField?.Dispose();
            frontMistField?.Dispose();
            frontGlowMistField?.Dispose();
            impactCoreMistField?.Dispose();
            impactBurstField?.Dispose();
            crystalField?.Dispose();
            coreBatch = null;
            groundBatch = null;
            frontBatch = null;
            blueFireAssetBatch = null;
            iceFlameAssetBatch = null;
            windAssetBatch = null;
            burstAssetBatch = null;
            mistField = null;
            glowMistField = null;
            travelPlumeField = null;
            frontMistField = null;
            frontGlowMistField = null;
            impactCoreMistField = null;
            impactBurstField = null;
            crystalField = null;
            SpellBackends.DestroyOwned(coreMaterial);
            SpellBackends.DestroyOwned(mistMaterial);
            SpellBackends.DestroyOwned(glowMistMaterial);
            SpellBackends.DestroyOwned(travelPlumeMaterial);
            SpellBackends.DestroyOwned(groundMaterial);
            SpellBackends.DestroyOwned(frontMaterial);
            SpellBackends.DestroyOwned(frontMistMaterial);
            SpellBackends.DestroyOwned(frontGlowMistMaterial);
            SpellBackends.DestroyOwned(impactCoreMistMaterial);
            SpellBackends.DestroyOwned(impactBurstMaterial);
            SpellBackends.DestroyOwned(crystalMaterial);
            SpellBackends.DestroyOwned(blueFireAssetMaterial);
            SpellBackends.DestroyOwned(iceFlameAssetMaterial);
            SpellBackends.DestroyOwned(windAssetMaterial);
            SpellBackends.DestroyOwned(burstAssetMaterial);
            SpellBackends.DestroyOwned(flowTexture);
            coreMaterial = null;
            mistMaterial = null;
            glowMistMaterial = null;
            travelPlumeMaterial = null;
            groundMaterial = null;
            frontMaterial = null;
            frontMistMaterial = null;
            frontGlowMistMaterial = null;
            impactCoreMistMaterial = null;
            impactBurstMaterial = null;
            crystalMaterial = null;
            blueFireAssetMaterial = null;
            iceFlameAssetMaterial = null;
            windAssetMaterial = null;
            burstAssetMaterial = null;
            flowTexture = null;
            effectAsset = null;
        }

        readonly struct Shape
        {
            public Shape(float length, float radius, float turns, float impactProfile)
            {
                Length = length;
                Radius = radius;
                Turns = turns;
                ImpactProfile = impactProfile;
            }

            public float Length { get; }
            public float Radius { get; }
            public float Turns { get; }
            public float ImpactProfile { get; }
        }

        readonly struct ImpactProfile
        {
            public ImpactProfile(
                float heightH,
                float bottomRadiusH,
                float crownRadiusH,
                float turns,
                float liftH)
            {
                HeightH = heightH;
                BottomRadiusH = bottomRadiusH;
                CrownRadiusH = crownRadiusH;
                Turns = turns;
                LiftH = liftH;
            }

            public float HeightH { get; }
            public float BottomRadiusH { get; }
            public float CrownRadiusH { get; }
            public float Turns { get; }
            public float LiftH { get; }

            public static ImpactProfile Lerp(ImpactProfile a, ImpactProfile b, float t)
            {
                return new ImpactProfile(
                    Mathf.Lerp(a.HeightH, b.HeightH, t),
                    Mathf.Lerp(a.BottomRadiusH, b.BottomRadiusH, t),
                    Mathf.Lerp(a.CrownRadiusH, b.CrownRadiusH, t),
                    Mathf.Lerp(a.Turns, b.Turns, t),
                    Mathf.Lerp(a.LiftH, b.LiftH, t));
            }
        }

        readonly struct Frame
        {
            Frame(Vector3 right, Vector3 up, Vector3 forward, Vector3 groundForward)
            {
                CameraRight = right;
                CameraUp = up;
                CameraForward = forward;
                GroundForward = groundForward;
            }

            public Vector3 CameraRight { get; }
            public Vector3 CameraUp { get; }
            public Vector3 CameraForward { get; }
            public Vector3 GroundForward { get; }

            public static Frame From(in SpellSample sample)
            {
                var camera = sample.Camera;
                var right = camera != null ? camera.transform.right : Vector3.right;
                var up = camera != null ? camera.transform.up : Vector3.up;
                var forward = camera != null ? camera.transform.forward : Vector3.forward;
                var groundForward = Vector3.ProjectOnPlane(forward, Vector3.up);
                if (groundForward.sqrMagnitude < 0.001f)
                    groundForward = Vector3.forward;
                return new Frame(right.normalized, up.normalized, forward.normalized, groundForward.normalized);
            }
        }

        /// <summary>
        /// Atlas-smoke funnel used while the spell travels. Positions are
        /// reconstructed from absolute time, so the silhouette rotates
        /// continuously at normal and slow speed without emission stepping.
        /// The volume contains no mesh ribbon, card edge or regular helix.
        /// </summary>
        sealed class TravelPlumeField
        {
            const int ParticleCount = 42;

            readonly DynamicMeshBatch batch;
            readonly float[] heights = new float[ParticleCount];
            readonly float[] angles = new float[ParticleCount];
            readonly float[] radialBias = new float[ParticleCount];
            readonly float[] sizeBias = new float[ParticleCount];
            readonly float[] stretchBias = new float[ParticleCount];
            readonly float[] spinBias = new float[ParticleCount];
            readonly int[] atlasCells = new int[ParticleCount];
            readonly Color[] colors = new Color[ParticleCount];

            public TravelPlumeField(
                Transform parent,
                Material material,
                int sortingOrder,
                uint randomSeed)
            {
                batch = new DynamicMeshBatch(
                    parent,
                    "Continuous organic frost funnel",
                    material,
                    sortingOrder);

                var state = randomSeed == 0 ? 1u : randomSeed;
                for (var index = 0; index < ParticleCount; index++)
                {
                    // Stratification keeps the funnel filled from toe to crown
                    // while the sub-cell jitter avoids visible horizontal rows.
                    heights[index] = Mathf.Repeat(
                        (index + Hash01(ref state) * 0.82f) / ParticleCount,
                        1f);
                    angles[index] = Hash01(ref state) * Mathf.PI * 2f;
                    radialBias[index] = index < 4
                        ? Mathf.Lerp(0.04f, 0.30f, Hash01(ref state))
                        : Mathf.Lerp(0.28f, 1.02f, Hash01(ref state));
                    sizeBias[index] = Mathf.Lerp(0.58f, 1.12f, Hash01(ref state));
                    stretchBias[index] = Mathf.Lerp(1.34f, 2.18f, Hash01(ref state));
                    spinBias[index] = Mathf.Lerp(-34f, 34f, Hash01(ref state));
                    atlasCells[index] = Mathf.Min(3, Mathf.FloorToInt(Hash01(ref state) * 4f));

                    Color palette;
                    switch (index % 12)
                    {
                        case 0:
                        case 1:
                        case 2:
                            palette = Color.Lerp(DeepIce, IceBlue, 0.28f + Hash01(ref state) * 0.20f);
                            break;
                        case 3:
                        case 4:
                        case 5:
                            palette = Color.Lerp(Glacier, MoonCyan, 0.18f + Hash01(ref state) * 0.24f);
                            break;
                        case 6:
                        case 7:
                            palette = Color.Lerp(MysticJade, Glacier, 0.28f + Hash01(ref state) * 0.24f);
                            break;
                        case 8:
                            palette = Color.Lerp(ArcaneIndigo, AuroraViolet, 0.24f);
                            break;
                        case 9:
                            palette = Color.Lerp(AuroraViolet, MoonCyan, 0.22f);
                            break;
                        case 10:
                            palette = Color.Lerp(Frost, IceWhite, 0.18f);
                            break;
                        default:
                            palette = Color.Lerp(PaleGold, WarmWhite, 0.08f);
                            break;
                    }
                    palette.a = index < 9 ? 0.25f : 0.17f;
                    colors[index] = palette;
                }
            }

            public void Sample(
                Vector3 basePosition,
                Vector3 cameraRight,
                Vector3 cameraUp,
                Vector3 cameraForward,
                float length,
                float radius,
                float phase,
                float time,
                float visibility)
            {
                if (batch == null)
                    return;

                batch.Begin();
                if (visibility <= 0.002f)
                {
                    batch.Commit();
                    return;
                }

                for (var index = 0; index < ParticleCount; index++)
                {
                    var s = Mathf.Repeat(heights[index] + time * 0.10f, 1f);
                    var crown = Mathf.Pow(s, 0.68f);
                    var profileRadius = radius * Mathf.Lerp(0.22f, 1.04f, crown);
                    var theta = angles[index]
                        + phase * Mathf.Lerp(0.48f, 0.86f, (index % 7) / 6f)
                        + s * Mathf.PI * 4.35f;
                    var pulse = 1f
                        + 0.12f * Mathf.Sin(time * 7.1f + index * 1.73f)
                        + 0.06f * Mathf.Sin(time * 12.7f - index * 0.91f);
                    var orbitRadius = profileRadius * radialBias[index] * pulse;
                    var point = basePosition
                        + cameraUp * (length * s)
                        + cameraRight * (Mathf.Cos(theta) * orbitRadius)
                        + cameraForward * (Mathf.Sin(theta) * orbitRadius * 0.24f)
                        - cameraForward * (0.030f + 0.006f * (index % 4));

                    var endFade = Ease(0f, 0.055f, s)
                        * (1f - Ease(0.92f, 1f, s));
                    var color = colors[index];
                    color.a *= visibility * endFade;
                    var size = radius
                        * Mathf.Lerp(0.38f, 0.76f, crown)
                        * sizeBias[index];
                    var rotation = theta + spinBias[index] * time * Mathf.Deg2Rad;
                    var axisRight = (cameraRight * Mathf.Cos(rotation)
                        + cameraUp * Mathf.Sin(rotation)).normalized;
                    var axisUp = (-cameraRight * Mathf.Sin(rotation)
                        + cameraUp * Mathf.Cos(rotation)).normalized;
                    batch.AddBillboardQuad(
                        point,
                        axisRight,
                        axisUp,
                        size * Mathf.Lerp(0.50f, 0.72f, Seed01(index + 8401)),
                        size * stretchBias[index],
                        color,
                        atlasCells[index],
                        2,
                        2);
                }

                batch.Commit();
            }

            public void Dispose()
            {
                batch?.Dispose();
            }

            static float Hash01(ref uint state)
            {
                state ^= state << 13;
                state ^= state >> 17;
                state ^= state << 5;
                return (state & 0x00ffffffu) / 16777215f;
            }
        }

        /// <summary>
        /// A deterministic Unity particle volume rebuilt from absolute time.
        /// These are soft mist lobes rather than frame-by-frame emitted cards:
        /// replay, capture and 0.30x slow motion therefore sample the same
        /// continuously rotating field without birth-cadence stepping.
        /// </summary>
        sealed class ProceduralMistField
        {
            readonly Transform owner;
            readonly GameObject root;
            readonly ParticleSystem system;
            readonly ParticleSystemRenderer renderer;
            readonly ParticleSystem.Particle[] particles;
            readonly float[] heights;
            readonly float[] angles;
            readonly float[] radialBias;
            readonly float[] sizeBias;
            readonly Color[] colors;
            readonly int particleCount;
            readonly bool foreground;

            public ProceduralMistField(
                Transform parent,
                Material material,
                int sortingOrder,
                uint randomSeed,
                int count,
                bool isForeground)
            {
                particleCount = Mathf.Max(4, count);
                foreground = isForeground;
                particles = new ParticleSystem.Particle[particleCount];
                heights = new float[particleCount];
                angles = new float[particleCount];
                radialBias = new float[particleCount];
                sizeBias = new float[particleCount];
                colors = new Color[particleCount];
                owner = parent;
                root = new GameObject("Continuous frost mist volume");
                root.transform.SetParent(parent, false);
                system = root.AddComponent<ParticleSystem>();

                var main = system.main;
                main.loop = false;
                main.playOnAwake = false;
                main.simulationSpace = ParticleSystemSimulationSpace.Local;
                main.maxParticles = particleCount;
                main.startLifetime = 1000f;
                main.startSpeed = 0f;
                main.startSize = 1f;
                main.startSize3D = true;
                main.startRotation3D = true;
                main.startSize3D = true;
                main.startRotation3D = true;

                var emission = system.emission;
                emission.enabled = false;
                var shape = system.shape;
                shape.enabled = false;

                renderer = root.GetComponent<ParticleSystemRenderer>();
                renderer.renderMode = ParticleSystemRenderMode.Billboard;
                renderer.alignment = ParticleSystemRenderSpace.View;
                renderer.sharedMaterial = material;
                renderer.sortingOrder = sortingOrder;
                renderer.enabled = false;

                var state = randomSeed == 0 ? 1u : randomSeed;
                for (var index = 0; index < particleCount; index++)
                {
                    heights[index] = Hash01(ref state);
                    angles[index] = Hash01(ref state) * Mathf.PI * 2f;
                    radialBias[index] = isForeground
                        ? Mathf.Lerp(0.045f, 0.98f, Hash01(ref state))
                        : Mathf.Lerp(0.16f, 1.00f, Hash01(ref state));
                    sizeBias[index] = isForeground
                        ? Mathf.Lerp(0.76f, 1.38f, Hash01(ref state))
                        : Mathf.Lerp(0.82f, 1.46f, Hash01(ref state));
                    var backColor = Color.Lerp(
                        new Color(0.018f, 0.16f, 0.25f, 0.58f),
                        new Color(0.10f, 0.62f, 0.78f, 0.72f),
                        Hash01(ref state));
                    colors[index] = isForeground
                        ? index % 17 == 0
                            ? Color.Lerp(PaleGold, IceWhite, 0.38f)
                            : index % 11 == 0
                                ? Color.Lerp(AuroraViolet, AuroraRose, Hash01(ref state) * 0.46f)
                            : index % 5 == 0
                                ? Color.Lerp(
                                    new Color(0.06f, 0.58f, 0.43f, 0.88f),
                                    new Color(0.42f, 1.00f, 0.78f, 0.96f),
                                    Hash01(ref state))
                                : Color.Lerp(
                                    new Color(0.025f, 0.30f, 0.58f, 0.82f),
                                    new Color(0.50f, 0.94f, 1.00f, 0.96f),
                                    Hash01(ref state))
                        : backColor;
                }
            }

            public void Sample(
                Vector3 basePosition,
                Quaternion orientation,
                Shape shape,
                float phase,
                float visibility,
                Vector3 cameraForward,
                float time)
            {
                if (system == null)
                    return;

                var axis = orientation * Vector3.up;
                var basisX = orientation * Vector3.right;
                var basisZ = orientation * Vector3.forward;
                var impact = shape.ImpactProfile;
                for (var index = 0; index < particleCount; index++)
                {
                    var s = Mathf.Repeat(heights[index] + time * Mathf.Lerp(0.24f, 0.42f, impact), 1f);
                    var flightRadius = 1f - 0.62f * s;
                    var impactRadius = 0.30f + 0.70f * s;
                    var profile = Mathf.Lerp(flightRadius, impactRadius, impact);
                    var wobble = 1f
                        + 0.15f * Mathf.Sin(s * 19.3f + time * 4.7f + angles[index])
                        + 0.07f * Mathf.Sin(s * 37.1f - time * 2.9f + index);
                    var theta = angles[index]
                        + phase * Mathf.Lerp(0.74f, 1.06f, (index % 5) / 4f)
                        + s * Mathf.PI * 2f * Mathf.Lerp(0.86f, 1.44f, impact);
                    var radius = shape.Radius * profile * radialBias[index] * wobble;
                    var point = basePosition
                        + axis * (shape.Length * s)
                        + basisX * (Mathf.Cos(theta) * radius)
                        + basisZ * (Mathf.Sin(theta) * radius)
                        - cameraForward * (foreground ? 0.075f + 0.008f * (index % 3) : 0.015f * (index % 3));

                    var edgeFade = Ease(0f, 0.06f, s)
                        * (1f - Ease(0.90f, 1f, s));
                    var color = colors[index];
                    color.a *= visibility * edgeFade
                        * Mathf.Lerp(0.94f, foreground ? 1.88f : 1.42f, impact);
                    var size = shape.Radius
                        * Mathf.Lerp(foreground ? 0.46f : 0.44f,
                            foreground ? 0.70f : 0.62f,
                            impact)
                        * sizeBias[index];
                    var stretch = foreground
                        ? Mathf.Lerp(0.88f, 1.42f, impact)
                            * Mathf.Lerp(0.82f, 1.18f, Seed01(index + 5101))
                        : Mathf.Lerp(0.84f, 1.22f, impact);
                    particles[index] = new ParticleSystem.Particle
                    {
                        position = owner.InverseTransformPoint(point),
                        startColor = color,
                        startSize3D = new Vector3(size * 0.78f, size * stretch, size),
                        rotation = (angles[index] + time * 1.7f) * Mathf.Rad2Deg,
                        startLifetime = 1000f,
                        remainingLifetime = 999f
                    };
                }
                system.SetParticles(particles, particleCount);
                if (renderer != null)
                    renderer.enabled = visibility > 0.002f;
            }

            public void Dispose()
            {
                if (system != null)
                    system.Clear(true);
                if (root != null)
                    SpellBackends.DestroyOwned(root);
            }

            static float Hash01(ref uint state)
            {
                state ^= state << 13;
                state ^= state >> 17;
                state ^= state << 5;
                return (state & 0x00ffffffu) / 16777215f;
            }
        }

        /// <summary>
        /// Deterministic atlas-plume detonation. The body is reconstructed from
        /// four photographed smoke silhouettes and three separately timed
        /// pressure waves: compressed contact, dense engulfment, then scatter.
        /// No generated billboard uses a geometric wedge, ribbon or hard ring.
        /// </summary>
        sealed class ImpactBurstField
        {
            const int ParticleCount = 16;
            const int CoreCount = 5;
            const int PrimaryCount = 12;

            readonly Transform owner;
            readonly GameObject root;
            readonly ParticleSystem system;
            readonly ParticleSystemRenderer renderer;
            readonly ParticleSystem.Particle[] particles = new ParticleSystem.Particle[ParticleCount];
            readonly float[] birthTimes = new float[ParticleCount];
            readonly float[] angles = new float[ParticleCount];
            readonly float[] speeds = new float[ParticleCount];
            readonly float[] bends = new float[ParticleCount];
            readonly float[] lifts = new float[ParticleCount];
            readonly float[] lifetimes = new float[ParticleCount];
            readonly float[] sizes = new float[ParticleCount];
            readonly float[] stretches = new float[ParticleCount];
            readonly float[] spins = new float[ParticleCount];
            readonly float[] spawnRadii = new float[ParticleCount];
            readonly float[] spawnHeights = new float[ParticleCount];
            readonly Color[] colors = new Color[ParticleCount];

            public ImpactBurstField(
                Transform parent,
                Material material,
                int sortingOrder,
                uint randomSeed)
            {
                owner = parent;
                root = new GameObject("Deterministic frost pressure detonation");
                root.transform.SetParent(parent, false);
                system = root.AddComponent<ParticleSystem>();

                var main = system.main;
                main.loop = false;
                main.playOnAwake = false;
                main.simulationSpace = ParticleSystemSimulationSpace.Local;
                main.maxParticles = ParticleCount;
                main.startLifetime = 1000f;
                main.startSpeed = 0f;
                main.startSize = 1f;
                main.startSize3D = true;

                var emission = system.emission;
                emission.enabled = false;
                var shape = system.shape;
                shape.enabled = false;

                var textureSheet = system.textureSheetAnimation;
                textureSheet.enabled = false;

                renderer = root.GetComponent<ParticleSystemRenderer>();
                renderer.renderMode = ParticleSystemRenderMode.Billboard;
                renderer.alignment = ParticleSystemRenderSpace.View;
                renderer.sharedMaterial = material;
                renderer.sortingOrder = sortingOrder;
                renderer.enabled = false;

                var state = randomSeed == 0 ? 1u : randomSeed;
                for (var index = 0; index < ParticleCount; index++)
                {
                    var inner = index < CoreCount;
                    var primary = index < PrimaryCount;
                    birthTimes[index] = inner
                        ? Mathf.Lerp(ContactTime - 0.006f, 0.825f, Hash01(ref state))
                        : primary
                            ? Mathf.Lerp(0.985f, 1.105f, Hash01(ref state))
                            : Mathf.Lerp(1.280f, 1.380f, Hash01(ref state));
                    angles[index] = Hash01(ref state) * Mathf.PI * 2f
                        + (index % 7) * 0.071f;
                    speeds[index] = inner
                        ? Mathf.Lerp(0.04f, 0.26f, Hash01(ref state))
                        : primary
                            ? Mathf.Lerp(0.62f, 1.48f, Hash01(ref state))
                            : Mathf.Lerp(2.00f, 3.40f, Hash01(ref state));
                    bends[index] = inner
                        ? Mathf.Lerp(-0.18f, 0.18f, Hash01(ref state))
                        : primary
                            ? Mathf.Lerp(-0.42f, 0.42f, Hash01(ref state))
                            : Mathf.Lerp(-0.68f, 0.68f, Hash01(ref state));
                    lifts[index] = inner
                        ? Mathf.Lerp(-0.08f, 0.20f, Hash01(ref state))
                        : primary
                            ? Mathf.Lerp(-0.22f, 0.58f, Hash01(ref state))
                            : Mathf.Lerp(-0.18f, 0.94f, Hash01(ref state));
                    lifetimes[index] = inner
                        ? Mathf.Lerp(0.55f, 0.78f, Hash01(ref state))
                        : primary
                            ? Mathf.Lerp(0.78f, 1.06f, Hash01(ref state))
                            : Mathf.Lerp(0.66f, 0.92f, Hash01(ref state));
                    sizes[index] = inner
                        ? Mathf.Lerp(0.105f, 0.210f, Hash01(ref state))
                        : primary
                            ? Mathf.Lerp(0.145f, 0.310f, Hash01(ref state))
                            : Mathf.Lerp(0.044f, 0.094f, Hash01(ref state));
                    stretches[index] = inner
                        ? Mathf.Lerp(0.84f, 1.16f, Hash01(ref state))
                        : primary
                            ? Mathf.Lerp(0.76f, 1.28f, Hash01(ref state))
                            : Mathf.Lerp(0.72f, 1.24f, Hash01(ref state));
                    spins[index] = Mathf.Lerp(-190f, 190f, Hash01(ref state));
                    spawnRadii[index] = inner
                        ? Mathf.Lerp(0.006f, 0.095f, Hash01(ref state))
                        : primary
                            ? Mathf.Lerp(0.018f, 0.205f, Hash01(ref state))
                            : Mathf.Lerp(0.180f, 0.400f, Hash01(ref state));
                    spawnHeights[index] = inner
                        ? Mathf.Lerp(-0.18f, 0.18f, Hash01(ref state))
                        : primary
                            ? Mathf.Lerp(-0.34f, 0.34f, Hash01(ref state))
                            : Mathf.Lerp(-0.30f, 0.42f, Hash01(ref state));

                    Color palette;
                    switch (index % 12)
                    {
                        case 0:
                        case 1:
                            palette = Color.Lerp(InkJade, Emerald, 0.35f + Hash01(ref state) * 0.28f);
                            break;
                        case 2:
                        case 3:
                            palette = Color.Lerp(Emerald, IceCyan, 0.34f + Hash01(ref state) * 0.36f);
                            break;
                        case 4:
                        case 5:
                            palette = Color.Lerp(IceCyan, JadeWhitePro, 0.22f + Hash01(ref state) * 0.34f);
                            break;
                        default:
                            palette = Color.Lerp(InkJade, IceCyan, 0.42f + Hash01(ref state) * 0.22f);
                            break;
                    }
                    palette.a = inner ? 0.94f : primary ? 0.78f : 0.64f;
                    colors[index] = palette;
                }
            }

            public void Sample(
                Vector3 origin,
                Vector3 cameraRight,
                Vector3 cameraUp,
                Vector3 cameraForward,
                float time,
                float actorHeight,
                float visibility)
            {
                if (system == null)
                    return;

                var activeCount = 0;
                for (var index = 0; index < ParticleCount; index++)
                {
                    var inner = index < CoreCount;
                    var primary = index < PrimaryCount;
                    var age = time - birthTimes[index];
                    var life = lifetimes[index];
                    if (age < 0f || age >= life)
                        continue;

                    var normalizedAge = age / life;
                    var direction = (cameraRight * Mathf.Cos(angles[index])
                        + cameraUp * Mathf.Sin(angles[index])).normalized;
                    var tangent = (-cameraRight * Mathf.Sin(angles[index])
                        + cameraUp * Mathf.Cos(angles[index])).normalized;
                    var drag = inner ? 3.10f : primary ? 1.82f : 0.94f;
                    var distance = speeds[index] * actorHeight
                        * ((1f - Mathf.Exp(-drag * age)) / drag);
                    if (!primary)
                        distance *= Mathf.Lerp(0.88f, 1.46f, normalizedAge);
                    var curl = tangent * (actorHeight * bends[index]
                        * age * Mathf.Lerp(0.42f, 1.08f, normalizedAge));
                    var lift = cameraUp * (actorHeight * lifts[index] * age);
                    var outward = primary ? Vector3.zero : direction
                        * (actorHeight * 0.09f * Ease(0.18f, 1f, normalizedAge));
                    var point = origin
                        + direction * (distance + actorHeight * spawnRadii[index])
                        + cameraUp * (actorHeight * spawnHeights[index])
                        + curl + lift + outward
                        - cameraForward * (actorHeight * (0.070f + 0.012f * (index % 4)));

                    var fade = Ease(0f, inner ? 0.040f : primary ? 0.070f : 0.055f, normalizedAge)
                        * (1f - Ease(inner ? 0.82f : primary ? 0.76f : 0.80f, 1f, normalizedAge));
                    var beatEnvelope = inner
                        ? 1f - Ease(0.950f, 1.060f, time)
                        : primary
                            ? 1f - Ease(1.380f, 1.540f, time)
                            : Ease(1.340f, 1.470f, time);
                    var color = colors[index];
                    color.a *= visibility * fade * beatEnvelope;
                    var sizeGrowth = inner
                        ? Mathf.Lerp(0.54f, 1.20f, Ease(0f, 0.18f, normalizedAge))
                        : primary
                            ? Mathf.Lerp(0.46f, 1.26f, Ease(0f, 0.24f, normalizedAge))
                            : Mathf.Lerp(0.92f, 0.72f, Ease(0.28f, 1f, normalizedAge));
                    var size = sizes[index] * actorHeight * sizeGrowth;
                    particles[activeCount++] = new ParticleSystem.Particle
                    {
                        position = owner.InverseTransformPoint(point),
                        startColor = color,
                        startSize3D = new Vector3(
                            size * Mathf.Lerp(0.70f, 1.08f, Seed01(index + 701)),
                            size * stretches[index],
                            size),
                        rotation = angles[index] * Mathf.Rad2Deg - 90f
                            + spins[index] * age,
                        randomSeed = unchecked((uint)index * 2654435761u + 101u),
                        startLifetime = 1000f,
                        remainingLifetime = 999f
                    };
                }

                system.SetParticles(particles, activeCount);
                renderer.enabled = activeCount > 0 && visibility > 0.002f;
            }

            public void Dispose()
            {
                if (system != null)
                    system.Clear(true);
                if (root != null)
                    SpellBackends.DestroyOwned(root);
            }

            static float Hash01(ref uint state)
            {
                state ^= state << 13;
                state ^= state >> 17;
                state ^= state << 5;
                return (state & 0x00ffffffu) / 16777215f;
            }
        }

        /// <summary>
        /// One deterministic mesh-particle draw call supplies all high-value
        /// ice facets. Particles are reconstructed from absolute spell time,
        /// so replay and 0.30x inspection cannot expose emission stepping.
        /// </summary>
        sealed class CrystalParticleField
        {
            // Five large, seven medium and four micro crystals.  The old 64
            // particle cloud read as a second snowstorm and kept the late
            // frame full of unrelated colored cards.
            const int ParticleCount = 16;

            readonly Transform owner;
            readonly GameObject root;
            readonly ParticleSystem system;
            readonly ParticleSystemRenderer renderer;
            readonly ParticleSystem.Particle[] particles = new ParticleSystem.Particle[ParticleCount];
            readonly float[] birthTimes = new float[ParticleCount];
            readonly float[] angles = new float[ParticleCount];
            readonly float[] radialSpeeds = new float[ParticleCount];
            readonly float[] tangentSpeeds = new float[ParticleCount];
            readonly float[] liftSpeeds = new float[ParticleCount];
            readonly float[] lifetimes = new float[ParticleCount];
            readonly float[] sizes = new float[ParticleCount];
            readonly float[] spinSpeeds = new float[ParticleCount];
            readonly float[] tilts = new float[ParticleCount];
            readonly Color[] colors = new Color[ParticleCount];

            public CrystalParticleField(
                Transform parent,
                Material material,
                int sortingOrder,
                uint randomSeed)
            {
                owner = parent;
                root = new GameObject("Deterministic faceted ice crystals");
                root.transform.SetParent(parent, false);
                system = root.AddComponent<ParticleSystem>();

                var main = system.main;
                main.loop = false;
                main.playOnAwake = false;
                main.simulationSpace = ParticleSystemSimulationSpace.Local;
                main.maxParticles = ParticleCount;
                main.startLifetime = 1000f;
                main.startSpeed = 0f;
                main.startSize = 1f;
                main.startSize3D = true;

                var emission = system.emission;
                emission.enabled = false;
                var shape = system.shape;
                shape.enabled = false;

                renderer = root.GetComponent<ParticleSystemRenderer>();
                renderer.renderMode = ParticleSystemRenderMode.Billboard;
                renderer.alignment = ParticleSystemRenderSpace.View;
                renderer.sharedMaterial = material;
                renderer.sortingOrder = sortingOrder;
                renderer.enabled = false;

                var state = randomSeed == 0 ? 1u : randomSeed;
                for (var index = 0; index < ParticleCount; index++)
                {
                    var group = GroupOf(index);
                    var rawAngle = Hash01(ref state) * Mathf.PI * 2f;
                    angles[index] = rawAngle + (index % 5) * 0.083f;
                    birthTimes[index] = group == 0
                        ? Mathf.Lerp(0.795f, 0.825f, Hash01(ref state))
                        : group == 1
                            ? Mathf.Lerp(0.850f, 0.900f, Hash01(ref state))
                            : group == 2
                                ? Mathf.Lerp(1.000f, 1.080f, Hash01(ref state))
                                : Mathf.Lerp(1.355f, 1.435f, Hash01(ref state));
                    var totalSpeed = group == 0
                        ? Mathf.Lerp(0.75f, 1.25f, Hash01(ref state))
                        : group == 1
                            ? Mathf.Lerp(0.90f, 1.50f, Hash01(ref state))
                            : Mathf.Lerp(0.18f, 0.40f, Hash01(ref state));
                    radialSpeeds[index] = totalSpeed * (group == 0
                        ? 0.76f
                        : group == 1 ? 0.68f : 0.34f);
                    tangentSpeeds[index] = totalSpeed * (group == 2
                        ? 0.42f
                        : 0.28f)
                        * (Hash01(ref state) > 0.5f ? 1f : -1f);
                    liftSpeeds[index] = group == 2
                        ? Mathf.Lerp(0.18f, 0.40f, Hash01(ref state))
                        : totalSpeed * 0.12f + Mathf.Lerp(0.04f, 0.10f, Hash01(ref state));
                    lifetimes[index] = group == 0
                        ? Mathf.Lerp(0.30f, 0.48f, Hash01(ref state))
                        : group == 1
                            ? Mathf.Lerp(0.32f, 0.56f, Hash01(ref state))
                            : Mathf.Lerp(0.48f, 0.76f, Hash01(ref state));
                    sizes[index] = group == 0
                        ? Mathf.Lerp(0.028f, 0.060f, Hash01(ref state))
                        : group == 1
                            ? Mathf.Lerp(0.013f, 0.032f, Hash01(ref state))
                            : Mathf.Lerp(0.005f, 0.012f, Hash01(ref state));
                    spinSpeeds[index] = Mathf.Lerp(720f, 1440f, Hash01(ref state))
                        * (Hash01(ref state) > 0.5f ? 1f : -1f);
                    tilts[index] = Mathf.Lerp(-72f, 72f, Hash01(ref state));
                    colors[index] = group == 0
                        ? Color.Lerp(Emerald, IceCyan, 0.35f + Hash01(ref state) * 0.45f)
                        : group == 1
                            ? Color.Lerp(IceCyan, JadeWhitePro, 0.18f + Hash01(ref state) * 0.48f)
                            : Color.Lerp(InkJade, IceCyan, 0.42f + Hash01(ref state) * 0.34f);
                    colors[index].a = group == 2 ? 0.56f : 0.68f;
                }
            }

            public void Sample(
                Vector3 origin,
                Vector3 cameraRight,
                Vector3 cameraUp,
                Vector3 cameraForward,
                float time,
                float actorHeight)
            {
                if (system == null)
                    return;

                var activeCount = 0;
                for (var index = 0; index < ParticleCount; index++)
                {
                    var group = GroupOf(index);
                    var age = time - birthTimes[index];
                    var life = lifetimes[index];
                    if (age < 0f || age >= life)
                        continue;

                    var normalizedAge = age / life;
                    var drag = group == 3
                        ? Mathf.Lerp(0.64f, 0.86f, Seed01(index * 197 + 41))
                        : Mathf.Lerp(0.90f, 1.30f, Seed01(index * 197 + 41));
                    var easedDistance = (1f - Mathf.Exp(-drag * age)) / drag;
                    var radial = cameraRight * Mathf.Cos(angles[index])
                        + cameraForward * Mathf.Sin(angles[index]);
                    var tangent = Vector3.Cross(cameraUp, radial).normalized;
                    var distance = radialSpeeds[index] * actorHeight * easedDistance;
                    var tangentDistance = tangentSpeeds[index] * actorHeight * easedDistance;
                    var gravity = group == 0
                        ? -0.12f
                        : group == 1 ? -0.08f : group == 3 ? -0.04f : 0.03f;
                    var height = liftSpeeds[index] * actorHeight * age
                        + 0.5f * gravity * actorHeight * age * age;
                    var groupOffset = group == 0
                        ? cameraUp * (actorHeight * Mathf.Lerp(0.10f, 0.28f, Seed01(index + 811)))
                        : group == 1
                            ? cameraUp * (actorHeight * Mathf.Lerp(0.06f, 0.18f, Seed01(index + 887)))
                            : group == 2
                                ? cameraUp * (actorHeight * Mathf.Lerp(0.16f, 0.38f, Seed01(index + 977)))
                                : cameraUp * (actorHeight * Mathf.Lerp(0.40f, 0.62f, Seed01(index + 1031)));
                    var point = origin + groupOffset + radial * distance + tangent * tangentDistance;
                    var fade = Ease(0f, group == 2 ? 0.045f : group == 3 ? 0.025f : 0.030f, normalizedAge)
                        * (1f - Ease(group == 2 ? 0.68f : group == 3 ? 0.78f : 0.72f, 1f, normalizedAge));
                    var color = colors[index];
                    color.a *= fade;
                    var size = sizes[index] * actorHeight
                        * Mathf.Lerp(0.90f, 0.68f, Ease(0.30f, 1f, normalizedAge));
                    particles[activeCount++] = new ParticleSystem.Particle
                    {
                        position = owner.InverseTransformPoint(point),
                        startColor = color,
                        startSize3D = new Vector3(
                            size * Mathf.Lerp(0.82f, 1.12f, Seed01(index + 61)),
                            size * Mathf.Lerp(0.88f, 1.24f, Seed01(index + 121)),
                            size),
                        rotation = tilts[index] + spinSpeeds[index] * age,
                        startLifetime = 1000f,
                        remainingLifetime = 999f
                    };
                }

                system.SetParticles(particles, activeCount);
                renderer.enabled = activeCount > 0;
            }

            public void Dispose()
            {
                if (system != null)
                    system.Clear(true);
                if (root != null)
                    SpellBackends.DestroyOwned(root);
            }

            static int GroupOf(int index) => index < 5 ? 0 : index < 12 ? 1 : 2;

            static float Hash01(ref uint state)
            {
                state ^= state << 13;
                state ^= state >> 17;
                state ^= state << 5;
                return (state & 0x00ffffffu) / 16777215f;
            }
        }

        /// <summary>
        /// Quad-only batch for mature Effekseer textures. TEXCOORD0 selects a
        /// source crop while TEXCOORD1 preserves the local 0..1 card domain for
        /// edge erosion and UV flow. This is what lets one source texture form
        /// several independently moving organic layers without looking like a
        /// translated static image.
        /// </summary>
        sealed class AssetQuadBatch
        {
            readonly Transform owner;
            readonly GameObject root;
            readonly Mesh mesh;
            readonly MeshRenderer renderer;
            readonly List<Vector3> vertices = new(40);
            readonly List<Color> colors = new(40);
            readonly List<Vector2> sourceUvs = new(40);
            readonly List<Vector3> localUvs = new(40);
            readonly List<int> triangles = new(60);

            public AssetQuadBatch(
                Transform parent,
                string name,
                Material material,
                int sortingOrder)
            {
                owner = parent;
                root = new GameObject(name);
                root.transform.SetParent(parent, false);
                var filter = root.AddComponent<MeshFilter>();
                renderer = root.AddComponent<MeshRenderer>();
                mesh = new Mesh
                {
                    name = name,
                    hideFlags = HideFlags.DontSave,
                    indexFormat = IndexFormat.UInt16
                };
                mesh.MarkDynamic();
                filter.sharedMesh = mesh;
                renderer.sharedMaterial = material;
                renderer.sortingOrder = sortingOrder;
                renderer.enabled = false;
            }

            public void Begin()
            {
                vertices.Clear();
                colors.Clear();
                sourceUvs.Clear();
                localUvs.Clear();
                triangles.Clear();
            }

            public void AddQuad(
                Vector3 center,
                Vector3 cameraRight,
                Vector3 cameraUp,
                float width,
                float height,
                float rotationDegrees,
                Color color,
                Rect sourceCrop,
                bool flipX,
                bool flipY)
            {
                if (color.a <= 0.001f || width <= 0.001f || height <= 0.001f)
                    return;

                var angle = rotationDegrees * Mathf.Deg2Rad;
                var right = (cameraRight * Mathf.Cos(angle)
                    + cameraUp * Mathf.Sin(angle)).normalized * (width * 0.5f);
                var up = (-cameraRight * Mathf.Sin(angle)
                    + cameraUp * Mathf.Cos(angle)).normalized * (height * 0.5f);
                var baseVertex = vertices.Count;
                vertices.Add(owner.InverseTransformPoint(center - right - up));
                vertices.Add(owner.InverseTransformPoint(center + right - up));
                vertices.Add(owner.InverseTransformPoint(center - right + up));
                vertices.Add(owner.InverseTransformPoint(center + right + up));
                colors.Add(color);
                colors.Add(color);
                colors.Add(color);
                colors.Add(color);

                var left = flipX ? sourceCrop.xMax : sourceCrop.xMin;
                var rightUv = flipX ? sourceCrop.xMin : sourceCrop.xMax;
                var bottom = flipY ? sourceCrop.yMax : sourceCrop.yMin;
                var top = flipY ? sourceCrop.yMin : sourceCrop.yMax;
                sourceUvs.Add(new Vector2(left, bottom));
                sourceUvs.Add(new Vector2(rightUv, bottom));
                sourceUvs.Add(new Vector2(left, top));
                sourceUvs.Add(new Vector2(rightUv, top));
                localUvs.Add(new Vector3(0f, 0f, 1f));
                localUvs.Add(new Vector3(1f, 0f, 1f));
                localUvs.Add(new Vector3(0f, 1f, 1f));
                localUvs.Add(new Vector3(1f, 1f, 1f));
                triangles.Add(baseVertex);
                triangles.Add(baseVertex + 2);
                triangles.Add(baseVertex + 1);
                triangles.Add(baseVertex + 1);
                triangles.Add(baseVertex + 2);
                triangles.Add(baseVertex + 3);
            }

            /// <summary>
            /// A single connected, open surface with a narrow toe, tight waist
            /// and torn crown.  It reuses the mature atlas through cropped UVs
            /// but never exposes the source rectangle as a billboard.  The
            /// caller can swap the axis basis to make the same surface serve
            /// as the horizontal impact shell or the upright tornado funnel.
            /// </summary>
            public void AddOpenFunnelSurface(
                Vector3 baseCenter,
                Vector3 radialRight,
                Vector3 axisUp,
                Vector3 cameraForward,
                float height,
                float baseRadius,
                float waistRadius,
                float crownRadius,
                float waistAt,
                float depthScale,
                float angularCoverage,
                float phase,
                int rings,
                int sides,
                Rect sourceCrop,
                float uvPhase,
                Color baseColor,
                Color waistColor,
                Color crownColor,
                float time,
                float seed01)
            {
                if (rings < 3 || sides < 4 || height <= 0.001f
                    || Mathf.Max(baseRadius, Mathf.Max(waistRadius, crownRadius)) <= 0.001f
                    || Mathf.Max(baseColor.a, Mathf.Max(waistColor.a, crownColor.a)) <= 0.001f)
                    return;

                waistAt = Mathf.Clamp(waistAt, 0.20f, 0.80f);
                var baseVertex = vertices.Count;
                for (var ring = 0; ring < rings; ring++)
                {
                    var s = ring / (rings - 1f);
                    float profile;
                    Color color;
                    if (s <= waistAt)
                    {
                        var lower = Mathf.SmoothStep(0f, 1f, s / waistAt);
                        profile = Mathf.Lerp(baseRadius, waistRadius, lower);
                        color = Color.Lerp(baseColor, waistColor, lower);
                    }
                    else
                    {
                        var upper = Mathf.SmoothStep(0f, 1f, (s - waistAt) / (1f - waistAt));
                        profile = Mathf.Lerp(waistRadius, crownRadius, upper);
                        color = Color.Lerp(waistColor, crownColor, upper);
                    }

                    var drift = radialRight * (
                            Mathf.Sin(s * 5.4f + seed01 * 8.1f + time * 1.8f)
                            * crownRadius * 0.10f)
                        + cameraForward * (
                            Mathf.Cos(s * 4.1f - seed01 * 5.4f - time * 1.3f)
                            * crownRadius * 0.045f);
                    for (var side = 0; side < sides; side++)
                    {
                        var t = side / (sides - 1f);
                        var sideCoord = t * 2f - 1f;
                        var edgeWarp = Mathf.Sin(
                                s * 9.7f + t * 7.1f + seed01 * 13.2f + time * 2.0f) * 0.065f
                            + Mathf.Sin(s * 23.1f - t * 11.7f - time * 1.4f) * 0.028f;
                        var angle = phase
                            + sideCoord * angularCoverage * 0.5f
                            + Mathf.Sin(s * 2.2f + time * 0.8f) * 0.10f
                            + edgeWarp;
                        var radialNoise = 1f
                            + Mathf.Sin(s * 13.4f + t * 6.7f + seed01 * 11.1f + time * 1.9f) * 0.075f
                            + Mathf.Sin(s * 29.3f - t * 8.3f - time * 2.4f) * 0.032f;
                        var radius = profile * radialNoise;
                        var tear = Mathf.SmoothStep(0.68f, 1f, s) * height * (
                            Mathf.Sin(t * 8.9f + seed01 * 12.7f + time * 1.6f) * 0.055f
                            + Mathf.Sin(t * 19.1f - seed01 * 6.9f - time * 1.1f) * 0.025f);
                        var point = baseCenter
                            + axisUp * (height * s + tear)
                            + drift
                            + radialRight * (Mathf.Sin(angle) * radius)
                            - cameraForward * (
                                Mathf.Cos(angle) * radius * depthScale
                                + Mathf.Max(0.004f, crownRadius) * 0.055f);

                        var edgeEnvelope = Mathf.Pow(Mathf.Sin(Mathf.PI * t), 0.58f);
                        color.a *= Mathf.Lerp(0.62f, 1f, edgeEnvelope)
                            * Mathf.SmoothStep(0f, 0.045f, s)
                            * (1f - Mathf.SmoothStep(0.945f, 1f, s));
                        vertices.Add(owner.InverseTransformPoint(point));
                        colors.Add(color);
                        var sourceU = sourceCrop.xMin + sourceCrop.width * Mathf.Repeat(
                            t + uvPhase + Mathf.Sin(s * 4.1f + seed01) * 0.035f, 1f);
                        var sourceV = sourceCrop.yMin + sourceCrop.height * Mathf.Repeat(
                            s + uvPhase * 0.17f + Mathf.Sin(t * 3.7f + time) * 0.025f, 1f);
                        sourceUvs.Add(new Vector2(sourceU, sourceV));
                        localUvs.Add(new Vector3(Mathf.Repeat(t + uvPhase, 1f), s, 1f));
                    }
                }

                for (var ring = 0; ring < rings - 1; ring++)
                {
                    for (var side = 0; side < sides - 1; side++)
                    {
                        var a = baseVertex + ring * sides + side;
                        var b = a + 1;
                        var c = a + sides;
                        var d = c + 1;
                        triangles.Add(a);
                        triangles.Add(c);
                        triangles.Add(b);
                        triangles.Add(b);
                        triangles.Add(c);
                        triangles.Add(d);
                    }
                }
            }

            public void Commit()
            {
                mesh.Clear(false);
                if (vertices.Count < 4)
                {
                    renderer.enabled = false;
                    return;
                }
                mesh.SetVertices(vertices);
                mesh.SetColors(colors);
                mesh.SetUVs(0, sourceUvs);
                mesh.SetUVs(1, localUvs);
                mesh.SetTriangles(triangles, 0, false);
                mesh.bounds = new Bounds(Vector3.zero, Vector3.one * 8f);
                renderer.enabled = true;
            }

            public void Dispose()
            {
                if (root != null)
                    SpellBackends.DestroyOwned(root);
                if (mesh != null)
                    SpellBackends.DestroyOwned(mesh);
            }
        }

        sealed class DynamicMeshBatch
        {
            readonly Transform owner;
            readonly GameObject root;
            readonly Mesh mesh;
            readonly MeshRenderer renderer;
            readonly List<Vector3> vertices = new(420);
            readonly List<Color> colors = new(420);
            readonly List<Vector2> uvs = new(420);
            readonly List<int> triangles = new(900);

            public DynamicMeshBatch(Transform parent, string name, Material material, int sortingOrder)
            {
                owner = parent;
                root = new GameObject(name);
                root.transform.SetParent(parent, false);
                var filter = root.AddComponent<MeshFilter>();
                renderer = root.AddComponent<MeshRenderer>();
                mesh = new Mesh
                {
                    name = name,
                    hideFlags = HideFlags.DontSave,
                    indexFormat = IndexFormat.UInt16
                };
                mesh.MarkDynamic();
                filter.sharedMesh = mesh;
                renderer.sharedMaterial = material;
                renderer.sortingOrder = sortingOrder;
                renderer.enabled = false;
            }

            public void Begin()
            {
                vertices.Clear();
                colors.Clear();
                uvs.Clear();
                triangles.Clear();
            }

            public void AddHelixStrip(
                Vector3 basePosition,
                Quaternion orientation,
                float length,
                float radius,
                float turns,
                float phase,
                float phaseOffset,
                int sampleCount,
                float widthMin,
                float widthMax,
                float impactProfile,
                Color color,
                Vector3 cameraForward,
                float time,
                float seed01)
            {
                if (sampleCount < 2 || color.a <= 0.001f)
                    return;
                var baseVertex = vertices.Count;
                var step = 1f / (sampleCount - 1f);
                for (var index = 0; index < sampleCount; index++)
                {
                    var s = index * step;
                    var previous = HelixPoint(
                        Mathf.Max(0f, s - step), basePosition, orientation, length, radius,
                        turns, phase, phaseOffset, impactProfile, time, seed01);
                    var next = HelixPoint(
                        Mathf.Min(1f, s + step), basePosition, orientation, length, radius,
                        turns, phase, phaseOffset, impactProfile, time, seed01);
                    var point = HelixPoint(
                        s, basePosition, orientation, length, radius,
                        turns, phase, phaseOffset, impactProfile, time, seed01);
                    var tangent = next - previous;
                    if (tangent.sqrMagnitude < 0.000001f)
                        tangent = orientation * Vector3.up;
                    tangent.Normalize();
                    var across = Vector3.Cross(cameraForward, tangent);
                    if (across.sqrMagnitude < 0.0001f)
                        across = orientation * Vector3.right;
                    across.Normalize();
                    var widthWave = 0.78f
                        + 0.17f * Mathf.Sin(s * Mathf.PI * 5f + phaseOffset + time * 2.1f)
                        + 0.08f * Mathf.Sin(s * Mathf.PI * 13f - time * 3.7f + seed01 * 9f);
                    var width = Mathf.Lerp(widthMin, widthMax, Mathf.Clamp01(s * 0.74f + 0.18f)) * widthWave;
                    var pointColor = Color.Lerp(color, Color.Lerp(MoonCyan, ArcaneIndigo, 0.48f),
                        0.12f + 0.12f * Mathf.Sin(s * Mathf.PI * 3f + phaseOffset));
                    pointColor.a *= Mathf.SmoothStep(0f, 0.06f, s) * (1f - Mathf.SmoothStep(0.91f, 1f, s));
                    AddPair(point, across, width * 0.5f, pointColor, s);
                    AddSegment(baseVertex, index, sampleCount);
                }
            }

            public void AddBrokenGroundArc(
                Vector3 center,
                Vector3 right,
                Vector3 forward,
                float radius,
                float width,
                int sampleCount,
                float angularCoverage,
                float startAngle,
                Color color,
                float time,
                float seed01)
            {
                if (sampleCount < 2 || color.a <= 0.001f)
                    return;
                var baseVertex = vertices.Count;
                var step = 1f / (sampleCount - 1f);
                for (var index = 0; index < sampleCount; index++)
                {
                    var s = index * step;
                    var angle = startAngle + angularCoverage * s;
                    var radialNoise = 1f
                        + Mathf.Sin(s * 19.2f + time * 5.4f + seed01 * 8f) * 0.09f
                        + Mathf.Sin(s * 41.7f - time * 3.2f) * 0.05f;
                    var direction = right * Mathf.Cos(angle) + forward * Mathf.Sin(angle);
                    var point = center
                        + direction * (radius * radialNoise)
                        + Vector3.up * (Mathf.Sin(s * 27.1f + time * 4.6f) * ActorHeight * 0.012f);
                    var pointColor = color;
                    pointColor.a *= Mathf.SmoothStep(0f, 0.08f, s) * (1f - Mathf.SmoothStep(0.90f, 1f, s));
                    AddPair(point, direction, width * 0.5f, pointColor, s);
                    AddSegment(baseVertex, index, sampleCount);
                }
            }

            public void AddFrontVeil(
                Vector3 basePosition,
                Vector3 cameraRight,
                Vector3 cameraUp,
                Vector3 cameraForward,
                float height,
                float radius,
                float angularCoverage,
                float phase,
                int sampleCount,
                float width,
                Color color,
                float time,
                float phaseBias,
                bool faceted = false,
                bool luminous = false,
                bool solidOcclusion = false)
            {
                if (sampleCount < 2 || color.a <= 0.001f)
                    return;
                var baseVertex = vertices.Count;
                var step = 1f / (sampleCount - 1f);
                for (var index = 0; index < sampleCount; index++)
                {
                    var s = index * step;
                    var angle = (s - 0.5f) * angularCoverage
                        + Mathf.Sin(s * Mathf.PI * 4f + phase) * 0.12f
                        + phaseBias;
                    var profileRadius = radius * (0.64f + s * 0.36f);
                    var point = basePosition
                        + cameraUp * (height * s)
                        + cameraRight * (Mathf.Sin(angle) * profileRadius)
                        - cameraForward * (Mathf.Abs(Mathf.Cos(angle)) * profileRadius * 0.56f)
                        + cameraRight * (Mathf.Sin(s * 15.7f + time * 4.2f) * radius * 0.045f);
                    var previousS = Mathf.Max(0f, s - step);
                    var nextS = Mathf.Min(1f, s + step);
                    var tangent = cameraUp * ((nextS - previousS) * height)
                        + cameraRight * Mathf.Cos(angle) * profileRadius * angularCoverage * (nextS - previousS);
                    if (tangent.sqrMagnitude < 0.0001f)
                        tangent = cameraUp;
                    tangent.Normalize();
                    var across = Vector3.Cross(cameraForward, tangent).normalized;
                    var widthWave = 0.76f + Mathf.Sin(s * 17.5f + phase * 0.35f) * 0.18f;
                    var pointColor = Color.Lerp(
                        color,
                        Color.Lerp(MoonCyan, ArcaneIndigo, 0.42f),
                        0.10f + 0.13f * Mathf.Sin(s * Mathf.PI * 3.5f + phaseBias));
                    pointColor.a *= Mathf.SmoothStep(0f, 0.08f, s) * (1f - Mathf.SmoothStep(0.91f, 1f, s));
                    if (solidOcclusion)
                        AddOcclusionPair(point, across, width * widthWave * 0.5f, pointColor, s);
                    else if (luminous)
                        AddLuminousPair(point, across, width * widthWave * 0.5f, pointColor, s);
                    else if (faceted)
                        AddFacetedPair(point, across, width * widthWave * 0.5f, pointColor, s);
                    else
                        AddBrushPair(point, across, width * widthWave * 0.5f, pointColor, s);
                    AddSegment(baseVertex, index, sampleCount);
                }
            }

            public void AddCalligraphicFunnelStroke(
                Vector3 basePosition,
                Vector3 cameraRight,
                Vector3 cameraUp,
                Vector3 cameraForward,
                float height,
                float maxRadius,
                float turns,
                float phase,
                int sampleCount,
                float maxWidth,
                Color rootColor,
                Color tipColor,
                float time,
                float seed01,
                bool faceted = false,
                bool luminous = false,
                bool solidOcclusion = false)
            {
                if (sampleCount < 3 || height <= 0.001f || maxRadius <= 0.001f
                    || maxWidth <= 0.001f || Mathf.Max(rootColor.a, tipColor.a) <= 0.001f)
                    return;

                var baseVertex = vertices.Count;
                var step = 1f / (sampleCount - 1f);
                for (var index = 0; index < sampleCount; index++)
                {
                    var s = index * step;
                    var fragmentEnvelope = FunnelFragmentEnvelope(s, time, seed01);
                    var angle = phase + turns * Mathf.PI * 2f * s
                        + Mathf.Sin(s * Mathf.PI * 4.3f + seed01 * 7.1f + time * 1.9f) * 0.24f;
                    var funnel = Mathf.Lerp(0.24f, 1f, Mathf.Pow(s, 0.72f));
                    var radiusNoise = 1f
                        + Mathf.Sin(s * 13.7f + seed01 * 9.4f) * 0.11f
                        + Mathf.Sin(s * 29.1f - time * 2.2f + seed01 * 17.3f) * 0.06f;
                    var radius = maxRadius * funnel * radiusNoise;
                    var depth = Mathf.Cos(angle);
                    var point = basePosition
                        + cameraUp * (height * s)
                        + cameraRight * (Mathf.Sin(angle) * radius)
                        - cameraForward * (depth * radius * 0.42f + 0.055f);
                    var previousS = Mathf.Max(0f, s - step);
                    var nextS = Mathf.Min(1f, s + step);
                    var previousAngle = phase + turns * Mathf.PI * 2f * previousS;
                    var nextAngle = phase + turns * Mathf.PI * 2f * nextS;
                    var previousRadius = maxRadius * Mathf.Lerp(0.24f, 1f, Mathf.Pow(previousS, 0.72f));
                    var nextRadius = maxRadius * Mathf.Lerp(0.24f, 1f, Mathf.Pow(nextS, 0.72f));
                    var previous = basePosition
                        + cameraUp * (height * previousS)
                        + cameraRight * (Mathf.Sin(previousAngle) * previousRadius)
                        - cameraForward * (Mathf.Cos(previousAngle) * previousRadius * 0.42f + 0.055f);
                    var next = basePosition
                        + cameraUp * (height * nextS)
                        + cameraRight * (Mathf.Sin(nextAngle) * nextRadius)
                        - cameraForward * (Mathf.Cos(nextAngle) * nextRadius * 0.42f + 0.055f);
                    var tangent = next - previous;
                    if (tangent.sqrMagnitude < 0.00001f)
                        tangent = cameraUp;
                    tangent.Normalize();
                    var across = Vector3.Cross(cameraForward, tangent);
                    if (across.sqrMagnitude < 0.00001f)
                        across = cameraRight;
                    across.Normalize();
                    var belly = Mathf.Pow(Mathf.Sin(Mathf.PI * s), 0.55f);
                    var widthEnvelope = solidOcclusion
                        ? Mathf.Lerp(0.20f, 1f, Mathf.Pow(belly, 0.48f))
                        : faceted
                            ? Mathf.Lerp(0.035f, 1f, Mathf.Pow(belly, 0.70f))
                            : Mathf.Lerp(0.32f, 1f, belly);
                    var width = maxWidth
                        * widthEnvelope
                        * Mathf.Lerp(0.025f, 1f, fragmentEnvelope)
                        * (0.78f + 0.22f * (0.5f + 0.5f
                            * Mathf.Sin(s * 13.2f + seed01 * 8.8f + time * 1.3f)));
                    var color = Color.Lerp(rootColor, tipColor, Mathf.SmoothStep(0.12f, 0.94f, s));
                    color.a *= Mathf.Lerp(0.70f, 1f, Mathf.Max(0f, -depth) * 0.30f)
                        * Mathf.SmoothStep(0f, 0.035f, s)
                        * (1f - Mathf.SmoothStep(0.94f, 1f, s));
                    if (solidOcclusion)
                        AddOcclusionPair(point, across, width * 0.5f, color, s);
                    else if (luminous)
                        AddLuminousPair(point, across, width * 0.5f, color, s);
                    else if (faceted)
                        AddFacetedPair(point, across, width * 0.5f, color, s);
                    else
                        AddBrushPair(point, across, width * 0.5f, color, s);
                    if (index < sampleCount - 1)
                    {
                        var nextFragment = FunnelFragmentEnvelope(s + step, time, seed01);
                        if (Mathf.Min(fragmentEnvelope, nextFragment) > 0.085f)
                            AddSegment(baseVertex, index, sampleCount);
                    }
                }
            }

            static float FunnelFragmentEnvelope(float s, float time, float seed01)
            {
                // Three irregular moving cuts turn each helix into authored
                // ice-qi fragments. Geometry is actually disconnected here;
                // relying on vertex alpha alone is not stable on the Metal
                // particle/mesh color paths used by the preview.
                var drift = Mathf.Sin(time * 1.35f + seed01 * 19.1f) * 0.012f;
                var gapA = 0.22f + (seed01 - 0.5f) * 0.10f + drift;
                var gapB = 0.53f + Mathf.Sin(seed01 * 31.7f) * 0.055f - drift * 0.65f;
                var gapC = 0.79f + Mathf.Cos(seed01 * 23.9f) * 0.035f + drift * 0.42f;
                var keepA = GapKeep(s, gapA, 0.038f, 0.075f);
                var keepB = GapKeep(s, gapB, 0.052f, 0.092f);
                var keepC = GapKeep(s, gapC, 0.030f, 0.064f);
                return keepA * keepB * keepC;
            }

            static float GapKeep(float s, float center, float innerRadius, float outerRadius)
            {
                return Mathf.SmoothStep(
                    0f,
                    1f,
                    Mathf.InverseLerp(innerRadius, outerRadius, Mathf.Abs(s - center)));
            }

            /// <summary>
            /// Builds one broad, incomplete crescent in the camera plane.
            /// Unlike the old radial petal, this has a circular flow tangent
            /// and a noisy width envelope, so a group reads as rotating storm
            /// pressure rather than a flower, leaf or straight neon cable.
            /// This is rendered by its own aurora-arc material; UV is the
            /// regular 0..1 brush field rather than a multiplexed UV band.
            /// </summary>
            public void AddStormArcSheet(
                Vector3 center,
                Vector3 cameraRight,
                Vector3 cameraUp,
                Vector3 cameraForward,
                float radiusX,
                float radiusY,
                float startAngle,
                float angularSpan,
                float maxWidth,
                int sampleCount,
                Color rootColor,
                Color tipColor,
                float time,
                float seed01,
                float depthOffset)
            {
                if (sampleCount < 3 || radiusX <= 0.001f || radiusY <= 0.001f
                    || maxWidth <= 0.001f
                    || Mathf.Max(rootColor.a, tipColor.a) <= 0.001f)
                    return;

                var baseVertex = vertices.Count;
                var step = 1f / (sampleCount - 1f);
                for (var index = 0; index < sampleCount; index++)
                {
                    var s = index * step;
                    var edgeEnvelope = Mathf.Pow(Mathf.Sin(Mathf.PI * s), 0.52f);
                    var angularNoise = Mathf.Sin(
                            s * 9.7f + seed01 * 13.1f + time * 2.3f) * 0.070f
                        + Mathf.Sin(
                            s * 21.3f - seed01 * 7.9f - time * 1.6f) * 0.028f;
                    var angle = startAngle + angularSpan * s + angularNoise;
                    var radiusNoise = 1f
                        + Mathf.Sin(s * 12.7f + seed01 * 9.3f + time * 1.8f) * 0.070f
                        + Mathf.Sin(s * 27.1f - seed01 * 5.7f - time * 2.1f) * 0.028f;
                    var point = center
                        + cameraRight * (Mathf.Cos(angle) * radiusX * radiusNoise)
                        + cameraUp * (Mathf.Sin(angle) * radiusY * radiusNoise)
                        - cameraForward * (depthOffset
                            + Mathf.Sin(angle * 1.7f + seed01 * 8.1f)
                                * maxWidth * 0.10f);

                    var tangent = -cameraRight * (Mathf.Sin(angle) * radiusX)
                        + cameraUp * (Mathf.Cos(angle) * radiusY);
                    tangent += cameraRight * (Mathf.Sin(s * 15.4f + seed01 * 11.0f)
                        * maxWidth * 0.08f);
                    if (tangent.sqrMagnitude < 0.00001f)
                        tangent = cameraRight;
                    tangent.Normalize();
                    var across = Vector3.Cross(cameraForward, tangent);
                    if (across.sqrMagnitude < 0.00001f)
                        across = cameraUp;
                    across.Normalize();

                    var widthNoise = 0.86f
                        + Mathf.Sin(s * 13.9f + seed01 * 16.7f + time * 2.0f) * 0.14f
                        + Mathf.Sin(s * 31.6f - seed01 * 5.2f - time * 2.8f) * 0.06f;
                    var halfWidth = maxWidth
                        * Mathf.Lerp(0.10f, 1f, edgeEnvelope)
                        * widthNoise * 0.5f;
                    var color = Color.Lerp(
                        rootColor,
                        tipColor,
                        Mathf.SmoothStep(0.08f, 0.92f, s));
                    color.a *= Mathf.SmoothStep(0f, 0.06f, s)
                        * (1f - Mathf.SmoothStep(0.90f, 1f, s));
                    vertices.Add(owner.InverseTransformPoint(point - across * halfWidth));
                    vertices.Add(owner.InverseTransformPoint(point + across * halfWidth));
                    colors.Add(color);
                    colors.Add(color);
                    uvs.Add(new Vector2(s, 0f));
                    uvs.Add(new Vector2(s, 1f));
                    AddSegment(baseVertex, index, sampleCount);
                }
            }

            public void AddVortexSheet(
                Vector3 basePosition,
                Vector3 cameraRight,
                Vector3 cameraUp,
                Vector3 cameraForward,
                float height,
                float bottomRadius,
                float topRadius,
                float turns,
                float angularCoverage,
                float phase,
                float phaseOffset,
                int rings,
                int sides,
                float depthScale,
                Color rootColor,
                Color tipColor,
                float time,
                float seed01)
            {
                if (rings < 3 || sides < 3 || height <= 0.001f
                    || Mathf.Max(bottomRadius, topRadius) <= 0.001f
                    || Mathf.Max(rootColor.a, tipColor.a) <= 0.001f)
                    return;

                var baseVertex = vertices.Count;
                for (var ring = 0; ring < rings; ring++)
                {
                    var s = ring / (rings - 1f);
                    // One shared concave radius curve gives the commercial
                    // bottom-narrow / waist-tight / crown-open silhouette.
                    // A near-linear profile made the previous version a tube.
                    var profile = Mathf.Pow(s, 1.45f);
                    var centerAngle = phase + phaseOffset
                        + turns * Mathf.PI * 2f * s
                        + Mathf.Sin(s * 8.7f + seed01 * 15.1f + time * 2.6f) * 0.10f
                        + Mathf.Sin(s * 21.4f - seed01 * 7.3f - time * 1.8f) * 0.035f;
                    var profileRadius = Mathf.Lerp(bottomRadius, topRadius, profile);
                    var centerDrift = cameraRight * (
                            Mathf.Sin(s * 5.1f + seed01 * 9.4f + time * 1.7f)
                            * topRadius * 0.055f)
                        + cameraForward * (
                            Mathf.Cos(s * 4.3f - seed01 * 5.8f - time * 1.3f)
                            * topRadius * 0.026f);

                    for (var side = 0; side < sides; side++)
                    {
                        var t = side / (sides - 1f);
                        var sideCoord = t * 2f - 1f;
                        var coverage = angularCoverage * Mathf.Lerp(0.78f, 1.08f, profile);
                        var edgeWarp = Mathf.Sin(
                                s * 11.6f + t * 7.7f + seed01 * 17.0f + time * 2.2f) * 0.075f
                            + Mathf.Sin(
                                s * 27.3f - t * 13.1f - time * 1.6f) * 0.035f;
                        var angle = centerAngle + sideCoord * coverage * 0.5f + edgeWarp;
                        var radialNoise = 1f
                            + Mathf.Sin(s * 14.7f + t * 6.2f + seed01 * 12.3f + time * 2.0f) * 0.075f
                            + Mathf.Sin(s * 31.9f - t * 9.4f - time * 2.7f) * 0.035f;
                        var radius = profileRadius * radialNoise;
                        var crown = Mathf.SmoothStep(0.70f, 1f, s) * height * (
                            Mathf.Sin(t * 8.9f + seed01 * 12.7f + time * 1.5f) * 0.070f
                            + Mathf.Sin(t * 19.1f - seed01 * 6.9f - time * 1.1f) * 0.030f);
                        var rootTear = (1f - Mathf.SmoothStep(0f, 0.16f, s))
                            * height * Mathf.Sin(t * 10.3f + seed01 * 8.0f) * 0.018f;
                        var point = basePosition
                            + cameraUp * (height * s + crown + rootTear)
                            + centerDrift
                            + cameraRight * (Mathf.Sin(angle) * radius)
                            - cameraForward * (
                                Mathf.Cos(angle) * radius * depthScale
                                + ActorHeight * 0.052f);
                        var color = Color.Lerp(
                            rootColor,
                            tipColor,
                            Mathf.SmoothStep(0.08f, 0.94f, s));
                        var sideLight = Mathf.Pow(Mathf.Sin(Mathf.PI * t), 0.72f);
                        color = Color.Lerp(
                            color,
                            Color.Lerp(JadeWhite, PaleGold, 0.08f),
                            sideLight * Mathf.SmoothStep(0.42f, 0.92f, s) * 0.11f);
                        color.a *= Mathf.Lerp(0.72f, 1f, sideLight)
                            * Mathf.SmoothStep(0f, 0.035f, s)
                            * (1f - Mathf.SmoothStep(0.965f, 1f, s));
                        vertices.Add(owner.InverseTransformPoint(point));
                        colors.Add(color);
                        // UV 22..23 selects the dedicated broad storm-sheet
                        // shader. It is deliberately isolated from the legacy
                        // dark/faceted families that produced black cables.
                        uvs.Add(new Vector2(s, 22f + t));
                    }
                }

                for (var ring = 0; ring < rings - 1; ring++)
                {
                    for (var side = 0; side < sides - 1; side++)
                    {
                        var a = baseVertex + ring * sides + side;
                        var b = a + 1;
                        var c = a + sides;
                        var d = c + 1;
                        triangles.Add(a);
                        triangles.Add(c);
                        triangles.Add(b);
                        triangles.Add(b);
                        triangles.Add(c);
                        triangles.Add(d);
                    }
                }
            }

            public void AddImpactShell(
                Vector3 center,
                Vector3 cameraRight,
                Vector3 cameraUp,
                Vector3 cameraForward,
                float radiusX,
                float radiusY,
                float radiusZ,
                float angularCoverage,
                float phase,
                int rings,
                int sides,
                Color lowerColor,
                Color upperColor,
                float time,
                float seed01)
            {
                if (rings < 3 || sides < 3
                    || Mathf.Min(radiusX, Mathf.Min(radiusY, radiusZ)) <= 0.001f
                    || Mathf.Max(lowerColor.a, upperColor.a) <= 0.001f)
                    return;

                var baseVertex = vertices.Count;
                for (var ring = 0; ring < rings; ring++)
                {
                    var v = ring / (rings - 1f);
                    var latitude = Mathf.Lerp(-1.34f, 1.34f, v);
                    var latitudeRadius = Mathf.Max(0.045f, Mathf.Cos(latitude));
                    var verticalNoise = Mathf.Sin(
                        v * 13.7f + seed01 * 11.2f + time * 5.1f) * radiusY * 0.035f;
                    for (var side = 0; side < sides; side++)
                    {
                        var t = side / (sides - 1f);
                        var edgeEnvelope = Mathf.Pow(Mathf.Sin(Mathf.PI * t), 0.34f);
                        var angularTear = Mathf.Sin(
                                t * 15.3f + v * 7.7f + seed01 * 17.1f + time * 4.2f) * 0.065f
                            + Mathf.Sin(
                                t * 29.4f - v * 11.8f - time * 2.9f) * 0.025f;
                        var angle = phase + (t - 0.5f) * angularCoverage + angularTear;
                        var radialNoise = 1f
                            + Mathf.Sin(v * 9.8f + t * 17.1f + seed01 * 8.3f) * 0.065f
                            + Mathf.Sin(v * 23.7f - t * 12.4f + time * 3.3f) * 0.030f;
                        var point = center
                            + cameraRight * (Mathf.Sin(angle) * radiusX * latitudeRadius * radialNoise)
                            + cameraUp * (Mathf.Sin(latitude) * radiusY + verticalNoise)
                            - cameraForward * (
                                Mathf.Cos(angle) * radiusZ * latitudeRadius * radialNoise
                                + radiusZ * 0.08f);
                        var color = Color.Lerp(lowerColor, upperColor,
                            Mathf.SmoothStep(0.10f, 0.90f, v));
                        color.a *= edgeEnvelope
                            * Mathf.Lerp(0.72f, 1f, latitudeRadius)
                            * Mathf.SmoothStep(0f, 0.045f, v)
                            * (1f - Mathf.SmoothStep(0.955f, 1f, v));
                        vertices.Add(owner.InverseTransformPoint(point));
                        colors.Add(color);
                        // UV 4..5 is the torn organic-pressure branch.  It
                        // gives the contact shell a fast outward pop without a
                        // dark outline or a mathematically clean sphere.
                        uvs.Add(new Vector2(v, 4f + t));
                    }
                }

                for (var ring = 0; ring < rings - 1; ring++)
                {
                    for (var side = 0; side < sides - 1; side++)
                    {
                        var a = baseVertex + ring * sides + side;
                        var b = a + 1;
                        var c = a + sides;
                        var d = c + 1;
                        triangles.Add(a);
                        triangles.Add(c);
                        triangles.Add(b);
                        triangles.Add(b);
                        triangles.Add(c);
                        triangles.Add(d);
                    }
                }
            }

            public void AddFunnelMantle(
                Vector3 center,
                Vector3 cameraRight,
                Vector3 cameraUp,
                Vector3 cameraForward,
                float height,
                float maxRadius,
                float angularCoverage,
                float phase,
                int rings,
                int sides,
                float depthScale,
                Color rootColor,
                Color tipColor,
                float time,
                float seed01)
            {
                if (rings < 2 || sides < 3 || height <= 0.001f || maxRadius <= 0.001f
                    || Mathf.Max(rootColor.a, tipColor.a) <= 0.001f)
                    return;

                var baseVertex = vertices.Count;
                for (var ring = 0; ring < rings; ring++)
                {
                    var s = ring / (rings - 1f);
                    var taper = Mathf.Lerp(0.16f, 1f, Mathf.Pow(s, 0.58f));
                    var centreDrift = cameraRight * (
                        Mathf.Sin(s * 5.4f + time * 2.3f + seed01 * 8.1f) * maxRadius * 0.10f)
                        + cameraForward * (
                            Mathf.Cos(s * 4.7f - time * 1.7f + seed01 * 5.4f) * maxRadius * 0.045f);
                    for (var side = 0; side < sides; side++)
                    {
                        var t = side / (sides - 1f);
                        var edgeWarp = Mathf.Sin(s * 8.2f + t * 6.1f + seed01 * 12.0f + time * 2.6f) * 0.11f
                            + Mathf.Sin(s * 17.0f - t * 4.3f - time * 1.9f) * 0.055f;
                        var verticalTwist = (s - 0.5f)
                            * Mathf.Lerp(0.72f, 1.24f, seed01);
                        var angle = phase
                            + verticalTwist
                            + (t - 0.5f) * angularCoverage
                            + edgeWarp * (0.32f + 0.68f * t);
                        var radialNoise = 1f
                            + Mathf.Sin(s * 13.3f + t * 5.7f + seed01 * 7.2f + time * 2.0f) * 0.10f
                            + Mathf.Sin(s * 29.4f - t * 8.1f - time * 2.8f) * 0.045f;
                        var radius = maxRadius * taper * radialNoise;
                        // Each side reaches a different top height. This keeps
                        // the wide tornado mouth but removes the procedural
                        // grid's giveaway flat horizontal cap.
                        var topTear = Mathf.SmoothStep(0.72f, 1f, s);
                        var topTearOffset = topTear * height * (
                            Mathf.Sin(t * 8.7f + seed01 * 13.1f + time * 1.8f) * 0.055f
                            + Mathf.Sin(t * 19.4f - seed01 * 7.6f - time * 1.1f) * 0.026f);
                        var point = center
                            + cameraUp * ((s - 0.5f) * height + topTearOffset)
                            + centreDrift
                            + cameraRight * (Mathf.Sin(angle) * radius)
                            - cameraForward * (Mathf.Cos(angle) * radius * depthScale + 0.072f);
                        var color = Color.Lerp(rootColor, tipColor, Mathf.SmoothStep(0.08f, 0.94f, s));
                        var sideValue = 1f - Mathf.Abs(t * 2f - 1f);
                        color.a *= Mathf.Lerp(0.78f, 1f, sideValue)
                            * Mathf.Lerp(0.82f, 1f, Mathf.Sin(Mathf.PI * s));
                        vertices.Add(owner.InverseTransformPoint(point));
                        colors.Add(color);
                        uvs.Add(new Vector2(s, 22f + t));
                    }
                }

                for (var ring = 0; ring < rings - 1; ring++)
                {
                    for (var side = 0; side < sides - 1; side++)
                    {
                        var a = baseVertex + ring * sides + side;
                        var b = a + 1;
                        var c = a + sides;
                        var d = c + 1;
                        triangles.Add(a);
                        triangles.Add(c);
                        triangles.Add(b);
                        triangles.Add(b);
                        triangles.Add(c);
                        triangles.Add(d);
                    }
                }
            }

            public void AddOrganicBurstPetal(
                Vector3 origin,
                Vector3 direction,
                Vector3 across,
                float length,
                float maxWidth,
                float bend,
                int sampleCount,
                Color rootColor,
                Color tipColor,
                float time,
                float seed01,
                bool faceted = false,
                bool luminous = false,
                bool solidOcclusion = false)
            {
                if (sampleCount < 3 || length <= 0.001f || maxWidth <= 0.001f
                    || Mathf.Max(rootColor.a, tipColor.a) <= 0.001f)
                    return;

                direction.Normalize();
                across.Normalize();
                var baseVertex = vertices.Count;
                var step = 1f / (sampleCount - 1f);
                for (var index = 0; index < sampleCount; index++)
                {
                    var s = index * step;
                    var belly = Mathf.Pow(Mathf.Sin(Mathf.PI * s), 0.55f);
                    var envelope = (solidOcclusion
                            ? Mathf.Lerp(0.018f, 1.0f, Mathf.Pow(belly, 0.56f))
                            : faceted
                                ? Mathf.Lerp(0.035f, 1.0f, Mathf.Pow(belly, 0.68f))
                                : Mathf.Lerp(0.32f, 1.0f, belly))
                        * Mathf.Lerp(0.82f, 1.06f, s);
                    var tornWidth = 1f
                        + Mathf.Sin(s * 17.3f + seed01 * 11.7f + time * 3.1f) * 0.18f
                        + Mathf.Sin(s * 39.1f - seed01 * 7.3f - time * 2.4f) * 0.09f;
                    var sideWarp = bend * Mathf.Pow(s, 1.35f)
                        + maxWidth * 0.11f * Mathf.Sin(s * 12.7f + seed01 * 9.2f + time * 2.2f);
                    var liftWarp = maxWidth * 0.075f
                        * Mathf.Sin(s * 21.4f - time * 3.7f + seed01 * 13.1f);
                    var point = origin
                        + direction * (length * s)
                        + across * sideWarp
                        + Vector3.up * liftWarp;
                    var previousS = Mathf.Max(0f, s - step);
                    var nextS = Mathf.Min(1f, s + step);
                    var tangent = direction * (length * (nextS - previousS))
                        + across * (bend * 1.35f * Mathf.Pow(Mathf.Max(0.001f, s), 0.35f) * (nextS - previousS));
                    if (tangent.sqrMagnitude < 0.00001f)
                        tangent = direction;
                    tangent.Normalize();
                    var localAcross = Vector3.ProjectOnPlane(across, tangent);
                    if (localAcross.sqrMagnitude < 0.00001f)
                        localAcross = across;
                    localAcross.Normalize();
                    var color = Color.Lerp(rootColor, tipColor, Mathf.SmoothStep(0.08f, 0.92f, s));
                    var veinPulse = Mathf.Pow(Mathf.Clamp01(
                        1f - Mathf.Abs(Mathf.Repeat(s * 2.6f + seed01 * 0.35f - time * 1.25f, 1f) * 2f - 1f)),
                        5f);
                    color = Color.Lerp(color, Color.Lerp(MoonCyan, PaleGold, 0.14f), veinPulse * 0.16f);
                    color.a *= Mathf.SmoothStep(0f, 0.055f, s)
                        * (1f - Mathf.SmoothStep(0.87f, 1f, s));
                    if (solidOcclusion)
                    {
                        AddOcclusionPair(
                            point,
                            localAcross,
                            maxWidth * envelope * tornWidth * 0.5f,
                            color,
                            s);
                    }
                    else if (luminous)
                    {
                        AddLuminousPair(
                            point,
                            localAcross,
                            maxWidth * envelope * tornWidth * 0.5f,
                            color,
                            s);
                    }
                    else if (faceted)
                    {
                        AddFacetedPair(
                            point,
                            localAcross,
                            maxWidth * envelope * tornWidth * 0.5f,
                            color,
                            s);
                    }
                    else
                    {
                        AddBurstPair(
                            point,
                            localAcross,
                            maxWidth * envelope * tornWidth * 0.5f,
                            color,
                            s);
                    }
                    AddSegment(baseVertex, index, sampleCount);
                }
            }

            public void AddEngulfVolume(
                Vector3 center,
                Vector3 cameraRight,
                Vector3 cameraUp,
                float width,
                float height,
                float tiltRadians,
                float bottomScale,
                float topScale,
                Color color,
                float time,
                float seed01,
                bool solidOcclusion = false,
                bool softVolume = false)
            {
                if (color.a <= 0.001f || width <= 0.001f || height <= 0.001f)
                    return;

                var baseVertex = vertices.Count;
                var movingTilt = tiltRadians
                    + Mathf.Sin(time * 1.7f + seed01 * 10.3f) * 0.035f;
                var rightAxis = (cameraRight * Mathf.Cos(movingTilt)
                    + cameraUp * Mathf.Sin(movingTilt)).normalized;
                var upAxis = (-cameraRight * Mathf.Sin(movingTilt)
                    + cameraUp * Mathf.Cos(movingTilt)).normalized;
                var bottomCenter = center - upAxis * (height * 0.50f)
                    - rightAxis * (width * 0.025f);
                var topCenter = center + upAxis * (height * 0.50f)
                    + rightAxis * (width * (seed01 - 0.5f) * 0.09f);
                var bottomHalf = width * bottomScale * 0.50f;
                var topHalf = width * topScale * 0.50f;

                vertices.Add(owner.InverseTransformPoint(bottomCenter - rightAxis * bottomHalf));
                vertices.Add(owner.InverseTransformPoint(bottomCenter + rightAxis * bottomHalf));
                vertices.Add(owner.InverseTransformPoint(topCenter - rightAxis * topHalf));
                vertices.Add(owner.InverseTransformPoint(topCenter + rightAxis * topHalf));
                colors.Add(color);
                colors.Add(color);
                var liftedColor = Color.Lerp(color, MoonCyan, 0.10f);
                liftedColor.a = color.a;
                colors.Add(liftedColor);
                colors.Add(liftedColor);
                // UV 16 selects the near-solid pressure body, UV 14 the
                // softer colored storm layer, and UV 12 the dark back volume.
                var uvBand = solidOcclusion ? 16f : softVolume ? 14f : 12f;
                uvs.Add(new Vector2(0f, uvBand));
                uvs.Add(new Vector2(0f, uvBand + 1f));
                uvs.Add(new Vector2(1f, uvBand));
                uvs.Add(new Vector2(1f, uvBand + 1f));
                triangles.Add(baseVertex);
                triangles.Add(baseVertex + 2);
                triangles.Add(baseVertex + 1);
                triangles.Add(baseVertex + 1);
                triangles.Add(baseVertex + 2);
                triangles.Add(baseVertex + 3);
            }

            public void AddColdCoreLobe(
                Vector3 center,
                Vector3 cameraRight,
                Vector3 cameraUp,
                float width,
                float height,
                Color color,
                float time,
                float seed01,
                bool fissure = false,
                float tiltBiasRadians = 0f,
                bool darkVolume = false)
            {
                if (color.a <= 0.001f || width <= 0.001f || height <= 0.001f)
                    return;

                // A skewed billboard gives the fragment shader a complete
                // 0..1 field for an SDF/noise cloud. The previous long strip
                // mesh either became a flat-ended column or, after stronger
                // tapering, lost the opacity required to engulf the actor.
                // The quad itself is never visible: coreMask erodes all four
                // edges into a moving, asymmetric frost-plasma silhouette.
                var baseVertex = vertices.Count;
                var tilt = tiltBiasRadians
                    + (seed01 - 0.5f) * 0.34f
                    + Mathf.Sin(time * 1.9f + seed01 * 12.7f) * 0.055f;
                var rightAxis = (cameraRight * Mathf.Cos(tilt)
                    + cameraUp * Mathf.Sin(tilt)).normalized;
                var upAxis = (-cameraRight * Mathf.Sin(tilt)
                    + cameraUp * Mathf.Cos(tilt)).normalized;
                var bottomWidth = width * Mathf.Lerp(0.82f, 1.03f, seed01);
                var topWidth = width * Mathf.Lerp(1.04f, 0.84f, seed01);
                var bottomCenter = center - upAxis * (height * 0.50f)
                    - rightAxis * (width * (seed01 - 0.5f) * 0.08f);
                var topCenter = center + upAxis * (height * 0.50f)
                    + rightAxis * (width * (seed01 - 0.5f) * 0.11f);

                vertices.Add(owner.InverseTransformPoint(bottomCenter - rightAxis * (bottomWidth * 0.5f)));
                vertices.Add(owner.InverseTransformPoint(bottomCenter + rightAxis * (bottomWidth * 0.5f)));
                vertices.Add(owner.InverseTransformPoint(topCenter - rightAxis * (topWidth * 0.5f)));
                vertices.Add(owner.InverseTransformPoint(topCenter + rightAxis * (topWidth * 0.5f)));
                colors.Add(color);
                colors.Add(color);
                var topColor = Color.Lerp(color, IceWhite, 0.055f);
                topColor.a = color.a;
                colors.Add(topColor);
                colors.Add(topColor);
                var uvBand = darkVolume ? 12f : fissure ? 10f : 8f;
                uvs.Add(new Vector2(0f, uvBand));
                uvs.Add(new Vector2(0f, uvBand + 1f));
                uvs.Add(new Vector2(1f, uvBand));
                uvs.Add(new Vector2(1f, uvBand + 1f));
                triangles.Add(baseVertex);
                triangles.Add(baseVertex + 2);
                triangles.Add(baseVertex + 1);
                triangles.Add(baseVertex + 1);
                triangles.Add(baseVertex + 2);
                triangles.Add(baseVertex + 3);
            }

            public void AddImpactRefraction(
                Vector3 center,
                Vector3 cameraRight,
                Vector3 cameraUp,
                float actorHeight,
                float visibility,
                float phase,
                Color iceColor,
                Color paleGold)
            {
                if (visibility <= 0.001f)
                    return;

                var degrees = new[] { -38f, 9f, 61f };
                var lengths = new[] { 0.29f, 0.23f, 0.27f };
                var widths = new[] { 0.034f, 0.026f, 0.031f };
                var offsetX = new[] { -0.12f, 0.08f, 0.13f };
                var offsetY = new[] { 0.15f, 0.055f, -0.075f };
                for (var index = 0; index < degrees.Length; index++)
                {
                    var angle = degrees[index] * Mathf.Deg2Rad
                        + Mathf.Sin(phase * 0.31f + index * 1.7f) * 0.035f;
                    var direction = (cameraRight * Mathf.Cos(angle) + cameraUp * Mathf.Sin(angle)).normalized;
                    var tangent = (-cameraRight * Mathf.Sin(angle) + cameraUp * Mathf.Cos(angle)).normalized;
                    var color = index == 1 ? Color.Lerp(iceColor, paleGold, 0.14f) : iceColor;
                    color.a = visibility * Mathf.Lerp(0.36f, 0.44f, index / 2f);
                    var offset = cameraRight * (actorHeight * offsetX[index])
                        + cameraUp * (actorHeight * offsetY[index]);
                    AddTaperedWedge(
                        center + offset - direction * (actorHeight * 0.035f),
                        direction,
                        tangent,
                        actorHeight * lengths[index],
                        actorHeight * widths[index],
                        color);
                }

                var vertical = Color.Lerp(iceColor, paleGold, 0.24f);
                vertical.a = visibility * 0.35f;
                AddTaperedWedge(
                    center - cameraUp * (actorHeight * 0.12f) - cameraRight * (actorHeight * 0.10f),
                    cameraUp,
                    cameraRight,
                    actorHeight * 0.20f,
                    actorHeight * 0.017f,
                    vertical);
            }

            public void AddIceCracks(
                Vector3 center,
                Vector3 right,
                Vector3 forward,
                float actorHeight,
                float time,
                float phase,
                Color color)
            {
                var reveal = Ease(0.82f, 0.98f, time);
                var fade = 1f - Ease(1.24f, 1.68f, time);
                var visibility = reveal * fade;
                if (visibility <= 0.001f)
                    return;

                var anglesDegrees = new[] { 18f, 104f, 218f, 311f };
                var lengths = new[] { 0.31f, 0.21f, 0.34f, 0.27f };
                for (var crack = 0; crack < anglesDegrees.Length; crack++)
                {
                    const int points = 6;
                    var baseVertex = vertices.Count;
                    var angle = anglesDegrees[crack] * Mathf.Deg2Rad;
                    var direction = (right * Mathf.Cos(angle) + forward * Mathf.Sin(angle)).normalized;
                    var tangent = (-right * Mathf.Sin(angle) + forward * Mathf.Cos(angle)).normalized;
                    for (var index = 0; index < points; index++)
                    {
                        var s = index / (points - 1f);
                        var zig = Mathf.Sin(s * Mathf.PI * 5f + crack * 1.83f + phase * 0.025f)
                            * actorHeight * 0.010f * (1f - s * 0.42f);
                        var point = center
                            + direction * (actorHeight * lengths[crack] * reveal * s)
                            + tangent * zig
                            + Vector3.up * (actorHeight * 0.0018f * index);
                        var pointColor = color;
                        pointColor.a = visibility * 0.32f
                            * (1f - Ease(0.72f, 1f, s));
                        var halfWidth = actorHeight * Mathf.Lerp(0.009f, 0.0008f, s);
                        AddPair(point, tangent, halfWidth, pointColor, s);
                        AddSegment(baseVertex, index, points);
                    }
                }
            }

            public void AddSpiralGlints(
                Vector3 basePosition,
                Vector3 cameraRight,
                Vector3 cameraUp,
                Vector3 cameraForward,
                float actorHeight,
                float time,
                float phase,
                float visibility,
                Color iceColor,
                Color paleGold)
            {
                if (visibility <= 0.012f || time < ContactTime || time > 1.68f)
                    return;

                var decay = 1f - Ease(1.40f, 1.68f, time);
                var glintCount = time >= 1.42f ? 6 : 10;
                for (var index = 0; index < glintCount; index++)
                {
                    var normalized = Mathf.Repeat(
                        Seed01(index * 173 + 211) + (time - ContactTime) * Mathf.Lerp(0.42f, 0.68f, Seed01(index + 19)),
                        1f);
                    var angle = phase * Mathf.Lerp(0.34f, 0.58f, Seed01(index + 71))
                        + normalized * Mathf.PI * 3.5f
                        + Seed01(index * 317 + 17) * Mathf.PI * 2f;
                    var radius = actorHeight * Mathf.Lerp(0.085f, 0.29f, normalized)
                        * (0.88f + 0.12f * Mathf.Sin(time * 7.1f + index));
                    var center = basePosition
                        + cameraUp * (actorHeight * normalized * 1.03f)
                        + cameraRight * (Mathf.Sin(angle) * radius)
                        - cameraForward * (0.10f + Mathf.Abs(Mathf.Cos(angle)) * radius * 0.18f);
                    var longAxis = (cameraUp * 0.82f
                        + cameraRight * Mathf.Cos(angle) * 0.57f).normalized;
                    var across = (-cameraUp * longAxis.x + cameraRight * longAxis.y).normalized;
                    var size = actorHeight * Mathf.Lerp(0.028f, 0.066f, Seed01(index + 911));
                    var color = index >= glintCount - 2
                        ? Color.Lerp(iceColor, paleGold, index == glintCount - 1 ? 0.52f : 0.32f)
                        : iceColor;
                    color.a = Mathf.Clamp01(visibility * 1.75f * decay)
                        * Mathf.Lerp(0.68f, 0.96f, Seed01(index + 137));
                    AddTaperedWedge(center - longAxis * size * 0.35f, longAxis, across, size * 1.8f, size * 0.22f, color);
                }
            }

            void AddTaperedWedge(
                Vector3 origin,
                Vector3 direction,
                Vector3 across,
                float length,
                float halfWidth,
                Color color)
            {
                var baseVertex = vertices.Count;
                var root = owner.InverseTransformPoint(origin - across * halfWidth);
                var shoulder = owner.InverseTransformPoint(origin + across * halfWidth * 0.72f);
                var kink = owner.InverseTransformPoint(
                    origin + direction * (length * 0.58f) - across * (halfWidth * 0.21f));
                var tip = owner.InverseTransformPoint(origin + direction * length);
                vertices.Add(root);
                vertices.Add(shoulder);
                vertices.Add(kink);
                vertices.Add(tip);
                colors.Add(color);
                colors.Add(color);
                var middle = color;
                middle.a *= 0.78f;
                colors.Add(middle);
                var end = color;
                end.a = 0f;
                colors.Add(end);
                // V > 1 marks the rare impact-refraction branch in the
                // shared flow shader. It remains in the existing Always
                // renderer, so this highlight adds no pass or draw call.
                uvs.Add(new Vector2(0f, 2f));
                uvs.Add(new Vector2(0f, 3f));
                uvs.Add(new Vector2(0.58f, 2.35f));
                uvs.Add(new Vector2(1f, 2.5f));
                triangles.Add(baseVertex);
                triangles.Add(baseVertex + 2);
                triangles.Add(baseVertex + 1);
                triangles.Add(baseVertex + 1);
                triangles.Add(baseVertex + 2);
                triangles.Add(baseVertex + 3);
            }

            static Vector3 HelixPoint(
                float s,
                Vector3 basePosition,
                Quaternion orientation,
                float length,
                float radius,
                float turns,
                float phase,
                float phaseOffset,
                float impactProfile,
                float time,
                float seed01)
            {
                var axis = orientation * Vector3.up;
                var basisX = orientation * Vector3.right;
                var basisZ = orientation * Vector3.forward;
                var theta = phase + phaseOffset + Mathf.PI * 2f * turns * s
                    + 0.24f * Mathf.Sin(Mathf.PI * 6f * s + 1.7f * time + seed01 * 4f)
                    + 0.11f * Mathf.Sin(Mathf.PI * 14f * s - 3.1f * time + seed01 * 11f);
                var flightRadius = 1f - 0.65f * s;
                var impactRadius = 0.26f + 0.74f * s;
                var profile = Mathf.Lerp(flightRadius, impactRadius, impactProfile);
                profile *= 1f
                    + Mathf.Sin(s * 21.3f + time * 3.4f + seed01 * 9f) * 0.13f
                    + Mathf.Sin(s * 43.7f - time * 2.6f + seed01 * 13f) * 0.055f;
                return basePosition
                    + axis * (length * s)
                    + basisX * (Mathf.Cos(theta) * radius * profile)
                    + basisZ * (Mathf.Sin(theta) * radius * profile);
            }

            void AddPair(Vector3 worldPoint, Vector3 across, float halfWidth, Color color, float u)
            {
                // Runtime extension roots are positioned on their anchors by
                // SpellRuntime. Resetting only rotation/scale is intentional;
                // converting authored world points through the owner keeps the
                // mesh local and avoids applying the anchor translation twice.
                vertices.Add(owner.InverseTransformPoint(worldPoint - across * halfWidth));
                vertices.Add(owner.InverseTransformPoint(worldPoint + across * halfWidth));
                colors.Add(color);
                colors.Add(color);
                uvs.Add(new Vector2(u, 0f));
                uvs.Add(new Vector2(u, 1f));
            }

            void AddBurstPair(Vector3 worldPoint, Vector3 across, float halfWidth, Color color, float u)
            {
                vertices.Add(owner.InverseTransformPoint(worldPoint - across * halfWidth));
                vertices.Add(owner.InverseTransformPoint(worldPoint + across * halfWidth));
                colors.Add(color);
                colors.Add(color);
                // V 4..5 selects the organic burst branch in the same shared
                // front shader/material. No additional renderer or draw call.
                uvs.Add(new Vector2(u, 4f));
                uvs.Add(new Vector2(u, 5f));
            }

            void AddBrushPair(Vector3 worldPoint, Vector3 across, float halfWidth, Color color, float u)
            {
                vertices.Add(owner.InverseTransformPoint(worldPoint - across * halfWidth));
                vertices.Add(owner.InverseTransformPoint(worldPoint + across * halfWidth));
                colors.Add(color);
                colors.Add(color);
                // V 6..7 identifies the flowing calligraphy branch.
                uvs.Add(new Vector2(u, 6f));
                uvs.Add(new Vector2(u, 7f));
            }

            void AddFacetedPair(Vector3 worldPoint, Vector3 across, float halfWidth, Color color, float u)
            {
                vertices.Add(owner.InverseTransformPoint(worldPoint - across * halfWidth));
                vertices.Add(owner.InverseTransformPoint(worldPoint + across * halfWidth));
                colors.Add(color);
                colors.Add(color);
                // V 18..19 selects the dense faceted brush branch in the same
                // material. It adds no renderer, pass, texture, or draw call.
                uvs.Add(new Vector2(u, 18f));
                uvs.Add(new Vector2(u, 19f));
            }

            void AddLuminousPair(Vector3 worldPoint, Vector3 across, float halfWidth, Color color, float u)
            {
                vertices.Add(owner.InverseTransformPoint(worldPoint - across * halfWidth));
                vertices.Add(owner.InverseTransformPoint(worldPoint + across * halfWidth));
                colors.Add(color);
                colors.Add(color);
                // V 20..21 is the sparse jade-white/gold edge class.
                uvs.Add(new Vector2(u, 20f));
                uvs.Add(new Vector2(u, 21f));
            }

            void AddOcclusionPair(Vector3 worldPoint, Vector3 across, float halfWidth, Color color, float u)
            {
                vertices.Add(owner.InverseTransformPoint(worldPoint - across * halfWidth));
                vertices.Add(owner.InverseTransformPoint(worldPoint + across * halfWidth));
                colors.Add(color);
                colors.Add(color);
                // V 16..17 uses the near-solid turbulent body branch, but on a
                // curved/tapered strip rather than a screen-facing quad.
                uvs.Add(new Vector2(u, 16f));
                uvs.Add(new Vector2(u, 17f));
            }

            void AddCorePair(Vector3 worldPoint, Vector3 across, float halfWidth, Color color, float u)
            {
                vertices.Add(owner.InverseTransformPoint(worldPoint - across * halfWidth));
                vertices.Add(owner.InverseTransformPoint(worldPoint + across * halfWidth));
                colors.Add(color);
                colors.Add(color);
                // V 8..9 identifies the dense cold-core branch.
                uvs.Add(new Vector2(u, 8f));
                uvs.Add(new Vector2(u, 9f));
            }

            public void AddBillboardQuad(
                Vector3 center,
                Vector3 right,
                Vector3 up,
                float width,
                float height,
                Color color,
                int atlasCell,
                int atlasColumns,
                int atlasRows)
            {
                if (color.a <= 0.001f || width <= 0.001f || height <= 0.001f)
                    return;

                atlasColumns = Mathf.Max(1, atlasColumns);
                atlasRows = Mathf.Max(1, atlasRows);
                var cellCount = atlasColumns * atlasRows;
                atlasCell = Mathf.Clamp(atlasCell, 0, cellCount - 1);
                var column = atlasCell % atlasColumns;
                var row = atlasCell / atlasColumns;
                var uvMin = new Vector2(
                    column / (float)atlasColumns,
                    row / (float)atlasRows);
                var uvMax = new Vector2(
                    (column + 1f) / atlasColumns,
                    (row + 1f) / atlasRows);
                var halfRight = right.normalized * (width * 0.5f);
                var halfUp = up.normalized * (height * 0.5f);
                var baseVertex = vertices.Count;

                vertices.Add(owner.InverseTransformPoint(center - halfRight - halfUp));
                vertices.Add(owner.InverseTransformPoint(center + halfRight - halfUp));
                vertices.Add(owner.InverseTransformPoint(center - halfRight + halfUp));
                vertices.Add(owner.InverseTransformPoint(center + halfRight + halfUp));
                colors.Add(color);
                colors.Add(color);
                colors.Add(color);
                colors.Add(color);
                uvs.Add(new Vector2(uvMin.x, uvMin.y));
                uvs.Add(new Vector2(uvMax.x, uvMin.y));
                uvs.Add(new Vector2(uvMin.x, uvMax.y));
                uvs.Add(new Vector2(uvMax.x, uvMax.y));
                triangles.Add(baseVertex);
                triangles.Add(baseVertex + 2);
                triangles.Add(baseVertex + 1);
                triangles.Add(baseVertex + 1);
                triangles.Add(baseVertex + 2);
                triangles.Add(baseVertex + 3);
            }

            void AddSegment(int baseVertex, int index, int sampleCount)
            {
                if (index >= sampleCount - 1)
                    return;
                var vertex = baseVertex + index * 2;
                triangles.Add(vertex);
                triangles.Add(vertex + 2);
                triangles.Add(vertex + 1);
                triangles.Add(vertex + 1);
                triangles.Add(vertex + 2);
                triangles.Add(vertex + 3);
            }

            public void Commit()
            {
                mesh.Clear(false);
                if (vertices.Count < 4)
                {
                    renderer.enabled = false;
                    return;
                }
                mesh.SetVertices(vertices);
                mesh.SetColors(colors);
                mesh.SetUVs(0, uvs);
                mesh.SetTriangles(triangles, 0, false);
                mesh.bounds = new Bounds(Vector3.zero, Vector3.one * 8f);
                renderer.enabled = true;
            }

            public void Dispose()
            {
                if (root != null)
                    SpellBackends.DestroyOwned(root);
                if (mesh != null)
                    SpellBackends.DestroyOwned(mesh);
            }
        }
    }
}
