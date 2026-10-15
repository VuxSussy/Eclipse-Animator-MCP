// One-step setup: Studio plugin, Claude Desktop / Claude Code config, video tools. Run: node setup.js
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { execFileSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'

const here = path.dirname(fileURLToPath(import.meta.url))
const home = os.homedir()
const win = process.platform === 'win32'
const has = (cmd, flag = '--version') => { try { execFileSync(cmd, [flag], { stdio: 'ignore' }); return true } catch { return false } }
// the stable PATH node, not the versioned binary a package manager upgrade would remove
const node = win ? process.execPath : execFileSync('sh', ['-c', 'command -v node']).toString().trim() || process.execPath
const entry = { command: node, args: [path.join(here, 'server.js')] }

const plugins = win ? path.join(process.env.LOCALAPPDATA, 'Roblox', 'Plugins') : path.join(home, 'Documents', 'Roblox', 'Plugins')
fs.mkdirSync(plugins, { recursive: true })
const source = fs.readFileSync(path.join(here, 'plugin', 'EclipseAnimatorMCP.server.luau'), 'utf8').replaceAll(']]>', ']]]]><![CDATA[>')
fs.writeFileSync(path.join(plugins, 'EclipseAnimatorMCP.rbxmx'), '<roblox version="4"><Item class="Script" referent="0"><Properties><string name="Name">EclipseAnimatorMCP</string><ProtectedString name="Source"><![CDATA[' + source + ']]></ProtectedString></Properties></Item></roblox>')
fs.rmSync(path.join(plugins, 'EclipseAnimatorMCP.lua'), { force: true }) // older installs
console.log('✓ Roblox Studio plugin installed')

const desktop = win ? path.join(process.env.APPDATA, 'Claude') : path.join(home, 'Library', 'Application Support', 'Claude')
if (fs.existsSync(desktop)) {
  const file = path.join(desktop, 'claude_desktop_config.json')
  const config = fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, 'utf8')) : {}
  if (fs.existsSync(file)) fs.copyFileSync(file, file + '.bak')
  config.mcpServers = { ...config.mcpServers, 'eclipse-animator': entry }
  fs.writeFileSync(file, JSON.stringify(config, null, 2))
  console.log('✓ Added to Claude Desktop')
}
if (has('claude')) {
  try { execFileSync('claude', ['mcp', 'remove', 'eclipse-animator', '--scope', 'user'], { stdio: 'ignore' }) } catch {}
  execFileSync('claude', ['mcp', 'add', 'eclipse-animator', '--scope', 'user', '--', entry.command, ...entry.args], { stdio: 'ignore' })
  console.log('✓ Added to Claude Code')
}

if (has('uv') && has('ffmpeg', '-version')) {
  console.log('… Preparing video import (first time takes a minute)')
  execFileSync('uv', ['run', '--quiet', '--with', 'mediapipe', 'python', '-c', 'import mediapipe'], { stdio: 'inherit' })
  console.log('✓ Video import ready')
} else {
  console.log('! Video import needs uv and ffmpeg. Install them, then run setup again:')
  console.log(win ? '    winget install astral-sh.uv Gyan.FFmpeg' : '    brew install uv ffmpeg')
}

console.log('\nDone. Restart Roblox Studio and Claude. In Studio, click Allow when the plugin asks about HTTP requests.')
