Shader "Mindstone/HeroSpellVolume"
{
Properties{_DeclarationArt("Authored name parchment",2D)="black"{} _InstanceWeight("Target overlap weight",Float)=1 _TimeBeat("Time",Float)=0 _Contact("Contact",Float)=.7 _Kind("Skill",Float)=2 _Center("Spell center",Vector)=(.5,.5,0,0) _SourceUV("Origin",Vector)=(.5,.3,0,0) _Aspect("Aspect",Float)=.6 _Atlas("Tarot art",2D)="black"{} }
SubShader{Tags{"Queue"="Overlay-2" "RenderType"="Transparent"} Cull Off ZWrite Off ZTest Always Blend One OneMinusSrcAlpha
Pass{CGPROGRAM
#pragma vertex vert
#pragma fragment frag
#pragma target 3.0
#include "UnityCG.cginc"
struct A{float4 vertex:POSITION;float2 uv:TEXCOORD0;};struct V{float4 pos:SV_POSITION;float2 uv:TEXCOORD0;};
float _TimeBeat,_Contact,_Kind,_Aspect,_InstanceWeight;float4 _Center,_SourceUV;sampler2D _Atlas,_DeclarationArt;
V vert(A a){V o;o.pos=UnityObjectToClipPos(a.vertex);o.uv=a.uv;return o;}
float hash(float n){return frac(sin(n*127.1)*43758.5453);}
float2 rot(float2 p,float a){float c=cos(a),s=sin(a);return float2(c*p.x-s*p.y,s*p.x+c*p.y);}
float noise(float2 p){float2 g=floor(p),f=frac(p);f=f*f*(3-2*f);float n=g.x+g.y*157;return lerp(lerp(hash(n),hash(n+1),f.x),lerp(hash(n+157),hash(n+158),f.x),f.y);}
float cloud(float2 p){return noise(p)*.55+noise(p*2.1)*.3+noise(p*4.3)*.15;}
float3 art(float2 p,float tile){float2 uv=p+.5;float mask=step(0,uv.x)*step(uv.x,1)*step(0,uv.y)*step(uv.y,1);float2 offset=float2(fmod(tile,4),3-floor(tile/4));return tex2D(_Atlas,(offset+clamp(uv,.006,.994))*.25).rgb*mask;}
// A torn, finite sheet: detailed coloured skin and a narrow luminous edge.
// Called only after authoritative contact. No shared radial ring or white disk.
float ruptureSheet(float2 p,float2 center,float angle,float2 extent,float clock,float seed){
 float2 q=rot(p-center,-angle)/extent;
 float edge=q.y+(noise(float2(q.x*4+seed,clock*5+seed))-.5)*.24;
 float taper=max(.08,saturate(1-abs(q.x)*.68));
 float body=(1-smoothstep(.40*taper,.94*taper,abs(edge)))*(1-smoothstep(.72,1.0,abs(q.x)));
 float ridge=exp(-abs(abs(edge)-.45*taper)*19)*.32;
 return (body*.60+ridge)*(1-smoothstep(.78,1.0,abs(q.x)));
}
float4 frag(V i):SV_Target
{
float t=_TimeBeat,dt=t-_Contact,h=max(dt,0),charge=saturate(t/_Contact);
float release=smoothstep(0,.045,dt),fade=1-smoothstep(.38,.93,h),appear=smoothstep(0,.12,t);
float2 aspect=float2(_Aspect,1),p=(i.uv-_Center.xy)*aspect*.88;
// A finite contact overshoot changes the silhouette, never the whole cast.
// Status spells keep their controlled expansion; destructive sheets open fast.
float attackKind=(_Kind>4.5&&_Kind<8.5)?1:0;
float peak=step(0,dt)*smoothstep(0,.042,h)*exp(-max(0,h-.042)*10);
float2 expansion=float2(1,1);
if(_Kind>4.5&&_Kind<5.5) expansion+=float2(1.10,.32)*peak;
else if(_Kind>5.5&&_Kind<6.5) expansion+=float2(.28,.85)*peak;
else if(_Kind>6.5&&_Kind<7.5) expansion+=float2(1.10,1.25)*peak;
else if(_Kind>7.5&&_Kind<8.5) expansion+=float2(1.20,.50)*peak;
else expansion+=float2(.15,.22)*peak;
p/=expansion;
if(_Kind>9.5)p/=float2(.44,.64);
float r=length(p);
float3 violet=float3(.43,.10,1.25),cyan=float3(.08,.66,1.25),gold=float3(1.35,.51,.075),pink=float3(1.1,.06,.32);
float3 tint=_Kind>8.5&&_Kind<9.5?cyan:_Kind>7.5&&_Kind<8.5?pink:violet;
float3 coreTint=lerp(tint,float3(1.6,1.45,1.8),.62);if((_Kind>4.5&&_Kind<5.5)||(_Kind>6.5&&_Kind<7.5)){tint=lerp(violet,gold,.45);coreTint=float3(1.9,1.2,.32);}
float n=cloud(p*15+float2(-t*1.6,t*2.3)),n2=cloud(rot(p,h*.8)*29-float2(h*4,h*2));
float3 col=0;
// Larger coherent flame folds with fine bright mineral edges inside them.
float ridge=pow(saturate(1-abs(n2-.53)*8),3);
float flame=pow(saturate(n*.7+n2*.55-.34),2.1)*10;
flame*=1+ridge*.24;
float bloom=release*fade;
// The fast opening then decelerating breakup creates an impact distinct from travel.
float breakGate=step(0,dt)*(1-smoothstep(.30,.60,h));
float breakOpen=1-exp(-h*32);
float3 breakColor=lerp(tint,gold,.22);
// Shared turbulence is material detail only. Each complete release below owns
// its silhouette, transport direction and hot-core shape; no common radial burst.
if(_Kind<2.5){
 float rise=h*.23;float y=p.y-rise;
 float wav=sin(y*19-t*7)*.024;
 float wings=exp(-pow((abs(p.x+wav)-(.075+.055*charge))/.065,2))*exp(-abs(y)*5.4);
 float crown=exp(-p.x*p.x*60-pow(y-.16,2)*90);
 float lift=smoothstep(-.17,-.06,y)*(1-smoothstep(.30,.44,y));
 float body=wings+crown*1.3;
 col+=lerp(violet,coreTint,n2)*flame*body*(.40+charge*.75+bloom*1.05)*fade;
 col+=coreTint*exp(-pow((abs(p.x)-.10)/.025,2))*lift*bloom*.72;
 // Four broad ascending soul flares collect into the crown, never fly outward.
 for(int k=0;k<4;k++){float x=(k-1.5)*.065;float yy=-.12+frac(t*.5+hash(k))* .42;float2 d=p-float2(x,yy);col+=lerp(violet,coreTint,hash(k+4))*exp(-abs(d.x)*92-abs(d.y)*33)*charge*fade*.9;}

 // Crown tears into three broad ascending petals, leaving the face visible.
 float crownBurst=0;
 for(int k=0;k<3;k++){float side=k-1;float2 c=float2(side*(.045+breakOpen*.15),.12+breakOpen*(.15+.03*k));crownBurst+=ruptureSheet(p,c,1.57-side*.48,float2(.11,.035),h,k+2);}
 col=col*(1-breakGate*.12)+lerp(violet,gold,.28)*crownBurst*breakGate*1.25;
}else if(_Kind<4.5){
 float crossing=lerp(.23,-.23,charge);float distancePast=h*.34;
 float pathY=sin(p.x*11+t*3)*.024;
 float left=exp(-pow((p.x-crossing+distancePast)/.065,2)-pow((p.y-pathY-.025)/.09,2));
 float right=exp(-pow((p.x+crossing-distancePast)/.065,2)-pow((p.y+pathY+.025)/.09,2));
 float horizontal=exp(-pow(p.y/.075,2))*exp(-pow(p.x/.36,4));
 float fissure=exp(-abs(p.x+sin(p.y*35)*.009)*74)*exp(-pow(p.y/.29,4));
 col+=lerp(violet,cyan,n2)*(left+right)*flame*(1+charge)*fade;
 col+=lerp(pink,coreTint,n)*horizontal*flame*bloom*1.35;
 col+=coreTint*fissure*bloom*1.4;

 // Two opposing identity planes snap apart, not a circular explosion.
 float splitBurst=ruptureSheet(p,float2(-.05-breakOpen*.19,.025),-.15,float2(.15,.052),h,12)
 +ruptureSheet(p,float2(.05+breakOpen*.19,-.025),-.15,float2(.15,.052),h,17);
 col=col*(1-breakGate*.16)+lerp(cyan,pink,n2)*splitBurst*breakGate*1.65;
}else if(_Kind<5.5){
 float drop=.34*(1-pow(charge,3));float2 q=p-float2(0,drop);
 float pillar=exp(-pow(q.x/.10,4))*exp(-abs(q.y)*8);
 float pressure=exp(-pow(p.y/.060,2))*exp(-pow(p.x/(.14+h*.50),4));
 float compression=exp(-pow(p.x/.13,4)-pow(p.y/.066,4));
 col+=gold*pillar*flame*charge*(1-release*.55)*fade*1.7;
 col+=lerp(gold,coreTint,n2)*pressure*flame*bloom*1.60;
 col+=coreTint*compression*bloom*.90;
 // Descending columns of light terminate at a broad horizontal pressure front.
 for(int k=0;k<3;k++){float x=(k-1)*.080;float shaft=exp(-abs(p.x-x)*112)*smoothstep(-.035,0,p.y)*(1-smoothstep(.20,.38,p.y));col+=gold*shaft*charge*fade*.62;}
col*=.92;

 // The seal crushes down and ejects two thick gilded pressure slabs sideways.
 float stampBurst=ruptureSheet(p,float2(-.07-breakOpen*.22,-.025-breakOpen*.03),-.20,float2(.16,.056),h,22)
 +ruptureSheet(p,float2(.07+breakOpen*.22,-.025-breakOpen*.03),.20,float2(.16,.056),h,28);
 col=col*(1-breakGate*.24)+gold*stampBurst*breakGate*1.28;
}else if(_Kind<6.5){
 float2 delta=(_Center.xy-_SourceUV.xy)*aspect;float angle=atan2(delta.y,delta.x);
 float2 q=rot((i.uv-_SourceUV.xy)*aspect,-angle);float lengthToTarget=max(.03,length(delta));
 float head=lengthToTarget*pow(charge,2.4)+h*.62;
 float through=smoothstep(-.12,0,q.x)*(1-smoothstep(head-.01,head+.06,q.x));
 for(int k=0;k<2;k++){
  float side=k==0?-1:1;float lane=side*.07*sin(saturate(q.x/lengthToTarget)*3.14159);
  float wake=exp(-abs(q.y-lane)*58)*through*exp(-max(0,head-q.x)*7);
  float tip=exp(-pow((q.x-head)/.04,2)-pow((q.y-lane)/.034,2));
  col+=lerp(k==0?cyan:violet,coreTint,n2)*wake*flame*(.7+charge)*fade*2.0+coreTint*tip*fade;
 }
 // A piercing front carries energy BEYOND the target along the travel axis.
 col+=cyan*exp(-pow((q.x-lengthToTarget-h*.55)/.07,2)-pow(q.y/.095,2))*flame*bloom*1.5;

 // Twin piercing wakes split beyond the target along the actual attack axis.
 float pursuitBurst=0;
 for(int k=0;k<2;k++){float side=k==0?-1:1;pursuitBurst+=ruptureSheet(q,float2(lengthToTarget+.05+breakOpen*.17,side*(.025+breakOpen*.065)),side*.18,float2(.14,.035),h,33+k);}
 col=col*(1-breakGate*.12)+lerp(cyan,violet,n2)*pursuitBurst*breakGate*1.6;
}else if(_Kind<7.5){
 float2 q=rot(p,-.63);float sweep=.30*(1-charge)-h*.10;
 float slash=exp(-abs(q.y-sweep+sin(q.x*30)*.006)*77)*exp(-pow(q.x/.39,4));
 float fan=smoothstep(-.025,.035,q.y)*(1-smoothstep(.12+h*.31,.21+h*.31,q.y))*exp(-pow(q.x/(.12+max(q.y,0)*1.7),4));
 col+=lerp(gold,coreTint,n2)*slash*smoothstep(.55,.97,charge)*fade*3.3;
 col+=lerp(violet,gold,n)*fan*flame*bloom*1.80;
 // Art fragments follow ONE fan normal to the incision, not a radial tarot nova.
 for(int k=0;k<6;k++){float lane=(k/5.0-.5);float2 c=float2(lane*(.06+h*.58),.025+h*(.18+hash(k)*.28));float size=.055+hash(k+2)*.065;col+=art(rot(q-c,lane+h*3)/size,1+floor(hash(k+4)*3))*bloom*.65;}
col*=.92;

 // Three broad chips peel normal to the giant card incision; hot edge stays clear.
 float verdictBurst=0;
 for(int k=0;k<3;k++){float lane=k-1;verdictBurst+=ruptureSheet(q,float2(lane*(.06+breakOpen*.12),.05+breakOpen*(.12+.035*k)),lane*.25,float2(.105,.050),h,41+k);}
 col=col*(1-breakGate*.23)+lerp(gold,violet,n2*.65)*verdictBurst*breakGate*1.5;
}else if(_Kind<8.5){
 float opening=.03+charge*.13+h*.36;
 float wall=exp(-pow((abs(p.x)-opening)/.060,2))*exp(-pow(p.y/.25,4));
 col+=lerp(pink,violet,n)*wall*flame*(.4+charge)*fade*1.8;
 // The parted curtain releases a wide lateral sheet that sweeps across target.
 float front=-.28+h*.95;float sweep=exp(-pow((p.x-front)/.12,2))*exp(-pow(p.y/.20,4));
 float wake=smoothstep(-.36,-.20,p.x)*(1-smoothstep(front-.02,front+.025,p.x))*exp(-pow(p.y/.18,4));
 col+=lerp(pink,coreTint,n2)*sweep*flame*bloom*2.2;
 col+=violet*wake*flame*bloom*.95;

 // Curtain edges tear into a pair of wide folds, followed by a shorter counterfold.
 float theatreBurst=ruptureSheet(p,float2(-.08-breakOpen*.20,.025),1.35,float2(.18,.055),h,51)
 +ruptureSheet(p,float2(.08+breakOpen*.20,-.025),1.35,float2(.18,.055),h,56);
 col=col*(1-breakGate*.18)+lerp(pink,violet,n2)*theatreBurst*breakGate*1.7;
}else if(_Kind<9.5){
 float angle=atan2(p.y,p.x),contract=max(.18,1-charge*.4-h*1.3);
 float spiral=pow(saturate(sin(angle*3+r*64+t*17)*.5+.5),3);
 float radius=.29*contract;float suction=exp(-pow(r/max(.025,radius),3));
 col+=lerp(cyan,coreTint,n2)*(spiral+.24)*flame*suction*(.65+charge+bloom)*fade*2.0;
 // Individual luminous leaves spiral IN and are consumed by the source book.
 for(int k=0;k<6;k++){float rad=(.09+hash(k)*.19)*contract;float a=k*2.399+t*3;float2 c=float2(cos(a),sin(a))*rad;col+=art(rot(p-c,-a)/(.036+.039*contract),2)*float3(.55,1.1,1.4)*fade*.60;}
 col+=coreTint*exp(-r*r/(.0007+.0015*contract))*bloom*.95;

 // Three illuminated folios crack open, then fold back into the caster's book.
 float rewriteBurst=0;float foldBack=sin(saturate(h/.48)*3.14159);
 for(int k=0;k<3;k++){float side=k-1;rewriteBurst+=ruptureSheet(p,float2(side*(.03+foldBack*.15),.045+foldBack*.08),side*.55,float2(.105,.045),h,61+k);}
 col=col*(1-breakGate*.16)+cyan*rewriteBurst*breakGate*1.5;
}else{
 // H10 declares identities: gilded fragments peel upward from each porcelain
 // portrait. Keep the restored spatial extent, but remove the H08-like pink
 // vortex wash. Each target retains a clear central portrait window.
 float rise=saturate(h/.68),letters=0,outerVeil=0;
 for(int k=0;k<23;k++){
  float seed=hash(k+73),side=k%2==0?-1:1;
  float2 q=p-float2(side*(.075+seed*.18)+(sin(t*2.1+k)*.018),-.18+seed*.32+rise*(.18+seed*.24));
  float slant=q.x+q.y*(.50+seed*.70)+sin(q.y*52+seed*3)*.004;
  float stroke=exp(-pow(slant/(.008+seed*.007),2))*exp(-pow(q.y/(.014+seed*.018),4));
  float tear=.4+.6*noise(q*82+float2(k,-t*2));
  letters+=stroke*tear;
  if(k<5)outerVeil+=ruptureSheet(p,float2(side*(.12+seed*.20),.03+rise*.22),.35+seed*2.1,float2(.19,.045),h,71+k);
 }
 float portraitWindow=1-.91*exp(-pow(p.x/.090,4)-pow(p.y/.15,4));
 float2 writtenUV=float2(.25+p.y*.82+p.x*.24,.40+p.x*.67-p.y*.26-t*.014);
 float4 written=tex2D(_DeclarationArt,saturate(writtenUV));
 float litInk=smoothstep(.28,.87,written.r*.72+written.g*.28);
 col+=(written.rgb*1.35+gold*.36)*letters*(.35+charge)*fade*2.5;
 col+=(written.rgb*.56+violet*.27+gold*litInk*.30)*outerVeil*flame*(.40+charge)*fade*1.28*portraitWindow;

}
// Short local inner glints live along the existing torn material, not a
// screen-filling white flash. Fine texture survives between bright seams.
float micro=pow(saturate(1-abs(noise(p*93+float2(h*8,-h*12))-.5)*17),5);
col += coreTint * micro * saturate(flame*.18) * exp(-r*r*25) * peak * attackKind * .36;
// Keep the restored screen-wide material without bleaching the authored
// porcelain portraits, stamp, hunting shadows or great tarot beneath it.
if(_Kind>3.5&&_Kind<4.5) col*=.38*(1-.82*exp(-r*r*25));
else if(_Kind>4.5&&_Kind<5.5) col*=.28;
else if(_Kind>5.5&&_Kind<6.5) col*=.41;
else if(_Kind>6.5&&_Kind<7.5) col*=.72;
else if(_Kind>7.5&&_Kind<8.5) col*=.67;
if(_Kind>9.5)col*=.42*_InstanceWeight;
// 2026-09-26: pure additive light over the pale marble clipped to white.
// Emit premultiplied colour and partly cover the ground under bright
// material, with a hue-preserving roll-off, so peaks stay vivid.
float3 E=min(col*(1.14+peak*attackKind*.30),2.7)*appear*(1-smoothstep(.70,.95,h));
float m=max(E.r,max(E.g,E.b));
float lum=dot(E,float3(.299,.587,.114));
E=max(0,lerp(lum.xxx,E,1.3));
float mm=max(max(E.r,max(E.g,E.b)),1e-4);
E*=(mm/(1+mm*.55)*1.55)/mm;
return float4(E,saturate(m*.6)*.68);
}
ENDCG}}
Fallback Off
}
