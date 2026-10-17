using System;
using System.Collections;
using System.Globalization;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Animations.Rigging;

// Captures the current production model selection, materials and battle camera.
// It runs only in the Editor and never opens the iOS player's saved profile.
public static class CharacterPolishPreview20261016
{
    const string Key = "CharacterPolishPreview20261016";

    public static void Begin()
    {
        var args = Environment.GetCommandLineArgs();
        int index = Array.IndexOf(args, "-characterOutput");
        if (index < 0 || index + 1 >= args.Length)
            throw new ArgumentException("Missing -characterOutput directory.");
        BeginAt(args[index + 1], args.Contains("-shadowfangPreview"), false);
    }

    /// v51: record only the near three-quarter attack views (the rest already captured).
    public static void BeginNear(string output)
    {
        SessionState.SetBool(Key + "OnlyNear", true);
        BeginAt(output, true, true);
    }

    public static void BeginAt(string output, bool shadowfang, bool keepEditor)
    {
        HeroMotionVariationVerification.Verify();
        SessionState.SetBool(Key + "Shadowfang", shadowfang);
        SessionState.SetBool(Key + "KeepEditor", keepEditor);
        SessionState.SetString(Key + "Output", Path.GetFullPath(output));
        SessionState.SetBool(Key, true);
        EditorSceneManager.OpenScene("Assets/Scenes/BattlePrototype.unity");
        if (Camera.main) Camera.main.aspect = 720f / 1280;
        EditorApplication.isPlaying = true;
    }

    [InitializeOnLoadMethod]
    static void Initialize()
    {
        EditorApplication.playModeStateChanged += state =>
        {
            if (!SessionState.GetBool(Key, false)) return;
            if (state == PlayModeStateChange.EnteredPlayMode)
            {
                var runner = new GameObject(Key).AddComponent<CharacterPolishPreviewRunner20261016>();
                runner.Output = SessionState.GetString(Key + "Output", "");
            }
            if (state == PlayModeStateChange.EnteredEditMode)
            {
                SessionState.SetBool(Key, false);
                SessionState.SetBool(Key + "OnlyNear", false);
                if (!SessionState.GetBool(Key + "KeepEditor", false)) EditorApplication.Exit(0);
            }
        };
    }
}

[DefaultExecutionOrder(32000)]
public sealed class CharacterPolishPreviewRunner20261016 : MonoBehaviour
{
    public string Output;
    Camera motionCamera;
    CombatTempoAnimatedBody motionBody;
    StreamWriter motionLog;
    string pendingFrame;
    int motionFrame;

    void Awake()
    {
        if (Camera.main) Camera.main.aspect = 720f / 1280;
    }

    IEnumerator Start()
    {
        AudioListener.volume = 0;
        Application.logMessageReceived += OnLog;
        yield return new WaitForSeconds(2);
        Directory.CreateDirectory(Output);
        var battle = FindFirstObjectByType<BattlePrototype>();
        if (!battle) throw new InvalidOperationException("Battle runtime was not created.");
        battle.SetNativeCombatEnabled(false);
        battle.UseEarlyHellHoundModel();
        battle.SetEarlyBattlePresence("3");
        CombatTempoPresentation.Get(battle).Configure("chapter01_q03_encounter");
        yield return new WaitForSeconds(.5f);

        var body = FindObjectsByType<CombatTempoAnimatedBody>(FindObjectsSortMode.None)
            .FirstOrDefault(value => value.Kind == "Hound" && value.gameObject.activeInHierarchy);
        if (!body) throw new InvalidOperationException("The current early-hound replacement body is missing.");
        if (SessionState.GetBool("CharacterPolishPreview20261016Shadowfang", false))
            body = ShadowfangPreviewImport20261016.ReplaceForReview(body);
        this.battle = battle;
        reviewBody = body;
        hound = FindObjectsByType<EnemyHandle>(FindObjectsSortMode.None).FirstOrDefault(h => h.BattleEnemyId == EnemyBattleIds.HellHoundPrimary);
        {
            var bones = body.GetComponentsInChildren<Transform>();
            headBone = bones.FirstOrDefault(t => t.name == "Head");
            var neck = bones.FirstOrDefault(t => t.name == "Neck");
            var furWind = body.GetComponent<ShadowfangFurWind>();
            if (headBone && neck && furWind) {
                // Between the jaws, in the head's own space so it follows the head as it lifts and sweeps.
                var forward = (headBone.position - neck.position).normalized;
                noseLocal = headBone.InverseTransformPoint(headBone.position + forward * .36f * furWind.WorldUnit - Vector3.up * .12f * furWind.WorldUnit);
            }
        }
        var camera = Camera.main;
        if (!camera) throw new InvalidOperationException("The production battle camera is missing.");
        var animator = body.GetComponent<Animator>();
        var clips = animator.runtimeAnimatorController.animationClips;
        var battlePosition = camera.transform.position;
        var battleRotation = camera.transform.rotation;
        float battleFov = camera.fieldOfView;
        Render(camera, "hound-battle.png", 720, 1280);
        // v49: the production battle view with the hound idling in a gust, to judge
        // whether the fur reads at the size the player actually sees.
        if (SessionState.GetBool("CharacterPolishPreview20261016Shadowfang", false) && !SessionState.GetBool("CharacterPolishPreview20261016OnlyNear", false))
            yield return RecordMotion(camera, body, "BattleIdle", "-battle", 720, 1280);
        var hero = FindFirstObjectByType<AIHeroAnimatedBody>();
        if (hero && hero.Surface) hero.Surface.enabled = false;
        var background = camera.GetComponentsInChildren<Renderer>().Select(value => (renderer: value, visible: value.enabled)).ToArray();
        foreach (var item in background) item.renderer.enabled = false;
        var battleClear = camera.clearFlags;
        camera.clearFlags = CameraClearFlags.SolidColor;
        camera.backgroundColor = new Color(.12f, .13f, .16f);
        var bounds = SkinBounds(body.transform);
        var direction = (battlePosition - bounds.center).normalized;
        camera.transform.position = bounds.center + direction * Mathf.Max(2, bounds.size.y * 2.3f);
        camera.transform.LookAt(bounds.center);
        camera.fieldOfView = 36;
        if (SessionState.GetBool("CharacterPolishPreview20261016OnlyNear", false)) {
            yield return RecordNear(camera, body, bounds, battlePosition, background);
        } else if (SessionState.GetBool("CharacterPolishPreview20261016Shadowfang", false)) {
            var breeze = body.GetComponent<ShadowfangFurWind>();
            var fullPosition=camera.transform.position;
            var fullRotation=camera.transform.rotation;
            var focus=body.GetComponentsInChildren<Transform>().First(t=>t.name=="Head").position-Vector3.up*bounds.size.y*.06f;
            camera.transform.position=focus+direction*Mathf.Max(1,bounds.size.y*1.15f);
            camera.transform.LookAt(focus);
            var windAnimator=body.GetComponent<Animator>();
            body.enabled=false; windAnimator.speed=0;
            if(breeze) breeze.Breeze=false;
            yield return RecordMotion(camera,body,"BattleIdle","-calm");
            if(breeze) breeze.Breeze=true;
            yield return RecordMotion(camera,body,"BattleIdle","-gust");
            body.enabled=true; windAnimator.speed=1;
            camera.transform.position=fullPosition;camera.transform.rotation=fullRotation;
            foreach (var clip in new[] { "Light", "HeavyRelease" })
                yield return RecordMotion(camera, body, clip);
            var frontPosition = camera.transform.position;
            var frontRotation = camera.transform.rotation;
            camera.transform.position = bounds.center + Quaternion.AngleAxis(75, Vector3.up) *
                (frontPosition - bounds.center) * 1.8f;
            camera.transform.LookAt(bounds.center);
            yield return RecordMotion(camera, body, "Light", "-side");
            yield return RecordMotion(camera, body, "HeavyRelease", "-side");
            // v51: the attacks with the game's own effects (painted claw on the bite, hellfire
            // breath poured for the whole open-mouthed release), in the production battle view
            // and from the side with hound and hero both in frame.
            if (hero && hero.Surface) hero.Surface.enabled = true;
            foreach (var item in background) item.renderer.enabled = item.visible;
            camera.clearFlags = battleClear;
            camera.transform.position = battlePosition; camera.transform.rotation = battleRotation; camera.fieldOfView = battleFov;
            foreach (var clip in new[] { "Light", "HeavyRelease" })
                yield return RecordMotion(camera, body, clip, "-battle-vfx", 720, 1280, Attack(clip));
            yield return RecordNear(camera, body, bounds, battlePosition, background);
            camera.fieldOfView = 36;
            if (hero && hero.Surface) hero.Surface.enabled = false;
            foreach (var item in background) item.renderer.enabled = false;
            camera.clearFlags = CameraClearFlags.SolidColor;
            camera.transform.position = frontPosition;
            camera.transform.rotation = frontRotation;
        } else yield return RecordMotion(camera, body);
        body.Cancel();
        body.enabled = false;
        animator.enabled = false;
        foreach (var rig in body.GetComponents<RigBuilder>()) rig.enabled = false;
        Time.timeScale = 0;
        var home = body.transform.localPosition;
        var rotation = body.transform.localRotation;
        var scale = body.transform.localScale;
        void Pose(string name, float phase)
        {
            var clip = clips.First(value => value.name == name);
            body.transform.localPosition = home;
            body.transform.localRotation = rotation;
            body.transform.localScale = scale;
            clip.SampleAnimation(body.gameObject, clip.length * phase);
        }
        Pose("BattleIdle", 0);
        yield return null;

        Render(camera, "hound-closeup.png", 960, 960);
        foreach (var sample in new[] { ("Pounce", .38f), ("HeavyRelease", .58f) })
        {
            Pose(sample.Item1, sample.Item2);
            Render(camera, "hound-" + sample.Item1.ToLowerInvariant() + ".png", 960, 960);
        }
        Pose("BattleIdle", 0);
        camera.transform.position = battlePosition;
        camera.transform.rotation = battleRotation;
        camera.fieldOfView = battleFov;
        foreach (var item in background) if (item.renderer) item.renderer.enabled = item.visible;
        File.WriteAllText(Path.Combine(Output, "capture.txt"),
            "Current runtime early hound, production model selection and materials. " +
            "Battle view retains the production camera; closeups use an Editor review camera. " +
            "Not iPhone evidence or user visual acceptance.\n");
        Debug.Log("CHARACTER_POLISH_PREVIEW_WRITTEN " + Output);
        Application.logMessageReceived -= OnLog;
        Time.timeScale = 1;
        EditorApplication.isPlaying = false;
    }

    int frameWidth = 640, frameHeight = 640;

    BattlePrototype battle;
    CombatTempoAnimatedBody reviewBody;
    EnemyHandle hound;
    Transform headBone;
    Vector3 noseLocal;

    /// The game's own hound effects on the authored timing: the bite's claw marks land on the
    /// lunge's contact; the breath is poured in four painted streams while the mouth is open,
    /// each reaching the hero .78 s after it leaves the mouth, as in PresentHellHoundFireBreathTurn.
    /// Near three-quarter view of both attacks: background off, the camera close to the hound
    /// on the hero's side, with room for the breath to leave the mouth. The bite stays in place
    /// here (its claw marks land on the hero, off frame; the battle view shows them).
    IEnumerator RecordNear(Camera camera, CombatTempoAnimatedBody body, Bounds bounds, Vector3 battlePosition,
        (Renderer renderer, bool visible)[] background)
    {
        foreach (var item in background) item.renderer.enabled = false;
        var clear = camera.clearFlags;
        camera.clearFlags = CameraClearFlags.SolidColor;
        camera.backgroundColor = new Color(.12f, .13f, .16f);
        var toHero = battlePosition - bounds.center; toHero.y = 0; toHero.Normalize();
        var view = Quaternion.AngleAxis(58, Vector3.up) * toHero;
        camera.transform.position = bounds.center + view * bounds.size.y * 3.1f + Vector3.up * bounds.size.y * .35f;
        camera.transform.LookAt(bounds.center + toHero * bounds.size.y * .85f + Vector3.up * bounds.size.y * .1f);
        camera.fieldOfView = 40;
        foreach (var clip in new[] { "Light", "HeavyRelease" })
            yield return RecordMotion(camera, body, clip, "-near-vfx", 1280, 720, Attack(clip, false));
        camera.clearFlags = clear;
    }

    System.Action<float> Attack(string clip, bool lunge = true)
    {
        if (!battle || !hound) return null;
        var fireball = battle.GetComponent<HellHoundEffekseerFireball>();
        var root = hound.EnemyRoot;
        var home = root.position;
        System.Func<Vector3> target = () => battle.PlayerFireBreathImpactAnchor;
        System.Func<Vector3> mouth = () => headBone ? headBone.TransformPoint(noseLocal) : SpellSpectacle20260926.AnchorOf(hound);
        var done = new System.Collections.Generic.HashSet<string>();
        bool Once(string key) => done.Add(key);
        string actor = "enemy:" + hound.BattleEnemyId;
        float length = reviewBody.GetComponent<Animator>().runtimeAnimatorController.animationClips.First(c => c.name == clip).length;
        if (clip == "HeavyRelease")
            return t => {
                foreach (var at in new[] { .45f, 1.2f, 1.95f, 2.7f }) {
                    if (t >= at - .2f && Once("begin" + at)) SpellSpectacle20260926.BeginEnemy(battle, hound, "strike", target, null);
                    if (at == .45f && t >= at - .2f && Once("charge") && fireball) StartCoroutine(fireball.PlayCharge(mouth, target));
                    if (t >= at && Once("stream" + at)) SpellSpectacle20260926.EnemyBreath(hound, mouth, target, .78f);
                    if (t >= at + .78f && Once("hit" + at)) UnityBattleBridge.ReportCombatContact(actor);
                }
            };
        // The bite: launch at half the clip, contact at 58 % (animate-v49's Light), back home after.
        var ground = target(); ground.y = home.y;
        var strike = Vector3.Lerp(home, ground, .65f);
        float launch = .5f * length, contact = .58f * length, leave = .74f * length, back = .9f * length;
        return t => {
            if (t >= contact - .4f && Once("begin")) SpellSpectacle20260926.BeginEnemy(battle, hound, "bite", target, null);
            if (!lunge) { }
            else if (t < launch || t > back + .2f) root.position = home;
            else if (t < contact) { float u = (t - launch) / (contact - launch); root.position = Vector3.Lerp(home, strike, u) + Vector3.up * Mathf.Sin(u * Mathf.PI) * .35f; }
            else if (t < leave) root.position = strike;
            else root.position = Vector3.Lerp(strike, home, Mathf.SmoothStep(0, 1, (t - leave) / (back - leave)));
            if (t >= contact && Once("hit")) UnityBattleBridge.ReportCombatContact(actor);
        };
    }

    IEnumerator RecordMotion(Camera camera, CombatTempoAnimatedBody body, string clip = "HeavyRelease", string suffix = "", int width = 640, int height = 640, System.Action<float> onTime = null)
    {
        frameWidth = width; frameHeight = height;
        bool still = clip == "BattleIdle" && (suffix == "-calm" || suffix == "-gust");
        string folder = (clip == "HeavyRelease" ? "heavy-release" : clip) + suffix;
        Directory.CreateDirectory(Path.Combine(Output, folder));
        motionCamera = camera;
        motionBody = body;
        motionLog = new StreamWriter(Path.Combine(Output, folder + ".csv")) { AutoFlush = true };
        motionLog.WriteLine("frame,time,acting,rootX,rootY,rootZ,hipsX,hipsY,hipsZ");
        var wind=body.GetComponent<ShadowfangFurWind>();
        if(wind) { wind.Direction=camera.transform.right; wind.ResetTrial(); }
        Time.captureFramerate = 30;
        body.Idle();
        bool authoredReview = SessionState.GetBool("CharacterPolishPreview20261016Shadowfang", false);
        float duration = authoredReview
            ? body.GetComponent<Animator>().runtimeAnimatorController.animationClips.First(c => c.name == clip).length
            : .45f;
        int frameCount = authoredReview ? Mathf.CeilToInt(duration * 30) + 30 : 75;
        if(clip == "BattleIdle") frameCount=240;
        if(onTime != null) frameCount += 24;   // let the last flames and claw marks clear
        for (int frame = 0; frame < frameCount; frame++)
        {
            if(still) body.GetComponent<Animator>().speed=0;
            if (frame == 15 && clip != "BattleIdle") {
                if (clip == "HitAdditive") body.ConfirmedHit(true);
                // Review authored duration explicitly; the old .45 contact retimed
                // every long animation into less than a second.
                else body.Play(clip, duration, authoredReview || clip == "Walking", 0);
            }
            onTime?.Invoke((frame - 15) / 30f);
            motionFrame = frame;
            pendingFrame = folder + "/frame-" + frame.ToString("D3") + ".png";
            yield return null;
        }
        pendingFrame = null;
        if(wind) File.AppendAllText(Path.Combine(Output,"wind-metrics.txt"), folder+" peakResponse="+wind.PeakResponse+" worldUnit="+wind.WorldUnit+" finite="+wind.Finite+" windAtEnd="+wind.CurrentWind+"\n");
        motionLog.Dispose();
        motionLog = null;
        motionBody = null;
        motionCamera = null;
        Time.captureFramerate = 0;
    }

    void LateUpdate()
    {
        if (pendingFrame == null || !motionCamera || !motionBody) return;
        Render(motionCamera, pendingFrame, frameWidth, frameHeight);
        var position = motionBody.transform.localPosition;
        var hips = motionBody.GetComponentsInChildren<Transform>().FirstOrDefault(t => t.name == "Hips");
        var hipsPosition = hips ? motionBody.transform.InverseTransformPoint(hips.position) : Vector3.zero;
        motionLog.WriteLine(string.Join(",", motionFrame, (motionFrame / 30f).ToString("R", CultureInfo.InvariantCulture),
            motionBody.IsActing ? 1 : 0, position.x.ToString("R", CultureInfo.InvariantCulture),
            position.y.ToString("R", CultureInfo.InvariantCulture), position.z.ToString("R", CultureInfo.InvariantCulture),
            hipsPosition.x.ToString("R", CultureInfo.InvariantCulture),
            hipsPosition.y.ToString("R", CultureInfo.InvariantCulture),
            hipsPosition.z.ToString("R", CultureInfo.InvariantCulture)));
        pendingFrame = null;
    }

    static Bounds SkinBounds(Transform root)
    {
        bool found = false;
        Bounds bounds = default;
        foreach (var skin in root.GetComponentsInChildren<SkinnedMeshRenderer>())
        {
            if (!skin.enabled) continue;
            // FBX bounds may include the whole animation range, but keep the
            // original scale convention. BakeMesh on this imported hierarchy
            // compensates scale differently and is unsuitable for framing it.
            if (!found) { bounds = skin.bounds; found = true; }
            else bounds.Encapsulate(skin.bounds);
        }
        if (!found) throw new InvalidOperationException("Current hound skin bounds are unavailable.");
        return bounds;
    }

    void Render(Camera camera, string name, int width, int height)
    {
        var previousTarget = camera.targetTexture;
        var previousActive = RenderTexture.active;
        float previousAspect = camera.aspect;
        var target = new RenderTexture(width, height, 24, RenderTextureFormat.ARGB32) { antiAliasing = 1 };
        var texture = new Texture2D(width, height, TextureFormat.RGB24, false);
        try
        {
            camera.aspect = (float)width / height;
            camera.targetTexture = target;
            camera.Render();
            RenderTexture.active = target;
            texture.ReadPixels(new Rect(0, 0, width, height), 0, 0);
            texture.Apply();
            File.WriteAllBytes(Path.Combine(Output, name), texture.EncodeToPNG());
        }
        finally
        {
            camera.targetTexture = previousTarget;
            camera.aspect = previousAspect;
            RenderTexture.active = previousActive;
            DestroyImmediate(texture);
            DestroyImmediate(target);
        }
    }

    void OnLog(string message, string stack, LogType type)
    {
        if (type != LogType.Exception && type != LogType.Assert) return;
        if (stack.Contains("UnityEditor.Search.")) return;
        Application.logMessageReceived -= OnLog;
        Directory.CreateDirectory(Output);
        File.WriteAllText(Path.Combine(Output, "capture-error.txt"), message + "\n" + stack);
        EditorApplication.Exit(2);
    }
}
