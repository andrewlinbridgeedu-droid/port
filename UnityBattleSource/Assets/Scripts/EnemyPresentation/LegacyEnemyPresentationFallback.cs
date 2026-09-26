using UnityEngine;

/// Isolated compatibility for pre-profile scenes. New installations and normal
/// runtime presentation must resolve EnemyHandle/Profile data instead.
public static class LegacyEnemyPresentationFallback
{
    public static void FindLegacyEnemies(out GameObject guard, out GameObject core)
    {
        guard = GameObject.Find("ClockGuard_Imported");
        core = GameObject.Find("ClockCore_Imported");
        if (core != null) return;

        var candidates = Resources.FindObjectsOfTypeAll<GameObject>();
        for (var i = 0; i < candidates.Length; i++)
        {
            if (candidates[i].name != "ClockCore_Imported") continue;
            core = candidates[i];
            return;
        }
    }

    public static Vector3 ApplyGuardOnly(GameObject guard)
    {
        var home = GroundedAt(guard, new Vector3(0f, 0f, 12f));
        guard.transform.SetPositionAndRotation(home, Quaternion.Euler(0f, 180f, 0f));
        return home;
    }

    public static Vector3 ApplyGuardAndCore(GameObject guard, GameObject core)
    {
        var guardHome = GroundedAt(guard, new Vector3(0.75f, 0f, 9.0f));
        guard.transform.SetPositionAndRotation(guardHome, Quaternion.Euler(0f, 180f, 0f));

        core.SetActive(false);
        core.transform.localScale = Vector3.one;
        core.transform.rotation =
            Quaternion.Euler(-15f, 0f, 0f)
            * Quaternion.Euler(0f, 90f, 0f)
            * Quaternion.AngleAxis(90f, Vector3.forward)
            * Quaternion.Euler(0f, 90f, 0f);
        ScaleToHeightRatio(core, guard, 0.496f);
        core.transform.position = GroundedAt(core, new Vector3(-1.8f, 1.15f, 17f));
        core.SetActive(true);
        return guardHome;
    }

    static Vector3 GroundedAt(GameObject character, Vector3 position)
    {
        character.transform.position = position;
        var renderers = character.GetComponentsInChildren<Renderer>(true);
        if (renderers.Length == 0) return position;
        var bounds = renderers[0].bounds;
        for (var i = 1; i < renderers.Length; i++) bounds.Encapsulate(renderers[i].bounds);
        return position + Vector3.up * (position.y - bounds.min.y);
    }

    static void ScaleToHeightRatio(GameObject subject, GameObject reference, float ratio)
    {
        var subjectRenderers = subject.GetComponentsInChildren<Renderer>(true);
        var referenceRenderers = reference.GetComponentsInChildren<Renderer>(true);
        if (subjectRenderers.Length == 0 || referenceRenderers.Length == 0) return;

        var subjectBounds = subjectRenderers[0].bounds;
        for (var i = 1; i < subjectRenderers.Length; i++) subjectBounds.Encapsulate(subjectRenderers[i].bounds);
        var referenceBounds = referenceRenderers[0].bounds;
        for (var i = 1; i < referenceRenderers.Length; i++) referenceBounds.Encapsulate(referenceRenderers[i].bounds);
        if (subjectBounds.size.y <= 0.001f) return;
        subject.transform.localScale *= referenceBounds.size.y * ratio / subjectBounds.size.y;
    }
}
