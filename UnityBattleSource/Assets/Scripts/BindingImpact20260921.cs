using UnityEngine;

// Five-frame contact hold and broken filigree release. Damage keeps its own clock.
public sealed class BindingImpact20260921 : MonoBehaviour
{
    public const float Hold = .166667f;
    BountySurfaceRound2 matter;
    public int VisibleSurfaceCount => matter && matter.GetComponent<MeshFilter>().sharedMesh.vertexCount > 0 ? 1 : 0;
    public static float Expansion(float post)
    {
        float release = post - Hold;
        return release < 0 ? 0 : Mathf.SmoothStep(0, 1, release / .045f)
            * Mathf.Exp(-Mathf.Max(0, release - .045f) * 13);
    }
    public static float Motion(float age, float contact)
        => age <= contact ? age : age < contact + Hold ? contact
            : contact + (age - contact - Hold) * 1.8f;

    void Awake()
    {
        var child = new GameObject("Open filigree fracture");
        child.transform.SetParent(transform, false);
        matter = child.AddComponent<BountySurfaceRound2>();
        matter.Configure("b02");
    }

    public void Draw(Vector3 point, float post, bool held)
    {
        if (!matter) return;
        if (held || post < 0) { matter.Clear(); return; }
        float release = Mathf.Max(0, post - Hold);
        float bloom = Expansion(post);
        float fade = 1 - Mathf.SmoothStep(0, 1, Mathf.Max(0, post - Hold) / .32f);
        Vector3 right = Camera.main ? Camera.main.transform.right : Vector3.right;
        Vector3 up = Camera.main ? Camera.main.transform.up : Vector3.up;
        Vector3 depth = Camera.main ? Camera.main.transform.forward : Vector3.forward;
        Vector3 center = point + up * .16f;
        matter.Begin(post);
        for (int k = 0; k < 4; k++) {
            float lane = k, sign = k % 2 == 0 ? -1 : 1;
            matter.Ribbon(q => center
                    + right * (sign * (.27f + q * (.30f + bloom * (.55f + lane * .12f))))
                    + up * ((q - .5f) * (.70f + bloom * (.46f + lane * .11f))
                        + Mathf.Sin(q * (4.9f + lane * .4f) + lane * 1.8f) * (.08f + bloom * .11f))
                    + depth * (Mathf.Sin(q * 4.1f + lane * 2.1f) * (.17f + bloom * .15f)
                        + lane * .07f),
                up, (.15f + bloom * .13f) * fade, .86f,
                k == 1 ? new Color(1, .90f, .56f, fade) : new Color(1, .65f, .22f, fade),
                lane * 2.8f + post * .2f, .74f,
                silhouette: BountySurfaceRound2.Silhouette.Plate);
        }
        if (post >= Hold) matter.Spray(center, right, up, depth, release,
            3.0f, 12, new Color(1, .84f, .42f, fade), 4.6f);
        matter.End(1, 1.36f);
    }
}
