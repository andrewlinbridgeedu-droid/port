using UnityEngine;

public static class EnemyBattleIds
{
    public const string ClockGuardPrimary = "clock-guard-primary";
    public const string ClockGuardSecondary = "clock-guard-secondary";
    public const string ClockCorePrimary = "clock-core-primary";
    public const string HellHoundPrimary = "hell-hound-primary";
}

/// Stable presentation identity and hierarchy references for one battle enemy.
/// EnemyRoot is owned by formation/combat movement; MotionRoot by procedural
/// motion; VisualRoot by model calibration. Callers must not cross those lanes.
public sealed class EnemyHandle : MonoBehaviour
{
    [SerializeField] string battleEnemyId;
    [SerializeField] string profileEnemyId;
    [SerializeField] string formationSlotId;
    [SerializeField] EnemyVisualProfile profile;
    [SerializeField] EnemyFormationProfile formation;
    [SerializeField] Transform enemyRoot;
    [SerializeField] Transform motionRoot;
    [SerializeField] Transform visualRoot;
    [SerializeField] Transform model;
    [SerializeField] Transform shieldAnchor;
    [SerializeField] Transform targetAnchor;
    [SerializeField] Transform healthBarAnchor;
    [SerializeField] Transform damageTextAnchor;
    [SerializeField] Transform effectAnchor;
    [SerializeField] EnemyHoverMotion hoverMotion;

    public string BattleEnemyId => battleEnemyId;
    public string ProfileEnemyId => profileEnemyId;
    public string FormationSlotId => formationSlotId;
    public EnemyVisualProfile Profile => profile;
    public EnemyFormationProfile Formation => formation;
    public Transform EnemyRoot => enemyRoot;
    public Transform MotionRoot => motionRoot;
    public Transform VisualRoot => visualRoot;
    public Transform Model => model;
    // Presentation swap only. Formation and gameplay identity remain stable.
    internal void SetTempoPresentationModel(Transform value) => model = value;
    public Transform ShieldAnchor => shieldAnchor;
    public Transform TargetAnchor => targetAnchor;
    public Transform HealthBarAnchor => healthBarAnchor;
    public Transform DamageTextAnchor => damageTextAnchor;
    public Transform EffectAnchor => effectAnchor;
    public EnemyHoverMotion HoverMotion => hoverMotion;

    // Instantiate remaps serialized hierarchy references to the clone. Assign
    // its new contact identity before exposing it to the battle bridge.
    public EnemyHandle CloneForBattle(string identity)
    {
        if (string.IsNullOrEmpty(identity)) throw new System.ArgumentException("Enemy identity is required.");
        var clone = Instantiate(gameObject, transform.parent).GetComponent<EnemyHandle>();
        clone.battleEnemyId = identity;
        clone.name = "EnemyRoot [" + identity + "]";
        return clone;
    }

    // Park reusable variants under distinct identities, so a visibility update
    // after death cannot accidentally revive a different hidden model.
    internal void SetInactiveBattleIdentity(string identity)
    {
        if (gameObject.activeInHierarchy)
            throw new System.InvalidOperationException("Deactivate the enemy before changing its presentation identity.");
        if (string.IsNullOrEmpty(identity)) throw new System.ArgumentException("Enemy identity is required.");
        battleEnemyId = identity;
    }

    internal void Bind(
        string stableBattleEnemyId,
        EnemyVisualProfile visualProfile,
        EnemyFormationProfile formationProfile,
        string slotId,
        Transform root,
        Transform motion,
        Transform visual,
        Transform modelTransform,
        Transform shield,
        Transform target,
        Transform healthBar,
        Transform damageText,
        Transform effect,
        EnemyHoverMotion hover)
    {
        battleEnemyId = stableBattleEnemyId;
        profileEnemyId = visualProfile != null ? visualProfile.EnemyId : string.Empty;
        formationSlotId = slotId;
        profile = visualProfile;
        formation = formationProfile;
        enemyRoot = root;
        motionRoot = motion;
        visualRoot = visual;
        model = modelTransform;
        shieldAnchor = shield;
        targetAnchor = target;
        healthBarAnchor = healthBar;
        damageTextAnchor = damageText;
        effectAnchor = effect;
        hoverMotion = hover;
    }
}
