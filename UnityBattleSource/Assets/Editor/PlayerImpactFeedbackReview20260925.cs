using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

public static class PlayerImpactFeedbackReview20260925
{
    const string Key = "PlayerImpactFeedbackReview20260925";
    public static void Begin()
    {
        SessionState.SetBool(Key, true);
        EditorSceneManager.OpenScene("Assets/Scenes/BattlePrototype.unity");
        EditorApplication.isPlaying = true;
    }
    [InitializeOnLoadMethod] static void Hook()
    {
        EditorApplication.playModeStateChanged += state => {
            if (!SessionState.GetBool(Key, false)) return;
            if (state == PlayModeStateChange.EnteredPlayMode)
                new GameObject(Key).AddComponent<PlayerImpactFeedbackReviewRunner20260925>();
            if (state == PlayModeStateChange.EnteredEditMode) {
                SessionState.SetBool(Key, false); EditorApplication.Exit(0);
            }
        };
    }
}

public sealed class PlayerImpactFeedbackReviewRunner20260925 : MonoBehaviour
{
    readonly List<string> checks = new List<string>();
    UnityBattleBridge bridge;
    BattlePrototype battle;
    PlayerImpactFeedback20260925 feedback;
    string output;
    string context = "review-a";
    long sequence;
    void Send(string action) => bridge.ApplyCommand("{\"action\":\"" + action + "\"}");
    void Context(string value) { context = value; sequence = 0; Send("player-impact-context:" + context); }
    string Packet(int hp = 90, int shield = 0, bool dead = false, bool reduce = false)
        => "player-impact:" + context + ";" + (++sequence) + ";" + hp + ";" + shield + ";1000;" + (dead ? 1 : 0) + ";" + (reduce ? 1 : 0);
    void Check(bool ok, string name)
    {
        if (!ok) {
            File.WriteAllText(output + "/unity-player-impact-failed.txt", name);
            Debug.LogError("PLAYER_IMPACT_FAIL " + name); EditorApplication.Exit(3);
            throw new System.Exception(name);
        }
        checks.Add(name); Debug.Log("PLAYER_IMPACT_PASS " + name);
    }
    IEnumerator Start()
    {
        output = Path.GetFullPath(Path.Combine(Application.dataPath, "../../output/player-impact-feedback-20260925/checks"));
        Directory.CreateDirectory(output);
        float deadline = Time.realtimeSinceStartup + 30;
        while ((!battle || !battle.IsPresentationReady) && Time.realtimeSinceStartup < deadline) {
            battle = FindFirstObjectByType<BattlePrototype>(); yield return null;
        }
        Check(battle && battle.IsPresentationReady, "formal battle scene ready");
        bridge = FindFirstObjectByType<UnityBattleBridge>();
        Check(bridge, "formal native bridge available");
        Send("combat-stop"); Send("clock-guard"); Send("combat-start"); Context("review-a");
        feedback = battle.PlayerImpactFeedback;
        Check(feedback && feedback.MappedJointCount >= 2, "real hero torso bones mapped");
        var actor = feedback.transform;
        var animator = actor.GetComponentInChildren<Animator>();
        var choreography = actor.GetComponent<FoolSkillChoreography>();
        var head = animator.GetBoneTransform(HumanBodyBones.Head);
        var rootPosition = actor.position; var rootRotation = actor.rotation; var rootScale = actor.localScale;
        float timeScale = Time.timeScale;
        var camera = Camera.main; var cameraPosition = camera.transform.position;
        var cameraProjection = camera.projectionMatrix;
        int count = feedback.PlayCount;
        Send(Packet(0, 0)); Check(feedback.PlayCount == count, "zero loss/control/immune rejected");
        Send("player-impact:review-a;2;-1;0;1000;0;0");
        Check(feedback.PlayCount == count, "negative loss rejected");
        sequence = 2;
        var firstPacket = Packet(); Send(firstPacket);
        Check(feedback.PlayCount == ++count && feedback.IsPlaying, "positive HP loss accepted once");
        Send(firstPacket); Check(feedback.PlayCount == count, "same-context repeated sequence rejected");
        Send("player-impact-context:" + context); Send(firstPacket);
        Check(feedback.PlayCount == count, "duplicate context command cannot re-enable old sequence");
        yield return new WaitForSeconds(.05f);
        Check(feedback.PeakAppliedDegrees > .1f, "real torso additive pose applied");
        float hpPeak = feedback.PeakAppliedDegrees;
        Check((actor.position-rootPosition).sqrMagnitude < .0000001f && Quaternion.Angle(actor.rotation,rootRotation) < .001f
            && (actor.localScale-rootScale).sqrMagnitude < .0000001f, "impact never changes actor root transform");
        Send(Packet(0, 60)); yield return new WaitForSeconds(.05f);
        Check(feedback.LastWasShieldOnly && feedback.PeakAppliedDegrees < hpPeak, "shield-only reaction weaker than HP loss");
        Send(Packet(90, 0, false, true)); yield return new WaitForSeconds(.05f);
        Check(feedback.PeakAppliedDegrees < hpPeak * .5f, "reduce motion attenuates body response");
        Send(Packet()); Send(Packet());
        Check(feedback.IsPlaying && feedback.LastSequence == sequence, "distinct rapid contacts replace one owned pulse");
        yield return new WaitForSeconds(.40f);
        Check(!feedback.IsPlaying && feedback.LastPoseWeight == 0, "pulse completely finishes");
        Check(Time.timeScale == timeScale && (camera.transform.position-cameraPosition).sqrMagnitude < .0000001f
            && camera.projectionMatrix == cameraProjection, "no global time/camera state modified");

        Send("basic:clock-guard-primary"); yield return new WaitForSeconds(.06f); Send(Packet());
        Check(choreography.IsPlaying && choreography.CurrentSkill == FoolSkillChoreography.BasicID, "reaction does not replace live basic choreography");
        yield return new WaitForSeconds(.06f); Send("skill:fool_skill_07:clock-guard-primary");
        yield return new WaitForSeconds(.08f);
        Check(choreography.IsPlaying && choreography.CurrentSkill == "fool_skill_07", "basic-to-skill transition retains new skill owner");
        feedback.Clear();
        Check(choreography.IsPlaying && choreography.CurrentSkill == "fool_skill_07", "impact cleanup cannot clear newer cast");
        yield return new WaitForSeconds(1.5f);

        Send(Packet()); yield return new WaitForSeconds(.05f);
        Quaternion newerHead = Quaternion.Euler(11, 13, 17);
        head.localRotation = newerHead; feedback.Clear();
        Check(Quaternion.Angle(head.localRotation, newerHead) < .001f, "cleanup leaves a newer bone writer untouched");
        animator.Update(0); yield return null;
        Send(Packet()); yield return new WaitForSeconds(.04f);
        Send("combat-stop");
        Check(!feedback.IsPlaying, "combat stop clears active recoil");
        Send(firstPacket); Check(!feedback.IsPlaying, "stopped fight rejects late packet");
        Send("combat-start"); Context("review-retry");
        Send(firstPacket); Check(!feedback.IsPlaying, "retry rejects previous context");
        Send(Packet()); Check(feedback.IsPlaying, "retry accepts fresh context");
        Send("wave-instances:clock-guard-primary");
        Check(!feedback.IsPlaying, "wave replacement clears active recoil");
        Context("review-wave"); Send(Packet());
        Check(feedback.IsPlaying, "new wave can react");
        Send(Packet(1000, 0, true));
        Check(!feedback.IsPlaying, "authoritative fatal loss clears without recoil");
        Send(Packet()); Check(!feedback.IsPlaying, "fatal context refuses later recoil");
        Send("player-reset"); Context("review-after-death"); Send(Packet());
        Check(feedback.IsPlaying, "player reset plus fresh context recovers");
        Send("player-defeated");
        Check(!feedback.IsPlaying, "explicit death owns body and clears recoil");
        Send("player-reset"); Context("review-disable"); Send(Packet());
        feedback.enabled = false;
        Check(!feedback.IsPlaying, "component disable clears owned pose/context");
        feedback.enabled = true; Send(Packet());
        Check(!feedback.IsPlaying, "reenable alone cannot accept stale context");
        Check(PlayerImpactFeedback20260925.Envelope(-1) == 0 && PlayerImpactFeedback20260925.Envelope(0) == 0
            && PlayerImpactFeedback20260925.Envelope(PlayerImpactFeedback20260925.Duration) == 0
            && PlayerImpactFeedback20260925.Envelope(float.NaN) == 0, "negative/start/end/nonfinite envelope boundaries");
        Send("combat-stop");
        File.WriteAllLines(output + "/unity-player-impact-passed.txt", checks);
        EditorApplication.isPlaying = false;
    }
}
