#if UNITY_EDITOR
using System;
using UnityEditor.SceneManagement;
using UnityEngine;

public static class VerifyWaveEnemyClones
{
    public static void Run()
    {
        EditorSceneManager.OpenScene("Assets/Scenes/BattlePrototype.unity");
        var guardSource = Array.Find(UnityEngine.Object.FindObjectsByType<EnemyHandle>(FindObjectsInactive.Include, FindObjectsSortMode.None), h => h.BattleEnemyId == EnemyBattleIds.ClockGuardPrimary);
        if (guardSource == null) throw new Exception("Missing primary guard template");
        // Secondary guards are created at runtime, not stored in this scene.
        var guardTemplate = guardSource.CloneForBattle(EnemyBattleIds.ClockGuardSecondary);
        guardTemplate.gameObject.SetActive(false);
        var activeGuard = guardTemplate.CloneForBattle(EnemyBattleIds.ClockGuardSecondary);
        try {
            activeGuard.gameObject.SetActive(true);
            var lookup = typeof(BattlePrototype).GetMethod("FindInstalledEnemyHandle", System.Reflection.BindingFlags.Static | System.Reflection.BindingFlags.NonPublic);
            if (lookup == null || lookup.Invoke(null, new object[] { EnemyBattleIds.ClockGuardSecondary }) as EnemyHandle != activeGuard)
                throw new Exception("Enemy lookup selected hidden template instead of active guard");
            Debug.Log("WAVE_ACTIVE_GUARD_PASS");
        } finally {
            UnityEngine.Object.DestroyImmediate(activeGuard.gameObject);
            UnityEngine.Object.DestroyImmediate(guardTemplate.gameObject);
        }
        foreach (var family in new[] { "memory-leech", "clock-core" }) {
            var source = Array.Find(UnityEngine.Object.FindObjectsByType<EnemyHandle>(FindObjectsInactive.Include, FindObjectsSortMode.None), h => h.BattleEnemyId == family + "-primary");
            if (source == null) throw new Exception("Missing installed template " + family);
            var clone = source.CloneForBattle(family + "-secondary");
            try {
                if (clone.BattleEnemyId == source.BattleEnemyId) throw new Exception("Clone identity collision");
                if (clone.EnemyRoot == source.EnemyRoot || clone.VisualRoot == source.VisualRoot || clone.EffectAnchor == source.EffectAnchor)
                    throw new Exception("Clone references original actor hierarchy");
                if (!clone.EffectAnchor.IsChildOf(clone.EnemyRoot)) throw new Exception("Effect anchor outside clone");
                var original = source.EnemyRoot.position;
                clone.EnemyRoot.position += Vector3.right * 3;
                if (source.EnemyRoot.position != original) throw new Exception("Moving clone moved source");
                clone.gameObject.SetActive(false);
                if (source.BattleEnemyId != family + "-primary") throw new Exception("Source identity mutated");
                clone.gameObject.SetActive(true);
                EnemyPresenter.Reposition(clone, EnemyFormationSlotIds.FrontRight, false);
                foreach (var renderer in clone.GetComponentsInChildren<SkinnedMeshRenderer>(true))
                {
                    Debug.Log("CLONE_BOUNDS " + family + " active=" + renderer.gameObject.activeInHierarchy + " enabled=" + renderer.enabled + " bounds=" + renderer.bounds + " scale=" + renderer.transform.lossyScale);
                    var baked = new Mesh();
                    renderer.BakeMesh(baked);
                    baked.RecalculateBounds();
                    if (family == "memory-leech" && renderer.name == "Mesh_0") {
                        var material = renderer.sharedMaterial;
                        if (material == null || material.GetTexture("_MainTex") == null
                            || material.GetTexture("_BumpMap") == null || material.GetTexture("_MetallicRoughness") == null)
                            throw new Exception("Leech body is missing an original texture binding");
                        if (baked.bounds.size.y < .1f || baked.bounds.size.y > 10f)
                            throw new Exception("Leech body skin scale is outside visible creature range");
                        Debug.Log("WAVE_LEECH_MATERIAL_AND_SIZE_PASS");
                    }
                    Debug.Log("SKIN_EXACT " + renderer.name + " sourceSize=" + renderer.sharedMesh.bounds.size.ToString("G9") + " bakedSize=" + baked.bounds.size.ToString("G9") + " readable=" + renderer.sharedMesh.isReadable);
                    for (var b = 0; b < renderer.bones.Length; b++)
                        Debug.Log("SKIN_BONE " + renderer.name + " index=" + b + " name=" + renderer.bones[b].name + " scale=" + renderer.bones[b].lossyScale.ToString("G9") + " bind=" + renderer.sharedMesh.bindposes[b].ToString("G9"));
                    Debug.Log("CLONE_SKIN " + family + " vertices=" + baked.vertexCount + " baked=" + baked.bounds + " local=" + renderer.localBounds + " bones=" + renderer.bones.Length + " root=" + renderer.rootBone + " model=" + clone.Model.localToWorldMatrix);
                    if (family == "memory-leech") {
                        renderer.rootBone = clone.Model.Find("MemoryLeechRig");
                        renderer.BakeMesh(baked);
                        baked.RecalculateBounds();
                        Debug.Log("CLONE_SKIN_ROOT " + renderer.name + " root=" + renderer.rootBone + " baked=" + baked.bounds + " world=" + renderer.bounds);
                    }
                    UnityEngine.Object.DestroyImmediate(baked);
                }
                Debug.Log("WAVE_CLONE_PASS " + family);
            } finally { UnityEngine.Object.DestroyImmediate(clone.gameObject); }
        }
    }
}
#endif
