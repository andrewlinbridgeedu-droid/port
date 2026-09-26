using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace Mindstone.VFXV1
{
    /// <summary>
    /// Golden phoenix strike built from the existing Effekseer material
    /// library. The exact blue_fire, Wind, Fire_Single, Burst01_2 and
    /// particle textures are reused through the project's recolour shader.
    /// </summary>
    public sealed class VerdantEffekseerSpellExtension : MonoBehaviour, ISpellExtension
    {
        const string AssetShaderResource =
            "Mindstone/VFXV1/Spells/storm-frost-tornado-v1/FrostAssetSprite";
        const string BlueFireTextureResource =
            "Mindstone/VFXV1/Spells/storm-frost-tornado-v1/Effekseer/SnowstormOfficial/Texture/blue_fire";
        const string WindTextureResource =
            "Mindstone/VFXV1/Spells/storm-frost-tornado-v1/Effekseer/FrostStormImpact/Texture/Wind";
        const string FlameTextureResource =
            "Mindstone/VFXV1/Spells/storm-frost-tornado-v1/Effekseer/FrostStormImpact/Texture/Fire_Single";
        const string BurstTextureResource =
            "Mindstone/VFXV1/Spells/storm-frost-tornado-v1/Effekseer/SnowstormOfficial/Texture/Burst01_2";
        const string ParticleTextureResource =
            "Mindstone/VFXV1/Spells/storm-frost-tornado-v1/Effekseer/SnowstormOfficial/Texture/Particle01";

        // Phoenix palette: deep burnt umber for volume, saturated orange for
        // the body, gold for the wings, and a small warm-white core. Keep the
        // warm ramp broad enough to read as fire, but reserve the highest
        // value for the head, feather edges, and impact center.
        static readonly Color DeepGreen = new(0.105f, 0.026f, 0.008f, 1f);
        static readonly Color Emerald = new(0.420f, 0.085f, 0.012f, 1f);
        static readonly Color Leaf = new(0.900f, 0.245f, 0.018f, 1f);
        static readonly Color Lime = new(1.000f, 0.565f, 0.045f, 1f);
        static readonly Color WhiteGreen = new(1.000f, 0.900f, 0.520f, 1f);
        static readonly Color LeafDeep = new(0.280f, 0.038f, 0.006f, 1f);
        static readonly Color Mint = new(1.000f, 0.430f, 0.020f, 1f);
        static readonly Color Spring = new(1.000f, 0.805f, 0.100f, 1f);
        static readonly Color BridgeLime = new(1.000f, 0.625f, 0.070f, 1f);
        static readonly Color LemonGold = new(1.000f, 0.900f, 0.280f, 1f);
        static readonly Color SoftGold = new(1.000f, 0.769f, 0.227f, 1f);
        static readonly Color WarmWhite = new(1.000f, 0.840f, 0.540f, 1f);
        static readonly Color SolarGold = new(1.000f, 0.700f, 0.120f, 1f);
        static readonly Color Ember = new(1.000f, 0.130f, 0.018f, 1f);

        SpellSpec spell;
        SpellLayerSpec layer;
        int seed;
        bool released;

        Material bodyMaterial;
        Material windMaterial;
        Material flameMaterial;
        Material burstMaterial;
        Material debrisMaterial;
        Material goldMaterial;
        Material particleMaterial;
        AssetQuadBatch bodyBatch;
        AssetQuadBatch windBatch;
        AssetQuadBatch flameBatch;
        AssetQuadBatch burstBatch;
        AssetQuadBatch debrisBatch;
        AssetQuadBatch goldBatch;
        AssetQuadBatch particleBatch;
        PhoenixMeshRuntime phoenixMesh;
        Camera shakeCamera;
        Vector3 shakeBasePosition;
        Quaternion shakeBaseRotation;
        bool shakeCaptured;

        public void Initialize(SpellSpec spellSpec, SpellLayerSpec layerSpec, int deterministicSeed)
        {
            spell = spellSpec;
            layer = layerSpec;
            seed = deterministicSeed;
            var shader = Resources.Load<Shader>(AssetShaderResource)
                ?? Shader.Find("Mindstone/VFXV1/Frost Recolored Asset Sprite")
                ?? Shader.Find("Sprites/Default");
            if (shader == null)
            {
                Debug.LogError("[VFX V1] Verdant vortex asset shader is unavailable.");
                return;
            }

            var blueFire = Resources.Load<Texture2D>(BlueFireTextureResource);
            var wind = Resources.Load<Texture2D>(WindTextureResource);
            var flame = Resources.Load<Texture2D>(FlameTextureResource);
            var burst = Resources.Load<Texture2D>(BurstTextureResource);
            var particle = Resources.Load<Texture2D>(ParticleTextureResource);
            if (blueFire == null || wind == null || flame == null || burst == null || particle == null)
            {
                Debug.LogError("[VFX V1] Verdant vortex Effekseer texture stack is incomplete.");
                return;
            }

            switch (layer.role)
            {
                case "core":
                    bodyMaterial = CreateAssetMaterial(shader, blueFire, 4960, 0.72f, 1.32f, false);
                    windMaterial = CreateAssetMaterial(shader, wind, 4962, 0.62f, 1.16f, true);
                    flameMaterial = CreateAssetMaterial(shader, flame, 4966, 0.72f, 1.25f, false);
                    bodyBatch = new AssetQuadBatch(transform, "Verdant vortex body", bodyMaterial, 3);
                    windBatch = new AssetQuadBatch(transform, "Verdant vortex wind", windMaterial, 4);
                    flameBatch = new AssetQuadBatch(transform, "Verdant vortex hot cuts", flameMaterial, 5);
                    phoenixMesh = new PhoenixMeshRuntime(transform, deterministicSeed);
                    break;
                case "direction":
                    bodyMaterial = CreateAssetMaterial(shader, blueFire, 4964, 0.62f, 1.18f, false);
                    windMaterial = CreateAssetMaterial(shader, wind, 4968, 0.62f, 1.22f, true);
                    flameMaterial = CreateAssetMaterial(shader, flame, 4972, 0.70f, 1.28f, false);
                    debrisMaterial = CreateAssetMaterial(shader, flame, 4976, 0.46f, 1.16f, false);
                    bodyBatch = new AssetQuadBatch(transform, "Verdant carried vortex", bodyMaterial, 5);
                    windBatch = new AssetQuadBatch(transform, "Verdant carried wind", windMaterial, 6);
                    flameBatch = new AssetQuadBatch(transform, "Verdant carried flame", flameMaterial, 7);
                    debrisBatch = new AssetQuadBatch(transform, "Verdant carried debris", debrisMaterial, 8);
                    break;
                case "impact-back":
                    bodyMaterial = CreateAssetMaterial(shader, blueFire, 3275, 0.82f, 1.32f, false);
                    windMaterial = CreateAssetMaterial(shader, wind, 3278, 0.76f, 1.24f, true);
                    bodyBatch = new AssetQuadBatch(transform, "Verdant impact body back", bodyMaterial, -4);
                    windBatch = new AssetQuadBatch(transform, "Verdant impact pressure back", windMaterial, -3);
                    break;
                case "impact-front":
                    burstMaterial = CreateAssetMaterial(shader, burst, 4990, 0.78f, 1.32f, false);
                    Set(burstMaterial, "_DeepColor", Emerald);
                    Set(burstMaterial, "_Tint", Leaf);
                    Set(burstMaterial, "_HotColor", WhiteGreen);
                    Set(burstMaterial, "_WarmColor", SolarGold);
                    Set(burstMaterial, "_AlphaCap", 0.88f);
                    Set(burstMaterial, "_Intensity", 1.72f);
                    Set(burstMaterial, "_WarmAmount", 0.018f);
                    Set(burstMaterial, "_SourceMix", 0.18f);
                    flameMaterial = CreateAssetMaterial(shader, flame, 4994, 0.60f, 1.22f, false);
                    Set(flameMaterial, "_DeepColor", Emerald);
                    Set(flameMaterial, "_Tint", Leaf);
                    Set(flameMaterial, "_HotColor", Lime);
                    Set(flameMaterial, "_WarmColor", SolarGold);
                    Set(flameMaterial, "_Intensity", 1.50f);
                    Set(flameMaterial, "_WarmAmount", 0.012f);
                    Set(flameMaterial, "_SourceMix", 0.12f);
                    debrisMaterial = CreateAssetMaterial(shader, flame, 4998, 0.46f, 1.14f, false);
                    Set(debrisMaterial, "_DeepColor", Emerald);
                    Set(debrisMaterial, "_Tint", Leaf);
                    Set(debrisMaterial, "_HotColor", Lime);
                    Set(debrisMaterial, "_WarmColor", SolarGold);
                    Set(debrisMaterial, "_WarmAmount", 0.010f);
                    // Keep the warm detonation above the green burst cards,
                    // but still just behind the foreground vortex coils so
                    // the impact reads as green-gold-orange instead of neon
                    // green with hidden warm accents.
                    goldMaterial = CreateAssetMaterial(shader, burst, 5008, 0.72f, 1.58f, false);
                    Set(goldMaterial, "_DeepColor", SolarGold);
                    Set(goldMaterial, "_Tint", SolarGold);
                    Set(goldMaterial, "_HotColor", Ember);
                    Set(goldMaterial, "_WarmColor", WhiteGreen);
                    Set(goldMaterial, "_WarmAmount", 0.036f);
                    Set(goldMaterial, "_AlphaCap", 0.72f);
                    Set(goldMaterial, "_Intensity", 1.58f);
                    Set(goldMaterial, "_SourceMix", 0.02f);
                    // Keep the tornado-readable ring in front of every impact
                    // card. Sorting order alone cannot lift it above a lower
                    // material render queue, so this queue must sit above the
                    // green burst (4990), flame tongues (4994), debris (4998)
                    // and warm detonation (5004).
                    windMaterial = CreateAssetMaterial(shader, wind, 5010, 0.68f, 1.78f, true);
                    Set(windMaterial, "_DeepColor", Emerald);
                    Set(windMaterial, "_Tint", Mint);
                    Set(windMaterial, "_HotColor", Spring);
                    Set(windMaterial, "_WarmColor", SolarGold);
                    Set(windMaterial, "_WarmAmount", 0.042f);
                    Set(windMaterial, "_AlphaCap", 0.58f);
                    Set(windMaterial, "_Intensity", 1.58f);
                    Set(windMaterial, "_ArcSpan", 0.92f);
                    Set(windMaterial, "_FlowDissolve", 0.10f);
                    Set(windMaterial, "_VortexEye", 0.04f);
                    // Particle01 is an existing Effekseer atlas entry. Keep
                    // it in its own foreground batch so the final release can
                    // break into discrete sparks instead of another sampled
                    // Wind card or continuous ribbon.
                    particleMaterial = CreateAssetMaterial(shader, particle, 5012, 0.54f, 1.38f, true);
                    Set(particleMaterial, "_DeepColor", Emerald);
                    Set(particleMaterial, "_Tint", BridgeLime);
                    Set(particleMaterial, "_HotColor", LemonGold);
                    Set(particleMaterial, "_WarmColor", SolarGold);
                    Set(particleMaterial, "_WarmAmount", 0.032f);
                    Set(particleMaterial, "_AlphaCap", 0.54f);
                    Set(particleMaterial, "_Intensity", 1.38f);
                    Set(particleMaterial, "_SourceMix", 0.02f);
                    burstBatch = new AssetQuadBatch(transform, "Verdant impact burst", burstMaterial, 18);
                    flameBatch = new AssetQuadBatch(transform, "Verdant impact tongues", flameMaterial, 19);
                    debrisBatch = new AssetQuadBatch(transform, "Verdant impact debris", debrisMaterial, 20);
                    goldBatch = new AssetQuadBatch(transform, "Verdant impact gold detonation", goldMaterial, 17);
                    // The vortex coils are a foreground readability layer;
                    // the hit burst sits behind them so the tornado motion is
                    // still visible at the white-hot peak.
                    windBatch = new AssetQuadBatch(transform, "Verdant impact vortex coils", windMaterial, 21);
                    particleBatch = new AssetQuadBatch(transform, "Verdant impact particle release", particleMaterial, 22);
                    break;
                case "accent":
                    burstMaterial = CreateAssetMaterial(shader, burst, 5000, 0.98f, 1.45f, true);
                    debrisMaterial = CreateAssetMaterial(shader, flame, 5002, 0.50f, 1.18f, false);
                    Set(burstMaterial, "_DeepColor", Emerald);
                    Set(burstMaterial, "_Tint", Leaf);
                    Set(burstMaterial, "_HotColor", Mint);
                    Set(burstMaterial, "_WarmColor", SolarGold);
                    Set(burstMaterial, "_WarmAmount", 0.024f);
                    Set(debrisMaterial, "_DeepColor", Emerald);
                    Set(debrisMaterial, "_Tint", Leaf);
                    Set(debrisMaterial, "_HotColor", Spring);
                    Set(debrisMaterial, "_WarmColor", SolarGold);
                    Set(debrisMaterial, "_WarmAmount", 0.012f);
                    burstBatch = new AssetQuadBatch(transform, "Verdant contact flash", burstMaterial, 24);
                    debrisBatch = new AssetQuadBatch(transform, "Verdant contact sparks", debrisMaterial, 25);
                    break;
            }
        }

        public void Sample(in SpellSample sample)
        {
            if (released || layer == null)
                return;

            RestoreCameraShake();
            transform.rotation = Quaternion.identity;
            transform.localScale = Vector3.one;
            var frame = Frame.From(sample);
            var contact = ContactTime;
            var phase = Phase(sample.AbsoluteTime, seed);

            switch (layer.role)
            {
                case "core":
                    SampleCore(in sample, in frame, phase, contact);
                    break;
                case "direction":
                    SampleDirection(in sample, in frame, phase, contact);
                    break;
                case "impact-back":
                    SampleImpactBack(in sample, in frame, phase, contact);
                    break;
                case "impact-front":
                    SampleImpactFront(in sample, in frame, phase, contact);
                    break;
                case "accent":
                    SampleAccent(in sample, in frame, phase, contact);
                    break;
            }
        }

        void SampleCore(in SpellSample sample, in Frame frame, float phase, float contact)
        {
            var time = sample.AbsoluteTime;
            var formation = Ease(0.015f, 0.12f, time);
            // The supplied FBX is the only phoenix silhouette. It starts as a
            // small, readable bird at the source, grows continuously while
            // SpellRuntime moves it along the source-to-target path, then
            // holds the full mesh for a short contact beat before the impact
            // particle layer takes over.
            // Keep the complete Phoenix visible through the exact contact
            // sample. The mesh begins fragmenting on that same sample, so
            // there is no dead hold between impact and release.
            var preImpactVisibility = formation
                * (1f - Ease(contact, contact + 0.040f, time));
            var burstMeshVisibility = formation * 0.96f
                * (1f - Ease(contact + 0.060f, contact + 0.180f, time));
            var modelVisibility = Mathf.Max(
                preImpactVisibility,
                burstMeshVisibility);
            if (modelVisibility <= 0.001f)
            {
                ClearBatches();
                return;
            }

            var attackAxis = TravelAxis(in sample, in frame);
            // Add a short final lunge so contact has a visible velocity beat;
            // the target anchor still owns the actual hit position.
            var impactRush = Ease(contact - 0.14f, contact - 0.018f, time);
            var strikeCenter = sample.Position
                + attackAxis * (sample.Scale.x * 0.12f * impactRush);
            var flightLength = Mathf.Lerp(0.16f, 0.62f,
                Ease(0.08f, contact, time)) * sample.Scale.x;
            var flightRadius = Mathf.Lerp(0.08f, 0.28f,
                Ease(0.08f, contact, time)) * sample.Scale.x;
            var explosion = ImpactBurst(contact, time);
            DrawPhoenixStrike(strikeCenter, attackAxis, in frame, phase, time,
                flightLength, flightRadius, modelVisibility, false,
                1.0f, sample.Scale.x, explosion);
        }

        void SampleDirection(in SpellSample sample, in Frame frame, float phase, float contact)
        {
            var time = sample.AbsoluteTime;
            var growth = Ease(0.08f, 0.70f, time);
            var visibility = Ease(0.035f, 0.14f, time)
                * (1f - Ease(0.98f, 1.14f, time));
            if (visibility <= 0.001f)
            {
                ClearBatches();
                return;
            }

            var travelAxis = TravelAxis(in sample, in frame);
            var length = Mathf.Lerp(0.18f, 0.54f, growth) * sample.Scale.x;
            var width = Mathf.Lerp(0.06f, 0.18f, growth) * sample.Scale.x;
            // This layer is now a short, straight fire wake only. It never
            // builds a funnel, ring, spiral, leaf cloud, or second phoenix.
            DrawPhoenixFlameTrail(
                sample.Position + travelAxis * (sample.Scale.x * 0.06f * growth),
                travelAxis,
                in frame,
                phase,
                time,
                length,
                width,
                visibility);
            return;

            debrisBatch?.Begin();
            for (var index = 0; index < 12; index++)
            {
                var u = (index + 0.35f) / 12f;
                var birth = 0.28f + (index % 3) * 0.060f + u * 0.18f;
                if (time < birth)
                    continue;
                var leafLife = Mathf.Clamp01((time - birth) / (0.58f + (index % 3) * 0.09f));
                var angle = phase * 0.45f + index * 2.21f;
                var radial = Vector3.Cross(frame.CameraForward, travelAxis).normalized;
                if (radial.sqrMagnitude < 0.001f)
                    radial = frame.CameraUp;
                var point = sample.Position
                    + travelAxis * (length * (u - 0.46f))
                    + radial * (Mathf.Cos(angle) * width * (0.56f + u * 0.72f))
                    + frame.CameraForward * (Mathf.Sin(angle) * width * 0.10f)
                    + frame.CameraUp * (leafLife * (0.04f + u * 0.08f));
                var color = index == 7
                    ? Color.Lerp(Spring, SolarGold, 0.42f)
                    : index % 4 == 0
                        ? Color.Lerp(Mint, Spring, u * 0.52f)
                        : Color.Lerp(Leaf, Spring, u * 0.72f);
                color.a = visibility * (1f - leafLife) * Mathf.Lerp(0.44f, 0.70f, u);
                debrisBatch?.AddLeaf(
                    point,
                    frame.CameraRight,
                    frame.CameraUp,
                    sample.Scale.x * Mathf.Lerp(0.032f, 0.064f, (index % 3) / 2f),
                    sample.Scale.x * Mathf.Lerp(0.12f, 0.24f, u),
                    phase * 19f + index * 47f + leafLife * 360f,
                    color,
                    FlameCrop(index),
                    (index & 1) != 0);
            }
            debrisBatch?.Commit();
        }

        void DrawPhoenixFlameTrail(
            Vector3 center,
            Vector3 travelAxis,
            in Frame frame,
            float phase,
            float time,
            float length,
            float width,
            float visibility)
        {
            if (flameBatch == null || visibility <= 0.001f)
                return;

            var axis = travelAxis.sqrMagnitude > 0.001f
                ? travelAxis.normalized
                : frame.CameraUp;
            var radial = Vector3.Cross(frame.CameraForward, axis).normalized;
            if (radial.sqrMagnitude < 0.001f)
                radial = frame.CameraRight;

            Set(flameMaterial, "_Phase", time * 7.2f + phase * 0.20f);
            Set(flameMaterial, "_Intensity", 1.48f);
            Set(flameMaterial, "_DeepColor", new Color(0.20f, 0.008f, 0.001f, 1f));
            Set(flameMaterial, "_Tint", new Color(0.96f, 0.16f, 0.008f, 1f));
            Set(flameMaterial, "_HotColor", new Color(1.0f, 0.78f, 0.08f, 1f));
            Set(flameMaterial, "_WarmColor", new Color(1.0f, 0.96f, 0.66f, 1f));
            Set(flameMaterial, "_WarmAmount", 0.040f);
            Set(flameMaterial, "_AlphaCap", 0.48f);
            Set(flameMaterial, "_FlowDissolve", 0.18f);
            Set(flameMaterial, "_VertexMix", 0.64f);

            flameBatch.Begin();
            var root = center - axis * (length * 0.16f);
            for (var index = 0; index < 2; index++)
            {
                var side = index == 0 ? -1f : 1f;
                var rootColor = Color.Lerp(
                    new Color(0.92f, 0.10f, 0.005f, 1f),
                    new Color(1.0f, 0.50f, 0.02f, 1f),
                    index * 0.18f);
                rootColor.a = visibility * 0.34f;
                var tipColor = Color.Lerp(
                    new Color(1.0f, 0.56f, 0.02f, 1f),
                    new Color(1.0f, 0.94f, 0.42f, 1f),
                    index * 0.18f);
                tipColor.a = visibility * 0.10f;
                flameBatch.AddCurvedRibbon(
                    root + radial * (side * width * 0.32f),
                    -axis,
                    radial * side,
                    frame.CameraForward,
                    length * Mathf.Lerp(0.82f, 1.08f, index * 0.20f),
                    width * 0.30f,
                    width * (0.72f + index * 0.08f),
                    side * 0.018f,
                    phase + index * 2.4f,
                    9,
                    width * 0.92f,
                    rootColor,
                    tipColor,
                    FlameCrop(index),
                    time + index * 0.04f,
                    0.24f + index * 0.19f,
                    0.22f);
            }
            flameBatch.Commit();
        }

        void SampleImpactBack(in SpellSample sample, in Frame frame, float phase, float contact)
        {
            var time = sample.AbsoluteTime;
            var expansion = Ease(contact + 0.020f, contact + 0.32f, time);
            var radialExpansion = Ease(contact + 0.020f, contact + 0.245f, time);
            var compression = Ease(contact - 0.040f, contact, time);
            // Use a real compressed beat instead of a long smooth scale:
            // 82% compression, a 40-50 ms hold, then a 1.15x release
            // overshoot that eases back to normal over roughly 70 ms.
            var impactHold = Ease(contact - 0.002f, contact + 0.002f, time)
                * (1f - Ease(contact + 0.040f, contact + 0.050f, time));
            var compressedScale = Mathf.Lerp(1f, 0.82f, compression);
            // Hold the compressed state through the contact beat, then make
            // the release a near single-frame change so the impact has a
            // clear snap without increasing brightness or particle count.
            var releaseProgress = Ease(contact + 0.050f, contact + 0.068f, time);
            var releaseReturn = Ease(contact + 0.068f, contact + 0.128f, time);
            var releaseScale = Mathf.Lerp(0.82f, 1.15f, releaseProgress);
            releaseScale = Mathf.Lerp(releaseScale, 1f, releaseReturn);
            var shapePulse = Mathf.Lerp(releaseScale, 0.82f, impactHold);
            shapePulse = Mathf.Lerp(compressedScale, shapePulse,
                Mathf.Clamp01(releaseProgress + releaseReturn));
            // Let the pressure body finish before the particle release takes
            // over. Keeping this tail too long makes the final frame read as
            // a second green funnel instead of a detonation breaking apart.
            var visibility = Ease(contact - 0.025f, contact + 0.02f, time)
                * (1f - Ease(contact + 0.12f, contact + 0.24f, time));
            if (visibility <= 0.001f)
            {
                ClearBatches();
                return;
            }

            var center = sample.Target + frame.CameraUp * (0.08f * sample.Scale.x);
            // The player review called out the effect's small impact area.
            // Open the actual pressure volume in both axes so the hit reads
            // as a body slamming into the target, not a narrow vertical
            // ribbon. The front burst supplies the radial punctuation below.
            var releaseVolume = Mathf.Pow(
                Ease(contact + 0.045f, contact + 0.085f, time), 0.24f);
            var stage4HeightScale = 1.16f
                * Mathf.Lerp(1f, 1.07f, releaseVolume);
            var stage4WidthScale = 1.28f
                * Mathf.Lerp(1f, 1.12f, releaseVolume);
            // The previous version was technically large but visually too
            // fine at phone size. Give the storm a real hero silhouette: a
            // broader body, thicker open volume, and stronger value separation
            // while retaining the broken funnel surface and depth holes.
            var heroImpactScale = 1.32f;
            var height = Mathf.Lerp(0.60f, 1.72f, expansion)
                * shapePulse * stage4HeightScale * heroImpactScale * sample.Scale.x;
            var bottomRadius = Mathf.Lerp(0.06f, 0.18f, radialExpansion)
                * Mathf.Lerp(0.78f, 1f, shapePulse)
                * stage4WidthScale * heroImpactScale * sample.Scale.x;
            var waistRadius = Mathf.Lerp(0.22f, 0.45f, radialExpansion)
                * Mathf.Lerp(0.84f, 1f, shapePulse)
                * stage4WidthScale * heroImpactScale * sample.Scale.x;
            var topRadius = Mathf.Lerp(0.34f, 0.56f, radialExpansion)
                * Mathf.Lerp(0.86f, 1f, shapePulse)
                * stage4WidthScale * heroImpactScale * sample.Scale.x;
            var root = ScaleRgb(DeepGreen, 1.08f);
            var stage3Density = 1f
                + (1f - Ease(contact + 0.080f, contact + 0.300f, time))
                    * 0.14f;
            // Add weight only to the inner/central wind body. The outer
            // silhouette stays at the approved density so the tornado does
            // not become a larger, brighter green blob.
            var stage3CoreDensity = 1f
                + (1f - Ease(contact + 0.100f, contact + 0.240f, time))
                    * 0.26f;
            // Keep the broad volume below the front explosion alpha. The old
            // additive overlap was turning the peak into a white-green plate.
            root.a = visibility * 0.34f * 1.05f * stage3Density;
            var mid = ScaleRgb(Color.Lerp(Emerald, Leaf, 0.24f), 1.08f);
            mid.a = visibility * 0.50f * stage3Density
                * stage3CoreDensity;
            var tip = ScaleRgb(Color.Lerp(Leaf, BridgeLime, 0.42f), 1.04f);
            tip.a = visibility * 0.46f * stage3Density;
            var rootB = ScaleRgb(Color.Lerp(DeepGreen, Emerald, 0.32f), 0.90f);
            rootB.a = visibility * 0.14f * 1.05f;
            var midB = ScaleRgb(Color.Lerp(Emerald, BridgeLime, 0.34f), 0.88f);
            midB.a = visibility * 0.20f * stage3CoreDensity;
            var tipB = ScaleRgb(BridgeLime, 0.82f);
            tipB.a = visibility * 0.18f;

            // After the hit has registered, accelerate the main UV flow for
            // 40-60 ms, then return to the normal phase rate.  Integrating
            // the extra phase keeps the motion continuous at both ends.
            var postHitFlowTime = time;
            if (time > contact + 0.040f)
                postHitFlowTime += Mathf.Min(time - (contact + 0.040f), 0.060f) * 0.20f;
            var impactAngularPhase = phase;
            if (time > contact)
            {
                // Add only the integrated angular offset for a short 20%
                // speed kick. Once the 35 ms window closes, normal rotation
                // continues from the new phase instead of snapping back.
                impactAngularPhase += Mathf.Min(time - contact, 0.035f)
                    * 8.8f * 0.20f;
            }
            var impactColorLift = Mathf.Clamp01(0.28f + releaseVolume * 0.72f);
            var bodyHot = Color.Lerp(BridgeLime, SoftGold,
                0.10f + impactColorLift * 0.18f);
            var windHot = Color.Lerp(BridgeLime, LemonGold,
                0.22f + impactColorLift * 0.20f);
            Set(bodyMaterial, "_Phase", postHitFlowTime * 2.07f + phase * 0.17f);
            Set(bodyMaterial, "_Intensity", 1.34f);
            Set(bodyMaterial, "_DeepColor", Color.Lerp(DeepGreen, Emerald, 0.12f));
            Set(bodyMaterial, "_Tint", Color.Lerp(Emerald, Leaf, 0.46f));
            Set(bodyMaterial, "_HotColor", bodyHot);
            Set(bodyMaterial, "_WarmColor", SoftGold);
            Set(bodyMaterial, "_WarmAmount", 0.024f);
            Set(bodyMaterial, "_AlphaCap", 0.42f);
            Set(bodyMaterial, "_CutLow", 0.002f);
            Set(bodyMaterial, "_CutHigh", 0.10f);
            Set(bodyMaterial, "_EdgeErode", 0.10f);
            Set(bodyMaterial, "_Distortion", 0.075f);
            Set(bodyMaterial, "_SourceMix", 0.10f);
            Set(bodyMaterial, "_VertexMix", 0.24f);
            Set(bodyMaterial, "_FlowDissolve", 0.28f);
            Set(bodyMaterial, "_VortexEye", 0.16f);
            Set(windMaterial, "_Phase", postHitFlowTime * 2.99f + phase * 0.23f);
            Set(windMaterial, "_Intensity", 1.24f);
            Set(windMaterial, "_DeepColor", Emerald);
            Set(windMaterial, "_Tint", Color.Lerp(Leaf, BridgeLime, 0.34f));
            Set(windMaterial, "_HotColor", windHot);
            Set(windMaterial, "_WarmColor", SoftGold);
            Set(windMaterial, "_WarmAmount", 0.020f);
            Set(windMaterial, "_AlphaCap", 0.28f);
            Set(windMaterial, "_FlowDissolve", 0.34f);
            Set(windMaterial, "_VortexEye", 0.12f);
            bodyBatch?.Begin();
            windBatch?.Begin();
            // Add a small stack of moving body fragments inside the open
            // funnel. These are existing blue_fire atlas crops, deliberately
            // depth-offset and alpha-limited: they give the impact weight at
            // phone size without turning the whole effect into one opaque
            // rectangle.
            AddImpactBodyCards(center, in frame, impactAngularPhase + 0.34f,
                height * 0.90f, bottomRadius * 1.16f, topRadius * 1.16f,
                visibility * 0.72f);
            AddImpactWindCards(center, in frame, impactAngularPhase + 1.06f,
                height * 0.84f, topRadius * 1.12f, visibility * 0.40f);
            // Two short mint glints ride the pressure body during release.
            // They are curved strips made from the existing Wind atlas, so
            // the impact gains a rotating highlight without another asset or
            // a flat full-screen flash.
            var glintVisibility = visibility
                * Mathf.Lerp(0.34f, 0.72f, releaseVolume);
            var glintRoot = Color.Lerp(Leaf, BridgeLime, 0.42f);
            glintRoot.a = glintVisibility * 0.28f;
            var glintTip = Color.Lerp(BridgeLime, SoftGold, 0.22f);
            glintTip.a = glintVisibility * 0.44f;
            windBatch?.AddCurvedRibbon(
                center - frame.CameraUp * (height * 0.30f)
                    + frame.CameraRight * (topRadius * 0.12f),
                frame.CameraUp,
                frame.CameraRight,
                frame.CameraForward,
                height * 0.72f,
                topRadius * 0.10f,
                topRadius * 0.34f,
                0.58f,
                impactAngularPhase + 0.72f,
                11,
                topRadius * 0.22f,
                glintRoot,
                glintTip,
                WindCrop(1),
                time + 0.04f,
                0.27f);
            var glintRootB = Color.Lerp(BridgeLime, SoftGold, 0.26f);
            glintRootB.a = glintVisibility * 0.20f;
            var glintTipB = Ember;
            glintTipB.a = glintVisibility * 0.34f;
            windBatch?.AddCurvedRibbon(
                center - frame.CameraUp * (height * 0.18f)
                    - frame.CameraRight * (topRadius * 0.16f),
                frame.CameraUp,
                frame.CameraRight,
                frame.CameraForward,
                height * 0.58f,
                topRadius * 0.08f,
                topRadius * 0.28f,
                -0.46f,
                impactAngularPhase + 3.10f,
                10,
                topRadius * 0.18f,
                glintRootB,
                glintTipB,
                WindCrop(3),
                time + 0.11f,
                0.71f);
            bodyBatch?.AddOpenFunnelSurface(
                center - frame.CameraUp * (height * 0.46f),
                frame.CameraRight,
                frame.CameraUp,
                frame.CameraForward,
                height * 1.10f,
                bottomRadius * 1.22f,
                waistRadius * 1.22f,
                topRadius * 1.20f,
                0.46f,
                0.72f,
                1.15f,
                165f * Mathf.Deg2Rad,
                impactAngularPhase + 0.15f,
                13,
                22,
                new Rect(0.08f, 0.08f, 0.70f, 0.76f),
                0.03f,
                root,
                mid,
                tip,
                time,
                Mathf.Repeat(Mathf.Abs(impactAngularPhase + 0.17f), 1f),
                0.00f,
                1.00f);
            bodyBatch?.AddOpenFunnelSurface(
                center - frame.CameraUp * (height * 0.45f)
                    + frame.CameraRight * (sample.Scale.x * 0.018f),
                frame.CameraRight,
                frame.CameraUp,
                frame.CameraForward,
                height * 0.96f,
                bottomRadius * 0.98f,
                waistRadius * 0.90f,
                topRadius * 0.86f,
                0.50f,
                0.76f,
                0.82f,
                132f * Mathf.Deg2Rad,
                impactAngularPhase + 2.42f,
                12,
                20,
                new Rect(0.18f, 0.10f, 0.62f, 0.70f),
                0.24f,
                rootB,
                midB,
                tipB,
                time + 0.07f,
                Mathf.Repeat(Mathf.Abs(impactAngularPhase + 0.41f), 1f),
                0.15f,
                0.92f);
            windBatch?.AddOpenFunnelSurface(
                center - frame.CameraUp * (height * 0.43f)
                    - frame.CameraRight * (sample.Scale.x * 0.022f),
                frame.CameraRight,
                frame.CameraUp,
                frame.CameraForward,
                height * 0.88f,
                bottomRadius * 0.86f,
                waistRadius * 0.78f,
                topRadius * 0.78f,
                0.44f,
                0.80f,
                1.48f,
                96f * Mathf.Deg2Rad,
                impactAngularPhase + 4.91f,
                11,
                18,
                new Rect(0.06f, 0.12f, 0.88f, 0.68f),
                0.41f,
                WithAlpha(ScaleRgb(Color.Lerp(Emerald, Leaf, 0.20f), 0.90f), visibility * 0.085f),
                WithAlpha(ScaleRgb(Color.Lerp(Leaf, BridgeLime, 0.30f), 0.88f), visibility * 0.102f),
                WithAlpha(ScaleRgb(BridgeLime, 0.82f), visibility * 0.078f),
                time - 0.04f,
                Mathf.Repeat(Mathf.Abs(impactAngularPhase + 0.73f), 1f),
                0.35f,
                1.00f);

            // v23 made the footprint large enough, but the user still saw a
            // wireframe made of many thin cuts. This central body is the
            // missing mass: one broad, depth-curled blue_fire surface with
            // fewer holes and a stronger mid-value. It stays behind the
            // impact-front ribbons, so the explosion keeps a readable core
            // instead of becoming a flat opaque card.
            var massRoot = Color.Lerp(DeepGreen, Emerald, 0.28f);
            massRoot.a = visibility * 0.26f;
            var massMid = Color.Lerp(Emerald, Leaf, 0.30f);
            massMid.a = visibility * 0.42f;
            var massTip = Color.Lerp(Leaf, BridgeLime, 0.24f);
            massTip.a = visibility * 0.32f;
            bodyBatch?.AddOpenFunnelSurface(
                center - frame.CameraUp * (height * 0.43f)
                    + frame.CameraRight * (sample.Scale.x * 0.010f),
                frame.CameraRight,
                frame.CameraUp,
                frame.CameraForward,
                height * 0.94f,
                bottomRadius * 1.34f,
                waistRadius * 1.30f,
                topRadius * 1.26f,
                0.48f,
                0.78f,
                0.38f,
                338f * Mathf.Deg2Rad,
                impactAngularPhase + 0.72f,
                13,
                28,
                new Rect(0.02f, 0.02f, 0.96f, 0.94f),
                0.36f,
                massRoot,
                massMid,
                massTip,
                time + 0.11f,
                Mathf.Repeat(Mathf.Abs(impactAngularPhase + 0.58f), 1f),
                0.04f,
                0.98f);
            // Two phase-offset support bodies close the negative space left
            // by the photographed atlas. Their lower alpha preserves depth,
            // while the overlap makes the center read as a thick moving
            // volume instead of a collection of filaments.
            var supportRoot = Color.Lerp(DeepGreen, Emerald, 0.24f);
            supportRoot.a = visibility * 0.10f;
            var supportMid = Color.Lerp(Emerald, Leaf, 0.26f);
            supportMid.a = visibility * 0.15f;
            var supportTip = Color.Lerp(Leaf, BridgeLime, 0.22f);
            supportTip.a = visibility * 0.11f;
            bodyBatch?.AddOpenFunnelSurface(
                center - frame.CameraUp * (height * 0.40f)
                    + frame.CameraForward * (sample.Scale.x * 0.034f),
                frame.CameraRight,
                frame.CameraUp,
                frame.CameraForward,
                height * 0.86f,
                bottomRadius * 1.22f,
                waistRadius * 1.18f,
                topRadius * 1.18f,
                0.50f,
                0.72f,
                0.58f,
                286f * Mathf.Deg2Rad,
                impactAngularPhase + 2.18f,
                11,
                24,
                new Rect(0.06f, 0.05f, 0.88f, 0.90f),
                0.71f,
                supportRoot,
                supportMid,
                supportTip,
                time + 0.19f,
                Mathf.Repeat(Mathf.Abs(impactAngularPhase + 0.91f), 1f),
                0.08f,
                0.96f);
            bodyBatch?.AddOpenFunnelSurface(
                center - frame.CameraUp * (height * 0.45f)
                    - frame.CameraForward * (sample.Scale.x * 0.028f),
                frame.CameraRight,
                frame.CameraUp,
                frame.CameraForward,
                height * 0.80f,
                bottomRadius * 1.16f,
                waistRadius * 1.12f,
                topRadius * 1.10f,
                0.46f,
                0.68f,
                0.74f,
                270f * Mathf.Deg2Rad,
                impactAngularPhase + 4.06f,
                10,
                22,
                new Rect(0.10f, 0.08f, 0.80f, 0.82f),
                0.23f,
                supportRoot,
                supportMid,
                supportTip,
                time + 0.27f,
                Mathf.Repeat(Mathf.Abs(impactAngularPhase + 0.37f), 1f),
                0.12f,
                0.92f);
            // The outer pressure layer is deliberately quieter than the
            // visible cuts. It adds a little compressed air around the peak
            // without increasing the green brightness or introducing another
            // readable ribbon.
            bodyBatch?.AddOpenFunnelSurface(
                center - frame.CameraUp * (height * 0.48f),
                frame.CameraRight,
                frame.CameraUp,
                frame.CameraForward,
                height * 1.12f,
                bottomRadius * 1.30f,
                waistRadius * 1.26f,
                topRadius * 1.20f,
                0.48f,
                0.90f,
                0.58f,
                238f * Mathf.Deg2Rad,
                impactAngularPhase + 1.22f,
                9,
                18,
                new Rect(0.02f, 0.02f, 0.96f, 0.94f),
                0.62f,
                WithAlpha(Color.Lerp(DeepGreen, Emerald, 0.18f), visibility * 0.030f),
                WithAlpha(Color.Lerp(Emerald, Leaf, 0.22f), visibility * 0.027f),
                WithAlpha(Color.Lerp(Leaf, BridgeLime, 0.16f), visibility * 0.021f),
                time + 0.13f,
                Mathf.Repeat(Mathf.Abs(impactAngularPhase + 0.87f), 1f));
            bodyBatch?.Commit();
            windBatch?.Commit();
        }

        void SampleImpactFront(in SpellSample sample, in Frame frame, float phase, float contact)
        {
            // The Phoenix-only impact owns the contact release. The previous
            // implementation below authored a tornado shell, wind ring, and
            // spiral coils; none of that belongs in this attack now.
            ApplyCameraShake(in sample, phase, contact);
            SamplePhoenixImpactOnly(in sample, in frame, phase, contact);
            return;

            var time = sample.AbsoluteTime;
            // The front layer is the two-frame hit punctuation. The slower
            // tornado volume lives in impact-back; keeping this layer brief
            // makes the strike read as compress -> burst -> curl instead of a
            // smooth enlargement of the same shell.
            var compression = Ease(contact - 0.040f, contact + 0.002f, time)
                * (1f - Ease(contact + 0.034f, contact + 0.096f, time));
            // Let the existing impact ribbons survive into the 1.30 s review
            // frame. This exposes the release punctuation without adding a
            // new particle layer or increasing brightness.
            var shell = Ease(contact + 0.030f, contact + 0.070f, time)
                * (1f - Ease(contact + 0.22f, contact + 0.48f, time));
            var explosionOpen = Ease(contact + 0.004f, contact + 0.080f, time);
            var explosionFade = 1f - Ease(contact + 0.28f, contact + 0.62f, time);
            var explosionVisibility = explosionOpen * explosionFade;
            // The pressure flash is allowed to peak, then it must hand the
            // frame over to discrete debris. Without this short hand-off the
            // Burst/Flame bloom leaves a flat horizontal star behind the
            // particles and the result no longer reads as an explosion
            // breaking apart.
            var particleBreakFade = 1f
                - Ease(contact + 0.12f, contact + 0.24f, time);
            // Let the smooth ring/coil silhouette collapse quickly after the
            // hit. The release then reads as discrete material being thrown
            // outward instead of one more large additive disc.
            var shapeFade = 1f - Ease(contact + 0.10f, contact + 0.26f, time);
            var shapeVisibility = explosionVisibility * shapeFade;
            var particleVisibility = Mathf.Pow(
                Ease(contact + 0.035f, contact + 0.14f, time), 0.72f)
                * (1f - Ease(contact + 0.48f, contact + 0.84f, time));
            var armVisibility = Mathf.Max(
                Ease(contact - 0.005f, contact + 0.035f, time),
                explosionVisibility * 0.92f)
                * (1f - Ease(contact + 0.24f, contact + 0.48f, time))
                * shapeFade;
            var visibility = Mathf.Max(compression, shell);
            if (visibility <= 0.001f)
            {
                ClearBatches();
                return;
            }

            var center = sample.Target - frame.CameraForward * 0.12f;
            var armGrowth = Ease(contact + 0.010f, contact + 0.100f, time);
            var shearCurl = Ease(contact + 0.080f, contact + 0.180f, time);
            var impactSnap = Ease(contact - 0.004f, contact + 0.004f, time)
                * (1f - Ease(contact + 0.040f, contact + 0.050f, time));
            // Keep the contact frame compressed, then use a steep release
            // curve so the next review frame reads as a detonation rather
            // than a continuously widening vortex.
            var releasePunch = Mathf.Pow(
                Ease(contact + 0.018f, contact + 0.060f, time), 0.32f);
            var shockPunch = Mathf.Pow(
                Ease(contact + 0.028f, contact + 0.066f, time), 0.24f);
            var shockFade = 1f - Ease(contact + 0.30f, contact + 0.58f, time);
            var shockVisibility = shockPunch * shockFade;
            var coilVisibility = shockVisibility * shapeFade;
            var burstScale = time <= contact + 0.012f
                ? 0.78f
                : time <= contact + 0.075f
                    ? Mathf.Lerp(0.78f, 1.78f,
                        Ease(contact + 0.012f, contact + 0.075f, time))
                    : Mathf.Lerp(1.78f, 1.42f,
                        Ease(contact + 0.075f, contact + 0.34f, time));
            // A short outward inertia beat after release makes the existing
            // ribbons read as an impact spray rather than a static ring.
            var radialRelease = Mathf.Pow(
                    Ease(contact + 0.028f, contact + 0.080f, time), 0.32f)
                * (1f - Ease(contact + 0.36f, contact + 0.60f, time));
            var radialSpray = 1f + radialRelease * 0.48f;
            // The outer reach jumps during release instead of arriving by a
            // long smooth scale tween. This is the visual distinction between
            // "风压散开" and "砸中后炸开".
            var explosionReach = Mathf.Lerp(0.68f, 2.34f, releasePunch);
            var hitCoreScale = Mathf.Lerp(0.94f, 1.46f, releasePunch);
            var detonationHot = Color.Lerp(BridgeLime, LemonGold,
                0.18f + releasePunch * 0.26f);
            Set(burstMaterial, "_DeepColor", Emerald);
            Set(burstMaterial, "_Tint", Leaf);
            Set(burstMaterial, "_HotColor", detonationHot);
            Set(burstMaterial, "_WarmColor", SoftGold);
            Set(burstMaterial, "_WarmAmount", 0.028f);
            Set(burstMaterial, "_AlphaCap", 0.56f);
            Set(burstMaterial, "_Intensity", 1.42f);
            Set(flameMaterial, "_DeepColor", LeafDeep);
            Set(flameMaterial, "_Tint", Color.Lerp(Leaf, BridgeLime, 0.36f));
            Set(flameMaterial, "_HotColor", BridgeLime);
            Set(flameMaterial, "_WarmColor", SoftGold);
            Set(flameMaterial, "_WarmAmount", 0.024f);
            Set(flameMaterial, "_AlphaCap", 0.40f);
            Set(flameMaterial, "_Intensity", 1.35f);
            Set(debrisMaterial, "_DeepColor", Emerald);
            Set(debrisMaterial, "_Tint", Leaf);
            Set(debrisMaterial, "_HotColor", BridgeLime);
            Set(debrisMaterial, "_WarmColor", SoftGold);
            Set(debrisMaterial, "_WarmAmount", 0.018f);
            Set(debrisMaterial, "_AlphaCap", 0.48f);
            Set(goldMaterial, "_DeepColor", SoftGold);
            Set(goldMaterial, "_Tint", SoftGold);
            Set(goldMaterial, "_HotColor", Ember);
            Set(goldMaterial, "_WarmColor", WarmWhite);
            Set(goldMaterial, "_WarmAmount", 0.025f);
            Set(goldMaterial, "_AlphaCap", 0.42f);
            Set(goldMaterial, "_Intensity", 1.18f);
            Set(windMaterial, "_Phase", time * 6.40f + phase * 0.38f);
            Set(windMaterial, "_DeepColor", Emerald);
            Set(windMaterial, "_Tint", Color.Lerp(Leaf, BridgeLime, 0.38f));
            Set(windMaterial, "_HotColor", LemonGold);
            Set(windMaterial, "_WarmColor", SoftGold);
            Set(windMaterial, "_WarmAmount", 0.025f);
            Set(windMaterial, "_AlphaCap", 0.40f);
            Set(windMaterial, "_Intensity", 1.35f);
            Set(windMaterial, "_ArcSpan", Mathf.Lerp(0.86f, 1.0f, releasePunch));
            Set(windMaterial, "_FlowDissolve", 0.08f);
            Set(windMaterial, "_VortexEye", 0.12f);
            Set(windMaterial, "_VertexMix", 0.30f);
            burstBatch?.Begin();
            flameBatch?.Begin();
            debrisBatch?.Begin();
            goldBatch?.Begin();
            windBatch?.Begin();
            particleBatch?.Begin();
            AddDetonationParticles(
                particleBatch,
                center,
                in frame,
                phase,
                time,
                contact,
                sample.Scale.x,
                particleVisibility);
            // At the review peak the hit has already finished its pressure
            // beat. Commit only the discrete release from this point onward;
            // otherwise the older burst ribbons remain visible underneath and
            // make the explosion look like a flat star with particles on top.
            if (time >= contact + 0.24f)
            {
                burstBatch?.Commit();
                flameBatch?.Commit();
                debrisBatch?.Commit();
                goldBatch?.Commit();
                windBatch?.Commit();
                particleBatch?.Commit();
                return;
            }
            // Reintroduce the tornado's centre of force at the exact moment
            // of the detonation. The Wind atlas supplies a rotating pressure
            // ring, while the coils below keep the blast from becoming a flat
            // eight-point star.
            var vortexScale = Mathf.Lerp(0.78f, 1.34f, releasePunch)
                * hitCoreScale;
            var vortexRing = Color.Lerp(Emerald, BridgeLime, 0.42f);
            vortexRing.a = shapeVisibility * 0.30f;
            windBatch?.AddQuad(
                center + frame.CameraForward * 0.002f,
                frame.CameraRight,
                frame.CameraUp,
                sample.Scale.x * 1.26f * vortexScale,
                sample.Scale.x * 0.76f * vortexScale,
                phase * 7.4f,
                vortexRing,
                WindFullCrop(),
                false,
                false);
            var vortexRingHot = Color.Lerp(LemonGold, WarmWhite, 0.16f);
            vortexRingHot.a = coilVisibility * 0.22f;
            windBatch?.AddQuad(
                center + frame.CameraForward * 0.016f,
                frame.CameraRight,
                frame.CameraUp,
                sample.Scale.x * 0.86f * vortexScale,
                sample.Scale.x * 1.08f * vortexScale,
                phase * -5.9f,
                vortexRingHot,
                WindFullCrop(),
                true,
                false);
            // A facing-open funnel makes the peak read as a tornado tearing
            // open toward the camera, rather than a starburst with a ring
            // pasted over it. The surface is built from the existing Wind
            // atlas and leaves a rotating negative-space eye through its
            // centre; the radial burst remains visible around the crown.
            var funnelRoot = Color.Lerp(Emerald, Leaf, 0.18f);
            funnelRoot.a = shapeVisibility * 0.24f;
            var funnelMid = Color.Lerp(Leaf, BridgeLime, 0.46f);
            funnelMid.a = shapeVisibility * 0.34f;
            var funnelTip = Color.Lerp(LemonGold, WarmWhite, 0.16f);
            funnelTip.a = coilVisibility * 0.28f;
            windBatch?.AddOpenFunnelSurface(
                center - frame.CameraForward * 0.12f,
                frame.CameraRight,
                frame.CameraForward,
                frame.CameraForward,
                sample.Scale.x * 0.54f * vortexScale,
                sample.Scale.x * 0.08f * vortexScale,
                sample.Scale.x * 0.30f * vortexScale,
                sample.Scale.x * 1.08f * vortexScale,
                0.36f,
                0.72f,
                1.55f,
                292f * Mathf.Deg2Rad,
                phase + time * 1.10f,
                9,
                24,
                new Rect(0.03f, 0.03f, 0.94f, 0.94f),
                0.36f,
                funnelRoot,
                funnelMid,
                funnelTip,
                time + 0.03f,
                Mathf.Repeat(Mathf.Abs(phase + 0.17f), 1f));
            var coilLength = sample.Scale.x
                * Mathf.Lerp(0.46f, 0.86f, shockPunch)
                * explosionReach * 0.58f;
            for (var index = 0; index < 5; index++)
            {
                var coilAngle = (index * 72f - 14f) * Mathf.Deg2Rad
                    + phase * 0.10f;
                var coilDirection = (frame.CameraRight * Mathf.Cos(coilAngle)
                    + frame.CameraUp * Mathf.Sin(coilAngle)).normalized;
                var coilTangent = (frame.CameraRight * -Mathf.Sin(coilAngle)
                    + frame.CameraUp * Mathf.Cos(coilAngle)).normalized;
                var coilRoot = index % 2 == 0
                    ? Color.Lerp(Leaf, BridgeLime, 0.34f)
                    : Color.Lerp(Emerald, BridgeLime, 0.36f);
                coilRoot.a = coilVisibility * (0.22f - index * 0.008f);
                var coilTip = index == 2
                    ? Color.Lerp(BridgeLime, SoftGold, 0.36f)
                    : Color.Lerp(LemonGold, WarmWhite, 0.18f);
                coilTip.a = coilVisibility * (0.30f - index * 0.010f);
                windBatch?.AddCurvedRibbon(
                    center - coilDirection * coilLength * 0.12f
                        + frame.CameraForward * (0.020f + index * 0.004f),
                    coilDirection,
                    coilTangent,
                    frame.CameraForward,
                    coilLength * (0.94f + index * 0.035f),
                    sample.Scale.x * 0.035f,
                    sample.Scale.x * (0.24f + index * 0.016f),
                    index % 2 == 0 ? 0.76f : -0.66f,
                    coilAngle + 0.70f,
                    12,
                    sample.Scale.x * (0.13f + index * 0.012f),
                    coilRoot,
                    coilTip,
                    WindFullCrop(),
                    time + index * 0.041f,
                    0.16f + index * 0.19f);
            }
            for (var index = 0; index < 2; index++)
            {
                var goldCoilAngle = (index * 180f + 42f) * Mathf.Deg2Rad
                    + phase * 0.08f;
                var goldCoilDirection = (frame.CameraRight * Mathf.Cos(goldCoilAngle)
                    + frame.CameraUp * Mathf.Sin(goldCoilAngle)).normalized;
                var goldCoilTangent = (frame.CameraRight * -Mathf.Sin(goldCoilAngle)
                    + frame.CameraUp * Mathf.Cos(goldCoilAngle)).normalized;
                var goldCoilRoot = SolarGold;
                goldCoilRoot.a = coilVisibility * 0.20f;
                var goldCoilTip = Ember;
                goldCoilTip.a = coilVisibility * 0.30f;
                goldBatch?.AddCurvedRibbon(
                    center - goldCoilDirection * coilLength * 0.10f
                        - frame.CameraForward * 0.008f,
                    goldCoilDirection,
                    goldCoilTangent,
                    frame.CameraForward,
                    coilLength * 0.76f,
                    sample.Scale.x * 0.026f,
                    sample.Scale.x * 0.14f,
                    index == 0 ? 0.88f : -0.78f,
                    goldCoilAngle + 1.12f,
                    11,
                    sample.Scale.x * 0.11f,
                    goldCoilRoot,
                    goldCoilTip,
                    BurstFullCrop(),
                    time + 0.08f + index * 0.055f,
                    0.43f + index * 0.22f);
            }
            // Eight uneven radial tongues turn the hit into a readable
            // explosion. They still use the existing Burst01_2 and
            // Fire_Single atlases; the change is their short, thick outward
            // release rather than another set of long wind lines.
            var armAngles = new[] { -170f, -128f, -88f, -42f, 4f, 48f, 96f, 142f };
            var armLengths = new[] { 0.54f, 0.46f, 0.62f, 0.50f, 0.66f, 0.52f, 0.58f, 0.48f };
            var armWidths = new[] { 0.145f, 0.126f, 0.168f, 0.138f, 0.176f, 0.142f, 0.154f, 0.132f };
            for (var index = 0; index < armAngles.Length; index++)
            {
                var angle = armAngles[index] * Mathf.Deg2Rad
                    + phase * 0.08f
                    + Mathf.Sin(phase + index * 2.41f) * 0.055f;
                var direction = (frame.CameraRight * Mathf.Cos(angle)
                    + frame.CameraUp * Mathf.Sin(angle)).normalized;
                var radialDirection = direction;
                var tangent = (frame.CameraRight * -Mathf.Sin(angle)
                    + frame.CameraUp * Mathf.Cos(angle)).normalized;
                var curledDirection = (tangent * 0.78f
                    + frame.CameraUp * 0.32f).normalized;
                direction = Vector3.Slerp(direction, curledDirection, shearCurl)
                    .normalized;
                // The existing curl gives the hit its rotation; after the
                // release, blend that same ribbon back toward its radial
                // direction so the impact visibly pushes outward.
                direction = Vector3.Slerp(direction, radialDirection,
                    radialRelease * 0.96f).normalized;
                var across = Vector3.Cross(frame.CameraForward, direction).normalized;
                if (across.sqrMagnitude < 0.001f)
                    across = frame.CameraRight;
                var root = Color.Lerp(Emerald, BridgeLime, 0.20f + index * 0.055f);
                root.a = armVisibility * (0.28f - index * 0.010f);
                var tip = index % 4 == 0
                    ? Color.Lerp(SoftGold, WarmWhite, 0.14f)
                    : Color.Lerp(BridgeLime, SoftGold, 0.10f + index * 0.045f);
                tip.a = armVisibility * (0.48f - index * 0.016f);
                var armLength = sample.Scale.x * armLengths[index]
                    * Mathf.Lerp(0.92f, 1.16f, armGrowth)
                    * explosionReach * radialSpray * 0.82f;
                var armStartBack = Mathf.Lerp(0.20f, 0.06f, releasePunch);
                var burstTurns = Mathf.Lerp(
                    0.52f + index * 0.08f,
                    0.18f + index * 0.035f,
                    releasePunch);
                burstBatch?.AddCurvedRibbon(
                    center - direction * armLength * armStartBack
                        + frame.CameraForward
                            * ((index & 1) == 0 ? 0.028f : -0.020f)
                            * sample.Scale.x * radialRelease,
                    direction,
                    across,
                    frame.CameraForward,
                    armLength,
                    sample.Scale.x * 0.022f,
                    sample.Scale.x * armWidths[index] * 1.34f,
                    burstTurns,
                    angle + phase * 0.16f,
                    13,
                    sample.Scale.x * (0.190f + index * 0.014f),
                    root,
                    tip,
                    BurstCrop(index + 1),
                    time + index * 0.047f,
                    0.20f + index * 0.31f);
                var tongueRoot = index % 3 == 0
                    ? Color.Lerp(BridgeLime, SoftGold, 0.22f)
                    : Color.Lerp(Leaf, BridgeLime, 0.12f + index * 0.10f);
                tongueRoot.a = armVisibility * 0.22f;
                var tongueTip = index % 4 == 0
                    ? Color.Lerp(SolarGold, Ember, 0.14f)
                    : Color.Lerp(BridgeLime, WarmWhite, 0.12f);
                tongueTip.a = armVisibility * 0.32f;
                flameBatch?.AddCurvedRibbon(
                    center + frame.CameraForward * 0.018f - direction * armLength * 0.06f,
                    direction,
                    across,
                    frame.CameraForward,
                    armLength * (0.58f + index * 0.035f),
                    sample.Scale.x * 0.009f,
                    sample.Scale.x * (0.074f + index * 0.009f),
                    Mathf.Lerp(0.68f, 0.30f, releasePunch),
                    angle + 0.42f,
                    10,
                    sample.Scale.x * (0.098f + index * 0.005f),
                    tongueRoot,
                    tongueTip,
                    FlameCrop(index + 1),
                    time + index * 0.061f,
                    0.61f + index * 0.13f);
            }
            // A second, thinner set of outward streaks appears only during
            // the detonation beat. It is the fast-moving outer edge of the
            // same impact, built from the existing atlases rather than a new
            // particle/material family.
            if (coilVisibility > 0.001f)
            {
                for (var index = 0; index < 8; index++)
                {
                    var angle = (index * 45f - 12f) * Mathf.Deg2Rad
                        + phase * 0.045f;
                    var direction = (frame.CameraRight * Mathf.Cos(angle)
                        + frame.CameraUp * Mathf.Sin(angle)).normalized;
                    var across = Vector3.Cross(
                        frame.CameraForward, direction).normalized;
                    if (across.sqrMagnitude < 0.001f)
                        across = frame.CameraRight;
                    var root = Color.Lerp(Leaf, BridgeLime, 0.22f);
                    root.a = coilVisibility * (0.14f - index * 0.004f);
                    var tip = index % 4 == 0
                        ? Color.Lerp(SoftGold, Ember, 0.14f)
                        : index % 3 == 0
                            ? Color.Lerp(BridgeLime, WarmWhite, 0.10f)
                            : Color.Lerp(BridgeLime, SoftGold, 0.42f);
                    tip.a = coilVisibility * (0.22f - index * 0.006f);
                    var length = sample.Scale.x
                        * Mathf.Lerp(0.28f, 1.24f, shockPunch)
                        * (1f + radialRelease * 0.18f);
                    burstBatch?.AddCurvedRibbon(
                        center - direction * length * 0.34f,
                        direction,
                        across,
                        frame.CameraForward,
                        length,
                        sample.Scale.x * 0.006f,
                        sample.Scale.x * (0.060f + index * 0.004f),
                        0.12f + index * 0.018f,
                        angle + 0.23f,
                        9,
                        sample.Scale.x * (0.074f + index * 0.004f),
                        root,
                        tip,
                        BurstCrop(index + 2),
                        time + index * 0.019f,
                        0.37f + index * 0.11f);
                }
            }
            // The center stays compact at contact, then opens with the same
            // steep release curve as the radial shell.
            // Use the complete existing Burst01_2 atlas for the detonation
            // centre. The earlier quadrant crops looked like bright shards
            // layered over the target; a full radial sample makes the peak
            // read as a single impact that throws energy outward.
            var shockBurstScale = Mathf.Lerp(0.84f, 1.34f, releasePunch);
            var shockBurst = Color.Lerp(BridgeLime, SoftGold, 0.18f);
            shockBurst.a = shapeVisibility * 0.24f;
            burstBatch?.AddQuad(
                center + frame.CameraForward * 0.010f,
                frame.CameraRight,
                frame.CameraUp,
                sample.Scale.x * 0.88f * shockBurstScale * hitCoreScale,
                sample.Scale.x * 0.88f * shockBurstScale * hitCoreScale,
                phase * 5.4f,
                shockBurst,
                BurstFullCrop(),
                false,
                false);
            // Keep the warm pass in its own material so the gold/orange
            // contrast remains visible instead of recolouring every green
            // tongue in the shared burst batch.
            var goldBurst = Color.Lerp(SoftGold, Ember, 0.12f);
            goldBurst.a = coilVisibility * 0.18f;
            goldBatch?.AddQuad(
                center - frame.CameraForward * 0.018f,
                frame.CameraRight,
                frame.CameraUp,
                sample.Scale.x * 1.22f * shockBurstScale * hitCoreScale,
                sample.Scale.x * 0.82f * shockBurstScale * hitCoreScale,
                phase * -4.6f,
                goldBurst,
                BurstFullCrop(),
                true,
                false);
            // Four asymmetric amber forks break the perfect star silhouette
            // and make the detonation feel more violent and colourful.
            for (var index = 0; index < 4; index++)
            {
                var goldAngle = (index * 90f + 18f) * Mathf.Deg2Rad
                    + phase * 0.06f;
                var goldDirection = (frame.CameraRight * Mathf.Cos(goldAngle)
                    + frame.CameraUp * Mathf.Sin(goldAngle)).normalized;
                var goldAcross = Vector3.Cross(
                    frame.CameraForward, goldDirection).normalized;
                if (goldAcross.sqrMagnitude < 0.001f)
                    goldAcross = frame.CameraRight;
                var goldRoot = SolarGold;
                goldRoot.a = coilVisibility * 0.18f;
                var goldTip = index == 1
                    ? Color.Lerp(SolarGold, Ember, 0.22f)
                    : Color.Lerp(SoftGold, Ember, 0.26f);
                goldTip.a = coilVisibility * 0.28f;
                var goldLength = sample.Scale.x
                    * Mathf.Lerp(0.62f, 0.98f, shockPunch)
                    * explosionReach * 0.64f;
                goldBatch?.AddCurvedRibbon(
                    center - goldDirection * goldLength * 0.12f
                        + frame.CameraForward * 0.006f,
                    goldDirection,
                    goldAcross,
                    frame.CameraForward,
                    goldLength,
                    sample.Scale.x * 0.028f,
                    sample.Scale.x * 0.110f,
                    0.12f + index * 0.04f,
                    goldAngle + 0.34f,
                    10,
                    sample.Scale.x * 0.128f,
                    goldRoot,
                    goldTip,
                    BurstCrop(index + 1),
                    time + index * 0.033f,
                    0.23f + index * 0.17f);
            }
            var shockBurstUnder = Color.Lerp(SoftGold, Ember, 0.10f);
            shockBurstUnder.a = shapeVisibility * 0.12f;
            burstBatch?.AddQuad(
                center - frame.CameraForward * 0.010f,
                frame.CameraRight,
                frame.CameraUp,
                sample.Scale.x * 1.20f * shockBurstScale * hitCoreScale,
                sample.Scale.x * 0.76f * shockBurstScale * hitCoreScale,
                phase * -3.8f,
                shockBurstUnder,
                BurstFullCrop(),
                true,
                false);
            // Burst01_2 is also kept as a smaller pressure bloom in front of
            // the full radial sample, adding a hot centre without hiding the
            // outward shape.
            var bloom = Color.Lerp(BridgeLime, LemonGold, 0.28f);
            bloom.a = explosionVisibility * particleBreakFade * 0.28f;
            burstBatch?.AddQuad(
                center + frame.CameraForward * 0.026f,
                frame.CameraRight,
                frame.CameraUp,
                sample.Scale.x * 0.46f * burstScale * hitCoreScale,
                sample.Scale.x * 0.37f * burstScale * hitCoreScale,
                phase * 8.5f,
                bloom,
                BurstCrop(5),
                true,
                false);
            var bloomHot = Color.Lerp(SoftGold, WarmWhite, 0.18f);
            bloomHot.a = explosionVisibility * particleBreakFade * 0.30f;
            flameBatch?.AddQuad(
                center + frame.CameraForward * 0.044f,
                frame.CameraRight,
                frame.CameraUp,
                sample.Scale.x * 0.34f * burstScale * hitCoreScale,
                sample.Scale.x * 0.52f * burstScale * hitCoreScale,
                phase * -10.5f,
                bloomHot,
                FlameCrop(1),
                false,
                true);
            var core = WarmWhite;
            core.a = compression * 0.76f;
            burstBatch?.AddQuad(center, frame.CameraRight, frame.CameraUp,
                Mathf.Lerp(0.20f, 0.28f, compression) * sample.Scale.x
                    * burstScale * hitCoreScale,
                Mathf.Lerp(0.24f, 0.36f, compression) * sample.Scale.x
                    * burstScale * hitCoreScale,
                phase * 12f, core, BurstCrop(7), true, false);
            var coreHot = WarmWhite;
            coreHot.a = compression * 0.36f;
            burstBatch?.AddQuad(
                center + frame.CameraForward * 0.018f,
                frame.CameraRight,
                frame.CameraUp,
                sample.Scale.x * 0.072f * burstScale * hitCoreScale,
                sample.Scale.x * 0.108f * burstScale * hitCoreScale,
                phase * -7f,
                coreHot,
                BurstCrop(0),
                false,
                true);
            var coreRibbonRoot = WarmWhite;
            coreRibbonRoot.a = compression * 0.36f;
            var coreRibbonTip = WarmWhite;
            coreRibbonTip.a = compression * 0.52f;
            burstBatch?.AddCurvedRibbon(
                center - frame.CameraUp
                    * (sample.Scale.x * 0.055f * burstScale * hitCoreScale),
                frame.CameraUp,
                frame.CameraRight,
                frame.CameraForward,
                sample.Scale.x * 0.14f * burstScale * hitCoreScale,
                sample.Scale.x * 0.008f,
                sample.Scale.x * 0.045f * burstScale * hitCoreScale,
                0.24f,
                phase + 0.52f,
                8,
                sample.Scale.x * 0.090f,
                coreRibbonRoot,
                coreRibbonTip,
                BurstCrop(3),
                time + 0.08f,
                0.47f);
            // Fire_Single is already in the Effekseer library and is better
            // suited to the short white-green pressure flash than another
            // large Burst01_2 card. It is tied to the brief compression pulse
            // so the hit is faster, not merely brighter.
            var pressureFlash = Color.Lerp(WarmWhite, SoftGold, 0.18f);
            pressureFlash.a = compression * 0.72f;
            flameBatch?.AddQuad(
                center + frame.CameraForward * 0.032f,
                frame.CameraRight,
                frame.CameraUp,
                sample.Scale.x * 0.24f * burstScale * hitCoreScale,
                sample.Scale.x * 0.18f * burstScale * hitCoreScale,
                phase * -11f,
                pressureFlash,
                FlameCrop(0),
                true,
                false);
            var snapFlash = Color.Lerp(WarmWhite, SoftGold, 0.22f);
            snapFlash.a = impactSnap * 0.70f;
            flameBatch?.AddQuad(
                center + frame.CameraForward * 0.040f,
                frame.CameraRight,
                frame.CameraUp,
                sample.Scale.x * 0.34f * burstScale * hitCoreScale,
                sample.Scale.x * 0.26f * burstScale * hitCoreScale,
                phase * 13f,
                snapFlash,
                FlameCrop(1),
                false,
                true);
            flameBatch?.AddQuad(
                center + frame.CameraForward * 0.044f,
                frame.CameraRight,
                frame.CameraUp,
                sample.Scale.x * 0.18f * burstScale * hitCoreScale,
                sample.Scale.x * 0.38f * burstScale * hitCoreScale,
                phase * -9f,
                WithAlpha(BridgeLime, impactSnap * 0.58f),
                FlameCrop(2),
                true,
                false);
            // A handful of short, bright shards make the release feel like a
            // detonation. They are deliberately large enough to survive the
            // phone-scale capture, but short-lived and kept in the same flame
            // batch so the effect does not become a cloud of tiny noise.
            if (shockVisibility > 0.001f)
            {
                for (var index = 0; index < 7; index++)
                {
                    var angle = (index * 51f - 18f) * Mathf.Deg2Rad
                        + phase * 0.12f;
                    var direction = (frame.CameraRight * Mathf.Cos(angle)
                        + frame.CameraUp * Mathf.Sin(angle)).normalized;
                    var distance = sample.Scale.x
                        * Mathf.Lerp(0.08f, 0.22f, index / 6f)
                        * shockPunch;
                    var shard = index == 5
                        ? Color.Lerp(SolarGold, Ember, 0.22f)
                        : index % 3 == 0
                            ? SoftGold
                            : index % 4 == 0
                                ? WarmWhite
                                : Color.Lerp(BridgeLime, Mint, (index % 4) * 0.18f);
                    shard.a = shockVisibility * (0.26f - index * 0.012f);
                    flameBatch?.AddQuad(
                        center + direction * distance
                            + frame.CameraForward * (0.046f + index * 0.004f),
                        frame.CameraRight,
                        frame.CameraUp,
                        sample.Scale.x * (0.052f + index * 0.006f)
                            * hitCoreScale,
                        sample.Scale.x * (0.16f + index * 0.018f)
                            * hitCoreScale,
                        angle * Mathf.Rad2Deg + phase * 13f,
                        shard,
                        FlameCrop(index + 1),
                        (index & 1) != 0,
                        (index & 2) != 0);
                }
            }
            AddImpactLeaves(debrisBatch, center, in frame, phase, time,
                sample.Scale.x * 1.10f, particleVisibility * 0.38f, 10, 0f,
                0.90f, 0.50f);
            burstBatch?.Commit();
            flameBatch?.Commit();
            debrisBatch?.Commit();
            goldBatch?.Commit();
            windBatch?.Commit();
            particleBatch?.Commit();
        }

        void ApplyCameraShake(
            in SpellSample sample,
            float phase,
            float contact)
        {
            var camera = sample.Camera != null ? sample.Camera : Camera.main;
            if (camera == null)
                return;

            if (!shakeCaptured || shakeCamera != camera)
            {
                shakeCamera = camera;
                shakeBasePosition = camera.transform.position;
                shakeBaseRotation = camera.transform.rotation;
                shakeCaptured = true;
            }

            var contactEnvelope = 1f
                - Ease(contact, contact + 0.045f, sample.AbsoluteTime);
            var reboundEnvelope = ImpactBurst(contact, sample.AbsoluteTime)
                * (1f - Ease(contact + 0.055f, contact + 0.20f,
                    sample.AbsoluteTime));
            var envelope = Mathf.Max(contactEnvelope, reboundEnvelope);
            if (envelope <= 0.001f)
                return;

            var age = sample.AbsoluteTime - contact;
            var frequency = 175f
                + Mathf.Repeat(Mathf.Abs(seed * 0.0137f), 1f) * 55f;
            var jitterX = Mathf.Sin(age * frequency + phase * 0.73f);
            var jitterY = Mathf.Cos(age * frequency * 1.17f + phase * 1.11f);
            var jitterZ = Mathf.Sin(age * frequency * 0.61f + phase * 1.87f);
            var localOffset = new Vector3(
                jitterX * 0.030f * envelope,
                jitterY * 0.022f * envelope,
                jitterZ * 0.010f * envelope);
            var roll = Mathf.Sin(age * frequency * 0.42f + phase)
                * 1.25f * envelope;

            camera.transform.position = shakeBasePosition
                + shakeBaseRotation * localOffset;
            camera.transform.rotation = shakeBaseRotation
                * Quaternion.AngleAxis(roll, Vector3.forward);
        }

        void RestoreCameraShake()
        {
            if (!shakeCaptured || shakeCamera == null)
                return;
            shakeCamera.transform.SetPositionAndRotation(
                shakeBasePosition,
                shakeBaseRotation);
        }

        void SamplePhoenixImpactOnly(
            in SpellSample sample,
            in Frame frame,
            float phase,
            float contact)
        {
            var time = sample.AbsoluteTime;
            var compression = 1f - Ease(contact, contact + 0.032f, time);
            var release = ImpactBurst(contact, time);
            var fade = 1f - Ease(contact + 0.22f, contact + 0.68f, time);
            var visibility = Mathf.Max(compression, release * fade);
            if (visibility <= 0.001f)
            {
                ClearBatches();
                return;
            }

            var center = sample.Target - frame.CameraForward * 0.12f;
            var scale = sample.Scale.x;
            var releaseOpen = Mathf.SmoothStep(0f, 1f, release);
            var flashVisibility = Mathf.Max(
                compression,
                release * (1f - Ease(contact + 0.07f, contact + 0.16f, time)));

            Set(burstMaterial, "_Phase", time * 8.4f + phase * 0.20f);
            Set(burstMaterial, "_DeepColor", new Color(0.25f, 0.006f, 0.001f, 1f));
            Set(burstMaterial, "_Tint", new Color(1.0f, 0.20f, 0.005f, 1f));
            Set(burstMaterial, "_HotColor", new Color(1.0f, 0.76f, 0.06f, 1f));
            Set(burstMaterial, "_WarmColor", new Color(1.0f, 0.97f, 0.68f, 1f));
            Set(burstMaterial, "_AlphaCap", 0.74f);
            Set(burstMaterial, "_Intensity", 1.70f);
            Set(flameMaterial, "_Phase", time * 9.5f + phase * 0.24f);
            Set(flameMaterial, "_DeepColor", new Color(0.22f, 0.006f, 0.001f, 1f));
            Set(flameMaterial, "_Tint", new Color(0.98f, 0.17f, 0.006f, 1f));
            Set(flameMaterial, "_HotColor", new Color(1.0f, 0.72f, 0.035f, 1f));
            Set(flameMaterial, "_WarmColor", new Color(1.0f, 0.96f, 0.62f, 1f));
            Set(flameMaterial, "_AlphaCap", 0.56f);
            Set(flameMaterial, "_Intensity", 1.62f);
            Set(goldMaterial, "_DeepColor", new Color(0.68f, 0.045f, 0.001f, 1f));
            Set(goldMaterial, "_Tint", new Color(1.0f, 0.36f, 0.008f, 1f));
            Set(goldMaterial, "_HotColor", new Color(1.0f, 0.82f, 0.08f, 1f));
            Set(goldMaterial, "_WarmColor", new Color(1.0f, 0.98f, 0.72f, 1f));
            Set(goldMaterial, "_AlphaCap", 0.72f);
            Set(goldMaterial, "_Intensity", 1.72f);
            Set(particleMaterial, "_DeepColor", new Color(0.34f, 0.008f, 0.001f, 1f));
            Set(particleMaterial, "_Tint", new Color(1.0f, 0.24f, 0.006f, 1f));
            Set(particleMaterial, "_HotColor", new Color(1.0f, 0.78f, 0.08f, 1f));
            Set(particleMaterial, "_WarmColor", new Color(1.0f, 0.98f, 0.72f, 1f));
            Set(particleMaterial, "_AlphaCap", 0.72f);
            Set(particleMaterial, "_Intensity", 1.78f);

            burstBatch?.Begin();
            flameBatch?.Begin();
            goldBatch?.Begin();
            particleBatch?.Begin();

            // A two-axis contact stamp gives the target a clear hit point;
            // it peaks on the contact sample and vanishes before the debris
            // field becomes the dominant read.
            var contactStamp = new Color(1.0f, 0.18f, 0.004f, 1f);
            contactStamp.a = compression * 0.78f;
            burstBatch?.AddQuad(
                center + frame.CameraForward * 0.052f,
                frame.CameraRight,
                frame.CameraUp,
                scale * 0.58f,
                scale * 0.16f,
                phase * 17f,
                contactStamp,
                BurstCrop(2),
                false,
                false);
            var contactStampHot = new Color(1.0f, 0.92f, 0.48f, 1f);
            contactStampHot.a = compression * 0.92f;
            goldBatch?.AddQuad(
                center + frame.CameraForward * 0.064f,
                frame.CameraRight,
                frame.CameraUp,
                scale * 0.16f,
                scale * 0.42f,
                -phase * 11f,
                contactStampHot,
                BurstCrop(0),
                true,
                false);

            var flash = new Color(1.0f, 0.56f, 0.015f, 1f);
            flash.a = flashVisibility * 0.74f;
            burstBatch?.AddQuad(
                center + frame.CameraForward * 0.018f,
                frame.CameraRight,
                frame.CameraUp,
                scale * Mathf.Lerp(0.30f, 0.92f, releaseOpen),
                scale * Mathf.Lerp(0.26f, 0.76f, releaseOpen),
                phase * 22f,
                flash,
                BurstCrop(0),
                false,
                false);

            var core = new Color(1.0f, 0.94f, 0.58f, 1f);
            core.a = flashVisibility * 0.86f;
            goldBatch?.AddQuad(
                center + frame.CameraForward * 0.032f,
                frame.CameraRight,
                frame.CameraUp,
                scale * Mathf.Lerp(0.12f, 0.36f, releaseOpen),
                scale * Mathf.Lerp(0.10f, 0.32f, releaseOpen),
                -phase * 15f,
                core,
                BurstCrop(1),
                true,
                false);

            // The mesh shader and this fragment field start on the same
            // contact sample. The initial positions follow the Phoenix's
            // chest, wings, and tail; then those pieces scatter outward so
            // the whole creature visibly disintegrates instead of becoming
            // four unrelated petals.
            AddPhoenixFragmentParticles(
                particleBatch,
                center,
                in frame,
                phase,
                time,
                contact,
                scale,
                Mathf.Max(compression * 0.72f, release * fade));

            AddDetonationParticles(
                particleBatch,
                center,
                in frame,
                phase,
                time,
                contact,
                scale,
                Mathf.Max(compression * 0.42f, release * fade));

            burstBatch?.Commit();
            flameBatch?.Commit();
            goldBatch?.Commit();
            particleBatch?.Commit();
        }

        void AddPhoenixFragmentParticles(
            AssetQuadBatch batch,
            Vector3 center,
            in Frame frame,
            float phase,
            float time,
            float contact,
            float scale,
            float visibility)
        {
            if (batch == null || visibility <= 0.001f)
                return;

            var progress = ImpactBurst(contact, time);
            var fade = 1f - Ease(contact + 0.18f, contact + 0.64f, time);
            if (fade <= 0.001f)
                return;

            const int fragmentCount = 72;
            for (var index = 0; index < fragmentCount; index++)
            {
                var randomA = Mathf.Repeat(
                    Mathf.Sin((index + 1) * 19.193f + phase * 0.11f)
                    * 31741.173f, 1f);
                var randomB = Mathf.Repeat(
                    Mathf.Sin((index + 1) * 47.719f + phase * 0.23f)
                    * 19753.911f, 1f);
                var randomC = Mathf.Repeat(
                    Mathf.Sin((index + 1) * 83.117f + phase * 0.37f)
                    * 27183.441f, 1f);

                // Sample three broad regions of the authored Phoenix read:
                // swept wings, chest/head, and the lower tail. These are the
                // coherent birth positions before the pieces are thrown out.
                float localX;
                float localY;
                if (index < 38)
                {
                    var side = (index & 1) == 0 ? -1f : 1f;
                    localX = side * Mathf.Lerp(0.18f, 0.92f, randomA);
                    localY = Mathf.Lerp(0.02f, 0.58f, randomB);
                }
                else if (index < 57)
                {
                    localX = Mathf.Lerp(-0.22f, 0.22f, randomA);
                    localY = Mathf.Lerp(-0.34f, 0.42f, randomB);
                }
                else
                {
                    localX = Mathf.Lerp(-0.34f, 0.34f, randomA);
                    localY = Mathf.Lerp(-0.88f, -0.28f, randomB);
                }

                var localOffset = frame.CameraRight * (localX * scale)
                    + frame.CameraUp * (localY * scale)
                    + frame.CameraForward * ((randomC - 0.5f) * scale * 0.16f);
                var direction = (localOffset.normalized
                    + frame.CameraForward * ((randomB - 0.5f) * 0.42f)
                    + frame.CameraRight * ((randomA - 0.5f) * 0.22f)).normalized;
                if (direction.sqrMagnitude < 0.001f)
                    direction = frame.CameraUp;

                var scatterDistance = scale
                    * Mathf.Lerp(0.035f, 1.72f, randomC)
                    * progress;
                var gravity = frame.CameraUp
                    * (-scale * 0.06f * progress * progress * randomA);
                var point = center + localOffset * (1f - progress * 0.78f)
                    + direction * scatterDistance + gravity;

                var color = index % 13 == 0
                    ? new Color(1.0f, 0.98f, 0.72f, 1f)
                    : index % 7 == 0
                        ? new Color(1.0f, 0.72f, 0.05f, 1f)
                        : index % 3 == 0
                            ? new Color(1.0f, 0.34f, 0.008f, 1f)
                            : Color.Lerp(
                                new Color(0.78f, 0.035f, 0.001f, 1f),
                                new Color(1.0f, 0.60f, 0.025f, 1f),
                                randomB);
                color.a = visibility * fade
                    * Mathf.Lerp(0.38f, 0.92f, randomA)
                    * Mathf.Lerp(0.72f, 1f, progress);

                var width = scale * Mathf.Lerp(
                    index < 38 ? 0.030f : 0.021f,
                    index < 38 ? 0.092f : 0.064f,
                    randomB) * Mathf.Lerp(0.86f, 1.18f, progress);
                var height = scale * Mathf.Lerp(
                    index < 38 ? 0.052f : 0.032f,
                    index < 38 ? 0.19f : 0.13f,
                    randomC) * Mathf.Lerp(0.88f, 1.22f, progress);
                batch.AddQuad(
                    point,
                    frame.CameraRight,
                    frame.CameraUp,
                    width,
                    height,
                    randomA * 360f + time * Mathf.Lerp(220f, 520f, randomC),
                    color,
                    ParticleCrop(index),
                    (index & 1) != 0,
                    (index & 2) != 0);
            }
        }

        void AddDetonationParticles(
            AssetQuadBatch batch,
            Vector3 center,
            in Frame frame,
            float phase,
            float time,
            float contact,
            float scale,
            float visibility)
        {
            if (batch == null || visibility <= 0.001f)
                return;

            var progress = ImpactBurst(contact, time);
            var fade = 1f - Ease(contact + 0.22f, contact + 0.68f, time);
            var scatter = Mathf.SmoothStep(0f, 1f, progress);
            if (fade <= 0.001f)
                return;

            // Deterministic small quads turn the pressure ring into a spray of
            // existing Particle01 atlas fragments. The distribution is radial
            // but not a perfect circle, so the last frame reads as material
            // being thrown apart rather than a second geometric shell.
            const int particleCount = 56;
            for (var index = 0; index < particleCount; index++)
            {
                var randomA = Mathf.Repeat(
                    Mathf.Sin((index + 1) * 12.9898f + phase * 0.17f)
                    * 43758.5453f, 1f);
                var randomB = Mathf.Repeat(
                    Mathf.Sin((index + 1) * 78.233f + phase * 0.31f)
                    * 19341.173f, 1f);
                var randomC = Mathf.Repeat(
                    Mathf.Sin((index + 1) * 39.346f + phase * 0.53f)
                    * 25173.719f, 1f);
                var angle = phase * 0.045f
                    + index * 2.399963f
                    + (randomA - 0.5f) * 0.42f;
                var radial = (frame.CameraRight * Mathf.Cos(angle)
                    + frame.CameraUp * Mathf.Sin(angle)).normalized;
                var depth = (randomB - 0.5f) * 0.42f;
                var direction = (radial + frame.CameraForward * depth).normalized;
                var distance = scale * (
                    0.055f
                    + Mathf.Lerp(0.18f, 1.55f, randomC)
                        * Mathf.Lerp(0.22f, 1.0f, scatter));
                var gravity = frame.CameraUp
                    * (-scale * 0.045f * scatter * scatter * randomA);
                var point = center + direction * distance + gravity;
                var color = index % 11 == 0
                    ? Color.Lerp(new Color(1.0f, 0.98f, 0.72f, 1f),
                        new Color(1.0f, 0.26f, 0.005f, 1f), 0.24f)
                    : index % 7 == 0
                        ? Color.Lerp(new Color(1.0f, 0.88f, 0.20f, 1f),
                            new Color(1.0f, 0.42f, 0.008f, 1f), 0.30f)
                        : index % 5 == 0
                            ? new Color(1.0f, 0.72f, 0.06f, 1f)
                        : index % 3 == 0
                                ? new Color(1.0f, 0.52f, 0.012f, 1f)
                                : Color.Lerp(
                                    new Color(0.90f, 0.08f, 0.003f, 1f),
                                    new Color(1.0f, 0.64f, 0.035f, 1f),
                                    0.34f + randomB * 0.42f);
                color.a = visibility * fade
                    * Mathf.Lerp(0.34f, 0.82f, randomA)
                    * Mathf.Lerp(0.72f, 1f, scatter);
                var width = scale * Mathf.Lerp(0.016f, 0.046f, randomB)
                    * Mathf.Lerp(0.72f, 1.10f, scatter);
                var height = scale * Mathf.Lerp(0.024f, 0.092f, randomC)
                    * Mathf.Lerp(0.76f, 1.18f, scatter);
                batch.AddQuad(
                    point,
                    frame.CameraRight,
                    frame.CameraUp,
                    width,
                    height,
                    angle * Mathf.Rad2Deg
                        + Mathf.Lerp(-42f, 42f, randomC)
                        + time * Mathf.Lerp(160f, 420f, randomA),
                    color,
                    ParticleCrop(index),
                    (index & 1) != 0,
                    (index & 2) != 0);
            }
        }

        void SampleAccent(in SpellSample sample, in Frame frame, float phase, float contact)
        {
            var time = sample.AbsoluteTime;
            var pulse = Ease(contact - 0.018f, contact + 0.045f, time);
            var visibility = pulse * (1f - Ease(contact + 0.10f, contact + 0.25f, time));
            if (visibility <= 0.001f)
            {
                ClearBatches();
                return;
            }

            var center = sample.Target - frame.CameraForward * 0.16f;
            Set(burstMaterial, "_DeepColor", new Color(0.24f, 0.006f, 0.001f, 1f));
            Set(burstMaterial, "_Tint", new Color(1.0f, 0.18f, 0.004f, 1f));
            Set(burstMaterial, "_HotColor", new Color(1.0f, 0.70f, 0.04f, 1f));
            Set(burstMaterial, "_WarmColor", new Color(1.0f, 0.95f, 0.62f, 1f));
            Set(burstMaterial, "_WarmAmount", 0.028f);
            Set(burstMaterial, "_Intensity", 1.42f);
            Set(debrisMaterial, "_DeepColor", new Color(0.24f, 0.006f, 0.001f, 1f));
            Set(debrisMaterial, "_Tint", new Color(1.0f, 0.20f, 0.004f, 1f));
            Set(debrisMaterial, "_HotColor", new Color(1.0f, 0.68f, 0.04f, 1f));
            Set(debrisMaterial, "_WarmColor", new Color(1.0f, 0.95f, 0.62f, 1f));
            Set(debrisMaterial, "_WarmAmount", 0.018f);
            burstBatch?.Begin();
            debrisBatch?.Begin();
            var flashHalo = Color.Lerp(
                new Color(1.0f, 0.26f, 0.008f, 1f),
                new Color(1.0f, 0.90f, 0.28f, 1f),
                0.36f);
            flashHalo.a = visibility * 0.34f;
            burstBatch?.AddQuad(center + frame.CameraForward * 0.008f,
                frame.CameraRight, frame.CameraUp,
                sample.Scale.x * 0.24f,
                sample.Scale.x * 0.16f,
                phase * -6f,
                flashHalo,
                BurstCrop(2),
                false,
                true);
            var flashCore = new Color(1.0f, 0.98f, 0.72f, 1f);
            flashCore.a = visibility * 0.42f;
            burstBatch?.AddQuad(center, frame.CameraRight, frame.CameraUp,
                sample.Scale.x * 0.18f,
                sample.Scale.x * 0.22f,
                phase * 9f,
                flashCore,
                BurstCrop(0),
                true,
                false);
            AddImpactLeaves(debrisBatch, center, in frame, phase + 0.8f, time,
                sample.Scale.x, visibility * 0.42f, 4, 0.045f);
            burstBatch?.Commit();
            debrisBatch?.Commit();
        }

        static Vector3 TravelAxis(in SpellSample sample, in Frame frame)
        {
            var direction = Vector3.ProjectOnPlane(sample.Target - sample.Source, frame.CameraForward);
            if (direction.sqrMagnitude < 0.001f)
                direction = frame.CameraUp;
            return direction.normalized;
        }

        void ClearBatches()
        {
            phoenixMesh?.Hide();
            ClearBatch(bodyBatch);
            ClearBatch(windBatch);
            ClearBatch(flameBatch);
            ClearBatch(burstBatch);
            ClearBatch(debrisBatch);
            ClearBatch(goldBatch);
            ClearBatch(particleBatch);
        }

        static void ClearBatch(AssetQuadBatch batch)
        {
            if (batch == null)
                return;
            batch.Begin();
            batch.Commit();
        }

        void AddImpactLeaves(
            AssetQuadBatch batch,
            Vector3 center,
            in Frame frame,
            float phase,
            float time,
            float scale,
            float amount,
            int count = 18,
            float birthOffset = 0f,
            float spreadMultiplier = 1f,
            float sizeMultiplier = 1f)
        {
            if (batch == null || amount <= 0.001f)
                return;

            for (var index = 0; index < count; index++)
            {
                float birth;
                float life;
                if (index < 7)
                {
                    birth = birthOffset + 0.995f + (index % 4) * 0.015f;
                    life = 0.66f + (index % 3) * 0.075f;
                }
                else if (index < 14)
                {
                    birth = birthOffset + 1.09f + (index - 7) * 0.015f;
                    life = 0.76f + ((index + 1) % 3) * 0.075f;
                }
                else
                {
                    birth = birthOffset + 1.22f + (index - 14) * 0.035f;
                    life = 0.90f + (index % 2) * 0.10f;
                }
                if (time < birth)
                    continue;

                var age = time - birth;
                var progress = Mathf.Clamp01(age / life);
                if (progress >= 0.995f)
                    continue;

                var classIndex = index % 3;
                var spin = Mathf.Lerp(2.1f, 4.8f, progress)
                    * (index % 2 == 0 ? 1f : -1f);
                var angle = phase * 0.22f + index * 2.399f
                    + spin * progress
                    + Mathf.Sin(index * 1.91f + phase) * 0.18f;
                var radialDistance = scale * Mathf.Lerp(
                    0.12f + classIndex * 0.030f,
                    0.46f + classIndex * 0.10f,
                    Mathf.SmoothStep(0f, 1f, progress)) * spreadMultiplier;
                var tangent = scale * Mathf.Lerp(0.055f, 0.22f, progress)
                    * spreadMultiplier;
                var point = center
                    + frame.CameraRight * Mathf.Cos(angle) * radialDistance
                    + frame.CameraUp * Mathf.Sin(angle) * radialDistance * 0.55f
                    + frame.CameraForward * Mathf.Sin(angle * 1.7f + index) * scale * 0.035f
                    + frame.CameraUp * Mathf.Lerp(0.015f, 0.40f, progress) * scale
                    + frame.CameraRight * Mathf.Sin(angle + Mathf.PI * 0.5f) * tangent;
                var color = index % 20 >= 18
                    ? Color.Lerp(Ember, SolarGold, 0.34f)
                    : index % 20 >= 15
                        ? Color.Lerp(SolarGold, Spring, 0.28f)
                        : index % 20 >= 12
                            ? Color.Lerp(Leaf, Spring, 0.18f)
                            : Color.Lerp(LeafDeep, Emerald, 0.32f + classIndex * 0.10f);
                var fade = 1f - Ease(0.84f, 1f, progress);
                color.a = amount * fade * Mathf.Lerp(0.50f, 0.82f, 1f - progress);
                var leafReadability = 1.20f * sizeMultiplier;
                batch.AddLeaf(
                    point,
                    frame.CameraRight,
                    frame.CameraUp,
                    scale * leafReadability
                        * Mathf.Lerp(0.026f, 0.066f, classIndex / 2f),
                    scale * leafReadability
                        * Mathf.Lerp(0.17f, 0.36f, classIndex / 2f),
                    angle * Mathf.Rad2Deg + (index % 2 == 0 ? 18f : -24f)
                        + progress * (index % 2 == 0 ? 520f : -680f),
                    color,
                    FlameCrop(index + 1),
                    (index & 1) != 0);
            }
        }

        void AddResidualLeaves(
            AssetQuadBatch batch,
            Vector3 center,
            in Frame frame,
            float phase,
            float time,
            float length,
            float radius,
            float amount)
        {
            if (batch == null || amount <= 0.001f)
                return;

            var radial = Vector3.Cross(frame.CameraForward, Vector3.up).normalized;
            if (radial.sqrMagnitude < 0.001f)
                radial = frame.CameraRight;
            var lift = Vector3.up;
            for (var index = 0; index < 4; index++)
            {
                var isSlowHeroLeaf = index == 3;
                var birth = isSlowHeroLeaf
                    ? 1.30f
                    : 1.20f + index * 0.07f;
                // The leaves intentionally outlive the residual wind by a
                // visible 0.12-0.18 s, so the audience reads air that is
                // still moving after the vortex body has cleared.
                var life = isSlowHeroLeaf
                    ? 1.80f
                    : 1.38f + index * 0.04f + (index % 2) * 0.10f;
                if (time < birth)
                    continue;
                var progress = Mathf.Clamp01((time - birth) / life);
                if (progress >= 0.995f)
                    continue;

                var side = index % 2 == 0 ? 1f : -1f;
                var angle = phase * 0.18f + index * 2.31f;
                var tangent = (frame.CameraRight * Mathf.Cos(angle)
                    + frame.CameraUp * Mathf.Sin(angle) * 0.45f).normalized;
                var finalUpCurl = isSlowHeroLeaf
                    ? Ease(1.66f, 1.80f, time)
                    : 0f;
                var point = center
                    + lift * (length * Mathf.Lerp(0.06f,
                        isSlowHeroLeaf ? 1.27f : 0.90f, progress))
                    + lift * (length * finalUpCurl * 0.24f)
                    + tangent * (length * Mathf.Lerp(0.115f,
                        isSlowHeroLeaf ? 0.80f : 0.53f, progress) * side)
                    + radial * Mathf.Sin(angle + progress * 2.4f)
                        * radius * Mathf.Lerp(0.30f,
                            isSlowHeroLeaf ? 1.21f : 0.86f, progress)
                    + frame.CameraForward * Mathf.Sin(angle * 1.7f)
                        * radius * 0.24f;
                var color = isSlowHeroLeaf
                    ? Color.Lerp(SolarGold, Leaf, 0.28f)
                    : index == 2
                    ? Color.Lerp(SolarGold, Spring, 0.18f)
                    : index == 1
                        ? Color.Lerp(Leaf, Lime, 0.18f)
                        : Color.Lerp(LeafDeep, Emerald, 0.34f);
                var heroMemory = isSlowHeroLeaf
                    ? Mathf.Lerp(1f, 1.18f, Ease(1.68f, 1.78f, time))
                    : 1f;
                color.a = amount * (1f - progress) * 0.78f * heroMemory;
                var leafScale = Mathf.Max(0.72f,
                    length * (isSlowHeroLeaf ? 1.78f : 1.55f));
                batch.AddLeaf(
                    point,
                    frame.CameraRight,
                    frame.CameraUp,
                    leafScale * (isSlowHeroLeaf
                        ? 0.068f
                        : index % 2 == 0 ? 0.058f : 0.072f),
                    leafScale * (isSlowHeroLeaf
                        ? 0.29f
                        : index % 2 == 0 ? 0.19f : 0.25f),
                    angle * Mathf.Rad2Deg + progress * (side > 0f ? 720f : -840f),
                    color,
                    FlameCrop(index + 1),
                    (index & 1) != 0);
            }
        }

        void AddImpactBodyCards(Vector3 center, in Frame frame, float phase,
            float height, float bottomRadius, float topRadius, float visibility)
        {
            if (bodyBatch == null)
                return;

            for (var index = 0; index < 5; index++)
            {
                var s = (index + 0.5f) / 5f;
                var angle = phase * 0.22f + index * 1.43f;
                var radius = Mathf.Lerp(bottomRadius, topRadius, s);
                var point = center
                    + frame.CameraUp * (height * (s - 0.42f))
                    + frame.CameraRight * Mathf.Cos(angle) * radius * 0.42f
                    + frame.CameraForward * Mathf.Sin(angle) * radius * 0.10f;
                var color = index % 4 == 0
                    ? Color.Lerp(Spring, SolarGold, 0.24f + s * 0.22f)
                    : index % 2 == 0
                        ? Color.Lerp(Leaf, Mint, 0.28f + s * 0.24f)
                        : Color.Lerp(Lime, Spring, 0.24f + s * 0.22f);
                color = Color.Lerp(color, WhiteGreen, 0.06f + s * 0.12f);
                color.a = visibility * Mathf.Lerp(0.46f, 0.72f, s);
                bodyBatch.AddQuad(
                    point,
                    frame.CameraRight,
                    frame.CameraUp,
                    radius * Mathf.Lerp(0.58f, 1.12f, s),
                    height * Mathf.Lerp(0.22f, 0.36f, s),
                    angle * Mathf.Rad2Deg + phase * 8f,
                    color,
                    BodyFragmentCrop(index + 2),
                    (index & 1) != 0,
                    (index & 2) != 0);
            }
        }

        void AddImpactWindCards(Vector3 center, in Frame frame, float phase,
            float height, float topRadius, float visibility)
        {
            if (windBatch == null)
                return;

            for (var index = 0; index < 4; index++)
            {
                var s = (index + 0.5f) / 4f;
                var angle = phase * 0.35f + index * 1.61f;
                var point = center
                    + frame.CameraUp * (height * (s - 0.38f))
                    + frame.CameraRight * Mathf.Cos(angle) * topRadius * (0.30f + s * 0.36f)
                    + frame.CameraForward * (0.035f + Mathf.Sin(angle) * topRadius * 0.08f);
                var color = index == 2
                    ? Color.Lerp(SolarGold, WhiteGreen, 0.28f + s * 0.18f)
                    : Color.Lerp(Mint, Spring, 0.18f + s * 0.40f);
                color = Color.Lerp(color, WhiteGreen, 0.08f + s * 0.12f);
                color.a = visibility * Mathf.Lerp(0.22f, 0.38f, s);
                windBatch.AddQuad(
                    point,
                    frame.CameraRight,
                    frame.CameraUp,
                    topRadius * Mathf.Lerp(0.52f, 0.88f, s),
                    height * Mathf.Lerp(0.24f, 0.40f, s),
                    angle * Mathf.Rad2Deg - phase * 10f,
                    color,
                    WindCrop(index),
                    index % 2 == 0,
                    index % 3 == 0);
            }
        }

        void AddTravelVortexCards(AssetQuadBatch batch, bool bodyTexture,
            Vector3 center, Vector3 axis, in Frame frame, float phase,
            float length, float radius, float visibility, bool carryDetail)
        {
            if (batch == null)
                return;

            var radial = Vector3.Cross(frame.CameraForward, axis).normalized;
            if (radial.sqrMagnitude < 0.001f)
                radial = frame.CameraRight;
            var count = carryDetail ? 6 : 5;
            for (var index = 0; index < count; index++)
            {
                var s = (index + 0.5f) / count;
                var angle = phase * 0.30f + index * 1.77f;
                var localRadius = radius * Mathf.Lerp(0.24f, 1.0f, s);
                var point = center
                    + axis * ((s - 0.50f) * length * 0.92f)
                    + radial * Mathf.Sin(angle) * localRadius * 0.72f
                    + frame.CameraForward * Mathf.Cos(angle) * localRadius * 0.16f;
                var color = Color.Lerp(Leaf, WhiteGreen, 0.18f + s * 0.48f);
                color.a = visibility * Mathf.Lerp(0.40f, 0.68f, s);
                batch.AddQuad(
                    point,
                    frame.CameraRight,
                    frame.CameraUp,
                    radius * Mathf.Lerp(0.28f, 0.86f, s),
                    Mathf.Max(radius * 0.42f, length * Mathf.Lerp(0.16f, 0.30f, s)),
                    angle * Mathf.Rad2Deg + phase * 11f,
                    color,
                    bodyTexture ? BodyFragmentCrop(index) : WindCrop(index + 1),
                    (index & 1) != 0,
                    (index & 2) != 0);
            }
        }

        void AddTravelWindCards(Vector3 center, Vector3 axis, in Frame frame,
            float phase, float length, float radius, float visibility, bool carryDetail)
        {
            if (windBatch == null)
                return;

            var radial = Vector3.Cross(frame.CameraForward, axis).normalized;
            if (radial.sqrMagnitude < 0.001f)
                radial = frame.CameraRight;
            var count = carryDetail ? 4 : 3;
            for (var index = 0; index < count; index++)
            {
                var s = (index + 0.35f) / count;
                var angle = phase * 0.36f + index * 2.18f;
                var point = center
                    + axis * ((s - 0.48f) * length * 0.82f)
                    + radial * Mathf.Cos(angle) * radius * (0.44f + s * 0.28f)
                    + frame.CameraForward * (0.04f + Mathf.Sin(angle) * radius * 0.10f);
                var color = Color.Lerp(Lime, WhiteGreen, 0.28f + s * 0.36f);
                color.a = visibility * Mathf.Lerp(0.18f, 0.30f, s);
                windBatch.AddQuad(
                    point,
                    frame.CameraRight,
                    frame.CameraUp,
                    radius * Mathf.Lerp(0.70f, 1.15f, s),
                    Mathf.Max(radius * 0.58f, length * Mathf.Lerp(0.18f, 0.32f, s)),
                    angle * Mathf.Rad2Deg - phase * 9f,
                    color,
                    WindCrop(index + 2),
                    index % 2 == 0,
                    index % 3 == 0);
            }
        }

        void DrawPhoenixStrike(Vector3 center, Vector3 attackAxis, in Frame frame,
            float phase, float time, float length, float radius, float visibility,
            bool carryDetail, float flowMultiplier = 1.0f,
            float scaleMultiplier = 1.0f,
            float explosion = 0.0f)
        {
            if (visibility <= 0.001f)
            {
                phoenixMesh?.Hide();
                return;
            }

            if (phoenixMesh == null || !phoenixMesh.IsAvailable)
                return;

            // The supplied 3D Phoenix is the entire travelling silhouette.
            // Do not add the old vortex body, wind rings, open funnels, or
            // procedural bird cards around it.
            var modelGrowth = Ease(0.08f, 0.86f, time);
            var targetHeight = Mathf.Lerp(0.22f, 1.50f, modelGrowth)
                * Mathf.Max(0.10f, scaleMultiplier);
            var modelCenter = center + frame.CameraForward * 0.024f
                + frame.CameraUp * (targetHeight * 0.04f);
            phoenixMesh.Sample(
                modelCenter,
                frame.CameraUp,
                frame.CameraForward,
                targetHeight,
                visibility,
                phase,
                time,
                explosion);
            return;

            if (attackAxis.sqrMagnitude < 0.001f)
                attackAxis = frame.CameraUp;
            attackAxis.Normalize();
            // Keep the travelling silhouette front-facing. The strike moves
            // along the travel vector, but the phoenix itself must retain a
            // centred head and two readable wings during flight.
            attackAxis = frame.CameraUp;
            var wingAxis = frame.CameraRight;

            // Scale the supplied mesh directly over the flight beat. The old
            // procedural phoenix was driven by the vortex radius, which made
            // it appear as a huge bird immediately at the source. This mesh
            // now starts small and reaches its readable attack size only as
            // it approaches the target.
            var legacyModelGrowth = Ease(0.08f, 0.86f, time);
            var heroScale = Mathf.Lerp(0.22f, 1.50f, legacyModelGrowth)
                * Mathf.Max(0.10f, scaleMultiplier);
            var bodyLength = Mathf.Clamp(
                length * (carryDetail ? 0.42f : 0.37f),
                heroScale * 0.72f,
                heroScale * 1.46f);
            var wingSpan = Mathf.Clamp(
                radius * (carryDetail ? 1.95f : 2.10f),
                heroScale * 1.00f,
                heroScale * 2.00f);
            var bodyWidth = Mathf.Clamp(
                radius * (carryDetail ? 0.42f : 0.48f),
                heroScale * 0.16f,
                heroScale * 0.34f);

            bodyBatch?.Begin();
            windBatch?.Begin();
            flameBatch?.Begin();

            if (bodyMaterial != null)
            {
                Set(bodyMaterial, "_Phase", time * 2.18f * flowMultiplier + phase * 0.16f);
                Set(bodyMaterial, "_Intensity", carryDetail ? 1.40f : 1.32f);
                Set(bodyMaterial, "_DeepColor", DeepGreen);
                Set(bodyMaterial, "_Tint", Color.Lerp(Emerald, Leaf, 0.34f));
                Set(bodyMaterial, "_HotColor", Color.Lerp(Lime, Spring, 0.26f));
                Set(bodyMaterial, "_WarmColor", SoftGold);
                Set(bodyMaterial, "_WarmAmount", 0.034f);
                Set(bodyMaterial, "_AlphaCap", carryDetail ? 0.58f : 0.54f);
                Set(bodyMaterial, "_VolumeFill", carryDetail ? 0.48f : 0.40f);
                Set(bodyMaterial, "_VertexMix", 0.72f);
                Set(bodyMaterial, "_FlowDissolve", 0.18f);
                Set(bodyMaterial, "_VortexEye", 0.08f);
            }
            if (windMaterial != null)
            {
                Set(windMaterial, "_Phase", time * 4.40f * flowMultiplier + phase * 0.24f);
                Set(windMaterial, "_Intensity", 1.46f);
                Set(windMaterial, "_DeepColor", Emerald);
                Set(windMaterial, "_Tint", Color.Lerp(Leaf, Lime, 0.34f));
                Set(windMaterial, "_HotColor", LemonGold);
                Set(windMaterial, "_WarmColor", SolarGold);
                Set(windMaterial, "_WarmAmount", 0.046f);
                Set(windMaterial, "_AlphaCap", 0.50f);
                Set(windMaterial, "_VertexMix", 0.82f);
                Set(windMaterial, "_FlowDissolve", 0.20f);
                Set(windMaterial, "_VortexEye", 0.12f);
            }
            if (flameMaterial != null)
            {
                Set(flameMaterial, "_Phase", time * 5.80f * flowMultiplier + phase * 0.28f);
                Set(flameMaterial, "_Intensity", 1.46f);
                Set(flameMaterial, "_DeepColor", LeafDeep);
                Set(flameMaterial, "_Tint", Color.Lerp(Leaf, Lime, 0.24f));
                Set(flameMaterial, "_HotColor", LemonGold);
                Set(flameMaterial, "_WarmColor", WarmWhite);
                Set(flameMaterial, "_WarmAmount", 0.034f);
                Set(flameMaterial, "_AlphaCap", 0.52f);
                Set(flameMaterial, "_VertexMix", 0.78f);
            }

            // The mesh owns the creature silhouette. Effekseer materials only
            // provide a restrained aura and travel wake around it.
            var contourBatch = bodyBatch != null ? bodyBatch : windBatch;
            var silhouetteWidth = Mathf.Clamp(
                heroScale * (carryDetail ? 1.22f : 1.14f), 0.12f, 2.80f);
            var silhouetteHeight = Mathf.Clamp(
                heroScale * (carryDetail ? 1.10f : 1.04f), 0.16f, 2.60f);
            var wingFlap = Mathf.Sin(time * 8.20f + phase * 0.45f) * 0.075f;
            var tailSway = Mathf.Sin(time * 4.60f + phase * 0.32f) * 0.052f;
            var contourCenter = center + frame.CameraForward * 0.024f
                + frame.CameraUp * (heroScale * 0.015f);

            if (phoenixMesh != null && phoenixMesh.IsAvailable)
            {
                // The FBX is the complete phoenix read. Keep it as one
                // renderer and use the shader only for the engine-side wing
                // beat; Effekseer materials remain a restrained flight aura
                // instead of being used to assemble another bird.
                phoenixMesh.Sample(
                    contourCenter,
                    frame.CameraUp,
                    frame.CameraForward,
                    silhouetteHeight * (carryDetail ? 0.98f : 1.02f),
                    visibility,
                    phase,
                    time,
                    0.0f);

                var aura = Color.Lerp(Emerald, Leaf, 0.24f);
                aura.a = visibility * (carryDetail ? 0.085f : 0.105f);
                bodyBatch?.AddEllipse(
                    contourCenter - frame.CameraForward * 0.048f,
                    frame.CameraRight,
                    frame.CameraUp,
                    silhouetteWidth * 0.82f,
                    silhouetteHeight * 0.86f,
                    phase * 18f,
                    aura,
                    BodyCrop(1),
                    false,
                    false);

                var hotAura = Color.Lerp(Leaf, LemonGold, 0.48f);
                hotAura.a = visibility * (carryDetail ? 0.050f : 0.064f);
                flameBatch?.AddEllipse(
                    contourCenter + frame.CameraForward * 0.010f,
                    frame.CameraRight,
                    frame.CameraUp,
                    silhouetteWidth * 0.58f,
                    silhouetteHeight * 0.66f,
                    -phase * 13f,
                    hotAura,
                    FlameCrop(0),
                    true,
                    false);

                for (var sideIndex = 0; sideIndex < 2; sideIndex++)
                {
                    var side = sideIndex == 0 ? -1f : 1f;
                    var root = contourCenter
                        + frame.CameraRight * (side * heroScale * 0.18f)
                        + frame.CameraUp * (heroScale * 0.18f);
                    var rootColor = Color.Lerp(Emerald, Leaf, 0.34f);
                    rootColor.a = visibility * (carryDetail ? 0.060f : 0.078f);
                    var tipColor = Color.Lerp(Lime, LemonGold, 0.30f);
                    tipColor.a = visibility * (carryDetail ? 0.105f : 0.135f);
                    windBatch?.AddCurvedRibbon(
                        root,
                        frame.CameraRight * side,
                        frame.CameraUp,
                        frame.CameraForward,
                        heroScale * (carryDetail ? 0.72f : 0.82f),
                        heroScale * 0.035f,
                        heroScale * 0.15f,
                        side * 0.34f,
                        phase + sideIndex * 2.4f,
                        10,
                        heroScale * 0.075f,
                        rootColor,
                        tipColor,
                        WindFullCrop(),
                        time + sideIndex * 0.05f,
                        0.32f + sideIndex * 0.16f);
                }

                bodyBatch?.Commit();
                windBatch?.Commit();
                flameBatch?.Commit();
                return;
            }

            // Never fall back to the old card-built bird. If the supplied FBX
            // cannot load, leave the travel aura empty and report the asset
            // problem instead of silently recreating the deleted phoenix.
            bodyBatch?.Commit();
            windBatch?.Commit();
            flameBatch?.Commit();
            return;

            var contourColor = Color.white;
            contourColor.a = visibility * (carryDetail ? 0.94f : 0.88f);
            contourBatch?.AddPhoenixSilhouette(
                contourCenter,
                frame.CameraRight,
                frame.CameraUp,
                frame.CameraForward,
                silhouetteWidth,
                silhouetteHeight,
                contourColor,
                BodyCrop(0),
                wingFlap,
                tailSway);

            var hotContour = Color.white;
            hotContour.a = visibility * (carryDetail ? 0.30f : 0.24f);
            flameBatch?.AddPhoenixSilhouette(
                contourCenter + frame.CameraForward * 0.022f,
                frame.CameraRight,
                frame.CameraUp,
                frame.CameraForward,
                silhouetteWidth * 0.965f,
                silhouetteHeight * 0.965f,
                hotContour,
                FlameCrop(0),
                wingFlap * 1.08f,
                tailSway * 1.08f);

            contourBatch?.Commit();
            windBatch?.Commit();
            flameBatch?.Commit();
            return;

            // Legacy ribbon/card authoring remains below for comparison while
            // iterating, but is unreachable for the phoenix strike. Keeping it
            // in source avoids disturbing the approved tornado/impact helpers.
            var bodyTarget = bodyBatch != null ? bodyBatch : windBatch;
            var silhouetteHeading = Mathf.Atan2(
                Vector3.Dot(attackAxis, frame.CameraRight),
                Vector3.Dot(attackAxis, frame.CameraUp)) * Mathf.Rad2Deg;
            var wingLift = Mathf.Sin(time * 8.20f + phase * 0.45f)
                * heroScale * 0.045f;
            var legacyTailSway = Mathf.Sin(time * 4.60f + phase * 0.32f)
                * heroScale * 0.055f;

            // Put a deliberate, readable phoenix silhouette on top of the
            // existing Effekseer ribbons. The ribbons supply motion and
            // texture; these broad leaf meshes supply the unmistakable bird
            // read at phone-sized review scale: chest, swept wings, head and
            // three separated tail feathers.
            var chest = center + attackAxis * (bodyLength * 0.02f);
            var bodySilhouette = Color.Lerp(DeepGreen, Ember, 0.58f);
            bodySilhouette.a = visibility * (carryDetail ? 0.58f : 0.70f);
            bodyBatch?.AddLeaf(
                chest - frame.CameraForward * 0.010f,
                frame.CameraRight,
                frame.CameraUp,
                heroScale * 0.27f,
                heroScale * 0.50f,
                silhouetteHeading,
                bodySilhouette,
                BodyCrop(0),
                false);
            var chestColor = Color.Lerp(Ember, SolarGold, 0.42f);
            chestColor.a = visibility * (carryDetail ? 0.46f : 0.54f);
            flameBatch?.AddLeaf(
                chest + frame.CameraForward * 0.026f,
                frame.CameraRight,
                frame.CameraUp,
                heroScale * 0.22f,
                heroScale * 0.38f,
                silhouetteHeading,
                chestColor,
                FlameCrop(0),
                false);
            flameBatch?.AddEllipse(
                chest + frame.CameraForward * 0.044f,
                frame.CameraRight,
                frame.CameraUp,
                heroScale * 0.30f,
                heroScale * 0.52f,
                silhouetteHeading,
                chestColor,
                FlameCrop(0),
                false,
                false);
            var chestHot = Color.Lerp(LemonGold, WarmWhite, 0.20f);
            chestHot.a = visibility * (carryDetail ? 0.28f : 0.36f);
            flameBatch?.AddQuad(
                chest + frame.CameraForward * 0.040f,
                frame.CameraRight,
                frame.CameraUp,
                heroScale * 0.14f,
                heroScale * 0.34f,
                silhouetteHeading,
                chestHot,
                FlameCrop(1),
                true,
                false);
            flameBatch?.AddEllipse(
                chest + frame.CameraForward * 0.056f,
                frame.CameraRight,
                frame.CameraUp,
                heroScale * 0.14f,
                heroScale * 0.34f,
                silhouetteHeading,
                chestHot,
                FlameCrop(1),
                true,
                false);

            for (var silhouetteSideIndex = 0;
                silhouetteSideIndex < 2;
                silhouetteSideIndex++)
            {
                var silhouetteSide = silhouetteSideIndex == 0 ? -1f : 1f;
                var silhouetteWingAxis = wingAxis * silhouetteSide;
                var wingRoot = chest
                    + silhouetteWingAxis * (heroScale * 0.12f)
                    + attackAxis * (bodyLength * 0.14f + wingLift);
                var wingColor = silhouetteSideIndex == 0
                    ? Color.Lerp(Leaf, LemonGold, 0.58f)
                    : Color.Lerp(Lime, WarmWhite, 0.42f);
                wingColor.a = visibility * (carryDetail ? 0.42f : 0.50f);
                flameBatch?.AddLeaf(
                    wingRoot,
                    frame.CameraRight,
                    frame.CameraUp,
                    heroScale * 0.24f,
                    heroScale * 0.68f,
                    silhouetteHeading + silhouetteSide * (58f + wingFlap),
                    wingColor,
                    FlameCrop(silhouetteSideIndex + 1),
                    silhouetteSideIndex != 0);
                var outerFeather = wingRoot
                    + silhouetteWingAxis * (heroScale * 0.34f)
                    - attackAxis * (heroScale * (0.02f - wingLift * 0.40f));
                var outerColor = Color.Lerp(SolarGold, WarmWhite, 0.30f);
                outerColor.a = visibility * (carryDetail ? 0.30f : 0.38f);
                flameBatch?.AddLeaf(
                    outerFeather,
                    frame.CameraRight,
                    frame.CameraUp,
                    heroScale * 0.18f,
                    heroScale * 0.58f,
                    silhouetteHeading + silhouetteSide * (72f + wingFlap * 0.80f),
                    outerColor,
                    FlameCrop(silhouetteSideIndex + 2),
                    silhouetteSideIndex == 0);
                var wingTip = wingRoot
                    + silhouetteWingAxis * (heroScale * 0.62f)
                    - attackAxis * (heroScale * (0.24f - wingLift * 0.85f));
                var wingTipColor = Color.Lerp(LemonGold, WarmWhite, 0.34f);
                wingTipColor.a = visibility * (carryDetail ? 0.24f : 0.30f);
                flameBatch?.AddLeaf(
                    wingTip,
                    frame.CameraRight,
                    frame.CameraUp,
                    heroScale * 0.13f,
                    heroScale * 0.46f,
                    silhouetteHeading + silhouetteSide * (82f + wingFlap * 0.60f),
                    wingTipColor,
                    FlameCrop(silhouetteSideIndex + 3),
                    silhouetteSideIndex != 0);
            }

            for (var silhouetteTailIndex = 0;
                silhouetteTailIndex < 3;
                silhouetteTailIndex++)
            {
                var tailSide = silhouetteTailIndex == 0
                    ? 0f
                    : silhouetteTailIndex == 1 ? -0.34f : 0.34f;
                var tailPoint = center
                    - attackAxis * (bodyLength * (0.28f + silhouetteTailIndex * 0.04f))
                    + wingAxis * (heroScale * tailSide + tailSway
                        * (silhouetteTailIndex == 0 ? 0.35f : 1f));
                var tailColor = Color.Lerp(Ember, LemonGold,
                    0.42f + silhouetteTailIndex * 0.10f);
                tailColor.a = visibility * (carryDetail ? 0.30f : 0.42f);
                flameBatch?.AddLeaf(
                    tailPoint,
                    frame.CameraRight,
                    frame.CameraUp,
                    heroScale * (0.19f - silhouetteTailIndex * 0.018f),
                    heroScale * (0.54f - silhouetteTailIndex * 0.05f),
                    silhouetteHeading + 180f + tailSide * 18f,
                    tailColor,
                    FlameCrop(silhouetteTailIndex + 2),
                    silhouetteTailIndex == 1);
            }

            var bodyRoot = Color.Lerp(DeepGreen, Emerald, 0.28f);
            bodyRoot.a = visibility * (carryDetail ? 0.34f : 0.42f);
            var bodyTip = Color.Lerp(Lime, Spring, 0.34f);
            bodyTip.a = visibility * (carryDetail ? 0.58f : 0.52f);
            bodyTarget?.AddCurvedRibbon(
                center - attackAxis * (bodyLength * 0.48f),
                attackAxis,
                wingAxis,
                frame.CameraForward,
                bodyLength,
                bodyWidth * 0.24f,
                bodyWidth * 0.92f,
                0.10f,
                phase + 0.26f,
                carryDetail ? 16 : 14,
                bodyWidth * 1.18f,
                bodyRoot,
                bodyTip,
                BodyCrop(0),
                time,
                0.21f,
                0.18f);

            // Two opposing wing ribbons are the defining phoenix read. Keep
            // the wings broad and symmetrical, then add a weaker outer edge so
            // the silhouette survives the small portrait review frame.
            for (var sideIndex = 0; sideIndex < 2; sideIndex++)
            {
                var side = sideIndex == 0 ? -1f : 1f;
                var sideAxis = wingAxis * side;
                var wingRoot = Color.Lerp(Leaf, Lime, 0.22f + sideIndex * 0.08f);
                wingRoot.a = visibility * (carryDetail ? 0.10f : 0.14f);
                var wingTip = sideIndex == 0
                    ? Color.Lerp(LemonGold, SoftGold, 0.10f)
                    : Color.Lerp(Spring, WarmWhite, 0.16f);
                wingTip.a = visibility * (carryDetail ? 0.20f : 0.24f);
                flameBatch?.AddCurvedRibbon(
                    center + attackAxis * (bodyLength * 0.06f)
                        + sideAxis * (bodyWidth * 0.08f),
                    sideAxis,
                    attackAxis,
                    frame.CameraForward,
                    wingSpan * (1.00f - sideIndex * 0.06f),
                    bodyWidth * 0.10f,
                    bodyWidth * 0.72f,
                    sideIndex == 0 ? 0.30f : -0.24f,
                    phase + 0.72f + sideIndex * 2.84f,
                    carryDetail ? 15 : 13,
                    heroScale * 0.26f,
                    wingRoot,
                    wingTip,
                    FlameCrop(sideIndex + 1),
                    time + sideIndex * 0.05f,
                    0.34f + sideIndex * 0.27f,
                    0.16f);

                var edgeRoot = Color.Lerp(BridgeLime, LemonGold, 0.20f);
                edgeRoot.a = visibility * 0.10f;
                var edgeTip = Color.Lerp(SoftGold, Ember, 0.22f);
                edgeTip.a = visibility * 0.18f;
                windBatch?.AddCurvedRibbon(
                    center + attackAxis * (bodyLength * 0.12f)
                        + sideAxis * (bodyWidth * 0.12f),
                    sideAxis,
                    attackAxis,
                    frame.CameraForward,
                    wingSpan * 0.86f,
                    bodyWidth * 0.08f,
                    bodyWidth * 0.44f,
                    sideIndex == 0 ? 0.18f : -0.16f,
                    phase + 1.08f + sideIndex * 2.58f,
                    12,
                    heroScale * 0.18f,
                    edgeRoot,
                    edgeTip,
                    WindFullCrop(),
                    time + 0.08f,
                    0.62f + sideIndex * 0.19f,
                    0.12f);

                for (var feather = 0; feather < 3; feather++)
                {
                    var featherProgress = (feather + 1f) / 4f;
                    var featherPoint = center
                        + attackAxis * (bodyLength * (0.18f - featherProgress * 0.16f))
                        + sideAxis * (wingSpan * (0.28f + featherProgress * 0.22f));
                    var featherColor = feather == 2
                        ? Color.Lerp(SolarGold, Ember, 0.22f)
                        : Color.Lerp(LemonGold, WarmWhite, 0.16f + feather * 0.08f);
                    featherColor.a = visibility
                        * (carryDetail ? 0.08f : 0.04f - feather * 0.006f);
                    var heading = Mathf.Atan2(
                        Vector3.Dot(attackAxis, frame.CameraRight),
                        Vector3.Dot(attackAxis, frame.CameraUp)) * Mathf.Rad2Deg;
                    flameBatch?.AddQuad(
                        featherPoint,
                        frame.CameraRight,
                        frame.CameraUp,
                        heroScale * (0.12f - feather * 0.012f),
                        heroScale * (0.30f - feather * 0.025f),
                        heading + side * (48f + feather * 8f),
                        featherColor,
                        FlameCrop(feather + sideIndex + 1),
                        (feather + sideIndex) % 2 != 0,
                        feather % 2 != 0);
                }
            }

            // Three separated tail feathers keep the rear of the silhouette
            // from reading as a generic fireball or a pair of wings only.
            for (var tail = 0; tail < 3; tail++)
            {
                var side = tail == 0 ? 0f : tail == 1 ? -0.46f : 0.46f;
                var tailRadial = wingAxis * side;
                var tailRoot = Color.Lerp(Ember, Leaf, 0.24f + tail * 0.08f);
                tailRoot.a = visibility * 0.13f;
                var tailTip = Color.Lerp(Lime, SolarGold, 0.28f + tail * 0.08f);
                tailTip.a = visibility * 0.26f;
                flameBatch?.AddCurvedRibbon(
                    center - attackAxis * (bodyLength * 0.16f)
                        + tailRadial * bodyWidth * 0.16f,
                    -attackAxis,
                    wingAxis + tailRadial * 0.12f,
                    frame.CameraForward,
                    bodyLength * (0.60f + tail * 0.08f),
                    bodyWidth * 0.10f,
                    bodyWidth * (0.44f - tail * 0.035f),
                    tail == 1 ? 0.24f : -0.18f,
                    phase + 1.74f + tail * 1.38f,
                    12,
                    heroScale * (0.16f - tail * 0.012f),
                    tailRoot,
                    tailTip,
                    FlameCrop(tail + 2),
                    time + 0.12f + tail * 0.04f,
                    0.52f + tail * 0.22f,
                    0.18f);
            }

            // A compact head and crest make the front of the attack legible as
            // a bird rather than a symmetric elemental projectile.
            var neck = center + attackAxis * (bodyLength * 0.30f);
            var neckColor = Color.Lerp(Ember, Leaf, 0.32f);
            neckColor.a = visibility * (carryDetail ? 0.34f : 0.44f);
            flameBatch?.AddEllipse(
                neck + frame.CameraForward * 0.045f,
                frame.CameraRight,
                frame.CameraUp,
                heroScale * 0.22f,
                heroScale * 0.40f,
                silhouetteHeading,
                neckColor,
                FlameCrop(2),
                false,
                false);

            var head = center + attackAxis * (bodyLength * 0.62f);
            var headHeading = Mathf.Atan2(
                Vector3.Dot(attackAxis, frame.CameraRight),
                Vector3.Dot(attackAxis, frame.CameraUp)) * Mathf.Rad2Deg;
            var headColor = Color.Lerp(LemonGold, WarmWhite, 0.64f);
            headColor.a = visibility * 0.86f;
            flameBatch?.AddQuad(
                head + frame.CameraForward * 0.018f,
                frame.CameraRight,
                frame.CameraUp,
                heroScale * 0.12f,
                heroScale * 0.16f,
                headHeading,
                headColor,
                FlameCrop(0),
                true,
                false);
            var crestColor = Color.Lerp(SoftGold, Ember, 0.20f);
            crestColor.a = visibility * 0.38f;
            flameBatch?.AddLeaf(
                head + attackAxis * (heroScale * 0.13f)
                    - wingAxis * (heroScale * 0.045f),
                frame.CameraRight,
                frame.CameraUp,
                heroScale * 0.07f,
                heroScale * 0.24f,
                headHeading - 24f,
                crestColor,
                FlameCrop(2),
                false);
            flameBatch?.AddLeaf(
                head + attackAxis * (heroScale * 0.13f)
                    + wingAxis * (heroScale * 0.045f),
                frame.CameraRight,
                frame.CameraUp,
                heroScale * 0.07f,
                heroScale * 0.24f,
                headHeading + 24f,
                crestColor,
                FlameCrop(3),
                true);
            flameBatch?.AddEllipse(
                head + frame.CameraForward * 0.048f,
                frame.CameraRight,
                frame.CameraUp,
                heroScale * 0.24f,
                heroScale * 0.22f,
                headHeading,
                headColor,
                FlameCrop(0),
                true,
                false);
            var beakColor = Color.Lerp(LemonGold, WarmWhite, 0.46f);
            beakColor.a = visibility * 0.90f;
            flameBatch?.AddLeaf(
                head - attackAxis * (heroScale * 0.12f)
                    + frame.CameraForward * 0.072f,
                frame.CameraRight,
                frame.CameraUp,
                heroScale * 0.085f,
                heroScale * 0.24f,
                silhouetteHeading + 180f,
                beakColor,
                FlameCrop(1),
                false);
            var eyeColor = Ember;
            eyeColor.a = visibility * 0.86f;
            flameBatch?.AddEllipse(
                head + frame.CameraForward * 0.064f
                    - attackAxis * (heroScale * 0.01f)
                    - wingAxis * (heroScale * 0.065f),
                frame.CameraRight,
                frame.CameraUp,
                heroScale * 0.042f,
                heroScale * 0.042f,
                0f,
                eyeColor,
                FlameCrop(2),
                false,
                false);
            flameBatch?.AddEllipse(
                head + frame.CameraForward * 0.064f
                    - attackAxis * (heroScale * 0.01f)
                    + wingAxis * (heroScale * 0.065f),
                frame.CameraRight,
                frame.CameraUp,
                heroScale * 0.042f,
                heroScale * 0.042f,
                0f,
                eyeColor,
                FlameCrop(2),
                true,
                false);

            bodyBatch?.Commit();
            windBatch?.Commit();
            flameBatch?.Commit();
        }

        void DrawTravelFunnel(Vector3 center, Vector3 axis, in Frame frame, float phase,
            float time, float length, float radius, float visibility, bool carryDetail,
            float flowMultiplier = 1.0f, float leafVisibility = -1.0f)
        {
            var primary = bodyBatch != null ? bodyBatch : windBatch;
            bodyBatch?.Begin();
            windBatch?.Begin();
            flameBatch?.Begin();
            // Travel direction controls where the spell moves, not which way
            // the tornado stands. Keep the visible body on the camera-up
            // axis so a phone-sized preview reads as a vertical vortex.
            if (carryDetail)
                axis = frame.CameraUp;
            if (carryDetail)
                length *= 1.38f;
            var radial = Vector3.Cross(frame.CameraForward, axis).normalized;
            if (radial.sqrMagnitude < 0.001f)
                radial = frame.CameraRight;
            // The travelling hit is meant to lift a column of air/water, not
            // draw a wireframe. Give the lower third a real belly before the
            // material's detail breaks it into visible streams.
            var baseRadius = Mathf.Max(
                radius * (carryDetail ? 0.22f : 0.27f), 0.022f * length);
            var waistRadius = Mathf.Max(
                radius * (carryDetail ? 0.32f : 0.82f),
                0.052f * length);
            var crownRadius = Mathf.Max(
                radius * (carryDetail ? 1.00f : 1.24f),
                0.086f * length);

            if (primary != null)
            {
                var primaryMaterial = primary == bodyBatch
                    ? bodyMaterial
                    : windMaterial;
                Set(primaryMaterial, "_Intensity",
                    primary == bodyBatch
                        ? (carryDetail ? 1.82f : 1.96f)
                        : (carryDetail ? 1.74f : 1.66f));
                Set(primaryMaterial, "_Phase",
                    time * (carryDetail ? 3.22f : 2.53f) * flowMultiplier
                        + phase * 0.19f);
                Set(primaryMaterial, "_AlphaCap",
                    primary == bodyBatch
                        ? (carryDetail ? 0.50f : 0.38f)
                        : (carryDetail ? 0.32f : 0.30f));
                Set(primaryMaterial, "_EdgeErode",
                    primary == bodyBatch
                        ? (carryDetail ? 0.16f : 0.32f)
                        : 0.20f);
                Set(primaryMaterial, "_FlowDissolve",
                    carryDetail ? 0.10f : 0.38f);
                Set(primaryMaterial, "_VortexEye",
                    carryDetail ? 0.18f : 0.20f);
                Set(primaryMaterial, "_VolumeFill",
                    primary == bodyBatch
                        ? (carryDetail ? 0.62f : 0.12f)
                        : (carryDetail ? 0.52f : 0.18f));
                Set(primaryMaterial, "_DeepColor",
                    Color.Lerp(DeepGreen, Emerald, carryDetail ? 0.12f : 0.06f));
                Set(primaryMaterial, "_Tint",
                    Color.Lerp(Emerald, Leaf, carryDetail ? 0.46f : 0.30f));
                Set(primaryMaterial, "_HotColor",
                    carryDetail
                        ? Color.Lerp(BridgeLime, LemonGold, 0.24f)
                        : Color.Lerp(Leaf, Spring, 0.30f));
                Set(primaryMaterial, "_WarmColor",
                    carryDetail ? Color.Lerp(SoftGold, SolarGold, 0.34f) : SoftGold);
                Set(primaryMaterial, "_WarmAmount", carryDetail ? 0.050f : 0.020f);
                // The open surfaces carry a per-vertex green -> gold palette.
                // The old value let the shared green material overpower that
                // gradient, so every layer collapsed into one green tone.
                Set(primaryMaterial, "_VertexMix", carryDetail ? 0.70f : 0.20f);
                // The residual keeps its three incomplete streams. During
                // the travelling hit, use one dedicated continuous body
                // below instead; the old extra stream was one of the layers
                // that made the silhouette read as crossed sheets.
                var surfaceCount = carryDetail ? 0 : 3;
                var baseCenter = center - axis * (length * 0.47f);
                var phaseOffsets = new[] { 0.15f, 2.42f, 4.91f };
                var coverage = new[] { 165f, 132f, 96f };
                var turns = new[] { 1.15f, 0.82f, 1.48f };
                var alpha = new[] { 0.34f, 0.20f, 0.12f };
                var startFractions = new[] { 0.00f, 0.15f, 0.35f };
                var endFractions = new[] { 1.00f, 0.92f, 1.00f };
                for (var index = 0; index < surfaceCount; index++)
                {
                    // Give the first stream a clear visual lead without
                    // increasing the total effect count: +20% apparent area
                    // for the hero stream, -25% for each support stream.
                    var areaScale = index == 0 ? 1.10f : 0.87f;
                    var axialScale = index == 0 ? 1.02f : 0.94f;
                    var visualWeight = index == 0 ? 1.09f : 0.90f;
                    var root = ScaleRgb(
                        Color.Lerp(DeepGreen, Emerald, index * 0.12f),
                        visualWeight);
                    var streamAlpha = alpha[index] * (index == 0 ? 1.0f : 0.90f);
                    root.a = visibility * streamAlpha;
                    var mid = index == 0
                        ? Color.Lerp(Leaf, BridgeLime, 0.28f)
                        : Color.Lerp(BridgeLime, SoftGold, 0.22f + index * 0.06f);
                    mid = ScaleRgb(mid, visualWeight);
                    mid.a = visibility * (streamAlpha + 0.040f);
                    var tip = index == 1
                        ? Color.Lerp(SoftGold, Ember, 0.16f)
                        : Color.Lerp(BridgeLime, SoftGold, 0.20f);
                    tip = ScaleRgb(tip, visualWeight);
                    tip.a = visibility * Mathf.Max(index == 0 ? 0.105f : 0.085f,
                        streamAlpha - 0.015f);
                    primary.AddOpenFunnelSurface(
                        baseCenter + radial * Mathf.Sin(phase + index * 1.7f) * radius * 0.045f,
                        radial,
                        axis,
                        frame.CameraForward,
                        length * (1f - index * 0.055f) * axialScale,
                        baseRadius * (1f - index * 0.06f) * areaScale,
                        waistRadius * (1f - index * 0.08f) * areaScale,
                        crownRadius * (1f - index * 0.10f) * areaScale,
                        0.47f + index * 0.025f,
                        0.72f + index * 0.04f,
                        turns[index],
                        coverage[index] * Mathf.Deg2Rad,
                        phase + phaseOffsets[index],
                        carryDetail ? 11 : 12,
                        carryDetail ? 18 : 22,
                        index == 0
                            ? new Rect(0.08f, 0.09f, 0.70f, 0.76f)
                            : index == 1
                                ? new Rect(0.18f, 0.08f, 0.62f, 0.70f)
                                : new Rect(0.22f, 0.16f, 0.52f, 0.62f),
                        index * 0.21f,
                        root,
                        mid,
                        tip,
                        time + index * 0.07f,
                        Mathf.Repeat(Mathf.Abs(phase + index * 0.37f), 1f),
                        startFractions[index],
                        endFractions[index]);
                }

                    // The previous broad mass was a second overlapping shell.
                    // It filled pixels, but its independent arc read as the
                    // diagonal slab the review rejected. The single column
                    // below is now the only hero body.
                    if (carryDetail)
                    {
                        var massRoot = Color.Lerp(DeepGreen, Emerald, 0.30f);
                    massRoot.a = 0f;
                    var massMid = Color.Lerp(BridgeLime, LemonGold, 0.24f);
                    massMid.a = 0f;
                    var massTip = Color.Lerp(LemonGold, SolarGold, 0.30f);
                    massTip.a = 0f;
                    primary.AddOpenFunnelSurface(
                        baseCenter - axis * (length * 0.025f),
                        radial,
                        axis,
                        frame.CameraForward,
                        length * 1.05f,
                        baseRadius * 1.06f,
                        waistRadius * 1.12f,
                        crownRadius * 1.06f,
                        0.44f,
                        0.78f,
                        0.78f,
                        196f * Mathf.Deg2Rad,
                        phase + 0.84f,
                        12,
                        26,
                        new Rect(0.02f, 0.02f, 0.96f, 0.94f),
                        0.47f,
                        massRoot,
                        massMid,
                        massTip,
                        time + 0.09f,
                        Mathf.Repeat(Mathf.Abs(phase + 0.52f), 1f),
                        0.04f,
                        0.98f);

                    // The travelling hit must have one continuous water
                    // column, not a pile of independent contour sheets. Its
                    // near-full angular coverage supplies the thick belly;
                    // the three narrow same-direction helices below supply
                    // the readable rotation.
                    var columnRoot = Color.Lerp(DeepGreen, Emerald, 0.22f);
                    columnRoot.a = visibility * 0.46f;
                    var columnMid = Color.Lerp(Leaf, BridgeLime, 0.48f);
                    columnMid.a = visibility * 0.60f;
                    var columnTip = Color.Lerp(LemonGold, SolarGold, 0.26f);
                    columnTip.a = visibility * 0.50f;
                    primary.AddOpenFunnelSurface(
                        baseCenter + frame.CameraForward * (radius * 0.045f),
                        radial,
                        axis,
                        frame.CameraForward,
                        length * (carryDetail ? 1.02f : 1.12f),
                        baseRadius * (carryDetail ? 1.02f : 1.42f),
                        waistRadius * (carryDetail ? 1.04f : 1.30f),
                        crownRadius * (carryDetail ? 1.00f : 1.18f),
                        carryDetail ? 0.52f : 0.46f,
                        carryDetail ? 0.82f : 0.58f,
                        carryDetail ? 1.78f : 0.64f,
                        (carryDetail ? 296f : 220f) * Mathf.Deg2Rad,
                        phase + (carryDetail ? 0.40f : 0.66f),
                        carryDetail ? 18 : 14,
                        carryDetail ? 34 : 30,
                        new Rect(0.02f, 0.02f, 0.96f, 0.94f),
                        carryDetail ? 0.10f : 0.16f,
                        columnRoot,
                        columnMid,
                        columnTip,
                        time + 0.05f,
                        Mathf.Repeat(Mathf.Abs(phase + 0.24f), 1f),
                        0.02f,
                        0.99f,
                        carryDetail ? 0.34f : 1.0f);

                    // A quiet, same-direction inner shell gives the column
                    // depth without introducing a counter-rotating sheet.
                    var innerRoot = Color.Lerp(Emerald, Leaf, 0.18f);
                    innerRoot.a = visibility * (carryDetail ? 0.08f : 0.14f);
                    var innerMid = Color.Lerp(BridgeLime, LemonGold, 0.18f);
                    innerMid.a = visibility * (carryDetail ? 0.12f : 0.20f);
                    var innerTip = Color.Lerp(LemonGold, SoftGold, 0.30f);
                    innerTip.a = visibility * (carryDetail ? 0.11f : 0.18f);
                    primary.AddOpenFunnelSurface(
                        baseCenter - frame.CameraForward * (radius * 0.038f),
                        radial,
                        axis,
                        frame.CameraForward,
                        length * (carryDetail ? 0.96f : 0.98f),
                        baseRadius * (carryDetail ? 0.94f : 1.12f),
                        waistRadius * (carryDetail ? 0.92f : 1.04f),
                        crownRadius * (carryDetail ? 0.94f : 0.98f),
                        carryDetail ? 0.54f : 0.46f,
                        carryDetail ? 0.76f : 0.72f,
                        carryDetail ? 1.60f : -0.52f,
                        (carryDetail ? 250f : 168f) * Mathf.Deg2Rad,
                        phase + (carryDetail ? 2.54f : 3.02f),
                        carryDetail ? 16 : 12,
                        carryDetail ? 30 : 26,
                        new Rect(0.06f, 0.05f, 0.88f, 0.90f),
                        carryDetail ? 0.34f : 0.42f,
                        innerRoot,
                        innerMid,
                        innerTip,
                        time + 0.13f,
                        Mathf.Repeat(Mathf.Abs(phase + 0.78f), 1f),
                        0.06f,
                        0.96f,
                        carryDetail ? 0.42f : 1.0f);

                    // These are the only readable contour lines: two hero
                    // helices and one weaker support, all turning the same
                    // way around the shared column. Counter-rotation here
                    // was making the previous version look like crossed
                    // sheets instead of one coherent vortex.
                    for (var index = 0; index < 3; index++)
                    {
                        var helixRoot = index == 1
                            ? Color.Lerp(BridgeLime, LemonGold, 0.18f)
                            : Color.Lerp(Emerald, Leaf, 0.24f);
                        helixRoot.a = visibility * (index == 2 ? 0.075f : 0.12f);
                        var helixTip = index == 1
                            ? Color.Lerp(LemonGold, Ember, 0.56f)
                            : Color.Lerp(BridgeLime, SoftGold, 0.28f);
                        helixTip.a = visibility * (index == 2 ? 0.12f : 0.20f);
                        var helixTurns = index == 0
                            ? 1.72f
                            : index == 1 ? 1.94f : 1.60f;
                        primary.AddCurvedRibbon(
                            baseCenter + frame.CameraForward
                                * ((index - 1) * radius * 0.010f),
                            axis,
                            radial,
                            frame.CameraForward,
                            length * (1.04f + index * 0.035f),
                            baseRadius * (0.46f + index * 0.05f),
                            crownRadius * (0.72f + index * 0.06f),
                            helixTurns,
                            phase + 0.72f + index * 2.07f,
                            18,
                            radius * (index == 2 ? 0.10f : 0.14f),
                            helixRoot,
                            helixTip,
                            BodyCrop(index + 1),
                            time + index * 0.08f,
                            Mathf.Repeat(Mathf.Abs(phase + 0.25f + index * 0.31f), 1f),
                            0.46f);
                    }
                }

                // A low-alpha outer volume supplies the air that the thin
                // Effekseer cuts disturb. It uses the same blue_fire atlas and
                // open cross-section, but is intentionally too quiet to read
                // as another ribbon on its own.
                if (!carryDetail)
                {
                    var volumeRoot = Color.Lerp(DeepGreen, Emerald, 0.18f);
                    volumeRoot.a = visibility * 0.13f;
                    var volumeMid = Color.Lerp(Leaf, Mint, 0.22f);
                    volumeMid.a = visibility * 0.11f;
                    var volumeTip = Color.Lerp(Lime, Spring, 0.18f);
                    volumeTip.a = visibility * 0.09f;
                    primary.AddOpenFunnelSurface(
                        baseCenter - axis * (length * 0.02f),
                        radial,
                        axis,
                        frame.CameraForward,
                        length * 1.06f,
                        baseRadius * 1.34f,
                        waistRadius * 1.20f,
                        crownRadius * 1.12f,
                        0.49f,
                        0.90f,
                        0.62f,
                        246f * Mathf.Deg2Rad,
                        phase + 1.13f,
                        9,
                        18,
                        new Rect(0.02f, 0.02f, 0.96f, 0.94f),
                        0.58f,
                        volumeRoot,
                        volumeMid,
                        volumeTip,
                        time + 0.16f,
                        Mathf.Repeat(Mathf.Abs(phase + 0.93f), 1f));
                }
            }

            // The direction pass needs a recognisable outer rotation, not
            // only a filled green volume. Reuse the existing Wind atlas in a
            // separate batch so its brighter edge can sit above the body and
            // show the green -> lime -> gold/orange temperature change.
            if (carryDetail && windBatch != null)
            {
                Set(windMaterial, "_Phase", time * 4.65f + phase * 0.26f);
                Set(windMaterial, "_Intensity", 1.28f);
                Set(windMaterial, "_DeepColor", DeepGreen);
                Set(windMaterial, "_Tint", Color.Lerp(Emerald, Leaf, 0.34f));
                Set(windMaterial, "_HotColor", BridgeLime);
                Set(windMaterial, "_WarmColor", SolarGold);
                Set(windMaterial, "_WarmAmount", 0.060f);
                Set(windMaterial, "_AlphaCap", 0.38f);
                Set(windMaterial, "_FlowDissolve", 0.20f);
                Set(windMaterial, "_VortexEye", 0.24f);
                Set(windMaterial, "_VolumeFill", 0.10f);
                Set(windMaterial, "_VertexMix", 0.82f);

                var outerRoot = Color.Lerp(Emerald, Leaf, 0.24f);
                outerRoot.a = visibility * 0.10f;
                var outerMid = Color.Lerp(BridgeLime, LemonGold, 0.18f);
                outerMid.a = visibility * 0.16f;
                var outerTip = Color.Lerp(SolarGold, Ember, 0.52f);
                outerTip.a = visibility * 0.22f;
                windBatch.AddOpenFunnelSurface(
                    center - axis * (length * 0.47f)
                        + frame.CameraForward * (radius * 0.035f),
                    radial,
                    axis,
                    frame.CameraForward,
                    length * 1.04f,
                    baseRadius * 0.50f,
                    waistRadius * 0.68f,
                    crownRadius * 0.98f,
                    0.43f,
                    0.86f,
                    1.64f,
                    244f * Mathf.Deg2Rad,
                    phase + 1.12f,
                    13,
                    24,
                    WindFullCrop(),
                    0.18f,
                    outerRoot,
                    outerMid,
                    outerTip,
                    time + 0.07f,
                    Mathf.Repeat(Mathf.Abs(phase + 0.31f), 1f),
                    0.02f,
                    0.98f,
                    0.48f);

                // One outer wrap is enough to explain the flow. The previous
                // counter-rotating companion crossed the body and destroyed
                // the single-axis tornado read.
                var wrapRoot = Color.Lerp(Leaf, BridgeLime, 0.22f);
                wrapRoot.a = visibility * 0.13f;
                var wrapTip = Color.Lerp(LemonGold, Ember, 0.52f);
                wrapTip.a = visibility * 0.25f;
                windBatch.AddCurvedRibbon(
                    center - axis * (length * 0.47f)
                        + frame.CameraForward * (radius * 0.04f),
                    axis,
                    radial,
                    frame.CameraForward,
                    length * 1.08f,
                    baseRadius * 0.42f,
                    crownRadius * 0.66f,
                    1.84f,
                    phase + 1.62f,
                    18,
                    radius * 0.14f,
                    wrapRoot,
                    wrapTip,
                    WindFullCrop(),
                    time + 0.10f,
                    Mathf.Repeat(Mathf.Abs(phase + 0.47f), 1f),
                    0.54f);
            }

            // The residual should be two broken upward streams only. The
            // extra wind surface is useful during the travelling strike but
            // turns the after-image into a broad horizontal sheet.
            if (bodyBatch != null && windBatch != null && !carryDetail)
            {
                Set(windMaterial, "_Phase", time * 3.565f + phase * 0.27f);
                Set(windMaterial, "_Intensity", 1.16f);
                Set(windMaterial, "_AlphaCap", 0.32f);
                Set(windMaterial, "_DeepColor", Emerald);
                Set(windMaterial, "_Tint", Leaf);
                Set(windMaterial, "_HotColor", Mint);
                Set(windMaterial, "_WarmColor", SolarGold);
                Set(windMaterial, "_WarmAmount", 0.024f);
                Set(windMaterial, "_FlowDissolve", 0.58f);
                Set(windMaterial, "_VortexEye", 0.13f);
                windBatch.AddOpenFunnelSurface(
                    center - axis * (length * 0.44f) - radial * radius * 0.035f,
                    radial,
                    axis,
                    frame.CameraForward,
                    length * 0.88f,
                    baseRadius * 0.84f,
                    waistRadius * 0.78f,
                    crownRadius * 0.78f,
                    0.44f,
                    0.78f,
                    0.92f,
                    112f * Mathf.Deg2Rad,
                    phase + 3.72f,
                    carryDetail ? 9 : 10,
                    carryDetail ? 16 : 18,
                    new Rect(0.05f, 0.12f, 0.90f, 0.68f),
                    0.34f,
                    WithAlpha(Emerald, visibility * (carryDetail ? 0.15f : 0.22f)),
                    WithAlpha(Leaf, visibility * (carryDetail ? 0.19f : 0.27f)),
                    WithAlpha(Mint, visibility * (carryDetail ? 0.15f : 0.22f)),
                    time + 0.12f,
                    Mathf.Repeat(Mathf.Abs(phase + 0.61f), 1f),
                    0.10f,
                    0.88f);
            }

            // A narrow, high-value cut made from the existing Fire_Single atlas
            // gives the growing wind cone a readable bright front without
            // turning the whole source texture into a white card.
            if (flameBatch != null)
            {
                Set(flameMaterial, "_Phase",
                    time * 5.29f * flowMultiplier + phase * 0.31f);
                Set(flameMaterial, "_Intensity", carryDetail ? 1.56f : 2.05f);
                Set(flameMaterial, "_DeepColor",
                    carryDetail ? Color.Lerp(Emerald, Ember, 0.22f) : LeafDeep);
                Set(flameMaterial, "_Tint",
                    carryDetail ? Color.Lerp(SolarGold, Ember, 0.38f) : Leaf);
                Set(flameMaterial, "_HotColor",
                    carryDetail ? Color.Lerp(SolarGold, Ember, 0.56f) : Spring);
                Set(flameMaterial, "_WarmColor", carryDetail ? Ember : SolarGold);
                Set(flameMaterial, "_WarmAmount", carryDetail ? 0.024f : 0.018f);
                Set(flameMaterial, "_VertexMix", carryDetail ? 0.78f : 0.20f);
                Set(flameMaterial, "_AlphaCap", carryDetail ? 0.23f : 0.32f);
                var accentRoot = Color.Lerp(Leaf, Mint, 0.26f);
                accentRoot.a = visibility * (carryDetail ? 0.10f : 0.18f);
                var accentTip = Color.Lerp(Mint, WhiteGreen,
                    carryDetail ? 0.34f : 0.22f);
                accentTip.a = visibility * (carryDetail ? 0.16f : 0.28f);
                flameBatch.AddCurvedRibbon(
                    center - axis * (length * 0.30f),
                    axis,
                    radial,
                    frame.CameraForward,
                    length * 0.68f,
                    radius * 0.018f,
                    radius * 0.16f,
                    0.72f,
                    phase + 0.88f,
                    12,
                    radius * 0.34f,
                    accentRoot,
                    accentTip,
                    FlameCrop(0),
                    time + 0.05f,
                    Mathf.Repeat(Mathf.Abs(phase + 0.29f), 1f));

                if (carryDetail)
                {
                    // Two broad hero cuts give the travelling strike a
                    // visible saturated core before impact. They are short
                    // curved samples of Fire_Single, not extra sprite assets.
                    var heroCutRoot = Color.Lerp(BridgeLime, LemonGold, 0.14f);
                    heroCutRoot.a = visibility * 0.16f;
                    var heroCutTip = Color.Lerp(LemonGold, Ember, 0.48f);
                    heroCutTip.a = visibility * 0.40f;
                    flameBatch.AddCurvedRibbon(
                        center - axis * (length * 0.12f)
                            + radial * (radius * 0.24f),
                        axis,
                        radial,
                        frame.CameraForward,
                        length * 0.64f,
                        radius * 0.028f,
                        radius * 0.21f,
                        0.46f,
                        phase + 2.28f,
                        10,
                        radius * 0.30f,
                        heroCutRoot,
                        heroCutTip,
                        FlameCrop(1),
                        time + 0.13f,
                        Mathf.Repeat(Mathf.Abs(phase + 0.41f), 1f));
                    var heroCutRootB = Color.Lerp(Emerald, BridgeLime, 0.38f);
                    heroCutRootB.a = visibility * 0.12f;
                    var heroCutTipB = Color.Lerp(SoftGold, Ember, 0.52f);
                    heroCutTipB.a = visibility * 0.32f;
                    flameBatch.AddCurvedRibbon(
                        center - axis * (length * 0.04f)
                            - radial * (radius * 0.20f),
                        axis,
                        radial,
                        frame.CameraForward,
                        length * 0.48f,
                        radius * 0.020f,
                        radius * 0.16f,
                        -0.36f,
                        phase + 4.02f,
                        9,
                        radius * 0.24f,
                        heroCutRootB,
                        heroCutTipB,
                        FlameCrop(2),
                        time + 0.21f,
                        Mathf.Repeat(Mathf.Abs(phase + 0.86f), 1f));

                    // A short warm wrap makes the palette read as a designed
                    // storm gradient rather than a single green material.
                    var warmWrapRoot = Color.Lerp(BridgeLime, SoftGold, 0.18f);
                    warmWrapRoot.a = visibility * 0.15f;
                    var warmWrapTip = Color.Lerp(SolarGold, Ember, 0.58f);
                    warmWrapTip.a = visibility * 0.42f;
                    flameBatch.AddCurvedRibbon(
                        center - axis * (length * 0.02f)
                            + radial * (radius * 0.15f)
                            + frame.CameraForward * (radius * 0.028f),
                        axis,
                        radial,
                        frame.CameraForward,
                        length * 0.60f,
                        radius * 0.030f,
                        radius * 0.16f,
                        -0.62f,
                        phase + 5.02f,
                        11,
                        radius * 0.20f,
                        warmWrapRoot,
                        warmWrapTip,
                        FlameCrop(3),
                        time + 0.17f,
                        Mathf.Repeat(Mathf.Abs(phase + 0.95f), 1f));
                }

                if (!carryDetail && time < 0.36f)
                {
                    var seedRoot = Color.Lerp(Leaf, Lime, 0.24f);
                    seedRoot.a = visibility * 0.30f;
                    var seedTip = WhiteGreen;
                    seedTip.a = visibility * 0.62f;
                    flameBatch.AddCurvedRibbon(
                        center + axis * (length * 0.12f),
                        axis,
                        radial,
                        frame.CameraForward,
                        Mathf.Max(length * 0.34f, 0.14f),
                        radius * 0.028f,
                        radius * 0.20f,
                        0.28f,
                        phase + 1.46f,
                        8,
                        Mathf.Max(radius * 0.46f, 0.055f),
                        seedRoot,
                        seedTip,
                        FlameCrop(2),
                        time + 0.12f,
                        Mathf.Repeat(Mathf.Abs(phase + 0.77f), 1f));
                }

                // The direction layer gets one short, denser leading cut
                // from the existing Fire_Single atlas.  It lives only during
                // the forward push, so Stage2 gains pressure without adding
                // a new mesh family or making the whole cone brighter.
                if (carryDetail && flowMultiplier > 1.05f && time < 0.86f)
                {
                    var frontPressure = Ease(0.265f, 0.365f, time)
                        * (1f - Ease(0.665f, 0.805f, time));
                    if (frontPressure > 0.001f)
                    {
                        Set(flameMaterial, "_AlphaCap", 0.34f);
                        var pressureRoot = ScaleRgb(
                            Color.Lerp(Leaf, Lime, 0.18f), 1.06f);
                        pressureRoot.a = visibility * frontPressure * 0.24f;
                        var pressureTip = ScaleRgb(WhiteGreen, 1.04f);
                        pressureTip.a = visibility * frontPressure * 0.39f;
                        var pressureLength = Mathf.Max(length * 0.22f,
                            radius * 0.72f);
                        flameBatch.AddCurvedRibbon(
                            center + axis * (length * 0.43f),
                            axis,
                            radial,
                            frame.CameraForward,
                            pressureLength,
                            radius * 0.025f * 0.92f,
                            radius * 0.16f * 0.92f,
                            0.26f,
                            phase + 2.08f,
                            8,
                            Mathf.Max(radius * 0.52f, 0.045f),
                            pressureRoot,
                            pressureTip,
                            FlameCrop(1),
                            time * 1.10f * 1.15f + 0.08f,
                            Mathf.Repeat(Mathf.Abs(phase + 0.63f), 1f));
                    }
                }

                if (carryDetail)
                {
                    Set(flameMaterial, "_AlphaCap", 0.32f);
                    var leaves = leafVisibility >= 0.0f
                        ? leafVisibility
                        : visibility;
                    AddResidualLeaves(flameBatch, center, in frame, phase,
                        time, length, radius, leaves);
                }
            }
            bodyBatch?.Commit();
            windBatch?.Commit();
            flameBatch?.Commit();
        }

        public void Interrupt() => Release();
        public void Cleanup() => Release();
        void OnDestroy() => Release();

        void Release()
        {
            if (released)
                return;
            released = true;
            RestoreCameraShake();
            shakeCaptured = false;
            shakeCamera = null;
            bodyBatch?.Dispose();
            windBatch?.Dispose();
            flameBatch?.Dispose();
            burstBatch?.Dispose();
            debrisBatch?.Dispose();
            goldBatch?.Dispose();
            particleBatch?.Dispose();
            phoenixMesh?.Dispose();
            DestroyMaterial(bodyMaterial);
            DestroyMaterial(windMaterial);
            DestroyMaterial(flameMaterial);
            DestroyMaterial(burstMaterial);
            DestroyMaterial(debrisMaterial);
            DestroyMaterial(goldMaterial);
            DestroyMaterial(particleMaterial);
        }

        Material CreateAssetMaterial(Shader shader, Texture2D texture, int queue,
            float alphaCap, float intensity, bool additive)
        {
            var material = new Material(shader)
            {
                name = $"Runtime {layer.name} · {texture.name}",
                hideFlags = HideFlags.DontSave,
                mainTexture = texture,
                renderQueue = queue
            };
            material.SetTexture("_MainTex", texture);
            Set(material, "_DeepColor", DeepGreen);
            Set(material, "_Tint", Emerald);
            Set(material, "_HotColor", Leaf);
            Set(material, "_WarmColor", SolarGold);
            Set(material, "_Opacity", 1f);
            Set(material, "_AlphaCap", texture == Resources.Load<Texture2D>(BlueFireTextureResource)
                ? Mathf.Max(alphaCap, 0.58f)
                : alphaCap);
            Set(material, "_Intensity", texture == Resources.Load<Texture2D>(BlueFireTextureResource)
                ? Mathf.Max(intensity, 1.28f)
                : intensity);
            Set(material, "_CutLow", texture == Resources.Load<Texture2D>(BlueFireTextureResource)
                ? 0.002f
                : 0.018f);
            Set(material, "_CutHigh", texture == Resources.Load<Texture2D>(BlueFireTextureResource)
                ? 0.12f
                : texture == Resources.Load<Texture2D>(FlameTextureResource) ? 0.24f : 0.16f);
            Set(material, "_Distortion", 0.045f);
            Set(material, "_ArcSpan", texture == Resources.Load<Texture2D>(WindTextureResource) ? 0.58f : 1f);
            Set(material, "_WarmAmount", 0.006f);
            Set(material, "_SourceMix", texture == Resources.Load<Texture2D>(BlueFireTextureResource)
                ? 0f
                : 0.04f);
            Set(material, "_VertexMix", texture == Resources.Load<Texture2D>(BlueFireTextureResource)
                ? 0.10f
                : 0.18f);
            Set(material, "_EdgeErode", texture == Resources.Load<Texture2D>(WindTextureResource) ? 0.12f : 0.18f);
            Set(material, "_VolumeFill", 0f);
            Set(material, "_UseSourceAlpha", texture == Resources.Load<Texture2D>(FlameTextureResource) ? 1f : 0f);
            Set(material, "_ZTest", (int)CompareFunction.Always);
            Set(material, "_SrcBlend", (int)BlendMode.One);
            Set(material, "_DstBlend", additive ? (int)BlendMode.One : (int)BlendMode.OneMinusSrcAlpha);
            return material;
        }

        static void Set(Material material, string property, float value)
        {
            if (material.HasProperty(property)) material.SetFloat(property, value);
        }
        static void Set(Material material, string property, int value)
        {
            if (material.HasProperty(property)) material.SetInt(property, value);
        }
        static void Set(Material material, string property, Color value)
        {
            if (material.HasProperty(property)) material.SetColor(property, value);
        }
        static Color ScaleRgb(Color color, float factor)
        {
            color.r *= factor;
            color.g *= factor;
            color.b *= factor;
            return color;
        }
        static void DestroyMaterial(Material material)
        {
            if (material != null) SpellBackends.DestroyOwned(material);
        }

        static float ContactTime => 1.0f;

        static float Phase(float time, int seed)
        {
            unchecked
            {
                var hash = (uint)seed;
                hash ^= hash >> 16;
                hash *= 0x7feb352du;
                hash ^= hash >> 15;
                var offset = (hash & 0xffffu) / 65535f * Mathf.PI * 2f;
                return offset + time * (7.2f + ((hash >> 16) & 0xffu) / 255f * 2.6f);
            }
        }
        static float Ease(float start, float end, float value)
        {
            if (end <= start + 0.0001f) return value >= end ? 1f : 0f;
            return Mathf.SmoothStep(0f, 1f, Mathf.Clamp01((value - start) / (end - start)));
        }
        static float ImpactBurst(float contact, float time)
        {
            // A short, high-impulse curve: the release moves almost all the
            // way outward in the first few render frames instead of drifting
            // into a slow scatter.
            return Mathf.Pow(Ease(contact, contact + 0.075f, time), 0.16f);
        }
        static Color WithAlpha(Color color, float alpha)
        {
            color.a = Mathf.Clamp01(alpha) * color.a;
            return color;
        }

        static Rect BodyCrop(int index)
        {
            switch (index & 3)
            {
                case 0: return new Rect(0.00f, 0.00f, 1.00f, 1.00f);
                case 1: return new Rect(0.08f, 0.04f, 0.84f, 0.88f);
                case 2: return new Rect(0.04f, 0.10f, 0.90f, 0.82f);
                default: return new Rect(0.12f, 0.08f, 0.76f, 0.86f);
            }
        }
        static Rect BodyFragmentCrop(int index)
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
        static Rect WindCrop(int index)
        {
            switch (index & 3)
            {
                case 0: return new Rect(0.00f, 0.00f, 1.00f, 0.58f);
                case 1: return new Rect(0.00f, 0.42f, 1.00f, 0.58f);
                case 2: return new Rect(0.12f, 0.10f, 0.76f, 0.80f);
                default: return new Rect(0.05f, 0.22f, 0.90f, 0.58f);
            }
        }
        static Rect WindFullCrop() => new Rect(0.00f, 0.00f, 1.00f, 1.00f);
        static Rect FlameCrop(int index)
        {
            switch (index & 3)
            {
                case 0: return new Rect(0.00f, 0.50f, 0.50f, 0.50f);
                case 1: return new Rect(0.50f, 0.50f, 0.50f, 0.50f);
                case 2: return new Rect(0.00f, 0.00f, 0.50f, 0.50f);
                default: return new Rect(0.50f, 0.00f, 0.50f, 0.50f);
            }
        }
        static Rect BurstCrop(int index)
        {
            switch (index & 3)
            {
                case 0: return new Rect(0.00f, 0.00f, 0.62f, 0.62f);
                case 1: return new Rect(0.38f, 0.00f, 0.62f, 0.62f);
                case 2: return new Rect(0.00f, 0.38f, 0.62f, 0.62f);
                default: return new Rect(0.38f, 0.38f, 0.62f, 0.62f);
            }
        }
        static Rect BurstFullCrop() => new Rect(0.00f, 0.00f, 1.00f, 1.00f);
        static Rect ParticleCrop(int index)
        {
            switch (index & 3)
            {
                case 0: return new Rect(0.00f, 0.00f, 0.50f, 0.50f);
                case 1: return new Rect(0.50f, 0.00f, 0.50f, 0.50f);
                case 2: return new Rect(0.00f, 0.50f, 0.50f, 0.50f);
                default: return new Rect(0.50f, 0.50f, 0.50f, 0.50f);
            }
        }

        readonly struct Frame
        {
            Frame(Vector3 right, Vector3 up, Vector3 forward)
            {
                CameraRight = right;
                CameraUp = up;
                CameraForward = forward;
            }
            public Vector3 CameraRight { get; }
            public Vector3 CameraUp { get; }
            public Vector3 CameraForward { get; }
            public static Frame From(in SpellSample sample)
            {
                var camera = sample.Camera;
                var right = camera != null ? camera.transform.right : Vector3.right;
                var up = camera != null ? camera.transform.up : Vector3.up;
                var forward = camera != null ? camera.transform.forward : Vector3.forward;
                return new Frame(right.normalized, up.normalized, forward.normalized);
            }
        }

        sealed class AssetQuadBatch
        {
            readonly Transform owner;
            readonly GameObject root;
            readonly Mesh mesh;
            readonly MeshRenderer renderer;
            readonly List<Vector3> vertices = new(64);
            readonly List<Color> colors = new(64);
            readonly List<Vector2> sourceUvs = new(64);
            readonly List<Vector3> localUvs = new(64);
            readonly List<int> triangles = new(96);
            readonly List<Vector3> ribbonPoints = new(32);
            readonly List<Vector2> phoenixPoints = new(48);
            readonly List<int> phoenixIndices = new(48);
            bool invalidGeometryReported;

            // One continuous contour.  It is intentionally a bird silhouette,
            // not a collection of feather cards: crest, beak, neck, chest,
            // swept wings and the three-pronged tail all share this boundary.
            // The existing Effekseer flame atlas is sampled inside the mesh by
            // FrostAssetSprite.shader, so the material supplies motion without
            // replacing the authored shape.
            static readonly Vector2[] PhoenixOutline =
            {
                new(0.00f, 1.00f),
                new(0.08f, 0.94f),
                new(0.12f, 0.86f),
                new(0.22f, 0.82f),
                new(0.40f, 0.78f),
                new(0.61f, 0.71f),
                new(0.39f, 0.66f),
                new(0.22f, 0.58f),
                new(0.15f, 0.44f),
                new(0.22f, 0.38f),
                new(0.40f, 0.48f),
                new(0.70f, 0.63f),
                new(0.99f, 0.69f),
                new(0.83f, 0.51f),
                new(1.10f, 0.43f),
                new(0.82f, 0.33f),
                new(0.96f, 0.22f),
                new(0.62f, 0.10f),
                new(0.74f, 0.02f),
                new(0.40f, -0.02f),
                new(0.25f, -0.14f),
                new(0.20f, -0.30f),
                new(0.27f, -0.70f),
                new(0.08f, -0.57f),
                new(0.00f, -1.18f),
                new(-0.08f, -0.57f),
                new(-0.27f, -0.70f),
                new(-0.20f, -0.30f),
                new(-0.25f, -0.14f),
                new(-0.40f, -0.02f),
                new(-0.74f, 0.02f),
                new(-0.62f, 0.10f),
                new(-0.96f, 0.22f),
                new(-0.82f, 0.33f),
                new(-1.10f, 0.43f),
                new(-0.83f, 0.51f),
                new(-0.70f, 0.57f),
                new(-0.40f, 0.48f),
                new(-0.22f, 0.38f),
                new(-0.15f, 0.44f),
                new(-0.20f, 0.58f),
                new(-0.30f, 0.70f),
                new(-0.18f, 0.82f),
                new(-0.13f, 0.93f)
            };

            public AssetQuadBatch(Transform parent, string name, Material material, int sortingOrder)
            {
                owner = parent;
                root = new GameObject(name);
                root.transform.SetParent(parent, false);
                var filter = root.AddComponent<MeshFilter>();
                renderer = root.AddComponent<MeshRenderer>();
                mesh = new Mesh { name = name, hideFlags = HideFlags.DontSave, indexFormat = IndexFormat.UInt16 };
                mesh.MarkDynamic();
                filter.sharedMesh = mesh;
                renderer.sharedMaterial = material;
                renderer.sortingOrder = sortingOrder;
                renderer.shadowCastingMode = ShadowCastingMode.Off;
                renderer.receiveShadows = false;
                renderer.allowOcclusionWhenDynamic = false;
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

            public void AddQuad(Vector3 center, Vector3 cameraRight, Vector3 cameraUp,
                float width, float height, float rotationDegrees, Color color,
                Rect sourceCrop, bool flipX, bool flipY)
            {
                if (color.a <= 0.001f || width <= 0.001f || height <= 0.001f) return;
                if (!IsFinite(center) || !IsFinite(cameraRight) || !IsFinite(cameraUp)
                    || !IsFinite(width) || !IsFinite(height) || !IsFinite(rotationDegrees))
                {
                    ReportInvalidGeometry("quad inputs");
                    return;
                }
                var angle = rotationDegrees * Mathf.Deg2Rad;
                var right = (cameraRight * Mathf.Cos(angle) + cameraUp * Mathf.Sin(angle)).normalized
                    * (width * 0.5f);
                var up = (-cameraRight * Mathf.Sin(angle) + cameraUp * Mathf.Cos(angle)).normalized
                    * (height * 0.5f);
                var bottomLeft = owner.InverseTransformPoint(center - right - up);
                var bottomRight = owner.InverseTransformPoint(center + right - up);
                var topLeft = owner.InverseTransformPoint(center - right + up);
                var topRight = owner.InverseTransformPoint(center + right + up);
                if (!IsFinite(bottomLeft) || !IsFinite(bottomRight)
                    || !IsFinite(topLeft) || !IsFinite(topRight))
                {
                    ReportInvalidGeometry("quad transform");
                    return;
                }
                var baseVertex = vertices.Count;
                vertices.Add(bottomLeft);
                vertices.Add(bottomRight);
                vertices.Add(topLeft);
                vertices.Add(topRight);
                colors.Add(color); colors.Add(color); colors.Add(color); colors.Add(color);
                var left = flipX ? sourceCrop.xMax : sourceCrop.xMin;
                var rightUv = flipX ? sourceCrop.xMin : sourceCrop.xMax;
                var bottom = flipY ? sourceCrop.yMax : sourceCrop.yMin;
                var top = flipY ? sourceCrop.yMin : sourceCrop.yMax;
                sourceUvs.Add(new Vector2(left, bottom)); sourceUvs.Add(new Vector2(rightUv, bottom));
                sourceUvs.Add(new Vector2(left, top)); sourceUvs.Add(new Vector2(rightUv, top));
                // Ordinary quads must keep the atlas/source alpha path.  Only connected
                // ribbons use localUV.z = 1; otherwise Burst01_2 becomes a solid card.
                localUvs.Add(new Vector3(0f, 0f, 0f)); localUvs.Add(new Vector3(1f, 0f, 0f));
                localUvs.Add(new Vector3(0f, 1f, 0f)); localUvs.Add(new Vector3(1f, 1f, 0f));
                triangles.Add(baseVertex); triangles.Add(baseVertex + 2); triangles.Add(baseVertex + 1);
                triangles.Add(baseVertex + 1); triangles.Add(baseVertex + 2); triangles.Add(baseVertex + 3);
            }

            public void AddLeaf(Vector3 center, Vector3 cameraRight, Vector3 cameraUp,
                float width, float height, float rotationDegrees, Color color,
                Rect sourceCrop, bool flipX)
            {
                if (color.a <= 0.001f || width <= 0.001f || height <= 0.001f)
                    return;
                if (!IsFinite(center) || !IsFinite(cameraRight) || !IsFinite(cameraUp)
                    || !IsFinite(width) || !IsFinite(height) || !IsFinite(rotationDegrees))
                {
                    ReportInvalidGeometry("leaf inputs");
                    return;
                }

                var angle = rotationDegrees * Mathf.Deg2Rad;
                var right = (cameraRight * Mathf.Cos(angle) + cameraUp * Mathf.Sin(angle)).normalized
                    * width;
                var up = (-cameraRight * Mathf.Sin(angle) + cameraUp * Mathf.Cos(angle)).normalized
                    * height;
                var baseVertex = vertices.Count;
                var points = new[]
                {
                    center - up * 0.50f,
                    center - up * 0.14f - right * 0.46f,
                    center + up * 0.23f - right * 0.24f,
                    center + up * 0.50f,
                    center + up * 0.23f + right * 0.24f,
                    center - up * 0.14f + right * 0.46f
                };
                var uvs = new[]
                {
                    new Vector2(0.50f, 0.02f),
                    new Vector2(flipX ? 0.95f : 0.05f, 0.30f),
                    new Vector2(flipX ? 0.74f : 0.26f, 0.72f),
                    new Vector2(0.50f, 0.98f),
                    new Vector2(flipX ? 0.26f : 0.74f, 0.72f),
                    new Vector2(flipX ? 0.05f : 0.95f, 0.30f)
                };
                for (var index = 0; index < points.Length; index++)
                {
                    var point = owner.InverseTransformPoint(points[index]);
                    if (!IsFinite(point))
                    {
                        ReportInvalidGeometry("leaf transform");
                        return;
                    }
                    vertices.Add(point);
                    colors.Add(color);
                    sourceUvs.Add(new Vector2(
                        sourceCrop.xMin + sourceCrop.width * uvs[index].x,
                        sourceCrop.yMin + sourceCrop.height * uvs[index].y));
                    // z=2 selects the procedural leaf branch in the shared
                    // shader; z=1 is reserved for connected vortex ribbons.
                    localUvs.Add(new Vector3(uvs[index].x, uvs[index].y, 2f));
                }
                triangles.Add(baseVertex); triangles.Add(baseVertex + 1); triangles.Add(baseVertex + 2);
                triangles.Add(baseVertex); triangles.Add(baseVertex + 2); triangles.Add(baseVertex + 3);
                triangles.Add(baseVertex); triangles.Add(baseVertex + 3); triangles.Add(baseVertex + 4);
                triangles.Add(baseVertex); triangles.Add(baseVertex + 4); triangles.Add(baseVertex + 5);
            }

            public void AddEllipse(Vector3 center, Vector3 cameraRight, Vector3 cameraUp,
                float width, float height, float rotationDegrees, Color color,
                Rect sourceCrop, bool flipX, bool flipY)
            {
                if (color.a <= 0.001f || width <= 0.001f || height <= 0.001f)
                    return;
                if (!IsFinite(center) || !IsFinite(cameraRight) || !IsFinite(cameraUp)
                    || !IsFinite(width) || !IsFinite(height)
                    || !IsFinite(rotationDegrees))
                {
                    ReportInvalidGeometry("ellipse inputs");
                    return;
                }

                var angle = rotationDegrees * Mathf.Deg2Rad;
                var right = (cameraRight * Mathf.Cos(angle)
                    + cameraUp * Mathf.Sin(angle)).normalized * (width * 0.5f);
                var up = (-cameraRight * Mathf.Sin(angle)
                    + cameraUp * Mathf.Cos(angle)).normalized * (height * 0.5f);
                var bottomLeft = owner.InverseTransformPoint(center - right - up);
                var bottomRight = owner.InverseTransformPoint(center + right - up);
                var topLeft = owner.InverseTransformPoint(center - right + up);
                var topRight = owner.InverseTransformPoint(center + right + up);
                if (!IsFinite(bottomLeft) || !IsFinite(bottomRight)
                    || !IsFinite(topLeft) || !IsFinite(topRight))
                {
                    ReportInvalidGeometry("ellipse transform");
                    return;
                }

                var baseVertex = vertices.Count;
                vertices.Add(bottomLeft);
                vertices.Add(bottomRight);
                vertices.Add(topLeft);
                vertices.Add(topRight);
                colors.Add(color); colors.Add(color); colors.Add(color); colors.Add(color);
                var left = flipX ? sourceCrop.xMax : sourceCrop.xMin;
                var rightUv = flipX ? sourceCrop.xMin : sourceCrop.xMax;
                var bottom = flipY ? sourceCrop.yMax : sourceCrop.yMin;
                var top = flipY ? sourceCrop.yMin : sourceCrop.yMax;
                sourceUvs.Add(new Vector2(left, bottom));
                sourceUvs.Add(new Vector2(rightUv, bottom));
                sourceUvs.Add(new Vector2(left, top));
                sourceUvs.Add(new Vector2(rightUv, top));
                // z=4 selects the rounded phoenix body/head branch in the
                // shared recolour shader. The atlas crop still supplies the
                // material's source detail and animated colour response.
                localUvs.Add(new Vector3(0f, 0f, 4f));
                localUvs.Add(new Vector3(1f, 0f, 4f));
                localUvs.Add(new Vector3(0f, 1f, 4f));
                localUvs.Add(new Vector3(1f, 1f, 4f));
                triangles.Add(baseVertex); triangles.Add(baseVertex + 2);
                triangles.Add(baseVertex + 1);
                triangles.Add(baseVertex + 1); triangles.Add(baseVertex + 2);
                triangles.Add(baseVertex + 3);
            }

            /// <summary>
            /// Adds the phoenix as one triangulated contour.  This is the
            /// recognisable creature layer: the wings, chest, head and tail
            /// are not assembled from independent quads.  The Effekseer
            /// Fire_Single atlas is used only as animated material detail by
            /// the z=5 shader branch.
            /// </summary>
            public void AddPhoenixSilhouette(
                Vector3 center,
                Vector3 cameraRight,
                Vector3 cameraUp,
                Vector3 cameraForward,
                float width,
                float height,
                Color color,
                Rect sourceCrop,
                float wingFlap,
                float tailSway)
            {
                if (color.a <= 0.001f || width <= 0.001f || height <= 0.001f)
                    return;
                if (!IsFinite(center) || !IsFinite(cameraRight)
                    || !IsFinite(cameraUp) || !IsFinite(cameraForward)
                    || !IsFinite(width) || !IsFinite(height)
                    || !IsFinite(wingFlap) || !IsFinite(tailSway))
                {
                    ReportInvalidGeometry("phoenix silhouette inputs");
                    return;
                }

                cameraRight = NormalizeOr(cameraRight, Vector3.right);
                cameraUp = NormalizeOr(cameraUp, Vector3.up);
                cameraForward = NormalizeOr(cameraForward, Vector3.forward);
                wingFlap = Mathf.Clamp(wingFlap, -0.16f, 0.16f);
                tailSway = Mathf.Clamp(tailSway, -0.16f, 0.16f);

                phoenixPoints.Clear();
                for (var index = 0; index < PhoenixOutline.Length; index++)
                {
                    var point = PhoenixOutline[index];
                    var wingWeight = Mathf.SmoothStep(0f, 1f,
                        Mathf.InverseLerp(0.30f, 1.12f, Mathf.Abs(point.x)));
                    if (point.y > 0.02f)
                        point.y += wingFlap * wingWeight
                            * Mathf.Lerp(0.24f, 0.86f,
                                Mathf.InverseLerp(0.02f, 0.92f, point.y));
                    if (point.y < -0.22f)
                        point.x += tailSway * Mathf.SmoothStep(0f, 1f,
                            Mathf.InverseLerp(-0.22f, -1.16f, point.y));
                    phoenixPoints.Add(point);
                }

                var baseVertex = vertices.Count;
                for (var index = 0; index < phoenixPoints.Count; index++)
                {
                    var point = phoenixPoints[index];
                    var worldPoint = center
                        + cameraRight * (point.x * width * 0.5f)
                        + cameraUp * (point.y * height * 0.5f);
                    var localPoint = owner.InverseTransformPoint(worldPoint);
                    if (!IsFinite(localPoint))
                    {
                        ReportInvalidGeometry("phoenix silhouette transform");
                        return;
                    }

                    var u = Mathf.Clamp01(0.5f + point.x * 0.5f);
                    var v = Mathf.Clamp01(0.5f + point.y * 0.5f);
                    vertices.Add(localPoint);
                    colors.Add(color);
                    sourceUvs.Add(new Vector2(
                        sourceCrop.xMin + sourceCrop.width * u,
                        sourceCrop.yMin + sourceCrop.height * v));
                    // z=5 selects the filled contour branch.  Unlike the
                    // atlas cards, its alpha comes from the actual polygon.
                    localUvs.Add(new Vector3(u, v, 5f));
                }

                phoenixIndices.Clear();
                for (var index = 0; index < phoenixPoints.Count; index++)
                    phoenixIndices.Add(index);

                var signedArea = 0f;
                for (var index = 0; index < phoenixPoints.Count; index++)
                {
                    var current = phoenixPoints[index];
                    var next = phoenixPoints[(index + 1) % phoenixPoints.Count];
                    signedArea += current.x * next.y - next.x * current.y;
                }
                var orientation = signedArea >= 0f ? 1f : -1f;
                var guard = phoenixIndices.Count * phoenixIndices.Count;
                while (phoenixIndices.Count > 3 && guard-- > 0)
                {
                    var earFound = false;
                    for (var listIndex = 0;
                        listIndex < phoenixIndices.Count;
                        listIndex++)
                    {
                        var previousIndex = phoenixIndices[
                            (listIndex + phoenixIndices.Count - 1)
                            % phoenixIndices.Count];
                        var currentIndex = phoenixIndices[listIndex];
                        var nextIndex = phoenixIndices[
                            (listIndex + 1) % phoenixIndices.Count];
                        var previous = phoenixPoints[previousIndex];
                        var current = phoenixPoints[currentIndex];
                        var next = phoenixPoints[nextIndex];
                        if (Cross2(current - previous, next - current)
                            * orientation <= 0.00001f)
                            continue;

                        var containsPoint = false;
                        for (var testIndex = 0;
                            testIndex < phoenixIndices.Count;
                            testIndex++)
                        {
                            var candidateIndex = phoenixIndices[testIndex];
                            if (candidateIndex == previousIndex
                                || candidateIndex == currentIndex
                                || candidateIndex == nextIndex)
                                continue;
                            if (PointInTriangle(
                                phoenixPoints[candidateIndex],
                                previous, current, next, orientation))
                            {
                                containsPoint = true;
                                break;
                            }
                        }
                        if (containsPoint)
                            continue;

                        triangles.Add(baseVertex + previousIndex);
                        triangles.Add(baseVertex + currentIndex);
                        triangles.Add(baseVertex + nextIndex);
                        phoenixIndices.RemoveAt(listIndex);
                        earFound = true;
                        break;
                    }

                    if (!earFound)
                    {
                        // The authored outline is simple, but keep a safe
                        // fallback so a future contour edit cannot erase the
                        // entire spell on a device with different float
                        // behaviour.
                        for (var index = 1;
                            index < phoenixIndices.Count - 1;
                            index++)
                        {
                            triangles.Add(baseVertex + phoenixIndices[0]);
                            triangles.Add(baseVertex + phoenixIndices[index]);
                            triangles.Add(baseVertex + phoenixIndices[index + 1]);
                        }
                        phoenixIndices.Clear();
                        break;
                    }
                }

                if (phoenixIndices.Count == 3)
                {
                    triangles.Add(baseVertex + phoenixIndices[0]);
                    triangles.Add(baseVertex + phoenixIndices[1]);
                    triangles.Add(baseVertex + phoenixIndices[2]);
                }
            }

            /// <summary>
            /// Builds a connected, open funnel from the existing Effekseer
            /// texture. Sampling the source atlas along both surface axes is
            /// important here: a single horizontal strip only exposes a dark
            /// slice of blue_fire and reads as a faint dot, while this surface
            /// retains the photographed turbulent body as the vortex grows.
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
                float turns,
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
                float seed01,
                float startFraction = 0f,
                float endFraction = 1f,
                float chaosScale = 1f)
            {
                if (rings < 3 || sides < 4 || height <= 0.001f
                    || Mathf.Max(baseRadius, Mathf.Max(waistRadius, crownRadius)) <= 0.001f
                    || Mathf.Max(baseColor.a, Mathf.Max(waistColor.a, crownColor.a)) <= 0.001f)
                    return;
                if (!IsFinite(baseCenter) || !IsFinite(radialRight)
                    || !IsFinite(axisUp) || !IsFinite(cameraForward)
                    || !IsFinite(height) || !IsFinite(baseRadius)
                    || !IsFinite(waistRadius) || !IsFinite(crownRadius)
                    || !IsFinite(depthScale) || !IsFinite(angularCoverage)
                    || !IsFinite(phase) || !IsFinite(time) || !IsFinite(seed01))
                {
                    ReportInvalidGeometry("funnel inputs");
                    return;
                }

                axisUp = NormalizeOr(axisUp, Vector3.up);
                radialRight = Vector3.ProjectOnPlane(radialRight, axisUp);
                radialRight = NormalizeOr(radialRight, Vector3.right);
                cameraForward = NormalizeOr(cameraForward, Vector3.forward);
                chaosScale = Mathf.Clamp01(chaosScale);
                var crossBend = Vector3.Cross(axisUp, radialRight);
                crossBend = NormalizeOr(crossBend, cameraForward);
                waistAt = Mathf.Clamp(waistAt, 0.20f, 0.80f);
                startFraction = Mathf.Clamp01(startFraction);
                endFraction = Mathf.Clamp(endFraction, startFraction + 0.08f, 1f);
                var baseVertex = vertices.Count;
                for (var ring = 0; ring < rings; ring++)
                {
                    var u = ring / (rings - 1f);
                    var s = Mathf.Lerp(startFraction, endFraction, u);
                    float profile;
                    Color color;
                    if (u <= waistAt)
                    {
                        var lower = Mathf.SmoothStep(0f, 1f, u / waistAt);
                        profile = Mathf.Lerp(baseRadius, waistRadius, lower);
                        color = Color.Lerp(baseColor, waistColor, lower);
                    }
                    else
                    {
                        var upper = Mathf.SmoothStep(0f, 1f, (u - waistAt) / (1f - waistAt));
                        profile = Mathf.Lerp(waistRadius, crownRadius, upper);
                        color = Color.Lerp(waistColor, crownColor, upper);
                    }

                    // A stream is a thin, broken sheet with a changing belly,
                    // not a planar cone.  The longitudinal depth curl keeps
                    // the existing Effekseer texture wrapped through real
                    // depth while the narrow ends stay torn and asymmetric.
                    var belly = Mathf.Pow(
                        Mathf.Max(0f, Mathf.Sin(Mathf.PI * u)), 0.62f);
                    var coverageAt = angularCoverage
                        * Mathf.Lerp(0.68f, 1f, belly);
                    var depthCurl = Mathf.Sin(
                            u * Mathf.PI * 2f + phase)
                        * height * 0.060f
                        + Mathf.Sin(u * Mathf.PI * 4f
                            - seed01 * 3.7f + time * 0.27f)
                        * height * 0.022f;
                    var drift = radialRight * (
                            Mathf.Sin(u * 5.4f + seed01 * 8.1f + time * 1.8f)
                            * crownRadius * 0.10f
                            + Mathf.Sin(u * Mathf.PI * 2f + phase * 0.7f)
                            * crownRadius * 0.055f) * chaosScale
                        + cameraForward * (
                            Mathf.Cos(u * 4.1f - seed01 * 5.4f - time * 1.3f)
                            * crownRadius * 0.045f
                            + depthCurl * 0.35f) * chaosScale;
                    for (var side = 0; side < sides; side++)
                    {
                        var t = side / (sides - 1f);
                        var sideCoord = t * 2f - 1f;
                        var edgeWarp = Mathf.Sin(
                                u * 9.7f + t * 7.1f + seed01 * 13.2f + time * 2.0f) * 0.090f
                            + Mathf.Sin(u * 23.1f - t * 11.7f - time * 1.4f) * 0.040f;
                        edgeWarp *= chaosScale;
                        var angle = phase
                            + turns * Mathf.PI * 2f * u
                            + sideCoord * coverageAt * 0.5f
                            + Mathf.Sin(u * 2.2f + time * 0.8f) * 0.10f
                            + edgeWarp;
                        var radialNoise = 1f
                            + Mathf.Sin(u * 13.4f + t * 6.7f + seed01 * 11.1f + time * 1.9f) * 0.080f * chaosScale
                            + Mathf.Sin(u * 29.3f - t * 8.3f - time * 2.4f) * 0.040f * chaosScale;
                        var radius = profile * radialNoise
                            * Mathf.Lerp(0.78f, 1f, belly);
                        var tear = height * (
                            Mathf.Sin(u * Mathf.PI * 1.4f + seed01 * 2.3f) * 0.022f
                            + Mathf.SmoothStep(0.55f, 1f, u) * (
                                Mathf.Sin(t * 8.9f + seed01 * 12.7f + time * 1.6f) * 0.055f
                                + Mathf.Sin(t * 19.1f - seed01 * 6.9f - time * 1.1f) * 0.025f)) * chaosScale;
                        var crossDepth = sideCoord * depthCurl
                            * Mathf.Lerp(0.40f, 1f, belly) * chaosScale
                            + Mathf.Sin(t * Mathf.PI * 3f + u * 8.0f + phase)
                            * height * 0.018f * chaosScale;
                        var point = baseCenter
                            + axisUp * (height * s + tear)
                            + drift
                            + radialRight * (Mathf.Sin(angle) * radius)
                            + crossBend * (Mathf.Sin(Mathf.PI * t)
                                * height * 0.048f
                                * Mathf.Lerp(0.68f, 1f, belly))
                            + axisUp * (Mathf.Sin(t * Mathf.PI * 2f
                                + u * 7.0f + phase) * height * 0.012f * chaosScale)
                            - cameraForward * (
                                Mathf.Cos(angle) * radius * depthScale
                                + Mathf.Max(0.004f, crownRadius) * 0.055f
                                - depthCurl
                                - crossDepth);
                        if (!IsFinite(point))
                        {
                            ReportInvalidGeometry("funnel point");
                            return;
                        }

                        var edgeEnvelope = Mathf.Pow(
                            Mathf.Max(0f, Mathf.Sin(Mathf.PI * t)), 0.54f);
                        var edgeBreak = 0.78f + 0.22f * (0.5f + 0.5f * Mathf.Sin(
                            u * 31.0f + t * 17.0f + seed01 * 9.0f + time * 2.7f));
                        // Keep the ring's interpolated colour intact for each
                        // side. Mutating `color` here would let side 0's
                        // zero-width edge multiply every later vertex in the
                        // same ring to alpha 0, erasing the whole surface.
                        var vertexColor = color;
                        vertexColor.a *= Mathf.Lerp(0.16f, 1f, edgeEnvelope)
                            * edgeBreak
                            * Mathf.SmoothStep(0f, 0.10f, u)
                            * (1f - Mathf.SmoothStep(0.88f, 1f, u));
                        vertices.Add(owner.InverseTransformPoint(point));
                        colors.Add(vertexColor);
                        var sourceU = sourceCrop.xMin + sourceCrop.width * Mathf.Repeat(
                            t + uvPhase + Mathf.Sin(u * 4.1f + seed01) * 0.035f, 1f);
                        var sourceV = sourceCrop.yMin + sourceCrop.height * Mathf.Repeat(
                            u + uvPhase * 0.17f + Mathf.Sin(t * 3.7f + time) * 0.025f, 1f);
                        sourceUvs.Add(new Vector2(sourceU, sourceV));
                        // z=3 marks the open surface path; its local x axis is
                        // the broken angular span, unlike a ribbon's y edge.
                        localUvs.Add(new Vector3(t, u, 3f));
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
                        triangles.Add(a); triangles.Add(c); triangles.Add(b);
                        triangles.Add(b); triangles.Add(c); triangles.Add(d);
                    }
                }
            }

            void AddFunnelRibbon(
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
                float turns,
                float angularCoverage,
                float phase,
                int rings,
                Rect sourceCrop,
                float uvPhase,
                Color baseColor,
                Color waistColor,
                Color crownColor,
                float time,
                float seed01)
            {
                var segments = Mathf.Max(8, rings * 2);
                axisUp = NormalizeOr(axisUp, Vector3.up);
                radialRight = Vector3.ProjectOnPlane(radialRight, axisUp);
                radialRight = NormalizeOr(radialRight, Vector3.right);
                cameraForward = NormalizeOr(cameraForward, Vector3.forward);
                var baseVertex = vertices.Count;
                var step = 1f / (segments - 1f);
                for (var index = 0; index < segments; index++)
                {
                    var s = index * step;
                    var lower = s <= waistAt
                        ? Mathf.SmoothStep(0f, 1f, s / Mathf.Max(0.001f, waistAt))
                        : 1f;
                    var upper = s > waistAt
                        ? Mathf.SmoothStep(0f, 1f, (s - waistAt) / Mathf.Max(0.001f, 1f - waistAt))
                        : 0f;
                    var profile = s <= waistAt
                        ? Mathf.Lerp(baseRadius, waistRadius, lower)
                        : Mathf.Lerp(waistRadius, crownRadius, upper);
                    var color = s <= waistAt
                        ? Color.Lerp(baseColor, waistColor, lower)
                        : Color.Lerp(waistColor, crownColor, upper);
                    var angle = phase
                        + turns * Mathf.PI * 2f * s
                        + angularCoverage * 0.18f * s
                        + Mathf.Sin(s * 8.3f + seed01 * 7.1f + time * 1.6f) * 0.12f;
                    var pathRadius = profile * (0.60f
                        + 0.09f * Mathf.Sin(s * 9.1f + seed01)
                        + 0.045f * Mathf.Sin(s * 21.4f - time * 2.1f));
                    var point = baseCenter
                        + axisUp * (height * s)
                        + radialRight * (Mathf.Sin(angle) * pathRadius)
                        - cameraForward * (Mathf.Cos(angle) * pathRadius * depthScale * 0.36f);
                    var previousS = Mathf.Max(0f, s - step);
                    var nextS = Mathf.Min(1f, s + step);
                    var previousAngle = phase
                        + turns * Mathf.PI * 2f * previousS
                        + angularCoverage * 0.18f * previousS;
                    var nextAngle = phase
                        + turns * Mathf.PI * 2f * nextS
                        + angularCoverage * 0.18f * nextS;
                    var previous = baseCenter
                        + axisUp * (height * previousS)
                        + radialRight * (Mathf.Sin(previousAngle) * pathRadius)
                        - cameraForward * (Mathf.Cos(previousAngle) * pathRadius * depthScale * 0.36f);
                    var next = baseCenter
                        + axisUp * (height * nextS)
                        + radialRight * (Mathf.Sin(nextAngle) * pathRadius)
                        - cameraForward * (Mathf.Cos(nextAngle) * pathRadius * depthScale * 0.36f);
                    var tangent = next - previous;
                    if (tangent.sqrMagnitude < 0.00001f)
                        tangent = axisUp;
                    tangent.Normalize();
                    var side = Vector3.Cross(cameraForward, tangent);
                    if (side.sqrMagnitude < 0.00001f)
                        side = radialRight;
                    side.Normalize();
                    var belly = Mathf.Pow(Mathf.Max(0f, Mathf.Sin(Mathf.PI * s)), 0.46f);
                    var width = Mathf.Lerp(
                        Mathf.Max(baseRadius * 0.72f, height * 0.012f),
                        Mathf.Max(crownRadius * 0.44f, height * 0.018f),
                        Mathf.SmoothStep(0f, 1f, s));
                    width *= Mathf.Lerp(0.34f, 0.92f, belly);
                    color.a *= Mathf.Lerp(0.72f, 1f, belly)
                        * Mathf.SmoothStep(0f, 0.06f, s)
                        * (1f - Mathf.SmoothStep(0.90f, 1f, s));
                    var left = owner.InverseTransformPoint(point - side * width * 0.5f);
                    var right = owner.InverseTransformPoint(point + side * width * 0.5f);
                    if (!IsFinite(left) || !IsFinite(right))
                    {
                        ReportInvalidGeometry("funnel ribbon transform");
                        return;
                    }
                    vertices.Add(left);
                    vertices.Add(right);
                    colors.Add(color);
                    colors.Add(color);
                    var sourceAlong = Mathf.Repeat(
                        0.08f + s * 0.86f + uvPhase + time * 0.06f, 1f);
                    var sourceU = Mathf.Lerp(sourceCrop.xMin, sourceCrop.xMax,
                        sourceAlong);
                    var sourceVPhase = Mathf.Repeat(
                        0.16f + uvPhase * 0.11f
                            + Mathf.Sin(s * 7.2f + seed01 * 4.3f) * 0.035f,
                        1f);
                    var lowerV = Mathf.Repeat(sourceVPhase, 1f);
                    var upperV = Mathf.Repeat(sourceVPhase + 0.68f, 1f);
                    sourceUvs.Add(new Vector2(
                        sourceU,
                        Mathf.Lerp(sourceCrop.yMin, sourceCrop.yMax, lowerV)));
                    sourceUvs.Add(new Vector2(
                        sourceU,
                        Mathf.Lerp(sourceCrop.yMin, sourceCrop.yMax, upperV)));
                    localUvs.Add(new Vector3(s, 0.12f, 1f));
                    localUvs.Add(new Vector3(s, 0.88f, 1f));
                }
                for (var index = 0; index < segments - 1; index++)
                {
                    var a = baseVertex + index * 2;
                    var b = a + 1;
                    var c = a + 2;
                    var d = a + 3;
                    triangles.Add(a); triangles.Add(c); triangles.Add(b);
                    triangles.Add(b); triangles.Add(c); triangles.Add(d);
                }
            }

            public void AddCurvedRibbon(
                Vector3 start,
                Vector3 axis,
                Vector3 radial,
                Vector3 depth,
                float height,
                float bottomRadius,
                float topRadius,
                float turns,
                float phase,
                int segments,
                float maxWidth,
                Color rootColor,
                Color tipColor,
                Rect sourceCrop,
                float time,
                float seed01,
                float chaosScale = 1f)
            {
                if (segments < 3 || height <= 0.001f || maxWidth <= 0.001f
                    || Mathf.Max(rootColor.a, tipColor.a) <= 0.001f)
                    return;

                if (!IsFinite(start) || !IsFinite(axis) || !IsFinite(radial)
                    || !IsFinite(depth) || !IsFinite(height) || !IsFinite(bottomRadius)
                    || !IsFinite(topRadius) || !IsFinite(turns) || !IsFinite(phase)
                    || !IsFinite(maxWidth) || !IsFinite(time) || !IsFinite(seed01))
                {
                    ReportInvalidGeometry("ribbon inputs");
                    return;
                }

                axis = axis.normalized;
                radial = Vector3.ProjectOnPlane(radial, axis);
                if (radial.sqrMagnitude < 0.0001f)
                    radial = Vector3.Cross(depth, axis);
                radial.Normalize();
                depth = Vector3.Cross(axis, radial).normalized;
                if (depth.sqrMagnitude < 0.0001f)
                    depth = Vector3.forward;
                chaosScale = Mathf.Clamp01(chaosScale);

                ribbonPoints.Clear();
                for (var index = 0; index < segments; index++)
                {
                    var s = index / (segments - 1f);
                    var profile = Mathf.Lerp(0.12f, 1f, Mathf.Pow(s, 0.72f));
                    var radius = Mathf.Lerp(bottomRadius, topRadius, Mathf.Pow(s, 1.12f));
                    var angle = phase + turns * Mathf.PI * 2f * s
                        + Mathf.Sin(s * 11.7f + seed01 * 13.4f + time * 1.7f) * 0.16f * chaosScale
                        + Mathf.Sin(s * 26.1f - seed01 * 7.1f - time * 2.1f) * 0.055f * chaosScale;
                    var drift = radial * (
                            Mathf.Sin(s * 5.2f + seed01 * 8.3f + time * 1.2f)
                            * topRadius * 0.10f * chaosScale)
                        + depth * (
                            Mathf.Cos(s * 4.4f - seed01 * 6.1f - time * 1.5f)
                            * topRadius * 0.055f * chaosScale);
                    var point = start
                        + axis * (height * s)
                        + drift
                        + radial * (Mathf.Cos(angle) * radius * profile)
                        + depth * (Mathf.Sin(angle) * radius * profile * 0.46f);
                    if (!IsFinite(point))
                    {
                        ReportInvalidGeometry("ribbon point");
                        ribbonPoints.Clear();
                        return;
                    }
                    ribbonPoints.Add(point);
                }

                var baseVertex = vertices.Count;
                for (var index = 0; index < segments; index++)
                {
                    var s = index / (segments - 1f);
                    var previous = ribbonPoints[Mathf.Max(0, index - 1)];
                    var next = ribbonPoints[Mathf.Min(segments - 1, index + 1)];
                    var tangent = next - previous;
                    if (tangent.sqrMagnitude < 0.00001f)
                        tangent = axis;
                    tangent.Normalize();
                    var across = Vector3.Cross(depth, tangent);
                    if (across.sqrMagnitude < 0.00001f)
                        across = radial;
                    across.Normalize();

                    var edgeEnvelope = Mathf.SmoothStep(0f, 0.08f, s)
                        * (1f - Mathf.SmoothStep(0.93f, 1f, s));
                    // Sin(pi) is a tiny negative value in floating point. Clamp
                    // it before the fractional power or the tip vertex becomes
                    // NaN and Unity rejects the whole mesh bounds.
                    var belly = Mathf.Pow(Mathf.Max(0f, Mathf.Sin(Mathf.PI * s)), 0.52f);
                    var widthNoise = 0.88f
                        + Mathf.Sin(s * 15.4f + seed01 * 9.7f + time * 2.2f) * 0.10f * chaosScale
                        + Mathf.Sin(s * 31.8f - seed01 * 4.1f - time * 1.4f) * 0.04f * chaosScale;
                    var halfWidth = maxWidth
                        * Mathf.Lerp(0.24f, 1f, belly)
                        * widthNoise * 0.5f;
                    var color = Color.Lerp(rootColor, tipColor,
                        Mathf.SmoothStep(0.08f, 0.94f, s));
                    color.a *= edgeEnvelope;
                    var point = ribbonPoints[index];
                    var left = owner.InverseTransformPoint(point - across * halfWidth);
                    var right = owner.InverseTransformPoint(point + across * halfWidth);
                    if (!IsFinite(left) || !IsFinite(right))
                    {
                        ReportInvalidGeometry("ribbon transform");
                        return;
                    }
                    vertices.Add(left);
                    vertices.Add(right);
                    colors.Add(color);
                    colors.Add(color);

                    var u = Mathf.Lerp(sourceCrop.xMin, sourceCrop.xMax, s);
                    var bottom = sourceCrop.yMin;
                    var top = sourceCrop.yMax;
                    sourceUvs.Add(new Vector2(u, bottom));
                    sourceUvs.Add(new Vector2(u, top));
                    // FrostAssetSprite uses TEXCOORD1 as an organic card
                    // mask.  A ribbon's two strip edges must stay inside
                    // that mask; using exact 0/1 values makes edgeY collapse
                    // to zero for the whole strip and silently erases the
                    // curved mesh.  Keep a narrow transparent margin while
                    // leaving the actual source UV crop unchanged.
                    localUvs.Add(new Vector3(s, 0.12f, 1f));
                    localUvs.Add(new Vector3(s, 0.88f, 1f));
                    if (index < segments - 1)
                    {
                        var a = baseVertex + index * 2;
                        var b = a + 1;
                        var c = a + 2;
                        var d = a + 3;
                        triangles.Add(a); triangles.Add(c); triangles.Add(b);
                        triangles.Add(b); triangles.Add(c); triangles.Add(d);
                    }
                }
            }

            public void Commit()
            {
                mesh.Clear(false);
                if (vertices.Count < 4) { renderer.enabled = false; return; }
                for (var index = 0; index < vertices.Count; index++)
                {
                    if (!IsFinite(vertices[index]))
                    {
                        ReportInvalidGeometry("commit vertex");
                        renderer.enabled = false;
                        return;
                    }
                }
                mesh.SetVertices(vertices); mesh.SetColors(colors); mesh.SetUVs(0, sourceUvs);
                mesh.SetUVs(1, localUvs); mesh.SetTriangles(triangles, 0, true);
                mesh.RecalculateBounds();
                renderer.enabled = true;
            }

            public string Describe() => $"{root.name} vertices={mesh.vertexCount} bounds={mesh.bounds} enabled={renderer.enabled}";
            public string RendererDescribe() => $"worldBounds={renderer.bounds} material={renderer.sharedMaterial?.name}";

            static bool IsFinite(float value)
            {
                return !float.IsNaN(value) && !float.IsInfinity(value);
            }

            static bool IsFinite(Vector3 value)
            {
                return IsFinite(value.x) && IsFinite(value.y) && IsFinite(value.z);
            }

            static bool IsFinite(Vector2 value)
            {
                return IsFinite(value.x) && IsFinite(value.y);
            }

            static float Cross2(Vector2 first, Vector2 second)
            {
                return first.x * second.y - first.y * second.x;
            }

            static bool PointInTriangle(
                Vector2 point,
                Vector2 a,
                Vector2 b,
                Vector2 c,
                float orientation)
            {
                const float epsilon = -0.00001f;
                return Cross2(b - a, point - a) * orientation >= epsilon
                    && Cross2(c - b, point - b) * orientation >= epsilon
                    && Cross2(a - c, point - c) * orientation >= epsilon;
            }

            static Vector3 NormalizeOr(Vector3 value, Vector3 fallback)
            {
                return value.sqrMagnitude > 0.0001f && IsFinite(value)
                    ? value.normalized
                    : fallback;
            }

            void ReportInvalidGeometry(string stage)
            {
                if (invalidGeometryReported)
                    return;
                invalidGeometryReported = true;
                Debug.LogError($"[VFX V1] Verdant vortex invalid geometry in {root.name} at {stage}. "
                    + $"ownerPosition={owner.position} ownerScale={owner.lossyScale}");
            }

            public void Dispose()
            {
                if (root != null) SpellBackends.DestroyOwned(root);
                if (mesh != null) SpellBackends.DestroyOwned(mesh);
            }
        }
    }
}
