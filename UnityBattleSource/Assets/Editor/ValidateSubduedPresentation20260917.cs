using System;
using System.IO;
using UnityEditor;
using UnityEngine;

public static class ValidateSubduedPresentation20260917
{
    public static void Run()
    {
        var root = new GameObject("Subdued contract probe");
        try {
            var animator = root.AddComponent<Animator>(); animator.speed = .9f;
            var head = new GameObject("Head").transform; head.SetParent(root.transform);
            var subdued = root.AddComponent<EnemySubduedPresentation>();
            subdued.Begin(); subdued.Begin();
            Require(subdued.IsSubdued && root.activeSelf, "remains alive and visible");
            Require(Mathf.Approximately(animator.speed, .65f), "slows living idle");
            subdued.SendMessage("LateUpdate"); subdued.Clear();
            Require(!subdued.IsSubdued && Mathf.Approximately(animator.speed, .9f), "idempotent begin preserves original speed");
            Require(Quaternion.Angle(head.localRotation, Quaternion.identity) < .01f, "clear restores bone offset");
            subdued.Begin(); root.SetActive(false); typeof(EnemySubduedPresentation).GetMethod("OnDisable", System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic).Invoke(subdued, null);
            Require(!subdued.IsSubdued && Mathf.Approximately(animator.speed, .9f), "pool disable clears restraint");
            root.SetActive(true); subdued.Begin(); subdued.Clear();
            Require(root.activeSelf && !subdued.IsSubdued, "retry returns living actor");
            File.WriteAllText("/tmp/mistport-subdued-contract-passed.txt", "Component contract: living visibility, repeated begin, idle speed restoration, bone restoration, disable and retry passed. Not a rendered actor or device visual acceptance.\n");
            Debug.Log("SUBDUED_COMPONENT_CONTRACT_PASS");
        } finally { UnityEngine.Object.DestroyImmediate(root); }
    }
    static void Require(bool ok, string reason) { if (!ok) throw new Exception(reason); }
}
