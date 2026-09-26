using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

/// Presentation for Paper Double. Swift remains authoritative for redirect rules.
public sealed class FoolDefenseVFX : MonoBehaviour
{
    static readonly Color Violet = new(0.62f, 0.24f, 1f, 1f);
    static readonly Color Gold = new(1f, 0.72f, 0.22f, 1f);
    static readonly Vector3 PaperDepthOffset = new(0f, 0f, -0.35f);
    const float PaperFragmentDuration = 1.05f;
    readonly List<UnityEngine.Object> transientAssets = new();
    readonly List<GameObject> presentationRoots = new();
    int presentationGeneration;
    Coroutine deployedRoutine;
    GameObject deployedRoot;
    bool consumeDeployedPaper;
    bool paperDoubleArmed;

    public bool IsDeployed => deployedRoutine != null;
    public bool IsArmed => paperDoubleArmed;

    /// Arms the relic without putting a second player silhouette into the
    /// scene. The paper person is materialized only at the lethal contact beat.
    public void Arm()
    {
        if (deployedRoutine == null)
            paperDoubleArmed = true;
    }

    public void ResetArmedState() => paperDoubleArmed = false;

    public void ResetPresentation()
    {
        presentationGeneration++;
        if (deployedRoutine != null)
            StopCoroutine(deployedRoutine);
        deployedRoutine = null;
        consumeDeployedPaper = false;
        paperDoubleArmed = false;
        if (deployedRoot != null)
            Destroy(deployedRoot);
        deployedRoot = null;
        for (var index = 0; index < presentationRoots.Count; index++)
            if (presentationRoots[index] != null)
                Destroy(presentationRoots[index]);
        presentationRoots.Clear();
        ReleaseTransientAssets();
    }

    public void Deploy(Func<Vector3> anchor)
    {
        if (deployedRoutine != null) return;
        paperDoubleArmed = false;
        consumeDeployedPaper = false;
        deployedRoutine = StartCoroutine(PlayDeployed(anchor));
    }

    public void Consume()
    {
        if (deployedRoutine != null) consumeDeployedPaper = true;
    }

    public IEnumerator WaitForCompletion()
    {
        while (deployedRoutine != null)
            yield return null;
    }

    IEnumerator PlayDeployed(Func<Vector3> anchor)
    {
        var texture = Resources.Load<Texture2D>("VFX/Fool/paper_effigy_v1");
        if (texture == null)
        {
            Debug.LogError("Paper Double texture is missing.");
            deployedRoutine = null;
            paperDoubleArmed = false;
            yield break;
        }
        var sprite = Sprite.Create(texture, new Rect(0, 0, texture.width, texture.height), new Vector2(0.5f, 0.5f), 620f);
        transientAssets.Add(sprite);
        var root = new GameObject("VFX · 已部署纸人代身");
        deployedRoot = root;
        presentationRoots.Add(root);
        var glowBack = CreatePaperLayer(root.transform, "纸偶紫色虚影", sprite, Violet, 0.12f, 58);
        glowBack.transform.localScale = Vector3.one * 1.10f;
        var glowGold = CreatePaperLayer(root.transform, "纸偶金色残影", sprite, Gold, 0.07f, 59);
        glowGold.transform.localScale = Vector3.one * 1.045f;
        var paper = CreatePaperLayer(root.transform, "纸偶主体", sprite, Color.white, 0f, 60);
        var motes = CreateMotes(root.transform);

        var elapsed = 0f;
        while (elapsed < 0.28f)
        {
            elapsed += Time.deltaTime;
            var t = Mathf.SmoothStep(0f, 1f, elapsed / 0.28f);
            root.transform.position = PaperPosition(anchor());
            root.transform.localScale = Vector3.one * Mathf.Lerp(0.35f, 1f, t);
            SetAlpha(paper, t * 0.58f);
            SetAlpha(glowBack, t * 0.26f);
            SetAlpha(glowGold, t * 0.12f);
            yield return null;
        }

        elapsed = 0f;
        while (!consumeDeployedPaper && elapsed < 12f)
        {
            elapsed += Time.deltaTime;
            var pulse = (Mathf.Sin(elapsed * 5.2f) + 1f) * 0.5f;
            root.transform.position = PaperPosition(anchor())
                + Vector3.up * (Mathf.Sin(elapsed * 3.2f) * 0.025f);
            SetAlpha(paper, Mathf.Lerp(0.43f, 0.61f, pulse));
            SetAlpha(glowBack, Mathf.Lerp(0.10f, 0.30f, pulse));
            SetAlpha(glowGold, Mathf.Lerp(0.05f, 0.15f, 1f - pulse));
            glowBack.transform.localPosition = new Vector3(Mathf.Sin(elapsed * 8f) * 0.016f, 0f, 0f);
            glowGold.transform.localPosition = new Vector3(-Mathf.Sin(elapsed * 6.5f) * 0.012f, 0f, 0f);
            yield return null;
        }

        if (consumeDeployedPaper)
        {
            SetColor(paper, new Color(1f, 0.94f, 1f, 0.98f));
            CreateImpactFlash(root.transform);
            elapsed = 0f;
            while (elapsed < 0.18f)
            {
                elapsed += Time.deltaTime;
                var shake = (1f - elapsed / 0.18f) * 0.035f;
                root.transform.position = PaperPosition(anchor()) + new Vector3(
                    Mathf.Sin(elapsed * 95f) * shake,
                    Mathf.Cos(elapsed * 83f) * shake,
                    0f);
                yield return null;
            }
            CreatePaperFragments(root.transform.position, texture);
            paper.enabled = glowBack.enabled = glowGold.enabled = false;
            motes.Stop(true, ParticleSystemStopBehavior.StopEmitting);
            // Keep the routine alive until the last delayed shard has finished
            // drifting, so the host can restore the player on the real visual
            // cleanup boundary rather than during the paper break.
            yield return new WaitForSeconds(PaperFragmentDuration + 0.10f);
        }
        else
        {
            motes.Stop(true, ParticleSystemStopBehavior.StopEmitting);
        }

        presentationRoots.Remove(root);
        Destroy(root);
        deployedRoot = null;
        ReleaseTransientAssets();
        deployedRoutine = null;
        consumeDeployedPaper = false;
        paperDoubleArmed = false;
    }

    public IEnumerator Play(Func<Vector3> anchor, bool previewImpact = false)
    {
        var generation = presentationGeneration;
        var texture = Resources.Load<Texture2D>("VFX/Fool/paper_effigy_v1");
        if (texture == null)
        {
            Debug.LogError("Paper Double texture is missing.");
            yield break;
        }

        var sprite = Sprite.Create(texture, new Rect(0, 0, texture.width, texture.height), new Vector2(0.5f, 0.5f), 620f);
        transientAssets.Add(sprite);
        var root = new GameObject("VFX · 纸人代身");
        presentationRoots.Add(root);
        root.transform.position = PaperPosition(anchor());

        var glowBack = CreatePaperLayer(root.transform, "紫色虚影", sprite, Violet, 0.12f, 58);
        glowBack.transform.localScale = Vector3.one * 1.10f;
        var glowGold = CreatePaperLayer(root.transform, "金色残影", sprite, Gold, 0.07f, 59);
        glowGold.transform.localScale = Vector3.one * 1.045f;
        var paper = CreatePaperLayer(root.transform, "纸偶主体", sprite, Color.white, 0f, 60);
        var motes = CreateMotes(root.transform);

        var elapsed = 0f;
        while (generation == presentationGeneration && elapsed < 0.22f)
        {
            elapsed += Time.deltaTime;
            var t = Mathf.SmoothStep(0f, 1f, elapsed / 0.22f);
            root.transform.position = PaperPosition(anchor());
            root.transform.localScale = Vector3.one * Mathf.Lerp(0.50f, 1f, t);
            SetAlpha(paper, Mathf.Lerp(0f, 0.58f, t));
            SetAlpha(glowBack, Mathf.Lerp(0f, 0.25f, t));
            SetAlpha(glowGold, Mathf.Lerp(0f, 0.12f, t));
            yield return null;
        }
        if (generation != presentationGeneration)
            yield break;

        elapsed = 0f;
        while (generation == presentationGeneration && elapsed < 0.42f)
        {
            elapsed += Time.deltaTime;
            var pulse = (Mathf.Sin(elapsed * 22f) + 1f) * 0.5f;
            root.transform.position = PaperPosition(anchor())
                + Vector3.up * (Mathf.Sin(elapsed * 7f) * 0.025f);
            SetAlpha(paper, Mathf.Lerp(0.42f, 0.62f, pulse));
            SetAlpha(glowBack, Mathf.Lerp(0.10f, 0.32f, pulse));
            SetAlpha(glowGold, Mathf.Lerp(0.04f, 0.16f, 1f - pulse));
            glowBack.transform.localPosition = new Vector3(Mathf.Sin(elapsed * 15f) * 0.018f, 0f, 0f);
            glowGold.transform.localPosition = new Vector3(-Mathf.Sin(elapsed * 12f) * 0.012f, 0f, 0f);
            yield return null;
        }
        if (generation != presentationGeneration)
            yield break;

        if (previewImpact)
        {
            SetColor(paper, new Color(1f, 0.94f, 1f, 0.95f));
            root.transform.localScale = Vector3.one * 1.08f;
            CreateImpactFlash(root.transform);
            elapsed = 0f;
            while (generation == presentationGeneration && elapsed < 0.18f)
            {
                elapsed += Time.deltaTime;
                var shake = (1f - elapsed / 0.18f) * 0.035f;
                root.transform.position = PaperPosition(anchor()) + new Vector3(
                    Mathf.Sin(elapsed * 95f) * shake,
                    Mathf.Cos(elapsed * 83f) * shake,
                    0f);
                SetAlpha(paper, Mathf.Lerp(0.95f, 0.68f, elapsed / 0.18f));
                yield return null;
            }
            if (generation != presentationGeneration)
                yield break;
            CreatePaperFragments(root.transform.position, texture);
            paper.enabled = false;
            glowBack.enabled = false;
            glowGold.enabled = false;
            yield return new WaitForSeconds(PaperFragmentDuration + 0.10f);
        }
        else
        {
            elapsed = 0f;
            while (generation == presentationGeneration && elapsed < 0.22f)
            {
                elapsed += Time.deltaTime;
                var alpha = 1f - elapsed / 0.22f;
                SetAlpha(paper, alpha * 0.50f);
                SetAlpha(glowBack, alpha * 0.22f);
                SetAlpha(glowGold, alpha * 0.10f);
                yield return null;
            }
            if (generation != presentationGeneration)
                yield break;
        }

        motes.Stop(true, ParticleSystemStopBehavior.StopEmitting);
        presentationRoots.Remove(root);
        Destroy(root);
        ReleaseTransientAssets();
    }

    SpriteRenderer CreatePaperLayer(Transform parent, string name, Sprite sprite, Color tint, float glow, int order)
    {
        var node = new GameObject(name);
        node.transform.SetParent(parent, false);
        var renderer = node.AddComponent<SpriteRenderer>();
        renderer.sprite = sprite;
        renderer.color = tint;
        renderer.sortingOrder = order;
        if (glow > 0f)
        {
            var shader = Shader.Find("Mindstone/Fool Additive Sprite") ?? Shader.Find("Sprites/Default");
            renderer.material = new Material(shader) { color = tint };
            transientAssets.Add(renderer.material);
        }
        return renderer;
    }

    ParticleSystem CreateMotes(Transform parent)
    {
        var node = new GameObject("纸屑流光");
        node.transform.SetParent(parent, false);
        var ps = node.AddComponent<ParticleSystem>();
        var main = ps.main;
        main.startLifetime = new ParticleSystem.MinMaxCurve(0.35f, 0.85f);
        main.startSpeed = new ParticleSystem.MinMaxCurve(0.05f, 0.24f);
        main.startSize = new ParticleSystem.MinMaxCurve(0.012f, 0.042f);
        main.startColor = new ParticleSystem.MinMaxGradient(Violet, Gold);
        main.simulationSpace = ParticleSystemSimulationSpace.Local;
        main.maxParticles = 80;
        var emission = ps.emission;
        emission.rateOverTime = 36f;
        var shape = ps.shape;
        shape.shapeType = ParticleSystemShapeType.Rectangle;
        shape.scale = new Vector3(0.75f, 1.25f, 0.05f);
        var renderer = ps.GetComponent<ParticleSystemRenderer>();
        var shader = Shader.Find("Mindstone/Fool Additive Sprite") ?? Shader.Find("Sprites/Default");
        renderer.material = new Material(shader);
        transientAssets.Add(renderer.material);
        renderer.sortingOrder = 62;
        ps.Play();
        return ps;
    }

    void CreateImpactFlash(Transform parent)
    {
        var flash = new GameObject("替身受击闪光");
        flash.transform.SetParent(parent, false);
        var light = flash.AddComponent<Light>();
        light.type = LightType.Point;
        light.color = new Color(0.72f, 0.36f, 1f);
        light.range = 3f;
        light.intensity = 5f;
    }

    void CreatePaperFragments(Vector3 origin, Texture2D texture)
    {
        // The previous 3 x 5 grid read as fifteen large cards. Use a 10 x 15
        // grid so the impact becomes a real paper-body disintegration rather
        // than a handful of obvious rectangles.
        const int columns = 10;
        const int rows = 15;
        var cellWidth = texture.width / (float)columns;
        var cellHeight = texture.height / (float)rows;
        var worldCellWidth = cellWidth / 620f;
        var worldCellHeight = cellHeight / 620f;
        for (var row = 0; row < rows; row++)
        {
            for (var column = 0; column < columns; column++)
            {
                // Integer boundaries keep the final row inside the texture;
                // fractional 2048/15 cells can round past its bottom edge.
                var left = column * texture.width / columns;
                var right = (column + 1) * texture.width / columns;
                var bottom = row * texture.height / rows;
                var top = (row + 1) * texture.height / rows;
                var rect = new Rect(left, bottom, right - left, top - bottom);
                var shard = Sprite.Create(texture, rect, new Vector2(0.5f, 0.5f), 620f);
                transientAssets.Add(shard);
                var node = new GameObject("纸偶真实碎片");
                presentationRoots.Add(node);
                var x = (column - (columns - 1) * 0.5f) * worldCellWidth;
                var y = (row - (rows - 1) * 0.5f) * worldCellHeight + 0.06f;
                node.transform.position = origin + new Vector3(x, y, -0.01f);
                var renderer = node.AddComponent<SpriteRenderer>();
                renderer.sprite = shard;
                renderer.color = new Color(1f, 0.90f, 1f, 0.90f);
                renderer.sortingOrder = 63;
                var normalizedX = (column - (columns - 1) * 0.5f) / ((columns - 1) * 0.5f);
                var normalizedY = (row - (rows - 1) * 0.5f) / ((rows - 1) * 0.5f);
                var delay = (Mathf.Abs(normalizedX) + Mathf.Abs(normalizedY)) * 0.045f;
                StartCoroutine(AnimateFragment(
                    node.transform,
                    renderer,
                    row * columns + column,
                    x,
                    y,
                    delay));
            }
        }
    }

    IEnumerator AnimateFragment(
        Transform fragment,
        SpriteRenderer renderer,
        int index,
        float x,
        float y,
        float delay)
    {
        var direction = new Vector3(x * 1.35f, y * 0.75f + 0.28f, 0f).normalized;
        var velocity = direction * UnityEngine.Random.Range(0.55f, 1.18f);
        if (delay > 0f) yield return new WaitForSeconds(delay);
        var elapsed = 0f;
        while (elapsed < PaperFragmentDuration && fragment != null)
        {
            elapsed += Time.deltaTime;
            fragment.position += velocity * Time.deltaTime;
            velocity.x += Mathf.Sin(elapsed * 7.5f + index * 0.72f) * 0.16f * Time.deltaTime;
            velocity.y -= 0.48f * Time.deltaTime;
            fragment.Rotate(0f, 0f, (index % 2 == 0 ? 155f : -175f) * Time.deltaTime);
            var fade = elapsed < 0.40f
                ? 1f
                : 1f - (elapsed - 0.40f) / (PaperFragmentDuration - 0.40f);
            SetAlpha(renderer, Mathf.Clamp01(fade) * 0.90f);
            yield return null;
        }
        if (fragment != null) Destroy(fragment.gameObject);
    }

    static void SetAlpha(SpriteRenderer renderer, float alpha)
    {
        var color = renderer.color;
        color.a = alpha;
        renderer.color = color;
    }

    static void SetColor(SpriteRenderer renderer, Color color) => renderer.color = color;

    static Vector3 PaperPosition(Vector3 anchor) => anchor + PaperDepthOffset;

    void ReleaseTransientAssets()
    {
        foreach (var item in transientAssets)
        {
            if (item != null)
                Destroy(item);
        }
        transientAssets.Clear();
    }

    void OnDisable()
    {
        presentationGeneration++;
        if (deployedRoutine != null) StopCoroutine(deployedRoutine);
        deployedRoutine = null;
        consumeDeployedPaper = false;
        paperDoubleArmed = false;
        if (deployedRoot != null) Destroy(deployedRoot);
        deployedRoot = null;
        for (var index = 0; index < presentationRoots.Count; index++)
            if (presentationRoots[index] != null)
                Destroy(presentationRoots[index]);
        presentationRoots.Clear();
        ReleaseTransientAssets();
    }
}
