#!/usr/bin/env python3
"""Original deterministic chamber-folk score. No samples or third-party music.
32-bar A/B/interlude/reprise arrangements with synchronized pressure stems.
Run: python tools/audio/compose_score.py (numpy + ffmpeg).
"""
from pathlib import Path
import json, math, subprocess, tempfile, wave
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/music'
SR = 32000
# root MIDI, tempo, lead, mode; chapter identities follow their environments.
PIECES = {
    'title': (62, 92, 'flute', 'major'), 'camp': (60, 76, 'pluck', 'major'),
    'story': (57, 72, 'flute', 'dorian'),
    'field': (62, 104, 'flute', 'major'), 'boss': (50, 124, 'strings', 'minor'),
    'field_2': (65, 100, 'pluck', 'major'), 'boss_2': (53, 120, 'strings', 'dorian'),
    'field_3': (57, 88, 'flute', 'dorian'), 'boss_3': (45, 116, 'flute', 'minor'),
    'field_4': (60, 108, 'pluck', 'major'), 'boss_4': (48, 128, 'strings', 'minor'),
    'field_5': (62, 94, 'bell', 'dorian'), 'boss_5': (50, 130, 'strings', 'minor'),
    'field_6': (59, 102, 'flute', 'dorian'), 'boss_6': (47, 126, 'strings', 'minor'),
}
SCALES = {'major':[0,2,4,5,7,9,11], 'minor':[0,2,3,5,7,8,10], 'dorian':[0,2,3,5,7,9,10]}
# A question and answer, plus a contrasting middle melody. Rests are explicit.
PHRASES = [
 [(0,0,1),(1.5,2,.5),(2,4,1.5)], [(0,5,1),(1,4,.5),(2,2,1.5)],
 [(0,3,1.5),(2,2,.5),(3,1,.75)], [(0,0,2.5)],
 [(0,4,.75),(1,6,.75),(2,7,1.5)], [(0,6,1.5),(2,4,1.5)],
 [(0,3,1),(1.5,1,.5),(2,2,1)], [(0,0,3)],
]
BRIDGE = [
 [(0,7,1.5),(2,6,1)],[(.5,4,1),(2,5,1.5)],
 [(0,3,2),(2.5,2,.5)],[(0,4,3)],
 [(0,5,1),(1,7,1),(2.5,6,1)],[(0,4,1.5),(2,2,1)],
 [(0,1,1),(1.5,2,.5),(2,4,1)],[(0,6,1),(2,4,1.5)],
]

def pitch(root, scale, degree):
    return root + 12 * (degree // 7) + scale[degree % 7]

def voice(kind, midi, duration, rng):
    t = np.arange(max(1, int(SR * (duration + .4))), dtype=np.float64) / SR
    f = 440 * 2 ** ((midi - 69) / 12)
    vib = .0025 * np.sin(2*np.pi*4.8*t) * np.minimum(t*3, 1)
    phase = 2*np.pi*f * (t + vib/(2*np.pi*4.8))
    release = np.clip((duration + .4 - t)/.4, 0, 1)
    if kind == 'pluck':
        x = sum(np.sin(phase*k+.12*k) * np.exp(-t*(2.6+k*.8)) / k**1.6 for k in range(1,7))
        env = np.minimum(t/.006, 1) * release
    elif kind == 'bell':
        x = np.sin(phase)*np.exp(-t*2) + .24*np.sin(phase*2.76)*np.exp(-t*4)
        env = np.minimum(t/.008, 1) * release
    elif kind == 'flute':
        x = np.sin(phase)+.19*np.sin(phase*2)+.06*np.sin(phase*3)
        x += rng.normal(0, .014, len(t))
        env = np.minimum(t/.075, 1) * release * (.9+.1*np.sin(np.pi*np.minimum(t/max(duration,.1),1)))
    else:
        x = sum((np.sin(phase*k)+np.sin(phase*k*1.002)) / (2*k**1.7) for k in range(1,8))
        env = np.minimum(t/.18, 1) * release
    return (x*env).astype(np.float32)

def add(buf, sample, beat, beat_sec, gain, pan):
    start = int(beat * beat_sec * SR)
    # Wrap releases into the start: each loop has the preceding phrase's tail.
    idx = (start + np.arange(len(sample))) % len(buf)
    buf[idx,0] += sample * gain * math.sqrt((1-pan)/2)
    buf[idx,1] += sample * gain * math.sqrt((1+pan)/2)

def drum(rng, kind):
    t=np.arange(int(SR*.28))/SR
    if kind=='low':
        return (np.sin(2*np.pi*(65*t+4*(1-np.exp(-t*22))))*np.exp(-t*20)).astype(np.float32)
    noise=rng.normal(0,1,len(t))
    noise=np.convolve(noise,np.ones(5)/5,mode='same')
    return (noise*np.exp(-t*(40 if kind=='brush' else 20))).astype(np.float32)

def write_ogg(name, buf):
    # Stereo short room reflections, circular for loop continuity.
    buf = buf + .13*np.roll(buf[:,::-1], int(SR*.071), axis=0) + .07*np.roll(buf, int(SR*.113), axis=0)
    peak=float(np.max(np.abs(buf)))
    buf *= min(1.0, .78/max(peak,1e-6))
    with tempfile.NamedTemporaryFile(suffix='.wav') as tmp:
        with wave.open(tmp.name,'wb') as wav:
            wav.setnchannels(2);wav.setsampwidth(2);wav.setframerate(SR)
            wav.writeframes((buf*32767).astype('<i2').tobytes())
        subprocess.run(['ffmpeg','-v','error','-y','-i',tmp.name,'-c:a','libvorbis','-q:a','4',str(OUT/(name+'.ogg'))],check=True)
    return {'seconds':round(len(buf)/SR,4),'peak':round(float(np.max(np.abs(buf))),5),
            'rms':round(float(np.sqrt(np.mean(buf**2))),5),'seam_jump':round(float(np.max(np.abs(buf[-1]-buf[0]))),5)}

def compose(name, spec):
    root, bpm, lead, mode=spec
    rng=np.random.default_rng(1937+sum((i+1)*ord(c) for i,c in enumerate(name)))
    scale=SCALES[mode];beat_sec=60/bpm;bars=32
    core=np.zeros((round(SR*beat_sec*bars*4),2),dtype=np.float32);pressure=np.zeros_like(core)
    chords=[0,5,3,4,0,2,3,4,5,3,0,4,3,5,4,4]
    boss=name.startswith('boss');quiet=name in ('camp','story')
    for bar in range(bars):
        section=bar//8;chord=chords[bar%16];start=bar*4
        # Alternating inversions and register keep accompaniment from a mechanical loop.
        for step in range(4):
            degree=chord+[0,4,2,4][step] + (7 if bar%4==3 and step==3 else 0)
            add(core,voice('pluck',pitch(root,scale,degree),.7*beat_sec,rng),start+step+.008*rng.random(),beat_sec,.12 if quiet else .16,-.30)
        for degree in (chord-7,chord-3):
            add(core,voice('strings',pitch(root,scale,degree),3.5*beat_sec,rng),start,beat_sec,.075 if section==2 else .10,.32)
        melody=BRIDGE if section==1 else PHRASES
        # Interlude makes real room in the arrangement, not a nonstop melody.
        if section!=2 or bar%2==0:
            for offset,degree,length in melody[bar%8]:
                shift=7 if section==3 and bar%4==0 else 0
                add(core,voice(lead,pitch(root+12,scale,degree+shift),length*beat_sec,rng),start+offset,beat_sec,.16 if quiet else .21,.05)
        if section==3 and bar%2==1:
            add(core,voice('bell',pitch(root+12,scale,chord+2),beat_sec,rng),start+3,beat_sec,.065,-.45)
        for beat in range(4):
            add(pressure,drum(rng,'low' if beat%2==0 else 'tap'),start+beat,beat_sec,.24 if boss else .17,0)
            if section!=2:
                add(pressure,drum(rng,'brush'),start+beat+.5,beat_sec,.075,.35 if beat%2 else -.35)
        if boss:
            # Restrained low ostinato lives in the pressure layer.
            for beat in (0,1.5,2,3.5):
                add(pressure,voice('strings',pitch(root-12,scale,chord),.3*beat_sec,rng),start+beat,beat_sec,.12,-.2)
    result={'bpm':bpm,'bars':bars,'form':'A / B / interlude / reprise','mode':mode,'lead':lead,'core':write_ogg(name,core)}
    if name.startswith(('field','boss')):
        result['pressure']=write_ogg(name+'_pressure',pressure)
    print(name,result['core']['seconds'],flush=True)
    return result

if __name__=='__main__':
    OUT.mkdir(exist_ok=True)
    manifest={name:compose(name,spec) for name,spec in PIECES.items()}
    (OUT/'score_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
