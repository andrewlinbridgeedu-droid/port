using UnityEngine;

/// A soft grounding contact under the actor, not a target indicator. Owns no actor
/// transforms/materials. Lives outside actor bounds and follows hide/fade/pooling.
[DisallowMultipleComponent]
[DefaultExecutionOrder(1500)]
public sealed class CharacterContactShadow : MonoBehaviour
{
    GameObject shadow;
    Renderer body;
    Material material;
    EnemyHandle handle;
    Transform leftFoot,rightFoot;
    float opacity,width,depth,height;
    bool floating;
    public static void Install(GameObject actor,CharacterSurfaceRefinement20260916.Family family)
    {
        if(!actor)return;
        var instance=actor.GetComponent<CharacterContactShadow>();
        if(!instance)instance=actor.AddComponent<CharacterContactShadow>();
        if(!instance.shadow)instance.Configure(family);
    }
    void Configure(CharacterSurfaceRefinement20260916.Family family)
    {
        handle=GetComponentInParent<EnemyHandle>();
        foreach(var r in GetComponentsInChildren<Renderer>(true)) {
            if(r is ParticleSystemRenderer||r is LineRenderer||r is TrailRenderer)continue;
            if(!body||r.bounds.size.sqrMagnitude>body.bounds.size.sqrMagnitude)body=r;
        }
        if(!body)return;
        var shader=Resources.Load<Shader>("Shaders/CharacterContactShadow");if(!shader)return;
        floating=family==CharacterSurfaceRefinement20260916.Family.Ghost||family==CharacterSurfaceRefinement20260916.Family.Core||family==CharacterSurfaceRefinement20260916.Family.Leech;
        height=Mathf.Max(.5f,body.bounds.size.y);
        width=Mathf.Clamp(body.bounds.size.x*.72f,.45f,height*.8f);
        depth=width*.62f;opacity=floating?.085f:.21f;
        var animator=GetComponentInChildren<Animator>();
        if(animator&&animator.isHuman) {leftFoot=animator.GetBoneTransform(HumanBodyBones.LeftFoot);rightFoot=animator.GetBoneTransform(HumanBodyBones.RightFoot);}
        shadow=GameObject.CreatePrimitive(PrimitiveType.Quad);shadow.name="Soft character contact - "+name;
        Destroy(shadow.GetComponent<Collider>());
        material=new Material(shader);shadow.GetComponent<Renderer>().sharedMaterial=material;
        shadow.GetComponent<Renderer>().shadowCastingMode=UnityEngine.Rendering.ShadowCastingMode.Off;
        shadow.GetComponent<Renderer>().receiveShadows=false;
        shadow.transform.rotation=Quaternion.Euler(90,0,0);
        shadow.transform.localScale=new Vector3(width*2,depth*2,1);
    }
    void LateUpdate()
    {
        if(!shadow||!body)return;
        bool visible=body.enabled&&body.gameObject.activeInHierarchy;
        shadow.SetActive(visible);if(!visible)return;
        var position=handle?handle.EnemyRoot.position:transform.position;
        if(leftFoot&&rightFoot) {var feet=(leftFoot.position+rightFoot.position)*.5f;position.x=feet.x;position.z=feet.z;position.y=Mathf.Min(leftFoot.position.y,rightFoot.position.y)-height*.035f;}
        position.y+=.018f;
        shadow.transform.position=position;
        float alpha=1;
        foreach(var m in body.sharedMaterials) {
            if(m&&m.HasProperty("_ExitOpacity"))alpha=Mathf.Min(alpha,m.GetFloat("_ExitOpacity"));
        }
        material.SetColor("_Color",new Color(.025f,.024f,.035f,opacity*alpha));
    }
    void OnDisable(){if(shadow)shadow.SetActive(false);}
    void OnDestroy(){if(shadow)Destroy(shadow);if(material)Destroy(material);}
}
