// Builds the Studio plugin model (.rbxmx): the Script, with the R6 kit's ModuleScripts in a Folder under it.
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const here = path.dirname(fileURLToPath(import.meta.url))

export function pluginModel() {
  let ref = 0
  const cdata = s => '<![CDATA[' + s.replaceAll(']]>', ']]]]><![CDATA[>') + ']]>'
  const item = (cls, name, source, children = '') => `<Item class="${cls}" referent="${ref++}"><Properties><string name="Name">${name}</string>` +
    (source === null ? '' : `<ProtectedString name="Source">${cdata(source)}</ProtectedString>`) + `</Properties>${children}</Item>`
  const modules = fs.readdirSync(path.join(here, 'R6')).filter(f => f.endsWith('.luau')).sort()
    .map(f => item('ModuleScript', f.slice(0, -5), fs.readFileSync(path.join(here, 'R6', f), 'utf8'))).join('')
  const main = fs.readFileSync(path.join(here, 'EclipseAnimatorMCP.server.luau'), 'utf8')
  return '<roblox version="4">' + item('Script', 'EclipseAnimatorMCP', main, item('Folder', 'R6', null, modules)) + '</roblox>'
}
