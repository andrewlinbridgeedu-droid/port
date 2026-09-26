using System;
using UnityEditor;
using UnityEngine;

public static class SpellAudioVerification20260924
{
    public static void Run()
    {
        var keys = AssetDatabase.FindAssets("t:AudioClip", new[] { "Assets/Resources/Audio/Spell" });
        if (keys.Length != 58) throw new Exception("Expected 58 authored spell cues, found " + keys.Length);
        string[] profiles = {
            "paper", "sidestep", "mask", "identity", "mirror", "seal", "chase", "climax", "reversal",
            "ward", "declaration", "ghost", "fire", "magma", "poison", "water", "metal",
            "machine", "silk", "bell", "bone", "heal", "beast", "crystal", "stone",
            "clock", "mind", "ink", "frog"
        };
        foreach (var profile in profiles)
        foreach (var phase in new[] { "cast", "impact" })
        {
            var clip = Resources.Load<AudioClip>("Audio/Spell/" + profile + "_" + phase);
            if (!clip || clip.channels != 1 || clip.frequency != 22050 || clip.length < .12f || clip.length > .9f)
                throw new Exception("Invalid cue " + profile + " " + phase);
        }
        Expect("hero basic", SpellAudioDirector20260924.PlayerProfile("basic"), "paper");
        Expect("hero sidestep", SpellAudioDirector20260924.PlayerProfile("fool_skill_01"), "sidestep");
        Expect("hero identity", SpellAudioDirector20260924.PlayerProfile("fool_skill_04"), "identity");
        Expect("hero finale", SpellAudioDirector20260924.PlayerProfile("fool_skill_07"), "climax");
        Expect("hero ultimate", SpellAudioDirector20260924.PlayerProfile("fool_skill_10"), "declaration");
        Expect("b02 bind", Enemy("bounty_b02_abductor", "bounty_bind", "bounty-b02"), "seal");
        Expect("b03 sea", Enemy("bounty_b03_drowned_captain", "heavy_strike", "bounty-b03"), "water");
        Expect("b07 toxic spit", Enemy("bounty_b07_knocker", "bounty_spittle", "bounty-b07"), "poison");
        Expect("b08 mirror", Enemy("bounty_b08_miren", "bounty_mirror", "bounty-b08"), "mirror");
        Expect("b09 armor", Enemy("bounty_b09_contract_eater", "bounty_armor", "bounty-b09"), "metal");
        Expect("b10 transfer", Enemy("bounty_b10_life_vessel", "bounty_transfer", "bounty-b10"), "heal");
        Expect("salt spike", Enemy("tower_1", "tower_salt_spike", "saltmaw"), "crystal");
        Expect("real salt sac spike", Enemy("church_d02_salt_sac_1", "tower_salt_spike", "church-d02"), "crystal");
        Expect("salt sac charge", Enemy("church_d02_salt_sac_1", "tower_sac_charge", "church-d02"), "poison");
        Expect("frog voice", Enemy("tower_2", "tower_throat_first", "golden-throat"), "bell");
        Expect("moonfang", Enemy("tower_3", "tower_moonfang_second", "moonfang"), "bone");
        Expect("copper armor", Enemy("tower_4", "tower_copperback_first", "copperback"), "metal");
        Expect("brute flame", Enemy("tower_5", "tower_brute_second", "crimson-brute"), "fire");
        Expect("veil", Enemy("tower_6", "tower_veil_first", "veil-oracle"), "silk");
        Expect("early hound", Enemy("hell-hound-primary", "strike", "early-hell-hound"), "fire");
        Expect("memory", Enemy("memory-leech-primary", "name_devour", "memory-leech"), "mind");
        Expect("boss clock", Enemy("chronarch-primary", "strike", "chronarch"), "clock");
        Debug.Log("SPELL_AUDIO_VERIFY_PASSED 58 assets / 22 semantic routes");
    }

    static string Enemy(string actor, string intent, string model) =>
        SpellAudioDirector20260924.EnemyProfile(actor, intent, model);

    static void Expect(string name, string actual, string expected)
    {
        if (actual != expected) throw new Exception(name + ": expected " + expected + ", got " + actual);
    }
}
