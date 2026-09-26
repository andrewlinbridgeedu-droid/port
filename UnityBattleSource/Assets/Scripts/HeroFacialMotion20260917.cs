using System.Collections.Generic;
using UnityEngine;

// Eyelid vertices belong to the continuous face surface. No texture swapping.
[DefaultExecutionOrder(2210)]
public sealed class HeroFacialMotion20260917 : MonoBehaviour
{
    readonly List<SkinnedMeshRenderer> faces=new List<SkinnedMeshRenderer>();
    readonly List<int> shapes=new List<int>();
    float nextBlink,started=-1;
    public int CompletedBlinks { get; private set; }
    public float CurrentWeight { get; private set; }
    public int ShapeCount => faces.Count;
    public void Configure(SkinnedMeshRenderer face,int shape)
    {
        if(!face||shape<0)return;
        faces.Add(face);shapes.Add(shape);nextBlink=Time.time+1.3f;
    }
    void LateUpdate()
    {
        bool visible=false;foreach(var face in faces)if(face&&face.enabled&&face.gameObject.activeInHierarchy)visible=true;
        if(!visible){ResetBlink();return;}
        if(started<0&&Time.time>=nextBlink)started=Time.time;
        if(started<0)return;
        float age=Time.time-started;
        float amount=age<.09f?Mathf.SmoothStep(0,1,age/.09f):age<.15f?1:1-Mathf.SmoothStep(0,1,(age-.15f)/.15f);
        Apply(amount*100);
        if(age>=.30f){CompletedBlinks++;started=-1;nextBlink=Time.time+3.1f+(CompletedBlinks%3)*.47f;Apply(0);}
    }
    void Apply(float weight){CurrentWeight=weight;for(int n=0;n<faces.Count;n++)if(faces[n])faces[n].SetBlendShapeWeight(shapes[n],weight);}
    void ResetBlink(){started=-1;nextBlink=Time.time+1.3f;Apply(0);}
    void OnEnable(){nextBlink=Time.time+1.3f;}
    void OnDisable(){ResetBlink();}
    void OnDestroy(){Apply(0);}
}
