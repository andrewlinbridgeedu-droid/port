using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using Mindstone.VFXV1;
public static class FoolTempestPreview {
 public static void Capture(){
 EditorSceneManager.NewScene(NewSceneSetup.EmptyScene,NewSceneMode.Single);
 RenderSettings.ambientLight=new Color(.14f,.13f,.24f);RenderSettings.fog=true;RenderSettings.fogColor=new Color(.022f,.027f,.055f);RenderSettings.fogDensity=.024f;
 var cam=new GameObject("Tempest Camera").AddComponent<Camera>();cam.tag="MainCamera";cam.transform.position=new Vector3(4,4.8f,-13);cam.transform.LookAt(new Vector3(0,2.55f,.7f));cam.fieldOfView=38;cam.backgroundColor=new Color(.016f,.022f,.045f);cam.clearFlags=CameraClearFlags.SolidColor;cam.allowHDR=true;
 var sky=GameObject.CreatePrimitive(PrimitiveType.Quad);sky.name="Procedural thundercloud horizon";sky.transform.position=cam.transform.position+cam.transform.forward*35;sky.transform.rotation=cam.transform.rotation;sky.transform.localScale=new Vector3(25,35,1);sky.GetComponent<Renderer>().sharedMaterial=new Material(Resources.Load<Shader>("Mindstone/VFXV1/Spells/storm-fool-arcana-v1/ArcanaSky"));
 Light("Moon key",new Vector3(0,7,-4),new Color(.55f,.63f,1),1.2f,LightType.Directional);
 Light("Arcana rim",new Vector3(1,3,1),new Color(.55f,.17f,1),4,LightType.Point);
 Light("Amber fill",new Vector3(-3,2,-3),new Color(1,.63f,.26f),3,LightType.Point);
 var mat=new Material(Shader.Find("Standard"));mat.color=new Color(.024f,.028f,.042f);mat.SetFloat("_Metallic",.55f);mat.SetFloat("_Glossiness",.65f);
 for(int a=-7;a<=7;a++)for(int b=-7;b<=7;b++){var tile=GameObject.CreatePrimitive(PrimitiveType.Cube);tile.name="Obsidian courtyard slab";tile.transform.position=new Vector3(a*1.32f,-.11f,b*1.32f);tile.transform.localScale=new Vector3(1.315f,.2f,1.315f);tile.GetComponent<Renderer>().sharedMaterial=mat;}
 var file="Assets/Models/Fool/Meshy_AI_battle_magician_rig_biped_Animation_mage_soell_cast_4_frame_rate_60.fbx";
 var fool=Object.Instantiate(AssetDatabase.LoadAssetAtPath<GameObject>(file));fool.name="Fool actual game model";
 var bounds=new Bounds();bool first=true;foreach(var r in fool.GetComponentsInChildren<Renderer>()){if(first){bounds=r.bounds;first=false;}else bounds.Encapsulate(r.bounds);}
 fool.transform.localScale*=2.6f/bounds.size.y;
 fool.transform.position=new Vector3(-1.05f,0,-2.2f);fool.transform.rotation=Quaternion.Euler(0,155,0);
 var fm=new Material(Shader.Find("Standard"));fm.mainTexture=AssetDatabase.LoadAssetAtPath<Texture2D>("Assets/Models/Fool/Meshy_AI_battle_magician_rig_biped_texture_0.png");fm.SetFloat("_Glossiness",.3f);foreach(var r in fool.GetComponentsInChildren<Renderer>())r.sharedMaterial=fm;
 var actorScale=fool.transform.localScale;
 var clip=AssetDatabase.LoadAllAssetsAtPath(file).OfType<AnimationClip>().FirstOrDefault(v=>!v.name.StartsWith("__"));
 var host=new GameObject("Fool Arcana Tempest");var fx=host.AddComponent<FoolArcanaTempest>();fx.Initialize(null,null,73013);
 var rt=new RenderTexture(720,1080,24,RenderTextureFormat.ARGB32);rt.antiAliasing=4;cam.targetTexture=rt;var tex=new Texture2D(720,1080,TextureFormat.RGB24,false);
 var dir=Path.GetFullPath("../artifacts/fool-arcana-tempest");Directory.CreateDirectory(dir);
 bool seq=System.Environment.GetCommandLineArgs().Contains("-tempestSequence");int count=seq?120:5;float[] beats={.45f,1.2f,2.3f,3.4f,5.45f};
 for(int i=0;i<count;i++){float t=seq?i/20f:beats[i];if(clip)clip.SampleAnimation(fool,Mathf.Min(t*.45f,clip.length));fool.transform.localScale=actorScale;var bb=ActualBounds(fool);fool.transform.position+=new Vector3(-.25f-bb.center.x,-bb.min.y,-2.1f-bb.center.z);fx.SampleAt(t,new Vector3(0,0,1));cam.Render();RenderTexture.active=rt;tex.ReadPixels(new Rect(0,0,720,1080),0,0);tex.Apply();File.WriteAllBytes(Path.Combine(dir,seq?$"frame-{i:000}.png":$"stage-{i+1}.png"),tex.EncodeToPNG());}
 fx.Cleanup();RenderTexture.active=null;cam.targetTexture=null;Object.DestroyImmediate(rt);Object.DestroyImmediate(tex);Debug.Log("FOOL_TEMPEST_CAPTURE_OK "+dir);
 }
 static Bounds ActualBounds(GameObject actor){var b=new Bounds();bool first=true;foreach(var r in actor.GetComponentsInChildren<SkinnedMeshRenderer>()){var m=new Mesh();r.BakeMesh(m);foreach(var v in m.vertices){var p=r.transform.TransformPoint(v);if(first){b=new Bounds(p,Vector3.zero);first=false;}else b.Encapsulate(p);}Object.DestroyImmediate(m);}return b;}
 static void Light(string name,Vector3 pos,Color color,float intensity,LightType type){var l=new GameObject(name).AddComponent<Light>();l.type=type;l.transform.position=pos;l.transform.rotation=Quaternion.Euler(35,-35,0);l.color=color;l.intensity=intensity;l.range=12;l.shadows=LightShadows.Soft;}
}
