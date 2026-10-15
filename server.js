#!/usr/bin/env node
// Eclipse Animator MCP: stdio MCP server + a localhost bridge the Studio plugin long-polls.
import http from 'node:http'
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js'
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js'
import { z } from 'zod'

const PORT = Number(process.env.ECLIPSE_MCP_PORT) || 44755
const TIMEOUT = 30000
const queue = []
const pending = new Map()
let waiter = null // the plugin's open /poll request, if any
let nextId = 1

function send(tool, args) {
  const cmd = { id: nextId++, tool, args }
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      pending.delete(cmd.id)
      const i = queue.indexOf(cmd)
      if (i >= 0) queue.splice(i, 1) // never run a command the caller already gave up on
      reject(new Error('Roblox Studio did not answer in 30s. Is Studio open with the Eclipse Animator MCP plugin installed?'))
    }, TIMEOUT)
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
  res.writeHead(404).end()
})
// shortcut: one bridge per port, so a second MCP instance can't reach Studio; set ECLIPSE_MCP_PORT per instance if you ever need two.
bridge.on('error', e => console.error(`[eclipse-animator-mcp] bridge on port ${PORT} failed: ${e.message}`))
bridge.listen(PORT, '127.0.0.1')

const text = tool => async args => ({ content: [{ type: 'text', text: JSON.stringify(await send(tool, args), null, 1) }] })

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
    poses: z.record(z.string(), pose).describe('Keyed by the part a Motor6D drives (e.g. "Head", "RightUpperArm"). Unlisted parts are not keyed at this time.'),
  })).min(1),
}
const rig = z.string().describe('Rig full name from list_rigs (e.g. "Workspace.Rig") or just its Name.')

const server = new McpServer({ name: 'eclipse-animator', version: '0.1.0' })
server.registerTool('list_rigs', {
  description: 'List animatable rigs in Workspace: their animatable parts (Motor6D Part1 names) and the animations saved in their AnimSaves folder, which Eclipse Animator lists and opens.',
}, text('list_rigs'))
server.registerTool('get_animation', {
  description: 'Read a KeyframeSequence from a rig\'s AnimSaves as JSON keyframes (same shape save_animation takes).',
  inputSchema: { rig, name: z.string() },
}, text('get_animation'))
server.registerTool('save_animation', {
  description: 'Write a KeyframeSequence into a rig\'s AnimSaves so it can be opened in Eclipse Animator. Replaces an animation with the same name (undoable with Ctrl+Z in Studio).',
  inputSchema: { rig, name: z.string().min(1), ...animation },
}, text('save_animation'))

await server.connect(new StdioServerTransport())
