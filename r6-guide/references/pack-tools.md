# Reusable pack tools

Run Lune commands from `tools/` (Rokit pins the runtime). Load only trusted move providers you authored; third-party RBXM/RBXL references are read as data and their scripts never execute here.

## Commands

```sh
lune run measure /path/reference.rbxm /path/brief.json "ClipName" --tip="Right Arm:0,-1,-4"
lune run pack /path/Moves.luau /path/out
lune run pack /path/Moves.luau /path/out --three=/path/three.min.js
lune run pack_demo /path/Moves.luau /path/out /path/r6-base.rbxl
python3 render_pack.py /path/out
```

`measure` prints one line per selected clip and saves the complete report. The exact source bytes, selected names, tip, analysis module code, measure tool and runtime manifest determine the cache key. A changed grip/source/tool invalidates it. `--verbose` prints full study text. `study` remains available for `--keys` and `--fit`; use it when you need pose extraction, not for routine status.

`pack` exports individual attacks, a combined sequence, full audit/study/reference JSON, actual baked world frames, fixed weapon geometry and the existing 3D preview. A local Three.js file can be embedded for offline use; otherwise the original CDN is used. It writes artifacts only after successful validation. Default output is one compact status line per move plus the result; use `--verbose` only for investigation.

`render_pack.py` requires Python with Pillow and NumPy; it renders the baked body/weapon to a GIF and front/side contact sheet. Use an existing dependency runtime when available. Rendering does not certify engine playback. View the result, including preparation, follow-through and recovery, not just the four contact poses.

`pack_demo` needs an existing clean R6 base place with StarterCharacter. It reuses `assets/PackDemo.client.luau`, disables default Animate and controls, attaches the fixed weapon and compiles the harness. It exports a rig with AnimSaves and a demo place. The live harness checks combined duration/hit order, separate tracks and engine tip/sole/off-hand samples. It does not apply gameplay damage. An offline compiled demo is **not** an engine PASS.

## Provider contract

A ModuleScript-style `.luau` file requires the skill modules through `script.Parent`. Supply:

- `PACK`: combined sequence name; `LIST`: ordered attack names.
- `build()`: map each name to `{clip, baked, meta}`. Each attack is non-looping 60 FPS with one `Hit`, and `meta.hit` agrees with the marker. Endpoints must match.
- `REFERENCE={brief="brief.json", adaptations="..."}`: measurement file relative to the provider, with explicit differences and fallback. Keep the search/provenance brief alongside it.
- Heavy providers also need `REFERENCE.visualBrief="heavy-reference.json"`: schema 1, `archetype="heavy"`, `observedOn`, and `sources` with URL/title/creator/rig, `status="viewed"`, and at least three `{seconds,note}` observations. Record actual load/cut/follow-through/recovery before posing; listing text and unrelated slash measurements cannot satisfy this gate. The JSON records evidence; a format check cannot verify that footage was watched.
- For fixed weapons: `TIP=Vector3` in the animated body part's space and `WEAPON={name,parent,grip,tip,geometry,offhand?}`. `grip` is a CFrame; weapon `tip={x,y,z}` is in grip space. The tool verifies `TIP == grip * tip`.
- `geometry`: array of `{name,size={x,y,z},cf=CFrame,color={r,g,b},shape?}`. Geometry is local to grip; shape is a Roblox PartType (default Block).
- `offhand={part="Left Arm",point={x,y,z},maxError=number}`: desired lower-hand grip point in weapon space. Author paired poses; this check does not solve or move the hand.
- For custom sizes: `BODY_SIZES` keyed by torso/leg names with actual Vector3 sizes, passed through to R6Quality.

The fixed-grip pipeline intentionally rejects `WEAPON.joints`. Wings or independently animated weapons need an adapter that exports those channels and verifies the actual geometry. Never silently drop them to save tokens.

The default scope is an animation pack. Requesting gameplay wiring may additionally need R6Combat/runtime references; it is not required merely to export animation keys.

## Contact and validation

`meta.contactHeight={minY,maxY}` optionally restricts an arc's center-line contact test to an actual target-height band in root space. It prevents an upright blade high above the target from being mistaken for the hit. Define it from the intended target region; do not cherry-pick a range merely to hide an earlier valid impact. Omit it to retain the previous audit behavior.

Required gates remain motion audit, body clearance, grip consistency, marker count/times, seams and serialized export reproduction. Fixed-weapon floor checks include its blade segment and primitive geometry. Full geometry/clothing collision is not implied.

Run `lune run check`, `lune run check_quality`, `lune run check_contact` and Selene once for the tool version. Re-run affected checks after changes. An archive of a past successful check is not evidence for modified code.
