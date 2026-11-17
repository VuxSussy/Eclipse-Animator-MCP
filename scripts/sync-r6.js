#!/usr/bin/env node
// Copies the R6 animation kit from github.com/VuxSussy/ultimate-r6-animation-design into this repo:
// the Luau modules into plugin/R6 (they run inside the Studio plugin) and the guide into r6-guide.
// Run: npm run sync-r6 [path/to/local/clone]
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { execFileSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'

const here = path.dirname(path.dirname(fileURLToPath(import.meta.url)))
const REPO = 'https://github.com/VuxSussy/ultimate-r6-animation-design'
export const MODULES = ['R6Rig', 'Ease', 'Sequence', 'R6Clip', 'R6Collision', 'R6Quality', 'R6Study', 'CombatMoves', 'Locomotion']
// English stand-ins for the few non-English lines upstream
const PHRASES = [['"nhanh qu\u00e1, m\u01b0\u1ee3t qu\u00e1"', '"too fast, too smooth"'], ['("ch\u01b0a m\u01b0\u1ee3t, kh\u00f4ng c\u00f3 curve")', '("not smooth yet, no curve")']]
const NON_ENGLISH = /[\u0103\u00e2\u0111\u00ea\u00f4\u01a1\u01b0\u1ea1\u1ea3\u1ea5\u1ea7\u1ea9\u1eab\u1ead\u1eaf\u1eb1\u1eb3\u1eb5\u1eb7\u1eb9\u1ebb\u1ebd\u1ebf\u1ec1\u1ec3\u1ec5\u1ec7\u1ec9\u1ecb\u1ecd\u1ecf\u1ed1\u1ed3\u1ed5\u1ed7\u1ed9\u1edb\u1edd\u1edf\u1ee1\u1ee3\u1ee5\u1ee7\u1ee9\u1eeb\u1eed\u1eef\u1ef1\u1ef3\u1ef5\u1ef7\u1ef9]/i

let src = process.argv[2]
let tmp
if (!src) {
  tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'r6-'))
  execFileSync('git', ['clone', '--depth', '1', '--quiet', REPO, tmp], { stdio: 'inherit' })
  src = tmp
}
const skill = path.join(src, 'ultimate-r6-animation-design')
const commit = execFileSync('git', ['-C', src, 'rev-parse', 'HEAD']).toString().trim()

fs.mkdirSync(path.join(here, 'plugin', 'R6'), { recursive: true })
for (const m of MODULES) fs.copyFileSync(path.join(skill, 'scripts', m + '.luau'), path.join(here, 'plugin', 'R6', m + '.luau'))

const guide = path.join(here, 'r6-guide')
fs.mkdirSync(path.join(guide, 'references'), { recursive: true })
const docs = [['SKILL.md', 'SKILL.md'], ...fs.readdirSync(path.join(skill, 'references')).map(f => [path.join('references', f), path.join('references', f)])]
for (const [from, to] of docs) {
  let text = fs.readFileSync(path.join(skill, from), 'utf8')
  for (const [a, b] of PHRASES) text = text.replaceAll(a, b)
  if (NON_ENGLISH.test(text)) {
    const translated = path.join(guide, 'translations', path.basename(to))
    if (!fs.existsSync(translated)) { console.warn('! ' + from + ' is not in English and has no translation in r6-guide/translations: skipped'); continue }
    text = fs.readFileSync(translated, 'utf8')
  }
  fs.writeFileSync(path.join(guide, to), text)
}
fs.writeFileSync(path.join(guide, 'SOURCE.txt'), REPO + ' @ ' + commit + '\n')
if (tmp) fs.rmSync(tmp, { recursive: true, force: true })
console.log('✓ R6 kit synced from ' + commit.slice(0, 7))
