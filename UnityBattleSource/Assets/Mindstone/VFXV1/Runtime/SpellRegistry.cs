using System;
using System.Collections.Generic;
using UnityEngine;

namespace Mindstone.VFXV1
{
    public static class SpellRegistry
    {
        const string RegistryRoot = "Mindstone/VFXV1/Registry";
        static readonly Dictionary<string, SpellSpec> Specs = new(StringComparer.OrdinalIgnoreCase);
        static bool loaded;

        [Serializable]
        sealed class RegistryEntry
        {
            public int schema;
            public string id;
            public string spec;
        }

        public static bool Contains(string id) => TryGet(id, out _);

        public static bool TryGet(string id, out SpellSpec spec)
        {
            EnsureLoaded();
            return Specs.TryGetValue(id ?? string.Empty, out spec);
        }

        public static IReadOnlyCollection<SpellSpec> All
        {
            get
            {
                EnsureLoaded();
                return Specs.Values;
            }
        }

        public static void Reload()
        {
            loaded = false;
            Specs.Clear();
            EnsureLoaded();
        }

        public static string[] Validate(string onlyID = null)
        {
            EnsureLoaded();
            var errors = new List<string>();
            foreach (var pair in Specs)
            {
                if (!string.IsNullOrWhiteSpace(onlyID)
                    && !string.Equals(pair.Key, onlyID, StringComparison.OrdinalIgnoreCase))
                    continue;
                ValidateSpec(pair.Value, errors);
            }
            if (!string.IsNullOrWhiteSpace(onlyID) && !Specs.ContainsKey(onlyID))
                errors.Add($"Spell is not registered: {onlyID}");
            return errors.ToArray();
        }

        static void EnsureLoaded()
        {
            if (loaded)
                return;
            loaded = true;
            Specs.Clear();
            var entries = Resources.LoadAll<TextAsset>(RegistryRoot);
            Array.Sort(entries, (left, right) => string.CompareOrdinal(left.name, right.name));
            foreach (var text in entries)
            {
                RegistryEntry entry;
                try
                {
                    entry = JsonUtility.FromJson<RegistryEntry>(text.text);
                }
                catch (Exception exception)
                {
                    Debug.LogError($"[VFX V1] Invalid registry JSON {text.name}: {exception.Message}");
                    continue;
                }
                if (entry == null || entry.schema != 1 || string.IsNullOrWhiteSpace(entry.id)
                    || string.IsNullOrWhiteSpace(entry.spec))
                {
                    Debug.LogError($"[VFX V1] Invalid registry entry: {text.name}");
                    continue;
                }
                if (Specs.ContainsKey(entry.id))
                {
                    Debug.LogError($"[VFX V1] Duplicate spell ID: {entry.id}");
                    continue;
                }
                var specText = Resources.Load<TextAsset>(entry.spec);
                if (specText == null)
                {
                    Debug.LogError($"[VFX V1] Missing SpellSpec resource: {entry.spec}");
                    continue;
                }
                SpellSpec spec;
                try
                {
                    spec = JsonUtility.FromJson<SpellSpec>(specText.text);
                }
                catch (Exception exception)
                {
                    Debug.LogError($"[VFX V1] Invalid SpellSpec {entry.spec}: {exception.Message}");
                    continue;
                }
                if (spec == null || !string.Equals(spec.id, entry.id, StringComparison.Ordinal))
                {
                    Debug.LogError($"[VFX V1] Registry/spec ID mismatch: {entry.id}");
                    continue;
                }
                Specs.Add(entry.id, spec);
            }
        }

        static void ValidateSpec(SpellSpec spec, List<string> errors)
        {
            if (spec == null)
            {
                errors.Add("Null SpellSpec");
                return;
            }
            if (spec.schema != 1)
                errors.Add($"{spec.id}: schema must be 1");
            if (string.IsNullOrWhiteSpace(spec.id))
                errors.Add("Spell ID is empty");
            if (spec.Duration <= 0f)
                errors.Add($"{spec.id}: duration must be positive");
            if (spec.layers == null || spec.layers.Length == 0)
                errors.Add($"{spec.id}: requires at least one layer");
            if (spec.capture == null || spec.capture.times == null || spec.capture.times.Length != 5)
                errors.Add($"{spec.id}: requires exactly five capture times");
            else
            {
                var previous = 0f;
                foreach (var time in spec.capture.times)
                {
                    if (time <= previous || time > spec.Duration + 0.0001f)
                    {
                        errors.Add($"{spec.id}: capture times must increase inside duration");
                        break;
                    }
                    previous = time;
                }
            }
            if (spec.capture != null
                && (!string.Equals(spec.capture.device, "iPhone 13", StringComparison.Ordinal)
                    || spec.capture.targetFps != 60))
                errors.Add($"{spec.id}: baseline must be iPhone 13 at 60 fps");
            if (spec.layers == null)
                return;
            var hasCore = false;
            var hasDirectional = false;
            var hasImpact = false;
            foreach (var layer in spec.layers)
            {
                if (layer == null || string.IsNullOrWhiteSpace(layer.name))
                {
                    errors.Add($"{spec.id}: layer name is empty");
                    continue;
                }
                if (layer.start < 0f || layer.end > 1f || layer.start >= layer.end)
                    errors.Add($"{spec.id}/{layer.name}: invalid normalized layer range");
                hasCore |= layer.role == "core";
                hasDirectional |= layer.role == "direction" || layer.role == "trail";
                hasImpact |= layer.role == "impact-front" || layer.role == "impact-back";
                if (!SpellBackends.CanResolve(layer, out var reason))
                    errors.Add($"{spec.id}/{layer.name}: {reason}");
            }
            if (!hasCore)
                errors.Add($"{spec.id}: requires a core layer");
            if (!hasDirectional && (spec.archetype == "projectile" || spec.archetype == "slash" || spec.archetype == "beam" || spec.archetype == "summon"))
                errors.Add($"{spec.id}: moving archetype requires direction/trail layer");
            if (!hasImpact)
                errors.Add($"{spec.id}: requires an impact-front or impact-back layer");
        }
    }
}
