// End-to-end bridge check: real MCP client -> server.js -> fake Studio plugin over HTTP.
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { Client } from '@modelcontextprotocol/sdk/client/index.js'
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js'

const PORT = '44799'
const URL = `http://127.0.0.1:${PORT}`

test('tool call round-trips through the Studio bridge', async () => {
  const client = new Client({ name: 'test', version: '0' })
  await client.connect(new StdioClientTransport({ command: process.execPath, args: ['server.js'], env: { ...process.env, ECLIPSE_MCP_PORT: PORT } }))
  const { tools } = await client.listTools()
  assert.deepEqual(tools.map(t => t.name).sort(), ['enhance_animation', 'get_animation', 'import_animation_pack', 'list_rigs', 'preview_animation', 'save_animation', 'video_to_animation'])

  // fake plugin: answer one command successfully, one with an error
  const plugin = (async () => {
    for (const answer of [{ ok: true, result: [{ rig: 'Workspace.Rig' }] }, { ok: false, error: 'rig not found: Nope' }]) {
      let res
      do res = await fetch(`${URL}/poll`).catch(() => null); while (!res || res.status !== 200)
      const cmd = await res.json()
      await fetch(`${URL}/result`, { method: 'POST', body: JSON.stringify({ id: cmd.id, ...answer }) })
    }
  })()

  const ok = await client.callTool({ name: 'list_rigs', arguments: {} })
  assert.deepEqual(JSON.parse(ok.content[0].text), [{ rig: 'Workspace.Rig' }])
  const bad = await client.callTool({ name: 'get_animation', arguments: { rig: 'Nope', name: 'Walk' } })
  assert.equal(bad.isError, true)
  assert.match(bad.content[0].text, /rig not found/)
  await plugin
  await client.close()
})

test('a second MCP instance on the same port relays through the first', async () => {
  const start = async () => {
    const c = new Client({ name: 'test', version: '0' })
    await c.connect(new StdioClientTransport({ command: process.execPath, args: ['server.js'], env: { ...process.env, ECLIPSE_MCP_PORT: PORT } }))
    return c
  }
  const first = await start()
  const second = await start() // its port is taken, so it must relay
  const plugin = (async () => {
    let res
    do res = await fetch(`${URL}/poll`).catch(() => null); while (!res || res.status !== 200)
    const cmd = await res.json()
    await fetch(`${URL}/result`, { method: 'POST', body: JSON.stringify({ id: cmd.id, ok: true, result: cmd.tool }) })
  })()
  const out = await second.callTool({ name: 'list_rigs', arguments: {} })
  assert.equal(JSON.parse(out.content[0].text), 'list_rigs')
  await plugin
  await second.close()
  await first.close()
})
