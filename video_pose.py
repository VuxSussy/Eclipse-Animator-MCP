# Video -> 3D body points per frame (MediaPipe Pose), printed as JSON in Roblox axes.
# Run: uv run --with mediapipe python video_pose.py VIDEO [--fps 30] [--start 0] [--end 0]
import argparse, json, os, subprocess, sys, urllib.request

import mediapipe as mp
import numpy as np
from mediapipe.tasks.python import BaseOptions, vision

MODEL_URL = 'https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_full/float16/latest/pose_landmarker_full.task'
MODEL = os.path.expanduser('~/.cache/eclipse-animator-mcp/pose_landmarker_full.task')
# MediaPipe landmark index -> our point name (l/r = the person's own left/right)
POINTS = {'nose': 0, 'lEar': 7, 'rEar': 8, 'lShoulder': 11, 'rShoulder': 12, 'lElbow': 13, 'rElbow': 14,
          'lWrist': 15, 'rWrist': 16, 'lHip': 23, 'rHip': 24, 'lKnee': 25, 'rKnee': 26, 'lAnkle': 27,
          'rAnkle': 28, 'lHeel': 29, 'rHeel': 30, 'lToe': 31, 'rToe': 32}

ap = argparse.ArgumentParser()
ap.add_argument('video')
ap.add_argument('--fps', type=float, default=30)
ap.add_argument('--start', type=float, default=0)
ap.add_argument('--end', type=float, default=0, help='0 = until the end')
a = ap.parse_args()

if not os.path.exists(MODEL):
    os.makedirs(os.path.dirname(MODEL), exist_ok=True)
    urllib.request.urlretrieve(MODEL_URL, MODEL + '.part')
    os.replace(MODEL + '.part', MODEL)

w, h = map(int, subprocess.check_output(['ffprobe', '-v', 'error', '-select_streams', 'v:0', '-show_entries',
                                          'stream=width,height', '-of', 'csv=p=0:s=x', a.video], text=True).strip().split('x')[:2])
scale = min(1, 640 / max(w, h))  # pose models work at low res; keeps it fast
w, h = int(w * scale) // 2 * 2, int(h * scale) // 2 * 2
cmd = ['ffmpeg', '-v', 'error', '-ss', str(a.start), '-i', a.video]
if a.end > a.start:
    cmd += ['-t', str(a.end - a.start)]
cmd += ['-vf', f'fps={a.fps},scale={w}:{h}', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-']
ff = subprocess.Popen(cmd, stdout=subprocess.PIPE)

opts = vision.PoseLandmarkerOptions(base_options=BaseOptions(model_asset_path=MODEL), running_mode=vision.RunningMode.VIDEO)
frames, i = [], 0
with vision.PoseLandmarker.create_from_options(opts) as landmarker:
    while (buf := ff.stdout.read(w * h * 3)) and len(buf) == w * h * 3:
        t = i / a.fps
        res = landmarker.detect_for_video(mp.Image(image_format=mp.ImageFormat.SRGB, data=np.frombuffer(buf, np.uint8).reshape(h, w, 3)), int(t * 1000))
        if res.pose_world_landmarks:
            lm = res.pose_world_landmarks[0]
            # MediaPipe: x image-right, y down, z away from camera. Roblox: X right, Y up, facing -Z (toward camera).
            p = {n: [-lm[k].x, -lm[k].y, lm[k].z] for n, k in POINTS.items()}
            for s, (index, pinky) in {'l': (19, 17), 'r': (20, 18)}.items():
                p[s + 'HandTip'] = [-(lm[index].x + lm[pinky].x) / 2, -(lm[index].y + lm[pinky].y) / 2, (lm[index].z + lm[pinky].z) / 2]
            frames.append({'t': round(t, 4), 'p': {n: [round(v, 4) for v in xyz] for n, xyz in p.items()}})
        i += 1
if ff.wait() != 0:
    sys.exit('ffmpeg could not read the video')
json.dump({'frames': frames, 'total': i}, sys.stdout)
