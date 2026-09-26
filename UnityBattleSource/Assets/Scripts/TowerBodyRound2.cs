using UnityEngine;

// D01/D06 replacement for the old upper-body-only gestures. Caller owns the
// clock and contact. Pelvis displacement is local to the skin, never EnemyRoot.
[DefaultExecutionOrder(1820)]
public sealed class TowerBodyRound2 : MonoBehaviour
{
    EnemyHandle actor;
    TowerRigRound2 rig;
    TowerSurfaceRound2 seams, armor;
    string species, action;
    float age, contact;
    bool held, restored;

    public static TowerBodyRound2 Create(EnemyHandle actor, string species, string action, float contact, Transform owner)
    {
        var go = new GameObject("Tower weighted body round 2 " + action); go.transform.SetParent(owner, false);
        var v = go.AddComponent<TowerBodyRound2>();
        v.actor = actor; v.species = species; v.action = action; v.contact = Mathf.Max(.01f, contact);
        v.held = action == "guard" || action.Contains("charge");
        v.rig = new TowerRigRound2(actor.VisualRoot, v.gameObject);
        v.seams = new TowerSurfaceRound2(go.transform, 12, "Effects/Mistport/Official/Slashing/Line01", true);
        if (species == "stonehide") v.armor = new TowerSurfaceRound2(go.transform, 4, "ChurchSpellArt/earth");
        return v;
    }
    public void Tick(float elapsed)
    {
        age = held ? Mathf.Max(0, elapsed) : TowerImpactTiming20260921.Sample(Mathf.Max(0, elapsed), contact, species == "stonehide" ? .115f : .105f);
    }
    void Update() { if (restored) return; rig?.Reset(); if (held) age += Time.deltaTime; }
    static float E(float x) => TowerRigRound2.Ease(x);
    void Pose(string joint, Vector3 rotation) => rig.Rotate(joint, rotation);
    void LateUpdate()
    {
        if (restored || !actor || !actor.gameObject.activeInHierarchy) return;
        rig.Capture();
        if (species == "stonehide") Stone(); else Bone();
        DrawSeams();
    }
    void Legs(float crouch, float drive, float turn, float fade)
    {
        // A loaded rear leg and a bracing front leg carry the turn; amplitudes
        // are intentionally asymmetric, with ankle compensation at landing.
        Pose("Pelvis", new Vector3(6 * crouch - 8 * drive, turn, 2 * crouch) * fade);
        Pose("Thigh.L", new Vector3(-19 * crouch + 11 * drive, -turn * .22f, -3 * crouch) * fade);
        Pose("Thigh.R", new Vector3(-27 * crouch + 17 * drive, -turn * .18f, 4 * crouch) * fade);
        Pose("Shin.L", new Vector3(25 * crouch - 12 * drive, 0, 0) * fade);
        Pose("Shin.R", new Vector3(34 * crouch - 21 * drive, 0, 0) * fade);
        Pose("Foot.L", new Vector3(-7 * crouch + 2 * drive, 0, 0) * fade);
        Pose("Foot.R", new Vector3(-9 * crouch + 5 * drive, 0, 0) * fade);
    }
    void Stone()
    {
        float load = E(age / (held ? .42f : contact * .50f));
        float strike = held ? 0 : E((age - contact * .70f) / (contact * .30f));
        float settle = held ? 1 : 1 - E((age - contact - .16f) / .38f);
        float breath = .035f * Mathf.Sin(age * 3.7f) * load;
        if (action == "guard")
        {
            Legs(.65f * load + breath, 0, -4 * load, 1);
            Pose("Chest", new Vector3(13 * load + breath * 16, -5 * load, 0));
            Pose("Head", new Vector3(23 * load, 5 * load, 0));
            rig.ShiftWorld("Pelvis", Vector3.down * (.055f * load));
            for (int side = 0; side < 2; side++)
            {
                string suffix = side == 0 ? "L" : "R"; float sign = side == 0 ? 1 : -1;
                float close = E((age - side * .055f) / .27f);
                Pose("UpperArm." + suffix, new Vector3(-39 * close, sign * 22 * close, sign * (25 * close + breath * 9)));
                Pose("Forearm." + suffix, new Vector3(59 * close, sign * 12 * close, 0));
                Pose("Hand." + suffix, new Vector3(-11 * close, sign * 7 * close, 0));
            }
            Pose("TailBase", new Vector3(0, 7 * load, 3 * breath));
            return;
        }
        float lift = E((age - (held ? .06f : contact * .14f)) / (held ? .40f : contact * .40f));
        float landing = held ? 0 : E((age - contact) / .045f) * (1 - E((age - contact - .09f) / .20f));
        Legs(load * (1 - .45f * strike) + .48f * landing, .75f * strike, -5 * load + 7 * strike, settle);
        rig.ShiftWorld("Pelvis", Vector3.up * ((-.06f * load + .065f * lift - .10f * landing) * settle));
        Pose("Chest", new Vector3(-20 * lift + 55 * strike, -4 * load + 7 * strike, 0) * settle);
        Pose("Head", new Vector3(-12 * lift + 30 * strike, 3 * load, 0) * settle);
        for (int side = 0; side < 2; side++)
        {
            string suffix = side == 0 ? "L" : "R"; float sign = side == 0 ? 1 : -1;
            float armLift = E((age - side * .025f - contact * .10f) / (contact * .42f));
            float armReturn = held ? 1 : 1 - E((age - contact - .17f - side * .045f) / .34f);
            Pose("UpperArm." + suffix, new Vector3(-124 * armLift + 132 * strike, sign * 4 * load, sign * (20 * armLift - 15 * strike)) * armReturn);
            Pose("Forearm." + suffix, new Vector3(-25 * lift + 39 * strike, 0, sign * 5 * strike) * armReturn);
            Pose("Hand." + suffix, new Vector3(18 * lift - 40 * strike, sign * 7 * strike, 0) * armReturn);
        }
        Pose("TailBase", new Vector3(0, 10 * load - 15 * strike, 0) * settle);
        Pose("TailTip", new Vector3(8 * lift - 15 * strike, -10 * load + 13 * strike, 0) * settle);
    }
    void Bone()
    {
        float load = E(age / (held ? .36f : contact * .53f));
        float strike = held ? 0 : E((age - contact * .69f) / (contact * .31f));
        float settle = held ? 1 : 1 - E((age - contact - .13f) / .39f);
        float breathing = held ? .035f * Mathf.Sin(age * 3.9f) : 0;
        bool tail = action == "tower_tail_sweep", heavy = action == "tower_heavy_claw";
        float turn = (tail ? -23 * load + 51 * strike : heavy ? -4 * load + 7 * strike : 14 * load - 29 * strike);
        float landing = heavy ? E((age - contact) / .05f) * (1 - E((age - contact - .10f) / .20f)) : 0;
        Legs((heavy ? .85f : .50f) * load + landing * .55f + breathing, strike * .80f, turn, settle);
        if (heavy)
        {
            float rise = E((age - contact * .35f) / (contact * .23f)) * (1 - E((age - contact * .65f) / (contact * .35f)));
            rig.ShiftWorld("Pelvis", Vector3.up * ((-.045f * load + .13f * rise - .07f * landing) * settle));
            Pose("Chest", new Vector3(-24 * load + 61 * strike, 0, 3 * load - 6 * strike) * settle);
            Pose("Head", new Vector3(-14 * load + 26 * strike, 0, 0) * settle);
            for (int s = 0; s < 2; s++)
            {
                string suffix = s == 0 ? "L" : "R"; float sign = s == 0 ? 1 : -1;
                float release = E((age - contact * (.69f + s * .015f)) / (contact * (.31f - s * .015f)));
                float recover = 1 - E((age - contact - .15f - s * .025f) / .35f);
                Pose("UpperArm." + suffix, new Vector3(-130 * load + 182 * release, sign * 7 * load, sign * 17 * load) * recover);
                Pose("Forearm." + suffix, new Vector3(-32 * load + 72 * release, 0, sign * 6 * release) * recover);
                Pose("Hand." + suffix, new Vector3(27 * load - 54 * release, sign * 12 * release, 0) * recover);
            }
            Pose("TailBase", new Vector3(-8 * load + 16 * strike, -12 * load + 19 * strike, 0) * settle);
            Pose("TailTip", new Vector3(17 * load - 24 * strike, 18 * load - 25 * strike, 0) * settle);
        }
        else if (tail)
        {
            Pose("Chest", new Vector3(10 * load - 6 * strike, -29 * load + 63 * strike, -8 * load + 15 * strike) * settle);
            Pose("Head", new Vector3(-4 * load, 18 * load - 35 * strike, 0) * settle);
            Pose("UpperArm.L", new Vector3(-37 * load + 20 * strike, 15 * load, -39 * load) * settle);
            Pose("UpperArm.R", new Vector3(-25 * load - 10 * strike, -22 * load, 25 * load + 12 * strike) * settle);
            Pose("Forearm.L", new Vector3(-18 * load + 29 * strike, 0, 0) * settle);
            Pose("Forearm.R", new Vector3(-30 * load + 16 * strike, 0, 0) * settle);
            string[] chain = { "TailBase", "Tail1", "Tail2", "TailTip" };
            for (int i = 0; i < chain.Length; i++)
            {
                float whip = E((age - contact * .63f - i * .022f) / Mathf.Max(.04f, contact * .37f - i * .022f));
                float recoil = 1 - E((age - contact - .13f - i * .026f) / .31f);
                Pose(chain[i], new Vector3(4 * load - 8 * whip, (-24 * load + (65 - i * 6) * whip) * recoil, 0));
            }
        }
        else
        {
            Pose("Chest", new Vector3(-12 * load + 31 * strike, 23 * load - 46 * strike, 5 * load - 11 * strike) * settle);
            Pose("Neck", new Vector3(-8 * load + 12 * strike, -6 * load, 0) * settle);
            Pose("Head", new Vector3(6 * load, -13 * load + 21 * strike, 0) * settle);
            Pose("UpperArm.R", new Vector3(-80 * load + 133 * strike, -35 * load + 62 * strike, 21 * load) * settle);
            Pose("Forearm.R", new Vector3(-63 * load + 105 * strike, 0, 0) * settle);
            Pose("Hand.R", new Vector3(22 * load - 43 * strike, 12 * load - 18 * strike, 0) * settle);
            Pose("UpperArm.L", new Vector3(-24 * load + 10 * strike, 12 * load, -29 * load) * settle);
            Pose("Forearm.L", new Vector3(-22 * load + 10 * strike, 0, 0) * settle);
            Pose("TailBase", new Vector3(0, -23 * load + 35 * strike, 0) * settle);
            Pose("TailTip", new Vector3(8 * load, 15 * load - 23 * strike, 0) * settle);
        }
    }
    void DrawSeams()
    {
        seams.Hide(); armor?.Hide(); float fade = held ? .70f + .10f * Mathf.Sin(age * 4) : 1 - E((age - contact + .025f) / .20f);
        if (fade <= 0) return;
        Color hue = species == "stonehide" ? new Color(1, .48f, .12f) : action == "tower_tail_sweep" ? new Color(.18f, .90f, .56f) : action == "tower_heavy_claw" || action.Contains("charge") ? new Color(.72f, .31f, 1) : new Color(.25f, .68f, 1);
        for (int side = 0; side < 2; side++) for (int segment = 0; segment < 3; segment++)
        {
            string suffix = side == 0 ? "L" : "R";
            string from = segment == 0 ? "UpperArm." : segment == 1 ? "Forearm." : "Hand.";
            string to = segment == 0 ? "Forearm." : "Hand.";
            var a = rig.Find(from + suffix); var b = rig.Find(to + suffix); if (!a || !b) continue;
            Vector3 start = a.position, end = segment == 2 ? a.position + actor.EnemyRoot.forward * .25f : b.position;
            Vector3 front = -(TowerSurfaceRound2.Face * Vector3.forward) * (species == "stonehide" ? .22f : .08f);
            int index = side * 6 + segment * 2;
            float pulse = .58f + .42f * Mathf.Pow(Mathf.Max(0, Mathf.Sin(age * 7 - segment * .83f - side * .31f)), 2);
            if (armor != null && segment < 2)
            {
                var direction = end - start;
                if (direction.sqrMagnitude > .0001f)
                    armor.Leaf(side * 2 + segment, (start + end) * .5f + front * .64f,
                        Quaternion.LookRotation(TowerSurfaceRound2.Face * Vector3.forward, direction),
                        new Vector2(segment == 0 ? .66f : .48f, direction.magnitude * 1.18f),
                        segment == 0 ? new Color(1, .64f, .25f) : new Color(1, .81f, .47f),
                        fade * pulse * .62f, age, .25f,
                        new Rect(segment == 0 ? .07f : .38f, .16f, .32f, .68f));
            }
            for (int pass = 0; pass < 2; pass++)
            {
                int limb = segment;
                seams.Stroke(index + pass, q => Vector3.Lerp(start, end, .06f + q * .90f) + front +
                    actor.EnemyRoot.right * Mathf.Sin(q * 7.7f + limb * 1.4f) * .026f,
                    pass == 0 ? .105f : .035f, pass == 0 ? hue : Color.Lerp(hue, new Color(1, .93f, .70f), .68f), fade * pulse, age, .018f);
            }
        }
    }
    public void Restore() { if (restored) return; restored = true; rig?.Reset(); seams?.Hide(); armor?.Hide(); }
    void OnDisable() { Restore(); }
    void OnDestroy() { Restore(); seams?.Dispose(); armor?.Dispose(); }
}
