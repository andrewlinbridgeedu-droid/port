using System;
using System.Collections.Generic;
using UnityEngine;

namespace Mindstone.VFXV1
{
    public sealed class SpellRuntime : MonoBehaviour
    {
        public const float FixedStep = 1f / 60f;

        readonly Dictionary<int, ActiveSpell> active = new();
        readonly List<int> completed = new();
        int nextHandle = 1;
        float accumulator;
        string replayID;
        SpellContext replayContext;

        public bool AutoAdvance { get; set; } = true;
        public int ActiveCount => active.Count;

        public SpellHandle Play(string id, SpellContext context)
        {
            if (!SpellRegistry.TryGet(id, out var spec))
            {
                Debug.LogError($"[VFX V1] Unknown spell: {id}");
                return SpellHandle.Invalid;
            }
            var handle = new SpellHandle(nextHandle++);
            var root = new GameObject($"VFX V1 · {spec.id} · {handle.Value}");
            root.transform.SetParent(transform, false);
            active.Add(handle.Value, new ActiveSpell(spec, context, root.transform));
            replayID = id;
            replayContext = context;
            return handle;
        }

        public bool IsPlaying(SpellHandle handle) => handle.IsValid && active.ContainsKey(handle.Value);

        public void Advance(float deltaTime)
        {
            if (deltaTime <= 0f || active.Count == 0)
                return;
            accumulator += Mathf.Min(deltaTime, 0.25f);
            while (accumulator + 0.000001f >= FixedStep)
            {
                accumulator -= FixedStep;
                Step(FixedStep);
            }
            if (active.Count > 0 && accumulator > 0.000001f)
                Render(accumulator);
        }

        public void Interrupt(SpellHandle handle)
        {
            if (!handle.IsValid || !active.TryGetValue(handle.Value, out var spell))
                return;
            spell.Interrupt();
            spell.Cleanup();
            active.Remove(handle.Value);
        }

        public void Cleanup(SpellHandle handle)
        {
            if (!handle.IsValid || !active.TryGetValue(handle.Value, out var spell))
                return;
            spell.Cleanup();
            active.Remove(handle.Value);
        }

        public void StopAll()
        {
            foreach (var spell in active.Values)
                spell.Cleanup();
            active.Clear();
            completed.Clear();
            accumulator = 0f;
        }

        public SpellHandle Replay()
        {
            if (string.IsNullOrWhiteSpace(replayID) || replayContext == null)
                return SpellHandle.Invalid;
            StopAll();
            return Play(replayID, replayContext);
        }

        void Update()
        {
            if (AutoAdvance)
                Advance(Time.deltaTime);
        }

        void OnDisable() => StopAll();
        void OnDestroy() => StopAll();

        void Step(float deltaTime)
        {
            completed.Clear();
            foreach (var pair in active)
            {
                pair.Value.Advance(deltaTime);
                if (pair.Value.IsComplete)
                    completed.Add(pair.Key);
            }
            foreach (var id in completed)
            {
                if (!active.TryGetValue(id, out var spell))
                    continue;
                spell.Cleanup();
                active.Remove(id);
            }
        }

        void Render(float leadTime)
        {
            foreach (var spell in active.Values)
                spell.Render(leadTime);
        }

        sealed class ActiveSpell
        {
            readonly SpellSpec spec;
            readonly SpellContext context;
            readonly Transform root;
            readonly LayerState[] layers;
            readonly Vector3 initialSource;
            float elapsed;
            bool cleaned;
            bool contactReported;

            public ActiveSpell(SpellSpec spec, SpellContext context, Transform root)
            {
                this.spec = spec;
                this.context = context ?? new SpellContext();
                this.root = root;
                initialSource = ResolveConfigured(spec.anchors.origin, spec.anchors.originOffset);
                layers = new LayerState[spec.layers.Length];
                var seed = context?.seed ?? spec.seed;
                for (var index = 0; index < layers.Length; index++)
                    layers[index] = new LayerState(spec.layers[index], unchecked(seed + spec.layers[index].seedOffset));
            }

            public bool IsComplete => cleaned || elapsed >= spec.Duration + Mathf.Max(0f, spec.cleanupSeconds);

            public void Advance(float deltaTime)
            {
                if (cleaned)
                    return;
                elapsed += deltaTime;
                Sample(elapsed, true);
            }

            public void Render(float leadTime)
            {
                if (cleaned || leadTime <= 0f)
                    return;
                Sample(Mathf.Min(elapsed + leadTime, spec.Duration), false);
            }

            void Sample(float sampleTime, bool advanceSimulation)
            {
                var duration = Mathf.Max(0.0001f, spec.Duration);
                var normalized = Mathf.Clamp01(sampleTime / duration);
                var source = ResolveConfigured(spec.anchors.origin, spec.anchors.originOffset);
                var target = ResolveConfigured(spec.anchors.target, spec.anchors.targetOffset);
                var impact = ResolveConfigured(spec.anchors.impact, spec.anchors.impactOffset);
                var ground = ResolveConfigured(spec.anchors.ground, spec.anchors.groundOffset);
                var motion = ResolveMotion(sampleTime, source, target);
                var direction = target - source;
                var rotation = direction.sqrMagnitude > 0.000001f
                    ? Quaternion.LookRotation(direction.normalized, Vector3.up)
                    : Quaternion.identity;
                var behaviorScale = ResolveScale(sampleTime);
                var camera = context.camera != null ? context.camera : Camera.main;

                for (var index = 0; index < layers.Length; index++)
                {
                    var state = layers[index];
                    var layer = state.Spec;
                    var startTime = layer.start * duration;
                    var endTime = layer.end * duration;
                    if (sampleTime + 0.000001f < startTime)
                        continue;
                    if (!state.Started)
                    {
                        if (!advanceSimulation)
                            continue;
                        state.Start(root, spec);
                    }
                    if (sampleTime > endTime && !state.Stopping && advanceSimulation)
                        state.StopRoot();
                    if (state.Runtime == null)
                        continue;
                    if (state.Stopping)
                    {
                        state.Cleanup();
                        continue;
                    }

                    var position = layer.anchor switch
                    {
                        "source" => source,
                        "target" => target,
                        "weapon" => context.Resolve("weapon"),
                        "mouth" => context.Resolve("mouth"),
                        "impact" => impact,
                        "ground" => ground,
                        _ => motion
                    };
                    if (camera != null)
                    {
                        if (layer.frontOfTarget || layer.role == "impact-front")
                            position -= camera.transform.forward * 0.10f;
                        else if (layer.role == "impact-back")
                            position += camera.transform.forward * 0.10f;
                    }
                    var local = Mathf.Clamp01((sampleTime - startTime) / Mathf.Max(0.0001f, endTime - startTime));
                    var layerScale = Mathf.Lerp(layer.startScale, layer.endScale, Mathf.SmoothStep(0f, 1f, local));
                    var scale = Vector3.one * behaviorScale * Mathf.Max(0.0001f, layerScale);
                    var sample = new SpellSample(
                        sampleTime,
                        normalized,
                        Mathf.Max(0f, sampleTime - startTime),
                        position,
                        source,
                        target,
                        rotation,
                        scale,
                        camera,
                        state.Seed,
                        advanceSimulation);
                    state.Runtime.Sample(in sample);
                }
                // Report after sampling the authored impact frame, never from
                // an independent wall clock in the native combat UI.
                if (!contactReported && advanceSimulation && sampleTime >= (context.contactTime ?? (spec.timeline.windup + spec.timeline.travel))) {
                    contactReported = true;
                    context.onContact?.Invoke();
                }
            }

            public void Interrupt()
            {
                foreach (var layer in layers)
                    layer.StopRoot();
            }

            public void Cleanup()
            {
                if (cleaned)
                    return;
                cleaned = true;
                foreach (var layer in layers)
                    layer.Cleanup();
                if (root != null)
                    SpellBackends.DestroyOwned(root.gameObject);
            }

            Vector3 ResolveConfigured(string anchor, float[] offset)
            {
                var position = context.Resolve(anchor);
                if (offset != null && offset.Length >= 3)
                    position += new Vector3(offset[0], offset[1], offset[2]);
                return position;
            }

            Vector3 ResolveMotion(float sampleTime, Vector3 currentSource, Vector3 target)
            {
                var behavior = spec.behavior ?? new SpellBehavior();
                if (behavior.path == "stationary")
                    return target;
                var travelStart = spec.timeline.windup;
                var travelDuration = Mathf.Max(0.0001f, spec.timeline.travel);
                var progress = Mathf.SmoothStep(0f, 1f, Mathf.Clamp01((sampleTime - travelStart) / travelDuration));
                var source = Vector3.Lerp(initialSource, currentSource, Mathf.Clamp01(behavior.tracking));
                if (behavior.path == "orbit")
                {
                    var angle = progress * behavior.spinDegrees * Mathf.Deg2Rad;
                    return target + new Vector3(Mathf.Cos(angle), Mathf.Sin(angle), 0f) * behavior.orbitRadius;
                }
                var position = Vector3.Lerp(source, target, progress);
                if (behavior.path == "bezier")
                    position += Vector3.up * (4f * progress * (1f - progress) * behavior.arcHeight);
                return position;
            }

            float ResolveScale(float sampleTime)
            {
                var behavior = spec.behavior ?? new SpellBehavior();
                var travelStart = spec.timeline.windup;
                var travelEnd = travelStart + spec.timeline.travel;
                if (sampleTime <= travelEnd)
                {
                    var progress = Mathf.Clamp01((sampleTime - travelStart) / Mathf.Max(0.0001f, spec.timeline.travel));
                    return Mathf.Lerp(behavior.startScale, behavior.endScale, Mathf.SmoothStep(0f, 1f, progress));
                }
                var impactEnd = travelEnd + spec.timeline.impact;
                if (sampleTime <= impactEnd)
                {
                    var progress = Mathf.Clamp01((sampleTime - travelEnd) / Mathf.Max(0.0001f, spec.timeline.impact));
                    return Mathf.Lerp(behavior.endScale, behavior.impactScale, Mathf.SmoothStep(0f, 1f, progress));
                }
                var decay = Mathf.Clamp01((sampleTime - impactEnd) / Mathf.Max(0.0001f, spec.timeline.decay));
                return Mathf.Lerp(behavior.impactScale, 0.01f, Mathf.SmoothStep(0f, 1f, decay));
            }
        }

        sealed class LayerState
        {
            public LayerState(SpellLayerSpec spec, int seed)
            {
                Spec = spec;
                Seed = seed;
            }

            public SpellLayerSpec Spec { get; }
            public int Seed { get; }
            public ISpellLayerRuntime Runtime { get; private set; }
            public bool Started { get; private set; }
            public bool Stopping { get; private set; }

            public void Start(Transform parent, SpellSpec spell)
            {
                if (Started)
                    return;
                Started = true;
                Runtime = SpellBackends.Create(parent, spell, Spec, Seed);
            }

            public void StopRoot()
            {
                if (!Started || Stopping)
                    return;
                Stopping = true;
                Runtime?.Interrupt();
            }

            public void Cleanup()
            {
                Runtime?.Cleanup();
                Runtime = null;
            }
        }
    }
}
