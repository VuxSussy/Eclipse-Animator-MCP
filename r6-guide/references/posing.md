# Posing R6 without IK: angles and slides

> New body-clearance requirement: source poses may telescope thighs into the torso. Preserve the measurement as provenance, but do not copy that artifact. Run R6Quality.audit and follow body-clearance.md. Grounded soles and legal slide budgets do not prove that the visible thigh is clear.

This skill has no IK and no FK/IK solver modes. A clip is the poses you key, nothing more. That
was the user's call after the first version: IK targets kept every arm at a fixed reach on a fixed
line and planted-leg solving pinned the hips, so moves came out tucked in and timid, with no force. Measured R6 references get their force the other way: big torso turns,
and limbs **slid a short way out of their sockets** (see `reference-first.md`).

## Contents
1. The R6 rig in numbers
2. Part entries
3. Slides (`pos`) and their budgets
4. Legs: pelvis space, grounding, never crossed; lowering the body the house way
5. How Roblox applies a pose
6. Why not IKControl, and what replaced each IK feature

## 1. The R6 rig in numbers

| Part | Motor6D (in) | C0 (in the parent) | C1 (in the part) | Pivot → tip |
|---|---|---|---|---|
| Torso | RootJoint (HumanoidRootPart) | (0,0,0) | (0,0,0) | — |
| Head | Neck (Torso) | (0,1,0) | (0,−0.5,0) | face at (0,0,−0.5) |
| Right Arm | Right Shoulder (Torso) | (1,0.5,0) | (−0.5,0.5,0) | 1.58 studs to the fist |
| Left Arm | Left Shoulder (Torso) | (−1,0.5,0) | (0.5,0.5,0) | 1.58 |
| Right Leg | Right Hip (Torso) | (1,−1,0) | (0.5,1,0) | 2.06 studs to the sole |
| Left Leg | Left Hip (Torso) | (−1,−1,0) | (−0.5,1,0) | 2.06 |

- **The pivots are at the edges.** The shoulder pivot sits at the arm's inner top edge and the hip
  pivot at the leg's outer top edge. A limb does not swing about its own centre line.
- **`Part1 = Part0 · C0 · Transform · C1⁻¹`.** A Pose.CFrame in a KeyframeSequence *is* that
  Transform. Its rotation turns the part about the joint; its **position slides the joint out of
  its socket**. `R6Rig.gap(part, transform)` reads that slide back in the parent's space.
- **Axis cheat sheet.** R6 joint frames are rotated (the RootJoint's own X points left, Y back, Z
  up), so raw Euler angles on Pose.CFrame mean different things per joint. Key named angles
  (`R6Rig.rotation`), which work in the parent's space:
  - Torso: `lean` (forward +), `twist` (left +), `tilt` (right +)
  - Head: `nod` (down +), `turn` (left +), `tilt`
  - Arms: `raise` (forward/up +), `spread` (out +), `swing` (across the front +), `twist`
  - Legs: `raise` (forward +), `spread` (out +), `twist`

  `tools/check.luau` proves each. Character space: +X right, +Y up, −Z forward, floor at y = −3.
- **Useful arm numbers** (fist positions measured with the kit, torso at rest unless said):
  - guard, fist at the chin: `raise ≈ 138, swing ≈ 32` (lead), `raise ≈ 150, swing ≈ 62` (rear)
  - straight punch with the torso turned 50 and leaning 22: `raise ≈ 134, swing ≈ −30`, fist at
    shoulder height on the centre line
  - hook arc: `spread = 100` and `swing` 50 → 85 (the fist crosses the centre line around 50 when
    the torso is turned −50)
  - a sideways arm (spread ≈ 90) ignores `raise`; lift it with spread past 90

## 2. Part entries

```lua
c:key(frame, {
	Torso = { lean = 22, twist = -50, pos = { up = -0.42, forward = 0.55 } },
	Head = { nod = 4, turn = 26 },
	LeftArm = { raise = 134, swing = -32, pos = { forward = 0.75 } },     -- shoulder thrown at the target
	LeftLeg = { raise = 24, spread = 4, space = "root", ground = true },  -- see section 4
	RightLeg = { raise = -28, spread = 6, space = "root", ground = true, pos = { forward = -0.25 } },
}, { settle = 0.12 })
```

| Field | Parts | Meaning |
|---|---|---|
| named angles | all | degrees about the joint, in the parent's space |
| `pos = { forward, up, right }` | all | studs. Torso: the body against the root. Others: the slide out of the socket |
| `space = "root"` | legs | hang the leg from a pelvis (section 4) |
| `hips = 0..1` | legs with `space = "root"` | the pelvis's share of the torso's turn and lean (default 0.35) |
| `ground = true` | legs | every frame, slide the leg straight up or down until its sole is on the floor |
| `transform = CFrame` | all | a raw Transform, e.g. copied from a measured reference |
| `ease` | all | this part's ease leaving this key |

`R6Clip.merge(base, over)` merges angles field by field and `pos` axis by axis, so
`merge(Guard, { LeftArm = { pos = { forward = 0.8 } } })` keeps the guard's arm angles.
`aim`, `pole`, `free`, `feet = "planted"` and `headCounter` were removed; an old `aim` key errors
instead of silently doing nothing.

### How keys interpolate

Between two keys of named angles (and `pos`), R6Clip interpolates the **numbers**, then builds the
pose: raise -55 → 150 goes -55, 0, 50, 100, 150, down and forward. It does not blend the two
rotations, because a rotation blend always takes the shortest way round, and two poses more than
180 degrees apart are "shorter" the wrong way (an arm flung behind the back comes home over the
head). Raw `transform` keys and root-space legs still blend as rotations; keep those under 180
degrees apart. The export (`toKeyframeSequence`) keeps enough keys that Roblox's own blending
plays the same path; the audit's `export` check proves it.

## 3. Slides (`pos`) and their budgets

The slide is the R6 animator's substitute for an elbow, a knee, a shoulder blade and a pelvis.

| Part | Budget (`R6Rig.GAP`) | Where the number comes from | Typical use |
|---|---|---|---|
| arm | 1.0 stud | movement system: idle 0.15, walk 0.4, run 0.7, crawl 0.9; punch packs: 0.5-1.0 at contact | punch +0.6-0.9 forward; guard +0.15-0.2; rear hand −0.1 inward; recoil −0.25 back |
| leg | 1.5 studs | movement system: walk 1.0, run 1.3, landings 1.3-1.6, crouch 1.1 | short slide/stance adjustment with a clear visible thigh; kick +0.6 out of the hip; body clearance still required |
| head | 0.15 stud | The movement system never moves the head off the neck (0 in all 15 clips) | rotation only |

- **"A short distance."** The user wants limbs out of the torso only a little. Community packs
  throw the striking arm 1.3-3.9 studs (visible); we stop at 1.0. Raise a clip's budget only when
  the user asks (`R6Clip.new(name, { budget = { LeftArm = 1.4 } })`).
- **Slide along the motion.** The movement system's arms slide forward on the forward swing and back on the back
  swing; a punch pushes the shoulder along the punch line. A slide across the motion reads as a
  dislocated limb.
- **Slides ease like angles.** They interpolate with the same ease; a 0.8-stud slide in 2 frames
  pops (the audit counts a 0.5-stud jump in one frame as a 20-degree pop).
- **The audit** prints each part's largest gap (`metrics.gap`) and notes any part past its budget.

## 4. Legs: pelvis space, grounding, never crossed; lowering the body the house way

R6 legs hang from the Torso, and the Torso is chest and pelvis at once. Twist it 60 degrees for a
cross and, by default, the hips swap front-to-back with it: the front leg ends up hanging from the
back hip and the legs cross into an X. The user caught exactly that on the first draft of this
kit's Cross. Three tools stop it:

1. **`space = "root"`**: the leg hangs from a **pelvis** that takes only `hips` (default 0.35) of
   the torso's turn and lean, the way real hips turn less than shoulders. The hip socket is slid
   to where that pelvis puts it (a translation, inside the leg budget), and the leg's angles are
   read against the pelvis. Between two root-space keys the leg is blended against the root and
   hung from each frame's torso, so a fast torso swing cannot drag the legs through each other.
   `hips = 0` keeps the legs exactly on the root; `hips = 1` is the old torso-space behaviour.
2. **`ground = true`**: every frame the leg slides straight up or down (root space) until its sole
   is on the floor. No angle changes. A deep body drop can push the thigh into the torso, so
   grounding is not a knee-bending solution. Reduce the drop or change the keyed leg pose until
   R6Quality.audit passes body clearance. Between a grounded key and a free one it fades in or out.
   is on the floor. No angle changes. When the body sinks, the legs ride up into the torso by
   however much the drop needs: grounding does not choose WHICH leg should take it. Two legs
   hanging straight down both ride the whole drop and read as stumps; pose them the house way
   (below) so only the front one does. Between a grounded key and a free one (a kick chamber) it
   fades in or out.
3. **The audit's leg checks**:
   - the legs' centre lines must stay 0.75 stud apart (two one-stud blocks closer than that pass
     through each other)
   - seen from the side or the front, the hips must not be in one order and the feet in the other
     by more than 0.3 stud: that is the X
   - set `meta.legsMayCross = true` only for a deliberate cross-step
   - R6Quality.audit also rejects visible thigh/torso intersection, regardless of cross-step flags

### Lowering the body the house way

The house grammar lowers a body on one leg. Its crouch (`lune run house <movement-system.rbxm>
Crouch`): drop 0.74, chest leaning 22 and turned -8.65, the front foot 0.96 ahead with that leg 0.96
into the torso, the back foot 1.29 behind with its leg only 0.11 in, feet 0.73-0.82 out from the
centre, the face 10 degrees down. Its walk and run keep the same habits while moving.

- **Feet under the hips**, 0.5-0.82 out from the centre: `spread` 0-5. Width comes from nothing;
  depth and stability come from splitting the feet front and back.
- **The back leg stays long.** A leg tilted θ from vertical reaches `2·cos θ` down, so with the hips
  lowered by `drop` it touches the floor with no slide at `θ = acos(1 − drop/2)`: drop 0.35 → 34,
  0.45 → 40, 0.6 → 46, 0.75 → 51 degrees (`raise` negative for the back leg).
- **The front leg takes the depth**, `raise` 10-20, riding up into the torso by up to about 1.0.
- **The chest leans into the drop**, about 30 degrees per stud (at least 20): drop 0.45 → lean 13,
  0.6 → 18-20. A deep drop with an upright chest is a squat, not a stance.
- **The head counters the lean** so the face looks 2-13 degrees down. With the kit's names,
  `Head.nod ≈ 8 − Torso.lean`.

The audit holds every clip to this (`R6Clip.HOUSE`): `bury` flags two legs sunk together in a
held pose, and on grounded loops `house` flags splayed feet, an upright squat and a face looking at
the floor.

How to pose legs for a strike: front leg `raise` 18-30 (steps forward), rear leg `raise` −40 to
−50 (stretched long behind; it pushes), feet under the hips (`spread` 0-5), toes turned with
`twist`, both `space = "root", ground = true`. `CombatMoves.leg{...}` sets both flags.

## 5. How Roblox applies a pose

- **The Animator writes every `Motor6D.Transform` each frame, before `RunService.PreSimulation`.**
  The Transform carries the Pose's rotation *and* position, so slides play in game exactly as
  keyed. Nothing extra runs at runtime.
- **Procedural motion on top** (lean into velocity, a strafe turn), if a game wants it, belongs in
  `PreSimulation`, multiplying the Transform the Animator just wrote; it then resets every frame.
  The reference system's Turning script writes `C0` instead, which persists and fights other scripts. This skill
  no longer ships a runtime layer module; keep such scripts small and separate from the clips.
- **All of this is visual.** Hit shapes and gameplay read the HumanoidRootPart on the server,
  never the drawn limbs, so a slid fist never changes the hitbox.

## 6. Why not IKControl, and what replaced each IK feature

IKControl does not work on R6 (a Roblox staff reply on DevForum: single-part limbs almost never
have a solution; `Position` targets go NaN). The first version of this skill wrote its own
one-joint IK instead. The user found it made R6 timid, so it was removed:

| Removed | Why it hurt | What to do instead |
|---|---|---|
| `aim` keys (fist on a target point) | a fixed-length arm on a fixed line; the shoulder never moved, so every punch stopped short | key the arm angle, then `pos.forward` 0.6-0.9 on the shoulder; the audit's `commit` check wants the fist 2.4+ studs out |
| `feet = "planted"` solver | pinned the hips over the feet and opened the legs only as far as needed: no lunge, no step | `space = "root"` + `ground = true`, and step the legs yourself |
| `headCounter` | took back a share of every torso move automatically | key the head: `turn` about −0.4 × the torso twist keeps the eyes on target |
| `R6Layers` modes FK+IK / FK / IK / None | runtime IK aim and foot IK pulled clips off their authored poses | play clips as authored; add procedural turning only if the game needs it |
| `R6Rig.aim`, `plant`, `softDistance` | the IK math | `R6Rig.orient` remains, used only by `R15ToR6` to copy where an R15 limb points |
