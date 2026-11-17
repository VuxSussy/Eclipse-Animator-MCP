# Weight and feel on R6

> New body-clearance requirement: source poses may telescope thighs into the torso. Preserve the measurement as provenance, but do not copy that artifact. Run R6Quality.audit and follow body-clearance.md. Grounded soles and legal slide budgets do not prove that the visible thigh is clear.

How to make six blocks feel heavy, snappy and smooth instead of plastic. Every number names its
source (details in `sources.md`). Numbers are starting points to vary, not laws. Only the four
non-negotiables in SKILL.md hold everywhere.

## Contents
1. Why R6 reads as plastic
2. Timing
3. Spacing: which ease goes where
4. Overlap and drag
5. Holds, overshoot and settle
6. Working the six-part body
7. Locomotion numbers (measured)
8. Impact: hit-stop, reactions, camera, effects
9. The anti-plastic checklist
10. Learning from other clips

## 1. Why R6 reads as plastic

Mostly from DevForum critiques of R6 combat animation:
- **Even spacing and linear keys.** Every in-between moves the same amount, so nothing accelerates.
- **Twinning.** Left and right do the same thing at the same time.
- **Everything moves at once.** No part leads and no part drags.
- **A strike that slows at the end.** It reads as touching air instead of hitting.
- **Cutting out of a move.** No follow-through, or straight back to the start pose.
- **A dead idle.** The pose is held at zero motion.
- **Sliding feet.** The root drifts over planted feet, or the feet ride the torso's twist.
- **Tucked-in limbs, or limbs thrown off the body.** An arm locked in its socket stops every punch
  short and reads timid (the user's complaint about the IK version). An arm thrown 2-4 studs out
  (some Toolbox packs) reads as a broken rig. Slide limbs a short way: `posing.md` section 3.
- **A body that does not commit.** The fist moves, the torso barely turns. R6 punch references
  turn the torso 30-110 degrees and lunge 0.2-0.65 stud.
- **Punches on the wrong line.** Aimed at shoulder height instead of the target's centre line.
- **Travel inside the clip.** An animation that carries the body far, or keys HumanoidRootPart.

R6 has fewer joints than a human, so it needs *more* exaggeration than feels natural (Sakurai via
the motion bible; DevForum "exaggerate more on rigs with few joints").

## 2. Timing

**Short before the hit, long after.** The hit lands at a third to a fifth of the move (Sakurai).
The starter kit lands at 29–34%. Creator Store R6 punch packs land later, around 50%, and carry
the weight in the recovery instead of a hold; use that for single heavy moves, the earlier hit for
a chained M1 string.

| Move (60 fps) | Total | Load | Strike | Hit at | Hold | Recovery | Hit-stop |
|---|---|---|---|---|---|---|---|
| Jab (power) | 30 f (0.5 s) | 4 f + 3 f hang | 3 f | f10 (33%) | 8 f | 12 f, snaps | 75 ms |
| Cross | 32 f | 4 f + 3 f hang | 4 f | f11 (34%) | 8 f | 13 f | 80 ms |
| Hook | 32 f | 5 f + 3 f hang | 4 f | f12 (38%) | 7 f | 13 f | 85 ms |
| Uppercut | 38 f | 6 f + 3 f hang | 4 f | f13 (34%) | 8 f | 17 f | 120 ms |
| Push kick | 40 f | 6 f | 6 f | f12 (30%) | 8 f | 20 f | 100 ms |
| Dash forward | 26 f | 3 f crouch | 3 f burst | Go at f6 | glide to f14 | 12 f brake | none |

Rules behind the table:
- **A key needs 4–6 frames on screen to read** (2017 GDC panel, via the motion bible). Hold the
  contact pose that long.
- **The chamber-to-contact strike is 3–5 frames.** In the Nullscript fight (YouTube) a punch goes
  from chamber to contact in about 3 frames and holds the extended arm about 6 frames or more.
- **Make a move shorter, never faster.** Cut holds, settles and recovery, never the strike (2018
  panel, Skullgirls).
- **Combo spacing.** One DevForum combo spaced its punches 0.41 s apart and they read well; at
  0.35 s they blended into each other. The kit's cancel windows open at 0.2–0.4 s.
- **A string builds.** The first hit is fast, later hits are heavier, and the finisher is the
  heaviest: deeper chamber, longer hit-stop (motion bible). Jab 60 ms → Uppercut 120 ms.
- **A player move changes pose on its first frame.** A press must read as taken at once (motion
  bible). Light jabs have near-zero chambers and heavy hits get a real one.

### Power comes from contrast (the "hang, then snap" recipe)

Two references show what makes a light punch hit hard, and the kit's Jab now follows them:
- **"cross punch"** (YouTube Shorts `X1SlPWUjW3k`, creator wesley, Moon Animator). At 30 fps:
  - the chamber holds 4–5 frames with a slight creep
  - the release takes 1–2 frames
  - an impact cone flashes at contact
  - the torso keeps turning about 0.2 s with swing arcs
  - the extension holds about 0.3 s
  - the arm snaps back to guard in 2 frames
- **A YouTube combat-system showcase**, M1s at 30 fps:
  - a 2-frame wind-up flash (a Highlight)
  - a 3–4 frame strike, with the whole body diving about 40° forward behind the arm
  - about 3 frames held at contact
  - M1s about 0.63 s apart, with random variants per hit

The recipe, in frames at 60 fps:
1. **Load and strain (4–6 frames).** Sit back, square up a little, draw the fist in, and keep
   loading through the hold. A frozen chamber reads as a stall.
2. **Release in 2–3 frames,** with the `snap` ease and the audit's `strike` window covering it.
   The slower the load, the harder a short release reads.
3. **The whole body behind the fist:**
   - lean 20–28° and lunge 0.4–0.6 stud
   - the torso turns 45–60° into the punch (jab: twist toward −50; cross: toward +60)
   - **the shoulder is thrown 0.6–0.9 stud out of its socket** along the punch line (`pos.forward`
     on the arm): the fist ends 3+ studs in front of the root, like the R6 punch packs
   - the front leg steps and the back leg extends, both hung from the pelvis (`posing.md` §4)
   - **the rear hand yanks back** to the chin as the lead fires (action and reaction)
4. **Arrive with a lurch.** `{ settle = 0.12 }` leaving contact, so the body passes the pose a hair
   and comes back.
5. **Hold 6–10 frames, creeping in.** This is what the eye keeps, and hit-stop sits on top of it.
6. **Snap home.** Return to guard over 6–8 frames with `snap`, then a short settle. Do not drift
   back slowly: a slow return gives the power away.
7. **Telegraph and juice.** A wind-up highlight for the chamber (`R6Combat` `windup`), hit-stop of
   70–80 ms even on a jab, and a one-frame impact flash or cone.

## 3. Spacing: which ease goes where

Roblox shapes the segment that **leaves** a key with that key's easing. Eclipse's exporter
interpolates segment [a, b] with a's key when it checks Roblox compatibility. `R6Clip:key(frame,
pose, ease)` follows the same rule.

| Segment | Ease | Why |
|---|---|---|
| guard → chamber (the load) | `sineInOut`, `quadIn` | the body gathers and accelerates into the load |
| chamber → contact (the strike) | `snap` (cubicOut), over 3–5 frames | leaves at full speed and brakes into the pose; over 1–2 frames any curve pops |
| contact → end of hold | `sineInOut`, with a few studs/degrees of creep | a hold that is alive, not a freeze |
| hold → guard (recovery, long) | `{ recover = 0.08–0.15 }` | eases out, drifts a little past guard, settles |
| short arrival (a reaction beat, a small adjust) | `{ settle = 0.1–0.2 }` | arrives at 20% of the segment, one bounce back |
| idle and breathing loops | `sineInOut` | a moving hold |
| a deliberate snap or step | `"constant"`, or bake `{ step = 5, stepped = true }` | the team's "on twos" house look: 12 poses a second, Constant easing |
| Eclipse's default curve | `smooth` = bezier (0.42, 0, 0.58, 1) | what an Eclipse user sees by default |

Roblox Pose easing has only Linear, Constant, Elastic, Cubic, Bounce and CubicV2. Moon Animator and
Eclipse **bake** anything richer into dense keys, and so does `R6Clip:bake()`: every frame, then
`R6Clip.reduce` drops keys that straight interpolation reproduces within 0.25°.

All 14 clips in the user's R6 movement system are baked this way: one key per 1/60 s, all Linear. Dense
Linear keys are the normal export of good R6 animation, not a smell. Legacy `Cubic` runs with In
and Out swapped, so use `CubicV2` when writing sparse keys.

## 4. Overlap and drag

- **The torso leads, the extremities trail.** Hips before chest, chest before arm, arm before fist
  (motion bible "drag / lag"; DevForum "the shoulder moves first and the arm lags behind").
- **Leads in the kit:**
  - attacks: `Torso +1`, the non-striking arm `−1`, `Head −2`
  - dashes: arms `−2`
  - idle: head `−4`, arms `−2/−3`
  - `R6Clip` extends the bake until trailing parts land.
- **The body keeps going after the fist stops.** The upper body lurches a frame or two past the
  arm's stop (DevForum R6 thread), then settles.
- **Delays must not add up.** If drag makes the fist late for the hit, the audit's contact check
  flags it.
- **The head counters, by hand.** Key `turn` at about −0.4 × the torso twist and ease off the nod,
  so the eyes stay on the target. The movement system takes back 35% of its sprint lunge at the neck. The
  hydraz run reference keeps the head level while the chest twists 30–45°. Never slide the head.
- **Springs give character.** Lightly underdamped head and waist (motion bible dials): bake the
  wobble into keys with a lead of −2 on the head, or a `settle` ease.

## 5. Holds, overshoot and settle

- **Overshoot 1.1–1.2×** past the pose on Hunter-style moves. Above 1.3 reads as cartoon (motion
  bible dials).
- **Settle 0.05–0.25** bounce. More than 0.5 is wobbly (motion bible).
- **Holds stay alive.** Creep a little toward the target (the bible's "attacker creep") or drift
  and breathe. A dead freeze reads as a stall or a network hitch.
- **Pose C.** A to B to C, never back to A. A recovery leans into the next move's wind-up, so the
  next press feels instant (bible "anticipation at the end").

## 6. Working the six-part body

- **The torso is the spine.** Twist it against the hips and lean it into the move. On a run, the
  chest twists 30–45° against the hips and the shoulder line rolls 15–20° (hydraz reference, motion
  bible). Stances turn the torso 70–90°.
- **Rotating the torso drags the legs,** because the legs are children of the Torso (DevForum),
  and a big twist swaps the hips front-to-back and crosses the legs. Hang the legs from the pelvis
  (`space = "root"`, with suitable `hips` weighting) and ground support feet (`ground = true`).
  Keep the visible thighs clear; use a shallower drop when a rigid leg cannot reproduce the source crouch.
- **A foot passing under a lowered hip** (a step, a kick chamber) needs a passing key with the
  body risen. The leg has no knee to fold.
- **No elbows.** To suggest a bent elbow or a cocked fist, move the whole arm to where the forearm
  would be, and let the shoulder "detach" from the torso a little (DevForum R6 thread; the movement system's
  clips slide arms 0.15-0.9 stud). That slide is `pos` on the arm.
- **Treat the knee as if it sat at the hip** (DevForum). Small hops at the end of moves stand in
  for toes rising.
- **A sideways arm ignores raise.** At spread ≈ 90 the raise axis lies along the arm. Lift it with
  spread past 90 (the kit's hook uses 100).
- **Silhouette first.** Check every key pose from the play camera. The arms leave the body at
  60–90° from the sides (hydraz reference).
- **The Torso `pos` offset** (sink, lunge) must stay small, about a stud at most. The hitbox is the
  HumanoidRootPart, and a visual body far from it lies to the player.
- **Limb slides stay short.** Arms 1.0, legs 1.5, head 0.15 (`R6Rig.GAP`, audited).

## 7. Locomotion numbers (measured)

These come from the user's R6 movement system, measured offline.
The clips are baked at 60 fps, all Linear.

| Clip | Length | Key facts |
|---|---|---|
| idle v2 | 1.883 s, loop | tiny: legs splay 6–10°, head nod 1–3°, arms 2–7° |
| walk v3 | 0.833 s, loop | legs swing −35…+55°, arms ±20–29°, torso leans 8–11° and bobs 0.10–0.25 stud, head counter-rolls ±8° |
| run v4 | 0.633 s, loop | legs −58…+80°, arms −37…+122° (the forward arm swings high), torso leans 18–24°, rolls ±18°, bobs 0.25–0.34 stud, head counters ±18° |
| jump | 0.433 s | arms rise to 65°, torso pitches up to 17°, head 29° |
| fall | 1.35 s, loop | arms up 52–88°, legs paddling |
| Normal Land | 0.167 s | torso dips 15–33° forward and 0.32–0.39 stud down |
| Short / Long land | 0.467 / 0.667 s | big arm throw (to 104°), torso folds up to 42° / 57° |
| CrouchWalk | 1.2 s, loop | torso leans 37–45° |

Procedural numbers from the same system's turning, falling and animate scripts:
- **Lean by momentum.** Walk 0.020, sprint 0.007, crouch 0.025 rad per stud/s, blended at 4/s.
- **Sprint-start lunge.** 0.6 rad (34°) forward, decaying at 4/s. The neck takes back 35%.
- **Turning.** The hips yaw up to 40° toward a strafe and the torso counters.
- **Blend times by pair of clips:**
  - idle → walk 0.25 s, walk → idle 0.30 s
  - walk → run 0.18 s, run → walk 0.22 s
  - run → idle 0.30 s
- **Clip rate follows speed.** Walk plays at speed / 14.5, run at 1.3, and walking backwards plays
  the clip reversed.
- **Landing tiers by fall height:** under 4 studs normal, 4–15 short, over 15 long. Camera shake
  0.15 at 0.35 s for a short fall, 0.2 → 2.0 over 0.3 → 0.7 s for a long one.
- **The camera.** FOV 70 walk, 90 sprint, 62 crouch, 55 crawl, eased over 0.35–0.5 s. Bob 7 steps/s
  walking, 15 running. A 0.18-stud dip on landing.

Its limb slides, measured with `lune run study` (the house grammar, `reference-first.md` §5):
arms 0.15 idle → 0.4 walk → 0.7 run; legs ride 1.0-1.6 into the torso; the head never moves off
the neck. These are measurements of the old source: visible thigh burial must be repaired, not imitated.

Two runtime parts of that system are worth improving if a game copies them: its turning writes
`C0` every frame with a frame-rate *dependent* lerp (write `Motor6D.Transform` in PreSimulation
with `1 - exp(-rate·dt)` instead), and its "IK" hides the real legs and moves a cloned pair by
raycasts. This skill ships neither: clips play as authored.

## 8. Impact: hit-stop, reactions, camera, effects

- **Hit-stop.** 50–80 ms on light hits and 100–160 ms on heavy ones (motion bible). Both fighters
  freeze, the attacker lightly. Repay the freeze inside the drawn recovery, never on the server
  clock.
- **The victim starts displaced.** Frame 0 of a reaction is already the struck pose: no wind-up.
  In the Nullscript fight the victim is thrown back on the very next frame after contact, torso
  pitched back about 45°, head snapped. The hurt pose blends in over about 4 frames during the
  freeze (motion bible).
- **Reactions cut in hard** (fade 0). Hits start hard. Only the way *out* of a move blends
  (0.1–0.15 s).
- **Camera.** Shake on impact, but not on every hit, or nothing reads as big.
  - Nullscript cuts to a close-up on a fist clash and holds it about 0.5 s.
  - Hovark (TikTok) flashes a blank frame, then cuts to a near-POV angle at contact, with tilted
    (dutch) angles on aerials.
  - FOV kicks on dashes (movement system, DevForum).
- **Effects meet the motion, never bury it:**
  - a one-frame impact star at contact, with radial speed lines (Nullscript)
  - white arc trails on swings
  - 2D swirl or wind lines held about 0.25 s around a landed kick (Hovark)
  - smear frames only on the fastest strike frames
  - trails never run through the wind-up (motion bible)

## 9. The anti-plastic checklist

Run it on every clip, by eye in `preview.html` at 1× and 0.25×, and with `R6Clip.audit`:

- [ ] Brief written: weight, striking limb, what reads first, keywords.
- [ ] Load opposite the strike. The torso twists through the hit in the right direction
  (orthodox: jab and lead hook clockwise, cross and uppercut counter-clockwise).
- [ ] A reference found and measured (`reference-first.md`), or the fallback to the house grammar
  said out loud.
- [ ] Hit at 20–50%, strike over 3–5 frames, contact held 4–6 frames with a little creep.
- [ ] The body commits: torso turned 40+ into a straight punch, a lunge, the fist 2.8+ studs out.
- [ ] Ease per segment (section 3). No linear-everywhere, no ease-in-out on the strike.
- [ ] Leads and trails set: torso first, head and free arm behind.
- [ ] Feet on the floor during grounded moves (the audit's dig and hover are both near 0), legs
  never crossed (no `legs:` note).
- [ ] The recovery overshoots guard a touch and settles. The next move can start from it.
- [ ] Slides short and along the motion (no `gap:` note); the head only rotates.
- [ ] The striking limb lands on the target's centre line.
- [ ] No HumanoidRootPart keys. Travel is physics (`R6Combat` dash burst).
- [ ] Priorities are correct (idle < movement < action < block < reaction) and no two clips share
  a priority on the same joints at once.
- [ ] Audit clean, and seen from the side and from the front.

## 10. Learning from other clips

`lune run study <file>` (or `R6Study.measure` in Studio) prints the R6 numbers that matter for
imitation: timing, the strike line, torso drop/lunge/lean, every part's rotation reach and socket
slide. `Sequence.analyze(Sequence.read(ks))` adds, per part, travel, peak speed and holds, for any
rig (R15 too). The full method is `reference-first.md`.

To study a clip you like:
- Measure where its peak speed falls (the strike).
- Count its holds and see how far the torso turns against the legs.
- Copy the *proportions*, not the keys.

For R15 sources, convert first (`r15-to-r6.md`) and measure both sides. The convert tool prints
them.
