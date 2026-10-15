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
  assert.deepEqual(tools.map(t => t.name).sort(), ['get_animation', 'list_rigs', 'save_animation'])

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
