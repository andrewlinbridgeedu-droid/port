using System;
using System.Collections.Generic;
using UnityEngine;

// Candidate head topology uses the existing hero rig; body, animations and identity stay intact.
public sealed class HeroPremiumHead20260917 : MonoBehaviour {
 [Serializable] sealed class Weight { public string bone; public float weight; }
 [Serializable] sealed class Influence { public Weight[] items; }
 [Serializable] sealed class Shape { public string name; public Vector3[] deltaVertices,deltaNormals; }
 [Serializable] sealed class Part { public string name,materialKind,textureResource; public Color color=Color.white; public float smoothness=.3f; public Vector3[] vertices,normals; public Vector2[] uv; public int[] triangles; public Influence[] weights; public Shape[] blendShapes; }
 [Serializable] sealed class ExtraBone { public string name,parent,digit,side; public int segment; public Vector3 position,axis; }
 [Serializable] sealed class Data { public Vector2[] headTriangleUVs; public Part[] meshes; public ExtraBone[] bones; }
 readonly List<Mesh> owned=new List<Mesh>();readonly List<GameObject> objects=new List<GameObject>();
 Mesh original;SkinnedMeshRenderer body;Material hairMaterial;readonly List<Material> eyeMaterials=new List<Material>();
 public static void Install(GameObject actor){if(actor&&!actor.GetComponent<HeroPremiumHead20260917>())actor.AddComponent<HeroPremiumHead20260917>();}
 static string Short(string name){int n=name.LastIndexOf(':');return n<0?name:name.Substring(n+1);}
 static string Point(Vector2 uv){return Mathf.RoundToInt(uv.x*1000000)+":"+Mathf.RoundToInt(uv.y*1000000);}
 static string Key(Vector2 a,Vector2 b,Vector2 c){var v=new[]{Point(a),Point(b),Point(c)};Array.Sort(v,StringComparer.Ordinal);return string.Join("/",v);}
 void Awake(){
  var json=Resources.Load<TextAsset>("HeroPremium/head");if(!json)return;
  foreach(var r in GetComponentsInChildren<SkinnedMeshRenderer>(true))if(r.name=="char1"){body=r;break;}
  Matrix4x4 conversion;
  if(!body||!HeroTailoringDetails20260916.ResolveSourceTransform(body,out conversion)){Debug.LogError("[HeroPremium] Source correspondence failed");return;}
  var data=JsonUtility.FromJson<Data>(json.text);original=body.sharedMesh;
  var signatures=new HashSet<string>();
  for(int i=0;i<data.headTriangleUVs.Length;i+=3)signatures.Add(Key(data.headTriangleUVs[i],data.headTriangleUVs[i+1],data.headTriangleUVs[i+2]));
  var uv=original.uv;var remaining=new List<int[]>();int removed=0;
  for(int sub=0;sub<original.subMeshCount;sub++){
   var tris=original.GetTriangles(sub);var keep=new List<int>();
   for(int i=0;i<tris.Length;i+=3){if(signatures.Contains(Key(uv[tris[i]],uv[tris[i+1]],uv[tris[i+2]]))){removed++;continue;}keep.Add(tris[i]);keep.Add(tris[i+1]);keep.Add(tris[i+2]);}
   remaining.Add(keep.ToArray());
  }
  if(removed!=data.headTriangleUVs.Length/3){Debug.LogError("[HeroPremium] Head triangle correspondence mismatch: "+removed+" expected "+data.headTriangleUVs.Length/3);original=null;return;}
  // Derive new joints from original bind matrices, not the current animated pose.
  var bones=new List<Transform>(body.bones);var bindposes=new List<Matrix4x4>(original.bindposes);
  var joints=new List<HeroFingerArticulation20260917.Joint>();
  if(data.bones!=null)foreach(var extra in data.bones){
   int parent=bones.FindIndex(b=>b&&Short(b.name)==Short(extra.parent));
   if(parent<0){Debug.LogError("[HeroPremium] Missing finger parent "+extra.parent);original=null;return;}
   var localPosition=bindposes[parent].MultiplyPoint3x4(conversion.MultiplyPoint3x4(extra.position));
   var obj=new GameObject(extra.name);objects.Add(obj);var bone=obj.transform;bone.SetParent(bones[parent],false);bone.localPosition=localPosition;
   var sourceToParent=bindposes[parent]*conversion;
   var axis=sourceToParent.MultiplyVector(extra.axis).normalized*Mathf.Sign(sourceToParent.determinant);
   joints.Add(new HeroFingerArticulation20260917.Joint{bone=bone,bindLocalRotation=bone.localRotation,curlLocalAxis=axis,side=extra.side=="Left"?0:1,digit=Array.IndexOf(new[]{"Thumb","Index","Middle","Ring","Little"},extra.digit),segment=extra.segment});
   bones.Add(bone);bindposes.Add(Matrix4x4.Translate(-localPosition)*bindposes[parent]);
  }
  // Validate every bone before modifying the visible source.
  foreach(var part in data.meshes)foreach(var influence in part.weights)foreach(var w in influence.items)
   if(bones.FindIndex(b=>b&&Short(b.name)==Short(w.bone))<0){Debug.LogError("[HeroPremium] Missing bone "+w.bone);original=null;return;}
  var bodyMesh=Instantiate(original);bodyMesh.name="Hero body with rebuilt head surfaces";
  for(int i=0;i<remaining.Count;i++)bodyMesh.SetTriangles(remaining[i],i);owned.Add(bodyMesh);body.sharedMesh=bodyMesh;
  var normalMatrix=conversion.inverse.transpose;
  foreach(var part in data.meshes){
   var vertices=new Vector3[part.vertices.Length];var normals=new Vector3[vertices.Length];var weights=new BoneWeight[vertices.Length];
   for(int i=0;i<vertices.Length;i++){
    vertices[i]=conversion.MultiplyPoint3x4(part.vertices[i]);normals[i]=normalMatrix.MultiplyVector(part.normals[i]).normalized;
    var ids=new int[4];var values=new float[4];float sum=0;int j=0;
    foreach(var w in part.weights[i].items){if(j==4)break;ids[j]=bones.FindIndex(b=>b&&Short(b.name)==Short(w.bone));values[j]=w.weight;sum+=w.weight;j++;}
    if(sum<=0)throw new InvalidOperationException("Empty premium skin weights");
    weights[i]=new BoneWeight{boneIndex0=ids[0],boneIndex1=ids[1],boneIndex2=ids[2],boneIndex3=ids[3],weight0=values[0]/sum,weight1=values[1]/sum,weight2=values[2]/sum,weight3=values[3]/sum};
   }
   var triangles=(int[])part.triangles.Clone();if(conversion.determinant<0)for(int i=0;i<triangles.Length;i+=3){int swap=triangles[i+1];triangles[i+1]=triangles[i+2];triangles[i+2]=swap;}
   var mesh=new Mesh{name=part.name,indexFormat=vertices.Length>65535?UnityEngine.Rendering.IndexFormat.UInt32:UnityEngine.Rendering.IndexFormat.UInt16};mesh.vertices=vertices;mesh.normals=normals;mesh.uv=part.uv;mesh.triangles=triangles;mesh.boneWeights=weights;mesh.bindposes=bindposes.ToArray();mesh.RecalculateBounds();mesh.RecalculateTangents();owned.Add(mesh);
   if(part.blendShapes!=null)foreach(var shape in part.blendShapes){
    var dv=new Vector3[vertices.Length];var dn=new Vector3[vertices.Length];
    if(shape.deltaVertices==null||shape.deltaVertices.Length!=vertices.Length)throw new InvalidOperationException("Mismatched face shape "+shape.name);
    for(int n=0;n<vertices.Length;n++){
     dv[n]=conversion.MultiplyVector(shape.deltaVertices[n]);
     if(shape.deltaNormals!=null&&shape.deltaNormals.Length==vertices.Length)dn[n]=normalMatrix.MultiplyVector(part.normals[n]+shape.deltaNormals[n]).normalized-normals[n];
    }
    mesh.AddBlendShapeFrame(shape.name,100,dv,dn,null);
   }
   var obj=new GameObject(part.name);obj.transform.SetParent(body.transform,false);objects.Add(obj);var renderer=obj.AddComponent<SkinnedMeshRenderer>();renderer.sharedMesh=mesh;renderer.bones=bones.ToArray();renderer.rootBone=body.rootBone;renderer.localBounds=body.localBounds;renderer.shadowCastingMode=body.shadowCastingMode;renderer.receiveShadows=body.receiveShadows;
   bool hair=part.name.IndexOf("Hair",StringComparison.OrdinalIgnoreCase)>=0;
   if(hair){hairMaterial=new Material(Shader.Find("Standard")){name="Hero sculpted ink hair",color=new Color(.025f,.032f,.048f,1)};hairMaterial.SetFloat("_Glossiness",.3f);renderer.sharedMaterial=hairMaterial;}
   else if(part.materialKind=="eye"){
    var material=new Material(Shader.Find("Standard")){name="Hero eye · "+part.name,color=part.color};material.SetFloat("_Glossiness",part.smoothness);material.SetFloat("_Metallic",0);
    if(!string.IsNullOrEmpty(part.textureResource))material.mainTexture=Resources.Load<Texture2D>(part.textureResource);
    renderer.sharedMaterial=material;eyeMaterials.Add(material);
   }else renderer.sharedMaterial=body.sharedMaterial;
   int blink=mesh.GetBlendShapeIndex("Blink");if(blink>=0){var facial=GetComponent<HeroFacialMotion20260917>()??gameObject.AddComponent<HeroFacialMotion20260917>();facial.Configure(renderer,blink);}
  }
  if(joints.Count>0){var fingers=GetComponent<HeroFingerArticulation20260917>()??gameObject.AddComponent<HeroFingerArticulation20260917>();fingers.Configure(joints);}
  Debug.Log("[HeroPremium] Replaced "+removed+" source triangles; installed "+data.meshes.Length+" skinned face/hair/hand parts; finger joints "+joints.Count);
 }
 void OnDestroy(){if(body&&original)body.sharedMesh=original;foreach(var obj in objects)if(obj)Destroy(obj);foreach(var mesh in owned)if(mesh)Destroy(mesh);if(hairMaterial)Destroy(hairMaterial);foreach(var material in eyeMaterials)if(material)Destroy(material);}
}
