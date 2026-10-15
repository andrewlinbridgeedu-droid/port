using System;
using UnityEngine;

/// 2026-10-03, the user on the phone: 你很多都设置成这样弯弯的，都改掉吧. The older spell
/// scripts draw ribbons and tubes along authored curves full of sine waves and sweeps; every
/// helper that builds one passes its curve through here first. A curve keeps only a share of
/// its deviation from the straight chord between its ends, so waves and sweeps become straight
/// or gently bowed strokes. A curve whose ends meet (a ring or a loop) is shrunk toward its own
/// centre instead, so it reads as a small knot of light rather than a ring. Presentation only.
///
/// 2026-10-07 night, the user: 你很多这些一条条的 ... 做完所有98组. The spectacle layer now
/// draws every spell with objects and smoke (SpellSpectacle20260926.SolidAll); while it does,
/// the older scripts' ribbons and tubes are collapsed to nothing here, so their bands no
/// longer stand over the new objects. Their timing, contacts and other parts are untouched.
public static class StraightLines20261003
{
    public const float Kept = .3f;

    /// The older scripts' bands are hidden (the spectacle layer draws the spell instead).
    public static bool Hidden => SpellSpectacle20260926.HidesLegacyBands;

    public static Func<float, Vector3> Flatten(Func<float, Vector3> curve, float kept = Kept)
    {
        if (curve == null) return null;
        if (Hidden) { var start = curve(0f); return q => start + (curve(q) - start) * 1e-4f; }
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
        if (Hidden)
        {
            for (int i = 0; i < count; i++) outPoints[i] = points[0] + (points[i] - points[0]) * 1e-4f;
            return outPoints;
        }
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
