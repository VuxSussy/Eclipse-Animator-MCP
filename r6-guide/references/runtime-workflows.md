# Runtime and conversion workflows


| Path | What it is | Runs in |
|---|---|---|
| `scripts/R6Rig.luau` | joint table, named angles, FK, slide (`gap`) and budgets (`GAP`), springs | Studio, game, Lune |
| `scripts/Ease.luau` | timing curves: snap, settle, recover, back, elastic, bezier, Roblox pose easing | everywhere |
| `scripts/Sequence.luau` | read/evaluate/measure any KeyframeSequence (R6, R15, custom) | everywhere |
| `scripts/R6Study.luau` | measure an R6 clip for imitation: strike line, torso commit, socket slides | everywhere |
| `scripts/R6Clip.luau` | build clips from key poses, bake, thin, export, **audit** | everywhere |
| `scripts/CombatMoves.luau` | 13 ready clips with gameplay numbers (`references/combat.md`) | everywhere |
| `scripts/Locomotion.luau` | Idle, Walk, Run, Climb, Jump, Fall, Land / LandShort / LandLong (movement system), WallRunRight/Left (Creator Store parkour pack) | everywhere |
| `scripts/R6Locomotion.luau` | client driver: wall run, landings, climb, jump/fall, idle/walk/run/Stance from the real state and speed | client |
| `scripts/R6WallRun.luau` | a small client wall run that drives the WallRunLeft/Right clips (tune the gameplay yourself) | client |
| `scripts/R15ToR6.luau` | R15 → R6 through body points, with limb slides (offline or sampled in Studio) | everywhere |
| `scripts/R6Combat.luau` | client combat animator: string, buffer, cancels, dash burst, block, hit-stop | client (+ server query) |
| `tools/` | Lune: `study` (measure a file), `check` (192 tests), `build` (pack + preview), `convert` (R15 → R6), `studio_place` | terminal |

All modules are ModuleScripts that `require(script.Parent.X)` each other. Put them in one folder,
for example `ReplicatedStorage.R6Animation`. Run the tools from `tools/` (`lune` and `selene` come
from `rokit.toml` there).


## R15 → R6

`R15ToR6` plays the R15 clip into body points, takes the torso from the shoulder line over the
hips, copies the head, points each limb at the R15 fist or sole and **slides** it (arm 0.8, leg 1.5)
so the fist and sole land on the R15 ones. Offline: `lune run convert <file> <outDir> [clips]`; in
Studio: `R15ToR6.sampleInStudio` → `convertSampled`; whole packs: `eclipse-animator`
`import_animation_pack`. R15 is a third-choice reference: look for an R6 version first.
`references/r15-to-r6.md`.

## Locomotion quick start

`Locomotion.build()` gives Idle, Walk, Run, Climb, Jump, Fall, Land, LandShort, LandLong,
WallRunRight, WallRunLeft, each rebuilt from an R6 reference (`reference-first.md` §4: the movement system's
clips, and the Creator Store "R6 Parkour Animations" wall run). `R6Locomotion.new(character, {
animations = {...} })` picks the clip from the real state, in this order:
- wall run while `R6WallRun` holds a wall (airborne, fast, a wall at one side; jump kicks off)
- a landing after a fall, by the height fallen since Freefall began (movement system): under 4 studs Land,
  4-15 LandShort, over 15 LandLong
- Climb at vertical speed / 12 (paused when the climber stops)
- Jump on take-off, then Fall
- on the ground: Idle (or the guard Stance for 3 s after `loco:combat()`), Walk at speed / 14.5
  (reversed backwards), Run at 1.3 once `WalkSpeed` ≥ 20 (movement system: walk 12, Shift sprint 27)

`loco:setAnimation("Idle", clip)` swaps a state's clip at runtime (a weapon's guard when a weapon
is drawn). Several movesets on one character: one `R6Combat` per moveset (e.g. fists and sword,
`config = { combo = { "SwordSlash" } }`), route input to the active one, or the fist string
plays over the weapon's clip. `lune run studio_place <out.rbxl> ../../sword/SwordMoves.luau` builds
the test place with a Fists / Sword toggle (button or key 1).
Give `R6Combat` `config = { idle = false }`, and put an empty LocalScript named `Animate` in
StarterCharacterScripts (Roblox's default Animate plays its own walk and stops every track when it
starts). Walks, runs, falls and wall runs pass their legs on purpose: their meta has
`stride = true`, so the audit checks crossed legs only from the front.

## Combat quick start

`CombatMoves.build()` gives 13 baked clips: Stance, Jab, Cross, Hook, Uppercut, Kick, four dashes,
Block, HitLight, HitHeavy. `R6Combat.new(character, { animations = ..., moves =
R6Combat.movesFrom(CombatMoves), onHit = ... })` gives `attack()`, `dash(dir)`, `block(on)`,
`react(heavy)`, timed from the clips' markers; the server decides hits (`R6Combat.query`).
`references/combat.md`.

