# Eclipse Animator MCP

Make Roblox animations by talking to Claude. This MCP server lets an AI agent (Claude Desktop, Claude Code, …) create, enhance and import animations in the open Roblox Studio place. Every animation lands in the rig's `AnimSaves` folder, where [Eclipse Animator](https://create.roblox.com/store) lists and opens it for polishing.

**Không biết code? Đọc [HUONG-DAN.md](HUONG-DAN.md)** (tiếng Việt, từng bước).

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

- Motor6D and AnimationConstraint rigs (R6, R15 including Roblox's new joints, most custom rigs). No Bone rigs.
- Video and cross-rig pack imports are rotation only: no root motion, and limbs don't twist around their own axis.
- Video import is a solid first draft; polish it in Eclipse Animator. It works best with one person, whole body visible, steady camera.
- Enhanced poses are capped at ±175° per axis, since Roblox interpolates larger rotations the short way round.

## Test

```bash
npm test
```

Runs the enhancer tests and a real MCP client against `server.js` with a fake Studio plugin, including two server instances sharing one port.
