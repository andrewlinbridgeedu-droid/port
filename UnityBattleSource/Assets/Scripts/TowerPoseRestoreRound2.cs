using UnityEngine;

// Tower acting is layered AFTER EnemyImpactFeedback.LateUpdate (1100).
// Undo it BEFORE that component's next Update: reverse the composition order.
[DefaultExecutionOrder(1050), DisallowMultipleComponent]
public sealed class TowerPoseRestoreRound2 : MonoBehaviour
{
    public TowerRigRound2 rig;
    void Update() { rig?.Reset(); }
    void OnDisable() { rig?.Reset(); }
}
