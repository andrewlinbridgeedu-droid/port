using UnityEngine;

/// Camera-space accents follow world-space combat anchors; owns all temporary resources.
[DefaultExecutionOrder(960)]
public sealed class FoolBasicTarotVFX : MonoBehaviour
{
    public const float Duration = 1.65f;
    Camera view;
    Transform source, target;
    GameObject surface;
    Material material;
    GameObject card;
    Mesh cardMesh;
    Material cardFace, cardEdge;
    FoolSkillChoreography choreography;
    Vector3 launch;
    bool launched;
    float elapsed;
    bool playing;
    bool contactReported;
    static readonly int Beat = Shader.PropertyToID("_Beat");
    static readonly int Source = Shader.PropertyToID("_Source");
    static readonly int Target = Shader.PropertyToID("_Target");
    static readonly int Aspect = Shader.PropertyToID("_Aspect");

    public void Play(Camera camera, Transform caster, Transform victim)
    {
        Clear();
        if (!camera || !caster || !victim) return;
        var shader = Resources.Load<Shader>("Effects/Fool/TarotNova");
        if (!shader) { Debug.LogError("Fool basic attack shader missing."); return; }
        view = camera; source = caster; target = victim;
        // The sample owns its illustrated body action; this component keeps
        // the original flying tarot and its sole .58 s contact callback.
        if (!caster.GetComponentInChildren<AIHeroAnimatedBody>()) {
            choreography=FoolSkillChoreography.Install(caster);
            choreography.Begin(FoolSkillChoreography.BasicID);
        }
        var paperShader=Shader.Find("Sprites/Default");
        if(paperShader)
        {
            card=new GameObject("H00 physical flipping tarot");
            card.transform.SetParent(transform,false);
            cardMesh=HeroPaperRound2.Create(new Rect(.344f,.814f,.052f,.111f),.58f,.018f,.055f,4);
            cardFace=new Material(paperShader){mainTexture=Resources.Load<Texture2D>("Effects/Fool/FoolTarotVFXAtlas"),renderQueue=3018};
            cardEdge=new Material(paperShader){renderQueue=3018};
            card.AddComponent<MeshFilter>().sharedMesh=cardMesh;
            card.AddComponent<MeshRenderer>().sharedMaterials=new[]{cardFace,cardEdge};
        }
        material = new Material(shader) { name = "Fool basic tarot (owned)" };
        material.SetTexture("_Atlas", Resources.Load<Texture2D>("Effects/Fool/FoolTarotVFXAtlas"));
        surface = GameObject.CreatePrimitive(PrimitiveType.Quad);
        surface.name = "Fool Basic Tarot Fullscreen";
        Destroy(surface.GetComponent<Collider>());
        surface.transform.SetParent(camera.transform, false);
        surface.GetComponent<MeshRenderer>().sharedMaterial = material;
        elapsed = 0; contactReported = false; launched=false; playing = true; Sample(0);
    }

    void LateUpdate()
    {
        if (!playing) return;
        elapsed += Time.deltaTime;
        if (elapsed >= Duration || !source || !target || !view || !source.gameObject.activeInHierarchy || !target.gameObject.activeInHierarchy) { Clear(); return; }
        Sample(elapsed);
    }

    public void Sample(float time)
    {
        if (!material || !view || !surface || !source || !target) return;
        time=Mathf.Max(0,time);
        Vector3 wrist=choreography?choreography.CastingHandPosition:source.position+Vector3.up*1.15f;
        if(!launched)launch=wrist;
        if(time>=.16f)launched=true;
        Vector3 aim=target.position+Vector3.up*1.05f;
        float flight=Mathf.Clamp01((time-.16f)/.42f);
        Vector3 bow=-view.transform.right*.24f+Vector3.up*.16f;
        Vector3 center=Vector3.Lerp(launch,aim,flight)+bow*Mathf.Sin(flight*Mathf.PI);
        if(card)
        {
            float hit=Mathf.Max(0,time-.58f);
            float alpha=Mathf.SmoothStep(0,1,time/.06f)*(1-Mathf.SmoothStep(0,1,hit/.16f));
            card.SetActive(alpha>0);
            card.transform.position=time<.16f?wrist:center;
            card.transform.rotation=view.transform.rotation*Quaternion.Euler(13+flight*18,Mathf.Lerp(-65,16,Mathf.Clamp01(time/.19f)),Mathf.Lerp(-48,29,flight));
            card.transform.localScale=Vector3.one*(.52f+Mathf.Sin(flight*Mathf.PI)*.08f);
            cardFace.color=cardEdge.color=new Color(1,1,1,alpha);
        }
        float distance = view.nearClipPlane + .12f;
        float height = view.orthographic ? view.orthographicSize * 2 : 2 * distance * Mathf.Tan(view.fieldOfView * Mathf.Deg2Rad * .5f);
        surface.transform.localPosition = new Vector3(0, 0, distance);
        surface.transform.localScale = new Vector3(height * view.aspect, height, 1);
        material.SetFloat(Beat, HeroVisualBeat.Sample(time, .58f, .055f));
        if (!contactReported && time >= .58f) {
            contactReported = true;
            if(choreography&&choreography.CurrentSkill==FoolSkillChoreography.BasicID)choreography.Contact();
            UnityBattleBridge.ReportCombatContact("player");
        }
        material.SetFloat(Aspect, view.aspect);
        material.SetVector(Source, view.WorldToViewportPoint(launch));
        material.SetVector(Target, view.WorldToViewportPoint(target.position + Vector3.up * 1.05f));
    }

    public void Clear()
    {
        playing = false;
        if(choreography&&choreography.CurrentSkill==FoolSkillChoreography.BasicID)choreography.Clear();
        choreography=null;
        if(card){card.SetActive(false);Destroy(card);}card=null;
        if(cardMesh)Destroy(cardMesh);cardMesh=null;
        if(cardFace)Destroy(cardFace);cardFace=null;
        if(cardEdge)Destroy(cardEdge);cardEdge=null;
        if (surface) { surface.SetActive(false); Destroy(surface); }
        if (material) Destroy(material);
        surface = null; material = null; source = null; target = null; view = null;
    }
    void OnDisable() => Clear();
    void OnDestroy() => Clear();
}
