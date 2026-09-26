using System;
using System.Collections.Generic;
using UnityEngine;

// Extra weighted phalanges are not animated by the original 24-bone Animator.
// Every pose is authored from its immutable bind rotation, never accumulated.
[DefaultExecutionOrder(2200)]
public sealed class HeroFingerArticulation20260917 : MonoBehaviour
{
    [Serializable]
    public sealed class Joint
    {
        public Transform bone;
        public Quaternion bindLocalRotation = Quaternion.identity;
        public Vector3 curlLocalAxis = Vector3.right;
        // side: 0 left / 1 right; digit: 0 thumb, 1 index ... 4 little;
        // segment: 0 proximal, 1 intermediate, 2 distal.
        public int side, digit, segment;
    }
    readonly List<Joint> joints = new List<Joint>();
    readonly List<float> angles = new List<float>();
    FoolSkillChoreography choreography;
    Animator animator;
    SkinnedMeshRenderer[] bodies;
    bool explicitlyDefeated;
    public int BoneCount => joints.Count;
    public int FingerCount { get; private set; }
    public float MaxAppliedAngle { get; private set; }
    public long TotalAnimatedFrames { get; private set; }

    public void Configure(IEnumerable<Joint> source)
    {
        ResetPose(); joints.Clear(); angles.Clear();
        var bones = new HashSet<Transform>(); var fingers = new HashSet<int>();
        if (source != null) foreach (var j in source)
        {
            if (j == null || !j.bone || !bones.Add(j.bone) || j.curlLocalAxis.sqrMagnitude < 1e-8f
                || j.side < 0 || j.side > 1 || j.digit < 0 || j.digit > 4 || j.segment < 0 || j.segment > 2) continue;
            // Copy caller data; loader mutations must not change the bind reference.
            joints.Add(new Joint { bone=j.bone, bindLocalRotation=j.bindLocalRotation,
                curlLocalAxis=j.curlLocalAxis.normalized, side=j.side, digit=j.digit, segment=j.segment });
            angles.Add(0); fingers.Add(j.side*5+j.digit);
        }
        FingerCount=fingers.Count; TotalAnimatedFrames=0; explicitlyDefeated=false;
        choreography=GetComponentInParent<FoolSkillChoreography>();
        if (!choreography) choreography=GetComponentInChildren<FoolSkillChoreography>(true);
        animator=GetComponentInParent<Animator>();
        if (!animator) animator=GetComponentInChildren<Animator>(true);
        bodies=animator ? animator.GetComponentsInChildren<SkinnedMeshRenderer>(true) : GetComponentsInChildren<SkinnedMeshRenderer>(true);
    }
    // Optional immediate hook before a defeat snapshot; renderer hiding is also
    // detected because the current game shatters the hero instead of a Death clip.
    public void SetDefeated(bool value) { explicitlyDefeated=value; if(value)ResetPose(); }
    bool IsDeadOrHidden()
    {
        if(explicitlyDefeated)return true;
        if(animator && animator.runtimeAnimatorController){
            var s=animator.GetCurrentAnimatorStateInfo(0);
            if(s.IsName("Death")||s.IsName("Dead")||s.IsName("Meshy · Death"))return true;
        }
        if(bodies!=null && bodies.Length>0){
            foreach(var body in bodies)if(body && body.enabled && body.gameObject.activeInHierarchy)return false;
            return true;
        }
        return false;
    }
    void LateUpdate()
    {
        if(joints.Count==0)return;
        if(IsDeadOrHidden()){ResetPose();return;}
        bool casting=choreography && choreography.IsPlaying;
        string skill=casting?choreography.CurrentSkill:"";
        float blend=1f-Mathf.Exp(-Mathf.Min(Time.deltaTime,.1f)*(casting?11f:6f));
        MaxAppliedAngle=0;
        for(int i=0;i<joints.Count;i++){
            var j=joints[i];if(!j.bone)continue;
            float target=IdleCurl(j,Time.time);
            if(casting)target=SkillCurl(j,skill);
            angles[i]=Mathf.Lerp(angles[i],Mathf.Clamp(target,0,9),blend);
            j.bone.localRotation=j.bindLocalRotation*Quaternion.AngleAxis(angles[i],j.curlLocalAxis);
            MaxAppliedAngle=Mathf.Max(MaxAppliedAngle,angles[i]);
        }
        TotalAnimatedFrames++;
    }
    static float IdleCurl(Joint j,float t)
    {
        float curl=j.digit==0?3f:3.2f+j.digit*.6f;
        curl+=j.side==0?.5f:0;
        curl*=j.segment==0?.85f:j.segment==1?1f:.72f;
        // Small breath-linked flexion with different phalanx lag, not a grasp loop.
        return curl+.28f*Mathf.Sin(t*.83f+j.side*.7f+j.digit*.37f-j.segment*.3f);
    }
    static float SkillCurl(Joint j,string skill)
    {
        float value=5;
        switch(skill){
            case "fool_skill_01": value=j.digit<=1?3:6;break;
            case "fool_skill_02": value=j.side==1?4:6;break;
            case "fool_skill_04": value=j.digit==1?3:7;break;
            case "fool_skill_05": value=j.side==1?7.5f:4;break;
            case "fool_skill_06": value=j.digit<=1?3.5f:5.5f;break;
            case "fool_skill_07": value=j.digit==0?4:3;break;
            case "fool_skill_08": value=j.side==1?(j.digit==1?3:8):5;break;
            case "fool_skill_09": value=j.digit<=2?3.5f:6.5f;break;
            case "fool_skill_10": value=j.digit==0?4:3.2f;break;
        }
        return value*(j.segment==0?.9f:j.segment==1?1f:.75f);
    }
    public void ResetPose()
    {
        for(int i=0;i<joints.Count;i++){if(joints[i].bone)joints[i].bone.localRotation=joints[i].bindLocalRotation;angles[i]=0;}
        MaxAppliedAngle=0;
    }
    void OnDisable(){ResetPose();}
    void OnDestroy(){ResetPose();}
}
