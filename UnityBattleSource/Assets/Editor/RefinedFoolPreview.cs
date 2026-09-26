using System;
using System.Collections;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

public static class RefinedFoolPreview
{
    const string Key = "Mindstone.RefinedFoolPreview";
    public static void Begin()
    {
        SessionState.SetBool(Key,true);
        EditorSceneManager.OpenScene("Assets/Scenes/BattlePrototype.unity");
        EditorApplication.isPlaying=true;
    }
    [InitializeOnLoadMethod] static void Restore()
    {
        EditorApplication.playModeStateChanged += state => {
            if (!SessionState.GetBool(Key,false)) return;
            if (state==PlayModeStateChange.EnteredPlayMode) new GameObject("Refined Fool QA").AddComponent<RefinedFoolPreviewRunner>();
            if (state==PlayModeStateChange.EnteredEditMode) { SessionState.SetBool(Key,false);EditorApplication.Exit(0); }
        };
    }
}
public sealed class RefinedFoolPreviewRunner:MonoBehaviour
{
    IEnumerator Start()
    {
        yield return new WaitForSeconds(1);
        var actor=GameObject.Find("Fool_Imported");var animator=actor.GetComponent<Animator>();
        var flutter=actor.GetComponent<FoolRibbonFlutter>();
        var ribbons=actor.GetComponentsInChildren<SkinnedMeshRenderer>().Where(r=>r.name.StartsWith("FoolRibbon")).ToArray();
        bool original = Environment.GetEnvironmentVariable("MISTPORT_ORIGINAL_FOOL_PREVIEW") == "1";
        if (!animator.isHuman || (original ? ribbons.Length != 0 || flutter != null : ribbons.Length != 2)) { EditorApplication.Exit(3);yield break; }
        var floor=GameObject.Find("Clock Arena");if(floor)floor.SetActive(false);
        foreach(var ring in FindObjectsByType<Transform>(FindObjectsSortMode.None)) if(ring.name.StartsWith("Arena Rune Ring"))ring.gameObject.SetActive(false);
        var dir=Path.GetFullPath(Environment.GetEnvironmentVariable("MISTPORT_ACTOR_PREVIEW_OUTPUT") ?? "../artifacts/fool-refined-game");Directory.CreateDirectory(dir);
        var camera=Camera.main;camera.aspect=9f/16f;
        if (Environment.GetEnvironmentVariable("MISTPORT_WARD_REVIEW") == "1") {
            var ward=FindFirstObjectByType<Mindstone.VFXV1.GuardianWard>();
            var draw=typeof(Mindstone.VFXV1.GuardianWard).GetMethod("Draw",System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic);
            float[] times={.12f,.38f,.76f,1.18f,1.58f};
            for(int i=0;i<times.Length;i++) {
                float p=times[i]/1.68f;
                draw.Invoke(ward,new object[]{times[i],Mathf.SmoothStep(0,1,p/.18f)*(1-Mathf.SmoothStep(0,1,Mathf.InverseLerp(.75f,1,p))),Mathf.Clamp01((p-.38f)*2.5f)});
                Capture(camera,dir+"/stage-"+(i+1)+".png");
            }
        }
        Capture(camera,dir+"/idle.png");
        var trackedWard=FindFirstObjectByType<Mindstone.VFXV1.GuardianWard>();
        if(trackedWard) {
            var guardAnimator=trackedWard.transform.parent.GetComponentInChildren<Animator>();
            var spine=guardAnimator.GetBoneTransform(HumanBodyBones.Spine);
            float maxError=0;var startCenter=trackedWard.transform.position;
            for(int frame=0;frame<45;frame++) { yield return null;maxError=Mathf.Max(maxError,Vector3.Distance(trackedWard.transform.position,spine.position)); }
            float motion=Vector3.Distance(startCenter,trackedWard.transform.position);
            File.WriteAllText(dir+"/ward-tracking.json",$"{{\"max_center_error\":{maxError},\"tracked_motion\":{motion}}}");
            if(maxError>.001f || motion<.001f) {Debug.LogError("Ward tracking failed");EditorApplication.Exit(8);yield break;}
        }
        var hand=animator.GetBoneTransform(HumanBodyBones.RightHand);
        var idleHand=hand.position;
        float vertexMotion=0, vertexSeam=0, startWeight=0, endWeight=0;
        if (!original)
        {
        var baked=new Mesh();
        flutter.SampleWind(0);ribbons[0].BakeMesh(baked);var vertices0=baked.vertices;
        startWeight=ribbons[0].GetBlendShapeWeight(0);
        flutter.SampleWind(1);ribbons[0].BakeMesh(baked);var vertices1=baked.vertices;
        vertexMotion=vertices0.Zip(vertices1,(a,b)=>Vector3.Distance(a,b)).Max();
        float movedWeight=ribbons[0].GetBlendShapeWeight(0);
        flutter.SampleWind(4);ribbons[0].BakeMesh(baked);var vertices4=baked.vertices;
        vertexSeam=vertices0.Zip(vertices4,(a,b)=>Vector3.Distance(a,b)).Max();Destroy(baked);
        endWeight=ribbons[0].GetBlendShapeWeight(0);
        if(vertexMotion<.01f || vertexSeam>.0001f) {Debug.LogError($"Ribbon mesh QA failed {vertexMotion} {vertexSeam}");EditorApplication.Exit(6);yield break;}
        if(Mathf.Abs(startWeight-movedWeight)<10 || Mathf.Abs(startWeight-endWeight)>.001f) { EditorApplication.Exit(4);yield break; }
        }
        yield return new WaitForSeconds(.7f);
        Capture(camera,dir+"/idle-later.png");
        float idleDistance=Vector3.Distance(hand.position,idleHand);
        if(idleDistance<.0001f) {EditorApplication.Exit(7);yield break;}
        var battle=FindFirstObjectByType<BattlePrototype>();battle.PresentPlayerBasic();
        yield return new WaitForSeconds(.3f);
        float castDistance=Vector3.Distance(hand.position,idleHand);
        Capture(camera,dir+"/cast.png");
        yield return new WaitForSeconds(.35f);Capture(camera,dir+"/impact.png");
        yield return new WaitForSeconds(2.5f);Capture(camera,dir+"/recovered.png");
        bool recovered=animator.GetCurrentAnimatorStateInfo(0).IsName("Meshy · Idle");
        if(castDistance<.025f || !recovered || GameObject.Find("Fool Basic Tarot Fullscreen")) { Debug.LogError($"Cast QA failed {castDistance} {recovered}");EditorApplication.Exit(5);yield break; }
        File.WriteAllText(dir+"/validation.json",$"{{\"humanoid\":true,\"ribbons\":{ribbons.Length},\"loop_seam_weight\":{Mathf.Abs(startWeight-endWeight)},\"cast_hand_distance\":{castDistance},\"ribbon_vertex_motion\":{vertexMotion},\"ribbon_vertex_seam\":{vertexSeam},\"idle_hand_distance\":{idleDistance},\"returned_to_idle\":true}}");
        EditorApplication.isPlaying=false;
    }
    static void Capture(Camera camera,string path)
    {
        var rt=new RenderTexture(900,1600,24);var image=new Texture2D(900,1600,TextureFormat.RGB24,false);
        var old=camera.targetTexture;var active=RenderTexture.active;camera.targetTexture=rt;camera.Render();RenderTexture.active=rt;
        image.ReadPixels(new Rect(0,0,900,1600),0,0);image.Apply();File.WriteAllBytes(path,image.EncodeToPNG());
        camera.targetTexture=old;RenderTexture.active=active;rt.Release();Destroy(rt);Destroy(image);
    }
}
