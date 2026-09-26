#if UNITY_EDITOR
using System;
using System.Linq;
using UnityEditor;
using UnityEngine;
using Object = UnityEngine.Object;

/// Validates imported actor structure and grounded visible skin before native export.
public static class VerifyApprovedEnemyRework
{
    public static void Verify()
    {
        var paths = new[] {
            "Enemies/Signature/HellhoundSentinel/Actor",
            "Enemies/Signature/ArchivistSentinel/Actor",
            "Enemies/Signature/ClockworkVeilMatriarch/Actor",
            "Enemies/EmeraldRevenant/EmeraldRevenantActor"
        };
        foreach(var path in paths) {
            var prefab=Resources.Load<GameObject>(path);
            if(!prefab)throw new Exception("Missing actor "+path);
            var actor=Object.Instantiate(prefab);
            try {
                var animator=actor.GetComponentInChildren<Animator>(true);
                if(!animator || !animator.runtimeAnimatorController)throw new Exception("Missing animator "+path);
                var skins=actor.GetComponentsInChildren<SkinnedMeshRenderer>(true);
                if(skins.Length==0)throw new Exception("No skinned geometry "+path);
                foreach(var skin in skins) {
                    var mesh=skin.sharedMesh;
                    if(!mesh || !mesh.isReadable || mesh.boneWeights.Length!=mesh.vertexCount)throw new Exception("Unreadable skin "+skin.name);
                    if(mesh.boneWeights.Any(w=>Mathf.Abs(w.weight0+w.weight1+w.weight2+w.weight3-1)>.002f))throw new Exception("Unnormalized skin "+skin.name);
                }
                if(path.Contains("ArchivistSentinel")) {
                    var arm=skins.SingleOrDefault(s=>s.name=="IronVaultLaunchArm");
                    if(!arm || !arm.bones.Any(b=>b && b.name=="Forearm.L") || !arm.bones.Any(b=>b && b.name=="Hand.L"))throw new Exception("Launch arm interface missing");
                }
                if(path.Contains("Hellhound") && !actor.GetComponentsInChildren<Transform>(true).Any(t=>t.name=="Jaw"))throw new Exception("Jaw missing");
                if(path.Contains("Matriarch") && !skins.Any(s=>s.name.StartsWith("CrimsonControlThreads") && s.sharedMaterial.name.Contains("Crimson")))throw new Exception("Independent thread material missing");
                if(path.Contains("Emerald") && !skins.Any(s=>s.name=="EncoreCore" && s.sharedMaterial.IsKeywordEnabled("_EMISSION")))throw new Exception("Emerald core emission missing");
                Debug.Log($"APPROVED_ACTOR_OK {path} skins={skins.Length} vertices={skins.Sum(s=>s.sharedMesh.vertexCount)} clips={animator.runtimeAnimatorController.animationClips.Distinct().Count()}");
            } finally {Object.DestroyImmediate(actor);}
        }
        Debug.Log("FOUR_APPROVED_ACTORS_VERIFY_OK");
    }
}
#endif
