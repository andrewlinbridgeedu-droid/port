using System;
using System.Collections.Generic;
using UnityEngine;

public static class HeroMotionVariationVerification
{
    public static void Verify()
    {
        foreach (var outfit in new[] { "mistport-night", "starlight-magician", "midnight-carnival" })
            foreach (var action in AIHeroAnimatedBody.Actions) {
                string path = "CombatTempo/AIHero/" + outfit + "/" + action;
                var info = Resources.Load<TextAsset>(path);
                if (!info || !Resources.Load<Texture2D>(path) || !Resources.Load<Texture2D>(path + "-idle"))
                    throw new Exception("Missing motion take: " + path);
                var clip = JsonUtility.FromJson<AIHeroAnimatedBody.ClipInfo>(info.text);
                if (clip.frames <= 1 || clip.releaseFrame <= 0 || clip.releaseFrame >= clip.frames || clip.sourceEnd <= clip.sourceRelease)
                    throw new Exception("Invalid release timing: " + path);
            }
        var parent = new GameObject("Temporary hero feedback verification");
        parent.hideFlags = HideFlags.DontSave;
        try {
            var body = AIHeroAnimatedBody.Install(parent.transform,
                new Bounds(Vector3.up, new Vector3(1, 2, 1)), "mistport-night");
            if (!body) throw new Exception("Could not create the actual illustrated hero");
            Check(body, "basic-only", new[] { "basic" });
            Check(body, "opening-card", new[] { "fool_skill_01", "basic" });
            Check(body, "two-card-Q5", new[] { "fool_skill_01", "fool_skill_04", "basic" });
            foreach (var skill in new[] { "fool_skill_01", "fool_skill_02", "fool_skill_04", "fool_skill_05", "fool_skill_06", "fool_skill_07", "fool_skill_08", "fool_skill_09", "fool_skill_10" })
                Check(body, skill + "-with-basic", new[] { skill, "basic" });
            CheckHitPause(body);
        } finally { UnityEngine.Object.DestroyImmediate(parent); }
        Debug.Log("HERO_MOTION_VARIATION_VERIFIED outfits=3 takes=15 sequences=12 hitPause=passed");
    }

    static void CheckHitPause(AIHeroAnimatedBody body)
    {
        float now = Time.unscaledTime;
        body.PlaySkill("fool_skill_01", .6192f);
        body.AdvancePresentation(.2f, now);
        float frame = body.DisplayFrame;
        body.ConfirmedHit(.3f);
        body.AdvancePresentation(.05f, now + .05f);
        if (!body.IsRecoiling || body.DisplayFrame != frame || !body.IsHitPausedAt(now + .05f))
            throw new Exception("A cast did not hold its visible frame while showing the hit");
        body.AdvancePresentation(.06f, now + .11f);
        if (body.DisplayFrame <= frame || body.IsHitPausedAt(now + .11f))
            throw new Exception("The held cast did not resume after the short hit pause");
        body.PlayAction(AIHeroAnimatedBody.Actions[0], .08f);
        body.AdvancePresentation(.8f, now);
        body.ConfirmedHit(1f);
        body.AdvancePresentation(.11f, now + .11f);
        if (body.IsActing || !body.IsRecoiling)
            throw new Exception("Finishing a cast erased its late hit reaction");
        body.Cancel();
        if (body.IsRecoiling || body.IsHitPausedAt(now)) throw new Exception("Exit did not clear the hit pause");
        Debug.Log("HERO_HIT_PAUSE_VERIFIED held-frame resume late-hit exit-clear");
    }

    static void Check(AIHeroAnimatedBody body, string label, string[] inputs)
    {
        var seen = new HashSet<string>();
        string previous = null;
        for (int i = 0; i < 30; i++) {
            string skill = inputs[i % inputs.Length];
            body.PlaySkill(skill, skill == "basic" ? .58f : FoolSkillChoreography.ExpectedContact(skill));
            string action = body.CurrentAction;
            if (action == previous) throw new Exception(label + " repeated a consecutive take: " + action);
            if (Array.IndexOf(AIHeroAnimatedBody.Actions, action) < 0) throw new Exception(label + " selected a missing take");
            seen.Add(action); previous = action;
        }
        if (seen.Count != 5) throw new Exception(label + " did not use all five takes: " + seen.Count);
        Debug.Log("HERO_MOTION_SEQUENCE " + label + " takes=" + seen.Count);
    }
}
