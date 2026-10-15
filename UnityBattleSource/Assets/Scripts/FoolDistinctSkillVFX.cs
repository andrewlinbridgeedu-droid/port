using System.Collections;
using System.Collections.Generic;
using UnityEngine;

/// Target-side card marks for investigation-two skills. Native combat owns the
/// state; this component only renders the identity/evidence vocabulary.
public sealed class FoolDistinctSkillVFX : MonoBehaviour
{
    readonly List<GameObject> roots = new();
    readonly List<Object> owned = new();
    int playback;

    public IEnumerator Play(string skillID, System.Func<Vector3> caster, System.Func<Vector3> target, System.Action onContact = null)
    {
        _ = caster;
        Stop();
        var token = ++playback;
        var point = target();
        if (skillID == "fool_skill_04") yield return IdentityDisplacement(token, point, onContact);
        else if (skillID == "fool_skill_05") yield return FabricatedEvidence(token, point, onContact);
    }

    public void Stop()
    {
        playback++;
        foreach (var root in roots) if (root) Destroy(root);
        roots.Clear();
        foreach (var item in owned) if (item) Destroy(item);
        owned.Clear();
    }

    IEnumerator IdentityDisplacement(int token, Vector3 point, System.Action onContact)
    {
        var root = Root("VFX · 张冠李戴");
        var eyeA = SpriteLayer(root.transform, "Effects/Fool/MaskedEye", "误认影 · 蓝");
        var eyeB = SpriteLayer(root.transform, "Effects/Fool/MaskedEye", "误认影 · 紫");
        var rift = SpriteLayer(root.transform, "Effects/Fool/CurtainRift", "身份断裂");
        FaceCamera(eyeA, eyeB, rift);
        var elapsed = 0f;
        const float duration = 1.05f;
        var didContact = false;
        while (elapsed < duration && token == playback && root)
        {
            elapsed += Time.deltaTime;
            var t = Mathf.Clamp01(elapsed / duration);
            var pulse = Mathf.Sin(t * Mathf.PI);
            var drift = Mathf.Sin(t * Mathf.PI * 2f) * .22f;
            eyeA.transform.position = point + new Vector3(-drift, .10f + pulse * .08f, 0f);
            eyeB.transform.position = point + new Vector3(drift, -.08f - pulse * .06f, 0f);
            eyeA.transform.localScale = Vector3.one * (.42f + pulse * .16f);
            eyeB.transform.localScale = Vector3.one * (.36f + pulse * .20f);
            rift.transform.position = point + Vector3.up * .02f;
            rift.transform.localScale = Vector3.one * (pulse * .72f);
            SetAlpha(eyeA, pulse * .72f);
            SetAlpha(eyeB, pulse * .62f);
            SetAlpha(rift, pulse * .78f);
            if (!didContact && t >= .42f) { didContact = true; onContact?.Invoke(); }
            yield return null;
        }
        StopRoot(root);
    }

    IEnumerator FabricatedEvidence(int token, Vector3 point, System.Action onContact)
    {
        var root = Root("VFX · 伪证烙印");
        var writing = SpriteLayer(root.transform, "Effects/Fool/CurtainRift", "证词写入");
        var stamp = SpriteLayer(root.transform, "Effects/Fool/MaskedEye", "伪证封印");
        FaceCamera(writing, stamp);
        var seal = Line(root.transform, new Color(1f, .25f, .62f, .95f), .022f);
        var elapsed = 0f;
        const float duration = .95f;
        var didContact = false;
        while (elapsed < duration && token == playback && root)
        {
            elapsed += Time.deltaTime;
            var t = Mathf.Clamp01(elapsed / duration);
            var write = Mathf.SmoothStep(0f, 1f, Mathf.Clamp01(t / .46f));
            var drop = Mathf.SmoothStep(0f, 1f, Mathf.Clamp01((t - .38f) / .25f));
            writing.transform.position = point + Vector3.up * .12f;
            writing.transform.localScale = Vector3.one * (.24f + write * .48f);
            stamp.transform.position = point + Vector3.up * (.90f - drop * .82f);
            stamp.transform.localScale = Vector3.one * (.30f + drop * .20f);
            SetAlpha(writing, write * (1f - Mathf.Clamp01((t - .72f) / .28f)));
            SetAlpha(stamp, Mathf.Clamp01(drop * 1.5f) * (1f - Mathf.Clamp01((t - .78f) / .22f)));
            var radius = Mathf.Lerp(.04f, .52f, write);
            seal.positionCount = 13;
            for (var i = 0; i < seal.positionCount; i++)
            {
                var a = i / 12f * Mathf.PI * 2f;
                seal.SetPosition(i, point + Vector3.up * .12f + new Vector3(Mathf.Cos(a) * radius, Mathf.Sin(a) * radius, 0f));
            }
            seal.startColor = seal.endColor = new Color(1f, .25f, .62f, write * (1f - Mathf.Clamp01((t - .70f) / .30f)));
            if (!didContact && drop >= .86f) { didContact = true; onContact?.Invoke(); }
            yield return null;
        }
        StopRoot(root);
    }

    GameObject Root(string name) { var root = new GameObject(name); roots.Add(root); return root; }

    SpriteRenderer SpriteLayer(Transform parent, string resource, string name)
    {
        var texture = Resources.Load<Texture2D>(resource);
        var go = new GameObject(name);
        go.transform.SetParent(parent, false);
        var renderer = go.AddComponent<SpriteRenderer>();
        if (texture)
        {
            var sprite = Sprite.Create(texture, new Rect(0f, 0f, texture.width, texture.height), new Vector2(.5f, .5f), 512f);
            renderer.sprite = sprite;
            owned.Add(sprite);
        }
        var material = new Material(Shader.Find("Sprites/Default"));
        renderer.material = material;
        owned.Add(material);
        return renderer;
    }

    LineRenderer Line(Transform parent, Color color, float width)
    {
        var go = new GameObject("证据烙印轨迹");
        go.transform.SetParent(parent, false);
        var line = go.AddComponent<LineRenderer>();
        line.material = new Material(Shader.Find("Sprites/Default"));
        owned.Add(line.material);
        line.startColor = line.endColor = color;
        line.startWidth = line.endWidth = width;
        line.numCapVertices = 3;
        return line;
    }

    static void FaceCamera(params SpriteRenderer[] sprites)
    {
        var camera = Camera.main;
        if (!camera) return;
        foreach (var sprite in sprites) if (sprite) sprite.transform.rotation = camera.transform.rotation;
    }

    static void SetAlpha(SpriteRenderer renderer, float alpha)
    {
        if (!renderer) return;
        var color = renderer.color;
        color.a = alpha;
        renderer.color = color;
    }

    void StopRoot(GameObject root)
    {
        if (!roots.Remove(root)) return;
        if (root) Destroy(root);
        if (roots.Count > 0) return;
        foreach (var item in owned) if (item) Destroy(item);
        owned.Clear();
    }

    void OnDisable() => Stop();
    void OnDestroy() => Stop();
}
