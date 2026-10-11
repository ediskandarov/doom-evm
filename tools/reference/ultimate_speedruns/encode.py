#!/usr/bin/env python3
"""Use the accepted palette-only encoder with the verified map's exact tic count."""
import argparse
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[3]
ap=argparse.ArgumentParser();ap.add_argument('directory',type=Path);a=ap.parse_args();directory=a.directory.resolve()
m=json.loads((directory/'frame-manifest.json').read_text());n=m['gameplayTics'];assert m['pass'] and m['sampleEvery']==1
assert [f['tic'] for f in m['frames']]==list(range(1,n+1))
# Preserve encoder logic; adapt only the E1M1 count and output basename.
source=ROOT/'tools/reference/speedrun/encode_video.py'
text=source.read_text().replace('279',str(n)).replace('speedrun-e1m1',f"speedrun-{m.get('map','episode').lower()}")
# Pin both MP4 clocks to whole tic units; preserve the strict duration gate.
text=text.replace("'-video_track_timescale', '35000',", "'-video_track_timescale', '35000', '-movie_timescale', '35000',")
namespace={'__name__':'episode_palette_encoder','__file__':str(source)}
exec(compile(text,str(source),'exec'),namespace);namespace['encode'](directory)
