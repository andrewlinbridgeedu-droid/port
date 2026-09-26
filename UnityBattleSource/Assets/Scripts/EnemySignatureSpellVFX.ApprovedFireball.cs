using Effekseer;
using UnityEngine;

public sealed partial class EnemySignatureSpellVFX
{
    EffekseerEffectAsset approvedFireball;
    EffekseerHandle approvedFlight,approvedFinish;
    bool approvedFlightStarted,approvedFinishStarted;
    void ClearApprovedFireball()
    {
        if(approvedFlightStarted)approvedFlight.Stop();
        if(approvedFinishStarted)approvedFinish.Stop();
        approvedFlightStarted=false;approvedFinishStarted=false;
    }
    bool DrawApprovedFireball(int phase,Vector3 source,Vector3 target)
    {
        if(!approvedFireball)approvedFireball=Resources.Load<EffekseerEffectAsset>("Effects/HellHound/FireBall");
        if(!approvedFireball)return false;
        if(phase==1 && !approvedFlightStarted) {
            Vector3 from=new Vector3(0,4.851079f,1.01948f),to=new Vector3(0,.09186983f,-15.32988f);
            Vector3 authored=to-from,travel=target-source;
            float scale=travel.magnitude/authored.magnitude;
            Quaternion rotation=Quaternion.FromToRotation(authored.normalized,travel.normalized);
            var parameters=EffekseerPlayEffectParameters.Create(source-rotation*(from*scale));
            parameters.SetScale(Vector3.one*scale);rotation.ToAngleAxis(out float angle,out Vector3 axis);
            parameters.SetRotation(axis,angle*Mathf.Deg2Rad);parameters.Speed=29.9f/(60f*TravelDuration);
            approvedFlight=EffekseerSystem.PlayEffect(approvedFireball,parameters);
            approvedFlight.SetAllColor(new Color(.90f,.82f,.72f,.75f));approvedFlight.SetTargetLocation(target);
            approvedFlight.UpdateHandleToMoveToFrame(120);approvedFlightStarted=true;
        }
        if(phase==2 && !approvedFinishStarted) {
            if(approvedFlightStarted)approvedFlight.Stop();
            var parameters=EffekseerPlayEffectParameters.Create(target);
            parameters.SetScale(Vector3.one*.29f);parameters.Speed=2.2f;
            approvedFinish=EffekseerSystem.PlayEffect(approvedFireball,parameters);
            approvedFinish.SetAllColor(new Color(1,.92f,.72f,.91f));approvedFinish.SetTargetLocation(target);
            approvedFinish.UpdateHandleToMoveToFrame(150);approvedFinishStarted=true;
        }
        return phase>0;
    }
}
