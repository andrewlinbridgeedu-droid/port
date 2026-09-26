#if UNITY_EDITOR
using UnityEngine;
using UnityEditor.SceneManagement;
using System.Linq;
public static class DiagnoseLeechPose {
 public static void Run() {
  EditorSceneManager.OpenScene("Assets/Scenes/BattlePrototype.unity");
  var h=Object.FindObjectsByType<EnemyHandle>(FindObjectsInactive.Include,FindObjectsSortMode.None).First(x=>x.BattleEnemyId=="memory-leech-primary");
  h.gameObject.SetActive(true);
  var a=h.GetComponentInChildren<Animation>(true);
  foreach(var phase in new[]{"before","Idle"}) {
   if(phase=="Idle") { a.GetClip("Idle").SampleAnimation(a.gameObject,0.1f); }
   foreach(var r in h.GetComponentsInChildren<SkinnedMeshRenderer>(true)) {
    var m=new Mesh();r.BakeMesh(m);
    Debug.Log("LEECH_DIAG "+phase+" "+r.name+" mesh="+r.sharedMesh.vertexCount+" local="+r.localBounds+" baked="+m.bounds+" scale="+r.transform.lossyScale.ToString("F6")+" rootScale="+r.rootBone.lossyScale.ToString("F6"));
    Object.DestroyImmediate(m);
   }
  }
 }
}
#endif
