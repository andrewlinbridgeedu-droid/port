using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace Mindstone.VFXV1
{
    /// <summary>
    /// A spell-private Unity translation of the Three.js-style pattern:
    /// procedural noisy fire volume, deterministic GPU-like particles, and a
    /// short impact impulse. The Phoenix spell is intentionally untouched.
    /// </summary>
    public sealed class EmberCometSpellExtension : MonoBehaviour, ISpellExtension
    {
        const string VolumeShaderResource =
            "Mindstone/VFXV1/Spells/projectile-ember-comet-v1/EmberVolume";
        const string ParticleShaderResource =
            "Mindstone/VFXV1/Spells/projectile-ember-comet-v1/EmberParticle";
        const string FlameCardShaderResource =
            "Mindstone/VFXV1/Spells/projectile-ember-comet-v1/EmberFlameCard";

        SpellSpec spell;
        SpellLayerSpec layer;
        int seed;
        bool released;
        bool impactEmitted;

        GameObject volumeObject;
        Renderer volumeRenderer;
        Material volumeMaterial;
        TrailRenderer trail;
        Material trailMaterial;
        ParticleSystem particles;
        Material particleMaterial;
        readonly List<GameObject> flameCards = new();
        readonly List<Material> flameCardMaterials = new();
        Shader flameCardShader;

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

            var volumeShader = Resources.Load<Shader>(VolumeShaderResource)
                ?? Shader.Find("Mindstone/VFXV1/Ember Volume");
            var particleShader = Resources.Load<Shader>(ParticleShaderResource)
                ?? Shader.Find("Mindstone/VFXV1/Ember Particle")
                ?? Shader.Find("Particles/Standard Unlit");
            flameCardShader = Resources.Load<Shader>(FlameCardShaderResource)
                ?? Shader.Find("Mindstone/VFXV1/Ember Flame Card");
            if (volumeShader == null || particleShader == null)
            {
                Debug.LogError("[VFX V1] Ember comet shader stack is incomplete.");
                return;
            }

            switch (layer.role)
            {
                case "core":
                    CreateFlameCard("VFX V1 · Ember comet body", flameCardShader, false);
                    CreateFlameCard("VFX V1 · Ember comet cross flame", flameCardShader, false);
                    volumeObject = CreateVolume("VFX V1 · Ember volume core",
                        volumeShader, 3408);
                    volumeMaterial = volumeRenderer != null
                        ? volumeRenderer.sharedMaterial
                        : null;
                    particles = CreateParticles("VFX V1 · Ember core sparks",
                        particleShader, 3412, 256);
                    particleMaterial = particles != null
                        ? particles.GetComponent<ParticleSystemRenderer>().sharedMaterial
                        : null;
                    break;
                case "trail":
                    particles = CreateParticles("VFX V1 · Ember GPU-style wake",
                        particleShader, 3398, 220);
                    particleMaterial = particles != null
                        ? particles.GetComponent<ParticleSystemRenderer>().sharedMaterial
                        : null;
                    trail = CreateTrail("VFX V1 · Ember cast trail", particleShader, 3396);
                    break;
                case "impact-front":
                    CreateFlameCard("VFX V1 · Ember detonation", flameCardShader, true);
                    CreateFlameCard("VFX V1 · Ember detonation cross", flameCardShader, true);
                    CreateFlameCard("VFX V1 · Ember detonation flare", flameCardShader, true);
                    volumeObject = CreateVolume("VFX V1 · Ember impact volume",
                        volumeShader, 3418);
                    volumeMaterial = volumeRenderer != null
                        ? volumeRenderer.sharedMaterial
                        : null;
                    particles = CreateParticles("VFX V1 · Ember impact burst",
                        particleShader, 3422, 320);
                    particleMaterial = particles != null
                        ? particles.GetComponent<ParticleSystemRenderer>().sharedMaterial
                        : null;
                    break;
            }
        }

        public void Sample(in SpellSample sample)
        {
            if (released || layer == null)
                return;

            RestoreCameraShake();
            var contact = ContactTime;
            switch (layer.role)
            {
                case "core":
                    SampleCore(in sample, contact);
                    break;
                case "trail":
                    SampleTrail(in sample, contact);
                    break;
                case "impact-front":
                    SampleImpact(in sample, contact);
                    break;
            }
        }

        void SampleCore(in SpellSample sample, float contact)
        {
            var time = sample.AbsoluteTime;
            var visibility = 1f - Ease(contact - 0.015f, contact + 0.09f, time);
            if (visibility <= 0.001f)
            {
                HideVolume();
                HideFlameCards();
                return;
            }

            var axis = TravelAxis(in sample);
            var growth = Ease(0.04f, contact - 0.03f, time);
            var cardScale = sample.Scale.x * Mathf.Lerp(0.48f, 1.30f, growth);
            SetFlameCard(0, sample.Position, axis, sample.Camera,
                time * 5.8f, visibility * 0.72f, 0f, cardScale, 0f);
            SetFlameCard(1, sample.Position - axis * cardScale * 0.03f,
                axis, sample.Camera, time * 5.8f + 1.7f,
                visibility * 0.46f, 0f, cardScale * 0.88f, 90f);

            var scale = sample.Scale.x * Mathf.Lerp(0.12f, 0.58f, growth);
            if (volumeObject != null)
            {
                volumeObject.SetActive(true);
                volumeObject.transform.SetPositionAndRotation(
                    sample.Position, sample.Rotation);
                volumeObject.transform.localScale = new Vector3(
                    scale * 0.82f, scale * 0.82f, scale * 1.35f);
                SetVolume(time * 5.2f, visibility, 0f,
                    Color.red, 0.0f);
            }

            if (sample.AdvanceSimulation && particles != null)
            {
                for (var index = 0; index < 3; index++)
                {
                    var jitter = new Vector3(
                        Mathf.Sin(time * 19f + index * 2.7f + seed) * scale * 0.22f,
                        Mathf.Cos(time * 23f + index * 1.9f + seed) * scale * 0.18f,
                        0f);
                    EmitParticle(
                        particles,
                        sample.Position - axis * (scale * (0.25f + index * 0.10f))
                            + jitter,
                        -axis * Mathf.Lerp(0.25f, 0.55f, index / 2f)
                            + jitter * 2.0f,
                        Mathf.Lerp(0.12f, 0.26f, index / 2f),
                        scale * Mathf.Lerp(0.025f, 0.060f, index / 2f),
                        EmberColor(index, 0.80f));
                }
            }
        }

        void SampleTrail(in SpellSample sample, float contact)
        {
            var time = sample.AbsoluteTime;
            var visibility = Ease(0.02f, 0.12f, time)
                * (1f - Ease(contact - 0.02f, contact + 0.05f, time));
            if (visibility <= 0.001f)
            {
                if (trail != null) trail.emitting = false;
                return;
            }

            if (trail != null)
            {
                trail.emitting = true;
                trail.transform.position = sample.Position;
                trail.widthMultiplier = sample.Scale.x * 0.26f * visibility;
                trail.time = 0.24f;
            }

            if (!sample.AdvanceSimulation || particles == null)
                return;
            var axis = TravelAxis(in sample);
            for (var index = 0; index < 4; index++)
            {
                var side = index % 2 == 0 ? -1f : 1f;
                var local = sample.Camera != null
                    ? sample.Camera.transform.right * side
                        * sample.Scale.x * (0.05f + index * 0.018f)
                    : Vector3.right * side * sample.Scale.x * 0.06f;
                EmitParticle(
                    particles,
                    sample.Position - axis * sample.Scale.x
                        * (0.08f + index * 0.06f) + local,
                    -axis * Mathf.Lerp(0.2f, 0.55f, index / 3f)
                        + local * 2.5f,
                    Mathf.Lerp(0.18f, 0.34f, index / 3f),
                    sample.Scale.x * Mathf.Lerp(0.018f, 0.042f, index / 3f),
                    EmberColor(index + 1, visibility));
            }
        }

        void SampleImpact(in SpellSample sample, float contact)
        {
            var age = sample.AbsoluteTime - contact;
            var burst = ImpactBurst(contact, sample.AbsoluteTime);
            var fade = 1f - Ease(contact + 0.24f, contact + 0.72f,
                sample.AbsoluteTime);
            if (fade <= 0.001f)
            {
                HideVolume();
                HideFlameCards();
                RestoreCameraShake();
                return;
            }

            var impactAxis = TravelAxis(in sample);
            var impactBase = Mathf.Clamp(sample.Scale.x * 0.62f, 0.30f, 0.82f);
            var impactScale = impactBase * Mathf.Lerp(0.50f, 0.96f,
                Mathf.Clamp01(burst));
            SetFlameCard(0, sample.Target, impactAxis, sample.Camera,
                sample.AbsoluteTime * 7.0f, fade * 0.58f, 1f, impactScale, 0f);
            SetFlameCard(1, sample.Target, impactAxis, sample.Camera,
                sample.AbsoluteTime * 7.0f + 1.5f, fade * 0.38f,
                1f, impactScale * 0.90f, 90f);
            SetFlameCard(2, sample.Target, impactAxis, sample.Camera,
                sample.AbsoluteTime * 7.0f + 3.0f, fade * 0.26f,
                1f, impactScale * 1.08f, 45f);

            if (volumeObject != null)
            {
                volumeObject.SetActive(true);
                volumeObject.transform.SetPositionAndRotation(
                    sample.Target, Quaternion.identity);
                var volumeBase = Mathf.Clamp(sample.Scale.x * 0.50f, 0.24f, 0.72f);
                var scale = volumeBase * Mathf.Lerp(0.18f, 0.64f, burst);
                volumeObject.transform.localScale = new Vector3(
                    scale, scale * 0.78f, scale);
                SetVolume(sample.AbsoluteTime * 8f, fade * 0.24f, burst,
                    Color.white, 1f);
            }

            ApplyCameraShake(in sample, contact);
            if (!impactEmitted && sample.AdvanceSimulation)
            {
                impactEmitted = true;
                EmitImpactBurst(sample.Target, sample.Scale.x, burst);
            }
        }

        void EmitImpactBurst(Vector3 center, float scale, float burst)
        {
            if (particles == null)
                return;
            const int particleCount = 96;
            for (var index = 0; index < particleCount; index++)
            {
                var a = Hash01(index * 3 + seed);
                var b = Hash01(index * 7 + seed + 19);
                var c = Hash01(index * 11 + seed + 41);
                var angle = a * Mathf.PI * 2f;
                var direction = new Vector3(
                    Mathf.Cos(angle),
                    Mathf.Lerp(-0.60f, 0.95f, b),
                    Mathf.Sin(angle)).normalized;
                var speed = scale * Mathf.Lerp(1.8f, 4.8f, c);
                var color = EmberColor(index, 1f);
                EmitParticle(
                    particles,
                    center + direction * scale * 0.05f,
                    direction * speed * Mathf.Lerp(0.85f, 1.25f, burst),
                    Mathf.Lerp(0.28f, 0.68f, b),
                    scale * Mathf.Lerp(0.025f, 0.082f, c),
                    color);
            }
        }

        void ApplyCameraShake(in SpellSample sample, float contact)
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

            var envelope = ImpactBurst(contact, sample.AbsoluteTime)
                * (1f - Ease(contact + 0.04f, contact + 0.26f,
                    sample.AbsoluteTime));
            if (envelope <= 0.001f)
                return;
            var age = sample.AbsoluteTime - contact;
            var localOffset = new Vector3(
                Mathf.Sin(age * 190f + seed) * 0.018f * envelope,
                Mathf.Cos(age * 230f + seed * 0.7f) * 0.014f * envelope,
                0f);
            var roll = Mathf.Sin(age * 160f + seed) * 0.8f * envelope;
            camera.transform.position = shakeBasePosition
                + shakeBaseRotation * localOffset;
            camera.transform.rotation = shakeBaseRotation
                * Quaternion.AngleAxis(roll, Vector3.forward);
        }

        void SetVolume(float phase, float opacity, float burst,
            Color accent, float accentAmount)
        {
            if (volumeMaterial == null)
                return;
            volumeMaterial.SetFloat("_Phase", phase);
            volumeMaterial.SetFloat("_Opacity", Mathf.Clamp01(opacity));
            volumeMaterial.SetFloat("_Burst", Mathf.Clamp01(burst));
            volumeMaterial.SetFloat("_Dissolve", burst * 0.24f);
            volumeMaterial.SetFloat("_Intensity", 1.8f + burst * 1.8f);
            volumeMaterial.SetColor("_DeepColor", new Color(0.12f, 0.004f, 0.001f, 1f));
            volumeMaterial.SetColor("_MidColor", new Color(0.90f, 0.045f, 0.002f, 1f));
            volumeMaterial.SetColor("_HotColor", Color.Lerp(
                new Color(1f, 0.54f, 0.02f, 1f),
                new Color(1f, 0.96f, 0.54f, 1f), burst));
            volumeMaterial.SetColor("_EdgeColor", accent * accentAmount);
        }

        void CreateFlameCard(string name, Shader shader, bool impact)
        {
            if (shader == null)
                return;
            var card = GameObject.CreatePrimitive(PrimitiveType.Quad);
            card.name = name;
            card.transform.SetParent(transform, false);
            var collider = card.GetComponent<Collider>();
            if (collider != null)
                Destroy(collider);
            var renderer = card.GetComponent<Renderer>();
            var material = new Material(shader)
            {
                name = name + " material",
                hideFlags = HideFlags.DontSave,
                renderQueue = impact ? 4460 : 4410
            };
            material.SetFloat("_Mode", impact ? 1f : 0f);
            material.SetFloat("_Intensity", impact ? 2.0f : 2.1f);
            renderer.sharedMaterial = material;
            renderer.shadowCastingMode = ShadowCastingMode.Off;
            renderer.receiveShadows = false;
            renderer.enabled = false;
            flameCards.Add(card);
            flameCardMaterials.Add(material);
        }

        void SetFlameCard(int index, Vector3 position, Vector3 axis,
            Camera camera, float phase, float opacity, float burst,
            float scale, float roll)
        {
            if (index < 0 || index >= flameCards.Count)
                return;
            var card = flameCards[index];
            var renderer = card.GetComponent<Renderer>();
            if (renderer == null)
                return;
            var forward = camera != null ? -camera.transform.forward : Vector3.back;
            var up = axis.sqrMagnitude > 0.001f ? axis.normalized : Vector3.up;
            var rotation = Quaternion.LookRotation(forward, up)
                * Quaternion.AngleAxis(roll, forward);
            card.SetActive(true);
            renderer.enabled = true;
            card.transform.SetPositionAndRotation(position, rotation);
            var impact = layer != null && layer.role == "impact-front";
            card.transform.localScale = impact
                ? new Vector3(scale * 1.28f, scale * 1.28f, 1f)
                : new Vector3(scale * 0.72f, scale * 1.34f, 1f);
            var material = flameCardMaterials[index];
            material.SetFloat("_Phase", phase);
            material.SetFloat("_Opacity", Mathf.Clamp01(opacity));
            material.SetFloat("_Burst", Mathf.Clamp01(burst));
            material.SetFloat("_Mode", impact ? 1f : 0f);
            material.SetFloat("_Intensity", impact ? 2.05f : 2.15f);
        }

        void HideFlameCards()
        {
            for (var index = 0; index < flameCards.Count; index++)
            {
                if (flameCards[index] != null)
                    flameCards[index].SetActive(false);
            }
        }

        GameObject CreateVolume(string name, Shader shader, int queue)
        {
            var value = GameObject.CreatePrimitive(PrimitiveType.Sphere);
            value.name = name;
            value.transform.SetParent(transform, false);
            var collider = value.GetComponent<Collider>();
            if (collider != null)
                Destroy(collider);
            volumeRenderer = value.GetComponent<Renderer>();
            volumeMaterial = new Material(shader)
            {
                name = name + " material",
                hideFlags = HideFlags.DontSave,
                renderQueue = queue
            };
            volumeRenderer.sharedMaterial = volumeMaterial;
            volumeRenderer.shadowCastingMode = ShadowCastingMode.Off;
            volumeRenderer.receiveShadows = false;
            volumeRenderer.enabled = false;
            return value;
        }

        ParticleSystem CreateParticles(string name, Shader shader, int sortingOrder,
            int maxParticles)
        {
            var root = new GameObject(name);
            root.transform.SetParent(transform, false);
            var system = root.AddComponent<ParticleSystem>();
            var main = system.main;
            main.loop = false;
            main.playOnAwake = false;
            main.simulationSpace = ParticleSystemSimulationSpace.World;
            main.maxParticles = maxParticles;
            main.startLifetime = 0.45f;
            main.startSpeed = 0f;
            main.startSize = 0.05f;
            main.startColor = Color.white;
            var emission = system.emission;
            emission.enabled = false;
            var renderer = system.GetComponent<ParticleSystemRenderer>();
            var material = new Material(shader)
            {
                name = name + " material",
                hideFlags = HideFlags.DontSave,
                renderQueue = 3424
            };
            material.SetColor("_Tint", new Color(1f, 0.25f, 0.01f, 1f));
            material.SetFloat("_Intensity", 2.2f);
            renderer.sharedMaterial = material;
            renderer.sortingOrder = sortingOrder;
            renderer.shadowCastingMode = ShadowCastingMode.Off;
            renderer.receiveShadows = false;
            system.useAutoRandomSeed = false;
            system.randomSeed = unchecked((uint)seed);
            particleMaterial = material;
            return system;
        }

        TrailRenderer CreateTrail(string name, Shader shader, int sortingOrder)
        {
            var root = new GameObject(name);
            root.transform.SetParent(transform, false);
            var value = root.AddComponent<TrailRenderer>();
            value.time = 0.24f;
            value.minVertexDistance = 0.015f;
            value.widthMultiplier = 0.10f;
            value.shadowCastingMode = ShadowCastingMode.Off;
            value.receiveShadows = false;
            value.sortingOrder = sortingOrder;
            var material = new Material(shader)
            {
                name = name + " material",
                hideFlags = HideFlags.DontSave,
                renderQueue = 3396
            };
            material.SetColor("_Tint", new Color(1f, 0.12f, 0.002f, 1f));
            material.SetFloat("_Intensity", 1.8f);
            trailMaterial = material;
            value.material = material;
            return value;
        }

        void EmitParticle(ParticleSystem system, Vector3 position,
            Vector3 velocity, float lifetime, float size, Color color)
        {
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

        void HideVolume()
        {
            if (volumeObject != null)
                volumeObject.SetActive(false);
            if (trail != null)
                trail.emitting = false;
        }

        Vector3 TravelAxis(in SpellSample sample)
        {
            var cameraForward = sample.Camera != null
                ? sample.Camera.transform.forward
                : Vector3.forward;
            var axis = Vector3.ProjectOnPlane(
                sample.Target - sample.Source, cameraForward);
            return axis.sqrMagnitude > 0.001f ? axis.normalized : Vector3.up;
        }

        static Color EmberColor(int index, float alpha)
        {
            var value = index % 7;
            var color = value == 0
                ? new Color(1f, 0.96f, 0.62f, 1f)
                : value % 3 == 0
                    ? new Color(1f, 0.30f, 0.006f, 1f)
                    : new Color(1f, 0.66f, 0.035f, 1f);
            color.a = alpha;
            return color;
        }

        static float Hash01(int value)
        {
            return Mathf.Repeat(Mathf.Sin(value * 12.9898f) * 43758.5453f, 1f);
        }

        static float Ease(float start, float end, float value)
        {
            if (end <= start + 0.0001f)
                return value >= end ? 1f : 0f;
            return Mathf.SmoothStep(0f, 1f,
                Mathf.Clamp01((value - start) / (end - start)));
        }

        static float ImpactBurst(float contact, float time)
        {
            return Mathf.Pow(Ease(contact, contact + 0.075f, time), 0.18f);
        }

        float ContactTime => spell != null && spell.timeline != null
            ? spell.timeline.windup + spell.timeline.travel
            : 0.90f;

        void RestoreCameraShake()
        {
            if (!shakeCaptured || shakeCamera == null)
                return;
            shakeCamera.transform.SetPositionAndRotation(
                shakeBasePosition, shakeBaseRotation);
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
            HideVolume();
            HideFlameCards();
            if (particles != null)
                particles.Stop(true, ParticleSystemStopBehavior.StopEmittingAndClear);
            if (volumeObject != null)
                SpellBackends.DestroyOwned(volumeObject);
            if (particles != null)
                SpellBackends.DestroyOwned(particles.gameObject);
            if (trail != null)
                SpellBackends.DestroyOwned(trail.gameObject);
            if (volumeMaterial != null)
                SpellBackends.DestroyOwned(volumeMaterial);
            if (particleMaterial != null)
                SpellBackends.DestroyOwned(particleMaterial);
            if (trailMaterial != null)
                SpellBackends.DestroyOwned(trailMaterial);
            for (var index = 0; index < flameCards.Count; index++)
            {
                if (flameCards[index] != null)
                    SpellBackends.DestroyOwned(flameCards[index]);
            }
            for (var index = 0; index < flameCardMaterials.Count; index++)
            {
                if (flameCardMaterials[index] != null)
                    SpellBackends.DestroyOwned(flameCardMaterials[index]);
            }
            flameCards.Clear();
            flameCardMaterials.Clear();
        }
    }
}
