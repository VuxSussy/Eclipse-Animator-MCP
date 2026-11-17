---
name: ultimate-r6-animation-design
description: Create, repair, convert and preview Roblox R6 animations, weapon combos and movement packs. Uses measured references, keyed angles and short limb slides without IK; validates timing, body commitment, joints, legs and export. Applies to six-part rigs, KeyframeSequences and AnimSaves, including R15-to-R6 conversion.
description: 'Ultimate R6 Animation Design. Build, fix, convert and run Roblox R6 animations that hit with force instead of looking stiff, plastic or timid. Reference first: find the same move already made for R6 (the user''s files, Creator Store packs, video), measure it with the bundled study tool and imitate it; for a move the kit has never made (a mage cast, a staff spin, a summon, a bow, a dance) run a research ladder through Creator Store packs, Roblox emotes, free human motion capture converted to R6 with Blender, video and the user acting it out, before posing anything. Poses are keyed angles plus short slides of the limbs out of the torso (no IK, no FK/IK solver), legs hang from a pelvis so they never cross, and an audit checks pops, hit timing, commitment, slide budgets, crossed legs and floor contact. Also R15 to R6 conversion and a combat kit (dash, jab, cross, hook, uppercut, kick, block, hit reactions, combos, hit-stop) with a 3D preview. Use it whenever someone animates an R6 rig (Torso, Left Arm, Right Leg...): a punch, kick, dash, combo, idle, walk, run, emote, spell, cast, magic, mage, summon, staff, bow, dance; an animation that looks stiff, robotic, plastic, cramped or weak; weight, timing, easing; requests for IK or FK on R6; turning an R15 animation into R6; KeyframeSequences, AnimSaves, Moon Animator or Eclipse Animator work; or a battlegrounds-style combat system. Use it even when "R6" is not said but the rig has six parts.'
---

# Ultimate R6 Animation Design

Build expressive R6 motion from references, then prove the exported result. R6 has no elbows,
knees or spine: key named joint angles plus short `pos` slides. Do not introduce IK aims,
planted-leg solvers or a procedural FK/IK system.

## Route once

Read this entrypoint once per task; retain a short working brief. Open only relevant sections
of references. Re-read when the source changes, context is lost or a failure needs detail.

| Need | Read when needed |
| --- | --- |
| Find/measure a source; fallback grammar | [reference-first.md](references/reference-first.md), §§1–5; measured tables §6 |
| First-time posing, unfamiliar angle/space or slide issue | [posing.md](references/posing.md), §§1–4 |
| Timing, weight or an animation that feels weak | [weight-and-feel.md](references/weight-and-feel.md), relevant section |
| Heavy sword / greatsword | [heavy-weapons.md](references/heavy-weapons.md) before keying; mass/overswing/recovery and phase-dependent grip |
| Weapon attack | [combat.md](references/combat.md), §§1, 8–9 |
| Mage casting | [staff-casting.md](references/staff-casting.md) before keying; actual casting footage required |
| Runtime combat/locomotion, service wiring | [runtime-workflows.md](references/runtime-workflows.md); [combat.md](references/combat.md) §§3–7 |
| R15 conversion | [r15-to-r6.md](references/r15-to-r6.md) |
| Thigh hidden inside torso, crouch/tuck artifacts | [body-clearance.md](references/body-clearance.md) |
| First clip example | [authoring-example.md](references/authoring-example.md) |
| A known failure or nonstandard weapon joint | [troubleshooting.md](references/troubleshooting.md) |
| Provenance | [sources.md](references/sources.md) |
| Reusable pack commands/schema | [pack-tools.md](references/pack-tools.md) |

## Reference before poses

Search in order: user files/AnimSaves, Creator Store R6 clips, converted R15, R6 video.
Use the first suitable accessible source; strip every script from third-party models before
parenting. A listing is discovery, not a measured or viewed reference. When none is accessible,
use the user's R6 movement grammar and explicitly document the fallback and adaptations.
For spellcasting and heavy weapons, also watch footage of that exact action/archetype before posing.
Save URLs, timestamps and observed load/strike/follow-through/recovery; a listing or unrelated slash cannot satisfy this step. See the corresponding route.

Measure sources with `tools/measure.luau` (compact output, complete report saved), or `study`
for key extraction/fitting. Keep a brief: source and content fingerprint, selected clips, rig/grip,
intent, load/hit/release/hold frames, torso twist/lean/drop/lunge, limb slides and tip reach.
Reuse a saved measurement only while the source fingerprint, selection, tool versions and grip
match. A source for a slash does not establish two-hand grip or heavy-sword timing: state those
adaptations and verify them independently. Compare generated measurements to the source;
explain deviations from its strike proportions, ~20% torso range or ~0.5-stud tip placement.

## Authoring invariants

- Space: +X right, +Y up, −Z forward; standing floor y=−3 relative to HumanoidRootPart.
- Named angles: torso lean/twist/tilt, head nod/turn/tilt; limbs raise/spread/swing/twist.
  `pos={forward,up,right}` slides in the parent. Head should stay on the neck.
- Arms ≤1.0 stud, legs ≤1.5, head ≤0.15 by default. Increase budgets only for an explicit user
  preference or a measured source, explaining the exception. Never relax a check merely to pass.
- Legs use `space="root"` on the pelvis (default hips=0.35); grounded support uses `ground=true`.
  Keep legs apart and uncrossed. Do not telescope a visible thigh into the torso to fake a knee bend;
  use a shallower stance when necessary. Use `meta.stride` only for actual passing footwork.
- Key guard → preparation/load → release → contact → readable hold → follow-through/recovery.
  Adapt the preparation to the technique: a thrust need not have a sword-swing wind-up.
- Easing shapes the segment **leaving** a key. Named angles interpolate as numbers. For swords,
  accelerate with `quadIn` into contact; a long blade amplifies speed. Head/free arm may trail;
  two hands holding one weapon must remain on the grip during declared gripping phases. A heavy style may intentionally release/regrip; require explicit windows and markers.
- No pops outside declared strike/Snap windows. Hit should agree with the visible tip within
  2 frames, hold 4–6+ readable frames and normally occur 20–50% through the move.
  Straight punches need body commitment (reference reach 2.3–4.2 studs, torso turn 30–110°);
  weapon/casting moves use their own measured geometry and contact/aim tests.
- Raw rotations and runtime fades take the shortest path; avoid >180° transitions. Match combo
  endpoints. Never key HumanoidRootPart for travel; gameplay owns root movement.
- For fixed grip, `meta.tip` must describe the actual blade point in arm space. A separately
  animated weapon needs its own exported channel and geometry checks; six-body-joint audit
  alone cannot validate that weapon. Keep all intentional overhead exceptions explicit.

## Build, verify, look

Prefer the reusable `tools/pack.luau` for fixed-grip packs. Supply a move provider/configuration;
do not rewrite a builder, renderer or playtest harness for every combo. Use an adapter when a
rig genuinely needs extra joints, preserving the same quality gates.

Required: every new clip passes **`R6Quality.audit`** (original motion audit plus oriented
thigh/torso clearance on every frame, with actual body sizes for custom rigs); study agrees with the reference or documented
adaptations; marker times/order, combo seams, actual weapon tip, slide budgets and export round
trip pass. For two-hand weapons measure off-hand/grip distance throughout gripping phases and verify declared release/regrip transitions. Heavy weapons also need visible load, full overswing and recovery; use the heavy-specific route, not merely slower katana timing. Inspect front,
side and full-speed movement. A numeric PASS with bad visuals is unfinished.

Run `lune run check`, `lune run check_quality` and Selene on the skill modules once for the unchanged tool version in a
task. Lint new modules/harnesses too. After edits, re-run affected checks; broaden to the full
suite when shared math/export changes or failures justify it. Do not skip mandatory gates.

When Studio is accessible, play/pose a real R6 rig and read tip/soles at markers. Lock player
controls for measurements. Use `pack_demo` for an existing pack instead of recreating a harness.
If access fails, inspect the blocker and make one relevant recovery attempt; avoid repeated
unchanged timeouts or closing unrelated user work. Save the demo and state that engine testing
is unconfirmed. Only real engine results justify “playtest passed”. Registration IDs are Studio
local; a published game needs uploaded AnimationIds.

## Context and delivery

Default tool output is status, relevant numbers, errors and artifact paths. Full measurements,
code, frames and logs stay on disk; open only the section needed to resolve a decision/failure.
Use `--verbose` deliberately. Keep source search, pose work, export and tests scoped to the request.

For an animation pack, deliver the clips/combo, usable rig/grip instructions, preview and concise
validation/provenance. Reuse a demo when needed to verify or when requested. Do not add a combat
controller, networking, damage system or additional effects unless needed or requested.
Report source/fallback, hit/hold/hit-stop, reach/body commitment, largest slides, audit and what
was actually seen/tested. Save detailed numbers in the pack; keep the user-facing reply concise.
R6 is six blocks on six Motor6Ds: no elbows, no knees, no spine. Force on R6 comes from timing,
from the torso committing to the move, and from limbs **sliding a short way out of their sockets**
(a shoulder thrown into a punch, a leg riding up into the torso as the body drops). This skill
works in four rules:

1. **Reference first.** Before posing anything, look for the same move already made for R6, measure
   it, and imitate it (`references/reference-first.md`). A move the kit has never made is a
   research job: go down the whole source ladder in `references/new-moves.md` (R6 packs, Roblox
   emotes, human mocap through `lune run mocap`, video, the user acting it out) and never start
   from the kit's punches and walks.
2. **No IK, no FK/IK system.** A clip is exactly the poses you key: named angles plus `pos`
   slides. The first version of this skill used IK aims and planted-leg solving; the user found the
   result cramped and timid, so it was removed. (`references/posing.md`)
3. **The house body, always.** Whatever the move and wherever its reference came from, the body
   moves the way the user's R6 movement system moves it (the house grammar): how far it drops and
   leans, which leg takes the depth, where the feet stand, where the face looks. Its numbers live
   in `R6Clip.HOUSE`, the audit holds every clip to them, and `lune run house <movement-system.rbxm>
   <yours.rbxm>` puts any clip next to them. A reference (an R15 clip, mocap, a pack) gives the
   move's content and timing; where its body disagrees with the house, the house wins.
4. **Numbers, then eyes.** Every clip is audited (pops, hit timing, holds, commitment, slide
   budgets, crossed legs, floor contact), measured against its reference, and looked at.

## What is bundled

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
| `scripts/MocapToR6.luau` | human motion capture (body points from Blender) → R6: arms along the human's, each foot on the human's foot, legs from a square pelvis riding straight up for knees | everywhere |
| `scripts/R6Combat.luau` | client combat animator: string, buffer, cancels, dash burst, block, hit-stop | client (+ server query) |
| `tools/` | Lune: `study` (measure a file), `mocap` (FBX/BVH/GLB/.blend → R6 reference, via Blender and `mocap_points.py`, with a hands-and-feet table against the human), `compare` (your clip vs its reference: limb directions, fist/foot travel, torso), `house` (any clip next to the house grammar's body ranges), `check` (214 tests), `build` (pack + preview), `convert` (R15 → R6), `studio_place` | terminal |

All modules are ModuleScripts that `require(script.Parent.X)` each other. Put them in one folder,
for example `ReplicatedStorage.R6Animation`. Run the tools from `tools/` (`lune` and `selene` come
from `rokit.toml` there).

References, read the one that matches the job:
- `references/reference-first.md`: where to find R6 references, loading them safely, `study`,
  how to imitate, the house grammar, measured tables. **Read for every new animation.**
- `references/new-moves.md`: researching a move the kit has never made: breaking it down, search
  vocabulary, the six-tier source ladder, the reference sheet, archetype cards. **Read for any move
  that is not a punch, kick, dash, block, reaction, idle, walk, run, climb, jump, fall, landing or
  wall run.**
- `references/posing.md`: the rig, named angles, part entries, slides and budgets, legs on the
  pelvis, why there is no IK. **Read before keying.**
- `references/weight-and-feel.md`: timing, easing per segment, overlap, holds, the anti-plastic
  checklist.
- `references/combat.md`: move anatomy, the move table, combo, dash physics, hit-stop, wiring.
- `references/r15-to-r6.md`: converting and learning from R15.
- `references/sources.md`: where every number came from.

## Workflow: from a request to a clip that hits

1. **Find the reference.** New to the kit? `new-moves.md`: brief, vocabulary, the whole ladder,
   two references, a reference sheet. Otherwise (`reference-first.md` §1-2): In order: the user's files
   (`~/Downloads/*.rbxm`, rigs' `AnimSaves` in the open place), the Creator Store through Studio
   MCP (`search_assets` "R6 <move> animation", load with `game:GetObjects`, **destroy every script
   before parenting**, `export_rbxm` to the scratchpad), R15 packs converted, then video. No R6
   version anywhere: go to `new-moves.md` tiers 2-5 (emotes, mocap, video, the user acting it
   out) before falling back to the house grammar, and say which you used.
2. **Measure it.** `lune run study <file> [clip]`: length, chamber and hit frames, release and hold,
   torso twist/lean/drop/lunge at contact, how far each limb leaves its socket, where the fist or
   foot ends. `--keys=0,6,12` also prints the reference's poses at those frames as R6Clip key
   tables (named angles + `pos`, exact, angles kept continuous); `--fit=4` picks the fewest keys
   that rebuild the reference within 4 degrees (`--half` for a symmetric cycle you will mirror). Write the brief
   from these numbers (intent, weight, striking limb, keywords, measured frames and amounts).
3. **Block the key poses** at the reference's moments: guard → chamber (load *opposite* the
   strike) → hang → contact → held contact → recovery → guard. Body first: torso twist, lean,
   `pos` drop and lunge. Then the striking limb's angles, then its slide (`pos`) inside the budget.
   Legs hang from the pelvis and stay grounded (`space = "root", ground = true`).
4. **Time and space it.** Ease the segment that *leaves* each key: `sineInOut` load, `snap` strike
   (3-5 frames), `{ settle = 0.1 }` arrival, `sineInOut` creep in the hold, `{ recover = 0.1 }`
   home. Overlap with `clip:lead`: torso +1, free arm −1, head −2.
   **Weight is uneven speed, not smoothness.** A clip that glides through every key at one speed
   reads fast and weightless; one that stops dead at every key reads robotic. Build with
   `R6Clip.new(name, { curve = "auto", tension = 0.45, weight = "medium" })` (or set
   `R6Clip.curve / tension / weight` before building a set):
   - `curve = "auto"`: in-betweens and recoveries follow a monotone curve through the keys (the
     limbs travel arcs, never overshoot a key);
   - `tension` (0..1): how hard the body slows into each key on that curve. 0 glides (too smooth,
     too fast), 0.45 surges between poses and settles into each, 1 stops at every key;
   - `weight` (`light` / `medium` / `heavy`, `R6Clip.WEIGHTS`): timing contrast. The wind-up and
     the recovery are stretched (medium 1.3x / 1.55x, heavy 1.7x / 1.9x), the strike keeps its
     keyed speed, so the move is slow - fast - slow. Loops, jumps and landings keep their timing;
   - the weight eases for single segments: `heavyIn` (slow to start, then a surge: a heavy
     weapon into the cut), `heavyOut` (a fast arrival, then a long drift into the pose), `heavy`
     (inertia out of a pose, a firm brake into the next).
5. **Bake, audit, compare, look.** `R6Clip.audit` must come back clean. Run `study` on your clip
   next to the reference: the strike line should match and the torso numbers sit within ~20%.
   Look at it: `lune run build <outDir>` writes `preview.html` (scrub, 0.25×, trails), and if
   Studio is connected, pose a rig at the `Hit` frame and screenshot it from the side and front.
   A clean audit that looks wrong is still wrong.
6. **Ship it into Studio.** MCP: put the modules in (`set_script_source` or Rojo), build with
   `execute_luau`, parent the KeyframeSequence into the rig's `AnimSaves`, `eclipse-animator`
   `preview_animation`. Eclipse: `R6Clip.toEclipse(baked)` is the JSON `save_animation` takes.
   Offline: drag `R6CombatPack.rbxm` in. A live game needs the animation uploaded
   (`RegisterKeyframeSequence` ids only work in Studio).
7. **Hand over with numbers:** the reference used (or the fallback), hit frame, hold, hit-stop,
   fist reach and torso twist at the hit, the largest slides, the audit, and what you did not see
   (full speed in Play mode, the real camera).

### Writing a clip

```lua
local R6Clip = require(path.R6Clip)
local Moves = require(path.CombatMoves)
local G, leg, merge = Moves.Guard, Moves.leg, R6Clip.merge

-- lead jab: hanging chamber -> 3-frame release -> body and shoulder thrown in -> hold -> snap home
local c = R6Clip.new("Jab")
c:key(0, G, "snap")                                      -- the press reads on the first frame
local chamber = merge(G, {
	Torso = { twist = -12, lean = 4, pos = { up = -0.5, forward = -0.25 } },
	LeftArm = { raise = 120, swing = 40, pos = { forward = -0.15 } },   -- fist drawn back in
})
c:key(4, chamber, "sineInOut")
c:key(7, merge(chamber, { Torso = { twist = -9, pos = { forward = -0.3 } } }), "snap") -- keeps loading
local contact = merge(G, {
	Torso = { twist = -50, lean = 22, pos = { up = -0.42, forward = 0.55 } },  -- turned in, lunging
	Head = { turn = 26 },                                                      -- eyes stay on target
	LeftArm = { raise = 134, swing = -32, pos = { forward = 0.75 } },         -- shoulder thrown out
	RightArm = { raise = 158, swing = 70, pos = { forward = 0.1 } },          -- rear hand to the chin
	LeftLeg = leg({ raise = 24, spread = 4 }),                                 -- front foot steps
	RightLeg = leg({ raise = -28, spread = 6, pos = { forward = -0.25 } }),   -- rear leg pushes
})
c:key(10, contact, { settle = 0.12 })
c:key(18, merge(contact, { LeftArm = { pos = { forward = 0.82 } } }), "snap")  -- held, creeping
c:key(24, merge(G, { Torso = { twist = -30, lean = 12 } }), { settle = 0.1 })
c:key(30, G)
c:marker(10, "Hit"); c:marker(18, "Cancel")
c:lead("Torso", 1); c:lead("Head", -2)
c.meta = { limb = "LeftArm", strike = { 7, 10 }, hit = 10, hitstop = 0.075 }

local baked = c:bake()
print(R6Clip.audit(baked, c.meta).notes)                -- fix until empty
local ks = R6Clip.toKeyframeSequence(baked)             -- AnimSaves-ready
```

**Weapons.** A sword in a Tool's default grip (RightGrip) is a fixed extension of the arm: its
blade stands out of the fist along the arm's front, so the arm's `raise` sets where the blade
points (raise 0 forward, 90 straight up, 165 back over the head). Give the clip `meta.tip =
Vector3.new(0, -1, -blade)` (Right Arm space) and the audit's contact/sweep checks measure the
blade tip; `lune run study ... --tip="Right Arm:0,-1,-4"` measures references the same way. A
long lever turns small arm motions into big tip speeds: accelerate into contact (`quadIn` or
`heavyIn` out of the hang), do not `snap` out of it. **A weapon is swung, not punched**: wind it up
all the way (an overhead cut starts with the sword raised over the head, the blade hanging behind
it: raise 150-165 with the back arched), swing it round a wide arc with the arm out at full
stretch (spread and the shoulder slid out 0.5-0.9 at the middle of the arc, keys every 2-3 frames
along it so the tip travels the circle, not a chord), and carry it through past the target to the
far side (behind the opposite hip, out wide to the other side, down to the floor). The audit's
`swing` check holds a `meta.tip` clip to `meta.minArc` degrees of travelled arc (default 120; a
katana combo uses 190), `meta.minStretch` studs of average arm slide through the swing, and, with
`meta.cut = "overhead"`, a wind-up blade 1.5+ above and behind the head. Worked example and
numbers: `references/combat.md` §9.

Part entries: named angles (Torso `lean/twist/tilt`, Head `nod/turn/tilt`, limbs
`raise/spread/swing/twist`, degrees, parent space), `pos = { forward, up, right }` studs (the torso
against the root; any other part slid out of its socket), and for legs `space = "root"` (hang from
a pelvis taking `hips` = 0.35 of the torso's turn) and `ground = true` (slide to the floor every
frame). `transform = CFrame` takes a raw pose. Details and numbers: `posing.md`.

## The non-negotiables of force on R6

1. **No pops.** No part jumps (turn or slide) in one frame unless a `Snap` marker or the strike
   window covers it.
2. **The hit reads at its moment.** The striking limb is at its extreme within 2 frames of `Hit`,
   held 4-6+ frames, landing 20-50% into the move.
3. **The body commits.** A straight punch turns the torso 40+ degrees into it, lunges, and puts the
   fist 2.8+ studs in front of the root (references: 30-110 degrees, 2.3-4.2 studs). The audit fails
   a timid punch.
4. **Short slides, never none, never wild.** Arms up to 1.0 stud out of the socket, legs 1.5
   (mostly riding up into the torso), head 0.15 (rotate it, do not slide it). Slide along the
   motion.
5. **Honest legs.** Soles on the floor while grounded, legs never crossed or passing through each
   other (the X a 60-degree twist makes when the hips turn with the chest).
6. **Limbs travel the path the keys describe.** Between keys the named angles are interpolated, so
   an arm flung back comes home down and forward, never up and over the head. Raw transforms and
   runtime fades still blend the short way: keep those under 180 degrees apart.
7. **Nothing moves as one block.** Torso leads, limbs trail, the head counters; every move ends in
   its own pose and settles.
8. **Lower the body the house way.** Measured from the house crouch, walk and run:
   - feet under the hips (0.5-0.82 out from the centre), split front and back, never splayed
     sideways like a sumo;
   - one leg takes the depth (the front one, up to about 1.0 stud into the torso), the other stays
     long (within 0.4) and stretches behind at `acos(1 - drop/2)` (drop 0.45 → 40 degrees, 0.6 →
     46): two legs sunk together read as stumps under the torso;
   - the chest leans into the drop, about 30 degrees per stud (at least 20);
   - the head nods up against the lean: the face looks 2-13 degrees down, not at the floor (with
     the kit's angle names, `nod ≈ 8 - lean`).
9. **Uneven, weighted timing.** Slow wind-up, fast strike, slow heavy recovery (`weight`), the body
   settling into each pose (`tension`), never one even glide. A weapon swings a wide arc at full
   stretch; it is never a punch with a blade on it.

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

## Before you say it is done

- `lune run house <movement-system.rbxm> <yours.rbxm>`: your stance, guard, walk and run sit inside
  the house's ranges (drop, lean, face, bury per leg, feet).
- `lune run check` from `tools/` (214 tests: mocap → R6, math, slides, legs on the pelvis, the crossed-legs
  case, every move's audit and commitment, export round trip, R15 → R6 accuracy, study).
- `selene --config selene.toml ../scripts` from `tools/`.
- `lune run compare <reference> <yours>`: arms within about 10 degrees and feet within 0.25 stud
  of the reference except where you changed them on purpose (name those in the hand-over).
- The audit is clean on every new clip, `study` agrees with the reference, and you looked at it
  from the side and the front (preview, or a posed rig in Studio).
- If Studio MCP is connected, play or pose the clip on a real R6 rig and read a value back (the
  fist's position at `Hit`, the soles' height) instead of trusting the code.
- Say plainly what was not tested: `R6Combat` compiles and lints, but only a playtest proves it.

## Mistakes this skill has made, and what now stops each

Every one of these shipped once and was caught by the user or a playtest. Each has a fix in the
code and a check that fails if it comes back. Do not remove the checks to make a clip pass.

| Mistake | Fix | Caught by |
|---|---|---|
| Mocap legs crossed into an X: keyed against a torso folding 45 degrees, and the performer's small hip turn five times larger on R6's 2-stud hips | `study --root-legs --hips=0`; `MocapToR6` hangs legs from a square pelvis | tests "study --root-legs keeps the feet", "mocap fold ... does not cross the legs" |
| Mocap feet skated 0.5 stud as the body folded, and legs slid along their slant | each R6 foot goes where the human foot is; legs ride straight up | test "mocap feet stay planted"; `mocap`'s hands-and-feet table |
| One part named twice in a pose ("RightLeg" and "Right Leg") silently kept a random one | `R6Clip:key` errors | test "a part keyed twice under two names is rejected" |
| Arms drifted 33-47 degrees off the reference between sparse keys on a wide arc | `lune run compare` against the reference; add keys where it drifts | the compare step in the workflow |
| Asked for a mage animation, the skill reposed its own punches and walks: no reference was searched for a move the kit never had | `references/new-moves.md`: brief, search vocabulary, the six-tier ladder, a reference sheet in every hand-over; `lune run mocap` turns free human mocap into R6 references | the eval "mage-fireball-new-move" (a reference sheet with real sources, no kit poses) |
| IK aims and planted-leg solving made every move cramped and timid | no IK; angles plus short slides | audit `commit` (fist 2.4+ out, torso 25+ turned) |
| A 60-degree torso twist swapped the hips and crossed the legs into an X | legs on a pelvis (`space = "root"`, `hips` 0.35); R15ToR6 hangs legs from the R15 pelvis | audit `legs` (centre lines, X from side/front); tests |
| An arm flung back (raise -55) came home to the guard (150) over the head: rotation blends take the shortest way, and 193 degrees is "shorter" backwards | R6Clip interpolates the named angles, not the rotations | audit `overhead` and `export`; test on all four dashes |
| Reading an overhead arm back out of a clip gave swing ±179, which interpolates as a full spin | `R6Study.entry` picks the Euler split and 360-wrap nearest the previous frame | test "study angles stay continuous" |
| The reference walk/run/fall "cross" from the side: legs passing in a stride | `meta.stride = true` (front view only) | audit `legs` |
| Roblox's default Animate stopped the idle the moment it loaded | empty `Animate` script; R6Locomotion replays a stopped loop | playtest |
| The wall run caught the wall in the Jumping frame, before the jump's push, and "landed" at once | catch walls only in Freefall, 1.5 studs clear of the floor; keep the jump's rise | playtest |
| Dash distances measured wrong because someone was steering the character | disable the PlayerModule controls (or WalkSpeed 0) while measuring | playtest method |
| A sword slash was judged by the fist, not the blade (the skill had no weapon) | `meta.tip` in the audit, `--tip` / `opts.tips` in study, sweep lines (fastest frame, centre crossing) | test "meta.tip measures from the weapon" |
| A class stance and guard sank both legs 0.7 into the torso with the feet splayed 1.1 out, like stumps under the body (copied from an R15 prototype) | the house's crouch: split feet, front leg deep, back leg long; `R6Clip.HOUSE` | audit `bury` ("both legs") and `house` (feet width); tests "house: ..." |
| Guards looked at the floor (face 33 degrees down) behind a torso that barely leaned for its drop | the head nods up against the lean; the chest leans about 30 degrees per stud of drop | audit `house` (face, lean per stud) |
| A walk and run made "heavier" by dropping the body 0.25 below the house cycles | keep the house's walk and run whole; change only what the class adds (the arms) | `lune run house` side by side |
| `curve = "auto"` with no tension glided through every key at one speed: the user found every clip "too fast, too smooth", no weight | `tension` (0.45) and `weight` profiles: slow wind-up, fast strike, slow recovery; `heavyIn` / `heavyOut` / `heavy` eases | tests "weight stretches the wind-up and recovery, not the strike", "tension slows the curve into a key"; speed contrast (peak over mean speed) 3.7 keyed → 4.2 weighted over 58 clips |
| Katana cuts keyed like punches: the arm pushed out along a line, the overhead cut never raising the sword over the head | wide arcs at full stretch, wind-up all the way back, follow-through to the far side | audit `swing` (`meta.minArc`, `meta.minStretch`, `meta.cut = "overhead"`); tests "a punch-shaped cut fails the swing check" |
| Every in-between eased `sineInOut` made the body stop at every key: stop-start motion, no curve through passing keys ("not smooth yet, no curve") | `curve = "auto"`: monotone cubic (PCHIP) through the keys; `recover` curved too | tests "auto curve keeps its speed through a passing key", "... never overshoots", "every kit move audits clean with curve = auto"; hitches counted over 58 clips (225 → 172) |
| `snap` out of the hang made the blade peak at 309 studs/s right after the wind-up (reference: 192, 3 frames before contact) | `quadIn` into the cut | study's sweep line against the reference |

Two that the audit cannot see, so watch for them:
- **Fades between clips at runtime** (an AnimationTrack fading out while another fades in) blend
  rotations the short way too. A fade between poses more than 180 degrees apart swings through the
  back. End a move near the pose the next one starts from (every kit move ends in the guard), or
  fade fast.
- **Weapon joints.** Some packs turn the weapon with its own Motor6D (a "Handle" joint in the Right
  Arm). R6Clip keys only the six body joints: such a pack's arm timing is usable, its blade
  angles are not, and our clips rely on the Tool's default grip.
- **Raw `transform` keys** still blend as rotations. Keep consecutive raw keys under 180 degrees
  apart, or convert them with `R6Study.entry`.

## Gotchas

- A Pose's easing shapes the segment *leaving* it. Legacy `Cubic` has In and Out swapped; use
  `CubicV2`.
- `CFrame:ToAxisAngle()` can return angles over 180°; fold them (`Sequence.axisAngle`).
- A Pose with Weight 0 is a placeholder. Never key HumanoidRootPart; travel is physics.
- Torso twist drags the legs (they are its children) and can cross them: legs on the pelvis
  (`space = "root"`). The audit's `legs:` notes catch an X from the side or the front.
- A sideways arm (spread ≈ 90) ignores `raise`; lift it with spread past 90.
- Toolbox rigs: `GetObjects` works where `insert_asset` says "not authorized"; packs labelled "No
  scripts" can still carry some. Destroy them before parenting.
- `study` reports `gap` (joint translation, what you copy) and `visible` (what the eye reads);
  clips made by rotating parts about their centre show a large `gap` with a small `visible`.
- `AdjustSpeed(0)` hit-stop is reliable when a keyframe sits exactly on the marker (R6Clip
  guarantees that).
- Measuring in a playtest: disable the controls first (`PlayerModule:GetControls():Disable()`),
  or input from whoever is at the keyboard moves the character mid-measurement.
- Long `eval_client_runtime` calls (several seconds of `task.wait`) can fail with "Unknown error",
  and threads spawned from them may stop when the call returns: test in short steps.
- `Players:CreateHumanoidModelFromDescription` rigs come out black (default body colours) and
  their pivot may not be the root: set `HumanoidRootPart.CFrame` directly when posing for a
  screenshot.
