using System.Collections;
using Effekseer;
using UnityEngine;

/// Mouth charge, visible travelling hellfire and contact detonation.
public sealed class HellHoundEffekseerFireball : MonoBehaviour
{
    // Early hound only: same authored flame/travel/finish clocks, without the
    // closed Wind rings and screen-filling additive soft lights. Q4 is separate.
    const string EffectResourcePath = "Effects/HellHound/MainlineEarlyFireballRound2";
    const float PreviewDistance = 6.4f;
    const float PreviewScale = 0.30f;
    const float PlaybackSpeed = 2.0f;
    // Attenuate additive fire without changing the authored travel curve.
    static readonly Color ReadableFireColor = new Color(0.84f, 0.77f, 0.66f, 0.70f);
    const float ImpactScale = 0.34f;

    EffekseerEffectAsset fireball;
    EffekseerHandle activeFireball;
    EffekseerHandle activeImpact;

    public void Clear(){activeFireball.Stop();activeImpact.Stop();}
    void OnDisable()=>Clear();
    void OnDestroy()=>Clear();

    public bool IsReady => fireball != null;

    void Awake()
    {
        fireball = Resources.Load<EffekseerEffectAsset>(EffectResourcePath);
        if (fireball == null)
            Debug.LogError($"Hell hound fireball is missing at Resources/{EffectResourcePath}.");
    }

    public IEnumerator PlayCharge(
        System.Func<Vector3> source,
        System.Func<Vector3> target)
    {
        if (!IsReady) yield break;

        var launch = source();
        var direction = target() - launch;
        if (direction.sqrMagnitude < 0.0001f)
            direction = Vector3.back;

        var distance = direction.magnitude;
        // FireBall.efkproj is authored along local +Y, not Unity forward/-Z.
        // Aligning from -Z rotated the projectile roughly 90 degrees upward.
        var rotation = Quaternion.FromToRotation(Vector3.up, direction.normalized);
        rotation.ToAngleAxis(out var angle, out var axis);

        var parameters = EffekseerPlayEffectParameters.Create(launch);
        var scale = Mathf.Clamp(
            distance / PreviewDistance * PreviewScale,
            0.10f,
            0.30f);
        parameters.SetScale(Vector3.one * scale);
        parameters.SetRotation(axis, angle * Mathf.Deg2Rad);
        parameters.Speed = PlaybackSpeed;
        activeFireball = EffekseerSystem.PlayEffect(fireball, parameters);
        activeFireball.SetAllColor(ReadableFireColor);
        activeFireball.SetTargetLocation(target());

        // The authored opening glow gathers at the mouth before release.
        yield return new WaitForSeconds(0.24f);
    }

    public IEnumerator Fly(System.Func<Vector3> source, System.Func<Vector3> target)
    {
        if (!IsReady) yield break;

        // Reuse the authored flame mesh/particles, including their location curve.
        // Its actual launch is frames 120–150: local Z -1.01948 → 15.32988,
        // while local Y falls from 4.851079 to ground level.
        // Effekseer runs left-handed in Unity, so imported curve Z is inverted.
        activeFireball.Stop();
        var launch = source();
        var destination = target();
        var authoredStart = new Vector3(0, 4.851079f, 1.01948f);
        var authoredEnd = new Vector3(0, .09186983f, -15.32988f);
        var authoredTravel = authoredEnd - authoredStart;
        var direction = destination - launch;
        var scale = direction.magnitude / authoredTravel.magnitude;
        var rotation = Quaternion.FromToRotation(authoredTravel.normalized, direction.normalized);
        var parameters = EffekseerPlayEffectParameters.Create(launch - rotation * (authoredStart * scale));
        parameters.SetScale(Vector3.one * scale);
        rotation.ToAngleAxis(out var angle, out var axis);
        parameters.SetRotation(axis, angle * Mathf.Deg2Rad);
        parameters.Speed = 1;
        activeFireball = EffekseerSystem.PlayEffect(fireball, parameters);
        activeFireball.SetAllColor(ReadableFireColor);
        activeFireball.SetTargetLocation(destination);
        activeFireball.UpdateHandleToMoveToFrame(120f);

        // Keep the existing 1.10-second combat-contact deadline. Stop before
        // Finish spawns; PlayImpact owns the single terminal blast and damage.
        const float flightDuration = .78f;
        activeFireball.speed = 29.9f / (60f * flightDuration);
        yield return new WaitForSeconds(flightDuration);
        activeFireball.Stop();
    }

    public IEnumerator PlayImpact(System.Func<Vector3> target, System.Action onContact = null)
    {
        if (!IsReady) yield break;

        var parameters = EffekseerPlayEffectParameters.Create(target());
        // Keep the terminal flash local to the victim rather than covering
        // the corridor between the hound and the player's whole silhouette.
        parameters.SetScale(Vector3.one * ImpactScale);
        parameters.Speed = 2.20f;
        var impact = EffekseerSystem.PlayEffect(fireball, parameters);
        activeImpact=impact;
        impact.SetAllColor(new Color(1,.88f,.67f,.88f));
        impact.SetTargetLocation(target());
        // The authored Finish node starts at frame 150. Playing from frame
        // zero at the victim replays the flight AFTER native damage/phantom
        // break. Sample the terminal contact first, then notify the rules.
        impact.UpdateHandleToMoveToFrame(150f);
        onContact?.Invoke();
        // FireBall.efkproj supplies the dense terminal flare.
        yield return new WaitForSeconds(0.20f);
    }

}
