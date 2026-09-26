using System.Collections.Generic;
using UnityEngine;

/// Preserves the authored mesh/UV/paint while restoring distinct cloth and metal response.
[DefaultExecutionOrder(2100)]
public sealed class HeroBackArtRefinement : MonoBehaviour
{
 readonly List<Renderer> renderers = new List<Renderer>();
 readonly List<Material[]> originals = new List<Material[]>();
 readonly List<Material[]> refined = new List<Material[]>();
 readonly List<Material> owned = new List<Material>();
 Animator rig;
 public static HeroBackArtRefinement Install(GameObject actor)
 {
  if (!actor) return null;
  HeroPremiumHead20260917.Install(actor);
  HeroPortraitFill20260917.Install(actor);
  HeroTailoringDetails20260916.Install(actor);
  return actor.GetComponent<HeroBackArtRefinement>() ?? actor.AddComponent<HeroBackArtRefinement>();
 }
 void Awake()
 {
  rig=GetComponentInChildren<Animator>();
  var shader=Resources.Load<Shader>("Shaders/HeroTailoredPBR");
  var metal=Resources.Load<Texture2D>("RuntimeModels/Fool/Meshy_AI_battle_magician_rig_biped_texture_0_metallic");
  var normal=Resources.Load<Texture2D>("RuntimeModels/Fool/Meshy_AI_battle_magician_rig_biped_texture_0_normal");
  var facePaint=Resources.Load<Texture2D>("RuntimeModels/Fool/HeroFacePaint");
  var regions=Resources.Load<Texture2D>("RuntimeModels/Fool/HeroRegions");
  var costume=Resources.Load<Texture2D>("RuntimeModels/Fool/HeroCostumeAlbedo");
  var costumeRough=Resources.Load<Texture2D>("RuntimeModels/Fool/HeroCostumeRoughness");
  var costumeMetal=Resources.Load<Texture2D>("RuntimeModels/Fool/HeroCostumeMetallic");
  var rough=Resources.Load<Texture2D>("RuntimeModels/Fool/Meshy_AI_battle_magician_rig_biped_texture_0_roughness");
  if (!shader || !metal || !rough || !normal) {Debug.LogError("Hero tailored PBR resources missing");return;}
  foreach(var renderer in GetComponentsInChildren<SkinnedMeshRenderer>(true)) {
   // Sclera and iris use their own UVs and wet surface response.
   if(renderer.sharedMaterial&&renderer.sharedMaterial.name.StartsWith("Hero eye · "))continue;
   var source=renderer.sharedMaterials;var result=new Material[source.Length];
   for(int i=0;i<source.Length;i++) {
    if(!source[i]) continue;
    var mat=new Material(source[i]);mat.shader=shader;mat.name=source[i].name+" · tailored";
    string materialName=source[i].name.ToLowerInvariant();
    bool hair=materialName.Contains("hair");
    bool painted=source[i].mainTexture && !materialName.Contains("silk") && !materialName.Contains("gold") && !hair;
    // Decorative meshes do not share the body atlas UVs. Never project body normals onto hair.
    mat.SetFloat("_FacePaintReady",painted&&facePaint?1:0);if(painted&&facePaint)mat.SetTexture("_FacePaintMap",facePaint);
    mat.SetFloat("_RegionsReady",painted&&regions?1:0);if(painted&&regions)mat.SetTexture("_RegionMap",regions);
    mat.SetFloat("_Painted",painted?1:0);mat.SetFloat("_Hair",hair?1:0);
    mat.SetFloat("_SourceMetal",source[i].HasProperty("_Metallic")?source[i].GetFloat("_Metallic"):0);
    mat.SetFloat("_SourceSmooth",source[i].HasProperty("_Glossiness")?source[i].GetFloat("_Glossiness"):.35f);
    bool authoredSurface=painted&&costume&&costumeRough&&costumeMetal;
    mat.SetFloat("_AuthoredSurfaceReady",authoredSurface?1:0);
    if(authoredSurface)mat.SetTexture("_MainTex",costume);
    if(painted){mat.SetTexture("_MetalMap",authoredSurface?costumeMetal:metal);mat.SetTexture("_RoughMap",authoredSurface?costumeRough:rough);}
    else {mat.SetTexture("_MetalMap",Texture2D.blackTexture);mat.SetTexture("_RoughMap",Texture2D.whiteTexture);mat.SetTexture("_BumpMap",null);}
    bool fabric=source[i].name.ToLowerInvariant().Contains("silk");
    bool gold=source[i].name.ToLowerInvariant().Contains("gold");
    if (painted) mat.SetTexture("_BumpMap",normal);
    mat.SetFloat("_Fabric",fabric?1:0);mat.SetFloat("_Gold",gold?1:0);
    mat.SetFloat("_BumpScale",painted?.78f:0f);owned.Add(mat);result[i]=mat;
   }
   renderers.Add(renderer);originals.Add(source);refined.Add(result);renderer.sharedMaterials=result;
  }
 }
 void LateUpdate()
 {
  if(!rig || !rig.isHuman) return;
  var neck=rig.GetBoneTransform(HumanBodyBones.Neck);var hips=rig.GetBoneTransform(HumanBodyBones.Hips);
  var left=rig.GetBoneTransform(HumanBodyBones.LeftUpperArm);var right=rig.GetBoneTransform(HumanBodyBones.RightUpperArm);
  if(!neck || !hips || !left || !right) return;
  var up=(neck.position-hips.position).normalized;var side=(right.position-left.position).normalized;
  var forward=Vector3.Cross(side,up).normalized;
  var center=Vector3.Lerp(hips.position,neck.position,.66f);float width=Vector3.Distance(left.position,right.position)*.48f;
  foreach(var mat in owned) {
   mat.SetVector("_BackCenter",new Vector4(center.x,center.y,center.z,width));
   mat.SetVector("_BackRight",side);mat.SetVector("_BackUp",up);mat.SetVector("_BackForward",forward);
  }
 }
 public void ShowRefinement(bool show) {for(int i=0;i<renderers.Count;i++) if(renderers[i]) renderers[i].sharedMaterials=show?refined[i]:originals[i];}
 void OnDestroy() {ShowRefinement(false);foreach(var mat in owned) if(mat) Destroy(mat);}
}
