using UnityEngine;

public sealed partial class EnemySignatureSpellVFX
{
    // Authored fire and smoke textures supply the silhouettes. No rings, sigils,
    // regular polygons, paths drawn as lines, or patterned particle lattices.
    void Vapor(Vector3 c,float size,Color color,float opacity,int seed,float drift)
    {
        Billboard(smoke,c,size,size*(.82f+Noise(seed+3)*.4f),Noise(seed)*6+drift,Fade(color,opacity),seed%4);
    }
    void FlameTongue(Vector3 c,float size,Color color,float opacity,int seed,float motion)
    {
        flames.material.SetFloat("_DstBlend",(float)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
        float turn=(Noise(seed+9)-.5f)*1.4f+Mathf.Sin(motion*4+seed)*.2f;
        size *= 1.42f;
        opacity=Mathf.Min(.95f,opacity*1.65f);
        Billboard(flames,c,size*(.65f+Noise(seed)*.35f),size*(1.3f+Noise(seed+7)*.5f),turn,Fade(color,opacity));
    }
    void OrganicImpact(Vector3 t,float p,Color color,Color dark,bool metal)
    {
        float fade=Mathf.Pow(1-p,1.6f);
        // Offset lopsided lobes instead of an expanding circular outline.
        for(int i=0;i<10;i++) {
            Vector3 d=cameraRight*(Noise(i*3+2)-.5f)*2+cameraUp*(Noise(i*3+7)-.3f)*1.4f+forward*(Noise(i*3+9)-.5f);
            Vector3 c=t+d*(.25f+Mathf.Sqrt(p)*2.8f)+Vector3.up*p*.3f;
            Vapor(c,.95f+p*.95f,dark,fade*.32f,i,p*.3f);
            if(i%2==0) FlameTongue(c,.35f+(1-p)*.35f,color,fade*.40f,i,p);
            if(metal && i%2==1) MetalSplinter(c,d,.055f+.06f*Noise(i),fade,i);
        }
        Radiance(t,.85f+p*1.05f,color,fade*.38f);
    }
    void OrganicHound(int variant,int phase,float p,Vector3 s,Vector3 t)
    {
        // Parent to the existing spell root: cancellation immediately disables
        // it, and the child's OnDestroy owns its material and bounds mesh.
        var volume=root.GetComponent<HoundVolumetricInferno>();
        if(!volume)volume=root.AddComponent<HoundVolumetricInferno>();
        volume.Draw(variant,phase,p,s,t);
    }
    void MetalSplinter(Vector3 c,Vector3 axis,float size,float fade,int seed)
    {
        Vector3 d=axis.sqrMagnitude>.001f?axis.normalized:cameraUp;
        Vector3 x=Vector3.Cross(d,view).normalized*size;
        Vector3 y=d*size*(1.5f+Noise(seed)*2);
        // Irregular filled, shaded facets are physical fragments, never wireframe polygons.
        ink.Quad(c-y-x,c+y*.7f-x*.3f,c+y+x*.6f,c-y*.5f+x,new Color(.11f,.19f,.25f,fade));
        ink.Quad(c-y-x,c+y*.7f-x*.3f,c+y*.55f,c-y*.8f,new Color(.51f,.63f,.67f,fade));
    }
    void OrganicMachine(int variant,int phase,float p,Vector3 s,Vector3 t,Vector3 arm)
    {
        var mechanical=root.GetComponent<ArchivistMechanicalSpell>();
        if(!mechanical)mechanical=root.AddComponent<ArchivistMechanicalSpell>();
        mechanical.Draw(variant,phase,p,s,t,arm);
        bool fist=(variant&1)==0;
        Vector3 center=phase==0?s:phase==1?(fist?arm:Vector3.Lerp(s,t,p)):t;
        Color ice=new Color(.24f,.65f,1),white=new Color(.72f,.9f,1);
        float fade=phase==2?Mathf.Pow(1-p,1.8f):Mathf.SmoothStep(0,1,p*3);
        // Keep a small illuminated core so the real arm and enamel faces read.
        Radiance(center,phase==2?.45f+p*.65f:.26f,ice,fade*.66f);
        if(phase<2){
            int lanes=phase==0?2:fist?2:3;
            for(int lane=0;lane<lanes;lane++){
                float h=Noise(lane+33),k=Noise(lane+71);
                Vector3 offset=right*(h-.46f)*(fist?.75f:2.1f)+up*(k-.4f)*(fist?.5f:1.2f);
                const int count=36;
                for(int j=0;j<count;j++){
                    float u=j/(float)(count-1);
                    if(phase==0)curve[j]=s+offset*(1-u)*(1-p*.6f)+up*Mathf.Sin(u*Mathf.PI)*(.25f+h*.3f)-forward*(1-u)*.5f;
                    else curve[j]=center+offset*(1-u*.8f)-forward*(1-u)*(fist?2.4f:1.3f)+right*Mathf.Sin(u*4.7f+lane*.8f-p*2)*.22f*(1-u)+up*Mathf.Sin(u*Mathf.PI)*.20f;
                }
                Stroke(ink,count,fist?.14f:.09f,Fade(new Color(.025f,.10f,.26f),fade*.7f),true);
                Stroke(glow,count,.042f,Fade(ice,fade*.40f),true);
            }
        }else{
            for(int lane=0;lane<(fist?3:4);lane++){
                float a=Noise(lane+53)*6.283f,h=Noise(lane+17);
                Vector3 axis=right*Mathf.Cos(a)+up*Mathf.Sin(a),bend=Vector3.Cross(forward,axis);
                for(int j=0;j<32;j++){
                    float u=j/31f,reach=.3f+Mathf.Sqrt(p)*(1.7f+h*1.4f);
                    curve[j]=t+axis*(.08f+u*reach)+bend*Mathf.Sin(u*4+lane)*u*.27f+forward*u*(h-.4f)*.65f;
                }
                Stroke(ink,32,.16f,Fade(new Color(.035f,.12f,.24f),fade*.65f),true);
                Stroke(glow,32,.046f,Fade(ice,fade*.42f),true);
                Vector3 c=t+axis*(.23f+Mathf.Sqrt(p)*(1.3f+h*1.3f))-Vector3.up*p*p*.6f;
                MetalSplinter(c,axis,.11f+h*.10f,fade,lane);
            }
        }
    }
}
