using UnityEngine;

// Presentation geometry only. The existing caller owns contact, targets,
// cancellation and lifetime. Each identity has a different spatial operation.
public sealed class MainlineDistinct20260925 : MonoBehaviour
{
    MainlineSpellMeshRound2 surface;
    Vector3 R,U,F,groundR,groundF;
    float clock,fade,burst,post;bool hit;
    Color brass,hot,ink;
    void Ensure(){if(!surface){surface=GetComponent<MainlineSpellMeshRound2>();if(!surface)surface=gameObject.AddComponent<MainlineSpellMeshRound2>();}}
    static float H(int n)=>Mathf.Repeat(Mathf.Sin(n*37.17f+4.19f)*4371.3f,1);
    Color A(Color c,float a=1){c.a=fade*a;return c;}
    void Curve(Vector3 a,Vector3 b,Vector3 c,Vector3 d,float w,Color color,int seed,Vector3 across=default){
        surface.AuthoredRibbon(a,b,c,d,across.sqrMagnitude>.001f?across:R,w,A(color),seed);
    }
    void Seam(Vector3 a,Vector3 b,Vector3 c,Vector3 d,float w,int seed,Vector3 across=default){Curve(a,b,c,d,w,hot,seed,across);}
    void Begin(float age,Vector3 source,Vector3 target,float motif){
        Ensure();var cam=Camera.main;R=cam?cam.transform.right:Vector3.right;U=cam?cam.transform.up:Vector3.up;
        F=(target-source).normalized;if(F.sqrMagnitude<.01f)F=Vector3.forward;
        groundF=Vector3.ProjectOnPlane(F,Vector3.up).normalized;if(groundF.sqrMagnitude<.01f)groundF=Vector3.forward;
        groundR=Vector3.Cross(Vector3.up,groundF).normalized;
        clock=age;post=Mathf.Max(0,age-1);hit=age>=1;
        // Preserve raw caller time. A local 50ms expansion does not pause or
        // delay the native combat callback at age == 1.
        burst=hit?(1-Mathf.Exp(-post*65))*Mathf.Exp(-post*5.6f):0;
        fade=hit?Mathf.Pow(Mathf.Clamp01(1-post/.50f),1.30f):Mathf.SmoothStep(0,1,Mathf.Clamp01(age/.30f));
        brass=new Color(1,.49f,.075f);hot=new Color(1.65f,1.22f,.52f);ink=new Color(.16f,.055f,.30f);
        surface.Begin(age,hit?Mathf.Exp(-post*12):0,motif);
        float scaleGain=motif==33?1.35f:motif==34?.25f:motif==35?.60f:motif==32?.48f:motif==31?.13f:.28f;
        surface.SetSpatialScale(target,1+burst*scaleGain);
    }
    // Metal chips have actual irregular closed volume and a lit fractured face;
    // they are secondary debris, never the whole spell's repeated ribbon motif.
    void Chip(Vector3 p,Vector3 direction,float size,Color c,int seed){
        Vector3 side=Vector3.Cross(direction,U).normalized;if(side.sqrMagnitude<.01f)side=R;
        Vector3 cross=Vector3.Cross(direction,side).normalized;
        Vector3 tip=p+direction*size,back=p-direction*size*.37f;
        surface.Triangle(tip,p+side*size*.43f,back+cross*size*.30f,A(c));
        surface.Triangle(tip,back+cross*size*.30f,p-side*size*.31f,A(c*.74f));
        surface.Triangle(tip,p-side*size*.31f,p+side*size*.43f,A(Color.Lerp(c,hot,.55f)));
    }
    void Debris(Vector3 target,int count,float spread,Color c,bool low=false){
        if(!hit)return;count*=2;
        for(int i=0;i<count;i++){
            Vector3 d=(R*(H(i+12)-.5f)*2+(low?Vector3.up:U)*(H(i+30)*1.4f-.2f)+F*(H(i+41)-.5f)).normalized;
            Vector3 p=target+d*(.08f+post*(5+H(i+7)*6)*spread)-Vector3.up*post*post*2;
            Chip(p,d,(.035f+H(i+1)*.08f)*(1-post),i%4==0?hot:c,i);
        }
    }
    public void Draw(EnemyAuthoredBurstTier20260919.Motif motif,float age,Vector3 source,Vector3 target,bool alternate){
        Begin(age,source,target,motif==EnemyAuthoredBurstTier20260919.Motif.Scribe?32:30);
        float travel=Mathf.Clamp01((age-.4f)/.6f);Vector3 center=Vector3.Lerp(source,target,travel);
        if(motif==EnemyAuthoredBurstTier20260919.Motif.Executor)Pen(center,target,travel,alternate);
        else if(motif==EnemyAuthoredBurstTier20260919.Motif.Scribe)Ink(center,target,travel);
        else if(motif==EnemyAuthoredBurstTier20260919.Motif.Clock){if(alternate)Ownership(target,travel);else Bell(center,target,travel);}
        else if(motif==EnemyAuthoredBurstTier20260919.Motif.Hammer)Hammer(center,target,travel);
        else if(motif==EnemyAuthoredBurstTier20260919.Motif.Convoy)Convoy(source,target,travel);
        else if(motif==EnemyAuthoredBurstTier20260919.Motif.Bearer)Palm(center,target,travel);
        surface.End();
    }
    void Pen(Vector3 c,Vector3 t,float flight,bool hook){
        if(!hook){
            Vector3 axis=hit?(U+R*.35f).normalized:F;
            float length=hit?1.15f+burst*2.2f:.52f+flight*1.0f;
            Curve(c-axis*length,c-axis*length*.65f+R*.38f,c+axis*.24f-R*.18f,c+axis*.53f,.62f+burst*1.10f,brass,1,hit?R:U);
            Seam(c-axis*length,c-axis*.42f+R*.10f,c+axis*.12f,c+axis*.54f,.042f+burst*.075f,3,hit?R:U);
            if(hit){
                for(int i=0;i<2;i++){float y=(H(i+50)-.45f)*1.40f;Vector3 p=t+axis*y;float sign=i%2==0?-1:1;
                    Curve(p,p+R*sign*.36f+axis*.12f,p+R*sign*(.4f+burst*.8f)+axis*.43f,p+R*sign*(.6f+burst*1.25f)+axis*.48f,.23f+burst*.18f,brass,i+5,U);}
                Debris(t,17,.65f,brass);
            }
        }else{
            // A pressured diagonal brush breaks before a short reverse barb.
            // The broad shoulder, split tip and detached ink keep it from
            // reading as a uniform metal C or an almost-complete ring.
            float close=hit?Mathf.Clamp01(post/.35f):flight;
            float span=1.0f+burst*2.0f;
            Vector3 a=c+R*span*.62f+U*.86f;
            Vector3 heel=c-R*span*.55f-U*.50f;
            Vector3 d=c+R*(.18f-close*.65f)-U*.77f;
            Curve(a,c+R*span*.12f+U*.35f,c-R*span*.10f-U*.25f,heel,.50f+burst*.79f,brass,11,U+F*.7f);
            Seam(a,c+R*span*.12f+U*.29f,c-R*span*.10f-U*.25f,heel,.033f+burst*.045f,12,U);
            // A visible break separates the snap-back from the broad downstroke.
            Vector3 start=heel+R*.15f-U*.12f;
            Curve(start,start+R*span*.40f-U*.27f,d-R*.12f+U*.25f,d,.20f+burst*.22f,brass,15,U+F*.2f);
            Curve(d-R*.12f,d+R*.50f-U*.03f,d+R*.38f+U*.23f,d+R*.20f+U*.38f,.13f+burst*.10f,ink,14,U);
            Curve(heel+R*.02f,heel+U*.04f+F*.23f,heel+R*.43f-U*.21f,heel+R*.73f-U*.12f,.085f+burst*.05f,brass,16,U);
            if(hit)for(int i=0;i<8;i++){Vector3 p=t+R*(H(i+11)-.5f)*1.5f+U*(H(i+7)-.5f)*1.2f;Vector3 d2=(-R+U*.4f).normalized;Chip(p+d2*post*6,d2,.10f+H(i)*.08f,hot,i);}
        }
    }
    void Ink(Vector3 c,Vector3 t,float flight){
        // A broad pressure brush with a wet split tip, then curling ink droplets.
        Color violet=new Color(.66f,.13f,1.15f);hot=new Color(1.13f,.69f,1.7f);
        float reach=.65f+burst*2.3f;
        Curve(c-R*reach-U*.65f,c-R*reach*.45f+U*(1.0f+burst*.65f),c+R*reach*.7f-U*.8f,c+R*reach+U*.3f,.38f+burst*.40f,violet,20,U+F*.30f);
        Seam(c-R*reach*.83f-U*.34f,c-R*.4f+U*.9f,c+R*.55f-U*.54f,c+R*reach+U*.3f,.07f+burst*.12f,22,U);
        for(int i=0;i<(hit?13:4);i++){float h=H(i+71);Vector3 d=(R*(h-.45f)*2+U*(H(i+30)-.3f)*1.5f).normalized;
            Vector3 p=hit?t+d*(.20f+post*(4+h*7)):c-F*(.3f+h*.8f)+U*Mathf.Sin(flight*6+i)*.15f;
            Curve(p-d*.21f,p+U*.3f+R*.13f,p+d*.17f-U*.16f,p+d*.26f,.08f+h*.10f,i%3==0?hot:violet,i+30,R+U*.3f);}
    }
    void Bell(Vector3 c,Vector3 t,float flight){
        // Three uneven open bronze wall sectors move like a broken bell mouth.
        // Contact turns them outwards and releases a downward pressure rupture.
        float radius=.42f+burst*1.90f,height=.80f+burst*2.05f;
        for(int i=0;i<3;i++){
            float a=i==0?-2.80f:i==1?-.58f:1.58f,span=i==0?1.74f:i==1?1.49f:1.38f;
            int section=i;
            surface.Patch((u,v)=>{
                float theta=a+u*span,rag=.90f+.11f*Mathf.Sin(u*7+section*2)+.06f*Mathf.Sin(u*21-section);
                float wall=(1-v*.68f)*radius*rag;
                float lip=.16f*Mathf.Sin(u*12+section)*Mathf.Pow(1-v,3);
                Vector3 center=c-F*(.22f+burst*.35f)+U*(-.55f+v*height);
                return center+R*Mathf.Cos(theta)*wall+F*Mathf.Sin(theta)*wall*.74f+U*(lip+Mathf.Sin(u*5+section)*.12f);
            },A(i==1?new Color(.65f,.23f,.035f):brass),i+40);
        }
        if(hit){
            float w=1.0f+burst*2.5f;
            Curve(t-R*w-U*.7f,t-R*w*.55f+U*.4f,t+R*w*.65f+U*.6f,t+R*w-U*.9f,.32f+burst*.45f,hot,48,U);
            Debris(t,25,1.1f,brass);
        }
    }
    void Ownership(Vector3 t,float flight){
        // Torn contracts close from separate heights; at contact their gilt
        // handwriting is ripped upward, not the bell's expanding pressure.
        float seal=hit?1-Mathf.Clamp01(post/.48f):flight;
        for(int i=0;i<3;i++){
            float h=H(i+51),side=i==1?-1:1;
            Vector3 c=t+R*(i==0?-.52f:i==1?.53f:.07f)*(1+(1-seal)*.42f)+U*(i==0?.22f:i==1?-.36f:.70f)+F*(i==0?-.40f:i==1?.29f:.62f);
            if(hit)c+=U*post*(1.6f+h*2.1f)+R*side*post*.7f;
            Vector3 along=(U*(i==2?.45f:1)+R*(i==0?-.61f:i==1?.50f:1.2f)).normalized;
            Vector3 across=Vector3.Cross(F,along).normalized;
            float extent=1.08f+burst*.72f;
            Curve(c-along*extent*.78f,c-along*.29f+across*side*.72f+F*.28f,c+along*.46f-across*side*.48f-F*.32f,c+along*extent,.62f+burst*.64f,i==0?brass:new Color(.73f,.29f,.055f),i+51,across);
            // Broken letter strokes follow each fold's own tangent; the
            // disconnected short marks cannot form a straight binding cage.
            for(int j=0;j<3;j++){Vector3 q=c+along*(j-1)*.30f;
                Seam(q-across*.10f,q+along*.05f+across*.09f,q+along*.15f-across*.14f,q+along*.20f,.030f+burst*.025f,i*3+j+61,across);}
        }
        if(hit)Debris(t,15,.75f,hot);
    }
    void Hammer(Vector3 c,Vector3 t,float flight){
        Vector3 floor=t;floor.y=.07f;
        if(!hit){
            Vector3 fall=Vector3.Lerp(t+U*2.65f,t,flight*flight);
            Curve(fall+U*.9f-R*.13f,fall+U*.55f+R*.22f,fall+U*.12f-R*.08f,fall-U*.24f,.25f,brass,70,R);return;
        }
        for(int i=0;i<5;i++){
            float h=H(i+80),a=h*6.28f;Vector3 d=groundR*Mathf.Cos(a)+groundF*Mathf.Sin(a);
            Vector3 across=Vector3.Cross(Vector3.up,d);
            float reach=.6f+burst*(2.3f+h*1.4f);Vector3 p=floor+d*.12f;
            surface.Patch((u,v)=>{
                float width=(.25f+burst*.82f)*Mathf.Sin(u*Mathf.PI)*(1+.22f*Mathf.Sin(u*17+i));
                float ridge=(1-Mathf.Abs(v-.5f)*2)*(.18f+burst*(.65f+h*.40f))*Mathf.Sin(u*Mathf.PI);
                return p+d*u*reach+across*((v-.5f)*2*width+Mathf.Sin(u*12+i)*.12f)+Vector3.up*ridge;
            },A(i==0?hot:brass),i+71);
            Chip(floor+d*(.25f+post*(3+h*6))+Vector3.up*(.12f+burst*(.6f+h)),(d+Vector3.up*(1.2f+h)).normalized,.28f+h*.23f,brass,i+83);
        }
        Debris(floor,19,1,brass,true);
    }
    void Convoy(Vector3 source,Vector3 t,float flight){
        Vector3 floor=t;floor.y=.09f;
        Vector3 c=hit?floor+groundF*post*2:Vector3.Lerp(new Vector3(source.x,.1f,source.z),floor,flight);
        // A low rolling compression front, weighted plates tilting forward;
        // unlike the hammer there is no rising radial pillar or airborne fall.
        float wide=.75f+burst*2.3f;
        surface.Patch((u,v)=>{
            float rag=.85f+.10f*Mathf.Sin(u*9)+.07f*Mathf.Sin(u*23);
            float taper=Mathf.Pow(Mathf.Max(0,Mathf.Sin(u*Mathf.PI)),.55f);
            float angle=v*2.2f+.2f*Mathf.Sin(u*7);
            float roll=(.32f+burst*1.45f)*taper*rag;
            return c+groundR*(u-.5f)*wide*2+groundF*(Mathf.Sin(angle)*roll)+Vector3.up*(.02f+(1-Mathf.Cos(angle))*roll);
        },A(brass),90);
        // Two separate sheared plate corners lead the rolling front at unequal
        // heights; there is no repeated three-arc stencil.
        Curve(c-groundR*wide*.85f+groundF*.18f,c-groundR*wide*.64f+Vector3.up*.41f,c-groundR*wide*.22f+Vector3.up*.55f,c-groundR*wide*.08f+groundF*.24f,.20f+burst*.3f,hot,94,groundF+Vector3.up*.5f);
        if(hit)for(int i=0;i<11;i++){Vector3 p=floor+groundR*(H(i+70)-.5f)*(1+post*7)+groundF*post*(5+H(i)*5)+Vector3.up*(.07f+Mathf.Sin(post*6)*.25f);Chip(p,(groundF+groundR*(H(i+5)-.5f)).normalized,.15f+H(i+8)*.16f,brass,i);}
    }
    void Palm(Vector3 c,Vector3 t,float flight){
        float spread=.65f+burst*1.6f;
        // The palm heel presses a curved concave membrane; unequal fingertips
        // gather inward rather than resembling the weapon's pointed flights.
        surface.Patch((u,v)=>{
            float x=(u-.5f)*2,z=(v-.5f)*2,taper=Mathf.Sqrt(Mathf.Clamp01(1-x*x));
            return c+R*x*spread+U*z*taper*spread*.68f+F*(.22f*(x*x+z*z)-.25f)*spread;
        },A(new Color(1,.55f,.16f),.84f),103);
        for(int i=0;i<4;i++){
            float x=(i-1.4f)*.34f*spread;Vector3 p=c+R*x;
            float bend=i==0?-.4f:i==1?-.08f:i==2?.19f:.48f;
            Curve(p-U*.1f,p+U*.3f-F*.24f+R*bend,p+U*(.68f+H(i)*.45f)*spread+F*.1f+R*bend,p+U*(.47f+H(i)*.35f)*spread+R*(bend+.12f),.14f+burst*.15f,brass,i+105,R+F*.35f);
        }
        if(hit){
            for(int i=0;i<3;i++){
                Vector3 d=(R*(i==0?-1:i==1?.8f:.25f)+U*(i==0?.27f:i==1?-.6f:1)).normalized;
                Vector3 cross=Vector3.Cross(F,d).normalized;
                Curve(t+d*.23f,t+d*(.8f+burst)+cross*.30f,t+d*(1.25f+burst*.9f)-cross*.23f,t+d*(1.40f+burst*1.45f),.23f+burst*.31f,brass,i+115,cross);
            }
            Debris(t,17,.85f,brass);
        }
    }
    public void Ghost(bool wisp,float time,Vector3 source,Vector3 target){
        float mapped=time<.9f?time/.9f:1+(time-.9f)/.66f*.50f;Begin(mapped,source,target,wisp?33:31);
        float travel=Mathf.Clamp01((time-.18f)/.72f);Vector3 c=Vector3.Lerp(source,target,travel);
        if(wisp){
            Color violet=new Color(.70f,.17f,1.2f);hot=new Color(1.4f,.63f,1.65f);
            // One pursuing hooked soul and two unequal stragglers, with their
            // tails following from different depths rather than mirrored jaws.
            float reach=hit?1.2f+burst*2.7f:1.7f;
            Vector3 tail=c-F*reach-R*.45f-U*.36f;
            Vector3 head=c+R*(.15f+burst*.70f)+U*.35f;
            Curve(tail,c-F*reach*.46f-R*(.62f+burst*.65f)+U*.43f,c+R*(.45f+burst*.6f)+U*(.96f+burst*.4f),head,.20f+burst*.22f,violet,130,U+F*.5f);
            Seam(tail,c-F*reach*.46f-R*(.62f+burst*.65f)+U*.43f,c+R*(.45f+burst*.6f)+U*(.96f+burst*.4f),head,.033f+burst*.04f,133,U+F*.5f);
            for(int i=0;i<2;i++){
                Vector3 q=c+R*(i==0?.6f:-.33f)+U*(i==0?-.52f:1.03f)+F*(i==0?.4f:-.55f);
                Vector3 turn=(R*(i==0?1:-.35f)+U*(i==0?.25f:.8f)).normalized;
                Curve(q-F*.8f-turn*.25f,q-F*.32f+turn*.28f,q+turn*(.45f+burst*.5f)+U*.18f,q+turn*.18f,.075f+burst*.1f,violet,i+136,U+R*.3f);
            }
        }else{
            // A single billowing fog diaphragm is pushed across the target.
            // Its rippled lobe and detached curling lip do not form parallel bars.
            Color cyan=new Color(.10f,.80f,1.25f);hot=new Color(.76f,1.5f,1.65f);
            float span=.72f+burst*2.45f;
            surface.Patch((u,v)=>{
                float lobe=Mathf.Pow(Mathf.Max(0,Mathf.Sin(u*Mathf.PI)),.55f);
                float fold=Mathf.Sin(u*5.4f-.7f)*(.22f+v*.26f);
                return c+R*(u-.5f)*span*2+U*((v-.5f)*lobe*(.85f+.3f*Mathf.Sin(u*7))*span+fold)+F*(Mathf.Sin(v*Mathf.PI)*lobe*.55f+Mathf.Sin(u*7+time*2)*.19f);
            },A(cyan,.90f),140);
            Curve(c-R*span*.92f-U*.25f,c-R*span*.70f-U*.95f,c+R*span*.25f-U*.65f,c+R*span*.45f-U*.27f,.14f+burst*.13f,cyan,142,U+F*.6f);
            Curve(c+R*span*.24f+U*.24f,c+R*span*.68f+U*.84f,c+R*span*.95f+U*.6f,c+R*span*.76f+U*.04f,.11f+burst*.12f,hot,143,U+F*.4f);
        }
        if(hit)Debris(target,12,.75f,wisp?new Color(.93f,.45f,1.5f):new Color(.53f,1.1f,1.4f));surface.End();
    }
    public void Memory(Vector3 center,float age,bool contact){
        Begin(contact?1+age*.50f/.65f:age,center+Vector3.forward,center,34);
        if(!contact){fade=Mathf.SmoothStep(0,1,Mathf.Clamp01(age/.08f))*(1-Mathf.SmoothStep(0,1,Mathf.Clamp01((age-.35f)/.09f)));burst=0;}hot=new Color(.50f,.56f,.86f);
        // Distinct torn folios tumble on different depth planes; at contact the
        // pages peel apart and their ink runs upward. They are not fog lips.
        for(int i=0;i<(contact?5:3);i++){
            float h=H(i+170),a=clock*(1.2f+h)+i*1.8f;
            Vector3 q=center+R*(h-.5f)*(contact?1+burst*3:.65f)+U*(H(i+150)-.5f)*(contact?1+burst*2:.45f)+F*(h-.5f)*.8f;
            float length=contact?.65f+burst*.75f:.40f;
            Vector3 direction=(U*Mathf.Cos(a)+R*Mathf.Sin(a)).normalized;
            Vector3 across=Vector3.Cross(F,direction).normalized;
            if(across.sqrMagnitude<.1f)across=R;
            float width=(contact?.38f+burst*.32f:.23f)*(1+h*.5f);
            surface.Patch((u,v)=>{
                float taper=(.53f+.35f*Mathf.Sin(u*Mathf.PI))*(1+.13f*Mathf.Sin(u*12.3f+i*2)+.08f*Mathf.Sin(u*27.1f-i));
                float torn=.10f*Mathf.Sin(u*17+i*3)*(v-.5f);
                float rag=.07f*Mathf.Sin(v*18.7f+i)+.035f*Mathf.Sin(v*37.3f-i);
                float curl=Mathf.Sin(u*4.8f+a*.7f+i)*.15f+Mathf.Sin(v*4.6f+u*3.3f+i)*.12f;
                return q+direction*((u-.5f)*length*2+rag)+across*((v-.5f)*2+torn)*width*taper+F*curl;
            },A(i%3==0?new Color(.76f,.84f,1.02f):new Color(.65f,.77f,.95f)),i+150);
            // A short ink fragment follows each folio, not a long bright spine.
            Seam(q-direction*.17f,q+across*.09f-F*.08f,q+direction*.11f-across*.05f,q+direction*.22f,.023f,i+159,across);
        }
        surface.End();
    }
    public void Devour(float age,Vector3 source,Vector3 target){
        Begin(age,source,target,35);Color acid=new Color(.45f,1.15f,.12f);hot=new Color(1.25f,1.5f,.45f);
        float travel=Mathf.Clamp01((age-.4f)/.6f);
        // At launch ligaments reach towards the victim; torn name fragments
        // flow in the reverse direction. The ordinary probe stays a lobed glob.
        // The dominant asymmetrical siphon folds inward, broad at the victim
        // and narrow towards the leech; no parallel ligaments or closed loop.
        Vector3 end=Vector3.Lerp(source,target,travel);
        float pull=hit?post*1.8f:0;
        Curve(source-R*.18f,Vector3.Lerp(source,end,.35f)+R*.65f+U*.48f,Vector3.Lerp(source,end,.78f)-R*.25f-U*.31f,end+U*.10f,.46f+burst*.86f,acid,180,R+U*.4f);
        if(hit){
            Vector3 q=target-F*pull;
            Curve(q-R*(.8f+burst*.9f)-U*.35f,q-R*.44f+U*(1.2f+burst),q+R*(.56f+burst*.4f)+U*.85f,q+R*.21f-U*.13f,.50f+burst*.78f,acid,183,R+F*.4f);
        }
        for(int i=0;i<9;i++){
            if(age<.65f)continue;
            float q=Mathf.Repeat(H(i+190)+age*.95f,1);Vector3 p=Vector3.Lerp(target,source,q)+U*Mathf.Sin(q*3.14f)*.45f+R*(H(i)-.5f)*.85f;
            Curve(p-U*.12f,p+R*.16f+F*.1f,p+U*.11f-R*.10f,p+U*.24f,.08f+burst*.055f,i%3==0?hot:acid,i+190,R);
        }
        surface.End();
    }
}
