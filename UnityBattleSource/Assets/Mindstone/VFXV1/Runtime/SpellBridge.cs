using System;
using System.Collections;
using UnityEngine;

namespace Mindstone.VFXV1
{
    public sealed class SpellBridge : MonoBehaviour
    {
        SpellRuntime runtime;

        public SpellRuntime Runtime
        {
            get
            {
                if (runtime == null)
                    runtime = GetComponent<SpellRuntime>() ?? gameObject.AddComponent<SpellRuntime>();
                return runtime;
            }
        }

        public bool CanPlay(string id) => SpellRegistry.Contains(id);

        public IEnumerator Play(
            string id,
            Func<Vector3> source,
            Func<Vector3> target,
            Func<Vector3> weapon = null,
            Func<Vector3> mouth = null,
            Func<Vector3> impact = null,
            Func<Vector3> ground = null,
            int? seed = null,
            Action onContact = null,
            float? contactTime = null)
        {
            var context = new SpellContext
            {
                source = source,
                target = target,
                weapon = weapon,
                mouth = mouth,
                impact = impact ?? target,
                ground = ground ?? target,
                camera = Camera.main,
                onContact = onContact,
                contactTime = contactTime,
                seed = seed
            };
            var handle = Runtime.Play(id, context);
            while (Runtime.IsPlaying(handle))
                yield return null;
        }

        public void Stop() => runtime?.StopAll();

        public static bool TryGetCaptureTimes(string id, out float[] times)
        {
            if (SpellRegistry.TryGet(id, out var spec)
                && spec.capture != null && spec.capture.times != null
                && spec.capture.times.Length == 5)
            {
                times = (float[])spec.capture.times.Clone();
                return true;
            }
            times = null;
            return false;
        }

        public static float Duration(string id, float fallback = 2f)
        {
            return SpellRegistry.TryGet(id, out var spec)
                ? spec.Duration + Mathf.Max(0f, spec.cleanupSeconds)
                : fallback;
        }

        public static bool TryGetShowcase(string id, out SpellShowcaseSpec showcase)
        {
            if (SpellRegistry.TryGet(id, out var spec) && spec.showcase != null)
            {
                showcase = spec.showcase;
                return true;
            }
            showcase = null;
            return false;
        }
    }
}
