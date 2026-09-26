using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace Mindstone.VFXV1
{
    /// <summary>
    /// Spell-private presentation for a demonic scream. The source silhouette,
    /// pressure volume, wave fronts, target compression, release particles,
    /// and camera impulse are intentionally owned by separate layer roles.
    /// </summary>
    public sealed class WraithScreamSpellExtension : MonoBehaviour, ISpellExtension
    {
        const string VolumeShaderResource =
            "Mindstone/VFXV1/Spells/beam-wraith-scream-v1/WraithScreamVolume";
        const string SpriteShaderResource =
            "Mindstone/VFXV1/Spells/beam-wraith-scream-v1/WraithScreamSprite";
        const string WaveShaderResource =
            "Mindstone/VFXV1/Spells/beam-wraith-scream-v1/WraithScreamWave";
        const string MeshWraithShaderResource =
            "Mindstone/VFXV1/Spells/beam-wraith-scream-v1/WraithScreamMesh";
        const string MeshWraithModelResource =
            "Mindstone/VFXV1/Spells/beam-wraith-scream-v1/Meshy/image";
        const string MeshWraithTextureResource =
            "Mindstone/VFXV1/Spells/beam-wraith-scream-v1/Meshy/image_texture-0-base_color";
        const string GhostFaceTextureResource =
            "Mindstone/VFXV1/Spells/beam-wraith-scream-v1/WraithScreamFace-v1";
        const string ShockwaveTextureResource =
            "Effects/HellHound/Texture/Shockwave";
        const string ParticleTextureResource =
            "Effects/Fool/Effekseer/TktkDarkRift/Parts/Line01";
        const string ImpactParticleTextureResource =
            "Effects/Fool/Effekseer/MaskExplosion/Texture/Particle01";
        const string SmokeTextureResource =
            "Effects/Fool/Effekseer/MaskExplosion/Texture/smoke_tex";
        const string GlowTextureResource =
            "Effects/Fool/Effekseer/MaskExplosion/Texture/glow";
        const string FlowNoiseTextureResource =
            "Effects/Fool/Effekseer/TktkDarkRift/Parts/Distortion";
        const string SonicPressureTextureResource =
            "Effects/Fool/Effekseer/MaskExplosion/Texture/Shock_wave_ring001_long";
        const string SonicFlowTextureResource =
            "Effects/Fool/Effekseer/MaskExplosion/Texture/aurora01";
        const string SonicFilamentTextureResource =
            "Effects/Fool/Effekseer/TktkDarkRift/Parts/Line6";
        readonly List<GameObject> ownedObjects = new();
        readonly List<Material> ownedMaterials = new();
        readonly List<Mesh> ownedMeshes = new();
        readonly List<GameObject> sourceCards = new();
        readonly List<Material> sourceMaterials = new();
        readonly List<GameObject> coneObjects = new();
        readonly List<Mesh> coneMeshes = new();
        readonly List<Material> coneMaterials = new();
        readonly List<GameObject> impactCards = new();
        readonly List<Material> impactMaterials = new();

        const int OrganicConeSegments = 14;
        const int FaceFragmentCount = 960;
        const int SonicPulseCount = 5;
        const int SonicEchoCount = 4;
        const int SonicArcSegments = 48;
        const int ImpactArcCount = 7;
        const int ImpactArcSegments = 28;

        SpellSpec spell;
        SpellLayerSpec layer;
        int seed;
        bool released;
        bool impactEmitted;
        Shader volumeShader;
        Shader spriteShader;
        Shader waveShader;
        Shader meshWraithShader;
        Texture2D ghostFaceTexture;
        Texture2D shockwaveTexture;
        Texture2D particleTexture;
        Texture2D impactParticleTexture;
        Texture2D smokeTexture;
        Texture2D glowTexture;
        Texture2D flowNoiseTexture;
        Texture2D sonicPressureTexture;
        Texture2D sonicFlowTexture;
        Texture2D sonicFilamentTexture;
        Texture2D meshWraithTexture;
        ParticleSystem impactParticles;
        ParticleSystem echoParticles;
        GameObject faceParticleObject;
        Mesh faceParticleMesh;
        Material faceParticleMaterial;
        Vector2[] faceParticleTargets;
        Color[] facePointColors;
        Vector3[] faceParticleVertices;
        Color32[] faceParticleVertexColors;
        GameObject sonicArcObject;
        Mesh sonicArcMesh;
        Material sonicArcMaterial;
        Vector3[] sonicArcVertices;
        Color32[] sonicArcVertexColors;
        GameObject impactArcObject;
        Mesh impactArcMesh;
        Material impactArcMaterial;
        Vector3[] impactArcVertices;
        Color32[] impactArcVertexColors;
        GameObject meshWraithObject;
        readonly List<Renderer> meshWraithRenderers = new();
        readonly List<Material> meshWraithMaterials = new();

        Camera shakeCamera;
        Vector3 shakeBasePosition;
        Quaternion shakeBaseRotation;
        bool shakeCaptured;

        public void Initialize(SpellSpec spellSpec, SpellLayerSpec layerSpec,
            int deterministicSeed)
        {
            spell = spellSpec;
            layer = layerSpec;
            seed = deterministicSeed;
            volumeShader = Resources.Load<Shader>(VolumeShaderResource)
                ?? Shader.Find("Mindstone/VFXV1/Wraith Scream Volume");
            spriteShader = Resources.Load<Shader>(SpriteShaderResource)
                ?? Shader.Find("Mindstone/VFXV1/Wraith Scream Sprite")
                ?? Shader.Find("Sprites/Default");
            waveShader = Resources.Load<Shader>(WaveShaderResource)
                ?? Shader.Find("Mindstone/VFXV1/Wraith Scream Wave");
            meshWraithShader = Resources.Load<Shader>(MeshWraithShaderResource)
                ?? Shader.Find("Mindstone/VFXV1/Wraith Scream Mesh");
            ghostFaceTexture = Resources.Load<Texture2D>(GhostFaceTextureResource);
            shockwaveTexture = Resources.Load<Texture2D>(ShockwaveTextureResource);
            particleTexture = Resources.Load<Texture2D>(ParticleTextureResource);
            impactParticleTexture = Resources.Load<Texture2D>(
                ImpactParticleTextureResource);
            smokeTexture = Resources.Load<Texture2D>(SmokeTextureResource);
            glowTexture = Resources.Load<Texture2D>(GlowTextureResource);
            flowNoiseTexture = Resources.Load<Texture2D>(FlowNoiseTextureResource);
            sonicPressureTexture = Resources.Load<Texture2D>(SonicPressureTextureResource);
            sonicFlowTexture = Resources.Load<Texture2D>(SonicFlowTextureResource);
            sonicFilamentTexture = Resources.Load<Texture2D>(
                SonicFilamentTextureResource);
            meshWraithTexture = Resources.Load<Texture2D>(
                MeshWraithTextureResource);
            if (volumeShader == null || spriteShader == null || waveShader == null
                || ghostFaceTexture == null || particleTexture == null
                || impactParticleTexture == null || sonicPressureTexture == null
                || sonicFlowTexture == null || sonicFilamentTexture == null)
            {
                Debug.LogError("[VFX V1] Wraith scream source stack is incomplete.");
                return;
            }

            switch (layer.role)
            {
                case "accent":
                    CreateSourceFace();
                    break;
                case "core":
                    CreatePressureVolumes();
                    break;
                case "direction":
                    CreateWaveRings();
                    break;
                case "impact-back":
                    CreateImpactBack();
                    break;
                case "impact-front":
                    CreateImpactFront();
                    break;
            }
        }

        public void Sample(in SpellSample sample)
        {
            if (released || layer == null)
                return;
            RestoreCameraShake();
            switch (layer.role)
            {
                case "accent":
                    SampleSourceFace(in sample);
                    break;
                case "core":
                    SamplePressureVolumes(in sample);
                    break;
                case "direction":
                    SampleWaveRings(in sample);
                    break;
                case "impact-back":
                    SampleImpactBack(in sample);
                    break;
                case "impact-front":
                    SampleImpactFront(in sample);
                    break;
            }
        }

        void CreateSourceFace()
        {
            CreateMeshWraith();
            CreateFaceAssembly();
            sourceCards.Add(CreateCard(
                "VFX V1 · Wraith scream ghost face",
                ghostFaceTexture,
                new Color(0.88f, 0.76f, 1f, 0.82f),
                1.28f,
                4200,
                false,
                sourceMaterials));
            sourceCards.Add(CreateCard(
                "VFX V1 · Wraith scream ghost echo",
                ghostFaceTexture,
                new Color(0.16f, 1f, 0.86f, 0.25f),
                0.72f,
                4210,
                false,
                sourceMaterials));
            sourceCards.Add(CreateCard(
                "VFX V1 · Wraith scream mouth core",
                shockwaveTexture,
                new Color(0.82f, 0.24f, 1f, 0.82f),
                2.4f,
                4230,
                false,
                sourceMaterials));
        }

        void CreateMeshWraith()
        {
            var prefab = Resources.Load<GameObject>(MeshWraithModelResource);
            if (prefab == null || meshWraithShader == null)
            {
                Debug.LogWarning("[VFX V1] Meshy wraith model is unavailable; using the 2D fallback face.");
                return;
            }

            meshWraithObject = Instantiate(prefab, transform);
            meshWraithObject.name = "VFX V1 · Meshy wraith scream hero";
            meshWraithObject.SetActive(false);
            ownedObjects.Add(meshWraithObject);

            var renderers = meshWraithObject.GetComponentsInChildren<Renderer>(true);
            for (var index = 0; index < renderers.Length; index++)
            {
                var sourceMaterial = renderers[index].sharedMaterial;
                var material = new Material(meshWraithShader)
                {
                    name = $"VFX V1 · Meshy wraith hero material {index}",
                    hideFlags = HideFlags.DontSave,
                    renderQueue = 4215
                };
                var sourceTexture = meshWraithTexture != null
                    ? meshWraithTexture
                    : sourceMaterial != null
                        ? sourceMaterial.mainTexture as Texture2D
                        : null;
                if (sourceTexture != null)
                    material.SetTexture("_MainTex", sourceTexture);
                material.SetColor("_Tint", new Color(0.40f, 0.12f, 0.72f, 1f));
                material.SetColor("_RimColor", new Color(0.68f, 1f, 1f, 1f));
                material.SetFloat("_Opacity", 0f);
                material.SetFloat("_Intensity", 2.02f);
                material.SetFloat("_Dissolve", 0f);
                material.SetFloat("_Burst", 0f);
                material.SetFloat("_Phase", seed * 0.017f + index * 1.31f);
                material.SetFloat("_RimPower", 2.6f);
                renderers[index].sharedMaterial = material;
                renderers[index].shadowCastingMode = ShadowCastingMode.Off;
                renderers[index].receiveShadows = false;
                meshWraithRenderers.Add(renderers[index]);
                meshWraithMaterials.Add(material);
                ownedMaterials.Add(material);
            }
        }

        void SampleSourceFace(in SpellSample sample)
        {
            var time = sample.AbsoluteTime;
            var contact = ContactTime;
            var appear = Ease(0.02f, spell.timeline.windup * 0.72f, time);
            var fade = 1f - Ease(contact + 0.24f, contact + 0.42f, time);
            var visibility = appear * fade;
            if (visibility <= 0.001f)
            {
                SetActive(sourceCards, false);
                if (faceParticleObject != null)
                    faceParticleObject.SetActive(false);
                if (meshWraithObject != null)
                    meshWraithObject.SetActive(false);
                return;
            }

            var axis = TravelAxis(in sample);
            var camera = sample.Camera;
            var towardsCamera = camera != null ? -camera.transform.forward : Vector3.back;
            var cameraUp = camera != null ? camera.transform.up : Vector3.up;
            var roll = ScreenAxisAngle(axis, camera);
            var throb = 1f + Mathf.Sin(time * 24f + seed * 0.07f) * 0.045f;
            var baseScale = Mathf.Lerp(0.78f, 1.10f, appear)
                * Mathf.Max(0.65f, sample.Scale.x) * throb;
            var sourcePosition = sample.Source
                + cameraUp * baseScale * 0.17f
                + towardsCamera * 0.12f;
            var faceRotation = BillboardRotation(camera, 0f);
            var lunge = Ease(spell.timeline.windup * 0.72f,
                contact - 0.020f, time);
            var meshPosition = sourcePosition
                + axis * baseScale * 0.30f * lunge;
            var faceReveal = Ease(spell.timeline.windup * 0.48f,
                spell.timeline.windup * 1.02f, time);
            var faceFade = 1f - Ease(contact - 0.015f,
                contact + 0.070f, time);
            var faceVisibility = visibility * faceReveal * faceFade;

            SampleMeshWraith(in sample, meshPosition, faceRotation,
                baseScale, visibility, faceVisibility);

            SetCard(sourceCards[0], sourceMaterials[0], sourcePosition,
                faceRotation,
                new Vector3(baseScale * 1.04f, baseScale * 1.04f, 1f),
                faceVisibility * (meshWraithObject == null ? 0.90f : 0.08f),
                time * 3.7f);
            SetCard(sourceCards[1], sourceMaterials[1],
                sourcePosition + towardsCamera * 0.025f,
                faceRotation,
                new Vector3(baseScale * 1.10f, baseScale * 1.10f, 1f),
                faceVisibility * (meshWraithObject == null ? 0.25f : 0.12f),
                time * 4.1f + 1.3f);
            var mouthCharge = Ease(spell.timeline.windup * 0.72f,
                spell.timeline.windup + 0.055f, time);
            var mouthFade = 1f - Ease(contact - 0.015f,
                contact + 0.055f, time);
            SetCard(sourceCards[2], sourceMaterials[2],
                meshPosition + axis * baseScale * 0.025f
                    + towardsCamera * 0.16f,
                BillboardRotation(camera, 0f),
                new Vector3(baseScale * 0.22f, baseScale * 0.34f, 1f),
                visibility * mouthCharge * mouthFade * 0.92f,
                time * 7.2f);
            SampleFaceAssembly(in sample, meshPosition, faceRotation,
                baseScale, visibility);
        }

        void SampleMeshWraith(in SpellSample sample, Vector3 position,
            Quaternion rotation, float baseScale, float sourceVisibility,
            float faceVisibility)
        {
            if (meshWraithObject == null || meshWraithMaterials.Count == 0)
                return;

            var contact = ContactTime;
            var burst = Ease(contact - 0.010f, contact + 0.22f,
                sample.AbsoluteTime);
            var dissolve = Ease(contact - 0.012f, contact + 0.15f,
                sample.AbsoluteTime);
            var heroOpacity = faceVisibility * 0.96f;
            meshWraithObject.SetActive(heroOpacity > 0.001f);
            meshWraithObject.transform.SetPositionAndRotation(position,
                rotation);
            meshWraithObject.transform.localScale = Vector3.one
                * baseScale * 2.34f;
            for (var index = 0; index < meshWraithMaterials.Count; index++)
            {
                var material = meshWraithMaterials[index];
                material.SetFloat("_Opacity", Mathf.Clamp01(heroOpacity));
                material.SetFloat("_Dissolve", Mathf.Clamp01(dissolve));
                material.SetFloat("_Burst", Mathf.Clamp01(burst));
                material.SetFloat("_Phase", sample.AbsoluteTime * 5.8f
                    + seed * 0.017f + index * 1.31f);
                material.SetFloat("_Intensity", 1.75f
                    + Mathf.Clamp01(sourceVisibility) * 0.45f);
            }
        }

        void CreateFaceAssembly()
        {
            var candidates = new List<Vector2>();
            var candidateColors = new List<Color>();
            try
            {
                var pixels = ghostFaceTexture.GetPixels32();
                const int grid = 42;
                for (var row = 0; row < grid; row++)
                {
                    var pixelY = Mathf.Clamp(Mathf.RoundToInt(
                        (row + 0.5f) / grid * (ghostFaceTexture.height - 1)),
                        0, ghostFaceTexture.height - 1);
                    for (var column = 0; column < grid; column++)
                    {
                        var pixelX = Mathf.Clamp(Mathf.RoundToInt(
                            (column + 0.5f) / grid * (ghostFaceTexture.width - 1)),
                            0, ghostFaceTexture.width - 1);
                        var pixel = pixels[pixelY * ghostFaceTexture.width + pixelX];
                        if (pixel.a < 52)
                            continue;
                        candidates.Add(new Vector2(
                            (column + 0.5f) / grid - 0.5f,
                            (row + 0.5f) / grid - 0.5f));
                        var sampled = (Color)pixel;
                        var accent = (row + column) % 5 == 0
                            ? new Color(0.06f, 1f, 0.84f, 1f)
                            : new Color(0.72f, 0.10f, 1f, 1f);
                        sampled = Color.Lerp(accent, sampled, 0.58f);
                        var peak = Mathf.Max(sampled.r,
                            Mathf.Max(sampled.g, sampled.b));
                        if (peak < 0.42f)
                            sampled *= 0.42f / Mathf.Max(0.02f, peak);
                        sampled.a = 0.94f;
                        candidateColors.Add(sampled);
                    }
                }
            }
            catch (UnityException)
            {
                candidates.Clear();
                candidateColors.Clear();
            }

            if (candidates.Count < 32)
            {
                for (var index = 0; index < 128; index++)
                {
                    var angle = Hash01(seed + index * 37) * Mathf.PI * 2f;
                    var radius = Mathf.Sqrt(Hash01(seed + index * 53 + 9));
                    candidates.Add(new Vector2(
                        Mathf.Cos(angle) * radius * 0.42f,
                        Mathf.Sin(angle) * radius * 0.49f));
                    candidateColors.Add(index % 4 == 0
                        ? new Color(0.04f, 1f, 0.82f, 0.94f)
                        : new Color(0.68f, 0.08f, 1f, 0.94f));
                }
            }

            // Keep the silhouette readable while giving the breakup enough
            // granularity to look like material disintegrating, not a few dots.
            var pointCount = FaceFragmentCount;
            faceParticleTargets = new Vector2[pointCount];
            facePointColors = new Color[pointCount];
            for (var index = 0; index < pointCount; index++)
            {
                var candidateIndex = Mathf.Clamp(Mathf.FloorToInt(
                    (index + 0.5f) * candidates.Count / pointCount),
                    0, candidates.Count - 1);
                var jitterAngle = Hash01(seed + index * 151 + 23)
                    * Mathf.PI * 2f;
                var jitterRadius = Mathf.Lerp(0.0015f, 0.0075f,
                    Hash01(seed + index * 163 + 47));
                faceParticleTargets[index] = candidates[candidateIndex]
                    + new Vector2(Mathf.Cos(jitterAngle),
                        Mathf.Sin(jitterAngle)) * jitterRadius;
                var color = candidateColors[candidateIndex];
                color = Color.Lerp(color,
                    index % 11 == 0
                        ? new Color(1f, 0.38f, 1f, 0.96f)
                        : new Color(0.03f, 0.92f, 0.90f, 0.92f),
                    index % 7 == 0 ? 0.24f : 0.07f);
                facePointColors[index] = color;
            }

            faceParticleObject = new GameObject(
                "VFX V1 · Wraith scream assembling face particles");
            faceParticleObject.transform.SetParent(transform, false);
            var filter = faceParticleObject.AddComponent<MeshFilter>();
            var renderer = faceParticleObject.AddComponent<MeshRenderer>();
            faceParticleMesh = new Mesh
            {
                name = "VFX V1 · Wraith scream face particle mesh"
            };
            faceParticleMesh.MarkDynamic();
            faceParticleVertices = new Vector3[pointCount * 4];
            faceParticleVertexColors = new Color32[pointCount * 4];
            var uvs = new Vector2[pointCount * 4];
            var triangles = new int[pointCount * 6];
            for (var index = 0; index < pointCount; index++)
            {
                var vertex = index * 4;
                uvs[vertex] = new Vector2(0f, 0f);
                uvs[vertex + 1] = new Vector2(1f, 0f);
                uvs[vertex + 2] = new Vector2(0f, 1f);
                uvs[vertex + 3] = new Vector2(1f, 1f);
                var triangle = index * 6;
                triangles[triangle] = vertex;
                triangles[triangle + 1] = vertex + 2;
                triangles[triangle + 2] = vertex + 1;
                triangles[triangle + 3] = vertex + 1;
                triangles[triangle + 4] = vertex + 2;
                triangles[triangle + 5] = vertex + 3;
            }
            faceParticleMesh.vertices = faceParticleVertices;
            faceParticleMesh.uv = uvs;
            faceParticleMesh.colors32 = faceParticleVertexColors;
            faceParticleMesh.triangles = triangles;
            filter.sharedMesh = faceParticleMesh;
            faceParticleMaterial = new Material(spriteShader)
            {
                name = "VFX V1 · Wraith scream face particle material",
                hideFlags = HideFlags.DontSave,
                renderQueue = 4220
            };
            faceParticleMaterial.SetTexture("_MainTex", particleTexture);
            faceParticleMaterial.SetColor("_Tint", Color.white);
            faceParticleMaterial.SetFloat("_Intensity", 2.15f);
            faceParticleMaterial.SetFloat("_Opacity", 1f);
            faceParticleMaterial.SetFloat("_SoftParticle", 1f);
            faceParticleMaterial.SetFloat("_PreserveSourceColor", 0f);
            renderer.sharedMaterial = faceParticleMaterial;
            renderer.shadowCastingMode = ShadowCastingMode.Off;
            renderer.receiveShadows = false;
            faceParticleObject.SetActive(false);
            ownedObjects.Add(faceParticleObject);
            ownedMeshes.Add(faceParticleMesh);
            ownedMaterials.Add(faceParticleMaterial);
        }

        void SampleFaceAssembly(in SpellSample sample, Vector3 faceCenter,
            Quaternion faceRotation, float faceScale, float sourceVisibility)
        {
            if (faceParticleObject == null || faceParticleMesh == null
                || faceParticleTargets == null)
                return;

            var time = sample.AbsoluteTime;
            var contact = ContactTime;
            var assembly = Ease(0.015f, spell.timeline.windup * 0.90f, time);
            var formationOpacity = Ease(0f, 0.035f, time)
                * (1f - Ease(spell.timeline.windup * 0.82f,
                    spell.timeline.windup + 0.11f, time));
            if (meshWraithObject != null)
                formationOpacity *= 0.18f;
            var burstWake = Ease(contact - 0.055f, contact + 0.015f, time);
            var burstFade = 1f - Ease(contact + 0.11f,
                contact + 0.37f, time);
            // The face must break on contact, not hang for a beat and then
            // dissolve. A fast displacement curve supplies the hit while
            // staggered fragment lifetimes keep the pulverised silhouette
            // readable for a few frames afterwards.
            var burst = Ease(contact - 0.028f, contact + 0.13f, time);
            var blastDistance = Mathf.Pow(burst, 0.54f);
            var fragmentAge = Mathf.Clamp01((time - (contact - 0.028f))
                / 0.36f);
            var opacity = sourceVisibility
                * Mathf.Max(formationOpacity, burstWake * burstFade);
            if (opacity <= 0.001f)
            {
                faceParticleObject.SetActive(false);
                return;
            }

            faceParticleObject.SetActive(true);
            faceParticleObject.transform.SetPositionAndRotation(
                faceCenter, faceRotation);
            var pointCount = faceParticleTargets.Length;
            for (var index = 0; index < pointCount; index++)
            {
                var target = faceParticleTargets[index] * faceScale * 1.04f;
                var startAngle = Hash01(seed + index * 47 + 3)
                    * Mathf.PI * 2f;
                var startRadius = faceScale * Mathf.Lerp(0.72f, 1.26f,
                    Hash01(seed + index * 61 + 17));
                var spiralAngle = startAngle + (1f - assembly) * 4.8f;
                var start = new Vector2(Mathf.Cos(spiralAngle),
                    Mathf.Sin(spiralAngle)) * startRadius;
                var position = Vector2.Lerp(start, target, assembly);
                var targetDirection = target.sqrMagnitude > 0.002f
                    ? target.normalized
                    : new Vector2(Mathf.Cos(startAngle), Mathf.Sin(startAngle));
                var burstDirection = Vector2.Lerp(targetDirection,
                    new Vector2(Mathf.Cos(startAngle), Mathf.Sin(startAngle)),
                    0.38f).normalized;
                var tangent = new Vector2(-burstDirection.y,
                    burstDirection.x);
                position += burstDirection * faceScale * blastDistance
                    * Mathf.Lerp(0.72f, 1.78f,
                        Hash01(seed + index * 79 + 29));
                position += tangent * faceScale * blastDistance
                    * (Hash01(seed + index * 181 + 61) - 0.5f)
                    * 0.68f;
                position += new Vector2(
                    Mathf.Sin(time * 31f + index * 1.7f),
                    Mathf.Cos(time * 27f + index * 2.1f))
                    * faceScale * 0.034f * burst;

                var size = faceScale * Mathf.Lerp(0.0038f, 0.0105f,
                    Hash01(seed + index * 97 + 41));
                if (index % 19 == 0)
                    size *= 1.65f;
                size *= Mathf.Lerp(1f, 0.72f, burst);
                var shardAngle = startAngle
                    + Mathf.Sin(index * 1.37f + time * 8.2f) * 0.34f
                    + burst * Mathf.Lerp(-2.8f, 2.8f,
                        Hash01(seed + index * 211 + 31));
                var shardRight = new Vector2(Mathf.Cos(shardAngle),
                    Mathf.Sin(shardAngle)) * size * 0.52f;
                var shardUp = new Vector2(-Mathf.Sin(shardAngle),
                    Mathf.Cos(shardAngle)) * size
                    * Mathf.Lerp(1.65f, 2.85f,
                        Hash01(seed + index * 223 + 71));
                var vertex = index * 4;
                faceParticleVertices[vertex] = new Vector3(
                    position.x - shardRight.x - shardUp.x,
                    position.y - shardRight.y - shardUp.y, 0f);
                faceParticleVertices[vertex + 1] = new Vector3(
                    position.x + shardRight.x - shardUp.x,
                    position.y + shardRight.y - shardUp.y, 0f);
                faceParticleVertices[vertex + 2] = new Vector3(
                    position.x - shardRight.x + shardUp.x,
                    position.y - shardRight.y + shardUp.y, 0f);
                faceParticleVertices[vertex + 3] = new Vector3(
                    position.x + shardRight.x + shardUp.x,
                    position.y + shardRight.y + shardUp.y, 0f);
                var color = facePointColors[index];
                var fragmentFadeStart = Mathf.Lerp(0.38f, 0.82f,
                    Hash01(seed + index * 229 + 101));
                var fragmentFade = 1f - Ease(fragmentFadeStart,
                    Mathf.Min(0.99f, fragmentFadeStart + 0.17f),
                    fragmentAge);
                color.a *= opacity * Mathf.Lerp(0.46f, 0.94f,
                    Hash01(seed + index * 109 + 7))
                    * Mathf.Lerp(1f, fragmentFade, burst);
                var packed = (Color32)color;
                faceParticleVertexColors[vertex] = packed;
                faceParticleVertexColors[vertex + 1] = packed;
                faceParticleVertexColors[vertex + 2] = packed;
                faceParticleVertexColors[vertex + 3] = packed;
            }
            faceParticleMesh.vertices = faceParticleVertices;
            faceParticleMesh.colors32 = faceParticleVertexColors;
            faceParticleMesh.RecalculateBounds();
            faceParticleMaterial.SetFloat("_Phase", time * 4.6f);
        }

        void CreatePressureVolumes()
        {
            CreateCone("VFX V1 · Wraith scream outer pressure",
                new Color(0.035f, 0.002f, 0.085f, 1f),
                new Color(0.36f, 0.012f, 0.70f, 1f),
                new Color(0.02f, 0.86f, 0.72f, 1f), 0.88f, 3480);
            CreateCone("VFX V1 · Wraith scream spectral body",
                new Color(0.055f, 0.003f, 0.12f, 1f),
                new Color(0.72f, 0.035f, 0.96f, 1f),
                new Color(0.12f, 1.0f, 0.82f, 1f), 1.08f, 3490);
            CreateCone("VFX V1 · Wraith scream compressed core",
                new Color(0.11f, 0.012f, 0.24f, 1f),
                new Color(0.94f, 0.16f, 1.0f, 1f),
                new Color(0.58f, 1.0f, 0.86f, 1f), 0.82f, 3500);
        }

        void CreateCone(string name, Color deep, Color mid, Color edge,
            float intensity, int queue)
        {
            var root = new GameObject(name);
            root.transform.SetParent(transform, false);
            var filter = root.AddComponent<MeshFilter>();
            var renderer = root.AddComponent<MeshRenderer>();
            var mesh = new Mesh { name = name + " mesh" };
            mesh.MarkDynamic();
            var vertices = new Vector3[(OrganicConeSegments + 1) * 2];
            var uvs = new Vector2[vertices.Length];
            var triangles = new int[OrganicConeSegments * 6];
            for (var segment = 0; segment <= OrganicConeSegments; segment++)
            {
                var progress = segment / (float)OrganicConeSegments;
                var vertex = segment * 2;
                uvs[vertex] = new Vector2(progress, 0f);
                uvs[vertex + 1] = new Vector2(progress, 1f);
                if (segment >= OrganicConeSegments)
                    continue;
                var triangle = segment * 6;
                triangles[triangle] = vertex;
                triangles[triangle + 1] = vertex + 1;
                triangles[triangle + 2] = vertex + 2;
                triangles[triangle + 3] = vertex + 2;
                triangles[triangle + 4] = vertex + 1;
                triangles[triangle + 5] = vertex + 3;
            }
            mesh.vertices = vertices;
            mesh.uv = uvs;
            mesh.triangles = triangles;
            filter.sharedMesh = mesh;
            var material = new Material(volumeShader)
            {
                name = name + " material",
                hideFlags = HideFlags.DontSave,
                renderQueue = queue
            };
            material.SetTexture("_MainTex", flowNoiseTexture);
            material.SetColor("_DeepColor", deep);
            material.SetColor("_MidColor", mid);
            material.SetColor("_EdgeColor", edge);
            material.SetFloat("_Intensity", intensity);
            renderer.sharedMaterial = material;
            renderer.shadowCastingMode = ShadowCastingMode.Off;
            renderer.receiveShadows = false;
            ownedObjects.Add(root);
            ownedMeshes.Add(mesh);
            ownedMaterials.Add(material);
            coneObjects.Add(root);
            coneMeshes.Add(mesh);
            coneMaterials.Add(material);
        }

        void SamplePressureVolumes(in SpellSample sample)
        {
            var time = sample.AbsoluteTime;
            var contact = ContactTime;
            var develop = Ease(spell.timeline.windup * 0.88f,
                contact - 0.055f, time);
            var fade = 1f - Ease(contact + 0.015f, contact + 0.13f, time);
            var visibility = develop * fade;
            if (visibility <= 0.001f)
            {
                SetActive(coneObjects, false);
                return;
            }

            var source = sample.Source;
            var target = Vector3.Lerp(sample.Source, sample.Target, develop);
            var scale = Mathf.Clamp(sample.Scale.x, 0.52f, 1.35f);
            UpdateCone(0, in sample, source, target,
                0.112f * scale, 0.82f * scale, 0.035f, time);
            UpdateCone(1, in sample, source, target,
                0.084f * scale, 0.60f * scale, 0.005f, time);
            UpdateCone(2, in sample, source, target,
                0.050f * scale, 0.35f * scale, -0.028f, time);

            for (var index = 0; index < coneMaterials.Count; index++)
            {
                var material = coneMaterials[index];
                material.SetFloat("_Phase", time * (2.8f + index * 0.45f)
                    + seed * 0.013f);
                material.SetFloat("_Pulse", Mathf.Clamp01(develop));
                material.SetFloat("_Opacity", visibility
                    * (index == 0 ? 0.64f : index == 1 ? 0.56f : 0.42f));
            }
        }

        void UpdateCone(int index, in SpellSample sample, Vector3 source,
            Vector3 target, float sourceWidth, float targetWidth, float depth,
            float time)
        {
            if (index < 0 || index >= coneObjects.Count)
                return;
            var root = coneObjects[index];
            root.SetActive(true);
            var camera = sample.Camera;
            var forward = camera != null
                ? camera.transform.forward
                : Vector3.forward;
            var travelAxis = target - source;
            var side = Vector3.Cross(forward, travelAxis).normalized;
            if (side.sqrMagnitude < 0.0001f)
                side = camera != null ? camera.transform.right : Vector3.right;
            var vertices = new Vector3[(OrganicConeSegments + 1) * 2];
            var phase = seed * 0.011f + index * 1.73f;
            var bendSign = index == 1 ? -1f : 1f;
            for (var segment = 0; segment <= OrganicConeSegments; segment++)
            {
                var progress = segment / (float)OrganicConeSegments;
                var body = Mathf.Sin(progress * Mathf.PI);
                var width = Mathf.Lerp(sourceWidth, targetWidth, progress);
                width *= 1f
                    + Mathf.Sin(progress * 9.7f + phase + time * 5.1f)
                        * (0.045f + progress * 0.055f)
                    + Mathf.Sin(progress * 21.3f - phase * 0.8f)
                        * 0.026f;
                var bend = body * targetWidth
                    * (0.055f + index * 0.018f) * bendSign;
                var turbulence = Mathf.Sin(progress * 7.4f + phase
                        + time * (4.4f + index * 0.35f))
                    * width * (0.075f + progress * 0.055f);
                var shear = Mathf.Sin(progress * 17.2f - phase
                        - time * 3.2f)
                    * width * 0.032f;
                var center = Vector3.Lerp(source, target, progress)
                    + side * (bend + turbulence + shear)
                    + forward * (depth
                        + Mathf.Sin(progress * 12.6f + phase)
                            * 0.012f);
                var asymmetry = Mathf.Sin(progress * 8.8f + phase * 1.4f
                        - time * 2.6f) * 0.10f
                    + (Hash01(seed + index * 71 + segment * 13) - 0.5f)
                        * 0.055f;
                var leftWidth = width * (1f + asymmetry);
                var rightWidth = width * (1f - asymmetry * 0.72f);
                var vertex = segment * 2;
                vertices[vertex] = root.transform.InverseTransformPoint(
                    center - side * leftWidth);
                vertices[vertex + 1] = root.transform.InverseTransformPoint(
                    center + side * rightWidth);
            }
            coneMeshes[index].vertices = vertices;
            coneMeshes[index].RecalculateBounds();
        }

        void CreateWaveRings()
        {
            var bandCount = SonicPulseCount * SonicEchoCount;
            var verticesPerBand = (SonicArcSegments + 1) * 2;
            sonicArcVertices = new Vector3[bandCount * verticesPerBand];
            sonicArcVertexColors = new Color32[sonicArcVertices.Length];
            var uvs = new Vector2[sonicArcVertices.Length];
            var triangles = new int[bandCount * SonicArcSegments * 6];
            for (var band = 0; band < bandCount; band++)
            {
                var baseVertex = band * verticesPerBand;
                for (var segment = 0; segment <= SonicArcSegments; segment++)
                {
                    var progress = segment / (float)SonicArcSegments;
                    var vertex = baseVertex + segment * 2;
                    uvs[vertex] = new Vector2(progress, 0f);
                    uvs[vertex + 1] = new Vector2(progress, 1f);
                }
                var baseTriangle = band * SonicArcSegments * 6;
                for (var segment = 0; segment < SonicArcSegments; segment++)
                {
                    var vertex = baseVertex + segment * 2;
                    var triangle = baseTriangle + segment * 6;
                    triangles[triangle] = vertex;
                    triangles[triangle + 1] = vertex + 1;
                    triangles[triangle + 2] = vertex + 2;
                    triangles[triangle + 3] = vertex + 2;
                    triangles[triangle + 4] = vertex + 1;
                    triangles[triangle + 5] = vertex + 3;
                }
            }

            sonicArcObject = new GameObject(
                "VFX V1 · Wraith scream organic perspective wave rings");
            sonicArcObject.transform.SetParent(transform, false);
            var filter = sonicArcObject.AddComponent<MeshFilter>();
            var renderer = sonicArcObject.AddComponent<MeshRenderer>();
            sonicArcMesh = new Mesh
            {
                name = "VFX V1 · Wraith scream acoustic arc mesh"
            };
            sonicArcMesh.MarkDynamic();
            sonicArcMesh.vertices = sonicArcVertices;
            sonicArcMesh.uv = uvs;
            sonicArcMesh.colors32 = sonicArcVertexColors;
            sonicArcMesh.triangles = triangles;
            filter.sharedMesh = sonicArcMesh;
            sonicArcMaterial = new Material(waveShader)
            {
                name = "VFX V1 · Wraith scream acoustic arc material",
                hideFlags = HideFlags.DontSave,
                renderQueue = 3580
            };
            sonicArcMaterial.SetTexture("_MainTex", sonicPressureTexture);
            sonicArcMaterial.SetTexture("_FlowTex", sonicFlowTexture);
            sonicArcMaterial.SetTexture("_FilamentTex", sonicFilamentTexture);
            sonicArcMaterial.SetFloat("_Intensity", 1.62f);
            sonicArcMaterial.SetFloat("_Opacity", 1f);
            renderer.sharedMaterial = sonicArcMaterial;
            renderer.shadowCastingMode = ShadowCastingMode.Off;
            renderer.receiveShadows = false;
            sonicArcObject.SetActive(false);
            ownedObjects.Add(sonicArcObject);
            ownedMeshes.Add(sonicArcMesh);
            ownedMaterials.Add(sonicArcMaterial);
        }

        void SampleWaveRings(in SpellSample sample)
        {
            if (sonicArcObject == null || sonicArcMesh == null)
                return;
            var time = sample.AbsoluteTime;
            var contact = ContactTime;
            var axis = TravelAxis(in sample);
            var cameraForward = sample.Camera != null
                ? sample.Camera.transform.forward
                : Vector3.forward;
            axis = Vector3.ProjectOnPlane(axis, cameraForward).normalized;
            if (axis.sqrMagnitude < 0.0001f)
                axis = Vector3.down;
            var side = Vector3.Cross(cameraForward, axis).normalized;
            if (side.sqrMagnitude < 0.0001f)
                side = sample.Camera != null
                    ? sample.Camera.transform.right
                    : Vector3.right;
            var forward = sample.Camera != null
                ? -sample.Camera.transform.forward
                : Vector3.back;
            var distance = Vector3.Distance(sample.Source, sample.Target);
            var scale = Mathf.Clamp(sample.Scale.x, 0.58f, 1.30f);
            var emissionStart = spell.timeline.windup * 0.86f;
            var globalFade = 1f - Ease(contact + 0.015f,
                contact + 0.13f, time);
            var verticesPerBand = (SonicArcSegments + 1) * 2;
            var hasVisibleBand = false;

            for (var pulse = 0; pulse < SonicPulseCount; pulse++)
            {
                for (var echo = 0; echo < SonicEchoCount; echo++)
                {
                    var band = pulse * SonicEchoCount + echo;
                    var baseVertex = band * verticesPerBand;
                    var pulseJitter = (Hash01(seed + pulse * 43 + 11) - 0.5f)
                        * 0.024f;
                    // Echoes are material strata on the same pressure ring,
                    // not separately spaced chevrons.
                    var start = emissionStart + pulse * 0.105f
                        + echo * 0.0045f + pulseJitter;
                    var lifetime = 0.49f
                        + Hash01(seed + pulse * 59 + echo * 17) * 0.055f;
                    var age = time - start;
                    var progress = Mathf.Clamp01(age / lifetime);
                    var fadeIn = Ease(0f, 0.035f, age);
                    var fadeOut = 1f - Ease(lifetime - 0.18f,
                        lifetime, age);
                    var opacity = age >= 0f && age <= lifetime
                        ? fadeIn * fadeOut * globalFade
                        : 0f;
                    if (opacity > 0.001f)
                        hasVisibleBand = true;

                    var expansion = 1f - Mathf.Pow(1f - progress, 2.10f);
                    var ringBreath = 1f + Mathf.Sin(time * 13.4f
                            + pulse * 1.91f + seed * 0.007f)
                        * Mathf.Lerp(0.018f, 0.045f, expansion);
                    var finalMajorRadius = Mathf.Clamp(distance * 0.86f,
                        0.72f, 1.12f) * scale;
                    var layerRadiusOffset = scale * (echo == 0
                        ? 0.020f
                        : echo == 1 ? 0f
                        : echo == 2 ? -0.018f : 0.034f);
                    var majorRadius = (Mathf.Lerp(0.085f * scale,
                            finalMajorRadius, expansion)
                        + layerRadiusOffset) * ringBreath;
                    var perspectiveRatio = Mathf.Lerp(0.88f, 0.67f,
                        expansion);
                    var minorRadius = majorRadius * perspectiveRatio;
                    // Like the user's sketch, each expanding ellipse keeps its
                    // upper lip close to the mouth while its centre travels
                    // toward the target, producing nested perspective rings.
                    var center = sample.Source
                        + axis * (minorRadius * 0.82f
                            + distance * expansion * 0.09f)
                        + side * Mathf.Sin(time * 7.2f + pulse * 1.57f)
                            * majorRadius * 0.035f
                        + side * (Hash01(seed + pulse * 67 + 19) - 0.5f)
                            * majorRadius * 0.055f
                        + forward * (0.105f + echo * 0.014f);
                    var thickness = scale * (echo == 0
                        ? 0.070f
                        : echo == 1 ? 0.030f
                        : echo == 2 ? 0.020f : 0.012f)
                        * Mathf.Lerp(0.76f, 1.20f, expansion);
                    var color = echo == 0
                        ? Color.Lerp(
                            new Color(0.38f, 0.018f, 0.64f, 1f),
                            new Color(0.13f, 0.018f, 0.34f, 1f),
                            progress)
                        : echo == 1
                            ? Color.Lerp(
                                new Color(0.98f, 0.30f, 1f, 1f),
                                new Color(0.62f, 0.06f, 0.98f, 1f),
                                progress)
                            : echo == 2
                                ? Color.Lerp(
                                    new Color(0.56f, 1f, 0.94f, 1f),
                                    new Color(0.02f, 0.82f, 0.78f, 1f),
                                    progress)
                                : Color.Lerp(
                                    new Color(1f, 0.70f, 1f, 1f),
                                    new Color(0.32f, 0.72f, 1f, 1f),
                                    progress);
                    color.a = opacity * (echo == 0
                        ? 0.52f
                        : echo == 1 ? 0.88f
                        : echo == 2 ? 0.62f : 0.52f);
                    for (var segment = 0; segment <= SonicArcSegments; segment++)
                    {
                        var arcProgress = segment / (float)SonicArcSegments;
                        // Start the seam at the upper lip beside the mouth. The
                        // tiny faded gap and animated radial wobble prevent a
                        // mathematically perfect UI-circle appearance.
                        var angle = -Mathf.PI * 0.5f
                            + arcProgress * Mathf.PI * 2f;
                        angle += Mathf.Sin(arcProgress * Mathf.PI * 4f
                                + pulse * 1.37f - time * 3.8f)
                            * 0.018f;
                        var cosine = Mathf.Cos(angle);
                        var sine = Mathf.Sin(angle);
                        var radialWobble = 1f
                            + Mathf.Sin(angle * 3f + pulse * 1.41f
                                + time * 7.6f) * 0.052f
                            + Mathf.Sin(angle * 7f - pulse * 0.83f
                                - time * 4.9f) * 0.024f
                            + (Hash01(seed + pulse * 307 + segment * 17)
                                - 0.5f) * 0.018f;
                        var leftRightSkew = 1f + cosine
                            * (Hash01(seed + pulse * 149 + 31) - 0.5f)
                            * 0.11f;
                        var verticalWobble = 1f
                            + Mathf.Sin(angle * 5f + pulse * 0.97f
                                + time * 5.7f) * 0.040f;
                        var point = center
                            + side * (cosine * majorRadius * radialWobble
                                * leftRightSkew)
                            + axis * (sine * minorRadius * radialWobble
                                * verticalWobble)
                            + forward * Mathf.Sin(angle * 2f + time * 4.1f)
                                * 0.012f;
                        var radialNormal = (side * (cosine
                                / Mathf.Max(0.02f, majorRadius))
                            + axis * (sine
                                / Mathf.Max(0.02f, minorRadius))).normalized;
                        var localThickness = thickness * (0.84f
                            + 0.16f * Mathf.Sin(angle * 4f
                                + pulse * 1.17f - time * 6.2f));
                        var inner = point - radialNormal * localThickness;
                        var outer = point + radialNormal * localThickness;
                        var vertex = baseVertex + segment * 2;
                        sonicArcVertices[vertex] = sonicArcObject.transform
                            .InverseTransformPoint(inner);
                        sonicArcVertices[vertex + 1] = sonicArcObject.transform
                            .InverseTransformPoint(outer);
                        var segmentColor = color;
                        var fractureSignal = Mathf.Sin(arcProgress
                                * (18.6f + echo * 3.7f)
                                + pulse * 2.13f + echo * 1.17f
                                - time * (7.6f + echo))
                            + Mathf.Sin(arcProgress * 43.1f
                                - pulse * 0.91f) * 0.34f;
                        // The broad and hot strata stay readable; cold and
                        // filament strata break more heavily around the rim.
                        var tornMask = echo == 0
                            ? 0.56f + 0.44f * Ease(-0.62f, 0.42f,
                                fractureSignal)
                            : echo == 1
                                ? 0.48f + 0.52f * Ease(-0.58f, 0.46f,
                                    fractureSignal)
                                : 0.14f + 0.86f * Ease(-0.30f, 0.58f,
                                    fractureSignal);
                        var depthShade = Mathf.Lerp(0.72f, 1f,
                            Mathf.Clamp01(sine * 0.5f + 0.5f));
                        tornMask *= depthShade;
                        segmentColor.a *= tornMask;
                        var packed = (Color32)segmentColor;
                        sonicArcVertexColors[vertex] = packed;
                        sonicArcVertexColors[vertex + 1] = packed;
                    }
                }
            }
            sonicArcObject.SetActive(hasVisibleBand);
            if (!hasVisibleBand)
                return;
            sonicArcMesh.vertices = sonicArcVertices;
            sonicArcMesh.colors32 = sonicArcVertexColors;
            sonicArcMesh.RecalculateBounds();
            sonicArcMaterial.SetFloat("_Phase", time * 3.8f);
        }

        void CreateImpactBack()
        {
            impactCards.Add(CreateCard(
                "VFX V1 · Wraith scream impact mist",
                smokeTexture,
                new Color(0.22f, 0.018f, 0.48f, 0.52f),
                1.25f,
                3340,
                false,
                impactMaterials));
            impactCards.Add(CreateCard(
                "VFX V1 · Wraith scream offset cold mist",
                smokeTexture,
                new Color(0.025f, 0.58f, 0.53f, 0.38f),
                1.18f,
                3350,
                false,
                impactMaterials));
        }

        void CreateImpactFront()
        {
            impactCards.Add(CreateCard(
                "VFX V1 · Wraith scream contact flash",
                glowTexture,
                new Color(0.62f, 0.08f, 1f, 0.90f),
                2.1f,
                4380,
                false,
                impactMaterials));
            CreateImpactPressureArcs();
            impactParticles = CreateParticles(
                "VFX V1 · Wraith scream pressure residue particles",
                impactParticleTexture,
                4410,
                512,
                new Color(0.66f, 0.06f, 1f, 1f),
                1.78f,
                true);
            echoParticles = CreateParticles(
                "VFX V1 · Wraith scream residual mist",
                smokeTexture,
                4370,
                256,
                new Color(0.04f, 0.82f, 0.70f, 0.62f),
                1.35f,
                false);
        }

        void CreateImpactPressureArcs()
        {
            var verticesPerArc = (ImpactArcSegments + 1) * 2;
            impactArcVertices = new Vector3[ImpactArcCount * verticesPerArc];
            impactArcVertexColors = new Color32[impactArcVertices.Length];
            var uvs = new Vector2[impactArcVertices.Length];
            var triangles = new int[ImpactArcCount * ImpactArcSegments * 6];
            for (var arc = 0; arc < ImpactArcCount; arc++)
            {
                var baseVertex = arc * verticesPerArc;
                for (var segment = 0; segment <= ImpactArcSegments; segment++)
                {
                    var progress = segment / (float)ImpactArcSegments;
                    var vertex = baseVertex + segment * 2;
                    uvs[vertex] = new Vector2(progress, 0f);
                    uvs[vertex + 1] = new Vector2(progress, 1f);
                }
                var baseTriangle = arc * ImpactArcSegments * 6;
                for (var segment = 0; segment < ImpactArcSegments; segment++)
                {
                    var vertex = baseVertex + segment * 2;
                    var triangle = baseTriangle + segment * 6;
                    triangles[triangle] = vertex;
                    triangles[triangle + 1] = vertex + 1;
                    triangles[triangle + 2] = vertex + 2;
                    triangles[triangle + 3] = vertex + 2;
                    triangles[triangle + 4] = vertex + 1;
                    triangles[triangle + 5] = vertex + 3;
                }
            }

            impactArcObject = new GameObject(
                "VFX V1 · Wraith scream torn asymmetric impact wavefronts");
            impactArcObject.transform.SetParent(transform, false);
            var filter = impactArcObject.AddComponent<MeshFilter>();
            var renderer = impactArcObject.AddComponent<MeshRenderer>();
            impactArcMesh = new Mesh
            {
                name = "VFX V1 · Wraith scream torn impact arc mesh"
            };
            impactArcMesh.MarkDynamic();
            impactArcMesh.vertices = impactArcVertices;
            impactArcMesh.uv = uvs;
            impactArcMesh.colors32 = impactArcVertexColors;
            impactArcMesh.triangles = triangles;
            filter.sharedMesh = impactArcMesh;
            impactArcMaterial = new Material(waveShader)
            {
                name = "VFX V1 · Wraith scream torn impact arc material",
                hideFlags = HideFlags.DontSave,
                renderQueue = 4400
            };
            impactArcMaterial.SetTexture("_MainTex", sonicPressureTexture);
            impactArcMaterial.SetTexture("_FlowTex", sonicFlowTexture);
            impactArcMaterial.SetTexture("_FilamentTex", sonicFilamentTexture);
            impactArcMaterial.SetFloat("_Intensity", 1.82f);
            impactArcMaterial.SetFloat("_Opacity", 1f);
            renderer.sharedMaterial = impactArcMaterial;
            renderer.shadowCastingMode = ShadowCastingMode.Off;
            renderer.receiveShadows = false;
            impactArcObject.SetActive(false);
            ownedObjects.Add(impactArcObject);
            ownedMeshes.Add(impactArcMesh);
            ownedMaterials.Add(impactArcMaterial);
        }

        void SampleImpactBack(in SpellSample sample)
        {
            var age = sample.AbsoluteTime - ContactTime;
            var release = Ease(-0.025f, 0.13f, age);
            var fade = 1f - Ease(0.13f, 0.42f, age);
            if (age < -0.08f || fade <= 0.001f)
            {
                SetActive(impactCards, false);
                return;
            }
            var camera = sample.Camera;
            var back = camera != null ? camera.transform.forward * 0.13f : Vector3.forward * 0.13f;
            var cameraRight = camera != null
                ? camera.transform.right
                : Vector3.right;
            var cameraUp = camera != null
                ? camera.transform.up
                : Vector3.up;
            var position = sample.Target + back;
            var scale = Mathf.Lerp(0.16f, 1.10f, release)
                * Mathf.Clamp(sample.Scale.x, 0.55f, 1.35f);
            SetCard(impactCards[0], impactMaterials[0], position,
                BillboardRotation(camera, 17f + sample.AbsoluteTime * 26f),
                new Vector3(scale * 1.46f, scale * 1.06f, 1f),
                fade * Mathf.Lerp(0.18f, 0.52f, release),
                sample.AbsoluteTime * 2.8f);
            SetCard(impactCards[1], impactMaterials[1],
                position + cameraRight * scale * 0.11f
                    - cameraUp * scale * 0.07f,
                BillboardRotation(camera, -31f - sample.AbsoluteTime * 19f),
                new Vector3(scale * 1.18f, scale * 0.84f, 1f),
                fade * Mathf.Lerp(0.12f, 0.38f, release),
                sample.AbsoluteTime * 4.1f);
        }

        void SampleImpactFront(in SpellSample sample)
        {
            var age = sample.AbsoluteTime - ContactTime;
            var compression = Ease(-0.075f, 0f, age);
            var flashFade = 1f - Ease(0.015f, 0.12f, age);
            var tailFade = 1f - Ease(0.30f, 0.48f, age);
            if (age < -0.08f || tailFade <= 0.001f)
            {
                SetActive(impactCards, false);
                if (impactArcObject != null)
                    impactArcObject.SetActive(false);
                RestoreCameraShake();
                return;
            }

            var camera = sample.Camera;
            var front = camera != null ? -camera.transform.forward * 0.14f : Vector3.back * 0.14f;
            var position = sample.Target + front;
            var scale = Mathf.Clamp(sample.Scale.x, 0.56f, 1.38f);
            SetCard(impactCards[0], impactMaterials[0], position,
                BillboardRotation(camera, -12f),
                new Vector3(scale * 0.31f, scale * 0.45f, 1f),
                flashFade
                    * Mathf.Lerp(0.45f, 1f, compression),
                sample.AbsoluteTime * 7.6f);
            SampleImpactPressureArcs(in sample, age,
                position + front * 0.04f, scale);

            ApplyCameraShake(in sample, age);
            if (!impactEmitted && age >= 0f && sample.AdvanceSimulation)
            {
                impactEmitted = true;
                EmitImpactBurst(in sample);
            }
        }

        void SampleImpactPressureArcs(in SpellSample sample, float age,
            Vector3 position, float scale)
        {
            if (impactArcObject == null || impactArcMesh == null
                || impactArcVertices == null)
                return;

            var camera = sample.Camera;
            var right = camera != null ? camera.transform.right : Vector3.right;
            var up = camera != null ? camera.transform.up : Vector3.up;
            var towardsCamera = camera != null
                ? -camera.transform.forward
                : Vector3.back;
            var incoming = sample.Target - sample.Source;
            var incomingAngle = Mathf.Atan2(
                Vector3.Dot(incoming, up),
                Vector3.Dot(incoming, right));
            var verticesPerArc = (ImpactArcSegments + 1) * 2;
            var hasVisibleArc = false;

            for (var arc = 0; arc < ImpactArcCount; arc++)
            {
                var arcDelay = -0.025f + arc * 0.014f
                    + (Hash01(seed + arc * 31 + 7) - 0.5f) * 0.018f;
                var localAge = age - arcDelay;
                var release = Ease(-0.030f, 0.145f, localAge);
                var fade = 1f - Ease(0.16f + arc * 0.010f,
                    0.36f + arc * 0.014f, localAge);
                var visibility = localAge >= -0.055f
                    ? Ease(-0.055f, -0.005f, localAge) * fade
                    : 0f;
                if (visibility > 0.001f)
                    hasVisibleArc = true;

                var span = Mathf.Lerp(0.62f, 1.68f,
                    Hash01(seed + arc * 83 + 29));
                var orderedOffset = (arc - (ImpactArcCount - 1) * 0.5f)
                    * 0.11f;
                var fanOffset = Mathf.Lerp(-1.04f, 0.94f,
                        Hash01(seed + arc * 71 + 13))
                    + orderedOffset;
                var midAngle = incomingAngle + Mathf.PI + fanOffset;
                var startAngle = midAngle - span * 0.5f;
                var spin = release * (arc % 2 == 0 ? 0.24f : -0.31f);
                var radius = Mathf.Lerp(
                        Mathf.Lerp(0.075f, 0.16f,
                            Hash01(seed + arc * 37 + 3)),
                        Mathf.Lerp(0.60f, 0.94f,
                            Hash01(seed + arc * 47 + 41)),
                        release)
                    * scale;
                var offsetX = (Hash01(seed + arc * 97 + 17) - 0.5f)
                    * scale * Mathf.Lerp(0.06f, 0.20f, release);
                var offsetY = (Hash01(seed + arc * 103 + 53) - 0.5f)
                    * scale * Mathf.Lerp(0.05f, 0.17f, release);
                var arcCenter = position + right * offsetX + up * offsetY
                    + towardsCamera * (0.012f * arc);
                var baseVertex = arc * verticesPerArc;
                var arcColor = arc % 3 == 0
                    ? new Color(0.96f, 0.16f, 1f, 1f)
                    : arc % 3 == 1
                        ? new Color(0.055f, 0.92f, 0.80f, 1f)
                        : new Color(0.42f, 0.025f, 0.86f, 1f);

                for (var segment = 0; segment <= ImpactArcSegments; segment++)
                {
                    var progress = segment / (float)ImpactArcSegments;
                    var angle = startAngle + span * progress + spin;
                    angle += Mathf.Sin(progress * Mathf.PI * 2.7f
                            + arc * 1.37f + sample.AbsoluteTime * 4.2f)
                        * 0.075f;
                    var radialNoise = 1f
                        + Mathf.Sin(progress * 8.7f + arc * 1.91f
                            - sample.AbsoluteTime * 5.3f) * 0.085f
                        + Mathf.Sin(progress * 19.4f - arc * 0.63f) * 0.035f;
                    var normal = right * Mathf.Cos(angle)
                        + up * Mathf.Sin(angle);
                    var tangent = -right * Mathf.Sin(angle)
                        + up * Mathf.Cos(angle);
                    var point = arcCenter + normal * radius * radialNoise;
                    point += tangent * Mathf.Sin(progress * 12.3f
                            + arc * 0.88f + sample.AbsoluteTime * 7.1f)
                        * radius * 0.035f;
                    var halfThickness = scale
                        * Mathf.Lerp(0.018f, 0.052f,
                            Hash01(seed + arc * 109 + 61))
                        * Mathf.Lerp(0.72f, 1.14f,
                            0.5f + 0.5f * Mathf.Sin(progress * 10.1f
                                + arc * 1.51f));
                    var vertex = baseVertex + segment * 2;
                    impactArcVertices[vertex] = impactArcObject.transform
                        .InverseTransformPoint(point - normal * halfThickness);
                    impactArcVertices[vertex + 1] = impactArcObject.transform
                        .InverseTransformPoint(point + normal * halfThickness);

                    var endpointTaper = Ease(0f, 0.13f, progress)
                        * (1f - Ease(0.87f, 1f, progress));
                    var fractureNoise = Mathf.Sin(progress
                            * Mathf.Lerp(10.2f, 18.6f,
                                Hash01(seed + arc * 127 + 19))
                            + arc * 2.07f - sample.AbsoluteTime * 8.5f)
                        + Mathf.Sin(progress * 27.4f + arc * 0.73f) * 0.42f;
                    var brokenPulse = Ease(-0.18f, 0.48f, fractureNoise);
                    var color = arcColor;
                    color.a = visibility * endpointTaper * brokenPulse
                        * (arc % 3 == 1 ? 0.70f : 0.82f);
                    var packed = (Color32)color;
                    impactArcVertexColors[vertex] = packed;
                    impactArcVertexColors[vertex + 1] = packed;
                }
            }

            impactArcObject.SetActive(hasVisibleArc);
            if (!hasVisibleArc)
                return;
            impactArcMesh.vertices = impactArcVertices;
            impactArcMesh.colors32 = impactArcVertexColors;
            impactArcMesh.RecalculateBounds();
            impactArcMaterial.SetFloat("_Phase",
                sample.AbsoluteTime * 5.9f + seed * 0.009f);
        }

        void EmitImpactBurst(in SpellSample sample)
        {
            var camera = sample.Camera;
            var right = camera != null ? camera.transform.right : Vector3.right;
            var up = camera != null ? camera.transform.up : Vector3.up;
            var forward = camera != null ? camera.transform.forward : Vector3.forward;
            var incoming = (sample.Target - sample.Source).normalized;
            var scale = Mathf.Clamp(sample.Scale.x, 0.58f, 1.35f);
            // Ten times the former fragment count, but at a much smaller
            // per-fragment size so the release reads as pulverisation rather
            // than a field of large floating dots.
            for (var index = 0; index < 180; index++)
            {
                var a = Hash01(index * 5 + seed);
                var b = Hash01(index * 11 + seed + 31);
                var c = Hash01(index * 17 + seed + 73);
                var d = Hash01(index * 23 + seed + 107);
                var angle = a * Mathf.PI * 2f
                    + Mathf.Sin(a * Mathf.PI * 10f + seed * 0.017f) * 0.22f;
                var radial = right * Mathf.Cos(angle)
                    + up * Mathf.Sin(angle) * Mathf.Lerp(0.62f, 1.12f, b);
                var direction = (radial * Mathf.Lerp(0.78f, 1.34f, a)
                    + incoming * Mathf.Lerp(0.10f, 0.72f, c)
                    + forward * Mathf.Lerp(-0.48f, 0.48f, d)).normalized;
                var color = index % 11 == 0
                    ? new Color(0.74f, 0.94f, 1f, 0.96f)
                    : index % 7 == 0
                        ? new Color(0.03f, 1f, 0.82f, 0.92f)
                        : index % 3 == 0
                            ? new Color(1f, 0.12f, 0.90f, 0.98f)
                            : new Color(0.48f, 0.018f, 0.94f, 0.90f);
                var particleSize = scale * Mathf.Lerp(0.0055f, 0.020f, c);
                if (index % 29 == 0)
                    particleSize *= 2.1f;
                EmitParticle(impactParticles,
                    sample.Target + direction * scale
                        * Mathf.Lerp(0.012f, 0.070f, d),
                    direction * scale * Mathf.Lerp(0.72f, 1.92f, c),
                    Mathf.Lerp(0.16f, 0.43f, b),
                    particleSize,
                    color);
            }
            for (var index = 0; index < 36; index++)
            {
                var a = Hash01(index * 19 + seed + 17);
                var b = Hash01(index * 29 + seed + 41);
                var c = Hash01(index * 43 + seed + 83);
                var angle = a * Mathf.PI * 2f;
                var direction = (right * Mathf.Cos(angle)
                    + up * Mathf.Sin(angle) * Mathf.Lerp(0.56f, 0.94f, c)
                    + incoming * Mathf.Lerp(0.08f, 0.34f, b)
                    + forward * Mathf.Lerp(-0.24f, 0.24f, b)).normalized;
                EmitParticle(echoParticles,
                    sample.Target + direction * scale
                        * Mathf.Lerp(0.018f, 0.075f, c),
                    direction * scale * Mathf.Lerp(0.24f, 0.68f, b),
                    Mathf.Lerp(0.22f, 0.48f, a),
                    scale * Mathf.Lerp(0.028f, 0.090f, b),
                    index % 4 == 0
                        ? new Color(0.17f, 0.72f, 0.74f, 0.30f)
                        : new Color(0.22f, 0.035f, 0.48f, 0.25f));
            }
        }

        GameObject CreateCard(string name, Texture2D texture, Color tint,
            float intensity, int queue, bool cropHead, List<Material> materialList)
        {
            var card = GameObject.CreatePrimitive(PrimitiveType.Quad);
            card.name = name;
            card.transform.SetParent(transform, false);
            var collider = card.GetComponent<Collider>();
            if (collider != null)
                Destroy(collider);
            var renderer = card.GetComponent<MeshRenderer>();
            var material = new Material(spriteShader)
            {
                name = name + " material",
                hideFlags = HideFlags.DontSave,
                renderQueue = queue
            };
            material.SetTexture("_MainTex", texture);
            material.SetColor("_Tint", tint);
            material.SetFloat("_Intensity", intensity);
            material.SetFloat("_CropHead", cropHead ? 1f : 0f);
            material.SetFloat("_SoftParticle", 0f);
            material.SetFloat("_PreserveSourceColor",
                texture == ghostFaceTexture ? 1f : 0f);
            renderer.sharedMaterial = material;
            renderer.shadowCastingMode = ShadowCastingMode.Off;
            renderer.receiveShadows = false;
            card.SetActive(false);
            ownedObjects.Add(card);
            ownedMaterials.Add(material);
            materialList.Add(material);
            return card;
        }

        void SetCard(GameObject card, Material material, Vector3 position,
            Quaternion rotation, Vector3 scale, float opacity, float phase)
        {
            if (card == null || material == null)
                return;
            card.SetActive(opacity > 0.001f);
            card.transform.SetPositionAndRotation(position, rotation);
            card.transform.localScale = scale;
            material.SetFloat("_Opacity", Mathf.Clamp01(opacity));
            material.SetFloat("_Phase", phase);
        }

        ParticleSystem CreateParticles(string name, Texture2D texture,
            int sortingOrder, int maxParticles, Color tint, float intensity,
            bool stretched)
        {
            var root = new GameObject(name);
            root.transform.SetParent(transform, false);
            var system = root.AddComponent<ParticleSystem>();
            var main = system.main;
            main.loop = false;
            main.playOnAwake = false;
            main.simulationSpace = ParticleSystemSimulationSpace.World;
            main.maxParticles = maxParticles;
            main.startLifetime = 0.5f;
            main.startSpeed = 0f;
            main.startSize = 0.08f;
            main.startColor = Color.white;
            var emission = system.emission;
            emission.enabled = false;
            var renderer = system.GetComponent<ParticleSystemRenderer>();
            var material = new Material(spriteShader)
            {
                name = name + " material",
                hideFlags = HideFlags.DontSave,
                renderQueue = sortingOrder
            };
            material.SetTexture("_MainTex", texture);
            material.SetColor("_Tint", tint);
            material.SetFloat("_Intensity", intensity);
            material.SetFloat("_Opacity", 1f);
            material.SetFloat("_SoftParticle", 1f);
            renderer.sharedMaterial = material;
            renderer.sortingOrder = sortingOrder;
            renderer.renderMode = stretched
                ? ParticleSystemRenderMode.Stretch
                : ParticleSystemRenderMode.Billboard;
            renderer.velocityScale = stretched ? 0.14f : 0f;
            renderer.lengthScale = stretched ? 1.7f : 1f;
            renderer.cameraVelocityScale = 0f;
            renderer.shadowCastingMode = ShadowCastingMode.Off;
            renderer.receiveShadows = false;
            system.useAutoRandomSeed = false;
            system.randomSeed = unchecked((uint)seed);
            ownedObjects.Add(root);
            ownedMaterials.Add(material);
            return system;
        }

        static void EmitParticle(ParticleSystem system, Vector3 position,
            Vector3 velocity, float lifetime, float size, Color color)
        {
            if (system == null)
                return;
            var parameters = new ParticleSystem.EmitParams
            {
                position = position,
                velocity = velocity,
                startLifetime = lifetime,
                startSize = size,
                startColor = color
            };
            system.Emit(parameters, 1);
        }

        void ApplyCameraShake(in SpellSample sample, float age)
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
            var envelope = Ease(0f, 0.035f, age)
                * (1f - Ease(0.11f, 0.23f, age));
            if (envelope <= 0.001f)
                return;
            var localOffset = new Vector3(
                Mathf.Sin(age * 210f + seed) * 0.034f * envelope,
                Mathf.Cos(age * 247f + seed * 0.37f) * 0.027f * envelope,
                0f);
            var roll = Mathf.Sin(age * 181f + seed) * 1.42f * envelope;
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
                shakeBasePosition, shakeBaseRotation);
        }

        Vector3 TravelAxis(in SpellSample sample)
        {
            var axis = sample.Target - sample.Source;
            return axis.sqrMagnitude > 0.0001f ? axis.normalized : Vector3.down;
        }

        static Quaternion BillboardRotation(Camera camera, float roll)
        {
            if (camera == null)
                return Quaternion.Euler(0f, 0f, roll);
            return Quaternion.LookRotation(-camera.transform.forward,
                camera.transform.up)
                * Quaternion.AngleAxis(roll, Vector3.forward);
        }

        static float ScreenAxisAngle(Vector3 axis, Camera camera)
        {
            if (camera == null)
                return Mathf.Atan2(axis.y, axis.x) * Mathf.Rad2Deg;
            var horizontal = Vector3.Dot(axis, camera.transform.right);
            var vertical = Vector3.Dot(axis, camera.transform.up);
            return Mathf.Atan2(vertical, horizontal) * Mathf.Rad2Deg;
        }

        static void SetActive(List<GameObject> objects, bool active)
        {
            for (var index = 0; index < objects.Count; index++)
                if (objects[index] != null)
                    objects[index].SetActive(active);
        }

        static float Ease(float start, float end, float value)
        {
            if (end <= start + 0.0001f)
                return value >= end ? 1f : 0f;
            return Mathf.SmoothStep(0f, 1f,
                Mathf.Clamp01((value - start) / (end - start)));
        }

        static float Hash01(int value)
        {
            return Mathf.Repeat(Mathf.Sin(value * 12.9898f) * 43758.5453f, 1f);
        }

        float ContactTime => spell != null && spell.timeline != null
            ? spell.timeline.windup + spell.timeline.travel
            : 0.78f;

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
            if (impactParticles != null)
                impactParticles.Stop(true,
                    ParticleSystemStopBehavior.StopEmittingAndClear);
            if (echoParticles != null)
                echoParticles.Stop(true,
                    ParticleSystemStopBehavior.StopEmittingAndClear);
            for (var index = 0; index < ownedObjects.Count; index++)
                if (ownedObjects[index] != null)
                    SpellBackends.DestroyOwned(ownedObjects[index]);
            for (var index = 0; index < ownedMaterials.Count; index++)
                if (ownedMaterials[index] != null)
                    SpellBackends.DestroyOwned(ownedMaterials[index]);
            for (var index = 0; index < ownedMeshes.Count; index++)
                if (ownedMeshes[index] != null)
                    SpellBackends.DestroyOwned(ownedMeshes[index]);
            ownedObjects.Clear();
            ownedMaterials.Clear();
            ownedMeshes.Clear();
            sourceCards.Clear();
            sourceMaterials.Clear();
            coneObjects.Clear();
            coneMeshes.Clear();
            coneMaterials.Clear();
            impactCards.Clear();
            impactMaterials.Clear();
            faceParticleObject = null;
            faceParticleMesh = null;
            faceParticleMaterial = null;
            faceParticleTargets = null;
            facePointColors = null;
            faceParticleVertices = null;
            faceParticleVertexColors = null;
            meshWraithObject = null;
            meshWraithRenderers.Clear();
            meshWraithMaterials.Clear();
            sonicArcObject = null;
            sonicArcMesh = null;
            sonicArcMaterial = null;
            sonicArcVertices = null;
            sonicArcVertexColors = null;
            impactArcObject = null;
            impactArcMesh = null;
            impactArcMaterial = null;
            impactArcVertices = null;
            impactArcVertexColors = null;
        }
    }
}
