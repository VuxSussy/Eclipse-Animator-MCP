# Reference first: find an R6 version, measure it, imitate it

> New body-clearance requirement: source poses may telescope thighs into the torso. Preserve the measurement as provenance, but do not copy that artifact. Run R6Quality.audit and follow body-clearance.md. Grounded soles and legal slide budgets do not prove that the visible thigh is clear.

Every new animation starts by looking for the same move already made **for R6**. A real R6 clip
already solved the problems a six-block body has (no elbows, no knees, a torso that is the spine),
so its timing, angles and slides are worth more than any rule of thumb. When no R6 version exists
you fall back to the movement grammar of the user's R6 movement system (section 5), which the
user picked as the house style. Either way, **the body always follows the house** (section 5,
"The house body"): a reference gives the move and its timing, the house decides how the torso
drops and leans, which leg takes the depth, where the feet stand and where the face looks.

## Contents
1. Where to look, in order
2. Loading a reference safely
3. Measuring it (`lune run study`)
4. Imitating it
5. No R6 reference: the house grammar
6. Measured references (tables)

## 1. Where to look, in order

For a move this kit has never made (magic, weapons other than a sword, emotes, anything that is
not a punch, kick, dash, block, reaction or locomotion), use the longer ladder in `new-moves.md`
instead: it adds Roblox emotes, free human motion capture (`lune run mocap`), video and the user
acting the move out, and requires a reference sheet.

Stop at the first source that has the move (or something close: a "heavy punch" for a cross, a
"kick" for a push kick).

1. **The user's own files.** `~/Downloads/*.rbxm|*.rbxl`, the project's `output/`, rigs with an
   `AnimSaves` folder in the open Studio place (`robloxstudio` `search_objects` for
   `KeyframeSequence`). The user's R6 movement system lives at `<movement-system>.rbxm` (in `~/Downloads`)
   (15 locomotion clips: idle, walk, run, jump, fall, three landings, crouch, crawl, climb).
2. **The Creator Store, through Studio MCP.** `search_assets` with `assetType = "Model"` and a
   plain query: `"R6 punch animation"`, `"R6 kick animation"`, `"R6 dash animation"`,
   `"R6 <move> animation"`. Long queries ("R6 combat animations AnimSaves punch") return nothing;
   keep it to three or four words. Some words return nothing at all ("sword", "katana", "weapon"
   on 2026-10-28): describe the motion instead ("R6 slash animation", "R6 parkour animations").
   Packs are often arms-only (legs and torso unkeyed); take the body from another reference. Prefer results whose description says *"An R6 character rig ...
   N animations ... No scripts"*: those are rigs with KeyframeSequences in `AnimSaves`.
3. **Animation packs converted from R15.** `eclipse-animator` `import_animation_pack`, or our
   `R15ToR6` (see `r15-to-r6.md`). Second best: R15 timing survives, R6 posing has to be redone.
4. **Video.** YouTube, TikTok, Shorts of R6 combat (search "roblox r6 <move> animation"). Step it
   frame by frame and write down the frames (load, release, hold, recovery, how far the body turns).
   `eclipse-animator` `video_to_animation` can draft keys from a clip.
5. **Nothing R6 at all:** section 5.

Say which source you used and why in the hand-over. If you fell back to section 5, say that too.

### Archetype check before keying

A technically accessible clip is suitable only if it demonstrates the requested action and weapon weight. For heavy swords, inspect full load, strike, follow-through and recovery in actual heavy footage (R6 first, other rigs when R6 cannot be verified). An unrelated slash or locomotion grammar may support rig mechanics, but cannot replace heavy visual research. Save the URL, creator, rig, approximate timestamps, visible observations and adaptation decisions before making keys. Distinguish searched listings, watched videos and measured key data. Do not infer 3D angles/studs from a camera view or describe authored numbers as source measurements. Reuse this brief only for the same action/style.

## 2. Loading a reference safely

Creator Store models are untrusted. Their scripts must never run.

- `insert_asset` may answer "not authorized" for assets the user does not own. Loading through
  `execute_luau` works in edit mode:

  ```lua
  local folder = Instance.new("Folder")
  folder.Name = "Ref_" .. id
  folder.Parent = game.ServerStorage
  for _, o in game:GetObjects("rbxassetid://" .. id) do
  	for _, d in o:GetDescendants() do
  		if d:IsA("LuaSourceContainer") then
  			d:Destroy() -- strip BEFORE parenting anywhere
  		end
  	end
  	o.Parent = folder
  end
  ```

  Assets that say "No scripts" sometimes carry two; strip anyway.
- Pull it out to disk with `export_rbxm` (into the scratchpad, not the project), then measure
  offline. Nothing in Lune runs the file's scripts.
- **Imitate, do not ship their keys.** Copy proportions and numbers into your own keys. If the user
  wants the original clip itself, it is theirs to take from the Toolbox under the creator's terms;
  credit the asset id.
- Clean up what you added to the place (the `Ref_` folders), or tell the user where it is.

## 3. Measuring it (`lune run study`)

From `tools/`:

```bash
lune run study <file.rbxm|.rbxl> [clip name ...]
```

It reads every R6 KeyframeSequence (it uses the rig's own joints when the clip sits in a rig's
`AnimSaves`) and prints, per clip:

| Line | What it tells you | How to use it |
|---|---|---|
| length, keyframes, easing | how long, and whether it is baked (dense Linear keys are normal) | your clip's length |
| torso: drops, lunges, leans | how much the body commits | `Torso.pos.up`, `pos.forward`, `lean` at contact |
| part: rot reach | the biggest rotation from rest, degrees | sanity check for your angles |
| part: **gap** max / avg | how far the joint is slid out of its socket (translation in the Transform), with the frame and direction | `pos` on that part, at that frame |
| part: **visible** max / avg | the smallest slide left when the rotation is taken about any point of the limb's upper half: what the eye reads as "detached" | judge against the budgets (`posing.md`) |
| strike: chamber → hit | frame of the deepest load and of 90% travel, share of the move, release frames, hold frames | your keys' frames and the `Hit` marker |
| strike: tip travels / to | studs the fist or foot travels forward and where it ends in front of the root | the audit's `commit` reach |
| strike: gap at hit, torso twist, lean, lunge | the body at contact | your contact key |

`gap` and `visible` differ when the tool that made the clip rotated parts about their centre
(Moon Animator, some Toolbox packs): that adds joint translation nobody sees. Copy `gap` to
reproduce the pose exactly; judge the look with `visible`.

In Studio (no Lune), `R6Study` is a ModuleScript like the others:
`R6Study.format(R6Study.measure(Sequence.read(ks)))`.

## 4. Imitating it

1. **Write the brief from the numbers.** Length, chamber frame, hit frame (share), release and hold
   frames; at contact: torso twist, lean, drop, lunge, the striking limb's gap and where the tip
   ends; which legs step and how far they slide up.
2. **Block the same key moments** in `R6Clip`: guard, chamber, (hang), contact, held contact,
   recovery, guard. Put keys on the reference's chamber and hit frames. Rescale time only as a
   whole (a 0.75 s reference can become 0.5 s), never by speeding up the release alone.
3. **Match the body first, then the limb.** Torso twist/lean/`pos` to the reference's values at
   contact; then the striking arm's angles until its tip lands near the reference's (the
   `tip ... to N fwd` number); then `pos` on the arm for the reference's gap, inside the budget.
4. **Legs**: `space = "root"` and `ground = true` (posing.md). Step the front leg and extend the
   rear one the way the reference does; repair any thigh/torso overlap in the source before export.
   Reduce the depth of a stance when the six-block rig cannot keep the thigh visible and feet supported.
5. **Bake, audit, and run `study` on your own clip** next to the reference. The two reports should
   agree on the strike line (chamber, hit share, release, hold), the torso numbers within about
   20%, and the tip's end point within half a stud. Where they differ, say why (a budget, the
   user's taste, the combo's timing).
6. **Look at both** in Studio side by side (pose both rigs at the `Hit` frame, or play them), not
   only at the numbers.

## 5. No R6 reference: the house grammar

The user's R6 movement system measured with `study` (all 15 clips: 60 fps baked, Linear).
These are the house rules when nothing closer exists:

- **The head never leaves the neck** (gap 0 in every clip). Move it by rotation only.
- **Arms slide along their swing**, more as the motion grows: idle 0.15 stud, walk 0.4, jump 0.3,
  land 0.6, run 0.7, crawl 0.9. The slide follows the swing: a forward swing pushes the arm
  forward, a back swing pulls it back.
- **Measured legacy leg slides, not permission to bury thighs** (R6 has no knee): walk ~1.0 stud on the
  forward leg as it passes, run 1.3, crouch 1.1, landings 1.3-1.6. At jump takeoff the legs push
  *out* of the hips 0.56 stud downward, then tuck up 0.9 in the air.
- **The body drops into effort**: walk bobs 0.17-0.33 stud down and 0.1-0.25 forward, run
  0.29-0.46 down, a normal landing 0.9 down with a 15-33 degree fold.
- **Rotation ranges**: walk legs ±55, arms ±37; run legs ±82, arms to 129, torso 27; landing
  arms thrown to 100 degrees.
- **Procedural turning on top** (runtime, not in clips): lean by momentum, hips yaw into strafes,
  a sprint-start lunge (see `weight-and-feel.md` section 7).

For a combat move with no reference, combine this grammar with the measured punch numbers in
section 6: commit the body like the punch packs, keep the slides inside the movement system's sizes.

### The house body (every clip, referenced or not)

Measured with `lune run house <movement-system.rbxm>`; the rules are in `R6Clip.HOUSE` and the
audit checks them. How to pose them: `posing.md` §4, "Lowering the body the house way".

| House clip | drop | lean | face | bury front / back leg | feet out |
|---|---|---|---|---|---|
| idle | 0.03-0.06 | 0-1 | -4..-2 | 0.03 / 0.03 | 0.58-0.66 |
| walk | 0.17-0.33 | 8-11 | -10..-7 | passes 0.48 / -0.38 | 0.52-0.57 |
| run | 0.29-0.46 | 18-24 | -13..-11 | passes 0.95 / -0.20 | 0.50 |
| crouch (held) | 0.74 | 22 | -10 | 0.96 / 0.11 | 0.73-0.82 |
| normal land | 0.9 | 15-33 | -47..-42 | 1.11 / 0.44 | 0.63-0.73 |

A reference whose body disagrees (the Iron Bastion prototype's R15 stance: feet 1.05 out, both
legs 0.5 in, lean 5 for a 0.5 drop) keeps its arms and timing and takes the house's body.

### Worked example: the kit's Idle, Walk and Run

1. `lune run study "<movement-system>.rbxm" "walk v3" --keys=0,6,12,18,24`
   printed five poses; the clip is symmetric (frame 25 mirrors frame 0), so the cycle is those five
   plus `R6Clip.mirror` of each.
2. Key spacing was chosen by measuring the rebuilt clip against the reference every frame: walk
   every 6 frames, linear (worst 4.8 degrees, 0.14 stud at a tip); run every 3 frames (3.9 degrees);
   idle 4 keys, sineInOut (1.2 degrees).
3. The audit passed with `stride = true` (walks pass one leg past the other seen from the side).
4. In a playtest the driver read 12.0 studs/s → Walk at 0.83, 27 → Run at 1.3, backwards → Walk at
   −0.83, stop → Idle, an attack → Stance, Idle again 3 s later.

### Worked example: climb, jump, fall, landings, wall run

- The movement system's "Climbing", "jump", "fall", "Normal Land", "Short", "Long" were fitted with
  `lune run study ... --fit=4` (6 for the long Climb and Fall loops): 2-27 keys each.
- The landings' soles dip 0.14-0.15 stud into the floor in the reference: `ground = true` on the
  legs. The movement system's deep landings ride the legs 1.55-1.6 studs into the torso, past the 1.5 budget:
  those two clips carry `budget = 1.7` for the legs, a choice backed by the reference.
- No wall run in the movement system file, so the Creator Store came next: "R6 Wall Run" packs (103291843985457,
  13289041733) barely move the torso; "R6 Parkour Animations" (15259391918, "full rights ... credits
  appreciated") has WallRunR/WallRunL, a sprint cycle with the torso tilted 25 degrees away from the
  wall, legs riding 1.15 stud. Fitted at 4 degrees (18 keys); the left run is `R6Clip.mirror`.
- Overhead arms (the climb) are where Euler angles wrap: `R6Study.entry` keeps them continuous
  (raise 154, spread -45 rather than swing -179).
- Playtested: a jump in place lands with Land (fell 0.3), a 10-stud ledge with LandShort (7.7),
  a 30-stud ledge with LandLong (27); Climb plays at 0.70 (8.4 studs/s ÷ 12) and pauses when the
  climber stops; the wall run holds 1.4 s along 37 studs of wall, rising to 11 and sinking off.

## 6. Measured references (tables)

### Creator Store "punch aims" pack (asset 85161273651688, R6 rig, 9 strikes + equip)

Measured 2026-10-28 with `study`. Dense 60 fps Linear keys.

| Quantity | Range | Typical |
|---|---|---|
| length | 0.45-0.75 s (27-45 f) | 0.5 s |
| hit share (90% travel) | 30-72% | ~50% |
| release (chamber → 90% travel) | 4-14 f | 6-9 f |
| hold near the extreme | 0-21 f | 1-4 f (they rely on recovery, not holds) |
| torso twist at contact | 8-113 degrees | 30-70 |
| torso lean max | 12-47 degrees | 20-40 |
| torso drop / lunge | 0.06-0.97 / 0-0.65 stud | 0.4 / 0.35 |
| fist ends in front of the root | 2.2-4.2 studs | ~3 |
| striking arm gap at contact | 0.2-1.6 stud | 0.5-1.0 |
| striking arm visible max | 0.6-3.9 stud | 1.3-1.9 (beyond our "short" budget) |
| legs gap | 0.5-1.7 stud | ~1.0, mostly up into the torso |

### Creator Store "TemplateR6" swing pack (assets 80460719695191 and 107810164673839, same clips)

Equip, Idle, Swing, Swing 2, Swing 3: arms only (legs and torso unkeyed), 0.97 s swings with the
hit at 43-48%, release 6-9 f, hold 4-14 f. The swinging arm is thrown **2.5-3.8 studs** out of the
shoulder: a weapon style, far past what the user wants. Use it for timing only.

### What our kit does now (for comparison)

| Move | Fist ends | Torso twist | Arm gap | Hit share | Release | Hold |
|---|---|---|---|---|---|---|
| Jab (before this rewrite) | 2.93 | -40 | 0 (IK) | 26% | 3 f | 8 f |
| Jab | 3.39 | -50 | 0.83 | 31% | 3 f | 9 f |
| Cross (before) | 2.60 | 24 | 0 (IK) | 21% | 4 f | 11 f |
| Cross | 3.28 | 62 | 0.91 | 32% | 3 f | 15 f |

The kit keeps the hit earlier than the packs (about a third in) because R6Combat chains M1s;
re-time toward 45-50% for single heavy moves.
