#!/usr/bin/env node
// Eclipse Animator MCP: stdio MCP server + a localhost bridge the Studio plugin long-polls.
import http from 'node:http'
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js'
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js'
import { z } from 'zod'
import { execFile } from 'node:child_process'
import { promisify } from 'node:util'
import { fileURLToPath } from 'node:url'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { enhance } from './enhance.js'

const PORT = Number(process.env.ECLIPSE_MCP_PORT) || 44755
const queue = []
const pending = new Map()
let waiter = null // the plugin's open /poll request, if any
let nextId = 1

function send(tool, args, seconds = 30) {
  const cmd = { id: nextId++, tool, args }
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      pending.delete(cmd.id)
      const i = queue.indexOf(cmd)
      if (i >= 0) queue.splice(i, 1) // never run a command the caller already gave up on
      reject(new Error(i >= 0
        ? 'Roblox Studio is not connected. Open Studio (with the Eclipse Animator MCP plugin installed) and click Allow if it asks about HTTP requests.'
        : `Roblox Studio did not finish in ${seconds}s.`))
    }, seconds * 1000)
    pending.set(cmd.id, { resolve, reject, timer })
    if (waiter) waiter(cmd)
    else queue.push(cmd)
  })
}

const bridge = http.createServer((req, res) => {
  if (req.method === 'GET' && req.url === '/poll') {
    const reply = cmd => {
      clearTimeout(idle)
      if (waiter === reply) waiter = null
      if (cmd) res.writeHead(200, { 'content-type': 'application/json' }).end(JSON.stringify(cmd))
      else res.writeHead(204).end()
    }
    const idle = setTimeout(reply, 20000)
    if (queue.length) return reply(queue.shift())
    if (waiter) waiter(null) // a newer poll replaces the old one
    waiter = reply
    req.on('close', () => { if (waiter === reply) { waiter = null; clearTimeout(idle) } })
    return
  }
  if (req.method === 'POST' && req.url === '/result') {
    let body = ''
    req.on('data', c => { body += c })
    req.on('end', () => {
      try {
        const { id, ok, result, error } = JSON.parse(body)
        const p = pending.get(id)
        if (p) {
          pending.delete(id)
          clearTimeout(p.timer)
          ok ? p.resolve(result) : p.reject(new Error(error))
        }
        res.writeHead(204).end()
      } catch {
        res.writeHead(400).end()
      }
    })
    return
  }
  if (req.method === 'POST' && req.url === '/send') { // another MCP instance (e.g. a second AI app window) relaying through us
    let body = ''
    req.on('data', c => { body += c })
    req.on('end', async () => {
      let out
      try {
        const { tool, args, seconds } = JSON.parse(body)
        out = { ok: true, result: await send(tool, args, seconds) }
      } catch (e) {
        out = { ok: false, error: e.message }
      }
      res.writeHead(200, { 'content-type': 'application/json' }).end(JSON.stringify(out))
    })
    return
  }
  res.writeHead(404).end()
})
bridge.on('error', () => {}) // port taken: another instance owns the bridge, call() relays through it

const listen = () => new Promise(resolve => {
  const done = ok => { bridge.off('error', fail); bridge.off('listening', win); resolve(ok) }
  const fail = () => done(false), win = () => done(true)
  bridge.once('error', fail).once('listening', win).listen(PORT, '127.0.0.1')
})
await listen()

// Own the bridge if the port is free (or was freed), else relay to the instance that owns it.
async function call(tool, args, seconds = 30) {
  if (bridge.listening || await listen()) return send(tool, args, seconds)
  let res
  try {
    res = await fetch(`http://127.0.0.1:${PORT}/send`, { method: 'POST', body: JSON.stringify({ tool, args, seconds }) })
  } catch {
    if (await listen()) return send(tool, args, seconds) // the owner just quit
    throw new Error(`Port ${PORT} is busy with another program. Set ECLIPSE_MCP_PORT to a free port.`)
  }
  const out = await res.json().catch(() => ({ ok: false, error: `Port ${PORT} is busy with another program. Set ECLIPSE_MCP_PORT to a free port.` }))
  if (!out.ok) throw new Error(out.error)
  return out.result
}

const reply = value => ({ content: [{ type: 'text', text: JSON.stringify(value, null, 1) }] })
const text = (tool, seconds) => async args => reply(await call(tool, args, seconds))

const pose = z.object({
  pos: z.array(z.number()).length(3).optional().describe('Offset in studs from the joint rest pose. Default [0,0,0].'),
  rot: z.array(z.number()).length(3).optional().describe('Rotation in degrees, XYZ order (CFrame.Angles). Default [0,0,0].'),
  easing: z.enum(['Linear', 'Constant', 'Elastic', 'Cubic', 'Bounce', 'CubicV2']).optional().describe('Default Linear.'),
  direction: z.enum(['In', 'Out', 'InOut']).optional().describe('Default In.'),
})
const animation = {
  loop: z.boolean().optional(),
  priority: z.enum(['Core', 'Idle', 'Movement', 'Action', 'Action2', 'Action3', 'Action4']).optional().describe('Default Action.'),
  keyframes: z.array(z.object({
    time: z.number().min(0).describe('Seconds.'),
    poses: z.record(z.string(), pose).describe('Keyed by part or bone name from list_rigs (e.g. "Head", "RightUpperArm", "Wing1_L"). Unlisted parts are not keyed at this time.'),
  })).min(1),
}
const rig = z.string().describe('Rig full name from list_rigs (e.g. "Workspace.Rig") or just its Name.')

const here = path.dirname(fileURLToPath(import.meta.url))
const run = promisify(execFile)

async function videoFrames(file, fps, start, end) {
  file = path.resolve(file.replace(/^~(?=\/|$)/, os.homedir()))
  if (!fs.existsSync(file)) throw new Error(`Video not found: ${file}`)
  let out
  try {
    out = await run('uv', ['run', '--quiet', '--with', 'mediapipe', 'python', '-I', path.join(here, 'video_pose.py'), file,
      '--fps', String(fps), '--start', String(start), '--end', String(end)], { maxBuffer: 1 << 28 })
  } catch (e) {
    if (e.code === 'ENOENT') throw new Error('Video import needs "uv" (https://docs.astral.sh/uv/) and ffmpeg. Run the installer again or install them.')
    throw new Error(`Could not read the video: ${e.stderr?.split('\n').filter(l => !/^[WI]\d{4}/.test(l)).join('\n').trim() || e.message}`)
  }
  const { frames, total } = JSON.parse(out.stdout)
  if (frames.length < 2) throw new Error(`No person found in the video (${total} frames checked). Use a clip where one whole body is clearly visible.`)
  // centered 5-frame moving average: pose detection jitters frame to frame
  return frames.map((f, i) => {
    const near = frames.slice(Math.max(0, i - 2), i + 3)
    const p = {}
    for (const n of Object.keys(f.p)) p[n] = [0, 1, 2].map(k => near.reduce((s, g) => s + g.p[n][k], 0) / near.length)
    return { t: Math.round((f.t - frames[0].t) * 1e4) / 1e4, p }
  })
}

async function findPack(pack) {
  const id = String(pack).match(/^\s*(\d+)\s*$|roblox\.com\/(?:[a-z-]+\/)?(?:bundles|catalog)\/(\d+)/i)
  if (id) return Number(id[1] ?? id[2])
  for (const creator of ['&CreatorName=Roblox', '']) {
    const res = await fetch(`https://catalog.roblox.com/v1/search/items/details?Category=12&Subcategory=38&Limit=10&Keyword=${encodeURIComponent(pack)}${creator}`)
    const hit = res.ok && (await res.json()).data?.[0]
    if (hit) return hit.id
  }
  throw new Error(`No animation pack found for "${pack}". Try the number in the pack's roblox.com/bundles/<id> link.`)
}

const { version } = JSON.parse(fs.readFileSync(path.join(here, 'package.json'), 'utf8'))
const server = new McpServer({ name: 'eclipse-animator', title: 'Eclipse Animator', version }, {
  instructions: `Eclipse Animator MCP makes Roblox animations in the open Roblox Studio place. Many users do not code: talk simply, avoid jargon, and do the steps for them.
- Start with list_rigs to find the rig and its animatable parts.
- After creating or changing an animation, call preview_animation so the user sees it move in the viewport, then ask if they want changes.
- Animations are saved in the rig's AnimSaves folder; the user opens them in Eclipse Animator to polish. Saving under an existing name replaces it (Ctrl+Z in Studio undoes), so pick new names unless asked to replace.
- Pose rot is in degrees around the joint's own axes, which differ between rigs: read an existing animation with get_animation to learn them, and check with preview_animation.
- Bone rigs (list_rigs shows bones, e.g. a phoenix or dragon): key bones by name like parts. A bone's rot and pos are in its own axes, often nothing like the world's: read an existing animation with get_animation first, and preview before building a whole clip.
- R6 rigs (list_rigs shows r6: true): use the R6 kit. Read r6_guide (overview, then posing) once per task. Reference first: study_animation on a similar existing animation before posing. Author with save_r6_animation (named angles + short slides, smooth weighted timing) and fix its audit notes until clean. Ready combat/movement clips: import_r6_kit. An R6 animation that looks stiff or floaty: smooth_r6_animation.`,
})

server.registerTool('list_rigs', {
  title: 'List rigs',
  annotations: { readOnlyHint: true, openWorldHint: false },
  description: 'List animatable rigs in Workspace: their animatable parts, their bones (skinned creatures: wings, tails, spines; parents first) and their animations (AnimSaves, which Eclipse Animator lists and opens, plus any kept directly in the model).',
}, text('list_rigs'))
server.registerTool('get_animation', {
  title: 'Read animation',
  annotations: { readOnlyHint: true, openWorldHint: false },
  description: 'Read a saved animation as JSON keyframes (same shape save_animation takes).',
  inputSchema: { rig, name: z.string() },
}, text('get_animation'))
server.registerTool('save_animation', {
  title: 'Save animation',
  annotations: { destructiveHint: true, idempotentHint: true, openWorldHint: false },
  description: 'Create an animation from keyframes and save it into the rig\'s AnimSaves so it opens in Eclipse Animator. Replaces an animation with the same name.',
  inputSchema: { rig, name: z.string().min(1), ...animation },
}, text('save_animation'))
server.registerTool('preview_animation', {
  title: 'Preview animation',
  annotations: { readOnlyHint: true, openWorldHint: false },
  description: 'Play a saved animation on the rig in the Studio viewport (no playtest needed), then return the rig to its rest pose.',
  inputSchema: { rig, name: z.string(), seconds: z.number().min(1).max(60).optional().describe('How long to play. Default 6.') },
}, text('preview_animation'))
server.registerTool('enhance_animation', {
  title: 'Enhance animation',
  annotations: { destructiveHint: true, idempotentHint: true, openWorldHint: false },
  description: 'Make an animation feel more alive: bigger poses, smooth easing, overshoot-and-settle on big moves, seamless loop. Saves the result as a new animation. For R6 rigs prefer smooth_r6_animation, which follows the R6 kit\'s timing.',
  inputSchema: {
    rig, name: z.string().describe('Animation to enhance.'),
    new_name: z.string().optional().describe('Default "<name> Enhanced".'),
    exaggerate: z.number().min(0.5).max(2).optional().describe('Pose strength. 1 = unchanged, default 1.15.'),
    ease: z.boolean().optional().describe('Turn linear moves into smooth ease-in-out. Default true.'),
    overshoot: z.number().min(0).max(0.5).optional().describe('How far big moves swing past their target before settling. Default 0.15.'),
    speed: z.number().min(0.25).max(4).optional().describe('Playback speed. Default 1.'),
    fix_loop: z.boolean().optional().describe('For looping animations, make every part end where it starts. Default true.'),
  },
}, async ({ rig, name, new_name, fix_loop, ...options }) => {
  const anim = await call('get_animation', { rig, name })
  const better = enhance(anim, { ...options, fixLoop: fix_loop })
  return reply(await call('save_animation', { rig, name: new_name || `${name} Enhanced`, ...better }))
})
server.registerTool('import_animation_pack', {
  title: 'Import animation pack',
  annotations: { destructiveHint: true, idempotentHint: true, openWorldHint: true },
  description: 'Copy a Roblox animation pack (idle, walk, run, jump...) or a single animation onto the rig, adapting it when the rig is a different body type (e.g. an R15 pack onto an R6 rig). Saves each animation into AnimSaves.',
  inputSchema: { rig, pack: z.string().describe('Pack name (e.g. "Ninja", "Stylish", "Robot"), a roblox.com/bundles link, a bundle ID, or an animation asset ID.') },
}, async ({ rig, pack }) => reply(await call('import_pack', { rig, id: await findPack(pack) }, 300)))
server.registerTool('video_to_animation', {
  title: 'Animation from video',
  annotations: { destructiveHint: true, idempotentHint: true, openWorldHint: false },
  description: 'Turn a video of a person moving into an animation on the rig (body tracking with MediaPipe). Best with one person, whole body visible, steady camera, a few seconds long.',
  inputSchema: {
    rig, video_path: z.string().describe('Path to a video file on this computer (mp4, mov...).'),
    name: z.string().min(1),
    loop: z.boolean().optional(),
    fps: z.number().min(5).max(60).optional().describe('Keyframes per second. Default 30.'),
    start: z.number().min(0).optional().describe('Start time in seconds. Default 0.'),
    end: z.number().min(0).optional().describe('End time in seconds. Default: end of video.'),
  },
}, async ({ rig, video_path, name, loop, fps = 30, start = 0, end = 0 }) => {
  const frames = await videoFrames(video_path, fps, start, end)
  return reply(await call('retarget', { rig, name, loop, frames }, 120))
})

// R6 kit (github.com/VuxSussy/ultimate-r6-animation-design, vendored in plugin/R6 and r6-guide)
const KIT = ["Stance","Jab","Cross","Hook","Uppercut","Kick","DashForward","DashBack","DashLeft","DashRight","Block","HitLight","HitHeavy","Idle","Walk","Run","Climb","Jump","Fall","Land","LandShort","LandLong","WallRunRight","WallRunLeft"]
const GUIDE = path.join(here, 'r6-guide')
const TOPICS = ['overview', ...fs.readdirSync(path.join(GUIDE, 'references')).filter(f => f.endsWith('.md')).map(f => f.slice(0, -3))]
const guideFile = topic => path.join(GUIDE, topic === 'overview' ? 'SKILL.md' : path.join('references', topic + '.md'))
const GUIDE_NOTE = `> In Eclipse Animator MCP the kit runs inside the Studio plugin. Where this guide says:
> R6Clip keys / clip:bake() / R6Quality.audit -> save_r6_animation (it bakes, audits and saves; fix the audit notes and save again)
> lune run study / --keys / --fit -> study_animation (frames / fit)
> CombatMoves.build() / Locomotion.build() -> import_r6_kit
> a clip that glides or stops at every key -> smooth_r6_animation
> R15 pack onto R6 -> import_animation_pack
> Lune-only tools (mocap, compare, house, pack, check) are not available here; say so when the guide asks for them.

`

const angle = z.number().optional()
const r6Entry = z.looseObject({
  lean: angle, twist: angle, tilt: angle, nod: angle, turn: angle, raise: angle, spread: angle, swing: angle,
  pos: z.object({ forward: z.number().optional(), up: z.number().optional(), right: z.number().optional() }).optional()
    .describe('Studs. Torso: body against the root (drop, lunge). Limb/head: slide out of the socket (arms <= 1.0, legs <= 1.5, head <= 0.15).'),
  space: z.literal('root').optional().describe('Legs: hang from the pelvis so a twisting torso never crosses the legs.'),
  ground: z.boolean().optional().describe('Legs: slide to keep the sole on the floor every frame.'),
  hips: z.number().optional(),
  ease: z.any().optional().describe('Overrides the key\'s ease for this part.'),
}).describe('Named angles in degrees: Torso lean/twist/tilt, Head nod/turn/tilt, limbs raise/spread/swing/twist.')
const ease = z.union([z.string(), z.record(z.string(), z.any())]).optional()
  .describe('Shapes the segment LEAVING this key: "snap", "sineInOut", "quadIn", "heavyIn", "heavyOut", "heavy", "auto", { settle: 0.1 }, { recover: 0.1 }...')

server.registerTool('r6_guide', {
  title: 'R6 animation guide',
  description: `The R6 animation design guide: how to pose, time and weight R6 animations so they hit with force instead of looking stiff or floaty. Read "overview" once per R6 task, then the topic you need (posing before keying). Topics: ${TOPICS.join(', ')}.`,
  annotations: { readOnlyHint: true, openWorldHint: false },
  inputSchema: { topic: z.enum(TOPICS).optional().describe('Default "overview".') },
}, async ({ topic = 'overview' }) => ({ content: [{ type: 'text', text: GUIDE_NOTE + fs.readFileSync(guideFile(topic), 'utf8') }] }))

server.registerTool('save_r6_animation', {
  title: 'Save R6 animation',
  annotations: { destructiveHint: true, idempotentHint: true, openWorldHint: false },
  description: 'Build an R6 animation from key poses written as named angles plus short slides (no IK), on a smooth curve through the keys with weighted timing, check it with the R6 audit (pops, hit timing, commitment, slide budgets, crossed legs, floor contact, thighs in the torso) and save it to AnimSaves. Returns the audit notes: fix them and save again until it is clean. Only for six-part R6 rigs (list_rigs shows r6: true). Read r6_guide first.',
  inputSchema: {
    rig, name: z.string().min(1),
    keys: z.array(z.object({
      frame: z.number().int().min(0).describe('60 fps.'),
      pose: z.record(z.string(), r6Entry).describe('Keyed by part: Torso, Head, RightArm, LeftArm, RightLeg, LeftLeg. Parts left out are not keyed here.'),
      ease,
    })).min(1),
    markers: z.array(z.object({ frame: z.number().int().min(0), name: z.string(), value: z.string().optional() })).optional().describe('e.g. { frame: 10, name: "Hit" }.'),
    lead: z.record(z.string(), z.number()).optional().describe('Overlap in frames per part: Torso 1 (moves first), free arm -1, Head -2 (trails).'),
    meta: z.record(z.string(), z.any()).optional().describe('For the audit and timing: limb (striking part), strike [from,to], hit, cancel, tip [x,y,z] for a weapon, stride (walk/run), airborne, impact...'),
    loop: z.boolean().optional(),
    priority: animation.priority,
    curve: z.enum(['auto', 'none']).optional().describe('auto (default): in-betweens follow a smooth curve through the keys.'),
    tension: z.number().min(0).max(1).optional().describe('How much the body slows into each key. 0 glides (floaty), 0.45 default, 1 stops at every key.'),
    weight: z.enum(['light', 'medium', 'heavy', 'none']).optional().describe('Timing contrast: slow wind-up, fast strike, slow recovery. Default medium; loops keep their timing.'),
    require_clean: z.boolean().optional().describe('Refuse to save when the audit finds problems. Default false.'),
  },
}, text('save_r6_animation', 60))

server.registerTool('study_animation', {
  title: 'Study animation',
  annotations: { readOnlyHint: true, openWorldHint: false },
  description: 'Measure a saved R6 animation to imitate it: length, chamber and hit frames, release and hold, torso twist/lean/drop/lunge at contact, how far each limb leaves its socket. With frames or fit it also returns key poses ready for save_r6_animation. Use it on reference animations before posing a new one.',
  inputSchema: {
    rig, name: z.string(),
    frames: z.array(z.number().int().min(0)).optional().describe('Return the poses at these frames (60 fps).'),
    fit: z.number().min(0.5).max(20).optional().describe('Return the fewest keys that rebuild the clip within this many degrees (e.g. 4).'),
    root_legs: z.boolean().optional().describe('Write legs on the pelvis (space root, grounded), the way save_r6_animation keys them best.'),
    tip: z.tuple([z.string(), z.number(), z.number(), z.number()]).optional().describe('Measure strikes from a weapon tip: [part, x, y, z] in that part\'s space, e.g. ["Right Arm", 0, -1, -4].'),
  },
}, text('study_animation', 60))

server.registerTool('smooth_r6_animation', {
  title: 'Smooth R6 animation',
  annotations: { destructiveHint: true, idempotentHint: true, openWorldHint: false },
  description: 'Make an existing R6 animation flow: rebuild it from its key poses on a smooth curve with weight (it surges between poses and settles into each instead of gliding or stopping at every key), audit it and save it as a new animation. Keeps the length and markers unless weight is set.',
  inputSchema: {
    rig, name: z.string().describe('Animation to smooth.'),
    new_name: z.string().optional().describe('Default "<name> Smooth".'),
    tension: z.number().min(0).max(1).optional().describe('Default 0.45.'),
    weight: z.enum(['light', 'medium', 'heavy']).optional().describe('Also stretch the wind-up and recovery (changes the length).'),
    tolerance: z.number().min(0.5).max(20).optional().describe('Degrees the rebuilt keys may differ from the original. Default 3.'),
  },
}, text('smooth_r6_animation', 60))

server.registerTool('import_r6_kit', {
  title: 'Import R6 animation kit',
  annotations: { destructiveHint: true, idempotentHint: true, openWorldHint: false },
  description: 'Put ready-made, reference-measured R6 animations on an R6 rig: combat (Stance, Jab, Cross, Hook, Uppercut, Kick, four dashes, Block, HitLight, HitHeavy) and movement (Idle, Walk, Run, Climb, Jump, Fall, three landings, wall runs). Saves each into AnimSaves with its audit.',
  inputSchema: { rig, names: z.array(z.enum(KIT)).optional().describe('Default: all 24.') },
}, text('import_r6_kit', 180))

for (const topic of TOPICS) {
  server.registerResource(`r6-guide-${topic}`, `r6-guide://${topic}`, { title: `R6 guide: ${topic}`, mimeType: 'text/markdown' },
    async uri => ({ contents: [{ uri: uri.href, text: fs.readFileSync(guideFile(topic), 'utf8') }] }))
}

const prompt = (name, title, description, argsSchema, body) =>
  server.registerPrompt(name, { title, description, argsSchema }, args => ({ messages: [{ role: 'user', content: { type: 'text', text: body(args) } }] }))
prompt('animate', 'Make an animation', 'Describe a move in your own words and get it on your rig.', { idea: z.string() },
  ({ idea }) => `Using the eclipse-animator tools, make this animation on my rig: ${idea}. Find the rig with list_rigs, build it with save_animation (on an R6 rig: read r6_guide and use save_r6_animation), show it with preview_animation, then ask me what to change. Reply in my language, simply.`)
prompt('enhance', 'Enhance an animation', 'Make an existing animation smoother and more alive.', { animation: z.string() },
  ({ animation }) => `Using the eclipse-animator tools, enhance my animation "${animation}" with enhance_animation (smooth_r6_animation if the rig is R6), preview the result, and tell me simply what changed. Reply in my language.`)
prompt('from_video', 'Animation from a video', 'Copy a person\'s movement from a video file.', { video_path: z.string() },
  ({ video_path }) => `Using the eclipse-animator tools, turn the video at ${video_path} into an animation on my rig with video_to_animation, preview it, and offer to enhance it. Reply in my language, simply.`)
prompt('from_pack', 'Use an animation pack', 'Put a Roblox animation pack (Ninja, Stylish, Robot...) on your rig.', { pack: z.string() },
  ({ pack }) => `Using the eclipse-animator tools, import the "${pack}" animation pack onto my rig with import_animation_pack, preview one of the animations, and list what was added. Reply in my language, simply.`)

await server.connect(new StdioServerTransport())
