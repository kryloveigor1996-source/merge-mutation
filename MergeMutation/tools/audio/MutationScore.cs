// Original offline composition and synthesis for Merge Mutation. No samples or model weights.
using System;
using System.IO;
using System.Collections.Generic;
using System.Text;
public static class MutationScore {
 const int Rate=44100;
 class Note { public double Beat,Length,Gain,Pan; public int Pitch,Voice; public Note(double b,double l,int p,int v,double g,double pan){Beat=b;Length=l;Pitch=p;Voice=v;Gain=g;Pan=pan;} }
 static List<Note> notes;
 static Random random;
 static double bpm,totalBeats;
 static int frames,theme;
 static float[] left,right;
 static double Hz(int pitch){return 440*Math.Pow(2,(pitch-69)/12.0);}
 static double S(double x){return Math.Sin(x*2*Math.PI);}
 static int Mod(int x,int n){int r=x%n;return r<0?r+n:r;}
 static void Add(double beat,double length,int pitch,int voice,double gain,double pan=0){
  if(beat<0 || beat>=totalBeats) return;
  notes.Add(new Note(beat,length,pitch,voice,gain,pan));
 }
 static void Render(Note note){
  double seconds=note.Length*60/bpm;
  double release=note.Voice==0?0.8:note.Voice==1?0.18:0.4;
  int count=(int)((seconds+release)*Rate);
  int start=(int)(note.Beat*60/bpm*Rate);
  double f=Hz(note.Pitch),phase=0,noise=0;
  double lp=Math.Sqrt((1-note.Pan)*0.5),rp=Math.Sqrt((1+note.Pan)*0.5);
  for(int i=0;i<count;i++){
   double t=i/(double)Rate,gate=t<seconds?1:Math.Exp(-(t-seconds)*9/release);
   double sample=0,env=1;
   switch(note.Voice){
    case 0: // Slow stereo pad: detuned, filtered harmonic stack.
     env=(1-Math.Exp(-t*5))*gate;
     sample=(S(f*t*.998)+S(f*t*1.002)+.26*S(2*f*t)+.10*S(3*f*t))*.35;
     break;
    case 1: // Rounded harmonically rich bass.
     env=(1-Math.Exp(-t*80))*Math.Exp(-t*.65)*gate;
     sample=.65*S(f*t)+.22*S(2*f*t)+.10*S(3*f*t)+.03*S(5*f*t);
     break;
    case 2: // FM felt piano / struck glass, with independently decaying partials.
     env=(1-Math.Exp(-t*220))*Math.Exp(-t*2.1)*gate;
     sample=.65*S(f*t+0.35*Math.Exp(-t*4)*S(f*t*2))+.22*S(f*t*2.003)*Math.Exp(-t*1.7)+.13*S(f*t*4.01)*Math.Exp(-t*4);
     break;
    case 3: // Liquid marimba, pitch scoop and vibrato.
     phase+=f*(1-.05*Math.Exp(-t*22)+.004*S(t*4))/Rate;
     env=(1-Math.Exp(-t*250))*Math.Exp(-t*3.7)*gate;
     sample=S(phase+.5*Math.Exp(-t*8)*S(phase*3))*.75+.2*S(phase*4.01)*Math.Exp(-t*9);
     break;
    case 4: // Plucked/reedy counterline.
     env=(1-Math.Exp(-t*120))*Math.Exp(-t*2.7)*gate;
     sample=.65*S(f*t)+.25*S(f*t*3)+.10*S(f*t*5)*Math.Exp(-t*4);
     break;
    case 5: // Synthesized low drum with falling pitch.
     phase+=(44+75*Math.Exp(-t*24))/Rate;
     env=Math.Exp(-t*12);
     sample=.82*S(phase)+.18*(random.NextDouble()*2-1)*Math.Exp(-t*80);
     break;
    case 6: // Wood/rim/percussion resonator.
     noise=.45*noise+.55*(random.NextDouble()*2-1);
     env=Math.Exp(-t*22);
     sample=.45*noise+.35*S(310*t)*Math.Exp(-t*20)+.2*S(611*t)*Math.Exp(-t*35);
     break;
    case 7: // Closed shaker: differentiated noise, not a sampled cymbal.
     double next=random.NextDouble()*2-1;
     sample=next-noise;noise=next;env=Math.Exp(-t*65)*.5;
     break;
    case 8: // Bubble/sonar gesture.
     phase+=(f*(.55+.9*Math.Exp(-t*5)))/Rate;
     env=(1-Math.Exp(-t*90))*Math.Exp(-t*4)*gate;
     sample=S(phase+S(phase*.5)*.6);
     break;
   }
   int index=Mod(start+i,frames);
   double value=sample*env*note.Gain;
   left[index]+=(float)(value*lp);right[index]+=(float)(value*rp);
  }
 }
 static void Space(){
  float[] dryL=(float[])left.Clone(),dryR=(float[])right.Clone();
  double beat=60/bpm;
  int[] delays={(int)(Rate*.029),(int)(Rate*.071),(int)(Rate*beat*.75),(int)(Rate*beat*1.5)};
  double[] gains={.08,.07,.12,.055};
  for(int i=0;i<frames;i++){
   for(int j=0;j<delays.Length;j++){
    int k=Mod(i-delays[j],frames);
    left[i]+=(float)(dryR[k]*gains[j]);right[i]+=(float)(dryL[k]*gains[j]*.94);
   }
  }
 }
 public static Dictionary<string,object> Compose(string id,string wavPath,string midiPath,int seconds,int tempo,int seed){
  theme=seed;random=new Random(21700+seed);bpm=tempo>0?tempo:96;
  frames=seconds*Rate;totalBeats=seconds*bpm/60.0;
  left=new float[frames];right=new float[frames];notes=new List<Note>();
  int[] roots={38,46,43,45,38,41,43,45};
  int[] motif={0,3,7,14,5,10};
  double[] rhythm={0,1,1.75,2.5,4,5.5};
  bool jingle=id.EndsWith("jingle");
  if(jingle){
   int[] pitches=id=="victory_jingle"?new int[]{62,65,69,74,77,81}:new int[]{62,63,69,76,74,86};
   for(int i=0;i<pitches.Length;i++) Add(i*.48,.85,pitches[i],2,.27,(i%2==0?-.25:.25));
   foreach(int p in new int[]{50,57,62,65,69})Add(0,seconds*bpm/60.0-.2,p,0,.10);
   Add(.1,.8,38,5,.15);
  }else{
   for(double b=0;b<totalBeats;b+=4){
    int bar=(int)(b/4),section=(int)(b/totalBeats*4);
    int root=roots[(bar/2+(section==2?2:0))%roots.Length];
    int third=(root==45?4:3);
    double padGain=theme==1?.075:.045;
    foreach(int interval in new int[]{12,12+third,19,22}) Add(b,Math.Min(3.8,totalBeats-b),root+interval,0,padGain,(interval%2==0?-.52:.52));
    int[] bassRhythm=theme==4?new int[]{0,2,3}:new int[]{0,2};
    foreach(int off in bassRhythm)Add(b+off,theme==1?1.6:.8,root+(off==3?7:0),1,theme==4?.23:.15,-.06);
    if(theme!=1 && theme!=5){
     Add(b,.35,36,5,theme==4?.24:.12);
     Add(b+2,.3,36,5,theme==4?.21:.09);
     Add(b+1,.22,55,6,.065,-.28);
     Add(b+3,.22,58,6,.07,.3);
     for(int step=0;step<8;step++){
      if(theme==0 && step%2==1 && section==0)continue;
      double swing=theme==3 && step%2==1?.10:0;
      Add(b+step*.5+swing,.12,70,7,.023+(step%2)*.008,step%2==0?-.6:.6);
     }
     if(bar%8==7)for(int fill=0;fill<3;fill++)Add(b+3.25+fill*.25,.16,60+fill*3,6,.06,-.4+fill*.4);
    }else if(bar%4==0){Add(b,.4,36,5,.04);Add(b+2.5,.3,72,8,.035,.6);}
   }
   for(double phrase=0;phrase<totalBeats-2;phrase+=8){
    int index=(int)(phrase/8),section=(int)(phrase/totalBeats*4);
    int root=roots[(index+(section==2?2:0))%roots.Length]+24;
    for(int n=0;n<motif.Length;n++){
     if(theme==1 && n%2==1)continue;
     double beat=phrase+rhythm[n];
     if(beat>=totalBeats-2)continue;
     int interval=motif[(n+(section==2?2:0))%motif.Length];
     int pitch=root+interval+(theme==5?0:theme==1?12:0);
     int voice=theme==3?3:theme==4?4:2;
     double leadGain=theme==1?.08:theme==4?.13:.16;
     if(section==0)leadGain*=.85;
     Add(beat,n==3?1.35:.8,pitch,voice,leadGain,Math.Sin(index*.9+n*.6)*.32);
     if(section==1 || section==2){
      Add(beat+.5,.55,pitch-12,4,leadGain*.25,-.5);
     }
    }
    if(index%3==2)Add(phrase+6.5,.6,81+(index%3)*2,8,.055,.65);
   }
   // Deliberate short turnaround also handles requested lengths with fractional final beats.
   Add(totalBeats-1.75,.5,69,2,.13,-.25);
   Add(totalBeats-1.0,.4,65,2,.12,.25);
   Add(totalBeats-.5,.45,62,3,.13);
  }
  foreach(Note note in notes)Render(note);
  Space();
  double meanL=0,meanR=0;
  for(int i=0;i<frames;i++){meanL+=left[i];meanR+=right[i];}
  meanL/=frames;meanR/=frames;
  double peak=0,sum=0;
  for(int i=0;i<frames;i++){
   left[i]-=(float)meanL;right[i]-=(float)meanR;
   peak=Math.Max(peak,Math.Max(Math.Abs(left[i]),Math.Abs(right[i])));
   sum+=(double)left[i]*left[i]+(double)right[i]*right[i];
  }
  double rms=Math.Sqrt(sum/(2*frames));
  double gain=Math.Min(.67/Math.Max(peak,.001),.125/Math.Max(rms,.001));
  // 5.8 ms cyclic edge taper: no hard sample discontinuity, no long silent loop gap.
  int edge=jingle?2048:256;
  for(int i=0;i<edge;i++){
   double envelope=Math.Pow(Math.Sin(Math.PI*.5*i/edge),2);
   left[i]*=(float)envelope;right[i]*=(float)envelope;
   left[frames-1-i]*=(float)envelope;right[frames-1-i]*=(float)envelope;
  }
  Directory.CreateDirectory(Path.GetDirectoryName(wavPath));
  using(var writer=new BinaryWriter(File.Create(wavPath))){
   writer.Write(Encoding.ASCII.GetBytes("RIFF"));writer.Write(36+frames*4);writer.Write(Encoding.ASCII.GetBytes("WAVEfmt "));
   writer.Write(16);writer.Write((short)1);writer.Write((short)2);writer.Write(Rate);writer.Write(Rate*4);writer.Write((short)4);writer.Write((short)16);
   writer.Write(Encoding.ASCII.GetBytes("data"));writer.Write(frames*4);
   for(int i=0;i<frames;i++){writer.Write((short)Math.Round(left[i]*gain*32767));writer.Write((short)Math.Round(right[i]*gain*32767));}
  }
  WriteMidi(midiPath);
  var result=new Dictionary<string,object>();
  result["id"]=id;result["duration"]=seconds;result["bpm"]=tempo;result["sample_rate"]=Rate;result["channels"]=2;result["notes"]=notes.Count;
  result["peak"]=peak*gain;result["rms"]=rms*gain;result["seed"]=21700+seed;result["seam_difference"]=0;
  left=null;right=null;notes=null;
  return result;
 }
 class MidiEvent {public int Tick;public byte[] Data;public MidiEvent(int t,params byte[] d){Tick=t;Data=d;}}
 static void BE(BinaryWriter w,int value,int bytes){for(int i=bytes-1;i>=0;i--)w.Write((byte)((value>>(8*i))&255));}
 static void VL(BinaryWriter w,int value){int buffer=value&127;while((value>>=7)>0){buffer<<=8;buffer|=(value&127)|128;}while(true){w.Write((byte)buffer);if((buffer&128)!=0)buffer>>=8;else break;}}
 static void WriteMidi(string path){
  var events=new List<MidiEvent>();
  int tempo=(int)(60000000/bpm);
  events.Add(new MidiEvent(0,0xff,0x51,3,(byte)(tempo>>16),(byte)(tempo>>8),(byte)tempo));
  foreach(Note note in notes){
   int channel=note.Voice>=5?9:note.Voice;
   int pitch=note.Voice==5?36:note.Voice==6?37:note.Voice==7?42:note.Pitch;
   int velocity=Math.Min(110,Math.Max(18,(int)(note.Gain*240)));
   int begin=(int)(note.Beat*480),end=(int)(Math.Min(totalBeats,note.Beat+note.Length)*480);
   events.Add(new MidiEvent(begin,(byte)(0x90+channel),(byte)pitch,(byte)velocity));
   events.Add(new MidiEvent(end,(byte)(0x80+channel),(byte)pitch,0));
  }
  events.Sort((a,b)=>a.Tick!=b.Tick?a.Tick.CompareTo(b.Tick):a.Data[0].CompareTo(b.Data[0]));
  using(var memory=new MemoryStream()){
   using(var track=new BinaryWriter(memory,Encoding.ASCII,true)){
    int tick=0;foreach(var e in events){VL(track,e.Tick-tick);track.Write(e.Data);tick=e.Tick;}
    VL(track,0);track.Write(new byte[]{0xff,0x2f,0});
   }
   using(var output=new BinaryWriter(File.Create(path))){
    output.Write(Encoding.ASCII.GetBytes("MThd"));BE(output,6,4);BE(output,0,2);BE(output,1,2);BE(output,480,2);
    output.Write(Encoding.ASCII.GetBytes("MTrk"));BE(output,(int)memory.Length,4);output.Write(memory.ToArray());
   }
  }
 }
}
