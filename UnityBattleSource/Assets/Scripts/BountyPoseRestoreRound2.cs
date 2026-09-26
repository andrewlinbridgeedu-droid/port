using UnityEngine;

// Runs after EnemyImpactFeedback.Update, while BountyBodyRound2.LateUpdate runs
// before that component. This removes additive layers in their reverse order.
[DefaultExecutionOrder(1200), DisallowMultipleComponent]
public sealed class BountyPoseRestoreRound2 : MonoBehaviour
{
    public BountyBodyRound2 owner;
    void Update() { if (owner) owner.RestoreFrame(); }
    void OnDisable() { if (owner) owner.RestoreFrame(); }
}
