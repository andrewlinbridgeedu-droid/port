using System;
using UnityEngine;

// A visual for one authoritative status instance. It has no expiration rule,
// hit/contact callback or target search. ChurchStatusPresentation owns removal.
public sealed class TowerStatusRound2 : MonoBehaviour
{
    Func<Vector3> target;
    Func<bool> valid;
    bool poison;
    float elapsed;
    public float intensity = 1;
    TowerSurfaceRound2 folds, threads;
    public static TowerStatusRound2 Create(bool poison, Func<Vector3> target, Func<bool> valid = null)
    {
        var go = new GameObject(poison ? "Finite tower poison folds round 2" : "Single beneficiary crown round 2");
        var v = go.AddComponent<TowerStatusRound2>(); v.poison = poison; v.target = target; v.valid = valid;
        v.folds = new TowerSurfaceRound2(go.transform, 4, "ChurchSpellArt/" + (poison ? "venom" : "corona"), false, poison ? .22f : .28f);
        v.threads = new TowerSurfaceRound2(go.transform, 6, "Effects/Mistport/Official/Slashing/Line01", true);
        return v;
    }
    void Update()
    {
        folds.Hide(); threads.Hide();
        if (target == null || valid != null && !valid()) return;
        elapsed += Time.deltaTime;
        Vector3 center = target(); var face = TowerSurfaceRound2.Face;
        if (poison)
        {
            // Three short descending wet folds leave visible gaps and stay on
            // the player. The arena environment is never tinted or filled.
            for (int i = 0; i < 3; i++)
            {
                float phase = Mathf.Repeat(elapsed * (.27f + i * .017f) + i * .31f, 1);
                float side = i % 2 == 0 ? -1 : 1;
                Vector3 p = center + face * new Vector3(side * (.29f + .06f * Mathf.Sin(elapsed * 1.9f + i)), .37f - phase * .84f, -.12f + i * .035f);
                folds.Leaf(i, p, face * Quaternion.Euler(0, side * 32, side * (19 + 7 * Mathf.Sin(elapsed * 1.4f + i))),
                    new Vector2(.55f + phase * .17f, 1.13f), new Color(.65f, .83f, .28f),
                    (.43f + .12f * Mathf.Sin(phase * Mathf.PI)) * intensity, elapsed, .36f);
                int k = i;
                threads.Stroke(i, q => p + face * new Vector3(Mathf.Sin(q * 5.3f + k) * .11f, (q - .5f) * .56f, -.015f),
                    .024f, new Color(.68f, .95f, .34f), .38f * intensity, elapsed);
            }
        }
        else
        {
            // Four staggered frill leaves descend from shoulders to chest on
            // one receiver. They breathe in place, leaving an open center and
            // never forming a full halo or repeating a damage burst.
            for (int i = 0; i < 4; i++)
            {
                float side = i % 2 == 0 ? -1 : 1;
                float breathe = .93f + .07f * Mathf.Sin(elapsed * 2.8f - i * .9f);
                Vector3 p = center + face * new Vector3(side * (.38f + (i >= 2 ? .10f : 0)), i >= 2 ? -.13f : .59f + (i == 1 ? .12f : 0), -.42f + i * .025f);
                folds.Leaf(i, p, face * Quaternion.Euler(0, side * 29, side * (i >= 2 ? 49 : 31)), new Vector2(1.07f + (i >= 2 ? .10f : 0), 1.30f + (i % 2) * .13f) * breathe,
                    i == 1 ? new Color(1, .91f, .68f) : new Color(1, .65f, .79f), .88f * intensity, elapsed, .39f,
                    new Rect(i % 2 == 0 ? 0 : .5f, 0, .5f, 1));
                int k = i;
                threads.Stroke(i, q => p + face * new Vector3(Mathf.Sin(q * (3.7f + k * .2f) + k) * .14f, (q - .5f) * (.79f + k * .06f), -.035f),
                    .026f, new Color(1, .89f, .64f), (.49f + .18f * Mathf.Sin(elapsed * 4 - i)) * intensity, elapsed);
            }
        }
    }
    void OnDisable() { folds?.Hide(); threads?.Hide(); }
    void OnDestroy() { folds?.Dispose(); threads?.Dispose(); }
}
