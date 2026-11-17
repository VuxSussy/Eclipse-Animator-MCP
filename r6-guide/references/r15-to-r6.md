# Learning from R15 and converting to R6

Most animation packs, emotes and tutorial clips are R15. They are worth learning from (timing,
spacing, silhouettes), and many can be turned into usable R6 clips.

## Why copying joints fails

R15 has 15 parts; R6 has 6. An R6 arm has no elbow and an R6 leg has no knee. A single R6 torso
stands for LowerTorso + UpperTorso. Copying the shoulder rotation alone throws away the forearm, so
the fist ends up somewhere else. That is why simple mappers lose hands, feet and lower limbs, and
why the 6to15 plugin's author says the easing "can't be fixed" (DevForum).

## The method (body points, then solve)

Both `R15ToR6` and the user's EasyAnimator use this idea; EasyAnimator measured 0.03° worst limb
error on R6.

1. **Play the R15 clip forward** (FK on the R15 joint table) into body points: shoulders, elbows,
   wrists, fists, hips, knees, ankles, soles, the pelvis.
2. **Torso.** Its "right" is the shoulder line and its "up" runs from mid-hips to mid-shoulders. A
   twisted chest over still hips gives a torso turned by the chest's twist, and hip sway survives
   too. The pelvis offset from rest moves the R6 torso (crouches drop it).
3. **Head.** Copy the R15 head's orientation.
4. **Arms.** Point the pivot→fist line along the R15 shoulder→fist line (`armBlend = 0`, "reach",
   the default), or along the R15 upper arm (`armBlend = 1`, "silhouette", for bent-arm guards),
   or between. Then **slide the arm out of its socket** (up to `armSlide`, 0.8 stud) so the R6 fist
   lands on the R15 fist: the R15 arm is shorter when bent and longer when the shoulder blade
   reaches, and the slide carries that. The roll comes from the R15 hand's front.
5. **Legs.** Hang each leg from the **R15 pelvis** (LowerTorso), not from the R6 torso, which
   carries the chest's twist: hanging them from the twisted torso swaps the hips front-to-back and
   crosses the legs. Point the leg from that hip to the R15 sole, then **slide it into or out of
   the torso** (up to `legSlide`, 1.5 studs) so the sole lands on the R15 sole. `opts.hips` (default
   1) scales how much of the pelvis's turn the hips take. Bent R15 knees become the R6 leg
   riding up into the torso, the way the movement system's crouch and landings do it. `ground = false` turns
   the leg slide off. The roll comes from the R15 foot.

There is no IK in this: each frame copies where the R15 points are (`R6Rig.orient` turns a limb
along a direction; the slide is a translation).

Measured in `tools/check.luau` on synthetic poses:
- the R6 fists land on the R15 fists within 0.02 stud, with the arm slide inside 0.8
- the torso keeps a 35° chest twist within 1°
- both soles land on the R15 soles within 0.03 stud
- a 0.9-stud pelvis drop carries over

## Three ways to run it

| Where | How | Exactness |
|---|---|---|
| Offline (Lune) | `lune run convert <file.rbxm/.rbxmx/.rbxl> <outDir> [clip names] [--blend=0.5] [--no-ground]` | R15 poses read by `Sequence`. Exact for Linear, Constant and CubicV2 keys (dense baked clips are all Linear); legacy Cubic, Elastic and Bounce are approximated |
| Studio, from a plugin, the command bar or MCP `execute_luau` | `local frames = R15ToR6.sampleInStudio(r15Rig, ks)` → `R15ToR6.convertSampled(frames, opts)` → `R6Clip.toKeyframeSequence(...)` → parent into the R6 rig's `AnimSaves` | exact: the engine's own Animator plays the source |
| A whole Roblox pack, or an id or link | `eclipse-animator` MCP `import_animation_pack` | R15 → R6 retargeting built into the user's Eclipse MCP |

The convert tool prints both analyses (source per R15 part, result per R6 part) and the audit.
Check the result in its `preview.html`.

## Tested on real clips

The team's R15 combat clips (SingleJab, SingleCross, SingleUpcut, SingleElbowStrike, in
`se370/game/build/bastion-sandbox2.rbxl`) were converted offline, and only read for this.
- The R6 results keep the source's speeds. The R6 torso peaks at 8,799°/s on the cross against
  LowerTorso + UpperTorso at 5,048 + 3,812°/s.
- The audit's "pops" are the source's own first-frame snaps, kept faithfully: those clips change
  pose on their first frame by design.
- Viewed in the preview, the converted cross reads correctly: a guard with both hands up, a big
  hip turn with the rear arm extended, and a return to guard.
- After the frame-1-to-3 snaps, SingleJab and SingleElbowStrike audit clean on the legs. SingleCross
  turns its *pelvis* about 90 degrees for frames 8-13 (the hip line points forward); the
  one-stud-wide R6 legs then pass 0.6 stud apart and read crossed from the front, and the audit
  says so. Repair: re-key those frames by hand with legs on the pelvis (`posing.md` §4), or lower
  `opts.hips`.

## What does not survive, and how to repair it

- **Elbow and knee bends.** A bent R15 arm becomes a straight R6 arm pointing at the fist and slid
  to reach it. For guards and blocks where the bend *is* the shape, try `--blend=0.5` to `1`, or
  re-pose those keys by hand (angles plus a short slide, `posing.md`).
- **Hands, feet and fingers** are gone. Their roll survives only as the limb's roll.
- **Spine waves.** Two torso parts become one. If the R15 clip's power is in the chest against the
  pelvis, re-key the R6 torso twist by hand and hang the legs from the pelvis (`space = "root"`,
  `hips` 0.3-0.5), using the measured peaks as targets. Check the audit's leg-cross notes.
- **Twists past 90°** at the waist are kept, but on one block they read as the whole body
  spinning. Consider halving them.
- **Different proportions.** For Rthro or scaled R15 sources, pass `opts.joints =
  R15ToR6.jointsFromModel(rig)`. The stock table is the default R15 block rig.
- **Snaps inherited from the source.** Keep them if the house style wants them (the team's
  "change pose on the first frame"), or smooth the first frames by re-timing.

## Learning instead of converting

An R15 clip is the third choice for a reference (`reference-first.md`): look for the move made
for R6 first. When R15 is all there is, *measure* it and re-animate on R6 more often than not:
1. `Sequence.analyze` gives the source's peak frames (the strike), holds and travel per part;
   convert it and run `lune run study` on the result for R6 numbers (torso, slides, strike line).
2. Build an R6Clip with the same frame of contact, the same hold length and the same recovery
   share.
3. Pose it R6-style: straight limbs, a big torso turn, short slides, legs on the pelvis, more
   exaggeration.
4. Compare the two reports side by side.
