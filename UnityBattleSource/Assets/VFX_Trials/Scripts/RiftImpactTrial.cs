using UnityEngine;
using System.Collections.Generic;
public sealed class RiftImpactTrial:MonoBehaviour{
 readonly List<Transform> nodes=new List<Transform>();readonly List<Material> mats=new List<Material>();readonly List<Mesh> meshes=new List<Mesh>();
 public void Build(Vector3[] targets){for(int k=0;k<targets.Length;k++)for(int i=0;i<10;i++){
 var g=new GameObject("Contact flame "+k+" "+i);g.transform.SetParent(transform,false);var m=new Mesh();m.vertices=new[]{new Vector3(-.5f,-.5f,0),new Vector3(.5f,-.5f,0),new Vector3(.5f,.5f,0),new Vector3(-.5f,.5f,0)};m.uv=new[]{Vector2.zero,Vector2.right,Vector2.one,Vector2.up};m.triangles=new[]{0,1,2,0,2,3};m.RecalculateBounds();meshes.Add(m);g.AddComponent<MeshFilter>().sharedMesh=m;var mat=new Material(Shader.Find("Mistport/RiftImpact"));mat.SetFloat("_Seed",i*1.71f+k);mats.Add(mat);g.AddComponent<MeshRenderer>().sharedMaterial=mat;g.transform.position=targets[k]+Vector3.up*1.05f+Vector3.back*.5f;nodes.Add(g.transform);
 }centers=new Vector3[nodes.Count];for(int n=0;n<nodes.Count;n++)centers[n]=nodes[n].localPosition;Sample(0);}
 public void Sample(float t){for(int n=0;n<nodes.Count;n++){int i=n%10;float age=t-.84f;var tr=nodes[n];tr.gameObject.SetActive(age>=0&&age<.32f);if(age<0||age>=.32f)continue;mats[n].SetFloat("_Age",age);float a=i*2.39996f;float size=i==0?Mathf.Lerp(.2f,2.6f,Mathf.Clamp01(age/.055f)):Mathf.Lerp(.8f,.18f,Mathf.Clamp01(age/.32f));tr.localScale=i==0?Vector3.one*size:new Vector3(size*2.8f,size*.36f,1);tr.localRotation=Quaternion.Euler(0,0,a*Mathf.Rad2Deg); if(i>0){tr.localPosition=centers[n]+new Vector3(Mathf.Cos(a),Mathf.Sin(a)*.7f+.3f,0)*age*(3+i*.35f);} }}
 Vector3[] centers;
 void OnDestroy(){foreach(var m in mats)Destroy(m);foreach(var m in meshes)Destroy(m);}
}
