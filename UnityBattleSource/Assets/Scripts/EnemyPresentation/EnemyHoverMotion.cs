using UnityEngine;

/// Reusable deterministic hover. This component owns only MotionRoot.localPosition.
public sealed class EnemyHoverMotion : MonoBehaviour
{
    const float MinimumSafePeriod = 0.0001f;

    [SerializeField, Min(0f)] float amplitude;
    [SerializeField] float period = 4.2f;

    Vector3 baselineLocalPosition;
    double startedAt;
    bool baselineCaptured;
    bool motionRunning;

    public float Amplitude => amplitude;
    public float Period => period;
    public Vector3 BaselineLocalPosition => baselineLocalPosition;
    public bool MotionRunning => motionRunning;

    public void Configure(float hoverAmplitude, float hoverPeriod)
    {
        amplitude = !float.IsNaN(hoverAmplitude) && !float.IsInfinity(hoverAmplitude)
            ? Mathf.Max(0f, hoverAmplitude)
            : 0f;
        period = !float.IsNaN(hoverPeriod) && !float.IsInfinity(hoverPeriod)
            ? hoverPeriod
            : 0f;
    }

    public void CaptureBaseline()
    {
        baselineLocalPosition = transform.localPosition;
        baselineCaptured = true;
    }

    public void CaptureBaselineAndEnable()
    {
        CaptureBaseline();
        startedAt = Time.timeAsDouble;
        motionRunning = amplitude > 0f && period > MinimumSafePeriod;
        enabled = motionRunning;
        if (!motionRunning)
            transform.localPosition = baselineLocalPosition;
    }

    public void StopAndReset()
    {
        motionRunning = false;
        enabled = false;
        if (baselineCaptured)
            transform.localPosition = baselineLocalPosition;
    }

    public void EvaluateAtElapsed(float elapsed)
    {
        if (!baselineCaptured)
            CaptureBaseline();

        var offset = 0f;
        if (amplitude > 0f && period > MinimumSafePeriod)
        {
            var phase = elapsed * Mathf.PI * 2f / period;
            offset = Mathf.Sin(phase) * amplitude;
        }

        transform.localPosition = new Vector3(
            baselineLocalPosition.x,
            baselineLocalPosition.y + offset,
            baselineLocalPosition.z);
    }

    void Update()
    {
        if (!motionRunning) return;
        EvaluateAtElapsed((float)(Time.timeAsDouble - startedAt));
    }
}
