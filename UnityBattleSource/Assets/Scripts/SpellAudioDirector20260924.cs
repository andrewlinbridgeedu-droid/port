using System;
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// Presentation-only audio. Native combat remains authoritative: a contact
/// sound is emitted only when the existing Unity/native contact callback fires.
/// All samples are original procedural renders in Resources/Audio/Spell.
/// </summary>
public sealed class SpellAudioDirector20260924 : MonoBehaviour
{
    sealed class Pending
    {
        public string profile;
        public float expiresAt;
        public float lastContact = float.NegativeInfinity;
    }

    static SpellAudioDirector20260924 instance;
    const float DefaultVolume = .60f;
    static float masterVolume = DefaultVolume;
    /// Other battle sounds were mixed at the default combat volume; they follow the player's setting.
    public static float Scaled(float volumeAtDefault) => Mathf.Clamp01(volumeAtDefault * masterVolume / DefaultVolume);
    readonly Dictionary<string, Pending> pending = new Dictionary<string, Pending>();
    readonly Dictionary<string, AudioClip> clips = new Dictionary<string, AudioClip>();
    AudioSource source;

    static SpellAudioDirector20260924 Ensure(BattlePrototype battle)
    {
        if (instance) return instance;
        if (!battle) return null;
        instance = battle.GetComponent<SpellAudioDirector20260924>();
        if (!instance) instance = battle.gameObject.AddComponent<SpellAudioDirector20260924>();
        return instance;
    }

    void Awake()
    {
        instance = this;
        source = gameObject.AddComponent<AudioSource>();
        source.playOnAwake = false;
        source.spatialBlend = 0f;
        source.volume = masterVolume;
        source.priority = 100;
    }

    public static void SetVolume(float volume)
    {
        masterVolume = Mathf.Clamp01(volume);
        if (instance && instance.source) instance.source.volume = masterVolume;
    }

    public static void BeginPlayer(BattlePrototype battle, string skillID)
    {
        var director = Ensure(battle);
        if (!director) return;
        string profile = PlayerProfile(skillID);
        director.Begin("player", profile, false);
    }

    public static void BeginEnemy(BattlePrototype battle, string actorID, string intent, string modelID)
    {
        var director = Ensure(battle);
        if (!director || string.IsNullOrEmpty(actorID)) return;
        string key = "enemy:" + actorID;
        if (intent == "recover") { director.pending.Remove(key); return; }
        bool preparing = intent == "charge" || intent.EndsWith("charge", StringComparison.Ordinal)
            || intent.EndsWith("charge2", StringComparison.Ordinal);
        string profile = EnemyProfile(actorID, intent, modelID);
        director.Begin(key, profile, preparing);
    }

    void Begin(string key, string profile, bool preparing)
    {
        pending[key] = new Pending { profile = profile, expiresAt = Time.unscaledTime + 5f };
        Play(profile, "cast", preparing ? .37f : key == "player" && profile == "paper" ? .39f : .59f);
    }

    public static void Contact(string actor)
    {
        if (!instance || !instance.source || masterVolume <= 0f || string.IsNullOrEmpty(actor)) return;
        if (!instance.pending.TryGetValue(actor, out var cue) || Time.unscaledTime > cue.expiresAt) return;
        // A two-projectile attack may legally contact twice. Reject only same-
        // frame duplicate callbacks, not the second authored hit.
        if (Time.unscaledTime - cue.lastContact < .085f) return;
        cue.lastContact = Time.unscaledTime;
        instance.Play(cue.profile, "impact", actor == "player" && cue.profile == "paper" ? .40f : .69f);
    }

    void Play(string profile, string phase, float gain)
    {
        if (masterVolume <= 0f || !source) return;
        var key = profile + "_" + phase;
        if (!clips.TryGetValue(key, out var clip))
        {
            clip = Resources.Load<AudioClip>("Audio/Spell/" + key);
            clips[key] = clip;
            if (!clip) { Debug.LogWarning("SPELL_AUDIO_MISSING " + key); return; }
        }
        source.PlayOneShot(clip, gain);
    }

    public static void StopAll()
    {
        if (!instance) return;
        instance.pending.Clear();
        if (instance.source) instance.source.Stop();
    }

    void OnDestroy()
    {
        if (instance == this) instance = null;
    }

    public static string PlayerProfile(string skillID)
    {
        switch (skillID)
        {
            case "basic": return "paper";
            case "defend": return "ward";
            case "fool_skill_01": return "sidestep";
            case "fool_skill_02": return "mask";
            case "fool_skill_03": return "paper"; // Retired card on old saves only.
            case "fool_skill_04": return "identity";
            case "fool_skill_05": return "seal";
            case "fool_skill_06": return "chase";
            case "fool_skill_07": return "climax";
            case "fool_skill_08": return "reversal";
            case "fool_skill_09": return "ward";
            case "fool_skill_10": return "declaration";
            default: return "paper";
        }
    }

    public static string EnemyProfile(string actorID, string intent, string modelID)
    {
        intent = intent ?? "strike";
        actorID = actorID ?? "";
        modelID = modelID ?? "";
        if (intent == "repair_guard" || intent == "tower_mend" || intent == "tower_empower"
            || intent == "bounty_transfer") return "heal";
        if (intent == "guard" || intent == "fortify" || intent == "tower_armor") return "ward";
        if (intent.Contains("sac_charge")) return "poison";
        if (intent.Contains("poison") || intent.Contains("spittle")) return "poison";
        if (intent.Contains("salt_spike")) return "crystal";
        if (intent.Contains("sound_arrow") || intent.Contains("throat") || intent.Contains("knock")) return "bell";
        if (intent.Contains("flame") || intent.Contains("brute")) return "fire";
        if (intent.Contains("copperback") || intent.Contains("armor")) return "metal";
        if (intent.Contains("veil") || intent.Contains("silk")) return "silk";
        if (intent.Contains("moonfang") || intent.Contains("claw") || intent.Contains("tail_sweep")) return "bone";
        if (intent.Contains("cut") || intent.Contains("blade")) return "metal";
        if (intent.Contains("pounce") || intent.Contains("rend")) return "beast";
        if (intent.Contains("mend")) return "heal";
        if (intent.Contains("overwrite") || intent.Contains("copy")) return "ink";
        if (intent.Contains("bind")) return "seal";
        if (intent.Contains("mirror")) return "mirror";
        if (intent.Contains("true_stab")) return "paper";
        if (intent.Contains("heavy_strike") && (actorID.Contains("b03") || modelID.Contains("b03"))) return "water";
        if (intent.Contains("archive_slam")) return "stone";

        string identity = actorID + ":" + modelID;
        if (identity.Contains("bounty_b01") || identity.Contains("bounty-b01")) return "metal";
        if (identity.Contains("bounty_b02") || identity.Contains("bounty-b02")) return "seal";
        if (identity.Contains("bounty_b03") || identity.Contains("bounty-b03")) return "water";
        if (identity.Contains("bounty_b04") || identity.Contains("bounty-b04")) return "ink";
        if (identity.Contains("bounty_b05") || identity.Contains("bounty-b05")) return "silk";
        if (identity.Contains("bounty_b06") || identity.Contains("bounty-b06")) return "metal";
        if (identity.Contains("bounty_b07") || identity.Contains("bounty-b07")) return "frog";
        if (identity.Contains("bounty_b08") || identity.Contains("bounty-b08")) return "mirror";
        if (identity.Contains("bounty_b09") || identity.Contains("bounty-b09")) return "beast";
        if (identity.Contains("bounty_b10") || identity.Contains("bounty-b10")) return "silk";
        if (identity.Contains("ghost") || identity.Contains("wraith")) return "ghost";
        if (identity.Contains("emerald")) return "poison";
        if (identity.Contains("armored-hell") || identity.Contains("armored_hell")) return "magma";
        if (identity.Contains("hound") || identity.Contains("emberwolf")) return "fire";
        if (identity.Contains("leech") || identity.Contains("memory")) return "mind";
        if (identity.Contains("chronarch") || identity.Contains("clock-core")) return "clock";
        if (identity.Contains("scribe") || identity.Contains("executor") || identity.Contains("archivist")) return "machine";
        if (identity.Contains("matriarch") || identity.Contains("threadweaver")) return "silk";
        if (identity.Contains("saltmaw") || identity.Contains("salt_sac")) return "poison";
        if (identity.Contains("shellback")) return "heal";
        if (identity.Contains("stonehide") || identity.Contains("shield-jaw")) return "stone";
        if (identity.Contains("frilled") || identity.Contains("crown")) return "bell";
        if (identity.Contains("boneclaw")) return "bone";
        if (identity.Contains("golden-throat")) return "frog";
        if (identity.Contains("copperback")) return "metal";
        if (identity.Contains("veil-oracle")) return "silk";
        if (identity.Contains("crimson-brute")) return "fire";
        if (identity.Contains("moonfang")) return "bone";
        if (identity.Contains("clock")) return "metal";
        return "metal";
    }
}
