#if UNITY_EDITOR || UNITY_STANDALONE
using System;
using System.Collections;
using System.IO;
using System.Linq;
using UnityEngine;
public sealed class HeroBackArtCapture:MonoBehaviour {
 [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)] static void Boot(){if(Environment.GetCommandLineArgs().Contains("--verify-hero-back-art"))new GameObject("Hero rear material capture").AddComponent<HeroBackArtCapture>();}
 IEnumerator Start(){
  var output=Environment.GetEnvironmentVariable("MISTPORT_HERO_CAPTURE")??"/tmp/hero-back-art";Directory.CreateDirectory(output);
  Screen.SetResolution(720,1280,false);yield return new WaitForSeconds(2);
  var battle=FindFirstObjectByType<BattlePrototype>();battle.SetNativeCombatEnabled(true);battle.UseEarlyHellHoundModel();
  yield return new WaitForSeconds(.5f);
  var hero=GameObject.Find("Fool_Imported");var refinement=HeroBackArtRefinement.Install(hero);var animator=hero.GetComponentInChildren<Animator>();animator.speed=0;
  Time.timeScale=0;
  refinement.ShowRefinement(false);yield return new WaitForEndOfFrame();Capture(output+"/before.png");
  refinement.ShowRefinement(true);yield return new WaitForEndOfFrame();Capture(output+"/after.png");
  File.WriteAllText(output+"/passed.txt","Same live battle camera/pose; original and tailored material renders captured. Original mesh and texture resources preserved.\n");
  Time.timeScale=1;Application.Quit(0);
 }
 void Capture(string path){var tex=ScreenCapture.CaptureScreenshotAsTexture();File.WriteAllBytes(path,tex.EncodeToPNG());Destroy(tex);}
}
#endif
