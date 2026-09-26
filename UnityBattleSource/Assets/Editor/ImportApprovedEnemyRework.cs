#if UNITY_EDITOR
using UnityEngine;

/// One reproducible import entry for the four explicitly approved 2026-09-13 masters.
public static class ImportApprovedEnemyRework
{
    public static void Import()
    {
        ImportSignatureEnemies.Import();
        ImportEmeraldRevenant.Import();
        VerifyApprovedEnemyRework.Verify();
        Debug.Log("FOUR_APPROVED_ENEMIES_IMPORT_OK");
    }
}
#endif
