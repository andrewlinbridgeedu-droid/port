using UnityEngine;

/// Local illumination links a spell's luminous volume to the real actor surfaces.
/// It never changes ambient light, exposure, background or gameplay state.
public sealed class SpellSceneLighting : MonoBehaviour
{
    Light pulse;
    public void Draw(Vector3 center, Color color, float strength, float radius)
    {
        if (strength <= .001f) { if (pulse) pulse.enabled = false; return; }
        if (!pulse)
        {
            var go = new GameObject("Spell surface light (temporary)");
            go.transform.SetParent(transform, false);
            pulse = go.AddComponent<Light>();
            pulse.type = LightType.Point;
            pulse.renderMode = LightRenderMode.ForcePixel;
            pulse.shadows = LightShadows.None;
            pulse.bounceIntensity = 0;
        }
        pulse.enabled = true;
        pulse.transform.position = center;
        pulse.color = color;
        // Capped lower: a 5x point light bleached the pale marble around hero peaks.
        pulse.intensity = Mathf.Clamp(strength, 0, 2.6f);
        pulse.range = Mathf.Clamp(radius, .1f, 10);
    }
    public void Clear()
    {
        if (pulse) { pulse.enabled = false; Destroy(pulse.gameObject); }
        pulse = null;
    }
    void OnDisable() { Clear(); }
    void OnDestroy() { Clear(); }
}
