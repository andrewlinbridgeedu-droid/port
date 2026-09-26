using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
// Independent outlaw instance palette and readable props. Mainline source assets never mutate.
public sealed class BountyIdentityPresentation20260917:MonoBehaviour {
 public string bountyID;
 readonly List<Material> owned=new List<Material>();
 GameObject props;
 BountyBodyRound2 body;
 int strikeVariation;
 public void Configure(EnemyHandle actor,string id) {
  bountyID=id;
  bool authoredModel=actor.ProfileEnemyId!=null&&actor.ProfileEnemyId.StartsWith("bounty-b",StringComparison.Ordinal);
  // The actor can already carry its single body owner after clone/reconfigure.
  body=GetComponent<BountyBodyRound2>();
  if(!body)body=gameObject.AddComponent<BountyBodyRound2>();
  body.Configure(actor,id);
  var palette=authoredModel?(id=="b08-echo"?new Color(.58f,.72f,1f):Color.white):id=="b01"?new Color(.51f,.57f,.61f):id=="b02"?new Color(.48f,.31f,.20f):id.StartsWith("b03")?new Color(.20f,.58f,.80f):id=="b04"?new Color(.42f,.62f,.45f):id=="b05"?new Color(.8f,.79f,.83f):new Color(.22f,.24f,.29f);
  var shader=Resources.Load<Shader>("Shaders/BountyIdentity");
  foreach(var ward in actor.EnemyRoot.GetComponentsInChildren<Mindstone.VFXV1.GuardianWard>(true))ward.gameObject.SetActive(false);
  foreach(var renderer in actor.EnemyRoot.GetComponentsInChildren<Renderer>(true)) {
   if(!(renderer is SkinnedMeshRenderer))continue;
   var materials=renderer.sharedMaterials;
   for(int i=0;i<materials.Length;i++) {
    if(!materials[i])continue;var source=materials[i];var mat=new Material(shader);mat.name="Bounty_"+id+"_"+source.name;
    if(source.HasProperty("_MainTex"))mat.SetTexture("_MainTex",source.GetTexture("_MainTex"));
    foreach(var map in new[]{"_BumpMap","_MetallicGlossMap"})if(source.HasProperty(map))mat.SetTexture(map,source.GetTexture(map));
    mat.SetColor("_IdentityTint",palette);mat.SetFloat("_ArtPreserve",authoredModel?1:0);mat.SetColor("_EmissionColor",!authoredModel&&id.StartsWith("b03")?new Color(.015f,.055f,.08f):Color.black);owned.Add(mat);materials[i]=mat;
   }
   renderer.sharedMaterials=materials;
  }
  if(id=="b03-escort"||authoredModel)return;
  var skins=actor.EnemyRoot.GetComponentsInChildren<Renderer>().Where(x=>x is SkinnedMeshRenderer).ToArray();
  Bounds bounds=new Bounds(actor.EnemyRoot.position,Vector3.zero);foreach(var r in skins)bounds.Encapsulate(r.bounds);
  float height=Mathf.Max(1.6f,bounds.size.y);props=new GameObject("BountyIdentity_"+id);props.transform.SetParent(actor.EnemyRoot,false);
  var head=actor.EnemyRoot.GetComponentsInChildren<Transform>(true).FirstOrDefault(t=>t.gameObject.activeInHierarchy&&(t.name=="Head"||t.name.EndsWith(":Head")||t.name=="head"));
  Vector3 face=head?head.position:actor.EnemyRoot.position+Vector3.up*height*.83f;
  if(id=="b02") {var mask=Part("Outlaw face covering",PrimitiveType.Sphere,face+Vector3.up*.12f+Vector3.back*.30f,new Vector3(.23f,.30f,.075f),new Color(.11f,.065f,.04f));if(head)mask.transform.SetParent(head,true);}
  // Keep faces readable. The pirate uses a worn anchor brooch, never a floating primitive hat.
  var bones=actor.EnemyRoot.GetComponentsInChildren<Transform>().Where(t=>t.gameObject.activeInHierarchy).ToArray();
  var chest=bones.FirstOrDefault(t=>t.name=="Chest"||t.name.EndsWith(":Spine2"))??bones.FirstOrDefault(t=>t.name=="Spine"||t.name.EndsWith(":Spine"));
  var shoulder=bones.FirstOrDefault(t=>t.name.ToLowerInvariant().Contains("leftshoulder")||t.name=="Shoulder.L")??chest;
  Transform attachment=id=="b01"?shoulder:chest;
  Vector3 desired=attachment?attachment.position:actor.EnemyRoot.position+Vector3.up*height*.63f;
  if(id=="b01")desired+=Vector3.left*.36f+Vector3.down*.08f;
  else if(id=="b05")desired+=Vector3.left*.14f;
  Vector3 badge=SurfacePoint(actor,desired)+Vector3.back*.018f;
  float scale=id=="b01"?.62f:id=="b05"?.68f:1f;
  if(id!="b05") {
   var seal=Part("Worn metal insignia "+id,PrimitiveType.Cylinder,badge,new Vector3(.15f*scale,.014f,.18f*scale),id=="b01"?new Color(.57f,.40f,.11f):new Color(.27f,.31f,.34f));seal.transform.rotation=Quaternion.Euler(90,0,0);
  }
  if(id=="b01"||id=="b04"){
   var g=new GameObject("Engraved identity mark");g.transform.SetParent(props.transform);g.transform.position=badge+Vector3.back*.021f;g.transform.rotation=Quaternion.identity;var text=g.AddComponent<TextMesh>();text.text=id=="b01"?"7":"31";text.anchor=TextAnchor.MiddleCenter;text.alignment=TextAlignment.Center;text.fontSize=48;text.characterSize=.033f*scale;text.color=new Color(.85f,.78f,.52f);
  }
  if(id=="b05")for(int i=0;i<2;i++){
   var blade=Part("Silver scissor brooch",PrimitiveType.Capsule,badge+Vector3.back*.02f,new Vector3(.014f,.095f,.014f),new Color(.68f,.73f,.80f));blade.transform.rotation=Quaternion.Euler(0,0,i==0?28:-28);
  }
  if(id=="b03"||id=="b06"){
   Part("Anchor stem",PrimitiveType.Cube,badge+Vector3.back*.025f,new Vector3(.016f,.13f,.016f),new Color(.69f,.75f,.78f));
   for(int i=-1;i<=1;i+=2){var tip=Part("Anchor fluke",PrimitiveType.Cube,badge+new Vector3(i*.029f,-.034f,-.025f),new Vector3(.014f,.065f,.016f),new Color(.69f,.75f,.78f));tip.transform.rotation=Quaternion.Euler(0,0,i*-45);}
  }
  if(attachment)props.transform.SetParent(attachment,true);

 }
 static Vector3 SurfacePoint(EnemyHandle actor,Vector3 desired){
  // Read the actual skinned surface so ornaments cannot float above the shoulder or chest.
  Vector3 result=desired;float score=float.PositiveInfinity;
  foreach(var renderer in actor.EnemyRoot.GetComponentsInChildren<SkinnedMeshRenderer>()){
   var mesh=new Mesh();renderer.BakeMesh(mesh,true);
   foreach(var vertex in mesh.vertices){var world=renderer.transform.TransformPoint(vertex);float d=(world.x-desired.x)*(world.x-desired.x)+(world.y-desired.y)*(world.y-desired.y)*2+Mathf.Max(0,world.z-desired.z)*.2f;
    if(d<score){score=d;result=world;}}
   Destroy(mesh);
  }
  return result;
 }
 GameObject Part(string name,PrimitiveType type,Vector3 position,Vector3 size,Color color) {
  var g=GameObject.CreatePrimitive(type);g.name=name;Destroy(g.GetComponent<Collider>());g.transform.position=position;g.transform.localScale=size;g.transform.SetParent(props.transform,true);var mat=new Material(Shader.Find("Standard"));mat.color=color;mat.SetFloat("_Metallic",.25f);mat.SetFloat("_Glossiness",.4f);owned.Add(mat);g.GetComponent<Renderer>().sharedMaterial=mat;return g;
 }
 int epoch;GameObject attackFx;Material attackMaterial;
 public bool OwnsStrike => bountyID=="b01"||bountyID.StartsWith("b03");
 public void Prepare(string phase){
  Cancel();var h=GetComponent<EnemyHandle>();
  if(phase=="recover"){ReturnIdle();return;}
  body.Begin(phase,.65f,true,strikeVariation);
  attackFx=new GameObject("Bounty telegraph "+bountyID);
  var art=attackFx.AddComponent<BountySpellRound2>();
  art.Configure(bountyID,phase,body.SourcePoint,()=>h.EffectAnchor.position,.65f);
  art.AttachSource(()=>body.SourcePoint);art.ambient=true;
  var a=body.Animator;if(!a)return;
  a.speed=1;
  if(a.HasState(0,Animator.StringToHash("Charge")))a.CrossFadeInFixedTime("Charge",.1f,0,0);
  else ReturnIdle();
 }
 void ReturnIdle(){var a=body?body.Animator:GetComponentInChildren<Animator>();if(!a)return;a.speed=1;
  string idle=a.HasState(0,Animator.StringToHash("Meshy · Idle"))?"Meshy · Idle":"Idle";
  if(a.HasState(0,Animator.StringToHash(idle)))a.CrossFadeInFixedTime(idle,.12f,0,0);
 }
 public IEnumerator Strike(EnemyHandle actor,Func<Vector3> victim,string intent,Action contact,Func<bool> valid){
  bool prepared=body&&body.IsPreparing;Cancel();int token=epoch;
  const float contactTime=.65f;
  body.Begin(intent,contactTime,false,strikeVariation++,prepared);
  var a=body.Animator;if(a){a.speed=1;if(a.HasState(0,Animator.StringToHash("Cast")))a.CrossFadeInFixedTime("Cast",.08f,0,0);else a.SetTrigger("Attack");}actor.GetComponentInChildren<FogGhostActor>()?.Cast();
  attackFx=new GameObject("Bounty attack "+bountyID);var ownedFx=attackFx;
  Func<Vector3> spellTarget=victim;
  if(bountyID=="b10-vessel"){
   var boss=FindObjectsOfType<EnemyHandle>().FirstOrDefault(x=>x&&x!=actor&&x.ProfileEnemyId=="bounty-b10"&&x.gameObject.activeInHierarchy);
   if(boss)spellTarget=()=>boss&&boss.gameObject.activeInHierarchy?boss.EffectAnchor.position:victim();
  }
  bool torsoSource=intent=="bounty_armor"||intent=="bounty_mirror";
  var art=attackFx.AddComponent<BountySpellRound2>();art.Configure(bountyID,intent,torsoSource?body.TorsoPoint:body.SourcePoint,spellTarget,contactTime);art.AttachSource(()=>torsoSource?body.TorsoPoint:body.SourcePoint);bool hit=false;
  try{for(float t=0;t<1.3f;t+=Time.deltaTime){if(token!=epoch||!valid())yield break;art.Sample(t);if(!hit&&t>=contactTime){hit=true;body.Contact();contact?.Invoke();}yield return null;}}
  finally{if(ownedFx){ownedFx.SetActive(false);Destroy(ownedFx);}if(attackFx==ownedFx)attackFx=null;if(token==epoch){body.Clear();ReturnIdle();}}
 }
 public void Cancel(){epoch++;if(attackFx){attackFx.SetActive(false);Destroy(attackFx);}if(attackMaterial)Destroy(attackMaterial);attackFx=null;attackMaterial=null;if(body)body.Clear();var a=body?body.Animator:GetComponentInChildren<Animator>();if(a)a.speed=1;}
 void OnDisable(){Cancel();}
 void OnDestroy(){foreach(var m in owned)if(m)Destroy(m);}
}
