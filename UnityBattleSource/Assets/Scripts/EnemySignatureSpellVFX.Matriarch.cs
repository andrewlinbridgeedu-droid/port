using UnityEngine;

public sealed partial class EnemySignatureSpellVFX
{
    MainlineSilkRound2 crimsonProjection;
    // Owns only presentation. The existing Play coroutine still owns release,
    // contact and cancellation; all meshes live beneath that coroutine's root.
    private void CrimsonSpectacle(int variant, int phase, float p, Vector3 s, Vector3 t,float rawPhaseProgress)
    {
        if (!crimsonProjection || crimsonProjection.transform.parent != root.transform)
        {
            var go = new GameObject("Crimson spatial spell choreography");
            go.transform.SetParent(root.transform, false);
            crimsonProjection = go.AddComponent<MainlineSilkRound2>();
        }
        crimsonProjection.Sample(variant, phase, p, s, t,rawPhaseProgress);
        // Small authored smoke punctuation leaves the woven and metal volumes
        // readable; no screen projection, panel, tidal wall or large light plate.
        if (phase == 2)
        {
            float fade = Mathf.Pow(1-p, 1.7f);
            for (int i=0;i<5;i++)
            {
                Vector3 offset = cameraRight*(Noise(i+21)-.5f)*2.6f
                    + forward*(Noise(i+43)-.5f)*1.4f + Vector3.up*(.05f+p*.35f);
                Vapor(t-Vector3.up*.7f+offset*(.2f+Mathf.Sqrt(p)*1.7f), .36f+p*.55f,
                    new Color(.18f,.018f,.045f), fade*.33f, i, p);
            }
            Radiance(t, .58f+p*.62f, new Color(1,.20f,.30f), fade*.72f);
        }
    }
}
