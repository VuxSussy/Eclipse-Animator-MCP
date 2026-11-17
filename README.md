# Eclipse Animator MCP

Make Roblox animations by talking to Claude. This MCP server lets an AI agent (Claude Desktop, Claude Code, …) create, enhance and import animations in the open Roblox Studio place. Every animation lands in the rig's `AnimSaves` folder, where [Eclipse Animator](https://create.roblox.com/store) lists and opens it for polishing.

```
Claude ──stdio──> server.js ──HTTP 127.0.0.1:44755──> Studio plugin ──> Workspace.<Rig>.AnimSaves
                     │
                     └── video_pose.py (MediaPipe) for video import
```

This repo does **not** include Eclipse Animator or any of its code. You need your own licensed copy of the plugin.

## What it can do

| Tool | What it does |
|------|--------------|
| `list_rigs` | Rigs in Workspace, their animatable parts and saved animations |
| `get_animation` / `save_animation` | Read or write an animation as JSON keyframes |
| `preview_animation` | Play an animation in the Studio viewport, no playtest needed |
| `enhance_animation` | Stronger poses, ease-in-out, overshoot-and-settle on big moves, seamless loops, speed. Saves as `<name> Enhanced` |
| `import_animation_pack` | Put a Roblox animation pack (Ninja, Robot, Stylish… or any bundle/animation ID/link) on a rig. R15 packs are adapted to R6 and custom rigs automatically |
| `video_to_animation` | Turn a video of a person into an animation on the rig (MediaPipe body tracking) |

### R6 animation kit

For six-part R6 rigs (`list_rigs` marks them `r6: true`) the server bundles [Ultimate R6 Animation Design](https://github.com/VuxSussy/ultimate-r6-animation-design): poses as named angles plus short limb slides (no IK), in-betweens on a smooth curve through the keys, and weighted timing (slow wind-up, fast strike, slow recovery) so moves hit with force instead of gliding. Every clip is audited before it is saved.

| Tool | What it does |
|------|--------------|
| `r6_guide` | The R6 design guide (posing, timing and weight, combat, R15 → R6...), also served as `r6-guide://` resources |
| `save_r6_animation` | Build an R6 animation from key poses, audit it (pops, hit timing, body commitment, slide budgets, crossed legs, floor contact, thighs in the torso) and save it |
| `study_animation` | Measure a saved animation to imitate it, and get its key poses back for `save_r6_animation` |
| `smooth_r6_animation` | Rebuild a stiff or floaty R6 animation on the kit's curve and weight, saved as `<name> Smooth` |
| `import_r6_kit` | 24 ready R6 clips: Stance, Jab, Cross, Hook, Uppercut, Kick, four dashes, Block, two hit reactions, Idle, Walk, Run, Climb, Jump, Fall, three landings, two wall runs |

The kit's Luau modules live in `plugin/R6` (they run inside the Studio plugin) and its guide in `r6-guide`. `npm run sync-r6` updates both from GitHub.

Ready-made prompts (Claude's `/` or **+** menu): **Make an animation**, **Enhance an animation**, **Animation from a video**, **Use an animation pack**.

In Studio, **Plugins → AI Status** shows whether the AI app is connected and what it last did.

## Setup

Double-click `install.command` (macOS) or `install.bat` (Windows). This runs `npm install` and `node setup.js`, which:

1. installs the Studio plugin (`EclipseAnimatorMCP.rbxmx` in your Studio plugins folder),
2. adds the server to Claude Desktop (backs up `claude_desktop_config.json` first) and to Claude Code if it's installed,
3. prepares video import if `uv` and `ffmpeg` are installed (`brew install uv ffmpeg` / `winget install astral-sh.uv Gyan.FFmpeg`).

Then restart Studio and Claude, and click **Allow** when the plugin asks about HTTP requests.

`ECLIPSE_MCP_PORT` changes the port (also set the plugin setting `EclipseMCPPort`). Several Claude windows can run the server at once: the first one owns the port and the others relay through it.

## Poses

A pose is `{ pos: [x,y,z], rot: [x,y,z] /* degrees, XYZ */, easing, direction }`, keyed by part name:

```json
{
  "rig": "Workspace.R6", "name": "Wave", "loop": true,
  "keyframes": [
    { "time": 0,   "poses": { "Right Arm": { "rot": [0, 0, 0] } } },
    { "time": 0.5, "poses": { "Right Arm": { "rot": [0, 0, 120], "easing": "Cubic", "direction": "Out" } } }
  ]
}
```

## How retargeting works

Video frames and animation packs are both turned into 3D body points (shoulders, elbows, wrists, hips, knees, ankles, ears, nose…). The plugin then solves each joint of the target rig, parents first, so each limb points where the body points say, and saves the result as a `KeyframeSequence`. Measured on Roblox's Robot pack (R15 → R6): average limb error ≤ 0.3°, worst 4°, including arms-overhead climbs.

## Limits

- Motor6D, AnimationConstraint and Bone rigs: R6, R15 (including Roblox's new joints), custom rigs and skinned creatures (wings, tails, spines). Video and pack import only fit humanoid bodies.
- Video and cross-rig pack imports are rotation only: no root motion, and limbs don't twist around their own axis.
- Video import is a solid first draft; polish it in Eclipse Animator. It works best with one person, whole body visible, steady camera.
- Enhanced poses are capped at ±175° per axis, since Roblox interpolates larger rotations the short way round.

## Test

```bash
npm test
```

Runs the enhancer tests and a real MCP client against `server.js` with a fake Studio plugin, including two server instances sharing one port.

```bash
npm run test:r6
```

Runs the plugin's R6 modules offline in [Lune](https://github.com/lune-org/lune) (`rokit install` gets it): building, auditing, studying and smoothing clips, and every kit clip.
