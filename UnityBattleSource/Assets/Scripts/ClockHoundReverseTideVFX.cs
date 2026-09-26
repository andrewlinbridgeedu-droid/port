using System;
using System.Collections;
using System.Collections.Generic;
using Effekseer;
using UnityEngine;

/// <summary>
/// Production presentation for the Clock Hound's Reverse Tide Bite.
///
/// Effekseer owns the authored particle, ribbon, distortion and impact layers;
/// this component only choreographs those assets against combat anchors. The
/// Unity side never owns damage or timing decisions from the combat core.
/// </summary>
public sealed class ClockHoundReverseTideVFX : MonoBehaviour
{
    const string FireballResource = "Effects/HellHound/FireBall";
    const string FireOnlyResource = "Effects/HellHound/FireOnly";
    const string CurtainResource = "Effects/Fool/Effekseer/CurtainExplosion/FoolCurtainExplosion";
    const string MaskResource = "Effects/Fool/Effekseer/MaskExplosion/FoolMaskExplosion";
    const string DarkRiftResource = "Effects/Fool/Effekseer/TktkDarkRift/Dark2";

    const float TelegraphDuration = 0.28f;
    const float TravelDuration = 0.22f;
    const float ImpactDuration = 0.58f;
    const float ResidualDuration = 0.36f;

    static readonly Color ChargeColor = new(0.72f, 0.08f, 0.42f, 0.74f);
    static readonly Color TideColor = new(0.18f, 0.46f, 1.00f, 0.70f);
    static readonly Color ImpactColor = new(0.98f, 0.16f, 0.08f, 0.78f);
    static readonly Color ClockColor = new(0.88f, 0.28f, 0.74f, 0.72f);
    static readonly Color ResidualColor = new(0.26f, 0.42f, 1.00f, 0.42f);

    readonly List<EffekseerHandle> activeHandles = new();
    EffekseerEffectAsset fireball;
    EffekseerEffectAsset fireOnly;
    EffekseerEffectAsset curtain;
    EffekseerEffectAsset mask;
    EffekseerEffectAsset darkRift;
    bool playing;
    int playbackID;

    public bool IsPlaying => playing;

    void Awake()
    {
        fireball = Resources.Load<EffekseerEffectAsset>(FireballResource);
        fireOnly = Resources.Load<EffekseerEffectAsset>(FireOnlyResource);
        curtain = Resources.Load<EffekseerEffectAsset>(CurtainResource);
        mask = Resources.Load<EffekseerEffectAsset>(MaskResource);
        darkRift = Resources.Load<EffekseerEffectAsset>(DarkRiftResource);

        if (fireball == null) Debug.LogError($"Reverse Tide is missing Resources/{FireballResource}.");
        if (fireOnly == null) Debug.LogError($"Reverse Tide is missing Resources/{FireOnlyResource}.");
        if (curtain == null) Debug.LogError($"Reverse Tide is missing Resources/{CurtainResource}.");
    }

    public IEnumerator Play(Func<Vector3> source, Func<Vector3> target)
    {
        var id = ++playbackID;
        StopActiveEffects();
        playing = true;

        var sourcePosition = source != null ? source() : Vector3.zero;
        var targetPosition = target != null
            ? target()
            : sourcePosition + Vector3.forward * 4f;
        var targetEffectPosition = targetPosition + Vector3.back * 1.10f + Vector3.up * 0.12f;
        var sourceEffectPosition = sourcePosition + Vector3.back * 0.28f + Vector3.up * 0.04f;

        // Beat 1: the hound's mouth gathers a restrained red-violet charge
        // while a small blue rift marks the exact contact point.
        var charge = PlayTinted(
            fireOnly,
            sourceEffectPosition,
            0.075f,
            ChargeColor,
            1.75f);
        var targetMark = PlayTinted(
            darkRift ?? mask,
            targetEffectPosition,
            0.085f,
            TideColor,
            1.85f);
        yield return WaitFor(id, TelegraphDuration);
        if (id != playbackID) yield break;
        StopRoot(charge);
        StopRoot(targetMark);

        // Beat 2: use the authored FireBall motion as the bite itself. The
        // handle is moved along the live anchor curve, so this is not a
        // screenshot-tuned beam or a floating projectile.
        var travel = PlayDirectional(
            fireball,
            sourceEffectPosition,
            targetEffectPosition,
            Mathf.Clamp((targetEffectPosition - sourceEffectPosition).magnitude / 6.4f * 0.30f, 0.12f, 0.30f),
            ImpactColor,
            2.45f);
        var travelElapsed = 0f;
        var travelControl = Vector3.Lerp(sourceEffectPosition, targetEffectPosition, 0.52f)
            + Vector3.up * 0.38f;
        while (travelElapsed < TravelDuration && id == playbackID)
        {
            travelElapsed += Time.deltaTime;
            var travelT = Mathf.SmoothStep(0f, 1f, Mathf.Clamp01(travelElapsed / TravelDuration));
            var oneMinusT = 1f - travelT;
            var travelPosition = oneMinusT * oneMinusT * sourceEffectPosition
                + 2f * oneMinusT * travelT * travelControl
                + travelT * travelT * targetEffectPosition;
            travel.SetLocation(travelPosition);
            yield return null;
        }
        if (id != playbackID) yield break;
        StopRoot(travel);

        // Beat 3: the clock tear and fire contact are layered Effekseer
        // assets. The secondary mask layer supplies the cool afterimage that
        // keeps the red hit readable against the pale plaza background.
        // The mask is the silhouette layer. Put it towards the camera so the
        // authored face, orbit and clock marks stay readable over the actor;
        // fire is intentionally a restrained rim instead of a whiteout.
        PlayTinted(mask, targetEffectPosition + Vector3.back * 0.30f, 0.30f,
            new Color(0.84f, 0.20f, 0.76f, 0.52f), 0.85f);
        PlayTinted(darkRift ?? curtain, targetEffectPosition + Vector3.back * 0.16f, 0.14f,
            new Color(0.18f, 0.46f, 1.00f, 0.36f), 1.20f);
        PlayTinted(fireOnly, targetEffectPosition + Vector3.back * 0.08f, 0.040f,
            new Color(1.00f, 0.18f, 0.035f, 0.36f), 1.70f);
        yield return WaitFor(id, ImpactDuration);
        if (id != playbackID) yield break;

        // Residual punctuation is short and bounded; imported looping roots
        // are stopped before the next combat action can begin.
        PlayTinted(fireOnly, targetEffectPosition, 0.052f, ResidualColor, 1.35f);
        yield return WaitFor(id, ResidualDuration);
        if (id == playbackID)
        {
            StopActiveEffects();
            playing = false;
        }
    }

    public void StopRoot()
    {
        playbackID++;
        StopActiveEffects();
        playing = false;
    }

    IEnumerator WaitFor(int id, float duration)
    {
        var elapsed = 0f;
        while (elapsed < duration && id == playbackID)
        {
            elapsed += Time.deltaTime;
            yield return null;
        }
    }

    EffekseerHandle PlayTinted(
        EffekseerEffectAsset asset,
        Vector3 position,
        float scale,
        Color color,
        float speed)
    {
        if (asset == null) return default;
        var parameters = EffekseerPlayEffectParameters.Create(position);
        parameters.SetScale(Vector3.one * scale);
        parameters.Speed = speed;
        var handle = EffekseerSystem.PlayEffect(asset, parameters);
        handle.SetAllColor(color);
        activeHandles.Add(handle);
        return handle;
    }

    EffekseerHandle PlayDirectional(
        EffekseerEffectAsset asset,
        Vector3 source,
        Vector3 target,
        float scale,
        Color color,
        float speed)
    {
        if (asset == null) return default;
        var direction = target - source;
        if (direction.sqrMagnitude < 0.0001f) direction = Vector3.forward;
        var rotation = Quaternion.FromToRotation(Vector3.up, direction.normalized);
        rotation.ToAngleAxis(out var angle, out var axis);

        var parameters = EffekseerPlayEffectParameters.Create(source);
        parameters.SetScale(Vector3.one * scale);
        parameters.SetRotation(axis, angle * Mathf.Deg2Rad);
        parameters.Speed = speed;
        var handle = EffekseerSystem.PlayEffect(asset, parameters);
        handle.SetAllColor(color);
        activeHandles.Add(handle);
        return handle;
    }

    static void StopRoot(EffekseerHandle handle)
    {
        handle.StopRoot();
    }

    void StopActiveEffects()
    {
        for (var i = 0; i < activeHandles.Count; i++)
            activeHandles[i].Stop();
        activeHandles.Clear();
    }

    void OnDisable() => StopRoot();

    void OnDestroy() => StopRoot();
}
