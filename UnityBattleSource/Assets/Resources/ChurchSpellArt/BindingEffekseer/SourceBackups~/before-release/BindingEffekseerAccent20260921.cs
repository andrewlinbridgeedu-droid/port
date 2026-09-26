using UnityEngine;
using Effekseer;

/// <summary>
/// Sparse, real Effekseer surface glints for B02's separate binding ribbons.
/// center is the target chest, not the feet. Authored radius ~.8, height +/-1.05.
/// This helper owns at most two finite held effects plus one contact effect.
/// </summary>
public sealed class BindingEffekseerAccent20260921 : MonoBehaviour
{
    // Ownership counter for cancellation/scene-exit checks; expiry is reaped in Draw.
    public static int ActiveHandles { get; private set; }
    public int LiveHandleCount
    {
        get
        {
            int count = contactLive && contact.exists ? 1 : 0;
            for (int i = 0; i < attached.Length; i++)
                if (attachedLive[i] && attached[i].exists) count++;
            return count;
        }
    }
    const string ResourceRoot = "ChurchSpellArt/BindingEffekseer/";
    const float RenewSeconds = .9f;
    readonly EffekseerHandle[] attached = new EffekseerHandle[2];
    readonly bool[] attachedLive = new bool[2];
    readonly bool[] attachedRootStopped = new bool[2];
    EffekseerHandle contact;
    EffekseerEffectAsset attachedAsset;
    EffekseerEffectAsset contactAsset;
    bool assetsLoaded;
    bool contactLive;
    bool contactPlayed;
    bool previouslyHeld;
    int nextSlot;
    float nextRenew;

    /// <param name="center">World-space target chest position.</param>
    /// <param name="fade">Overall opacity from zero to one.</param>
    /// <param name="held">True while the bindings persist; false stops new emissions.</param>
    /// <param name="contactPulse">Positive at real contact; latched once until StopAll/fade zero.</param>
    public void Draw(Vector3 center, float fade, bool held, float contactPulse)
    {
        fade = Mathf.Clamp01(fade);
        if (fade <= .003f)
        {
            StopAll();
            return;
        }
        if (!assetsLoaded)
        {
            assetsLoaded = true;
            attachedAsset = Resources.Load<EffekseerEffectAsset>(ResourceRoot + "BindingAttachedGlints");
            contactAsset = Resources.Load<EffekseerEffectAsset>(ResourceRoot + "BindingContactTighten");
            if (!attachedAsset || !contactAsset)
                Debug.LogError("B02 binding Effekseer accents missing: import both BindingEffekseer .efkproj projects.", this);
        }

        if (held && (!previouslyHeld || Time.time >= nextRenew))
        {
            int slot = nextSlot;
            nextSlot = (nextSlot + 1) % attached.Length;
            StopAttached(slot);
            attachedRootStopped[slot] = false;
            nextRenew = Time.time + RenewSeconds;
            if (attachedAsset)
            {
                var parameters = EffekseerPlayEffectParameters.Create(center);
                parameters.SetScale(Vector3.one);
                attached[slot] = EffekseerSystem.PlayEffect(attachedAsset, parameters);
                attachedLive[slot] = attached[slot].enabled;
                if (attachedLive[slot]) ActiveHandles++;
            }
        }
        previouslyHeld = held;

        for (int i = 0; i < attached.Length; i++)
        {
            if (!attachedLive[i]) continue;
            if (!attached[i].exists)
            {
                attachedLive[i] = false;
                ActiveHandles--;
                continue;
            }
            if (!held && !attachedRootStopped[i])
            {
                attached[i].StopRoot();
                attachedRootStopped[i] = true;
            }
            attached[i].SetLocation(center);
            attached[i].SetAllColor(new Color(1f, 1f, 1f, fade));
        }

        // A level signal is accepted, but can never replay the pulse each frame.
        if (!contactPlayed && contactPulse > .025f)
        {
            contactPlayed = true;
            if (contactAsset)
            {
                var parameters = EffekseerPlayEffectParameters.Create(center);
                parameters.SetScale(Vector3.one);
                contact = EffekseerSystem.PlayEffect(contactAsset, parameters);
                contactLive = contact.enabled;
                if (contactLive) ActiveHandles++;
            }
        }
        if (contactLive)
        {
            if (!contact.exists)
            {
                contactLive = false;
                ActiveHandles--;
            }
            else
            {
                contact.SetLocation(center);
                contact.SetAllColor(new Color(1f, 1f, 1f, fade));
            }
        }
    }

    /// <summary>Cancel, death, retry, or target exit; only stop handles owned here.</summary>
    public void StopAll()
    {
        for (int i = 0; i < attached.Length; i++)
        {
            StopAttached(i);
            attachedRootStopped[i] = false;
        }
        if (contactLive)
        {
            contact.Stop();
            ActiveHandles--;
        }
        contactLive = false;
        contactPlayed = false;
        previouslyHeld = false;
        nextSlot = 0;
        nextRenew = 0f;
    }

    void StopAttached(int index)
    {
        if (!attachedLive[index]) return;
        attached[index].Stop();
        attachedLive[index] = false;
        ActiveHandles--;
    }

    void OnDisable() { StopAll(); }
    void OnDestroy() { StopAll(); }
}
