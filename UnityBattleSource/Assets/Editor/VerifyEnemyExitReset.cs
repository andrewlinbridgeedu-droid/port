#if UNITY_EDITOR
using System;
using System.Collections.Generic;
using System.Reflection;
using UnityEditor.SceneManagement;
using UnityEngine;

public static class VerifyEnemyExitReset
{
    public static void Run()
    {
        EditorSceneManager.OpenScene("Assets/Scenes/BattlePrototype.unity");
        var guard = Array.Find(UnityEngine.Object.FindObjectsByType<EnemyHandle>(FindObjectsInactive.Include, FindObjectsSortMode.None),
            h => h.BattleEnemyId == EnemyBattleIds.ClockGuardPrimary);
        if (!guard) throw new Exception("Missing guard template");
        var host = new GameObject("Exit reset verification");
        var bridge = host.AddComponent<UnityBattleBridge>();
        try {
            EnemyPresenter.Reposition(guard, EnemyFormationSlotIds.FrontLeft, false);
            var poses = (Dictionary<Transform, Vector3>) typeof(UnityBattleBridge)
                .GetField("originalPositions", BindingFlags.Instance | BindingFlags.NonPublic).GetValue(bridge);
            poses[guard.EnemyRoot] = guard.EnemyRoot.localPosition;
            guard.gameObject.SetActive(false);
            bridge.ResetEnemyExitPresentation();
            EnemyPresenter.Reposition(guard, EnemyFormationSlotIds.FrontRight, false);
            var expected = guard.EnemyRoot.position;
            for (int repeat = 0; repeat < 3; repeat++)
                bridge.SetEnemyVisibility(EnemyBattleIds.ClockGuardPrimary + "=visible");
            if (guard.EnemyRoot.position != expected || expected.x <= 0 || poses.Count != 0)
                throw new Exception("Old death pose overwrote the next encounter formation");
            Debug.Log("ENEMY_EXIT_CROSS_LEVEL_RESET_PASS");
            var activeClone = guard.CloneForBattle(guard.BattleEnemyId);
            try {
                guard.gameObject.SetActive(false);
                activeClone.gameObject.SetActive(true);
                bridge.SetEnemyVisibility(guard.BattleEnemyId + "=visible");
                if (guard.gameObject.activeSelf || !activeClone.gameObject.activeSelf)
                    throw new Exception("Visibility command reactivated hidden template instead of live clone");
                Debug.Log("ENEMY_VISIBILITY_ACTIVE_CLONE_PASS");
            } finally { UnityEngine.Object.DestroyImmediate(activeClone.gameObject); }
        } finally { UnityEngine.Object.DestroyImmediate(host); }
    }
}
#endif
