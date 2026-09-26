using System;
using UnityEngine;

namespace Mindstone.VFXV1
{
    [Serializable]
    public sealed class SpellSpec
    {
        public int schema = 1;
        public string id;
        public string displayName;
        public string archetype;
        public int seed = 1;
        public SpellTimeline timeline = new();
        public SpellAnchors anchors = new();
        public SpellBehavior behavior = new();
        public SpellLayerSpec[] layers = Array.Empty<SpellLayerSpec>();
        public SpellCaptureSpec capture = new();
        public float cleanupSeconds = 0.35f;
        public SpellShowcaseSpec showcase = new();

        public float Duration => timeline != null ? timeline.Duration : 0f;
    }

    [Serializable]
    public sealed class SpellTimeline
    {
        public float windup;
        public float travel;
        public float impact;
        public float decay;

        public float Duration => Mathf.Max(0f, windup)
            + Mathf.Max(0f, travel)
            + Mathf.Max(0f, impact)
            + Mathf.Max(0f, decay);
    }

    [Serializable]
    public sealed class SpellAnchors
    {
        public string origin = "source";
        public string target = "target";
        public string impact = "impact";
        public string ground = "ground";
        public float[] originOffset = { 0f, 0f, 0f };
        public float[] targetOffset = { 0f, 0f, 0f };
        public float[] impactOffset = { 0f, 0f, 0f };
        public float[] groundOffset = { 0f, 0f, 0f };
    }

    [Serializable]
    public sealed class SpellBehavior
    {
        public string path = "linear";
        public float arcHeight;
        public float startScale = 1f;
        public float endScale = 1f;
        public float impactScale = 1f;
        public float tracking = 1f;
        public float beamWidth;
        public float orbitRadius;
        public float spinDegrees;
        public string extensionType = "";
    }

    [Serializable]
    public sealed class SpellLayerSpec
    {
        public string name;
        public string backend;
        public string asset;
        public string role = "core";
        public string anchor = "motion";
        public float start;
        public float end = 1f;
        public float[] color = { 1f, 1f, 1f, 1f };
        public float[] scale = { 1f, 1f, 1f };
        public float startScale = 1f;
        public float endScale = 1f;
        public float width = 0.1f;
        public int pointCount = 20;
        public int renderQueue = 3400;
        public int sortingOrder;
        public int seedOffset;
        public float fps = 24f;
        public bool loop;
        public bool faceCamera = true;
        public bool frontOfTarget;
        public string extensionType = "";
    }

    [Serializable]
    public sealed class SpellCaptureSpec
    {
        public float[] times = Array.Empty<float>();
        public string device = "iPhone 13";
        public int targetFps = 60;
    }

    [Serializable]
    public sealed class SpellShowcaseSpec
    {
        public string sourceActor = "clockguard";
        public float[] source = { -3.45f, 1.65f, 3.8f };
        public float[] target = { -3.45f, 0.66f, 3.8f };
    }

    public readonly struct SpellHandle : IEquatable<SpellHandle>
    {
        public static readonly SpellHandle Invalid = new(0);

        public SpellHandle(int value) => Value = value;
        public int Value { get; }
        public bool IsValid => Value > 0;
        public bool Equals(SpellHandle other) => Value == other.Value;
        public override bool Equals(object obj) => obj is SpellHandle other && Equals(other);
        public override int GetHashCode() => Value;
        public override string ToString() => IsValid ? $"SpellHandle({Value})" : "SpellHandle.Invalid";
    }

    public sealed class SpellContext
    {
        public Func<Vector3> source;
        public Func<Vector3> target;
        public Func<Vector3> weapon;
        public Func<Vector3> mouth;
        public Func<Vector3> impact;
        public Func<Vector3> ground;
        public Action onContact;
        public float? contactTime;
        public Camera camera;
        public int? seed;

        public Vector3 Resolve(string anchor)
        {
            return anchor switch
            {
                "source" => Invoke(source),
                "target" => Invoke(target),
                "weapon" => Invoke(weapon ?? source),
                "mouth" => Invoke(mouth ?? source),
                "impact" => Invoke(impact ?? target),
                "ground" => Invoke(ground ?? target),
                _ => Invoke(target)
            };
        }

        static Vector3 Invoke(Func<Vector3> value) => value != null ? value() : Vector3.zero;
    }

    public readonly struct SpellSample
    {
        public SpellSample(
            float absoluteTime,
            float normalizedTime,
            float layerTime,
            Vector3 position,
            Vector3 source,
            Vector3 target,
            Quaternion rotation,
            Vector3 scale,
            Camera camera,
            int seed,
            bool advanceSimulation)
        {
            AbsoluteTime = absoluteTime;
            NormalizedTime = normalizedTime;
            LayerTime = layerTime;
            Position = position;
            Source = source;
            Target = target;
            Rotation = rotation;
            Scale = scale;
            Camera = camera;
            Seed = seed;
            AdvanceSimulation = advanceSimulation;
        }

        public float AbsoluteTime { get; }
        public float NormalizedTime { get; }
        public float LayerTime { get; }
        public Vector3 Position { get; }
        public Vector3 Source { get; }
        public Vector3 Target { get; }
        public Quaternion Rotation { get; }
        public Vector3 Scale { get; }
        public Camera Camera { get; }
        public int Seed { get; }
        public bool AdvanceSimulation { get; }
    }

    public interface ISpellExtension
    {
        void Initialize(SpellSpec spell, SpellLayerSpec layer, int seed);
        void Sample(in SpellSample sample);
        void Interrupt();
        void Cleanup();
    }
}
