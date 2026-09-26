using System;
using System.Collections.Generic;
using Effekseer;
using UnityEngine;

namespace Mindstone.VFXV1
{
    internal interface ISpellLayerRuntime
    {
        bool IsAlive { get; }
        void Sample(in SpellSample sample);
        void Interrupt();
        void Cleanup();
    }

    internal static class SpellBackends
    {
        public static void DestroyOwned(UnityEngine.Object value)
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

        public static bool CanResolve(SpellLayerSpec layer, out string reason)
        {
            reason = null;
            if (layer == null)
            {
                reason = "null layer";
                return false;
            }
            switch (layer.backend)
            {
                case "effekseer":
                    if (Resources.Load<EffekseerEffectAsset>(layer.asset) == null)
                        reason = $"missing Effekseer asset {layer.asset}";
                    break;
                case "prefab":
                    if (Resources.Load<GameObject>(layer.asset) == null)
                        reason = $"missing prefab {layer.asset}";
                    break;
                case "spriteSequence":
                    if (Resources.LoadAll<Sprite>(layer.asset).Length == 0
                        && Resources.Load<Texture2D>(layer.asset) == null)
                        reason = $"missing sprites/texture {layer.asset}";
                    break;
                case "ribbon":
                    if (!string.IsNullOrWhiteSpace(layer.asset)
                        && Resources.Load<Texture2D>(layer.asset) == null)
                        reason = $"missing ribbon texture {layer.asset}";
                    break;
                case "extension":
                    if (ResolveType(layer.extensionType) == null)
                        reason = $"missing extension type {layer.extensionType}";
                    break;
                default:
                    reason = $"unsupported backend {layer.backend}";
                    break;
            }
            return reason == null;
        }

        public static ISpellLayerRuntime Create(
            Transform parent,
            SpellSpec spell,
            SpellLayerSpec layer,
            int seed)
        {
            return layer.backend switch
            {
                "effekseer" => new EffekseerLayer(parent, layer),
                "prefab" => new PrefabLayer(parent, layer, seed),
                "spriteSequence" => new SpriteSequenceLayer(parent, layer),
                "ribbon" => new RibbonLayer(parent, layer),
                "extension" => new ExtensionLayer(parent, spell, layer, seed),
                _ => throw new ArgumentOutOfRangeException(nameof(layer.backend), layer.backend, "Unsupported VFX backend")
            };
        }

        public static Color ColorOf(SpellLayerSpec layer)
        {
            var values = layer.color;
            return values != null && values.Length >= 4
                ? new Color(values[0], values[1], values[2], values[3])
                : Color.white;
        }

        public static Vector3 ScaleOf(SpellLayerSpec layer)
        {
            var values = layer.scale;
            return values != null && values.Length >= 3
                ? new Vector3(values[0], values[1], values[2])
                : Vector3.one;
        }

        static Type ResolveType(string name)
        {
            if (string.IsNullOrWhiteSpace(name))
                return null;
            var direct = Type.GetType(name, false);
            if (direct != null)
                return direct;
            foreach (var assembly in AppDomain.CurrentDomain.GetAssemblies())
            {
                var candidate = assembly.GetType(name, false);
                if (candidate != null)
                    return candidate;
            }
            return null;
        }

        abstract class LayerBase : ISpellLayerRuntime
        {
            protected readonly SpellLayerSpec Layer;
            protected LayerBase(SpellLayerSpec layer) => Layer = layer;
            public virtual bool IsAlive => true;
            public abstract void Sample(in SpellSample sample);
            public virtual void Interrupt() => Cleanup();
            public abstract void Cleanup();

            protected static void ApplyTransform(Transform transform, SpellLayerSpec layer, in SpellSample sample)
            {
                transform.position = sample.Position;
                transform.rotation = sample.Rotation;
                var layerScale = ScaleOf(layer);
                transform.localScale = Vector3.Scale(sample.Scale, layerScale);
            }
        }

        sealed class EffekseerLayer : LayerBase
        {
            readonly EffekseerEffectAsset asset;
            EffekseerHandle handle;
            bool started;

            public EffekseerLayer(Transform parent, SpellLayerSpec layer) : base(layer)
            {
                asset = Resources.Load<EffekseerEffectAsset>(layer.asset);
                handle = new EffekseerHandle(-1);
            }

            public override bool IsAlive => !started || handle.exists;

            public override void Sample(in SpellSample sample)
            {
                if (!started)
                {
                    handle = EffekseerSystem.PlayEffect(asset, sample.Position);
                    started = true;
                    if (!handle.enabled)
                        return;
                    handle.paused = true;
                    handle.SetAllColor(ColorOf(Layer));
                }
                if (!handle.enabled || !handle.exists)
                    return;
                handle.SetLocation(sample.Position);
                handle.SetRotation(sample.Rotation);
                handle.SetScale(Vector3.Scale(sample.Scale, ScaleOf(Layer)));
                if (sample.AdvanceSimulation)
                    handle.UpdateHandle(1f);
            }

            public override void Interrupt()
            {
                Cleanup();
            }

            public override void Cleanup()
            {
                if (handle.enabled && handle.exists)
                    handle.Stop();
                handle = new EffekseerHandle(-1);
            }
        }

        sealed class PrefabLayer : LayerBase
        {
            readonly GameObject instance;
            readonly ParticleSystem[] particles;
            readonly Animator[] animators;

            public PrefabLayer(Transform parent, SpellLayerSpec layer, int seed) : base(layer)
            {
                var prefab = Resources.Load<GameObject>(layer.asset);
                instance = UnityEngine.Object.Instantiate(prefab, parent);
                instance.name = $"VFX V1 · {layer.name}";
                particles = instance.GetComponentsInChildren<ParticleSystem>(true);
                for (var index = 0; index < particles.Length; index++)
                {
                    particles[index].useAutoRandomSeed = false;
                    particles[index].randomSeed = unchecked((uint)(seed + index * 997));
                    particles[index].Pause(true);
                }
                animators = instance.GetComponentsInChildren<Animator>(true);
                foreach (var animator in animators)
                {
                    animator.enabled = false;
                    animator.Rebind();
                }
            }

            public override bool IsAlive => instance != null;

            public override void Sample(in SpellSample sample)
            {
                if (instance == null)
                    return;
                ApplyTransform(instance.transform, Layer, sample);
                if (sample.AdvanceSimulation)
                {
                    foreach (var particle in particles)
                        if (particle != null)
                            particle.Simulate(1f / 60f, true, false, true);
                    foreach (var animator in animators)
                        if (animator != null)
                            animator.Update(1f / 60f);
                }
            }

            public override void Cleanup()
            {
                if (instance != null)
                    DestroyOwned(instance);
            }
        }

        sealed class SpriteSequenceLayer : LayerBase
        {
            readonly GameObject root;
            readonly SpriteRenderer renderer;
            readonly Sprite[] sprites;
            readonly Sprite ownedSprite;
            readonly Material material;

            public SpriteSequenceLayer(Transform parent, SpellLayerSpec layer) : base(layer)
            {
                root = new GameObject($"VFX V1 · {layer.name}");
                root.transform.SetParent(parent, false);
                renderer = root.AddComponent<SpriteRenderer>();
                renderer.color = ColorOf(layer);
                renderer.sortingOrder = layer.sortingOrder;
                var loaded = Resources.LoadAll<Sprite>(layer.asset);
                if (loaded.Length > 0)
                {
                    Array.Sort(loaded, (left, right) => string.CompareOrdinal(left.name, right.name));
                    sprites = loaded;
                }
                else
                {
                    var texture = Resources.Load<Texture2D>(layer.asset);
                    ownedSprite = Sprite.Create(texture, new Rect(0f, 0f, texture.width, texture.height), new Vector2(0.5f, 0.5f), 128f);
                    sprites = new[] { ownedSprite };
                }
                renderer.sprite = sprites[0];
                material = renderer.material;
                material.renderQueue = layer.renderQueue;
            }

            public override bool IsAlive => root != null;

            public override void Sample(in SpellSample sample)
            {
                if (root == null)
                    return;
                ApplyTransform(root.transform, Layer, sample);
                var frame = Mathf.FloorToInt(sample.LayerTime * Mathf.Max(1f, Layer.fps));
                frame = Layer.loop ? frame % sprites.Length : Mathf.Min(frame, sprites.Length - 1);
                renderer.sprite = sprites[Mathf.Max(0, frame)];
                if (Layer.faceCamera && sample.Camera != null)
                    root.transform.rotation = sample.Camera.transform.rotation;
            }

            public override void Cleanup()
            {
                if (root != null)
                    DestroyOwned(root);
                if (ownedSprite != null)
                    DestroyOwned(ownedSprite);
                if (material != null)
                    DestroyOwned(material);
            }
        }

        sealed class RibbonLayer : LayerBase
        {
            readonly GameObject root;
            readonly LineRenderer line;
            readonly Material material;
            readonly Vector3[] positions;
            int count;

            public RibbonLayer(Transform parent, SpellLayerSpec layer) : base(layer)
            {
                root = new GameObject($"VFX V1 · {layer.name}");
                root.transform.SetParent(parent, false);
                line = root.AddComponent<LineRenderer>();
                line.useWorldSpace = true;
                line.alignment = LineAlignment.View;
                line.textureMode = LineTextureMode.Stretch;
                line.numCornerVertices = 3;
                line.numCapVertices = 2;
                line.widthMultiplier = Mathf.Max(0.005f, layer.width);
                var color = ColorOf(layer);
                line.startColor = color;
                line.endColor = new Color(color.r, color.g, color.b, 0f);
                line.sortingOrder = layer.sortingOrder;
                var shader = Shader.Find("Sprites/Default") ?? Shader.Find("Unlit/Transparent");
                material = new Material(shader) { name = $"VFX V1 · {layer.name} Material" };
                material.renderQueue = layer.renderQueue;
                var texture = string.IsNullOrWhiteSpace(layer.asset) ? null : Resources.Load<Texture2D>(layer.asset);
                if (texture != null)
                    material.mainTexture = texture;
                line.sharedMaterial = material;
                positions = new Vector3[Mathf.Clamp(layer.pointCount, 2, 128)];
            }

            public override bool IsAlive => root != null;

            public override void Sample(in SpellSample sample)
            {
                if (root == null)
                    return;
                if (sample.AdvanceSimulation)
                {
                    if (count < positions.Length)
                        count++;
                    for (var index = count - 1; index > 0; index--)
                        positions[index] = positions[index - 1];
                    positions[0] = sample.Position;
                }
                if (count == 0)
                    return;
                line.positionCount = count;
                line.SetPosition(0, sample.Position);
                for (var index = 1; index < count; index++)
                    line.SetPosition(index, positions[index]);
                var fade = Mathf.SmoothStep(1f, 0f, sample.NormalizedTime);
                line.widthMultiplier = Mathf.Max(0.005f, Layer.width * Mathf.Lerp(0.35f, 1f, fade));
            }

            public override void Cleanup()
            {
                if (root != null)
                    DestroyOwned(root);
                if (material != null)
                    DestroyOwned(material);
            }
        }

        sealed class ExtensionLayer : LayerBase
        {
            readonly GameObject root;
            readonly ISpellExtension extension;

            public ExtensionLayer(Transform parent, SpellSpec spell, SpellLayerSpec layer, int seed) : base(layer)
            {
                root = new GameObject($"VFX V1 · {layer.name}");
                root.transform.SetParent(parent, false);
                var type = ResolveType(layer.extensionType);
                if (type == null || !typeof(MonoBehaviour).IsAssignableFrom(type)
                    || !typeof(ISpellExtension).IsAssignableFrom(type))
                    throw new InvalidOperationException($"Extension must be MonoBehaviour + ISpellExtension: {layer.extensionType}");
                extension = (ISpellExtension)root.AddComponent(type);
                extension.Initialize(spell, layer, seed);
            }

            public override bool IsAlive => root != null;

            public override void Sample(in SpellSample sample)
            {
                if (root == null)
                    return;
                ApplyTransform(root.transform, Layer, sample);
                extension.Sample(in sample);
            }

            public override void Interrupt() => extension?.Interrupt();

            public override void Cleanup()
            {
                extension?.Cleanup();
                if (root != null)
                    DestroyOwned(root);
            }
        }
    }
}
