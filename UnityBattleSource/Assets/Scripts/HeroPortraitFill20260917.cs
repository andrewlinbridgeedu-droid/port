using UnityEngine;

// A restrained, real scene bounce light. The inspection camera never changes this light.
[DefaultExecutionOrder(2200)]
public sealed class HeroPortraitFill20260917 : MonoBehaviour {
 Animator animator;Transform marker;Light fill;
 public static void Install(GameObject actor){if(actor&&!actor.GetComponent<HeroPortraitFill20260917>())actor.AddComponent<HeroPortraitFill20260917>();}
 void Awake(){
  animator=GetComponentInChildren<Animator>();if(!animator||!animator.isHuman)return;
  foreach(var t in animator.GetComponentsInChildren<Transform>(true))if(t.name=="headfront"||t.name.EndsWith(":headfront")){marker=t;break;}
  var go=new GameObject("Hero warm sky bounce");go.transform.SetParent(transform,false);fill=go.AddComponent<Light>();
  fill.type=LightType.Point;fill.color=new Color(1f,.94f,.86f);fill.intensity=.65f;fill.shadows=LightShadows.None;fill.renderMode=LightRenderMode.ForcePixel;
 }
 void LateUpdate(){
  if(!fill||!animator)return;
  var head=animator.GetBoneTransform(HumanBodyBones.Head);var foot=animator.GetBoneTransform(HumanBodyBones.LeftFoot);if(!head||!foot)return;
  float height=Vector3.Distance(head.position,foot.position);
  var direction=marker?Vector3.ProjectOnPlane(marker.position-head.position,Vector3.up).normalized:transform.forward;
  fill.transform.position=head.position+direction*height*.65f+Vector3.up*height*.25f+Vector3.Cross(Vector3.up,direction)*height*.25f;
  fill.range=height*1.6f;
 }
 void OnDisable(){if(fill)fill.enabled=false;}
 void OnEnable(){if(fill)fill.enabled=true;}
}
