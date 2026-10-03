using System;
using Random = UnityEngine.Random;
using System.Collections;
using System.Collections.Generic;
using Effekseer;
using UnityEngine;

/// Effekseer-only presentation for the ten Fool cards. Combat rules remain
/// native. Each card owns a palette, scale and three-beat choreography so the
/// Unity battlefield never needs the legacy SpriteKit scan/beam overlay.
public sealed class FoolEffekseerSkillVFX : MonoBehaviour
{
    const string ArcanaResource = "Effects/HellHound/FireBall";
    const string AuraResource = "Effects/HellHound/FireOnly";
    const string CurtainExplosionResource = "Effects/Fool/Effekseer/CurtainExplosion/FoolCurtainExplosion";
    const string MaskExplosionResource = "Effects/Fool/Effekseer/MaskExplosion/FoolMaskExplosion";
    const string TktkDarkRiftResource = "Effects/Fool/Effekseer/TktkDarkRift/Dark2";
    const string TarotAtlasResource = "Effects/Fool/FoolTarotVFXAtlas";

    readonly struct Profile
    {
        public readonly Color Color;
        public readonly float CastScale;
        public readonly float ImpactScale;
        public readonly bool TargetsEnemy;
        public readonly int Echoes;

        public Profile(Color color, float castScale, float impactScale, bool targetsEnemy, int echoes)
        {
            Color = color;
            CastScale = castScale;
            ImpactScale = impactScale;
            TargetsEnemy = targetsEnemy;
            Echoes = echoes;
        }
    }

    static readonly Dictionary<string, Profile> Profiles = new()
    {
        ["fool_skill_01"] = new(new Color(0.65f, 0.18f, 1f), 0.12f, 0.22f, true, 1),
        ["fool_skill_02"] = new(new Color(0.92f, 0.22f, 0.88f), 0.14f, 0.25f, true, 2),
        ["fool_skill_03"] = new(new Color(0.36f, 0.78f, 1f), 0.20f, 0.30f, false, 2),
        ["fool_skill_04"] = new(new Color(0.28f, 0.42f, 1f), 0.14f, 0.28f, true, 2),
        ["fool_skill_05"] = new(new Color(1f, 0.34f, 0.72f), 0.13f, 0.27f, true, 2),
        ["fool_skill_06"] = new(new Color(0.40f, 0.92f, 1f), 0.13f, 0.24f, true, 3),
        ["fool_skill_07"] = new(new Color(1f, 0.28f, 0.18f), 0.22f, 0.42f, true, 3),
        ["fool_skill_08"] = new(new Color(0.76f, 0.52f, 1f), 0.18f, 0.32f, true, 2),
        ["fool_skill_09"] = new(new Color(0.18f, 0.88f, 0.82f), 0.18f, 0.30f, false, 3),
        ["fool_skill_10"] = new(new Color(1f, 0.76f, 0.22f), 0.24f, 0.48f, true, 4),
    };

    EffekseerEffectAsset arcana;
    EffekseerEffectAsset aura;
    EffekseerEffectAsset curtainExplosion;
    EffekseerEffectAsset maskExplosion;
    EffekseerEffectAsset tktkDarkRift;
    readonly List<EffekseerHandle> activeHandles = new();
    FoolDistinctSkillVFX distinctSkillVFX;
    FoolTarotStrikeVFX tarotStrike;
    HeroIdentityTheatreVFX identityTheatre;
    HeroArcanaTheatreVFX heroArcana;
    HeroNamelessRound2 nameless;
    public Transform HeroActor { get; set; }
    static Texture2D softParticleTexture;
    static Material additiveSpriteMaterial;

    void Awake()
    {
        distinctSkillVFX = gameObject.AddComponent<FoolDistinctSkillVFX>();
        tarotStrike = gameObject.AddComponent<FoolTarotStrikeVFX>();
        identityTheatre = gameObject.AddComponent<HeroIdentityTheatreVFX>();
        heroArcana = gameObject.AddComponent<HeroArcanaTheatreVFX>();
        nameless = gameObject.AddComponent<HeroNamelessRound2>();
        arcana = Resources.Load<EffekseerEffectAsset>(ArcanaResource);
        aura = Resources.Load<EffekseerEffectAsset>(AuraResource);
        curtainExplosion = Resources.Load<EffekseerEffectAsset>(CurtainExplosionResource);
        maskExplosion = Resources.Load<EffekseerEffectAsset>(MaskExplosionResource);
        tktkDarkRift = Resources.Load<EffekseerEffectAsset>(TktkDarkRiftResource);
    }

    public IEnumerator Play(string skillID, System.Func<Vector3> caster, System.Func<Vector3> target, System.Action onContact = null, System.Func<Vector3> secondary = null)
    {
        // No card VFX may survive into target selection or the next combat action.
        // Several imported Effekseer samples contain looping emitters, so their
        // authored lifetime alone is not a safe cleanup boundary.
        StopActiveEffects();

        // Hero cards with a travelling form (SpellSpectacle20260926, 2026-10-03) show that
        // form instead of the older stage theatre and its screen-wide volume; 双影 keeps its
        // two hero afterimages. The contact keeps the theatre's authored time.
        if (SpellSpectacle20260926.HasForm(skillID) && skillID is "fool_skill_05" or "fool_skill_06" or "fool_skill_07")
        {
            if (skillID == "fool_skill_06") yield return heroArcana.Play(skillID, HeroActor, caster, target, onContact, ghostsOnly: true);
            else yield return TimedContact(skillID == "fool_skill_05" ? HeroIdentityTheatreVFX.EvidenceContactTime : .885f, skillID == "fool_skill_05" ? 1.5f : 1.6f, onContact);
            yield break;
        }
        if (skillID == "fool_skill_01") { yield return tarotStrike.Play(()=>caster()-Vector3.up*1.15f,()=>target()-Vector3.up*1.05f,onContact, secondary == null ? null : () => secondary()-Vector3.up*1.05f, HeroActor); yield break; }
        if (skillID is "fool_skill_02" or "fool_skill_04" or "fool_skill_05")
        { yield return identityTheatre.Play(skillID, caster, target, onContact, HeroActor); yield break; }
        if (skillID == "fool_skill_10") { yield return nameless.Play(caster, target, onContact); yield break; }
        if (skillID is "fool_skill_06" or "fool_skill_07" or "fool_skill_08" or "fool_skill_09")
        { yield return heroArcana.Play(skillID, HeroActor, caster, target, onContact); yield break; }

        if (skillID == "fool_skill_04" || skillID == "fool_skill_05")
        {
            yield return distinctSkillVFX.Play(skillID, caster, target, onContact);
            yield break;
        }

        if (skillID == "fool_skill_01")
        {
            yield return PlayCurtainSlash(caster(), target());
            yield break;
        }
        if (skillID == "fool_skill_02")
        {
            yield return PlayMaskedWhisper(target());
            yield break;
        }
        if (skillID == "fool_skill_03")
        {
            yield return PlayPaperDollDouble(caster());
            yield break;
        }

        if (!Profiles.TryGetValue(skillID, out var profile))
            profile = Profiles["fool_skill_01"];

        var castPoint = caster();
        PlayTinted(aura, castPoint, profile.CastScale, profile.Color, 0.42f, 0.68f);
        yield return new WaitForSeconds(0.18f);

        var impactPoint = profile.TargetsEnemy ? target() : castPoint;
        for (var echo = 0; echo < profile.Echoes; echo++)
        {
            var offset = echo == 0
                ? Vector3.zero
                : new Vector3((echo % 2 == 0 ? 1f : -1f) * 0.12f * echo, 0.07f * echo, 0f);
            PlayTinted(arcana, impactPoint + offset, profile.ImpactScale * (1f + echo * 0.08f), profile.Color, 0.30f, 0.56f);
            yield return new WaitForSeconds(0.075f);
        }
        yield return new WaitForSeconds(skillID is "fool_skill_07" or "fool_skill_10" ? 0.48f : 0.30f);
    }

    readonly List<GameObject> targetInstances = new();
    int targetGeneration;

    // One visual owner per resolved recipient; combat still has one cast contact.
    /// Reports the contact at the theatre's time when no theatre is shown; a new action
    /// (StopActiveEffects) cancels it before contact, as it cancels a theatre.
    IEnumerator TimedContact(float contact, float end, System.Action onContact)
    {
        int run = targetGeneration;
        float elapsed = 0; bool contacted = false;
        while (run == targetGeneration && elapsed < end)
        {
            if (!contacted && elapsed >= contact) { contacted = true; onContact?.Invoke(); if (run != targetGeneration) yield break; }
            yield return null; elapsed += Time.deltaTime;
        }
    }

    public IEnumerator PlayTargetInstances(string skillID, Func<Vector3> caster,
        IReadOnlyList<EnemyHandle> targets, Action onContact)
    {
        StopActiveEffects();
        int run = targetGeneration;
        // 错步穿行 with a travelling form (2026-10-03): the hero's afterimage dashes at the
        // first target, while SpellSpectacle draws the footprints and the cut through the
        // others. The screen-wide offset rift is not played. Contact timing below is unchanged.
        bool dashForm = skillID == "fool_skill_01" && SpellSpectacle20260926.HasForm(skillID);
        if (dashForm && heroArcana && HeroActor)
            foreach (var first in targets)
            {
                if (first == null || first.EnemyRoot == null || !first.gameObject.activeInHierarchy) continue;
                var lead = first;
                Func<Vector3> leadPoint = () => lead && lead.EffectAnchor ? lead.EffectAnchor.position : lead ? lead.EnemyRoot.position + Vector3.up * 1.05f : caster();
                StartCoroutine(heroArcana.Play("fool_skill_06", HeroActor, caster, leadPoint, null, true, FoolTarotStrikeVFX.ContactTime, dash: true));
                break;
            }
        foreach (var target in targets)
        {
            if (dashForm) break;
            if (target == null || target.EnemyRoot == null || !target.gameObject.activeInHierarchy) continue;
            var bound = target;
            Func<bool> valid = () => bound != null && bound.EnemyRoot != null && bound.gameObject.activeInHierarchy;
            Func<Vector3> point = () => bound.EffectAnchor != null ? bound.EffectAnchor.position : bound.EnemyRoot.position + Vector3.up * 1.05f;
            var owner = new GameObject(skillID + " target [" + bound.BattleEnemyId + "]");
            owner.transform.SetParent(transform, false);
            targetInstances.Add(owner);
            if (skillID == "fool_skill_01") {
                var effect = owner.AddComponent<FoolTarotStrikeVFX>();
                effect.StartCoroutine(effect.Play(() => caster() - Vector3.up * 1.15f,
                    () => point() - Vector3.up * 1.05f, null, hero: HeroActor, targetValid: valid));
            } else {
                var effect = owner.AddComponent<HeroNamelessRound2>();
                effect.StartCoroutine(effect.Play(caster, point, null, valid));
            }
        }
        float contact = skillID == "fool_skill_01" ? FoolTarotStrikeVFX.ContactTime : .96f;
        float end = skillID == "fool_skill_01" ? FoolTarotStrikeVFX.Duration : 1.95f;
        float elapsed = 0; bool contacted = false;
        while (run == targetGeneration) {
            if (!contacted && elapsed >= contact) { contacted = true; onContact?.Invoke(); }
            if (run != targetGeneration || elapsed >= end) break;
            yield return null; elapsed += Time.deltaTime;
        }
        if (run == targetGeneration) StopActiveEffects();
    }

    /// Short, bounded defeat punctuation. The actor collapse remains owned by
    /// BattlePrototype; this method replaces the old stretched rectangles with
    /// a dark inward tear, fine memory ash and a restrained final flash.
    public IEnumerator PlayPlayerDefeat(Vector3 center)
    {
        StopActiveEffects();

        var root = new GameObject("VFX · 愚者记忆崩解");
        root.transform.position = center + Vector3.back * 1.35f;

        PlayTinted(
            tktkDarkRift ?? maskExplosion,
            root.transform.position,
            0.13f,
            new Color(0.20f, 0.07f, 0.34f),
            0.22f,
            0.54f,
            1.55f
        );
        CreateMagicParticles(
            root.transform,
            "失色记忆灰烬",
            new Color(0.58f, 0.46f, 0.72f, 0.92f),
            86,
            0.055f,
            1.35f,
            1.18f
        );
        CreateMagicParticles(
            root.transform,
            "碎裂金线",
            new Color(1f, 0.67f, 0.22f, 0.96f),
            32,
            0.035f,
            1.82f,
            0.74f
        );

        yield return new WaitForSeconds(0.16f);
        PlayTinted(
            curtainExplosion,
            root.transform.position,
            0.11f,
            new Color(0.54f, 0.18f, 0.72f),
            0.16f,
            0.34f,
            1.30f
        );
        yield return new WaitForSeconds(0.52f);

        StopActiveEffects();
        Destroy(root, 0.65f);
    }

    IEnumerator PlayCurtainSlash(Vector3 caster, Vector3 target)
    {
        var root = new GameObject("VFX · 错步穿行");
        root.transform.position = target + Vector3.up * 0.20f;
        root.transform.position += Vector3.back * 1.35f;

        // The sample supplies only the fractured-particle vocabulary. The
        // Fool identity is authored here: a readable tarot card crosses the
        // battlefield, leaves displaced copies, then tears open at impact.
        var cardStart = caster - root.transform.position + new Vector3(-0.10f, 0.38f, 0f);
        var cardEnd = new Vector3(0f, 0.08f, 0f);
        var cardControl = Vector3.Lerp(cardStart, cardEnd, 0.52f) + new Vector3(-0.42f, 0.62f, 0f);
        var cardEchoes = new List<SpriteRenderer>();
        for (var i = 0; i < 5; i++)
        {
            var card = CreateTarotAtlasLayer(root.transform, "斜飞塔罗残影", i == 0 ? 5 : 6, 25 - i);
            card.transform.localPosition = cardStart;
            card.transform.localScale = Vector3.one * (i == 0 ? 0.54f : 0.46f);
            card.transform.localRotation = Quaternion.Euler(0f, 0f, -34f);
            card.color = Color.clear;
            cardEchoes.Add(card);
        }

        var impactCards = new List<SpriteRenderer>();
        for (var i = 0; i < 4; i++)
        {
            var card = CreateTarotAtlasLayer(root.transform, "错位卡牌", 2, 23 - i);
            card.transform.localScale = Vector3.zero;
            card.color = Color.clear;
            impactCards.Add(card);
        }

        var camera = Camera.main;
        var cameraOrigin = camera ? camera.transform.position : Vector3.zero;

        const float duration = 0.88f;
        var elapsed = 0f;
        var exploded = false;
        while (elapsed < duration)
        {
            elapsed += Time.deltaTime;
            var t = Mathf.Clamp01(elapsed / duration);
            var flight = Mathf.SmoothStep(0f, 1f, Mathf.Clamp01(t / 0.40f));
            var impact = Mathf.SmoothStep(0f, 1f, Mathf.Clamp01((t - 0.30f) / 0.30f));
            var fade = 1f - Mathf.SmoothStep(0f, 1f, Mathf.Clamp01((t - 0.68f) / 0.30f));
            for (var i = 0; i < cardEchoes.Count; i++)
            {
                var card = cardEchoes[i];
                var echoT = Mathf.Clamp01(flight - i * 0.055f);
                card.transform.localPosition = QuadraticBezier(cardStart, cardControl, cardEnd, echoT);
                var flightScale = Mathf.Lerp(0.66f - i * 0.032f, 1.72f - i * 0.09f, echoT);
                card.transform.localScale = Vector3.one * flightScale;
                card.transform.localRotation = Quaternion.Euler(0f, 0f, Mathf.Lerp(-34f, 22f, echoT) - i * 3f);
                var flightFade = (1f - impact) * (i == 0 ? 1f : 0.34f - i * 0.045f);
                card.color = new Color(0.90f, 0.70f + i * 0.035f, 1f, flightFade);
            }

            for (var i = 0; i < impactCards.Count; i++)
            {
                var card = impactCards[i];
                var angle = (35f + i * 90f + impact * (i % 2 == 0 ? 34f : -34f)) * Mathf.Deg2Rad;
                var radius = Mathf.Lerp(0.14f, 1.62f + i * 0.08f, impact);
                card.transform.localPosition = new Vector3(Mathf.Cos(angle), Mathf.Sin(angle), 0f) * radius;
                card.transform.localScale = Vector3.one * Mathf.Lerp(0.26f, 1.38f, EaseOutBack(impact)) * fade;
                card.transform.localRotation = Quaternion.Euler(0f, 0f, -28f + i * 31f + impact * 65f);
                card.color = new Color(0.95f, 0.68f, 1f, 0.76f * impact * fade);
            }

            if (!exploded && t >= 0.34f)
            {
                exploded = true;
                CreateMagicParticles(root.transform, "蓝紫星屑",
                    new Color(0.42f, 0.34f, 1f, 1f), 92, 0.24f, 3.65f, 1.08f);
                CreateMagicParticles(root.transform, "粉金亮点",
                    new Color(1f, 0.34f, 0.78f, 1f), 76, 0.28f, 2.72f, 1.20f);
                CreateMagicParticles(root.transform, "青色碎光",
                    new Color(0.20f, 0.88f, 1f, 1f), 58, 0.17f, 4.55f, 0.84f);
                PlayTinted(tktkDarkRift ?? curtainExplosion, root.transform.position, 0.34f,
                    new Color(0.36f, 0.46f, 1f), 0.46f, 0.80f, 3.10f);
                PlayTinted(curtainExplosion, root.transform.position, 0.72f,
                    new Color(0.92f, 0.46f, 1f), 0.36f, 0.66f, 3.45f);
            }

            if (camera && t > 0.34f && t < 0.68f)
                camera.transform.position = cameraOrigin + (Vector3)(Random.insideUnitCircle * 0.026f * fade);
            yield return null;
        }
        if (camera) camera.transform.position = cameraOrigin;
        Destroy(root);
    }

    IEnumerator PlayMaskedWhisper(Vector3 target)
    {
        var root = new GameObject("VFX · 假面谕令");
        root.transform.position = target + Vector3.up * 0.45f;
        root.transform.position += Vector3.back * 1.35f;
        var main = CreateSpriteLayer(root.transform, "Effects/Fool/MaskedEye", "错认主体", 20);
        var echoes = new List<SpriteRenderer>();
        for (var i = 0; i < 4; i++)
        {
            var echo = CreateSpriteLayer(root.transform, "Effects/Fool/MaskedEye", "错位残影", 19 - i);
            echo.color = Color.clear;
            echoes.Add(echo);
        }
        var camera = Camera.main;
        var cameraOrigin = camera ? camera.transform.position : Vector3.zero;

        const float duration = 1.16f;
        var elapsed = 0f;
        var exploded = false;
        while (elapsed < duration)
        {
            elapsed += Time.deltaTime;
            var t = Mathf.Clamp01(elapsed / duration);
            var reveal = EaseOutBack(Mathf.Clamp01(t / 0.32f));
            var impact = Mathf.SmoothStep(0f, 1f, Mathf.Clamp01((t - 0.22f) / 0.28f));
            var fade = 1f - Mathf.SmoothStep(0f, 1f, Mathf.Clamp01((t - 0.74f) / 0.26f));
            var pulse = 1f + Mathf.Sin(t * Mathf.PI * 6f) * 0.065f;
            root.transform.localScale = Vector3.one * Mathf.Lerp(0.32f, 1.72f, reveal) * pulse;
            root.transform.rotation = Quaternion.Euler(0f, 0f, Mathf.Lerp(-7f, 8f, t));
            main.color = new Color(1f, 1f, 1f, 0.94f * fade);

            for (var i = 0; i < echoes.Count; i++)
            {
                var echo = echoes[i];
                var angle = (48f + i * 90f + t * (i % 2 == 0 ? 38f : -38f)) * Mathf.Deg2Rad;
                var distance = Mathf.Lerp(0.04f, 0.72f + i * 0.08f, impact);
                echo.transform.localPosition = new Vector3(Mathf.Cos(angle), Mathf.Sin(angle), 0f) * distance;
                echo.transform.localScale = Vector3.one * Mathf.Lerp(0.72f, 1.04f + i * 0.05f, impact);
                echo.transform.localRotation = Quaternion.Euler(0f, 0f, (i % 2 == 0 ? 1f : -1f) * (12f + t * 34f));
                var alpha = (0.34f - i * 0.045f) * impact * fade;
                echo.color = i % 2 == 0
                    ? new Color(0.22f, 0.84f, 1f, alpha)
                    : new Color(1f, 0.28f, 0.82f, alpha);
            }

            if (!exploded && t >= 0.28f)
            {
                exploded = true;
                CreateMagicParticles(root.transform, "紫白幻尘",
                    new Color(0.70f, 0.34f, 1f, 1f), 112, 0.25f, 3.85f, 1.12f);
                CreateMagicParticles(root.transform, "粉金呢喃",
                    new Color(1f, 0.30f, 0.72f, 1f), 94, 0.30f, 3.10f, 1.28f);
                CreateMagicParticles(root.transform, "青蓝错视",
                    new Color(0.16f, 0.88f, 1f, 1f), 78, 0.19f, 4.65f, 0.92f);
                PlayTinted(maskExplosion, root.transform.position, 1.18f,
                    new Color(0.96f, 0.22f, 0.82f), 0.72f, 1.10f, 2.35f);
                PlayTinted(tktkDarkRift ?? maskExplosion, root.transform.position, 0.42f,
                    new Color(0.22f, 0.76f, 1f), 0.38f, 0.70f, 2.55f);
            }
            if (camera && t > 0.28f && t < 0.64f)
                camera.transform.position = cameraOrigin + (Vector3)(Random.insideUnitCircle * 0.030f * fade);
            yield return null;
        }
        if (camera) camera.transform.position = cameraOrigin;
        Destroy(root);
    }

    IEnumerator PlayPaperDollDouble(Vector3 caster)
    {
        var root = new GameObject("VFX · 纸人代身");
        root.transform.position = caster + new Vector3(0f, 0.58f, -1.35f);

        var body = CreateTarotAtlasLayer(root.transform, "纸偶核心符牌", 9, 24);
        body.color = Color.clear;
        body.transform.localRotation = Quaternion.Euler(0f, 0f, -4f);

        var fragments = new List<SpriteRenderer>();
        for (var i = 0; i < 7; i++)
        {
            var fragment = CreateTarotAtlasLayer(root.transform, "纸偶分身符牌", (i + 3) % 12, 23 - i);
            fragment.color = Color.clear;
            fragment.transform.localScale = Vector3.zero;
            fragments.Add(fragment);
        }

        const float duration = 1.18f;
        var elapsed = 0f;
        var materialized = false;
        while (elapsed < duration)
        {
            elapsed += Time.deltaTime;
            var t = Mathf.Clamp01(elapsed / duration);
            var reveal = EaseOutBack(Mathf.Clamp01(t / 0.34f));
            var spread = Mathf.SmoothStep(0f, 1f, Mathf.Clamp01((t - 0.16f) / 0.36f));
            var fade = 1f - Mathf.SmoothStep(0f, 1f, Mathf.Clamp01((t - 0.78f) / 0.22f));

            body.transform.localScale = new Vector3(1.20f, 1.55f, 1f) * Mathf.Lerp(0.18f, 1.28f, reveal);
            body.transform.localPosition = new Vector3(0f, Mathf.Sin(t * Mathf.PI * 3f) * 0.055f, 0f);
            body.color = new Color(0.94f, 1f, 0.78f, 0.92f * fade);

            for (var i = 0; i < fragments.Count; i++)
            {
                var angle = (-105f + i * 35f + t * (i % 2 == 0 ? 22f : -18f)) * Mathf.Deg2Rad;
                var radius = Mathf.Lerp(0.08f, 0.92f + (i % 3) * 0.18f, spread);
                var fragment = fragments[i];
                fragment.transform.localPosition = new Vector3(Mathf.Cos(angle), Mathf.Sin(angle), 0f) * radius;
                fragment.transform.localScale = Vector3.one * Mathf.Lerp(0.12f, 0.58f + (i % 2) * 0.12f, spread) * fade;
                fragment.transform.localRotation = Quaternion.Euler(0f, 0f, -36f + i * 27f + t * 48f);
                fragment.color = i % 2 == 0
                    ? new Color(1f, 0.82f, 0.28f, 0.68f * spread * fade)
                    : new Color(0.24f, 0.94f, 0.88f, 0.62f * spread * fade);
            }

            if (!materialized && t >= 0.27f)
            {
                materialized = true;
                CreateMagicParticles(root.transform, "金色纸屑",
                    new Color(1f, 0.76f, 0.24f, 1f), 104, 0.25f, 3.40f, 1.18f);
                CreateMagicParticles(root.transform, "青色灵纸",
                    new Color(0.22f, 0.96f, 0.84f, 1f), 86, 0.22f, 4.10f, 1.02f);
                CreateMagicParticles(root.transform, "紫色误认",
                    new Color(0.72f, 0.36f, 1f, 1f), 72, 0.28f, 2.65f, 1.30f);
                PlayTinted(aura, root.transform.position, 0.72f,
                    new Color(0.20f, 0.90f, 0.78f), 0.44f, 0.82f, 2.45f);
                PlayTinted(maskExplosion, root.transform.position, 0.66f,
                    new Color(1f, 0.70f, 0.24f), 0.38f, 0.74f, 2.20f);
            }
            yield return null;
        }
        Destroy(root);
    }

    static LineRenderer CreateRadialBurst(
        Transform parent, int rayCount, float innerRadius, float outerRadius,
        float width, Color color)
    {
        var combined = CreateLine(parent, width, color, false);
        combined.positionCount = rayCount * 3;
        for (var i = 0; i < rayCount; i++)
        {
            var angle = i * Mathf.PI * 2f / rayCount;
            var direction = new Vector3(Mathf.Cos(angle), Mathf.Sin(angle), 0f);
            combined.SetPosition(i * 3, direction * innerRadius);
            combined.SetPosition(i * 3 + 1, direction * outerRadius);
            combined.SetPosition(i * 3 + 2, direction * innerRadius);
        }
        return combined;
    }

    static ParticleSystem CreateMagicParticles(
        Transform parent, string name, Color color, int count,
        float size, float speed, float lifetime)
    {
        var node = new GameObject(name);
        node.transform.SetParent(parent, false);
        var particles = node.AddComponent<ParticleSystem>();
        particles.Stop(true, ParticleSystemStopBehavior.StopEmittingAndClear);
        var main = particles.main;
        main.loop = false;
        main.duration = Mathf.Max(0.1f, lifetime);
        main.startLifetime = new ParticleSystem.MinMaxCurve(lifetime * 0.65f, lifetime);
        main.startSpeed = new ParticleSystem.MinMaxCurve(speed * 0.45f, speed);
        main.startSize = new ParticleSystem.MinMaxCurve(size * 0.45f, size);
        main.startColor = new ParticleSystem.MinMaxGradient(color, Color.white);
        main.simulationSpace = ParticleSystemSimulationSpace.Local;
        main.maxParticles = count * 2;
        var emission = particles.emission;
        emission.rateOverTime = 0f;
        emission.SetBursts(new[] { new ParticleSystem.Burst(0f, (short)count) });
        var shape = particles.shape;
        shape.shapeType = ParticleSystemShapeType.Circle;
        shape.radius = 0.42f;
        shape.radiusThickness = 0.18f;
        var colorOverLifetime = particles.colorOverLifetime;
        colorOverLifetime.enabled = true;
        var gradient = new Gradient();
        gradient.SetKeys(
            new[] { new GradientColorKey(color, 0f), new GradientColorKey(Color.white, 0.35f), new GradientColorKey(color, 1f) },
            new[] { new GradientAlphaKey(0f, 0f), new GradientAlphaKey(1f, 0.12f), new GradientAlphaKey(0f, 1f) });
        colorOverLifetime.color = gradient;
        var renderer = node.GetComponent<ParticleSystemRenderer>();
        var shader = Shader.Find("Particles/Standard Unlit") ?? Shader.Find("Sprites/Default");
        renderer.material = new Material(shader);
        renderer.material.mainTexture = SoftParticleTexture();
        renderer.sortingOrder = 22;
        particles.Play();
        return particles;
    }

    static Texture2D SoftParticleTexture()
    {
        if (softParticleTexture != null) return softParticleTexture;
        const int size = 32;
        softParticleTexture = new Texture2D(size, size, TextureFormat.RGBA32, false)
        {
            name = "Runtime soft magic mote",
            filterMode = FilterMode.Bilinear,
            wrapMode = TextureWrapMode.Clamp
        };
        var pixels = new Color[size * size];
        var center = (size - 1) * 0.5f;
        for (var y = 0; y < size; y++)
        for (var x = 0; x < size; x++)
        {
            var dx = (x - center) / center;
            var dy = (y - center) / center;
            var distance = Mathf.Sqrt(dx * dx + dy * dy);
            var alpha = Mathf.Pow(Mathf.Clamp01(1f - distance), 2.4f);
            pixels[y * size + x] = new Color(1f, 1f, 1f, alpha);
        }
        softParticleTexture.SetPixels(pixels);
        softParticleTexture.Apply(false, true);
        return softParticleTexture;
    }

    static SpriteRenderer CreateSpriteLayer(Transform parent, string resource, string name, int sortingOrder)
    {
        var texture = Resources.Load<Texture2D>(resource);
        var node = new GameObject(name);
        node.transform.SetParent(parent, false);
        var renderer = node.AddComponent<SpriteRenderer>();
        renderer.sortingOrder = sortingOrder;
        renderer.sprite = Sprite.Create(texture, new Rect(0f, 0f, texture.width, texture.height), new Vector2(0.5f, 0.5f), 512f);
        renderer.color = new Color(1f, 1f, 1f, 0f);
        return renderer;
    }

    static SpriteRenderer CreateTarotAtlasLayer(Transform parent, string name, int tileIndex, int sortingOrder)
    {
        var texture = Resources.Load<Texture2D>(TarotAtlasResource);
        var node = new GameObject(name);
        node.transform.SetParent(parent, false);
        var renderer = node.AddComponent<SpriteRenderer>();
        renderer.sortingOrder = sortingOrder;
        if (texture != null)
        {
            const int columns = 4;
            const int rows = 4;
            var cellWidth = texture.width / (float)columns;
            var cellHeight = texture.height / (float)rows;
            var column = tileIndex % columns;
            var rowFromTop = tileIndex / columns;
            var rect = new Rect(
                Mathf.Round(column * cellWidth),
                Mathf.Round(texture.height - (rowFromTop + 1) * cellHeight),
                Mathf.Round(cellWidth),
                Mathf.Round(cellHeight));
            renderer.sprite = Sprite.Create(texture, rect, new Vector2(0.5f, 0.5f), 260f);
            renderer.material = AdditiveSpriteMaterial();
        }
        return renderer;
    }

    static Material AdditiveSpriteMaterial()
    {
        if (additiveSpriteMaterial != null) return additiveSpriteMaterial;
        var shader = Shader.Find("Mindstone/Fool Additive Sprite")
            ?? Shader.Find("Legacy Shaders/Particles/Additive")
            ?? Shader.Find("Particles/Standard Unlit")
            ?? Shader.Find("Sprites/Default");
        additiveSpriteMaterial = new Material(shader) { name = "Fool tarot additive" };
        return additiveSpriteMaterial;
    }

    static Vector3 QuadraticBezier(Vector3 start, Vector3 control, Vector3 end, float t)
    {
        var inverse = 1f - t;
        return inverse * inverse * start + 2f * inverse * t * control + t * t * end;
    }

    static float EaseOutBack(float t)
    {
        const float c1 = 1.70158f;
        const float c3 = c1 + 1f;
        return 1f + c3 * Mathf.Pow(t - 1f, 3f) + c1 * Mathf.Pow(t - 1f, 2f);
    }

    static LineRenderer CreateStroke(Transform parent, Vector3 from, Vector3 to, float width, Color color)
    {
        var line = CreateLine(parent, width, color, false);
        line.positionCount = 3;
        line.SetPositions(new[] { from, Vector3.Lerp(from, to, 0.54f) + Vector3.up * 0.08f, to });
        return line;
    }

    static LineRenderer CreateRing(Transform parent, float radius, int segments, float width, Color color)
        => CreateArc(parent, radius, 0f, 360f, segments, width, color, true);

    static LineRenderer CreateArc(Transform parent, float radius, float start, float end, int segments, float width, Color color, bool loop = false)
    {
        var line = CreateLine(parent, width, color, loop);
        line.positionCount = segments + (loop ? 0 : 1);
        for (var i = 0; i < line.positionCount; i++)
        {
            var denominator = loop ? segments : segments;
            var angle = Mathf.Lerp(start, end, i / (float)denominator) * Mathf.Deg2Rad;
            line.SetPosition(i, new Vector3(Mathf.Cos(angle) * radius, Mathf.Sin(angle) * radius, 0f));
        }
        return line;
    }

    static LineRenderer CreateDiamond(Transform parent, float width, float height, float lineWidth, Color color)
    {
        var line = CreateLine(parent, lineWidth, color, true);
        line.positionCount = 4;
        line.SetPositions(new[]
        {
            new Vector3(-width, 0f), new Vector3(0f, height),
            new Vector3(width, 0f), new Vector3(0f, -height)
        });
        return line;
    }

    static LineRenderer CreateLine(Transform parent, float width, Color color, bool loop)
    {
        var node = new GameObject("Arcane stroke");
        node.transform.SetParent(parent, false);
        var line = node.AddComponent<LineRenderer>();
        line.useWorldSpace = false;
        line.loop = loop;
        line.alignment = LineAlignment.View;
        line.numCapVertices = 6;
        line.numCornerVertices = 4;
        line.widthMultiplier = width;
        line.material = new Material(Shader.Find("Sprites/Default"));
        line.startColor = color;
        line.endColor = color;
        return line;
    }

    static void SetColor(LineRenderer line, Color color)
    {
        line.startColor = color;
        line.endColor = color;
    }

    void PlayTinted(
        EffekseerEffectAsset asset,
        Vector3 position,
        float scale,
        Color color,
        float emissionDuration = 0.34f,
        float hardStopDuration = 0.68f,
        float playbackSpeed = 2.0f)
    {
        if (asset == null) return;
        var parameters = EffekseerPlayEffectParameters.Create(position);
        parameters.SetScale(Vector3.one * scale);
        parameters.Speed = playbackSpeed;
        var handle = EffekseerSystem.PlayEffect(asset, parameters);
        handle.SetAllColor(color);
        activeHandles.Add(handle);
        StartCoroutine(RetireEffect(handle, emissionDuration, hardStopDuration));
    }

    IEnumerator RetireEffect(EffekseerHandle handle, float emissionDuration, float hardStopDuration)
    {
        yield return new WaitForSeconds(emissionDuration);
        // Stop spawning first so existing particles get a short, natural tail.
        handle.StopRoot();

        yield return new WaitForSeconds(Mathf.Max(0f, hardStopDuration - emissionDuration));
        // Hard cleanup prevents looping rays/particles from remaining forever.
        handle.Stop();
        activeHandles.Remove(handle);
    }

    public void StopActiveEffects()
    {
        targetGeneration++;
        foreach (var owner in targetInstances) if (owner) { owner.SetActive(false); Destroy(owner); }
        targetInstances.Clear();
        tarotStrike?.Clear();
        identityTheatre?.Clear();
        heroArcana?.Clear();
        nameless?.Clear();
        distinctSkillVFX?.Stop();
        foreach (var handle in activeHandles)
            handle.Stop();
        activeHandles.Clear();
        distinctSkillVFX?.Stop();
    }

    void OnDisable()
    {
        StopActiveEffects();
        distinctSkillVFX?.Stop();
    }

    void OnDestroy()
    {
        StopActiveEffects();
        distinctSkillVFX?.Stop();
    }

    public static string DisplayName(string id) => id switch
    {
        "fool_skill_01" => "错步穿行",
        "fool_skill_02" => "假面谕令",
        "fool_skill_03" => "纸人代身（遗落物）",
        "fool_skill_04" => "张冠李戴",
        "fool_skill_05" => "伪证烙印",
        "fool_skill_06" => "错影追猎",
        "fool_skill_07" => "荒谬归结",
        "fool_skill_08" => "反客为主",
        "fool_skill_09" => "后手改写",
        "fool_skill_10" => "无名宣告",
        _ => "帷幕技能"
    };
}
