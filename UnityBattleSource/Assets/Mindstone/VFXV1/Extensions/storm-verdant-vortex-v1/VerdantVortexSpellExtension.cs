using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace Mindstone.VFXV1
{
    /// <summary>
    /// Spell-private verdant vortex presentation.  The effect is built from
    /// continuous ribbons, a soft volume quad, seeded leaf silhouettes and an
    /// irregular pressure burst; no character renderer or combat rule is
    /// touched here.
    /// </summary>
    public sealed class VerdantVortexSpellExtension : MonoBehaviour, ISpellExtension
    {
        const string WindVolumeShader = "Mindstone/Mistport Wind Volume";
        const string WildRibbonShader = "Mindstone/Mistport Wild Ribbon";
        const string FrontRibbonShader = "Mindstone/Mistport Front Ribbon";
        const string LeafShader = "Sprites/Default";
        const string NoiseResource = "Effects/HellHound/Texture/ExperimentalNoise";
        const float VortexScale = 1.35f;

        static readonly Color DeepForest = new(0.028f, 0.216f, 0.137f, 1f);
        static readonly Color DeepJade = new(0.025f, 0.12f, 0.07f, 1f);
        static readonly Color Emerald = new(0.14f, 0.72f, 0.39f, 1f);
        static readonly Color LeafGreen = new(0.10f, 0.56f, 0.26f, 1f);
        static readonly Color LimeEdge = new(0.59f, 0.91f, 0.43f, 1f);
        static readonly Color LeafGold = new(0.89f, 0.77f, 0.36f, 1f);
        static readonly Color AirWhite = new(0.87f, 1.00f, 0.78f, 1f);

        SpellSpec spell;
        SpellLayerSpec layer;
        int seed;
        Color tint;
        Texture2D noise;
        bool released;

        DynamicBatch volumeBatch;
        DynamicBatch ribbonBatch;
        DynamicBatch groundBatch;
        DynamicBatch leafBatch;
        DynamicBatch flashBatch;

        public void Initialize(SpellSpec spellSpec, SpellLayerSpec layerSpec, int deterministicSeed)
        {
            spell = spellSpec;
            layer = layerSpec;
            seed = deterministicSeed;
            tint = ReadColor(layerSpec != null ? layerSpec.color : null, Color.white);
            noise = Resources.Load<Texture2D>(NoiseResource);

            switch (layer.role)
            {
                case "core":
                    volumeBatch = CreateBatch(
                        "Verdant vortex rear streams",
                        CreateRibbonMaterial("Verdant vortex rear stream material", 3490, DeepForest, Emerald, 0.72f));
                    ribbonBatch = CreateBatch(
                        "Verdant vortex helixes",
                        CreateRibbonMaterial("Verdant vortex ribbon material", 3500, Emerald, LimeEdge, 0.92f));
                    break;

                case "direction":
                    ribbonBatch = CreateBatch(
                        "Verdant travel gusts",
                        CreateRibbonMaterial("Verdant travel ribbon material", 3510, DeepForest, Emerald, 0.82f));
                    leafBatch = CreateBatch(
                        "Verdant carried leaves",
                        CreateLeafMaterial("Verdant carried leaf material", 3520));
                    break;

                case "impact-back":
                    volumeBatch = CreateBatch(
                        "Verdant impact rear streams",
                        CreateRibbonMaterial("Verdant impact rear stream material", 3270, DeepForest, Emerald, 0.56f));
                    groundBatch = CreateBatch(
                        "Verdant ground pressure",
                        CreateRibbonMaterial("Verdant ground pressure material", 3280, DeepForest, LimeEdge, 0.82f));
                    leafBatch = CreateBatch(
                        "Verdant rear leaf burst",
                        CreateLeafMaterial("Verdant rear leaf material", 3290));
                    break;

                case "impact-front":
                    volumeBatch = CreateBatch(
                        "Verdant foreground vortex shell",
                        CreateRibbonMaterial("Verdant foreground shell material", 4988, DeepForest, Emerald, 0.74f, true));
                    ribbonBatch = CreateBatch(
                        "Verdant foreground pressure ribbons",
                        CreateRibbonMaterial("Verdant foreground ribbon material", 4990, Color.white, LimeEdge, 1.06f, true));
                    leafBatch = CreateBatch(
                        "Verdant foreground leaf burst",
                        CreateLeafMaterial("Verdant foreground leaf material", 4996));
                    break;

                case "accent":
                    flashBatch = CreateBatch(
                        "Verdant impact flash",
                        CreateLeafMaterial("Verdant impact flash material", 5000));
                    leafBatch = CreateBatch(
                        "Verdant impact debris",
                        CreateLeafMaterial("Verdant impact debris material", 5002));
                    break;
            }
        }

        public void Sample(in SpellSample sample)
        {
            if (released || layer == null)
                return;

            // Travel ribbons follow the projectile axis.  Impact geometry is
            // authored in the showcase/world frame so its upward curl stays
            // vertical instead of inheriting the source-to-target pitch.
            if (layer.role == "impact-back"
                || layer.role == "impact-front"
                || layer.role == "accent")
            {
                transform.rotation = Quaternion.identity;
                transform.localScale = sample.Scale * VortexScale;
            }
            else
            {
                transform.localScale = sample.Scale * VortexScale;
            }

            switch (layer.role)
            {
                case "core":
                    SampleCore(in sample);
                    break;
                case "direction":
                    SampleDirection(in sample);
                    break;
                case "impact-back":
                    SampleImpactBack(in sample);
                    break;
                case "impact-front":
                    SampleImpactFront(in sample);
                    break;
                case "accent":
                    SampleAccent(in sample);
                    break;
            }
        }

        public void Interrupt() => Release();

        public void Cleanup() => Release();

        void OnDestroy() => Release();

        void SampleCore(in SpellSample sample)
        {
            var time = sample.AbsoluteTime;
            var contact = ContactTime;
            var impactEnd = contact + ImpactDuration;
            var formation = Ease(0.015f, WindupTime, time);
            var growth = Ease(WindupTime, contact, time);
            var impactPulse = Ease(contact, contact + 0.10f, time)
                * (1f - Ease(contact + 0.26f, impactEnd, time));
            var decay = 1f - Ease(impactEnd + 0.02f, Duration, time);
            var visibility = formation * Mathf.Max(0f, decay);

            volumeBatch.Begin();
            ribbonBatch.Begin();
            if (visibility <= 0.001f)
            {
                volumeBatch.Commit();
                ribbonBatch.Commit();
                return;
            }

            var cameraForward = CameraForward(in sample);
            var phase = time * 4.6f + SeedPhase(seed);
            var length = Mathf.Lerp(0.24f, 0.58f, growth) + impactPulse * 0.10f;
            var rearRadius = Mathf.Lerp(0.050f, 0.12f, growth);
            var noseRadius = Mathf.Lerp(0.080f, 0.20f, growth) + impactPulse * 0.04f;

            volumeBatch.AddTravelSpiral(
                Vector3.zero,
                length,
                rearRadius,
                noseRadius,
                0.72f,
                phase,
                Mathf.Lerp(0.028f, 0.055f, growth),
                WithAlpha(DeepForest, visibility * 0.62f),
                cameraForward,
                18);
            ribbonBatch.AddTravelSpiral(
                Vector3.forward * 0.015f,
                length * 0.92f,
                rearRadius * 0.82f,
                noseRadius * 1.08f,
                0.96f,
                phase + 2.15f,
                Mathf.Lerp(0.034f, 0.072f, growth),
                WithAlpha(Emerald, visibility * 0.72f),
                cameraForward,
                22);

            if (impactPulse > 0.001f)
            {
                ribbonBatch.AddOpenVortex(
                    Vector3.up * 0.02f,
                    Mathf.Lerp(0.48f, 0.72f, impactPulse),
                    0.055f,
                    Mathf.Lerp(0.20f, 0.28f, impactPulse),
                    phase + 0.40f,
                    3.02f,
                    0.14f,
                    0.042f,
                    WithAlpha(LimeEdge, visibility * impactPulse * 0.52f),
                    cameraForward,
                    18);
            }

            SetPhase(volumeBatch, time * 2.6f);
            SetPhase(ribbonBatch, time * 4.3f);
            volumeBatch.Commit();
            ribbonBatch.Commit();
        }

        void SampleDirection(in SpellSample sample)
        {
            var time = sample.AbsoluteTime;
            var contact = ContactTime;
            var travel = Ease(WindupTime * 0.65f, contact, time);
            var vanish = 1f - Ease(contact + 0.06f, contact + 0.30f, time);
            var visibility = travel * Mathf.Max(0f, vanish);

            ribbonBatch.Begin();
            leafBatch.Begin();
            if (visibility <= 0.001f)
            {
                ribbonBatch.Commit();
                leafBatch.Commit();
                return;
            }

            var cameraForward = CameraForward(in sample);
            var phase = time * 6.0f + SeedPhase(seed + 101);
            var length = Mathf.Lerp(0.22f, 0.54f, travel);
            var rearRadius = Mathf.Lerp(0.038f, 0.10f, travel);
            var noseRadius = Mathf.Lerp(0.065f, 0.17f, travel);

            ribbonBatch.AddTravelSpiral(
                Vector3.zero,
                length,
                rearRadius,
                noseRadius,
                0.78f,
                phase,
                Mathf.Lerp(0.028f, 0.052f, travel),
                WithAlpha(LeafGreen, visibility * 0.78f),
                cameraForward,
                20);
            ribbonBatch.AddTravelSpiral(
                Vector3.forward * 0.012f,
                length * 0.86f,
                rearRadius * 0.86f,
                noseRadius * 1.06f,
                1.04f,
                phase + 2.70f,
                Mathf.Lerp(0.022f, 0.044f, travel),
                WithAlpha(Emerald, visibility * 0.58f),
                cameraForward,
                18);
            AddTravelLeaves(
                leafBatch,
                length,
                noseRadius,
                travel,
                visibility * 0.74f,
                seed + 211);

            leafBatch.Commit();
            ribbonBatch.Commit();
        }

        void SampleImpactBack(in SpellSample sample)
        {
            var time = sample.AbsoluteTime;
            var local = time - ContactTime;
            var impact = Ease(0f, 0.16f, local)
                * (1f - Ease(0.50f, 0.76f, local));
            var expand = Ease(0.03f, 0.36f, local);
            var tail = Ease(0.38f, 0.64f, local)
                * (1f - Ease(0.96f, 1.14f, local));
            var visibility = Mathf.Max(impact, tail);

            volumeBatch.Begin();
            groundBatch.Begin();
            leafBatch.Begin();
            if (visibility <= 0.001f)
            {
                volumeBatch.Commit();
                groundBatch.Commit();
                leafBatch.Commit();
                return;
            }

            var cameraForward = CameraForward(in sample);
            if (impact > 0.001f)
            {
                volumeBatch.AddOpenVortex(
                    Vector3.up * 0.025f,
                    Mathf.Lerp(0.56f, 1.20f, expand),
                    Mathf.Lerp(0.060f, 0.11f, expand),
                    Mathf.Lerp(0.22f, 0.42f, expand),
                    SeedPhase(seed + 401) + local * 2.1f,
                    3.04f,
                    0.18f,
                    Mathf.Lerp(0.042f, 0.076f, expand),
                    WithAlpha(Emerald, impact * 0.66f),
                    cameraForward,
                    20);
                volumeBatch.AddOpenVortex(
                    Vector3.up * 0.06f + Vector3.back * 0.02f,
                    Mathf.Lerp(0.44f, 0.98f, expand),
                    Mathf.Lerp(0.042f, 0.075f, expand),
                    Mathf.Lerp(0.15f, 0.31f, expand),
                    SeedPhase(seed + 407) + local * 2.7f,
                    2.46f,
                    0.10f,
                    Mathf.Lerp(0.030f, 0.058f, expand),
                    WithAlpha(DeepForest, impact * 0.72f),
                    cameraForward,
                    18);

                var groundRadius = Mathf.Lerp(0.34f, 0.84f, expand);
                groundBatch.AddGroundArc(
                    groundRadius,
                    -1.10f + SeedPhase(seed + 410) * 0.12f,
                    1.58f,
                    Mathf.Lerp(0.032f, 0.060f, expand),
                    WithAlpha(LeafGreen, impact * 0.56f),
                    22);
                groundBatch.AddGroundArc(
                    groundRadius * 0.78f,
                    1.34f + SeedPhase(seed + 413) * 0.14f,
                    1.18f,
                    Mathf.Lerp(0.024f, 0.046f, expand),
                    WithAlpha(LimeEdge, impact * 0.38f),
                    18);
                AddLeafBurst(
                    leafBatch,
                    Mathf.Lerp(0.28f, 0.82f, expand),
                    expand,
                    impact * 0.82f,
                    8,
                    seed + 501,
                    false,
                    local);
            }
            if (tail > 0.001f)
            {
                volumeBatch.AddOpenVortex(
                    Vector3.up * 0.36f,
                    Mathf.Lerp(0.46f, 0.64f, tail),
                    0.028f,
                    Mathf.Lerp(0.14f, 0.20f, tail),
                    SeedPhase(seed + 419) + local * 1.4f,
                    2.18f,
                    0.08f,
                    0.038f,
                    WithAlpha(Emerald, tail * 0.28f),
                    cameraForward,
                    14);
                AddLeafBurst(
                    leafBatch,
                    Mathf.Lerp(0.36f, 0.58f, tail),
                    tail,
                    tail * 0.32f,
                    3,
                    seed + 523,
                    false,
                    local + 0.24f);
            }
            volumeBatch.Commit();
            groundBatch.Commit();
            leafBatch.Commit();
        }

        void SampleImpactFront(in SpellSample sample)
        {
            var time = sample.AbsoluteTime;
            var local = time - ContactTime;
            var appear = Ease(0f, 0.045f, local);
            var expand = Ease(0.02f, 0.28f, local);
            var decay = 1f - Ease(0.50f, 0.74f, local);
            var visibility = appear * Mathf.Max(0f, decay);

            volumeBatch.Begin();
            ribbonBatch.Begin();
            leafBatch.Begin();
            if (visibility <= 0.001f)
            {
                volumeBatch.Commit();
                ribbonBatch.Commit();
                leafBatch.Commit();
                return;
            }

            var cameraForward = CameraForward(in sample);
            ribbonBatch.AddOpenVortex(
                Vector3.up * 0.025f,
                Mathf.Lerp(0.68f, 1.30f, expand),
                Mathf.Lerp(0.070f, 0.12f, expand),
                Mathf.Lerp(0.28f, 0.44f, expand),
                time * 3.2f + SeedPhase(seed + 601),
                3.12f,
                0.12f,
                Mathf.Lerp(0.046f, 0.082f, expand),
                WithAlpha(LimeEdge, visibility * 0.68f),
                cameraForward,
                22);
            ribbonBatch.AddOpenVortex(
                Vector3.up * 0.08f + Vector3.back * 0.03f,
                Mathf.Lerp(0.56f, 1.12f, expand),
                Mathf.Lerp(0.048f, 0.088f, expand),
                Mathf.Lerp(0.19f, 0.34f, expand),
                -time * 2.5f + SeedPhase(seed + 607),
                2.62f,
                0.08f,
                Mathf.Lerp(0.034f, 0.064f, expand),
                WithAlpha(Emerald, visibility * 0.58f),
                cameraForward,
                20);
            var gust = Ease(0.035f, 0.22f, local)
                * (1f - Ease(0.25f, 0.48f, local));
            if (gust > 0.001f)
            {
                var cameraRight = CameraRight(in sample);
                var gustUp = Vector3.up;
                ribbonBatch.AddGustWedge(
                    Vector3.up * 0.12f,
                    cameraRight,
                    gustUp,
                    -34f,
                    Mathf.Lerp(0.24f, 0.56f, expand),
                    Mathf.Lerp(0.045f, 0.085f, expand),
                    0.16f,
                    time * 1.8f + SeedPhase(seed + 612),
                    WithAlpha(LimeEdge, gust * 0.58f),
                    cameraForward,
                    12);
                ribbonBatch.AddGustWedge(
                    Vector3.up * 0.20f + Vector3.back * 0.02f,
                    cameraRight,
                    gustUp,
                    16f,
                    Mathf.Lerp(0.20f, 0.48f, expand),
                    Mathf.Lerp(0.040f, 0.074f, expand),
                    0.22f,
                    time * 2.1f + SeedPhase(seed + 617),
                    WithAlpha(Emerald, gust * 0.50f),
                    cameraForward,
                    12);
                ribbonBatch.AddGustWedge(
                    Vector3.up * 0.16f + Vector3.back * 0.04f,
                    cameraRight,
                    gustUp,
                    103f,
                    Mathf.Lerp(0.18f, 0.38f, expand),
                    Mathf.Lerp(0.032f, 0.062f, expand),
                    0.28f,
                    time * 1.5f + SeedPhase(seed + 623),
                    WithAlpha(AirWhite, gust * 0.22f),
                    cameraForward,
                    11);
            }

            AddLeafBurst(
                leafBatch,
                Mathf.Lerp(0.32f, 0.84f, expand),
                expand,
                visibility * 0.78f,
                6,
                seed + 701,
                true,
                local + 0.08f);
            volumeBatch.Commit();
            ribbonBatch.Commit();
            leafBatch.Commit();
        }

        void SampleAccent(in SpellSample sample)
        {
            var local = sample.AbsoluteTime - ContactTime;
            var compression = Ease(0f, 0.035f, local);
            var appear = Ease(0f, 0.018f, local);
            var visibility = appear * (1f - Ease(0.055f, 0.11f, local));

            flashBatch.Begin();
            leafBatch.Begin();
            if (visibility <= 0.001f)
            {
                flashBatch.Commit();
                leafBatch.Commit();
                return;
            }

            var cameraRight = CameraRight(in sample);
            var cameraUp = CameraUp(in sample);
            flashBatch.AddSoftCore(
                Vector3.zero,
                cameraRight,
                cameraUp,
                Mathf.Lerp(0.07f, 0.15f, compression),
                0.12f,
                WithAlpha(AirWhite, visibility * 0.48f),
                WithAlpha(Emerald, visibility * 0.22f));
            AddLeafBurst(
                leafBatch,
                Mathf.Lerp(0.18f, 0.30f, compression),
                compression,
                visibility * 0.42f,
                4,
                seed + 809,
                true,
                local);
            flashBatch.Commit();
            leafBatch.Commit();
        }

        void AddTravelLeaves(
            DynamicBatch batch,
            float length,
            float radius,
            float travel,
            float opacity,
            int leafSeed)
        {
            const int count = 14;
            var phase = SeedPhase(leafSeed);
            for (var index = 0; index < count; index++)
            {
                var randomA = Hash01(leafSeed + index * 17);
                var randomB = Hash01(leafSeed + index * 29);
                var normalized = index / (float)(count - 1);
                var angle = phase + index * 2.399963f + travel * (1.8f + randomA * 1.4f);
                var radial = radius * (0.52f + randomA * 0.62f);
                var center = new Vector3(
                    Mathf.Cos(angle) * radial,
                    Mathf.Sin(angle) * radial * 0.72f,
                    Mathf.Lerp(-length * 0.46f, length * 0.52f, normalized));
                center += Vector3.forward * (Mathf.Sin(angle * 1.7f) * 0.025f);
                var tangent = new Vector3(-Mathf.Sin(angle), Mathf.Cos(angle) * 0.72f, 0f).normalized;
                var direction = (tangent * Mathf.Lerp(0.48f, 0.72f, randomB)
                    + Vector3.forward * Mathf.Lerp(0.26f, 0.58f, travel)
                    + Vector3.up * Mathf.Lerp(0.06f, 0.22f, randomA)).normalized;
                var side = Vector3.Cross(Vector3.forward, direction);
                if (side.sqrMagnitude < 0.001f)
                    side = Vector3.right;
                side.Normalize();
                var sizeBand = index % 3;
                var size = sizeBand == 0
                    ? Mathf.Lerp(0.022f, 0.031f, randomB)
                    : sizeBand == 1
                        ? Mathf.Lerp(0.031f, 0.045f, randomB)
                        : Mathf.Lerp(0.044f, 0.060f, randomB);
                var palette = index % 9 == 0 ? LeafGold : (index % 3 == 0 ? LimeEdge : LeafGreen);
                batch.AddLeaf(center, direction, side, size, WithAlpha(palette, opacity * (0.66f + randomA * 0.34f)));
            }
        }

        void AddLeafBurst(
            DynamicBatch batch,
            float radius,
            float expansion,
            float opacity,
            int count,
            int burstSeed,
            bool foreground,
            float time)
        {
            for (var index = 0; index < count; index++)
            {
                var randomA = Hash01(burstSeed + index * 17);
                var randomB = Hash01(burstSeed + index * 29);
                var angle = index * 2.399963f + SeedPhase(burstSeed)
                    + randomA * 0.46f + time * (2.6f + randomB * 2.8f);
                var outward = new Vector3(Mathf.Cos(angle), 0f, Mathf.Sin(angle));
                var distance = Mathf.Lerp(0.10f, radius, expansion) * (0.74f + randomB * 0.38f);
                var tangent = new Vector3(-Mathf.Sin(angle), 0f, Mathf.Cos(angle));
                var center = outward * distance + tangent * (time * (0.08f + randomA * 0.10f));
                center.y = Mathf.Lerp(0.04f, 0.54f, randomA) + Mathf.Sin(angle * 1.7f) * 0.07f;
                if (foreground)
                    center += Vector3.back * (0.05f + randomB * 0.10f);
                var direction = (outward * Mathf.Lerp(0.28f, 0.42f, randomA)
                    + tangent * Mathf.Lerp(0.42f, 0.74f, randomB)
                    + Vector3.up * Mathf.Lerp(0.14f, 0.45f, randomB)).normalized;
                var side = Vector3.Cross(direction, Vector3.up);
                if (side.sqrMagnitude < 0.001f)
                    side = Vector3.right;
                side.Normalize();
                var sizeBand = index % 3;
                var size = sizeBand == 0
                    ? Mathf.Lerp(0.018f, 0.028f, randomB)
                    : sizeBand == 1
                        ? Mathf.Lerp(0.028f, 0.042f, randomB)
                        : Mathf.Lerp(0.040f, 0.060f, randomB);
                size *= 0.76f + expansion * 0.44f;
                var palette = index % 9 == 0 ? LeafGold : (index % 3 == 0 ? LimeEdge : LeafGreen);
                batch.AddLeaf(center, direction, side, size, WithAlpha(palette, opacity * (0.64f + randomA * 0.36f)));
            }
        }

        DynamicBatch CreateBatch(string name, Material material)
        {
            return new DynamicBatch(transform, name, material, layer != null ? layer.sortingOrder : 0);
        }

        Material CreateWindMaterial(string name, int queue, Color color, float intensity, float core)
        {
            var shader = Shader.Find(WindVolumeShader) ?? Shader.Find("Sprites/Default");
            var material = new Material(shader) { name = name, renderQueue = queue };
            SetColor(material, "_Color", color);
            SetFloat(material, "_Intensity", intensity);
            SetFloat(material, "_Core", core);
            SetFloat(material, "_Distortion", 0.13f);
            if (noise != null && material.HasProperty("_NoiseTex"))
                material.SetTexture("_NoiseTex", noise);
            return material;
        }

        Material CreateRibbonMaterial(string name, int queue, Color body, Color edge, float glow, bool front = false)
        {
            var shader = Shader.Find(front ? FrontRibbonShader : WildRibbonShader)
                ?? Shader.Find("Sprites/Default");
            var material = new Material(shader) { name = name, renderQueue = queue };
            SetColor(material, "_Color", body);
            SetColor(material, "_EdgeColor", edge);
            SetFloat(material, "_Glow", glow);
            return material;
        }

        Material CreateLeafMaterial(string name, int queue)
        {
            var shader = Shader.Find(LeafShader) ?? Shader.Find("Unlit/Transparent");
            return new Material(shader) { name = name, renderQueue = queue };
        }

        void SetPhase(DynamicBatch batch, float phase)
        {
            batch?.SetFloat("_Phase", phase);
        }

        Vector3 CameraRight(in SpellSample sample)
        {
            var camera = sample.Camera != null ? sample.Camera : Camera.main;
            var value = camera != null ? transform.InverseTransformDirection(camera.transform.right) : Vector3.right;
            return value.sqrMagnitude > 0.0001f ? value.normalized : Vector3.right;
        }

        Vector3 CameraUp(in SpellSample sample)
        {
            var camera = sample.Camera != null ? sample.Camera : Camera.main;
            var value = camera != null ? transform.InverseTransformDirection(camera.transform.up) : Vector3.up;
            return value.sqrMagnitude > 0.0001f ? value.normalized : Vector3.up;
        }

        Vector3 CameraForward(in SpellSample sample)
        {
            var camera = sample.Camera != null ? sample.Camera : Camera.main;
            var value = camera != null ? transform.InverseTransformDirection(camera.transform.forward) : Vector3.forward;
            return value.sqrMagnitude > 0.0001f ? value.normalized : Vector3.forward;
        }

        float WindupTime => spell != null && spell.timeline != null ? Mathf.Max(0f, spell.timeline.windup) : 0.18f;
        float ContactTime => spell != null && spell.timeline != null
            ? Mathf.Max(0f, spell.timeline.windup) + Mathf.Max(0f, spell.timeline.travel)
            : 1.0f;
        float ImpactDuration => spell != null && spell.timeline != null ? Mathf.Max(0f, spell.timeline.impact) : 0.46f;
        float Duration => spell != null ? Mathf.Max(0.01f, spell.Duration) : 2.04f;

        static Color ReadColor(float[] values, Color fallback)
        {
            return values != null && values.Length >= 4
                ? new Color(values[0], values[1], values[2], values[3])
                : fallback;
        }

        static Color WithAlpha(Color color, float alpha)
        {
            color.a *= Mathf.Clamp01(alpha);
            return color;
        }

        static void SetColor(Material material, string property, Color value)
        {
            if (material != null && material.HasProperty(property))
                material.SetColor(property, value);
        }

        static void SetFloat(Material material, string property, float value)
        {
            if (material != null && material.HasProperty(property))
                material.SetFloat(property, value);
        }

        static float Ease(float start, float end, float value)
        {
            if (end <= start)
                return value >= end ? 1f : 0f;
            return Mathf.SmoothStep(0f, 1f, Mathf.InverseLerp(start, end, value));
        }

        static float SeedPhase(int value)
        {
            return Hash01(value) * Mathf.PI * 2f;
        }

        static float Hash01(int value)
        {
            unchecked
            {
                uint hash = (uint)value;
                hash ^= hash >> 16;
                hash *= 0x7feb352dU;
                hash ^= hash >> 15;
                hash *= 0x846ca68bU;
                hash ^= hash >> 16;
                return (hash & 0x00ffffffU) / 16777215f;
            }
        }

        void Release()
        {
            if (released)
                return;
            released = true;
            volumeBatch?.Dispose();
            ribbonBatch?.Dispose();
            groundBatch?.Dispose();
            leafBatch?.Dispose();
            flashBatch?.Dispose();
            volumeBatch = null;
            ribbonBatch = null;
            groundBatch = null;
            leafBatch = null;
            flashBatch = null;
        }

        static void DestroyOwned(UnityEngine.Object value)
        {
            if (value == null)
                return;
#if UNITY_EDITOR
            if (!Application.isPlaying)
            {
                UnityEngine.Object.DestroyImmediate(value);
                return;
            }
#endif
            UnityEngine.Object.Destroy(value);
        }

        sealed class DynamicBatch
        {
            readonly Transform owner;
            readonly GameObject root;
            readonly Mesh mesh;
            readonly MeshRenderer renderer;
            readonly Material material;
            readonly List<Vector3> vertices = new(512);
            readonly List<Color> colors = new(512);
            readonly List<Vector2> uvs = new(512);
            readonly List<int> triangles = new(768);

            public DynamicBatch(Transform parent, string name, Material ownedMaterial, int sortingOrder)
            {
                owner = parent;
                material = ownedMaterial;
                root = new GameObject(name);
                root.transform.SetParent(parent, false);
                root.hideFlags = HideFlags.DontSave;
                var filter = root.AddComponent<MeshFilter>();
                renderer = root.AddComponent<MeshRenderer>();
                renderer.sharedMaterial = material;
                renderer.sortingOrder = sortingOrder;
                renderer.shadowCastingMode = ShadowCastingMode.Off;
                renderer.receiveShadows = false;
                renderer.allowOcclusionWhenDynamic = false;
                mesh = new Mesh { name = name, hideFlags = HideFlags.DontSave };
                mesh.MarkDynamic();
                filter.sharedMesh = mesh;
                renderer.enabled = false;
            }

            public void Begin()
            {
                vertices.Clear();
                colors.Clear();
                uvs.Clear();
                triangles.Clear();
            }

            public void SetFloat(string property, float value)
            {
                if (material != null && material.HasProperty(property))
                    material.SetFloat(property, value);
            }

            public void AddQuad(Vector3 center, Vector3 right, Vector3 up, Color color)
            {
                var baseVertex = vertices.Count;
                vertices.Add(center - right - up);
                vertices.Add(center + right - up);
                vertices.Add(center + right + up);
                vertices.Add(center - right + up);
                colors.Add(color);
                colors.Add(color);
                colors.Add(color);
                colors.Add(color);
                uvs.Add(new Vector2(0f, 0f));
                uvs.Add(new Vector2(1f, 0f));
                uvs.Add(new Vector2(1f, 1f));
                uvs.Add(new Vector2(0f, 1f));
                AddQuadTriangles(baseVertex);
            }

            public void AddTravelSpiral(
                Vector3 origin,
                float length,
                float rearRadius,
                float noseRadius,
                float turns,
                float phase,
                float width,
                Color color,
                Vector3 cameraForward,
                int segments)
            {
                if (segments < 2 || color.a <= 0.001f)
                    return;
                var baseVertex = vertices.Count;
                var step = 1f / (segments - 1f);
                for (var index = 0; index < segments; index++)
                {
                    var s = index * step;
                    var point = TravelPoint(s, origin, length, rearRadius, noseRadius, turns, phase);
                    var previous = TravelPoint(Mathf.Max(0f, s - step), origin, length, rearRadius, noseRadius, turns, phase);
                    var next = TravelPoint(Mathf.Min(1f, s + step), origin, length, rearRadius, noseRadius, turns, phase);
                    var tangent = next - previous;
                    if (tangent.sqrMagnitude < 0.0001f)
                        tangent = Vector3.forward;
                    tangent.Normalize();
                    var side = Vector3.Cross(cameraForward, tangent);
                    if (side.sqrMagnitude < 0.0001f)
                        side = Vector3.Cross(Vector3.up, tangent);
                    if (side.sqrMagnitude < 0.0001f)
                        side = Vector3.right;
                    side.Normalize();
                    var widthWave = 0.78f
                        + 0.16f * Mathf.Sin(s * Mathf.PI * 4f + phase)
                        + 0.06f * Mathf.Sin(s * Mathf.PI * 9f - phase * 0.7f);
                    var fade = Mathf.SmoothStep(0f, 0.10f, s)
                        * (1f - Mathf.SmoothStep(0.88f, 1f, s));
                    AddStripPair(
                        baseVertex,
                        index,
                        point,
                        side * width * widthWave * 0.5f,
                        WithAlpha(color, fade),
                        s);
                }
                AddStripTriangles(baseVertex, segments);
            }

            public void AddOpenVortex(
                Vector3 origin,
                float height,
                float bottomRadius,
                float topRadius,
                float startAngle,
                float coverage,
                float phase,
                float width,
                Color color,
                Vector3 cameraForward,
                int segments)
            {
                if (segments < 2 || color.a <= 0.001f)
                    return;
                var baseVertex = vertices.Count;
                var step = 1f / (segments - 1f);
                for (var index = 0; index < segments; index++)
                {
                    var s = index * step;
                    var point = OpenVortexPoint(s, origin, height, bottomRadius, topRadius, startAngle, coverage, phase);
                    var previous = OpenVortexPoint(Mathf.Max(0f, s - step), origin, height, bottomRadius, topRadius, startAngle, coverage, phase);
                    var next = OpenVortexPoint(Mathf.Min(1f, s + step), origin, height, bottomRadius, topRadius, startAngle, coverage, phase);
                    var tangent = next - previous;
                    if (tangent.sqrMagnitude < 0.0001f)
                        tangent = Vector3.up;
                    tangent.Normalize();
                    var side = Vector3.Cross(cameraForward, tangent);
                    if (side.sqrMagnitude < 0.0001f)
                        side = Vector3.Cross(Vector3.forward, tangent);
                    if (side.sqrMagnitude < 0.0001f)
                        side = Vector3.right;
                    side.Normalize();
                    var widthWave = 0.80f
                        + 0.14f * Mathf.Sin(s * Mathf.PI * 4.2f + phase)
                        + 0.06f * Mathf.Sin(s * Mathf.PI * 10.0f - phase * 0.8f);
                    var fade = Mathf.SmoothStep(0f, 0.09f, s)
                        * (1f - Mathf.SmoothStep(0.90f, 1f, s));
                    AddStripPair(
                        baseVertex,
                        index,
                        point,
                        side * width * widthWave * 0.5f,
                        WithAlpha(color, fade),
                        s);
                }
                AddStripTriangles(baseVertex, segments);
            }

            public void AddGustWedge(
                Vector3 origin,
                Vector3 right,
                Vector3 up,
                float angleDegrees,
                float length,
                float width,
                float bend,
                float phase,
                Color color,
                Vector3 cameraForward,
                int segments)
            {
                if (segments < 2 || color.a <= 0.001f)
                    return;
                right.Normalize();
                up.Normalize();
                var angle = angleDegrees * Mathf.Deg2Rad;
                var direction = (right * Mathf.Cos(angle) + up * Mathf.Sin(angle)).normalized;
                var baseVertex = vertices.Count;
                var step = 1f / (segments - 1f);
                for (var index = 0; index < segments; index++)
                {
                    var s = index * step;
                    var point = GustPoint(s, origin, direction, up, length, bend, phase);
                    var previous = GustPoint(Mathf.Max(0f, s - step), origin, direction, up, length, bend, phase);
                    var next = GustPoint(Mathf.Min(1f, s + step), origin, direction, up, length, bend, phase);
                    var tangent = next - previous;
                    if (tangent.sqrMagnitude < 0.0001f)
                        tangent = direction;
                    tangent.Normalize();
                    var side = Vector3.Cross(cameraForward, tangent);
                    if (side.sqrMagnitude < 0.0001f)
                        side = Vector3.Cross(Vector3.up, tangent);
                    if (side.sqrMagnitude < 0.0001f)
                        side = Vector3.right;
                    side.Normalize();
                    var widthWave = 0.72f
                        + 0.24f * Mathf.Sin(s * Mathf.PI * 2.2f + phase)
                        + 0.09f * Mathf.Sin(s * Mathf.PI * 6.5f - phase * 0.6f);
                    var fade = Mathf.SmoothStep(0f, 0.08f, s)
                        * (1f - Mathf.SmoothStep(0.82f, 1f, s));
                    AddStripPair(
                        baseVertex,
                        index,
                        point,
                        side * width * widthWave * 0.5f,
                        WithAlpha(color, fade),
                        s);
                }
                AddStripTriangles(baseVertex, segments);
            }

            public void AddSoftCore(
                Vector3 center,
                Vector3 right,
                Vector3 up,
                float radius,
                float irregularity,
                Color core,
                Color edge)
            {
                if (core.a <= 0.001f)
                    return;
                right.Normalize();
                up.Normalize();
                const int sides = 9;
                var centerIndex = vertices.Count;
                vertices.Add(center);
                colors.Add(core);
                uvs.Add(new Vector2(0.5f, 0.5f));
                for (var index = 0; index < sides; index++)
                {
                    var angle = index / (float)sides * Mathf.PI * 2f + 0.18f;
                    var variation = 1f + Mathf.Sin(index * 2.71f + 0.42f) * irregularity;
                    var point = center
                        + right * (Mathf.Cos(angle) * radius * variation)
                        + up * (Mathf.Sin(angle) * radius * variation);
                    vertices.Add(point);
                    colors.Add(WithAlpha(Color.Lerp(edge, core, 0.22f), edge.a));
                    uvs.Add(new Vector2(0.5f + Mathf.Cos(angle) * 0.5f, 0.5f + Mathf.Sin(angle) * 0.5f));
                }
                for (var index = 0; index < sides; index++)
                {
                    var next = index == sides - 1 ? 0 : index + 1;
                    triangles.Add(centerIndex);
                    triangles.Add(centerIndex + 1 + index);
                    triangles.Add(centerIndex + 1 + next);
                }
            }

            public void AddHelix(
                float height,
                float radius,
                float turns,
                float phase,
                float width,
                Color color,
                Vector3 cameraForward,
                int segments,
                float seedJitter)
            {
                if (segments < 2 || color.a <= 0.001f)
                    return;
                var baseVertex = vertices.Count;
                var step = 1f / (segments - 1f);
                for (var index = 0; index < segments; index++)
                {
                    var s = index * step;
                    var point = HelixPoint(s, height, radius, turns, phase, seedJitter);
                    var previous = HelixPoint(Mathf.Max(0f, s - step), height, radius, turns, phase, seedJitter);
                    var next = HelixPoint(Mathf.Min(1f, s + step), height, radius, turns, phase, seedJitter);
                    var tangent = next - previous;
                    if (tangent.sqrMagnitude < 0.0001f)
                        tangent = Vector3.up;
                    tangent.Normalize();
                    var side = Vector3.Cross(cameraForward, tangent);
                    if (side.sqrMagnitude < 0.0001f)
                        side = Vector3.Cross(Vector3.forward, tangent);
                    side.Normalize();
                    var widthWave = 0.78f
                        + 0.16f * Mathf.Sin(s * Mathf.PI * 5f + phase)
                        + 0.07f * Mathf.Sin(s * Mathf.PI * 13f - phase * 0.7f);
                    AddStripPair(
                        baseVertex,
                        index,
                        point,
                        side * width * widthWave * 0.5f,
                        WithAlpha(color, Mathf.SmoothStep(0f, 0.08f, s) * (1f - Mathf.SmoothStep(0.90f, 1f, s))),
                        s);
                }
                AddStripTriangles(baseVertex, segments);
            }

            public void AddGroundArc(
                float radius,
                float startAngle,
                float coverage,
                float width,
                Color color,
                int segments)
            {
                if (segments < 2 || color.a <= 0.001f)
                    return;
                var baseVertex = vertices.Count;
                var step = 1f / (segments - 1f);
                for (var index = 0; index < segments; index++)
                {
                    var s = index * step;
                    var angle = startAngle + coverage * s;
                    var point = new Vector3(Mathf.Cos(angle) * radius, 0.018f, Mathf.Sin(angle) * radius);
                    var previous = new Vector3(
                        Mathf.Cos(angle - 0.02f) * radius,
                        0.018f,
                        Mathf.Sin(angle - 0.02f) * radius);
                    var next = new Vector3(
                        Mathf.Cos(angle + 0.02f) * radius,
                        0.018f,
                        Mathf.Sin(angle + 0.02f) * radius);
                    var tangent = (next - previous).normalized;
                    var side = Vector3.Cross(Vector3.up, tangent).normalized;
                    AddStripPair(
                        baseVertex,
                        index,
                        point,
                        side * width * (0.78f + 0.22f * Mathf.Sin(s * Mathf.PI)),
                        WithAlpha(color, Mathf.SmoothStep(0f, 0.12f, s) * (1f - Mathf.SmoothStep(0.84f, 1f, s))),
                        s);
                }
                AddStripTriangles(baseVertex, segments);
            }

            public void AddLeaf(Vector3 center, Vector3 direction, Vector3 side, float size, Color color)
            {
                if (color.a <= 0.001f)
                    return;
                direction.Normalize();
                side.Normalize();
                var baseVertex = vertices.Count;
                var basePoint = center - direction * size * 0.56f;
                var leftShoulder = center - direction * size * 0.10f - side * size * 0.24f;
                var leftTip = center + direction * size * 0.30f - side * size * 0.11f;
                var tip = center + direction * size * 0.62f;
                var rightTip = center + direction * size * 0.30f + side * size * 0.11f;
                var rightShoulder = center - direction * size * 0.10f + side * size * 0.24f;
                var dark = WithAlpha(Color.Lerp(DeepJade, color, 0.42f), color.a);
                var light = WithAlpha(Color.Lerp(color, AirWhite, 0.20f), color.a);
                vertices.Add(basePoint);
                vertices.Add(leftShoulder);
                vertices.Add(leftTip);
                vertices.Add(tip);
                vertices.Add(rightTip);
                vertices.Add(rightShoulder);
                colors.Add(dark);
                colors.Add(color);
                colors.Add(color);
                colors.Add(light);
                colors.Add(color);
                colors.Add(color);
                uvs.Add(new Vector2(0.0f, 0.5f));
                uvs.Add(new Vector2(0.28f, 0.18f));
                uvs.Add(new Vector2(0.64f, 0.34f));
                uvs.Add(new Vector2(1.0f, 1.0f));
                uvs.Add(new Vector2(0.64f, 0.66f));
                uvs.Add(new Vector2(0.28f, 0.82f));
                triangles.Add(baseVertex + 0);
                triangles.Add(baseVertex + 1);
                triangles.Add(baseVertex + 2);
                triangles.Add(baseVertex + 0);
                triangles.Add(baseVertex + 2);
                triangles.Add(baseVertex + 3);
                triangles.Add(baseVertex + 0);
                triangles.Add(baseVertex + 3);
                triangles.Add(baseVertex + 4);
                triangles.Add(baseVertex + 0);
                triangles.Add(baseVertex + 4);
                triangles.Add(baseVertex + 5);
            }

            public void AddRadialFlash(
                Vector3 center,
                Vector3 right,
                Vector3 up,
                float radius,
                int rays,
                Color core,
                Color edge)
            {
                if (rays < 3 || core.a <= 0.001f)
                    return;
                var centerIndex = vertices.Count;
                vertices.Add(center);
                colors.Add(core);
                uvs.Add(new Vector2(0.5f, 0.5f));

                var coreRays = 8;
                var coreRadius = radius * 0.22f;
                for (var index = 0; index < coreRays; index++)
                {
                    var angle = index / (float)coreRays * Mathf.PI * 2f;
                    vertices.Add(center + right * Mathf.Cos(angle) * coreRadius + up * Mathf.Sin(angle) * coreRadius);
                    colors.Add(edge);
                    uvs.Add(new Vector2(0.5f + Mathf.Cos(angle) * 0.16f, 0.5f + Mathf.Sin(angle) * 0.16f));
                }
                for (var index = 0; index < coreRays; index++)
                {
                    var next = index == coreRays - 1 ? 0 : index + 1;
                    triangles.Add(centerIndex);
                    triangles.Add(centerIndex + 1 + index);
                    triangles.Add(centerIndex + 1 + next);
                }

                for (var index = 0; index < rays; index++)
                {
                    var angle = index / (float)rays * Mathf.PI * 2f;
                    var rayRadius = radius * (0.74f + 0.26f * Mathf.Sin(index * 3.17f + 0.7f));
                    var halfWidth = 0.095f + 0.025f * (0.5f + 0.5f * Mathf.Sin(index * 2.13f + 0.4f));
                    var leftAngle = angle - halfWidth;
                    var rightAngle = angle + halfWidth;
                    vertices.Add(center + right * Mathf.Cos(leftAngle) * rayRadius + up * Mathf.Sin(leftAngle) * rayRadius);
                    colors.Add(edge);
                    uvs.Add(new Vector2(0.5f + Mathf.Cos(leftAngle) * 0.5f, 0.5f + Mathf.Sin(leftAngle) * 0.5f));
                    vertices.Add(center + right * Mathf.Cos(rightAngle) * rayRadius + up * Mathf.Sin(rightAngle) * rayRadius);
                    colors.Add(edge);
                    uvs.Add(new Vector2(0.5f + Mathf.Cos(rightAngle) * 0.5f, 0.5f + Mathf.Sin(rightAngle) * 0.5f));
                    var rayVertex = centerIndex + 1 + coreRays + index * 2;
                    triangles.Add(centerIndex);
                    triangles.Add(rayVertex);
                    triangles.Add(rayVertex + 1);
                }
            }

            public void Commit()
            {
                if (vertices.Count == 0)
                {
                    mesh.Clear();
                    renderer.enabled = false;
                    return;
                }
                mesh.Clear();
                mesh.SetVertices(vertices);
                mesh.SetColors(colors);
                mesh.SetUVs(0, uvs);
                mesh.SetTriangles(triangles, 0, true);
                mesh.RecalculateBounds();
                renderer.enabled = true;
            }

            public void Dispose()
            {
                if (root != null)
                    DestroyOwned(root);
                if (mesh != null)
                    DestroyOwned(mesh);
                if (material != null)
                    DestroyOwned(material);
            }

            static Vector3 TravelPoint(
                float s,
                Vector3 origin,
                float length,
                float rearRadius,
                float noseRadius,
                float turns,
                float phase)
            {
                var angle = phase + s * turns * Mathf.PI * 2f;
                var radius = Mathf.Lerp(rearRadius, noseRadius, s)
                    * (1f + Mathf.Sin(angle * 1.7f + phase) * 0.07f);
                return origin
                    + Vector3.forward * Mathf.Lerp(-length * 0.52f, length * 0.48f, s)
                    + new Vector3(Mathf.Cos(angle) * radius, Mathf.Sin(angle) * radius, 0f);
            }

            static Vector3 OpenVortexPoint(
                float s,
                Vector3 origin,
                float height,
                float bottomRadius,
                float topRadius,
                float startAngle,
                float coverage,
                float phase)
            {
                var angle = startAngle + phase + coverage * s;
                var radius = Mathf.Lerp(bottomRadius, topRadius, s)
                    * (1f + Mathf.Sin(angle * 1.45f + phase * 0.7f) * 0.08f);
                return origin
                    + Vector3.up * (s * height)
                    + new Vector3(Mathf.Cos(angle) * radius, 0f, Mathf.Sin(angle) * radius);
            }

            static Vector3 GustPoint(
                float s,
                Vector3 origin,
                Vector3 direction,
                Vector3 up,
                float length,
                float bend,
                float phase)
            {
                return origin
                    + direction * (length * s)
                    + up * (bend * Mathf.Sin(Mathf.PI * s))
                    + Vector3.forward * (Mathf.Sin(phase + s * Mathf.PI * 1.7f) * 0.018f * s);
            }

            static Vector3 HelixPoint(float s, float height, float radius, float turns, float phase, float jitter)
            {
                var angle = phase + s * turns * Mathf.PI * 2f;
                var radial = radius * (0.78f + 0.22f * s)
                    * (1f + Mathf.Sin(angle * 2.7f + jitter * 6f) * 0.055f);
                return new Vector3(
                    Mathf.Cos(angle) * radial,
                    s * height,
                    Mathf.Sin(angle) * radial);
            }

            void AddStripPair(
                int baseVertex,
                int index,
                Vector3 point,
                Vector3 halfSide,
                Color color,
                float along)
            {
                var left = point - halfSide;
                var right = point + halfSide;
                vertices.Add(left);
                vertices.Add(right);
                colors.Add(color);
                colors.Add(color);
                uvs.Add(new Vector2(along, 0f));
                uvs.Add(new Vector2(along, 1f));
            }

            void AddStripTriangles(int baseVertex, int segments)
            {
                for (var index = 1; index < segments; index++)
                {
                    var previous = baseVertex + (index - 1) * 2;
                    var current = baseVertex + index * 2;
                    triangles.Add(previous);
                    triangles.Add(current);
                    triangles.Add(current + 1);
                    triangles.Add(previous);
                    triangles.Add(current + 1);
                    triangles.Add(previous + 1);
                }
            }

            void AddQuadTriangles(int baseVertex)
            {
                triangles.Add(baseVertex + 0);
                triangles.Add(baseVertex + 1);
                triangles.Add(baseVertex + 2);
                triangles.Add(baseVertex + 0);
                triangles.Add(baseVertex + 2);
                triangles.Add(baseVertex + 3);
            }
        }
    }
}
