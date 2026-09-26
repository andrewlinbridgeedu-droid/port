using UnityEngine;
using System.Collections.Generic;

/// Visual-only motion on a child of the enemy formation root.
public sealed class FogGhostActor : MonoBehaviour {
    Vector3 home; int variant; float castAt=-100; Transform leftArm,rightArm;
    Quaternion leftRest,rightRest; readonly List<Material> materials=new List<Material>();
    public bool IsSplit => variant >= 2;
    public bool IsCasting => (Time.time-castAt)*(IsSplit?1.5f:1f)<1.1f;
    bool configured;
    public void Configure(int colorVariant) {
        if(configured) { variant=colorVariant; ApplyColor(); return; }
        configured=true;
        variant=colorVariant;home=transform.localPosition;
        foreach(var bone in GetComponentsInChildren<Transform>()) {
            if(bone.name=="LeftArm"){leftArm=bone;leftRest=bone.localRotation;}
            if(bone.name=="RightArm"){rightArm=bone;rightRest=bone.localRotation;}
        }
        foreach(var r in GetComponentsInChildren<Renderer>()) {
            foreach(var m in r.materials) {
                materials.Add(m);

            }
        }
        ApplyColor();
    }
    void ApplyColor() {
        foreach(var m in materials) {
            m.color=IsSplit?new Color(1f,.14f,.105f):variant==0?new Color(.66f,.96f,1):new Color(.84f,.74f,1);
            m.EnableKeyword("_EMISSION");
            m.SetColor("_EmissionColor",IsSplit?new Color(.24f,.008f,.004f):variant==0?new Color(.01f,.075f,.09f):new Color(.055f,.018f,.085f));
        }
    }
    public void Cast(){castAt=Time.time;}
    void LateUpdate() {
        float phase=Time.time*(IsSplit?1.8f:1.3f)+variant*2.4f;
        float t=(Time.time-castAt)*(IsSplit?1.5f:1f);
        float cast=t<1.1f?Mathf.Sin(Mathf.Clamp01(t/1.1f)*Mathf.PI):0;
        transform.localPosition=home+Vector3.up*(.10f+Mathf.Sin(phase)*.055f+cast*.08f);
        transform.localRotation=Quaternion.Euler(0,180+Mathf.Sin(phase*.7f)*3,Mathf.Sin(phase)*1.5f);
        if(leftArm)leftArm.localRotation=leftRest*Quaternion.Euler(0,0,18+cast*28);
        if(rightArm)rightArm.localRotation=rightRest*Quaternion.Euler(0,0,-18-cast*40);
    }
    void OnDestroy(){foreach(var m in materials)if(m)Destroy(m);}
}
