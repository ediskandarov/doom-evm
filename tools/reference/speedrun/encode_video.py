#!/usr/bin/env python3
"""Palette expansion, nearest-neighbor scaling and encoding only; no scene logic."""
import argparse
from fractions import Fraction
import hashlib
import json
from pathlib import Path
import subprocess
import time

from PIL import Image, ImageDraw


def sha(data):
    return hashlib.sha256(data).hexdigest()


def encode(directory):
    manifest_path = directory / 'frame-manifest.json'
    manifest = json.loads(manifest_path.read_text())
    assert manifest['pass'] and manifest['ticRate'] == 35 and manifest['gameplayTics'] == 279
    palette = (directory / 'palette.bin').read_bytes()
    assert len(palette) == 768 and sha(palette) == manifest['authenticatedPaletteSha256']
    images = []
    previous = 0
    for frame in manifest['frames']:
        assert previous < frame['tic'] <= 279
        assert frame['durationTics'] == frame['tic'] - previous
        pixels = (directory / frame['file']).read_bytes()
        assert len(pixels) == 64000 and sha(pixels) == frame['indexed8Sha256']
        image = Image.frombytes('P', (320, 200), pixels)
        image.putpalette(palette)
        image = image.convert('RGB')
        png = directory / frame['file'].replace('.indexed8', '.png')
        image.save(png)
        frame.update(png=png.relative_to(directory).as_posix(), pngSha256=sha(png.read_bytes()),
                     rgbSha256=sha(image.tobytes()))
        images.append(image)
        previous = frame['tic']
    assert previous == 279 and sum(f['durationTics'] for f in manifest['frames']) == 279
    mp4 = directory / 'speedrun-e1m1.mp4'
    command = ['ffmpeg', '-hide_banner', '-loglevel', 'warning', '-y',
               '-f', 'rawvideo', '-pixel_format', 'rgb24', '-video_size', '320x200',
               '-framerate', '35', '-i', 'pipe:0', '-an',
               '-vf', 'scale=1280:800:flags=neighbor,setsar=5/6',
               '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '18',
               '-pix_fmt', 'yuv420p', '-fps_mode', 'passthrough',
               '-frames:v', '279', '-video_track_timescale', '35000',
               '-movflags', '+faststart', str(mp4)]
    began = time.perf_counter()
    with (directory / 'ffmpeg.log').open('w') as log:
        process = subprocess.Popen(command, stdin=subprocess.PIPE, stderr=log)
        try:
            for frame, image in zip(manifest['frames'], images):
                rgb = image.tobytes()
                for _ in range(frame['durationTics']):
                    process.stdin.write(rgb)
            process.stdin.close()
            assert process.wait(timeout=120) == 0, 'ffmpeg failed; see ffmpeg.log'
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()
    elapsed = time.perf_counter() - began
    probe_command = ['ffprobe', '-v', 'error', '-count_frames', '-select_streams', 'v:0',
                     '-show_streams', '-show_format', '-of', 'json', str(mp4)]
    probe = json.loads(subprocess.check_output(probe_command))
    stream = probe['streams'][0]
    assert stream['width'] == 1280 and stream['height'] == 800
    assert stream['sample_aspect_ratio'] == '5:6' and stream['display_aspect_ratio'] == '4:3'
    assert Fraction(stream['avg_frame_rate']) == 35 and int(stream['nb_read_frames']) == 279
    assert abs(float(stream['duration']) - 279 / 35) < 0.00001
    assert abs(float(probe['format']['duration']) - 279 / 35) < 0.00001
    sheet = Image.new('RGB', (4 * 320, 3 * 266), '#151515')
    draw = ImageDraw.Draw(sheet)
    indices = [round(i * (len(images) - 1) / 11) for i in range(12)]
    for cell, index in enumerate(indices):
        x, y = (cell % 4) * 320, (cell // 4) * 266
        # Contact panels use square-pixel4:3 display; source pixels remain nearest-neighbor.
        sheet.paste(images[index].resize((320, 240), Image.Resampling.NEAREST), (x, y))
        frame = manifest['frames'][index]
        draw.text((x + 6, y + 246), f"EVM tic {frame['tic']} / 279   {frame['tic'] / 35:.3f}s", fill='white')
    contact = directory / 'speedrun-e1m1-contact-sheet.png'
    sheet.save(contact)
    manifest['media'] = dict(mp4=mp4.name, mp4Sha256=sha(mp4.read_bytes()),
        contactSheet=contact.name, contactSheetSha256=sha(contact.read_bytes()),
        contactTics=[manifest['frames'][i]['tic'] for i in indices],
        encodedFrames=279, uniqueEVMFrames=len(images), fps=35, gameDurationSeconds=279 / 35,
        pixelWidth=1280, pixelHeight=800, sampleAspectRatio='5:6', displayAspectRatio='4:3',
        temporalPolicy='Each sampled post-tic image represents the preceding interval; hold its exact tic span at35fps. No interpolation.',
        ffmpegCommand=command, ffprobe=probe, encodingSeconds=elapsed,
        ffmpegVersion=subprocess.check_output(['ffmpeg', '-version'], text=True).splitlines()[0],
        pillowVersion=Image.__version__)
    manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps(dict(pass_=True, frames=len(images), durationSeconds=float(stream['duration']),
                         encodingSeconds=elapsed, mp4=str(mp4), contactSheet=str(contact)), indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('directory', type=Path)
    encode(parser.parse_args().directory.resolve())
