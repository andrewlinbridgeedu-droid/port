using UnityEngine;

/// Authored pinned-waist cloth shapes; left/right respond with separate lag.
[DefaultExecutionOrder(100)]
public sealed class FoolRibbonFlutter : MonoBehaviour
{
    SkinnedMeshRenderer[] ribbons;
    FoolSkillChoreography choreography;
    bool wasCasting;
    float releasedAt = -100f;
    void Awake()
    {
        ribbons = GetComponentsInChildren<SkinnedMeshRenderer>(true);
        choreography = GetComponent<FoolSkillChoreography>();
    }
    void LateUpdate()
    {
        if (!choreography) choreography = GetComponent<FoolSkillChoreography>();
        bool casting = choreography && choreography.IsPlaying;
        // A small damped release uses only the existing free-end morphs.
        // No bone pose, root translation or contact timing is touched.
        if (wasCasting && !casting) releasedAt = Time.time;
        wasCasting = casting;
        SampleWind(Time.time);
    }
    public void SampleWind(float seconds)
    {
        if (ribbons == null) ribbons = GetComponentsInChildren<SkinnedMeshRenderer>(true);
        float phase = seconds * (Mathf.PI * 2f / 4.8f);
        float elapsed = Mathf.Max(0, seconds - releasedAt);
        float release = .12f * Mathf.Exp(-elapsed * 2.4f) * Mathf.Sin(elapsed * 7f);
        foreach (var ribbon in ribbons)
        {
            if (!ribbon || !ribbon.sharedMesh || !ribbon.name.StartsWith("FoolRibbon")) continue;
            bool right = ribbon.name.Contains("Right");
            float sidePhase = right ? .62f : -.24f;
            float gust = .70f + .17f * Mathf.Sin(seconds * .43f + sidePhase);
            float sweep = phase + sidePhase + .12f * Mathf.Sin(seconds * .31f + sidePhase);
            for (int i = 0; i < ribbon.sharedMesh.blendShapeCount; i++)
            {
                string shape = ribbon.sharedMesh.GetBlendShapeName(i);
                bool curl = shape.Contains("Edge curl");
                float harmonic = curl ? sweep * 1.83f - .45f : sweep;
                float response = curl ? .73f : 1f;
                float wave = shape.Contains("cosine") ? Mathf.Cos(harmonic) : Mathf.Sin(harmonic);
                ribbon.SetBlendShapeWeight(i, 100f * response * Mathf.Clamp(gust * wave + release * (right ? -.8f : 1f), -1f, 1f));
            }
        }
    }
    void OnDisable()
    {
        wasCasting = false;
        releasedAt = -100f;
        if (ribbons == null) return;
        foreach (var ribbon in ribbons)
            if (ribbon && ribbon.sharedMesh && ribbon.name.StartsWith("FoolRibbon"))
                for (int i = 0; i < ribbon.sharedMesh.blendShapeCount; i++) ribbon.SetBlendShapeWeight(i, 0);
    }
}
