#!/usr/bin/env python3
"""Palette decoding, nearest video scaling and H.264 encoding only; all indexed pixels from EVM."""
import argparse,json,hashlib,subprocess,datetime
from pathlib import Path
from fractions import Fraction
from PIL import Image
ap=argparse.ArgumentParser();ap.add_argument('recording',type=Path);a=ap.parse_args();root=a.recording.resolve();r=json.loads((root/'recording.json').read_text());assert r['pass'];video=root/f"ultimate-e1m{r['identity']['map']}-complete.mp4";assert not video.exists(),'Refuse to overwrite an existing recording'
sha=lambda b:hashlib.sha256(b).hexdigest();start=datetime.datetime.now(datetime.timezone.utc).isoformat()
cmd=['ffmpeg','-hide_banner','-loglevel','error','-f','rawvideo','-pix_fmt','rgb24','-s','320x200','-r','35','-i','pipe:0','-an','-vf','scale=1280:960:flags=neighbor,setsar=1','-c:v','libx264','-preset','slow','-crf','16','-pix_fmt','yuv420p','-video_track_timescale','35000','-movie_timescale','35000','-movflags','+faststart',str(video)]
p=subprocess.Popen(cmd,stdin=subprocess.PIPE)
try:
 for f in r['frames']:
  pixels=(root/f['file']).read_bytes();pal=(root/f['paletteFile']).read_bytes();assert sha(pixels)==f['sha256'] and sha(pal)==f['paletteSha256']
  im=Image.frombytes('P',(320,200),pixels);im.putpalette(pal);p.stdin.write(im.convert('RGB').tobytes())
 p.stdin.close();assert p.wait()==0
except BaseException:
 p.stdin.close();p.terminate();p.wait();raise
probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-select_streams','v:0','-show_entries','stream=width,height,r_frame_rate,avg_frame_rate,nb_frames,duration,time_base,display_aspect_ratio:format=duration','-of','json',str(video)]))
s=probe['streams'][0];n=len(r['frames']);assert (s['width'],s['height'],s['display_aspect_ratio'])==(1280,960,'4:3');assert s['r_frame_rate']==s['avg_frame_rate']=='35/1';assert int(s['nb_frames'])==n
packets=json.loads(subprocess.check_output(['ffprobe','-v','error','-select_streams','v:0','-show_entries','packet=pts,duration','-of','json',str(video)]))['packets'];pts=sorted(x['pts'] for x in packets);assert pts==list(range(0,n*1000,1000));assert all(x['duration']==1000 for x in packets);assert Fraction(s['time_base'])==Fraction(1,35000);assert abs(Fraction(probe['format']['duration'])-Fraction(n,35))<=Fraction(1,1000000)
report=dict(pass_=True,startedUTC=start,endedUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),command=cmd,path=str(video),sha256=sha(video.read_bytes()),bytes=video.stat().st_size,frames=n,durationSeconds=n/35,probe=probe,allPacketClocksExact=True,presentation='35 FPS, nearest 1280x960, square-pixel 4:3, original per-frame EVM palette, CRF16 H.264, silent',limitations='H.264 is lossy; indexed8/native comparisons establish exact pixels before encoding.')
(root/'media.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
