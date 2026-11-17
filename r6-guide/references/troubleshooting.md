# Troubleshooting and regression history


Every one of these shipped once and was caught by the user or a playtest. Each has a fix in the
code and a check that fails if it comes back. Do not remove the checks to make a clip pass.

| Mistake | Fix | Caught by |
|---|---|---|
| Grounding pushed a legal-budget thigh inside the torso | shallower body drop and explicit thigh/torso OBB checks | R6Quality.audit / check_quality |
| IK aims and planted-leg solving made every move cramped and timid | no IK; angles plus short slides | audit `commit` (fist 2.4+ out, torso 25+ turned) |
| A 60-degree torso twist swapped the hips and crossed the legs into an X | legs on a pelvis (`space = "root"`, `hips` 0.35); R15ToR6 hangs legs from the R15 pelvis | audit `legs` (centre lines, X from side/front); tests |
| An arm flung back (raise -55) came home to the guard (150) over the head: rotation blends take the shortest way, and 193 degrees is "shorter" backwards | R6Clip interpolates the named angles, not the rotations | audit `overhead` and `export`; test on all four dashes |
| Reading an overhead arm back out of a clip gave swing ±179, which interpolates as a full spin | `R6Study.entry` picks the Euler split and 360-wrap nearest the previous frame | test "study angles stay continuous" |
| The reference walk/run/fall "cross" from the side: legs passing in a stride | `meta.stride = true` (front view only) | audit `legs` |
| Roblox's default Animate stopped the idle the moment it loaded | empty `Animate` script; R6Locomotion replays a stopped loop | playtest |
| The wall run caught the wall in the Jumping frame, before the jump's push, and "landed" at once | catch walls only in Freefall, 1.5 studs clear of the floor; keep the jump's rise | playtest |
| Dash distances measured wrong because someone was steering the character | disable the PlayerModule controls (or WalkSpeed 0) while measuring | playtest method |
| A sword slash was judged by the fist, not the blade (the skill had no weapon) | `meta.tip` in the audit, `--tip` / `opts.tips` in study, sweep lines (fastest frame, centre crossing) | test "meta.tip measures from the weapon" |
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

