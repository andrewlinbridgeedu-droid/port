using System.Collections.Generic;
using UnityEngine;

/// Contact-driven additive acting on the installed humanoid, independent of combat timing.
/// All authored axes are actor-space, converted into each joint's parent space: imported
/// FBX bone roll therefore cannot turn a forward palm press into a sideways elbow bend.
[DefaultExecutionOrder(900)]
public sealed class FoolSkillChoreography : MonoBehaviour
{
    sealed class Joint
    {
        public Transform bone;
        public Quaternion baseline;
        public Vector3 position;
        public bool applied;
    }

    readonly Dictionary<string, Joint> joints = new Dictionary<string, Joint>();
    Transform actor;
    float began, contacted = -1f, finished = -1f;
    public bool IsPlaying { get; private set; }
    public string CurrentSkill { get; private set; } = "";
    public int MappedJointCount => joints.Count;
    public float LastFootError { get; private set; }
    // Read-only recorder diagnostics: actual solved displacement, not the requested
    // pelvis lift. Encounter/root position and combat timing never participate.
    public float LastHopFootLift { get; private set; }
    public const string BasicID = "hero_basic_round2";
    public const string ManualMaskID = "hero_manual_mask_round2";
    Vector3 posedHand;
    bool handPosed;
    Vector3 CurrentHand => joints.TryGetValue("rh",out var wrist)&&wrist.bone
        ? wrist.bone.position : transform.position+Vector3.up*1.15f;
    // Update coroutines consume the last completed pose rather than a temporarily
    // restored baseline between Animator and LateUpdate; the launch is at the hand.
    public Vector3 CastingHandPosition => IsPlaying&&handPosed?posedHand:CurrentHand;

    public static FoolSkillChoreography Install(Transform root)
    {
        if (!root) return null;
        var component = root.GetComponent<FoolSkillChoreography>();
        if (!component) component = root.gameObject.AddComponent<FoolSkillChoreography>();
        component.Map(root);
        return component;
    }

    void Map(Transform root)
    {
        if (actor == root && joints.Count > 0) return;
        Clear(); actor = root; joints.Clear();
        var animator = root.GetComponentInChildren<Animator>(true);
        Add("hips", animator, HumanBodyBones.Hips, "Hips", "Pelvis");
        Add("spine", animator, HumanBodyBones.Spine, "Spine");
        Add("chest", animator, HumanBodyBones.Chest, "Spine1", "Chest");
        Add("head", animator, HumanBodyBones.Head, "Head");
        Add("ls", animator, HumanBodyBones.LeftShoulder, "LeftShoulder");
        Add("rs", animator, HumanBodyBones.RightShoulder, "RightShoulder");
        Add("la", animator, HumanBodyBones.LeftUpperArm, "LeftArm", "LeftUpperArm", "UpperArm.L");
        Add("ra", animator, HumanBodyBones.RightUpperArm, "RightArm", "RightUpperArm", "UpperArm.R");
        Add("le", animator, HumanBodyBones.LeftLowerArm, "LeftForeArm", "LeftLowerArm", "Forearm.L");
        Add("re", animator, HumanBodyBones.RightLowerArm, "RightForeArm", "RightLowerArm", "Forearm.R");
        Add("lh", animator, HumanBodyBones.LeftHand, "LeftHand", "Hand.L");
        Add("rh", animator, HumanBodyBones.RightHand, "RightHand", "Hand.R");
        Add("lt", animator, HumanBodyBones.LeftUpperLeg, "LeftUpLeg", "LeftUpperLeg", "Thigh.L");
        Add("rt", animator, HumanBodyBones.RightUpperLeg, "RightUpLeg", "RightUpperLeg", "Thigh.R");
        Add("lk", animator, HumanBodyBones.LeftLowerLeg, "LeftLeg", "LeftLowerLeg", "Shin.L");
        Add("rk", animator, HumanBodyBones.RightLowerLeg, "RightLeg", "RightLowerLeg", "Shin.R");
        Add("lf", animator, HumanBodyBones.LeftFoot, "LeftFoot", "Foot.L");
        Add("rf", animator, HumanBodyBones.RightFoot, "RightFoot", "Foot.R");
    }

    void Add(string key, Animator animator, HumanBodyBones human, params string[] aliases)
    {
        Transform bone = animator && animator.isHuman ? animator.GetBoneTransform(human) : null;
        if (!bone)
            foreach (var candidate in actor.GetComponentsInChildren<Transform>(true))
            {
                string name = candidate.name;
                int colon = name.LastIndexOf(':');
                if (colon >= 0) name = name.Substring(colon + 1);
                foreach (var alias in aliases) if (name == alias) { bone = candidate; break; }
                if (bone) break;
            }
        if (bone) joints[key] = new Joint { bone = bone };
    }

    public void Begin(string skillID)
    {
        Clear();
        if (!actor) Map(transform);
        CurrentSkill = skillID ?? "";
        if (!CurrentSkill.StartsWith("fool_skill_") && CurrentSkill != BasicID && CurrentSkill != ManualMaskID) return;
        began = Time.time; contacted = finished = -1f; IsPlaying = true;
    }

    public void Contact()
    {
        if (IsPlaying && contacted < 0f) contacted = Time.time;
    }

    public void Finish()
    {
        if (IsPlaying && finished < 0f) finished = Time.time;
    }

    public void Clear()
    {
        Restore(); IsPlaying = false; CurrentSkill = ""; contacted = finished = -1f;handPosed=false;LastHopFootLift=0;
    }

    void OnDisable() { Clear(); }
    void OnDestroy() { Restore(); }
    void Update() { Restore(); }

    // Restore saved pre-additive locals, including bones absent from the animation clip.
    // Never multiply inverses repeatedly, which can accumulate error on unanimated joints.
    void Restore()
    {
        foreach (var joint in joints.Values)
            if (joint.applied)
            {
                if (joint.bone) { joint.bone.localRotation = joint.baseline; joint.bone.localPosition = joint.position; }
                joint.applied = false;
            }
    }

    void LateUpdate()
    {
        if (!IsPlaying || !actor) return;
        float age = Time.time - began;
        if (age > 5f) { Clear(); return; }
        if (CurrentSkill == BasicID) { DrawBasic(age);CacheHand();return; }
        if (CurrentSkill == ManualMaskID) { DrawManualMask(age);CacheHand();return; }
        float releaseAge = contacted < 0f ? -1f : Time.time - contacted;
        // Anticipate the visual contact without owning its callback. The actual callback
        // locks the release pose immediately, including when a long frame crosses contact.
        float release = releaseAge < 0f ? .94f * Smooth((age - ExpectedContact() + .14f) / .14f) : 1f;
        // Delay the pose rather than holding a full windup for the projectile lifetime.
        float startDelay = CurrentSkill == "fool_skill_07" ? .015f : .025f;
        float envelope = Smooth((age - startDelay) / .21f);
        if (releaseAge > .10f) envelope *= 1f - Smooth((releaseAge - .10f) / .34f);
        if (finished >= 0f) envelope *= 1f - Smooth((Time.time - finished) / .18f);
        if ((releaseAge >= .44f) || (finished >= 0f && Time.time - finished >= .18f)) { Clear(); return; }

        // Torso and hands have different opposing poses, not recoloured versions of one cast.
        // Pelvis weight and separately solved feet support each gesture. The gameplay
        // actor/root never translates or spins; the short hop belongs to the bones.
        LowerBody(age, release, envelope);
        switch (CurrentSkill)
        {
            case "fool_skill_01":
                Pose("spine", V(17,-23,9), V(8,15,-7), release,envelope);
                Pose("chest",V(9,-19,4),V(-5,25,-9),release,envelope);
                Pose("ls",V(3,-9,-7),V(-3,8,4),release,envelope);
                Pose("rs",V(-4,-12,7),V(7,11,-5),release,envelope);
                Pose("la",V(-28,12,-20),V(-47,-24,-49),release,envelope);
                Pose("ra",V(-44,16,16),V(-16,32,45),release,envelope);
                Pose("re",V(-36,-8,0),V(12,5,0),release,envelope);
                Pose("rh",V(-12,-20,25),V(16,23,-24),release,envelope); break;
            case "fool_skill_02":
                Pose("ra",V(-30,-8,22),V(-18,4,30),release,envelope);
                Pose("rh",V(0,-18,24),V(8,18,-8),release,envelope); break;
            case "fool_skill_04":
                Pose("spine",V(2,-19,3),V(1,16,-3),release,envelope);
                Pose("chest",V(-5,-14,0),V(5,18,0),release,envelope);
                Pose("la",V(-42,15,-9),V(-17,24,-44),release,envelope);
                Pose("le",V(-37,6,-5),V(5,0,8),release,envelope);
                Pose("ra",V(-20,18,19),V(-56,-18,12),release,envelope);
                Pose("re",V(-38,-6,5),V(-3,0,-5),release,envelope);
                Pose("lh",V(0,27,-24),V(8,-20,32),release,envelope);
                Pose("rh",V(20,-39,31),V(-18,40,-27),release,envelope); break;
            case "fool_skill_05":
                Pose("spine",V(-8,-15,3),V(16,9,-4),release,envelope);
                Pose("chest",V(-14,-12,0),V(22,14,3),release,envelope);
                Pose("rs",V(-8,-6,6),V(9,8,-5),release,envelope);
                Pose("ra",V(-87,-12,21),V(-21,12,31),release,envelope);
                Pose("re",V(-44,0,0),V(14,0,0),release,envelope);
                Pose("rh",V(-29,-10,8),V(34,12,-8),release,envelope);
                Pose("la",V(-13,4,-30),V(-28,-18,-46),release,envelope); break;
            case "fool_skill_06":
                Pose("spine",V(10,-17,7),V(5,17,-6),release,envelope);
                Pose("chest",V(-7,-18,0),V(12,23,-7),release,envelope);
                Pose("la",V(-48,24,-12),V(-59,-29,-49),release,envelope);
                Pose("ra",V(-54,-23,14),V(-27,31,57),release,envelope);
                Pose("le",V(-40,0,0),V(10,0,0),release,envelope);
                Pose("re",V(-42,0,0),V(13,0,0),release,envelope);
                Pose("lh",V(0,-22,-18),V(10,12,14),release,envelope);
                Pose("rh",V(-10,24,16),V(5,-14,-12),release,envelope); break;
            case "fool_skill_07":
                Pose("spine",V(-10,-7,0),V(18,9,0),release,envelope);
                Pose("chest",V(-15,-10,0),V(23,12,-4),release,envelope);
                Pose("ls",V(-8,-4,-4),V(8,5,4),release,envelope);
                Pose("rs",V(-8,4,4),V(8,-5,-4),release,envelope);
                TwoHandLift(release, envelope); break;
            case "fool_skill_08":
                Pose("spine",V(-5,20,3),V(7,-15,-3),release,envelope);
                Pose("chest",V(-8,18,0),V(12,-23,0),release,envelope);
                Pose("ra",V(-17,25,31),V(-64,-21,28),release,envelope);
                Pose("re",V(-35,0,0),V(12,0,0),release,envelope);
                Pose("rh",V(-16,0,0),V(25,0,0),release,envelope);
                Pose("la",V(-40,21,-10),V(-23,-26,-52),release,envelope);
                Pose("lh",V(6,30,-13),V(-9,-31,22),release,envelope); break;
            case "fool_skill_09":
                Pose("spine",V(6,-13,3),V(-4,11,-2),release,envelope);
                Pose("chest",V(-7,-15,0),V(-3,16,0),release,envelope);
                Pose("la",V(-34,18,-12),V(-28,-12,-28),release,envelope);
                Pose("ra",V(-42,-18,12),V(-30,14,30),release,envelope);
                Pose("rh",V(0,-20,12),V(8,18,-16),release,envelope); break;
            case "fool_skill_10":
                Pose("spine",V(-5,0,0),V(5,0,0),release,envelope);
                Pose("chest",V(-9,0,0),V(12,0,0),release,envelope);
                Pose("la",V(-36,-14,-72),V(-67,22,-22),release,envelope);
                Pose("ra",V(-36,14,72),V(-67,-22,22),release,envelope);
                Pose("le",V(-22,-8,0),V(-9,8,0),release,envelope);
                Pose("re",V(-22,8,0),V(-9,-8,0),release,envelope);
                Pose("lh",V(-10,-22,0),V(15,18,0),release,envelope);
                Pose("rh",V(-10,22,0),V(15,-18,0),release,envelope); break;
        }
        Pose("head", V(0,0,0), V(-3,0,0), release, envelope);
        CacheHand();
    }

    void CacheHand(){if(IsPlaying){posedHand=CurrentHand;handPosed=true;}}

    void DrawBasic(float age)
    {
        // Release at the existing .16 s card launch, then immediately recover.
        // The hand is free before impact; the projectile owns its own clock.
        if(age >= .36f) { Clear(); return; }
        float weight = Smooth(age/.05f) * (1-Smooth((age-.18f)/.16f));
        float flick = Smooth((age-.09f)/.07f);
        Pose("spine",V(0,-1,0),V(1,1,0),flick,weight);
        Pose("chest",V(-1,-2,0),V(1,2,0),flick,weight);
        Pose("rs",V(-1,-2,1),V(1,2,-1),flick,weight);
        Pose("ra",V(-10,3,4),V(-7,-2,8),flick,weight);
        Pose("re",V(-14,-2,0),V(3,2,0),flick,weight);
        Pose("rh",V(-8,-15,13),V(9,13,-11),flick,weight);
    }

    void DrawManualMask(float age)
    {
        if(age >= .78f) { Clear(); return; }
        float weight=Smooth(age/.11f)*(1-Smooth((age-.42f)/.32f));
        float turn=Smooth((age-.20f)/.19f);
        Pose("chest",V(-3,-9,2),V(4,8,0),turn,weight);
        Pose("ra",V(-51,-16,9),V(-30,13,29),turn,weight);
        Pose("re",V(-48,0,0),V(-14,5,0),turn,weight);
        Pose("rh",V(-12,-30,19),V(14,22,-15),turn,weight);
        Pose("la",V(-13,8,-20),V(-21,-14,-34),turn,weight);
        Pose("head",V(0,-8,0),V(-3,0,0),turn,weight);
    }

    void Save(Joint joint)
    {
        if(joint.applied || !joint.bone) return;
        joint.baseline=joint.bone.localRotation; joint.position=joint.bone.localPosition; joint.applied=true;
    }

    void LowerBody(float age,float phase,float weight)
    {
        LastFootError=0;LastHopFootLift=0;
        if(!joints.TryGetValue("hips",out var hips) || !joints.TryGetValue("lf",out var lf)
            || !joints.TryGetValue("rf",out var rf)) return;
        Vector3 left=lf.bone.position,right=rf.bone.position;
        Vector3 plantedLeft=left,plantedRight=right;
        Quaternion leftRotation=lf.bone.rotation,rightRotation=rf.bone.rotation;
        float leg=Vector3.Distance(hips.bone.position,(left+right)*.5f);
        float crouch=.025f,shift=0,stride=0,hop=0,yaw=0,tuck=0;
        switch(CurrentSkill)
        {
            case "fool_skill_01": crouch=Mathf.Lerp(.15f,.045f,phase);shift=Mathf.Lerp(-.13f,.035f,phase);stride=.14f*Smooth(age/.18f);yaw=Mathf.Lerp(-11,9,phase);break;
            case "fool_skill_04": shift=Mathf.Lerp(-.04f,.045f,phase);yaw=Mathf.Lerp(-7,8,phase);break;
            case "fool_skill_05": crouch=Mathf.Lerp(.045f,.135f,phase);stride=.16f*Smooth((age-.20f)/.18f);yaw=Mathf.Lerp(-9,7,phase);break;
            case "fool_skill_06": crouch=Mathf.Lerp(.12f,.045f,phase);shift=Mathf.Lerp(-.085f,.08f,phase);stride=.14f*Smooth((age-.12f)/.2f);yaw=Mathf.Lerp(-12,11,phase);break;
            case "fool_skill_07":
                float flight=Mathf.Clamp01((age-.34f)/.49f);
                float airborne=Mathf.Max(0,Mathf.Sin(flight*Mathf.PI));
                hop=airborne*.32f;
                tuck=airborne*airborne*.075f;
                crouch=age<.34f?.16f*(1-Smooth((age-.24f)/.10f)):.16f*Smooth((age-.76f)/.07f);
                stride=.11f*Smooth((age-.58f)/.25f);break;
            case "fool_skill_08": shift=Mathf.Lerp(.065f,-.065f,phase);yaw=Mathf.Lerp(10,-11,phase);break;
            case "fool_skill_09": crouch=.05f;shift=Mathf.Lerp(.03f,-.02f,phase);break;
            case "fool_skill_10": crouch=Mathf.Lerp(.065f,.015f,phase);break;
        }
        Save(hips);
        hips.bone.position += (actor.right*shift+actor.forward*stride*.26f+actor.up*(hop-crouch))*leg*weight;
        Pose("hips",V(0,yaw,0),V(0,yaw,0),0,weight);
        left += (actor.forward*stride+actor.up*hop)*leg*weight;
        right += actor.up*hop*leg*weight;
        if(CurrentSkill=="fool_skill_07")
        {
            // The feet travel with the airborne pelvis, then tuck slightly
            // higher/backwards. Never solve the jump against planted targets.
            left+=(actor.up*tuck-actor.forward*tuck*.65f+actor.right*tuck*.25f)*leg*weight;
            right+=(actor.up*tuck*.75f-actor.forward*tuck*.38f-actor.right*tuck*.20f)*leg*weight;
        }
        // During the crossing step the moving foot clears the floor, then plants;
        // the supporting foot is solved at its baseline target throughout.
        float stepLift=(CurrentSkill=="fool_skill_01"||CurrentSkill=="fool_skill_05"||CurrentSkill=="fool_skill_06")
            ? Mathf.Sin(Mathf.Clamp01((age-.08f)/.31f)*Mathf.PI)*.055f : 0;
        left += actor.up*stepLift*leg*weight;
        SolveLeg("lt","lk","lf",left,leftRotation);
        SolveLeg("rt","rk","rf",right,rightRotation);
        LastFootError=Mathf.Max(Vector3.Distance(left,lf.bone.position),Vector3.Distance(right,rf.bone.position));
        if(CurrentSkill=="fool_skill_07")LastHopFootLift=Mathf.Min(
            Vector3.Dot(lf.bone.position-plantedLeft,actor.up),Vector3.Dot(rf.bone.position-plantedRight,actor.up));
    }

    void SolveLeg(string upperKey,string lowerKey,string footKey,Vector3 target,Quaternion orientation)
    {
        if(!joints.TryGetValue(upperKey,out var upper)||!joints.TryGetValue(lowerKey,out var lower)
            ||!joints.TryGetValue(footKey,out var foot))return;
        Save(upper);Save(lower);Save(foot);
        Vector3 start=upper.bone.position,delta=target-start;
        float a=Vector3.Distance(start,lower.bone.position),b=Vector3.Distance(lower.bone.position,foot.bone.position);
        if(a<.0001f||b<.0001f||delta.sqrMagnitude<.000001f)return;
        Vector3 direction=delta.normalized;
        float distance=Mathf.Clamp(delta.magnitude,Mathf.Abs(a-b)+.0001f,a+b-.0001f);
        Vector3 pole=Vector3.ProjectOnPlane(lower.bone.position-start,direction);
        if(pole.sqrMagnitude<.000001f)pole=Vector3.ProjectOnPlane(actor.forward,direction);
        if(pole.sqrMagnitude<.000001f)return;
        float along=(a*a-b*b+distance*distance)/(2*distance);
        Vector3 knee=start+direction*along+pole.normalized*Mathf.Sqrt(Mathf.Max(0,a*a-along*along));
        upper.bone.rotation=Quaternion.FromToRotation(lower.bone.position-start,knee-start)*upper.bone.rotation;
        lower.bone.rotation=Quaternion.FromToRotation(foot.bone.position-lower.bone.position,start+direction*distance-lower.bone.position)*lower.bone.rotation;
        foot.bone.rotation=orientation;
    }

    // Both wrists share one actor-space height: the asymmetric combat idle must
    // not turn a two-handed lift into one high hand and one low hand.
    void TwoHandLift(float phase, float weight)
    {
        if (!joints.TryGetValue("la", out var left) || !joints.TryGetValue("ra", out var right)
            || !joints.TryGetValue("le", out var elbow) || !joints.TryGetValue("lh", out var wrist)) return;
        var center = (left.bone.position + right.bone.position) * .5f;
        float length = Vector3.Distance(left.bone.position, elbow.bone.position)
            + Vector3.Distance(elbow.bone.position, wrist.bone.position);
        var raised = center + actor.up * (length * .68f) + actor.forward * (length * .24f);
        var pressed = center - actor.up * (length * .24f) + actor.forward * (length * .58f);
        var destination = Vector3.Lerp(raised, pressed, phase);
        float halfWidth = Vector3.Distance(left.bone.position, right.bone.position) * .58f;
        AimArm("la", "le", "lh", destination - actor.right * halfWidth, -actor.right, weight);
        AimArm("ra", "re", "rh", destination + actor.right * halfWidth, actor.right, weight);
    }

    void AimArm(string upperKey, string elbowKey, string wristKey, Vector3 target, Vector3 outward, float weight)
    {
        if (!joints.TryGetValue(upperKey, out var upper) || !joints.TryGetValue(elbowKey, out var elbow)
            || !joints.TryGetValue(wristKey, out var wrist)) return;
        foreach (var joint in new[] { upper, elbow, wrist }) {
            Save(joint);
        }
        var baseUpper = upper.bone.localRotation;
        var baseElbow = elbow.bone.localRotation;
        float a = Vector3.Distance(upper.bone.position, elbow.bone.position);
        float b = Vector3.Distance(elbow.bone.position, wrist.bone.position);
        Vector3 direction = (target - upper.bone.position).normalized;
        float distance = Mathf.Clamp(Vector3.Distance(target, upper.bone.position), Mathf.Abs(a-b)+.001f, (a+b)*.97f);
        target = upper.bone.position + direction * distance;
        Vector3 pole = Vector3.ProjectOnPlane(outward - actor.forward * .25f, direction).normalized;
        float along = (a*a - b*b + distance*distance) / (2*distance);
        Vector3 elbowTarget = upper.bone.position + direction * along + pole * Mathf.Sqrt(Mathf.Max(0,a*a-along*along));
        upper.bone.rotation = Quaternion.FromToRotation(elbow.bone.position-upper.bone.position, elbowTarget-upper.bone.position) * upper.bone.rotation;
        elbow.bone.rotation = Quaternion.FromToRotation(wrist.bone.position-elbow.bone.position, target-elbow.bone.position) * elbow.bone.rotation;
        var goalUpper = upper.bone.localRotation; var goalElbow = elbow.bone.localRotation;
        upper.bone.localRotation = Quaternion.Slerp(baseUpper, goalUpper, weight);
        elbow.bone.localRotation = Quaternion.Slerp(baseElbow, goalElbow, weight);
    }

    static Vector3 V(float x,float y,float z) => new Vector3(x,y,z);
    static float Smooth(float value) { value = Mathf.Clamp01(value); return value * value * (3f - 2f * value); }

    float ExpectedContact() => ExpectedContact(CurrentSkill);

    public static float ExpectedContact(string skill)
    {
        switch (skill)
        {
            case "fool_skill_01": return .6192f;
            case "fool_skill_02": return .38f;
            case "fool_skill_04": return .441f;
            case "fool_skill_05": return .543f;
            case "fool_skill_06": return .705f;
            case "fool_skill_07": return .885f;
            case "fool_skill_08": return .63f;
            case "fool_skill_09": return .705f;
            case "fool_skill_10": return .96f;
            default: return .65f;
        }
    }

    void Pose(string key, Vector3 windup, Vector3 strike, float phase, float weight)
    {
        if (!joints.TryGetValue(key, out var joint) || !joint.bone) return;
        Save(joint);
        Quaternion actorDelta = Quaternion.Euler(Vector3.Lerp(windup, strike, phase) * weight);
        Quaternion worldDelta = actor.rotation * actorDelta * Quaternion.Inverse(actor.rotation);
        Quaternion parentRotation = joint.bone.parent ? joint.bone.parent.rotation : Quaternion.identity;
        joint.bone.localRotation = Quaternion.Inverse(parentRotation) * worldDelta * parentRotation * joint.baseline;
    }
}
