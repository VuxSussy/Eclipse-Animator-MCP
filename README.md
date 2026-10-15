# Eclipse Animator MCP

An MCP server that lets an AI agent (Claude Code, Claude Desktop, …) read and write Roblox animations you can open in [Eclipse Animator](https://create.roblox.com/store) in Roblox Studio.

Eclipse Animator lists and opens the `KeyframeSequence`s in a rig's `AnimSaves` folder. This MCP reads and writes those, so an agent can block out a pose or a whole animation, and you finish it in Eclipse.

```
AI agent ──stdio──> server.js ──HTTP 127.0.0.1:44755──> Studio plugin ──> Workspace.<Rig>.AnimSaves
```

This repo does **not** include Eclipse Animator or any of its code. You need your own licensed copy of the plugin.

## Tools

| Tool | What it does |
|------|--------------|
| `list_rigs` | Rigs in Workspace, their animatable parts (Motor6D `Part1` names) and their saved animations |
| `get_animation` | A saved `KeyframeSequence` as JSON keyframes |
| `save_animation` | Writes a `KeyframeSequence` into `AnimSaves` (replaces one with the same name; Ctrl+Z undoes it) |

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

## Setup

1. `npm install`
2. Install the Studio plugin: copy `plugin/EclipseAnimatorMCP.server.luau` to your Studio plugins folder as `EclipseAnimatorMCP.lua`
   (macOS `~/Documents/Roblox/Plugins`, Windows `%LOCALAPPDATA%\Roblox\Plugins`), then restart Studio and allow its HTTP requests when asked.
3. Add the server to your agent:
   ```bash
   claude mcp add eclipse-animator --scope user -- node /path/to/Eclipse-Animator-MCP/server.js
   ```

`ECLIPSE_MCP_PORT` changes the port (also set the plugin setting `EclipseMCPPort`).

## Limits

- Motor6D rigs only (no Bone rigs).
- `get_animation` returns keyed poses only; Eclipse extras on a sequence (IK poses, markers) are ignored, and `save_animation` over an Eclipse-made animation drops them (Ctrl+Z restores it).
- One server per port: two agent sessions on the same port can't both reach Studio.

## Test

```bash
npm test
```

Runs a real MCP client against `server.js` with a fake Studio plugin.
