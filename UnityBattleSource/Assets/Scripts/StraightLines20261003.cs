using System;
using UnityEngine;

/// 2026-10-03, the user on the phone: 你很多都设置成这样弯弯的，都改掉吧. The older spell
/// scripts draw ribbons and tubes along authored curves full of sine waves and sweeps; every
/// helper that builds one passes its curve through here first. A curve keeps only a share of
/// its deviation from the straight chord between its ends, so waves and sweeps become straight
/// or gently bowed strokes. A curve whose ends meet (a ring or a loop) is shrunk toward its own
/// centre instead, so it reads as a small knot of light rather than a ring. Presentation only.
public static class StraightLines20261003
{
    public const float Kept = .3f;

    public static Func<float, Vector3> Flatten(Func<float, Vector3> curve, float kept = Kept)
    {
        if (curve == null) return null;
        Vector3 a = curve(0f), b = curve(1f), centre = Vector3.zero;
        for (int i = 0; i <= 8; i++) centre += curve(i / 8f);
        centre /= 9f;
        float extent = 0f;
        for (int i = 0; i <= 8; i++) extent = Mathf.Max(extent, (curve(i / 8f) - centre).magnitude);
        if ((b - a).magnitude < .35f * extent) return q => centre + (curve(q) - centre) * .45f;
        return q => { var chord = Vector3.Lerp(a, b, q); return chord + (curve(q) - chord) * kept; };
    }

    static readonly Vector3[][] pool = new Vector3[8][];
    static int next;

    /// A flattened copy of the first <paramref name="count"/> points; the source is untouched
    /// (some scripts carry their points from frame to frame).
    public static Vector3[] Flattened(Vector3[] points, int count, float kept = Kept)
    {
        if (points == null || count < 3) return points;
        next = (next + 1) % pool.Length;
        if (pool[next] == null || pool[next].Length < count) pool[next] = new Vector3[Mathf.Max(count, 64)];
        var outPoints = pool[next];
        Vector3 a = points[0], b = points[count - 1], centre = Vector3.zero;
        for (int i = 0; i < count; i++) centre += points[i];
        centre /= count;
        float extent = 0f;
        for (int i = 0; i < count; i++) extent = Mathf.Max(extent, (points[i] - centre).magnitude);
        bool closed = (b - a).magnitude < .35f * extent;
        for (int i = 0; i < count; i++)
        {
            if (closed) { outPoints[i] = centre + (points[i] - centre) * .45f; continue; }
            var chord = Vector3.Lerp(a, b, i / (count - 1f));
            outPoints[i] = chord + (points[i] - chord) * kept;
        }
        return outPoints;
    }
}
