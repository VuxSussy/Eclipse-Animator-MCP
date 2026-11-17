# Where this skill's knowledge comes from

Each source, what was taken from it, and how it was read. Nothing was copied as code from
third-party work. The user's movement system and Eclipse Animator were read offline, as data only, and are
described here in our own words, the way the team's clean-room studies do it.

## Skills that already existed (searched first)

- **`roblox-game`** (`references/animation-vfx.md`): the general Roblox animation API.
  - Load through the Animator, not Humanoid:LoadAnimation.
  - Priorities Core < Idle < Movement < Action < Action2–4.
  - `GetMarkerReachedSignal` for hit timing.
  - Blend with fade times and weights.
  - AnimationController plus Motor6Ds for custom rigs.

  It says nothing about R6, R15, IK or feel. This skill fills that gap.
- **Eclipse Animator MCP** (the user's own server): tools, not knowledge.
  - `list_rigs`, `get_animation` / `save_animation` (keyframes as `{time, poses: {Part: {rot (deg,
    XYZ), pos, easing, direction}}}`, which `R6Clip.toEclipse` emits)
  - `preview_animation`, `enhance_animation`
  - `import_animation_pack` (R15 → R6), `video_to_animation`
- **`rbx-scene-analysis`** (Roblox Studio Assistant): measures animation assets in a place, for
  memory and performance only.
- **Org skill and plugin catalogs:** nothing for R6 animation. `roblox-dev` has no animation
  skill. `animation-studio` is 2D video.

## The user's R6 movement system

Read offline from `<movement-system>.rbxm` (in `~/Downloads`) with Lune: 6,683 instances and
75 scripts, nothing run. 15 KeyframeSequences were measured, the second time (2026-10-28) with
`lune run study`, which added the limb slides: arms 0.15-0.9 stud along their swing, legs riding
1.0-1.6 into the torso, the head never off the neck. That measurement is the house grammar when no
R6 reference exists (`reference-first.md` §5).
- **Clips.** Dense 60 fps keys, all Linear (baked from a curve tool). Lengths and joint ranges are
  in `weight-and-feel.md` section 7.
- **Turning.** Every frame, writes C0 on RootJoint, Neck and both Hips:
  - lean by momentum (walk 0.020, sprint 0.007, crouch 0.025 rad per stud/s)
  - hips yaw toward a strafe (40° range)
  - a sprint-start lunge of 0.6 rad decaying at 4/s, the neck taking back 35%
  - lerp `1 − 0.005^dt`
- **IK.** A cloned leg pair follows raycasts (1.4 studs down, 0.3 stud forward offset), one leg at
  a time, lerping 0.2 per frame, with the real legs hidden. Weaknesses: frame-rate dependent,
  local only, and it breaks the real rig's animation. This skill no longer ships any IK.
- **Animate.** Blend time per pair of clips (0.18–0.30 s), walk rate speed / 14.5, run 1.3, walking
  backwards plays the clip reversed.
- **Falls.** Three tiers by height (4 / 15 studs), a camera shake from Perlin noise that grows
  with the height, a damage rule.
- **The team's earlier study** of the same model (`se370/game/docs/research/r6-movement-kit.md`)
  says the weight lives in how the body and camera answer the move, not in the physics. That
  study agrees with this measurement.

## Creator Store R6 punch packs (2026-10-28)

Found with `robloxstudio` `search_assets` ("R6 punch animation"), loaded in edit mode with
`game:GetObjects` (scripts destroyed before parenting, never run), exported with `export_rbxm`
and measured offline with `lune run study`. Only numbers were taken; no keys were copied.
- **"Punch Anims Animation Pack R6 Combat Fighting"** (asset 85161273651688, an R6 rig with 10
  clips: 9 strikes and an equip; it carried 2 scripts despite "No scripts"). The commitment numbers
  in `reference-first.md` §6 come from it: torso 30-110 degrees into the punch, fists 2.2-4.2 studs
  out, striking arm slid 0.5-1.0 at contact, hits around 50% of 0.45-0.75 s clips.
- **"R6 Punch Animations Fighting Combo Moveset"** (asset 80460719695191) and its duplicate
  107810164673839: arms-only weapon swings, arms thrown 2.5-3.8 studs out. Timing only; the slides
  are past the user's "short distance".
- `insert_asset` refused both ("not authorized"); `GetObjects` worked. Asset 91364775395456 could
  not be loaded at all.

## Creator Store wall-run and parkour packs (2026-10-28)

Same method (search, `GetObjects` with scripts destroyed, `export_rbxm`, `lune run study`):
- **"R6 Parkour Animations"** (asset 15259391918; the description grants full rights, credit
  appreciated): Climb, Crouch, Falling, Grab, Idle, Roll, Slide, Sprint, WallRunL, WallRunR. The
  kit's wall run imitates WallRunR.
- **"Wall Run Animation R6 Parkour Dummy Pack"** (103291843985457) and **"Wall Run Animation
  (r6)"** (13289041733): LeftWallRun/RightWallRun with an almost upright torso (lean 2-3 degrees);
  not used, the parkour pack's 25-degree tilt reads as running on a wall.
- 77251926150649 and 4935124655 hold only an "Automatic Save"; 74885347629474 could not be loaded.

## Sources for brand-new moves (2026-10-29)

Found while building `new-moves.md`, after the skill answered a mage request with reposed punches:
- **"R6 Magic Spell Animation Pack x24"** (Creator Store 139756676371748), found with "R6 magic
  animation" and "R6 fireball animation" ("R6 spell cast animation" found nothing). Not measured
  yet: Studio was disconnected when it was found.
- Web search "spell casting animation reference video mocap two hands fireball": Rokoko's free
  magic-themed mocap, Kevin Iglesias' "Human Spellcasting Animations" (a free version on itch.io),
  Rapamotion's "Mage Abilities" mocap, and an Animation Mentor note to film your own reference.
- **"Human Spellcasting Animations FREE"** (Kevin Iglesias, kevdev.itch.io; name your price; the
  page states no license text): downloaded with the user's approval (the "Blender files only"
  build, 2.3 MB, `HumanF_`/`HumanM_SpellcastingAnimationsFREE_2.0.blend`, 46 takes each).
  `MagicAttackDirect2H01` (male and female) are the references of the `mage/` example. The
  files are not in the repository; only measured key poses are.
- Tools on this machine that make those usable: Blender 5.2 (headless FBX/BVH/GLB import, used by
  `tools/mocap_points.py`), yt-dlp and ffmpeg (video frames, with permission), and the
  `eclipse-animator` MCP's `video_to_animation` and `import_animation_pack`.

## The user's correction (2026-10-28)

After the first version the user judged the IK-driven clips cramped, timid and without force and asked for: reference first (find the R6 version and imitate it, else
follow the movement system file), no IK/FK systems, and limbs allowed a short way out of the torso. On the
first rebuilt Cross they then caught the legs crossing into an X under a 60-degree torso twist,
which led to the pelvis space (`hips`) and the audit's leg-cross checks. Later the same day they
caught arms coming home "the long way" over the head after the back dash (rotation blends across
more than 180 degrees), asked for dash arms flung back, no guard on side dashes and a kneeling
back-dash finish, and for climb, wall run and landing clips; and asked that the skill be updated so
these mistakes do not come back (SKILL.md "Mistakes this skill has made").

## Eclipse Animator (riftkuro), `~/Downloads/eclipse.rbxm`

Read offline (362 scripts, about 239k lines), plus the user's own notes in
`~/dev/EasyAnimator/REVERSE-ENGINEERING.md`:
- **Default curve.** Bezier (0.42, 0, 0.58, 1) with auto-clamped handles. It exports the nearest
  native Pose easing plus a Moon-style `Ease` folder, and bakes dense keys when no native style
  fits (Constant on frame-skip). Its compatibility check interpolates segment [a, b] with **a's**
  easing, which confirms that a Pose's easing shapes the segment leaving it.
- **Easing library.** Includes Back (Overshoot), Elastic and Bounce, and Sine through Expo and
  Circ. These are not native on Roblox poses, hence baking.
- **IK.** LimbIK, BoneIK, SoftIK, IKKeyframing:
  - Soft IK starts at 90% of reach and approaches it on `1 − e^{−x}` (an earlier version of this
    skill copied it; removed with the rest of the IK).
  - The R6 limb is treated as a two-link chain with a virtual bend 65% of the way down
    (`R6BendPercent`, migrated from 74.2), solved with a pole and 4 correction passes.
- **Dynamics and physics baking.** Spring bones (Damping, Stiffness, Gravity) are simulated, then
  baked into keys: secondary motion as data. Our `R6Rig.Spring` (exact) and the clip leads play
  this role.
- **Export and storage.** Clips go to AnimSaves as KeyframeSequences with 7 priorities. Projects
  are stored as JSON chunks in ServerStorage.
- **The R15 template rig's joint values** were read as data for `R15ToR6.JOINTS`. They are
  Roblox's stock block-rig values.

## The user's EasyAnimator and Eclipse-Animator-MCP

`~/dev/EasyAnimator/src/Retarget.luau` uses the body-points method: every source becomes 3D
points, and joints are solved parents-first by aim. It measured 0.03° worst limb error on R6.
`Enhance.luau`: strength scaling, Linear → CubicV2 ease, overshoot-and-settle on moves over 15°
(push past by k, settle within 0.15 s), seamless loops, and a 175° cap so Roblox does not take the
short way round. `R15ToR6` and the `settle` and `recover` eases are built on these ideas.

## The team's motion bible (`se370/game/docs/motion-bible.md`)

- the anatomy of an attack and the hit placement (a third to a fifth)
- readable keys at 4–6 frames, "shorter, never faster"
- the keyword vocabulary (snappy, punchy, heavy, drag, settle…) and the dials (overshoot 1.1–1.2,
  settle 0.05–0.25)
- hit-stop of 50–80 / 100–160 ms
- the hard rules (pops, contact at active, floor contact, hand-overs, crossing)
- the motion-range study of hydraz's R15 combat reference (chest 30–45° against hips, arms 60–90°
  out, holds near extremes)
- "on twos" stepped baking as the house look

The audit in `R6Clip.audit` is these hard rules turned into code.

## The two videos

- **YouTube, Nullscript, *A generic roblox fight animation | Moon Animator*** (`dm5WJPQE738`,
  17 s, made in about 4 days). Studied frame by frame at 1 s steps and at 0.05 s steps around an
  exchange:
  - low, wide stances; the torso leans 30–45° into strikes
  - arms fully extended at contact; chamber to contact in about 3 frames; the extended pose held
    about 6 frames or more
  - the victim thrown back on the next frame, torso pitched back about 45°
  - a one-frame impact star with radial lines; white swing arcs
  - a dash-in crouched with the arm cocked, about 0.3 s
  - a clash cut to a close-up held about 0.5 s
  - viewers praise how readable it is and study it slowed down for the legs
- **TikTok, Hovark, R6 fight** (`7699064580944792840`, 16 s, "my first time making something like
  this in Roblox Studio", #r6). Studied at 1 s, 0.5 s and 0.075 s steps:
  - airborne tuck spins of about 0.3 s before a strike
  - a blank or flash frame at impact, then a cut to a near-POV angle
  - 2D swirl or wind lines held about 0.25 s around the landed hit
  - dutch angles; the opponent grounded after a dive kick
  - the creator's other posts mention making a hammer "feel heavy" and refs from TSB and Legends
    Battlegrounds

- **YouTube Shorts, *cross punch*** (`X1SlPWUjW3k`, creator wesley, Moon Animator, 5.8 s, 360×360,
  the punch shown from several angles). Studied at 1/30 s steps through one punch:
  - the chamber is held 4–5 frames with a slight creep
  - the release takes 1–2 frames
  - a white impact cone at contact
  - the torso keeps turning about 0.2 s with swing arcs
  - the extension held about 0.3 s
  - a 2-frame snap back to guard
  - an orange outline glow on the striking arm

  The user asked for a jab with this much force. It is the source of the power-jab recipe in
  `weight-and-feel.md`.
- **YouTube, a free combat-system showcase** (46 s), by the author of the user's R6 movement
  system. On-screen features:
  - "Random M1 Combos (randomized punch animations and combo chains)"
  - "Wind-Up Highlights (highlight players briefly before attacks)"
  - a knockout system, a bodyshot (lands only while the opponent blocks), block break, dashing, and
    debug options

  The M1s, studied at 1/30 s steps from the over-the-shoulder camera:
  - a 2-frame tan highlight flash at the wind-up, fading over about 3 frames
  - a strike of 3–4 frames with the whole body diving about 40° forward and twisting behind the
    arm
  - about 3 frames held at contact
  - punches about 0.63 s apart

  This led to R6Combat's `windup` highlight and combo variants.

## DevForum and the web (a research agent pass, with every link kept)

Video pages themselves gave no transcripts, so these come from DevForum feedback threads:
- **Punch timing.** Fast strike, abrupt stop, slow retraction, start from a strong ready pose.
  Three keys are enough: start, charged, extended.
- **Combo spacing** 0.41 s works and 0.35 s blends. Fades of 0.1–0.2 s normally, 0.1–0.15 s between
  combo hits, 0 for deliberate cuts. Use `GetMarkerReachedSignal`, not waits.
- **R6 posing tricks.** Move the whole arm to where the forearm would be. Treat the knee as at the
  hip. Exaggerate more. A small hop at the end. Torso twist drags the legs (pose them back).
- **Plastic causes.** Linear keys, twinning, everything at once, sliding feet, keying
  HumanoidRootPart.
- **IKControl does not work on R6 limbs** (a staff reply, NaN reports). Foot planting on R6 is
  build-your-own with raycasts.
- **R15 → R6 plugins** (6to15) map limbs and lose hands, feet and easing fidelity.
- **Hit-stop with `AdjustSpeed(0)`** is unreliable without a key at the marker. Add one.
- **The Adaptive Animations beta** once stopped the R6 torso rotating (December 2025). Turn it off
  if the torso freezes.

Links (DevForum topic ids): 2159530, 2042214, 2974402, 2046945, 1989275, 707780, 1507373, 1741255,
1533251, 225752, 1413330, 1900696, 2397709, 2156480, 2270766, 2929361, 2213267, 3586405, 2662256,
522708, 4147390, 2643111, 2927980. Also the PoseEasingStyle docs on create.roblox.com, and
kitsblox.com/blog/fix-choppy-roblox-animations.
