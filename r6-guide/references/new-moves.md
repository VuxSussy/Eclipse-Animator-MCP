# Brand-new moves: research before you pose

A request for a move this kit does not have (a mage's cast, a staff spin, a bow draw, a summon, a
transformation, a dance emote) is a research job first. The kit's punches, dashes and walks are
the answers to other questions: reposing them into "a mage" gives a boxer waving his hands. The
first time this skill was asked for a mage animation it did exactly that, and the user caught it.

**Rule.** For a move the kit lacks, never start from `CombatMoves` or `Locomotion` poses. Go
through the source ladder below, collect at least two references (one for timing, one for body
shape), write the reference sheet, and only then key. If the whole ladder comes up empty, say so
in the hand-over and offer the cheapest real reference: the user filming themself (tier 5).

## Contents
1. Break the move down
2. Build the search vocabulary
3. The source ladder
4. The reference sheet
5. From reference to R6
6. Archetype cards (what to look for)

## 1. Break the move down

Write the motion brief before searching; it decides what to search for.

| Field | Mage fireball, for example |
|---|---|
| intent (what it does in the world) | throws a ball of fire at one target |
| body mechanics (where the force comes from) | legs and hips coil, both palms push along the aim line |
| what the hands hold or make | an energy ball between the palms; no weapon |
| phases | gather (hands come together, body coils), charge (hold, tremble, rise), release (push), recoil (the cast kicks back), recover |
| one-shot or loop | one-shot; the charge may loop while the button is held |
| grounded or airborne | grounded, feet planted wide |
| gameplay timing | projectile spawns at the release marker; cast time about 0.6-0.9 s |

## 2. Build the search vocabulary

Search engines and the Creator Store match words, not ideas. Make 6-10 queries per source from:
- **motion verbs**: cast, channel, charge, conjure, summon, blast, beam, push, slam, raise, throw
- **who does it**: mage, wizard, sorcerer, warlock, witch, caster, monk, shaman
- **what it makes**: fireball, lightning, ice, heal, meteor, shield, rune, portal, beam
- **where the look comes from**: anime ("kamehameha", "rasengan", "domain expansion"), games
  (Genshin Impact catalyst attack, Elden Ring sorcery, Dark Souls pyromancy, WoW cast animation,
  Roblox battlegrounds games), real life (tai chi push, martial-arts palm strike, dance)
- **format words**: "R6", "animation", "pack", "mocap", "reference", "moon animator", "showcase"

Some words return nothing on the Creator Store ("sword", "katana", "weapon" on 2026-10-28); when a
query comes back empty, describe the motion instead ("R6 slash animation", "R6 magic animation").

## 3. The source ladder

Go down every tier until you have two good references. Note what each tier gave.

### Tier 1: R6 clips on the Creator Store (Studio MCP)
`search_assets` (assetType Model) with "R6 <word> animation" for several words. Prefer rigs whose
description lists animations ("An R6 character rig ... N animations"). Load with `game:GetObjects`,
destroy every script before parenting, `export_rbxm` to the scratchpad, `lune run study`
(`reference-first.md` §2-3). Example: "R6 magic animation" finds **"R6 Magic Spell Animation Pack
x24"** (139756676371748: MageStance, FireballCharge, FireballBlast, PalmBolt, ArcaneVolley,
MeteorCall, RuneCircle, Heal, standing and moving versions). That pack is the first stop for any
mage move.

### Tier 2: Roblox catalog animations and emotes (R15)
Emotes and animation bundles cover dances, gestures, poses and some magic. Find ids on the web
(`roblox catalog emote <word>`), then `eclipse-animator` `import_animation_pack` with the bundle
or animation id puts an R6 version on the rig; or convert with `R15ToR6`. Measure the result.

### Tier 3: human motion capture
Real people performing the move, as FBX/BVH, many of them free:
- Rokoko's free mocap packs (a magic-themed set among them; free for commercial use)
- itch.io: "Human Spellcasting Animations Free" (Kevin Iglesias), "Mage Abilities" mocap
- CMU Graphics Lab Motion Capture Database (2,600+ BVH clips, free)
- Mixamo (the user's Adobe account: download FBX "without skin" and hand you the file)

**Ask the user before downloading** (name the file, the site and the size). Then:

```bash
lune run mocap <file.fbx|.bvh|.glb|.blend> <outDir> <ClipName> --fit=4
```

A `.blend` with many takes: list them first (`Blender -b --factory-startup --disable-autoexec
--python tools/mocap_points.py -- <file.blend> --list`), then pass `--action=<take>`. Always keep
`--disable-autoexec`: a downloaded `.blend` can carry scripts.

Blender (headless, `tools/mocap_points.py`) reads the file into body points, `MocapToR6` solves the
six R6 parts from them (arms point where the human's do, a bent knee becomes the leg riding into
the torso, the feet stay as far apart as the R6 hips), and the tool writes an `.rbxm`, Eclipse
JSON, a preview, the study report and, with `--fit`, the fewest R6Clip keys that rebuild it. Use
`--start=`/`--end=` (seconds) to cut one move out of a long take, `--in-place` to drop travel,
`--map=Role:BoneName` when a skeleton's names are unusual. The result is a reference: R6-ify it
(§5) before calling it a clip.

### Tier 4: video
Roblox R6 showcases (YouTube, TikTok, DevForum), anime and game footage, real-life clips.
- **Look without downloading**: the built-in browser, the video paused at the move, frame-stepped
  (YouTube: `,` and `.`), a screenshot at each key moment. Write down the times: they are your
  timing (frames = seconds × 60).
- **Frames to read** (ask before downloading):
  `yt-dlp -f "mp4" -o ref.mp4 <url>`, then
  `ffmpeg -ss <start> -t <seconds> -i ref.mp4 -vf fps=15 frames/%03d.png`, and read the images.
- **Video to animation**: `eclipse-animator` `video_to_animation` (MediaPipe body tracking) turns a
  clip of one person, whole body visible, steady camera, into an animation on the rig. Export it
  and run `study` on it like any reference.

### Tier 5: the user acts it out
A 3-5 second phone video of the user doing the move (whole body, side or three-quarter view) is a
real reference for anything, and the user knows exactly what they want. Feed it to
`video_to_animation` or read frames from it.

### Tier 6: no reference at all
Only after tiers 1-5: build from the archetype card (§6) and this skill's measured numbers, say in
the hand-over that the clip is unreferenced, and offer tier 5.

### Worked example: the mage fireball (2026-10-29)

The first real run of this protocol, kept in the project's `mage/` folder:
1. **Find.** Creator Store "R6 magic animation" found a 24-clip R6 magic pack (Studio was
   disconnected, so it could not be loaded). Web search found free spellcasting mocap; the user
   approved downloading Kevin Iglesias' "Human Spellcasting Animations FREE" (itch.io, name your
   price; the "Blender files only" build, 2.3 MB, two `.blend` files). On itch.io the download
   key on the page expires within seconds and the file link within 60 s: fetch right away.
2. **Convert.** `--list` showed 46 takes; `HumanM@MagicAttackDirect2H01` (two-hand cast) and the
   female performance of the same move became references 1 and 2.
3. **Read the phases, not the guess.** A phase table (fist heights and reach, torso lean and
   drop every 6 frames) showed the motion repeating after frame 96: the take loops through a
   cyclic modifier, so `--end=1.6` cut the real 1.6 s. It also showed the cast is a throw from
   over the head (dip, sweep up wide, load behind the head arched back, throw forward and down in
   4-5 frames folding 45 degrees), not the chest push one would have guessed.
4. **Key from the reference** at the phase boundaries: `lune run study <ref.rbxm>
   --keys=0,12,18,... --root-legs --hips=0`. Then R6-ify (palms 0.6 out at the release, fold and
   arch 15% deeper, the throw easing in with `quadIn`).
5. **Check hands and feet against the reference**: `lune run compare <ref.rbxm> <yours.rbxm>`.
   The first pass had the arms 33-47 degrees off the reference during the recovery: one key every
   12 frames could not follow the wide arc the arms swing on the way back. Keys every 3-5 frames
   there fixed it; afterwards the only differences were the meant ones (fists 0.9 further at the
   release, lean +7), the arms within 8 degrees, the feet within 0.05 stud.

What went wrong on the way, each now fixed in the tools:
- Legs keyed against a torso that folds 45 degrees crossed into an X from the side: hand mocap
  legs over on the pelvis (`--root-legs`).
- R6 hips are 2 studs wide, a human's about 0.4: the performer's 11-degree hip turn, five times
  larger on R6, crossed the legs again. Mocap legs hang from a square pelvis (`--hips=0`,
  `MocapToR6` default `hips = 0`).
- Legs slid along their own slant to reach the floor put the front leg's top behind the back
  leg's: R6 legs ride straight up into the torso, and each R6 foot goes where the human foot is
  (shifted out to R6's hip width), so planted feet do not skate while the body folds.
- A pose that names one part twice ("RightLeg" from a merge, "Right Leg" added) kept whichever
  the table listed last: R6Clip now refuses it.

## 4. The reference sheet

Put it in the hand-over and in the clip's code header:

| Source | Where | Taken | Left out, and why |
|---|---|---|---|
| <pack name> <clip> | Creator Store <asset id> | timing: charge f<a>-f<b>, release f<b>-f<c>; torso drop <n> | <what you did not copy and why, e.g. arms slid past the budget> |
| <mocap pack> <take> | <site> | <the gesture, via `lune run mocap`> | <e.g. the walk-in before the cast, cut with `--start`> |

Fill it with what you measured; never with numbers you did not measure.

A clip with no sheet, or with only kit moves on it, is not done.

## 5. From reference to R6

1. **Numbers first**: `lune run study` (R6 clips) or `lune run mocap ... --fit=4` (mocap, video
   conversions) for timing, phases, the torso's turn/lean/drop, and key poses.
2. **Key from the reference**: put your keys on the reference's key frames and start each pose
   from the reference's numbers (the `--fit` tables), not from `CombatMoves.Guard`.
3. **R6-ify**: R6 has no elbows, knees, wrists or spine, so it needs more than the human did:
   - exaggerate the torso (turn, lean, drop) by 1.2-1.5x
   - slide the limbs that do the work (`pos`, inside the budgets): palms pushed out of the
     shoulders on a cast, legs riding into the torso on a crouch
   - legs on the pelvis (`space = "root"`, `ground = true`)
   - hold the release pose 4-8 frames, lead with the torso, trail the head and the free hand
4. **Audit and compare**: `R6Clip.audit` clean, `study` on your clip next to the reference's.
5. **Hands and feet**: `lune run compare <reference.rbxm> <yours.rbxm>` frame by frame. Arms
   within about 10 degrees and feet within 0.25 stud of the reference, except where you meant
   otherwise (and say where). A planted reference foot that moves in yours is skating.
6. **Look**: pose it in Studio at the release frame, play it in a playtest, or scrub the preview.

## 6. Archetype cards (what to look for)

These are checklists for reading references, not numbers to copy.

| Archetype | Phases to find in the reference | R6 notes |
|---|---|---|
| Projectile cast (fireball, bolt) | gather at the chest or hip, body coils; charge hold; palm(s) thrust along the aim line; recoil kicks the hands up/back | both arms slide forward 0.5-0.9 at release; torso leans into it; a short hop-back sells the recoil |
| Beam / channel | wide plant; hands locked forward; a looping strain with small shakes; start and end as separate clips | loop must be seamless; shake the torso, not only the arms |
| Summon / raise | hands low, body crouched; sweep up through the body; look up at the end | legs ride into the torso low, then extend out of it |
| Ground slam / AoE | rise or jump; hands or staff overhead; slam; deep drop | `overhead` audit: keys the arm up in front, not behind |
| Buff / heal / aura | arms gather in, then open out; chest up, head back; a breathing loop | spread arms past 90 to lift them sideways |
| Shield / barrier | arms cross, then push out; hold | forearms stacked in front of the face read best from the play camera |
| Teleport / blink | compact crouch to vanish; wide pose to arrive | two clips; VFX covers the cut |
| Staff / wand | the weapon leads the motion | `meta.tip` on the holding arm; a wand flick is a whole-arm flick with a slide (no wrist) |
| Bow / throw | draw back, hold at full draw, release, follow-through | the draw hand slides back 0.5-0.8 from the shoulder |
| Dance / emote | the beat: count it from the video | loops in whole beats; keep the feet honest |
