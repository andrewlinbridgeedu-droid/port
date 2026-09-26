#if UNITY_EDITOR || UNITY_STANDALONE
using System;
using System.Collections;
using System.IO;
using System.Linq;
using UnityEngine;

/// Inspection camera only in the optional desktop QA player, never the native battle.
public sealed class CharacterArtCloseupCapture : MonoBehaviour
{
    string folder;
    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Boot(){if(Environment.GetCommandLineArgs().Contains("--capture-character-closeups"))new GameObject("Character art inspection").AddComponent<CharacterArtCloseupCapture>();}
    IEnumerator Start()
    {
        folder=Environment.GetEnvironmentVariable("MISTPORT_ART_CAPTURE")??"/tmp/character-art-closeups";Directory.CreateDirectory(folder);
        Screen.SetResolution(720,1280,false);yield return new WaitForSeconds(3);
        var battle=FindFirstObjectByType<BattlePrototype>();var camera=Camera.main;
        var position=camera.transform.position;var rotation=camera.transform.rotation;var fov=camera.fieldOfView;
        foreach(var kind in new[]{"guard","ghost","early-hound","armored-hound","emerald","core","leech","archivist","matriarch","scribe","rescue"}) {
            battle.SetNativeCombatEnabled(false);battle.SetEncoreRevenant(false);
            switch(kind) {
                case "guard":battle.UseClockGuardModel();break;
                case "ghost":battle.UseDualClockGuardModel();break;
                case "early-hound":battle.UseEarlyHellHoundModel();break;
                case "armored-hound":battle.UseHellHoundModel();break;
                case "emerald":battle.UseHellHoundModel();battle.SetEncoreRevenant(true);break;
                case "core":battle.UseClockCoreModel();break;
                case "leech":battle.UseP1Escort(true);break;
                default:battle.ConfigureWaveInstances("clock-guard-primary@"+kind);break;
            }
            battle.SetEarlyBattlePresence(kind=="early-hound"?"4":kind=="ghost"?"2":kind=="emerald"?"5":"15");
            yield return new WaitForSeconds(.75f);
            var handles=FindObjectsByType<EnemyHandle>(FindObjectsSortMode.None).Where(battle.BelongsToCurrentEncounter).ToArray();
            var h=kind=="leech"?handles.First(x=>x.GetComponentInChildren<MemoryLeechPresentation>()):kind=="core"?handles.First(x=>x.ProfileEnemyId.Contains("core")):handles.First();
            var presence=h.GetComponent<EarlyEnemyIdlePresence>();var actor=presence&&presence.VisibleActor?presence.VisibleActor:h.Model;
            var renderers=actor.GetComponentsInChildren<Renderer>().Where(r=>r.enabled&&!(r is ParticleSystemRenderer)&&!(r is LineRenderer)&&!(r is TrailRenderer)).ToArray();
            var bounds=renderers[0].bounds;foreach(var r in renderers)bounds.Encapsulate(r.bounds);
            camera.transform.position=position;camera.transform.rotation=rotation;camera.fieldOfView=fov;
            yield return Shot(kind+"-battle");
            camera.transform.position=bounds.center+(position-bounds.center).normalized*Mathf.Max(2,bounds.size.y*1.65f);
            camera.transform.LookAt(bounds.center);camera.fieldOfView=40;
            yield return Shot(kind+"-closeup");
            camera.transform.position=position;camera.transform.rotation=rotation;camera.fieldOfView=fov;
        }
        var hero=GameObject.Find("Fool_Imported");var animator=hero.GetComponentInChildren<Animator>();
        var chest=animator.GetBoneTransform(HumanBodyBones.Chest).position;
        camera.transform.position=chest+(position-chest).normalized*2.3f;camera.transform.LookAt(chest);camera.fieldOfView=40;
        yield return Shot("hero-back-closeup");
        camera.transform.position=chest-(position-chest).normalized*2.3f;camera.transform.LookAt(chest);
        yield return Shot("hero-front-closeup");
        File.WriteAllText(Path.Combine(folder,"passed.txt"),"Actual Unity actor/lighting/material closeups; QA camera only. Battle camera and actor positions are unchanged in production.");Application.Quit(0);
    }
    IEnumerator Shot(string name){yield return null;yield return new WaitForEndOfFrame();var t=ScreenCapture.CaptureScreenshotAsTexture();File.WriteAllBytes(Path.Combine(folder,name+".png"),t.EncodeToPNG());Destroy(t);}
}
#endif
